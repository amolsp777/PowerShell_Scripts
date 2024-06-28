#!/bin/bash

# Read script parameters
AD_DOMAIN=$1
AD_USER=$2
AD_PASSWORD=$3

# Install required packages
sudo apt-get update
sudo apt-get install -y realmd sssd adcli krb5-user packagekit

# Join the AD domain
echo $AD_PASSWORD | realm join --user=$AD_USER $AD_DOMAIN

# Enable and start necessary services
sudo systemctl enable sssd
sudo systemctl start sssd

