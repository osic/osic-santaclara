#!/bin/bash


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


###################################################################
# Start parsing through the inventory and create a host entry for
# each server that is set up in cobbler
###################################################################

INVENV=incsc

# Set up headers for each config type
CONTROLLER="\n\n[controller]\n"
COMPUTE="\n\n[compute]\n"
SWIFT="\n\n[swift]\n"
LOGGING="\n\n[logging]\n"
NETWORK="\n\n[network]\n"
CINDER="\n\n[cinder]\n"
SWIFT="\n\n[swift]\n"
UNDEFINED="\n\n[undefined]\n"
CEPH="\n\n[ceph]\n"



# loop through export and pull out populate the ilo csv file
while read -r INV_LINE
do

    if [[ $INV_LINE =~ .*incsc.* ]]
    then
        ILOIP=$(echo $INV_LINE | awk -F ',' '/incsc/{print $6}')
        COBBLERIP=$(echo $INV_LINE | awk -F ',' '/incsc/{print $7}')
        MAC=$(echo $INV_LINE | awk -F ',' '/incsc/{print $4}')
        MODEL=$(echo $INV_LINE | awk -F ',' '/incsc/{print $5}')
        NAME=$(echo $INV_LINE | awk -F ',' '/incsc/{print $12}')
        #echo $NAME
        case $NAME in 
            *infra*)
                CONTROLLER=${CONTROLLER}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *compute*)
                COMPUTE=${COMPUTE}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *swift*)
                SWIFT=${SWIFT}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *logger*)
                LOGGING=${LOGGING}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *network*)
                NETWORK=${NETWORK}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *ceph*)
                CEPH=${CEPH}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *cinder*)
                CINDER=${CINDER}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *swift*)
                SWIFT=${SWIFT}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
            *)
                UNDEFINED=${UNDEFINED}"\n${NAME} ansible_ssh_host=${COBBLERIP} ironic_ip=${ILOIP}"
                ;;
        esac
    fi

done < $INVEXPORT


######################
# Print the results
######################

if [ "$CONTROLLER" != "\n\n[controller]\n" ]
then
    echo -e "$CONTROLLER"
fi

if [ "$COMPUTE" != "\n\n[compute]\n" ]
then
    echo -e "$COMPUTE"
fi

if [ "$LOGGING" != "\n\n[logging]\n" ]
then
    echo -e "$LOGGING"
fi

if [ "$NETWORK" != "\n\n[network]\n" ]
then
    echo -e "$NETWORK"
fi

if [ "$UNDEFINED" != "\n\n[undefined]\n" ]
then
    echo -e "$UNDEFINED"
fi

if [ "$SWIFT" != "\n\n[swift]\n" ]
then
    echo -e "$SWIFT"
fi

if [ "$CINDER" != "\n\n[cinder]\n" ]
then
    echo -e "$CINDER"
fi

if [ "$CEPH" != "\n\n[ceph]\n" ]
then
    echo -e "$CEPH"
    echo -e "\n\n[mons:children]\n\nceph\n"
    echo -e "\n[osds:children]\n\nceph\n"
    echo -e "\n[mdss]\n\nceph01\n"
    echo -e "\n[rgws]\n\nceph01\n"
fi

