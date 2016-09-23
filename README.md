# OSIC Santa Clara

This document details the installation tasks for the Santa Clara environment.

## IMPORTANT: Kernel update

IMPORTANT:
A problem with the 3.19.0-2x kernel that ships with the 14.04.3 amd64 is that it does not reliably add default route based on /etc/network/interfaces
http://serverfault.com/questions/748306/ifup-default-route-missing

Follow these commands to update the kernel:

### Prepare interfaces for Internet access

1. Create interfaces

Create interfaces on all nodes

    cd /opt/osic-ref-impl/playbooks
    # create interfaces w playbook (skip deploy)
    ansible-playbook -vv -i inventory/hosts.hasvcs create-network-interfaces.yml --ask-pass --limit '!deploy'

2. Setup Internet access w route and nameserver
    
Add route
    
    # add temporary route
    # example: ip route add default via 10.3.72.1 dev bond0.200
    ansible -i inventory/hosts.hasvcs all -m shell -a "ip route del default; ip route add default via 10.3.72.1 dev bond0.200" --ask-pass --limit '!deploy'

Add nameserver 

    # add resolv.conf value
    ansible -i inventory/hosts.hasvcs all -m shell -a "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf" --ask-pass --limit '!deploy'

Test connectivity

    # verify internet connectivity on target systems
    ansible -i inventory/hosts.hasvcs all -m shell -a "ping -c2 google.com" --ask-pass --limit '!deploy'

### Update kernel

Verify Internet connectivity by having all target systems ping an external host.  
If any fail, resolve before proceeding to next step.

    

Update system package indexes:
  
    # apt-get update on target systems
    ansible -i inventory/hosts.hasvcs all -m shell -a "apt-get update" --ask-pass --limit '!deploy'
 

Update the kernel:

    # udpate kernel of target systems with ansible
    ansible -i inventory/hosts.hasvcs all -m shell -a "apt-get install -y linux-generic-lts-xenial" --ask-pass --limit '!deploy'
 
Reboot
 
    # reboot
    ansible -i inventory/hosts.hasvcs all -m shell -a "reboot" --ask-pass --limit '!deploy'
  
 
    
    
    
## Interfaces

The SC cluster is comprised of Dell and Lenovo servers. The default NIC is different for each machine type and configuration files (e.g. input.csv) must account for different network interface names.

The following list shows the bonded interface to be used for each machine type.

  * Dell - em1
  * Lenovo - p2p1

The above interfaces must be entered into the input.csv during installation.

	# example lines showing different interfaces (em1 and p2p1)
	...
	qa-ci-cinder03,f0:bc:12:07:05:b0,172.22.0.34,255.255.252.0,172.22.0.1,8.8.8.8,em1,ubuntu-14.04.3-server-unattended-osic-generic
	qa-ci-swift01,f0:bc:12:07:1d:30,172.22.0.35,255.255.252.0,172.22.0.1,8.8.8.8,p2p1,ubuntu-14.04.3-server-unattended-osic-generic
	...

## Pre-installation items

### Edit seed

In osic-prep container, edit the seed (likely /opt/osic-prep/ubuntu-server-14.04-unattended-cobbler-osic-generic.seed) and make the following changes:

#### Extra packages

Add the following packages (vlan, ifenslave)

	#############
	#
	# Packages
	#
	#############

	...

	d-i pkgsel/include string vlan ifenslave

#### RAID

RAID setup must be disabled for SC. Comment out the line below if it exists.

	#############
	#
	# Partitioning
	#
	#############

	#d-i partman/early_command string \
	#      wget --no-check-certificate https://raw.githubusercontent.com/osic/osic-raid-scripts/master/create_raid_generic.sh -O /tmp/create_raid_generic.sh; \
	#      /bin/sh /tmp/create_raid_generic.sh

### Console in kernel options

To use Horizon's console to control each server, we must provide additional kernel options for each system profile in cobbler. You can manually update each system or use the update_cobbler_system.py and a kopts.txt file to set the console paramters.

#### Manually update cobbler profiles

	# Manually update a system profile to use serial console
	cobbler system edit --name=compute09 --kopts="interface=p2p1 console=tty0 console=ttyS0,115200n8"

#### Use update_cobbler_profile.py

	# use script and file containing <nodename>,<kopts>
	lxc-attach -n osic-prep
	cd rpc-prep-scripts
	python update_cobbler_system.py kopts.txt


### Extra NICs

TBD


# Ceph

    # clone repo
    git clone http://github.com/ceph/ceph-ansible
