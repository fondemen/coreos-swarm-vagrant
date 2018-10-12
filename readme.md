This is a Vagrantfile for mounting a Docker Swarm cluster using CoreOS nodes

Used key value store for swarm is etcd.

Both a public (DHCP assigned) and a private (only visible on the node) network interfaces are set up. By default, etcd and swarm are advertized using the public interface so that one can set up multiple nodes on different machines of the local network.

## Requirements ##

This script was tested against Vagrant > 1.9 and Virtualbox > 5.
It shoud be OK on Linux (tested on 4.9), MacOS X (tested on 10.11 and 10.12), Windows (tested on 8 and 10). It might also work on other hosts, please report other working stations...
In case you use Windows, you'll need an ssh client, such as the ones you get when installing git, Cygwin or MinGW64. Otherwise, have a look at the [PuTTY Vagrant plugin](https://github.com/nickryand/vagrant-multi-putty)

## Single-node usage ##

If you just want a single node to play with Docker:
`git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant;PUBLIC=0 NODES=1 ETCD_SIZE=0 vagrant up`

## Multi-node usage ##

First, clone the repo
`git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant`

To initialize a cluster, just issue `vagrant up`.
3 CoreOS nodes are set up (*docker-01*, *docker-O2*, and *docker-03*) and form an etcd cluster.
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
vagrant up docker-04
```
or on Windows cmd
```
set NODES=4
set SWARM=on
vagrant up docker-04
```
As etcd should be already up and running, there is no longer need for the two phase `vagrant up` for this node to join the Swarm.

## Setting up a new node on another VirtualBox host ##

If you wand to add a node on another host, copy the contents of the previously generated *etcd_token_url* file and fire on the new host (replacing XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX with your etcd token):
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
SWARM=ON NODES=4 ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' vagrant up docker-04
```
or on Windows cmd
```
git clone https://github.com/fondemen/coreos-swarm-vagrant.git ; cd coreos-swarm-vagrant
set SWARM=ON
set NODES=4
set ETCD_TOKEN_URL='https://discovery.etcd.io/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
vagrant up docker-04
```
The ETCD_TOKEN_URL is also stored on etcd_token file on the new host making the ETCD_TOKEN_URL parameter unnecessary for next `vagrant up`.

## Managers ##

For swarm to be highly available (i.e. survive the loss of the leader node), one needs to add manager nodes. Default manager nodes are docker-01, docker-02, and docker-03.
You can change them using the SWARM_MANAGERS environment variable, e.g. `SWARM=ON NODES=8 SWARM_MANAGERS=docker-1,docker-3,docker-5 vagrant provision`.

## Destroying cluster ##

Simply issue a `vagrant destroy && rm etcd_token_url` on each Vagrant host.

etcd token must be re-created for a new cluster, that's why the *etcd_token_url* file has to be deleted.

## Docker remote access ##

If you have the docker client installed, you can control Docker of ocker-01 VM from the host machine.
To do so:
```
export DOCKER_PORT=2375
vagrant up docker-01

export DOCKER_HOST=192.168.2.100:2375 # to tell your docker client how to connect (192.168.2.100 is the private IP of your machine)
docker info | grep ^Name\\s*:\\s* # to test whether the docker client actually connects docker-01
```

## Configuration ##

Many parameters can be adjusted by environment variable when issuing `vagrant up` commands.
Boolean variables can be set up using 0, no , off, false to state false, or any other value for true.

| Name                | Decription                                                                                                                           | Default             |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |:-------------------:|
| PREFIX              | The name of the VMs to set up (VMs will be named $PREFIX01, $PREFIX02, ... up to $PREFIX$NODES)                                      | docker-             |
| NODES               | The number of nodes (VM) to set up (VMs are named from $PREFIX01 to $PREFIX$NODES). Must be set equal or above ETCD_SIZE             | 3                   |
| ETCD_TOKEN_URL      | The etcd discovery URL or the file ; overrides any content in file `etcd_token_url`                                                  | On                  |
| ETCD_SIZE           | The number of etcd members (less nodes: etcd waits for new member, more nodes: only available as backup nodes)                       | 3                   |
| SWARM               | Whether to enable docker swarm mode ; etcd must be up and running before using this                                                  | Off                 |
| SWARM_MANAGERS      | Coma-separated list of docker swarm managers ; first node ($PREFIX01) will always be a manager regardless of this setting            | $PREFIX02,$PREFIX03 |
| COREOS              | The kind of ContainerOS to launch: stable, alpha, or beta                                                                            | alpha               |
| ITF                 | The default host network interface to bridge to (to avoid vagrant prompt)                                                            |                     |
| MEM                 | Memory to be allocated per VM (in mB)                                                                                                | 2048                |
| CPU                 | Number of CPUs to be used per VM                                                                                                     | 1                   |
| PRIVATE             | Whether to set up a private network interface for VMs (so that they can interact with each other)                                    | On                  |
| MASTER_IP           | In case PRIVATE is true, the private IP for $PREFIX01 ; private IP for other nodes is obtained by incrementing this IP               | 192.168.2.100       |
| PUBLIC              | Whether to set up a DHCP network interface for VMs (so that they can interact with each other across hosts)                          | On                  |
| INTERNAL_ITF        | Through which network interface etcd should communicate with other member (depends on $PUBLIC and $PRIVATE)                          | public *or* private |
| IPV6                | Whether to activate IPv6                                                                                                             | Off                 |
| DOCKER_PORT         | The Docker port for node $PREFIX01 ; a docker client can control Docker (swarm) using this port of $PREFIX01                         | 2375                |
| DOCKER_EXPERMIENTAL | Whether to enable docker experimental features                                                                                       | Off                 |
| COMPOSE             | Whether to install docker-compose on $PREFIX01 or which version to install                                                           | On                  |
| NANO                | Whether to install nano                                                                                                              | On                  |
| DOCKER_EXPERMIENTAL | Whether to enable docker experimental features                                                                                       | Off                 |
