N@lled By: Nguyễn Trung Hậu<br>
Email: ken.hdpro@gmail.com<br>
Facebook: http://fb.com/haunguyenckc<br>
Directadmin 1.604 đã được N@ll chỉ cài được cho centOS 7 64bit còn centOS 8 thì mình không biết :D

# COMMON PRE-INSTALL COMMANDS
```
# Pre-Install CentOS 7
yum -y install wget tar gcc gcc-c++ flex bison make bind bind-libs bind-utils openssl openssl-devel perl quota libaio \
libcom_err-devel libcurl-devel gd zlib-devel zip unzip libcap-devel cronie bzip2 cyrus-sasl-devel perl-ExtUtils-Embed \
autoconf automake libtool which patch mailx bzip2-devel lsof glibc-headers kernel-devel expat-devel \
psmisc net-tools systemd-devel libdb-devel perl-DBI perl-Perl4-CoreLibs perl-libwww-perl xfsprogs rsyslog logrotate \
crontabs file kernel-headers ipset

```

# INSTALL DIRECTADMIN ONLY CENTOS7 64BIT
```
# Directadmin 1.604 For Centos7
wget -O setup.sh "https://raw.githubusercontent.com/irf1404/Directadmin/master/da-1604-centos7.sh" && chmod +x setup.sh && ./setup.sh

```


# OPEN PORT FOR DIRECTADMIN
```
# Open Port 21,22,80,443,2222,3306
firewall-cmd --zone=public --add-port=21/tcp --permanent
firewall-cmd --zone=public --add-port=22/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload

```