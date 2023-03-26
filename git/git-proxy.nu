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
  # Get xray pid for Windows:
  # let xrayPID = (tasklist | findstr xray | detect columns -n | get column1 | get 0)
  # Get something like: `127.0.0.1:10809`
  # let proxyAddr = (netstat -ano | findstr $xrayPID | findstr LISTENING | detect columns -n | sort-by column1 -r | get 0 | get column1)
  let isWindows = (sys).host.name == 'Windows'
  let proxies = if $isWindows { (tasklist | findstr xray) } else { (lsof -i -n -P | grep AliMgrSoc | grep LISTEN) }

  if ($status == 'on') {

    let proxy = (if $proxies == '' { [] } else {
      if $isWindows {
        let xrayPID = ($proxies | detect columns -n | get column1 | get 0)
        let proxyAddr = (netstat -ano | findstr $xrayPID | findstr LISTENING | detect columns -n | sort-by column1 -r | get column1)
        echo $proxyAddr
      } else {
        ($proxies | detect columns -n).column8
      }
    })
    if ($proxy | length) == 0 {
      print $'(ansi r)(char nl)Can not find Ali or v2ray proxy, please start it and try again, bype...(ansi reset)(char nl)(char nl)'
      exit --now
    }

    # set http_proxy=http://127.0.0.1:10809; set http_proxys=http://127.0.0.1:10809; set ALL_RROXY=http://127.0.0.1:10809
    # let-env http_proxy = 'http://127.0.0.1:10809'; let-env https_proxy = 'http://127.0.0.1:10809'; let-env ALL_RROXY = 'http://127.0.0.1:10809'
    let proxy = ($proxy).0
    if $isWindows {
      let-env ALL_RROXY = $'http://($proxy)'
      let-env http_proxy = $'http://($proxy)'
      let-env https_proxy = $'http://($proxy)'
      git config --global http.proxy $'http://($proxy)'
      git config --global https.proxy $'http://($proxy)'
      git config --global socks.proxy $'http://($proxy)'
      print $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
      exit --now
    }
    git config --global http.proxy $'socks5://($proxy)'
    git config --global https.proxy $'socks5://($proxy)'
    git config --global socks.proxy $'socks5h://($proxy)'
    print $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
    print $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    print $'If you want to set proxy for the terminal, please run: (char nl)'
    print $'export http_proxy=socks5://($proxy) https_proxy=socks5://($proxy) ALL_RROXY=socks://($proxy)(char nl)(char nl)'
  } else {
    # if ('ALL_RROXY' in (env).name) { hide ALL_RROXY }
    # if ('http_proxy' in (env).name) { hide http_proxy }
    # if ('https_proxy' in (env).name) { hide https_proxy }
    unset-git-conf http.proxy
    unset-git-conf https.proxy
    unset-git-conf socks.proxy
    print $'(ansi p)Proxy turned off(ansi reset)(char nl)'
    print $'(ansi p)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    print $'If you want to unset proxy for the terminal, please run: (char nl)'
    print $'unset http_proxy https_proxy ALL_RROXY(char nl)(char nl)'
  }
}

def 'unset-git-conf' [ name: string ] {
  if not (git config --global --get $name | is-empty) {
    git config --global --unset $name
  }
}

git-proxy $env.GIT_PROXY_STATUS
