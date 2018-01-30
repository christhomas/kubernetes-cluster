#!/bin/sh
docker-compose stop
docker-compose up -d

resolve_conf=/etc/resolvconf/resolv.conf.d/head
container_name="jpillora/dnsmasq:latest"
container_id=$(docker ps | grep $container_name | awk '{ print $1 }')
ipaddress=$(docker inspect -f '{{ range .NetworkSettings.Networks }}{{ .IPAddress }}{{ end }}' $container_id)

echo "Updating DNS Resolver to use container id '$container_id' with ip address '$ipaddress'"
echo "Note: If you are asked for your password, it means your sudo password"

# I wanted to use a variable here, but the special characters defeated me :(
sudo sed -i "/\# CONTAINER\:jpillora\/dnsmasq\:latest/d" $resolve_conf

echo "nameserver $ipaddress # CONTAINER:$container_name ip address" | sudo tee -a $resolve_conf
sudo resolvconf -u

# we need to sleep for a second in order that the dns is updated
sleep 1
echo "Testing DNS Resolution with a test domain 'test-dns.local.env'"
ping -c1 -W 1 test-dns.local.env