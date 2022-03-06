#!/usr/bin/env bash

apt update
apt install apache2 -y

if ! [ -L /var/www ]; then
	rm -rf /var/www
	ln -fs /vagrant /var/www
fi
