#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/12/29 22:06:52
# Description: A tool for deploying artifacts
# [√] Build: Run pipeline to create artifacts
# [√] Download: Download artifacts by release ID
# [√] Download: Download artifacts by unique version number
# [√] Upload: Upload artifacts from local disk to Erda project
# [√] Create: Create a deployment order for artifacts on the Erda platform
# [√] Execute: Execute the Erda pipeline to deploy artifacts to the Erda platform
# [√] Query and display deployment status
# [√] Add artifact deployment config file
# [√] Display and confirm produce action details before execution
# [√] Deploy all apps by default, or let the user choose a group if no match is found
# [√] Display and confirm consume action details before execution
# [√] Install fzf if it is not available for artifact version selection
# [√] Use fzf to select the artifact version to deploy
# [√] Deploy artifacts by deployment order ID
# [√] Confirm deployment order details before execution
# [√] Support artifact actions: deploy, produce, consume
# [√] Show artifact deployment permission info somewhere
# [√] Support selecting multiple application groups for deployment
# [√] Support `deploy --combine`, which includes produce and consume
# [√] Add `--list` flag to list all available source and destination settings
# [√] Support multiple deployment groups separated by commas in settings or input
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
use ../utils/common.nu [ECODE, FZF_DEFAULT_OPTS, FZF_THEME, hr-line, ellie, log, get-tmp-path]
use ../utils/erda.nu [VALID_ENV, ERDA_HOST, get-erda-auth, renew-erda-session, should-retry-req]

const DEPLOY_POLLING_INTERVAL = 2sec
const RELEASE_META_PATH = 'terp/artifacts'
const AGENT_HELPERS = [list-sources list-destinations list-releases list-deploy-groups show-release show-deploy-order]
const SUPPORTED_ACTIONS = [deploy produce consume pack ...$AGENT_HELPERS]
const SUPPORTED_OUTPUTS = [text json]
const PREVIEW_TYPES = [artifact release group]

def is-non-interactive [] {
  $env.ART_NON_INTERACTIVE? | default false
}

def is-json-output [] {
  ($env.ART_OUTPUT_FORMAT? | default text) == json
}

def current-action [] {
  $env.ART_CURRENT_ACTION? | default artifact
}

def is-dry-run [] {
  $env.ART_DRY_RUN? | default false
}

def env-flag-enabled [name: string] {
  let value = $env | get -o $name
  if ($value | is-empty) { return false }
  let kind = $value | describe
  if $kind == bool { return $value }
  let normalized = ($value | into string | str downcase | str trim)
  $normalized in ['1' 'true' 'yes' 'on']
}

def print-info [value: any] {
  if (is-json-output) { print -e $value } else { print $value }
}

def print-info-n [value: any] {
  if (is-json-output) { print -e -n $value } else { print -n $value }
}

def print-divider [
  width: int = 80,
  --color(-c): string = grey27,
] {
  if not (is-json-output) { hr-line $width -c $color }
}

def print-table [value: any] {
  print-info ($value | table -e)
}

def write-json [payload: record] {
  print ($payload | to json -r)
}

def emit-success [
  action: string,
  data?: any,
  --warnings: list<any> = [],
] {
  let data = normalize-success-data $action ($data | default null)
  let payload = {
    success: true,
    action: $action,
    data: $data,
    warnings: $warnings,
  }
  if (is-json-output) { write-json $payload }
  $payload
}

def normalize-success-data [
  action: string,
  data: any,
] {
  let data_type = $data | describe
  let record_data = if ($data_type | str starts-with 'record') { $data } else { { raw: $data } }
  {
    version: ($record_data.version? | default null),
    releaseId: ($record_data.releaseId? | default null),
    deployOrderId: ($record_data.deployOrderId? | default null),
    detailUrl: ($record_data.detailUrl? | default null),
    projectId: ($record_data.projectId? | default null),
    sourceProjectId: ($record_data.sourceProjectId? | default null),
    destinationProjectId: ($record_data.destinationProjectId? | default null),
    deployGroup: ($record_data.deployGroup? | default null),
    dryRun: (is-dry-run),
    raw: $data,
  }
}

def fail-artifact [
  exit_code: int,
  error_code: string,
  message: string,
  --details: record = {},
] {
  let action = current-action
  if (is-json-output) {
    write-json {
      success: false,
      action: $action,
      error: {
        code: $error_code,
        message: $message,
        details: $details,
      }
    }
  } else {
    print -e $message
  }
  exit $exit_code
}

def cancel-artifact [
  message: string,
  --details: record = {},
] {
  let action = current-action
  if (is-json-output) {
    write-json {
      success: true,
      action: $action,
      cancelled: true,
      message: $message,
      details: $details,
    }
  } else {
    print $message
  }
  exit $ECODE.SUCCESS
}

def ensure-interactive [
  feature: string,
  prompt: string,
  --details: record = {},
] {
  if (is-non-interactive) {
    fail-artifact $ECODE.INVALID_PARAMETER INTERACTION_REQUIRED $'Interactive input is required for ($feature) in the current command.' --details ({
      feature: $feature,
      prompt: $prompt,
      ...$details,
    })
  }
}

def ensure-mutation-approved [action: string] {
  if (is-dry-run) { return }
  if (is-non-interactive) and not ($env.ART_ASSUME_YES? | default false) {
    fail-artifact $ECODE.INVALID_PARAMETER MUTATION_NOT_CONFIRMED $'Action ($action) mutates remote state. Re-run with --yes in non-interactive mode, or use --dry-run first.' --details {
      action: $action,
      required: [yes],
    }
  }
}

def read-fixture [
  env_key: string,
] {
  if not (env-flag-enabled ARTIFACT_ENABLE_FIXTURES) { return null }
  let path = $env | get -o $env_key
  if ($path | is-empty) { return null }
  open $path
}

# Build, download, and upload artifacts, create deployment orders, and deploy artifacts
# Detailed User Manual: https://fe-docs.app.terminus.io/termix/termix-nu#erda-artifacts
@example '在 TUI 界面选择一个 Trantor 制品然后下载、上传并部署该制品到 `terp` 开发环境' {
  t art consume -t terp -e DEV
} --result '会显示候选制品列表，并且可以预览制品信息和 CHANGELOG'
@example '下载、上传并部署指定版本制品到 `terp` 开发环境' {
  t art consume -v R.3.0.2506+20250721162706.810 -t terp -e DEV
} --result '底层基于 Trantor 官方脚本实现'
@example '列出所有可用的源与目标项目配置' {
  t art -l
} --result '显示全局设置、所有源与目标项目配置信息'
@example '使用指定版本制品部署 `terp` 测试环境' {
  t art deploy -v R.3.0.2506+20250721162706.810 -t terp -e TEST
} --result '前提是 `terp` 项目已经存在对应版本的制品'
@example '交互式选择 `terp` 项目制品后部署测试环境（支持预览版本信息与 CHANGELOG）' {
  t art deploy -t terp -e TEST
}
@example '从 Trantor 构建制品并部署到 `terp` 开发环境（联合部署模式）' {
  t art deploy -c -f trantor -b release/3.0.2506 -t terp -e DEV
} --result '包含制品构建、上传到目标项目、创建部署单、部署等步骤'
@example '仅在 `terp` 项目测试环境创建部署单，不执行部署操作' {
  t art deploy -v R.3.0.2506+20250721162706.810 -t terp -e TEST -n
} --result '输出部署单 ID'
@example '通过部署单 ID 执行部署' {
  t art deploy -i 1b39da9d-9a7b-4122-9369-7e51a35eab8f
}
@example '从 Trantor 项目指定分支构建制品并输出制品信息' {
  t art produce -f trantor -b release/3.0.2506
}
@example '将指定版本应用制品打包为项目制品' {
  t art pack -v Portal-3.0.2506-f785ce9+250607.213036 -f trantor
} --result '输出转换后的项目制品信息'
@example '部署指定应用组 `Dors` 和 `IAM` 到 `terp` 开发环境' {
  t art deploy -v R.3.0.2506+20250721162706.810 -t terp -e DEV -g Dors,IAM
}
export def artifacts [
  action?: string,            # Action to perform, such as `deploy`, `produce`, `consume`, or `pack`
  --list(-l),                 # List all available source and destination settings
  --non-interactive,          # Fail instead of prompting for user input or fzf selections
  --yes(-y),                  # Skip confirmation prompts
  --output(-o): string = text,# Output format: `text` or `json`
  --dry-run,                  # Validate and preview the execution plan without mutating remote state
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest (deploy)
  --no-deploy(-n),            # Don't deploy after creating deploy order (deploy/consume)
  --from(-f): string,         # Alias of source config to build or download artifact (produce/consume/deploy/pack)
  --to(-t): string,           # Alias of destination config to upload or deploy artifact (consume/deploy)
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail (deploy)
  --branch(-b): string,       # The branch name to build the artifact (produce)
  --version(-v): string,      # The version number of the artifact to deploy (consume/deploy) or pack
  --dest-env(-e): string,     # The destination environment, such as DEV, TEST, STAGING, or PROD (consume/deploy)
  --deploy-group(-g): string, # The app group to deploy, multiple groups should be separated by comma, `All` by default (consume/deploy)
] {
  cd ($env.TERMIX_DIR? | default (pwd))
  if $output not-in $SUPPORTED_OUTPUTS {
    fail-artifact $ECODE.INVALID_PARAMETER INVALID_OUTPUT $'Unsupported output format: ($output), supported formats are: ($SUPPORTED_OUTPUTS | str join ", ")' --details {
      output: $output,
      supported: $SUPPORTED_OUTPUTS,
    }
  }
  load-env {
    ART_NON_INTERACTIVE: $non_interactive,
    ART_ASSUME_YES: $yes,
    ART_OUTPUT_FORMAT: $output,
    ART_DRY_RUN: $dry_run,
    ART_CURRENT_ACTION: ($action | default ''),
  }
  let currentBranch = git branch --show-current
  let sha = do -i { git rev-parse $currentBranch | str substring 0..<7 }
  if not (is-json-output) {
    print-info-n (ellie)
    print-info $'        Terminus TERP Artifacts Assistant @ ($sha)'
    print-divider
  }

  let checkEnv = {|did|
      if ($'($did)' != '0') { return }
      if ($dest_env | is-empty) {
        fail-artifact $ECODE.INVALID_PARAMETER MISSING_DEST_ENV $'Please specify the destination environment with --dest-env/-e, such as DEV, TEST, STAGING, or PROD.' --details {
          required: [dest-env],
        }
      }
    }

  let checkVersion = {
      if ($version | is-empty) {
        fail-artifact $ECODE.INVALID_PARAMETER MISSING_VERSION $'Please specify the version of the artifact to process by --version/-v.' --details {
          required: [version],
        }
      }
    }

  let conf = load-art-conf
  if $list {
    let data = show-settings $conf
    if (is-json-output) {
      emit-success list $data | ignore
      return
    }
    return
  }

  let result = match $action {
    list-sources => { list-source-settings }
    list-destinations => { list-destination-settings }
    list-releases => { list-release-candidates --to $to }
    list-deploy-groups => { do $checkVersion; list-release-deploy-groups $version --to $to }
    show-release => { do $checkVersion; show-release-detail $version --to $to }
    show-deploy-order => {
      if ($doid | is-empty) {
        fail-artifact $ECODE.INVALID_PARAMETER MISSING_DEPLOY_ORDER_ID 'Please specify the deploy order ID by --doid/-i.' --details {
          required: [doid],
        }
      }
      show-deploy-order-detail $doid --to $to
    }
    pack => {
      do $checkVersion
      if (is-dry-run) { dry-run-pack $version --from $from } else { ensure-mutation-approved pack; pack-artifact $version --from $from --need-confirm }
    }
    produce => {
      if (is-dry-run) { dry-run-produce --from $from --branch $branch } else { ensure-mutation-approved produce; produce-artifact --from=$from --branch=$branch --need-confirm }
    }
    consume => {
      do $checkEnv 0
      if (is-dry-run) {
        dry-run-consume $dest_env -v $version -f $from -t $to --deploy-group=$deploy_group --no-deploy=$no_deploy
      } else {
        ensure-mutation-approved consume
        consume-artifact $dest_env -v $version -f $from -t $to -c --deploy-group=$deploy_group --no-deploy=$no_deploy
      }
    }
    deploy => {
      do $checkEnv $doid
      if (is-dry-run) {
        (dry-run-deploy --dest-env $dest_env --combine=$combine --from $from --branch $branch --doid $doid
          --version $version --to $to --deploy-group $deploy_group --no-deploy=$no_deploy)
      } else {
        ensure-mutation-approved deploy
        (deploy-artifact --dest-env $dest_env --combine=$combine --from $from --branch $branch --doid $doid
                         --version $version --to $to --deploy-group $deploy_group --no-deploy=$no_deploy)
      }
    }
    _ => {
      fail-artifact $ECODE.INVALID_PARAMETER INVALID_ACTION $'Unsupported action: ($action), supported actions are: ($SUPPORTED_ACTIONS | str join ", ")' --details {
        action: $action,
        supported: $SUPPORTED_ACTIONS,
      }
    }
  }
  if (is-json-output) {
    emit-success $action $result | ignore
    return
  }
  $result
}

# Display the artifact settings
def show-settings [
  conf: record,    # The artifact settings to display
] {
  let global = ($conf.settings | select -o orgId orgAlias erdaHost)
  let sourceTable = get-source-settings $conf
  let destTable = get-destination-settings $conf
  let result = {
    settings: $global,
    source: $sourceTable,
    destination: $destTable,
  }
  if not (is-json-output) {
    print-info $'Global artifact settings:(char nl)'
    print-info ($global | transpose | transpose --header-row)
    print-info $'(char nl)Available source settings:(char nl)'
    print-info $sourceTable
    print-info $'(char nl)Available destination settings:(char nl)'
    print-info $destTable
  }
  $result
}

def get-source-settings [conf: record] {
  mut sourceTable = []
  let sources = $conf.source | columns
  for s in $sources {
    $sourceTable ++= [{ alias: $s, ...($conf.source | get $s) }]
  }
  $sourceTable
    | upsert project {|it| $'($it.projectId) @ ($it.projectName)' }
    | select -o alias project appName env branch default
}

def get-destination-settings [conf: record] {
  mut destTable = []
  let dests = $conf.destination | columns
  for d in $dests {
    $destTable ++= [{ alias: $d, ...($conf.destination | get $d) }]
  }
  $destTable
    | upsert project {|it| $'($it.projectId) @ ($it.projectName)' }
    | select -o alias project erdaHost deployGroup default
}

def list-source-settings [] {
  let conf = $env.ART_CONF
  get-source-settings $conf
}

def list-destination-settings [] {
  let conf = $env.ART_CONF
  get-destination-settings $conf
}

def list-release-candidates [
  --to(-t): string,    # Destination config alias
] {
  let setting = get-destination-setting --to $to
  query-release-candidates $setting
    | get data.list
    | select projectName projectId createdAt version releaseId
    | sort-by -r createdAt
}

def show-release-detail [
  version: string,      # Release version to query
  --to(-t): string,     # Destination config alias
] {
  let setting = get-destination-setting --to $to
  let matches = query-release-by-version $version $setting
  if ($matches | is-empty) {
    fail-artifact $ECODE.CONDITION_NOT_SATISFIED ARTIFACT_NOT_FOUND $'No artifact found for version ($version) in project ID ($setting.projectId)' --details {
      version: $version,
      projectId: $setting.projectId,
    }
  }
  let release = ($matches | get 0)
  let detail = get-release-detail $release.releaseId $setting
  {
    version: $release.version,
    releaseId: $release.releaseId,
    projectId: $release.projectId,
    summary: $release,
    detail: $detail.data,
  }
}

def list-release-deploy-groups [
  version: string,      # Release version to query deploy groups
  --to(-t): string,     # Destination config alias
] {
  let release = show-release-detail $version --to $to
  let modes = $release.detail.modes? | default {}
  let modeNames = $modes | columns
  if ($modeNames | is-empty) {
    fail-artifact $ECODE.CONDITION_NOT_SATISFIED EMPTY_DEPLOY_GROUPS $'No deploy groups found for version ($version).' --details {
      version: $version,
    }
  }
  $modeNames | each {|name|
    let applications = $modes | get $name | get applicationReleaseList? | default [] | flatten
    {
      name: $name,
      applicationCount: ($applications | length),
      applications: ($applications | select -o applicationName releaseName version),
    }
  }
}

def show-deploy-order-detail [
  doid: string,         # Deploy order ID
  --to(-t): string,     # Destination config alias
] {
  let setting = get-destination-setting --to $to
  let response = get-artifact-deploy-detail $doid $setting
  let detail = try { $response | get data } catch { null }
  if ($detail | is-empty) {
    fail-artifact $ECODE.SERVER_ERROR INVALID_DEPLOY_ORDER_DETAIL_RESPONSE $'Failed to fetch deploy order detail for deploy order ID ($doid): response payload does not contain a valid `data` field.' --details {
      deployOrderId: $doid,
      projectId: $setting.projectId,
      response: $response,
    }
  }
  {
    deployOrderId: ($detail.id? | default $doid),
    projectId: $setting.projectId,
    detail: $detail,
  }
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
    release => { preview-trantor-release $selected }
    group => { preview-group $selected --options $options }
    _ => { fail-artifact $ECODE.INVALID_PARAMETER INVALID_PREVIEW_TYPE $'Unsupported preview type: ($type)' --details { type: $type, supported: $PREVIEW_TYPES } }
  }
}

# Query and show deploy group details in the fzf preview window
def preview-group [
  mode: string,         # The selected deploy mode or group to preview
  --options: string,    # The extra options to preview the selected item, each option is separated by `+++`
] {
  print-info $'You are about to deploy the application group: (ansi g)($mode)(ansi rst).'
  print-divider
  let previewOptions = $options | split column '+++' | rename projectId releaseID workspace orgAlias host | into record
  let host = $previewOptions.host
  let query = $previewOptions | reject host | merge { mode: $mode } | url build-query
  let queryUrl = $'($host)/api/($previewOptions.orgAlias)/deployment-orders/actions/render-detail?($query)'
  let detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  $env.config.table.mode = 'psql'
  print-info (
    $detail.data.applicationsInfo | flatten | select name preCheckResult
    | upsert checking {|it| if $it.preCheckResult.success { '✓' } else { $'✗ ($it.preCheckResult.failReasons | str join ";")' } }
    | select name checking | sort-by -r checking
  )
}

# Preview the selected artifact detail info
def preview-artifact [
  version: string,      # The version of the selected artifact
] {
  let metaPath = $'(get-tmp-path)/($RELEASE_META_PATH)/releases.json'
  const SELECT_COLUMN = [version projectName userId createdAt releaseId modes]
  $env.config.table.mode = 'psql'
  let releases = open $metaPath
  let selected = $releases.data.list | where version == $version | get 0
  mut meta = $selected | select ...$SELECT_COLUMN
  $meta.modes = (($meta.modes | from json | columns) | str join ', ')
  $meta.createdBy = ($releases.userInfo? | get -o $meta.userId).nick?
  print-info $'Version: ($version) by ($meta.createdBy)'
  print-divider
  print-info ($meta | select ...($SELECT_COLUMN | update 2 createdBy))
  print-divider
  print-info $selected.changelog
}

# Preview the selected Trantor release detail info
def preview-trantor-release [
  version: string,      # The version of the selected release
] {
  let metaPath = $'(get-tmp-path)/($RELEASE_META_PATH)/releases.json'
  let selected = open $metaPath | where metadata?.erda_release_version? == $version | get 0
  print-info $'Erda Release Version: ($version)'
  print-divider
  print-info ($selected | select version uploadedAt filename path)
  print-info $'(char nl)Changelog:'
  print-divider
  print-info ($selected.metadata.changelog? | default 'N/A')
}

# Load meta data settings and store them to environment variable
def --env load-art-conf [] {
  let artConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get artifact
  # TODO: Validate the artifact settings
  let checkUniqDefault = {|type|
    if ($artConf | get $type | values | default false default | where default == true | length) > 1 {
      fail-artifact $ECODE.INVALID_PARAMETER MULTIPLE_DEFAULT_SETTINGS $'Multiple default ($type) found, make sure that you have at most one default ($type) in .termixrc.' --details {
        type: $type,
      }
    }
  }
  do $checkUniqDefault source
  do $checkUniqDefault destination
  $env.ART_CONF = $artConf
  $artConf
}

def get-source-setting [
  --from(-f): string,     # Source config alias
  --branch(-b): string,   # Optional branch override
] {
  let artConf = $env.ART_CONF
  let setting = if ($from | is-empty) {
    $artConf.source | values | default false default | where default == true
  } else {
    [($artConf.source | get -o $from)]
  }

  if ($setting | compact | is-empty) {
    fail-artifact $ECODE.INVALID_PARAMETER SOURCE_CONFIG_NOT_FOUND 'No source config was found to build or download the artifact.' --details {
      from: $from,
    }
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  if ($branch | is-empty) { $setting } else { $setting | upsert branch $branch }
}

def get-destination-setting [
  --to(-t): string,           # Destination config alias
  --deploy-group(-g): string, # Deploy group override
] {
  let artConf = $env.ART_CONF
  let setting = if ($to | is-empty) {
    $artConf.destination | values | default false default | where default == true
  } else {
    [($artConf.destination | get -o $to)]
  }

  if ($setting | compact | is-empty) {
    fail-artifact $ECODE.INVALID_PARAMETER DESTINATION_CONFIG_NOT_FOUND 'No destination config was found for artifact deployment.' --details {
      to: $to,
    }
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  if ($deploy_group | is-empty) { $setting } else { $setting | upsert deployGroup $deploy_group }
}

def dry-run-produce [
  --from(-f): string,
  --branch(-b): string,
] {
  let setting = validate-produce-setting --from $from --branch $branch
  {
    action: 'produce',
    projectId: $setting.projectId,
    detailUrl: null,
    version: null,
    releaseId: null,
    plan: {
      source: ($setting | reject -o username password),
      steps: [validate-config run-pipeline query-artifact-meta],
    }
  }
}

def dry-run-pack [
  version: string,
  --from(-f): string,
] {
  let setting = validate-pack-setting $version --from $from
  {
    action: 'pack',
    version: $version,
    projectId: $setting.projectId,
    detailUrl: null,
    releaseId: null,
    plan: {
      source: ($setting | reject -o username password),
      targetVersion: (get-project-artifact-version $version),
      steps: [validate-config query-app-artifact create-project-artifact],
    }
  }
}

def dry-run-consume [
  destEnv: string,
  --version(-v): string,
  --from(-f): string,
  --to(-t): string,
  --deploy-group(-g): string,
  --no-deploy(-n),
] {
  if (is-non-interactive) and ($version | is-empty) {
    fail-artifact $ECODE.INVALID_PARAMETER INTERACTION_REQUIRED 'Interactive input is required to resolve the artifact version in non-interactive dry-run mode.' --details {
      feature: artifact-selection,
      prompt: 'select upstream artifact version with fzf',
      required: [version],
    }
  }
  let srcSetting = validate-produce-setting --from $from
  let destSetting = validate-consume-setting ($destEnv | str upcase) --to $to --deploy-group $deploy_group --no-deploy=$no_deploy
  {
    action: 'consume',
    version: $version,
    sourceProjectId: $srcSetting.projectId,
    destinationProjectId: $destSetting.projectId,
    deployGroup: (($deploy_group | default $destSetting.deployGroup | default 'All') | split row ','),
    plan: {
      source: ($srcSetting | reject -o username password),
      destination: ($destSetting | reject -o username password),
      environment: ($destEnv | str upcase),
      noDeploy: $no_deploy,
      steps: (if $no_deploy {
          [validate-config resolve-release download-artifact upload-artifact create-deploy-order]
        } else {
          [validate-config resolve-release download-artifact upload-artifact create-deploy-order deploy]
        }),
    }
  }
}

def dry-run-deploy [
  --dest-env: string,
  --combine(-c),
  --no-deploy(-n),
  --from(-f): string,
  --to(-t): string,
  --doid(-i): string,
  --branch(-b): string,
  --version(-v): string,
  --deploy-group(-g): string,
] {
  if ($doid | is-not-empty) {
    let destSetting = validate-consume-setting '' --to $to --deploy-group $deploy_group --deploy --doid $doid --no-deploy=$no_deploy
    return {
      action: 'deploy',
      deployOrderId: $doid,
      destinationProjectId: $destSetting.projectId,
      deployGroup: (($deploy_group | default $destSetting.deployGroup | default 'All') | split row ','),
      plan: {
        destination: ($destSetting | reject -o username password),
        steps: [validate-config deploy-existing-order],
      }
    }
  }

  let destEnv = $dest_env | str upcase
  if (is-non-interactive) and (not $combine) and ($version | is-empty) {
    fail-artifact $ECODE.INVALID_PARAMETER INTERACTION_REQUIRED 'Interactive input is required to resolve the artifact version in non-interactive dry-run mode.' --details {
      feature: artifact-selection,
      prompt: 'select artifact version with fzf',
      required: [version],
    }
  }
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --deploy --doid $doid --no-deploy=$no_deploy
  let srcSetting = if $combine { validate-produce-setting --from $from --branch $branch } else { null }
  let srcProjectId = if (($srcSetting | describe) == 'record') { $srcSetting.projectId? | default null } else { null }
  {
    action: 'deploy',
    version: $version,
    sourceProjectId: $srcProjectId,
    destinationProjectId: $destSetting.projectId,
    deployGroup: (($deploy_group | default $destSetting.deployGroup | default 'All') | split row ','),
    plan: {
      combine: $combine,
      environment: $destEnv,
      source: ($srcSetting | default {} | reject -o username password),
      destination: ($destSetting | reject -o username password),
      noDeploy: $no_deploy,
      steps: (if $combine {
          if $no_deploy {
            [validate-config produce-artifact download-upload-artifact create-deploy-order]
          } else {
            [validate-config produce-artifact download-upload-artifact create-deploy-order deploy]
          }
        } else if $no_deploy {
          [validate-config resolve-release create-deploy-order]
        } else {
          [validate-config resolve-release create-deploy-order deploy]
        }),
    }
  }
}

# Pack an app artifact into a project artifact
def pack-artifact [
  version: string,        # The version of the app artifact
  --from(-f): string,     # Source config to pack the app artifact into a project artifact
  --need-confirm(-c),     # Require confirmation before executing the pack action
] {
  let setting = validate-pack-setting $version --from $from
  if $need_confirm { confirm-pack $version $setting }
  let matches = query-release-by-version $version $setting --is-app
  if ($matches | is-empty) {
    fail-artifact $ECODE.CONDITION_NOT_SATISFIED ARTIFACT_NOT_FOUND $'No artifact found with version ($version) in project ID ($setting.projectId), please check it and try again.' --details {
      version: $version,
      projectId: $setting.projectId,
      isApp: true,
    }
  }
  print-info $'Found the following (ansi g)APP(ansi rst) artifact to pack:'
  print-divider
  print-info $matches

  let projectArtifactVer = get-project-artifact-version $version
  let destMatches = query-release-by-version $projectArtifactVer $setting
  if ($destMatches | is-empty) {
    let created = create-project-artifact $projectArtifactVer $matches.0 $setting
    return {
      sourceVersion: $version,
      projectArtifactVersion: $projectArtifactVer,
      created: true,
      release: ($created | get 0),
    }
  } else {
    print-info $'Artifact of version (ansi g)($projectArtifactVer)(ansi rst) already exists in dest project ID (ansi g)($setting.projectId)(ansi rst):(char nl)'
    print-info $destMatches
    {
      sourceVersion: $version,
      projectArtifactVersion: $projectArtifactVer,
      created: false,
      release: ($destMatches | get 0),
    }
  }
}

# Calc the project artifact version from app artifact version
def get-project-artifact-version [version: string] {
  # App artifact version and project artifact version should be different
  if ($version | str length) <= 28 { return $'($version).p' }
  let pVer = $version
    | str replace develop dev       # Dors
    | str replace release rls       # Dors
    | str replace master ma         # Dors
    | str replace Portal Ptl        # Portal FE
    | str replace SNAPSHOT SNAP     # Trantor
    | str replace Console-fe CFE    # Console
    | str replace -r '2.5.\d\d.' v  # Trantor Version
    | str substring 0..<30
  if $pVer != $version { return $pVer }
  $pVer | str substring 0..<28 | append '.p' | str join
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
    [($artConf.source | get -o $from)]
  }

  if ($setting | compact | is-empty) {
    fail-artifact $ECODE.INVALID_PARAMETER SOURCE_CONFIG_NOT_FOUND 'No source config was found for packing the app artifact.' --details {
      from: $from,
    }
  }
  mut setting = ($artConf.settings | merge $setting.0 | default $ERDA_HOST erdaHost)
  # TODO: setting fields validation
  ($setting | upsert appArtifactVersion $version)
}

# Confirm artifact pack settings before execution
def confirm-pack [
  version: string,    # The version of the app artifact
  setting: record,    # Source setting to produce the artifact
] {
  if ($env.ART_ASSUME_YES? | default false) { return }
  ensure-interactive confirmation 'confirm artifact packing' --details { expected: $version }
  print-info $'You are about to pack the APP artifact into a PROJECT artifact with the following config:'
  const SELECT_FIELDS = [projectId projectName default orgId orgAlias erdaHost]
  let option = ($setting | select -o ...$SELECT_FIELDS)
  print-divider 60 -c grey66
  print-info $option
  print-divider 60 -c grey66
  print-info 'Are you sure to continue? '
  let confirm = input $'Please enter (ansi p)($version)(ansi rst) to continue, or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print-info 'Artifact packing cancelled. Bye.'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    fail-artifact $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($confirm), does not match ($version).' --details {
      expected: $version,
      actual: $confirm,
    }
  }
}

# Produce artifacts from the source project and display artifact metadata
def produce-artifact [
  --from(-f): string,         # Source config to build or download artifact
  --branch(-b): string,       # The branch name to build the artifact
  --need-confirm(-c),         # Require confirmation before executing the produce action
] {
  let setting = validate-produce-setting --from $from --branch $branch
  if $need_confirm { confirm-produce $setting }
  let meta = create-artifact-from-pipeline $setting
  let version = resolve-produced-artifact-version $meta $setting
  print-info $'(char nl)Artifact has been created successfully:'
  print-divider
  print-table $meta
  {
    meta: $meta,
    version: $version,
    releaseId: ($meta | where Name == 'releaseID' | get Value?.0?),
    detailUrl: ($meta | where Name == 'detailUrl' | get Value?.0?),
  }
}

def resolve-produced-artifact-version [
  meta: table,
  setting: record,
] {
  let version = (
    $meta
      | where {|row| (($row.Name? | default '' | into string | str downcase) =~ 'version') }
      | get Value?.0?
  )
  if ($version | is-empty) {
    fail-artifact $ECODE.SERVER_ERROR EMPTY_ARTIFACT_VERSION 'The produced artifact metadata does not contain a version field.' --details {
      sourceProjectId: ($setting.projectId? | default null),
      sourceProjectName: ($setting.projectName? | default null),
      availableFields: ($meta | get Name? | default []),
    }
  }
  $version
}

# Confirm artifact produce settings before execution
def confirm-produce [
  setting: record,    # Source setting to produce the artifact
] {
  if ($env.ART_ASSUME_YES? | default false) { return }
  ensure-interactive confirmation 'confirm artifact production' --details { expected: $setting.branch }
  print-info 'You are about to produce artifacts with the following config:'
  let option = ($setting | reject -o username password)
  print-divider 60 -c grey66
  print-info $option
  print-divider 60 -c grey66
  print-info 'Are you sure to continue? '
  let confirm = input $'Please enter (ansi p)($setting.branch)(ansi rst) to continue, or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print-info 'Artifact creation cancelled. Bye.'; exit $ECODE.SUCCESS }
  if $confirm != $setting.branch {
    fail-artifact $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($confirm), does not match ($setting.branch).' --details {
      expected: $setting.branch,
      actual: $confirm,
    }
  }
}

# Confirm artifact consume settings before execution
def confirm-consume [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The destination environment, such as DEV, TEST, STAGING, or PROD
  destSetting: record,        # Destination setting to consume the artifact
  --no-deploy(-n),            # Don't deploy after creating deploy order
] {
  if ($env.ART_ASSUME_YES? | default false) { return }
  ensure-interactive confirmation 'confirm artifact consumption' --details { expected: $version }
  let msg = if $no_deploy {
      $'You are about to fetch the artifacts and create a deployment order with the following config:'
    } else {
      $'You are about to fetch the artifacts and (ansi r)DEPLOY(ansi rst) them with the following config:'
    }
  print-info $msg
  let setting = {
      version: $version, destEnv: $destEnv,
      destSetting: ($destSetting | reject -o username password)
    }
  print-divider 60 -c grey66
  print-table $setting
  print-divider 60 -c grey66
  print-info 'Are you sure to continue? '
  let confirm = input $'Please enter (ansi p)($version)(ansi rst) to continue, or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print-info 'Operation cancelled. Bye.'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    fail-artifact $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($confirm), does not match ($version).' --details {
      expected: $version,
      actual: $confirm,
    }
  }
}

# Confirm artifact deploy settings before execution
def confirm-deploy [
  version: string,            # The version number of the artifact to deploy
  destEnv: string,            # The destination environment, such as DEV, TEST, STAGING, or PROD
  destSetting: record,        # Destination setting to consume the artifact
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail
] {
  # TODO: Confirm deploy by --doid with more detail
  if ($env.ART_ASSUME_YES? | default false) { return }
  ensure-interactive confirmation 'confirm artifact deployment' --details { expected: $version, deployOrderId: $doid }
  let msg = if $no_deploy {
      $'You are about to create a deployment order from ($version) for ($destEnv) with the following config:'
    } else {
      $'You are about to (ansi r)DEPLOY ($version) to ($destEnv)(ansi rst) with the following config:'
    }
  print-info $msg
  let setting = {
      version: $version, destEnv: $destEnv,
      destSetting: ($destSetting | reject -o username password)
    }
  print-divider 60 -c grey66
  print-table $setting
  print-divider 60 -c grey66
  print-info 'Are you sure to continue? '
  let confirm = input $'Please enter (ansi p)($version)(ansi rst) to continue, or (ansi p)q(ansi rst) to quit: '
  if $confirm == 'q' { print-info 'Operation cancelled. Bye.'; exit $ECODE.SUCCESS }
  if $confirm != $version {
    fail-artifact $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($confirm), does not match ($version).' --details {
      expected: $version,
      actual: $confirm,
    }
  }
}

# Validate the artifact produce action settings and return the validated settings
def validate-produce-setting [
  --from(-f): string,         # Source config to build or download artifact
  --branch(-b): string,       # The branch name to build the artifact
] {
  get-source-setting --from $from --branch $branch
}

# Consume artifacts: download, upload, and deploy them to the destination environment
def consume-artifact [
  destEnv: string,            # The dest environment to deploy the artifact, such as DEV,TEST,STAGING,PROD, etc.
  --version(-v): string,      # The version number of the artifact to deploy
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --from(-f): string,         # Source config to build or download artifact
  --to(-t): string,           # Destination config to upload or deploy artifact
  --need-confirm(-c),         # Require confirmation before executing the consume action
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  let destEnv = $destEnv | str upcase
  let srcSetting = validate-produce-setting --from $from
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy
  let version = if ($version | is-empty) { select-artifact-2-consume-by-fzf } else { $version }
  if $need_confirm { confirm-consume $version $destEnv $destSetting --no-deploy=$no_deploy }
  if ($version | default '' | str starts-with 'R.') {
    consume-trantor-artifact $version $destSetting $destEnv --no-deploy=$no_deploy --deploy-group $deploy_group
    return
  }
  let srcPID = $srcSetting.projectId
  let destPID = $destSetting.projectId
  # 先查询项目制品
  mut matches = query-release-by-version $version $srcSetting --verbose
  # 如果项目制品里面没找到再查询应用制品
  if ($matches | is-empty) {
    $matches =  query-release-by-version $version $srcSetting --is-app
    if ($matches | is-empty) {
      fail-artifact $ECODE.CONDITION_NOT_SATISFIED ARTIFACT_NOT_FOUND $'No artifact found for version ($version) in project ID ($srcPID)' --details {
        version: $version,
        sourceProjectId: $srcPID,
      }
    }
    # 如果是应用制品则将其转换为项目制品
    print-info 'A APP artifact was found and will be packed into a PROJECT artifact...'
    let projectArtVer = get-project-artifact-version $matches.0.version
    $matches = create-project-artifact $projectArtVer $matches.0 $srcSetting
  }

  let version = $matches.version.0
  let dest = download-artifact-from-release $matches.releaseId.0 $version $srcSetting
  let destMatches = query-release-by-version $version $destSetting
  if ($destMatches | is-empty) {
    upload-artifact $version $dest $destSetting
  } else {
    print-info $'Artifact of version (ansi g)($version)(ansi rst) already exists in dest project ID (ansi g)($destPID)(ansi rst):(char nl)'
    print-info $destMatches
  }
  let selectedRelease = query-release-by-version $version $destSetting
  let deployGroup = $destSetting.deployGroup | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --deploy-group=$deployGroup --dest-setting $destSetting
  let deployResult = if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid $destSetting } else { null }
  {
    version: $version,
    sourceProjectId: $srcPID,
    destinationProjectId: $destPID,
    releaseId: ($selectedRelease | get releaseId.0?),
    deployOrderId: $doid,
    deployGroup: ($deployGroup | split row ','),
    deployResult: $deployResult,
  }
}

# Consume a Trantor artifact: rebuild and deploy it to the destination environment
def consume-trantor-artifact [
  version: string,            # The version number of the artifact to deploy
  destSetting: record,        # Destination setting to consume the artifact
  destEnv: string,            # The destination environment, such as DEV, TEST, STAGING, or PROD
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  let metaPath = $'(get-tmp-path)/($RELEASE_META_PATH)/releases.json'
  let token = renew-erda-session
  let selected = open $metaPath | where metadata?.erda_release_version? == $version | get 0
  let respBegin = $'Shell stderr:(char nl)(ansi grey66)--- Begin Response from Trantor Bash Script ---- (char nl)'
  let respEnd = $'--- End Response from Trantor Bash Script ---- (char nl)(ansi rst)'
  print-info $'You are about to consume the Trantor artifact: (ansi g)($version)(ansi rst)'
  print-divider
  print-table ($selected | reject -o metadata.file_hashes metadata.changelog)
  let preCheck = query-release-by-version $version $destSetting
  if ($preCheck | is-empty) {
    let artifactUrl = $'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/($selected.path)'
    let pipeline = (bash run/trantor-artifact-transfer.sh
        --erda-token $token
        --artifact-url $artifactUrl
        --base-url $destSetting.erdaHost
        --org-name $destSetting.orgAlias
        --project-id $destSetting.projectId
        --non-interactive --output-format json
      ) | complete

    # Guard: child process failure
    if ($pipeline.exit_code != 0) {
      print -e $'(char nl)(ansi r)Failed to bootstrap artifact building via shell script.(ansi rst)'
      if ($pipeline.stderr | is-not-empty) { print-info $'(char nl)($respBegin)'; print-info $pipeline.stderr; print-info $respEnd }
      if ($pipeline.stdout | is-empty) {
      print-info $'(ansi r)Shell stdout is empty. Please make sure you have the (ansi g)Admin OR Owner (ansi r)role for the (ansi g)trantor2 (ansi r)app.(ansi rst)'
      } else { print-info $'(char nl)Shell stdout:'; print-info $'(char nl)($respBegin)'; print-info $pipeline.stdout; print-info $respEnd }
      fail-artifact $ECODE.SERVER_ERROR SHELL_BOOTSTRAP_FAILED 'Failed to bootstrap artifact building via shell script.' --details {
        exitCode: $pipeline.exit_code,
      }
    }

    # Guard: empty stdout
    if ($pipeline.stdout | str trim | is-empty) {
      fail-artifact $ECODE.SERVER_ERROR EMPTY_SHELL_OUTPUT 'Shell returned empty output. Unable to read pipeline information. Please check authentication/session, base URL and application name, then retry.' --details {
        version: $version,
      }
    }

    # Parse JSON safely
    let shellResp = try { $pipeline.stdout | from json } catch { {} }
    if ($shellResp | is-empty) or ($shellResp.pipeline_id? | default '' | is-empty) {
      print-info $'(char nl)Raw stdout:'
      print-info $'(char nl)($respBegin)'
      print-info $pipeline.stdout
      print-info $respEnd
      fail-artifact $ECODE.SERVER_ERROR INVALID_SHELL_OUTPUT 'Failed to parse pipeline information from shell output.' --details {
        version: $version,
      }
    }

    print-info $'(char nl)Shell response:'
    print-table $shellResp
    let pipelineId = $shellResp.pipeline_id?
    print-info $'(char nl)Building artifact with pipeline ID: (ansi g)($pipelineId)(ansi rst)'
    query-cicd-by-id ($pipelineId | into int) --watch --host $destSetting.erdaHost
    let result = fetch-cicd-detail ($pipelineId | into int) --host $destSetting.erdaHost
    let status = $result | get data.pipelineStages.pipelineTasks | select status | flatten | get status
    if ('Failed' in $status) {
      fail-artifact $ECODE.SERVER_ERROR ARTIFACT_BUILD_FAILED 'Artifact build failed.' --details {
        version: $version,
        pipelineId: $pipelineId,
      }
    }
    let pkg = $result | get data.pipelineStages.pipelineTasks
      | last | get result.metadata | first | into record | get value
    print-info $'(char nl)Artifact package URL: (ansi g)($pkg)(ansi rst)'
    let dest = download-artifact-pkg $version $pkg
    upload-artifact $version $dest $destSetting
  }
  let selectedRelease = query-release-by-version $version $destSetting
  let deployGroup = $deploy_group | default $destSetting.deployGroup | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --deploy-group=$deployGroup --dest-setting $destSetting
  let deployResult = if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid $destSetting } else { null }
  {
    version: $version,
    releaseId: ($selectedRelease | get releaseId.0?),
    deployOrderId: $doid,
    deployGroup: ($deployGroup | split row ','),
    deployResult: $deployResult,
  }
}

# Validate the artifact consume action settings and return the validated settings
def validate-consume-setting [
  destEnv: string,            # The destination environment, such as DEV, TEST, STAGING, or PROD
  --deploy,                   # Perform a deploy action rather than consume action
  --no-deploy(-n),            # Don't deploy after creating deploy order
  --to(-t): string,           # Destination config to upload or deploy artifact
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail
  --deploy-group(-g): string, # The app group to deploy for the specified artifact, `all` by default
] {
  if not ($deploy and ($doid | is-not-empty)) {
    let destEnv = $destEnv | str upcase
    if $destEnv not-in $VALID_ENV {
      fail-artifact $ECODE.INVALID_PARAMETER INVALID_DEST_ENV $'Invalid destination environment: ($destEnv), supported environments are: ($VALID_ENV | str join ", ")' --details {
        destEnv: $destEnv,
        supported: $VALID_ENV,
      }
    }
  }
  get-destination-setting --to $to --deploy-group $deploy_group
}

# Deploy the specified artifact to the destination environment, or build, download, upload, and deploy it in combine mode
def deploy-artifact [
  --dest-env: string,         # The destination environment, such as DEV, TEST, STAGING, or PROD
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
  if ($destEnv | is-not-empty) {
    print-info $'Deploy artifact to (ansi g)($destEnv)(ansi rst)'
    print-divider
  }
  let srcSetting = validate-produce-setting --from $from
  mut version = $version
  if $combine {
    let meta = produce-artifact --from=$from --branch=$branch --need-confirm
    $version = $meta.version
  }
  let destSetting = validate-consume-setting $destEnv --to $to --deploy-group $deploy_group --no-deploy=$no_deploy --deploy --doid $doid
  if (not ($doid | is-empty)) and (not $no_deploy) {
    print-info $'You are about to deploy the artifact with deployment order ID: (ansi g)($doid)(ansi rst)'
    let deployResult = polling-artifact-deploy $doid $destSetting
    return {
      deployOrderId: $doid,
      deployResult: $deployResult,
    }
  }
  let version = if ($version | is-empty) { select-artifact-by-fzf $destSetting } else { $version }
  if ($version | is-empty) {
    cancel-artifact 'No artifact version selected. Deployment cancelled.' --details {
      mode: (if (is-non-interactive) { 'agent' } else { 'interactive' }),
    }
  }
  if $combine {
    return (consume-artifact $destEnv -v $version --from $from --to $to --deploy-group=$deploy_group --no-deploy=$no_deploy)
  }
  confirm-deploy $version $destEnv $destSetting --doid $doid --no-deploy=$no_deploy
  let selectedRelease = query-release-by-version $version $destSetting
  let deployGroup = $destSetting.deployGroup? | default 'All'
  let doid = create-deploy-order ($selectedRelease.0 | into record) $destEnv --deploy-group=$deployGroup --dest-setting $destSetting
  let deployResult = if (not ($doid | is-empty)) and (not $no_deploy) { polling-artifact-deploy $doid $destSetting } else { null }
  {
    version: $version,
    releaseId: ($selectedRelease | get releaseId.0?),
    deployOrderId: $doid,
    deployGroup: ($deployGroup | split row ','),
    deployResult: $deployResult,
  }
}

# Select a artifact version to deploy from the release list
def select-artifact-by-fzf [
  destSetting: record,    # The destination setting to search and deploy the artifact
] {
  ensure-interactive artifact-selection 'select artifact version with fzf' --details {
    projectId: $destSetting.projectId,
    projectName: $destSetting.projectName?,
  }
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
  let version = $releases.data.list | select version createdAt | sort-by -r createdAt
      | get version | str join (char nl) | fzf | complete | get stdout | str trim
  $version
}

# Select the artifact version to consume from source Trantor artifact list
def select-artifact-2-consume-by-fzf [] {
  ensure-interactive artifact-selection 'select upstream artifact version with fzf'
  # ~/.termix-nu/terp/artifacts/releases.json
  let tmp = $'(get-tmp-path)/($RELEASE_META_PATH)'
  if not ($tmp | path exists) { mkdir $tmp }
  let releaseMetaPath = $'($tmp)/releases.json'
  let candidates = http get https://trantor2-installer.app.terminus.io/artifacts
    | get artifacts
    | tee { save -f $releaseMetaPath }
    | select version metadata?.erda_release_version?
    | rename version release
    | default '' release
    | where release =~ 'R.'
  let title = $'Select the artifact to consume:'
  let PREVIEW_CMD = $"nu actions/artifact.nu {} release"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let version = $candidates | get release | str join (char nl) | fzf | complete | get stdout | str trim
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
    fail-artifact $ECODE.SERVER_ERROR DEPLOYMENT_START_FAILED $'Failed to start deployment: ($deploy.err.msg)' --details {
      deployOrderId: $doid,
      host: $host,
    }
  }
  print-info 'Deployment has been started successfully!'

  let groups = get-artifact-deploy-detail $doid $destSetting | get data.applicationsInfo
  let total = $groups | length
  const FINISH_STATUS = [OK, FAILED, CANCELED]
  const UNFINISHED_STATUS = [DEPLOYING, WAITDEPLOY]
  print-info $'(char nl)Artifact deployment details:'
  print-divider

  # pipelineTasks status: Created,Analyzed,Success,Queue,Running,Failed,StopByUser,NoNeedBySystem
  for g in ($groups | enumerate) {
    let groupStatus = $g.item | get status
    let apps = $g.item | get name | str join ', '
    let groupSuccess = $groupStatus | all {|it| $it == 'OK' }
    let groupFailed = $groupStatus | any {|it| $it == 'FAILED' }
    let groupCancelled = $groupStatus | any {|it| $it == 'CANCELED' }
    let groupUnfinished = $groupStatus | any {|it| $it in $UNFINISHED_STATUS }
    let indicator = if $groupSuccess {
        $'(ansi g)✓(ansi rst)  Deployment of (ansi g)($apps)(ansi rst) finished successfully!'
      } else if $groupFailed {
        $'(ansi y)⚠(ansi rst)  Deployment of (ansi y)($apps)(ansi rst) failed!'
      } else if $groupCancelled {
        $'(ansi y)👻(ansi rst) Deployment of (ansi y)($apps)(ansi rst) was cancelled!'
      } else if $groupUnfinished {
        $'(ansi pb)🪄(ansi rst) Artifact group (ansi g)[($apps)](ansi rst) is being deployed...'
      } else {
        $'(ansi r)✗(ansi rst) Unknown Status: ($groupStatus | str join ",")'
      }

    print-info $'Group ($g.index + 1)/($total): ($indicator)'
    mut counter = 0
    mut keepPolling = true
    while $keepPolling {
      print-info-n '*'  # * 💤 👣 ✨ 🍵 ⚡ 🎉 🔹 🔸
      $counter += 1
      if ($counter == 90) { $counter = 0; print-info-n (char nl) }
      let detail = get-artifact-deploy-detail $doid $destSetting
      let apps = $detail.data.applicationsInfo
      # DEPLOYING,OK,FAILED
      let status = $apps | get $g.index | get status
      if ($status | any {|it| $it in $UNFINISHED_STATUS }) {
        $keepPolling = true
      } else {
        $keepPolling = false
        print-info $'(char nl)Artifact group deployment finished with status: (ansi g)($status | str join ",")(ansi rst).'
        print-divider 60 -c grey66
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
  print-info $'(char nl)Artifact deployment finished with status: (ansi p)($detail.data.status)(ansi rst)! Total time: ($duration)'
  {
    deployOrderId: $doid,
    status: $detail.data.status,
    startedAt: $detail.data.startedAt,
    updatedAt: $detail.data.updatedAt,
    duration: ($duration | into string),
  }
}

# Get artifact deploy detail by deploy order ID
def get-artifact-deploy-detail [
  doid: string            # Deploy order ID to query the deploy detail
  destSetting: record,    # The destination setting to query artifact deploy detail
] {
  let fixture = read-fixture ARTIFACT_FIXTURE_DEPLOY_DETAIL
  if $fixture != null { return $fixture }
  let host = $destSetting.erdaHost
  let queryUrl = $'($host)/api/($destSetting.orgAlias)/deployment-orders/($doid)'
  load-erda-credentials $destSetting
  mut detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  # Check session expired, and renew if needed
  let check = should-retry-req $detail
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session ($destSetting.erdaOpenApiHost? | default $destSetting.erdaHost) }
    $detail = (http get -e --headers (get-erda-auth $host --type nu) $queryUrl)
  }
  $detail
}

def get-release-detail [
  releaseId: string,    # Release ID to query
  setting: record,      # The setting to query release detail
] {
  let fixture = read-fixture ARTIFACT_FIXTURE_RELEASE_DETAIL
  if $fixture != null { return $fixture }
  let host = $setting.erdaHost
  let queryUrl = $'($host)/api/($setting.orgAlias)/releases/($releaseId)'
  load-erda-credentials $setting
  mut detail = http get -e --headers (get-erda-auth $host --type nu) $queryUrl
  let check = should-retry-req $detail
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session ($setting.erdaOpenApiHost? | default $setting.erdaHost) }
    $detail = (http get -e --headers (get-erda-auth $host --type nu) $queryUrl)
  }
  if not ($detail.success? | default false) {
    fail-artifact $ECODE.SERVER_ERROR RELEASE_DETAIL_QUERY_FAILED $'Failed to query release detail for release ID ($releaseId).' --details {
      releaseId: $releaseId,
      projectId: $setting.projectId,
    }
  }
  $detail
}

# Select the application group to deploy from the artifact
def select-deploy-mode-by-fzf [
  modes: record,            # The deploy modes to select
  previewOptions: record,   # The preview options to query and render the preview detail panel
] {
  ensure-interactive deploy-group-selection 'select deploy group with fzf' --details {
    groups: ($modes | columns),
  }
  print-info $'(ansi g)Tip: Use `Tab` and `Shift + Tab` to toggle select items, and `Enter` to confirm(ansi rst)'
  let title = $'Select the application group to deploy:'
  let options = $previewOptions | get -o projectId releaseID workspace orgAlias host | str join '+++'
  let PREVIEW_CMD = $"nu actions/artifact.nu {} group --options ($options)"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --multi --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let selected = $modes | columns | str join (char nl) | fzf | complete | get stdout | str trim
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
  let inexistGroup = $deployGroup | where {|it| $it not-in ($modes | columns) }
  # Use specified deploy group or select the deploy mode
  mut selectedMode = if ($inexistGroup | is-empty) { $deployGroup } else {
      if (is-non-interactive) {
        fail-artifact $ECODE.INVALID_PARAMETER INVALID_DEPLOY_GROUP $'You are trying to deploy application groups ($deployGroup), but ($inexistGroup) do not exist.' --details {
          requested: $deployGroup,
          invalid: $inexistGroup,
          available: ($modes | columns),
        }
      }
      print-info $'You are trying to deploy application groups ($deployGroup), but (ansi r)($inexistGroup)(ansi rst) do not exist. Please select the groups manually.(char nl)'
      select-deploy-mode-by-fzf $modes $previewOptions
    }

  if ($selectedMode | is-empty) {
    cancel-artifact "You didn't select anything. Deployment cancelled." --details {
      available: ($modes | columns),
    }
  }
  if ($selectedMode | length) > 1 and ('All' in $selectedMode) {
    print-info $'You selected (ansi g)`All`(ansi rst) together with other groups, so (ansi r)`All` will be ignored.(ansi rst)'
    $selectedMode = ($selectedMode | where {|it| $it != 'All' })
  }
  print-info $'You are about to deploy the application groups: (ansi g)($selectedMode)(ansi rst).'
  print-info $'The following applications will be deployed:(char nl)'
  mut apps = []
  let columns = [applicationName createdAt releaseName version]
  for g in $selectedMode {
    let applications = ($modes | get $g | get applicationReleaseList | flatten | select ...$columns)
    $apps ++= $applications
  }
  print-info ($apps | flatten | sort-by applicationName)

  let doPayload = {
    projectId: $pid,
    modes: $selectedMode,
    workspace: $environment,
    releaseId: $artifact.releaseId,
  }
  let do = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $doCreateUrl $doPayload
  if not $do.success {
    fail-artifact $ECODE.SERVER_ERROR CREATE_DEPLOY_ORDER_FAILED $'Failed to create deploy order with error message: ($do.err.msg)' --details {
      environment: $environment,
      deployGroup: $selectedMode,
      releaseId: $artifact.releaseId,
    }
  } else {
    print-info $'Deploy order has been created successfully with ID (ansi g)($do.data.id)(ansi rst)'
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
  let fixture = read-fixture ARTIFACT_FIXTURE_RELEASE_CANDIDATES
  if $fixture != null { return $fixture }
  let host = $destSetting.erdaHost
  let queryUrl = $'($host)/api/($destSetting.orgAlias)/releases'
  let payload = {
    pageNo: '1',
    pageSize: '150',
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
    if $check.noAuth { renew-erda-session ($destSetting.erdaOpenApiHost? | default $destSetting.erdaHost) }
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
  let fixture = read-fixture ARTIFACT_FIXTURE_RELEASE_QUERY
  if $fixture != null {
    let matches = $fixture.data.list
      | select projectName projectId createdAt version releaseId
      | upsert releaseId {|it| $it.releaseId }
      | where version == $version
    if not $verbose { return $matches }

    let releaseType = if $is_app { 'APP Artifact' } else { 'PROJECT Artifact' }
    if ($matches | is-empty) {
      print-info $'(char nl)No ($releaseType) found of version (ansi g)($version)(ansi rst) in project (ansi g)($setting.projectName? | default "")@($setting.projectId)(ansi rst)'
    } else {
      let suffix = if ($setting.projectName | is-empty) { '' } else { $' in (ansi g)($setting.projectName)(ansi rst)' }
      print-info $'Found matched artifact release($suffix):(char nl)'
      print-info $matches
    }
    return $matches
  }
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
    if $check.noAuth { renew-erda-session ($setting.erdaOpenApiHost? | default $setting.erdaHost) }
    $filtered = (curl --silent -H (get-erda-auth $host) $queryUrl | from json)
  }

  if ($filtered | describe) == 'string' and $filtered =~ 'Unauthorized' {
    fail-artifact $ECODE.AUTH_FAILED AUTH_FAILED $'Failed to query release with error message: ($filtered)' --details {
      version: $version,
      projectId: $setting.projectId,
    }
  }
  let matches = if $filtered.success {
    $filtered.data.list
      | select projectName projectId createdAt version releaseId
      | upsert releaseId {|it| $it.releaseId }
      | where version == $version
  }
  if not $verbose { return $matches }

  let releaseType = if $is_app { 'APP Artifact' } else { 'PROJECT Artifact' }
  if ($matches | is-empty) {
    print-info $'(char nl)No ($releaseType) found of version (ansi g)($version)(ansi rst) in project (ansi g)($setting.projectName? | default "")@($setting.projectId)(ansi rst)'
  } else {
    let suffix = if ($setting.projectName | is-empty) { '' } else { $' in (ansi g)($setting.projectName)(ansi rst)' }
    print-info $'Found matched artifact release($suffix):(char nl)'
    print-info $matches
  }
  $matches
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
  print-info $'Downloading artifact of version (ansi g)($version)(ansi rst) and releaseId (ansi g)($releaseId)(ansi rst) ...'
  curl --silent -H (get-erda-auth $host) $downloadUrl -o $dest
  print-info $'Artifact has been downloaded to ($dest)(char nl)'
  $dest
}

# 根据新构建制品的链接下载制品
def download-artifact-pkg [
  version: string,      # Version number of the artifact
  url: string,          # URL of the artifact to download
] {
  let tmp = $'(get-tmp-path)/($RELEASE_META_PATH)'
  if not ($tmp | path exists) { mkdir $tmp }
  # Download artifact
  let dest = $'($tmp)/($version).zip'
  print-info $'Downloading artifact of version (ansi g)($version)(ansi rst) ...'
  http get $url | save -rfp $dest
  print-info $'Artifact has been downloaded to ($dest)(char nl)'
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
  print-info $upload
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
    print-info $'Artifact has been uploaded successfully with version (ansi g)($version)(ansi rst)'
    return {
      version: $version,
      releaseUpload: $release.data?,
      file: $file,
    }
  } else {
    fail-artifact $ECODE.SERVER_ERROR UPLOAD_ARTIFACT_FAILED $'Failed to upload artifact of version ($version) with error message: ($release.err.msg)' --details {
      version: $version,
      file: $file,
      projectId: $destSetting.projectId,
    }
  }
}

# Create project artifact from app artifact
def create-project-artifact [
  version: string,      # Version number of the artifact
  release: record,      # The app release to create project artifact
  destSetting: record   # The destination setting to upload artifact
] {
  let host = $destSetting.erdaHost
  let artifactCreateUrl = $'($host)/api/($destSetting.orgAlias)/releases'
  let userId = renew-erda-session ($destSetting.erdaOpenApiHost? | default $destSetting.erdaHost) --get-uid
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

  let resp = http post -e --headers (get-erda-auth $host --type nu) --content-type application/json $'($artifactCreateUrl)' $payload
  if $resp.success {
    print-info $'Project artifact has been created successfully with version (ansi g)($version)(ansi rst)'
    print-divider
    let matches = query-release-by-version $version $destSetting
    print-info $matches
    return $matches
  }
  fail-artifact $ECODE.SERVER_ERROR CREATE_PROJECT_ARTIFACT_FAILED $'Failed to create project artifact of version ($version) with error message: ($resp.err.msg)' --details {
    version: $version,
    projectId: $destSetting.projectId,
    sourceReleaseId: $release.releaseId,
  }
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
    print-info $'File (ansi g)($file)(ansi rst) has been uploaded successfully to Erda Cloud'
    return { fileID: $upload.data.uuid, url: $upload.data.url, creator: $upload.data.creator }
  }
  fail-artifact $ECODE.SERVER_ERROR UPLOAD_FILE_FAILED $'Failed to upload file ($file) to Erda Cloud with error message: ($upload.err.msg)' --details {
    file: $file,
    projectId: $destSetting.projectId,
  }
}

# Build, download, upload and deploy artifacts.
#
# This is the script entrypoint for direct `nu actions/artifact.nu ...` usage.
# It dispatches to the main `artifacts` command and preserves the legacy preview
# invocation used by fzf preview windows.
export def main [
  action?: string,            # Action to perform, such as `deploy`, `produce`, `consume`, `pack`
  --list(-l),                 # List all available source and destination settings
  --non-interactive,          # Fail instead of prompting for user input or fzf selections
  --yes(-y),                  # Skip confirmation prompts
  --output(-o): string = text,# Output format: `text` or `json`
  --dry-run,                  # Validate and preview the execution plan without mutating remote state
  --combine(-c),              # Build and upload the artifact to the dest project and deploy to the dest (deploy)
  --no-deploy(-n),            # Don't deploy after creating deploy order (deploy/consume)
  --from(-f): string,         # Alias of source config to build or download artifact (produce/consume/deploy/pack)
  --to(-t): string,           # Alias of destination config to upload or deploy artifact (consume/deploy)
  --doid(-i): string,         # The deploy order ID to deploy and query the deploy detail (deploy)
  --branch(-b): string,       # The branch name to build the artifact (produce)
  --version(-v): string,      # The version number of the artifact to deploy (consume/deploy) or pack
  --dest-env(-e): string,     # The destination environment, such as DEV, TEST, STAGING, or PROD (consume/deploy)
  --deploy-group(-g): string, # The app group to deploy, multiple groups should be separated by comma, `All` by default (consume/deploy)
  --options: string,          # Internal preview option used by fzf, not part of the normal CLI
  ...rest: string,            # Internal preview arguments used by fzf
] {
  let previewType = $rest | get -o 0
  if ($action | is-not-empty) and ($previewType in $PREVIEW_TYPES) and ($action not-in $SUPPORTED_ACTIONS) {
    return (fzf-preview $action $previewType --options $options)
  }

  if ($action | is-empty) and (not $list) and (($rest | length) == 0) {
    return (artifacts --help)
  }

  if $list {
    return (
      artifacts
        --list
        --yes=$yes
        --output=$output
        --dry-run=$dry_run
        --non-interactive=$non_interactive
    )
  }

  artifacts $action
    --list=$list
    --yes=$yes
    --output=$output
    --dry-run=$dry_run
    --combine=$combine
    --no-deploy=$no_deploy
    --from=$from
    --to=$to
    --doid=$doid
    --branch=$branch
    --version=$version
    --dest-env=$dest_env
    --deploy-group=$deploy_group
    --non-interactive=$non_interactive
}
