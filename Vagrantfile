# -*- mode: ruby -*-
# vi: set ft=ruby :

# WORK IN PROGRESS !!!
# http://tech.paulcz.net/2016/01/running-ha-docker-swarm/
# http://docs.master.dockerproject.org/engine/swarm/swarm-tutorial/create-swarm/
# Adding kubernetes: https://github.com/coreos/coreos-kubernetes/blob/master/multi-node/vagrant/Vagrantfile!

Vagrant.require_version ">= 1.6.0"

def read_bool_env key, default_value = false
  key = key.to_s
  if ENV.include?(key)
    return ! (['no', 'off', 'false', '0']).include?(ENV[key].strip.downcase)
  else
    return default_value
  end
end

def read_env key, default_value = nil, false_value = false
  key = key.to_s
  if ENV.include?(key)
    val = ENV[key].strip
    if  (['no', 'off', 'false', '0']).include? val
      return false_value
    else
      return val
    end
  else
    return default_value
  end
end

# Make sure the vagrant-ignition plugin is installed
required_plugins = %w(vagrant-ignition)
required_plugins << 'vagrant-scp' if read_bool_env 'SCP', true

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort "Installation of one or more plugins has failed. Aborting."
  end
end

memory = read_env 'MEM', '2048'
cpus = read_env 'CPU', '1'

host_itf = read_env 'ITF', false

leader_ip = (read_env 'MASTER_IP', "192.168.2.100").split('.').map {|nbr| nbr.to_i} # private ip ; public ip is to be set up with DHCP
hostname_prefix = read_env 'PREFIX', 'docker-'

nodes = (read_env 'NODES', 3).to_i
raise "There should be at least one node and at most 255 while prescribed #{nodes} ; you can set up node number like this: NODES=2 vagrant up" unless nodes.is_a? Integer and nodes >= 1 and nodes <= 255

coreos_canal = (read_env 'COREOS', 'alpha').downcase # could be 'beta', 'stable', 'uha'
box = if coreos_canal == 'uha' then 'coreos-alpha' else "coreos-#{coreos_canal}" end
box_url = if coreos_canal == 'uha' then 'https://svn.ensisa.uha.fr/vagrant/coreos_production_vagrant.json' else "https://#{coreos_canal}.release.core-os.net/amd64-usr/current/coreos_production_vagrant_virtualbox.json" end

enable_reboot = read_bool_env 'REBOOT_ON_UPDATE'

public = read_bool_env 'PUBLIC', false
private = read_bool_env 'PRIVATE', true

private_itf = 'eth1' # depends on chosen box and order of interface declaration
public_itf = if private then 'eth2' else 'eth1' end # depends on chosen box
default_itf = read_env 'DEFAULT_PUBLIC_ITF', if public then public_itf else private_itf end # default gateway
internal_itf = case ENV['INTERNAL_ITF']
  when 'public'
    raise 'Cannot use public interface in case it is disabled ; state PUBLIC=yes' unless public
    public_itf
  when 'private'
    raise 'Cannot use private interface in case it is disabled ; state PRIVATE=yes' unless private
    private_itf
  when String
    ENV['ETCD_ITF'].strip
  else
    if public then public_itf else private_itf end
  end # interface used for internal node communication by etcd and swarm (i.e. should it be public or private ?)

shared=read_env 'SHARED', false

docker_default_port = 2375
docker_port = read_env 'DOCKER_PORT', docker_default_port.to_s
docker_port = if docker_port then if docker_port.to_i.to_s == docker_port then docker_port.to_i else docker_default_port end else false end

docker_experimental = read_bool_env 'DOCKER_EXPERMIENTAL', false

etcd = read_env 'ETCD', 'latest' # check https://quay.io/repository/coreos/etcd?tag=latest&tab=tags
etcd = 'v'+etcd if etcd && etcd =~ /\A\d/ # e.g. 3.3.10 -> v3.3.10

etcd_size = read_env 'ETCD_SIZE', 3 # 3 is the default discovery.etcd.io value
if etcd_size
  etcd_size = etcd_size.to_i
  raise "Not enough servers configured: stated #{nodes} nodes while requested #{etcd_size} etcd nodes" if etcd_size > nodes
  etcd_url = read_env 'ETCD_TOKEN_URL', true
  raise "ETCD_TOKEN_URL should be an url such as https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX unlike #{etcd_url} ; ignore this parameter to generate one for a new cluster" if etcd_url.is_a? String and not etcd_url.start_with? 'https://discovery.etcd.io/'
else
  etcd_size = 0
  etcd_url = false
end

if read_bool_env 'ETCD_PORT'
  etcd_port = read_env 'ETCD_PORT', 0
  etcd_port = 2379 unless etcd_port.is_a? Integer
else
  etcd_port = 0
end

swarm = read_bool_env 'SWARM' # swarm mode is disabled by default ; use SWARM=on for setting up (only at node creation of leader)
raise "You shouldn't disable etcd when swarm mode is enabled" if swarm and not etcd_url
swarm_managers = (ENV['SWARM_MANAGERS'] || "#{hostname_prefix}02,#{hostname_prefix}03").split(',').map { |node| node.strip }.select { |node| node and node != ''}

nano = read_bool_env 'NANO', 1
compose = read_bool_env 'COMPOSE', 1
compose = read_env 'COMPOSE', '1.25.4' if compose

definitions = (1..nodes).map do |node_number|
  hostname = "%s%02d" % [hostname_prefix, node_number]
  ip = leader_ip.dup
  ip[-1] += node_number-1
  ip_str = ip.join('.')
  raise "Not enough addresses available for all nodes, e.g. can't assign IP #{ip_str} to #{hostname} ; lower NODES number or give another MASTER_IP" if ip[-1] > 255
  {:hostname => hostname, :ip => ip_str}
end

raise "There should be at least 3 nodes when etcd is enabled" if etcd_url and nodes < 3
# etc key generation
etcd_file_path = File.join(File.dirname(__FILE__), 'etcd_token_url')
# tries to read token
if etcd_url and not etcd_url.kind_of?(String) and File.file?(etcd_file_path)
  etcd_url = File.read etcd_file_path rescue true
end
# generating etcd token
if etcd_url and not etcd_url.kind_of?(String) and public
  require 'open-uri'
  puts 'Requesting a brand new etcd token'
  etcd_size_rq = if etcd_size then "?size=#{etcd_size.to_i}" else '' end
  etcd_url = URI.parse("https://discovery.etcd.io/new#{etcd_size_rq}").read
end
if etcd_url and etcd_url.kind_of?(String)
  # Storing found token
  File.open(etcd_file_path, 'w') do |file|
    file.write(etcd_url)
  end
elsif public
  etcd_url = false
end

if public
  require 'socket'
  vagrant_host = Socket.gethostname || Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
  puts "this host is #{vagrant_host}"
  require 'digest/md5' # used later for machine id generation so that dhcp returns the same IP
end

Vagrant.configure("2") do |config_all|
  # always use Vagrants insecure key
  config_all.ssh.insert_key = false
  # forward ssh agent to easily ssh into the different machines
  config_all.ssh.forward_agent = true

  config_all.vm.provider :virtualbox do |vb|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    vb.check_guest_additions = false
    vb.functional_vboxsf     = false
    # enable ignition (this is always done on virtualbox as this is how the ssh key is added to the system)
    config_all.ignition.enabled = true
  end

  if Vagrant.has_plugin?("vagrant-vbguest") then
    config_all.vbguest.auto_update = false
  end

  root_hostname = definitions[0][:hostname]
  root_ip = definitions[0][:ip]
  
  (1..nodes).each do |node_number|
    
    definition = definitions[node_number-1]
    hostname = definition[:hostname]
    ip = definition[:ip]
    
    config_all.vm.define hostname, primary: node_number == 1 do |config|
    
      config.vm.box = box
      begin config.vm.box_url = box_url if box_url rescue nil end
      
      config.vm.hostname = hostname
      
      config.vm.boot_timeout = 300
      
      config.vm.provider :virtualbox do |vb, override|
        vb.memory = memory
        vb.cpus = cpus
        vb.customize [
          'modifyvm', :id,
          '--name', hostname,
          '--cpuexecutioncap', '100',
          '--paravirtprovider', 'kvm',
        ]
	config.ignition.config_obj = vb
      end

      unless enable_reboot
        # Avoid being annoyed by auto-update reboots
        config.vm.provision :shell, :name => "disabling auto-reboot on update", :inline => <<-EOF
cat > /home/core/noreboot <<EOL
\#cloud-config

coreos:
  update:
    reboot_strategy: "off"
EOL
coreos-cloudinit --from-file=/home/core/noreboot 1>noreboot-application.log 2>&1
EOF
      end
      
      config.vm.network :private_network, ip: ip
      config.ignition.ip = ip if private

      if public
        options = {}
        # options[:use_dhcp_assigned_default_route] = true
        options[:bridge] = host_itf if host_itf
        options[:auto_config] = false
        options[:type] = 'dhcp'
        config.vm.network "public_network", **options

        machine_id = (Digest::MD5.hexdigest "#{hostname} on #{vagrant_host}").upcase
        machine_id[2] = (machine_id[2].to_i(16) & 0xFE).to_s(16).upcase # generated MAC must not be multicast
        machine_mac = "#{machine_id[1, 2]}:#{machine_id[3, 2]}:#{machine_id[5, 2]}:#{machine_id[7, 2]}:#{machine_id[9, 2]}:#{machine_id[11, 2]}"
      
        config.vm.provider :virtualbox do |vb, override|
          vb.customize [
            'modifyvm', :id,
            "--macaddress#{if private then "3" else "2" end}", "#{machine_mac.delete ':'}",
          ]
        end
      end

      # Referencing all IPs
      definitions.each do |other_nodes|
        config.vm.provision :shell, :name  => "referencing #{other_nodes[:hostname]}", :inline => "grep -q " + other_nodes[:hostname] + " /etc/hosts || echo \"" + other_nodes[:ip] + " " + other_nodes[:hostname] + "\" >> /etc/hosts"
      end
      
      if shared
        config.vm.synced_folder shared.to_s, "/home/core/share", id: "core", :nfs => true,  :mount_options   => ['nolock,vers=3,udp']
      end
      
      if nano
        config.vm.provision :shell, :run  => "always", :name => "checking for nano", :inline => "which nano >/dev/null || ( echo \"installing nano\" && wget https://svn.ensisa.uha.fr/vagrant/opt-nano-bin.tar.gz 2>/dev/null && tar xzf opt-nano-bin.tar.gz && cp -r opt / && rm -rf opt && echo \"TERM=vt100\" >> /etc/environment)"
      end
      
      if compose && node_number == 1
        config.vm.provision :shell, :run => "always", :name => "checking for docker-compose", :inline => "which docker-compose >/dev/null || ( echo \"installing docker-compose\" && mkdir -p /opt/bin && wget -O /opt/bin/docker-compose \"https://github.com/docker/compose/releases/download/#{compose}/docker-compose-Linux-x86_64\" 2>/dev/null && chmod a+x /opt/bin/docker-compose )"
      end

      if docker_experimental
        config.vm.provision :shell, run: "always", :name => "enabling Docker expermental features", :inline => <<-EOF
CLOUDINIT_FILE=/home/core/dockerxp
if [ ! -f "${CLOUDINIT_FILE}" ]; then
  echo "Enabling Docker experimental features"
  cat > $CLOUDINIT_FILE <<EOL
\#cloud-config

coreos:
  units:
    - name: docker.service
      drop-ins:
        - name: "50-experimental.conf"
          content: |
            [Service]
            Environment=DOCKER_OPTS='--experimental=true'
EOL
  coreos-cloudinit --from-file=$CLOUDINIT_FILE 1>dockerxp-application.log 2>&1 &
  systemctl restart docker
fi
EOF
      end

      config.vm.provider :virtualbox do |vb|
        config.ignition.hostname = hostname
        config.ignition.drive_name = "config" + node_number.to_s
        # when the ignition config doesn't exist, the plugin automatically generates a very basic Ignition with the ssh key
        # and previously specified options (ip and hostname).
      end

      if node_number == 1
        # Publishing etcd client port
        config.vm.network "forwarded_port", guest: 2379, host: etcd_port if etcd_port > 0

        # Making Docker remotely available from the host machine
        config.vm.provision :shell, run: "always", :name => "configuring etcd", :inline => <<-EOF
REMOTE_DOCKER_CONF_FILE=/etc/systemd/system/docker-tcp.socket
if [ ! -f "${REMOTE_DOCKER_CONF_FILE}" ]; then
    echo "Enabling docker remote port on #{hostname} ; export DOCKER_HOST=tcp://#{ip}:#{docker_port} to use it with your local Docker client"
    # see https://coreos.com/os/docs/latest/customizing-docker.html
    cat > $REMOTE_DOCKER_CONF_FILE <<EOL
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=#{ip}:#{docker_port}
BindIPv6Only=both
Service=docker.service

[Install]
WantedBy=sockets.target
EOL
    systemctl enable docker-tcp.socket
    systemctl stop docker
    systemctl start docker-tcp.socket
    systemctl start docker
fi
EOF
      end
      
      if etcd_url

        if public
          # Storing found token
          File.open(etcd_file_path, 'w') do |file|
            file.write(etcd_url)
          end
          etcd_discovery = "
    discovery: #{etcd_url}"
        else
          etcd_discovery = ""
        end
      
        config.vm.provision :shell, run: "always", :name => "configuring etcd", :inline => <<-EOF
if [ ! -f /home/core/etcd ]; then
  echo -n "Checking ip address "
  n=0
  until [ $n -ge 5 ]; do
    IP=$(ip -4 addr list #{internal_itf} |  grep -v secondary | grep inet | sed 's/.*inet\\s*\\([0-9.]*\\).*/\\1/' | head -n 1)
    [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$  ]] && break
    echo -n "."
    n=$[$n+1]
    sleep 2
  done
  if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$  ]]; then
    echo " found ip '$IP'"

    cat > /home/core/etcd <<EOL
\#cloud-config

coreos:
  etcd:
    #{if public then "discovery: #{etcd_url}" else "" end}
    version: #{etcd}
    name: #{hostname}
    advertise-client-urls: http://$IP:2379
    initial-advertise-peer-urls: http://$IP:2380
    listen-client-urls: http://0.0.0.0:2379
    listen-peer-urls: http://$IP:2380
    #{if public then "" else "initial-cluster: #{definitions[0, etcd_size].map { |definition| "#{definition[:hostname]}=http://#{definition[:ip]}:2380"}.join ','}" end}
    #{if public then "" else "initial-cluster-state: new" end}
  units:
    - name: etcd-member.service
      command: start
      enable: true
      drop-ins:
        - name: 20-clct-etcd-member.conf
          content: |
            [Service]
            Environment="ETCD_IMAGE_TAG=#{etcd}"
            Environment="#{if public then "ETCD_DISCOVERY=#{etcd_url}" else "ETCD_INITIAL_CLUSTER=#{definitions[0, etcd_size].map { |definition| "#{definition[:hostname]}=http://#{definition[:ip]}:2380"}.join ','}" end}"
            Environment="ETCD_ADVERTISE_CLIENT_URLS=http://$IP:2379"
            Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://$IP:2380"
            Environment="ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379"
            Environment="ETCD_LISTEN_PEER_URLS=http://$IP:2380"
            Environment="ETCD_NAME=#{hostname}"
EOL
    #export ETCD_OPTS="--name #{hostname} --listen-peer-urls http://$IP:2380 --listen-client-urls http://0.0.0.0:2379 --initial-advertise-peer-urls http://$IP:2380 --advertise-client-urls http://$IP:2379 --discovery #{etcd_url}"
    #echo "ETCD_OPTS=$ETCD_OPTS" >> /etc/environment
    coreos-cloudinit --from-file=/home/core/etcd 1>etcd-application.log 2>&1 &
  else
    echo "Cannot determine IP, please issue a 'vagrant up #{hostname}' again}"
  fi
fi
EOF
        
        if swarm
          
          role = if node_number == 1 or swarm_managers.include? hostname then 'manager' else 'worker' end
          config.vm.provision :shell, run: "always", :name => "checking swarm", :inline => <<-EOF
\# Checking whether a swarm already exists
etcdctl ls | grep vagrant-swarm >/dev/null || etcdctl mkdir vagrant-swarm
MANAGERS=$(etcdctl ls /vagrant-swarm | grep '_address$' | sed 's;^/vagrant-swarm/swarm_\\(.*\\)_address;\\1;')
HOST_IP=$(ip -4 addr list #{internal_itf} |  grep -v secondary | grep inet | sed 's/.*inet\\s*\\([0-9.]*\\).*/\\1/')
if [ -z "$MANAGERS" ]; then
  \# first node to appear: creating swarm (if not already)
  echo "initializing swarm";
  docker swarm init --advertise-addr $HOST_IP --listen-addr $HOST_IP;
elif [ "0" != $(docker node list 1>/dev/null 2>&1;echo $?) ]; then
  echo \"joining swarm as #{role}\"
  \# iterating over manager nodes to join
  for MANAGER in $MANAGERS; do
    docker swarm join --token $(etcdctl get "/vagrant-swarm/swarm_${MANAGER}_token_#{role}") $(etcdctl get "/vagrant-swarm/swarm_${MANAGER}_address") && break
  done
fi
if [ "#{role}" == "manager" ]; then
  \# Storing join token in etcd
  etcdctl get /vagrant-swarm/swarm_#{hostname}_address 1>/dev/null 2>&1 || etcdctl set /vagrant-swarm/swarm_#{hostname}_address $(docker swarm join-token worker | grep 'docker swarm join' | grep -o '[0-9]*\\.[0-9]*\\.[0-9]*\\.[0-9]*:[0-9]*$')
  etcdctl get /vagrant-swarm/swarm_#{hostname}_token_worker 1>/dev/null 2>&1 || etcdctl set /vagrant-swarm/swarm_#{hostname}_token_worker $(docker swarm join-token -q worker)
  etcdctl get /vagrant-swarm/swarm_#{hostname}_token_manager 1>/dev/null 2>&1 || etcdctl set /vagrant-swarm/swarm_#{hostname}_token_manager $(docker swarm join-token -q manager)
fi
EOF
   
          # TODO: docker service create     --name portainer     --publish 9000:9000     --constraint 'node.role == manager'     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock     portainer/portainer     -H unix:///var/run/docker.sock
       
        end # swarm
        
      end # etcd
      
    end # node cfg
  end # nodes
end # config
