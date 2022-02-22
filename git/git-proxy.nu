# Author: hustcer
# Created: 2021/12/10 10:09:52
# Description: Turn on or off the proxies for git
# Usage:
#   git-proxy
#   git-proxy off
#   git-proxy on ali

# Turn on or off the proxies for git
def 'git-proxy' [
  status: string  # Set proxy status: on/off
] {
  let proxies = (lsof -i -n -P | grep LISTEN | grep 'AliMgrSoc')

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
    # unlet-env ALL_RROXY
    # unlet-env http_proxy
    # unlet-env https_proxy
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    git config --global --unset socks.proxy
    $'(ansi p)Proxy turned off(ansi reset)(char nl)'
    $'(ansi p)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    $'If you want to unset proxy for the terminal, please run: (char nl)'
    $'unset http_proxy https_proxy ALL_RROXY(char nl)(char nl)'
  }
}

git-proxy $env.GIT_PROXY_STATUS
