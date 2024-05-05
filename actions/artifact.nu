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
# [√] Support artifact actions: deploy, produce, consume
# [√] Show artifact deploy permission info somewhere
# [√] Support select multiple application groups to deploy
# [√] Support `deploy --combine` which contains produce and consume
# [√] Add `--list` flag to list all available source and destination settings
# [√] Multiple deploy group separated by comma from setting or input support
# [√] Login with username and password from settings
# [√] Pack an app artifact to a project artifact
# [ ] Support private ERDA host
# [ ] If there is only one deploy group, deploy it directly without selection
# [ ] Validate input args and flags
# [√] Update artifact related docs
# Usage:
#   - t art deploy -e TEST -v ${version}    使用指定版本制品部署目标测试环境
#   - t art deploy -e TEST                  选择制品并部署目标测试环境
#   - t art deploy -e TEST -c               构建制品并部署目标测试环境（支持同项目 & 不同项目, 不同项目需要下载制品然后上传）
#   - t art produce                         构建制品并输出制品信息
#   - t art consume -e TEST -v ${version}   下载指定版本的制品并上传到目标项目然后部署指定环境
# Reference
#   - ls -f | get name | to text | fzf --height 50% -e --inline-info --preview 'cat {}'
# Usage:

use pipeline.nu [create-cicd, run-cicd, query-cicd-by-id, fetch-cicd-detail]
use ../utils/common.nu [ECODE, hr-line, ellie, log, get-tmp-path]
use ../utils/erda.nu [VALID_ENV, ERDA_HOST, get-erda-auth, renew-erda-session, should-retry-req]

const DEPLOY_POLLING_INTERVAL = 2sec
const RELEASE_META_PATH = 'terp/artifacts'
const SUPPORTED_ACTIONS = [deploy, produce, consume, pack]
const FZF_KEY_BINDING = '--bind ctrl-b:preview-half-page-up,ctrl-f:preview-half-page-down,ctrl-/:toggle-preview'
const FZF_DEFAULT_OPTS = $'--height 50% --layout=reverse --exact --preview-window=right:65%:~2 ($FZF_KEY_BINDING)'
const FZF_THEME = '--color=bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'

# Build, Download and Upload artifacts, create deploy order then deploy from artifacts
# Detailed User Manual: https://fe-docs.app.terminus.io/termix/termix-nu#erda-artifacts
export def artifacts [
  action?: string,            # Action to perform, such as `deploy`, `produce`, `consume` and `pack`
  --list(-l),                 # List all available source and destination settings
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest (deploy)
  --no-deploy(-n),            # Don't deploy after creating deploy order (deploy/consume)
  --from(-f): string,         # Alias of source config to build or download artifact (produce/consume/deploy/pack)
  --to(-t): string,           # Alias of destination config to upload or deploy artifact (consume/deploy)
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail (deploy)
  --branch(-b): string,       # The branch name to build the artifact (produce)
  --version(-v): string,      # The version number of the artifact to deploy (consume/deploy) or pack
  --dest-env(-e): string,     # The dest env to deploy the artifact, such as DEV,TEST,STAGING,PROD (consume/deploy)
  --deploy-group(-g): string, # The app group to deploy, multiple groups should be separated by comma, `All` by default (consume/deploy)
] {
  cd $env.TERMIX_DIR
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..7 }
  print -n (ellie); print $'        Terminus TERP Artifacts Assistant @ ($sha)'; hr-line

  let checkEnv = {|did|
      if ($'($did)' != '0') { return }
      if ($dest_env | is-empty) {
        print $'(ansi r)Please specify the dest environment to deploy the artifact by --dest-env/-e, such as DEV,TEST,STAGING,PROD, etc.(ansi reset)'
        exit $ECODE.INVALID_PARAMETER
      }
    }

  let checkVersion = {
      if ($version | is-empty) {
        print $'(ansi r)Please specify the version of the artifact to process by --version/-v...(ansi reset)'
        exit $ECODE.INVALID_PARAMETER
      }
    }

  let conf = load-art-conf
  if $list { show-settings $conf }

  match $action {
    pack => { do $checkVersion; pack-artifact $version --from $from --need-confirm }
    produce => { produce-artifact --from=$from --branch=$branch --need-confirm }
    consume => { do $checkEnv 0; do $checkVersion; consume-artifact $version $dest_env -f $from -t $to -c --deploy-group=$deploy_group --no-deploy=$no_deploy }
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

# Display the artifact settings
def show-settings [
  conf: record,    # The artifact settings to display
] {
  print $'Global artifact settings:(char nl)'
  $conf.settings | select -i orgId orgAlias erdaHost | transpose | transpose --header-row | print
  print $'(char nl)Available source settings:(char nl)'
  mut sourceTable = []
  let sources = $conf.source | columns
  for s in $sources {
    $sourceTable = ($sourceTable | append { alias: $s, ...($conf.source | get $s) })
  }
  $sourceTable
    | upsert project {|it| $'($it.projectId) @ ($it.projectName)' }
    | select -i alias project appName env branch default | print

  print $'Available destination settings:(char nl)'
  mut destTable = []
  let dests = $conf.destination | columns
  for d in $dests {
    $destTable = ($destTable | append { alias: $d, ...($conf.destination | get $d) })
  }
  $destTable
    | upsert project {|it| $'($it.projectId) @ ($it.projectName)' }
    | select -i alias project erdaHost deployGroup default | print
  exit $ECODE.SUCCESS
}

# Load the ERDA credentials from the settings and store them to environment variable
def --env load-erda-credentials [setting: record] {
  if ([username, password] | all {|it| $it in $setting }) {
    load-env { ERDA_USERNAME: $setting.username, ERDA_PASSWORD: $setting.password }
  }
}

# Preview the selected fzf item detail info
export def fzf-preview [
  selected: string,     # The selected item to preview
  type: string,         # The type of the selected item, such as `artifact`, `group`, etc.
  --options: string,    # The extra options to preview the selected item
] {
  match $type {
    artifact => { preview-artifact $selected }
    group => { preview-group $selected --options $options }
    _ => { print $'Unsupported preview type: (ansi r)($type)(ansi reset)' }
  }
}

# Query and show deploy group details in the fzf preview window
def preview-group [
  mode: string,         # The selected deploy mode or group to preview
  --options: string,    # The extra options to preview the selected item, each option is separated by `+++`
] {
  print $'You are going to deploy the application group: (ansi g)($mode)(ansi reset).'; hr-line
  let previewOptions = $options | split column '+++' | rename projectId releaseID workspace orgAlias host | into record
  let host = $previewOptions.host
  let query = $previewOptions | reject host | merge { mode: $mode } | url build-query
  let queryUrl = $'($host)/api/($previewOptions.orgAlias)/deployment-orders/actions/render-detail?($query)'
  let detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  $env.config.table.mode = 'psql'
  $detail.data.applicationsInfo | flatten | select name preCheckResult
    | upsert checking {|it| if $it.preCheckResult.success { '✓' } else { $'✗ ($it.preCheckResult.failReasons | str join ";")' } }
    | select name checking | sort-by -r checking | print
}

# Preview the selected artifact detail info
def preview-artifact [
  version: string,      # The version of the selected artifact
] {
  let metaPath = $'(get-tmp-path)/($RELEASE_META_PATH)/releases.json'
  const SELECT_COLUMN = [version projectName userId createdAt releaseId modes]
  $env.config.table.mode = 'psql'
  let releases = open $metaPath
  let selected = $releases.0.data.list | where version == $version | get 0
  mut meta = $selected | select ...$SELECT_COLUMN
  $meta.modes = (($meta.modes | from json | columns) | str join ', ')
  $meta.createdBy = ($releases.userInfo | get -i $meta.userId).nick?.0?
  print $'Version: ($version) by ($meta.createdBy)'; hr-line
  $meta | select ...($SELECT_COLUMN | update 2 createdBy) | print; hr-line
  print $selected.changelog
}

# Load meta data settings and store them to environment variable
def --env load-art-conf [] {
  let artConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get artifact
  # TODO: Validate the artifact settings
  let checkUniqDefault = {|type|
    if ($artConf | get $type | values | default false default | where default == true | length) > 1 {
      print $'(ansi r)Multiple default ($type) found, make sure that you have at most one default ($type) in .termixrc.(ansi reset)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  do $checkUniqDefault source
  do $checkUniqDefault destination
  $env.ART_CONF = $artConf
  $artConf
}

# Pack an app artifact to project artifact
def pack-artifact [
  version: string,        # The version of the app artifact
  --from(-f): string,     # Source config to pack the app artifact into a project artifact
  --need-confirm(-c),     # Need to confirm the pack action before execute
] {
  let setting = validate-pack-setting $version --from $from
  if $need_confirm { confirm-pack $version $setting }
  let matches = query-release-by-version $version $setting --is-app
  if ($matches | is-empty) {
    print $'No artifact found with version (ansi g)($version)(ansi reset) in project ID ($setting.projectId), please check it and try again...'
    return
  }
  print $'Found the following (ansi g)APP(ansi reset) artifact to pack:'; hr-line
  $matches | print

  let projectArtifactVer = get-project-artifact-version $version
  let destMatches = query-release-by-version $projectArtifactVer $setting
  if ($destMatches | is-empty) {
    create-project-artifact $projectArtifactVer $matches.0 $setting; return
  } else {
    print $'Artifact of version (ansi g)($projectArtifactVer)(ansi reset) already exists in dest project ID (ansi g)($setting.projectId)(ansi reset):(char nl)'
    print $destMatches
  }
}

# Calc the project artifact version from app artifact version
def get-project-artifact-version [version: string] {
  if ($version | str length) <= 30 { return $version }
  $version
    | str replace develop dev       # Dors
    | str replace release rls       # Dors
    | str replace master ma         # Dors
    | str replace Portal Ptl        # Portal FE
    | str replace SNAPSHOT SNAP     # Trantor
    | str replace Console-fe CFE    # Console
    | str replace -r '2.5.\d\d.' v  # Trantor Version
    | str substring 0..30
}

# Validate the artifact pack action settings and return the validated settings
def validate-pack-setting [
  version: string,        # The version of the app artifact
  --from(-f): string,     # Source config to pack the app artifact into a project artifact
] {
  let artConf = $env.ART_CONF
  let setting = if ($from | is-empty) {
    $artConf.source | values | default false default | where default == true
  } else {
    [($artConf.source | get -i $from)]
  }

  if ($setting | compact | is-empty) {
    print $'(ansi r)No source config found to pack the app artifact, bye...(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  ($setting | upsert appArtifactVersion $version)
}

# Confirm the artifact pack action settings before execute
def confirm-pack [
  version: string,    # The version of the app artifact
  setting: record,    # Source setting to produce the artifact
] {
  print $'You are going to pack the APP artifact into a PROJECT artifact with the following config:'
  const SELECT_FIELDS = [projectId projectName default orgId orgAlias erdaHost]
  let option = ($setting | select -i ...$SELECT_FIELDS)
  hr-line 60 -c grey66; print $option; hr-line 60 -c grey66
  print $'Are you sure to continue? '
  let confirm = input $'Please input (ansi p)($version)(ansi reset) to continue and (ansi p)q(ansi reset) to quit: '
  if $confirm == 'q' { print $'Artifact packing cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($version)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
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
  if $confirm == 'q' { print $'Artifacts creating cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $setting.branch {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($setting.branch)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Confirm the artifact consume action settings before execute
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
  if $confirm == 'q' { print $'Operation cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($version)(ansi reset), bye...'
    exit $ECODE.INVALID_PARAMETER
  }
}

# Confirm the artifact deploy action settings before execute
def confirm-deploy [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  destSetting: record,        # Destination setting to consume the artifact
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail
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
  if $confirm == 'q' { print $'Operation cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    print $'You input (ansi p)($confirm)(ansi reset) does not match (ansi p)($version)(ansi reset), bye...'
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
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  if ($branch | is-empty) { $setting } else { $setting | upsert branch $branch }
}

# Consume the artifacts: download, upload and deploy the artifacts to the dest environment
def consume-artifact [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --need-confirm(-c),         # Need to confirm the consume action before execute
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  let destEnv = $destEnv | str upcase
  let srcSetting = validate-produce-setting --from $from
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy
  if $need_confirm { confirm-consume $version $destEnv $destSetting --no-deploy=$no_deploy }
  let srcPID = $srcSetting.projectId
  let destPID = $destSetting.projectId
  let matches = query-release-by-version $version $srcSetting --verbose
  if ($matches | is-empty) {
    print $'No artifact found for version ($version) in project ID ($srcPID)'
    return
  }
  let dest = download-artifact-from-release $matches.releaseId.0 $version $srcSetting
  let destMatches = query-release-by-version $version $destSetting
  if ($destMatches | is-empty) {
    upload-artifact $version $dest $destSetting
  } else {
    print $'Artifact of version (ansi g)($version)(ansi reset) already exists in dest project ID (ansi g)($destPID)(ansi reset):(char nl)'
    print $destMatches
  }
  let selectedRelease = query-release-by-version $version $destSetting
  let deployGroup = $destSetting.deployGroup | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --deploy-group=$deployGroup --dest-setting $destSetting
  if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid $destSetting }
}

# Validate the artifact consume action settings and return the validated settings
def validate-consume-setting [
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --deploy,                   # Perform a deploy action rather than consume action
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --to(-t): string,           # Destination config to upload or deploy artifact
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail
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
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  if ($deploy_group | is-empty) { $setting } else { $setting | upsert deployGroup $deploy_group }
}

# Deploy the specified artifact to dest env, or build, download, upload, and deploy the artifact in combine mode
def deploy-artifact [
  --dest-env: string,         # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail
  --branch(-b): string,       # The branch name to build the artifact
  --version(-v): string,      # The version number of the artifact to deploy
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  let destEnv = $dest_env | default '' | str upcase
  if ($destEnv | is-not-empty) { print $'Deploy artifact to (ansi g)($destEnv)(ansi reset)'; hr-line }
  let srcSetting = validate-produce-setting --from $from
  mut version = $version
  if $combine {
    let meta = produce-artifact --from=$from --branch=$branch --need-confirm
    $version = ($meta | where Name == 'version' | get Value?.0?)
  }
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy --deploy --doid $doid
  if (not ($doid | is-empty)) and (not $no_deploy) {
    print $'You are going to deploy the artifact with deploy order ID: (ansi g)($doid)(ansi reset)'
    polling-artifact-deploy $doid $destSetting
    return
  }
  let version = if ($version | is-empty) { select-artifact-by-fzf $destSetting } else { $version }
  if ($version | is-empty) {
    print $'(ansi grey66)No artifact version selected, deploy cancelled, bye...(ansi reset)'
    exit $ECODE.SUCCESS
  }
  if $combine {
    consume-artifact $version $destEnv --from $from --to $to --deploy-group=$deploy_group --no-deploy=$no_deploy
    return
  }
  confirm-deploy $version $destEnv $destSetting --doid $doid --no-deploy=$no_deploy
  let selectedRelease = query-release-by-version $version $destSetting
  let deployGroup = $destSetting.deployGroup? | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --deploy-group=$deployGroup --dest-setting $destSetting
  if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid $destSetting }
}

# Select a artifact version to deploy from the release list
def select-artifact-by-fzf [
  destSetting: record,    # The destination setting to search and deploy the artifact
] {
  # ~/.termix-nu/terp/artifacts/releases.json
  let tmp = $'(get-tmp-path)/($RELEASE_META_PATH)'
  if not ($tmp | path exists) { mkdir $tmp }
  let releaseMetaPath = $'($tmp)/releases.json'
  let releases = query-release-candidates $destSetting
  $releases | tee { save -f $releaseMetaPath } | get data.list | length | ignore
  let title = $'Select the artifact to deploy:'
  let PREVIEW_CMD = $"nu actions/artifact.nu {} artifact"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let version = $releases.data.list | select version createdAt | sort-by -r createdAt | get version | str join (char nl) | fzf
  $version
}

# Create artifact from running the specified pipeline
def create-artifact-from-pipeline [
  setting: record,    # The source setting to create artifacts
] {
  let appId = $setting.appId
  let pid = $setting.projectId
  let host = $setting.erdaHost
  let cicdid = create-cicd $appId $setting.appName $setting.branch $setting.pipeline --host $host
  run-cicd $cicdid $appId $pid --host $host
  query-cicd-by-id $cicdid --watch --host $host
  mut meta = get-artifact-meta $cicdid $setting.artifactNode --host $host
  let releaseId = $meta | where Name == 'releaseID' | get Value?.0?
  let detailUrl = $'($host)/($setting.orgAlias)/dop/projects/($pid)/release/application/($releaseId)'
  $meta = ($meta | append { Name: 'detailUrl', Value: $detailUrl })
  $meta
}

# Polling and display artifacts deploy status
def polling-artifact-deploy [
  doid: string,           # Deploy order ID to poll and display the deploy status
  destSetting: record,    # The destination setting to query artifact deploy detail
] {
  let host = $destSetting.erdaHost
  let deployUrl = $'($host)/api/($destSetting.orgAlias)/deployment-orders/($doid)/actions/deploy'
  load-erda-credentials $destSetting
  let deploy = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $deployUrl {}
  if not ($deploy.success) {
    print $'Deployment started failed with error: (ansi r)($deploy.err.msg)(ansi reset)'
    return
  }
  print 'Deployment has been started successfully!'

  let groups = get-artifact-deploy-detail $doid $destSetting | get data.applicationsInfo
  let total = $groups | length
  const FINISH_STATUS = [OK, FAILED, CANCELED]
  const UNFINISHED_STATUS = [DEPLOYING, WAITDEPLOY]
  print $'(char nl)Artifact deploy Detail:'; hr-line

  # pipelineTasks status: Created,Analyzed,Success,Queue,Running,Failed,StopByUser,NoNeedBySystem
  for g in $groups -n {
    let groupStatus = $g.item | get status
    let apps = $g.item | get name | str join ', '
    let groupSuccess = $groupStatus | all {|it| $it == 'OK' }
    let groupFailed = $groupStatus | any {|it| $it == 'FAILED' }
    let groupCancelled = $groupStatus | any {|it| $it == 'CANCELED' }
    let groupUnfinished = $groupStatus | any {|it| $it in $UNFINISHED_STATUS }
    let indicator = if $groupSuccess {
        $'(ansi g)✓(ansi reset)  Deploy (ansi g)($apps)(ansi reset) Finished Successfully!'
      } else if $groupFailed {
        $'(ansi y)⚠(ansi reset)  Deploy (ansi y)($apps)(ansi reset) Failed!'
      } else if $groupCancelled {
        $'(ansi y)👻(ansi reset) Deploy (ansi y)($apps)(ansi reset) Was cancelled!'
      } else if $groupUnfinished {
        $'(ansi pb)🪄(ansi reset) Artifact group (ansi g)[($apps)](ansi reset) is being deployed ...'
      } else {
        $'(ansi r)✗(ansi reset) Unknown Status: ($groupStatus | str join ",")'
      }

    print $'Group ($g.index + 1)/($total): ($indicator)'
    mut counter = 0
    mut keepPolling = true
    while $keepPolling {
      print -n '*'  # * 💤 👣 ✨ 🍵 ⚡ 🎉 🔹 🔸
      $counter += 1
      if ($counter == 90) { $counter = 0; print -n (char nl) }
      let detail = get-artifact-deploy-detail $doid $destSetting
      let apps = $detail.data.applicationsInfo
      # DEPLOYING,OK,FAILED
      let status = $apps | get $g.index | get status
      if ($status | any {|it| $it in $UNFINISHED_STATUS }) {
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
    let detail = get-artifact-deploy-detail $doid $destSetting
    if $detail.data.status in $FINISH_STATUS { break }
  }

  # Refresh the query result and print the final time cost
  let detail = get-artifact-deploy-detail $doid $destSetting
  let duration = ($detail.data.updatedAt | into datetime) - ($detail.data.startedAt | into datetime)
  print $'(char nl)Artifacts deploy finished with status: (ansi p)($detail.data.status)(ansi reset)! Total time cost: ($duration)'
}

# Get artifact deploy detail by deploy order ID
def get-artifact-deploy-detail [
  doid: string            # Deploy order ID to query the deploy detail
  destSetting: record,    # The destination setting to query artifact deploy detail
] {
  let host = $destSetting.erdaHost
  let queryUrl = $'($host)/api/($destSetting.orgAlias)/deployment-orders/($doid)'
  load-erda-credentials $destSetting
  mut detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  # Check session expired, and renew if needed
  let check = should-retry-req $detail
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $detail = (http get -e --headers (get-erda-auth $host --type nu) $queryUrl)
  }
  $detail
}

# Select the application group to deploy from the artifact
def select-deploy-mode-by-fzf [
  modes: record,            # The deploy modes to select
  previewOptions: record,   # The preview options to query and render the preview detail panel
] {
  print $'(ansi g)Tip: Use `Tab` and `Shift + Tab` to toggle select items, and `Enter` to confirm(ansi reset)'
  let title = $'Select the application group to deploy:'
  let options = $previewOptions | get -i projectId releaseID workspace orgAlias host | str join '+++'
  let PREVIEW_CMD = $"nu actions/artifact.nu {} group --options ($options)"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --multi --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let selected = $modes | columns | str join (char nl) | fzf
  $selected | lines
}

# Create deploy order to deploy artifact to Erda cluster
def create-deploy-order [
  artifact: record,               # The artifact to create deploy order
  environment: string = 'DEV',    # The environment to deploy the artifact, such as DEV, TEST, STAGING, PROD, etc.
  --deploy-group(-g): string,     # The app group to deploy for the specified artifact, `all` by default
  --dest-setting: record,         # The destination setting to deploy the artifact
] {
  let host = $dest_setting.erdaHost
  let pid = $dest_setting.projectId
  let orgAlias = $dest_setting.orgAlias
  let doCreateUrl = $'($host)/api/($orgAlias)/deployment-orders'
  let releaseDetailUrl = $'($host)/api/($orgAlias)/releases/($artifact.releaseId)'
  load-erda-credentials $dest_setting
  let release = http get -e --headers (get-erda-auth $host --type nu) $releaseDetailUrl
  let modes = $release.data.modes
  let previewOptions = {
    projectId: $pid, releaseID: $artifact.releaseId, workspace: $environment, orgAlias: $orgAlias, host: $host
  }
  let deployGroup = $deploy_group | default 'All' | split row ','
  let inexistGroup = $deployGroup | filter {|it| $it not-in ($modes | columns) }
  # Use specified deploy group or select the deploy mode
  mut selectedMode = if ($inexistGroup | is-empty) { $deployGroup } else {
      print $'You are trying to deploy APP group ($deployGroup), however, (ansi r)($inexistGroup)(ansi reset) do NOT exist, Please select the group manually.(char nl)'
      select-deploy-mode-by-fzf $modes $previewOptions
    }

  if ($selectedMode | is-empty) {
    print $"(ansi grey66)You didn't select anything, deploy cancelled, bye...(ansi reset)"; exit $ECODE.SUCCESS
  }
  if ($selectedMode | length) > 1 and ('All' in $selectedMode) {
    print $'You have selected (ansi g)`All`(ansi reset) group with other groups, and (ansi r)`All` will be ignored!(ansi reset)'
    $selectedMode = ($selectedMode | filter {|it| $it != 'All' })
  }
  print $'You are going to deploy the APP group: (ansi g)($selectedMode)(ansi reset).'
  print $'The following applications will be deployed:(char nl)'
  mut apps = []
  let columns = [applicationName createdAt releaseName version]
  for g in $selectedMode {
    let applications = ($modes | get $g | get applicationReleaseList | flatten | select ...$columns)
    $apps = ($apps | append $applications)
  }
  $apps | flatten | sort-by applicationName | print

  let doPayload = {
    projectId: $pid,
    modes: $selectedMode,
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
    | rename Name Value
}

# Query releases by project ID
def query-release-candidates [
  destSetting: record,    # The destination setting to query the release candidates
] {
  let host = $destSetting.erdaHost
  let queryUrl = $'($host)/api/($destSetting.orgAlias)/releases'
  let payload = {
    pageNo: '1',
    pageSize: '200',
    isStable: 'true',
    projectId: $'($destSetting.projectId)',
    isProjectRelease: 'true'
  }
  let queryUrl = $'($queryUrl)?($payload | url build-query)'
  load-erda-credentials $destSetting
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
  setting: record,    # The setting to query release
  --is-app,           # Query the release of the application, not the project
  --verbose(-v),      # Print more details of the matched artifact
] {
  let host = $setting.erdaHost
  let queryUrl = $'($host)/api/($setting.orgAlias)/releases'
  let isProjectRelease = if $is_app { 'false' } else { 'true' }
  let payload = {
    pageNo: '1',
    pageSize: '100',
    isStable: 'true',
    version: $version,
    projectId: $'($setting.projectId)',
    isProjectRelease: $isProjectRelease
  }
  let queryUrl = $'($queryUrl)?($payload | url build-query)'
  load-erda-credentials $setting
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
      | where version == $version
  }
  if not $verbose { return $matches }

  if ($matches | is-empty) {
    print $'No release found for version (ansi g)($version)(ansi reset) in project ID ($setting.projectId)'
  } else {
    let suffix = if ($setting.projectName | is-empty) { '' } else { $' in (ansi g)($setting.projectName)(ansi reset)' }
    print $'Found matched artifact release($suffix):(char nl)'; print $matches
  }
  return $matches
}

# 根据创建制品的 ReleaseId 下载项目制品
def download-artifact-from-release [
  releaseId: string,    # Release ID to download artifact
  version: string,      # Version number of the artifact
  srcSetting: record,   # The source setting to download artifact
] {
  let host = $srcSetting.erdaHost
  let tmp = $'(get-tmp-path)/($RELEASE_META_PATH)'
  if not ($tmp | path exists) { mkdir $tmp }
  # Download artifact
  let downloadUrl = $'($host)/api/($srcSetting.orgAlias)/releases/($releaseId)/actions/download'
  let dest = $'($tmp)/($version).zip'
  load-erda-credentials $srcSetting
  print $'Downloading artifact of version (ansi g)($version)(ansi reset) and releaseId (ansi g)($releaseId)(ansi reset) ...'
  curl --silent -H (get-erda-auth $host) $downloadUrl -o $dest
  print $'Artifact has been downloaded to ($dest)(char nl)'
  $dest
}

# https://erda.cloud/api/terminus/releases/actions/check-version?isProjectRelease=true&orgID=2&projectID=1158&version=2.5.24.0130%2B20240223134546
# 上传制品到 Erda 项目
def upload-artifact [
  version: string,      # Version number of the artifact
  file: string,         # File path of the artifact to upload
  destSetting: record   # The destination setting to upload artifact
] {
  let host = $destSetting.erdaHost
  let upload = upload-file $file $destSetting
  let releaseUploadUrl = $'($host)/api/($destSetting.orgAlias)/releases/actions/upload'
  print $upload
  let payload = {
    version: $version,
    userId: $upload.creator,
    orgId: $destSetting.orgId,
    diceFileID: $'($upload.fileID)',
    projectID: $destSetting.projectId,
  }
  load-erda-credentials $destSetting
  let release = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $'($releaseUploadUrl)' $payload
  if $release.success {
    print $'Artifact has been uploaded successfully with version (ansi g)($version)(ansi reset)'
  } else {
    print $'Failed to upload artifact of version ($version) with error message:'
    print $'(ansi r)($release.err.msg)(ansi reset)'
  }
}

# Create project artifact from app artifact
def create-project-artifact [
  version: string,      # Version number of the artifact
  release: record,      # The app release to create project artifact
  destSetting: record   # The destination setting to upload artifact
] {
  let host = $destSetting.erdaHost
  let artifactCreatUrl = $'($host)/api/($destSetting.orgAlias)/releases'
  let userId = renew-erda-session $host --get-uid
  let payload = {
    isStable: true,
    isFormal: false,
    userId: $userId,
    version: $version,
    isProjectRelease: true,
    orgId: $destSetting.orgId,
    projectID: $destSetting.projectId,
    changelog: $destSetting.appArtifactVersion?,
    modes: { default: { expose: true, applicationReleaseList: [[$release.releaseId]] } }
  }

  let resp = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $'($artifactCreatUrl)' $payload
  if $resp.success {
    print $'Project artifact has been created successfully with version (ansi g)($version)(ansi reset)'; hr-line
    query-release-by-version $version $destSetting | print
    return $resp.data.releaseId
  }
  print $'Failed to create project artifact of version ($version) with error message:'
  print $'(ansi r)($resp.err.msg)(ansi reset)'
  exit $ECODE.SERVER_ERROR
}

# Upload file from local disk to Erda Cloud
def upload-file [
  file: string,         # File path to upload
  destSetting: record,  # The destination setting to upload artifact
] {
  let host = $destSetting.erdaHost
  let uploadUrl = $'($host)/api/files'
  load-erda-credentials $destSetting
  let upload = curl --silent -H (get-erda-auth $host) -F $'file=@($file)' $uploadUrl | from json
  if $upload.success {
    print $'File (ansi g)($file)(ansi reset) has been uploaded successfully to Erda Cloud'
    return { fileID: $upload.data.uuid, url: $upload.data.url, creator: $upload.data.creator }
  }
  print $'Failed to upload file ($file) to Erda Cloud with error message:'
  print $upload.err.msg
}

alias main = fzf-preview
