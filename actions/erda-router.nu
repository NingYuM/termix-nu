#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/05/06 15:06:56
# Description: Config Erda Address forwarding routers

# Usage:

use ../utils/common.nu [hr-line, ECODE]
use ../utils/erda.nu [get-erda-auth, ERDA_HOST]

const PROJECT_CONF = {
  orgId: 2, orgName: 'terminus', projectId: 1158, env: 'TEST', pageSize: 1000
}

const DOMAIN_MAP = {
  '190': [
    { name: 'portal', env: 'TEST', domain: 'portal-test.app.terminus.io' }
    { name: 'console', env: 'TEST', domain: 'console-test.app.terminus.io' }
    { name: 'portal-h5', env: 'TEST', domain: 'portal-m-test.app.terminus.io' }
    { name: 'portal', env: 'DEV', domain: 'portal-dev.app.terminus.io' }
    { name: 'console', env: 'DEV', domain: 'console-dev.app.terminus.io' }
    { name: 'portal-h5', env: 'DEV', domain: 'portal-m-dev.app.terminus.io' }
    { name: 'portal', env: 'STAGING', domain: 'portal-staging.app.terminus.io' }
    { name: 'console', env: 'STAGING', domain: 'console-staging.app.terminus.io' }
    { name: 'portal-h5', env: 'STAGING', domain: 'portal-m-staging.app.terminus.io' }
  ],
  '1158': [
    { name: 'portal', env: 'TEST', domain: 't-erp-portal-test.app.terminus.io' }
    { name: 'console', env: 'TEST', domain: 't-erp-console-test.app.terminus.io' }
    { name: 'portal-h5', env: 'TEST', domain: 't-erp-portal-m-test.app.terminus.io' }
    { name: 'portal', env: 'DEV', domain: 't-erp-portal-dev.app.terminus.io' }
    { name: 'console', env: 'DEV', domain: 't-erp-console-dev.app.terminus.io' }
    { name: 'portal-h5', env: 'DEV', domain: 't-erp-portal-m-dev.app.terminus.io' }
    { name: 'portal', env: 'STAGING', domain: 't-erp-portal-staging.app.terminus.io' }
    { name: 'console', env: 'STAGING', domain: 't-erp-console-staging.app.terminus.io' }
    { name: 'portal-h5', env: 'STAGING', domain: 't-erp-portal-m-staging.app.terminus.io' }
  ],
}

# Config Erda Address forwarding routers
export def erda-routers [
  --pid(-p): int,               # The project id to configure routers, default is 1158
  --environment(-e): string,    # The environment to configure routers, default is TEST
  --list-pkgs,                  # List all the packages with domains
] {
  $env.config.table.mode = 'psql'
  let environment = if ($environment | is-empty) { $PROJECT_CONF.env } else { $environment | str upcase }
  if $environment not-in [TEST DEV STAGING PROD] {
    print $'Invalid environment: ($environment)'; exit $ECODE.INVALID_PARAMETER
  }
  let packages = get-packages --pid $pid --environment $environment --all=$list_pkgs
  if $list_pkgs { $packages | reject matchDomain | print; exit $ECODE.SUCCESS }
  get-redirects $packages --type url --environment $environment
}

# Get Erda packages with domains
def get-packages [
  --pid(-p): int,               # The project id to configure routers
  --environment(-e): string,    # The environment to configure routers
  --all,                        # List all the packages with domains
] {
  let projectId = if ($pid | is-empty) { $PROJECT_CONF.projectId } else { $pid }
  let environment = if ($environment | is-empty) { $PROJECT_CONF.env } else { $environment | str upcase }
  let domainMap = $DOMAIN_MAP | get $'($projectId)' | where env == $environment | get domain
  let query = $PROJECT_CONF | upsert env $environment | upsert projectId $projectId | url build-query
  let pkgsQueryUrl = $'($ERDA_HOST)/api/($PROJECT_CONF.orgName)/gateway/openapi/packages?($query)'
  http get -e --headers (get-erda-auth $ERDA_HOST --type nu) $pkgsQueryUrl
    | get data.list
    | where {|it| if $all { true } else { $it.bindDomain | any { $in in $domainMap } }}
    | upsert matchDomain {|it| $it.bindDomain | where { $in in $domainMap } | get 0? | default - }
    | upsert domains {|it| $it.bindDomain | str join "\n" }
    | select name id scene domains createAt matchDomain
}

def get-redirects [
  packages: table,              # The packages to query redirects
  --environment(-e): string,    # The environment to configure routers
  --type(-t): string = 'url',   # The redirect type to query, default is url, available values are url or service
] {
  let redirctType = if ($type | is-empty) { 'ALL' } else { $type | str upcase }
  for pkg in $packages {
    print $'Querying Erda redirect configs for:(char nl)'
    print ($pkg | reject matchDomain)
    print $'(char nl)Erda (ansi g)($redirctType)(ansi reset) redirect configs for domain: (ansi g)($pkg.matchDomain)(ansi reset) of ($environment)'; hr-line
    let routerQueryUrl = $'($ERDA_HOST)/api/($PROJECT_CONF.orgName)/gateway/openapi/packages/($pkg.id)/apis?pageSize=1000'
    let routes = http get -e --headers (get-erda-auth $ERDA_HOST --type nu) $routerQueryUrl
      | get data.list
      | where redirectType == $type
      | select apiPath redirectAddr redirectPath description # createAt
    if ($routes | is-empty) { print $'(ansi grey66)---EMPTY---(char nl)(ansi reset)'; continue }
    print $routes
  }
}

alias main = erda-routers
