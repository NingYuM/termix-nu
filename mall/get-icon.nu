#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/17 17:20:56
# 该命令会根据提供的 iconfont Symbol JS 地址更新图标到本地指定项目里
#
# 需要全局安装了 @terminus/termix, 最低版本 v1.2.16;
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 使用:
#   nu scripts/nu/get-icon.nu b2c //at.alicdn.com/t/font_1949908_fie05xdkkq7.js
#   npm run icon:get b2c //at.alicdn.com/t/font_1949908_fie05xdkkq7.js

# Check if some command available in current shell

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

# 根据`业务类型`和 `Iconfont Symbol JS 地址` 生成图标配置文件, 两个入参必填
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
  iconFontURL?: string,    # Iconfont Symbol JS 地址, 比如: //at.alicdn.com/t/font_1949908_fie05xdkkq7.js
] {
  if ($bizType == null or $iconFontURL == null) {
    print $'(char nl)Usage: nu get-icon.nu (ansi r)<bizType> <iconFontURL>(ansi reset)'; hr-line
    print $'(ansi g)Description: (ansi reset)根据`业务类型`和 `Iconfont Symbol JS 地址` 生成图标配置文件, 两个入参必填'
    print $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    print $'请确保参数输入无误并重试!(char nl)'
    exit 7
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if (not $bizCheck) {
    print $'(ansi r)You have input the wrong biz type, Please try again!(ansi reset)(char nl)'
    exit 7
  }

  if (is-installed 'termix') {
    print $'Current termix version: (ansi g)(termix --version | str trim)(ansi reset)'; hr-line
  } else {
    print $'(ansi r)Command `termix` could not be found, Please install it by `npm i -g @terminus/termix@latest`, and try again!(ansi reset)'
    exit 2
  }

  print $'Running fetch icons from ($iconFontURL) for (ansi p)($bizType)(ansi reset)...'
  # The following does NOT work currently
  # termix icon --output=$'./mall-($bizType)/client/fonts' $iconFontURL
  termix icon $'--output=./mall-($bizType)/client/fonts' $iconFontURL
}
