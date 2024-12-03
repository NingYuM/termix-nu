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

use ../utils/common.nu [ECODE, HTTP_HEADERS, hr-line, ellie, is-installed, is-lower-ver]

const POLL_TICK_CHAR = '*'
const QUERY_INTERVAL = 1sec
const KEY_MAPPING = $"(ansi grey66)\(Space: Select, a: Select All, ESC/q: Quit, Enter: Confirm\)(ansi reset)"

# TERP Meta data synchronization tool: create and upload snapshot to OSS, and import
# meta data snapshot to the dest Console for all modules or selected modules.
# User manual: https://fe-docs.app.terminus.io/termix/termix-nu#meta-data-syncing
export def 'meta sync' [
  --from(-f): string@'nu-complete source',  # Specify the source meta data provider name from meta.source config
  --to(-t): string@'nu-complete dest',      # Specify the destination meta data provider name from meta.destination config
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules from config file of the specified source
  --list(-l),           # List all the available sources and destinations
  --install(-i),        # Install or upgrade the standard modules to the dest project, for 2.5.24.0930 or later
  --snapshot(-S),       # Only create and upload snapshot for meta data
] {
  cd $env.TERMIX_DIR
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..<7 }
  print -n (ellie); print $'        Terminus TERP Meta Data Syncing Tool @ ($sha)'; hr-line

  let confMeta = load-meta-conf
  if $list { show-available-providers $confMeta; exit $ECODE.SUCCESS }
  if $snapshot { create-and-upload-snapshot --from $from; exit $ECODE.SUCCESS }
  let usedSetting = get-meta-setting --from $from --to $to --all=$all --selected=$selected
  let dest = $usedSetting.dest
  let source = $usedSetting.source
  let modules = if $all { [] } else { get-selected-modules --from $source --selected=$selected }
  mut securityCode = ''
  if ($modules | is-empty) {
    print $'You have selected to sync (ansi p)ALL(ansi reset) the modules...'
    $securityCode = (input $'(ansi g)Please input the security code to continue: (ansi reset)')
  } else {
    print $'You have selected the following modules to import: (ansi p)($modules | str join ",")(ansi reset)'
  }
  print -n (char nl)
  let destAuth = get-user-auth $dest
  let sourceAuth = get-user-auth $source
  confirm-check --from $source --to $dest --src-auth $sourceAuth --dest-auth $destAuth
  install-check $dest $destAuth --install=$install

  let start = date now
  let snapshotOid = handle-create-snapshot $source $sourceAuth
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid $sourceAuth
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi reset)'
  handle-import-metadata $dest $snapshotOid $downloadUrl $destAuth --modules $modules --code $securityCode --install=$install
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi reset)'
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
  return $metaConf
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

# Create and upload meta data snapshot
def create-and-upload-snapshot [--from: string] {
  let metaConf = $env.META_CONF
  check-required source
  let defaultSource = $metaConf.source | values | default false default | where default == true
  provider-check 'source' $defaultSource --from $from
  let source = if ($from | is-empty) { $defaultSource | get 0 } else { $metaConf.source | get $from }
  let $source = ($source
    | upsert username {|it| $it.username? | default $metaConf.settings?.username? }
    | upsert password {|it| $it.password? | default $metaConf.settings?.password? })
  check-user-auth $source
  confirm-snapshot --from $source
  let start = date now
  let authentication = get-user-auth $source
  let snapshotOid = handle-create-snapshot $source $authentication --snapshot-only
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid $authentication --snapshot-only
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi reset)'
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi reset)'
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
  let confirm = input $'Please press (ansi p)y(ansi reset) to continue and (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { print $'Snapshot creating cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != 'y' {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)y(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)
}

# Check meta data settings
def get-meta-setting [
  --from(-f): string,   # Specify the source meta data provider name from meta.source config
  --to(-t): string,     # Specify the destination meta data provider name from meta.destination config
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules in config file
] {
  let metaConf = $env.META_CONF
  # print ($metaConf | table -e)

  check-required source
  check-required destination
  let defaultSource = $metaConf.source | values | default false default | where default == true
  let defaultDest = $metaConf.destination | values | default false default | where default == true
  # CHECK: Make sure at most one default source and destination was set
  provider-check 'source' $defaultSource --from $from
  provider-check 'destination' $defaultDest --to $to
  let source = if ($from | is-empty) { $defaultSource | get 0 } else { $metaConf.source | get $from }
  let destination = if ($to | is-empty) { $defaultDest | get 0 } else { $metaConf.destination | get $to }
  if $selected {
    # CHECK: Make sure the selected and available modules was set in the source config
    if ([selectedModules availableModules] | any {|| $in not-in $source }) {
      print $'The (ansi p)($from | default default)(ansi reset) source must have (ansi p)selectedModules & availableModules(ansi reset) config.'
      exit $ECODE.INVALID_PARAMETER
    }
    # CHECK: Make sure the selected modules was all in the available modules
    $source.selectedModules | each {|it| if $it not-in $source.availableModules {
      print $'The (ansi p)($from | default default)(ansi reset) source`s selectedModules ($it) must be one of ($source.availableModules | str join ",")'
      exit $ECODE.INVALID_PARAMETER
    }}
    return { source: $source, dest: $destination, selectedModules: $source.selectedModules }
  }
  let $source = ($source
    | upsert username {|it| $it.username? | default $metaConf.settings?.username? }
    | upsert password {|it| $it.password? | default $metaConf.settings?.password? })
  let $destination = ($destination
    | upsert username {|it| $it.username? | default $metaConf.settings?.username? }
    | upsert password {|it| $it.password? | default $metaConf.settings?.password? })
  check-user-auth $source
  check-user-auth $destination
  { source: $source, dest: $destination }
}

# Make sure the required config was set in source and destination provider
def check-required [name: string] {
  let metaConf = $env.META_CONF
  for provider in ($metaConf | get $name | columns) {
    let keys = $metaConf | get $name | get $provider | columns
    [teamId teamCode host] | each {|it| if $it not-in $keys {
      print $'The ($name) (ansi p)($provider)(ansi reset) must have (ansi p)($it)(ansi reset) config.'
      exit $ECODE.INVALID_PARAMETER
    }}
  }
}

# Make sure user has configured username and password
def check-user-auth [settings: record] {
  let authEmpty = [username password] | any {|it| $settings | get -i $it | is-empty }
  if $authEmpty {
    print $'(ansi r)Please config your username and password for the following setting:(ansi reset)'
    $settings | table -e | print
    exit $ECODE.INVALID_PARAMETER
  }
}

# Check provider type and value along with the command flags
def provider-check [type, value, --from: string, --to: string] {
  let metaConf = $env.META_CONF
  if ($value | length) > 1 {
    print $'Invalid meta data ($type) setting, at most one default ($type) was allowed.'
    exit $ECODE.INVALID_PARAMETER
  }
  let check = if $type == 'source' { $from } else { $to }
  if ($check | is-empty) and ($value | length) == 0 {
    print $'You must specify the ($type) name or set a default ($type) in the meta.($type) config.'
    exit $ECODE.INVALID_PARAMETER
  }
  if (not ($check | is-empty)) and ($check not-in ($metaConf | get $type)) {
    print $'The ($type) name (ansi p)($check)(ansi reset) does`t exists in the meta.($type) config, please check it again.'
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
  let shouldInstall = $isLegacy and ($dest | get -i resetModuleForInstall | default false)
  if $shouldInstall {
    print $'You are going to INSTALL modules to the dest project, please add (ansi g)`--install` / `-i`(ansi reset) flag and try again.(char nl)'
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
  let confirm = input $'Please confirm by typing (ansi r)($check)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { print $'Syncing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $check {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($check)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)
}

# Trim http(s):// form host to make it shorter
def trim-host [] {
  $in | str replace 'http://' '' | str replace 'https://' ''
}

# Get the selected modules to sync by user selection or config file
def get-selected-modules [
  --from(-f): record,   # Specify the meta data source config
  --selected(-s),       # Sync the selected modules from config file of the specified source
] {
  print -n (char nl)
  if $selected { return $from.selectedModules }
  let selected = $from.availableModules
    | input list --multi $'Please select the modules to sync ($KEY_MAPPING)'
  if ($selected | is-empty) {
    print $'You have not selected any modules, bye...'
    exit $ECODE.SUCCESS
  }
  return $selected
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
  print $'(ansi pr) STEP 1/($total): (ansi reset) Snapshot creating task started, id: (ansi p)(get-detail-link $source.host $taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $source.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host $auth)
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n '█'
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  print 'Task output:'; hr-line
  print ($detail.outputs | table -e)
  print $'Time consumed for 1st step: ($end - $start)'
  if ($stats.failed > 0) {
    print $'Failed to create snapshot, please try again later.'
    exit $ECODE.SERVER_ERROR
  }
  return $detail.outputs.1
}

# Upload meta data snapshot and wait for the task to finish, return the meta data download url if success
def handle-upload-snapshot [
  source: record,       # Specify the meta source config of the snapshot to upload
  rootOid: string,      # Specify the root oid of the snapshot to upload
  auth: record,         # A authentication record contains user and cookie info
  --snapshot-only,      # Specify whether to only create and upload snapshot without importing
] {
  let start = date now
  let total = if $snapshot_only { 2 } else { 3 }
  let taskId = upload-snapshot $source $rootOid $auth
  print -n (char nl)
  print $'(ansi pr) STEP 2/($total): (ansi reset) Snapshot uploading task started, id: (ansi p)(get-detail-link $source.host $taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $source.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host $auth)
    $stats = $detail.progress
    sleep $QUERY_INTERVAL
    print -n '█'
  }
  let end = date now
  print -n (char nl)
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  # print 'Task output:'; hr-line
  # print ($detail.outputs | table -e)
  print $'Time consumed for 2nd step: ($end - $start)'
  if ($stats.failed > 0) {
    print $'Failed to upload snapshot, please try again later.'
    exit $ECODE.SERVER_ERROR
  }
  return $detail.outputs.1
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
] {
  let start = date now
  let taskId = if $install {
    install-metadata $dest $metaUrl $auth --modules $modules --code $code
  } else {
    import-metadata $dest $rootOid $metaUrl $auth --modules $modules --code $code
  }
  print -n (char nl)
  print $'(ansi pr) STEP 3/3: (ansi reset) Meta data importing task started, id: (ansi p)(get-detail-link $dest.host $taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $dest.host $auth
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status):'

  let webDetailUrl = $'($dest.host)/task/run-detail?taskRunId=($detail.taskRunId)'
  print $'For more detail please visit: (ansi p)($webDetailUrl)(ansi reset)'
  print $'Task Status: Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)'
  hr-line 60 --color lcd

  mut successCount = $stats.success
  while $stats.success + $stats.failed < $stats.total {
    if $detail.status == 'Failed' { break }
    $detail = (fetch-task-detail $taskId $dest.host $auth)
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
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status)...'
  # print 'Sub tasks detail output:'; hr-line
  # print ($detail.subTasks | table -e)
  print $'Time consumed for 3rd step: ($end - $start)'
  if ($stats.failed > 0) {
    print $'(ansi r)Failed to import metadata with the following outputs:(ansi reset)'
    hr-line; print $detail.outputs
    exit $ECODE.SERVER_ERROR
  }
  print $'(ansi p)Bravo! Meta data synchronized successfully.(ansi reset)'
}

# Create meta data snapshot
def create-snapshot [
  source: record,       # Specify the meta source of the snapshot to create
  auth: record,         # A authentication record contains user and cookie info
] {
  const LEGACY_VERSIONS = [2.5.24.0430 2.5.24.0530 2.5.24.0630 2.5.24.0730]
  let taskName = if ($auth.version | is-empty) or ($auth.version in $LEGACY_VERSIONS) { 'RebuildObjectTask' } else { 'SnapshotTask' }
  let snapShotApi = $'/api/trantor/task/exec/($taskName)'
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode, ...$HTTP_HEADERS]
  let resp = http post --content-type application/json --headers $headers -e $'($source.host)($snapShotApi)?($query)' {}
  if $resp.status? == 401 {
    print $'Create snapshot failed with error: (ansi r)($resp.error)(ansi reset)'
    print $'Make sure you have set the username and password correctly and try again...'
    exit $ECODE.AUTH_FAILED
  }
  if ($resp.success? | is-empty) or (not $resp.success?) {
    print $'Failed to create snapshot, error: ($resp.err)'
    exit $ECODE.SERVER_ERROR
  }
  $resp.data.taskId
}

# Upload meta data snapshot to OSS
def upload-snapshot [
  source: record,       # Specify the meta source config of the snapshot to upload
  rootOid: string,      # Specify the root OID of the snapshot to upload
  auth: record,         # A authentication record contains user and cookie info
] {
  const snapShotUploadApi = '/api/trantor/task/exec/UploadObjectToOSSTask'
  let headers = [Cookie $auth.cookie Referer $auth.iamHost Trantor2-Team $source.teamCode, ...$HTTP_HEADERS]
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  let resp = http post --content-type application/json --headers $headers $'($source.host)($snapShotUploadApi)?($query)' { rootOid: $rootOid }
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
] {
  const destImportApi = '/api/trantor/task/exec/SyncAllInOneTask'
  let query = { teamId: $dest.teamId, teamCode: $dest.teamCode, userId: $auth.user.id, verbose: 'false' } | url build-query
  mut importPayload = {
    rootOid: $rootOid,
    securityCode: $code,
    downloadUrl: $metaUrl,
    ddlAutoUpdate: ($dest | get -i ddlAutoUpdate | default true),
    resetModuleForInstall: ($dest | get -i resetModuleForInstall | default false),
  }
  if not ($modules | is-empty) {
    $importPayload.resetModuleKeys = $modules
    print $'Going to import modules: ($modules | str join ",")'
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
    autoDDL: ($dest | get -i ddlAutoUpdate | default true),
  }
  if not ($modules | is-empty) {
    $installPayload.moduleKeys = $modules
    print $'Going to install modules: ($modules | str join ",")'
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
  let webDetailUrl = $'($host)/task/run-detail?taskRunId=($taskId)'
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
    print $'Task query failed with message: (ansi r)($resp)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  if not $resp.success {
    # 对于“服务器异常”，需要重试
    if $resp.err.code == 'O0003' {
      print $'(char nl)Fetch task detail failed with error: ($resp.err.msg), retrying...'
      return (fetch-task-detail $taskId $queryHost $auth)
    }
    print $'Fetch task detail failed with error: ($resp.err)'
  }
  if $resp.data.status == 'Failed' {
    print $'(char nl)Task running failed with error: '
    print $resp.data.outputs
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
    print $'Get user auth failed with message: (ansi r)($platform)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  if $platform.status? in [401 404] {
    return { user: { id: 1 }, iamHost: '', cookie: '' }
  }
  # OpenSSL Check
  if not (is-installed openssl) {
    print $'(ansi r)Please install openssl@3 first by `brew install openssl@3` and try again...(ansi reset)'
    exit $ECODE.MISSING_BINARY
  }
  let opensslVer = openssl version | detect columns -n | rename bin ver | get ver.0
  if (is-lower-ver $opensslVer '3.0.0') {
    print $'(ansi r)Openssl v3 or above is required, please install it by `brew install openssl@3` and try again...(ansi reset)'
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
  if not $resp.body.success {
    print $'Login failed with error: (ansi r)($resp.body.message)(ansi reset)'
    print $'Please check your auth info at (ansi g)($iamHost)/login(ansi reset)'
    exit $ECODE.AUTH_FAILED
  }
  let user = $resp.body.data.user
  let cookie = $resp.headers.response | where name == 'set-cookie' | get value.0 | split row ';' | get 0
  { user: $user, iamHost: $iamHost, version: $platform.version?.number?, cookie: $cookie }
}

alias main = meta sync
