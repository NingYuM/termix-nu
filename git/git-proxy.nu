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
  # On macOS, we typically use ClashX or AliMgrSoc to proxy the traffic
  # On windows the proxy could be Clash for Windows or v2ray
  let proxies = if $isWindows { (tasklist | findstr 'xray clash') } else { (lsof -i -n -P | grep -E 'ClashX|AliMgrSoc' | grep LISTEN) }

  if ($status == 'on') {

    let proxy = (if $proxies == '' { [] } else {
      if $isWindows {
        let xrayPID = ($proxies | detect columns -n | get column1 | get 0)
        let proxyAddr = (netstat -ano | findstr $xrayPID | findstr LISTENING | detect columns -n | sort-by column1 -r | get column1)
        $proxyAddr
      } else {
        ($proxies | detect columns -n).column8
      }
    })
    if ($proxy | length) == 0 {
      print $'(ansi r)(char nl)Can not find Ali, ClashX or v2ray proxy, please start it and try again, bype...(ansi reset)(char nl)(char nl)'
      exit 3
    }

    # set http_proxy=http://127.0.0.1:10809; set http_proxys=http://127.0.0.1:10809; set ALL_RROXY=http://127.0.0.1:10809
    # load-env {http_proxy: 'http://127.0.0.1:7890', https_proxy: 'http://127.0.0.1:7890', ALL_RROXY: 'http://127.0.0.1:7890'}
    # The first proxy in grep result should be http proxy
    let proxy = ($proxy).0
    let isClashX = ($proxies | lines | first) =~ 'ClashX'
    if $isWindows or $isClashX {
      git config --global http.proxy $'http://($proxy)'
      git config --global https.proxy $'http://($proxy)'
      git config --global socks.proxy $'http://($proxy)'
      print $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
      print $'If you want to set proxy for the terminal, please run the following line in NuShell:'
      print $"(ansi g)load-env {http_proxy: 'http://($proxy)', https_proxy: 'http://($proxy)', ALL_RROXY: 'http://($proxy)'}(ansi reset)(char nl)"
      if not $isWindows {
        print $'If you want to set proxy for the terminal, please run the following line in bash, zsh, sh, etc.:'
        print $"(ansi g)export http_proxy=http://($proxy) https_proxy=http://($proxy) ALL_RROXY=http://($proxy)(ansi reset)(char nl)"
      }
      exit 0
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
    if $isWindows {
      print $'hide-env http_proxy https_proxy ALL_RROXY(char nl)(char nl)'
      echo 'hide-env http_proxy https_proxy ALL_RROXY' | clip
    } else {
      print $'For NuShell: (ansi g)hide-env http_proxy https_proxy ALL_RROXY(ansi reset)(char nl)'
      print $'For bash, zsh, sh, etc.: (ansi g)unset http_proxy https_proxy ALL_RROXY(ansi reset)(char nl)'
    }
  }
}

def 'unset-git-conf' [ name: string ] {
  if not (git config --global --get $name | is-empty) {
    git config --global --unset $name
  }
}

git-proxy $env.GIT_PROXY_STATUS
