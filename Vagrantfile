# -*- mode: ruby -*-
# vi: set ft=ruby :

# WORK IN PROGRESS !!!
# http://tech.paulcz.net/2016/01/running-ha-docker-swarm/
# http://docs.master.dockerproject.org/engine/swarm/swarm-tutorial/create-swarm/

def read_bool_env key
  key = key.to_s
  return ENV[key] && (!['off', 'false', '0'].include?(ENV[key].strip.downcase)) || false
end

leader_ip = (ENV['MASTER_IP'] || "192.168.1.100").split('.').map {|nbr| nbr.to_i} # private ip ; public ip is to be set up with DHCP
raise "Master ip should be an ipv4 adress unlike #{leader_ip}" unless leader_ip.size == 4 and leader_ip.all? { |ipelt| (0..255).include? ipelt }
hostname_prefix = 'docker-'

nodes = if read_bool_env 'NODES' then ENV['NODES'].to_i else 3 end rescue 3
raise "There should be at least one node and at most 255 while prescribed #{nodes} ; you can set up node number like this: NODES=2 vagrant up" unless nodes.is_a? Integer and nodes > 1 and nodes <= 255

coreos_canal = 'alpha' # could be 'beta' or 'stable' though stable has a docker 1.11 version at the time of writing (so no SWARM mode available)
box = "coreos-#{coreos_canal}"
#box_url = 'https://svn.ensisa.uha.fr/vagrant/coreos_production_vagrant.json'
box_url = "https://storage.googleapis.com/#{coreos_canal}.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"
# see https://coreos.com/blog/coreos-clustering-with-vagrant.html
public_itf = 'eth1' # depends on chosen box
private_itf = 'eth2' # depends on chosen box
ipv6 = read_bool_env 'IPV6' # ipv6 is disabled by default ; use IPV6=on for avoiding this (to be set at node creation only)
default_itf = read_bool_env 'DEFAULT_PUBLIC_ITF' # default gateway

etcd_url = ENV['ETCD_TOKEN_URL'] || true
raise "ETCD_TOKEN_URL should be an url such as https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ; ignore this parameter to generate one for a new cluster" if etcd_url.is_a? String and not etcd_url.start_with? 'https://discovery.etcd.io/'
etcd_advertised_itf = case ENV['ETCD_ITF']
  when 'public'
    public_itf
  when 'private'
    private_itf
  when String
    ENV['ETCD_ITF'].strip
  else
    public_itf
  end # interface used by etcd (i.e. should it be public or private ?)

definitions = (1..nodes).map do |node_number|
  hostname = "#{hostname_prefix}#{node_number}"
  ip = leader_ip.dup
  ip[-1] += node_number-1
  ip_str = ip.join('.')
  raise "Not enough adresses available for all nodes, e.g. can't assign IP #{ip_str} to #{hostname} ; lower NODES number or given another MASTER_IP" if ip[-1] > 255
  {:hostname => hostname, :ip => ip_str}
end

# etc key generation
etcd_file_path = File.join(File.dirname(__FILE__), 'etcd_token_url')
# tries to read token
if etcd_url and not etcd_url.kind_of?(String) and File.file?(etcd_file_path)
  etcd_url = File.read etcd_file_path rescue true
end
# generating etcd token
if etcd_url and not etcd_url.kind_of?(String)
  require 'open-uri'
  etcd_url = URI.parse("https://discovery.etcd.io/new?size=#{nodes}").read
end
if etcd_url and etcd_url.kind_of?(String)
  # Storing found token
  File.open(etcd_file_path, 'w') do |file|
    file.write(etcd_url)
  end
else 
  etcd_url = false
end

Vagrant.configure("2") do |config_all|
  (1..nodes).each do |node_number|
    
    definition = definitions[node_number-1]
    hostname = definition[:hostname]
    ip = definition[:ip]
    
    config_all.vm.define hostname do |config|
    
      config.vm.box = box
      begin config.vm.box_url = box_url if box_url rescue nil end
      
      config.vm.hostname = hostname
      config.vm.network "public_network", bridge: "en0: Ethernet", use_dhcp_assigned_default_route: true
      config.vm.network "private_network", ip: ip
      
      config.vm.boot_timeout = 300
      
      config.vm.provider :virtualbox do |vb, override|
        vb.customize [
          'modifyvm', :id,
          '--name', hostname,
          '--memory', '2048',
          '--cpuexecutioncap', '100',
        ]
      end
  
      # Network stuff
      if default_itf
        # Clearing unwanted gateways
        config.vm.provision "shell",  run: "always",  inline: "ip route show | grep '^default' | sed 's;^.*\\sdev\\s*\\([a-z0-9]*\\)\\s*.*$;\\1;' | grep -v #{default_itf} | xargs -I ITF ip route del default dev ITF"
        # Making it sure a default route exists
        config.vm.provision "shell", run: "always", inline: "ip route show | grep -q '^default' || dhclient #{default_itf}"
      end
      unless ipv6
        # Disabling IPv6
        ipv6_file = '/etc/sysctl.d/vagrant-disable-ipv6.conf'
        config.vm.provision "shell", inline: "touch #{ipv6_file} ; sed -i '/disable_ipv6/d' #{ipv6_file}; find /proc/sys/net/ipv6/ -name disable_ipv6 | sed -e 's;^/proc/sys/;;' -e 's;/;.;g' -e 's;$; = 1;' >> #{ipv6_file} ; sysctl -p #{ipv6_file}"
      end
      # checking all interfaces are active
      config.vm.provision "shell", run: "always", inline: "ip a | grep '^[0-9]' | grep DOWN | cut -d: -f2 | grep -v docker | xargs -I ITF ip link set dev ITF up"
      
      # Referencing all IPs
      definitions.each do |other_nodes|
        config.vm.provision "shell", inline: "grep -q " + other_nodes[:hostname] + " /etc/hosts || echo \"" + other_nodes[:ip] + " " + other_nodes[:hostname] + "\" >> /etc/hosts"
      end
      
      if etcd_url

          # Storing found token
          File.open(etcd_file_path, 'w') do |file|
            file.write(etcd_url)
          end
          
          # generating etcd config
          config_file = File.join(File.dirname(__FILE__), "user-data-#{hostname}")
          
          File.open(config_file, 'w') do |file|
          file.write <<-EOF
\#cloud-config

hostname: #{hostname}
coreos:
  etcd2:
    discovery: #{etcd_url}
    advertise-client-urls: http://$public_ipv4:2379,http://$public_ipv4:4001
    initial-advertise-peer-urls: http://$public_ipv4:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://$public_ipv4:2380
  units:
    - name: etcd2.service
      command: start
EOF
          end
      
        config.vm.provision :file, :source => config_file, :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "sed -i -e \"s/\\$public_ipv4/$(ip -4 addr list #{etcd_advertised_itf} | grep inet | sed 's/.*inet\\s*\\([0-9.]*\\).*/\\1/')/g\" /tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end
      
    end
  end
end