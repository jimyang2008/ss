#!/bin/bash

err() {
    msg="$@"
    echo "ERROR: $msg" >&2
}

get_distro() {
    if [[ -r /etc/os-release ]]
    then
        source /etc/os-release
        echo $ID-$VERSION_ID
    else
        err Unsupported Linux distro
    fi
}

install-ubuntu-16.04() {
    apt-get install software-properties-common -y
    add-apt-repository ppa:max-c-lv/shadowsocks-libev -y
    apt-get update -y
    apt install -y shadowsocks-libev
}

install-centos-7() {
    # install dependencies
    yum install epel-release -y
    yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto udns-devel libev-devel -y

    # install hsadowsocks-libev
    curl -Lk \
      -o /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo \
      https://copr.fedoraproject.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo
    yum update -y
    yum install -y shadowsocks-libev
}

main() {
    test $(id -u) == $(id -u root) || {
        err "Root privilege required"
        return 1
    }
    distro=$(get_distro)
    install-${distro}
}

main
