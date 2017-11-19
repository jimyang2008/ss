#!/bin/bash

set -x

CMDDIR=$(dirname $0)

$CMDDIR/setup_ss.sh
$CMDDIR/setup_ap.sh

while ! systemctl status shadowsocks-libev
do
	systemctl restart shadowsocks-libev
	sleep 3
done
