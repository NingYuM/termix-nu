#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/29 16:15:20
# 从国际化文案管理平台下载最新的中英文文案到本地；
# 需要全局安装了 @terminus/termix, 最低版本 v2.2.5;
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 使用:
#   nu get-locale.nu b2c

use std [repeat]

let I18 = {
  b2c: { PID: 5, DESIGN_PID: 6 },
  sea: { PID: 7, DESIGN_PID: 8 },
  b2b: { PID: 51, DESIGN_PID: 63 },
}

# Check if some command available in current shell
def is-installed [ app: string ] {
  (which $app | length) > 0
}

export def hr-line [
  width?: int = 90,
  --color(-c): string = 'g',
  --blank-line(-b): bool,
  --with-arrow(-a): bool,
] {
  print $'(ansi $color)('─' | repeat $width | str join)(if $with_arrow {'>'})(ansi reset)'
  if $blank_line { char nl }
}

# 根据`业务类型`从国际化文案管理平台下载最新的中英文文案到本地；
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    print $'(char nl)Usage: nu get-locale.nu (ansi r)<bizType>(ansi reset)'; hr-line
    print $'(ansi g)Description: (ansi reset)根据`业务类型`从国际化文案管理平台下载最新的中英文文案到本地'
    print $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    print $'请确保参数输入无误并重试!(char nl)'
    exit 7
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if not $bizCheck {
    print $'(ansi r)You have input the wrong biz type, Please try again!(ansi reset)(char nl)'
    exit 7
  }

  # Check mall-$bizType dir exists
  if not ($'mall-($bizType)' | path exists) {
    print $'[ERR] This directory: (ansi r)mall-($bizType) does not exist!(ansi reset) Bye~~'; exit 3
  }

  if (is-installed 'termix') {
    print $'Current termix version: (ansi g)(termix --version | str trim)(ansi reset)'; hr-line
  } else {
    print $'(ansi r)Command `termix` could not be found, Please install it by `npm i -g @terminus/termix@latest`, and try again!(ansi reset)'
    exit 2
  }

  let ZH_DIR = 'client/locale/zh/messages.json'
  let EN_DIR = 'client/locale/en/messages.json'
  let DESIGN_ZH_DIR = 'client/design/locale/zh/messages.json'
  let DESIGN_EN_DIR = 'client/design/locale/en/messages.json'

  if $bizType not-in $I18 {
    print $'Locale ID for biz type: ($bizType) has not been configured, please try again...'
    exit 3
  }

  print $'Running get locale for (ansi p)($bizType)(ansi reset)...'
  let PID = ($I18 | get $bizType).PID
  let DESIGN_PID = ($I18 | get $bizType).DESIGN_PID
  termix locale-get $PID -o $'mall-($bizType)/($ZH_DIR)'
  termix locale-get $PID -o $'mall-($bizType)/($EN_DIR)' -f
  termix locale-get $DESIGN_PID -o $'mall-($bizType)/($DESIGN_ZH_DIR)'
  termix locale-get $DESIGN_PID -o $'mall-($bizType)/($DESIGN_EN_DIR)' -f
}
