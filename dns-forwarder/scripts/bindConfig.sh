#!/bin/bash

echo "${1}"
echo "${2}"

input="${2:1:-1}"
ip_list=""

IFS=',' read -ra ADDR <<< "$input"
for ip in "${ADDR[@]}"; do
    ip_list="${ip_list}\t${ip};\n"
done

ip_list="${ip_list:0:-2}"

echo "Downloading..."
echo "wget "${1}" -O /etc/bind/named.conf.options"
sudo wget "${1}" -O /etc/bind/named.conf.options

echo "Replacing..."
echo "sed -i s/.*{{IP}}.*/${ip_list}/ /etc/bind/named.conf.options"
sudo sed -i "s/.*{{IP}}.*/${ip_list}/" /etc/bind/named.conf.options

echo "Restarting..."
sudo service bind9 restart
