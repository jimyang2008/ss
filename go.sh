#!/bin/bash

CMDDIR=$(cd ${0%/*}>/dev/null; pwd -P)

cd $CMDDIR

echo '- Upgrade PIP'
yum install -y python-pip
pip install --upgrade pip

if [[ -e /usr/bin/ssserver ]]
then
    echo '- FOUND Shadowsockes'
else
    echo '- Install Shadowsocks'
    pip install git+https://github.com/shadowsocks/shadowsocks.git@master
    cp files/shadowsocks.json /etc/
fi

if ldconfig -p | grep -q libsodium
then
    echo '- FOUND ChaCha20 encryption'
else
    echo '- Install ChaCha20 encryption'
    yum install -y m2crypto gcc
    curl -LOk https://download.libsodium.org/libsodium/releases/libsodium-1.0.15.tar.gz
    tar -xzf libsodium-1.0.15.tar.gz
    cd libsodium-*
    ./configure
    make && make install
    echo '/usr/local/lib' >> /etc/ld.so.conf
    ldconfig
fi

export GOPATH=~/gocode
if [[ -e $GOPATH/bin/server ]]
then
    echo '- FOUND KCPTun'
else
    echo '- Install KCPTun'
    export GOPATH=~/gocode
    mkdir -p $GOPATH
    type go || yum install -y go
    go get -u github.com/xtaci/kcptun/server
    install -m 0755 $CMDDIR/files/kcptun.init /etc/init.d/kcptun
    chkconfig --add kcptun
    chkconfig --level 2345 kcptun on
fi

echo '- Install iptables'
iptables -D INPUT -p udp -m udp --dport 4000 -j ACCEPT
iptables -I INPUT -p udp -m udp --dport 4000 -j ACCEPT
iptables -D INPUT -p tcp -m tcp --dport 7777 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7777 -j ACCEPT

