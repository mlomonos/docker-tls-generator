#!/usr/bin/env bash

IP_FROM=$1
IP_TO=$2
USER=$3 || "root"

scp $USER@$IP_FROM:~/.docker/* $USER@$IP_TO:~/.docker/
scp $USER@$IP_FROM:/etc/docker/ssl/* $USER@$IP_TO:/etc/docker/ssl/