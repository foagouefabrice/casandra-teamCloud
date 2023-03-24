#!/bin/bash

dir=$1
dir_path=$2

rf_param=$3
rf=$4

osname=$(uname -o)
user_name=cassandra
password=cassandra

DATABASE_DIR=$cassandra_database
RECOVERY_FILE_DIR=$rf
FILE_NAME="cassandra_backup_$(date "+%Y.%m.%d-%H.%M.%S").tar"

init() {
	init_database_dir
	init_recovery_file_dir
}

flush_data_to_disk() {
	echo "Flushing data to disk"
	if [ "$osname" = "Cygwin" ] ; then 
		nodetool.bat -h localhost -u $user_name -pw $password -p 7199 flush
		check_for_errors
	else
		nodetool -h localhost -u $user_name -pw $password -p 7199 flush
		check_for_errors
	fi
}

await_flush() {
	sleep 10
}

snapshot_cassandra_database() {
	if [ "$osname" = "Cygwin" ] ; then
		echo "Stopping cassandra compactions if they were running"
		nodetool.bat -h localhost -u $user_name -pw $password -p 7199 stop
		echo "Taking a snapshot of all key spaces"
		nodetool.bat -h localhost -u $user_name -pw $password -p 7199 snapshot
		check_for_errors
	else
		echo "Stopping cassandra compactions if they were running"
		nodetool -h localhost -u $user_name -pw $password -p 7199 stop
		echo "Taking a snapshot of all key spaces"
		nodetool -h localhost -u $user_name -pw $password -p 7199 snapshot
		check_for_errors
	fi
}

init_database_dir() {
	if [ ! -d "DATABASE_DIR" ]; then
		if [ "$dir" = "-dir" ] ; then
			if [ ! -d "$dir_path" ]; then
				request_db_dir
			else
				DATABASE_DIR=$dir_path
			fi
		else
			request_db_dir
		fi
	fi
}

init_recovery_file_dir() {
	if [ ! -d "RECOVERY_FILE_DIR" ]; then
		if [ "$rf_param" = "-rf" ] ; then
			if [ ! -d "$rf" ]; then
				request_recovery_file_dir
			else
				RECOVERY_FILE_DIR=$rf
			fi
		else
			request_recovery_file_dir
		fi
	fi
}

request_recovery_file_dir() {
	need_dir=true
	while $need_dir; do
    	read -p "Please enter backup file location. I.e. /home/user/backups/: " RECOVERY_FILE_DIR
		if [ ! -d "$RECOVERY_FILE_DIR" ]; then
			echo "No backup directory found $RECOVERY_FILE_DIR"
			echo "Wrong dir entered."
		else
			need_dir=false;
		fi
	done
}

request_db_dir() {
	need_dir=true	
	while $need_dir; do
    	read -p "Please enter Cassandra database directory. I.e. /var/lib/cassandra: " DATABASE_DIR
		if [ ! -d "$DATABASE_DIR/data/" ]; then
			echo "No directory $DATABASE_DIR/data/"
			echo "Wrong directory entered."
		else
			need_dir=false;
		fi
	done
}

archive_snapshots_for_backup() {
	echo "Archiving snapshots for backup"
	(cd "$DATABASE_DIR/data"
		find . -type f -path "*/snapshots/*/*" | tar -cpf $RECOVERY_FILE_DIR/$FILE_NAME -T - --hard-dereference
		#mv $FILE_NAME $RECOVERY_FILE_DIR
	)
}

remove_snapshot() {
	echo "Removing old snapshots"
	if [ "$osname" = "Cygwin" ] ; then 
		nodetool.bat -h localhost -u $user_name -pw $password -p 7199 clearsnapshot
		check_for_errors
	else
		nodetool -h localhost -u $user_name -pw $password -p 7199 clearsnapshot
		check_for_errors
	fi
}

check_for_errors() {
	rc=$?
	if [[ $rc != 0 ]]; then
		exit $rc
	fi
}

finish() {
	echo "Backup file created successfully. Location: $RECOVERY_FILE_DIR/$FILE_NAME"
}

fail() {
	echo "Failed to backup cassandra, check console output for more details"
}

{
init && flush_data_to_disk && await_flush && snapshot_cassandra_database && archive_snapshots_for_backup && remove_snapshot && finish
} || {
	fail
}

