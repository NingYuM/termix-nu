#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/11/17 22:06:56
# [√] Download static assets listed in latest.json
# [√] Download static assets to specified dir
# [√] Upload static assets to minio
# [√] Support download assets for specified end, multi ends separated by `,`
# [√] `--from` support full latest.json url
# [√] Handle assets for t-material-ui and t-mobile-ui
# [√] Transfer 命令执行前需要确认，减少误操作的可能性
# [√] Sync modules by full name
# [√] Validate module names from latest.json support
# [√] Ignore new modules while transferring `all` assets support
# [√] Get available modules from latest.json if sync all is selected
# [√] Display front end module meta data
# [√] Display module status statistics info in meta data view
# Ref:
#   - https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json
#   - http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-test/latest.json
#   - https://min.io/docs/minio/linux/reference/minio-mc/mc-cp.html
#   - https://docs.erda.cloud/2.2/manual/dop/guides/reference/pipeline.html
#   - https://www.alibabacloud.com/help/zh/oss/developer-reference/install-ossutil#dda54a7096xfh
# Usage:
#   t ta detect -f dev
#   t ta detect -f https://public-go1688-trantor-noprod.oss-cn-hangzhou.aliyuncs.com/fe-resources/csp-test/latest.json
#   t ta download all -f dev
#   t ta download pc --from <mode> --to <dir>
#   t ta transfer pc --from <oss-mode> --to <minio-mode>
#   t ta transfer all -f dev -v -d oss -t ttt0
#   t ta transfer all --from dev --to ttt0 --dest-store oss --verbose
#   t ta transfer all --from foran --to fs-test --dest-store fsmio -v

use ../utils/common.nu [ECODE, is-installed, hr-line, get-tmp-path, compare-ver, _TIME_FMT]

const KEY_MAPPING = $"(ansi grey66)\(Space: Select, a: Select All, ESC/q: Quit, Enter: Confirm\)(ansi reset)"
const JSON_ENTRY = 'latest.json'
const VALID_ACTIONS = ['download', 'transfer', 'detect']
const VALID_MODULES = [terp-mobile terp service service-mobile iam dors dors-mobile base base-mobile b2b emp]
const ENDPOINT = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com'

# Front end module and descriptions
const MOD_DESC = {
    b2b: 'b2b: B2B & SRM 自定义业务组件'
    base: 'base: PC 端设计器基础组件'
    base-mobile: 'base-mobile: 移动端设计器基础组件'
    dors: 'dors: PC 端报表搭建组件'
    dors-mobile: 'dors-mobile: 移动端报表搭建组件'
    emp: 'emp: EMP 自定义业务组件'
    iam: 'iam: IAM 登录注册相关基础组件'
    service: 'service: PC 端审批/通知/日志/导入导出/打印等基础组件'
    service-mobile: 'service-mobile: 移动端审批/通知等基础组件'
    terp: 'terp: TERP PC 端业务组件'
    terp-mobile: 'terp-mobile: TERP 移动端业务组件'
  }

# Don't validate module names by default
const VALIDATE_MODULES = '0'
const PKG_TOOLS_VER = '0.3.0-beta.1'

# Download TERP static assets or transfer assets to other path of the specified cloud storage
export def 'terp assets' [
  action: string,             # Available actions: download, transfer
  modules?: string,           # Available values: pc/mobile/mat/mmat/iam/dors/mdors/all. Multiple modules separated by `,`
  --from(-f): string,         # Source mount point or source URL
  --to(-t): string,           # Destination mount point
  --verbose(-v),              # Show verbose info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  pre-check $action --to $to --dest-store $dest_store
  let latestMeta = get-latest-meta $from
  let modules = get-modules $modules --latest-meta $latestMeta --action $action
  confirm-action $action $modules --to $to --dest-store $dest_store

  match $action {
    'detect' => { detect $latestMeta },
    'download' => { download $modules $latestMeta $to --verbose=$verbose },
    'transfer' => { transfer $modules $latestMeta $to --dest-store $dest_store --verbose=$verbose },
  }
}

# Format module descriptions for display
def format-desc [] {
  let desc = $in
  $desc | split column : | rename m d
    | upsert desc {|it| $'(ansi p)($it.m | fill -w 15)(ansi reset):($it.d)'}
    | get desc.0
}

# Get valid modules from input and exit if any invalid module is found
def get-modules [modules?: string, --latest-meta: record, --action: string] {

  let descriptions = $MOD_DESC | columns
    | reduce --fold {} {|it, acc| $acc | merge { $it: ($MOD_DESC | get $it | format-desc) } }

  # Choose modules from latest.json if modules is empty
  let allModules = $latest_meta.latest | columns | wrap mod
    | upsert desc {|it| $descriptions | get -i $it.mod | default $it.mod }
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
  if $modules == 'all' { return $allModules }

  # Validate and sync specified modules
  let splits = $modules | default '' | split row ','
  if ($splits | length) > 0 {
    let inexists = $splits | filter {|it| $it not-in ($allModules | get mod) }
    if ($inexists | length) > 0 {
      print $'Invalid modules (ansi r)($inexists | str join ",")(ansi reset), the module you specified does not exists in latest.json(ansi reset)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  $splits
}

# Get latest.json from specified mount point
def get-latest-meta [from: string] {
  let isFullUrl = $from | str ends-with $'/($JSON_ENTRY)'
  let fromUrl = if $isFullUrl { $from } else { $'($ENDPOINT)/fe-resources/($from)/($JSON_ENTRY)' }
  let mount = $fromUrl
    | parse $'{base_url}/fe-resources/{mount}/($JSON_ENTRY)' | get mount | get 0
  let latest = http get $fromUrl
  let modules = $latest | columns
  let validModules = {|mods, validMods| $mods | all {|m| $m in $validMods } }
  let validateModules = if (($env.VALIDATE_MODULES? | default $VALIDATE_MODULES) == '0') { false } else { true }
  let validationPassed = (do $validModules $modules $VALID_MODULES)
  if (not $validateModules) or ($validateModules and $validationPassed) {
    return { from: $from, latestUrl: $fromUrl, mountpoint: $mount, latest: $latest }
  }
  print $'The latest.json from (ansi p)($fromUrl)(ansi reset) contains invalid modules, module list:'
  print $'($modules | str join ", ")'
  exit $ECODE.INVALID_PARAMETER
}

# Get dest OSS settings
def --env get-dest-oss [destStore: string] {
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
  let ossConf = open $LOCAL_CONFIG | from toml | get -i $destStore
  if ($ossConf | is-empty) {
    print $'The storage you specified (ansi p)($destStore)(ansi reset) does not exist in (ansi p)($LOCAL_CONFIG)(ansi reset).'
    exit $ECODE.INVALID_PARAMETER
  }
  return $ossConf
}

# Check if it's a valid action, and if the required tools are installed.
def pre-check [
  action: string,
  --to(-t): string,          # Destination
  --dest-store(-d): string,  # Destination store, should be configured in .termixrc
] {
  if $action not-in $VALID_ACTIONS {
    print $'Invalid action ($action), supported actions: ($VALID_ACTIONS | str join ", ")'
    exit $ECODE.INVALID_PARAMETER
  }
  if not (is-installed package-tools) {
    print 'Please install package-tools by `npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io` first.'
    exit $ECODE.MISSING_BINARY
  }
  let ver = package-tools -v
  let compVer = compare-ver $ver $PKG_TOOLS_VER
  if $compVer < 0 {
    print $'Only package-tools ($PKG_TOOLS_VER) or above is supported by this tool. Please reinstall it.'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
  if $action == 'transfer' and (($to | is-empty) or ($dest_store | is-empty)) {
    if ($to | is-empty) {
      print $'Please specify the dest to transfer by (ansi p)--to(ansi reset) option.'
    }
    if ($dest_store | is-empty) {
      print $'Please specify the dest store to transfer by (ansi p)--dest-store(ansi reset) option.'
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
  print $'Attention: You are going to TRANSFER (ansi p)($modules | str join ",")(ansi reset) assets to (ansi p)($to)@($dest_store)(ansi reset)'; hr-line
  let dest = input $'Please confirm by typing (ansi r)($to)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
  if $dest == 'q' { print $'Transfer cancelled, Bye...'; exit $ECODE.SUCCESS }
  if $dest != $to {
    print $'You input (ansi p)($dest)(ansi reset) does not match (ansi p)($to)(ansi reset), bye...'; exit $ECODE.INVALID_PARAMETER
  }
}

# Download static assets from OSS to specified directory
def download [
  modules: list,        # End point, available values: pc, mobile, all
  latestMeta: record,   # Latest meta info
  to?: string,          # Destination dir
  --verbose(-v),        # Show verbose info
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
    print $'Download assets from (ansi p)($mount)/($JSON_ENTRY)(ansi reset) to (ansi p)($dest)(ansi reset) for (ansi pb)($e)(ansi reset)...'

    # 保存 manifest.json 以便后续通过 package-tools 上传
    http get -r $'($assetUrlPrefix)/($prefix)/($dirname)/manifest.json'
      | save -rf $'($assetsDir)/manifest.json'

    let assets = open $'($assetsDir)/manifest.json' | get assets

    for a in $assets {
      let url = $'($assetUrlPrefix)/($prefix)/($dirname)/($a)'
      let assetPath = $'/($prefix)/($dirname)/($a)'
      if $verbose {
        print $'Downloading ($url | ansi link --text $assetPath)'
        http get -r $url | save -rfp $'($assetsDir)/($a)'
      } else {
        http get -r $url | save -rf $'($assetsDir)/($a)'
      }
    }

    print $'(ansi p)Assets for ($e) have been downloaded successfully!(ansi reset)'
    if $verbose { hr-line }
  }
  print "All downloads finished! \n"
}

# Transfer static assets from OSS to OSS or Minio's other path
def transfer [
  modules: list,              # Module name or alias available values: pc, mobile, all, etc.
  latestMeta: record,         # Latest meta info
  to: string,
  --verbose(-v),              # Show verbose info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  let tmp = $'(get-tmp-path)/terp'
  if (not ($tmp | path exists)) { mkdir $tmp }

  let startTime = date now
  download $modules $latestMeta $tmp --verbose=$verbose
  print $'Start to transfer assets from (ansi p)($latestMeta.from) to ($dest_store) ($to)(ansi reset)'

  let ossConf = get-dest-oss $dest_store
  let type = $ossConf.TYPE? | default 'aliyun'
  let ak = $ossConf.OSS_AK? | default ''
  let sk = $ossConf.OSS_SK? | default ''
  let bucket = $ossConf.OSS_BUCKET? | default ''
  let region = $ossConf.OSS_REGION? | default ''
  let endpoint = $ossConf.OSS_ENDPOINT? | default ''

  let mount = $latestMeta.mountpoint
  let fromUrl = $latestMeta.latestUrl
  for e in $modules {
    cd $'($tmp)/assets-($mount)-($e)'
    # Update namespace.json add transfer info
    update-transfer-meta $latestMeta
    for t in ($to | split row ',') {
      print $'Uploading (ansi p)($e)@($mount) to (ansi p)($t)(ansi reset)...'
      if ($type | str trim | str downcase) == 'minio' {
        package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t -s path
      } else {
        package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t
      }
    }
    print $'Assets (ansi p)($e)(ansi reset) have been transferred successfully!'
  }

  let endTime = date now
  print "All transfer finished! \n"
  print $"(ansi g)Total Time Cost: ($endTime - $startTime)(ansi reset)\n"

  print $"You can visit the latest.json from: \n"
  for t in ($to | split row ',') {
    let destUrl = match $type {
      'minio' => $'($endpoint)/($bucket)/fe-resources/($t)/latest.json',
      'aliyun' => $'https://($bucket).($region).aliyuncs.com/fe-resources/($t)/latest.json',
    }
    print $"(ansi g)($destUrl)(ansi reset)"
  }
}

# Add transfer metadata to namespace.json and latest.json
def update-transfer-meta [latestMeta: record] {
  let syncBy = $env.DICE_OPERATOR_NAME? | default (git config --get user.name) | encode base64
  let syncAt = (date now | format date $_TIME_FMT)
  let syncFrom = if ($latestMeta.from =~ 'latest.json') {
    $latestMeta.from | split row '/' | last 2 | first } else { $latestMeta.from }
  let syncMeta = { syncBy: $syncBy, syncFrom: $syncFrom, syncAt: $syncAt }
  mut ns = open namespace.json | upsert metadata {|it| $it.metadata? | default {} | merge $syncMeta }
  # Keep module deprecated status
  if ((($latestMeta.latest | get $ns.namespace).deprecated? | into string) == 'true') { $ns.deprecated = true }
  $ns | save -f namespace.json
}

# Display front end module meta data
def detect [latestMeta: record] {
  const TIME_FMT = '%m/%d %H:%M:%S'
  print $'Latest meta of (ansi g)($latestMeta.latestUrl)(ansi reset)'; hr-line 108
  let modules = $latestMeta.latest
    | values
    | select namespace deprecated? metadata?
    | upsert branch {|it| $it.metadata?.branch? | default '-' }
    | upsert SHA {|it| $it.metadata?.commitSha? | default '-' }
    | upsert buildAt {|it| if ($it.metadata?.buildAt? | is-empty) { '-' } else { $it.metadata.buildAt | format date $TIME_FMT } }
    | upsert syncBy {|it| $it.metadata?.syncBy? | default 'LQ==' | decode base64 }
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
  print $'Total modules: (ansi g)($modules | length)(ansi reset), Enabled: (ansi g)($modules | where deprecated? != true | length)(ansi reset), Deprecated modules: (ansi r)($modules | where deprecated? | length)(ansi reset)'
}

alias main = terp assets
