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
# [√] Get available modules from latest.json if sync all is selected
# Ref:
#   - https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json
#   - http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-test/latest.json
#   - https://min.io/docs/minio/linux/reference/minio-mc/mc-cp.html
#   - https://docs.erda.cloud/2.2/manual/dop/guides/reference/pipeline.html
#   - https://www.alibabacloud.com/help/zh/oss/developer-reference/install-ossutil#dda54a7096xfh
# Usage:
#   t ta download all -f dev
#   t ta download pc --from <mode> --to <dir>
#   t ta transfer pc --from <oss-mode> --to <minio-mode>
#   t ta transfer all -f dev -v -d oss -t ttt0
#   t ta transfer all --from dev --to ttt0 --dest-store oss --verbose
#   t ta transfer all --from foran --to fs-test --dest-store fsmio -v

use ../utils/common.nu [ECODE, is-installed, hr-line, get-tmp-path, compare-ver, _TIME_FMT]

const JSON_ENTRY = 'latest.json'
const VALID_ACTIONS = ['download', 'transfer']
const MODULE_ALIASES = ['pc', 'mobile', 'mat', 'mmat', 'dors', 'mdors', 'iam', 'all']
const VALID_MODULES = [t-runtime-mobile-erp t-runtime-erp iam-features dors-page dors-mobile t-material t-mobile t-b2b-ui emp-frontend-erp]
const NEXT_VALID_MODULES = [terp-mobile terp service service-mobile iam dors dors-mobile base base-mobile b2b emp]
const ENDPOINT = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com'

# Don't validate module names by default
const VALIDATE_MODULES = '0'
const PKG_TOOLS_VER = '0.3.0-beta.1'

# Module alias to real module name (Before module renamed)
const END_KEY_MAP = {
  mmat: 't-mobile',
  mat: 't-material',
  dors: 'dors-page',
  mdors: 'dors-mobile',
  iam: 'iam-features',
  pc: 't-runtime-erp',
  mobile: 't-runtime-mobile-erp',
}

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
  let modules = get-modules $modules --latest-meta $latestMeta
  confirm-action $action $modules --to $to --dest-store $dest_store

  match $action {
    'download' => { download $modules $latestMeta $to --verbose=$verbose },
    'transfer' => { transfer $modules $latestMeta $to --dest-store $dest_store --verbose=$verbose },
  }
}

# Get valid modules from input and exit if any invalid module is found
def get-modules [modules?: string, --latest-meta: record] {
  # Choose modules from latest.json if modules is empty
  let allModules = $latest_meta.latest | columns | sort
  if ($modules | is-empty) {
    print $'No module specified, please select the modules manually...'; hr-line
    let tips = $"Select the modules to sync or download (ansi grey66)\(space to select, esc or q to quit, enter to confirm\)(ansi reset)"
    let selected = $allModules | input list --multi $tips
    if ($selected | is-empty) {
      print $'You have not selected any modules, bye...'
      exit $ECODE.SUCCESS
    }
    return $selected
  }

  # Sync all modules if 'all' is specified
  if $modules == 'all' { return $allModules }

  # Validate and sync specified modules
  let splits = $modules | split row ','
  let validAliases = $splits | filter {|it| $it in $MODULE_ALIASES }
  if ($validAliases | length) > 0 {
    let unexists = $validAliases | filter {|it| ($END_KEY_MAP | get -i $it) not-in $allModules }
    if ($unexists | length) > 0 {
      print $'Invalid modules (ansi r)($unexists | str join ",")(ansi reset), the module you specified does not exists in latest.json(ansi reset)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
  let filterAlias = $splits | filter {|it| $it not-in $MODULE_ALIASES }
  let invalid = $filterAlias | filter {|it| $it not-in $allModules }
  if ($invalid | length) > 0 {
    print $'Invalid modules (ansi r)($invalid | str join ",")(ansi reset), available module aliases: (ansi g)($MODULE_ALIASES | str join ",")(ansi reset)'
    print $'And all available modules: (ansi g)($allModules | str join ",")(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  $splits | filter {|it| $it in [...$MODULE_ALIASES, ...$allModules] }
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
  let validationPassed = (do $validModules $modules $VALID_MODULES) or (do $validModules $modules $NEXT_VALID_MODULES)
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
    # Real module name has higher priority than alias
    let endKey = if ($e in $latestMeta.latest) { $e } else { $END_KEY_MAP | get -i $e | default $e }
    let assetsDir = $'($dest)/assets-($mount)-($e)'
    # 每次下载前先清空目录
    rm -rf $assetsDir; mkdir $'($assetsDir)/assets'
    let prefix = $entryConf | get $endKey | get prefix
    let dirname = $entryConf | get $endKey | get dirname
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
    update-transfer-meta $latestMeta.from
    if ($type | str trim | str downcase) == 'minio' {
      package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $to -s path
    } else {
      package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $to
    }
    print $'Assets for (ansi p)($e)(ansi reset) transferred successfully!'
  }
  print "All transfer finished! \n"

  let destUrl = $fromUrl | str replace $'/($mount)/' $'/($to)/'
  print $"You can visit the latest.json from: ($destUrl)\n"
}

# Add transfer metadata to namespace.json and latest.json
def update-transfer-meta [from: string] {
  let syncBy = $env.DICE_OPERATOR_NAME? | default (git config --get user.name) | encode base64
  let syncAt = (date now | format date $_TIME_FMT)
  let syncMeta = { syncBy: $syncBy, syncFrom: $from, syncAt: $syncAt }
  open namespace.json
    | upsert metadata {|it| $it.metadata? | default {} | merge $syncMeta }
    | save -f namespace.json
}

alias main = terp assets
