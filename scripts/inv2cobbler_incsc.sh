#!/bin/bash

INVENV=incsc
INPUTCSV=input_${INVENV}.csv
NETMASK=255.255.252.0
GATEWAY=172.22.0.1
DNS=8.8.8.8


#####################################################
# Need one argument which is the exported .csv file
#####################################################
if [ $# == 0 ]
then
    echo "Usage: inv2cobbler_incsc.sh inventory_csv_file.csv" 
    exit 1
else
    INVEXPORT=$1
    if [ ! -e "${INVEXPORT}" ]
    then
        echo "${INVEXPORT} doesn't exist"
        exit 1
    fi
fi

###############################################################
# Create the cobbler commands from an exported spreadsheet list
###############################################################

# empty the output
if [ -e $INPUTCSV ]
then
    rm $INPUTCSV
fi

# loop through export and pull out populate the ilo csv file
while read -r INV_LINE
do
    echo $INV_LINE | grep "${INVENV}" > /dev/null
    if [ $? == 0 ]
    then
        ILOIP=$(echo $INV_LINE | awk -F ',' '/incsc/{print $6}')
        COBBLERIP=$(echo $INV_LINE | awk -F ',' '/incsc/{print $7}')
        MAC=$(echo $INV_LINE | awk -F ',' '/incsc/{print $4}')
        MODEL=$(echo $INV_LINE | awk -F ',' '/incsc/{print $5}')
        NAME=$(echo $INV_LINE | awk -F ',' '/incsc/{print $12}')
        case $NAME in 
            *infra*)
                ROLE='controller'
                ;;
            *compute*)
                ROLE='compute'
                ;;
            *swift*)
                ROLE='swift'
                ;;
            *ceph*)
                ROLE='cinder'
                ;;
            *logger*)
                ROLE='logging'
                ;;
            *)
                ROLE='network'
                ;;
        esac

        # Select seed based on role
        case "$ROLE" in
            cinder)
                #PROFILE='ubuntu-server-14.03-unattended-osic-cinder'
                PROFILE='ubuntu-14.04.3-server-unattended-osic-cinder'
                ;;
            swift)
                #PROFILE='ubuntu-server-14.03-unattended-osic-swift'
                PROFILE='ubuntu-14.04.3-server-unattended-osic-swift'
                ;;
            *)
                #PROFILE='ubuntu-server-14.03-unattended-osic-generic.seed'
                PROFILE='ubuntu-14.04.3-server-unattended-osic-generic'
                ;;
        esac

        # Select pxe interface via model
        case "$MODEL" in
            LENOVO)
                INTERFACE='p1p1'
                ;;
            Dell)
                INTERFACE='em1'
                ;;
            *)
                INTERFACE='unknown'
                ;;
        esac
 

        # Create the input file
        INPUTLINE="${NAME},${MAC},${COBBLERIP},${NETMASK},${GATEWAY},${DNS},${INTERFACE},${PROFILE}" 
        echo $INPUTLINE | grep ',,' > /dev/null
        if [ $? == 0 ]
        then
          echo "Skipping on missing field: $INPUTLINE" >&2
          continue
        else
          echo $INPUTLINE >> $INPUTCSV
        fi

        # Check for an existing cobbler profile
        cobbler system report --name ${NAME} > /dev/null
        if [ $? == 0 ]
        then
            echo "cobbler system remove --name ${NAME}"
        fi
        echo "cobbler system add --name=${NAME} --mac=${MAC} --profile=${PROFILE} --hostname=${NAME} --interface=${INTERFACE} --ip-address=${COBBLERIP} --subnet=${NETMASK} --gateway=${GATEWAY} --name-servers=${DNS} --kopts=\"interface=${INTERFACE} console=tty0 console=ttyS0,115200n8\""

    fi  

done < $INVEXPORT

