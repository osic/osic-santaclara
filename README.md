# OSIC Santa Clara

This document details the installation tasks for the Santa Clara environment.

## About Santa Clara environment

### Interfaces

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



#### Extra NICs

TBD

### Lenovo BIOS boot device selection problem

BIOS on the Lenovo servers does not permit changing boot order but a woraround exists. To perform PXE boot, you must disable the RAID 
controller as a boot device, PXE boot and then re-enable the RAID controller as a boot device. The normal method does 
not work so we switch RAID to boot UEFI only and we maintain Boot Mode a Legacy Only. 



#### Disable RAID control to facilitate PXE boot

Follow these steps to disable RAID controller as boot device:

  * Reboot and press F1 repeatedly to enter BIOS setup
  * Press Right-Arrow 4 times to arrive at "Boot Manager" menu
  * Ensure "Boot Mode" is set to "Legacy Only"
  * Select "Miscellaneous Boot Settings" menu item
  * Select "Storage OpROM Policy" and change to "UEFI Only"
  * Press Esc to go back to top level Boot Manager menu
  * Press Right Arrow to arrive at "Save and Exit" menu
  * Select "Save Changes and Reset" to save and reboot
  * With the RAID device effectively disabled, system should PXE boot.

#### Enable RAID controller to boot from disk

Follow these steps to enable RAID controller as boot device:

  * Reboot and press F1 repeatedly to enter BIOS setup
  * Press Right-Arrow 4 times to arrive at "Boot Manager" menu
  * Ensure "Boot Mode" is set to "Legacy Only"
  * Select "Miscellaneous Boot Settings" menu item
  * Select "Storage OpROM Policy" and change to "Legacy Only"
  * Press Esc to go back to top level Boot Manager menu
  * Press Right Arrow to arrive at "Save and Exit" menu
  * Select "Save Changes and Reset" to save and reboot
  * With the RAID device effectively enabled, system should boot from internal disk.
  
### BIOS issues

All issues observed in Lenovo BIOS (PB1TS144 V1.44.0 15 Oct 2015):

  * Allows to change boot order but change is not persisted.  
  * "Boot Manager->Legacy Hard Disk Drives" does not save when RAID is disabled.
  * "Boot order" menu only allows choice of RAID or 1st Nic (slot 0200) 
  * "Adapters and UEFI Drivers" page is blank (could be conditional)
  * "Exclude boot device" page is blank
  * F10 prompts to exit without saving. should prompt to save and exit.
  * F11 Network boot menu never appears
  * F12 Boot menu never appears
  * LTDE (Lenovo ThinkServer Diagnostics Embeded) does not seem to work. (Black screen)

## Pre-installation items

To properly install in this environment we must complete these pre-installation tasks:

  * Edit seed file - Add packages and disable RAID formatting script.
  * Update cobbler systems to use serial console in kernel options
  * Copy the template for our interfaces file
  * Add ironic IP to hosts file
  

### Edit seed

In osic-prep container, edit the seed (likely /opt/osic-prep/ubuntu-server-14.04-unattended-cobbler-osic-generic.seed) and make the following changes:

    vi /opt/osic-prep/ubuntu-server-14.04-unattended-cobbler-osic-generic.seed
    
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

### Copy update_cobbler_settings

Copy the python script we will use to set console options on our cobbler systems

    # copy santa clara cobbler update script to rpc-prep-scripts in container
    lxc-attach --name osic-prep
    cp /opt/osic-santaclara/update_cobbler_sytem.py /var/lib/lxc/osic-prep/rootfs/root/rpc-prep-scripts

### Create kopts.txt

Create a file with one line for each system and the kernel options required for console

    # <node>,<kopts>
    infra01,interface=em1 console=tty0 console=ttyS0,115200n8
    infra02,interface=em1 console=tty0 console=ttyS0,115200n8
    ...

### Console in kernel options

To use Horizon's console to control each server, we must provide additional kernel options for each system profile in cobbler. You can manually update each system or use the update_cobbler_system.py and a kopts.txt file to set the console paramters.

#### Manually update cobbler systems

Manually update a system to use serial console

	# Manually update a system to use serial console
	cobbler system edit --name=compute09 --kopts="interface=p2p1 console=tty0 console=ttyS0,115200n8"

#### Use update_cobbler_settings.py

Use script and file containing <nodename>,<kopts>

	# use script and file containing <nodename>,<kopts>
	lxc-attach -n osic-prep
	cd rpc-prep-scripts
	python update_cobbler_settings.py kopts.txt

### Copy interface templates
    
    # copy santa clara interface templates. WARNING overrites existing templates
    cp /opt/osic-santaclara/templates/* /opt/osic-ref-impl/playbooks/templates

### Modify ansible hosts file

The ansible hosts file must be modified to include an extra parameter per server "ironic_ip"
 
Example:  

/opt/osic-ref-impl/playbooks/inventory/hosts.hasvcs

    [controller]
    hasvcs-infra01 ansible_ssh_host=172.22.0.41 ironic_ip=10.3.72.117
    hasvcs-infra02 ansible_ssh_host=172.22.0.42 ironic_ip=10.3.72.118
    ...
    
## PXE Boot

DO PXE BOOT HERE

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
    ansible-playbook -i inventory/hosts.hasvcs create-network-interfaces.yml --ask-pass --limit '!deploy'

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
  
 
## Bootstrap servers
    
    
    cd /root/osic-prep-ansible

    ansible-playbook -i inventory/hosts.hasvcs playbooks/bootstrap.yml --ask-pass --limit '!deploy'
    
    


# Keepalived  

The .22 address of container/mgmt_net needs to be assigned to keepalived

# Ceph

    # clone repo
    git clone http://github.com/ceph/ceph-ansible
