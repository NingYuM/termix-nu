#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/18 18:50:56
# 使用 tinypng api 压缩本地图片;
# 需要全局安装 @terminus/termix，最低版本 v1.2.1;
# 当前压缩 ./src/images、./src/design/images 中的图片
# 使用:
#   nu compress-image.nu b2c

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  ((which $app | length) > 0)
}

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank-line { char nl }
}

# 根据`业务类型` 使用 tinypng api 压缩指定业务类型的本地图片, 入参必填
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    $'(char nl)Usage: nu compress-image.nu (ansi r)<bizType>(ansi reset)'; hr-line
    $'(ansi g)Description: (ansi reset)根据`业务类型`压缩本地 `./client/images`、`./client/design/images` 中的图片'
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

  $'Running compress images for (ansi p)($bizType)(ansi reset)...'
  termix compress $'mall-($bizType)/client/images'
  termix compress $'mall-($bizType)/client/design/images'
}
