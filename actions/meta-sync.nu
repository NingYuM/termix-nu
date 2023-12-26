#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/12/20 13:52:00
# Description: A TUI tool for syncing meta data of TERP
# [√] Create snapshot of meta data
# [√] Upload meta data to OSS
# [√] Update meta data import status for each task
# [√] Import meta data from OSS to the destination host
# [√] Confirm source and destination: teameId, teamCode, host
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
# [?] User authentication support
# Usage:
#   t msync --all
#   t msync --selected
#   t msync --all --from a --to b

use std ellie
use ../utils/common.nu [ECODE, hr-line]

const POLL_TICK_CHAR = '*'
const QUERY_INTERVAL = 1sec

# TERP Meta data syncing tool
export def 'meta sync' [
  --from(-f): string,   # Specify the source meta data provider name from meta.source config
  --to(-t): string,     # Specify the destination meta data provider name from meta.destination config
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules from config file of the specified source
  --list(-l),           # List all the available sources and destinations
  --snapshot(-S),       # Only create and upload snapshot for meta data
] {
  cd $env.TERMIX_DIR
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..7 }
  print -n (ellie); print $'        Terminus TERP Meta Data Syncing Tool @ ($sha)'; hr-line

  let confMeta = load-meta-conf
  if $list { show-available-providers $confMeta; exit $ECODE.SUCCESS }
  if $snapshot { create-and-upload-snapshot --from $from; exit $ECODE.SUCCESS }
  let usedSetting = get-meta-setting --from $from --to $to --all=$all --selected=$selected
  let dest = $usedSetting.dest
  let source = $usedSetting.source
  let modules = if $all { [] } else { get-selected-modules --from $source --selected=$selected }
  if ($modules | is-empty) {
    print $'You have selected to sync (ansi p)ALL(ansi reset) the modules...'
  } else {
    print $'You have selected the following modules to import: (ansi p)($modules | str join ",")(ansi reset)'
  }
  print -n (char nl)
  confirm-check --from $source --to $dest

  let start = date now
  let snapshotOid = handle-create-snapshot $source
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi reset)'
  handle-import-metadata $dest $snapshotOid $downloadUrl --modules $modules
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi reset)'
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
  confirm-snapshot --from $source
  let start = date now
  let snapshotOid = handle-create-snapshot $source --snapshot-only
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid --snapshot-only
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
  if $confirm == 'q' { echo $'Snapshot creating cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != 'y' {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)y(ansi reset), bye...'
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
      print $'The source (ansi p)($from)(ansi reset) must have (ansi p)selectedModules & availableModules(ansi reset) config.'
      exit $ECODE.INVALID_PARAMETER
    }
    # CHECK: Make sure the selected modules was all in the available modules
    $source.selectedModules | each {|it| if $it not-in $source.availableModules {
      print $'The source (ansi p)($from)(ansi reset) selectedModules ($it) must be one of ($source.availableModules | str join ",")'
      exit $ECODE.INVALID_PARAMETER
    }}
    return { source: $source, dest: $destination, selectedModules: $source.selectedModules }
  }
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

# Check provider name and value along with the command flags
def provider-check [name, value, --from: string, --to: string] {
  let metaConf = $env.META_CONF
  if ($value | length) > 1 {
    print $'Invalid meta data ($name) setting, at most one default ($name) was allowed.'
    exit $ECODE.INVALID_PARAMETER
  }
  let check = if $name == 'source' { $from } else { $to }
  if ($check | is-empty) and ($value | length) == 0 {
    print $'You must specify the ($name) name or set a default ($name) in the meta.($name) config.'
    exit $ECODE.INVALID_PARAMETER
  }
  if (not ($check | is-empty)) and ($check not-in ($metaConf | get $name)) {
    print $'The ($name) name (ansi p)($check)(ansi reset) does`t exists in the meta.($name) config, please check it again.'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Make sure you know what you are doing
def confirm-check [
  --from(-f): record,   # Specify the meta data source config
  --to(-t): record,     # Specify the meta data destination config
] {
  print $'Attention:'; hr-line
  print $'You are going to sync meta data with the following config: (char nl)'
  let setting = [
    [Type Host TeamID TeamCode ddlAutoUpdate];
    [FROM ($from.host | trim-host) $'($from.teamId)' $from.teamCode '-']
    ['' '↓' '↓' '↓' '']
    [TO ($to.host | trim-host) $'($to.teamId)' $to.teamCode ($to | get -i ddlAutoUpdate | default true)]]
  # Theme: ascii_rounded,basic_compact,dots,psql,reinforced
  print ($setting | table -e --theme psql -i false)
  print $'Are you sure to continue?'
  let check = $'($from.teamId)-to-($to.teamId)'
  let confirm = input $'Please confirm by typing (ansi r)($check)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Syncing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $check {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($check)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
  print -n (char nl)
}

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
  let selected = $from.availableModules | input list --multi 'Please select the modules to sync (space to select, esc or q to quit, enter to confirm)'
  if ($selected | is-empty) {
    print $'You have not selected any modules, bye...'
    exit $ECODE.SUCCESS
  }
  return $selected
}

# Create meta data snapshot and wait for the task to finish, return the snapshot SHA if success
def handle-create-snapshot [
  source: record,       # Specify the meta source config of the snapshot to create
  --snapshot-only,      # Specify whether to only create and upload snapshot without importing
] {
  let start = date now
  let total = if $snapshot_only { 2 } else { 3 }
  let taskId = create-snapshot $source
  print $'(ansi pr) STEP 1/($total): (ansi reset) Snapshot creating task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $source.host
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host)
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
  --snapshot-only,      # Specify whether to only create and upload snapshot without importing
] {
  let start = date now
  let total = if $snapshot_only { 2 } else { 3 }
  let taskId = upload-snapshot $source $rootOid
  print -n (char nl)
  print $'(ansi pr) STEP 2/($total): (ansi reset) Snapshot uploading task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $source.host
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $source.host)
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
  --modules(-m): list,  # Specify the modules to sync
] {
  let start = date now
  let taskId = import-metadata $dest $rootOid $metaUrl --modules $modules
  print -n (char nl)
  print $'(ansi pr) STEP 3/3: (ansi reset) Meta data importing task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $dest.host
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status):'

  let webDetailUrl = $'($dest.host)/task/run-detail?taskRunId=($detail.taskRunId)'
  print $'For more detail please visit: (ansi p)($webDetailUrl)(ansi reset)'
  print $'Task Status: Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)'
  hr-line 60 --color lcd

  mut successCount = $stats.success
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $dest.host)
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
] {
  const snapShotApi = '/api/trantor/task/exec/RebuildObjectTask'
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: '1', verbose: 'false' } | url build-query
  let resp = http post --content-type application/json $'($source.host)($snapShotApi)?($query)' {}
  if not $resp.success {
    print $'Failed to create snapshot, error: ($resp.err)'
  }
  $resp.data.taskId
}

# Upload meta data snapshot to OSS
def upload-snapshot [
  source: record,       # Specify the meta source config of the snapshot to upload
  rootOid: string,      # Specify the root OID of the snapshot to upload
] {
  const snapShotUploadApi = '/api/trantor/task/exec/UploadObjectToOSSTask'
  let query = { teamId: $source.teamId, teamCode: $source.teamCode, userId: '1', verbose: 'false' } | url build-query
  let resp = http post --content-type application/json $'($source.host)($snapShotUploadApi)?($query)' { rootOid: $rootOid }
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
  --modules(-m): list,  # Specify the modules to sync
] {
  const destImportApi = '/api/trantor/task/exec/SyncAllInOneTask'
  let query = { teamId: $dest.teamId, teamCode: $dest.teamCode, userId: '1', verbose: 'false' } | url build-query
  mut importPayload = {
    rootOid: $rootOid,
    downloadUrl: $metaUrl,
    ddlAutoUpdate: ($dest | get -i ddlAutoUpdate | default true),
  }
  if not ($modules | is-empty) {
    $importPayload.resetModuleKeys = $modules
    print $'Goint to import modules: ($modules | str join ",")'
  }
  let resp = http post --content-type application/json $'($dest.host)($destImportApi)?($query)' $importPayload
  if not $resp.success {
    print $'Import meta data failed with error: ($resp.err)'
  }
  $resp.data.taskId
}

# Fetch task running detail by taskId
def fetch-task-detail [
  taskId: string,       # Specify the task id of the detail to fetch
  queryHost: string,    # Specify the query url prefix of the detail to fetch
] {
  const queryApi = '/api/trantor/task/run-detail'
  let DETAIL_URL = $'($queryHost)($queryApi)/($taskId)'
  let resp = try { http get $DETAIL_URL } catch { http get -e $DETAIL_URL }
  if not $resp.success {
    # 对于“服务器异常”，需要重试
    if $resp.err.code == 'O0003' {
      print $'(char nl)Fetch task detail failed with error: ($resp.err.msg), retrying...'
      return (fetch-task-detail $taskId $queryHost)
    }
    print $'Fetch task detail failed with error: ($resp.err)'
  }
  $resp.data
}

alias main = meta sync
