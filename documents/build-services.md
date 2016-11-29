# Overview

We are following the general steps from the following script and making any changes as needed.

https://github.com/openstack/openstack-ansible-ops/blob/master/multi-node-aio/openstack-service-setup.sh#L7-L43


## Log into the utility container on infra01 and make sure you can get a token

```
grep infra01 inventory/incsc_hosts 
infra01 ansible_ssh_host=172.22.0.23 ironic_ip=10.3.72.99

ssh 172.22.0.23

lxc-ls -f | grep utility
infra01_utility_container-7b766dde             RUNNING 1         onboot, openstack 10.0.3.86, 172.22.84.244                -  

lxc-attach -n infra01_utility_container-7b766dde



. /root/openrc 
openstack token issue

```


## Set up flavors

```
for flavor in micro tiny mini small medium large xlarge heavy; do
  NAME="m1.${flavor}"
  ID="${ID:-0}"
  RAM="${RAM:-256}"
  DISK="${DISK:-1}"
  VCPU="${VCPU:-1}"
  SWAP="${SWAP:-0}"
  EPHEMERAL="${EPHEMERAL:-0}"
  nova flavor-delete $ID > /dev/null || echo "No Flavor with ID: [ $ID ] found to clean up"
  nova flavor-create $NAME $ID $RAM $DISK $VCPU --swap $SWAP --is-public true --ephemeral $EPHEMERAL --rxtx-factor 1
  let ID=ID+1
  let RAM=RAM*2
  if [ "$ID" -gt 5 ];then
    let VCPU=VCPU*2
    let DISK=DISK*2
    let EPHEMERAL=256
    let SWAP=4
  elif [ "$ID" -gt 4 ];then
    let VCPU=VCPU*2
    let DISK=DISK*4+$DISK
    let EPHEMERAL=$DISK/2
    let SWAP=4
  elif [ "$ID" -gt 3 ];then
    let VCPU=VCPU*2
    let DISK=DISK*4+$DISK
    let EPHEMERAL=$DISK/3
    let SWAP=4
  elif [ "$ID" -gt 2 ];then
    let VCPU=VCPU+$VCPU/2
    let DISK=DISK*4
    let EPHEMERAL=$DISK/3
    let SWAP=4
  elif [ "$ID" -gt 1 ];then
    let VCPU=VCPU+1
    let DISK=DISK*2+$DISK
  fi
done
```

## Set up images

```
wget http://uec-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
glance image-create --name 'Ubuntu 14.04 LTS' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file ubuntu-14.04-server-cloudimg-amd64-disk1.img
rm ubuntu-14.04-server-cloudimg-amd64-disk1.img

wget http://uec-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
glance image-create --name 'Ubuntu 16.04' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file ubuntu-16.04-server-cloudimg-amd64-disk1.img
rm ubuntu-16.04-server-cloudimg-amd64-disk1.img

wget http://dfw.mirror.rackspace.com/fedora/releases/24/CloudImages/x86_64/images/Fedora-Cloud-Base-24-1.2.x86_64.qcow2
glance image-create --name 'Fedora 24' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file Fedora-Cloud-Base-24-1.2.x86_64.qcow2
rm Fedora-Cloud-Base-24-1.2.x86_64.qcow2

wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
glance image-create --name 'CentOS 7' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file CentOS-7-x86_64-GenericCloud.qcow2
rm CentOS-7-x86_64-GenericCloud.qcow2

wget http://download.opensuse.org/repositories/Cloud:/Images:/Leap_42.1/images/openSUSE-Leap-42.1-OpenStack.x86_64-0.0.4-Build2.12.qcow2
glance image-create --name 'OpenSuse Leap 42' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file openSUSE-Leap-42.1-OpenStack.x86_64-0.0.4-Build2.12.qcow2
rm openSUSE-Leap-42.1-OpenStack.x86_64-0.0.4-Build2.12.qcow2

wget http://cdimage.debian.org/cdimage/openstack/current/debian-8.6.0-openstack-amd64.qcow2
glance image-create --name 'Debian 8.6.0' \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file debian-8.6.0-openstack-amd64.qcow2
rm debian-8.6.0-openstack-amd64.qcow2

wget http://cdimage.debian.org/cdimage/openstack/testing/debian-testing-openstack-amd64.qcow2
glance image-create --name "Debian TESTING $(date +%m-%d-%y)" \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file debian-testing-openstack-amd64.qcow2
rm debian-testing-openstack-amd64.qcow2

wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
glance image-create --name "Cirros-0.3.4" \
                    --container-format bare \
                    --disk-format qcow2 \
                    --visibility public \
                    --progress \
                    --file cirros-0.3.4-x86_64-disk.img
rm cirros-0.3.4-x86_64-disk.img
```


## Set up networking

### Set up the public network and private networks
```
neutron net-create PublicNet --router:external=True --provider:physical_network=flat --provider:network_type=flat
neutron subnet-create PublicNet --name PublicSubnet 172.22.96.0/22 --gateway 172.22.96.1 --allocation-pool start=172.22.96.201,end=172.22.96.255 --dne-nameservers list=true 8.8.8.8 8.8.4.4
neutron net-create PrivateNet --shared --provider:network_type=vxlan --provider:segmentation_id 101
neutron subnet-create PrivateNet --name PrivateSubnet 192.168.0.0/24
```

### Allow everything through the default security group for testing
```
for id in $(neutron security-group-list -f yaml | awk '/- id\:/ {print $3}'); do
    # Allow ICMP
    neutron security-group-rule-create --protocol icmp \
                                       --direction ingress \
                                       $id || true
    # Allow all TCP
    neutron security-group-rule-create --protocol tcp \
                                       --port-range-min 1 \
                                       --port-range-max 65535 \
                                       --direction ingress \
                                       $id || true
    # Allow all UDP
    neutron security-group-rule-create --protocol udp \
                                       --port-range-min 1 \
                                       --port-range-max 65535 -\
                                       -direction ingress \
                                       $id || true
done
```

### Set up a router for the admin tenant
```
neutron router-create admin_router (note id)
neutron net-list (note PubicNet id and Private Subnet id)
neutron router-gateway-set <routerid> <publicnetid>
neutron router-interface-add <routerid> <private subnet id>

```


### Create a server with a floating ip and connect to it

```
ssh-keygen (enter through)
nova keypair-add --pub-key /root/.ssh/id_rsa.pub infra01-utility-root

nova flavor-list
neutron net-list
glance image-list

nova boot --flavor 3 --image <fedora image id> --key-name infra01-utility-root --nic net-id=<privatenetid> test02
nova show test02

neutron net-list
neutron floatingip-create <publicnet id>
neutron floatingip-list

neutron port-list | grep <test02 private ip>
neutron floatingip-associate <floating ip id> <port id>

ping <floating_ip>
ssh <floating_ip> -l fedora
```


## Set up haproxy to allow connectivity to the 172.0.22.23 address for horizon


```
grep infra01 inventory/incsc_hosts 
infra01 ansible_ssh_host=172.22.0.23 ironic_ip=10.3.72.99

ssh 172.22.0.23


vi /etc/haproxy/haproxy.cfg


...
# add the following
frontend horizon-front-3
    bind 172.22.0.23:443 ssl crt /etc/ssl/private/haproxy.pem ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
    option httplog
    option forwardfor except 127.0.0.0/8
    option http-server-close
    reqadd X-Forwarded-Proto:\ https
    mode http
    default_backend horizon-back

frontend horizon-redirect-front-3
bind 172.22.0.23:80
    mode http
    redirect scheme https if !{ ssl_fc }
...



service haproxy restart
```





## Connect to the horizon interface and check things out

Set up an ssh proxy.  We have many ways to do this.  I have already set up my ssh config to proxy through the db.  This will open up a socks proxy of which we have firefox
configured to use.
```
# From workstation
ssh 8.44.40.67 -D 9999 -N

```

Open up the browser on the workstation and set the socks proxy to locatlhost:9999. Once complete go to the following

  - https://172.22.0.23

Get the credentials from the utility container connected to earlier.

```
awk '/OS_(USERNAME|PASSWORD)/' /root/openrc 

```

Log in and test things out.


