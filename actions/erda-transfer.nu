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
# [√] 源项目或者源应用删除掉的成员或者环境变量在后续增量同步过程中如果目标应用里面有不会被删掉，以目标为准
# [√] 同步新应用的流水线及运行时环境变量与源应用保持一致，不含加密环境变量
# [√] 增量同步不覆盖目标应用已有环境变量: 环境变量如果在目标应用已经存在则跳过，以目标为准
# [√] 支持通过 fzf 选择要迁移的应用，可以多选、模糊搜索
# [√] Make sure the operator has access to all the selected APPs before transfer
# [ ] Reduce call of get-app-list API, especially for querying source Apps
# [ ] Add members in batch mode for those with the same roles
# [ ] Transfer encrypted env vars, and replace the values with text like 'Please update the value and encrypt it'
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

use ../git/repo-transfer.nu ['git-repo-transfer']
use ../utils/erda.nu [ERDA_HOST, check-erda-envs, get-erda-auth]
use ../utils/common.nu [ECODE, hr-line, FZF_DEFAULT_OPTS, FZF_THEME]

const PAGE_SIZE = 9999
# 查询、新增项目或者应用成员
const MEMBER_API = 'https://erda.cloud/api/terminus/members'
# 查询应用列表
const APP_LIST_API = 'https://openapi.erda.cloud/api/applications'
# 创建新应用
const APPLICATION_API = 'https://erda.cloud/api/terminus/applications'
# 批量添加流水线环境变量
const PIPELINE_ENV_ADD_API = 'https://erda.cloud/api/terminus/cicds/configs'
# 批量添加运行时环境变量
const RUNTIME_ENV_ADD_API = 'https://erda.cloud/api/terminus/configmanage/configs'
# 查询流水线环境变量
const PIPELINE_ENV_API = 'https://erda.cloud/api/terminus/cicds/multinamespace/configs'
# 查询运行时环境变量
const RUNTIME_ENV_API = 'https://erda.cloud/api/terminus/configmanage/multinamespace/configs'

# 流水线环境变量后缀
const PIPELINE_ENV_SUFFIXES = [
  { suffix: '-default$' }, { suffix: '-feature$' }, { suffix: '-develop$' },
  { suffix: '-release$' }, { suffix: '-master$' }
]
# 运行时环境变量后缀
const RUNTIME_ENV_SUFFIXES = [
  { suffix: '-DEFAULT$' }, { suffix: '-DEV$' }, { suffix: '-TEST$' },
  { suffix: '-STAGING$' }, { suffix: '-PROD$' }
]

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
  --apps(-a): string, # The Apps to transfer, separated by comma
  --debug(-d),        # Show more debug info
] {
  if ($from | is-empty) { print $'(ansi r)ERROR: Source Project ID cannot be empty!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  if ($to | is-empty) { print $'(ansi r)ERROR: Target Project ID cannot be empty!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  if $from == $to { print $'(ansi r)ERROR: Source and Target Project ID cannot be the same!(ansi rst)'; exit $ECODE.INVALID_PARAMETER }
  check-erda-envs
  let auth = get-erda-auth $ERDA_HOST --type nu | append [Org terminus]

  # Use fzf to select one or multiple Apps to transfer if none specified
  let selected = if ($apps | is-empty) { get-selected-apps $auth --from $from } else { $apps | split row ',' }
  # Validate the selected App names make sure they all exist in the source project
  validate-app-names $auth --selected $selected --from $from
  print $'You are going to transfer the following Apps:(char nl)';
  $selected | sort | wrap name | table -t psql | print
  print -n (char nl)
  let confirm = input $'Please confirm by typing (ansi r)y(ansi rst) to continue or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print $'Transfer cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != 'y' {
    print -e $'Your input (ansi p)($confirm)(ansi rst) does not match (ansi p)y(ansi rst), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)

  validate-app-auth $auth --selected $selected --from $from
  print $'(char nl)(ansi pr)STEP A:(ansi rst) Adding Members to Target Project...'; hr-line
  let source_members = get-members $auth project $from
  add-members $auth project $to $source_members

  print $'(ansi pr)STEP B:(ansi rst) Creating Apps...'; hr-line
  create-nonexistent-apps $auth --selected $selected --debug=$debug --from $from --to $to

  print $'(char nl)(ansi pr)STEP C:(ansi rst) Add Members to Dest Apps...'; hr-line
  add-app-members $auth --selected $selected --debug=$debug --from $from --to $to

  print $'(char nl)(ansi pr)STEP D:(ansi rst) Syncing Pipeline Env vars...'; hr-line
  sync-env-vars $auth $from $to --selected $selected --debug=$debug --type pipeline

  print $'(char nl)(ansi pr)STEP E:(ansi rst) Syncing Runtime Env vars...'; hr-line
  sync-env-vars $auth $from $to --selected $selected --debug=$debug --type runtime

  print $'(char nl)(ansi pr)STEP F:(ansi rst) Syncing Git Repos...'; hr-line
  sync-git-repos $auth $from $to --selected $selected --debug=$debug
}

# Validate the operator has access to the selected Apps in the source project
def validate-app-auth [auth: list, --selected: list, --from: int] {
  let source_apps = get-app-list $auth --from $from
  let select_ids = $source_apps | where ($it.name | str downcase) in $selected | get id
  mut no_auth_apps = []
  for ap in $select_ids {
    let try_auth = http get -H $auth -e $'($APPLICATION_API)/($ap)'
    if $try_auth.err.code == 'AccessDenied' { $no_auth_apps = $no_auth_apps | append $ap }
  }
  if ($no_auth_apps | is-empty) { return true }

  print $'(ansi r)ERROR: You don not have access to the following Apps in the source project:(ansi rst)(char nl)'
  $source_apps | where id in $no_auth_apps | select id name | table -t psql | print
  print -n (char nl)
  exit $ECODE.INVALID_PARAMETER
}

# Validate the selected App names make sure they all exist in the source project
def validate-app-names [auth: list, --selected: list, --from: int] {
  if ($selected | is-empty) { return true }
  let source_apps = get-app-list $auth --from $from
  let source_names = $source_apps | get name | str downcase
  let nonexistent_apps = $selected | where {|it| ($it | str downcase) not-in $source_names }

  if ($nonexistent_apps | length) > 0 {
    print $'(ansi r)ERROR: The following Apps do not exist in the source project:(ansi rst)'
    $nonexistent_apps | each {|app| print $'  - (ansi r)($app)(ansi rst)' }
    exit $ECODE.INVALID_PARAMETER
  }
  true
}

# Sync the pipeline or runtime env vars between the source and target app
def sync-env-vars [auth: list, sid: int, tid: int, --selected: list, --debug, --type: string] {
  let dest_apps = get-app-list $auth --from $tid
  let source_apps = get-app-list $auth --from $sid
  let candidates = if ($selected | is-empty) { $dest_apps.name } else { $selected }

  # Define environment suffixes in a structured way to reduce repetition
  let env_config = if $type == 'pipeline' { $PIPELINE_ENV_SUFFIXES } else { $RUNTIME_ENV_SUFFIXES }

  for ap in $candidates {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    let source_app = $source_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    if (check-app-empty $source_app $dest_app $ap 'ENV VAR') { continue }

    let dest_envs = get-env-vars $auth $dest_app --type $type
    let source_envs = get-env-vars $auth $source_app --type $type
    if $debug {
      print 'Destination App Envs:'; $dest_envs | table -e | print
      print 'Source App Envs:'; $source_envs | table -e | print
    }

    let dest_keys = $dest_envs | columns
    let source_keys = $source_envs | columns

    # Loop through each environment type (dev, test, prod, etc.)
    for config in $env_config {
      let src_key = $source_keys | where $it =~ $config.suffix | get 0?
      let dest_key = $dest_keys | where $it =~ $config.suffix | get 0?

      # If source or destination environment doesn't exist, skip
      if ($src_key | is-empty) or ($dest_key | is-empty) { continue }

      let src_vars = $source_envs | get $src_key | default []
      let dest_vars = $dest_envs | get $dest_key | default []

      # Identify variables that are missing in the destination
      let missing_vars = $src_vars | where $it.key not-in $dest_vars.key

      if ($missing_vars | is-empty) { continue }

      # Print warnings and info messages for missing variables
      for v in $missing_vars {
        if $v.encrypt {
          print $'(ansi y)WARN:(ansi rst) The env var (ansi g)($v.key)(ansi rst) is encrypted, skipping add to ($dest_key)'
          continue
        }
        if $v.type == 'dice-file' {
          print $'(ansi y)WARN:(ansi rst) The env var (ansi g)($v.key)(ansi rst) is a file, please check it after transfer'
          continue
        }
        print $'INFO: Adding env var (ansi g)($v.key)(ansi rst) to (ansi g)($dest_key) @ ($dest_app.name)(ansi rst) ...'
      }

      # Filter out only the encrypted variables for the final payload
      let vars_to_add = $missing_vars
        | where $it.encrypt == false
        | select key value type encrypt comment

      if not ($vars_to_add | is-empty) {
        add-env-vars $auth $dest_app $dest_key $vars_to_add --type $type
      }
    }
  }
  print $'(char nl)(ansi g)All Done!(ansi rst)'
}

# Add the pipeline or runtime env vars to the App in batch mode
def add-env-vars [auth: list, app: record, ns: string, vars: list, --type: string] {
  let query = { appID: $app.id, namespace_name: $ns, encrypt: false } | url build-query
  let payload = { configs: $vars }
  let api = if $type == 'pipeline' { $PIPELINE_ENV_ADD_API } else { $RUNTIME_ENV_ADD_API }
  http post -H $auth --content-type application/json $'($api)?($query)' $payload
}

# Get the env vars of the app
# Response example:
# {
#   pipeline-secrets-app-12367-default: [ { key: 'ENV1', value: 'value1', encrypt: false, comment: 'Description of ENV' } ],
#   pipeline-secrets-app-12367-develop: [ { key: 'ENV2', value: '', encrypt: true, comment: 'Description of ENV' } ],
#   pipeline-secrets-app-12367-feature: [],
#   pipeline-secrets-app-12367-master: [],
#   pipeline-secrets-app-12367-release: [],
# }
def get-env-vars [auth: list, app: record, --type: string] {
  let query = { appID: $app.id } | url build-query
  let pipeline_payload = {
    namespaceParams:[
      { namespace_name: $'pipeline-secrets-app-($app.id)-master', decrypt: false },
      { namespace_name: $'pipeline-secrets-app-($app.id)-default', decrypt: false },
      { namespace_name: $'pipeline-secrets-app-($app.id)-release', decrypt: false },
      { namespace_name: $'pipeline-secrets-app-($app.id)-develop', decrypt: false },
      { namespace_name: $'pipeline-secrets-app-($app.id)-feature', decrypt: false },
    ]}
  let runtime_payload = {
    namespaceParams:[
      { namespace_name: $'app-($app.id)-DEV', decrypt: false },
      { namespace_name: $'app-($app.id)-TEST', decrypt: false },
      { namespace_name: $'app-($app.id)-PROD', decrypt: false },
      { namespace_name: $'app-($app.id)-STAGING', decrypt: false },
      { namespace_name: $'app-($app.id)-DEFAULT', decrypt: false },
    ]}
  let api = if $type == 'pipeline' { $PIPELINE_ENV_API } else { $RUNTIME_ENV_API }
  let payload = if $type == 'pipeline' { $pipeline_payload } else { $runtime_payload }
  http post -H $auth --content-type application/json $'($api)?($query)' $payload | get data
}

# Sync the git repos between the source and target app
def sync-git-repos [auth: list, sid: int, tid: int, --selected: list, --debug] {
  let dest_apps = get-app-list $auth --from $tid
  let source_apps = get-app-list $auth --from $sid
  let candidates = if ($selected | is-empty) { $dest_apps.name } else { $selected }
  for ap in $candidates {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    let source_app = $source_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    if (check-app-empty $source_app $dest_app $ap git) { continue }
    print $'Syncing git repos from (ansi g)($source_app.name)(ansi rst) to (ansi g)($dest_app.name)(ansi rst) ...'
    git-repo-transfer https://($source_app.gitRepoNew) https://($dest_app.gitRepoNew)
  }
}

# Add members to the dest Apps with the same roles, support incremental addition
def add-app-members [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let dest_apps = get-app-list $auth --from $to
  let source_apps = get-app-list $auth --from $from
  let candidates = if ($selected | is-empty) { $dest_apps.name } else { $selected }
  if $debug { $candidates | first | table -e | print }
  for ap in $candidates {
    let dest_app = $dest_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    let source_app = $source_apps | where ($it.name | str downcase) == ($ap | str downcase) | get 0? | default {}
    if (check-app-empty $source_app $dest_app $ap member) { continue }
    let src_members = get-members $auth app $source_app.id
    print $'Adding members to (ansi g)($ap)(ansi rst) ...'
    add-members $auth app $dest_app.id $src_members --name $ap
  }
  print $'(char nl)(ansi g)All Done!(ansi rst)'
}

# Check if the app is not exist in the source or target project
def check-app-empty [source: record, dest: record, name: string, type: string] {
  mut empty = false
  if ($source | is-empty) {
    print $'(ansi y)WARN:(ansi rst) App (ansi r)($name)(ansi rst) not found in source project, skipping ($type) sync.'
    $empty = true
  }
  if ($dest | is-empty) {
    print $'(ansi y)WARN:(ansi rst) App (ansi r)($name)(ansi rst) not found in target project, skipping ($type) sync.'
    $empty = true
  }
  $empty
}

# Create the nonexistent Apps in the target project
def create-nonexistent-apps [auth: list, --selected: list, --from: int, --to: int, --debug] {
  let dest_apps = get-app-list $auth --from $to
  let source_apps = get-app-list $auth --from $from
  let nonexistent_apps = get-nonexistent-apps $source_apps $dest_apps
  let candidates = if ($selected | is-empty) { $nonexistent_apps } else { $nonexistent_apps | where $it.name in $selected }

  print $'The following Apps will be created:(char nl)'
  $candidates | select id name mode desc | print
  if $debug and ($candidates | length) > 0 {
    # print 'Source Apps:'; $source_apps | print
    # print 'Dest Apps:'; $dest_apps | print
    print $'(char nl)First detail:(char nl)'
    $candidates | first | table -e | print
  }
  print -n (char nl)
  for app in $candidates {
    create-app $auth $to $app
  }
}

# Get the Apps list from the specified project
def get-app-list [auth: list, --from: int] {
  let query = { projectId: $from, pageNo: 1, pageSize: $PAGE_SIZE } | url build-query
  http get -H $auth $'($APP_LIST_API)?($query)' | get data.list | sort-by id
}

# Get selected Apps by user selection with fzf
def get-selected-apps [auth: list, --from: int] {
  let source_apps = get-app-list $auth --from $from
  if ($source_apps | is-empty) { print $'No Apps found in the source project.'; exit $ECODE.SUCCESS }

  const KEY_MAPPING = $"(ansi grey66)\(Tab: Select, Ctrl-a: Select All, Ctrl-d: Deselect All, ESC: Quit, Enter: Confirm\)(ansi rst)"
  let FZF_ARGS = [--bind, 'ctrl-a:select-all,ctrl-d:deselect-all', --header, $'Select the Apps to transfer ($KEY_MAPPING)']
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) ($FZF_THEME)'

  let selected = $source_apps
      | each {|it|
          let desc = if ($it.desc | is-empty) { 'N/A' } else {
            $it.desc | str trim | lines | first | str substring 0..<100 | str trim
          }
          $it.name | fill -w 30 | append $desc | str join ' | '
        }
      | str join "\n"
      | fzf --multi ...$FZF_ARGS
      | complete | get stdout | str trim | lines
      | each {|it| $it | split row ' | ' | first | str trim }

  if ($selected | is-empty) { print $'You have not selected any Apps, bye...'; exit $ECODE.SUCCESS }
  $selected
}

# Get the Apps that do not exist in the target project
def get-nonexistent-apps [source: list, dest: list] {
  let dest_apps = $dest | get name
  $source | where {|it| ($it.name | str downcase) not-in $dest_apps }
}

# Get all the project or App members
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

# Add members to the project or App with the same roles, support incremental addition
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

# Create the App in target project
def create-app [auth: list, pid: int, app: record] {
  let payload = {
    mode: $app.mode, name: ($app.name | str downcase), desc: $app.desc, projectId: $pid, isExternalRepo: false
  }
  let resp = http post -H $auth --content-type application/json -e $APPLICATION_API $payload
  if $resp.success {
    print $'App (ansi g)($payload.name)(ansi rst) has been created successfully'
    return
  }
  print $'Failed to create App (ansi r)($payload.name)(ansi rst) with error message: (ansi r)($resp.err.msg)(ansi rst)'
  $resp | table -e | print
}
