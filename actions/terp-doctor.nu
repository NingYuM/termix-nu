#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/07/25 16:06:56
# Description:
#   Doctor for TERP, Try to diagnose and show TERP app's problems.
# TODO:
#   [√] Make sure host alive
#   [√] Checking terp-assets forwarding configured correctly
#   [√] Test if it's a valid host URL before checking
#   [ ] Checking latest.json forwarding configured correctly
#   [ ] Nginx forwarding policy check
#   [ ] Make sure base,base-mobile,service,service-mobile,iam,terp,terp-mobile available in latest.json
#   [ ] Trantor version and static assets version match
#   [ ] 0330以及以后版本必须要有蓝色主题
# Usage:
#   t doctor portal-dev.poc.erda.cloud
#   t doctor https://portal-test.app.terminus.io
#   t doctor https://portal-staging.app.terminus.io
#   t doctor https://norhor-erp-portal.norhorerp.cn
#   t doctor https://portal-staging.go1688.terminus.io
#   t doctor https://t-erp-portal-test.app.terminus.io
#   t doctor https://sanlux-runtime-portal-test.sanlux.net

use ../utils/common.nu [ECODE, HTTP_HEADERS, HOST_PATTERN, hr-line]

const ASSETS = [
  { path: 'terp-assets/fonts/msyh/f0adcba202.woff2', type: 'font/woff2' },
  { path: 'terp-assets/js/xlsx-0.20.0.full.min.js', type: 'text/javascript' },
  # { path: 'terp-assets/js/xlsx-0.20.0.full.min.jsx', type: 'text/javascript' },
  { path: 'terp-assets/fonts/UniGB-UTF32-V.bcmap', type: 'application/octet-stream' },
  { path: 'terp-assets/monaco-editor/0.52.2/min/vs/loader.js', type: 'text/javascript' },
]

# Essential rules for the response of latest.json
const ESSENTIAL_RULES = [
  { key: 'cache-control', value: 'no-cache' },
  { key: 'content-type', value: 'application/json' },
]

const STORAGE_IDENTIFIER = {
  aliyun: [ 'x-oss-request-id' ],
  minio: [ 'x-amz-id-2', 'x-amz-request-id' ],
  volc: [ { key: 'server', value: 'volcclb' } ],
  local: [ { key: 'x-trantor-endpoint', value: 'local' } ],
}

const FIXING_TIPS = {
  invalid-host: $'(ansi r)[ERROR](ansi rst) 无效的 host，请确保 host 输入正确',
  terp-assets-missing-some: $'(ansi y)[WARN](ansi rst) terp-assets 目录存在，但缺少部分文件，请核查确认是否正常',
  terp-assets-missing: $'(ansi r)[ERROR](ansi rst) terp-assets 目录不存在，请确保该静态资源包已经初始化并且添加了网关转发配置',
  latest-local-warning: $'(ansi y)[WARN](ansi rst) 当前应用使用本地 latest.json 文件，静态资源发布可能不会生效，建议通过网关转发',
  latest-resp-error: $'(ansi r)[ERROR](ansi rst) latest.json 响应错误，请检查网关转发配置',
  missing-nginx-endpoint: $'(ansi r)[ERROR](ansi rst) 缺少 `x-trantor-endpoint` Nginx 自定义配置，请检查网关 latest.json 的业务策略',
}

# Diagnose TERP app settings and try to figure out the problems
export def terp-diagnose [host: string] {
  let host = $host | str trim -c '/'
  let host = if ($host =~ 'https?://') { $host } else { $'https://($host)' }
  if $host !~ $HOST_PATTERN { print $FIXING_TIPS.invalid-host; return }
  check-latest-json $host
  check-terp-assets $host
}

# Check latest.json response
def check-latest-json [host: string] {
  print 'Checking latest.json... '; hr-line
  let url = ($host)/latest.json
  let resp = http get -ef $url -H $HTTP_HEADERS
  if $resp.status != 200 { print $FIXING_TIPS.latest-resp-error; return }

  print $'(ansi y)Guess Storage Provider: (ansi rst)(guess-storage-provider $resp)'
  mut essential_matched = true
  # Check ESSENTIAL_RULES
  for rule in $ESSENTIAL_RULES {
    let value = get-header-value $resp $rule.key
    if $value != $rule.value {
      $essential_matched = false
      print $'Response header `($rule.key)` expected: (ansi g)($rule.value)(ansi rst), actual: (ansi r)($value)(ansi rst)'
    }
  }
  if not $essential_matched { print $FIXING_TIPS.latest-resp-error; return }

  # Check WARNING_RULES
  mut warning_matched = false
  let WARNING_RULES = [
    { key: 'x-trantor-endpoint', value: {|v| $v == 'local' }, msg: $FIXING_TIPS.latest-local-warning },
    { key: 'x-trantor-endpoint', value: {|v| $v | is-empty }, msg: $FIXING_TIPS.missing-nginx-endpoint },
  ]
  for rule in $WARNING_RULES {
    let value = get-header-value $resp $rule.key
    if (do $rule.value $value) {
      $warning_matched = true
      print ($rule.msg)(char nl)
    }
  }

  if not $warning_matched { print $'(ansi g)Ok(ansi rst)' }
}

# Guess storage provider from response headers
def guess-storage-provider [resp: record] {
  let aliyun = get-header-value $resp $STORAGE_IDENTIFIER.aliyun.0
  if ($aliyun | is-not-empty) { return 'AliyunOSS' }
  let volc = get-header-value $resp $STORAGE_IDENTIFIER.volc.0.key
  if ($volc == $STORAGE_IDENTIFIER.volc.0.value) { return 'VolcEngine' }
  let m0 = get-header-value $resp $STORAGE_IDENTIFIER.minio.0
  let m1 = get-header-value $resp $STORAGE_IDENTIFIER.minio.1
  if ($m0 | is-not-empty) and ($m1 | is-not-empty) { return 'Minio' }
  let local = get-header-value $resp $STORAGE_IDENTIFIER.local.0.key
  if ($local == $STORAGE_IDENTIFIER.local.0.value) { return 'Local' }
  'Unknown'
}

# Check terp-assets and gateway forwarding policy
def check-terp-assets [host: string] {
  print 'Checking terp-assets... '; hr-line
  mut result = []
  for asset in $ASSETS {
    let url = $'($host)/($asset.path)'
    let resp = http get -ef $url -H $HTTP_HEADERS
    let content_type = get-header-value $resp content-type
    if $resp.status == 200 and $content_type =~ $asset.type {
      $result = $result | append { asset: $asset.path, status: 'Ok' }
    } else if $resp.status == 404 {
      let error = parse-response $resp
      $result = $result | append { asset: $asset.path, status: 'Not Found', ...$error }
    } else {
      $result = $result | append { asset: $asset.path, status: 'Error' }
    }
  }

  if ($result | all {|r| $r.status == 'Ok' }) {
    print $'(ansi g)Ok(ansi reset)'; return
  }
  if ($result | any {|r| $r.status == 'Ok' }) {
    print (char nl)($FIXING_TIPS.terp-assets-missing-some); hr-line
    $result | where status != 'Ok' | table -t light | print; return
  }
  print ($FIXING_TIPS.terp-assets-missing)(char nl)
}

def parse-response [resp: record] {
  let content_type = get-header-value $resp content-type
  if $content_type =~ 'application/xml' {
    let code = $resp.body.content | where tag == Code | get content.content | get 0.0
    let bucket = $resp.body.content | where tag == HostId | get content.content | get 0.0
    return { code: $code, bucket: $bucket }
  }
  {}
}

# Get header value from response
def get-header-value [resp: record, name: string] {
  let matches = $resp.headers.response | where name == $name
  if ($matches | is-empty) { return '' }
  $matches | first | get value
}

alias main = terp-diagnose
