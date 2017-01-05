This is a Vagrantfile for mounting a Docker Swarm cluster using CoreOS nodes

Key value store is etcd.

Both a public (DHCP assigned) and a private (only visible on the node) network interfaces are set up. By default, etcd and swarm are advertized using the public interface so that one can set up multiple nodes on different machines of the local network.

## Requirements ##

This script was tested against Vagrant > 1.9 and Virtualbox > 5.
It shoud be OK on Linux (tested on 4.9), MacOS X (tested on 10.11), Windows (tested on 10). It might also work on other hosts, please report other working stations...
In case you use Windows, you'll need an ssh client, such as the ones you gen when installing git, Cygwin or MinGW64.

## Usage ##

First, clone the repo
`git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant`

To initialize a cluster, just issue `vagrant up`.
3 CoreOS nodes are set up (*docker-1*, *docker-2*, and *docker-3*) and form an etcd cluster.
An etcd token url is automatically requested from discovery.etcd.io. The token url is stored to *etcd_token_url* file so that new nodes can be fired up and allowed to join.

To start Swarm, then issue
```
export SWARM=on
vagrant provision
```
or on windows
```
set SWARM=on
vagrant provision
```
The previous three node now form a Docker Swarm cluster.
This can't be done during the `vagrant up` phase as Swarm leader ip  and join token are shared using etcd (using /vagrant-swarm/swarm_docker-1_adress and /vagrant-swarm/swarm_token_worker keys, respectively). Indeed, etcd needs at least 3 nodes up and running to work which is the case only at the end of the `vagrant up` phase.

Now you can connect your cluster by 
`vagrant ssh docker-1` (or any other docker-X node).
It's now time to play with Docker Swarm.

To add a fourth node:
```
export NODES=4
export SWARM=on
vagrant up docker-4
```
or on Windows
```
set NODES=4
set SWARM=on
vagrant up docker-4
```
As etcd should be up, there is no longer need for the two phase `vagrant up` then `vagrant provision` for this node to join the Swarm.

## Setting up a node on another VirtualBox host ##

If you wand to add a node on another host, copy the contents of the previously generated *etcd_token_url* file and fire on the new host (replace XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX with you etcd token):
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
SWARM=ON NODES=4 ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' vagrant up docker-4
```
or on Windows
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
set SWARM=ON
set NODES=4
set ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
vagrant up docker-4
```
The ETCD_TOKEN_URL is also stored on etcd_token file on the new host making the ETCD_TOKEN_URL parameter useless for next `vagrant up`.
