#!/bin/bash

input="${2:1:-1}"
ip_list=""

IFS=',' read -ra ADDR <<< "$input"
for ip in "${ADDR[@]}"; do
    ip_list="${ip_list}\t${ip};\n"
done

ip_list="${ip_list:0:-2}"

sudo wget "${1}scripts/named.conf.options" -O /etc/bind/named.conf.options
sudo sed -i "s/.*{{IP}}.*/${ip_list}/" /etc/bind/named.conf.options
sudo service bind9 restart
