#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/18 13:50:56
# 上传图片到CDN, 需要根目录下有 oss-conf.json 配置文件;
# 并全局安装了 @terminus/termix, 最低版本 v1.2.1;
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 使用:
#   nu upload-image.nu b2c
#   npm run image:upload b2c

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  (which $app | length) > 0
}

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank_line { char nl }
}

# 根据`业务类型` 上传指定业务类型图片到CDN, 入参必填
def main [
  bizType?: string,        # 业务类型: b2c|b2b|scrm|sea|point
] {
  if ($bizType == $nothing) {
    print $'(char nl)Usage: nu upload-image.nu (ansi r)<bizType>(ansi reset)'; hr-line
    print $'(ansi g)Description: (ansi reset)根据`业务类型`上传图片到CDN, 需要根目录下有 oss-conf.json 配置文件;'
    print $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / scrm / sea / point'
    print $'请确保参数输入无误并重试!(char nl)'
    exit 7
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
  if (not $bizCheck) {
    print $'(ansi r)You have input the wrong biz type, Please try again!(ansi reset)(char nl)'
    exit 7
  }

  let OSS_CONF = './oss-conf.json'
  if not ($OSS_CONF | path exists) {
    print $"Oss config file (ansi r)'oss-conf.json' not found!(ansi reset) Please add it and try again!"
    exit 3
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

  print $'Running upload images for (ansi p)($bizType)(ansi reset)...'
  let OUTPUT = $'mall-($bizType)/cdn-images.json'
  # Remove mall-$bizType/cdn-images.json config file
  rm $OUTPUT
  termix upload -c $OSS_CONF -i tab -o $OUTPUT $'--prefix=_($bizType)' $'mall-($bizType)/client/images'
  termix upload -c $OSS_CONF -i thumbnails -o $OUTPUT $'--prefix=_($bizType)' --key-prefix=design $'mall-($bizType)/client/design/images'
}
