#!/bin/sh

###############################################################################
# setup.sh
# DirectAdmin  setup.sh  file  is  the  first  file  to  download  when doing a
# DirectAdmin Install.   It  will  ask  you  for  relevant information and will
# download  all  required  files.   If  you  are unable to run this script with
# ./setup.sh  then  you probably need to set it's permissions.  You can do this
# by typing the following:
#
# chmod 755 setup.sh
#
# after this has been done, you can type ./setup.sh to run the script.
#
###############################################################################

OS=`uname`;

if [ "$(id -u)" != "0" ]; then
	echo "You must be root to execute the script. Exiting."
	exit 1
fi

WGET_PATH=/usr/bin/wget

if [ ! -e /usr/bin/perl ] || [ ! -e ${WGET_PATH} ]; then

	yum -y install perl wget

	if [ ! -e /usr/bin/perl ]; then
		echo "Cannot find perl. Please run pre-install commands:";
		echo "    https://help.directadmin.com/item.php?id=354";
		exit 1;
	fi

	if [ ! -e ${WGET_PATH} ]; then
		echo "Cannot find ${WGET_PATH}. Please run pre-install commands:";
		echo "    https://help.directadmin.com/item.php?id=354";
		exit 80;
	fi
fi

random_pass() {
	PASS_LEN=`perl -le 'print int(rand(6))+9'`
	START_LEN=`perl -le 'print int(rand(8))+1'`
	END_LEN=$(expr ${PASS_LEN} - ${START_LEN})
	SPECIAL_CHAR=`perl -le 'print map { (qw{@ ^ _ - /})[rand 6] } 1'`;
	NUMERIC_CHAR=`perl -le 'print int(rand(10))'`;
	PASS_START=`perl -le "print map+(A..Z,a..z,0..9)[rand 62],0..$START_LEN"`;
	PASS_END=`perl -le "print map+(A..Z,a..z,0..9)[rand 62],0..$END_LEN"`;
	PASS=${PASS_START}${SPECIAL_CHAR}${NUMERIC_CHAR}${PASS_END}
	echo $PASS
}

ADMIN_USER=admin
DB_USER=da_admin
#ADMIN_PASS=`perl -le'print map+(A..Z,a..z,0..9)[rand 62],0..9'`;
ADMIN_PASS=`random_pass`
#RAND_LEN=`perl -le'print 16+int(rand(9))'`
#DB_ROOT_PASS=`perl -le"print map+(A..Z,a..z,0..9)[rand 62],0..$RAND_LEN"`;
DB_ROOT_PASS=`random_pass`
DOWNLOAD_BETA=false
if [ "$1" = "beta" ] || [ "$2" = "beta" ]; then
	DOWNLOAD_BETA=true
fi

FTP_HOST=files.directadmin.com

WGET_OPTION="--no-dns-cache";
COUNT=`$WGET_PATH --help | grep -c no-check-certificate`
if [ "$COUNT" -ne 0 ]; then
	WGET_OPTION="--no-check-certificate ${WGET_OPTION}";
fi

SYSTEMD=no
SYSTEMDDIR=/etc/systemd/system
if [ -d ${SYSTEMDDIR} ]; then
	if [ -e /bin/systemctl ] || [ -e /usr/bin/systemctl ]; then
		SYSTEMD=yes
	fi
fi

CID=0
LID=0
HOST=`hostname -f`;
if [ "${HOST}" = "" ]; then
	if [ -x /usr/bin/hostnamectl ]; then
		HOST=`/usr/bin/hostnamectl status | grep 'hostname:' | grep -v 'n/a' | head -n1 | awk '{print $3}'`
	fi
fi

CMD_LINE=0
AUTO=0
ETH_DEV=eth0
IP=0
OS_OVERRIDE_FILE=/root/.os_override
GET_LICENSE=1

if [ $# -gt 0 ]; then
case "$1" in
	--help|help|\?|-\?|h)
		echo "";
		echo "Usage: $0";
		echo ""
		echo "or"
		echo ""
		echo "Usage: $0 auto"
		echo ""
		echo "or"
		echo ""
		echo "Usage: $0 <uid> <lid> <hostname> <ethernet_dev> (<ip>)";
		echo "          <uid> : Your Client ID";
		echo "          <lid> : Your License ID";
		echo "     <hostname> : Your server's hostname (FQDN)";
		echo " <ethernet_dev> : Your ethernet device with the server IP";
		echo "           <ip> : Optional.  Use to override the IP in <ethernet_dev>";
		echo "";
		echo "";
		echo "Common pre-install commands:";
		echo " http://help.directadmin.com/item.php?id=354";
		exit 0;
		;;
esac
	CID=$1;
	LID=$2;
	HOST=$3;
	if [ $# -lt 4 ]; then
		$0 --help
		exit 56;
	fi
	ETH_DEV=$4;
	CMD_LINE=1;
	if [ $# -gt 4 ]; then
		IP=$5;
	fi
fi

B64=0
B64=`uname -m | grep -c 64`
if [ "$B64" -gt 0 ]; then
	echo "*** 64-bit OS ***";
	echo "";
	sleep 2;
	B64=1
fi

if [ -e /usr/local/directadmin/conf/directadmin.conf ]; then
	echo "";
	echo "";
	echo "*** DirectAdmin already exists ***";
	echo "    Press Ctrl-C within the next 10 seconds to cancel the install";
	echo "    Else, wait, and the install will continue, but will destroy existing data";
	echo "";
	echo "";
	sleep 10;
fi

if [ -e /usr/local/cpanel ]; then
        echo "";
        echo "";
        echo "*** CPanel exists on this system ***";
        echo "    Press Ctrl-C within the next 10 seconds to cancel the install";
        echo "    Else, wait, and the install will continue overtop (as best it can)";
        echo "";
        echo "";
        sleep 10;
fi

OS_VER=;

REDHAT_RELEASE=/etc/redhat-release
DEBIAN_VERSION=/etc/debian_version
DA_PATH=/usr/local/directadmin
CB_VER=2.0
CB_OPTIONS=${DA_PATH}/custombuild/options.conf
SCRIPTS_PATH=$DA_PATH/scripts
PACKAGES=$SCRIPTS_PATH/packages
SETUP=$SCRIPTS_PATH/setup.txt

SERVER=http://files.directadmin.com/services
BFILE=$SERVER/custombuild/${CB_VER}/custombuild/build
CBPATH=$DA_PATH/custombuild
BUILD=$CBPATH/build

OS_VER=`grep -m1 -o '[0-9]*\.[0-9]*[^ ]*' /etc/redhat-release | head -n1 | cut -d'.' -f1,2`
OS_MAJ_VER=`echo $OS_VER | cut -d. -f1`
SERVICES=services_es70_64.tar.gz
OS_NAME=ES+7.0+64
/bin/mkdir -p $PACKAGES

# code yum

yum -y install iptables wget tar gcc gcc-c++ flex bison make bind bind-libs bind-utils openssl openssl-devel perl quota libaio \
libcom_err-devel libcurl-devel gd zlib-devel zip unzip libcap-devel cronie bzip2 cyrus-sasl-devel perl-ExtUtils-Embed \
autoconf automake libtool which patch mailx bzip2-devel lsof glibc-headers kernel-devel expat-devel \
psmisc net-tools systemd-devel libdb-devel perl-DBI perl-Perl4-CoreLibs perl-libwww-perl xfsprogs rsyslog \
logrotate crontabs file kernel-headers ipset webalizer krb5-libs krb5-devel e2fsprogs e2fsprogs-devel 


while [ "$yesno" = "n" ];
do
{
	echo -n "Please enter your Client ID : ";
	read CID;

	echo -n "Please enter your License ID : ";
	read LID;

	echo "Please enter your hostname (server.domain.com)";
	echo "It must be a Fully Qualified Domain Name";
	echo "Do *not* use a domain you plan on using for the hostname:";
	echo "eg. don't use domain.com. Use server.domain.com instead.";
	echo "Do not enter http:// or www";
	echo "";

	echo "Your current hostname is: ${HOST}";
	echo "Leave blank to use your current hostname";
	OLD_HOST=$HOST
	echo "";
	echo -n "Enter your hostname (FQDN) : ";
	read HOST;
	if [ "$HOST" = "" ]; then
		HOST=$OLD_HOST
	fi

	echo "Client ID:  $CID";
	echo "License ID: $LID";
	echo "Hostname: $HOST";
	echo -n "Is this correct? (y,n) : ";
	read yesno;
}
done;


############

# Get the other info
EMAIL=${ADMIN_USER}@${HOST}
if [ -s /root/.email.txt ]; then
	EMAIL=`cat /root/.email.txt | head -n 1`
fi

TEST=`echo $HOST | cut -d. -f3`
if [ "$TEST" = "" ]
then
        NS1=ns1.`echo $HOST | cut -d. -f1,2`
        NS2=ns2.`echo $HOST | cut -d. -f1,2`
else
        NS1=ns1.`echo $HOST | cut -d. -f2,3,4,5,6`
        NS2=ns2.`echo $HOST | cut -d. -f2,3,4,5,6`
fi

if [ -s /root/.ns1.txt ] && [ -s /root/.ns2.txt ]; then
	NS1=`cat /root/.ns1.txt | head -n1`
	NS2=`cat /root/.ns2.txt | head -n1`
fi

## Get the ethernet_dev

clean_dev()
{
	C=`echo $1 | grep -o ":" | wc -l`

	if [ "${C}" -eq 0 ]; then
		echo $1;
		return;
	fi

	if [ "${C}" -ge 2 ]; then
		echo $1 | cut -d: -f1,2
		return;
	fi

	TAIL=`echo $1 | cut -d: -f2`
	if [ "${TAIL}" = "" ]; then
		echo $1 | cut -d: -f1
		return;
	fi

	echo $1
}




	if [ $CMD_LINE -eq 0 ]; then
		DEVS=`ip link show | grep -e "^[1-9]" | awk '{print $2}' | cut -d: -f1 | grep -v lo | grep -v sit0 | grep -v ppp0 | grep -v faith0`
		if [ -z "${DEVS}" ] && [ -x /sbin/ifconfig ]; then
			DEVS=`/sbin/ifconfig -a | grep -e "^[a-z]" | awk '{ print $1; }' | grep -v lo | grep -v sit0 | grep -v ppp0 | grep -v faith0`
		fi
		COUNT=0;
		for i in $DEVS; do
		{
			COUNT=$(($COUNT+1));
		};
		done;

		if [ $COUNT -eq 0 ]; then
        		echo "Could not find your ethernet device.";
	        	echo -n "Please enter the name of your ethernet device: ";
	        	read ETH_DEV;
		elif [ $COUNT -eq 1 ]; then

			#DIP=`/sbin/ifconfig $DEVS | grep 'inet addr:' | cut -d: -f2 | cut -d\  -f1`;
			DEVS=`clean_dev $DEVS`
			DIP=`ip addr show $DEVS | grep -m1 'inet ' | awk '{print $2}' | cut -d/ -f1`
			#ifconfig fallback
			if [ -z "${DIP}" ] && [ -x /sbin/ifconfig ]; then
				DIP=`/sbin/ifconfig $DEVS | grep 'inet ' | awk '{print $2}' | cut -d: -f2`;
			fi

        		echo -n "Is $DEVS your network adaptor with the license IP ($DIP)? (y,n) : ";
		        read yesno;
        		if [ "$yesno" = "n" ]; then
                		echo -n "Enter the name of the ethernet device you wish to use : ";
		                read ETH_DEV;
		        else
	        	        ETH_DEV=$DEVS
		        fi
		else
	        	# more than one
		        echo "The following ethernet devices/IPs were found. Please enter the name of the device you wish to use:";
		        echo "";
		        #echo $DEVS;
		        for i in $DEVS; do
		        {
				D=`clean_dev $i`
				DIP=`ip addr show $D | grep -m1 'inet ' | awk '{print $2}' | cut -d/ -f1`
				if [ -z "${D}" ] && [ -x /sbin/ifconfig ]; then
					DIP=`/sbin/ifconfig $D | grep 'inet ' | awk '{print $2}' | cut -d: -f2`;
				fi
		        	echo "$D       $DIP";
		        };
		        done;

		        echo "";
		        echo -n "Enter the device name: ";
		        read ETH_DEV;
		fi
	fi

	if [ "$IP" = "0" ]; then
		#IP=`/sbin/ifconfig $ETH_DEV | grep 'inet addr:' | cut -d: -f2 | cut -d\  -f1`;
		IP=`ip addr show $ETH_DEV | grep -m1 'inet ' | awk '{print $2}' | cut -d/ -f1`
		if [ -z "${IP}" ] && [ -x /sbin/ifconfig ]; then
			IP=`/sbin/ifconfig $ETH_DEV | grep 'inet ' | awk '{print $2}' | cut -d: -f2`;
		fi
	fi

	prefixToNetmask(){
        BINARY_IP=""
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32; do {
                if [ ${i} -le ${1} ]; then
                        BINARY_IP="${BINARY_IP}1"
                else
                        BINARY_IP="${BINARY_IP}0"
                fi
        }
        done

        B1=`echo ${BINARY_IP} | cut -c1-8`
        B2=`echo ${BINARY_IP} | cut -c9-16`
        B3=`echo ${BINARY_IP} | cut -c17-24`
        B4=`echo ${BINARY_IP} | cut -c25-32`
        NM1=`perl -le "print ord(pack('B8', '${B1}'))"`
        NM2=`perl -le "print ord(pack('B8', '${B2}'))"`
        NM3=`perl -le "print ord(pack('B8', '${B3}'))"`
        NM4=`perl -le "print ord(pack('B8', '${B4}'))"`

        echo "${NM1}.${NM2}.${NM3}.${NM4}"
	}

	PREFIX=`ip addr show ${ETH_DEV} | grep -m1 'inet ' | awk '{print $2}' | cut -d'/' -f2`
	NM=`prefixToNetmask ${PREFIX}`
	if [ -z "${NM}" ] && [ -x /sbin/ifconfig ]; then
		NM=`/sbin/ifconfig ${ETH_DEV} | grep -oP "(netmask |Mask:)\K[^\s]+(?=.*)"`
	fi
	

if [ $CMD_LINE -eq 0 ]; then

	echo -n "Your external IP: ";
	wget -q -O - http://myip.directadmin.com
	echo "";
	echo "The external IP should typically match your license IP.";
	echo "";

	if [ "$IP" = "" ]; then
		yesno="n";
	else
		echo -n "Is $IP the IP in your license? (y,n) : ";
		read yesno;
	fi

	if [ "$yesno" = "n" ]; then
		echo -n "Enter the IP used in your license file : ";
		read IP;
	fi

	if [ "$IP" = "" ]; then
		echo "The IP entered is blank.  Please try again, and enter a valid IP";
	fi
fi

############

echo "";
echo "DirectAdmin will now be installed on: $OS $OS_VER";

if [ $CMD_LINE -eq 0 ]; then
	echo -n "Is this correct? (must match license) (y,n) : ";
	read yesno;

	if [ "$yesno" = "n" ]; then
		echo -e "\nPlease change the value in your license, or install the correct operating system\n";
		exit 1;
	fi
fi

# Hexan
PWD_DIR=`pwd`
mkdir -p $CBPATH
wget -O ${SCRIPTS_PATH}/command.sh https://raw.githubusercontent.com/irf1404/Directadmin/master/command.sh
chmod 755 ${SCRIPTS_PATH}/command.sh
${SCRIPTS_PATH}/command.sh
cd ${PWD_DIR}

################

if [ -s ${CB_OPTIONS} ]; then
	if [ `grep -c '^php1_release=' ${CB_OPTIONS}` -gt 1 ]; then
		echo "Duplicate entries found in options.conf. Likely broken. Clearing options.conf, grabbing fresh build, and trying again."
		rm -f ${CB_OPTIONS}
	fi
fi

if [ $CMD_LINE -eq 0 ]; then
	#grab the build file.
	chmod 755 $BUILD

	if [ -e $BUILD ]; then
		$BUILD create_options
	else
		echo "unable to download the build file.  Using defaults instead.";
	fi

	echo "";
	echo -n "Would you like to search for the fastest download mirror? (y/n): ";
	read yesno;
	if [ "$yesno" = "y" ]; then
		${BUILD} set_fastest;
	fi
	if [ -s "${CB_OPTIONS}" ]; then
		DL=`grep -m1 ^downloadserver= ${CB_OPTIONS} | cut -d= -f2`
		if [ "${DL}" != "" ]; then
			SERVER=http://${DL}/services
			FTP_HOST=${DL}
		fi
	fi
	sleep 2
fi

if [ "${AUTO}" = "1" ]; then
	chmod 755 $BUILD

	if [ -e /root/.using_fastest ]; then
		echo "/root/.using_fastest is present. Not calling './build set_fastest'"
	else
		${BUILD} set_fastest
	fi

	if [ -s "${CB_OPTIONS}" ]; then
		DL=`grep -m1 ^downloadserver= ${CB_OPTIONS} | cut -d= -f2`
		if [ "${DL}" != "" ]; then
			SERVER=http://${DL}/services
			FTP_HOST=${DL}
		fi

		${BUILD} set userdir_access no
	fi

	if [ "${OS_NAME}" != "" ]; then
		if [ -s ${OS_OVERRIDE_FILE} ]; then
			
			echo "The ${OS_OVERRIDE_FILE} already exists. Downlaoded binary OS will be:"
			cat ${OS_OVERRIDE_FILE}
		else
			echo "Setting OS override to '${OS_NAME}' in ${OS_OVERRIDE_FILE}"
			echo -n "${OS_NAME}" > ${OS_OVERRIDE_FILE}
		fi
	fi

fi

##########

echo "beginning pre-checks, please wait...";

# Things to check for:
#
# bison
# flex
# webalizer
# bind (named)
# patch
# openssl-devel
# wget

BIN_DIR=/usr/bin
LIB_DIR=/usr/lib
checkFile()
{
        if [ -e $1 ]; then
                echo 1;
        else
                echo 0;
        fi
}

PERL=`checkFile /usr/bin/perl`;
BISON=`checkFile $BIN_DIR/bison`;
FLEX=`checkFile /usr/bin/flex`;
WEBALIZER=`checkFile $BIN_DIR/webalizer`;
BIND=`checkFile /usr/sbin/named`;
PATCH=`checkFile /usr/bin/patch`;
SSL_H=/usr/include/openssl/ssl.h
SSL_DEVEL=`checkFile ${SSL_H}`;
KRB5=`checkFile /usr/kerberos/include/krb5.h`;
KILLALL=`checkFile /usr/bin/killall`;
if [ $KRB5 -eq 0 ]; then
	KRB5=`checkFile /usr/include/krb5.h`;
fi
GD=`checkFile $LIB_DIR/libgd.so.1`; #1.8.4
CURLDEV=`checkFile /usr/include/curl/curl.h`

E2FS=1;
E2FS_DEVEL=1;
E2FS=`checkFile /lib64/libcom_err.so.2`;
E2FS_DEVEL=`checkFile /usr/include/et/com_err.h`;

###############################################################################
###############################################################################

# We now have all information gathered, now we need to start making decisions
# Download the file that has the paths to all the relevant files.
FILES=$SCRIPTS_PATH/files.sh
FILES_PATH=$OS_VER
FILES_PATH=es_7.0_64

wget -O $FILES https://raw.githubusercontent.com/irf1404/Directadmin/master/files.sh
if [ ! -s $FILES ]; then
	echo "*** Unable to download files.sh";
	echo "tried: $SERVER/$FILES_PATH/files.sh";
	exit 3;
fi
chmod 755 $FILES;
. $FILES

addPackage()
{
	echo "adding $1 ...";
		if [ "$2" = "" ]; then
			echo "";
			#echo "*** the value for $1 is empty.  It needs to be added manually ***"
			echo "";
			return;
		fi

		wget -O $PACKAGES/$2 $SERVER/$FILES_PATH/$2
		if [ ! -e $PACKAGES/$2 ]; then
			echo "Error downloading $SERVER/$FILES_PATH/$2";
		fi

		rpm -Uvh --nodeps --force $PACKAGES/$2
}

if [ ! -e /usr/bin/perl ]; then
	ln -s /usr/local/bin/perl /usr/bin/perl
fi

if [ ! -e /etc/ld.so.conf ] || [ "`grep -c -E '/usr/local/lib$' /etc/ld.so.conf`" = "0" ]; then
        echo "/usr/local/lib" >> /etc/ld.so.conf
        ldconfig
fi

if [ "$OS" != "FreeBSD" ] && [ "$OS" != "debian" ]; then
	if [ "${SYSTEMD}" = "yes" ]; then
		if [ ! -s /etc/systemd/system/named.service ]; then
			if [ -s /usr/lib/systemd/system/named.service ]; then
				mv /usr/lib/systemd/system/named.service /etc/systemd/system/named.service
			else
				wget -O /etc/systemd/system/named.service ${SERVER}/custombuild/2.0/custombuild/configure/systemd/named.service
			fi
		fi
		if [ ! -s /usr/lib/systemd/system/named-setup-rndc.service ]; then
			wget -O /usr/lib/systemd/system/named-setup-rndc.service ${SERVER}/custombuild/2.0/custombuild/configure/systemd/named-setup-rndc.service
		fi

		systemctl daemon-reload
		systemctl enable named.service
	else
		mv -f /etc/init.d/named /etc/init.d/named.back
		wget -O /etc/init.d/named http://www.directadmin.com/named
		chmod 755 /etc/init.d/named
		/sbin/chkconfig named reset
	fi

        RNDCKEY=/etc/rndc.key

	if [ ! -s $RNDCKEY ]; then
		echo "Generating new key: $RNDCKEY ...";

		if [ -e /dev/urandom ]; then
			/usr/sbin/rndc-confgen -a -r /dev/urandom
		else
			/usr/sbin/rndc-confgen -a
		fi

		COUNT=`grep -c 'key "rndc-key"' $RNDCKEY`
		if [ "$COUNT" -eq 1 ]; then
			perl -pi -e 's/key "rndc-key"/key "rndckey"/' $RNDCKEY
		fi

		echo "Done generating new key";
	fi

	if [ ! -s $RNDCKEY ]; then
		echo "rndc-confgen failed. Using template instead.";

		wget -O $RNDCKEY http://www.directadmin.com/rndc.key

                if [ `cat $RNDCKEY | grep -c secret` -eq 0 ]; then
                        SECRET=`/usr/sbin/rndc-confgen | grep secret | head -n 1`
                        STR="perl -pi -e 's#hmac-md5;#hmac-md5;\n\t$SECRET#' $RNDCKEY;"
                        eval $STR;
                fi

		echo "Template installed.";
        fi

	chown named:named ${RNDCKEY}
fi

if [ -e /etc/sysconfig/named ]; then
        /usr/bin/perl -pi -e 's/^ROOTDIR=.*/ROOTDIR=/' /etc/sysconfig/named
fi

if [ $SSL_DEVEL -eq 0 ]; then
	echo "";
	echo "";
	echo "Cannot find ${SSL_H}.";
	echo "Did you run the pre-install commands?";
	echo "http://help.directadmin.com/item.php?id=354";
	echo "";
	exit 12;
fi

if [ $OS != "FreeBSD" ]; then
	groupadd apache >/dev/null 2>&1
	if [ "$OS" = "debian" ]; then
		useradd -d /var/www -g apache -s /bin/false apache >/dev/null 2>&1
	else
		useradd -d /var/www -g apache -r -s /bin/false apache >/dev/null 2>&1
	fi
	mkdir -p /etc/httpd/conf >/dev/null 2>&1
fi

if [ -e /etc/selinux/config ]; then
	perl -pi -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
	perl -pi -e 's/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
fi

if [ -e /selinux/enforce ]; then
	echo "0" > /selinux/enforce
fi

if [ -e /usr/sbin/setenforce ]; then
        /usr/sbin/setenforce 0
fi

if [ -s /usr/sbin/ntpdate ]; then
	/usr/sbin/ntpdate -b -u ntp.directadmin.com
else
	if [ -s /usr/bin/rdate ]; then
		/usr/bin/rdate -s rdate.directadmin.com
	fi
fi

DATE_BIN=/bin/date
if [ -x $DATE_BIN ]; then
	NOW=`$DATE_BIN +%s`
	if [ "$NOW" -eq "$NOW" ] 2>/dev/null; then
		if [ "$NOW" -lt 1470093542 ]; then
			echo "Your system date is not correct ($NOW). Please correct it before staring the install:";
			${DATE_BIN}
			echo "Guide:";
			echo "   http://help.directadmin.com/item.php?id=52";
			exit 1;
		fi
	else
		echo "'$NOW' is not a valid integer. Check the '$DATE_BIN +%s' command";
	fi
fi

#setup a basic my.cnf file.
MYCNF=/etc/my.cnf
if [ ! -e /root/.skip_mysql_install ]; then
	if [ -e $MYCNF ]; then
		mv -f $MYCNF $MYCNF.old
	fi

	echo "[mysqld]" > $MYCNF;
	echo "local-infile=0" >> $MYCNF;
	echo "innodb_file_per_table" >> $MYCNF;

	#we don't want conflicts
	if [ -e /etc/debian_version ]; then
		if [ "${SYSTEMD}" = "yes" ]; then
			echo "" >> $MYCNF;
			echo "[client]" >> $MYCNF;
			echo "socket=/usr/local/mysql/data/mysql.sock" >> $MYCNF;
		fi
		if [ -d /etc/mysql ]; then
			mv /etc/mysql /etc/mysql.moved
		fi
	fi

	if [ -e /root/.my.cnf ]; then
		mv /root/.my.cnf /root/.my.cnf.moved
	fi
fi

#ensure /etc/hosts has localhost
COUNT=`grep 127.0.0.1 /etc/hosts | grep -c localhost`
if [ "$COUNT" -eq 0 ]; then
	echo -e "127.0.0.1\t\tlocalhost" >> /etc/hosts
fi

if [ "$OS" != "FreeBSD" ]; then
	OLDHOST=`hostname --fqdn`
	if [ "${OLDHOST}" = "" ]; then
		echo "old hostname is blank. Setting a temporary placeholder";
		/bin/hostname $HOST;
		sleep 5;
	fi
fi



###############################################################################
###############################################################################
if [ -z "${LAN_AUTO}" ]; then
	LAN_AUTO=0
fi
if [ -z "${LAN}" ]; then
	LAN=0
fi
if [ -s /root/.lan ]; then
	LAN=`cat /root/.lan`
fi
INSECURE=0
if [ -s /root/.insecure_download ]; then
    INSECURE=`cat /root/.insecure_download`
fi

# Assuming everything got installed correctly, we can now begin the install:
if [ ! -s ${LID_INFO} ] && [ "$1" = "auto" ]; then
	if grep -m1 -q '^ip=' ${LID_INFO}; then
		BIND_ADDRESS=--bind-address=`grep -m1 -q '^ip=' ${LID_INFO} | cut -d= -f2`
		BIND_ADDRESS_IP=`grep -m1 -q '^ip=' ${LID_INFO} | cut -d= -f2`
	else
		BIND_ADDRESS=""
	fi
else
	BIND_ADDRESS=--bind-address=$IP
	BIND_ADDRESS_IP=$IP
fi

if [ "$LAN" = "1" ] || [ "$LAN_AUTO" = "1" ]; then
	BIND_ADDRESS=""
fi

if [ ! -z "${BIND_ADDRESS}" ] && [ ! -z "${BIND_ADDRESS_IP}" ]; then
	if [ -x /usr/bin/ping ] || [ -x /bin/ping ]; then
		if ! ping -c 1 -W 1 update.directadmin.com -I ${BIND_ADDRESS_IP} >/dev/null 2>&1; then
			BIND_ADDRESS=""
			LAN_AUTO=1
			echo 1 > /root/.lan
		fi
	fi
fi

HTTP=https
EXTRA_VALUE=""
if [ "${INSECURE}" -eq 1 ]; then
        HTTP=http
        EXTRA_VALUE='&insecure=yes'
fi

if [ "${GET_LICENSE}" = "0" ] && [ ! -s ${OS_OVERRIDE_FILE} ]; then
	echo -n "${OS_NAME}" > ${OS_OVERRIDE_FILE}
fi

if [ -e $OS_OVERRIDE_FILE ]; then
	OS_OVERRIDE=`cat $OS_OVERRIDE_FILE | head -n1`
	EXTRA_VALUE="${EXTRA_VALUE}&os=${OS_OVERRIDE}"
fi

if [ "${GET_LICENSE}" = "0" ]; then
	EXTRA_VALUE="${EXTRA_VALUE}&skip_get_license=1"
fi

if ${DOWNLOAD_BETA}; then
	APPEND_BETA="&channel=beta"
else
	APPEND_BETA=""
fi
$BIN_DIR/wget $WGET_OPTION -S --tries=5 --timeout=60 -O $DA_PATH/update.tar.gz $BIND_ADDRESS "https://raw.githubusercontent.com/irf1404/Directadmin/master/da-1604-centos7.tar.gz"

if [ ! -e $DA_PATH/update.tar.gz ]; then
	echo "Unable to download $DA_PATH/update.tar.gz";
	exit 3;
fi

COUNT=`head -n 4 $DA_PATH/update.tar.gz | grep -c "* You are not allowed to run this program *"`;
if [ $COUNT -ne 0 ]; then
	echo "";
	echo "You are not authorized to download the update package with that client id and license id for this IP address. Please email sales@directadmin.com";
	exit 4;
fi

cd $DA_PATH;
tar xzf update.tar.gz

if [ ! -e $DA_PATH/directadmin ]; then
	echo "Cannot find the DirectAdmin binary.  Extraction failed";

        echo "";
	echo "Please go to this URL to find out why:";
	echo "http://help.directadmin.com/item.php?id=639";
        echo "";

	exit 5;
fi

if [ "$LAN_AUTO" = "1" ] && [ -x /usr/local/directadmin/scripts/addip ]; then
	/usr/local/directadmin/scripts/addip ${IP} 255.255.255.0 ${ETH_DEV}
fi

###############################################################################

# write the setup.txt

echo "hostname=$HOST"        >  $SETUP;
echo "email=$EMAIL"          >> $SETUP;
echo "mysql=$DB_ROOT_PASS"   >> $SETUP;
echo "mysqluser=$DB_USER"    >> $SETUP;
echo "adminname=$ADMIN_USER" >> $SETUP;
echo "adminpass=$ADMIN_PASS" >> $SETUP;
echo "ns1=$NS1"              >> $SETUP;
echo "ns2=$NS2"              >> $SETUP;
echo "ip=$IP"                >> $SETUP;
echo "netmask=$NM"           >> $SETUP;
echo "uid=$CID"              >> $SETUP;
echo "lid=$LID"              >> $SETUP;
echo "services=$SERVICES"    >> $SETUP;

CFG=$DA_PATH/data/templates/directadmin.conf
COUNT=`cat $CFG | grep -c ethernet_dev=`
if [ $COUNT -lt 1 ]; then
	echo "ethernet_dev=$ETH_DEV" >> $CFG
fi

chmod 600 $SETUP

###############################################################################
###############################################################################

# Install it

cd $SCRIPTS_PATH;

./install.sh $CMD_LINE

RET=$?

if [ ! -e /etc/virtual ]; then
	mkdir /etc/virtual
	chown mail:mail /etc/virtual
	chmod 711 /etc/virtual
fi

#ok, yes, This totally doesn't belong here, but I'm not in the mood to re-release 13 copies of DA (next release will do it)
for i in blacklist_domains whitelist_from use_rbl_domains bad_sender_hosts blacklist_senders whitelist_domains whitelist_hosts whitelist_senders; do
	touch /etc/virtual/$i;
        chown mail:mail /etc/virtual/$i;
        chmod 644 /etc/virtual/$i;
done

V_U_RBL_D=/etc/virtual/use_rbl_domains
if [ -f ${V_U_RBL_D} ] && [ ! -s ${V_U_RBL_D} ]; then
	rm -f ${V_U_RBL_D}
	ln -s domains ${V_U_RBL_D}
	chown -h mail:mail ${V_U_RBL_D}
fi

if [ -e /etc/aliases ]; then
	COUNT=`grep -c diradmin /etc/aliases`
	if [ "$COUNT" -eq 0 ]; then
		echo "diradmin: :blackhole:" >> /etc/aliases
	fi
fi

#CSF if AUTO
if [ "${OS}" != "FreeBSD" ] && [ "${AUTO}" = "1" ]; then
	CSF_LOG=/var/log/directadmin/csf_install.log
	CSF_SH=/root/csf_install.sh
	wget -O ${CSF_SH} ${SERVER}/all/csf/csf_install.sh > ${CSF_LOG} 2>&1
	if [ ! -s ${CSF_SH} ]; then
		echo "Error downloading ${SERVER}/all/csf/csf_install.sh"
		cat ${CSF_LOG}
	else
		#run it
		chmod 755 ${CSF_SH}
		${CSF_SH} auto >> ${CSF_LOG} 2>&1
		USE_IPSET=true
		if [ -x /usr/bin/systemd-detect-virt ]; then
			if systemd-detect-virt | grep -m1 -q -E 'lxc|openvz'; then
			    USE_IPSET=false
			fi
		fi
		if ${USE_IPSET} && grep -m1 -q '^LF_IPSET = "0"' /etc/csf/csf.conf; then
			perl -pi -e 's|^LF_IPSET = "0"|LF_IPSET = "1"|g' /etc/csf/csf.conf
			csf -r >> /dev/null 2>&1
		fi
	fi

        ${BUILD} secure_php
fi

rm -f /usr/lib/sendmail
ln -s ../sbin/sendmail /usr/lib/sendmail

if [ -s /usr/local/directadmin/conf/directadmin.conf ]; then
	echo ""
	echo "Install Complete!";
	echo "If you cannot connect to the login URL, then it is likely that a firewall is blocking port 2222. Please see:"
	echo "  https://help.directadmin.com/item.php?id=75"
fi

printf \\a
sleep 1
printf \\a
sleep 1
printf \\a

exit ${RET}

