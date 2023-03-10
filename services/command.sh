#!/bin/sh

DA_PATH=/usr/local/directadmin
CSB=${DA_PATH}/custombuild

cd ${DA_PATH}
wget -O ${CSB}/versions.txt https://raw.githubusercontent.com/irf1404/Directadmin/master/services/custombuild/versions.txt
wget -O ${CSB}.tar.gz https://raw.githubusercontent.com/irf1404/Directadmin/master/services/custombuild/custombuild.tar.gz
tar xzf custombuild.tar.gz
