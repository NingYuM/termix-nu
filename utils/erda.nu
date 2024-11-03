#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/01/02 13:55:20

use ../utils/common.nu [ECODE, HTTP_HEADERS, get-tmp-path]

export const ERDA_HOST = 'https://erda.cloud'
export const VALID_ENV = [DEV TEST STAGING PROD]

# Check if the required environment variable was set, quit if not
export def check-erda-envs [] {
  # 部署/查询 Pipeline 操作需要先配置 ERDA_USERNAME & ERDA_PASSWORD
  let envs = ['ERDA_USERNAME' 'ERDA_PASSWORD']
  let empties = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in your environment first...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Get Erda OpenAPI session token from .termix-conf file
export def get-erda-auth [host: string = $ERDA_HOST, --type: string = 'curl'] {
  const NA = 'N/A'
  let sessionKey = if $host == $ERDA_HOST { 'erdaSession' } else { $host | encode base64 }
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let erdaSession = open $TERMIX_CONF | from json | get -i $sessionKey | default $NA
  if $type == 'nu' {
    return ['cookie' $'OPENAPISESSION=($erdaSession)' ...$HTTP_HEADERS]
  }
  $'cookie: OPENAPISESSION=($erdaSession)'
}

# Renew Erda session by username and password if expired
export def renew-erda-session [host: string = $ERDA_HOST, --get-uid] {
  if not $get_uid { print 'Renewing Erda session...' }
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let sessionKey = if $host == $ERDA_HOST { 'erdaSession' } else { $host | encode base64 }
  let query = { username: $env.ERDA_USERNAME, password: $env.ERDA_PASSWORD } | url build-query
  let openApiHost = $host | str replace '://' '://openapi.'
  let RENEW_URL = $'($openApiHost)/login?($query)'
  let renew = curl --silent -X POST $RENEW_URL | from json
  if ($renew | is-empty) { print 'Try renew Erda session again...'; renew-erda-session $host }
  if ($renew | describe) == 'string' {
    print $'Erda session renew failed with message: (ansi r)($renew)(ansi reset)'; exit $ECODE.AUTH_FAILED
  }
  open $TERMIX_CONF | from json
    | upsert $sessionKey $renew.sessionid | to json
    | save -rf $TERMIX_CONF
  if $get_uid { return $renew.id }
}

# 判断是否需要重试，如果返回 true 则重试，否则不重试
export def should-retry-req [resp: any] {
  let isEmpty = ($resp | is-empty)
  let noAuth = ($resp | describe) == 'string' and ($resp =~ 'auth failed' or $resp =~ 'Unauthorized')
  let badRes = ($resp | describe) == 'string' and (not $noAuth)
  { isEmpty: $isEmpty, noAuth: $noAuth, shouldRetry: ($isEmpty or $noAuth or $badRes) }
}
