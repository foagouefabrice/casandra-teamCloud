#!/bin/bash

dir=$1
dir_path=$2
commitlog_param=$3
commitlog_path=$4
rf_param=$5
rf=$6
cassandra_param=$7
cassandra_dir=$8

osname=$(uname -o)

wait_s=30

user_name=cassandra
password=cassandra

COMMITLOG_DIR=$commitlog_path
DATABASE_DIR=$cassandra_database
CASSANDRA_PATH=$cassandra
CASSANDRA_AS_SERVICE=$service
RECOVERY_FILE=$rf

init() {
	init_database_dir
	init_commitlog_dir
	init_cassandra_home
	init_recovery_file
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

init_commitlog_dir() {
	if [ ! -d "COMMITLOG_DIR" ]; then
		if [ "$commitlog_param" = "-commitlog" ] ; then
			if [ ! -d "$commitlog_path" ]; then
				request_commitlog_dir
			else
				COMMITLOG_DIR=$commitlog_path
			fi
		else
			request_commitlog_dir
		fi
	fi
}

init_recovery_file() {
	if [ ! -f "RECOVERY_FILE" ]; then
		if [ "$rf_param" = "-rf" ] ; then
			if [ ! -f "$rf" ]; then
				request_recovery_file
			else
				RECOVERY_FILE=$rf
			fi
		else
			request_recovery_file
		fi
	fi
}

init_cassandra_home() {
	if [ "$CASSANDRA_AS_SERVICE" = false ] ; then 
		if [ ! -d "CASSANDRA_PATH" ]; then
			if [ "$cassandra_param" = "-cassandra" ] ; then
				if [ ! -d "$cassandra_dir" ]; then
					request_cassandra_home
				else
					COMMITLOG_DIR=$cassandra_dir
				fi
			else
				request_cassandra_home
			fi
		fi
	fi
}

remove_old_data() {
	echo "Removing current data *** DESTRUCTIVE ***" 
	(cd "$DATABASE_DIR/data/"
		find . -type f ! -path "*/snapshots/*" -exec rm -f {} \;
		check_for_errors
		find . -type d ! -path "*/snapshots/*" -iname "*_Idx" -exec rm -rf {} \;
		check_for_errors
	)
}

stop_cassandra() {
	if [ "$CASSANDRA_AS_SERVICE" = '' ] || [ "$CASSANDRA_AS_SERVICE" = true ] ; then 
		echo "Stoping Cassandra service"
		if [ "$osname" = "Cygwin" ] ; then 
			net stop DataStax_Cassandra_Community_server
		else
			systemctl stop cassandra
			echo "Waiting $wait_s seconds for Cassandra to stop"
			sleep $wait_s
			nohup ps aux | grep Cassandra | awk {'print $2'} | xargs kill &
			check_for_errors
		fi
	else
		echo "Stoping Cassandra process"
		if [ "$osname" = "Cygwin" ] ; then 
			wmic PROCESS where "CommandLine like '%cassandra%'" Call Terminate
		else
			nohup ps aux | grep Cassandra | awk {'print $2'} | xargs kill &
			check_for_errors
		fi
	fi
	sleep 5
}

start_cassandra() {
	if [ "$CASSANDRA_AS_SERVICE" = '' ] || [ "$CASSANDRA_AS_SERVICE" = true ] ; then 
		echo "Starting Cassandra service"
		if [ "$osname" = "Cygwin" ] ; then 
			net start DataStax_Cassandra_Community_server
		else
			systemctl start cassandra
		fi
	else
		if [ -d $CASSANDRA_PATH ]; then
			echo "Starting Cassandra process"
			if [ "$osname" = "Cygwin" ] ; then 
				(cd "$CASSANDRA_PATH/bin/"
					cassandra -f & disown
					check_for_errors
				)
			else
				(cd "$CASSANDRA_PATH/bin/"
					./cassandra
					check_for_errors
				)
			fi
		else
			echo "Cassandra home set to: $CASSANDRA_PATH"
			echo "Cassandra home is not set correctly. Example usage: $ cassandra=/opt/cassandra-2.2.5 ./restore_single_node.sh"
			echo "Or you can start Cassandra manually"
		fi
	fi
	echo "Waiting $wait_s seconds for Cassandra"
	sleep $wait_s
}

restore_data() {
	echo "Restoring snapshot data"
	(cd "$DATABASE_DIR/data/"
		for keyspace in `find . -mindepth 2 -maxdepth 2 -type d `; do
			echo "Restoring: $keyspace"
			for snapshot in `find $keyspace -mindepth 2 -maxdepth 2 -type d | sort -nr | head -1`; do
				echo "Copying contents from: $snapshot to: $keyspace"
				find $snapshot -type f ! -path "./esi/*/snapshots/*_Idx*" -exec cp -p {} $keyspace \;
				check_for_errors
				find $snapshot -type d -path "./esi/*/snapshots/*_Idx*" -exec cp -rp {} $keyspace \;
				check_for_errors
			done
		done
	)

	if [ "$CASSANDRA_AS_SERVICE" = '' ] || [ "$CASSANDRA_AS_SERVICE" = true ]; then
		(cd "$DATABASE_DIR"
			if [ ! "$osname" = "Cygwin" ]; then
				chown -R cassandra:cassandra data/
			else
				chown -R Administrators:SYSTEM data/
			fi
		)
	fi
}

clear_commitlog() {
	(cd "$DATABASE_DIR"
		if ls CommitLog* 1> /dev/null 2>&1; then
			commitlog_found
			(cd "$COMMITLOG_DIR"
				rm -f CommitLog*
			)
			check_for_errors
		else
			if [ ! -d "commitlog" ]; then
				(cd "/var/lib/cassandra"
					if [ ! -d "commitlog" ]; then
						commitlog_not_found
					else
						commitlog_found
						(cd "$COMMITLOG_DIR"
							rm -f CommitLog*
							check_for_errors
						)
					fi
				)
			else
				commitlog_found
				(cd "$COMMITLOG_DIR"
					rm -f CommitLog*
					check_for_errors
				)
			fi
		fi
	)
}

commitlog_not_found() {
	echo "Commitlog dir not cleared, please clear it manually"
}

commitlog_found() {
	echo "Removing old commit logs"
}

repair_keyspaces_linux() {
	echo "Repairing cassandra keyspaces"
	sleep $wait_s
	nodetool -h localhost -u $user_name -pw $password -p 7199 repair esi
	nodetool -h localhost -u $user_name -pw $password -p 7199 repair system
	nodetool -h localhost -u $user_name -pw $password -p 7199 repair system_auth
	nodetool -h localhost -u $user_name -pw $password -p 7199 repair system_distributed
	nodetool -h localhost -u $user_name -pw $password -p 7199 repair system_traces
	check_for_errors
}

repair_keyspaces_cygwin() {
	echo "Repairing Cassandra keyspaces"
	nodetool.bat -h localhost -u $user_name -pw $password -p 7199 repair esi
	nodetool.bat -h localhost -u $user_name -pw $password -p 7199 repair system
	nodetool.bat -h localhost -u $user_name -pw $password -p 7199 repair system_auth
	nodetool.bat -h localhost -u $user_name -pw $password -p 7199 repair system_distributed
	nodetool.bat -h localhost -u $user_name -pw $password -p 7199 repair system_traces
	check_for_errors
}

remove_recovery() {
	echo "Removing old snapshots"
	(cd "$DATABASE_DIR/data"
		nohup find . -path "*/snapshots/*" -exec rm -rf {} \; &
		check_for_errors
	)
}

request_recovery_file() {
	need_file=true
	while $need_file; do
    	read -p "Please enter full backup file path. I.e. /home/user/backups/cassandra_backup_2016.07.29.12.23.24.tar: " RECOVERY_FILE
		if [ ! -f "$RECOVERY_FILE" ]; then
			echo "No backup file found $RECOVERY_FILE"
			echo "Wrong file entered."
		else
			need_file=false;
		fi
	done
}

request_cassandra_home() {
	need_dir=true
	while $need_dir; do
    	read -p "Please enter Cassandra home directory. I.e. /opt/cassandra-2.2.5: " CASSANDRA_PATH
		if [ ! -d "$CASSANDRA_PATH/bin/" ]; then
			echo "No directory $CASSANDRA_PATH/bin/"
			echo "Wrong directory entered."
		else
			need_dir=false;
		fi
	done
}

request_commitlog_dir() {
	need_dir=true
	while $need_dir; do
    	read -p "Please enter Cassandra commitlog directory. I.e. /var/lib/cassandra/commitlog: " COMMITLOG_DIR
		if [ ! -d "$COMMITLOG_DIR" ]; then
			echo "No directory $COMMITLOG_DIR"
			echo "Wrong directory entered."
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

recover_snapshot_from_backup() {
	echo "Restoring snapshot from backup"
	(cd "$DATABASE_DIR/data"
		remove_old_data
		clear_commitlog
		tar --same-owner -C "$DATABASE_DIR/data/" -xvf "$RECOVERY_FILE"
		check_for_errors
	)
}

check_for_errors() {
	rc=$?
	if [[ $rc != 0 ]]; then
		exit $rc
	fi
}

repair_keyspaces() {
	if [ "$osname" = "Cygwin" ] ; then
		repair_keyspaces_cygwin
	else
		repair_keyspaces_linux
	fi
}

fail() {
	echo "Database recovery failed, please check console output for more details"
}

finish() {
	echo "Finished snapshot recovery"
}

{
	init && stop_cassandra && recover_snapshot_from_backup && restore_data && remove_recovery && start_cassandra && repair_keyspaces && finish
} || {
	fail
}

