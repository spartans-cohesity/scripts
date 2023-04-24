#!/bin/sh
#set -e
# Author: Manoj K Mittal
# This script is for use with Cohesity Remote adapter to backup any unix based system to Cohesity NFS view.
# Please take a look at "https://github.com/manojmittalcohesity/cohesitysolutionsengineering/blob/main/RSYNC%20-%20Backup%20and%20Recovery%20using%20RA.pdf"
# on how to use this script with Cohesity remote adapter

while getopts ":V:P:I:S:E:" opt
do
[ ${OPTARG} = -* ] && { echo "Missing argument for -${opt}" ; exit 1 ; }
    case "${opt}" in
        V) MOUNT_VIEW=${OPTARG};;
	P) MOUNT_PATH=${OPTARG};;
	I) MOUNT_IP=${OPTARG};;
	S) RSYNC_SOURCE=${OPTARG};;
	E) EXCLUDE_FILE=${OPTARG};;
      \? ) echo "Usage: cmd [-V][-P] [-I] [-S] [-E]"; exit 1;;
       : ) echo "missing argument for -${OPTARG}"; exit 1;;
    esac
done
## INPUT PARAMS
#MOUNT_VIEW=$1
#MOUNT_PATH=$2
#MOUNT_IP=$3
#RSYNC_SOURCE=$4
#EXCLUDE_FILE=$5

echo $MOUNT_VIEW
echo $MOUNT_PATH
echo $MOUNT_IP
echo $RSYNC_SOURCE
echo $EXCLUDE_FILE

#Check if MOUNT_PATH Exists on host
if [ -d $MOUNT_PATH ]
then
echo "Mount path $MOUNT_PATH exists"
else
echo "Mount path $MOUNT_PATH does not exist, please create and try again"
exit 1
fi

#Check if RSYNC_SOURCE Exists on host
if [ -d $RSYNC_SOURCE ]
then
echo "Source path to sync $RSYNC_SOURCE  exists"
else
echo "Source path to sync $RSYNC_SOURCE does not exists, please check and try again"
exit 1
fi

#Check if Exclude File Exists on host
if [ -f $EXCLUDE_FILE ]
then
echo "Exclude File $EXCLUDE_FILE exists"
else
echo "Exclude File $EXCLUDE_FILE does not exist, please create and try again"
exit 1
fi


#Check Required Commands Availability
#. $HOME/.profile 2> /dev/null
PATH="$PATH:/usr/sbin:/usr/bin:/usr/local/bin"
export PATH
checksudo=sudo
which $checksudo | grep "no $checksudo in"
if [ "$?" != "0" ]; then
echo $checksudo found
sudopath=`which sudo`
else
echo $checksudo not found
exit 1
echo $checksudo not found
fi

checkrsync=rsync
which $checkrsync | grep "no $checkrsync in"
if [ "$?" != "0" ]; then
echo ========================
echo $checkrsync found
rsyncpath=`which rsync`
echo ========================
else
echo ========================
echo $checkrsync not found
echo ========================
exit 1
fi

checkmount=mount
which $checkmount | grep "no $checkmount in"
if [ "$?" != "0" ]; then
echo ========================
echo $checkmount found
mountpath=`which mount`
echo ========================
else
echo ========================
echo $checkmount not found
echo ========================
exit 1
fi

checkumount=umount
which $checkumount | grep "no $checkumount in"
if [ "$?" != "0" ]; then
echo ========================
echo $checkumount found
umountpath=`which umount`
echo ========================
else
echo ========================
echo ========================
exit 1
fi

#/usr/local/bin/sudo -s <<EOF 

#Unmount before attempting mount
$sudopath $umountpath $MOUNT_PATH

$sudopath $mountpath -F nfs -o soft,proto=tcp,vers=3 $MOUNT_IP:/$MOUNT_VIEW $MOUNT_PATH
if [ "$?" != "0" ]; then
echo =======================
echo "Mount command failed, please check and fix mount issues if any"
echo ========================
exit 1
else
echo ======================
echo "Mount completed successfully, Starting Rsync Backup"
echo ======================
fi
df

#Find NFS filesystems and exclude them
cat $EXCLUDE_FILE > /tmp/rsyncexcludescriptgenerated
df -F nfs | awk '{print $1}' >> /tmp/rsyncexcludescriptgenerated

$sudopath $rsyncpath -aHS  --stats --hard-links --sparse --human-readable --relative --no-whole-file --out-format="%t %f %b" --exclude=$MOUNT_PATH --exclude-from=/tmp/rsyncexcludescriptgenerated $RSYNC_SOURCE $MOUNT_PATH 2>&1 | tee /usr/openv/netbackup/logs/bpbkar/rsyncbackup_log.$(date +'%Y%m%d')
rsyncstatus=$?
echo $rsyncstatus > /tmp/rsyncstatus.txt
if [ "$rsyncstatus" = "24" ]; then
echo =======================
echo "Rsync command was partially successful, please check error and fix issues if any, proceeding to unmount cohesity view "
echo ========================
rm -f /tmp/rsyncexcludescriptgenerated
elif [ "$rsyncstatus" != "0" ]; then
echo =======================
echo "Rsync command failed, please check error and try again"
echo ========================
rm -f /tmp/rsyncexcludescriptgenerated
$sudopath $umountpath -f $MOUNT_PATH
exit $rsyncstatus
else
echo ======================
echo "Rsync backup completed successfully, proceeding to unmount cohesity view"
echo ======================
rm -f /tmp/rsyncexcludescriptgenerated
fi 

echo "$sudopath $umountpath -f $MOUNT_PATH"

$sudopath $umountpath $MOUNT_PATH
if [ "$?" != "0" ]; then
echo =======================
echo "Unmount command failed, please unmount manually"
echo ========================
exit 1
else
echo ======================
echo "Unmount completed successfully, backup process completed successfully"
echo ======================
fi

df
#EOF
