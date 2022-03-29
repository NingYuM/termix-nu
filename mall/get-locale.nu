#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/29 16:15:20
# 从国际化文案管理平台下载最新的中英文文案到本地；
# 需要全局安装了 @terminus/termix, 最低版本 v2.2.5;
# 使用:
#   nu get-locale.nu b2c

let I18 = {
  b2c: { PID: 5, DESIGN_PID: 6 },
  sea: { PID: 7, DESIGN_PID: 8 },
  b2b: { PID: 51, DESIGN_PID: 63 },
}

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  ((which $app | length) > 0)
}

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank-line { char nl }
}

# 根据`业务类型`从国际化文案管理平台下载最新的中英文文案到本地；
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    $'(char nl)Usage: nu get-locale.nu (ansi r)<bizType>(ansi reset)'; hr-line
    $'(ansi g)Description: (ansi reset)根据`业务类型`从国际化文案管理平台下载最新的中英文文案到本地'
    $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    $'请确保参数输入无误并重试!(char nl)'
    exit --now
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if $bizCheck == false {
    $'(ansi r)You have input the wrong biz type, Please try again!(ansi reset)(char nl)'
    exit --now
  }

  # Check mall-$bizType dir exists
  if ($'mall-($bizType)' | path exists) == false {
    $'[ERR] This directory: (ansi r)mall-($bizType) does not exist!(ansi reset) Bye~~'; exit --now
  }

  if (is-installed 'termix') {
    $'Current termix version: (ansi g)(termix --version | str trim)(ansi reset)'; hr-line
  } else {
    $'(ansi r)Command `termix` could not be found, Please install it by `npm i -g @terminus/termix@latest`, and try again!(ansi reset)'
    exit --now
  }

  let ZH_DIR = 'client/locale/zh/messages.json'
  let EN_DIR = 'client/locale/en/messages.json'
  let DESIGN_ZH_DIR = 'client/design/locale/zh/messages.json'
  let DESIGN_EN_DIR = 'client/design/locale/en/messages.json'

  if $bizType not-in $I18 {
    $'Locale ID for biz type: ($bizType) has not been configured, please try agian...'
    exit --now
  }

  $'Running get locales for (ansi p)($bizType)(ansi reset)...'
  let PID = ($I18 | get $bizType).PID
  let DESIGN_PID = ($I18 | get $bizType).DESIGN_PID
  termix locale-get $PID -o $'mall-($bizType)/($ZH_DIR)'
  termix locale-get $PID -o $'mall-($bizType)/($EN_DIR)' -f
  termix locale-get $DESIGN_PID -o $'mall-($bizType)/($DESIGN_ZH_DIR)'
  termix locale-get $DESIGN_PID -o $'mall-($bizType)/($DESIGN_EN_DIR)' -f
}
