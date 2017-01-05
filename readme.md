This is a Vagrantfile for mounting a Docker Swarm cluster using CoreOS nodes
Key value store is etcd.
Both a public (DHCP assigned) and a private (only visible on the node) network interface are set up. By default, etcd and swarm are advertized using the public interface so that one can set up multiple nodes on different machines of the local network.

== Requirements ==

This script was tested against Vagrant > 1.9 and Virtualbox > 5.
It shoud be OK on Linux (tested on 4.4), Windows (tested on 8) and MacOS X (tested on 10.11)

== Usage ==

To initialize a cluster, just issue
`vagrant up`

To start swarm, then issue
`SWARM=on vagrant provision`
This can't be done during the `vagrant up` phase as swarm join token and leader ip are stored in etcd (using /vagrant-swarm/swarm_docker-1_adress and /vagrant-swarm/swarm_token_worker keys, respectively). Indeed, etcd needs at least 3 nodes up and running to work.

By default, 3 nodes (docker-1, docker-2, docker-3) are set up. docker-1 is the leader (both for etcd and swarm). You can connect it by 
`vagrant ssh docker-1`

To add a fourth node:
```
NODES=4 SWARM=on vagrant up docker-4
```

etcd is automatically set up by requesting a token to discovery.etcd.io. Token is stored to etcd_token_url file so that new nodes can be fired up (as the fourth above).
