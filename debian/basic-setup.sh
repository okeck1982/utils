#!/bin/bash

if [ $UID -ne 0 ]; then echo -e '\033[0;31mERROR: Script must run as root\033[0m'; exit 1; else echo -e $C_OK; fi

C_OK='\033[1;32mOK\033[0m'
C_ERR='\033[0;31mERR\033[0m'
C_INV='\033[0;31mINVALID\033[0m'

INTERFACE=`ip link | awk '$0 ~ /^[0-9].*$/ && $2 != "lo:" { gsub(":","",$2); print $2 }'`

# Get informations
read -p "Admin Username (administrator): " ADMINUSER < /dev/tty
read -p "IP Address: " NEW_IP < /dev/tty
read -p "Netmaks (255.255.255.0): " NEW_MASK < /dev/tty
read -p "Gateway: " NEW_GW < /dev/tty
read -p "DNS Server (10.10.100.11): " NEW_DNS < /dev/tty
read -p "New Domain (ok.home): " NEW_DOMAIN < /dev/tty

# Apply default Values
ADMINUSER=${ADMINUSER:-administrator}
NEW_MASK=${NEW_MASK:-255.255.255.0}
NEW_DNS=${NEW_DNS:-10.10.100.11}
NEW_DOMAIN=${NEW_DOMAIN:-ok.home}

# Pre Checks
ip_regex='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
echo -n "- CHECK: User '$ADMINUSER' exists ... "; if [ `grep -e "^${ADMINUSER}:.*$" /etc/passwd | wc -l` -eq 0 ]; then echo -e $C_ERR; exit 1; else echo -e $C_OK; fi
echo -n "- CHECK: IP Address '${NEW_IP}' ... "; if [ `echo -n "${NEW_IP}" | grep -E $ip_regex | wc -l` -gt 0 ]; then echo -e $C_OK; else echo -e $C_INV; exit 1; fi
echo -n "- CHECK: Netmask    '${NEW_MASK}' ... "; if [ `echo -n "${NEW_MASK}" | grep -E $ip_regex | wc -l` -gt 0 ]; then echo -e $C_OK; else echo -e $C_INV; exit 1; fi
echo -n "- CHECK: Gateway IP '${NEW_GW}' ... "; if [ `echo -n "${NEW_GW}" | grep -E $ip_regex | wc -l` -gt 0 ]; then echo -e $C_OK; else echo -e $C_INV; exit 1; fi
echo -n "- CHECK: DNS Server '${NEW_DNS}' ... "; if [ `echo -n "${NEW_DNS}" | grep -E $ip_regex | wc -l` -gt 0 ]; then echo -e $C_OK; else echo -e $C_INV; exit 1; fi

# Overview
cat << 'EOF'
===================================================================
Setup Details:
 - Admin user is:     ${ADMINUSER}

 TASKS:
 - APT
   - update sources (apt-get update)
   - update os packages (apt-get upgrade)
 - Install sudo
 - Allow 'sudo' without password for User '${ADMINUSER}'
 - Configure network interface '${INTERFACE}':
    IP:             ${NEW_IP}
    Netmask:        ${NEW_MASK}
    Gateway:        ${NEW_GW}
    DNS:            ${NEW_DNS}
    Domain:         ${NEW_DOMAIN}
 - Disable IPv6
 - Reboot

ATTENTION: SYSTEM WILL AUTOMATICALY REBOOT
===================================================================

EOF

read -p "Execute changes? (y/n)" CONFIRM < /dev/tty
if [ $CONFIRM != "y" ]; then exit 0; fi

# Begin Setup
echo -n "- APT Update ... "
apt-get update > /dev/null 2>&1
if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi

echo -n "- APT Upgrade ... "
apt-get upgrade > /dev/null 2>&1
if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi

echo -n "- Install Package: sudo ... "
apt-get install sudo > /dev/null 2>&1
if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi

echo -n "- Setup sudo for '${ADMINUSER}' ... "
echo "$ADMINUSER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$ADMINUSER
if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi

echo -n "- Replace /etc/network/interfaces ..."
cat << 'EOF' > /etc/network/interfaces
# Loopback network interface
auto lo
iface lo inet loopback

# Primary network interface '${INTERFACE}'
auto ${INTERFACE}
iface ${INTERFACE} inet static
        address ${NEW_IP}
        netmsak ${NEW_MASK}
        gateway ${NEW_GW}
        dns-nameservers ${NEW_DNS}
        dns-domain ${NEW_DOMAIN}
EOF

if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi

echo -n "- Disable IPv6 "
if [ `grep -E "net\.ipv6\.conf\.all\.disable_ipv6\s*=" /etc/sysctl.conf | wc -l` -gt 0 ];
  then
    echo -n "(edit /etc/sysctl.conf) ... "
    sed -i 's/^[# ]*net\.ipv6\.conf\.all\.disable_ipv6.*$/net\.ipv6\.conf\.all\.disable_ipv6 = 1/' /etc/sysctl.conf
    if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi
  else
    echo -n "(append to /etc/sysctl.conf) ... "
    echo -e "\n# Disable IPv6\nnet.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf;
    if [ $? -gt 0 ]; then echo -e $C_ERR; else echo -e $C_OK; fi
fi
