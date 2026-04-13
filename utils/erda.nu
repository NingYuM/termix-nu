#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/01/02 13:55:20

use ../utils/common.nu [ECODE, HTTP_HEADERS, get-tmp-path, 'from env']

export const ERDA_HOST = 'https://erda.cloud'
export const VALID_ENV = [DEV TEST STAGING PROD]

def --env load-erda-envs-from-dotenv [] {
  let termix_dir = $env.TERMIX_DIR? | default ''
  if ($termix_dir | is-empty) { return }

  let env_file = [$termix_dir '.env'] | path join
  if not ($env_file | path exists) { return }

  let dotenv = open --raw $env_file | from env
  mut loaded = {}

  let username = $dotenv.ERDA_USERNAME? | default ''
  if (($env.ERDA_USERNAME? | default '') | is-empty) and ($username | is-not-empty) {
    $loaded = ($loaded | upsert ERDA_USERNAME $username)
  }

  let password = $dotenv.ERDA_PASSWORD? | default ''
  if (($env.ERDA_PASSWORD? | default '') | is-empty) and ($password | is-not-empty) {
    $loaded = ($loaded | upsert ERDA_PASSWORD $password)
  }

  if ($loaded | columns | is-not-empty) {
    load-env $loaded
  }
}

# Check if the required environment variable was set, quit if not
export def --env check-erda-envs [] {
  load-erda-envs-from-dotenv
  # 部署/查询 Pipeline 操作需要先配置 ERDA_USERNAME & ERDA_PASSWORD
  let envs = ['ERDA_USERNAME' 'ERDA_PASSWORD']
  let empties = ($envs | where {|it| $env | get -o $it | is-empty })
  if ($empties | length) > 0 {
    print -e $'Please set (ansi r)($empties | str join ',')(ansi rst) in your environment first...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Get Erda OpenAPI auth token from .termix-conf file
export def get-erda-auth [host: string = $ERDA_HOST, --type: string = 'curl'] {
  let tokenKey = if $host == $ERDA_HOST { 'erdaToken' } else { $'($host | encode base64)_token' }
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let tokenInfo = open $TERMIX_CONF | from json | get -o $tokenKey
  let tokenInfo = match $tokenInfo { '' => {{}}, _ => $tokenInfo }
  let tokenType = $tokenInfo | get -o token_type | default 'Bearer'
  let accessToken = $tokenInfo | get -o access_token | default ''
  if $type == 'nu' {
    return ['Authorization' $'($tokenType) ($accessToken)' ...$HTTP_HEADERS]
  }
  $'Authorization: ($tokenType) ($accessToken)'
}

# Renew Erda auth token by username and password if expired
export def --env renew-erda-session [host: string = $ERDA_HOST, --get-uid] {
  load-erda-envs-from-dotenv
  if not $get_uid { print 'Renewing Erda auth token...' }
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let tokenKey = if $host == $ERDA_HOST { 'erdaToken' } else { $'($host | encode base64)_token' }
  let openApiHost = if ($host =~ 'openapi') { $host } else { $host | str replace '://' '://openapi.' }
  let LOGIN_URL = $'($openApiHost)/login'
  let payload = { username: $env.ERDA_USERNAME, password: $env.ERDA_PASSWORD }
  let renew = http post --content-type application/json $LOGIN_URL $payload
  if ($renew | is-empty) { print 'Try renew Erda auth token again...'; renew-erda-session $host }
  if ($renew | describe) == 'string' {
    print -e $'Erda auth token renew failed with message: (ansi r)($renew)(ansi rst)'
    print -e $'Login URL: (ansi r)($LOGIN_URL)(ansi rst).'
    exit $ECODE.AUTH_FAILED
  }
  let tokenInfo = $renew | get -o token | default {}
  open $TERMIX_CONF | from json
    | upsert $tokenKey $tokenInfo | to json
    | save -rf $TERMIX_CONF
  match $get_uid { true => { $renew.user.id }, _ => { $tokenInfo.access_token } }
}

# 判断是否需要重试，如果返回 true 则重试，否则不重试
export def should-retry-req [resp: any] {
  let isEmpty = ($resp | is-empty)
  let noAuth = ($resp | describe) == 'string' and ($resp =~ 'auth failed' or $resp =~ 'Unauthorized')
  let badRes = ($resp | describe) == 'string' and (not $noAuth)
  { isEmpty: $isEmpty, noAuth: $noAuth, shouldRetry: ($isEmpty or $noAuth or $badRes) }
}
