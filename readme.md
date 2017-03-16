This is a Vagrantfile for mounting a Docker Swarm cluster using CoreOS nodes

Used key value store for swarm is etcd.

Both a public (DHCP assigned) and a private (only visible on the node) network interfaces are set up. By default, etcd and swarm are advertized using the public interface so that one can set up multiple nodes on different machines of the local network.

## Requirements ##

This script was tested against Vagrant > 1.9 and Virtualbox > 5.
It shoud be OK on Linux (tested on 4.9), MacOS X (tested on 10.11 and 10.12), Windows (tested on 8 and 10). It might also work on other hosts, please report other working stations...
In case you use Windows, you'll need an ssh client, such as the ones you get when installing git, Cygwin or MinGW64. Otherwise, have a look at the [PuTTY Vagrant plugin](https://github.com/nickryand/vagrant-multi-putty)

## Usage ##

First, clone the repo
`git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant`

To initialize a cluster, just issue `vagrant up`.
3 CoreOS nodes are set up (*docker-01*, *docker-O2*, and *docker-03*) and form an etcd2 cluster.
An etcd token url is automatically requested from discovery.etcd.io. The token url is stored to *etcd_token_url* file so that new nodes can be fired up and allowed to join.

To start Swarm, then issue
```
export SWARM=on
vagrant up
```
or on windows cmd
```
set SWARM=on
vagrant up
```
The previous three node now form a Docker Swarm cluster.
This can't be done during the first `vagrant up` phase as Swarm leader ip  and join token are shared using etcd (using /vagrant-swarm/swarm_docker-1_adress and /vagrant-swarm/swarm_token_worker keys, respectively). Indeed, etcd needs at least 3 nodes up and running to work which is the case only at the end of the first `vagrant up` phase.

Now you can connect your cluster by 
`vagrant ssh docker-01` (or any other docker-XX node).
It's now time to play with Docker Swarm.

## Setting up a new node on the same VirtualBox host ##

To add a fourth node:
```
export NODES=4
export SWARM=on
vagrant up docker-4
```
or on Windows cmd
```
set NODES=4
set SWARM=on
vagrant up docker-4
```
As etcd should be up, there is no longer need for the two phase `vagrant up` then `vagrant provision` for this node to join the Swarm.

## Setting up a new node on another VirtualBox host ##

If you wand to add a node on another host, copy the contents of the previously generated *etcd_token_url* file and fire on the new host (replace XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX with you etcd token):
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
SWARM=ON NODES=4 ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' vagrant up docker-4
```
or on Windows cmd
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
set SWARM=ON
set NODES=4
set ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
vagrant up docker-4
```
The ETCD_TOKEN_URL is also stored on etcd_token file on the new host making the ETCD_TOKEN_URL parameter useless for next `vagrant up`.

## Managers ##

For swarm to be highly available (i.e. survive the loss of the leader node), one needs to add manager nodes. Default manager nodes is docker-01 alone.
You can change them using the SWARM_MANAGERS environment variable, e.g. `SWARM=ON NODES=8 SWARM_MANAGERS=docker-1,docker-3,docker-5 vagrant provision`.

## Destroying cluster ##

Simply issue a `vagrant destroy && rm etcd_token_url` on each Vagrant host.

etcd token must be re-created for a new cluster, that's why the *etcd_token_url* file has to be deleted.

## Docker remote access ##

If you have the docker client installed, you can control you Docker cluster from the host machine running docker-01 VM.
To do so:
```
export DOCKER_PORT=2375
vagrant up docker-01

export DOCKER_HOST=192.168.2.100:2375 # to tell your docker client how to connect (192.168.2.100 is the private IP of your machine)
docker info | grep ^Name\\s*:\\s* # to test whether the docker client actually connects docker-01
```