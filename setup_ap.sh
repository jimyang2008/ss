#!/bin/bash

STAIFNAME=wlan0
APIFNAME=wlan1
APIFMAC=$(ifconfig wlan0 |awk '/ether/ {print $2}')
APIFMAC="${APIFMAC%?}$(( (${APIFMAC: -1} + 1) % 10 ))"
APIFIP=192.168.6.1

ifconfig $STAIFNAME down
iw phy phy0 interface add $APIFNAME type __ap
ifconfig $APIFNAME hw ether $APIFMAC
ifconfig $APIFNAME $APIFIP up
systemctl restart hostapd
ifconfig $STAIFNAME up
systemctl restart dhcpcd
sleep 3
systemctl restart dnsmasq
