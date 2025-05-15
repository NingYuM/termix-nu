
const COLOR_MAP = {
    # 主题色替换
    '@primary-85' : '@primary-1'
    '@primary-70' : '@primary-1'
    '@primary-50' : '@primary-2'
    '@primary-20' : '@primary-3'
    '@primary-8' : '@primary-4'
    '@primary-4' : '@primary-4'
    'rgba(var(--custom-primary))' : '@primary'
    'rgba(var(--custom-primary-85))' : '@primary-1'
    'rgba(var(--custom-primary-70))' : '@primary-1'
    'rgba(var(--custom-primary-50))' : '@primary-2'
    'rgba(var(--custom-primary-20))' : '@primary-3'
    'rgba(var(--custom-primary-8))' : '@primary-4'
    'rgba(var(--custom-primary-4))' : '@primary-4'
    # 中性色替换
    '@middle-85' : '@middle-1'
    '@middle-70' : '@middle-1'
    '@middle-55' : '@middle-2'
    '@middle-40' : '@middle-3'
    '@middle-20' : '@middle-4'
    '@middle-10' : '@middle-4'
    '@middle-2' : '@middle-7'
    'rgba(var(--custom-neutral-2))' : '@middle-7'
    '@middle-6' : '@middle-5'
    'rgba(var(--custom-neutral))' : '@middle'
    'rgba(var(--custom-neutral-85))' : '@middle-1'
    'rgba(var(--custom-neutral-70))' : '@middle-1'
    'rgba(var(--custom-neutral-55))' : '@middle-2'
    'rgba(var(--custom-neutral-40))' : '@middle-3'
    'rgba(var(--custom-neutral-6))' : '@middle-5'
    '@middle-4' : '@middle-6'
    'rgba(var(--custom-neutral-4))' : '@middle-6'
    'rgba(var(--custom-neutral-20))' : '@middle-4'
    'rgba(var(--custom-neutral-10))' : '@middle-4'
    # 错误色替换
    '@error-10' : '@1error-100'
    '@error-20' : '@1error-200'
    '@error-60' : '@1error-600'
    '@error' : '@error-dark'
    '@1error-100' : '@error'
    '@1error-200' : '@error-light'
    '@1error-600' : '@error-hover'
    # 警告色替换
    '@warn-10' : '@1warn-100'
    '@warn-20' : '@1warn-200'
    '@warn' : '@warn-dark'
    '@1warn-100' : '@warn'
    '@1warn-200' : '@warn-light'
    # 提示色替换
    '@info-10' : '@1info-100'
    '@info-20' : '@1info-200'
    '@info' : '@info-dark'
    '@1info-100' : '@info'
    '@1info-200' : '@info-light'
    # 成功色替换
    '@success-10' : '@1success-100'
    '@success-20' : '@1success-200'
    '@success' : '@success-dark'
    '@1success-100' : '@success'
    '@1success-200' : '@success-light'
    # 圆角替换
    '@rounded-6' : '@rounded-sm'
    '@rounded-8' : '@rounded-md'
    '@rounded-12' : '@rounded-lg'
    '@rounded-16' : '@rounded-xl'
};

const ICON_MAP = {
    # ICON 替换
    'CloseSmall' : 'Close'
}

const source = '/Users/hustcer/iWork/terminus/terp-ui/packages/pc/src'

# sd '@primary-8' '@primary-4' ($'($source)/**/*/*.*' | into glob)

for ky in ($COLOR_MAP | columns) {
    sd $ky ($COLOR_MAP | get $ky) ($'($source)/**/*/*.*' | into glob)
}

for ky in ($ICON_MAP | columns) {
    sd $ky ($ICON_MAP | get $ky) ($'($source)/**/*/*.*' | into glob)
}
