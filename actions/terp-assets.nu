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
# [√] Revert frontend module to a selected version, s5cmd required
# [√] Add Revert metadata to latest.json
# Ref:
#   - https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json
#   - http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-test/latest.json
#   - https://min.io/docs/minio/linux/reference/minio-mc/mc-cp.html
#   - https://min.io/docs/minio/linux/reference/minio-mc.html?ref=docs#install-mc
#   - https://docs.erda.cloud/2.2/manual/dop/guides/reference/pipeline.html
#   - https://www.alibabacloud.com/help/zh/oss/developer-reference/install-ossutil#dda54a7096xfh
# Errors:
#   - 无权限: StatusCode=403, ErrorCode=AccessDenied, ErrorMessage="The bucket you access does not belong to you."

use ../utils/common.nu [ECODE, FZF_DEFAULT_OPTS, FZF_THEME, _TIME_FMT]
use ../utils/common.nu [is-installed, hr-line, get-conf, get-tmp-path, compare-ver, with-progress, get-empty-keys]

# --------------------------------- Constants and Configs ---------------------------------
const JSON_ENTRY = 'latest.json'
const STORE_TYPES = [aliyun, minio, volc, ifly]
const VALID_ACTIONS = [init, download, transfer, detect, revert]
const VALID_MODULES = [terp-mobile terp service service-mobile iam dors dors-mobile base base-mobile b2b emp]
const DEFAULT_ENDPOINT = 'https://oss-cn-hangzhou.aliyuncs.com'
const ENDPOINT = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com'
const ASSETS_URL = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/assets/terp-assets.tar.gz'
const SUPPORTED_OUTPUTS = [text json]

# Don't validate module names by default
const VALIDATE_MODULES = '0'

const KEY_MAPPING = $"(ansi grey66)\(Space: Select, a: Select All, ESC/q: Quit, Enter: Confirm\)(ansi rst)"

# Frontend module and descriptions
const MOD_DESC = {
    agent: 'agent: AI/智能体/聊天相关 PC 端组件'
    agent-mobile: 'agent-mobile: AI/智能体/聊天相关移动端组件'
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
  s5cmd: 'Please install s5cmd by `brew install s5cmd` first'
}
# -----------------------------------------------------------------------------------------

def is-agent-mode [] {
  $env.TA_AGENT_MODE? | default false
}

def assume-yes [] {
  $env.TA_ASSUME_YES? | default false
}

def is-json-output [] {
  ($env.TA_OUTPUT_FORMAT? | default text) == json
}

def current-action [] {
  $env.TA_CURRENT_ACTION? | default 'terp-assets'
}

def env-flag-enabled [name: string] {
  let value = $env | get -o $name
  if ($value | is-empty) { return false }
  let kind = $value | describe
  if $kind == bool { return $value }
  let normalized = ($value | into string | str downcase | str trim)
  $normalized in ['1' 'true' 'yes' 'on']
}

def read-fixture [env_key: string] {
  if not (env-flag-enabled TERP_ASSETS_ENABLE_FIXTURES) { return null }
  let path = $env | get -o $env_key
  if ($path | is-empty) { return null }
  open $path
}

def print-info [value: any] {
  if (is-json-output) { print -e $value } else { print $value }
}

def print-info-n [value: any] {
  if (is-json-output) { print -e -n $value } else { print -n $value }
}

def print-error [value: any] {
  print -e $value
}

def print-divider [
  width: int = 80,
  --color(-c): string = grey66,
] {
  if not (is-json-output) { hr-line $width -c $color }
}

def print-table [value: any] {
  print-info ($value | table -e)
}

def write-json [payload: record] {
  print ($payload | to json -r)
}

def normalize-success-data [data: any] {
  let data_type = $data | describe
  let record_data = if ($data_type | str starts-with 'record') { $data } else { { raw: $data } }
  {
    mountpoint: ($record_data.mountpoint? | default null)
    latestUrl: ($record_data.latestUrl? | default null)
    modules: ($record_data.modules? | default null)
    reverted: ($record_data.reverted? | default null)
    counts: ($record_data.counts? | default null)
    stats: ($record_data.stats? | default null)
    target: ($record_data.target? | default null)
    targets: ($record_data.targets? | default null)
    destStore: ($record_data.destStore? | default null)
    destination: ($record_data.destination? | default null)
    revision: ($record_data.revision? | default null)
    raw: $data
  }
}

def emit-success [
  action: string,
  data?: any,
  --warnings: list<any> = [],
] {
  let payload = {
    success: true
    action: $action
    data: (normalize-success-data ($data | default null))
    warnings: $warnings
  }
  if (is-json-output) { write-json $payload }
  $payload
}

def fail-assets [
  exit_code: int,
  error_code: string,
  message: string,
  --details: record = {},
] {
  let action = current-action
  if (is-json-output) {
    write-json {
      success: false
      action: $action
      error: {
        code: $error_code
        message: $message
        details: $details
      }
    }
  } else {
    print-error $message
  }
  exit $exit_code
}

def cancel-assets [
  message: string,
  --details: record = {},
] {
  let action = current-action
  if (is-json-output) {
    write-json {
      success: true
      action: $action
      cancelled: true
      message: $message
      details: $details
    }
  } else {
    print-info $message
  }
  exit $ECODE.SUCCESS
}

def ensure-interactive [
  feature: string,
  prompt: string,
  --details: record = {},
] {
  if (is-agent-mode) {
    fail-assets $ECODE.INVALID_PARAMETER INTERACTION_REQUIRED $'Interactive input is required for ($feature) in the current command.' --details ({
      feature: $feature
      prompt: $prompt
      ...$details
    })
  }
}

def ensure-mutation-approved [action: string] {
  if (is-agent-mode) and not (assume-yes) {
    fail-assets $ECODE.INVALID_PARAMETER MUTATION_NOT_CONFIRMED $'Action ($action) mutates remote state. Re-run with --yes in agent mode.' --details {
      action: $action
      required: ['yes']
    }
  }
}

def check-package-tools [] {
  if not (is-installed package-tools) {
    fail-assets $ECODE.MISSING_BINARY MISSING_BINARY 'Please install package-tools first.' --details {
      command: 'npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io'
    }
  }
  let ver = package-tools -v
  let minPkgToolsVer = get-conf minPkgToolVer
  let compVer = compare-ver $ver $minPkgToolsVer
  if $compVer < 0 {
    fail-assets $ECODE.CONDITION_NOT_SATISFIED PACKAGE_TOOLS_TOO_OLD $'Only package-tools ($minPkgToolsVer) or above is supported.' --details {
      current: $ver
      minimum: $minPkgToolsVer
    }
  }
}

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
@example '初始化低修改频率的公共静态资源到存储桶，Bucket 级别，跟环境无关' {
  t ta init --dest-store minio
} --result '在目标存储的 terp-assets 目录下完成 js/fonts/monaco-editor 等静态资源的初始化'
@example '将 3.0.2506 的 `base,service` 模块同步到 `toss` 配置对应存储的 `terp-dev` 挂载点' {
  t ta transfer base,service --from 3.0.2506 --to terp-dev --dest-store toss
} --result '只同步指定模块，一般建议这么操作既节省时间又减小影响范围'
@example '交互式选择模块将 3.0.2506 的选中模块同步到 `toss` 配置对应存储的 `terp-dev` 挂载点' {
  t ta transfer --from 3.0.2506 --to terp-dev --dest-store toss
} --result '按空格选中或者取消选择，回车确认，按 ESC/q 退出'
@example '将测试环境的所有模块同步到预发与生产挂载点(多目标逗号分隔)' {
  t ta transfer all --from test --to staging,prod --dest-store minio
} --result '先下载再上传，成功后输出各目标 latest.json 访问地址，一般不推荐直接同步 `all`, 影响范围太大'
@example '查看指定挂载点(如 `dev` & `test`)的资源摘要信息(多目标逗号分隔)' {
  t ta detect -f dev,test
} --result '从 dev & test 挂载点读取 latest.json 并显示模块列表及状态, 只有在 terminus-new-trantor OSS Bucket 的时候才能使用简写'
@example '通过自定义 `latest.json` 完整 URL 查看资源摘要' {
  t ta detect -f https://portal-test.app.terminus.io/latest.json
} --result '从指定 URL 读取 latest.json 并显示模块列表及状态'
@example '查看指定挂载点的静态资源统计信息(按模块和文件类型分类)' {
  t ta detect -f dev --stat
} --result '显示各模块的 js/css/json 等文件数量统计表格及总数'
@example '回滚 `terp-dev` 环境的 `base` 模块到之前的版本' {
  t ta revert base -t terp-dev -d oss
} --result '目前只支持回滚单个模块，交互式选择要回滚的版本，确认后执行回滚操作'
@example '从 OSS 下载所有模块静态资源到本地临时目录' {
  t ta download all -f dev
} --result '这个命令你一般不会用到，资源同步的时候会自动调用这个命令'
@example '以 agent 模式读取 latest.json 并输出结构化 JSON' {
  t ta detect -f dev --agent
} --result '不进入交互流程，输出稳定 JSON 协议，适合给 AI/脚本消费'
@example '以 agent 模式显式确认后同步模块' {
  t ta transfer base,service --from dev --to terp-dev --dest-store oss --agent --yes
} --result '不会出现确认提示，失败时返回明确错误码与 JSON 错误对象'
export def 'terp assets' [
  action: string@$VALID_ACTIONS,  # Available actions: init, download, transfer, detect and revert
  modules?: string,               # Available values: base/base-mobile/terp/terp-mobile/iam/charts/service/all. Multiple modules separated by `,`
  --from(-f): string,             # Source mount point or source URL. Note: Only `detect` action supports multiple sources separated by `,`
  --to(-t): string,               # Destination mount point
  --quiet(-q),                    # Show less info
  --dest-store(-d): string,       # Destination store, should be configured in .termixrc
  --stat(-s),                     # Show static assets statistics info in detect action
  --agent,                        # Agent-friendly mode: no prompts/fzf, structured failure semantics
  --yes(-y),                      # Skip confirmation prompts in agent mode or text mode
  --output(-o): string,           # Output format: `text` or `json`, defaults to `json` in agent mode
  --revision(-r): string,         # Explicit revision for `revert` action in agent mode
] {
  cd ($env.TERMIX_DIR? | default (pwd))
  let finalOutput = if ($output | is-empty) {
    if $agent { 'json' } else { 'text' }
  } else { $output }
  if $finalOutput not-in $SUPPORTED_OUTPUTS {
    fail-assets $ECODE.INVALID_PARAMETER INVALID_OUTPUT $'Unsupported output format: ($finalOutput), supported formats are: ($SUPPORTED_OUTPUTS | str join ", ")' --details {
      output: $finalOutput
      supported: $SUPPORTED_OUTPUTS
    }
  }
  load-env {
    TA_AGENT_MODE: $agent
    TA_ASSUME_YES: $yes
    TA_OUTPUT_FORMAT: $finalOutput
    TA_CURRENT_ACTION: $action
  }

  mut result = null
  if $action == 'revert' {
    if ($modules | is-empty) {
      fail-assets $ECODE.INVALID_PARAMETER MISSING_MODULE $'Please specify the frontend module to revert, e.g. `t ta revert base`.' --details {
        required: ['modules']
      }
    }
    if ($to | is-empty) {
      fail-assets $ECODE.INVALID_PARAMETER MISSING_TARGET 'Please specify the destination mount point to revert by `-t` or `--to`.' --details {
        required: ['to']
      }
    }
    if ($dest_store | is-empty) {
      fail-assets $ECODE.INVALID_PARAMETER MISSING_DEST_STORE 'Please specify the destination store to revert the frontend module by `-d` or `--dest-store`.' --details {
        required: ['dest-store']
      }
    }
    $result = revert-module $modules $to $dest_store --revision $revision
    if (is-json-output) { emit-success $action $result | ignore; return }
    $result | ignore
    return
  }

  if ($from | default '') =~ ',' and ($action == 'detect') {
    $result = detect-multiple-assets $from --stat=$stat
    if (is-json-output) { emit-success $action $result | ignore; return }
    $result | ignore
    return
  }

  if $action == 'init' {
    pre-check $action --to $to --dest-store $dest_store
    ensure-mutation-approved $action
    $result = init-assets --dest-store $dest_store --quiet=$quiet
    if (is-json-output) { emit-success $action $result | ignore; return }
    $result | ignore
    return
  }

  let latestMeta = get-latest-meta $from
  if $action == 'detect' {
    $result = detect $latestMeta --stat=$stat
    if (is-json-output) { emit-success $action $result | ignore; return }
    $result | ignore
    return
  }

  let selectedModules = get-modules $modules --latest-meta $latestMeta --action $action
  if $action == 'transfer' { ensure-mutation-approved $action }
  pre-check $action --to $to --dest-store $dest_store
  confirm-action $action $selectedModules --to $to --dest-store $dest_store

  $result = match $action {
    'download' => { download $selectedModules $latestMeta $to --quiet=$quiet }
    'transfer' => { transfer $selectedModules $latestMeta $to --dest-store $dest_store --quiet=$quiet }
  }
  if (is-json-output) { emit-success $action $result | ignore; return }
  $result | ignore
}

# Preview the module revision metadata in fzf preview window
export def fzf-preview [revision: string, localPath: string, remoteURI: string, destStore: string] {
  let dest = $'($localPath)/($revision)/namespace.json'
  let ossConf = get-dest-oss $destStore
  let remoteFile = $'($remoteURI)/($revision)/namespace.json'
  # Ensure parent directory exists for preview copy
  let parent = $dest | path dirname
  if not ($parent | path exists) { mkdir $parent }
  let result = do-storage-cp $remoteFile $dest
  if $result.exit_code != 0 {
    print-error $'Failed to copy namespace.json for preview'
    print-info $result.stderr
    exit $result.exit_code
  }

  let mountPoint = $remoteURI | split row '/' | last
  let module = $revision | split row '-' | drop | str join '-'

  print-info $'You are going to revert (ansi g)($module)(ansi rst) module at mount point (ansi g)($mountPoint)(ansi rst)'
  print-divider 66
  open $dest | rename -c { namespace: 'module' }
    | merge { revision: $revision, remoteURI: $remoteURI }
    | select module revision remoteURI metadata
    | upsert metadata.syncBy {|it| $it.metadata?.syncBy? | show }
    | table -e -t compact | print

  # Show static assets statistics for this revision
  let manifestDest = $'($localPath)/($revision)/manifest.json'
  let manifestRemote = $'($remoteURI)/($revision)/manifest.json'
  let manifestResult = do-storage-cp $manifestRemote $manifestDest
  if $manifestResult.exit_code == 0 and ($manifestDest | path exists) {
    let manifest = open $manifestDest
    let assets = $manifest | get -o assets | default []
    if ($assets | is-not-empty) {
      let byExt = $assets
        | each { |a| $a | path parse | get -o extension | default 'other' | str downcase }
        | group-by
        | items {|k, v| { ext: $k, count: ($v | length) } }
        | sort-by -r count
      print-info $'(char nl)(ansi g)Static Assets:(ansi rst)'
      print-divider 30
      $byExt | table -t psql | print
      print-info $'(char nl)(ansi g)Total: ($assets | length)(ansi rst)'
    }
  }
}

def main [revision: string, localPath: string, remoteURI: string, destStore: string] {
  fzf-preview $revision $localPath $remoteURI $destStore
}

# ***************************************************************************************
# ------------------------------------- Core Logic --------------------------------------
# ***************************************************************************************

def format-meta-time [value: any, fmt: string] {
  if ($value | is-empty) { return '-' }
  try { $value | into datetime | format date $fmt } catch { $value | into string }
}

# Detect multiple static assets and display the metadata
def detect-multiple-assets [from: string, --stat(-s)] {
  let mountPoints = $from | split row , | compact -e
  $mountPoints | enumerate | each {|item|
      let latestMeta = get-latest-meta $item.item
      let summary = detect $latestMeta --stat=$stat
      if (not (is-json-output)) and ($item.index < (($mountPoints | length) - 1)) {
        print-info-n (char nl)
      }
      $summary
    }
}

# Revert frontend module to a selected version, s5cmd required
def --env revert-module [
  module: string,
  to: string,
  destStore: string,
  --revision(-r): string,
] {
  let ossConf = get-dest-oss $destStore
  revert-precheck $module $to $ossConf

  let target = $to | split row @ | first
  let localPath = $'(get-tmp-path)/terp/revert/($module)/($target)/' | str replace -a \ /
  # Configure S3-compatible credentials for s5cmd once
  $env.AWS_REGION = $ossConf.OSS_REGION | default 'us-east-1'
  $env.AWS_ACCESS_KEY_ID = $ossConf.OSS_AK | default ''
  $env.AWS_SECRET_ACCESS_KEY = $ossConf.OSS_SK | default ''
  $env.S3_ENDPOINT_URL = $ossConf.OSS_ENDPOINT | default $DEFAULT_ENDPOINT
  let remoteURI = $'s3://($ossConf.OSS_BUCKET)/fe-resources/($target)'

  if not ($localPath | path exists) { mkdir $localPath }

  # Select revision
  let selectedRevision = select-revert-revision $module $remoteURI $localPath $destStore --revision $revision

  # Confirm and execute revert
  ensure-mutation-approved revert
  check-git-user
  execute-revert $module $target $destStore $selectedRevision $localPath $remoteURI $ossConf
}

# Download static assets from OSS and sync to destination store by s5cmd
def init-assets [
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
  --quiet(-q),                # Show less info
] {
  const ASSETS = [js/ fonts/ monaco-editor/ geojson/]
  let tmp = $'(get-tmp-path)/static'
  if not ($tmp | path exists) { mkdir $tmp }
  rm -rf ($'($tmp)/*' | into glob)
  let ossConf = get-dest-oss $dest_store
  $env.AWS_REGION = $ossConf.OSS_REGION | default 'us-east-1'
  $env.AWS_ACCESS_KEY_ID = $ossConf.OSS_AK | default ''
  $env.AWS_SECRET_ACCESS_KEY = $ossConf.OSS_SK | default ''
  $env.S3_ENDPOINT_URL = $ossConf.OSS_ENDPOINT | default $DEFAULT_ENDPOINT
  let s3_dest = $'s3://($ossConf.OSS_BUCKET)/terp-assets'
  let required = [OSS_AK OSS_SK OSS_BUCKET]
  let missing = $required | where {|it| $ossConf | get -o $it | is-empty }
  if ($missing | is-not-empty) {
    fail-assets $ECODE.INVALID_PARAMETER MISSING_STORE_CONFIG $'The following required config is missing: ($missing | str join ", ").' --details {
      missing: $missing
      destStore: $dest_store
    }
  }

  # Detect addressing style before any S3 operations
  # Available options for OSS_STYLE: virtual, path
  # Priority: OSS_STYLE config > MinIO default (path) > auto-detect
  let type = $ossConf.TYPE? | default 'aliyun' | str downcase
  let configuredStyle = $ossConf.OSS_STYLE? | default '' | str downcase
  let style = if $configuredStyle == 'virtual' {
    [--addressing-style=virtual]
  } else if $configuredStyle == 'path' {
    []  # Explicitly use path-style
  } else if $type in [minio ifly] {
    []  # MinIO/ifly default to path-style to avoid detection issues
  } else {
    detect-addressing-style $s3_dest  # Auto-detect for other storage types
  }
  if ($style | is-not-empty) { print-info $'(ansi grey66)Using virtual-hosted-style for S3 access(ansi rst)' }

  print-info $'Downloading assets from (ansi g)($ASSETS_URL)(ansi rst)...'
  http get $ASSETS_URL | save -rpf $'($tmp)/terp-assets.tar.gz'
  cd $tmp; tar -xzf terp-assets.tar.gz
  print-info $'Assets downloaded successfully to ($tmp)!'

  # Initial upload if bucket is empty
  let lsCheck = run-s5cmd $style '--json' ls $s3_dest
  if ($lsCheck.stderr | from json | get -o error | default '') =~ 'no object' {
    if (is-json-output) {
      sync-assets $style $ASSETS $s3_dest upload
    } else {
      with-progress $'Uploading assets to (ansi p)($dest_store)(ansi rst)...' {
        sync-assets $style $ASSETS $s3_dest upload
      }
    }
  }

  # Check what needs to be synced
  let dry_run_results = $ASSETS
    | each {|it| run-s5cmd $style '--dry-run' sync $it $'($s3_dest)/($it)' }

  # Check for errors in dry-run
  let dry_run_errors = $dry_run_results | where exit_code != 0
  if ($dry_run_errors | is-not-empty) {
    if not (is-json-output) {
      print-error $'(ansi r)Failed to check assets status:(ansi rst)'
      $dry_run_errors | each {|e| print-error $e.stderr }
    }
    fail-assets $ECODE.COMMAND_FAILED INIT_CHECK_FAILED 'Failed to check terp-assets sync status.' --details {
      stderr: ($dry_run_errors | get stderr)
      destStore: $dest_store
      s3Dest: $s3_dest
    }
  }

  let dry_run = $dry_run_results | get stdout | str join "\n" | str trim

  if ($dry_run | is-empty) {
    print-info $'(ansi g)Assets have already been uploaded to (ansi p)($dest_store)(ansi rst) (ansi g)successfully!(ansi rst)'
    let stats = show-terp-assets-stat $style $s3_dest
    return {
      destStore: $dest_store
      target: $s3_dest
      pendingFiles: 0
      changed: false
      stats: $stats
    }
  }

  # Show preview (max 7 lines)
  let lines = $dry_run | lines
  let preview = if ($lines | length) > 7 { $lines | take 7 | append '...' } else { $lines } | str join "\n"
  print-info $'Actions to be performed:(char nl)(ansi g)($preview)(ansi rst)'
  print-info $'Total files to be synced: (ansi g)($lines | length)(ansi rst)'

  # Confirm and sync
  if not (assume-yes) {
    let confirm = input $'Are you sure to sync the assets? (ansi g)[y/n](ansi rst) '
    if ($confirm | str upcase) != 'Y' {
      cancel-assets 'Assets syncing cancelled, Bye...' --details { destStore: $dest_store, s3Dest: $s3_dest }
    }
  }
  print-info 'Syncing assets...'
  sync-assets $style $ASSETS $s3_dest sync
  print-info 'Assets have been synced successfully!'
  let stats = show-terp-assets-stat $style $s3_dest
  {
    destStore: $dest_store
    target: $s3_dest
    pendingFiles: ($lines | length)
    changed: true
    stats: $stats
  }
}

# Show terp-assets statistics from cloud storage
def show-terp-assets-stat [style: list, s3_dest: string] {
  print-info $'(char nl)(ansi g)Terp Assets Statistics:(ansi rst)'
  print-divider 60
  # s5cmd uses glob pattern for recursive listing, not --recursive flag
  let lsResult = run-s5cmd $style ls $'($s3_dest)/**'
  if $lsResult.exit_code != 0 {
    print-error $'Failed to list assets: ($lsResult.stderr)'
    return { total: null, byExtension: [], byDir: [] }
  }
  # Parse s5cmd ls output: each line is like "2024/01/01 12:00:00  12345  s3://bucket/path/file.js"
  let files = $lsResult.stdout | str trim | lines
    | where { $in | is-not-empty }
    | each {|line|
        let parts = $line | split row -r '\s+' | last
        { path: $parts, ext: ($parts | path parse | get -o extension | default 'other' | str downcase) }
      }

  if ($files | is-empty) {
    print-info 'No assets found in cloud storage'
    return { total: 0, byExtension: [], byDir: [] }
  }

  # Group by top-level directory (js/, fonts/, monaco-editor/)
  let byDir = $files | each {|f|
      let rel = $f.path | str replace $'($s3_dest)/' ''
      let dir = $rel | split row '/' | first
      { dir: $dir, ext: $f.ext }
    }
    | group-by dir

  # Statistics by directory
  let dirStats = $byDir | items {|dir, items|
    let byExt = $items | get ext | group-by | items {|k, v| { ext: $k, count: ($v | length) } } | sort-by -r count
    { dir: $dir, total: ($items | length), byExt: $byExt }
  } | sort-by dir

  # Display per-directory stats
  # for stat in $dirStats {
  #   print $'(char nl)(ansi p)($stat.dir)/(ansi rst) - (ansi g)($stat.total)(ansi rst) files'
  #   $stat.byExt | take 5 | table -t compact | print
  # }

  # Summary
  let grandTotal = $dirStats | each {|s| $s.total } | math sum
  let allExts = $files | get ext | group-by | items {|k, v| { ext: $k, count: ($v | length) } } | sort-by -r count
  print-info $'(char nl)(ansi g)Summary:(ansi rst)'
  print-divider 40
  $allExts | table -t psql | do { |it| print-info $it }
  print-info $'(char nl)(ansi g)Total files in terp-assets: ($grandTotal)(ansi rst)'
  { total: $grandTotal, byExtension: $allExts, byDir: $dirStats }
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
  let entry = $'($dest)/latest-($mount).json'
  $latestMeta.latest | save -f $entry
  let entryConf = open $entry

  # Download assets for each end point
  let downloads = $modules | each { |e|
    let assetsDir = $'($dest)/assets-($mount)-($e)'
    # 每次下载前先清空目录
    rm -rf $assetsDir; mkdir $'($assetsDir)/assets'
    let moduleMeta = $entryConf | get $e
    let prefix = $moduleMeta | get prefix
    let dirname = $moduleMeta | get dirname
    let resolved = resolve-module-manifest $latestMeta $moduleMeta
    print-info $'Download assets from (ansi p)($mount)/($JSON_ENTRY)(ansi rst) to (ansi p)($dest)(ansi rst) for (ansi pb)($e)(ansi rst)...'

    # Save manifest.json for subsequent upload via package-tools
    if ($resolved | is-empty) {
      fail-assets $ECODE.COMMAND_FAILED MANIFEST_FETCH_FAILED $'Failed to fetch manifest.json for module ($e).' --details {
        module: $e
        latestUrl: $fromUrl
        attempted: (resolve-asset-roots $fromUrl $prefix | each {|root| $'($root)/($prefix)/($dirname)/manifest.json' })
      }
    }
    $resolved.manifest | to json -r | save -f $'($assetsDir)/manifest.json'

    let assets = open $'($assetsDir)/manifest.json' | get assets

    for a in $assets {
      let url = $'($resolved.root)/($prefix)/($dirname)/($a)'
      let assetPath = $'/($prefix)/($dirname)/($a)'
      let dir = $'($assetsDir)/($a)' | path dirname
      if not ($dir | path exists) { mkdir $dir }
      if $quiet {
        http get -r $url | save -rfp $'($assetsDir)/($a)'
      } else {
        print-info $'Downloading ($url | ansi link --text $assetPath)'
        http get -r $url | save -rf $'($assetsDir)/($a)'
      }
    }

    print-info $'(ansi p)Assets for ($e) have been downloaded successfully!(ansi rst)'
    if not $quiet { print-divider }
    {
      module: $e
      directory: $assetsDir
      manifest: $'($assetsDir)/manifest.json'
      assetCount: ($assets | length)
    }
  }
  print-info "All downloads finished! \n"
  {
    mountpoint: $mount
    latestUrl: $fromUrl
    destination: $dest
    entry: $entry
    modules: $modules
    downloads: $downloads
  }
}

# Transfer static assets from OSS to OSS or Minio's other path
def transfer [
  modules: list,              # Module name or alias available values: pc, mobile, all, etc.
  latestMeta: record,         # Latest metadata
  to: string,
  --quiet(-q),                # Show less info
  --dest-store(-d): string,   # Destination store, should be configured in .termixrc
] {
  check-git-user
  check-package-tools
  let tmp = $'(get-tmp-path)/terp'
  if (not ($tmp | path exists)) { mkdir $tmp }

  let startTime = date now
  let downloadSummary = download $modules $latestMeta $tmp --quiet=$quiet
  print-info $'Start to transfer assets from (ansi p)($latestMeta.from) to ($dest_store) ($to)(ansi rst)'

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
  let targets = ($to | split row ',' | compact -e)
  for e in $modules {
    cd $'($tmp)/assets-($mount)-($e)'
    # Update namespace.json add transfer info
    update-transfer-meta $latestMeta
    for t in $targets {
      print-info $'Uploading (ansi p)($e)@($mount) to (ansi p)($t)(ansi rst) ...'
      let upload = if ($type | str trim | str downcase) in [minio, ifly] {
        ^package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t -s path ...$extra | complete
      } else {
        ^package-tools s3 -c $ak $sk $bucket $endpoint $region -d . -m $t ...$extra | complete
      }
      if $upload.exit_code != 0 {
        fail-assets $ECODE.COMMAND_FAILED TRANSFER_FAILED $'Failed to upload module ($e) to target ($t).' --details {
          module: $e
          target: $t
          destStore: $dest_store
          stderr: $upload.stderr
        }
      }
    }
    print-info $'Assets (ansi p)($e)(ansi rst) have been transferred successfully!'
  }

  let endTime = date now
  print-info "All transfer finished! \n"
  print-info $"(ansi g)Total Time Cost: ($endTime - $startTime)(ansi rst)\n"

  let latestUrls = $targets | each {|t|
      match $type {
        'ifly' => $'($endpoint)/($bucket)/fe-resources/($t)/latest.json'
        'minio' => $'($endpoint)/($bucket)/fe-resources/($t)/latest.json'
        'volc' => $'https://($bucket).($region).volces.com/fe-resources/($t)/latest.json'
        'aliyun' => $'https://($bucket).($region).aliyuncs.com/fe-resources/($t)/latest.json'
      }
    }
  print-info $"You can visit the latest.json from: \n"
  $latestUrls | each {|url| print-info $"(ansi g)($url)(ansi rst)" }
  {
    mountpoint: $mount
    modules: $modules
    destStore: $dest_store
    targets: $targets
    latestUrls: $latestUrls
    elapsed: ($endTime - $startTime)
    download: $downloadSummary
  }
}

# Display front end module meta data
def detect [latestMeta: record, --stat(-s)] {
  const TIME_FMT = '%m/%d %H:%M:%S'
  let modules = $latestMeta.latest
    | values
    | select namespace deprecated? metadata?
    | upsert branch {|it| $it.metadata?.branch? | default '-' }
    | upsert SHA {|it| $it.metadata?.commitSha? | default '-' }
    | upsert buildAt {|it| format-meta-time $it.metadata?.buildAt? $TIME_FMT }
    | upsert syncBy {|it| $it.metadata?.syncBy? | show }
    | upsert syncFrom {|it| $it.metadata?.syncFrom? | default '-' }
    | upsert syncAt {|it| format-meta-time $it.metadata?.syncAt? $TIME_FMT }
    | reject -o metadata
    | sort-by namespace
    | rename module

  let reverted = $latestMeta.latest
    | values
    | where {|it| $it.metadata?.revertAt? | is-not-empty }
    | select namespace metadata.revertBy metadata.revertAt metadata.revertFrom? metadata.revertTo?
    | rename module revertBy revertAt revertFrom revertTo
    | sort-by module
    | upsert revertBy {|it| $it.revertBy? | show }
    | upsert revertAt {|it| format-meta-time $it.revertAt? $TIME_FMT }
  mut summary = {
    latestUrl: $latestMeta.latestUrl
    mountpoint: $latestMeta.mountpoint
    modules: $modules
    reverted: $reverted
    counts: {
      total: ($modules | length)
      enabled: ($modules | where deprecated? != true | length)
      deprecated: ($modules | where deprecated? | length)
    }
    stats: null
  }

  print-info $'Latest metadata of (ansi g)($latestMeta.latestUrl)(ansi rst)'
  if ($modules | get deprecated? | compact | length) > 0 {
    print-divider 108
    print-table $modules
    print-divider 118 --color grey30
  } else {
    print-divider 108
    print-table ($modules | reject deprecated)
    print-divider 108 --color grey30
  }
  print-info $'Total modules: (ansi g)($summary.counts.total)(ansi rst), Enabled: (ansi g)($summary.counts.enabled)(ansi rst), Deprecated modules: (ansi r)($summary.counts.deprecated)(ansi rst)'
  if ($reverted | length) > 0 {
    print-info $'(char nl)Module Revert Found:(char nl)'
    print-table $reverted
    print-info-n (char nl)
  }
  if $stat {
    let statsData = show-assets-stat $latestMeta
    $summary = ($summary | upsert stats $statsData)
  }
  $summary
}

# ***************************************************************************************
# ---------------------------------- Revert Helpers -----------------------------------
# ***************************************************************************************

# Check if the required tools are installed and validating args for module reverting
def revert-precheck [module: string, to: string, ossConf: record] {
  let type = $ossConf.TYPE? | default 'aliyun' | str downcase
  if $type not-in $STORE_TYPES {
    fail-assets $ECODE.INVALID_PARAMETER INVALID_STORE_TYPE $'The storage type ($type) is invalid for assets reverting.' --details {
      type: $type
      supported: $STORE_TYPES
    }
  }

  if $module =~ ',' {
    fail-assets $ECODE.INVALID_PARAMETER MULTI_MODULE_REVERT_UNSUPPORTED 'Revert frontend module is not supported for multiple modules yet.' --details {
      module: $module
    }
  }

  let requiredTools = if (is-agent-mode) { ['s5cmd'] } else { ['fzf' 's5cmd'] }
  let missingTips = $requiredTools | reduce --fold [] {|it, acc|
      if not (is-installed $it) { $acc | append ($TOOL_INSTALL_TIP | get $it) } else { $acc }
    }
  if ($missingTips | length) > 0 {
    if not (is-json-output) {
      print-info 'The following tools are required for reverting frontend module:'
      print-divider
      $missingTips | wrap Tips | table -t psql | do { |it| print-info $it }
      print-info-n (char nl)
    }
    fail-assets $ECODE.MISSING_BINARY MISSING_BINARY 'Required tools for reverting frontend module are missing.' --details {
      tools: $requiredTools
      tips: $missingTips
    }
  }
}

# Select the revision to revert
def list-revert-revisions [module: string, remoteURI: string] {
  let fixture = read-fixture TERP_ASSETS_FIXTURE_REVISIONS
  if ($fixture | is-not-empty) {
    return ($fixture | each {|it| $it | into string } | uniq | sort -r)
  }
  # Use s5cmd to list namespace.json under each revision directory, then extract revision names
  let pattern = $'($remoteURI)/($module)-*/namespace.json'
  let lines = s5cmd-auto ls $pattern
  if $lines.exit_code != 0 {
    fail-assets $lines.exit_code REVERT_REVISION_LIST_FAILED 'Failed to list revisions via s5cmd.' --details {
      module: $module
      remoteURI: $remoteURI
      stderr: $lines.stderr
    }
  }
  $lines.stdout | str trim | lines
    | where {|l| $l =~ $'($module)-\d' }
    | each {|l|
        let path = ($l | split row ' ' | last)
        let rel = if $path =~ '^s3://' { $path | str replace $'($remoteURI)/' '' } else { $path }
        $rel | split row '/' | first
      }
    | uniq
    | sort -r
}

def select-revert-revision [
  module: string,
  remoteURI: string,
  localPath: string,
  destStore: string,
  --revision(-r): string,
] {
  let moduleRevisions = list-revert-revisions $module $remoteURI
  if ($moduleRevisions | is-empty) {
    fail-assets $ECODE.CONDITION_NOT_SATISFIED NO_REVISIONS_FOUND $'No revisions were found for module ($module).' --details {
      module: $module
      remoteURI: $remoteURI
    }
  }
  if ($revision | is-not-empty) {
    if $revision not-in $moduleRevisions {
      fail-assets $ECODE.INVALID_PARAMETER INVALID_REVISION $'Revision ($revision) does not exist for module ($module).' --details {
        module: $module
        revision: $revision
        availableRevisions: $moduleRevisions
      }
    }
    return $revision
  }
  ensure-interactive 'revert-revision' 'Please choose one revision from the list.' --details {
    module: $module
    availableRevisions: $moduleRevisions
    required: ['revision']
  }
  let title = $'Select the revision to apply:'
  let PREVIEW_CMD = $"nu actions/terp-assets.nu {} ($localPath) ($remoteURI) ($destStore)"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let selected = $moduleRevisions | par-each { $in | str trim -c '/' | split row '/' | last } | str join "\n"
    | fzf | complete | get stdout | str trim
  if ($selected | is-empty) {
    cancel-assets 'No revision selected, Bye...' --details {
      module: $module
      availableRevisions: $moduleRevisions
    }
  }
  $selected
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
  let namespacePath = $'($localPath)/($revision)/namespace.json'
  if not ($namespacePath | path exists) {
    let parent = $namespacePath | path dirname
    if not ($parent | path exists) { mkdir $parent }
    let cpNamespace = do-storage-cp $'($remoteURI)/($revision)/namespace.json' $namespacePath
    if $cpNamespace.exit_code != 0 {
      fail-assets $cpNamespace.exit_code REVERT_NAMESPACE_FETCH_FAILED 'Failed to fetch namespace.json for the selected revision.' --details {
        revision: $revision
        remoteURI: $remoteURI
        stderr: $cpNamespace.stderr
      }
    }
  }

  print-info $'Attention: You are going to REVERT (ansi p)($module)(ansi rst) module to (ansi p)($revision) for ($target)@($destStore)(ansi rst)'
  print-divider
  print-info $'(ansi grey66)Metadata Detail:(ansi rst)'
  mut meta = open $namespacePath | get metadata
  if ($meta.syncBy? | is-not-empty) { $meta = $meta | upsert syncBy {|it| $it.syncBy? | show } }
  print-info $meta
  print-info-n (char nl)

  let dest = if (assume-yes) { $target } else { input $'Please confirm by typing (ansi r)($target)(ansi rst) to continue or (ansi p)q(ansi rst) to quit: ' }
  if $dest == 'q' {
    cancel-assets 'Revert cancelled, Bye...' --details {
      module: $module
      target: $target
      destStore: $destStore
      revision: $revision
    }
  }
  if $dest != $target {
    fail-assets $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($dest), does not match ($target).' --details {
      expected: $target
      actual: $dest
    }
  }
  # Copy remote latest.json to local at the last moment to make sure the latest version is used
  let cpLatest = do-storage-cp $'($remoteURI)/latest.json' $localPath
  if $cpLatest.exit_code != 0 {
    fail-assets $cpLatest.exit_code REVERT_LATEST_FETCH_FAILED 'Failed to copy latest.json from remote.' --details {
      remoteURI: $remoteURI
      stderr: $cpLatest.stderr
    }
  }

  let revertAt = date now | format date $_TIME_FMT
  let revertBy = $env.DICE_OPERATOR_NAME? | default (git config --get user.name) | encode base64
  let revertFrom = open $'($localPath)/latest.json' | get $module | get dirname
  let revertMeta = { revertAt: $revertAt, revertBy: $revertBy, revertTo: $revision, revertFrom: $revertFrom }
  let moduleMeta = open $'($localPath)/($revision)/namespace.json' | upsert metadata {|it| $it.metadata | merge $revertMeta }
  let update = {} | upsert $module { prefix: $'fe-resources/($target)', dirname: $revision, ...$moduleMeta }
  let updated = open $'($localPath)/latest.json' | merge $update
  $updated | save -f $'($localPath)/latest.json'

  let sync = do-storage-cp $'($localPath)/latest.json' $'($remoteURI)/latest.json'
  if $sync.exit_code != 0 {
    fail-assets $sync.exit_code REVERT_SYNC_FAILED $'Revert ($module) module to ($revision) for ($target)@($destStore) failed.' --details {
      module: $module
      revision: $revision
      target: $target
      destStore: $destStore
      stderr: $sync.stderr
    }
  }
  print-info $'Revert (ansi p)($module)(ansi rst) module to (ansi p)($revision) for ($target)@($destStore)(ansi rst) successful!'
  {
    module: $module
    target: $target
    destStore: $destStore
    revision: $revision
    revertAt: $revertAt
    revertFrom: $revertFrom
    latestUrl: $'($remoteURI)/latest.json'
  }
}


# ***************************************************************************************
# ------------------------------ Storage Abstractions ---------------------------------
# ***************************************************************************************

const VIRTUAL_STYLE_ERR = 'SecondLevelDomainForbidden|virtual'

# Check if the error indicates virtual-hosted-style is required
def needs-virtual-style [result: record] {
  $result.exit_code != 0 or ($result.stderr =~ $VIRTUAL_STYLE_ERR)
}

# Run s5cmd sync for each asset and check for failures, exit on error
def sync-assets [style: list, assets: list, s3_dest: string, action: string] {
  let results = $assets | each {|it|
    let r = run-s5cmd $style sync $it $'($s3_dest)/($it)'
    if $r.exit_code != 0 { print-error $'Failed to ($action) ($it): ($r.stderr)' }
    $r
  }
  let failed = $results | where exit_code != 0
  if ($failed | is-not-empty) {
    fail-assets $ECODE.COMMAND_FAILED SYNC_FAILED $'($failed | length) asset(s) failed to ($action)!' --details {
      action: $action
      target: $s3_dest
      errors: ($failed | get stderr)
    }
  }
}

# Detect the correct addressing style for the given S3 endpoint
# Returns: [] for path-style (default), [--addressing-style=virtual] for virtual-hosted
def detect-addressing-style [s3_dest: string] {
  let result = ^s5cmd ls $s3_dest | complete
  if (needs-virtual-style $result) { [--addressing-style=virtual] } else { [] }
}

# Run s5cmd with the specified addressing style (accepts list of extra flags)
def run-s5cmd [style: list, ...args: string] {
  ^s5cmd ...$style ...$args | complete
}

# Run s5cmd with auto-retry using virtual addressing style on path-style failure
def s5cmd-auto [...args: string] {
  let result = ^s5cmd ...$args | complete
  if (needs-virtual-style $result) {
    ^s5cmd --addressing-style=virtual ...$args | complete
  } else { $result }
}

# Copy assets from source to dest，s5cmd ENV vars should be set by caller
def do-storage-cp [source: string, dest: string] {
  # Use s5cmd for both upload and download; credentials must be set by caller
  let empties = get-empty-keys $env [AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY S3_ENDPOINT_URL]
  if ($empties | is-not-empty) {
    fail-assets $ECODE.INVALID_PARAMETER MISSING_STORAGE_ENV $'Please set ($empties | str join ", ") in your environment first.' --details {
      missing: $empties
      source: $source
      dest: $dest
    }
  }
  s5cmd-auto cp $source $dest
}

# ***************************************************************************************
# --------------------------------- General Helpers -----------------------------------
# ***************************************************************************************

# Check if git user identity is available for sync/revert metadata
def check-git-user [] {
  if ($env.DICE_OPERATOR_NAME? | is-not-empty) { return }
  let user = do { git config --get user.name } | complete
  if $user.exit_code != 0 or ($user.stdout | str trim | is-empty) {
    if (is-json-output) {
      fail-assets $ECODE.CONDITION_NOT_SATISFIED GIT_USER_REQUIRED 'Git user name is not configured.' --details {
        command: 'git config --global user.name "Your Name"'
      }
    }
    print-error $'(ansi r)Error: Git user name is not configured.(ansi rst)'
    print-error $'This is required for TERP asset operations. Please configure it by running:'
    print-error $'  (ansi g)git config --global user.name "Your Name"(ansi rst)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
}

# Decode base64 encoded string, show default as `-`
def show [] { $in | default 'LQ==' | decode base64 | decode }

# Read manifest fixture by manifest URL
def read-manifest-fixture [manifestUrl: string] {
  let fixtures = read-fixture TERP_ASSETS_FIXTURE_MANIFESTS
  if ($fixtures | is-empty) { return null }
  $fixtures | get -o $manifestUrl
}

# Normalize a manifest payload from HTTP or fixtures into a record
def normalize-manifest [] {
  let payload = $in
  if ($payload | is-empty) { return null }
  let kind = $payload | describe
  if ($kind | str starts-with 'record') { return $payload }
  if $kind == 'string' {
    return (try { $payload | from json } catch { null })
  }
  null
}

# Resolve candidate asset roots from latest.json URL and module prefix
def resolve-asset-roots [latestUrl: string, prefix: string] {
  mut roots = []
  if ($latestUrl | str contains '/fe-resources/') {
    $roots = ($roots | append ($latestUrl | split row '/fe-resources' | get 0))
  } else if ($latestUrl | str ends-with $'/($JSON_ENTRY)') {
    $roots = ($roots | append ($latestUrl | str replace -r '/latest\.json$' ''))
  }
  if ($prefix | str starts-with 'fe-resources/') {
    $roots = ($roots | append $ENDPOINT)
  }
  $roots | where {|root| $root | is-not-empty } | uniq
}

# Resolve manifest URL for a module and return parsed manifest data
def resolve-module-manifest [latestMeta: record, moduleMeta: record] {
  let prefix = $moduleMeta.prefix
  let dirname = $moduleMeta.dirname
  let candidates = resolve-asset-roots $latestMeta.latestUrl $prefix
  for root in $candidates {
    let manifestUrl = $'($root)/($prefix)/($dirname)/manifest.json'
    let manifest = if (env-flag-enabled TERP_ASSETS_ENABLE_FIXTURES) {
      read-manifest-fixture $manifestUrl
    } else {
      try { http get $manifestUrl } catch { null }
    } | normalize-manifest
    if ($manifest | is-not-empty) {
      return {
        root: $root
        manifestUrl: $manifestUrl
        manifest: $manifest
      }
    }
  }
  null
}

# Count static assets from manifest.json URL and return statistics by extension
def count-module-assets [latestMeta: record, moduleMeta: record] {
  let resolved = resolve-module-manifest $latestMeta $moduleMeta
  if ($resolved | is-empty) { return null }
  let manifest = $resolved.manifest
  let assets = $manifest | get -o assets | default []
  if ($assets | is-empty) { return null }
  # Count by extension and calculate total
  let byExt = $assets
    | each { |a| $a | path parse | get -o extension | default 'other' | str downcase }
    | group-by
    | items {|k, v| { ext: $k, count: ($v | length) } }
    | sort-by -r count
  { total: ($assets | length), byExt: $byExt, manifestUrl: $resolved.manifestUrl }
}

# Aggregate and display assets statistics for all modules
def show-assets-stat [latestMeta: record] {
  let modules = $latestMeta.latest | transpose key val

  print-info $'(char nl)(ansi g)Static Assets Statistics:(ansi rst)'
  print-divider 88

  # Collect stats for all modules
  let allStats = $modules | each {|m|
    let stats = count-module-assets $latestMeta $m.val
    if ($stats | is-empty) { null } else { { module: $m.key, ...$stats } }
  } | compact

  if ($allStats | is-empty) {
    print-info 'No assets found'
    return { total: 0, rows: [] }
  }

  # Get all unique extensions across all modules
  let allExts = $allStats | each {|s| $s.byExt | get ext } | flatten | uniq | sort

  # Build table rows with module name, each extension count, and total
  let rows = $allStats | each {|s|
    let extCounts = $s.byExt | reduce --fold {} {|e, acc| $acc | upsert $e.ext $e.count }
    let row = $allExts | reduce --fold { module: $s.module } {|ext, acc|
      $acc | upsert $ext ($extCounts | get -o $ext | default 0)
    }
    $row | upsert total $s.total
  } | sort-by module

  let preferred = [module js css] | where {|col| $col in ($rows | columns) }
  let displayRows = if ($preferred | is-empty) { $rows } else { $rows | move ...$preferred --first }
  print-info ($displayRows | table -t light)
  let grandTotal = $allStats | each {|s| $s.total } | math sum
  print-info $'(char nl)(ansi g)Total static assets: ($grandTotal)(ansi rst)'
  { total: $grandTotal, rows: $rows }
}

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
    ensure-interactive 'module-selection' 'Please select the modules manually.' --details {
      action: $action
      availableModules: ($allModules | get mod)
      required: ['modules']
    }
    print-info 'No module specified, please select the modules manually...'
    print-divider
    let tips = $"Select the modules to sync or download ($KEY_MAPPING)"
    let selected = $allModules | input list -d desc --multi $tips | default [] | get mod
    if ($selected | is-empty) {
      cancel-assets 'You have not selected any modules, Bye...' --details {
        action: $action
        availableModules: ($allModules | get mod)
      }
    }
    return $selected
  }

  # Sync all modules if 'all' is specified
  if $modules == 'all' { return ($allModules | get mod) }

  # Validate and sync specified modules
  let splits = $modules | default '' | split row ',' | compact -e
  if ($splits | length) > 0 {
    let inexists = $splits | where {|it| $it not-in ($allModules | get mod) }
    if ($inexists | length) > 0 {
      fail-assets $ECODE.INVALID_PARAMETER INVALID_MODULES $'Invalid modules: ($inexists | str join ",").' --details {
        invalid: $inexists
        availableModules: ($allModules | get mod)
      }
    }
  }
  $splits
}

# Get latest.json from specified mount point
def get-latest-meta [from: string] {
  let isFullUrl = $from | str ends-with $'/($JSON_ENTRY)'
  let fromUrl = if $isFullUrl { $from } else { $'($ENDPOINT)/fe-resources/($from)/($JSON_ENTRY)' }
  let fixture = read-fixture TERP_ASSETS_FIXTURE_LATEST
  let latest = if ($fixture | is-not-empty) { $fixture } else { http get $fromUrl }
  let mount = $latest | values | first | get prefix | str replace fe-resources/ ''
  let modules = $latest | columns
  let validModules = {|mods, validMods| $mods | all {|m| $m in $validMods } }
  let validateModules = if (($env.VALIDATE_MODULES? | default $VALIDATE_MODULES) == '0') { false } else { true }
  let validationPassed = (do $validModules $modules $VALID_MODULES)
  if (not $validateModules) or ($validateModules and $validationPassed) {
    return { from: $from, latestUrl: $fromUrl, mountpoint: $mount, latest: $latest }
  }
  fail-assets $ECODE.INVALID_PARAMETER INVALID_LATEST_JSON $'The latest.json from ($fromUrl) contains invalid modules.' --details {
    latestUrl: $fromUrl
    modules: $modules
  }
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
    fail-assets $ECODE.INVALID_PARAMETER DEST_STORE_NOT_FOUND $'The storage you specified, ($destStore), does not exist in ($LOCAL_CONFIG).' --details {
      destStore: $destStore
      config: $LOCAL_CONFIG
    }
  }
  if ($ossConf.TYPE? | is-not-empty) and ($ossConf.TYPE? not-in $STORE_TYPES) {
    fail-assets $ECODE.INVALID_PARAMETER INVALID_STORE_TYPE $'The storage type ($ossConf.TYPE) is invalid.' --details {
      type: $ossConf.TYPE
      supported: $STORE_TYPES
    }
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
    fail-assets $ECODE.INVALID_PARAMETER INVALID_ACTION $'Invalid action ($action).' --details {
      action: $action
      supported: $VALID_ACTIONS
    }
  }
  if $action == 'transfer' and (($to | is-empty) or ($dest_store | is-empty)) {
    let missing = []
      | append (if ($to | is-empty) { ['to'] } else { [] })
      | append (if ($dest_store | is-empty) { ['dest-store'] } else { [] })
    fail-assets $ECODE.INVALID_PARAMETER MISSING_TRANSFER_TARGET 'Please specify both `--to` and `--dest-store` for transfer.' --details {
      required: $missing
    }
  }
  if $action == 'init' {
    if not (is-installed s5cmd) {
      fail-assets $ECODE.MISSING_BINARY MISSING_BINARY $TOOL_INSTALL_TIP.s5cmd --details {
        tool: 's5cmd'
      }
    }
    if ($dest_store | is-empty) {
      fail-assets $ECODE.INVALID_PARAMETER MISSING_DEST_STORE 'Please specify the destination store to init static assets by `--dest-store`.' --details {
        required: ['dest-store']
      }
    }
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
  if (assume-yes) { return }
  print-info $'Attention: You are going to TRANSFER (ansi p)($modules | str join ",")(ansi rst) assets to (ansi p)($to)@($dest_store)(ansi rst)'
  print-divider
  let dest = input $'Please confirm by typing (ansi r)($to)(ansi rst) to continue or (ansi p)q(ansi rst) to quit: '
  if $dest == 'q' {
    cancel-assets 'Transfer cancelled, Bye...' --details {
      modules: $modules
      target: $to
      destStore: $dest_store
    }
  }
  if $dest != $to {
    fail-assets $ECODE.INVALID_PARAMETER CONFIRMATION_MISMATCH $'Your input, ($dest), does not match ($to).' --details {
      expected: $to
      actual: $dest
    }
  }
}
