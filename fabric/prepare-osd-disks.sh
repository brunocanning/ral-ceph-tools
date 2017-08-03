#!/bin/bash

# prepare-osd-disks.sh

# Check that OS disk is /dev/sdak if hardware_model is disk-2015-xma
if ! [ -x /usr/sbin/ncm-query ]
then
    echo "Unable to determine hardware model."
    exit 1
fi

unset confirm
hardware_model=$(quattor-query /hardware/model | awk '{print $5}' | tr -d "'" | tr -d [:space:])

if [ -z $hardware_model ]
then
    echo "Hardware model is undefined."
    exit 1
fi

if ( [ $hardware_model == "disk-2015-xma" ] && [ -b /dev/sdak4 ] && (mount | grep sdak2 | grep -q /boot) )
then
    os_dev=sdak
    echo "Hardware model is $hardware_model and OS disk is /dev/$os_dev"
elif ( [ -b /dev/sda4 ] && (mount | grep sda2 | grep -q /boot) && ! [ $hardware_model == "disk-2015-xma" ] )
then
    os_dev=sda
    echo "Hardware model is $hardware_model and OS disk is /dev/$os_dev"
else
    echo "ERROR: Cannot proceed."
    echo
    echo "The OS disk may not be correct for this model, consider rebooting the node"
    echo "until it is. Aborting operations."
    exit 1
fi

echo "Do you wish to proceed with OSD disk cleaning?"
echo "Options are: \"yes\" or \"no\""
echo "Warning! Answers are case sensitive."
while read confirm
do
    case $confirm in
        yes)
            echo "Proceeding with OSD disk cleaning..."
            break
            ;;
        no)
            echo "Operation aborted."
            echo
            exit 1
            ;;
        *)
            echo "Invalid input!"
            sleep 0.75s
            echo "Please select either \"yes\" or \"no\"."
            ;;
    esac
done
sleep 1s

# Over-write the start of the disk such that the OSD journal size plus 5 MiB is clean.
# CAUTION: This assumes all OSD disks are the same capacity and that /dev/sdb is an OSD disk.
if ( [ -f /etc/ceph/ceph.conf ] && (egrep -q '^osd_journal_size' /etc/ceph/ceph.conf) )
then
    journal_size=$(egrep '^osd_journal_size' /etc/ceph/ceph.conf | cut -d= -f2)
else
    journal_size=10240
fi

disk_size=$(parted -s /dev/sdb unit MiB print | grep "Disk /" | cut -f3 -d' ' | tr -d 'MiB')

for i in $(ls /sys/block/ | egrep ^sd | egrep -v ^${os_dev}$)
do
    echo "Zeroing disk /dev/$i"
    dd if=/dev/zero of=/dev/$i bs=1048576 count=$(((journal_size+5)))
    dd if=/dev/zero of=/dev/$i bs=1048576 count=4 seek=$(((disk_size-5)))
done

echo "Zeroing out completed"

exit 0
