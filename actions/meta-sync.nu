#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/12/20 13:52:00
# Description: A TUI tool for syncing meta data of TERP
# [√] Create snapshot of meta data
# [√] Upload meta data to OSS
# [√] Update import meta data status for each task
# [√] Import meta data from OSS to the destination
# [√] Confirm source and destination: teameId, teamCode, host
# [√] Select the modules to sync or sync all the modules
# [√] Add a config file for all the settings
# [√] Setting file validation check
# [√] Allow default settings, so we can run the script without any arguments
# [ ] Update user manual for meta data syncing script
# Usage:
#   t msync --all
#   t msync --selected
#   t msync --all --from a --to b

use std ellie
use ../utils/common.nu [ECODE, hr-line]

const QUERY_INTERVAL = 1sec

# Test data
const TEST_OID = ''
const TEST_META = ''

# TERP Meta data syncing tool
export def 'meta sync' [
  --from(-f): string,   # Specify the source meta data provider name
  --to(-t): string,     # Specify the destination meta data provider name
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules in config file
] {
  print -n (ellie); print '        Terminus TERP Meta Data Syncing Tool'; hr-line

  let confMeta = load-meta-conf
  let usedSetting = get-meta-setting --from $from --to $to --all=$all --selected=$selected
  let dest = $usedSetting.dest
  let source = $usedSetting.source
  confirm-check --from $source --to $dest
  # TODO: get selected modules from --modules flag
  let modules = if $all { [] } else { get-selected-modules --from $source }
  if ($modules | is-empty) {
    print $'Becarefull, You are going to sync (ansi p)ALL(ansi reset) the modules...'
  } else {
    print $'You have selected the following modules to import: (ansi p)($modules | str join ",")(ansi reset)'
  }

  let start = date now
  let snapshotOid = handle-create-snapshot $source
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $source $snapshotOid
  # let downloadUrl = handle-upload-snapshot 891a7cc3d936cba2ca1e826219770c9544fb40e21180ba1d9d3e78b54330ed25
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi reset)'
  handle-import-metadata $dest $snapshotOid $downloadUrl --modules $modules
  # handle-import-metadata $dest $TEST_OID $TEST_META
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi reset)'
}

# Load meta data settings and store them to environment variable
def --env load-meta-conf [] {
  let metaConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get meta
  $env.META_CONF = $metaConf
  return $metaConf
}

# Check meta data settings
def get-meta-setting [
  --from(-f): string,   # Specify the source meta data provider name
  --to(-t): string,     # Specify the destination meta data provider name
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules in config file
] {
  let metaConf = $env.META_CONF
  let defaultSource = $metaConf.source | values | where default == true
  let defaultDest = $metaConf.destination | values | where default == true
  # TODO: teamId, teamCode, host checking for each source and destination
  default-check 'source' $defaultSource
  default-check 'destination' $defaultDest
  if not ($from | is-empty) and ($from not-in ($metaConf.source | columns)) {
    print $'The source name (ansi p)($from)(ansi reset) does`t exists in the meta.source settings, please check it again.'
    exit $ECODE.INVALID_PARAMETER
  }
  if not ($to | is-empty) and ($to not-in ($metaConf.destination | columns)) {
    print $'The source name (ansi p)($to)(ansi reset) does`t exists in the meta.source settings, please check it again.'
    exit $ECODE.INVALID_PARAMETER
  }
  let source = if ($from | is-empty) { $defaultSource | get 0 } else { $metaConf.source | get $from }
  let destination = if ($to | is-empty) { $defaultDest | get 0 } else { $metaConf.destination | get $to }
  if $selected {
    if ([selectedModules availableModules] | any {|| $in not-in ($source | columns) }) {
      print $'The source (ansi p)($from)(ansi reset) must have (ansi p)selectedModules & availableModules(ansi reset) config.'
      exit $ECODE.INVALID_PARAMETER
    }
    $source.selectedModules | each {|it| if $it not-in $source.availableModules {
      print $'The source (ansi p)($from)(ansi reset) selectedModules ($it) must be one of ($source.availableModules | str join ",")'
      exit $ECODE.INVALID_PARAMETER
    }}
    return { source: $source, dest: $destination, selectedModules: $source.selectedModules }
  }
  print ($metaConf | table -e)
  { source: $source, dest: $destination }
}

def default-check [name, value] {
  if ($value | length) > 1 {
    print $'Invalid meta data ($name) setting, at most one default ($name) was allowed.'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Make sure you know what you are doing
def confirm-check [
  --from(-f): record,   # Specify the meta data source
  --to(-t): record,     # Specify the meta data destination
] {
  print $'Attention:'; hr-line
  print $'You are going to sync meta data from: (ansi p)($from.host) @ ($from.teamCode):($from.teamId)(ansi reset)'
  print $'To: (ansi p)($to.host) @ ($to.teamCode):($to.teamId)(ansi reset), are you sure to continue?'
  let check = $'($from.teamId)-to-($to.teamId)'
  let confirm = input $'Please confirm by typing (ansi r)($check)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Syncing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $check {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($check)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Get the selected modules to sync by user selection or config file
def get-selected-modules [
  --from(-f): record,   # Specify the meta data source
] {
  print -n (char nl)
  let selected = $from.availableModules | input list --multi 'Please select the modules to sync (space to select, esc or q to quit, enter to confirm)'
  if ($selected | is-empty) {
    print $'You have not selected any modules, bye...'
    exit $ECODE.SUCCESS
  }
  return $selected
}

# Create meta data snapshot and wait for the task to finish, return the snapshot SHA if success
def handle-create-snapshot [
  source: record,       # Specify the meta source of the snapshot to create
] {
  let start = date now
  let taskId = create-snapshot $source
  print $'(ansi pr) STEP 1/3: (ansi reset) Snapshot creating task started, id: (ansi p)($taskId)(ansi reset)'
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
  source: record,       # Specify the meta source of the snapshot to upload
  rootOid: string,      # Specify the root oid of the snapshot to upload
] {
  let start = date now
  let taskId = upload-snapshot $source $rootOid
  print -n (char nl)
  print $'(ansi pr) STEP 2/3: (ansi reset) Snapshot uploading task started, id: (ansi p)($taskId)(ansi reset)'
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
  dest: record,         # Specify the meta dest of the snapshot to import
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
    print -n '#'
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
    print $'Failed to import metadata, please try again later.'
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
  source: record,       # Specify the meta source of the snapshot to upload
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
  dest: record,         # Specify the meta dest of the snapshot to import
  rootOid: string,      # Specify the root OID of the meta data to import
  metaUrl: string,      # Specify the meta data download url for importing
  --modules(-m): list,  # Specify the modules to sync
] {
  const destImportApi = '/api/trantor/task/exec/SyncAllInOneTask'
  let query = { teamId: $dest.teamId, teamCode: $dest.teamCode, userId: '1', verbose: 'false' } | url build-query
  mut importPayload = {
    rootOid: $rootOid,
    downloadUrl: $metaUrl,
    ddlAutoUpdate: true,
    resetModuleForInstall: true,
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
  let resp = try { http get $DETAIL_URL } catch {
    try { http get $DETAIL_URL } catch { sleep 0.5sec; http get $DETAIL_URL }
  }
  if not $resp.success {
    print $'Fetch task detail failed with error: ($resp.err)'
  }
  $resp.data
}

alias main = meta sync
