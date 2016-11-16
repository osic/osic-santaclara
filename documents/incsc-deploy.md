# OSIC Santa Clara for INCSC

Please see the main README file for overall information about the Santa Clara environment.  This document is specific to the incsc build within that environment.



## Set up your local environment

### Set up your ssh config

Copy the santa clara private key over to your home directory ~/.ssh/santa
We are behind bastion servers and have to use a proxy command.  If you are not, you 
can hit the jump box directly and remove the ProxyCommand line.


```
vi ~/.ssh/config
```

``` 
Host 8.44.40.43 jumpbox1
    IdentityFile ~/.ssh/jump_rsa_key
    User root
    Port <jumpport>
    ProxyCommand ssh -p 22 -l bastionuser bastion.server.address nc -w120 %h %p

Host 8.44.40.67 jumpbox2
    IdentityFile ~/.ssh/jump_rsa_key
    User root
    Port <jumpport>
    ProxyCommand ssh -p 22 -l bastionuser bastion.server.address nc -w120 %h %p
```



## Setting up Cobbler for Onmetal Deploy


### Log into the cobbler deploy server and clone this repo

You can do this by hitting one of the jumpboxes and sshing into the 'cobbler' box.  Once you are there, you will want to attach
to the existing osic_deploy box.

```
ssh cobbler
lxc-attach -n osic-prep
git clone https://github.com/osic/osic-santaclara /opt/osic-santaclara-incsc
cd /opt/osic-santaclara-incsc/
```


### Set up the distro, profile and preseed files(if needed)

This only needs done once and has probably already in place.  Just in case I have posted a link to the steps below.

  - [Cobbler distro, profile and preseed file config](setup-cobbler-repo.md)



### Export the spreadsheet as a CSV.

For Santa Clara, a spreadsheet is being maintained that contains the mac, ip address and environment info. The mappings on what each server
is set up for is in this as well. The scripts in the next sections take this info and create cobbler commands and a host file.   

This is currently found at:

https://docs.google.com/spreadsheets/d/1jJ1z-La67j8dqZMFFDU8iGj55rRf4K1KJxhixYplk5o/edit#gid=138734026

You will want to export this as a CSV formated file for later use.  I have placed it under /opt/osic-santaclara-incsc/inventory.cvs on the osic-prep container.  


### Create the cobbler system configs


We have a script set up for creating the cobbler configs for the incsc devices.

```
./scripts/inv2cobbler_incsc.sh inventory.csv > scripts/cobbler_incsc_create.sh
chmod u+x scripts/cobbler_incsc_create.sh

vi scripts/cobbler_incsc_create.sh  # Verify that these are the commands you want to run

./scripts/cobbler_incsc_create.sh

cobbler sync
```


### Make last minute changes to the seed files if needed


Check to make sure vlan and ifenslave are installed.  If not, the network config will fail. Edit as needed.

```
grep vlan /opt/osic-preseeds/ubuntu-server-14.04-unattended-cobbler-osic-generic.seed 
d-i pkgsel/include string vim vlan ifenslave bridge-utils

grep vlan /opt/osic-preseeds/ubuntu-server-14.04-unattended-cobbler-osic-swift.seed 
d-i pkgsel/include string vim vlan ifenslave bridge-utils

grep vlan /opt/osic-preseeds/ubuntu-server-14.04-unattended-cobbler-osic-cinder.seed 
d-i pkgsel/include string vim vlan ifenslave bridge-utils
```



## PXE Booting

View which systems need a pxe boot. The netboot-enabled will be set to false on a good pxe boot on the cobbler server.

```
cobbler system find --netboot-enabled=true
```




### Set up a socks proxy and log into the Santa Clara horizon instance.


You can set up an ssh tunnel as a socks proxy to allow all requests from firefox.

```
ssh 8.44.40.67 -D 9999 -N
```

  - In firefox you can 'Edit' -> 'Preferences' -> 'Advanced' -> 'Network' -> 'Settings'
  - Then for the SOCKS Host use 'localhost' and port '9999'
  - Browse to http://cloud-api.sc.sdi-infra.org and use the provided credentials
  - Log into the console on each and issue a reboot.  The PXE process should start right away.
  - Monitor the reboots, as some changes may be needed if the system does not pick up the dhcp config.


If you have issues with the horizon interface, you have to stop/start the server via the cli on one of the jump boxes.

```
. openrc
. /opt/rally/bin/activate
nova list
nova stop <server name or uuid>
nova start <server name or uuid>
nova show <server name or uuid>
```



### Prep ansible and run a prep playbook

This playbook does some standard tasks like setting up ssh configs, network configuration
and removing some unneeded lvm volumes.

#### Set up the ansible hosts file

```
./scripts/inv2hosts_incsc.sh ./inventory.csv  > inventory/incsc_hosts
ansible -i inventory/incsc_hosts compute -m shell -a 'uptime' --ask-pass
```

Fix any that can't be contacted



#### Set up the variables needed to configure networking.

```
vi vars/vlan_network_mapping_incsc.yml
```
```
# 202 - MANAGEMENT_NET - 172.22.84.0/22
# 203 - STORAGE_NET    - 172.22.92.0/22
# 204 - OVERLAY_NET    - 172.22.88.0/22
# 205 - FLAT_NET       - 172.22.96.0/22
pxe_network: 172.22.0.0/22

management_vlan: 202
management_network: 172.22.84.0/22
storage_vlan: 203
storage_network: 172.22.92.0/22 
overlay_vlan: 204
overlay_network: 172.22.88.0/22
flat_vlan: 205
flat_network: 172.22.96.0/22
```


#### Run the prep script

```
ansible-playbook -i inventory/incsc_hosts prep_incsc_devices.yml --limit 'all:!deploy' -f 30 --ask-pass --list-hosts 
ansible-playbook -i inventory/incsc_hosts prep_incsc_devices.yml --limit 'all:!deploy' -f 30 --ask-pass
```


#### Access Issues

You may be having issues during the installs.  You can just set up the ssh portion of things and skip the rest with the following command
```
ansible-playbook -i inventory/incsc_hosts prep_incsc_devices.yml --limit 'all:!deploy' --tags sshonly --askpass -f 30

```


## Add virtual ip addresses for deploy/osic-prep connectivity

The incsc networks are unknown by the deploy device and any containers within.  To fix this we will use the '.22' for the last octet on each 
incsc network and assign it to the deployment host.

```

# Looks like we really only need the br-mgmt set up for the deployment
ip address add 172.22.84.22/22 dev br-mgmt label br-mgmt:incsc

#ip address add 172.22.92.22/22 dev br-storage label br-storage:incsc
#ip address add 172.22.88.22/22 dev br-vxlan label br-vxlan:incsc
#ip address add 172.22.96.22/22 dev br-flat label br-flat:incsc
```


## Configure Openstack and Services

The following is where things start to change based on the build. Each type of build will involve making changes to the spreadsheet before
running this document. After changing the spreadsheet and running this doc, the following builds notes will help set up openstack.

  - [Openstack-Ansible Deployment Architecture B (Ceph Backed Volumes)](incsc-deploy-b-ceph-steps.md)
    - 1 existing deployment node
    - 3 ceph nodes
    - 3 swift nodes
    - 1 loggin node
    - 1 network node
    - 3 control nodes
    - 5 computes

  - [Openstack-Ansible Deployment Architecture B (LVM Backed Volumes)](incsc-deploy-b-lvm-steps.md)
    - 1 existing deployment node
    - 3 cinder nodes
    - 3 swift nodes
    - 1 loggin node
    - 1 network node
    - 3 control nodes
    - 22 computes


## Configure Services and Test Functionality

  - [Run some basic setup commands and tests](build-services.md)
