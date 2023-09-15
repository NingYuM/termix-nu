#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/18 18:50:56
# 使用 tinypng api 压缩本地图片;
# 需要全局安装 @terminus/termix，最低版本 v1.2.1;
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 当前压缩 ./src/images、./src/design/images 中的图片
# 使用:
#   nu compress-image.nu b2c

use std [repeat]

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

# 根据`业务类型` 使用 tinypng api 压缩指定业务类型的本地图片, 入参必填
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    print $'(char nl)Usage: nu compress-image.nu (ansi r)<bizType>(ansi reset)'; hr-line
    print $'(ansi g)Description: (ansi reset)根据`业务类型`压缩本地 `./client/images`、`./client/design/images` 中的图片'
    print $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    print $'请确保参数输入无误并重试!(char nl)'
    exit 7
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if (not $bizCheck) {
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

  print $'Running compress images for (ansi p)($bizType)(ansi reset)...'
  termix compress $'mall-($bizType)/client/images'
  termix compress $'mall-($bizType)/client/design/images'
}
