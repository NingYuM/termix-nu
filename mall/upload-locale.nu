#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/29 16:15:20
# 该命令会将指定文件夹下`locale/zh/messages.json` & `locale/en/messages.json`
# 里的中英文案合并起来并上传到国际化平台指定ID的项目里面；除了直接上传外也可
# 以扫描指定文件夹下的文案然后将输出结果上传；
#
# 需要全局安装了 @terminus/termix, 最低版本 v2.0.0;
# 需要安装 Nushell， 最低版本 v0.65.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 使用:
#   nu upload-locale.nu b2c

let I18 = {
  b2c: { PID: 5, DESIGN_PID: 6 },
  sea: { PID: 7, DESIGN_PID: 8 },
  b2b: { PID: 51, DESIGN_PID: 63 },
}

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  (which $app | length) > 0
}

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank-line { char nl }
}

# 根据`业务类型`从本地上传文案到国际化文案管理平台，也可以从源码扫描并上传；
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    $'(char nl)Usage: nu upload-locale.nu (ansi r)<bizType>(ansi reset)'; hr-line
    $'(ansi g)Description: (ansi reset)根据`业务类型`从本地上传文案到国际化文案管理平台，也支持从源码扫描并上传'
    $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    $'请确保参数输入无误并重试!(char nl)'
    exit --now
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if (not $bizCheck) {
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

  if $bizType not-in $I18 {
    $'Locale ID for biz type: ($bizType) has not been configured, please try agian...'
    exit --now
  }

  $'Running upload locale for (ansi p)($bizType)(ansi reset)...'
  let PID = ($I18 | get $bizType).PID
  let DESIGN_PID = ($I18 | get $bizType).DESIGN_PID
  termix locale-upload --from-extract $'--pid=($PID)' $'mall-common,mall-($bizType)'
  termix locale-upload --from-extract --extract-design $'--pid=$(DESIGN_PID)' $'mall-common,mall-($bizType)'
  npm run locale:get $bizType
}
