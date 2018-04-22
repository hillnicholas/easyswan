# easyswan
An easy, headache-free setup script to create a simple IKEv2 ipsec VPN using a generic configuration. This script is still being developed, so use at your own risk.

## Usage

### server
```
./easyswan init
```
This will create a self-signed certificate authority, the server key and certificate and install a generic host-to-host configuration. You will be prompted to provide a public IP address or hostname, the organization, and the common name to use for the certificate.  
```
./easyswan adduser
```
This will start an interactive prompt to request the username and authentication type. If RSA is chosen, a private key and certificate will be generated, along with a generic configuration to connect to the server. These will be written to /usr/local/etc/strongswan/export, and include an installation script (for Strongswan clients). EAP authentication has not been set yet.

### client
The client configuration directory will contain install-config.sh, relevant certificates, keys, ipsec.secrets and ipsec.conf. These are auto-installed to the correct locations by running ./install-config.sh. This will require you to install Strongswan on your device to operate correctly.
