#!/usr/bin/env bash

IP_FROM=$1
IP_TO=$2
USER=$3

if [[ ! $USER ]]; then
    USER="root";
fi

echo "USER: $USER"
echo "IPS: $IP_FROM > $IP_TO"

scp -3 $USER@$IP_FROM:~/.docker/* $USER@$IP_TO:~/.docker/
scp -3 $USER@$IP_FROM:/etc/docker/ssl/* $USER@$IP_TO:/etc/docker/ssl/