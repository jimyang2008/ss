#!/bin/bash
set -x

CMDDIR=$(dirname $0)
SS_CONFIG=/etc/shadowsocks-libev/config.json 
SS_SERVER=103.238.226.193
SS_LPORT=12345
LAN_CIDR=192.168.6.0/24
IPSETS='lan chnroute'

err() {
    msg="$@"
    echo "ERROR: $msg" >&2
}

setup_fw() {

    if iptables -t nat -S SHADOWSOCKS
    then
        echo INFO: iptables chain SHADOWSOCKS already exists
        return 0
    fi

    # Create new chain
    iptables -t nat -N SHADOWSOCKS
    iptables -t mangle -N SHADOWSOCKS

    # Ignore your shadowsocks server's addresses
    # It's very IMPORTANT, just be careful.
    iptables -t nat -A SHADOWSOCKS -d $SS_SERVER -j RETURN

    # Ignore LANs and any other addresses you'd like to bypass the proxy
    for is in $IPSETS; do
        ipset restore -f $CMDDIR/files/ipset-${is}.txt
        iptables -t nat -A SHADOWSOCKS -m set --match-set $is dst -j RETURN
    done

    # Anything else should be redirected to shadowsocks's local port
    iptables -t nat -A SHADOWSOCKS -p tcp -m tcp --dport 22:1023 -j REDIRECT --to-ports $SS_LPORT
    iptables -t nat -A SHADOWSOCKS -p udp -j REDIRECT --to-ports $SS_LPORT

    # Add any UDP rules
    ip route add local default dev lo table 100
    ip rule add fwmark 1 lookup 100
    iptables -t mangle -A SHADOWSOCKS -p udp --dport 53 -j TPROXY --on-port $SS_LPORT --tproxy-mark 0x01/0x01

    # Apply the rules
    iptables -t nat -A PREROUTING -p tcp -s $LAN_CIDR -j SHADOWSOCKS
    iptables -t mangle -A PREROUTING -p tcp -s $LAN_CIDR -j SHADOWSOCKS

    # Add NAT
    iptables -t nat -A POSTROUTING -s $LAN_CIDR -j MASQUERADE

}

setup_service() {
    sname=$1
    if [[ -e $CMDDIR/files/etc/systemd/system/${sname}.service && \
        ! -e /etc/systemd/system/${sname}.service ]]
    then
        cp $CMDDIR/files/etc/systemd/system/${sname}.service /etc/systemd/system/
        systemctl enable $sname
        systemctl start $sname
    fi
}

prepare_chnroute() {
    chnroute=/etc/chnroute.txt
    if [[ -e $chnroute ]]
    then
        echo "INFO: $chnroute already exists"
        return 0
    fi

    tmp_chnroute=/tmp/chnroute.txt
    rm -f $tmp_chnroute
    curl 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | \
      grep ipv4 | \
      grep CN | \
      awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' \
      > $tmp_chnroute

    test -s $tmp_chnroute && cp -f $tmp_chnroute $chnroute
}

test $(id -u) == $(id -u root) || {
    err This script must be run with ROOT privilege
    exit 1
}

setup_fw
setup_service shadowsocks-libev

prepare_chnroute
setup_service chinadns

# Start the shadowsocks-redir
#ss-redir -u -c /etc/shadowsocks-libev/config.json -f /var/run/shadowsocks.pid


