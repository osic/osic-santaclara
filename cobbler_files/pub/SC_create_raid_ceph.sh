#!/bin/bash


# Remove any existing virtual drives
for DRIVE in $(megacli -LDInfo -Lall -aALL | egrep '^Virtual Drive' | cut -d" " -f 6 | sed -e 's/)//g')
do
  echo "Running: megacli -CfgLdDel -L${DRIVE} -a0"
  megacli -CfgLdDel -L${DRIVE} -a0
done


# Clear any mapped devices
/sbin/dmsetup remove_all --force
/sbin/dmsetup status


# Set up slots 0 and 1 as a raid1. This will be virtual drive 0
echo "Running: megacli -CfgLdAdd -r1 [0:0, 0:1]  WB RA Cached NoCachedBadBBU -a0"
megacli -CfgLdAdd -r1 [0:0, 0:1]  WB RA Cached NoCachedBadBBU -a0


# Set up physical disks for slot 2 and above as a singe drive raid0
for SLOT in $(megacli -PDList -aAll | egrep '^Slot Number' | grep -v 'Slot Number: [01]$' | cut -d" " -f 3)
do
    echo "Running: megacli -CfgLdAdd -r0 [0:${SLOT}] -a0"
    megacli -CfgLdAdd -r0 [0:${SLOT}] -a0
done

