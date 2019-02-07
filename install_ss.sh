#!/bin/bash

: ${SS_PASSWORD:='changeit'}
: ${SS_METHOD:='chacha20-ietf-poly1305'}
: ${SS_PORT:='8888'}

err() {
    msg="$@"
    echo "ERROR: $msg" >&2
}

get_value() {
    var_name=$1
    def_value=${!var_name}
    read -p "$var_name[ENTER=$def_value]:" ans
    test -n "$ans" && eval "$var_name=$ans"
}

get_distro() {
    if [[ -r /etc/os-release ]]
    then
        source /etc/os-release
        echo $ID-$VERSION_ID
    elif [[ -r /etc/centos-release ]]
    then
        x=$(awk '{print $1"-"$3}' /etc/centos-release| tr [A-Z] [a-z])
        echo ${x%.*}
    else
        err Unsupported Linux distro
    fi
}

install_ubuntu-16.04() {
    apt-get update -y
    apt-get install software-properties-common -y
    add-apt-repository ppa:max-c-lv/shadowsocks-libev -y
    apt-get update -y
    apt install -y shadowsocks-libev
    apt-get install -y qrencode iproute
    systemctl start shadowsocks-libev
}

install_libsodium() {
    export LIBSODIUM_VER=1.0.15
    curl -LOk https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz
    tar -xzf libsodium-$LIBSODIUM_VER.tar.gz
    pushd libsodium-$LIBSODIUM_VER
    ./configure --prefix=/usr && make
    make install
    popd
    ldconfig
}

install_mbedtls() {
    export MBEDTLS_VER=2.6.0
    curl -LOk https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
    tar -xzf mbedtls-$MBEDTLS_VER-gpl.tgz
    pushd mbedtls-$MBEDTLS_VER
    make SHARED=1 CFLAGS=-fPIC
    make DESTDIR=/usr install
    popd
    ldconfig
}

install_centos-6() {


    # update yum
    yum update -y

    # build environment
    yum install --enablerepo=extras epel-release -y
    yum install -y gettext gcc autoconf libtool automake make asciidoc xmlto c-ares-devel libev-devel pcre-devel qrencode iproute

    install_libsodium
    install_mbedtls

    # autoconf 2.69
    curl -LO http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz
    tar -xvzf autoconf-2.69.tar.gz
    ( cd autoconf-2.69
      ./configure && make && make install
    )

    # download shadowsocks-libev and build + install
    git clone https://github.com/shadowsocks/shadowsocks-libev.git
    ( cd shadowsocks-libev/
      git submodule update --init --recursive
      ./autogen.sh && ./configure --disable-documentation
      make && make install
      # add init.d service
      mkdir -p /etc/shadowsocks-libev
      cp ./rpm/SOURCES/etc/init.d/shadowsocks-libev /etc/init.d/shadowsocks-libev
      ## modify /usr/bin to /usr/local/bin as libev installed to /usr/local/bin by default
      sed -i 's|/usr/bin/|/usr/local/bin/|g' /etc/init.d/shadowsocks-libev
      chmod +x /etc/init.d/shadowsocks-libev
      chkconfig --add shadowsocks-libev
      /etc/init.d/shadowsocks-libev start
    )
}

install_centos-7() {
    # update yum
    yum update -y

    # install dependencies
    yum install --enablerepo=extras epel-release -y
    yum install -y gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto udns-devel libev-devel qrencode iproute

    # install libsodium and mbedtls
    install_libsodium
    install_mbedtls

    # install shadowsocks-libev
    curl -Lk \
      -o /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo \
      https://copr.fedoraproject.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo
    yum install -y shadowsocks-libev
    systemctl enable shadowsocks-libev
    systemctl start shadowsocks-libev
}

install_amzn-2() {
    # update yum
    yum update -y

    # install dependencies
    amazon-linux-extras install -y epel
    yum install -y gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto udns-devel libev-devel qrencode iproute

    # install libsodium and mbedtls
    yum install -y libsodium mbedtls

    # install shadowsocks-libev
    curl -Lk \
      -o /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo \
      https://copr.fedoraproject.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo
    yum install -y shadowsocks-libev
    systemctl enable shadowsocks-libev
    systemctl start shadowsocks-libev
}

init_config() {
    : ${SS_SERVER:=$(ip addr | grep -w inet | awk '/global/ {print $2}'|cut -f1 -d/)}
    cfg_dir=/etc/shadowsocks-libev
    test -d $cfg_dir || mkdir $cfg_dir
    cat <<EOC >$cfg_dir/config.json
{
    "server" : "$SS_SERVER",
    "server_port" : $SS_PORT,
    "password" : "$SS_PASSWORD",
    "method" : "$SS_METHOD"
}
EOC
    echo -n "ss://"`echo -n ${SS_METHOD}:${SS_PASSWORD}@${SS_SERVER}:${SS_PORT} \
      | base64` | qrencode -t ANSI | tee $cfg_dir/ss-qr.txt
}

main() {
    test $(id -u) == $(id -u root) || {
        err "Root privilege required"
        return 1
    }
    get_value SS_PASSWORD
    get_value SS_PORT
    distro=$(get_distro)
    install_${distro}
    init_config
}

main
