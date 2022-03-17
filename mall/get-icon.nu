#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/17 17:20:56
# 该命令会根据提供的 iconfont Symbol JS 地址更新图标到本地指定项目里
#
# 需要全局安装了 @terminus/termix, 最低版本 v1.2.16;
# 使用:
#   nu scripts/nu/get-icon.nu b2c //at.alicdn.com/t/font_1949908_fie05xdkkq7.js
#   npm run icon:get b2c //at.alicdn.com/t/font_1949908_fie05xdkkq7.js

def 'is-installed' [
    app: string     # The command to check
] {
    ((which $app | length) > 0)
}

def 'hr-line' [
    --blank-line(-b): bool
] {
    print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
    if $blank-line { char nl }
}

# 根据`业务类型`和 `Iconfont Symbol JS 地址` 生成图标配置文件, 两个入参必填
def main [
    bizType: string,        # 业务类型: b2c|b2b|scrm|sea|point
    iconFontURL: string,    # Iconfont Symbol JS 地址, 比如: //at.alicdn.com/t/font_1949908_fie05xdkkq7.js
] {
    if (is-installed 'termix') {
        $'Current termix version: (ansi g)(termix --version | str trim)(ansi reset)'; hr-line
    } else {
        $'(ansi r)Command `termix` could not be found, Please install it by `npm i -g @terminus/termix@latest`, and try again!(ansi reset)'
        exit --now
    }

    let bizCheck = $bizType in ['b2c', 'b2b', 'scrm', 'sea', 'point']
    if $bizCheck {
        $'Running fetch icons from ($iconFontURL) for (ansi p)($bizType)(ansi reset)...';
        # Fixme: Not work currrently
        # termix icon --output=$'./mall-($bizType)/client/fonts' $iconFontURL
        nu -c $'termix icon --output=./mall-($bizType)/client/fonts ($iconFontURL)'
    } else {
        $'(ansi r)You have input the wrong biz type, Please try again!(ansi reset)'
        exit --now
    }
}
