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
# [ ] Add a config file for all the settings
# [ ] Allow default settings, so we can run the script without any arguments
# [ ] Update user manual for meta data syncing script
# Usage:
# 97ed2a8177c8c1b7b90940ae1cd2eb2ff63b7067239ecd628e8ebe66fbd314a5
# https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/trantor2/console/export/44d99c6b-13fc-4c38-8a3e-f4ee01f86dc0/22-TERP-97ed2a8177c8c1b7b90940ae1cd2eb2ff63b7067239ecd628e8ebe66fbd314a5.zip
# https://back-terp-console-test.app.terminus.io/task/run-detail?taskRunId=41941

use std ellie
use ../utils/common.nu [ECODE, hr-line]

const QUERY_INTERVAL = 1sec
const FROM_TEAM_ID = '22'
const FROM_TEAM_CODE = 'TERP'
const TO_TEAM_ID = '22'
const TO_TEAM_CODE = 'TERP'
const SOURCE_HOST = 'https://back-terp-console-dev.app.terminus.io'
const DEST_HOST = 'https://back-terp-console-test.app.terminus.io'
const AVAILABLE_MODULES = [ERP_HR ERP_PRD ERP_PLN ERP_GEN ERP_SCM ERP_FI ERP_FIN ERP_CO TERP_PORTAL]

# Test data
const TEST_OID = '130b77d9827a86cf7cbcd6b835a9d1272509662de4648d45480f842f384c919e'
const TEST_META = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/trantor2/console/export/68d44bfb-1e5b-4356-b6a7-cca59da9db40/22-TERP-130b77d9827a86cf7cbcd6b835a9d1272509662de4648d45480f842f384c919e.zip'

export def 'meta sync' [
  --from(-f): string,   # Specify the source meta data provider name
  --to(-t): string,     # Specify the destination meta data provider name
  --all(-a),            # Specify whether to sync all the modules
  --selected(-s),       # Sync the selected modules in config file
] {
  print -n (ellie); print '        Terminus TERP Meta Data Syncing Tool'; hr-line
  confirm-check
  let modules = if $all { [] } else { get-selected-modules }
  if ($modules | is-empty) {
    print $'Becarefull, You are going to sync (ansi p)ALL(ansi reset) the modules...'
  } else {
    print $'You have selected the following modules to import: (ansi p)($modules | str join ",")(ansi reset)'
  }

  let start = date now
  let snapshotOid = handle-create-snapshot $FROM_TEAM_ID $FROM_TEAM_CODE
  hr-line
  print $'Snapshot created successfully with RootOID: (ansi p)($snapshotOid)(ansi reset)'
  let downloadUrl = handle-upload-snapshot $FROM_TEAM_ID $FROM_TEAM_CODE $snapshotOid
  # let downloadUrl = handle-upload-snapshot 891a7cc3d936cba2ca1e826219770c9544fb40e21180ba1d9d3e78b54330ed25
  print $'Snapshot uploaded successfully with download Url:'
  print $'(ansi p)($downloadUrl)(ansi reset)'
  handle-import-metadata $TO_TEAM_ID $TO_TEAM_CODE $snapshotOid $downloadUrl --modules $modules
  # handle-import-metadata $TO_TEAM_ID $TO_TEAM_CODE $TEST_OID $TEST_META
  let end = date now
  print $'Total time consumed: (ansi p)($end - $start)(ansi reset)'
}

# Make sure you know what you are doing
def confirm-check [] {
  print $'Attention:'; hr-line
  print $'You are going to sync meta data from: (ansi p)($SOURCE_HOST) @ ($FROM_TEAM_CODE):($FROM_TEAM_ID)(ansi reset)'
  print $'To: (ansi p)($DEST_HOST) @ ($TO_TEAM_CODE):($TO_TEAM_ID)(ansi reset), are you sure to continue?'
  let check = $'($FROM_TEAM_ID)-to-($TO_TEAM_ID)'
  let confirm = input $'Please confirm by typing (ansi r)($check)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Syncing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $check {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($check)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Get the selected modules to sync by user selection or config file
def get-selected-modules [] {
  print -n (char nl)
  let selected = $AVAILABLE_MODULES | input list --multi 'Please select the modules to sync (space to select, esc or q to quit, enter to confirm)'
  if ($selected | is-empty) {
    print $'You have not selected any modules, bye...'
    exit $ECODE.SUCCESS
  }
  return $selected
}

# Create meta data snapshot and wait for the task to finish, return the snapshot SHA if success
def handle-create-snapshot [
  teamId: string,       # Specify the team id of the snapshot to create
  teamCode: string,     # Specify the team code of the snapshot to create
] {
  let start = date now
  let taskId = create-snapshot $teamId $teamCode
  print $'(ansi pr) STEP 1/3: (ansi reset) Snapshot creating task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $SOURCE_HOST
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $SOURCE_HOST)
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
  teamId: string,       # Specify the team id of the snapshot to upload
  teamCode: string,     # Specify the team code of the snapshot to upload
  rootOid: string,      # Specify the root oid of the snapshot to upload
] {
  let start = date now
  let taskId = upload-snapshot $teamId $teamCode $rootOid
  print -n (char nl)
  print $'(ansi pr) STEP 2/3: (ansi reset) Snapshot uploading task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $SOURCE_HOST
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status): [Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)]'
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $SOURCE_HOST)
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
  teamId: string,       # Specify the team id of the snapshot to upload
  teamCode: string,     # Specify the team code of the snapshot to upload
  rootOid: string,      # Specify the root oid of the snapshot to upload
  metaUrl: string,      # Specify the meta data download url for importing
  --modules(-m): list,  # Specify the modules to sync
] {
  let start = date now
  let taskId = import-metadata $teamId $teamCode $rootOid $metaUrl --modules $modules
  print -n (char nl)
  print $'(ansi pr) STEP 3/3: (ansi reset) Meta data importing task started, id: (ansi p)($taskId)(ansi reset)'
  mut detail = fetch-task-detail $taskId $DEST_HOST
  print 'Task running detail:'; hr-line
  mut stats = $detail.progress
  print $'(ansi p)($detail.taskName)@($detail.taskRunId)(ansi reset) is ($detail.status):'

  let webDetailUrl = $'($DEST_HOST)/task/run-detail?taskRunId=($detail.taskRunId)'
  print $'For more detail please visit: (ansi p)($webDetailUrl)(ansi reset)'
  print $'Task Status: Total: ($stats.total), Success: ($stats.success), Failed: ($stats.failed)'
  hr-line 60 --color lcd

  mut successCount = $stats.success
  while $stats.success + $stats.failed < $stats.total {
    $detail = (fetch-task-detail $taskId $DEST_HOST)
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
  print $'(ansi p)Bravo! Meta data syncronized successfully.(ansi reset)'
}

# Create meta data snapshot
def create-snapshot [
  teamId: string,       # Specify the team id of the snapshot to create
  teamCode: string,     # Specify the team code of the snapshot to create
] {
  const snapShotApi = '/api/trantor/task/exec/RebuildObjectTask'
  let query = { teamId: $teamId, teamCode: $teamCode, userId: '1', verbose: 'false' } | url build-query
  let resp = http post --content-type application/json $'($SOURCE_HOST)($snapShotApi)?($query)' {}
  if not $resp.success {
    print $'Failed to create snapshot, error: ($resp.err)'
  }
  $resp.data.taskId
}

# Upload meta data snapshot to OSS
def upload-snapshot [
  teamId: string,       # Specify the team id of the snapshot to upload
  teamCode: string,     # Specify the team code of the snapshot to upload
  rootOid: string,      # Specify the root OID of the snapshot to upload
] {
  const snapShotUploadApi = '/api/trantor/task/exec/UploadObjectToOSSTask'
  let query = { teamId: $teamId, teamCode: $teamCode, userId: '1', verbose: 'false' } | url build-query
  let resp = http post --content-type application/json $'($SOURCE_HOST)($snapShotUploadApi)?($query)' { rootOid: $rootOid }
  if not $resp.success {
    print $'Upload snapshot to OSS failed with error: ($resp.err)'
  }
  $resp.data.taskId
}

# Import the meta data from OSS to destination
def import-metadata [
  teamId: string,       # Specify the team id of the meta data to import
  teamCode: string,     # Specify the team code of the meta data to import
  rootOid: string,      # Specify the root OID of the meta data to import
  metaUrl: string,      # Specify the meta data download url for importing
  --modules(-m): list,  # Specify the modules to sync
] {
  const destImportApi = '/api/trantor/task/exec/SyncAllInOneTask'
  let query = { teamId: $teamId, teamCode: $teamCode, userId: '1', verbose: 'false' } | url build-query
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
  let resp = http post --content-type application/json $'($DEST_HOST)($destImportApi)?($query)' $importPayload
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

meta sync
