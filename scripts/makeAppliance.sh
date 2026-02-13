#!/bin/bash
#called after installation is completed
#Performs: disabling of IPV6, fine tuning server, Downloading Safesquid

GROUP="root"
USER="ssquid"

UPDATE="/tmp"
UPTAR_UPDATE="${UPDATE}/_mkappliance/installation"
SETUP_SCRIPT="_mkappliance/installation/setup.sh"
TAR_NAME="safesquid_latest.tar.gz"
LATEST_SAFESQUID="http://downloads.safesquid.net/appliance/binary/${TAR_NAME}"

USER_ADD_SSQUID()
{
	useradd -r ${USER} -g ${GROUP} --shell ${SHELL}
	grep -iE "^${USER} " /etc/sudoers && return;
	echo "${USER}  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
}

SET_ULIMITS ()
{
	echo "ulimit -HSn 8192" >> /root/.bashrc	
	echo "* hard nofile 8192" >> /etc/security/limits.conf
	echo "* soft nofile 8192" >> /etc/security/limits.conf	
}

SETUP_MOTD ()
{
touch /etc/motd-maintenance
echo -e "
\033[1;32m
   _____            __           _____                   _       _
  / ____|          / _|         / ____|                 (_)     | |
 | (___     __ _  | |_    ___  | (___     __ _   _   _   _    __| |
  \___ \   / _\ | |  _|  / _ \  \___ \   / _\ | | | | | | |  / _\ |
  ____) | | (_| | | |   |  __/  ____) | | (_| | | |_| | | | | (_| |
 |_____/   \ _,_| |_|    \___| |_____/   \__, |  \__,_| |_|  \__,_|
                                            | |
                                            |_|

                                    _____  __          __  _____
                                   / ____| \ \        / / / ____|
                                  | (___    \ \  /\  / / | |  ___
                                   \___ \    \ \/  \/ /  | | |_  |
                                   ____) |    \  /\  /   | |___| |
                                  |_____/      \/  \/     \_____/


 Built on `date "+%d %B %Y"`

\033[0;35m+++++++++++++: \033[0;37mHelpful Information\033[0;35m :+++++++++++++++
\033[0;35m+     \033[0;37mWeb   \033[0;35m# \033[1;32mhttps://www.safesquid.com/
\033[0;35m+     \033[0;37mEMail \033[0;35m# \033[1;32msupport@safesquid.net
\033[0;35m+     \033[0;37mskype \033[0;35m# \033[1;32mSafeSquid 
\033[0;35m+++++++++++++++++: \033[0;37mSystem Data\033[0;35m :+++++++++++++++++++
+      \033[0;37mFqdn \033[0;35m= \033[1;32m$(hostname -f)
\033[0;35m+   \033[0;37mAddress \033[0;35m= \033[1;32m$(hostname -I)
\033[0;35m+    \033[0;37mKernel \033[0;35m= \033[1;32m$(uname -r)
\033[0;35m+    \033[0;37mMemory \033[0;35m= \033[1;32m$(cat /proc/meminfo | grep MemTotal | awk {'print $2'}) kB
\033[0;35m+++++++++++: \033[0;31mMaintenance Information\033[0;35m :+++++++++++++
+\033[0;31m $(cat /etc/motd-maintenance)
\033[0;35m+++++++++++++++++++++++++++++++++++++++++++++++++++\033[0;37m
" > /etc/motd
}

INSTALL_DEPENDENCIES()
{
	declare -a PACKS
	PACKS+=("aptitude")
	PACKS+=("debconf")
	PACKS+=("debconf-utils")
	PACKS+=("dpkg")
	PACKS+=("update-motd")
	PACKS+=("perl-base")
	PACKS+=("plymouth-themes")
	PACKS+=("zlib1g")
	PACKS+=("tar")
	PACKS+=("heimdal-clients")
	PACKS+=("libsasl2-modules-gssapi-heimdal")
	PACKS+=("libgssapi3-heimdal")
	PACKS+=("libkrb5-26-heimdal")
	PACKS+=("libsasl2-modules-ldap")
	PACKS+=("libudns0")
	PACKS+=("libpam0g")
	PACKS+=("libcap-ng0")
	PACKS+=("libcap2-bin")
	PACKS+=("libmagic1")
	PACKS+=("ntp")
	PACKS+=("ntpdate")
	PACKS+=("curl")
	PACKS+=("vim")
	PACKS+=("wget")
	PACKS+=("gnuplot-nox")
	PACKS+=("bind9")
	PACKS+=("bind9utils")
	PACKS+=("bind9-host")
	PACKS+=("resolvconf")	
	PACKS+=("monit")
	PACKS+=("sqlite3")
	PACKS+=("libkeepalive0")
	PACKS+=("clamav-daemon")
	PACKS+=("openssh-server")
	PACKS+=("tree")
	PACKS+=("net-tools")
	PACKS+=("lvm2")

	
	D=${DEBIAN_FRONTEND}	
	export DEBIAN_FRONTEND=noninteractive
	apt-get install -y ${PACKS[*]}
	export DEBIAN_FRONTEND=${D}
}

SET_ISSUE()
{
	cat << _EOF > /etc/issue
		
		Thank You! for choosing SafeSquid Appliance
		This Appliance has been built using %v
	
_EOF
	return;
}

GET_MSKTUTIL ()
{
	[ -f "/usr/local/bin/msktutil" ] && return;
	wget  --no-proxy 'http://downloads.safesquid.net/appliance/source/msktutil' -O /usr/local/bin/msktutil
	[ -f "/usr/local/bin/msktutil" ] && chmod 755 /usr/local/bin/msktutil && return;
	echo "error: downloading msktutil"
	apt-get install libudns0
}

FIX_BIND9()
{
	sed -i '22i\
	 \n\tmax-cache-ttl 300; \n\tmax-ncache-ttl 300; 
	' /etc/bind/named.conf.options

	touch /etc/bind/safesquid.dns.conf

	cat <<- _EOF >> /etc/bind/named.conf
	include "/etc/bind/safesquid.dns.conf";
	_EOF

	ln -sf /etc/init.d/named /etc/init.d/bind9
	/etc/init.d/bind9 restart
	systemctl start bind9-resolvconf
	systemctl enable bind9-resolvconf
}

FIX_RESOLVCONF()
{
	cat <<- _EOF >> /etc/default/resolvconf
	TRUNCATE_NAMESERVER_LIST_AFTER_LOOPBACK_ADDRESS=yes
	_EOF
}

SETUP_LATEST_SAFESQUID()
{
	wget --no-proxy ${LATEST_SAFESQUID} -O ${UPDATE}/${TAR_NAME}	
	tar -zxvf ${UPDATE}/${TAR_NAME} -C ${UPDATE}
	/bin/bash ${UPDATE}/${SETUP_SCRIPT}	

}

MAIN()
{
	INSTALL_DEPENDENCIES
	USER_ADD_SSQUID
	GET_MSKTUTIL
	SET_ULIMITS
	SET_ISSUE
	SETUP_MOTD
	SETUP_LATEST_SAFESQUID
	FIX_BIND9
	FIX_RESOLVCONF
}

MAIN
