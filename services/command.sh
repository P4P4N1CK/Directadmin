#!/bin/sh

DA_PATH=/usr/local/directadmin
CSB=${DA_PATH}/custombuild

firewall-cmd --zone=public --add-port=21/tcp --permanent
firewall-cmd --zone=public --add-port=22/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload

cd ${DA_PATH}
wget -O ${CSB}/versions.txt https://raw.githubusercontent.com/irf1404/Directadmin/master/services/custombuild/versions.txt
wget -O ${CSB}.tar.gz https://raw.githubusercontent.com/irf1404/Directadmin/master/services/custombuild/custombuild.tar.gz
tar xzf custombuild.tar.gz
