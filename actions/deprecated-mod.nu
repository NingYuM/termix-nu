# Usage:
#   IGNORE_NEW_MODULES=0 t ta transfer all -f dev -t ttt0 --dest-store oss -v
#   t mod ttt0 -s mmio -v
#   t mod ttt0 -s mmio -a me -dm pax
#   t mod ttt0 -s mmio -a me -em iam
#   t mod ttt0 -s mmio -a me -dm t-mobile,t-runtime-erp,t-runtime-mobile-erp
#   t mod ttt0 -s mmio -a me -m t-material,t-mobile
#   nu run/deprecated-mod.nu ttt0 t-material,t-mobile,iam-features,dors-page,t-runtime-erp,t-runtime-mobile-erp
#   http get https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/ttt0/latest.json | values | where deprecated? == true | get namespace
# REF:
#   - https://help.aliyun.com/zh/oss/developer-reference/install-ossutil
# TODO:
#   [✓] Ignore inexist modules while deprecating
#   [✓] Enable/Deprecated frontend modules by mount point and module names
#   [✓] View Package status
#   [✓] Remove modules by name support
#   [✓] Support none default oss bucket
#   [ ] Confirm the action detail before doing anything
#   [✓] Add minio storage support
#

use ../utils/common.nu [hr-line, ECODE]

# Deprecated or enable frontend modules by mount point and module names
export def deprecated-modules [
  mountPoint: string,          # OSS mount point: dev, terp-test, 2.5.24.0330, etc.
  --mods(-m): string,          # Frontend module name, multiple modules should be separated by `,`
  --delete(-d),                # Remove the specified modules
  --enable(-e),                # Enable the specified modules
  --view(-v),                  # View the modules and deprecate status of the specified mount point
  --mode: string,              # Output table mode: markdown, psql, compact, light
  --minio-alias(-a): string,   # Minio alias of the storage
  --dest-store(-s): string = 'oss' # Destination store alias of the static assets storage, default is oss
] {

  let ossConf = get-dest-oss $dest_store
  let type = $ossConf.TYPE? | default 'aliyun'
  let ak = $ossConf.OSS_AK? | default ''
  let sk = $ossConf.OSS_SK? | default ''
  let bucket = $ossConf.OSS_BUCKET? | default ''
  let region = $ossConf.OSS_REGION? | default ''
  let endpoint = $ossConf.OSS_ENDPOINT? | default ''

  # markdown, psql, compact, light
  $env.config.table.mode = ($mode | default 'psql')
  let dest = $'($env.TERMIX_DIR)/tmp/latest.json'
  let source = $'oss://($bucket)/fe-resources/($mountPoint)/latest.json'
  let destUrl = match $type {
      'minio' => $'($endpoint)/($bucket)/fe-resources/($mountPoint)/latest.json',
      'aliyun' => $'https://($bucket).($region).aliyuncs.com/fe-resources/($mountPoint)/latest.json',
    }
  if ($view) { view-modules $destUrl }
  if not $view and ($mods | is-empty) { print $'(ansi grey66)Nothing to do, Bye...(ansi reset)'; exit 0 }

  print $'You are going to deprecated (ansi r)($mods)(ansi reset) at (ansi g)($mountPoint)(ansi reset):'
  if $type == 'aliyun' { ossutil cp -i $ak -k $sk --force $source $dest | ignore }
  if $type == 'minio' and ($minio_alias | is-empty) {
    print $'(ansi red)Minio alias is not specified, please use --minio-alias to specify the alias.(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  if $type == 'minio' and ($minio_alias | is-not-empty) {
    mc cp --quiet $'($minio_alias)/($bucket)/fe-resources/($mountPoint)/latest.json' $dest
  }
  let modules = $mods | split row ','
  mut latest = open $dest
  for m in $modules {
    if $m not-in $latest { continue }
    if $delete { $latest = ($latest | reject -o $m); continue }
    if $enable {
      $latest = ($latest | reject -o ([$m deprecated] | into cell-path))
      continue
    }
    $latest = ($latest | upsert ([$m deprecated] | into cell-path) true)
  }
  $latest | save -f $dest
  if $type == 'aliyun' { ossutil cp -i $ak -k $sk --force $dest $source | ignore }
  if $type == 'minio' and ($minio_alias | is-not-empty) {
    mc cp --quiet $dest $'($minio_alias)/($bucket)/fe-resources/($mountPoint)/latest.json'
  }
  print $'Please check the result at: (ansi g)($destUrl)(ansi reset)'
  print 'Deprecated modules:'
  view-modules $destUrl
}

# View the modules and deprecate status
def view-modules [url: string] {
  print $'(char nl)Module status of (ansi g)($url)(ansi reset):'; hr-line -b
  let modules = http get $url
    | values
    | select namespace deprecated?
    | sort-by namespace deprecated

  $modules | print; hr-line 60
  print $'Total modules: (ansi g)($modules | length)(ansi reset), Enabled: (ansi g)($modules | where deprecated? != true | length)(ansi reset), Deprecated modules: (ansi r)($modules | where deprecated? | length)(ansi reset)'
  exit 0
}

# Get dest OSS settings
def --env get-dest-oss [destStore: string] {
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
  let ossConf = open $LOCAL_CONFIG | from toml | get -o $destStore
  if ($ossConf | is-empty) {
    print $'The storage you specified (ansi p)($destStore)(ansi reset) does not exist in (ansi p)($LOCAL_CONFIG)(ansi reset).'
    exit $ECODE.INVALID_PARAMETER
  }
  $ossConf
}

alias main = deprecated-modules
