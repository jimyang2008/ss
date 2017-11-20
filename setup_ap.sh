#!/bin/bash

set -x

STAIFNAME=wlan0
APIFNAME=wlan1
APIFMAC=$(ifconfig $STAIFNAME |awk '/ether/ {print $2}')
APIFMAC="${APIFMAC%?}$(( (${APIFMAC: -1} + 1) % 10 ))"
APIFIP=192.168.6.1

iwconfig $STAIFNAME power off
ifconfig $STAIFNAME down
iw phy phy0 interface add $APIFNAME type __ap
ifconfig $APIFNAME hw ether $APIFMAC
ifconfig $APIFNAME $APIFIP up

systemctl restart hostapd
ifconfig $STAIFNAME up

while ! ifconfig $APIFNAME | fgrep -q $APIFIP
do
    systemctl restart hostapd
    sleep 10
done

while ! ifconfig $STAIFNAME | grep -w inet
do
    systemctl restart dhcpcd
    sleep 10
done

systemctl restart dnsmasq

