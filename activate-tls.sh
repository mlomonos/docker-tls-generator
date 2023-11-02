#!/usr/bin/env bash

# Create folder that keep our keys
mkdir -p /etc/docker/ssl
mkdir -p ~/.docker

if [ ! -f ~/.docker/ca-key.pem ]; then
    echo "File ca-key.pem not found!"
    exit 1;
fi

if [ ! -f ~/.docker/ca.pem ]; then
    echo "File ca.pem not fount!"
    exit 1;
fi

if [ ! -f ~/.docker/ca.srl ]; then
    echo "File ca.srl not fount!"
    exit 1;
fi

if [ ! -f ~/.docker/cert.csr ]; then
    echo "File cert.csr not fount!"
    exit 1;
fi

if [ ! -f ~/.docker/cert.pem ]; then
    echo "File cert.pem not fount!"
    exit 1;
fi

if [ ! -f ~/.docker/key.pem ]; then
    echo "File key.pem not fount!"
    exit 1;
fi

if [ ! -f ~/.docker/openssl.cnf ]; then
    echo "File openssl.cnf not fount!"
    exit 1;
fi

if [ ! -f /etc/docker/ssl/ca.pem   ]; then
    echo "File ca.pem not found!"
    exit 1;
fi
if [ ! -f /etc/docker/ssl/server-cert.csr ]; then
    echo "File server-cert.csr not found!"
    exit 1;
fi
if [ ! -f /etc/docker/ssl/server-cert.pem ]; then
    echo "File server-cert.pem not found!"
    exit 1;
fi
if [ ! -f /etc/docker/ssl/server-key.pem ]; then
    echo "File server-key.pem not found!"
    exit 1;
fi

# set up docker for use TLS certificate
mkdir -p /etc/systemd/system/docker.service.d/
echo "[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/etc/docker/ssl/ca.pem --tlscert=/etc/docker/ssl/server-cert.pem --tlskey=/etc/docker/ssl/server-key.pem" > /etc/systemd/system/docker.service.d/override.conf

# reload docker and docker-deamon
systemctl daemon-reload
systemctl restart docker