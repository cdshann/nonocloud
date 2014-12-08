#!/bin/bash

DIR=`pwd` 

# Change working directories
cd "$(dirname "$0")"

# Read config
source nonocloud.conf 

# Download the ubuntu server image and hash
wget -O $FNAME $DL_URL$IMG
wget -O hashes $DL_URL$HASH

# Check the downloaded hashes
hash_check=`grep "$IMG" hashes | cut -d " " -f1`
checksum=`sha256sum $FNAME | cut -d " " -f1`

if [ "$hash_check" != "$checksum" ]; then
	echo "Error: image hash does not verify"
	exit 1
fi

# Create the overlay image
qemu-img create -f qcow2 -b $FNAME trusty64.img $DISK_SIZE

# Create the cloud-init data
cat > cloudinit.data <<EOF
#cloud-config
apt_update: true
apt_upgrade: true
password: $PASSWORD
chpasswd: { expire: False }
ssh_pwauth: True
manual_cache_clean: True

packages:
 - fail2ban

EOF

# Use cloud-localds to create the nocloud-data data source
cloud-localds cloudinit.iso cloudinit.data

# Create the VM using virt-install. Edit to reflect your environemnt
virt-install --connect qemu:///system --name $NAME --ram $RAM --vcpus $CPU --disk path=$DIR/trusty64.img,format=qcow2,bus=virtio --cdrom cloudinit.iso --network=bridge:br0,model=virtio --os-type=linux --os-variant=ubuntutrusty --noautoconsole

# Clean up
rm -f cloudinit.iso
rm -f cloudinit.data
rm -f hashes
