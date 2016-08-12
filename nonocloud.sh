#!/bin/bash

DIR=`pwd -P` 

# Read config
source nonocloud.conf 

# Check if a preexisting image was specified
if [ -z "$BASE_IMG" ]; then

# Download the ubuntu server image and hash
echo "[nonocloud] downloading xenial image hashes"
wget -q -O hashes $DL_URL$HASH

# Check if backing file already exists
if [ -n "$FNAME" ]; then
	echo "[nonocloud] found existing cloud image, checking hash"
else
	echo "[nonocloud] downloading xenial64 cloud image"
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

BASE_IMG=$FNAME

fi

# Create the overlay image
echo "[nonocloud] creating overlay image"
qemu-img create -f qcow2 -b $BASE_IMG $NAME.qcow2 $DISK_SIZE

if [ -n "$PASSWORD" ]; then

echo "[nonocloud] configuring password login"
# Create the cloud-init data for pw auth
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

elif [ -n "$SSH" ]; then

echo "[nonocloud] configuring ssh login"
# Create the cloud-init data for pw auth
cat > cloudinit.data <<EOF
#cloud-config
ssh_authorized_keys:
 - $SSH
manual_cache_clean: True
apt_update: true
apt_upgrade: true
packages:
 - fail2ban
EOF


else
echo "[nonocloud] no password or SSH key found, aborting"
fi

# Use cloud-localds to create the nocloud-data data source
echo "[nonocloud] creating cloudinit data source"
cloud-localds cloudinit.iso cloudinit.data

# Create the VM using virt-install. Edit to reflect your environemnt
echo "[nonocloud] provisioning vm"
virt-install --connect qemu:///system \
--name $NAME \
--ram $RAM \
--vcpus $CPU \
--disk path=$DIR/$NAME.qcow2,format=qcow2,bus=virtio \
--cdrom cloudinit.iso \
--network=bridge:$IFACE,model=virtio \
--os-type=linux \
--os-variant=ubuntu16.04 \
--noautoconsole

# Clean up
rm -f cloudinit.iso
rm -f cloudinit.data
rm -f hashes

echo "[nonocloud] complete. please use virsh to interact with your new vm"
