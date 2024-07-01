#!/bin/bash

# Read script parameters
AD_DOMAIN=$1
AD_USER=$2
AD_PASSWORD=$3
AD_GROUP=$4

# Install required packages
sudo apt-get update
#### sudo apt-get install -y realmd sssd adcli krb5-user packagekit
#--- DEBIAN_FRONTEND=noninteractive is required to eliminate the popup window while installing the package.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y realmd sssd adcli krb5-user packagekit

# Enable and start necessary services
sudo systemctl enable sssd
sudo systemctl start sssd

# Join the AD domain
echo $AD_PASSWORD | sudo realm join --user=$AD_USER $AD_DOMAIN

# list out realm details.
realm list

# Allow to make home directory
sudo pam-auth-update --enable mkhomedir

# Adding AD group to allow AD users to login, which are member of this group in AD
sudo realm permit --groups $AD_GROUP

# Restarting SSSD service
systemctl restart sssd 
