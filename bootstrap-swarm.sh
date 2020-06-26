#!/bin/sh
if [ -z "$1" ] ; then
	echo "Give number of nodes as parameter (ex. 3)"
	exit 1
fi

export NODES=$1
export ETCD_SIZE=$1

vagrant box update

UP=$( vagrant status | grep '^docker-' | grep running | wc -l | tr -d '[:space:]')
echo "$UP nodes found runnig"
if [ "0" == "$UP" -a -f ./etcd_token_url ] ; then
	echo "No machine running ; erasing current etcd token $(cat etcd_token_url)"
	rm ./etcd_token_url 2>/dev/null
elif [ "0" != "$UP" ] ; then
	echo "WARNING: $UP nodes found running. This scrpit is not battle-tested against existing clusters, use at your own risks (anyway)"
fi

echo "Setting up all $NODES machines"
vagrant up || exit 2
echo "Waiting for etcd to be availabble"
until vagrant ssh docker-01 -c 'etcdctl cluster-health' ; do
	sleep 1
done
echo "Setting up Docker Swarm"
SWARM=on vagrant up
