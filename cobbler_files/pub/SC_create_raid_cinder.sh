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


# Get information to set up a large raid 10 from the remaining drives
x=0
arrnum=0
R10COMMAND="megacli -CfgSpanAdd -r10 "
ARRLIST=""
for SLOT in $(megacli -PDList -aAll | egrep '^Slot Number' | grep -v 'Slot Number: [01]$' | cut -d" " -f 3)
do
    if [ $x -eq 0 ]
    then
        ARRLIST="${ARRLIST} -Array${arrnum} [0:${SLOT}, "
        x=$(( $x + 1 ))
    else
        ARRLIST="${ARRLIST} 0:${SLOT}]"
        x=0
        arrnum=$(( $arrnum + 1 ))
    fi
done


# Only run if we have a complete array.  Fail out and leave for manual runs if we have an odd number.
if [ $x -eq 0 ]
then
    R10COMMAND="${R10COMMAND} ${ARRLIST} WB RA Cached NoCachedBadBBU -a0"
    echo "Running: $R10COMMAND"
    $R10COMMAND
else
    echo "We have an odd number of disks to set up for the array. A manual setup is required"
fi


