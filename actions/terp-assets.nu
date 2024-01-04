#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/11/17 22:06:56
# [x] Download static assets listed in latest.json
# [x] Download static assets to specified dir
# [x] Upload static assets to minio
# [x] Support download assets for specified end, multi ends separated by `,`
# [x] `--from` support full latest.json url
# [x] Handle assets for t-material-ui and t-mobile-ui
# [x] Transfer 命令执行前需要确认，减少误操作的可能性
# [ ] Sync assets in minio from one dir to another
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

use ../utils/common.nu [is-installed, hr-line, get-tmp-path, compare-ver, _TIME_FMT]

const JSON_ENTRY = 'latest.json'
const VALID_ACTIONS = ['download', 'transfer']
const VALID_END = ['pc', 'mobile', 'mat', 'mmat', 'dors', 'mdors', 'iam', 'all']
const ENDPOINT = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com'

const PKG_TOOLS_VER = '0.3.0-beta.1'

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
  action: string,             # Available actions: download, transfer, sync
  end: string,                # Available values: pc/mobile/mat/mmat/iam/dors/mdors/all. Multiple ends separated by `,`
  --from(-f): string,         # Source mount point or source URL
  --to(-t): string,           # Dest mount point
  --verbose(-v),              # Show verbose info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  pre-check $action $end --to $to --dest-store $dest_store
  let ends = get-ends $end

  match $action {
    'download' => { download $ends $from $to --verbose=$verbose },
    'transfer' => { transfer $ends $from $to --dest-store $dest_store --verbose=$verbose },
  }
}

def get-ends [end: string] {
  if $end == 'all' {
    $VALID_END | where $it != 'all'
  } else {
    let splits = ($end | split row ',')
    let invalid = ($splits | filter {|it| $it not-in $VALID_END })
    if ($invalid | length) > 0 {
      echo $'Invalid end ($invalid | str join ", "), supported end: ($VALID_END | str join ", ")'
      exit 7
    }
    $splits | filter {|it| $it in $VALID_END }
  }
}

# Check if it's a valid action, and if the required tools are installed.
def pre-check [
  action: string,
  end: string,
  --to(-t): string,          # Destination
  --dest-store(-d): string,  # Destination store, should be configured in .termixrc
] {
  if $action not-in $VALID_ACTIONS {
    echo $'Invalid action ($action), supported actions: ($VALID_ACTIONS | str join ", ")'
    exit 7
  }
  get-ends $end
  if not (is-installed package-tools) {
    echo 'Please install package-tools by `npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io` first.'
    exit 2
  }
  let ver = (package-tools -v)
  let compVer = (compare-ver $ver $PKG_TOOLS_VER)
  if $compVer < 0 {
    echo $'Only package-tools ($PKG_TOOLS_VER) or above is supported by this tool. Please reinstall it.'
    exit 2
  }
  if $action == 'transfer' and (($to | is-empty) or ($dest_store | is-empty)) {
    if ($to | is-empty) {
      echo $'Please specify the dest to transfer by (ansi p)--to(ansi reset) option.'
    }
    if ($dest_store | is-empty) {
      echo $'Please specify the dest store to transfer by (ansi p)--dest-store(ansi reset) option.'
    }
    exit 7
  }
  if $action == 'transfer' {
    let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
    let ossConf = open $LOCAL_CONFIG | from toml | get -i $dest_store
    if ($ossConf | is-empty) {
      echo $'The storage you specified (ansi p)($dest_store)(ansi reset) does not exist in (ansi p)($LOCAL_CONFIG)(ansi reset).'
      exit 7
    }

    print $'Attention: You are going to TRANSFER (ansi p)($end)(ansi reset) assets to (ansi p)($to)@($dest_store)(ansi reset)'; hr-line
    let dest = input $'Please confirm by typing (ansi r)($to)(ansi reset) to continue or (ansi p)q(ansi reset) to quit: '
    if $dest == 'q' { echo $'Transfer cancelled, Bye...'; exit 0 }
    if $dest != $to {
      echo $'You input (ansi p)($dest)(ansi reset) does not match (ansi p)($to)(ansi reset), bye...'; exit 7
    }
  }
}

# Download static assets from OSS to specified directory
def download [
  end: list,            # End point, available values: pc, mobile, all
  from: string,
  to: string,
  --verbose(-v),        # Show verbose info
] {

  let tmp = $'(get-tmp-path)/terp'
  if (not ($tmp | path exists)) { mkdir $tmp }
  let dest = if ($to | is-empty) or (not ($to | path exists)) {
      $tmp
    } else { ($to | path expand) }
  let isFullUrl = ($from | str ends-with $'/($JSON_ENTRY)')
  let fromUrl = if $isFullUrl { $from } else { $'($ENDPOINT)/fe-resources/($from)/($JSON_ENTRY)' }
  let assetUrlPrefix = if $isFullUrl { $from | split row '/fe-resources' | get 0 } else { $ENDPOINT }
  let mount = $fromUrl
    | parse $'{base_url}/fe-resources/{mount}/($JSON_ENTRY)' | get mount | get 0
  let entry = $'($dest)/latest-($mount).json'
  http get $fromUrl | save -f $entry
  let entryConf = open $entry

  # Download assets for each end point
  $end | each { |e|
    let endKey = $END_KEY_MAP | get $e
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
  end: list,                  # End point, available values: pc, mobile, all
  from: string,
  to: string,
  --verbose(-v),              # Show verbose info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  let tmp = $'(get-tmp-path)/terp'
  if (not ($tmp | path exists)) { mkdir $tmp }
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }

  download $end $from $tmp --verbose=$verbose
  echo $'Start to transfer assets from (ansi p)($from) to ($dest_store) ($to)(ansi reset)'

  let ossConf = open $LOCAL_CONFIG | from toml | get -i $dest_store
  let type = $ossConf | get -i TYPE | default 'aliyun'
  let ak = $ossConf | get -i OSS_AK | default ''
  let sk = $ossConf | get -i OSS_SK | default ''
  let bucket = $ossConf | get -i OSS_BUCKET | default ''
  let region = $ossConf | get -i OSS_REGION | default ''
  let endpoint = $ossConf | get -i OSS_ENDPOINT | default ''

  let fromUrl = if ($from | str ends-with $'/($JSON_ENTRY)') {
      $from
    } else {
      $'($ENDPOINT)/fe-resources/($from)/($JSON_ENTRY)'
    }
  let mount = $fromUrl
    | parse $'{base_url}/fe-resources/{mount}/($JSON_ENTRY)' | get mount | get 0
  for e in $end {
    cd $'($tmp)/assets-($mount)-($e)'
    # Update namespace.json add transfer info
    update-transfer-meta $from
    if ($type | str trim | str downcase) == 'minio' {
      package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $to -s path
    } else {
      package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $to
    }
    echo $'Assets for (ansi p)($e)(ansi reset) transferred successfully!'
  }
  echo "All transfer finished! \n"
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
