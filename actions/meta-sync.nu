#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/12/20 13:52:00
# Description: A TUI tool for syncing meta data of TERP
# [√] Create snapshot of meta data
# [√] Upload meta data to OSS
# [√] Update meta data import status for each task
# [√] Import meta data from OSS to the destination host
# [√] Confirm source and destination: teamId, teamCode, host
# [√] Select the modules to sync or sync all the modules
# [x] Confirm the selected modules and reselect if needed
# [x] Allow to get selected modules from --modules flag
# [√] Add a config file for all the settings
# [√] Setting file validation check
# [√] Allow default settings, so we can run the script without any arguments
# [√] Handle 500 error properly for the last step
# [√] Display ddlAutoUpdate config somewhere
# [√] Select and show selected modules before confirmation
# [√] Must specify source and destination if no default source and destination was set
# [√] Add teamId, teamCode, host checking for each source and destination
# [√] List available sources and destinations by --list or -l flag
# [√] Update user manual for meta data syncing script
# [√] Add --snapshot(-S) flag to only create snapshot
# [√] Add ansi links to task ID
# [√] User authentication support
# [√] Add security code parameter for meta data import
# REF:
#   https://aliyuque.antfin.com/trantor/eewi6i/zia318wmury96hqo#TRlGB
# Usage:
#   t msync --all
#   t msync --all -S
#   t msync --selected
#   t msync --all --from a --to b

use ../utils/common.nu [ECODE, HTTP_HEADERS, FZF_DEFAULT_OPTS, FZF_THEME, hr-line, ellie, is-installed, is-lower-ver]

const POLL_TICK_CHAR = '*'
const QUERY_INTERVAL = 1sec
const KEY_MAPPING = $"(ansi grey66)\(Tab: Select, Ctrl-a: Select All, Ctrl-d: Deselect All, ESC: Quit, Enter: Confirm\)(ansi rst)"
# Versions that doesn't support SnapshotTask API
const LEGACY_L0_VERSIONS = [2.5.24.0430 2.5.24.0530 2.5.24.0630 2.5.24.0730]
# Versions that doesn't support DIR based meta data import
const LEGACY_L1_VERSIONS = [2.5.24.0830 2.5.24.0930 2.5.24.1030]

# TERP Meta data synchronization tool: create and upload snapshot to OSS, and import
# meta data snapshot to the dest Console for all modules or selected modules.
# User manual: https://fe-docs.app.terminus.io/termix/termix-nu#meta-data-syncing
@example '从默认源同步 `HR_ATT,HR_PER,HR_REC` 模块的元数据到默认目标' {
  t msync HR_ATT,HR_PER,HR_REC
}
@example '从默认源以交互方式选择模块后导入到默认目标' {
  t msync
} --result '在 TUI 中选择模块，可以选择多个模块, 支持模糊搜索'
@example '从默认源同步所有模块到默认目标' {
  t msync -a
} --result '将提示输入安全码(如果有)，并依次执行：创建快照、上传快照、导入元数据'
@example '从 `dev` 源仅创建并上传元数据快照（不导入）' {
  t msync --snapshot --from dev
} --result '输出快照 RootOID 与下载地址，不执行导入步骤'
@example '指定源与目标，同步所有模块的元数据' {
  t msync -a --from dev --to test
}
@example '列出可用的同步源与目标' {
  t msync -l
} --result '以表格形式列出 `meta.source` 与 `meta.destination` 配置'
@example '安装或者升级标准模块的元数据到目标，支持 Trantor 2.5.24.0930 及以后版本，表示安装为非原生模块' {
  t msync --install --to test
} --result '执行安装/升级任务而非普通导入'
@example '在源项目中为元数据创建指定版本的标签' {
  t msync --tag '20260202.0935'
} --result '调用 BuildTagTask 在源项目中创建标签'
@example '指定源项目创建元数据标签' {
  t msync --tag '20260202.0935' --from dev
}
@example '创建元数据制品并安装到目标环境，未指定模块时会进入交互式选择模式' {
  t msync --from terp-saas --install --to sanlux-dev --tag 20260212.1730
}
@example '创建制品并将指定模块安装到目标环境' {
  t msync SCM_DEL,ERP_FI,ERP_FIN --from terp-saas --install --to sanlux-dev --tag 20260212.1730
}
export def 'meta sync' [
  modules?: string,      # Specify the modules to sync, multiple modules separated by commas
  --from(-f): string@'nu-complete source',  # Specify the source meta data provider name from meta.source config
  --to(-t): string@'nu-complete dest',      # Specify the destination meta data provider name from meta.destination config
  --all(-a),            # Specify whether to sync all the modules
  --list(-l),           # List all the available sources and destinations
  --install(-i),        # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
  --snapshot(-S),       # Only create and upload snapshot for meta data
  --tag(-T): string,    # Build a tag for meta data with the specified version, e.g. '20260202.0935'
] {
  cd $env.TERMIX_DIR
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..<7 }
  print -n (ellie); print $'        Terminus TERP Meta Data Syncing Tool @ ($sha)'; hr-line

  let confMeta = load-meta-conf
  if $list { show-available-providers $confMeta; exit $ECODE.SUCCESS }
  if $snapshot { create-and-upload-snapshot --from $from --install=$install; exit $ECODE.SUCCESS }
  if ($tag | is-not-empty) { build-tag-and-install --from $from --to $to --tag $tag --install=$install --modules $modules; exit $ECODE.SUCCESS }
  let usedSetting = get-meta-setting --from $from --to $to
  let dest = $usedSetting.dest
  let source = $usedSetting.source
  let sourceAuth = get-user-auth ($confMeta.settings? | default {} | merge $source)
  let modules = if $all { [] } else { get-selected-modules --from $source --auth $sourceAuth --modules $modules }
  mut securityCode = ''
  if ($modules | is-empty) {
    print $'You have selected to sync (ansi p)ALL(ansi rst) the modules...'
    $securityCode = (input $'(ansi g)Please input the security code to continue: (ansi rst)')
  } else {
    print $'You have selected the following modules to import: (ansi p)($modules | str join ",")(ansi rst)'
  }
  if ($source.path? | is-not-empty) {
    print $'You are going to import meta data from path: (ansi p)($source.path)(ansi rst)'
  }
  print -n (char nl)
  let destAuth = get-user-auth ($confMeta.settings? | default {} | merge $dest)
  confirm-check --from $source --to $dest --src-auth $sourceAuth --dest-auth $destAuth
  install-check $dest $destAuth --install=$install

  let start = date now
  let snapshotOid = handle-create-snapshot $source $sourceAuth
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi rst)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid $sourceAuth --install=$install
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi rst)'
  handle-import-metadata $dest $snapshotOid $downloadUrl $destAuth --modules $modules --code $securityCode --install=$install --path=$source.path?
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi rst)'
}

# Tab complete for sources
def 'nu-complete source' [] {
  open $'($env.TERMIX_DIR)/.termixrc' | from toml | get meta.source | columns
}

# Tab complete for destinations
def 'nu-complete dest' [] {
  open $'($env.TERMIX_DIR)/.termixrc' | from toml | get meta.destination | columns
}

# Load meta data settings and store them to environment variable
def --env load-meta-conf [] {
  let metaConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get meta
  $env.META_CONF = $metaConf
  $metaConf
}

# List available sources and destinations
def show-available-providers [metaConf: record] {
  print $'Available meta data sources:'; hr-line
  get-providers source $metaConf | table -i false | print
  print $'(char nl)Available meta data destinations:'; hr-line
  get-providers destination $metaConf | table -i false | print
}

def get-providers [type: string, metaConf: record] {
  mut providers = []
  for provider in ($metaConf | get $type | columns) {
    let option = $metaConf | get $type | get $provider | upsert name $provider
    $providers = ($providers | append $option)
  }
  $providers
    | default false default
    | default '-' description
    | upsert default {|it| if $it.default { '√' } else { '' }}
    | select name teamId teamCode default host description
    | upsert host {|it| $it.host | trim-host }
}

# Resolve and validate a meta data provider (source or destination) by name or default
def resolve-provider [
  type: string,         # Provider type: 'source' or 'destination'
  name?: string,        # Provider name, from --from or --to flag
] {
  let metaConf = $env.META_CONF
  check-required $type
  let defaults = $metaConf | get $type | values | default false default | where default == true
  if $type == 'source' { provider-check $type $defaults --from $name } else { provider-check $type $defaults --to $name }
  let provider = if ($name | is-empty) { $defaults | get 0 } else { $metaConf | get $type | get $name }
  let $provider = ($provider
    | upsert username {|it| $it.username? | default $metaConf.settings?.username? }
    | upsert password {|it| $it.password? | default $metaConf.settings?.password? }
    | upsert cookie {|it| $it.cookie? | default $metaConf.settings?.cookie? })
  check-user-auth $provider
  $provider
}

# Create and upload meta data snapshot
def create-and-upload-snapshot [
  --from: string
  --install(-i),        # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
] {
  let source = resolve-provider source $from
  confirm-snapshot --from $source
  let start = date now
  let authentication = get-user-auth ($env.META_CONF.settings? | default {} | merge $source)
  let snapshotOid = handle-create-snapshot $source $authentication --snapshot-only
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi rst)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid $authentication --snapshot-only --install=$install
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi rst)'
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi rst)'
}

# Build tag for meta data, optionally install to destination
def build-tag-and-install [
  --from: string,
  --to: string,
  --tag: string,
  --modules: string,    # Comma-separated module keys, e.g. 'HR_ATT,HR_PER'
  --install,
] {
  let metaConf = $env.META_CONF
  let source = resolve-provider source $from
  if ($to | is-not-empty) and (not $install) {
    print $'(ansi y)Warning: --to is specified but --install is not set, destination will be ignored.(ansi rst)'
  }
  if $install and ($to | is-empty) {
    print $'(ansi y)Warning: --install is set but --to is not specified, skipping installation.(ansi rst)'
  }
  let start = date now
  let sourceAuth = get-user-auth ($metaConf.settings? | default {} | merge $source)

  # Resolve destination and select modules upfront before tag building
  mut dest = {}
  mut destAuth = {}
  mut moduleList = []
  if ($to | is-not-empty) and $install {
    $dest = (resolve-provider destination $to)
    $destAuth = (get-user-auth ($metaConf.settings? | default {} | merge $dest))
    $moduleList = if ($modules | is-not-empty) { $modules | split row , } else {
      get-selected-modules --from $source --auth $sourceAuth
    }
    if ($moduleList | is-empty) {
      print -e $'(ansi r)No modules specified, please specify modules to install.(ansi rst)'
      exit $ECODE.INVALID_PARAMETER
    }
    print $'Going to install modules: (ansi g)($moduleList | str join ",")(ansi rst)'
  }

  let metaUrl = handle-build-tag $source $sourceAuth $tag
  hr-line
  print $'Tag built successfully, meta data url:'
  print $'(ansi p)($metaUrl)(ansi rst)'

  if ($to | is-not-empty) and $install {
    handle-import-metadata $dest '' $metaUrl $destAuth --install=$install --modules $moduleList
  }

  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi rst)'
}

# Build tag for meta data and wait for the task to finish
def handle-build-tag [
  source: record,       # Specify the meta source config
  auth: record,         # A authentication record contains user and cookie info
  tag: string,          # Specify the tag version string
] {
  let start = date now
  let taskId = build-tag $source $auth $tag
  print $'(ansi pr) TAG: (ansi rst) Tag building task started, id: (ansi p)(get-detail-link $source.host $taskId)(ansi rst)'
  mut detail = fetch-task-detail $taskId $source.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    if $detail.status == 'Failed' { break }
    $detail = (fetch-task-detail $taskId $source.host $auth)
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n $POLL_TICK_CHAR
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  print ($detail.outputs | table -e)
  print $'Time consumed for tag building: ($end - $start)'
  if ($stats.failed > 0) {
    print -e $'Failed to build tag, please try again later.'
    exit $ECODE.SERVER_ERROR
  }
  print 'Task output:'; hr-line
  print ($detail.result.files | first)
  $detail.result.files | first | get url
}

# Build a tag for meta data by calling BuildTagTask API
def build-tag [
  source: record,       # Specify the meta source of the tag to build
  auth: record,         # A authentication record contains user and cookie info
  tag: string,          # Specify the tag version string
] {
  const buildTagApi = '/api/trantor/task/exec/BuildTagTask'
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode ...$HTTP_HEADERS]
  let payload = { version: $tag }
  let resp = http post --content-type application/json --headers $headers -e $'($source.host)($buildTagApi)?($query)' $payload
  if $resp.status? == 401 {
    print -e $'Build tag failed with error: (ansi r)($resp.error)(ansi rst)'
    print -e $'Make sure you have set the username and password correctly and try again...'
    exit $ECODE.AUTH_FAILED
  }
  if ($resp.success? | is-empty) or (not $resp.success?) {
    print -e $'Failed to build tag, error: ($resp.error)'
    exit $ECODE.SERVER_ERROR
  }
  $resp.data.taskId
}

# Make sure you know what you are doing
def confirm-snapshot [
  --from(-f): record,   # Specify the meta data source config
] {
  print $'Attention:'; hr-line
  print $'You are going to create and upload meta data snapshot with the following config: (char nl)'
  let setting = [
    [Host TeamID TeamCode];
    [($from.host | trim-host) $'($from.teamId)' $from.teamCode]
  ]
  # Theme: ascii_rounded,basic_compact,dots,psql,reinforced
  print ($setting | table -e --theme psql -i false)
  print $'Are you sure to continue? '
  let confirm = input $'Please press (ansi p)y(ansi rst) to continue and (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print $'Snapshot creating cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != 'y' {
    print -e $'Your input (ansi p)($confirm)(ansi rst) does not match (ansi p)y(ansi rst), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)
}

# Check meta data settings
def get-meta-setting [
  --from(-f): string,   # Specify the source meta data provider name from meta.source config
  --to(-t): string,     # Specify the destination meta data provider name from meta.destination config
] {
  let source = resolve-provider source $from
  let destination = resolve-provider destination $to
  { source: $source, dest: $destination }
}

# Make sure the required config was set in source and destination provider
def check-required [name: string] {
  let metaConf = $env.META_CONF
  for provider in ($metaConf | get $name | columns) {
    let keys = $metaConf | get $name | get $provider | columns
    [teamId teamCode host] | each {|it| if $it not-in $keys {
      print -e $'The ($name) (ansi p)($provider)(ansi rst) must have (ansi p)($it)(ansi rst) config.'
      exit $ECODE.INVALID_PARAMETER
    }}
  }
}

# Make sure user has configured username/password or cookie for authentication
def check-user-auth [settings: record] {
  if ($settings.cookie? | is-not-empty) { return }
  let authEmpty = [username password] | any {|it| $settings | get -o $it | is-empty }
  if $authEmpty {
    print -e $'(ansi r)Please config your username and password (or cookie) for the following setting:(ansi rst)'
    $settings | table -e | print
    exit $ECODE.INVALID_PARAMETER
  }
}

# Check provider type and value along with the command flags
def provider-check [type, value, --from: string, --to: string] {
  let metaConf = $env.META_CONF
  if ($value | length) > 1 {
    print -e $'Invalid meta data ($type) setting, at most one default ($type) was allowed.'
    exit $ECODE.INVALID_PARAMETER
  }
  let check = if $type == 'source' { $from } else { $to }
  if ($check | is-empty) and ($value | length) == 0 {
    print -e $'You must specify the ($type) name or set a default ($type) in the meta.($type) config.'
    exit $ECODE.INVALID_PARAMETER
  }
  if (not ($check | is-empty)) and ($check not-in ($metaConf | get $type)) {
    print -e $'The ($type) name (ansi p)($check)(ansi rst) does not exist in the meta.($type) config, please check it again.'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Install or upgrade the standard modules to the dest project pre-check
def install-check [
  dest: record,         # Specify the meta dest config for the snapshot to install
  auth: record,         # A authentication record contains user and cookie info
  --install(-i),        # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
] {
  if $install { return }
  let isLegacy = ($auth.version | is-empty) or ($auth.version | str replace -a . '' | str replace 'DEV' '' | into int) < 25240930
  let shouldInstall = (not $isLegacy) and ($dest | get -o resetModuleForInstall | default false)
  if $shouldInstall {
    print -e $'You are going to INSTALL modules to the dest project, please add (ansi g)`--install` / `-i`(ansi rst) flag and try again.(char nl)'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Make sure you know what you are doing
def confirm-check [
  --from(-f): record,   # Specify the meta data source config
  --to(-t): record,     # Specify the meta data destination config
  --src-auth: record,   # A authentication record for the source
  --dest-auth: record,  # A authentication record for the destination
] {
  print $'Attention:'; hr-line
  print $'You are going to sync meta data with the following config: (char nl)'
  let ddlAutoUpdate = $to.ddlAutoUpdate? | default true
  let resetModuleForInstall = $to.resetModuleForInstall? | default false
  let setting = [
    [Type Host TeamID TeamCode ddlAutoUpdate resetModuleForInstall version];
    [FROM ($from.host | trim-host) $'($from.teamId)' $from.teamCode '-' '-' ($src_auth.version? | default '-')]
    ['' '↓' '↓' '↓' '' '' '↓']
    [TO ($to.host | trim-host) $'($to.teamId)' $to.teamCode $ddlAutoUpdate $resetModuleForInstall ($dest_auth.version? | default '-')]]
  # Theme: ascii_rounded,basic_compact,dots,psql,reinforced
  print ($setting | table -e --theme psql -i false)
  print $'Are you sure to continue?'
  let check = $'($from.teamId)-to-($to.teamId)'
  let confirm = input $'Please confirm by typing (ansi r)($check)(ansi rst) to continue or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print $'Syncing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $check {
    print -e $'Your input (ansi p)($confirm)(ansi rst) does not match (ansi p)($check)(ansi rst), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)
}

# Trim http(s):// form host to make it shorter
def trim-host [] {
  $in | str replace 'http://' '' | str replace 'https://' ''
}

# Get all the available modules from Trantor2 Console
def get-available-source-modules [
  source: record,       # Specify the meta source config
  auth: record,         # A authentication record contains user and cookie info
] {
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode ...$HTTP_HEADERS]
  let resp = http get -H $headers $'($source.host)/api/trantor/console/module/query?type=Module'
  if not $resp.success {
    print -e $'Failed to get available modules, error: ($resp.err)'
    exit $ECODE.SERVER_ERROR
  }
  # sys_common is a system module, and it is not syncable
  $resp | get data | select key name | where key not-in [sys_common]
}

# Get the selected modules to sync by user selection or `modules` flag
def get-selected-modules [
  --from: record,       # Specify the meta data source config
  --auth: record,       # A authentication record contains user and cookie info
  --modules: string,    # Specify the modules to sync, multiple modules separated by commas
] {
  print -n (char nl)
  let availableModules = get-available-source-modules $from $auth
  let FZF_ARGS = [--bind, 'ctrl-a:select-all,ctrl-d:deselect-all', --header, $'Select the modules to sync ($KEY_MAPPING)']
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) ($FZF_THEME)'
  if ($modules | is-not-empty) {
    let invalidModules = $modules | split row , | where {|it| $it not-in $availableModules.key }
    if ($invalidModules | is-empty) { return ($modules | split row ,) }
    print -e $'The following modules are invalid: (ansi r)($invalidModules | str join ,)(ansi rst)'
    exit $ECODE.INVALID_PARAMETER
  }
  let selected = $availableModules
      | each {|it| $it.key | fill -w 16 | append $it.name | str join }
      | str join "\n"
      | fzf --multi ...$FZF_ARGS
      | complete | get stdout | str trim | lines
      | each {|it| $it | split row ' ' | first }
  if ($selected | is-empty) {
    print $'You have not selected any modules, bye...'
    exit $ECODE.SUCCESS
  }
  $selected
}

# Create meta data snapshot and wait for the task to finish, return the snapshot SHA if success
def handle-create-snapshot [
  source: record,       # Specify the meta source config of the snapshot to create
  auth: record,         # A authentication record contains user and cookie info
  --snapshot-only,      # Specify whether to only create and upload snapshot without importing
] {
  let start = date now
  let total = if $snapshot_only { 2 } else { 3 }
  let taskId = create-snapshot $source $auth
  print $'(ansi pr) STEP 1/($total): (ansi rst) Snapshot creating task started, id: (ansi p)(get-detail-link $source.host $taskId)(ansi rst)'
  mut detail = fetch-task-detail $taskId $source.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host $auth)
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n $POLL_TICK_CHAR
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  print 'Task output:'; hr-line
  print ($detail.outputs | table -e)
  print $'Time consumed for 1st step: ($end - $start)'
  if ($stats.failed > 0) {
    print -e $'Failed to create snapshot, please try again later.'
    exit $ECODE.SERVER_ERROR
  }
  $detail.outputs.1
}

# Upload meta data snapshot and wait for the task to finish, return the meta data download url if success
def handle-upload-snapshot [
  source: record,       # Specify the meta source config of the snapshot to upload
  rootOid: string,      # Specify the root oid of the snapshot to upload
  auth: record,         # A authentication record contains user and cookie info
  --install,            # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
  --snapshot-only,      # Specify whether to only create and upload snapshot without importing
] {
  let start = date now
  let total = if $snapshot_only { 2 } else { 3 }
  let taskId = upload-snapshot $source $rootOid $auth --install=$install
  print -n (char nl)
  print $'(ansi pr) STEP 2/($total): (ansi rst) Snapshot uploading task started, id: (ansi p)(get-detail-link $source.host $taskId)(ansi rst)'
  mut detail = fetch-task-detail $taskId $source.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host $auth)
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n $POLL_TICK_CHAR
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  # print 'Task output:'; hr-line
  # print ($detail.outputs | table -e)
  print $'Time consumed for 2nd step: ($end - $start)'
  if ($stats.failed > 0) {
    print -e $'Failed to upload snapshot, please try again later.'
    exit $ECODE.SERVER_ERROR
  }
  $detail.outputs.1
}

# Import meta data to destination and wait for the task to finish
def handle-import-metadata [
  dest: record,         # Specify the meta dest config for the snapshot to import
  rootOid: string,      # Specify the root oid of the snapshot to import
  metaUrl: string,      # Specify the meta data download url for importing
  auth: record,         # A authentication record contains user and cookie info
  --install(-i),        # Install or upgrade the standard modules to the dest project
  --code: string,       # Specify the security code to import the meta data
  --modules(-m): list,  # Specify the modules to sync
  --path: string,       # Specify the meta data path or directory to import
] {
  let start = date now
  let taskId = if $install {
    install-metadata $dest $metaUrl $auth --modules $modules --code $code
  } else {
    import-metadata $dest $rootOid $metaUrl $auth --modules $modules --code $code --path $path
  }
  print -n (char nl)
  let type = if $install { 'installing' } else { 'importing' }
  print $'(ansi pr) STEP 3/3: (ansi rst) Meta data ($type) task started, id: (ansi p)(get-detail-link $dest.host $taskId)(ansi rst)'
  mut detail = fetch-task-detail $taskId $dest.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status):'

  let webDetailUrl = $'($dest.host)/api/trantor/task/run-detail-page?taskRunId=($detail.taskRunId)'
  print $'For more detail please visit: (ansi p)($webDetailUrl)(ansi rst)'
  print $'Task Status: Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)'
  hr-line 60 --color lcd

  mut successCount = $stats.success
  while $stats.success + $stats.failed < $stats.total {
    if $detail.status == 'Failed' { break }
    $detail = (fetch-task-detail $taskId $dest.host $auth)
    # $detail | select -o taskName taskRunId status progress result endAt finishedAt | table -e | print
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n $POLL_TICK_CHAR
    if ($stats.success > $successCount) {
      $successCount = $stats.success
      print (char nl)
      print $'Task Status: Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)'
      hr-line 60 --color lcd
    }
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi rst) is ($detail.status)...'
  # print 'Sub tasks detail output:'; hr-line
  # print ($detail.subTasks | table -e)
  print $'Time consumed for 3rd step: ($end - $start)'
  if ($stats.failed > 0) {
    print -e $'(ansi r)Failed to import metadata with the following outputs:(ansi rst)'
    hr-line; print $detail.outputs
    exit $ECODE.SERVER_ERROR
  }
  print $'(ansi p)Bravo! Meta data synchronized successfully.(ansi rst)'
}

# Create meta data snapshot
def create-snapshot [
  source: record,       # Specify the meta source of the snapshot to create
  auth: record,         # A authentication record contains user and cookie info
] {
  let taskName = if ($auth.version | is-empty) or ($auth.version in $LEGACY_L0_VERSIONS) { 'RebuildObjectTask' } else { 'SnapshotTask' }
  let snapShotApi = $'/api/trantor/task/exec/($taskName)'
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode, ...$HTTP_HEADERS]
  let resp = http post --content-type application/json --headers $headers -e $'($source.host)($snapShotApi)?($query)' {}
  if $resp.status? == 401 {
    print -e $'Create snapshot failed with error: (ansi r)($resp.error)(ansi rst)'
    print -e $'Make sure you have set the username and password correctly and try again...'
    exit $ECODE.AUTH_FAILED
  }
  if ($resp.success? | is-empty) or (not $resp.success?) {
    print -e $'Failed to create snapshot, error: ($resp.error)'
    exit $ECODE.SERVER_ERROR
  }
  $resp.data.taskId
}

# Upload meta data snapshot to OSS
def upload-snapshot [
  source: record,       # Specify the meta source config of the snapshot to upload
  rootOid: string,      # Specify the root OID of the snapshot to upload
  auth: record,         # A authentication record contains user and cookie info
  --install,            # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
] {
  const snapShotUploadApi = '/api/trantor/task/exec/UploadObjectToOSSTask'
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode, ...$HTTP_HEADERS]
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  let payload = { rootOid: $rootOid, install: $'($install)' }
  let resp = http post --content-type application/json --headers $headers $'($source.host)($snapShotUploadApi)?($query)' $payload
  if not $resp.success {
    print $'Upload snapshot to OSS failed with error: ($resp.err)'
  }
  $resp.data.taskId
}

# Import the meta data from OSS to destination
def import-metadata [
  dest: record,         # Specify the meta dest config for the snapshot to import
  rootOid: string,      # Specify the root OID of the meta data to import
  metaUrl: string,      # Specify the meta data download url for importing
  auth: record,         # A authentication record contains user and cookie info
  --code: string,       # Specify the security code to import the meta data
  --modules(-m): list,  # Specify the modules to sync
  --path: string,       # Specify the meta data path or directory to import
] {
  const destImportApi = '/api/trantor/task/exec/SyncAllInOneTask'
  let dirImportNotSupported = ($auth.version | is-empty) or ($auth.version in $LEGACY_L0_VERSIONS) or ($auth.version in $LEGACY_L1_VERSIONS)
  let query = { teamId: $dest.teamId, teamCode: $dest.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  mut importPayload = {
    rootOid: $rootOid,
    securityCode: $code,
    downloadUrl: $metaUrl,
    ddlAutoUpdate: ($dest | get -o ddlAutoUpdate | default true),
    resetModuleForInstall: ($dest | get -o resetModuleForInstall | default false),
  }
  if not ($modules | is-empty) {
    $importPayload.resetModuleKeys = $modules
    print $'Going to import modules: ($modules | str join ",")'
  }
  if ($path | is-not-empty) {
    if $dirImportNotSupported {
      print $'(ansi r)The destination Trantor does not support DIR-based metadata import, minimum version required (ansi g)2.5.24.1130.(ansi rst)'
      exit $ECODE.INVALID_PARAMETER
    }
    if ($modules | length) > 1 {
      print -e $'(ansi r)You can only import one module at a time when specifying the `--path` option, please check it again.(ansi rst)'
      exit $ECODE.INVALID_PARAMETER
    }
    $importPayload.path = $path
    print $'Going to import meta data from path: ($path)'
  }
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $dest.teamCode, ...$HTTP_HEADERS]
  let resp = http post --content-type application/json --headers $headers $'($dest.host)($destImportApi)?($query)' $importPayload
  if not $resp.success {
    print $'Import meta data failed with error: ($resp.err)'
  }
  $resp.data.taskId
}

# Install or upgrade the meta data from OSS to destination
def install-metadata [
  dest: record,         # Specify the meta dest config for the snapshot to install
  metaUrl: string,      # Specify the meta data download url for installing
  auth: record,         # A authentication record contains user and cookie info
  --code: string,       # Specify the security code to install the meta data
  --modules: list,      # Specify the modules to sync
] {
  const destInstallApi = '/api/trantor/task/exec/InstallAndUpgradeAppTask'
  mut installPayload = {
    downloadUrl: $metaUrl,
    autoDDL: ($dest | get -o ddlAutoUpdate | default true),
  }
  if not ($modules | is-empty) {
    $installPayload.moduleKeys = $modules
    print $'Going to install modules: (ansi g)($modules | str join ",")(ansi rst)'
  }
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $dest.teamCode, ...$HTTP_HEADERS]
  let resp = http post --content-type application/json --headers $headers $'($dest.host)($destInstallApi)' $installPayload
  if not $resp.success {
    print $'Install meta data failed with error: ($resp.err)'
  }
  $resp.data.taskId
}

# Get ansi link of the specified taskId and host
def get-detail-link [host: string, taskId: int] {
  let webDetailUrl = $'($host)/api/trantor/task/run-detail-page?taskRunId=($taskId)'
  ($webDetailUrl | ansi link --text $'($taskId)')
}

# Fetch task running detail by taskId
def fetch-task-detail [
  taskId: int,          # Specify the task id of the detail to fetch
  queryHost: string,    # Specify the query url prefix of the detail to fetch
  auth: record,         # A authentication record contains user and cookie info
] {
  const queryApi = '/api/trantor/task/run-detail'
  let DETAIL_URL = $'($queryHost)($queryApi)/($taskId)'
  let headers = [Cookie $auth.cookie Referer $auth.iamHost]
  let resp = try { http get --headers $headers $DETAIL_URL } catch { http get -e --headers $headers $DETAIL_URL }
  if ($resp | describe) == 'string' {
    print -e $'Task query failed with message: (ansi r)($resp)(ansi rst)'
    exit $ECODE.SERVER_ERROR
  }
  if not $resp.success {
    # 对于“服务器异常”，需要重试
    if $resp.err.code == 'O0003' {
      print -e $'(char nl)Fetch task detail failed with error: ($resp.err.msg), retrying...'
      return (fetch-task-detail $taskId $queryHost $auth)
    }
    print -e $'Fetch task detail failed with error: ($resp.err)'
  }
  if $resp.data.status == 'Failed' {
    print -e $'(char nl)Task running failed with error: '
    print -e $resp.data.outputs
  }
  $resp.data
}

# Get user authentication info by settings
def get-user-auth [
  settings: record,
] {
  let platformApi = $'($settings.host)/api/trantor/platform'
  let platform = try { http get -e $platformApi } catch { http get -e $platformApi }
  if ($platform | describe) == 'string' {
    print -e $'Get user auth failed with message: (ansi r)($platform)(ansi rst)'
    exit $ECODE.SERVER_ERROR
  }
  if $platform.status? in [401 404] {
    return { user: { id: 1 }, iamHost: '', cookie: '' }
  }
  # 如果已配置 cookie 则跳过账密登录流程
  if ($settings.cookie? | is-not-empty) {
    mut iamHost = $platform.iamDomain?
    if not ($iamHost | str starts-with http) { $iamHost = $'https://($iamHost)' }
    return { user: { id: 1 }, iamHost: $iamHost, version: $platform.version?.number?, cookie: $settings.cookie }
  }
  # OpenSSL Check
  if not (is-installed openssl) {
    print -e $'(ansi r)Please install openssl@3 first by `brew install openssl@3` and try again...(ansi rst)'
    exit $ECODE.MISSING_BINARY
  }
  let opensslVer = openssl version | detect columns -n | rename bin ver | get ver.0
  if (is-lower-ver $opensslVer '3.0.0') {
    print -e $'(ansi r)Openssl v3 or above is required, please install it by `brew install openssl@3` and try again...(ansi rst)'
    exit $ECODE.MISSING_BINARY
  }

  cd $env.TERMIX_DIR
  mut iamHost = $platform.iamDomain?
  if not ($iamHost | str starts-with http) { $iamHost = $'https://($iamHost)' }
  const PUB_KEY_FILE = 'tmp/pub.key'
  let IAM_HEADER = [Referer $iamHost ...$HTTP_HEADERS]
  let pubKey = http get --headers $IAM_HEADER $'($iamHost)/iam/api/v1/user/common/front-end-config'
      | get data.transmissionCryptoProps?.publicKey?

  if not ('tmp/' | path exists) { mkdir tmp }
  echo ['-----BEGIN PUBLIC KEY-----' $pubKey '-----END PUBLIC KEY-----'] | str join (char nl) | save -rf $PUB_KEY_FILE
  let password = $settings.password | openssl pkeyutl -encrypt -pubin -inkey $PUB_KEY_FILE | openssl base64

  let payload = { account: $settings.username, password: $password }

  let resp = http post --headers $IAM_HEADER --full --content-type application/json -e $'($iamHost)/iam/api/v1/user/login/account' $payload
  # 应用未开启账密登录功能, 需要在 .termixrc 对应的 source/destination 中配置 cookie
  if $resp.body.code? == 'B0001' {
    print -e $'(ansi r)Account/password login is not available for (ansi p)($settings.host)(ansi r).(ansi rst)'
    print -e $'Please configure (ansi p)cookie(ansi rst) in the corresponding meta source/destination in (ansi p).termixrc(ansi rst), e.g.:'
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
  { user: $user, iamHost: $iamHost, version: $platform.version?.number?, cookie: $cookie }
}

alias main = meta sync
