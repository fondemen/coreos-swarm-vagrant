# -*- mode: ruby -*-
# vi: set ft=ruby :

# WORK IN PROGRESS !!!
# http://tech.paulcz.net/2016/01/running-ha-docker-swarm/
# http://docs.master.dockerproject.org/engine/swarm/swarm-tutorial/create-swarm/

leader_ip = [192,168,1,100]

box = 'coreos-alpha'
box_url = 'https://svn.ensisa.uha.fr/vagrant/coreos_production_vagrant.json'
#box_url = 'https://storage.googleapis.com/alpha.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json'
# see https://coreos.com/blog/coreos-clustering-with-vagrant.html

#box = 'debian/contrib-jessie64'
#box_url = 'https://svn.ensisa.uha.fr/vagrant/contrib-jessie64.box'

nodes = 3

etcd_url = true # undef to avoid creating one, or the url

default_itf = 'eth1'

definitions = (1..nodes).map do |node_number|
  ip = leader_ip.dup
  ip[-1] += node_number-1
  {:hostname => "docker-#{node_number}", :ip => ip.join('.')}
end
# puts definitions.inspect

# etc key generation
etcd_file_path = File.join(File.dirname(__FILE__), 'etcd_token_url')
# tries to read token
if etcd_url and not etcd_url.kind_of?(String) and File.file?(etcd_file_path)
  etcd_url = File.read '.etcd_token_url' rescue true
end
# generating etc token
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
        config.vm.provision "shell",  run: "always",  inline: "ip route show | grep '^default' | sed 's;^.*\\sdev\\s*\\([a-z0-9]*\\)\\s*.*$;\\1;' | grep -v " + default_itf + " | xargs -I ITF ip route del default dev ITF"
        # Making it sure a default route exists
        config.vm.provision "shell", run: "always", inline: "ip route show | grep -q '^default' || dhclient " + default_itf
      end
      # Disabling IPv6
      config.vm.provision "shell", inline: "sed -i '/disable_ipv6/d' /etc/sysctl.conf; find /proc/sys/net/ipv6/ -name disable_ipv6 | sed -e 's;^/proc/sys/;;' -e 's;/;.;g' -e 's;$; = 1;' >> /etc/sysctl.conf ; sysctl -p"
      # checking all interfaces are active
      config.vm.provision "shell", run: "always", inline: "ip a | grep '^[0-9]' | grep DOWN | cut -d: -f2 | grep -v docker | xargs -I ITF ifup ITF"
      
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
    advertise-client-urls: http://#{ip}:2379,http://#{ip}:4001
    initial-advertise-peer-urls: http://#{ip}:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://#{ip}:2380
  units:
    - name: etcd2.service
      command: start
EOF
          end
      
        config.vm.provision :file, :source => config_file, :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end
      
    end
  end
end