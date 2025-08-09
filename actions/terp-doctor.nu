#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/07/25 16:06:56
# Description:
#   Doctor for TERP, Try to diagnose and show TERP app's problems.
# TODO:
#   [√] Make sure host alive
#   [√] Checking terp-assets forwarding configured correctly
#   [√] Test if it's a valid host URL before checking
#   [√] Checking latest.json forwarding configured correctly
#   [√] Nginx forwarding policy check
#   [√] Make sure base,base-mobile,service,service-mobile,iam,terp,terp-mobile available in latest.json
#   [ ] Trantor version and static assets version match: http get https://console-staging.app.terminus.io/api/trantor/platform
#   [ ] 元数据静态化是否开启？
#   [ ] 丰富提示信息，附带修复指南
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

# Essential modules for latest.json
const ESSENTIAL_MODULES = [base, base-mobile, service, service-mobile, iam, terp, terp-mobile]

# Storage provider identification rules
const STORAGE_PROVIDERS = [
  { name: 'AliyunOSS', headers: [{ key: 'x-oss-request-id', type: 'exists' }] },
  { name: 'VolcEngine', headers: [{ key: 'server', type: 'equals', value: 'volcclb' }] },
  { name: 'Local', headers: [{ key: 'x-trantor-endpoint', type: 'equals', value: 'local' }] },
  { name: 'Minio', headers: [{ key: 'x-amz-id-2', type: 'exists' }, { key: 'x-amz-request-id', type: 'exists' }] },
]

# Warning rules for latest.json response
const WARNING_RULES = [
  { key: 'x-trantor-endpoint', condition: 'equals', value: 'local', message: 'latest-local-warning' },
  { key: 'x-trantor-endpoint', condition: 'empty', value: '', message: 'missing-nginx-endpoint' },
]

const FIXING_TIPS = {
  invalid-host: $'(ansi r)[ERROR](ansi rst) 无效的 host，请确保 host 输入正确',
  terp-assets-missing-some: $'(ansi y)[WARN](ansi rst) terp-assets 目录存在，但缺少部分文件，请核查确认是否正常',
  terp-assets-missing: $'(ansi r)[ERROR](ansi rst) terp-assets 目录不存在，请确保该静态资源包已经初始化并且添加了网关转发配置',
  latest-local-warning: $'(ansi y)[WARN](ansi rst) 当前应用使用本地 latest.json 文件，静态资源发布可能不会生效，建议通过网关转发',
  latest-resp-error: $'(ansi r)[ERROR](ansi rst) latest.json 响应错误，请检查网关转发配置',
  missing-nginx-endpoint: $'(ansi r)[ERROR](ansi rst) 缺少 `x-trantor-endpoint` Nginx 自定义配置，请检查网关 latest.json 的业务策略',
}

# Diagnose TERP app settings and try to figure out the problems
#
# This function performs comprehensive checks on a TERP application:
# 1. Validates the host URL format
# 2. Checks latest.json response and headers
# 3. Validates terp-assets availability and forwarding
export def terp-diagnose [host: string] {
  # Normalize the host URL
  let host = $host | str trim -c '/'
  let host = if ($host =~ 'https?://') { $host } else { $'https://($host)' }

  # Validate host format
  if $host !~ $HOST_PATTERN { print $FIXING_TIPS.invalid-host; return }

  # Perform diagnostic checks
  check-latest-json $host
  check-terp-assets $host
}

# Check latest.json response
def check-latest-json [host: string] {
  print 'Checking latest.json... '; hr-line
  let url = ($host)/latest.json
  let resp = http get -ef $url -H $HTTP_HEADERS

  if $resp.status != 200 { print $FIXING_TIPS.latest-resp-error; return }

  print $'(ansi y)云存储: (ansi rst)(guess-storage-provider $resp) (ansi grey66)（推测，仅供参考）(ansi rst)'

  # Check essential rules first
  if not (check-essential-rules $resp) { print $FIXING_TIPS.latest-resp-error; return }

  # Check warning rules
  let warnings = check-warning-rules $resp | append (check-latest-modules $resp)
  if ($warnings | is-empty) {
    print $'(ansi g)Ok(ansi rst)'
  } else {
    $warnings | each { |w| print $w } | ignore
  }
}

# Check latest.json response
def check-latest-modules [resp: record] {
  let modules = $resp.body | columns
  let missing_modules = $ESSENTIAL_MODULES | where $it not-in $modules
  if ($missing_modules | is-empty) { return [] }
  [$'(ansi y)[WARN](ansi rst) latest.json 缺少模块: (ansi r)($missing_modules | str join ,)(ansi rst)']
}

# Check essential rules for latest.json response
def check-essential-rules [resp: record] {
  mut all_passed = true
  for rule in $ESSENTIAL_RULES {
    let value = get-header-value $resp $rule.key
    if $value != $rule.value {
      $all_passed = false
      print $'Response header `($rule.key)` expected: (ansi g)($rule.value)(ansi rst), actual: (ansi r)($value)(ansi rst)'
    }
  }
  $all_passed
}

# Check warning rules for latest.json response
def check-warning-rules [resp: record] {
  mut warnings = []
  for rule in $WARNING_RULES {
    let value = get-header-value $resp $rule.key
    if (check-condition $value $rule.condition $rule.value) {
      $warnings = $warnings | append ($FIXING_TIPS | get $rule.message)
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
def check-terp-assets [host: string] {
  print $'(char nl)Checking terp-assets... '; hr-line

  let results = $ASSETS | each { |asset| check-single-asset $host $asset }
  let ok_count = $results | where status == 'Ok' | length
  let total_count = $results | length

  display-asset-results $results $ok_count $total_count
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
def display-asset-results [results: list, ok_count: int, total_count: int] {
  match [$ok_count, $total_count] {
    [$count, $total] if $count == $total => {
      print $'(ansi g)Ok(ansi rst)'
    },
    [$count, _] if $count > 0 => {
      print (char nl)($FIXING_TIPS.terp-assets-missing-some); hr-line
      $results | where status != 'Ok' | table -t light | print
    },
    _ => {
      print ($FIXING_TIPS.terp-assets-missing)(char nl)
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
