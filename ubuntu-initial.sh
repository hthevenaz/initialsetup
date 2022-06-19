#!/bin/bash

# This script is designed to work on Ubuntu 18 LTS (Bionic Beaver).
#
# A fast setup environment for Ubuntu initial configuration.
#
# Set up environment variables and do basic configuration.
# Installing apt-fast, a shell script wrapper for apt-get.
# Installing the required build-tools.
# Configuring time sync (ntp).
# Enabling Firewall (ufw).
#
# This method affords more flexibility than prebuilt packages:
# you can add particular modules, and apply latest security patches.
#
# Prerequisites:
#
# Basic Ubuntu installation from offical ISO boot image 18.04.6 TLS (x64 Platform).
# Configure network connections.
# Hard-Disk sizing and partitionning (LVM) with 50 GB minimum disk space.
# Profile setup by adding a default user (ubuntu) and server name (fqdn).
# Set password root.
# Wiring connected to external network (ping 8.8.8.8 with success).
#
# Adding Nominal LVM Volumes (minimal disk space: 50 GB):
#
#  LV        VG        Attr       LSize    Description
#  --------- --------- ---------- -------- --------------------------------------------
#  lv-home   ubuntu-vg -wi-ao---- 10.00g   user data
#  lv-opt    ubuntu-vg -wi-ao----  5.00g   install apps that are not part of the distro
#  lv-swap   ubuntu-vg -wi-ao----  2.00g   regarding the amount of ram (see tab. below)
#  lv-tmp    ubuntu-vg -wi-ao----  2.00g   temporary data
#  lv-var    ubuntu-vg -wi-ao----  5.00g   variable data (eg: logs)
#  lv-root   ubuntu-vg -wi-ao---- 25.00g   root data
#
# Fix the swap size regarding the amount of RAM available:
#
# ----------- RAM ---------------- ---------- swap size -----------
# < 1 GB                          |        double of RAM
# Between 1 GB and 4 GB           |        minimum of 2 GB
# Between 4 GB and 16 GB          |        minimum of 4 GB
# Between 16 GB and 64 GB         |        minimum of 8 GB
# Between 64 GB and 256 GB        |        minimum of 16 GB
# Between 256 GB and 512 GB       |        minimum of 32 GB
#
# Post-installation:
#
# Furthermore since losing an ssh server might mean losing your way to reach a server, 
# check the configuration after changing it and before restarting the server.
#
# sudo sshd -T | egrep -i 'PermitEmptyPasswords|PermitRootLogin|PasswordAuthentication|ChallengeResponseAuthentication'
#
# Downloading ISO image here:
#
# https://releases.ubuntu.com/18.04/ubuntu-18.04.6-live-server-amd64.iso
#
# References:
#
# https://github.com/ilikenwf/apt-fast
# https://ubuntu.com/server/docs/security-firewall
#
# Version 1.0 - 30.05.2022 -- Creation date.
#
# Author: Herve Thevenaz.

set -e
fail () { echo $1 >&2; exit 1; }
[[ $(id -u) = 0 ]] || fail "Please run as root."

# ------------------------------------------------------------------------
# Declare bash script local variables
# ------------------------------------------------------------------------

# https://www.ntppool.org/
NTPSERVER=('ch.pool.ntp.org' 'time.google.com')

# ------------------------------------------------------------------------
# Add source file repositories
# ------------------------------------------------------------------------

apt-get update -y
apt-get install gnupg -y # to use apt-key

CODENAME=$(lsb_release -cs)
cat >> /etc/apt/sources.list << EOF
deb http://ppa.launchpad.net/apt-fast/stable/ubuntu $CODENAME main
EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A2166B8DE8BDC3367D1901C11EE2FF37CA8DA16B
apt-get update

# ------------------------------------------------------------------------
# Install apt-fast
# ------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive
apt-get -qy install apt-fast

# Create apt-fast config file
cat > /etc/apt-fast.conf << EOF
_APTMGR=apt
DOWNLOADBEFORE=true
DLLIST='/tmp/apt-fast.list'
_DOWNLOADER='aria2c --no-conf -c -j 5 -x 10 -s 8 --min-split-size=1M --stream-piece-selector=default -i /tmp/apt-fast.list --connect-timeout=600 --timeout=600 -m0 --header "Accept: */*"'
DLDIR='/var/cache/apt/apt-fast'
APTCACHE='/var/cache/apt/archives'
EOF
chown root:root /etc/apt-fast.conf

# ------------------------------------------------------------------------
# Install the required build-tools
#
# Check available versions of the packages. For example:
# sudo apt list --installed | grep -i <package name>
# ------------------------------------------------------------------------

apt-fast -qy install build-essential ubuntu-drivers-common rsync pkg-config unzip tree net-tools
apt-fast -qy install git cmake ca-certificates bzip2 bash-completion wget
apt-fast -qy install software-properties-common curl grep sed lsb-release dpkg libglib2.0-dev zlib1g-dev
apt-fast -qy install ufw less htop openssh-client lsb-release dos2unix ubuntu-release-upgrader-core
apt-fast -qy install libmime-lite-perl exuberant-ctags pigz
apt-fast -qy install python3-pip python3-powerline ack lsyncd tmux

env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=mail apt-fast full-upgrade -qy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
apt -qy autoremove

# Install Pip
python3 -m pip install pip -Uq

# ------------------------------------------------------------------------
# Configure NTP
# ------------------------------------------------------------------------

# Before installing ntpd, we should turn off timesyncd
timedatectl set-ntp no
apt-fast -qy install ntp ntpdate

mv /etc/ntp.conf /etc/ntp.conf.orig

cat > /etc/ntp.conf << EOF
driftfile /var/lib/ntp/drift

logfile /var/log/ntp.log

restrict 127.0.0.1 mask 255.0.0.0

disable monitor

EOF

for i in "${NTPSERVER[@]}";
do
   echo "server $i" >> /etc/ntp.conf
done

# Enable the service
service ntp restart

# ------------------------------------------------------------------------
# Setup sshd deamon configuration
# ------------------------------------------------------------------------

# Copy the /etc/ssh/sshd_config file and protect it from writing with 
# the following commands, issued at a terminal prompt
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.original
chmod a-w /etc/ssh/sshd_config.original

perl -ni.bak -e 'print unless /^\s*(PermitEmptyPasswords|PermitRootLogin|PasswordAuthentication|ChallengeResponseAuthentication)/' /etc/ssh/sshd_config
cat << 'EOF' >> /etc/ssh/sshd_config
PasswordAuthentication yes
ChallengeResponseAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
EOF
systemctl reload ssh

# ------------------------------------------------------------------------
# Enable firewall and allow/block services by port, network interface and 
# source IP address.
# ------------------------------------------------------------------------

# Setting Up Default Policies
ufw default deny incoming
ufw default allow outgoing

# Allowing connections that your server needs to respond to
ufw allow ssh comment 'Open port SSH tcp port 22'
ufw allow 53/tcp comment 'Open port DNS tcp port 53'
ufw allow 53/udp comment 'Open port DNS udp port 53'
ufw allow 123/udp comment 'Open port NTP udp port 123'
ufw allow from any to any port 139,445 proto tcp comment 'Allow Samba tcp port 139,445'
ufw allow from any to any port 80,443 proto tcp comment 'Allow HTTP/HTTPS traffic tcp port 80,443'
ufw allow 25/tcp comment 'Open port Mail server (SMTP) tcp port 25'
ufw allow 587/tcp comment 'Open port Mail server to external IPs tcp port 587'

# Enable the firewall
ufw --force enable

# ------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------

echo
echo 'We need to reboot your machine to ensure kernel upgrades are installed.'
read -e -p 'When you are ready, type "y" to reboot. ' REBOOT
[[ $REBOOT = y* ]] && reboot || echo "You chose not to reboot now. When ready, type: 'shutdown -r now' or 'reboot' when ready."
echo
