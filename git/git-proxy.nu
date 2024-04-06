#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/10 10:09:52
# Description: Turn on or off the proxies for git
# Usage:
#   git-proxy
#   git-proxy off
#   git-proxy on ali

use ../utils/common.nu [ECODE]

# Turn on or off the proxies for git
def --env git-proxy [
  status: string  # Set proxy status: on/off
] {
  let isWindows = (sys).host.name == 'Windows'
  # On macOS, we typically use ClashX or AliMgrSoc to proxy the traffic
  # On windows the proxy could be Clash for Windows or v2ray
  let proxies = if $isWindows { tasklist | findstr 'xray clash' } else {
     lsof -i -n -P | grep -E 'ClashX|AliMgrSoc' | grep LISTEN
  }

  if ($status == 'on') {
    # Get something like: `127.0.0.1:10809`
    let proxy = (if $proxies == '' { [] } else {
      if $isWindows {
        let xrayPID = $proxies | detect columns -n | get column1.0
        netstat -ano | findstr $xrayPID | findstr LISTENING
          | detect columns -n | sort-by column1 -r | get column1
      } else {
        $proxies | detect columns -n | get column8
      }
    })
    if ($proxy | is-empty) {
      print $'(ansi r)(char nl)Can not find Ali, ClashX or v2ray proxy, please start it and try again, bye...(ansi reset)(char nl)(char nl)'
      exit $ECODE.MISSING_DEPENDENCY
    }

    # The first proxy in grep result should be http proxy
    let proxy = if ($proxy.0 | str contains '*') { $proxy.0 | str replace '*' '127.0.0.1' } else { $proxy.0 }
    let isClashX = ($proxies | lines | first) =~ 'ClashX'
    let LAN_IP = if $isWindows {
      ipconfig | find IPv4 | get 0 | ansi strip | detect columns -n | transpose k v| last | get v
     } else {
      ifconfig | grep broadcast | detect columns -n | get column1.0
    }

    if $isWindows or $isClashX {
      git config --global http.proxy $'http://($proxy)'
      git config --global https.proxy $'http://($proxy)'
      git config --global socks.proxy $'http://($proxy)'
      print $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
      print $'If you want to set proxy for the terminal, please run the following line in NuShell:'
      print $"(ansi g)load-env {http_proxy: 'http://($proxy)', https_proxy: 'http://($proxy)', ALL_PROXY: 'http://($proxy)'}(ansi reset)(char nl)"
      if not $isWindows {
        print $'If you want to set proxy for the terminal, please run the following line in bash, zsh, sh, etc.:'
        print $"(ansi g)export http_proxy=http://($proxy) https_proxy=http://($proxy) ALL_PROXY=http://($proxy)(ansi reset)(char nl)"

        print $'To share the proxy to other device, run the following command in terminal:'
        let shareProxy = $proxy | str replace '127.0.0.1' $LAN_IP
        print $"(ansi g)export http_proxy=http://($shareProxy) https_proxy=http://($shareProxy) ALL_PROXY=http://($shareProxy)(ansi reset)(char nl)"
      }
      exit $ECODE.SUCCESS
    }
    git config --global http.proxy $'socks5://($proxy)'
    git config --global https.proxy $'socks5://($proxy)'
    git config --global socks.proxy $'socks5h://($proxy)'
    print $'(ansi g)Proxy turned on at: ($proxy)(ansi reset)(char nl)'
    print $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    print $'If you want to set proxy for the terminal, please run: (char nl)'
    print $'export http_proxy=socks5://($proxy) https_proxy=socks5://($proxy) ALL_PROXY=socks://($proxy)(char nl)(char nl)'
    return
  }

  unset-git-conf http.proxy
  unset-git-conf https.proxy
  unset-git-conf socks.proxy
  print $'(ansi p)Proxy turned off(ansi reset)(char nl)'
  print $'(ansi p)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
  print $'If you want to unset proxy for the terminal, please run: (char nl)'
  const HIDE_CMD = '[http_proxy https_proxy ALL_PROXY] | each { do -i { hide-env $in } }'

  if $isWindows {
    print $'($HIDE_CMD)(char nl)(char nl)'
    print $'($HIDE_CMD)' | clip
  } else {
    print $'For NuShell: (ansi g)($HIDE_CMD)(ansi reset)(char nl)'
    print $'For bash, zsh, sh, etc.: (ansi g)unset http_proxy https_proxy ALL_PROXY(ansi reset)(char nl)'
  }
}

def unset-git-conf [ name: string ] {
  if not (git config --global --get $name | is-empty) {
    git config --global --unset $name
  }
}

git-proxy $env.GIT_PROXY_STATUS
