#!/bin/bash

echo "Creating 4 loop devices:"
dd if=/dev/zero of=disk0 bs=200M count=1
dd if=/dev/zero of=disk1 bs=200M count=1
dd if=/dev/zero of=disk2 bs=200M count=1
dd if=/dev/zero of=disk3 bs=200M count=1

losetup loop0 ./disk0
losetup loop1 ./disk1
losetup loop2 ./disk2
losetup loop3 ./disk3

echo "Creating RAID1 from first two loop devices on /dev/md0:"

yes | mdadm --create /dev/md0 --level=raid1 --raid-devices=2 \
/dev/loop0 /dev/loop1

echo "Creating RAID0 from last two loop devices on /dev/md1:"

yes | mdadm --create /dev/md1 --level=raid0 --raid-devices=2 \
/dev/loop2 /dev/loop3

echo "Creating volume group on top of both RAID devices:"

pvcreate /dev/md0 /dev/md1
vgcreate FIT_vg /dev/md0 /dev/md1 

echo "Creating 2 logical volumes of size 100MB on top of volume group:"

lvcreate FIT_vg -n FIT_lv1 -L100M
lvcreate FIT_vg -n FIT_lv2 -L100M

echo "Creating EXT4 fs on FIT_lv1 logical volume:"

mkfs.ext4 /dev/FIT_vg/FIT_lv1

echo "Creating XFS fs on FIT_lv2 logical volume:"

mkfs.xfs /dev/FIT_vg/FIT_lv2

echo "Mounting FIT_lv1 to /mnt/test1:"

mkdir /mnt/test1
mount /dev/FIT_vg/FIT_lv1 /mnt/test1

echo "Mounting FIT_lv2 to /mnt/test2:"

mkdir /mnt/test2
mount /dev/FIT_vg/FIT_lv2 /mnt/test2

echo "Resize fs FIT_lv1 to claim all avaibale space in volumegroup:"

umount /mnt/test1
lvresize -rl +100%FREE /dev/FIT_vg/FIT_lv1
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
df -h

echo "Creating 300MB file to /mnt/test1/big_file using 'dd':"

dd if=/dev/urandom of=/mnt/test1/big_file bs=1M count=300

echo "Calculating SHA-512 checksum of the file:"

sha512sum -b /mnt/test1/big_file

echo "Emulating faulty disk:"

echo "Creating 200MB new disk and mounting it to loop4":

dd if=/dev/zero of=disk4 bs=200M count=1
losetup loop4 ./disk4

echo "Replacing RAID1 loop0 with this new disk:"
mdadm --manage /dev/md0 --fail /dev/loop0
mdadm --manage /dev/md0 --remove /dev/loop0
mdadm --manage /dev/md0 --add /dev/loop4
cat /proc/mdstat
echo "done."
