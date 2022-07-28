#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/10 10:09:52
# Description: Turn on or off the proxies for git
# Usage:
#   git-proxy
#   git-proxy off
#   git-proxy on ali

# Turn on or off the proxies for git
def-env 'git-proxy' [
  status: string  # Set proxy status: on/off
] {
  let proxies = (lsof -i -n -P | grep AliMgrSoc | grep LISTEN)

  if ($status == 'on') {

    let proxy = (if $proxies == '' { [] } else { ($proxies | detect columns -n).column8 })
    if ($proxy | length) == 0 {
      $'(ansi r)(char nl)Can not find Ali proxy, please start it and try again, bype...(ansi reset)(char nl)(char nl)'
      exit --now
    }

    let proxy = ($proxy).0
    # let-env ALL_RROXY = $'socks://($proxy)'
    # let-env http_proxy = $'socks5://($proxy)'
    # let-env https_proxy = $'socks5://($proxy)'
    git config --global http.proxy $'socks5://($proxy)'
    git config --global https.proxy $'socks5://($proxy)'
    git config --global socks.proxy $'socks5h://($proxy)'
    $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
    $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    $'If you want to set proxy for the terminal, please run: (char nl)'
    $'export http_proxy=socks5://($proxy) https_proxy=socks5://($proxy) ALL_RROXY=socks://($proxy)(char nl)(char nl)'
  } else {
    # if ('ALL_RROXY' in (env).name) { hide ALL_RROXY }
    # if ('http_proxy' in (env).name) { hide http_proxy }
    # if ('https_proxy' in (env).name) { hide https_proxy }
    unset-git-conf http.proxy
    unset-git-conf https.proxy
    unset-git-conf socks.proxy
    $'(ansi p)Proxy turned off(ansi reset)(char nl)'
    $'(ansi p)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    $'If you want to unset proxy for the terminal, please run: (char nl)'
    $'unset http_proxy https_proxy ALL_RROXY(char nl)(char nl)'
  }
}

def 'unset-git-conf' [ name: string ] {
  if not (git config --global --get $name | empty?) {
    git config --global --unset $name
  }
}

git-proxy $env.GIT_PROXY_STATUS
