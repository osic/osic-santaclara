# Overview

It looks like initially James Thorne(now working for google) modified an install image for ubuntu to include the hpssacli tool as well as a seed file and hd setup scripts.  

  - http://public.thornelabs.net/ubuntu-14.04.3-server-i40e-hp-raid-x86_64.iso

It has been moved to private cloud account 863644 currently along with some other images. 

  - http://23.253.105.87/ubuntu-14.04.3-server-i40e-hp-raid-x86_64.iso
  - http://23.253.105.87/osic.seed  (used to be on the image at /cdrom/preseed/ubuntu-server.seed)
  - http://23.253.105.87/osic.tar.gz


We currently do not have a process documented to set up the custom distro's used for building out the environment(that I know of). This is an attempt to document the process and set up a cobbler to use it. Steps are on the osic-prep container set up in https://github.com/osic/ref-impl/blob/master/documents/bare_metal_provisioning.md for normal osic bare metal deploys.  Some may be required to be ran on the deploy host the contianer is setting in and will state it before the steps. The Santa Clara environment only has a single deployment box, so the distro, profile and cobbler files should be set up.


## Download the base distro

Find the distro you want at:

http://releases.ubuntu.com/14.04/

deploy device

```
wget http://releases.ubuntu.com/trusty/ubuntu-14.04.5-server-amd64.iso

md5sum ubuntu-14.04.5-server-amd64.iso 

#  (compare it the sum to the the MD5SUMS file in the same download loc)

curl http://releases.ubuntu.com/trusty/MD5SUMS -s | grep ubuntu-14.04.5-server-amd64
```


## Set up the distro in cobbler

Had to get out of the osic-prep container and into the deploy device to mount the iso


deploy device
```
cd /usr/local/var/lib/lxc/osic-prep/rootfs/root
mkdir mnt
mount -o loop ubuntu-14.04.5-server-amd64.iso mnt/
rsync -a --progress mnt/ ./ubuntu-14.04.5-server-amd64
umount mnt
rmdir mnt
```


osic-prep container
```
cobbler import --name=ubuntu-14.04.5-server-amd64 --path=/root/ubuntu-14.04.5-server-amd64
rm -rf ubuntu-14.04.5-server-amd64*



```



## Update the initrd

```
# 1st time, make a backup
cp /var/www/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/install/netboot/ubuntu-installer/amd64/initrd.gz /var/www/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/install/netboot/ubuntu-installer/amd64/initrd_orig.gz


# Unpack it into a temp directory
mkdir initrd_update
cd initrd_update
gzip -cd /var/www/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/install/netboot/ubuntu-installer/amd64/initrd.gz | cpio -id


# Make changes

# make sure you match the lsb-release to the debian/ubunut package.  Debian jessie packages should work with Ubuntu 14.04
cat etc/lsb-release 

# install lsi megaraid tool from https://hwraid.le-vert.net/debian
wget https://hwraid.le-vert.net/debian/pool-jessie/megacli_8.07.14-1_amd64.deb -O /tmp/megacli_8.07.14-1_amd64.deb
dpkg -x /tmp/megacli_8.07.14-1_amd64.deb .
rm /tmp/megacli_8.07.14-1_amd64.deb

# install hp raid tool from http://downloads.linux.hpe.com/SDR/repo/mcp/
wget http://downloads.linux.hpe.com/SDR/repo/mcp/pool/non-free/hpssacli-2.10-14.0_amd64.deb -O /tmp/hpssacli-2.10-14.0_amd64.deb
dpkg -x /tmp/hpssacli-2.10-14.0_amd64.deb .
rm /tmp/hpssacli-2.10-14.0_amd64.deb


# Extract some dependancies.  This was done on a box compatible with the installer version.  You 
dpkg -x /var/lib/cobbler/webroot/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/pool/main/n/ncurses/libncurses5_5.9+20140118-1ubuntu1_amd64.deb .
dpkg -x /var/lib/cobbler/webroot/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/pool/main/g/gccgo-4.9/libgcc1_4.9.3-0ubuntu4_amd64.deb .
dpkg -x /var/lib/cobbler/webroot/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/pool/main/g/gcc-4.8/libstdc++6_4.8.4-2ubuntu1~14.04.3_amd64.deb .
dpkg -x /var/lib/cobbler/webroot/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/pool/main/n/ncurses/libtinfo5_5.9+20140118-1ubuntu1_amd64.deb .




# Re-create the initrd
find . | cpio -o -H newc | gzip > ../initrd.gz
cp ../initrd.gz /var/www/cobbler/ks_mirror/ubuntu-14.04.5-server-amd64/install/netboot/ubuntu-installer/amd64/initrd.gz


```


## Set up cobbler

If not already download the osic-santaclara-incsc repo.

```
git clone https://github.com/osic/osic-santaclara /opt/osic-santaclara-incsc
cd /opt/osic-santaclara-incsc/
```


Copy any cobbler files over and set up a new profile to use it.

```
cp cobbler_files/ubuntu-server-14.04-unattended-cobbler-osic.seed /opt/osic-preseeds/
cp -rp cobbler_files/osic-snippets /opt/osic/preseeds/
ln -s /opt/osic-preseeds/osic-snippets /var/lib/cobbler/snippets/osic
cp cobbler_files/pub/* /var/www/cobbler/pub/

cobbler profile add --name=ubuntu-14.04.5-server-unattended-osic --distro=ubuntu-14.04.5-server-x86_64 --kickstart=/opt/osic-preseeds/ubuntu-server-14.04-unattended-cobbler-osic.seed --dhcp-tag=default --enable-gpxe=0 --enable-menu=1

```



