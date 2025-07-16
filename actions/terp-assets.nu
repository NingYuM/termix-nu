#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/11/17 22:06:56

# [√] Download static assets listed in latest.json
# [√] Download static assets to specified dir
# [√] Upload static assets to minio
# [√] Support download assets for specified end, multi ends separated by `,`
# [√] `--from` support full latest.json url
# [√] Handle assets for t-material-ui and t-mobile-ui
# [√] Transfer command requires confirmation before execution to reduce misoperation
# [√] Sync modules by full name
# [√] Validate module names from latest.json support
# [√] Ignore new modules while transferring `all` assets support
# [√] Get available modules from latest.json if sync all is selected
# [√] Display frontend module metadata
# [√] Display module status statistics info in metadata view
# [√] Revert frontend module to a selected version, ossutil or mc required
# [√] Add Revert metadata to latest.json
# Ref:
#   - https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json
#   - http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-test/latest.json
#   - https://min.io/docs/minio/linux/reference/minio-mc/mc-cp.html
#   - https://min.io/docs/minio/linux/reference/minio-mc.html?ref=docs#install-mc
#   - https://docs.erda.cloud/2.2/manual/dop/guides/reference/pipeline.html
#   - https://www.alibabacloud.com/help/zh/oss/developer-reference/install-ossutil#dda54a7096xfh

use ../utils/common.nu [ECODE, FZF_DEFAULT_OPTS, FZF_THEME, _TIME_FMT]
use ../utils/common.nu [is-installed, hr-line, get-conf, get-tmp-path, compare-ver]

# --------------------------------- Constants and Configs ---------------------------------
const JSON_ENTRY = 'latest.json'
const STORE_TYPES = [aliyun, minio, volc, ifly]
const VALID_ACTIONS = [download, transfer, detect, revert]
const VALID_MODULES = [terp-mobile terp service service-mobile iam dors dors-mobile base base-mobile b2b emp]
const ENDPOINT = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com'

# Don't validate module names by default
const VALIDATE_MODULES = '0'

const KEY_MAPPING = $"(ansi grey66)\(Space: Select, a: Select All, ESC/q: Quit, Enter: Confirm\)(ansi rst)"

# Frontend module and descriptions
const MOD_DESC = {
    b2b: 'b2b: B2B & SRM 自定义业务组件'
    base: 'base: PC 端设计器基础组件'
    base-mobile: 'base-mobile: 移动端设计器基础组件'
    charts: 'charts: 新版报表搭建相关 PC 端组件'
    charts-mobile: 'charts-mobile: 新版报表搭建相关移动端组件'
    dors: 'dors: PC 端报表搭建组件'
    dors-mobile: 'dors-mobile: 移动端报表搭建组件'
    emp: 'emp: EMP 自定义业务组件'
    iam: 'iam: IAM 角色 & 用户 & 日志列表及权限授权相关'
    service: 'service: PC 端审批/通知/日志/导入导出/打印等基础组件'
    service-mobile: 'service-mobile: 移动端审批/通知等基础组件'
    terp: 'terp: TERP PC 端业务组件'
    terp-mobile: 'terp-mobile: TERP 移动端业务组件'
  }

const TOOL_INSTALL_TIP = {
  fzf: 'Please install fzf by `brew install fzf` first'
  mc: 'Please install mc by `brew install minio/stable/mc`'
  ossutil: 'Please install `ossutil`, see https://alibabacloud.com/help/zh/oss/developer-reference/install-ossutil'
}
# -----------------------------------------------------------------------------------------

# ***************************************************************************************
# ------------------------------------ Main Commands ------------------------------------
# ***************************************************************************************

# Usage:
#   t ta detect -f dev
#   t ta detect -f https://public-go1688-trantor-noprod.oss-cn-hangzhou.aliyuncs.com/fe-resources/csp-test/latest.json
#   t ta download all -f dev
#   t ta download pc --from <mode> --to <dir>
#   t ta revert base -t terp-dev -d oss
#   t ta revert base --to dev@wq -d wqtest
#   t ta revert base --to ttt0 --dest-store oss
#   t ta transfer pc --from <oss-mode> --to <minio-mode>
#   t ta transfer all -f dev -v -d oss -t ttt0
#   t ta transfer all --from dev --to ttt0 --dest-store oss --quiet
#   t ta transfer all --from foran --to fs-test --dest-store fsmio

# Download TERP static assets or transfer assets to other path of the specified cloud storage
export def 'terp assets' [
  action: string,             # Available actions: download, transfer, detect and revert
  modules?: string,           # Available values: pc/mobile/mat/mmat/iam/dors/mdors/all. Multiple modules separated by `,`
  --from(-f): string,         # Source mount point or source URL. Note: Only `detect` action supports multiple sources separated by `,`
  --to(-t): string,           # Destination mount point
  --quiet(-q),                # Show less info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  cd $env.TERMIX_DIR
  # Handle revert action
  if $action == 'revert' {
    if ($modules | is-empty) {
      print $'Please specify the frontend (ansi p)module(ansi rst) to revert, e.g. `(ansi p)t ta revert base(ansi rst)`'
    }
    # If you want to revert module from MINIO the `--to` option should be in the format of `mount-point@mc-alias`
    if ($to | is-empty) {
      print $'Please specify the destination mount point to revert by `(ansi p)-t(ansi rst)` or `(ansi p)--to(ansi rst)` option'
      print $'To revert module in MINIO the `-t` option should be like `(ansi p)test@mc-alias(ansi rst)`'
    }
    if ($dest_store | is-empty) { print $'Please specify the destination store to revert the frontend module by `(ansi p)-d(ansi rst)` option' }
    if ([$modules $to $dest_store] | any { $in | is-empty }) { exit $ECODE.INVALID_PARAMETER }
    revert-module $modules $to $dest_store; return
  }

  if ($from =~ ',') and ($action == 'detect') { detect-multiple-assets $from; return }
  pre-check $action --to $to --dest-store $dest_store
  let latestMeta = get-latest-meta $from
  let modules = get-modules $modules --latest-meta $latestMeta --action $action
  confirm-action $action $modules --to $to --dest-store $dest_store

  match $action {
    'detect' => { detect $latestMeta },
    'download' => { download $modules $latestMeta $to --quiet=$quiet },
    'transfer' => { transfer $modules $latestMeta $to --dest-store $dest_store --quiet=$quiet },
  }
}

# Preview the module revision metadata in fzf preview window
export def fzf-preview [revision: string, localPath: string, remoteURI: string, destStore: string] {
  let dest = $'($localPath)/($revision)/namespace.json'
  let ossConf = get-dest-oss $destStore
  let remoteFile = $'($remoteURI)/($revision)/namespace.json'
  let result = do-storage-cp $remoteFile $dest $ossConf
  if $result.exit_code != 0 {
    print -e $'Failed to copy namespace.json for preview'
    print $result.stderr
    exit $result.exit_code
  }

  let mountPoint = $remoteURI | split row '/' | last
  let module = $revision | split row '-' | drop | str join '-'

  print $'You are going to revert (ansi g)($module)(ansi rst) module at mount point (ansi g)($mountPoint)(ansi rst)'; hr-line 66
  open $dest | rename -c { namespace: 'module' }
    | merge { revision: $revision, remoteURI: $remoteURI }
    | select module revision remoteURI metadata
    | upsert metadata.syncBy {|it| $it.metadata?.syncBy? | show }
    | table -e -t compact
}

alias main = fzf-preview

# ***************************************************************************************
# ------------------------------------- Core Logic --------------------------------------
# ***************************************************************************************

# Detect multiple static assets and display the metadata
def detect-multiple-assets [from: string] {
  let mountPoints = $from | split row , | compact -e
  for mp in $mountPoints {
    let latestMeta = get-latest-meta $mp
    detect $latestMeta; print -n (char nl)
  }
}

# Revert frontend module to a selected version, ossutil or mc required
def revert-module [module: string, to: string, destStore: string] {
  let ossConf = get-dest-oss $destStore
  revert-precheck $module $to $ossConf

  let target = $to | split row @ | first
  let localPath = $'(get-tmp-path)/terp/revert/($module)/($target)/' | str replace -a \ /
  let isMinio = ($ossConf.TYPE? | default 'aliyun') == 'minio'
  let mcAlias = if $isMinio { $to | split row @ | last } else { '' }
  let remoteURI = if $isMinio {
      $'($mcAlias)/($ossConf.OSS_BUCKET)/fe-resources/($target)'
    } else {
      $'oss://($ossConf.OSS_BUCKET)/fe-resources/($target)'
    }

  if not ($localPath | path exists) { mkdir $localPath }

  # Select revision
  let revision = select-revert-revision $module $remoteURI $localPath $destStore $ossConf
  if ($revision | is-empty) { print $'No revision selected, bye...'; exit $ECODE.SUCCESS }

  # Confirm and execute revert
  execute-revert $module $target $destStore $revision $localPath $remoteURI $ossConf
}

# Download static assets from OSS to specified directory
def download [
  modules: list,        # End point, available values: pc, mobile, all
  latestMeta: record,   # Latest metadata
  to?: string,          # Destination dir
  --quiet(-q),          # Show less info
] {

  let tmp = $'(get-tmp-path)/terp'
  if not ($tmp | path exists) { mkdir $tmp }
  let dest = if ($to | is-empty) or (not ($to | path exists)) { $tmp } else { ($to | path expand) }
  let mount = $latestMeta.mountpoint
  let fromUrl = $latestMeta.latestUrl
  let assetUrlPrefix = $fromUrl | split row '/fe-resources' | get 0
  let entry = $'($dest)/latest-($mount).json'
  $latestMeta.latest | save -f $entry
  let entryConf = open $entry

  # Download assets for each end point
  $modules | each { |e|
    let assetsDir = $'($dest)/assets-($mount)-($e)'
    # 每次下载前先清空目录
    rm -rf $assetsDir; mkdir $'($assetsDir)/assets'
    let prefix = $entryConf | get $e | get prefix
    let dirname = $entryConf | get $e | get dirname
    print $'Download assets from (ansi p)($mount)/($JSON_ENTRY)(ansi rst) to (ansi p)($dest)(ansi rst) for (ansi pb)($e)(ansi rst)...'

    # Save manifest.json for subsequent upload via package-tools
    http get -r $'($assetUrlPrefix)/($prefix)/($dirname)/manifest.json'
      | save -rf $'($assetsDir)/manifest.json'

    let assets = open $'($assetsDir)/manifest.json' | get assets

    for a in $assets {
      let url = $'($assetUrlPrefix)/($prefix)/($dirname)/($a)'
      let assetPath = $'/($prefix)/($dirname)/($a)'
      if $quiet {
        http get -r $url | save -rfp $'($assetsDir)/($a)'
      } else {
        print $'Downloading ($url | ansi link --text $assetPath)'
        http get -r $url | save -rf $'($assetsDir)/($a)'
      }
    }

    print $'(ansi p)Assets for ($e) have been downloaded successfully!(ansi rst)'
    if not $quiet { hr-line }
  }
  print "All downloads finished! \n"
}

# Transfer static assets from OSS to OSS or Minio's other path
def transfer [
  modules: list,              # Module name or alias available values: pc, mobile, all, etc.
  latestMeta: record,         # Latest metadata
  to: string,
  --quiet(-q),                # Show less info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  let tmp = $'(get-tmp-path)/terp'
  if (not ($tmp | path exists)) { mkdir $tmp }

  let startTime = date now
  download $modules $latestMeta $tmp --quiet=$quiet
  print $'Start to transfer assets from (ansi p)($latestMeta.from) to ($dest_store) ($to)(ansi rst)'

  let ossConf = get-dest-oss $dest_store
  let type = $ossConf.TYPE? | default 'aliyun'
  let ak = $ossConf.OSS_AK? | default ''
  let sk = $ossConf.OSS_SK? | default ''
  let bucket = $ossConf.OSS_BUCKET? | default ''
  let region = $ossConf.OSS_REGION? | default ''
  let endpoint = $ossConf.OSS_ENDPOINT? | default ''
  let options = $ossConf.OSS_OPTIONS? | default '' | split row ' '
  let extra = if ($options | compact -e | is-empty) { [] } else { [-o ...$options] }

  let mount = $latestMeta.mountpoint
  for e in $modules {
    cd $'($tmp)/assets-($mount)-($e)'
    # Update namespace.json add transfer info
    update-transfer-meta $latestMeta
    for t in ($to | split row ',' | compact -e) {
      print $'Uploading (ansi p)($e)@($mount) to (ansi p)($t)(ansi rst) ...'
      if ($type | str trim | str downcase) in [minio, ifly] {
        package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t -s path ...$extra
      } else {
        package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t ...$extra
      }
    }
    print $'Assets (ansi p)($e)(ansi rst) have been transferred successfully!'
  }

  let endTime = date now
  print "All transfer finished! \n"
  print $"(ansi g)Total Time Cost: ($endTime - $startTime)(ansi rst)\n"

  print $"You can visit the latest.json from: \n"
  for t in ($to | split row ',' | compact -e) {
    let destUrl = match $type {
      'ifly' => $'($endpoint)/($bucket)/fe-resources/($t)/latest.json',
      'minio' => $'($endpoint)/($bucket)/fe-resources/($t)/latest.json',
      'volc' => $'https://($bucket).($region).volces.com/fe-resources/($t)/latest.json',
      'aliyun' => $'https://($bucket).($region).aliyuncs.com/fe-resources/($t)/latest.json',
    }
    print $"(ansi g)($destUrl)(ansi rst)"
  }
}

# Display front end module meta data
def detect [latestMeta: record] {
  const TIME_FMT = '%m/%d %H:%M:%S'
  print $'Latest metadata of (ansi g)($latestMeta.latestUrl)(ansi rst)'; hr-line 108
  let modules = $latestMeta.latest
    | values
    | select namespace deprecated? metadata?
    | upsert branch {|it| $it.metadata?.branch? | default '-' }
    | upsert SHA {|it| $it.metadata?.commitSha? | default '-' }
    | upsert buildAt {|it| if ($it.metadata?.buildAt? | is-empty) { '-' } else { $it.metadata.buildAt | format date $TIME_FMT } }
    | upsert syncBy {|it| $it.metadata?.syncBy? | show }
    | upsert syncFrom {|it| $it.metadata?.syncFrom? | default '-' }
    | upsert syncAt {|it| if ($it.metadata?.syncAt? | is-empty) { '-' } else { $it.metadata.syncAt | format date $TIME_FMT } }
    | reject -i metadata
    | sort-by namespace
    | rename module

  if ($modules | get deprecated? | compact | length) > 0 {
    $modules | print; hr-line -c grey30 118
  } else {
    $modules | reject deprecated | print; hr-line -c grey30 108
  }
  print $'Total modules: (ansi g)($modules | length)(ansi rst), Enabled: (ansi g)($modules | where deprecated? != true | length)(ansi rst), Deprecated modules: (ansi r)($modules | where deprecated? | length)(ansi rst)'
  let reverted = $latestMeta.latest | values | where {|it| $it.metadata?.revertAt? | is-not-empty }
  if ($reverted | length) > 0 {
    print $'(char nl)Module Revert Found:(char nl)'
    $reverted | select namespace metadata.revertBy metadata.revertAt
      | rename module revertBy revertAt | sort-by module
      | upsert revertBy {|it| $it.revertBy? | show } | print; print -n (char nl)
  }
}

# ***************************************************************************************
# ---------------------------------- Revert Helpers -----------------------------------
# ***************************************************************************************

# Check if the required tools are installed and validating args for module reverting
def revert-precheck [module: string, to: string, ossConf: record] {
  let type = $ossConf.TYPE? | default 'aliyun' | str downcase
  if $type not-in [minio, aliyun] {
    print -e $'The storage type (ansi r)($type)(ansi rst) is invalid for assets reverting. Supported types: (ansi g)($STORE_TYPES | str join ", ")(ansi rst)'
    exit $ECODE.INVALID_PARAMETER
  }

  let isMinio = $type == 'minio'
  if $module =~ ',' { print $'Revert frontend module is not supported for multiple modules yet'; exit $ECODE.INVALID_PARAMETER }
  if $isMinio and ($to !~ '@') {
    print $'To revert module in MINIO the `-t` option should be like `(ansi p)test@mc-alias(ansi rst)`'; exit $ECODE.INVALID_PARAMETER
  }
  if $to =~ '@' {
    if not $isMinio { print '`@` should not be used in `-t` / `--to` option for OSS storage'; exit $ECODE.INVALID_PARAMETER }
    let mcAlias = $to | split row @ | last
    if $mcAlias not-in (mc alias ls --json | from json -o | get alias) {
      print $'The specified mc alias (ansi p)($mcAlias)(ansi rst) does not exist, please check your mc config'; exit $ECODE.INVALID_PARAMETER
    }
    # Minio AK/SK/Endpoint check
    let mconf = mc alias ls --json | from json -o | where alias == $mcAlias | get 0
    if $mconf.accessKey != $ossConf.OSS_AK or $mconf.secretKey != $ossConf.OSS_SK or $mconf.URL != $ossConf.OSS_ENDPOINT {
      print -e $'The specified mc alias (ansi p)($mcAlias)(ansi rst) does not match the OSS config, please check your mc config'
      exit $ECODE.INVALID_PARAMETER
    }
  }

  let requiredTools = if $type == 'aliyun' { [fzf ossutil] } else { [fzf mc] }
  let missingTips = $requiredTools | reduce --fold [] {|it, acc|
      if not (is-installed $it) { $acc | append ($TOOL_INSTALL_TIP | get $it) } else { $acc }
    }
  if ($missingTips | length) > 0 {
    print $'The following tools are required for reverting frontend module:'; hr-line
    $missingTips | wrap Tips | table -t psql | print
    print -n (char nl); exit $ECODE.MISSING_BINARY
  }
}

# Select the revision to revert
def select-revert-revision [module: string, remoteURI: string, localPath: string, destStore: string, ossConf: record] {
  let isMinio = ($ossConf.TYPE? | default 'aliyun') == 'minio'
  let ossAuth = [-i $ossConf.OSS_AK -k $ossConf.OSS_SK -e $ossConf.OSS_ENDPOINT]
  let moduleRevisions = if $isMinio {
      mc ls $remoteURI --json | from json -o | where key =~ $'($module)-\d' | get key
    } else {
      ossutil ls ...$ossAuth $'($remoteURI)/' -d | lines | where $it =~ $'($remoteURI)/($module)-\d'
    }

  let title = $'Select the revision to apply:'
  let PREVIEW_CMD = $"nu actions/terp-assets.nu {} ($localPath) ($remoteURI) ($destStore)"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  $moduleRevisions | par-each { $in | str trim -c '/' | split row '/' | last } | sort -r | str join "\n"
    | fzf | complete | get stdout | str trim
}

# Execute the revert operation
def execute-revert [
  module: string,     # Module name to revert
  target: string,     # Target assets mount point
  destStore: string,  # Destination store
  revision: string,   # Revision to revert
  localPath: string,  # Local path
  remoteURI: string,  # Remote URI
  ossConf: record,    # OSS config
] {
  # Are you sure to revert to revision (ansi p)($revision)(ansi rst)? (y/n)
  print $'Attention: You are going to REVERT (ansi p)($module)(ansi rst) module to (ansi p)($revision) for ($target)@($destStore)(ansi rst)'
  hr-line; print $'(ansi grey66)Metadata Detail:(ansi rst)'
  mut meta = open $'($localPath)/($revision)/namespace.json' | get metadata
  if ($meta.syncBy? | is-not-empty) { $meta = $meta | upsert syncBy {|it| $it.syncBy? | show } }
  $meta | print; print -n (char nl)

  let dest = input $'Please confirm by typing (ansi r)($target)(ansi rst) to continue or (ansi p)q(ansi rst) to quit: '
  if $dest == 'q' { print $'Revert cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $dest != $target {
    print -e $'Your input (ansi p)($dest)(ansi rst) does not match (ansi p)($target)(ansi rst), bye...'; exit $ECODE.INVALID_PARAMETER
  }
  # Copy remote latest.json to local at the last moment to make sure the latest version is used
  let cpLatest = do-storage-cp $'($remoteURI)/latest.json' $localPath $ossConf --force
  if $cpLatest.exit_code != 0 {
    print -e $'Failed to copy latest.json from remote'
    print $cpLatest.stderr
    exit $cpLatest.exit_code
  }

  let revertAt = date now | format date $_TIME_FMT
  let revertBy = $env.DICE_OPERATOR_NAME? | default (git config --get user.name) | encode base64
  let revertMeta = { revertAt: $revertAt, revertBy: $revertBy }
  let moduleMeta = open $'($localPath)/($revision)/namespace.json' | upsert metadata {|it| $it.metadata | merge $revertMeta }
  let update = {} | upsert $module { prefix: $'fe-resources/($target)', dirname: $revision, ...$moduleMeta }
  let updated = open $'($localPath)/latest.json' | merge $update
  $updated | save -f $'($localPath)/latest.json'

  let sync = do-storage-cp $'($localPath)/latest.json' $'($remoteURI)/latest.json' $ossConf --force
  if $sync.exit_code == 0 {
    print $'Revert (ansi p)($module)(ansi rst) module to (ansi p)($revision) for ($target)@($destStore)(ansi rst) successful!'; exit $ECODE.SUCCESS
  }
  print -e $'Revert (ansi p)($module)(ansi rst) module to (ansi p)($revision) for ($target)@($destStore)(ansi rst) failed:'
  print $sync.stderr
}


# ***************************************************************************************
# ------------------------------ Storage Abstractions ---------------------------------
# ***************************************************************************************

# Copy assets from source to dest
def do-storage-cp [source: string, dest: string, ossConf: record, --force] {
  let type = $ossConf.TYPE? | default 'aliyun' | str downcase
  if $type == 'minio' {
    # mc doesn't have a global force flag for `cp`, quiet is `-q`
    mc cp -q $source $dest | complete
  } else {
    let auth = [-i $ossConf.OSS_AK -k $ossConf.OSS_SK -e $ossConf.OSS_ENDPOINT]
    let force_flag = if $force { ['--force'] } else { [] }
    ossutil cp ...$auth ...$force_flag $source $dest | complete
  }
}

# ***************************************************************************************
# --------------------------------- General Helpers -----------------------------------
# ***************************************************************************************

# Decode base64 encoded string, show default as `-`
def show [] { $in | default 'LQ==' | decode base64 | decode }

# Format module descriptions for display
def format-desc [] {
  let desc = $in
  $desc | split column : | rename m d
    | upsert desc {|it| $'(ansi p)($it.m | fill -w 15)(ansi rst):($it.d)'}
    | get desc.0
}

# Get valid modules from input and exit if any invalid module is found
def get-modules [modules?: string, --latest-meta: record, --action: string] {

  let descriptions = $MOD_DESC | columns
    | reduce --fold {} {|it, acc| $acc | merge { $it: ($MOD_DESC | get $it | format-desc) } }

  # Choose modules from latest.json if modules is empty
  let allModules = $latest_meta.latest | columns | wrap mod
    | upsert desc {|it| $descriptions | get -o $it.mod | default $it.mod }
    | sort-by mod
  if $action == 'detect' { return $allModules }
  if ($modules | is-empty) {
    print $'No module specified, please select the modules manually...'; hr-line
    let tips = $"Select the modules to sync or download ($KEY_MAPPING)"
    let selected = $allModules | input list -d desc --multi $tips | default [] | get mod
    if ($selected | is-empty) { print $'You have not selected any modules, bye...'; exit $ECODE.SUCCESS }
    return $selected
  }

  # Sync all modules if 'all' is specified
  if $modules == 'all' { return ($allModules | get mod) }

  # Validate and sync specified modules
  let splits = $modules | default '' | split row ',' | compact -e
  if ($splits | length) > 0 {
    let inexists = $splits | where {|it| $it not-in ($allModules | get mod) }
    if ($inexists | length) > 0 {
      print -e $'Invalid modules (ansi r)($inexists | str join ",")(ansi rst), the modules you specified do not exist in latest.json(ansi rst)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  $splits
}

# Get latest.json from specified mount point
def get-latest-meta [from: string] {
  let isFullUrl = $from | str ends-with $'/($JSON_ENTRY)'
  let fromUrl = if $isFullUrl { $from } else { $'($ENDPOINT)/fe-resources/($from)/($JSON_ENTRY)' }
  let latest = http get $fromUrl
  let mount = $latest | values | first | get prefix | str replace fe-resources/ ''
  let modules = $latest | columns
  let validModules = {|mods, validMods| $mods | all {|m| $m in $validMods } }
  let validateModules = if (($env.VALIDATE_MODULES? | default $VALIDATE_MODULES) == '0') { false } else { true }
  let validationPassed = (do $validModules $modules $VALID_MODULES)
  if (not $validateModules) or ($validateModules and $validationPassed) {
    return { from: $from, latestUrl: $fromUrl, mountpoint: $mount, latest: $latest }
  }
  print -e $'The latest.json from (ansi p)($fromUrl)(ansi rst) contains invalid modules, module list:'
  print -e $'($modules | str join ", ")'
  exit $ECODE.INVALID_PARAMETER
}

# Add transfer metadata to namespace.json and latest.json
def update-transfer-meta [latestMeta: record] {
  let syncBy = $env.DICE_OPERATOR_NAME? | default (git config --get user.name) | encode base64
  let syncAt = date now | format date $_TIME_FMT
  let syncFrom = if ($latestMeta.from =~ 'latest.json') {
    $latestMeta.from | split row '/' | last 2 | first } else { $latestMeta.from }
  let syncMeta = { syncBy: $syncBy, syncFrom: $syncFrom, syncAt: $syncAt }
  mut ns = open namespace.json | upsert metadata {|it| $it.metadata? | default {} | merge $syncMeta }
  # Keep module deprecated status
  if ((($latestMeta.latest | get $ns.namespace).deprecated? | default false | into string) == 'true') { $ns.deprecated = true }
  $ns | save -f namespace.json
}

# Get destination OSS settings
def --env get-dest-oss [destStore: string] {
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
  let ossConf = open $LOCAL_CONFIG | from toml | get -o $destStore
  if ($ossConf | is-empty) {
    print -e $'The storage you specified (ansi p)($destStore)(ansi rst) does not exist in (ansi p)($LOCAL_CONFIG)(ansi rst).'
    exit $ECODE.INVALID_PARAMETER
  }
  if ($ossConf.TYPE? | is-not-empty) and ($ossConf.TYPE? not-in $STORE_TYPES) {
    print -e $'The storage type (ansi r)($ossConf.TYPE)(ansi rst) is invalid. Supported types: (ansi g)($STORE_TYPES | str join ", ")(ansi rst)'
    exit $ECODE.INVALID_PARAMETER
  }
  $ossConf
}

# Check if it's a valid action, and if the required tools are installed.
def pre-check [
  action: string,
  --to(-t): string,          # Destination
  --dest-store(-d): string,  # Destination store, should be configured in .termixrc
] {
  if $action not-in $VALID_ACTIONS {
    print -e $'Invalid action ($action), supported actions: ($VALID_ACTIONS | str join ", ")'
    exit $ECODE.INVALID_PARAMETER
  }
  if not (is-installed package-tools) {
    print -e $'Please install package-tools by (ansi g)`npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io`(ansi rst) first.'
    exit $ECODE.MISSING_BINARY
  }
  let ver = package-tools -v
  let minPkgToolsVer = get-conf minPkgToolVer
  let compVer = compare-ver $ver $minPkgToolsVer
  if $compVer < 0 {
    print -e $'Only package-tools (ansi r)($minPkgToolsVer)(ansi rst) or above is supported. Please reinstall it by:'
    print $'(ansi g)npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io (ansi rst)(char nl)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
  if $action == 'transfer' and (($to | is-empty) or ($dest_store | is-empty)) {
    if ($to | is-empty) {
      print -e $'Please specify the destination to transfer by (ansi p)--to(ansi rst) option.'
    }
    if ($dest_store | is-empty) {
      print -e $'Please specify the destination store to transfer by (ansi p)--dest-store(ansi rst) option.'
    }
    exit $ECODE.INVALID_PARAMETER
  }
}

# Confirm before the transfer action
def confirm-action [
  action: string,
  modules: list,
  --to(-t): string,          # Destination
  --dest-store(-d): string,  # Destination store, should be configured in .termixrc
] {
  if $action != 'transfer' { return }

  get-dest-oss $dest_store
  print $'Attention: You are going to TRANSFER (ansi p)($modules | str join ",")(ansi rst) assets to (ansi p)($to)@($dest_store)(ansi rst)'; hr-line
  let dest = input $'Please confirm by typing (ansi r)($to)(ansi rst) to continue or (ansi p)q(ansi rst) to quit: '
  if $dest == 'q' { print $'Transfer cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $dest != $to {
    print -e $'Your input (ansi p)($dest)(ansi rst) does not match (ansi p)($to)(ansi rst), bye...'; exit $ECODE.INVALID_PARAMETER
  }
}
