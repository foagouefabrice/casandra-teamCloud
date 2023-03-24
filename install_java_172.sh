#!/bin/bash
echo "=========================================="
echo "Installing Oracle Java 1.8.0_172"
echo "=========================================="
echo ""
echo "  Oracle Java can no longer be dowloaded directly due to new authentication requirements"
echo "  After manually downloading jdk-8u172-linux-x64.tar.gz, copy it to this directory"
echo ""
echo "  Archive downloads available from https://www.oracle.com/java/technologies/javase/javase8-archive-downloads.html"
echo ""
read -p -"Press any key to continue, Ctl-C to exit ...: " -n1 -s
echo "==========================================" 
sudo mkdir -p /opt/local/java
sudo tar xzf jdk-8u172-linux-x64.tar.gz -C /opt/local/java
cd /opt/local/java/jdk1.8.0_172/
sudo alternatives --install /usr/bin/java java /opt/local/java/jdk1.8.0_172/bin/java 2
sudo alternatives --config java
sudo alternatives --install /usr/bin/jar jar /opt/local/java/jdk1.8.0_172/bin/jar 2
sudo alternatives --install /usr/bin/javac javac /opt/local/java/jdk1.8.0_172/bin/javac 2
sudo alternatives --set jar /opt/local/java/jdk1.8.0_172/bin/jar
sudo alternatives --set javac /opt/local/java/jdk1.8.0_172/bin/javac
sudo echo 'JAVA_HOME=/opt/local/java/jdk1.8.0_172' > /etc/environment
sudo echo 'JRE_HOME=/opt/local/java/jdk1.8.0_172/jre' >> /etc/environment
sudo chown -R root:root /opt/local/java/jdk1.8.0_172