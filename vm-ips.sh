# List all running VM ips connected to a specified interface
iface=$1
table=`arp-scan --interface=$iface -l --quiet | sed 1,2d | head -n -3`

for vm in `virsh list | grep running | awk '{ print $2 }'`
do
	mac=`virsh dumpxml $vm | grep "mac address" | sed "s/.*'\(.*\)'.*/\1/g"`
	if [[ $table == *$mac* ]]
	then
		ip=`sed "s/$mac.*$//" <<< $table | awk '{ print $NF }'`
		echo "$vm : $ip : $mac"
	fi
done
