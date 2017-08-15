#!/bin/bash

# Source dataset or pool with no trailing /
source_dataset="dados"

# Destination dataset or pool with no trailing /
dest_dataset="backup/dados"

# Executables pathes, please edit according to your system, this config is for Ubuntu 16.04
zfs="/sbin/zfs"
pv="/usr/bin/pv"

# SSH parameters in case you want to send to a remote location, if you are sending to a local destionation (USB device) just choose ssh="no" instead. If you choose ssh="yes" please make sure that you can login via ssh to the remote server with no password
ssh="no"
sshpath="/usr/bin/ssh"
sshport=""
sshuser=""
sshserver=""


##############################################################################
# Please do not edit beyond this point unless you know what you are doing
##############################################################################

START_TIME=$SECONDS

if [ ${ssh} != "yes" ]; then
	zfsrem=${zfs}
	zfsrecv="${zfs} recv"
else
	zfsrem="${sshpath} -p ${sshport} ${sshuser}@${sshserver} ${zfs}"
	zfsrecv="${sshpath} -p ${sshport} ${sshuser}@${sshserver} ${zfs} recv"
fi


if [ ${ssh} != "yes" ]; then
	echo "Local copy..."
else
	echo "Ssh copy..."
fi


latest_source_snap=`${zfs} list -t snapshot | grep ${source_dataset}@ | tail -n1 | cut -d" " -f1 | rev | cut -d"/" -f1 | rev`
latest_source_snap_fpath=`${zfs} list -t snapshot | grep ${source_dataset}@ | tail -n1 | cut -d" " -f1`
if [ -z ${latest_source_snap_fpath} ]; then
	echo "No snapthosts found on the source, exiting..."
	exit
fi


if [ 1 == 1 ]; then
		
		dest_dataset_path=`dirname ${dest_dataset}`
		if ! ${zfsrem} list ${dest_dataset_path} >/dev/null 2>&1; then
			echo "The destination dataset ${dest_dataset_path} does not exist, creating..."
			${zfsrem} create -p ${dest_dataset_path}
			if [ $? = 0 ]; then
				echo "done!"
			else
				exit
			fi
		fi

		if ! ${zfsrem} list -t snapshot | grep ${dest_dataset}@ >/dev/null 2>&1; then
			echo "No snapshot found on the destination, doing initial transfer..."
			${zfs} send -R ${latest_source_snap_fpath} | $pv | $zfsrecv ${dest_dataset}
			if [ $? = 0 ]; then
                                echo "done!"
				exit
                        else
				echo "Initial transfer error, please check!"
                                exit
                        fi
		fi

		latest_dest_snap=`${zfsrem} list -t snapshot | grep ${dest_dataset}@ | tail -n1 | cut -d" " -f1 | rev | cut -d"/" -f1 | rev`
		source_dataset_path=`dirname ${source_dataset}`
		if [ $source_dataset_path = "." ]; then
			source_dataset_path=""
		else
			source_dataset_path=${source_dataset_path}\/
		fi 
		if [ $latest_dest_snap = $latest_source_snap ]; then
			echo "The last snapshot is already on the destination, exiting..."
			exit
		else
			echo "Old snapshot found on the destination, doing incremental copy!"
			${zfs} send -R -I ${source_dataset_path}${latest_dest_snap} ${latest_source_snap_fpath} | $pv | ${zfsrecv} ${dest_dataset}
			if [ $? = 0 ]; then
                                echo "done!"
                        else
				echo "Cannot do an incremental backup with the latest snapshot on the destination, please check!"
                                exit
                        fi
		fi	

END_TIME=$SECONDS
DIF=$(($END_TIME - $START_TIME))
echo $(($DIF/86400))d $(($DIF%86400/3600))h $(($DIF%3600/60))m $(($DIF%60))s

fi

