#!/usr/bin/env nu
# Create an each connect proxy locally
# REF:
#   - https://aliyuque.antfin.com/uhftro/kg7h1z/qitimmod9gh0g814
#   - https://github.com/docker-easyconnect/docker-easyconnect

const AUTH = {
    wq: {
        host: 'https://221.2.187.150:4434'
        username: 'liunian'
        password: '0000000b'
    }
}

def main [] {

    (docker run
        --rm --device /dev/net/tun
        --cap-add NET_ADMIN -ti
        -v /Users/hustcer/.easyconn:/root/.easyconn
        -p 127.0.0.1:1080:1080
        -p 127.0.0.1:8888:8888
        -e DISABLE_PKG_VERSION_XML=1
        -e EC_VER=7.6.7.4
        -e CLI_OPTS="-d https://221.2.187.150:4434 -u taojiaxuan -p wq+8965#"
        hustcer/ec:latest)

    # load-env {http_proxy: 'http://127.0.0.1:8888', https_proxy: 'http://127.0.0.1:8888', ALL_RROXY: 'http://127.0.0.1:8888'}
}

