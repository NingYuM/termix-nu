# Author: hustcer
# Created: 2021/09/13 19:37:30

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
# 使用:
#   nu scripts/nush/clean-locale.nu b2c
#   npm run locale:clean b2c

def check-termix [] {
  let check = (which termix | length)
  if $check == 0 {
    echo "Command 'termix' could not be found, Please install it by 'npm i -g @terminus/termix@latest', and try again!"
    exit 1
  } else {
    let termixVer = (termix --version)
    echo "Current termix version: " $termixVer | str collect
  }
}

check-termix
