A very simple script to quickly (and simply) deploy Ubuntu Cloud Images locally with KVM. Currently this script only supports amd64 trusty.

Usage:
  -Edit nonocloud.conf to update your desired VM configuration. Make sure and update the password field with your       desired password. 
  -Run nonocloud.sh
  -Login to the newly created VM with ssh/virsh console. The default username is "ubuntu".
