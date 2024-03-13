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
# [√] Add artifact deploy config file
# [√] Display and confirm produce action detail before execute
# [√] Deploy all apps by default, stop and select the group to deploy if no matched group found
# [√] Display and confirm consume action detail before execute
# [√] Install fzf if not exist for artifact version selection
# [√] Use fzf to select the artifact version to deploy
# [√] Deploy artifacts by deploy order ID
# [√] Confirm the deploy order detail before execute
# [ ] If there is only one deploy group, deploy it directly without select
# [ ] Show artifact deploy permission info somewhere
# [ ] Validate input args and flags
# [ ] Support artifact actions: deploy, produce, consume
# [ ] Support private ERDA host and login with username and password
# [ ] Update artifact related docs
# Usage:
#   - t art deploy -e TEST -v ${version}    使用指定版本制品部署目标测试环境
#   - t art deploy -e TEST                  选择制品并部署目标测试环境
#   - t art deploy -e TEST -c               构建制品并部署目标测试环境（支持同项目 & 不同项目, 不同项目需要下载制品然后上传）
#   - t art produce                         构建制品并输出制品信息
#   - t art consume -e TEST -v ${version}   下载指定版本的制品并上传到目标项目然后部署指定环境
# Reference
#   - https://erda.cloud/api/terminus/releases?isProjectRelease=true&isStable=true&pageNo=1&pageSize=10&projectId=1158&version=2.5.23.1214%2B20231227182207
#   - ls -f | get name | to text | fzf --height 50% -e --inline-info --preview 'cat {}'
# Usage:

use std ellie

use pipeline.nu [create-cicd, run-cicd, query-cicd-by-id, fetch-cicd-detail]
use ../utils/common.nu [ECODE, hr-line, log, get-tmp-path]
use ../utils/erda.nu [VALID_ENV, ERDA_HOST, get-erda-auth, renew-erda-session, should-retry-req]

const DEPLOY_POLLING_INTERVAL = 2sec
const SUPPORTED_ACTIONS = [deploy, produce, consume]

# Build, Download and Upload artifacts, create deploy order then deploy from artifacts
export def artifacts [
  action: string,             # Action to perform, such as `deploy`, `produce`, and `consume`
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Alias of source config to build or download artifact
  --to(-t): string,           # Alias of destination config to upload or deploy artifact
  --branch(-b): string,       # The branch name to build the artifact
  --version(-v): string,      # The version number of the artifact to deploy
  --dest-env(-e): string,     # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `All` by default
  --doid(-d): string,         # The deploy order ID to deploy and query the deploy detail
] {
  cd $env.TERMIX_DIR
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..7 }
  print -n (ellie); print $'        Terminus TERP Artifacts Assistant @ ($sha)'; hr-line

  let checkEnv = {|did?|
      if ($did | is-not-empty) { return }
      if ($dest_env | is-empty) {
        print $'(ansi r)Please specify the dest environment to deploy the artifact by --dest-env/-e, such as DEV,TEST,STAGING,PROD, etc.(ansi reset)'
        exit $ECODE.INVALID_PARAMETER
      }
    }

  let checkVersion = {
      if ($version | is-empty) {
        print $'(ansi r)Please specify the version of the artifact to deploy by --version/-v...(ansi reset)'
        exit $ECODE.INVALID_PARAMETER
      }
    }

  load-art-conf
  match $action {
    produce => { produce-artifact --from=$from --branch=$branch --need-confirm }
    consume => { do $checkEnv; do $checkVersion; consume-artifact $version $dest_env -f $from -t $to -c --deploy-group=$deploy_group --no-deploy=$no_deploy }
    deploy => {
      do $checkEnv $doid
      (deploy-artifact --dest-env $dest_env --combine=$combine --from $from --branch $branch --doid $doid
                       --version $version --to $to --deploy-group $deploy_group --no-deploy=$no_deploy)
    }
    _ => {
      print $'Unsupported action: (ansi r)($action)(ansi reset), supported actions are: (ansi g)($SUPPORTED_ACTIONS | str join ", ")(ansi reset)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
}

# Preview the selected artifact detail info
export def preview-artifact [
  version: string,      # The version of the selected artifact
  metaPath: string,     # The path of the artifact meta data file
] {
  const SELECT_COLUMN = [version projectName userId createdAt releaseId modes]
  print $'Version: ($version)'; hr-line
  $env.config.table.mode = 'psql'
  let releases = open $metaPath
  let selected = $releases.0.data.list | where version == $version | get 0
  mut meta = $selected | select ...$SELECT_COLUMN
  $meta.modes = (($meta.modes | from json | columns) | str join ', ')
  $meta.createdBy = ($releases.userInfo | get -i $meta.userId).nick?.0?
  $meta | select ...($SELECT_COLUMN | update 2 createdBy) | print; hr-line
  print $selected.changelog
}

# Load meta data settings and store them to environment variable
def --env load-art-conf [] {
  let artConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get artifact
  $env.ART_CONF = $artConf
  $artConf
}

# Produce artifacts from source project and display the artifact meta info
def produce-artifact [
  --from(-f): string,         # Source config to build or download artifact
  --branch(-b): string,       # The branch name to build the artifact
  --need-confirm(-c),         # Need to confirm the produce action before execute
] {
  let setting = validate-produce-setting --from $from --branch $branch
  if $need_confirm { confirm-produce $setting }
  let meta = create-artifact-from-pipeline $setting
  print $'(char nl)Artifact has been created successfully:'; hr-line;
  $meta
}

# Confirm the artifact produce action settings before execute
def confirm-produce [
  setting: record,    # Source setting to produce the artifact
] {
  print $'You are going to produce artifacts with the following config:'
  let option = ($setting | reject -i username password)
  hr-line 60 -c grey66; print $option; hr-line 60 -c grey66
  print $'Are you sure to continue? '
  let confirm = input $'Please input (ansi p)($setting.branch)(ansi reset) to continue and (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Artifacts creating cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $setting.branch {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($setting.branch)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Confirm the artifact cosume action settings before execute
def confirm-consume [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  destSetting: record,        # Destination setting to consume the artifact
  --no-deploy(-n),            # Don't deploy after creating deploy order
] {
  let msg = if $no_deploy {
      $'You are going to fetch the artifacts and create deploy order with the following config:'
    } else {
      $'You are going to fetch the artifacts and (ansi r)DEPLOY(ansi reset) them with the following config:'
    }
  print $msg
  let setting = {
      version: $version, destEnv: $destEnv,
      destSetting: ($destSetting | reject -i username password)
    }
  hr-line 60 -c grey66; print ($setting | table -e); hr-line 60 -c grey66
  print $'Are you sure to continue? '
  let confirm = input $'Please input (ansi p)($version)(ansi reset) to continue and (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Operation cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($version)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Confirm the artifact deploy action settings before execute
def confirm-deploy [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  destSetting: record,        # Destination setting to consume the artifact
  --doid(-d): string,         # The deploy order ID to deploy and query the deploy detail
  --no-deploy(-n),            # Don't deploy after creating deploy order
] {
  # TODO: Confirm deploy by --doid with more detail
  let msg = if $no_deploy {
      $'You are going to create deploy order from ($version) at ($destEnv) with the following config:'
    } else {
      $'You are going to (ansi r)DEPLOY ($version) to ($destEnv)(ansi reset) with the following config:'
    }
  print $msg
  let setting = {
      version: $version, destEnv: $destEnv,
      destSetting: ($destSetting | reject -i username password)
    }
  hr-line 60 -c grey66; print ($setting | table -e); hr-line 60 -c grey66
  print $'Are you sure to continue? '
  let confirm = input $'Please input (ansi p)($version)(ansi reset) to continue and (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { echo $'Operation cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    echo $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($version)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Validate the artifact produce action settings and return the validated settings
def validate-produce-setting [
  --from(-f): string,         # Source config to build or download artifact
  --branch(-b): string,       # The branch name to build the artifact
] {
  let artConf = $env.ART_CONF
  let setting = if ($from | is-empty) {
    $artConf.source | values | default false default | where default == true
  } else {
    [($artConf.source | get -i $from)]
  }

  if ($setting | compact | is-empty) {
    print $'(ansi r)No source config found to build or download the artifact, bye...(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  if ($setting | compact | length) > 1 {
    print $'(ansi r)Multiple default source configs found, make sure that you have only one default source.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  if ($branch | is-empty) { $setting } else { $setting | upsert branch $branch }
}

# Cosume the artifacts: download, upload and deploy the artifacts to the dest environment
def consume-artifact [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
  --need-confirm(-c),         # Need to confirm the consume action before execute
] {
  let destEnv = $destEnv | str upcase
  let srcSetting = validate-produce-setting --from $from
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy
  if $need_confirm { confirm-consume $version $destEnv $destSetting --no-deploy=$no_deploy }
  let srcPID = $srcSetting.projectId
  let destPID = $destSetting.projectId
  let matches = query-release-by-version $version $srcPID --verbose --name 'Source Project' --host $srcSetting.erdaHost
  if ($matches | is-empty) {
    print $'No artifact found for version ($version) in project ID ($srcPID)'
    return
  }
  let dest = download-artifact-from-release $matches.releaseId.0 $version --host $srcSetting.erdaHost
  let destMatches = query-release-by-version $version $destPID --host $destSetting.erdaHost
  if ($destMatches | is-empty) {
    upload-artifact $version $dest --oid $destSetting.orgId --pid $destPID --host $destSetting.erdaHost
  } else {
    print $'Artifact of version (ansi g)($version)(ansi reset) already exists in dest project ID (ansi g)($destPID)(ansi reset):(char nl)'
    print $destMatches
  }
  let selectedRelease = query-release-by-version $version $destPID --host $destSetting.erdaHost
  let deployGroup = $destSetting.deployGroup | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --pid $destPID --deploy-group=$deployGroup --host $destSetting.erdaHost
  if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid --host $destSetting.erdaHost }
}

# Validate the artifact consume action settings and return the validated settings
def validate-consume-setting [
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --deploy,                   # Perform a deploy action rather than consume action
  --doid(-d): string,         # The deploy order ID to deploy and query the deploy detail
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --to(-t): string,           # Destination config to upload or deploy artifact
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  if not ($deploy and ($doid | is-not-empty)) {
    let destEnv = $destEnv | str upcase
    if $destEnv not-in $VALID_ENV {
      print $'Invalid dest environment: (ansi r)($destEnv)(ansi reset), supported environments are: ($VALID_ENV | str join ", ")'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  let artConf = $env.ART_CONF
  let setting = if ($to | is-empty) {
    $artConf.destination | values | default false default | where default == true
  } else {
    [($artConf.destination | get -i $to)]
  }

  if ($setting | compact | is-empty) {
    print $'(ansi r)No destination config found to deploy the artifact, bye...(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  if ($setting | compact | length) > 1 {
    print $'(ansi r)Multiple default destination configs found, make sure that you have only one default destination.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  if ($deploy_group | is-empty) { $setting } else { $setting | upsert deployGroup $deploy_group }
}

def deploy-artifact [
  --dest-env: string,         # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --branch(-b): string,       # The branch name to build the artifact
  --version(-v): string,      # The version number of the artifact to deploy
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
  --doid(-d): string,         # The deploy order ID to deploy and query the deploy detail
] {
  let destEnv = $dest_env | default '' | str upcase
  if ($destEnv | is-not-empty) { print $'Deploy artifact to (ansi g)($destEnv)(ansi reset)'; hr-line }
  let srcSetting = validate-produce-setting --from $from
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy --deploy --doid $doid
  if (not ($doid | is-empty)) and (not $no_deploy) {
    print $'You are going to deploy the artifact with deploy order ID: (ansi g)($doid)(ansi reset)'
    polling-artifact-deploy $doid --host $destSetting.erdaHost
    return
  }
  let version = if ($version | is-empty) { select-artifact-by-fzf $destSetting } else { $version }
  if ($version | is-empty) {
    print $'(ansi r)No artifact version selected, deploy cancelled, bye...(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  confirm-deploy $version $destEnv $destSetting --doid $doid --no-deploy=$no_deploy
  let selectedRelease = query-release-by-version $version $destSetting.projectId --host $destSetting.erdaHost
  let deployGroup = $destSetting.deployGroup | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --pid $destSetting.projectId --deploy-group=$deployGroup --host $destSetting.erdaHost
  if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid --host $destSetting.erdaHost }
}

# Select a artifact version to deploy from the release list
def select-artifact-by-fzf [
  destSetting: record,    # The destination setting to search and deploy the artifact
] {
  # ~/.termix-nu/terp/artifacts/releases.json
  let tmp = $'(get-tmp-path)/terp/artifacts'
  if not ($tmp | path exists) { mkdir $tmp }
  let releaseMetaPath = $'($tmp)/releases.json'
  let releases = query-release-candidates $destSetting.projectId --name $destSetting.projectName --host $destSetting.erdaHost
  $releases | tee { save -f $releaseMetaPath } | get data.list | length | ignore
  let title = $'Select the artifact to deploy:'
  let PREVIEW_CMD = $"nu -c 'overlay use actions/artifact.nu; preview-artifact {} ($releaseMetaPath)'"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)" --preview-window=right:65%:~2'
  let FZF_THEME = '--color=bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'
  $env.FZF_DEFAULT_OPTS = $'--height 50% --layout=reverse --exact --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let version = $releases.data.list | select version createdAt | sort-by -r createdAt | get version | str join (char nl) | fzf
  $version
}

# Create artifact from running the specified pipeline
def create-artifact-from-pipeline [
  setting: record,    # The source setting to create artifacts
] {
  let appId = $setting.appId
  let host = $setting.erdaHost
  let cicdid = create-cicd $appId $setting.appName $setting.branch $setting.pipeline --host $host
  run-cicd $cicdid $appId $setting.projectId --host $host
  query-cicd-by-id $cicdid --watch --host $host
  get-artifact-meta $cicdid $setting.artifactNode --host $host
}

# Polling and display artifacts deploy status
def polling-artifact-deploy [
  doid: string,       # Deploy order ID to poll and display the deploy status
  --host: string,     # The Erda host to poll the deploy status
] {
  let deployUrl = $'($host)/api/terminus/deployment-orders/($doid)/actions/deploy'
  let deploy = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $deployUrl {}
  if not ($deploy.success) {
    print $'Deployment started failed with error: (ansi r)($deploy.err.msg)(ansi reset)'
    return
  }
  print 'Deployment has been started successfully!'

  let groups = get-artifact-deploy-detail $doid --host $host | get data.applicationsInfo
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
      let detail = get-artifact-deploy-detail $doid --host $host
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
    let detail = get-artifact-deploy-detail $doid --host $host
    if $detail.data.status in $FINISH_STATUS { break }
  }

  # Refresh the query result and print the final time cost
  let detail = get-artifact-deploy-detail $doid --host $host
  let duration = ($detail.data.updatedAt | into datetime) - ($detail.data.startedAt | into datetime)
  print $'(char nl)Artifacts deploy finished with status: (ansi p)($detail.data.status)(ansi reset)! Total time cost: ($duration)'
}

# Get artifact deploy detail by deploy order ID
def get-artifact-deploy-detail [
  doid: string      # Deploy order ID to query the deploy detail
  --host: string,   # The Erda host to query the deploy detail
] {
  let queryUrl = $'($host)/api/terminus/deployment-orders/($doid)'
  let detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  $detail
}

# Select the application group to deploy from the artifact
def select-deploy-mode [
  modes: record,    # The deploy modes to select
] {
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
    | input list -d option 'Select the application group to deploy'

  $selected
}

# Create deploy order to deploy artifact to Erda cluster
def create-deploy-order [
  artifact: record,               # The artifact to create deploy order
  environment: string = 'DEV',    # The environment to deploy the artifact, such as DEV, TEST, STAGING, PROD, etc.
  --pid: int,                     # The Project ID to deploy the artifact
  --deploy-group(-g): string,     # The app group to deploy for the specified artifact, `all` by default
  --host: string,                 # The Erda host to create deploy order
] {
  let releaseDetailUrl = $'($host)/api/terminus/releases/($artifact.releaseId)'
  let doCreateUrl = $'($host)/api/terminus/deployment-orders'
  let release = http get -e --headers (get-erda-auth $host --type nu) $releaseDetailUrl
  let modes = $release.data.modes
  # Use specified deploy group or select the deploy mode
  let selected = if $deploy_group in ($modes | columns) { { mode: $deploy_group } } else {
      print $'There is no matched deploy group: (ansi r)($deploy_group)(ansi reset), Please select the group manually.'
      select-deploy-mode $modes
    }

  if ($selected | is-empty) { print "You didn't select anything, deploy cancelled, bye..."; exit $ECODE.INVALID_PARAMETER }
  print $'You are going to deploy the group: (ansi g)($selected.mode)(ansi reset).'
  print $'The following applications will be deployed:(char nl)'
  $modes | get $selected.mode | get applicationReleaseList | flatten
    | select applicationName createdAt releaseName version | print

  let doPayload = {
    projectId: $pid,
    modes: [$selected.mode],
    workspace: $environment,
    releaseId: $artifact.releaseId,
  }
  let do = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $doCreateUrl $doPayload
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
  --host: string,     # The Erda host to query the artifact meta info
] {
  let detail = fetch-cicd-detail $cicdid --host $host
  $detail.data.pipelineStages
    | flatten
    | get pipelineTasks
    | where name == $taskName
    | get result?.metadata?
    | flatten
    | select name value
}

# Query releases by project ID
def query-release-candidates [
  pid: int,           # Project id to query the release artifact
  --name: string,     # Display name of the project
  --host: string,     # The Erda host to query the release
] {
  let queryUrl = $'($host)/api/terminus/releases'
  let payload = {
    pageNo: '1',
    pageSize: '200',
    isStable: 'true',
    projectId: $'($pid)',
    isProjectRelease: 'true'
  }
  let queryUrl = $'($queryUrl)?($payload | url build-query)'
  mut filtered = curl --silent -H (get-erda-auth $host) $queryUrl | from json
  # Check session expired, and renew if needed
  let check = should-retry-req $filtered
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $filtered = (curl --silent -H (get-erda-auth $host) $queryUrl | from json)
  }

  if $filtered.success { $filtered }
}

# Query release by version number and project ID
def query-release-by-version [
  version: string,    # Version number to query
  pid: int,           # Project id to query the release artifact
  --name: string,     # Display name of the project
  --verbose(-v),      # Print more details of the matched artifact
  --host: string,     # The Erda host to query the release
] {
  let queryUrl = $'($host)/api/terminus/releases'
  let payload = {
    pageNo: '1',
    pageSize: '100',
    isStable: 'true',
    version: $version,
    projectId: $'($pid)',
    isProjectRelease: 'true'
  }
  let queryUrl = $'($queryUrl)?($payload | url build-query)'
  mut filtered = curl --silent -H (get-erda-auth $host) $queryUrl | from json
  # Check session expired, and renew if needed
  let check = should-retry-req $filtered
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $filtered = (curl --silent -H (get-erda-auth $host) $queryUrl | from json)
  }

  let matches = if $filtered.success {
    $filtered.data.list
      | select projectName projectId createdAt version releaseId
      | upsert releaseId {|it| $it.releaseId }
  }
  if not $verbose { return $matches }

  if ($matches | is-empty) {
    print $'No release found for version ($version) in project ID ($pid)'
  } else {
    let suffix = if ($name | is-empty) { '' } else { $' in (ansi g)($name)(ansi reset)' }
    print $'Found matched artifact release($suffix):(char nl)'; print $matches
  }
  return $matches
}

# 根据创建制品的 ReleaseId 下载项目制品
def download-artifact-from-release [
  releaseId: string,    # Release ID to download artifact
  version: string,      # Version number of the artifact
  --host: string,       # The Erda host to download the artifact
] {
  let tmp = $'(get-tmp-path)/terp/artifacts'
  if not ($tmp | path exists) { mkdir $tmp }
  # Download artifact
  let downloadUrl = $'($host)/api/terminus/releases/($releaseId)/actions/download'
  let dest = $'($tmp)/($version).zip'
  print $'Downloading artifact of version (ansi g)($version)(ansi reset) and releaseId (ansi g)($releaseId)(ansi reset) ...'
  curl --silent -H (get-erda-auth $host) $downloadUrl -o $dest
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
  --host: string,     # The Erda host to upload the artifact
] {
  let releaseUploadUrl = $'($host)/api/terminus/releases/actions/upload'
  let upload = upload-file $file --host $host
  print $upload
  let payload = {
    orgId: $oid,
    projectID: $pid,
    version: $version,
    userId: $upload.creator,
    diceFileID: $'($upload.fileID)',
  }
  let release = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $'($releaseUploadUrl)' $payload
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
  --host: string,     # The Erda host to upload the file
] {
  let uploadUrl = $'($host)/api/files'
  let upload = curl --silent -H (get-erda-auth $host) -F $'file=@($file)' $uploadUrl | from json
  if $upload.success {
    print $'File (ansi g)($file)(ansi reset) has been uploaded successfully to Erda Cloud'
    return { fileID: $upload.data.uuid, url: $upload.data.url, creator: $upload.data.creator }
  }
  print $'Failed to upload file ($file) to Erda Cloud with error message:'
  print $upload.err.msg
}

alias main = artifacts
