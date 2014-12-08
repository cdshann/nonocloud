#!/bin/bash

DIR=`pwd -P` 

# Change working directories
cd "$(dirname "$0")"

# Read config
source nonocloud.conf 

# Download the ubuntu server image and hash
echo "[nonocloud] downloading trusty image hashes"
wget -q -O hashes $DL_URL$HASH

# Check if backing file already exists
if [ -f $FNAME ]; then
	echo "[nonocloud] found trusty64.img, checking hash"
else
	echo "[nonocloud] downloading trusty64 cloud image"
	wget -O $FNAME $DL_URL$IMG
fi

# Check the downloaded hashes
hash_check=`grep "$IMG" hashes | cut -d " " -f1`
checksum=`sha256sum $FNAME | cut -d " " -f1`

if [ "$hash_check" != "$checksum" ]; then
	echo "[nonocloud] error: image hash does not verify"
	echo "[nonocloud] attempting to re-download image"

	# We only attempt to re-download the image once
	wget -q -O $FNAME $DL_URL$IMG
	checksum=`sha256sum $FNAME | cut -d " " -f1`

	if [ "$hash_check" != "$checksum" ]; then
		echo "[nonocloud] hash mismatch after re-downloading image. exiting"
		exit -1
	fi
fi

# Create the overlay image
qemu-img create -f qcow2 -b $FNAME trusty64-cloud.img $DISK_SIZE

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
echo "[nonocloud] creating cloudinit data source"
cloud-localds cloudinit.iso cloudinit.data

# Create the VM using virt-install. Edit to reflect your environemnt
echo "[nonocloud] creating vm"
virt-install --connect qemu:///system \
--name $NAME \
--ram $RAM \
--vcpus $CPU \
--disk path=$DIR/trusty64-cloud.img,format=qcow2,bus=virtio \
--cdrom cloudinit.iso \
--network=bridge:$IFACE,model=virtio \
--os-type=linux \
--os-variant=ubuntutrusty \
--noautoconsole

# Clean up
rm -f cloudinit.iso
rm -f cloudinit.data
rm -f hashes

echo "[nonocloud] complete. please use virsh to interact with your new vm"
