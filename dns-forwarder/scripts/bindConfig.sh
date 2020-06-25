#!/bin/bash

input="${1:1:-1}"
ip_list=""

IFS=',' read -ra ADDR <<< "$input"
for ip in "${ADDR[@]}"; do
    ip_list="${ip_list}\t${ip};\n"
done

ip_list="${ip_list:0:-2}"

sudo sed -i "s/.*{{IP}}.*/${ip_list}/" /etc/bind/named.conf.options
