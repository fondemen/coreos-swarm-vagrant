# -*- mode: ruby -*-
# vi: set ft=ruby :

# WORK IN PROGRESS !!!
# http://tech.paulcz.net/2016/01/running-ha-docker-swarm/
# http://docs.master.dockerproject.org/engine/swarm/swarm-tutorial/create-swarm/
# Adding kubernetes: https://github.com/coreos/coreos-kubernetes/blob/master/multi-node/vagrant/Vagrantfile

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

memory = read_env 'MEM', '2048'
cpus = read_env 'CPU', '1'

host_itf = read_env 'ITF', false

leader_ip = (read_env 'MASTER_IP', "192.168.2.100").split('.').map {|nbr| nbr.to_i} # private ip ; public ip is to be set up with DHCP
hostname_prefix = read_env 'PREFIX', 'docker-'

nodes = (read_env 'NODES', 3).to_i
raise "There should be at least one node and at most 255 while prescribed #{nodes} ; you can set up node number like this: NODES=2 vagrant up" unless nodes.is_a? Integer and nodes >= 1 and nodes <= 255

coreos_canal = read_env 'COREOS', 'alpha' # could be 'beta' or 'stable' though stable has a docker 1.11 version at the time of writing (so no SWARM mode available)
box = "coreos-#{coreos_canal}"
#box_url = 'https://svn.ensisa.uha.fr/vagrant/coreos_production_vagrant.json'
box_url = "https://storage.googleapis.com/#{coreos_canal}.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"
# see https://coreos.com/blog/coreos-clustering-with-vagrant.html

public = read_bool_env 'PUBLIC', true
private = read_bool_env 'PRIVATE', true

public_itf = 'eth1' # depends on chosen box and order of interface declaration
private_itf = if public then 'eth2' else 'eth1' end # depends on chosen box
ipv6 = read_bool_env 'IPV6' # ipv6 is disabled by default ; use IPV6=on for avoiding this (to be set at node creation only)
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

etcd_url = read_env 'ETCD_TOKEN_URL', true
raise "ETCD_TOKEN_URL should be an url such as https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX unlike #{etcd_url} ; ignore this parameter to generate one for a new cluster" if etcd_url.is_a? String and not etcd_url.start_with? 'https://discovery.etcd.io/'
etcd_url = false unless read_bool_env 'ETCD', true

swarm = read_bool_env 'SWARM' # swarm mode is disabled by default ; use SWARM=on for setting up (only at node creation of leader)
raise "You shouldn't disable etcd when swarm mode is enabled" if swarm and not etcd_url
swarm_managers = (ENV['SWARM_MANAGERS'] || 'docker-2,docker-3').split(',').map { |node| node.strip }.select { |node| node and node != ''}

nano = read_bool_env 'NANO', 1
compose = read_bool_env 'COMPOSE', 1
compose = read_env 'COMPOSE', '1.11.2' if compose

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
if etcd_url and not etcd_url.kind_of?(String)
  require 'open-uri'
  puts 'Requesting a brand new etcd token'
  etcd_url = URI.parse("https://discovery.etcd.io/new").read
end
if etcd_url and etcd_url.kind_of?(String)
  # Storing found token
  File.open(etcd_file_path, 'w') do |file|
    file.write(etcd_url)
  end
else 
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
  end

  if Vagrant.has_plugin?("vagrant-vbguest") then
    config_all.vbguest.auto_update = false
  end
  
  (1..nodes).each do |node_number|
    
    definition = definitions[node_number-1]
    hostname = definition[:hostname]
    ip = definition[:ip]
    
    config_all.vm.define hostname do |config|
    
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
      end

      if public
        options = {}
        # options[:use_dhcp_assigned_default_route] = true
        options[:bridge] = host_itf if host_itf
        options[:auto_config] = false
        config.vm.network "public_network", **options

        machine_id = (Digest::MD5.hexdigest "#{hostname} on #{vagrant_host}").upcase
        machine_mac = "#{machine_id[1, 2]}:#{machine_id[3, 2]}:#{machine_id[5, 2]}:#{machine_id[7, 2]}:#{machine_id[9, 2]}:#{machine_id[11, 2]}"
      
        config.vm.provider :virtualbox do |vb, override|
          vb.customize [
            'modifyvm', :id,
            '--macaddress2', "#{machine_mac.delete ':'}",
          ]
        end
      
        # Avoid getting multiple IPs from DHCP
        # see https://coreos.com/os/docs/latest/network-config-with-networkd.html
        config.vm.provision :shell, :name => "public interface setup", :inline => <<-EOF
cat > /var/lib/coreos-vagrant/dhcp <<EOL
\#cloud-config
  
hostname: #{hostname}

coreos:
  units:
    - name: systemd-networkd.service
      command: stop
    - name: 00-#{public_itf}.network
      runtime: true
      content: |
        [Match]
        Name=#{public_itf}

        [Link]
        MACAddress=#{machine_mac}

        [Network]
        DHCP=yes
        
        [DHCP]
        UseMTU=true
        UseDomains=true
        ClientIdentifier=mac
    - name: down-interfaces.service
      command: start
      content: |
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/ip link set #{public_itf} down
        ExecStart=/usr/bin/ip addr flush dev #{public_itf}
    - name: systemd-networkd.service
      command: restart
EOL
coreos-cloudinit --from-file=/var/lib/coreos-vagrant/dhcp 1>dhcp-opt-application.log 2>&1
EOF
      end
      
      if private
        config.vm.network :private_network, ip: ip
      end
  
      # Network stuff
#      if default_itf
#        # Clearing unwanted gateways
#        config.vm.provision "shell", run: "always",  inline: "ip route show | grep '^default' | sed 's;^.*\\sdev\\s*\\([a-z0-9]*\\)\\s*.*$;\\1;' | grep -v #{default_itf} | xargs -I ITF ip route del default dev ITF"
#        # Making it sure a default route exists
#        config.vm.provision "shell", run: "always", inline: "ip route show | grep -q '^default' || dhcpcd #{default_itf}"
#      end
      # Dropping secondary dhcp-assigned interfaces
      # config.vm.provision "shell", run: "always", inline: "for itf in $(ip -4 addr list #{public_itf} |  grep secondary | grep inet | sed 's;.*inet\\s*\\([0-9.]*/[0-9]*\\).*;\\1;'); do sudo ip addr del $itf dev #{public_itf}; done"
#      unless ipv6
#        # Disabling IPv6
#        ipv6_file = '/etc/sysctl.d/vagrant-disable-ipv6.conf'
#        config.vm.provision "shell", inline: "touch #{ipv6_file} ; sed -i '/disable_ipv6/d' #{ipv6_file}; find /proc/sys/net/ipv6/ -name disable_ipv6 | sed -e 's;^/proc/sys/;;' -e 's;/;.;g' -e 's;$; = 1;' >> #{ipv6_file} ; sysctl -p #{ipv6_file}"
#      end
#      # checking all interfaces are active
#      config.vm.provision "shell", run: "always", inline: "ip a | grep '^[0-9]' | grep DOWN | cut -d: -f2 | grep -v docker | xargs -I ITF ip link set dev ITF up"
      
      # Referencing all IPs
      definitions.each do |other_nodes|
        config.vm.provision :shell, :name  => "referencing #{other_nodes[:hostname]}", :inline => "grep -q " + other_nodes[:hostname] + " /etc/hosts || echo \"" + other_nodes[:ip] + " " + other_nodes[:hostname] + "\" >> /etc/hosts"
      end
      
      if shared
        config.vm.synced_folder shared.to_s, "/home/core/share", id: "core", :nfs => true,  :mount_options   => ['nolock,vers=3,udp']
      end
      
      if nano
        config.vm.provision :shell, :run  => "always", :name => "checking for nano", :inline => "which nano >/dev/null || ( echo \"installing nano\" && wget https://svn.ensisa.uha.fr/vagrant/opt-nano-bin.tar.gz 2>/dev/null && tar xzf opt-nano-bin.tar.gz && cp -r opt / && rm -rf opt )"
      end
      
      if compose && node_number == 1
        config.vm.provision :shell, :run => "always", :name => "checking for docker-compose", :inline => "which docker-compose >/dev/null || ( echo \"installing docker-compose\" && mkdir -p /opt/bin && wget -O /opt/bin/docker-compose \"https://github.com/docker/compose/releases/download/#{compose}/docker-compose-Linux-x86_64\" 2>/dev/null && chmod a+x /opt/bin/docker-compose )"
      end
      
      if etcd_url

        # Storing found token
        File.open(etcd_file_path, 'w') do |file|
          file.write(etcd_url)
        end
      
        config.vm.provision :shell, run: "always", :name => "configuring etcd", :inline => <<-EOF
if [ ! -f /var/lib/coreos-vagrant/etcd ]; then
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
    echo " found '$IP'"
    cat > /var/lib/coreos-vagrant/etcd <<EOL
\#cloud-config

coreos:
  etcd2:
    discovery: #{etcd_url}
    advertise-client-urls: http://$IP:2379,http://$IP:4001
    initial-advertise-peer-urls: http://$IP:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://$IP:2380
  units:
    - name: etcd2.service
      command: start
EOL
    coreos-cloudinit --from-file=/var/lib/coreos-vagrant/etcd 1>etcd-application.log 2>&1 &
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
  etcdctl get /vagrant-swarm/swarm_#{hostname}_address 1>/dev/null 2>&1 || etcdctl set /vagrant-swarm/swarm_#{hostname}_address $(docker swarm join-token worker | sed 's;\\s;;g' | grep -o '^[0-9]*\\.[0-9]*\\.[0-9]*\\.[0-9]*:[0-9]*$')
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
