#!/bin/bash



IPSEC_PATH="/etc/ipsec.d"
IPSEC_LOCAL_PATH=$IPSEC_PATH

# CA variables
CA_KEYNAME="hillnetwork_CA_key"
CA_CERTNAME="hillnetwork_CA_cert"
CA_DN="C=US, O=Hillnetwork, CN=Hillnetwork Root CA"

# Server variables
SERVER_KEYNAME="serverkey"
SERVER_CERTNAME="servercert"
SERVER_PUBLIC_IP=hillnetwork.ddns.net
SERVER_DN="C=US, O=Hillnetwork, CN=$SERVER_PUBLIC_IP"



# dependencies
function get_dependencies() {
	apt update
	apt install strongswan -y 
}


# 
function create_dirs() {
	mkdir -p $IPSEC_PATH/private
	mkdir -p $IPSEC_PATH/cacerts
	mkdir -p $IPSEC_PATH/certs
	mkdir -p $IPSEC_LOCAL_PATH/client-configs
	mkdir -p $IPSEC_LOCAL_PATH/export
}


function gen_root_CA() {
	# generate the root CA key
	ipsec pki --gen --type rsa \
	--size 4096 \
	--outform pem > $IPSEC_PATH/private/$CA_KEYNAME.pem
	chmod 600 $IPSEC_PATH/private/$CA_KEYNAME.pem

	# generate a self signed CA cert with the key just made
	ipsec pki --self --ca \
	--lifetime 3650 \
	--in $IPSEC_PATH/private/$CA_KEYNAME.pem \
	--type rsa \
	--dn "$CA_DN" \
	--outform pem > $IPSEC_PATH/cacerts/$CA_CERTNAME.pem
}


function gen_server_cert() {
	
	# generate the key
	ipsec pki --gen --type rsa \
	--size 4096 \
	--outform pem > $IPSEC_PATH/private/$SERVER_KEYNAME.pem
	
	chmod 600 $IPSEC_PATH/private/$SERVER_KEYNAME.pem

	# cenerate the public key and sign it
	ipsec pki --pub \
	--in $IPSEC_PATH/private/$SERVER_KEYNAME.pem \
	--type rsa | ipsec pki --issue \
	--lifetime 730 \
	--cacert $IPSEC_PATH/cacerts/$CA_CERTNAME.pem \
	 --cakey $IPSEC_PATH/private/$CA_KEYNAME.pem \
	--dn "$SERVER_DN" \
	--san "$SERVER_PUBLIC_IP" \
	--flag serverAuth \
	--flag ikeIntermediate \
	--outform pem > $IPSEC_PATH/certs/$SERVER_CERTNAME.pem 

} 


# keep comments
function clear_server_secrets {
	grep /etc/ipsec.secrets -e "\\s*#.*" > /etc/ipsec.secrets
}


# append server secret 
function add_server_secret {
	echo ": RSA $SERVER_KEYNAME.pem" >> /etc/ipsec.secrets 
}


function add_user {
	USERNAME="$1" 
	debug "creating private key for user $username"
	# create private key
	ipsec pki --gen \
	--type rsa \
	--size 4096 \
	--outform pem > $IPSEC_PATH/private/${USERNAME}key.pem 
	
	# create pubkey + cert 
	debug "creating public key for user ${USERNAME} and signing key"
	ipsec pki --pub \
	--in $IPSEC_PATH/private/${USERNAME}key.pem \
	--type rsa | ipsec pki --issue \
	--lifetime 730 \
	--cacert $IPSEC_PATH/cacerts/$CA_CERTNAME.pem \
	--cakey $IPSEC_PATH/private/$CA_KEYNAME.pem \
	--dn "C=US, O=Hillnetwork, CN=$USERNAME" \
	--san "$USERNAME@$SERVER_PUBLIC_IP" \
	--san "$USERNAME" \
	--outform pem > $IPSEC_PATH/certs/${USERNAME}cert.pem

	# add to export
	mkdir -p $IPSEC_PATH/export/$USERNAME
	mkdir -p $IPSEC_PATH/export/$USERNAME/cacerts
	mkdir -p $IPSEC_PATH/export/$USERNAME/certs
	mkdir -p $IPSEC_PATH/export/$USERNAME/private

	# add secret for user config 
	echo ": RSA $IPSEC_PATH/private/${USERNAME}key.pem" >> $IPSEC_PATH/export/$USERNAME/ipsec.secrets

	# add CA cert
	cp $IPSEC_PATH/cacerts/$CA_CERTNAME.pem $IPSEC_PATH/export/$USERNAME/cacerts

	# add private key	
	cp $IPSEC_PATH/private/${USERNAME}key.pem $IPSEC_PATH/export/$USERNAME/private

	# add client cert
	cp $IPSEC_PATH/certs/${USERNAME}cert.pem $IPSEC_PATH/export/${USERNAME}/certs

	# add client install script 
	cp $IPSEC_PATH/client-configs/install-config.sh $IPSEC_PATH/export/${USERNAME}/install-config.sh

	# generate the client config
	debug "Generating Server Cert keys and certs..."
	genConfig nick

	# add install script 
	debug "adding install script for ${USERNAME}..."
		
	chmod 600 $IPSEC_PATH/private/${USERNAME}key.pem
}

# generates the client config, given in client/ipsec.conf
function gen_client_config {
	USERNAME=$1
	cat client/ipsec.conf \
	| sed "s/{{USERNAME}}/${USERNAME}/g" \
	> $IPSEC_PATH/export/${USERNAME}/ipsec.conf
}



function testing() {

	# commented because it takes forever and has been tested
	debug "Updating Apt and getting dependencies..."
	get_dependencies

	debug "Creating the directory structure in $IPSEC_PATH..."
	create_dirs 
	
	debug "Generating Root CA keys and certs..."
	gen_root_CA

	debug "Generating Server Cert keys and certs..."
	gen_server_cert

	debug "adding server cert to ipsec.secrets..."
	add_server_secret

	debug "adding user \"nick\"..."
	add_user nick

	debug "CA cert:"
	ipsec pki --print --in $IPSEC_PATH/cacerts/$CA_CERTNAME.pem

	debug "Server cert:"
	ipsec pki --print --in $IPSEC_PATH/certs/$SERVER_CERTNAME.pem

	debug "Client cert:"
	ipsec pki --print --in $IPSEC_PATH/certs/nickcert.pem

}


function install_server_config {
	cp server/ipsec.conf /etc/ipsec.conf 
} 


function debug {
	RED='\033[0;31m'
	NC='\033[0m'
	printf "${RED}[DEBUG] $1 ${NC}\n"

}

testing
chown ubuntu -R /etc/ipsec.d/export

