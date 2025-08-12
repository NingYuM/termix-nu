#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/07/25 16:06:56
# Description:
#   Doctor for TERP, Try to diagnose and show TERP app's problems.
# TODO:
#   [√] Make sure host alive
#   [√] Allow checking multiple hosts at once
#   [√] Checking terp-assets forwarding configured correctly
#   [√] Test if it's a valid host URL before checking
#   [√] Checking latest.json forwarding configured correctly
#   [√] Nginx forwarding policy check
#   [√] Make sure base,base-mobile,service,service-mobile,iam,terp,terp-mobile available in latest.json
#   [ ] Trantor version and static assets version match: http get https://console-staging.app.terminus.io/api/trantor/platform
#   [ ] 元数据静态化是否开启？
#   [√] 丰富提示信息，附带修复指南
# Usage:
#   t doctor portal-dev.poc.erda.cloud
#   t doctor https://portal-test.app.terminus.io
#   t doctor https://portal-staging.app.terminus.io
#   t doctor https://norhor-erp-portal.norhorerp.cn
#   t doctor https://portal-staging.go1688.terminus.io
#   t doctor https://t-erp-portal-test.app.terminus.io
#   t doctor https://sanlux-runtime-portal-test.sanlux.net

use ../utils/common.nu [ECODE, HTTP_HEADERS, HOST_PATTERN]
use ../utils/common.nu [hr-line, get-termix-conf, render-ansi]

const ASSETS = [
  { path: 'terp-assets/fonts/msyh/f0adcba202.woff2', type: 'font/woff2' },
  { path: 'terp-assets/js/xlsx-0.20.0.full.min.js', type: 'text/javascript' },
  # { path: 'terp-assets/js/xlsx-0.20.0.full.min.jsx', type: 'text/javascript' },
  { path: 'terp-assets/fonts/UniGB-UTF32-V.bcmap', type: 'application/octet-stream' },
  { path: 'terp-assets/monaco-editor/0.52.2/min/vs/loader.js', type: 'text/javascript' },
]

# Essential rules for the response of latest.json
const ESSENTIAL_RULES = [
  { file: 'latest.json', key: 'cache-control', value: ['no-cache'] },
  { file: 'latest.json', key: 'content-type', value: ['application/json'] },
  { file: 'iconpark.js', key: 'cache-control', value: ['no-cache'] },
  { file: 'iconpark.js', key: 'content-type', value: ['text/javascript' 'application/javascript'] },
]

# Essential modules for latest.json
const ESSENTIAL_MODULES = [base, base-mobile, service, service-mobile, iam, terp, terp-mobile]

# Storage provider identification rules
const STORAGE_PROVIDERS = [
  { name: 'AliyunOSS', headers: [{ key: 'x-oss-request-id', type: 'exists' }] },
  { name: 'VolcEngine', headers: [{ key: 'server', type: 'equals', value: 'volcclb' }] },
  { name: 'Local', headers: [{ key: 'x-trantor-endpoint', type: 'equals', value: 'local' }] },
  { name: 'MinIO', headers: [{ key: 'x-amz-id-2', type: 'exists' }, { key: 'x-amz-request-id', type: 'exists' }] },
]

# Warning rules for latest.json response
const WARNING_RULES = [
  { key: 'x-trantor-endpoint', condition: 'equals', value: 'local', message: 'latest-local-warning', tip: 'latest-gateway' },
  { key: 'x-trantor-endpoint', condition: 'empty', value: '', message: 'missing-nginx-endpoint', tip: 'latest-endpoint' },
]

const FIXING_TIPS = {
  invalid-host: $'(ansi r)[ERROR](ansi rst) 无效的 host，请检查并确保以下 host 输入正确(char nl)',
  terp-assets-missing-some: $'(ansi y)[WARN](ansi rst) terp-assets 目录存在，但缺少部分文件，请核查确认是否正常',
  terp-assets-missing: $'(ansi r)[ERROR](ansi rst) terp-assets 目录不存在，请确保该静态资源包已经初始化并且添加了网关转发配置',
  latest-local-warning: $'(ansi y)[WARN](ansi rst) 当前应用使用本地 latest.json 文件，静态资源发布可能不会生效，建议通过网关转发',
  latest-resp-error: $'(ansi r)[ERROR](ansi rst) latest.json 响应错误，请检查网关转发配置',
  missing-nginx-endpoint: $'(ansi y)[WARN](ansi rst) 缺少 `x-trantor-endpoint` Nginx 自定义配置，请检查网关 latest.json 的业务策略',
}

# Diagnose TERP app settings and try to figure out the problems
#
# This function performs comprehensive checks on a TERP application:
# 1. Validates the host URL format
# 2. Checks latest.json response and headers
# 3. Validates terp-assets availability and forwarding
export def terp-diagnose [host: string] {
  let _TERMIX_CONF = get-termix-conf
  $env.config.table.padding = { left: 0, right: 1 }
  let tips = open $_TERMIX_CONF | get TERP_CONFIG_TIPS

  let validation = validate-hosts $host
  if ($validation.invalid | is-not-empty) {
    print -e $FIXING_TIPS.invalid-host
    print -e ($validation.invalid | table -t psql)
    exit $ECODE.INVALID_PARAMETER
  }

  # Perform diagnostic checks
  $validation.valid | each { |h|
    print $'(char nl)Checking (ansi g)($h)(ansi rst) ...'; hr-line -c p
    check-latest-json $h $tips
    check-terp-assets $h $tips
  }
}

# Validate hosts
def validate-hosts [hosts: string] {
  let candidates = $hosts | split row ','
  mut valid = []
  mut invalid = []
  for h in $candidates {
    let host = $h | str trim -c '/'
    let host = if ($host =~ 'https?://') { $host } else { $'https://($host)' }

    # Validate host format
    if $host =~ $HOST_PATTERN { $valid = ($valid | append $host) } else { $invalid = ($invalid | append $h) }
  }
  { valid: $valid, invalid: $invalid }
}

# Check latest.json response
def check-latest-json [host: string, tips: record] {
  print 'Checking latest.json... '; hr-line -c grey66
  let url = ($host)/latest.json
  let resp = http get -ef $url -H $HTTP_HEADERS

  if $resp.status != 200 {
    print $FIXING_TIPS.latest-resp-error
    match $resp.status {
      404 => { print -e $'        Remote response with: (ansi r)404 Not Found(ansi rst)' },
      502 => { print -e $'        Remote response with: (ansi r)502 Bad Gateway(ansi rst)' },
      _ => {}
    }
    return
  }
  let provider = guess-storage-provider $resp
  let ps = if $provider == 'Unknown' { '（我猜不出来）' } else { '（推测，仅供参考）' }
  print $'(ansi y)云存储: (ansi rst)($provider) (ansi grey66)($ps)(ansi rst)'

  # Check essential rules first
  if not (check-essential-rules $resp latest.json) { print $FIXING_TIPS.latest-resp-error; return }

  # Check warning rules
  let warnings = check-warning-rules $resp $tips | append (check-latest-modules $resp)
  if ($warnings | is-empty) {
    print $'(ansi g)Ok(ansi rst)'
  } else {
    $warnings | each { |w| print (render-ansi $w) } | ignore
  }
}

# Check latest.json response
def check-latest-modules [resp: record] {
  let modules = $resp.body | columns
  let missing_modules = $ESSENTIAL_MODULES | where $it not-in $modules
  if ($missing_modules | is-empty) { return [] }
  [$'(ansi y)[WARN](ansi rst) latest.json 缺少模块: (ansi r)($missing_modules | str join ,)(ansi rst)']
}

# Check essential rules for latest.json or iconpark.js response
def check-essential-rules [resp: record, file: string] {
  mut all_passed = true
  for rule in ($ESSENTIAL_RULES | where $it.file == $file) {
    let value = get-header-value $resp $rule.key
    if $value not-in $rule.value {
      $all_passed = false
      print -e $'Response header `($rule.key)` expected: (ansi g)($rule.value)(ansi rst), actual: (ansi r)($value)(ansi rst)'
    }
  }
  $all_passed
}

# Check warning rules for latest.json response
def check-warning-rules [resp: record, tips: record] {
  mut warnings = []
  for rule in $WARNING_RULES {
    let value = get-header-value $resp $rule.key
    if (check-condition $value $rule.condition $rule.value) {
      $warnings = $warnings | append ($FIXING_TIPS | get $rule.message)
                            | append (render-ansi ($tips | get $rule.tip))
    }
  }
  $warnings
}

# Check condition based on type
def check-condition [value: string, condition: string, expected: string] {
  match $condition {
    'equals' => ($value == $expected),
    'empty' => ($value | is-empty),
    'not-empty' => ($value | is-not-empty),
    _ => false
  }
}

# Guess storage provider from response headers using unified logic
def guess-storage-provider [resp: record] {
  for provider in $STORAGE_PROVIDERS {
    if (check-provider-headers $resp $provider.headers) {
      return $provider.name
    }
  }
  'Unknown'
}

# Check if all headers match for a storage provider
def check-provider-headers [resp: record, headers: list] {
  $headers | all { |header|
    let value = get-header-value $resp $header.key
    match $header.type {
      'exists' => ($value | is-not-empty),
      'equals' => ($value == $header.value),
      _ => false
    }
  }
}

# Check terp-assets and gateway forwarding policy
def check-terp-assets [host: string, tips: record] {
  print $'(char nl)Checking terp-assets... '; hr-line -c grey66

  let results = $ASSETS | each { |asset| check-single-asset $host $asset }

  display-asset-results $results $tips
}

# Check a single asset
def check-single-asset [host: string, asset: record] {
  let url = $'($host)/($asset.path)'
  let resp = http get -ef $url -H $HTTP_HEADERS
  let content_type = get-header-value $resp content-type

  match [$resp.status, ($content_type =~ $asset.type)] {
    [200, true] => { asset: $asset.path, status: 'Ok' },
    [404, _] => {
      let error_info = parse-response $resp
      { asset: $asset.path, status: 'Not Found', ...$error_info }
    },
    _ => { asset: $asset.path, status: 'Error', http_status: $resp.status }
  }
}

# Display asset checking results
def display-asset-results [results: list, tips: record] {
  let total_count = $results | length
  let ok_count = $results | where status == 'Ok' | length

  match [$ok_count, $total_count] {
    [$count, $total] if $count == $total => {
      print $'(ansi g)Ok(ansi rst)'
    },
    [$count, _] if $count > 0 => {
      print -e (char nl)($FIXING_TIPS.terp-assets-missing-some); hr-line
      $results | where status != 'Ok' | table -t light | print
    },
    _ => {
      print -e ($FIXING_TIPS.terp-assets-missing)(char nl)
      print (render-ansi $tips.terp-assets)
    }
  }
}

# Parse error response from storage providers
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
  match $matches {
    [] => '',
    $m => ($m | first | get value)
  }
}

alias main = terp-diagnose
