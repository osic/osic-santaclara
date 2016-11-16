# Overview


  - Openstack-Ansible Deployment Architecture B
    - 1 existing deployment node
    - 3 cinder nodes
    - 3 swift nodes
    - 1 loggin node
    - 1 network node
    - 3 control nodes
    - 22 computes



  - Network Info:
    - Cobbler(PXE) Network:       172.22.0.0/22  (untagged)
    - Ironic Management Network:  10.3.72.0/21   (vlan 200)
    - Container Management:       172.22.84.0/22 (vlan 202)
    - Storage Network:            172.22.92.0/22 (vlan 203) 
    - VXLAN(Overlay) Network:     172.22.88.0/22 (vlan 204)
    - Flat Network:               172.22.96.0/22  (vlan 205)




---

## Prepare Deployment Host

Get out of the osic-prep container and drop into the deployment server hosting it
The remaining steps are happening on the deploy server


### Make your previous work available by linking osic-santaclara to /opt

```
ln -s /usr/local/var/lib/lxc/osic-prep/rootfs/opt/osic-santaclara-incsc /opt/
```


### Add the deployment host
```
vi /opt/osic-santaclara-incsc/inventory/incsc_hosts

  [deploy]

  osscr01r01c14-deploy ansible_ssh_host=172.22.0.21
```


### Copy the fingerprints over from the prep container
```
cp /usr/local/var/lib/lxc/osic-prep/rootfs/root/.ssh/known_hosts /root/.ssh/known_hosts
```


### Start a tmux session to run needed playbooks

```
tmux new -s incsc_prep

cd /opt/osic-ref-impl/playbooks/
```






---
## Set up the storage 

We will need to configure storage for the ceph, cinder and swift servers.  

  - They may already configured from previous builds and go from /dev/sdc to /dev/sdl.
  - One of the cinder nodes in the SC environment has a bad hard drive, so you will need to work around it.
  - Swift has a setup of using /dev/sdc -> /dev/sdl in individual raid0 virtual disks with no partitions.
  - Ceph has a setup of using /dev/sdc -> /dev/sdl in inndividual raid0 virtual disks with no partition.
  - Cinder with lvm reference backend needs some redundancy. So I'm going with /dev/sdc -> /dev/sdl in a raid 10 for now.




### Configure drives as needed

Use megacli commands to set up /dev/sdc-/dev/sdl disks if needed.  They are all built as a raid0 with no paritions to start out with. 
If partitions exist, remove them for the new build. At this point, we shouldn't have to worry about them being mounted or in the fstab as we
just rekicked the devices.

  - Official guide for megacli: http://www.cisco.com/c/dam/en/us/td/docs/unified_computing/ucs/3rd-party/lsi/mrsas/userguide/LSI_MR_SAS_SW_UG.pdf
  - You can find plenty of info on the command usage online: ex: http://erikimh.com/megacli-cheatsheet/





#### Some useful commands for the storage setup


```
# Show condensed physical disk info
megacli -PDList -aAll | awk '/^(Enclosure D|Slot|Drive.*pos|Device Id|Raw)/' | sed -e 's/\(^Enclosure.*$\)/\n\1/g'  

# Show virtual disk info
megacli -LDInfo -Lall -aALL

# Look at your existing disk config.
fdisk -l 2>/dev/null | awk '/^Disk/ && /sd[a-z].*/'

# Pull physical disk info
megacli -PDList -aAll | awk '/^(Enclosure D|Slot|Drive.*pos|Device Id|Raw|Firm)/' | sed -e 's/\(^Enclosure.*$\)/\n\1/g'

# Remove virtual disk if needed. This deletes virtual disk in slot 11
megacli -CfgLdDel -L11 -a0

# Set up individual device in a raid 0.  In this example we are setting up enclosure 0 and disks in slot 8 with raid0 virtual disks.
megacli -CfgLdAdd -r0 [0:8] -a0

# Set up a raid 10
megacli -CfgSpanAdd -r10 -Array0 [0:2, 0:3] -Array1 [0:4, 0:5] -Array2 [0:6, 0:7] -Array3 [0:8, 0:9] -Array4 [0:10, 0:11] WB RA Cached NoCachedBadBBU -a0

# view the results
megacli -LDInfo -Lall -aALL

# Check the hardware log
megacli -adpeventlog -getevents -f lsi-events.log -a0 -nolog
less lsi-events.log
```




---
## Prepare the disks for deployment

```
cd /opt/osic-santaclara-incsc


# (prepped in 10 single raid0 virtual disks)
vi vars/swift-disks.yml

disks:
  - sdc
  - sdd
  - sde
  - sdf
  - sdg
  - sdh
  - sdi
  - sdj
  - sdk
#  - sdl (removed as sc is down a drive)



# (prepped with a single large raid10 set up in a cinder-volumes LVM volume group)
vi vars/cinder-disks.yml
disks:
  - sdc


ansible-playbook -i inventory/incsc_hosts prep_incsc_disks.yml -e 'forceformat=yes' --limit 'swift:cinder' -f 6
```





---
## Install and configure Openstack-ansible


### set up the deploy box for openstack-ansible

This should already be in place on the santa clara deploy box

```
# if not already set up clone openstack-ansible
git clone https://git.openstack.org/openstack/openstack-ansible /opt/openstack-ansible
cd /opt/openstack-ansible/

git checkout stable/newton
git describe --abbrev=0 --tags
git checkout 14.0.1

scripts/bootstrap-ansible.sh 
```



### Set up the openstack_deploy dir

May need to move some things around if other project are using this deploy box. I have move the origional one
to /etc/openstack_deploy_orig and have been setting up new directories for each env and sym-linking
/etc/openstack_deploy to it.
```
cd /opt
git clone https://github.com/osic/ref-impl.git


cp -rf /opt/osic-ref-impl/openstack_deploy /etc/openstack_deploy_incsc_b
rm /etc/openstack_deploy
ln -s /etc/openstack_deploy_incsc_b /etc/openstack_deploy 
```


```
vi /etc/openstack_deploy/openstack_user_config.yml
```

```
# start openstack_user_config.yml changes #
cidr_networks:
  container: 172.22.84.0/22
  tunnel: 172.22.88.0/22
  storage: 172.22.92.0/22

used_ips:
  - "172.22.84.0,172.22.84.200"
  - "172.22.92.0,172.22.92.200"
  - "172.22.88.0,172.22.88.200"
  - "172.22.96.0,172.22.96.200"

  internal_lb_vip_address: "172.22.84.23"
  external_lb_vip_address: "172.22.96.23"

global_overrides:
  internal_lb_vip_address: "172.22.84.23"
  external_lb_vip_address: "172.22.96.23"

...
        # Change range: "839:849" to
        # went with the same pattern used for the ref-impl above the 200-205 vlan range uses. 
        # may need to change this later as we have a lack of info on these settings.
        range: "301:311"
...
```




```
vi /etc/openstack_deploy/conf.d/compute.yml
```

```
---
compute_hosts:
  compute01:
    ip: 172.22.84.28
  compute02:
    ip: 172.22.84.29
  compute03:
    ip: 172.22.84.30
  compute04:
    ip: 172.22.84.31
  compute05:
    ip: 172.22.84.32
  compute06:
    ip: 172.22.84.33
  compute07:
    ip: 172.22.84.34
  compute08:
    ip: 172.22.84.35
  compute09:
    ip: 172.22.84.36
  compute10:
    ip: 172.22.84.37
  compute11:
    ip: 172.22.84.38
  compute12:
    ip: 172.22.84.39
  compute13:
    ip: 172.22.84.40
  compute14:
    ip: 172.22.84.41
  compute15:
    ip: 172.22.84.42
  compute16:
    ip: 172.22.84.43
  compute17:
    ip: 172.22.84.44
  compute18:
    ip: 172.22.84.45
  compute19:
    ip: 172.22.84.46
  compute20:
    ip: 172.22.84.47
  compute21:
    ip: 172.22.84.48
  compute22:
    ip: 172.22.84.49


```


```
vi /etc/openstack_deploy/conf.d/infra.yml
```

```
---
shared-infra_hosts:
  infra01:
    ip: 172.22.84.23
  infra02:
    ip: 172.22.84.24
  infra03:
    ip: 172.22.84.25

os-infra_hosts:
  infra01:
    ip: 172.22.84.23
  infra02:
    ip: 172.22.84.24
  infra03:
    ip: 172.22.84.25

storage-infra_hosts:
  infra01:
    ip: 172.22.84.23
  infra02:
    ip: 172.22.84.24
  infra03:
    ip: 172.22.84.25

repo-infra_hosts:
  infra01:
    ip: 172.22.84.23
  infra02:
    ip: 172.22.84.24
  infra03:
    ip: 172.22.84.25

identity_hosts:
  infra01:
    ip: 172.22.84.23
  infra02:
    ip: 172.22.84.24
  infra03:
    ip: 172.22.84.25

```



```
vi /etc/openstack_deploy/conf.d/loadbalancer.yml
```

```
---
haproxy_hosts:
  infra01:
    ip: 172.22.84.23
```




```
vi /etc/openstack_deploy/conf.d/logging.yml
```

```
---
log_hosts:
  logging01:
    ip: 172.22.84.27
```



```
vi /etc/openstack_deploy/conf.d/network.yml
```

```
---
network_hosts:
  network01:
    ip: 172.22.84.26
```


```
vi /etc/openstack_deploy/conf.d/swift.yml
```

```
global_overrides:
  swift:
    part_power: 8
    storage_network: 'br-storage'
    replication_network: 'br-storage'
    drives:
      - name: sdc
      - name: sdd
      - name: sde
      - name: sdf
      - name: sdg
      - name: sdh
      - name: sdi
      - name: sdj
      - name: sdk
    mount_point: /srv/node
    storage_policies:
      - policy:
          name: default
          index: 0
          default: True

swift-proxy_hosts:
  infra01:
    ip: 172.22.84.23
    container_vars:
      swift_proxy_vars:
        read_affinity: "r1=100"
        write_affinity: "r1"
        write_affinity_node_count: "2 * replicas"
  infra02:
    ip: 172.22.84.24
    container_vars:
      swift_proxy_vars:
        read_affinity: "r2=100"
        write_affinity: "r2"
        write_affinity_node_count: "2 * replicas"
  infra03:
    ip: 172.22.84.25
    container_vars:
      swift_proxy_vars:
        read_affinity: "r3=100"
        write_affinity: "r3"
        write_affinity_node_count: "2 * replicas"

swift_hosts:
  swift01:
    ip: 172.22.84.143
    container_vars:
      swift_vars:
        limit_container_types: swift
        zone: 0
        region: 1
  swift02:
    ip: 172.22.84.141
    container_vars:
      swift_vars:
        limit_container_types: swift
        zone: 0
        region: 1
  swift03:
    ip: 172.22.84.142
    container_vars:
      swift_vars:
        limit_container_types: swift
        zone: 0
        region: 1

```

```
vi /etc/openstack_deploy/conf.d/storage.yml
```

```
storage_hosts:
  cinder01:
    ip: 172.22.84.156
    container_vars:
      cinder_storage_availability_zone: cinderAZ_1
      cinder_default_availability_zone: cinderAZ_1
      cinder_backends:
        lvm:
          volume_backend_name: LVM_iSCSI
          volume_driver: cinder.volume.drivers.lvm.LVMVolumeDriver
          volume_group: cinder-volumes
          iscsi_ip_address: 172.22.92.156
        limit_container_types: cinder_volume
  cinder02:
    ip: 172.22.84.155
    container_vars:
      cinder_storage_availability_zone: cinderAZ_1
      cinder_default_availability_zone: cinderAZ_1
      cinder_backends:
        lvm:
          volume_backend_name: LVM_iSCSI
          volume_driver: cinder.volume.drivers.lvm.LVMVolumeDriver
          volume_group: cinder-volumes
          iscsi_ip_address: 172.22.92.155
        limit_container_types: cinder_volume
  cinder03:
    ip: 172.22.84.140
    container_vars:
      cinder_storage_availability_zone: cinderAZ_1
      cinder_default_availability_zone: cinderAZ_1
      cinder_backends:
        lvm:
          volume_backend_name: LVM_iSCSI
          volume_driver: cinder.volume.drivers.lvm.LVMVolumeDriver
          volume_group: cinder-volumes
          iscsi_ip_address: 172.22.92.140
        limit_container_types: cinder_volume

```



---
## Install openstack


### gen passwords

```
python /opt/openstack-ansible/scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
```


### Set up openstack-ansible

```
tmux -a  (or set up a new session 'tmux new -s incsc_osa_install')

cd /opt/openstack-ansible/playbooks


openstack-ansible setup-hosts.yml -f 50 --list-hosts
openstack-ansible setup-hosts.yml -f 50

ansible -i ./inventory/dynamic_inventory.py all -m ping

openstack-ansible setup-infrastructure.yml -f 50 --list-hosts
openstack-ansible setup-infrastructure.yml -f 50


stdbuf -i0 -o0 -e0 openstack-ansible setup-openstack.yml -f 50 | tee setup-openstack.log
```

