#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/12/29 22:06:52
# Description: A tool to deploy from artifacts
# [√] Build: Run pipeline to create artifacts
# [√] Download: Download artifacts from releaseID
# [√] Download: Download artifacts from uniq version number
# [√] Upload: Upload artifacts from local disk to Erda project
# [√] Create: Create deploy order to deploy artifacts to Erda cluster
# [√] Execute: Execute Erda Pipeline to deploy artifacts to Erda cluster
# [√] Query and display the deploy status
# [ ] Add artifact deploy config file
# [ ] Validate input args and flags
# [ ] Confirm the deploy order detail before execute
# [ ] Support artifact actions: deploy, produce, consume
# [ ] Update artifact related docs
# Usage:
#   - t art deploy -e TEST ${version}   使用指定版本制品部署目标测试环境
#   - t art deploy -e TEST -s           选择制品并部署目标测试环境
#   - t art deploy -e TEST -c           构建制品并部署目标测试环境（支持同项目 & 不同项目, 不同项目需要下载制品然后上传）
#   - t art produce                     构建制品并输出制品信息
#   - t art consume -e TEST ${version}  下载指定版本的制品并上传到目标项目然后部署指定环境
# Reference
#   - https://erda.cloud/api/terminus/releases?isProjectRelease=true&isStable=true&pageNo=1&pageSize=10&projectId=1158&version=2.5.23.1214%2B20231227182207
#   - ls -f | get name | to text | fzf --height 50% -e --inline-info --preview 'cat {}'
# Usage:

use ../utils/common.nu [ECODE, hr-line, log, get-tmp-path]
use ../utils/erda.nu [get-erda-auth, renew-erda-session, should-retry-req]
use pipeline.nu [create-cicd, run-cicd, query-cicd-by-id, fetch-cicd-detail]

const SRC_PROJECT_ID = 190
const DEST_PROJECT_ID = 1158
const ENVIRONMENT = 'TEST'
const ERDA_HOST = 'https://erda.cloud'
const DEPLOY_POLLING_INTERVAL = 2sec
const ARTIFACT_VERSION = '2.5.23.1228+20240220102619'

# Build, Download and Upload artifacts, create deploy order then deploy from artifacts
export def artifacts [
  action: string,             # Action to perform, such as deploy, produce, and consume
  --select(-s),               # Select the artifact version to deploy to the dest environment
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --branch(-b): string,       # The branch name to build the artifact
  --version(-v): string,      # The version number of the artifact to deploy
  --dest-env(-e): string,     # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
] {
  let version = $ARTIFACT_VERSION
  # let meta = create-artifact-from-pipeline 1273 12201 fr-erp-release master .erda/pipelines/ci-artifact.yml
  # print $'(char nl)Artifact has been created successfully:'; hr-line; print $meta
  # let meta = $meta | transpose -r | get 0
  # download-artifact-from-release $meta.releaseID $meta.version
  let matches = query-release-by-version $version $SRC_PROJECT_ID --verbose
  if ($matches | is-empty) {
    print $'No artifact found for version ($version) in project ID ($SRC_PROJECT_ID)'
    return
  }
  let dest = download-artifact-from-release $matches.releaseId.0 $version
  let destMatches = query-release-by-version $version $DEST_PROJECT_ID
  if ($destMatches | is-empty) {
    upload-artifact $version $dest --oid 2 --pid $DEST_PROJECT_ID
  } else {
    print $'Artifact of version (ansi g)($version)(ansi reset) already exists in project ID (ansi g)($DEST_PROJECT_ID)(ansi reset):'
    print $destMatches
  }
  let selectedRelease = query-release-by-version $version $DEST_PROJECT_ID
  let doid = create-deploy-order ($selectedRelease.0 | into record) $ENVIRONMENT --pid $DEST_PROJECT_ID
  if not ($doid | is-empty) { polling-artifact-deploy $doid }
}

# Create artifact from running the specified pipeline
def create-artifact-from-pipeline [
  pid: int,           # Project ID to create artifact
  appId: int,         # Application ID to create artifact
  appName: string,    # Application name
  branch: string,     # Branch name to run the pipeline
  pipeline: string,   # Pipeline file to run and create artifact
] {
  let cicdid = create-cicd $appId $appName $branch $pipeline
  run-cicd $cicdid $appId $pid
  query-cicd-by-id $cicdid --watch
  get-artifact-meta $cicdid trantor2-artifacts
}

# Polling and display artifacts deploy status
def polling-artifact-deploy [
  doid: string,       # Deploy order ID to poll and display the deploy status
] {
  let deployUrl = $'($ERDA_HOST)/api/terminus/deployment-orders/($doid)/actions/deploy'
  let deploy = http post -e --headers (get-erda-auth --type nu) --content-type application/json $deployUrl {}
  if not ($deploy.success) {
    print $'Deployment started failed with error: (ansi r)($deploy.err.msg)(ansi reset)'
    return
  }
  print 'Deployment has been started successfully!'

  let groups = get-artifact-deploy-detail $doid | get data.applicationsInfo
  let total = $groups | length
  const FINISH_STATUS = [OK, FAILED, CANCELED]
  const UNFINISH_STATUS = [DEPLOYING, WAITDEPLOY]
  print $'(char nl)Artifact deploy Detail:'; hr-line

  # pipelineTasks status: Created,Analyzed,Success,Queue,Running,Failed,StopByUser,NoNeedBySystem
  for g in $groups -n {
    let groupStatus = $g.item | get status
    let apps = $g.item | get name | str join ', '
    let groupSuccess = $groupStatus | all {|it| $it == 'OK' }
    let groupFailed = $groupStatus | any {|it| $it == 'FAILED' }
    let groupCancelled = $groupStatus | any {|it| $it == 'CANCELED' }
    let groupUnfinish = $groupStatus | any {|it| $it in $UNFINISH_STATUS }
    let indicator = if $groupSuccess {
        $'(ansi g)✓(ansi reset)  Deploy (ansi g)($apps)(ansi reset) Finished Successfully!'
      } else if $groupFailed {
        $'(ansi y)⚠(ansi reset)  Deploy (ansi y)($apps)(ansi reset) Failed!'
      } else if $groupCancelled {
        $'(ansi y)👻(ansi reset) Deploy (ansi y)($apps)(ansi reset) Was cancelled!'
      } else if $groupUnfinish {
        $'(ansi pb)🪄(ansi reset) Artifact group (ansi g)[($apps)](ansi reset) is being deployed ...'
      } else {
        $'(ansi r)✗(ansi reset) Unknown Status: ($groupStatus | str join ",")'
      }

    print $'Group ($g.index + 1)/($total): ($indicator)'
    mut keepPolling = true
    while $keepPolling {
      print -n '*'  # * 💤 👣 ✨ 🍵 ⚡ 🎉 🔹 🔸
      let detail = get-artifact-deploy-detail $doid
      let apps = $detail.data.applicationsInfo
      # DEPLOYING,OK,FAILED
      let status = $apps | get $g.index | get status
      if ($status | any {|it| $it in $UNFINISH_STATUS }) {
        $keepPolling = true
      } else {
        $keepPolling = false
        print $'(char nl)Artifact group deploy finished with status: (ansi g)($status | str join ",")(ansi reset).'
        hr-line 60 -c grey66
      }
      sleep $DEPLOY_POLLING_INTERVAL
    }
  }

  # Wait for the final status to be updated
  loop {
    sleep $DEPLOY_POLLING_INTERVAL
    let detail = get-artifact-deploy-detail $doid
    if $detail.data.status in $FINISH_STATUS { break }
  }

  # Refresh the query result and print the final time cost
  let detail = get-artifact-deploy-detail $doid
  let duration = ($detail.data.updatedAt | into datetime) - ($detail.data.startedAt | into datetime)
  print $'(char nl)Artifacts deploy finished with status: (ansi p)($detail.data.status)(ansi reset)! Total time cost: ($duration)'
}

# Get artifact deploy detail by deploy order ID
def get-artifact-deploy-detail [
  doid: string      # Deploy order ID to query the deploy detail
] {
  let queryUrl = $'($ERDA_HOST)/api/terminus/deployment-orders/($doid)'
  let detail = http get -e --headers (get-erda-auth --type nu) $queryUrl
  $detail
}

# Create deploy order to deploy artifact to Erda cluster
def create-deploy-order [
  artifact: record,               # The artifact to create deploy order
  environment: string = 'DEV',    # The environment to deploy the artifact, such as DEV, TEST, STAGING, PROD, etc.
  --pid: int,                     # The Project ID to deploy the artifact
] {
  let releaseDetailUrl = $'($ERDA_HOST)/api/terminus/releases/($artifact.releaseId)'
  let doCreateUrl = $'($ERDA_HOST)/api/terminus/deployment-orders'
  let release = http get -e --headers (get-erda-auth --type nu) $releaseDetailUrl
  let modes = $release.data.modes
  mut choices = []
  for m in ($modes | columns) {
    if $m == 'All' {
      $choices = ($choices | append { mode: $m, children: null })
    } else {
      let children = $modes | get $m | get applicationReleaseList | flatten | get applicationName | str join ','
      $choices = ($choices | append { mode: $m, children: $children })
    }
  }
  let selected = $choices
    | upsert option {|c| if $c.mode == 'All' { 'All' } else { $'($c.mode) (ansi w)- ($c.children)(ansi reset)' } }
    | input list -d option 'Please select the applications to deploy'

  print $'The following applications will be deployed:(char nl)'
  $modes | get $selected.mode | get applicationReleaseList | flatten
    | select applicationName createdAt releaseName version | print

  let doPayload = {
    projectId: $pid,
    modes: [$selected.mode],
    workspace: $environment,
    releaseId: $artifact.releaseId,
  }
  let do = http post -e --headers (get-erda-auth --type nu) --content-type application/json $doCreateUrl $doPayload
  if not $do.success {
    print $'Failed to create deploy order with error message:'
    print $'(ansi r)($do.err.msg)(ansi reset)'
  } else {
    print $'Deploy order has been created successfully with ID (ansi g)($do.data.id)(ansi reset)'
    return $do.data.id
  }
}

# Get artifact meta data from CICD ID and task name, such as version, releaseID, etc.
def get-artifact-meta [
  cicdid: int,        # CICD ID to query artifact meta info
  taskName: string,   # Task name of the pipeline task to query artifact meta info
] {
  let detail = fetch-cicd-detail $cicdid
  $detail.data.pipelineStages
    | flatten
    | get pipelineTasks
    | where name == $taskName
    | get result?.metadata?
    | flatten
    | select name value
}

# Query release by version number and project ID
def query-release-by-version [
  version: string,    # Version number to query
  pid: int,           # Project id to query the release artifact
  --verbose(-v),      # Print more details of the matched artifact
] {
  let queryUrl = $'($ERDA_HOST)/api/terminus/releases'
  let payload = {
    pageNo: '1',
    pageSize: '100',
    isStable: 'true',
    version: $version,
    projectId: $'($pid)',
    isProjectRelease: 'true'
  }
  let filtered = curl --silent -H (get-erda-auth) $'($queryUrl)?($payload | url build-query)' | from json
  let matches = if $filtered.success {
    $filtered.data.list
      | select projectName projectId createdAt version releaseId
      | upsert releaseId {|it| $it.releaseId }
  }
  if not $verbose { return $matches }

  if ($matches | is-empty) {
    print $'No release found for version ($version) in project ID ($pid)'
  } else {
    print $'Found matched artifact release:'; print $matches
  }
  return $matches
}

# 根据创建制品的 ReleaseId 下载项目制品
def download-artifact-from-release [
  releaseId: string,    # Release ID to download artifact
  version: string,      # Version number of the artifact
] {
  let tmp = $'(get-tmp-path)/terp/artifacts'
  if not ($tmp | path exists) { mkdir $tmp }
  # Download artifact
  let downloadUrl = $'($ERDA_HOST)/api/terminus/releases/($releaseId)/actions/download'
  let dest = $'($tmp)/($version).zip'
  print $'Downloading artifact of version (ansi g)($version)(ansi reset) and releaseId (ansi g)($releaseId)(ansi reset) ...'
  curl --silent -H (get-erda-auth) $downloadUrl -o $dest
  print $'Artifact has been downloaded to ($dest)(char nl)'
  $dest
}

# https://erda.cloud/api/terminus/releases/actions/check-version?isProjectRelease=true&orgID=2&projectID=1158&version=2.5.24.0130%2B20240223134546
# 上传制品到 Erda 项目
def upload-artifact [
  version: string,    # Version number of the artifact
  file: string,       # File path of the artifact to upload
  --pid: int,         # Project ID to upload the artifact
  --oid: int,         # Organization ID to upload the artifact
] {
  let releaseUploadUrl = $'($ERDA_HOST)/api/terminus/releases/actions/upload'
  let upload = upload-file $file
  print $upload
  let payload = {
    orgId: $oid,
    projectID: $pid,
    version: $version,
    userId: $upload.creator,
    diceFileID: $'($upload.fileID)',
  }
  let release = http post -e --headers (get-erda-auth --type nu) --content-type application/json $'($releaseUploadUrl)' $payload
  if $release.success {
    print $'Artifact has been uploaded successfully with version (ansi g)($version)(ansi reset)'
  } else {
    print $'Failed to upload artifact of version ($version) with error message:'
    print $'(ansi r)($release.err.msg)(ansi reset)'
  }
}

# Upload file from local disk to Erda Cloud
def upload-file [
  file: string,       # File path to upload
] {
  let uploadUrl = $'($ERDA_HOST)/api/files'
  let upload = curl --silent -H (get-erda-auth) -F $'file=@($file)' $uploadUrl | from json
  if $upload.success {
    print $'File (ansi g)($file)(ansi reset) has been uploaded successfully to Erda Cloud'
    return { fileID: $upload.data.uuid, url: $upload.data.url, creator: $upload.data.creator }
  }
  print $'Failed to upload file ($file) to Erda Cloud with error message:'
  print $upload.err.msg
}

alias main = artifacts
