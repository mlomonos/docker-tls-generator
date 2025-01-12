#!/usr/bin/env bash
AGREE_ALL=$1
IP_LIST=$2
#IP list sepparated with coma (e.g. 1.1.1.1,2.2.2.2,3.3.3.3)

# Try to swap params
if [[ $IP_LIST == '-y' ]] || [[ ! $IP_LIST && $AGREE_ALL != '-y' ]]; then
  TMP_VAR="$AGREE_ALL"
  AGREE_ALL="$IP_LIST"
  IP_LIST="$TMP_VAR"
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit -1
fi
SERVER_IP=$(curl ifconfig.me)
DAYS=5475 # 15 years
if [[ $IP_LIST =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+,?)+$ ]]; then
  echo "Got IP List: $IP_LIST"
  IP_LIST_VALID=true
elif [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Got IP: $SERVER_IP"
else
  echo "Fail to get IP address from ifconfig.me, please try curl ifconfig.me"
  exit -1
fi
function create_new_ca {
  # Generating certificate authority (CA) with 4096-bit security.
  openssl genrsa -out ~/.docker/ca-key.pem 4096
  # generating a self-signed certificate for CA
  # X.509 is a standard that defines the format of public key certificates, with fixed size 256-bit (32-byte) hash
	openssl req -x509 -new -nodes -key ~/.docker/ca-key.pem \
			-days $DAYS -out ~/.docker/ca.pem -subj '/CN=docker-CA'
}
if [[ $AGREE_ALL != '-y' ]]
then
  read -p "This will remove all previous Docker TLS certificates and CA. Are you sure want to continue? [Y/n]" -n 1 -r < /dev/tty;
  echo "";
fi

if [[ $REPLY =~ ^[Yy]$ || $AGREE_ALL == '-y' ]]
then
    sudo rm -rf /etc/docker/ssl && rm -rf ~/.docker && rm -rf /etc/systemd/system/docker.service.d
else
    echo "Aborting...";
    exit -1;
fi


# Create folder that keep our keys
mkdir -p /etc/docker/ssl
mkdir -p ~/.docker


if [[ -f ~/.docker/ca-key.pem && $AGREE_ALL != '-y' ]]; then
	read -p "We found previous versions of the Certificate Authority's. Do you want to create a new 'Certificate Authority's'? [Y/n]" -n 1 -r < /dev/tty;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
    create_new_ca
	fi
else
	create_new_ca
fi

# copy the CA certificate into /etc/docker/ssl
cp ~/.docker/ca.pem /etc/docker/ssl



# create OpenSSL configuration file for the Docker client ~/.docker/openssl.cnf
OPEN_SSL_CONFIG_BASE="[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]"
if [[ ! $IP_LIST_VALID ]];then
  IP_LIST=$SERVER_IP
fi
OPEN_SSL_CONFIG_IP_LIST=$(echo $IP_LIST | awk '{split($0, ips, ","); for(ip in ips){ printf "IP.%d = %s\\n", 1+c++, ips[ip]};};END{ printf "IP.%d = 127.0.0.1\\n", 1+c++ }')

echo -e "${OPEN_SSL_CONFIG_BASE}\n${OPEN_SSL_CONFIG_IP_LIST}" > ~/.docker/openssl.cnf

# create and sign a certificate for the client
openssl genrsa -out ~/.docker/key.pem 4096
openssl req -new -key ~/.docker/key.pem -out ~/.docker/cert.csr \
    -subj '/CN=docker-client' -config ~/.docker/openssl.cnf
openssl x509 -req -in ~/.docker/cert.csr -CA ~/.docker/ca.pem \
    -CAkey ~/.docker/ca-key.pem -CAcreateserial \
    -out ~/.docker/cert.pem -days $DAYS -extensions v3_req \
    -extfile ~/.docker/openssl.cnf

# Also do the same for the server:
openssl genrsa -out /etc/docker/ssl/server-key.pem 2048
openssl req -new -key /etc/docker/ssl/server-key.pem \
    -out /etc/docker/ssl/server-cert.csr \
    -subj '/CN=docker-server' -config ~/.docker/openssl.cnf
openssl x509 -req -in /etc/docker/ssl/server-cert.csr -CA ~/.docker/ca.pem \
    -CAkey ~/.docker/ca-key.pem -CAcreateserial \
    -out /etc/docker/ssl/server-cert.pem -days $DAYS -extensions v3_req \
    -extfile ~/.docker/openssl.cnf

# set up docker for use TLS certificate
mkdir -p /etc/systemd/system/docker.service.d/
echo "[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/etc/docker/ssl/ca.pem --tlscert=/etc/docker/ssl/server-cert.pem --tlskey=/etc/docker/ssl/server-key.pem" > /etc/systemd/system/docker.service.d/override.conf

# reload docker and docker-deamon
systemctl daemon-reload
systemctl restart docker
