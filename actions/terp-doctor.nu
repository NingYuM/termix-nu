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
#   t doctor https://portal-test.app.terminus.io
#   t doctor https://norhor-erp-portal.norhorerp.cn
#   t doctor https://t-erp-portal-test.app.terminus.io
#   t doctor https://terp-poc-portal-dev.poc.erda.cloud
#   t doctor https://sanlux-runtime-portal-test.sanlux.net

use ../utils/common.nu [ECODE, HTTP_HEADERS, HOST_PATTERN, hr-line]

const ASSETS = [
  { path: 'terp-assets/fonts/msyh/f0adcba202.woff2', type: 'font/woff2' },
  { path: 'terp-assets/js/xlsx-0.20.0.full.min.js', type: 'text/javascript' },
  # { path: 'terp-assets/js/xlsx-0.20.0.full.min.jsx', type: 'text/javascript' },
  { path: 'terp-assets/fonts/UniGB-UTF32-V.bcmap', type: 'application/octet-stream' },
  { path: 'terp-assets/monaco-editor/0.52.2/min/vs/loader.js', type: 'text/javascript' },
]

const FIXING_TIPS = {
  invalid-host: '[ERROR] 无效的 host，请确保 host 输入正确',
  terp-assets-missing: '[ERROR] terp-assets 目录不存在，请确保该静态资源已经初始化并且添加了网关转发配置',
  terp-assets-missing-some: '[ERROR] terp-assets 目录存在，但缺少部分文件，请重新初始化配置静态资源',
  local-latest-json: '[WARN] 当前应用使用本地 latest.json 文件，静态资源发布可能不会生效，建议通过网关转发',
}

# Diagnose TERP app settings and try to figure out the problems
export def terp-diagnose [host: string] {
  let host = $host | str trim -c '/'
  let host = if ($host =~ 'https?://') { $host } else { $'https://($host)' }
  if $host !~ $HOST_PATTERN {
    print $'(ansi r)($FIXING_TIPS.invalid-host)(ansi reset)'; return
  }
  check-terp-assets $host
}

# Check terp-assets and gateway forwarding policy
def check-terp-assets [host: string] {
  print 'Checking terp-assets... '
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
    print $'(char nl)(ansi r)($FIXING_TIPS.terp-assets-missing-some)(ansi reset)'; hr-line
    $result | where status != 'Ok' | table -t light | print; return
  }
  print $'(char nl)(ansi r)($FIXING_TIPS.terp-assets-missing)(ansi reset)'
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
  $resp.headers.response | where name == $name | first | get value
}

alias main = terp-diagnose
