#!/bin/bash
echo "=========================================="
echo "Installing Apache Cassandra 3.11.x"
echo "=========================================="
echo "Removing Datastax Community Edition"
yum remove -y datastax-agent  &> /dev/null
yum remove -y opscenter  &> /dev/null
yum remove -y cassandra22-tools  &> /dev/null
yum remove -y cassandra22  &> /dev/null
yum remove -y dsc22  &> /dev/null
rm -f /etc/yum.repos.d/datastax.repo  &> /dev/null
echo "Creating Apache Cassandra Repository File"
echo "[cassandra]" > /etc/yum.repos.d/cassandra.repo
echo "name=Apache Cassandra" >> /etc/yum.repos.d/cassandra.repo
echo "baseurl=http://www.apache.org/dist/cassandra/redhat/311x/" >> /etc/yum.repos.d/cassandra.repo
echo "gpgcheck=1" >> /etc/yum.repos.d/cassandra.repo
echo "repo_gpgcheck=1" >> /etc/yum.repos.d/cassandra.repo
echo "gpgkey=https://www.apache.org/dist/cassandra/KEYS" >> /etc/yum.repos.d/cassandra.repo
OS=$(cat /etc/redhat-release | cut -f 1 -d " ");
if [ $OS = 'CentOS' ] 
then
	echo "Installing epel-release for CentOS"
	sudo yum -y -q install epel-release
else
	echo "Installing epel-release for RHEL"
	sudo rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sudo yum -y -q update
fi 
yum install -y cassandra
yum install -y cassandra-tools
yum install -y jemalloc
echo "======================="
echo "Configuring firewall"
echo "======================="
FWZONE=$(firewall-cmd --get-default-zone)
echo "Discovered firewall zone $FWZONE"
cat <<EOF > /etc/firewalld/services/cassandra.xml
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
    <short>cassandra</short>
    <description>cassandra</description>
    <port port="7000" protocol="tcp"/>
    <port port="7001" protocol="tcp"/>
	<port port="9042" protocol="tcp"/>
	<port port="9160" protocol="tcp"/>
	<port port="9142" protocol="tcp"/>
</service>
EOF
sleep 30
firewall-cmd --zone=$FWZONE --remove-port=7000/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --remove-port=7001/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --remove-port=7199/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --remove-port=9042/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --remove-port=9160/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --remove-port=9142/tcp --permanent  &> /dev/null
firewall-cmd --zone=$FWZONE --add-service=cassandra --permanent 
firewall-cmd --reload
echo "====================================================="
echo "Changing ownership of data and commit log directories"
echo "====================================================="
mkdir /data &> /dev/null
mkdir /logs &> /dev/null
chown cassandra:cassandra /data &> /dev/null
chown cassandra:cassandra /logs &> /dev/null
echo "====================================================="
echo "Making configuration file changes"
echo "====================================================="
IP_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}')
HOSTNAME=$(hostname)
cp /etc/cassandra/default.conf/cassandra.yaml /etc/cassandra/default.conf/cassandra.yaml.backup
cp /etc/cassandra/default.conf/cassandra.yaml ./cassandra.yaml.template
sed -i "s/ - seeds: \"127.0.0.1\"/ - seeds: \"$IP_ADDRESS\"/g" cassandra.yaml.template
sed -i "s/listen_address:.*/listen_address: $IP_ADDRESS/g" cassandra.yaml.template 
sed -i "s/# broadcast_rpc_address:.*/broadcast_rpc_address: $IP_ADDRESS/g" cassandra.yaml.template 
sed -i "s/broadcast_rpc_address:.*/broadcast_rpc_address: $IP_ADDRESS/g" cassandra.yaml.template 
sed -i "s/# commitlog_total_space_in_mb:.*/commitlog_total_space_in_mb: 8192/g" cassandra.yaml.template 
sed -i "s/commitlog_total_space_in_mb:.*/commitlog_total_space_in_mb: 8192/g" cassandra.yaml.template 
sed -i "s/^rpc_address:.*/rpc_address: 0.0.0.0/g" cassandra.yaml.template
sed -i "s/start_rpc:.*/start_rpc: true/g" cassandra.yaml.template
sed -i "s/thrift_framed_transport_size_in_mb:.*/thrift_framed_transport_size_in_mb: 100/g" cassandra.yaml.template
sed -i "s/commitlog_segment_size_in_mb:.*/commitlog_segment_size_in_mb: 192/g" cassandra.yaml.template
sed -i "s/read_request_timeout_in_ms:.*/read_request_timeout_in_ms: 1800000/g" cassandra.yaml.template
sed -i "s/range_request_timeout_in_ms:.*/range_request_timeout_in_ms: 1800000/g" cassandra.yaml.template
sed -i "s/write_request_timeout_in_ms:.*/write_request_timeout_in_ms: 1800000/g" cassandra.yaml.template
sed -i "s/cas_contention_timeout_in_ms:.*/cas_contention_timeout_in_ms: 1000/g" cassandra.yaml.template
sed -i "s/truncate_request_timeout_in_ms:.*/truncate_request_timeout_in_ms: 1800000/g" cassandra.yaml.template
sed -i "s/request_timeout_in_ms:.*/request_timeout_in_ms: 1800000/g" cassandra.yaml.template
sed -i "s/batch_size_warn_threshold_in_kb:.*/batch_size_warn_threshold_in_kb: 3000/g" cassandra.yaml.template
sed -i "s/batch_size_fail_threshold_in_kb:.*/batch_size_fail_threshold_in_kb: 5000/g" cassandra.yaml.template
sed -i '/data_file_directories:.*/!b;n;c\ \ \ \ - \/data\/data' cassandra.yaml.template  
sed -i "s/hints_directory:.*/hints_directory: \/data\/hints/g" cassandra.yaml.template 
sed -i "s/commitlog_directory:.*/commitlog_directory: \/logs\/commitlog/g" cassandra.yaml.template 
sed -i "s/saved_caches_directory:.*/saved_caches_directory: \/data\/saved_caches/g" cassandra.yaml.template 
\cp -fR ./cassandra.yaml.template /etc/cassandra/default.conf/cassandra.yaml 
# Apply fix to systemd vulnerability preventing service control of cassandra
cat << EOF > /etc/systemd/system/cassandra.service
[Unit]
Description=Apache Cassandra
After=network.target

[Service]
PIDFile=/var/run/cassandra/cassandra.pid
User=cassandra
Group=cassandra
ExecStart=/usr/sbin/cassandra -f -p /var/run/cassandra/cassandra.pid
Restart=always
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF
sleep 30
chkconfig --del cassandra
systemctl daemon-reload
systemctl enable cassandra

