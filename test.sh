#!/bin/bash

# LXD doesnt do too well with strongswan :( 
#lxc restore ipsectest config_added

# give her time to reset itself
#sleep 2 


HOST="192.168.2.36"
CLIENT="ubuntu@192.168.2.32"

ssh $HOST "sudo bash -s " < ./strongswan_init_pem.sh 

scp -r $HOST:/etc/ipsec.d/export/nick .

scp -r nick $CLIENT:

ssh $CLIENT "sudo bash /home/ubuntu/nick/install-config.sh"

