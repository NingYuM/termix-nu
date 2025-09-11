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
# [√] Git 代码仓库批量同步分支及 Tags
# [√] 增量同步不覆盖目标用户权限: 目标项目或者目标应用的同一用户权限若不一致，则以目标为准
# [√] 源项目或者源应用删除掉的成员、环境变量在后续增量同步过程中如果目标应用里面有不会被删掉，以目标为准
# [ ] 同步新应用的流水线及运行时环境变量与源应用保持一致，不含加密环境变量
# [ ] 增量同步不覆盖目标应用已有环境变量: 环境变量如果在目标应用已经存在则跳过，以目标为准
# [ ] 支持通过 fzf 选择要迁移的应用，可以多选、模糊搜索
# [?] 提前判断没有权限的应用，可以配置是忽略还是退出
# 前提：
# 1. 源项目和目标项目必须在 Terminus 组织下，目前也只支持这个组织
# 2. 需要有源项目和目标项目的管理员权限:
#     - 操作者需要先有源项目里面所有应用, 或者所选择应用的访问权限
#     - 操作者需要在目标项目里面有创建应用的权限
#     - 新应用创建后操作者即为新应用所有者，不因其在源应用的权限配置而改变(尚待验证)
# Usage:
#   t erda-transfer --from 213 --to 1000226
# 	t erda-transfer --from 213 --to 1000226 --apps termix-nu,nusi-slim

use ../utils/common.nu [ECODE, hr-line]
use ../git/repo-transfer.nu ['git-repo-transfer']
use ../utils/erda.nu [ERDA_HOST, check-erda-envs, get-erda-auth]

const PAGE_SIZE = 9999
const MEMBER_API = 'https://erda.cloud/api/terminus/members'
const APP_LIST_API = 'https://openapi.erda.cloud/api/applications'
const APP_CREATE_API = 'https://erda.cloud/api/terminus/applications'
const PIPELINE_ENV_API = 'https://erda.cloud/api/terminus/cicds/multinamespace/configs'
const RUNTIME_ENV_API = 'https://erda.cloud/api/terminus/configmanage/multinamespace/configs'

# Transfer Apps between Erda Projects, the App will be created if not exist in the dest project
# All Git branches, tags, project members and app members will be transferred
@example '将 Terminus 组织下编号为 213 的项目里面的 termix-nu,nusi-slim 应用迁移到编号为 1000226 的项目' {
  t erda-transfer --from 213 --to 1000226 --apps termix-nu,nusi-slim
} --result '迁移内容包括应用仓库所有分支、Tags、项目成员、应用成员。该命令可以重复执行,以实现增量同步'
@example '将 Terminus 组织下编号为 213 的项目里面的所有应用迁移到编号为 1000226 的项目' {
  t erda-transfer --from 213 --to 1000226
} --result '迁移内容包括所有应用的各分支、Tags、项目成员、应用成员。该命令可以重复执行,以实现增量同步'
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

  # print $'(char nl)(ansi pr)STEP E:(ansi rst) Syncing Pipeline Env vars...'; hr-line
  # sync-env-vars $auth $from $to --selected $selected --debug=$debug
}

# Sync the git repos between the source and target app
def sync-git-repos [auth: list, sid: int, tid: int, --selected: list, --debug] {
  let dest_apps = get-app-list $auth --from $tid
  let source_apps = get-app-list $auth --from $sid
  let candidates = if ($selected | is-empty) { $dest_apps.name } else { $selected }
  for s in $candidates {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($s | str downcase) | get 0? | default {}
    let source_app = $source_apps | where ($it.name | str downcase) == ($s | str downcase) | get 0? | default {}
    if ($dest_app | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) App (ansi r)($s)(ansi rst) not found in target project, skipping git sync.'
      continue
    }
    if ($source_app | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) App (ansi r)($s)(ansi rst) not found in source project, skipping git sync.'
      continue
    }
    print $'Syncing git repos from (ansi g)($source_app.name)(ansi rst) to (ansi g)($dest_app.name)(ansi rst) ...'
    git-repo-transfer https://($source_app.gitRepoNew) https://($dest_app.gitRepoNew)
  }
}

# Add members to the dest apps with the same roles, support incremental addition
def add-app-members [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let dest_apps = get-app-list $auth --from $to
  let source_apps = get-app-list $auth --from $from
  let candidates = if ($selected | is-empty) { $dest_apps.name } else { $selected }
  if $debug { $candidates | first | table -e | print }
  for s in $candidates {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($s | str downcase) | get 0? | default {}
    let source_app = $source_apps | where ($it.name | str downcase) == ($s | str downcase) | get 0? | default {}
    if ($dest_app | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) App (ansi r)($s)(ansi rst) not found in target project, skipping member sync.'
      continue
    }
    if ($source_app | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) App (ansi r)($s)(ansi rst) not found in source project, skipping member sync.'
      continue
    }
    let src_members = get-members $auth app $source_app.id
    print $'Adding members to (ansi g)($s)(ansi rst) ...'
    add-members $auth app $dest_app.id $src_members --name $s
  }
  print $'(char nl)(ansi g)All Done!(ansi rst)'
}

# Create the unexist apps in the target project
def create-unexist-apps [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let source_apps = get-app-list $auth --from $from
  let dest_apps = get-app-list $auth --from $to
  let unexist_apps = get-unexist-apps $source_apps $dest_apps
  let candidates = if ($selected | is-empty) { $unexist_apps } else { $unexist_apps | where $it.name in $selected }

  print $'The following apps will be transferred:(char nl)'
  $candidates | select id name mode desc | print
  if $debug and ($candidates | length) > 0 {
    # print 'Source apps:'; $source_apps | print
    # print 'Dest apps:'; $dest_apps | print
    print $'(char nl)First detail:(char nl)'
    $candidates | first | table -e | print
  }
  print -n (char nl)
  for app in $candidates {
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

# Get all the project or app members
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

# Add members to the project or app with the same roles, support incremental addition
def add-members [auth: list, type: string, sid: int, members: list, --name: string] {
  let exist_members = get-members $auth $type $sid
  let exist_ids = $exist_members.userId

  # Check all members' status and print necessary info to ensure the log order is reasonable
  for m in $members {
    if $m.userId in $exist_ids {
      let existing_member = $exist_members | where $it.userId == $m.userId | first
      let roles_match = ($m.roles | sort) == ($existing_member.roles | sort)
      if not $roles_match {
        print $'(ansi y)NOTE:(ansi rst) The member (ansi r)($m.nick)(ansi rst) already exists in ($type) (ansi r)($name | default $sid)(ansi rst) but with different roles, skipping.'
      }
    }
  }

  # Only add the members that do not exist
  let members_to_add = $members | where {|m| $m.userId not-in $exist_ids }

  for u in $members_to_add {
    print $'INFO: Adding member (ansi g)($u.nick)(ansi rst) to ($type) (ansi g)($name | default $sid)(ansi rst) ... '
    let payload = {
      roles: $u.roles,
      userIds: [$u.userId],
      options: {rewrite: true}
      scope: {id: ($sid | into string), type: $type},
    }
    let resp = http post -H $auth --content-type application/json -e $MEMBER_API $payload
    if not $resp.success {
      print $'Failed to add (ansi r)($u.nick)(ansi rst) to ($type) (ansi r)($sid)(ansi rst) with error: (ansi r)($resp.err.msg)(ansi rst)'
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
    return
  }
  print $'Failed to create app (ansi r)($payload.name)(ansi rst) with error message: (ansi r)($resp.err.msg)(ansi rst)'
  $resp | table -e | print
}
