#!/bin/bash
set -x

CMDDIR=$(dirname $0)
SS_CONFIG=/etc/shadowsocks-libev/config.json 
SS_SERVER=18.162.113.58
SS_LPORT=12345
LAN_CIDR=172.31.12.74/20
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

    ipset save > /etc/ipset.save
    iptables-save > /etc/iptables.save

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

install_sslibev() {
    . /etc/lsb-release
    DISTRIB_CODENAME
    sh -c "printf \"deb http://deb.debian.org/debian ${DISTRIB_CODENAME}-backports main\" > /etc/apt/sources.list.d/${DISTRIB_CODENAME}-backports.list"
    apt-get update -y
    apt-get -t ${DISTRIB_CODENAME}-backports install -y --allow-unauthenticated shadowsocks-libev
}

install_chinadns() {
    (
    curl -LOk https://github.com/shadowsocks/ChinaDNS/releases/download/1.3.2/chinadns-1.3.2.tar.gz
    tar -xzf chinadns-1.3.2.tar.gz
    cd chinadns-1.3.2
    ./configure && make
    cp src/chinadns /usr/local/bin/
    )
}

test $(id -u) == $(id -u root) || {
    err This script must be run with ROOT privilege
    exit 1
}

apt-get update -y
apt-get install -y \
    --no-install-recommends \
    --allow-unauthenticated \
    gettext build-essential autoconf libtool \
    libpcre3-dev asciidoc xmlto libev-dev \
    libc-ares-dev automake libmbedtls-dev \
    libsodium-dev hostapd dnsmasq ipset
apt-get upgrade -y dhcpcd5
install_sslibev
install_chinadns

rsync -av $CMDDIR/files/etc/ /etc/

setup_fw
setup_service shadowsocks-libev
setup_service chinadns

prepare_chnroute
setup_service chinadns



