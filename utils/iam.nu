#!/usr/bin/env nu
# Author: hustcer
# Created: 2026/02/13
# Description: Shared IAM authentication utilities

use common.nu [ECODE, HTTP_HEADERS, is-installed, is-lower-ver]

# Check that OpenSSL v3+ is installed
def check-openssl [] {
  if not (is-installed openssl) {
    print -e $'(ansi r)Please install openssl@3 first by `brew install openssl@3` and try again...(ansi rst)'
    exit $ECODE.MISSING_BINARY
  }
  let opensslVer = openssl version | detect columns -n | rename bin ver | get ver.0
  if (is-lower-ver $opensslVer '3.0.0') {
    print -e $'(ansi r)Openssl v3 or above is required, please install it by `brew install openssl@3` and try again...(ansi rst)'
    exit $ECODE.MISSING_BINARY
  }
}

# Perform IAM login: check OpenSSL, encrypt password with public key, and call login API
# Returns: { user: record, iamHost: string, cookie: string }
export def iam-login [
  username: string,      # Login username / account
  password: string,      # Login password (plain text, will be encrypted)
  iamHost: string,       # IAM host URL, must include https://
  --referer: string,     # Custom Referer header, defaults to iamHost
  --host: string,        # Original service host for error messages
  --cookie-hint: string, # Custom hint message for B0001 cookie configuration
] {
  check-openssl

  cd $env.TERMIX_DIR
  const PUB_KEY_FILE = 'tmp/pub.key'
  let IAM_HEADER = [Referer ($referer | default $iamHost) ...$HTTP_HEADERS]
  let pubKey = http get --headers $IAM_HEADER $'($iamHost)/iam/api/v1/user/common/front-end-config'
      | get data.transmissionCryptoProps?.publicKey?

  if not ('tmp/' | path exists) { mkdir tmp }
  echo ['-----BEGIN PUBLIC KEY-----' $pubKey '-----END PUBLIC KEY-----'] | str join (char nl) | save -rf $PUB_KEY_FILE
  let encPassword = $password | openssl pkeyutl -encrypt -pubin -inkey $PUB_KEY_FILE | openssl base64
  rm -f $PUB_KEY_FILE

  let payload = { account: $username, password: $encPassword }
  let resp = http post --headers $IAM_HEADER --full --content-type application/json -e $'($iamHost)/iam/api/v1/user/login/account' $payload

  # Account/password login is not available for this service
  if $resp.body.code? == 'B0001' {
    let errHost = $host | default $iamHost
    print -e $'(ansi r)Account/password login is not available for (ansi p)($errHost)(ansi r).(ansi rst)'
    let hint = $cookie_hint | default $'Please configure (ansi p)cookie(ansi rst) in the corresponding config, e.g.:'
    print -e $hint
    print -e $'  cookie = "t_iam_dev=eyJ0eXAiOiJKV1QiLCJh..."'
    exit $ECODE.AUTH_FAILED
  }
  if not $resp.body.success {
    print -e $'Login failed with error: (ansi r)($resp.body.message)(ansi rst)'
    print -e $'Please check your auth info at (ansi g)($iamHost)/login(ansi rst)'
    exit $ECODE.AUTH_FAILED
  }
  let user = $resp.body.data.user
  let cookie = $resp.headers.response | where name == 'set-cookie' | get value.0 | split row ';' | get 0
  { user: $user, iamHost: $iamHost, cookie: $cookie }
}
