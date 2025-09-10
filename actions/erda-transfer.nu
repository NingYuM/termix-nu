#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/09/09 15:20:05
# Description: Transfer Apps between Erda Projects
# TODO:
# [√] Parameter validation
# [√] 获取应用列表在新项目里面批量创建应用，名称、描述、应用类型与源应用保持一致
# [√] 在新项目里面添加用户，跟源项目保持一致
# [√] 只迁移指定应用，通过 --apps 参数指定
# [√] 在新应用里面添加用户，跟源应用保持一致
# [ ] 提前判断没有权限的应用，可以配置是忽略还是退出
# [ ] 同步新应用的流水线及运行时环境变量与源应用保持一致，不含加密环境变量
# [ ] 支持通过 fzf 选择要迁移的应用，可以多选、模糊搜索
# [√] Git 代码仓库批量同步分支及 Tags
# 前提：
# 1. 源项目和目标项目必须在 terminus 组织下，目前也只支持这个组织
# 2. 需要有源项目和目标项目的管理员权限:
#     - 操作者需要先有源项目里面所有应用的访问权限
#     - 操作者需要在目标项目里面有创建应用的权限
#     - 新应用创建后操作者即为新应用所有者，不因其在源应用的权限配置而改变
# Usage:
#   t erda-transfer --from 213 --to 1000226
# 	t erda-transfer --from 213 --to 1000226 --apps parkball,nusi-slim,dingtalk-sign

use ../utils/common.nu [ECODE, hr-line]
use ../git/repo-transfer.nu ['git-repo-transfer']
use ../utils/erda.nu [ERDA_HOST, check-erda-envs, get-erda-auth]

const PAGE_SIZE = 9999
const MEMBER_API = 'https://erda.cloud/api/terminus/members'
const APP_LIST_API = 'https://openapi.erda.cloud/api/applications'
const APP_CREATE_API = 'https://erda.cloud/api/terminus/applications'

# Transfer Apps between Erda Projects
@example '将 Terminus 组织下的 213 项目里面的 termix-nu,nusi-slim 应用迁移到 1000226 项目' {
  t erda-transfer --from 213 --to 1000226 --apps termix-nu,nusi-slim
} --result '迁移内容包括应用仓库分支、Tags、项目成员、应用成员。该命令可以重复执行,以实现增量同步'
@example '将 Terminus 组织下的 213 项目里面的所有应用迁移到 1000226 项目' {
  t erda-transfer --from 213 --to 1000226
} --result '迁移内容包括所有应用仓库分支、Tags、项目成员、应用成员。该命令可以重复执行,以实现增量同步'
export def 'erda transfer' [
  --from(-f): int,    # ERDA Source Project ID
  --to(-t): int,      # ERDA Target Project ID
  --apps(-a): string, # The apps to transfer, separated by comma
  --debug(-d),        # Show more debug info
] {
  if ($from | is-empty) { print $'(ansi r)Error: Source Project ID cannot be empty!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  if ($to | is-empty) { print $'(ansi r)Error: Target Project ID cannot be empty!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  if $from == $to { print $'(ansi r)Error: Source and Target Project ID cannot be the same!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  check-erda-envs
  let auth = get-erda-auth $ERDA_HOST --type nu | append [Org terminus]
  let source_members = get-members $auth project $from
  print $'(char nl)(ansi pr)STEP A:(ansi rst) Adding Members to Target Project...'; hr-line
  add-members $auth project $to $source_members

  print $'(ansi pr)STEP B:(ansi rst) Transferring Apps...'; hr-line
  let selected = if ($apps | is-empty) { [] } else { $apps | split row ',' }
  create-unexist-apps $auth --selected $selected --debug=$debug --from $from --to $to

  print $'(char nl)(ansi pr)STEP C:(ansi rst) Add Members to Dest Apps...'; hr-line
  add-app-members $auth --selected $selected --debug=$debug --from $from --to $to

  print $'(char nl)(ansi pr)STEP D:(ansi rst) Syncing Git Repos...'; hr-line
  sync-git-repos $auth $from $to --selected $selected --debug=$debug
}

# Sync the git repos between the source and target app
def sync-git-repos [auth: list, sid: int, tid: int, --selected: list, --debug] {
  let source_apps = get-app-list $auth --from $sid
  let dest_apps = get-app-list $auth --from $tid
  for s in $selected {
    let source_app = $source_apps | where ($it.name | str downcase) == ($s | str downcase) | first
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($s | str downcase) | first
    print $'Syncing git repos from (ansi g)($source_app.name)(ansi rst) to (ansi g)($dest_app.name)(ansi rst) ...'
    git-repo-transfer https://($source_app.gitRepoNew) https://($dest_app.gitRepoNew)
  }
}

# Add members to the dest apps with the same roles, support incremental addition
def add-app-members [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let dest_apps = get-app-list $auth --from $to
  let source_apps = get-app-list $auth --from $from
  if $debug { $dest_apps | first | table -e | print }
  for s in $selected {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($s | str downcase) | first
    let source_app = $source_apps | where ($it.name | str downcase) == ($s | str downcase) | first
    let src_members = get-members $auth app $source_app.id
    print -n $'(char nl)(char nl)Adding members to (ansi g)($s)(ansi rst) ...'
    add-members $auth app $dest_app.id $src_members --name $s
  }
  print $'(char nl)(ansi g)All Done!(ansi rst)'
}

# Create the unexist apps in the target project
def create-unexist-apps [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let source_apps = get-app-list $auth --from $from
  let dest_apps = get-app-list $auth --from $to
  let unexist_apps = get-unexist-apps $source_apps $dest_apps
  let transfer_apps = if ($selected | is-empty) { $unexist_apps } else { $unexist_apps | where $it.name in $selected }

  print $'The following apps will be transferred:(char nl)'
  $transfer_apps | select id name mode desc | print
  if $debug and ($transfer_apps | length) > 0 {
    # print 'Source apps:'; $source_apps | print
    # print 'Dest apps:'; $dest_apps | print
    print $'(char nl)First detail:(char nl)'
    $transfer_apps | first | table -e | print
  }
  print -n (char nl)
  for app in $transfer_apps {
    create-app $auth $to $app
  }
}

# Get the apps list from the specified project
def get-app-list [auth: list, --from: int] {
  let query = { projectId: $from, pageNo: 1, pageSize: $PAGE_SIZE } | url build-query
  http get -H $auth $'($APP_LIST_API)?($query)' | get data.list | sort-by id
}

# Get the apps that do not exist in the target project
def get-unexist-apps [source: list, dest: list] {
  let dest_apps = $dest | get name
  $source | where {|it| ($it.name | str downcase) not-in $dest_apps }
}

# Get all the project members
def get-members [auth: list, type: string, sid: int] {
  let query = {
    pageNo: 1,
    scopeId: $sid,
    scopeType: $type,
    pageSize: $PAGE_SIZE,
  } | url build-query
  http get -H $auth $'($MEMBER_API)?($query)'
    | get data.list | sort-by userId
    | select userId nick removed deleted status roles
}

# Add members to the project with the same roles, support incremental addition
def add-members [auth: list, type: string, sid: int, members: list, --name: string] {
  let exist_members = get-members $auth $type $sid
  let exist_ids = $exist_members.userId
  let cond = {|m|
    let missing = $m.userId not-in $exist_ids
    let unmatch = $exist_members
      | where $m.userId == $it.userId and ($m.roles | sort) == ($it.roles | sort)
      | is-empty
    $missing or $unmatch
  }
  for u in ($members | where $cond) {
    print -n $'(char nl)Adding member (ansi g)($u.nick)(ansi rst) to ($type) (ansi g)($name | default $sid)(ansi rst) ... '
    let payload = {
      roles: $u.roles,
      userIds: [$u.userId],
      options: {rewrite: true}
      scope: {id: ($sid | into string), type: $type},
    }
    let resp = http post -H $auth --content-type application/json -e $MEMBER_API $payload
    if $resp.success {
      print -n $'(ansi g)Done(ansi rst)'
    } else {
      print $'(char nl)Failed to add (ansi r)($u.nick)(ansi rst) to ($type) (ansi r)($sid)(ansi rst) with error: (ansi r)($resp.err.msg)(ansi rst)'
    }
  }
  if $type == 'project' { print (char nl) }
}

# Create the app in target project
def create-app [auth: list, pid: int, app: record] {
  let payload = {
    mode: $app.mode, name: ($app.name | str downcase), desc: $app.desc, projectId: $pid, isExternalRepo: false
  }
  let resp = http post -H $auth --content-type application/json -e $APP_CREATE_API $payload
  if $resp.success {
    print $'App (ansi g)($payload.name)(ansi rst) has been created successfully'
  } else {
    print $'Failed to create app (ansi r)($payload.name)(ansi rst) with error message: (ansi r)($resp.err.msg)(ansi rst)'
    $resp | table -e | print
  }
}
