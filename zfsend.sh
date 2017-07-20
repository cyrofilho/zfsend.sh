#!/bin/bash

source_dataset="dados"
dest_dataset="backup/dados"
ssh="no"
zfs="/sbin/zfs"





latest_source_snap=`${zfs} list -t snapshot | grep ${source_dataset}@ | tail -n1 | cut -d" " -f1 | rev | cut -d"/" -f1 | rev`
latest_source_snap_fpath=`${zfs} list -t snapshot | grep ${source_dataset}@ | tail -n1 | cut -d" " -f1`
if [ -z ${latest_source_snap_fpath} ]; then
	echo "No snapthosts found on the source, exiting..."
	exit
fi

if [ ${ssh} != "yes" ]; then

		echo "Local copy..."

		dest_dataset_path=`dirname ${dest_dataset}`
		if ! ${zfs} list ${dest_dataset_path} >/dev/null 2>&1; then
			echo "The destination dataset ${dest_dataset_path} does not exist, creating..."
			${zfs} create -p ${dest_dataset_path}
			if [ $? = 0 ]; then
				echo "done!"
			else
				exit
			fi
		fi

		if ! ${zfs} list -t snapshot | grep ${dest_dataset}@ >/dev/null 2>&1; then
			echo "No snapshot found on the destination, doing initial transfer..."
			${zfs} send -R ${latest_source_snap_fpath} | ${zfs} recv ${dest_dataset}
			if [ $? = 0 ]; then
                                echo "done!"
				exit
                        else
				echo "Initial transfer error, please check!"
                                exit
                        fi
		fi

		latest_dest_snap=`${zfs} list -t snapshot | grep ${dest_dataset}@ | tail -n1 | cut -d" " -f1 | rev | cut -d"/" -f1 | rev`
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
			${zfs} send -R -I ${source_dataset_path}${latest_dest_snap} ${latest_source_snap_fpath} | ${zfs} recv ${dest_dataset}
			if [ $? = 0 ]; then
                                echo "done!"
                        else
				echo "Cannot do an incremental backup with the latest snapshot on the destination, please check!"
                                exit
                        fi
		fi	

else

		echo "SSH copy..."

fi

