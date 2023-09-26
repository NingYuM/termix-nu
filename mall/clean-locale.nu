# Author: hustcer
# Created: 2022/03/29 17:15:20

# 该命令会清除指定文件夹下多余的文案，清理文案的逻辑：先用`formatjs`扫描指定文件夹生成所有使用到
# 的文案集假设为`A集合`，然后跟`src/locale`下的中英文案并集设为`B集合`进行对比，所有在`B集合`
# 而不在`A集合`里面的文案假设为`C集合`，在严格模式下`C集合`里面的文案会被直接删除掉，在非严格模
# 式下如果`C集合`里面的key是中文的直接会被标记成待删除的（因为目前国际化文案key命名规则不允许为
# 中文，方便潜在国外客户阅读），对于`C集合`里面的英文key假设为`D集合`，`D集合`里面的文案虽然不在
# `A集合`里面但仍然有可能是合法的国际化文案key（比如国际化代码被注释掉或者编写不规范导致未被扫描
# 出来），此时会对`D集合`里面的文案key进行全文搜索，如果未找到则会被标记为待删除，如果可以找到则
# 这部分文案会输出给用户，提示用户自己手工核对，自行决定是否删除；
#
# 需要全局安装了 @terminus/termix, 最低版本 v2.0.0;
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# 使用:
#   nu clean-locale.nu b2c
#   npm run locale:clean b2c

# use ./mall/i18n.nu [get-i18n-conf]

# let I18 = (get-i18n-conf)

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
  --blank-line(-b),
  --with-arrow(-a),
] {
  print $'(ansi $color)('─' | repeat $width | str join)(if $with_arrow {'>'})(ansi reset)'
  if $blank_line { char nl }
}

# 根据`业务类型`从本地清除指定业务类型文件夹下多余的国际化文案
def main [
  bizType?: string,        # 业务类型: b2c|b2b|sea
] {
  if ($bizType == null) {
    print $'(char nl)Usage: nu clean-locale.nu (ansi r)<bizType>(ansi reset)'; hr-line
    print $'(ansi g)Description: (ansi reset)根据`业务类型`从本地清除指定业务类型文件夹下多余的国际化文案'
    print $'(ansi g)Supported bizTypes: (ansi reset)b2c / b2b / sea'
    print $'请确保参数输入无误并重试!(char nl)'
    exit 7
  }

  let bizCheck = $bizType in ['b2c', 'b2b', 'sea']
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

  if $bizType not-in $I18 {
    print $'Locale ID for biz type: ($bizType) has not been configured, please try again...'
    exit 3
  }

  print $'Running clean locale for (ansi p)($bizType)(ansi reset)...'
  let PID = ($I18 | get $bizType).PID
  let DESIGN_PID = ($I18 | get $bizType).DESIGN_PID
  termix locale-clean $'--pid=($PID)' --strict $'mall-common,mall-($bizType)'
  termix locale-clean $'--pid=$(DESIGN_PID)' --extract-design --strict $'mall-common,mall-($bizType)'
  npm run locale:get $bizType
}
