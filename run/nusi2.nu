# REF:
#   1.  https://github.com/chmln/sd

const COLOR_MAP = {
    # 主题色替换
    'rgb(var(--nusi-primary))' : '@primary'
    'rgb(var(--nusi-primary-1))' : '@primary-1'
    'rgb(var(--nusi-primary-2))' : '@primary-2'
    'rgb(var(--nusi-primary-3))' : '@primary-3'
    'rgb(var(--nusi-primary-4))' : '@primary-4'
    # 中性色替换
    'rgb(var(--nusi-neutral))' : '@middle'
    'rgb(var(--nusi-neutral-1))' : '@middle-1'
    'rgb(var(--nusi-neutral-2))' : '@middle-2'
    'rgb(var(--nusi-neutral-3))' : '@middle-3'
    'rgb(var(--nusi-neutral-4))' : '@middle-4'
    'rgb(var(--nusi-neutral-5))' : '@middle-5'
    'rgb(var(--nusi-neutral-6))' : '@middle-6'
    'rgb(var(--nusi-neutral-7))' : '@middle-7'
    'rgb(var(--nusi-neutral-55))' : '@middle-2'
    'rgb(var(--nusi-neutral-85))' : '@middle-1'
    'rgb(var(--nusi-neutral-20))' : '@middle-4'
    'rgb(var(--nusi-neutral-10))' : '@middle-4'
    'rgb(var(--nusi-neutral-40))' : '@middle-3'
    # 错误色替换
    'rgb(var(--nusi-error))': '@error'
    'rgb(var(--nusi-error-1))': '@error-light'
    'rgb(var(--nusi-error-2))': '@error-dark'
    'rgb(var(--nusi-error-3))': '@error-heavy'
    # 警告色替换
    'rgb(var(--nusi-warn))': '@warn'
    'rgb(var(--nusi-warn-1))': '@warn-light'
    'rgb(var(--nusi-warn-2))': '@warn-dark'
    # 提示色替换
    'rgb(var(--nusi-info))': '@info'
    'rgb(var(--nusi-info-1))': '@info-light'
    'rgb(var(--nusi-info-2))': '@info-dark'
    # 成功色替换
    'rgb(var(--nusi-success))': '@success'
    'rgb(var(--nusi-success-1))': '@success-light'
    'rgb(var(--nusi-success-2))': '@success-dark'
    # 其他颜色替换
    'rgb(var(--nusi-text))': '@color-text'
    'rgb(var(--nusi-color-white))': '@color-white'
};

const source = '/Users/hustcer/iWork/terminus/terp-ui/packages/pc/src'

for ky in ($COLOR_MAP | columns) {
    sd -F $ky ($COLOR_MAP | get $ky) ($'($source)/**/*.less' | into glob)
}
