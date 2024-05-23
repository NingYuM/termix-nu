#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/06/28 15:33:15
# TODO:
#  [✓] 执行流水线要求在仓库目录下，且要有 i 分支 & .termixrc 文件里面的配置正确
#  [✓] `t dp -l` 列出所有可用的执行目标
#  [✓] 查询流水线可以在任意目录下执行，不一定要在仓库目录下，只要流水线 ID 正确即可
#  [✓] 根据流水线 ID 查询流水线执行结果
#  [✓] 根据流水线 ID 终止对应的流水线
#  [✓] 执行新流水线之前可以查询是否有正在运行的流水线，如果有则停止执行，也可以加上 `-f` 强制执行
#  [✓] 执行新流水线之前可以查询同一 Commit 是否已经被部署过，如果部署过则停止执行，也可以加上 `-f` 强制执行
#  [✓] 允许查询某个 target 下的最近20条流水线记录
#  [✓] 批量部署模式下不会检查该 Commit 是否部署过，但是会检查同一分支上是否有流水线正在部署
#  [✓] 支持一次部署多个应用，比如 `t dp dev --apps app1,app2,app3` or `t dp --apps all`
#  [✓] 支持一次查询多个应用的部署情况，比如 `t dq dev --apps app1,app2,app3`
#  [✓] Erda OpenAPI Session 过期后自动续期
#  [✓] 详情轮询模式下显示各阶段子任务名称/执行状态及耗时
#  [✓] 详情轮询模式下显示各阶段流水线执行耗时及阶段执行状态
#  [✓] 详情轮询模式下显示总 Stage 数，总耗时，整体执行状态
#  [ ] 同一个 Stage 下面的各个子任务的执行状态以表格形式展示
# Description: 创建 Erda 流水线并执行，同时可以查询流水线执行结果
#   可以 deploy 的 target 可以为 dev、test 等，对应的流水线配置文件为 .termixrc 中的 erda.dev、erda.test, etc.
#   执行流水线时要求在仓库的 i 分支上的 .termixrc 文件中配置了对应 dest 的 pid、appid、appName、alias、branch、pipeline 信息
#   如果不存在 origin/i 分支则会尝试从当前文件夹下的 .termixrc 文件中读取配置
#   查询流水线结果时可以通过流水线ID，应用名，或者单应用模式下不输入也可以
# Note:
#   curl -X POST 'https://openapi.erda.cloud/login?username=username&password=password'
#   Emojis: https://www.emojiall.com/zh-hans/all-emojis?type=normal
#   Test CICD: 1526920533510163, 1526835893764223, 1307076224876661
# Usage:
#   t dp -l
#   t dp; t dp dev; t dp test -f
#   t dq 997636681239659
#   t dq --cid 997636681239659
#   t dq; t dq test
#   t dp dev --apps app1,app2; t dp test -a all
#   t dq dev --apps app1,app2; t dq test -a all

use ../utils/common.nu [ECODE, has-ref, hr-line, log]
use ../utils/erda.nu [ERDA_HOST, check-erda-envs, get-erda-auth, renew-erda-session, should-retry-req]

const PIPELINE_POLLING_INTERVAL = 2sec

export-env {
  # FIXME: 去除前导空格背景色
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
}

# Check if the pipeline config was set correctly, quit if not
def check-pipeline-conf [pipeline: any] {
  let keys = ['pid', 'appid', 'branch', 'env', 'appName', 'pipeline']
  $pipeline | each {|conf|
    let empties = ($keys | filter {|it| $conf | get -i $it | is-empty })
    if ($empties | length) > 0 {
      print $'Please set (ansi r)($empties | str join ',')(ansi reset) in the following pipeline config:'
      print $conf; exit $ECODE.INVALID_PARAMETER
    }
  }
}

# Try to load pipeline config variables from .termixrc file on i branch or current dir, or list available deploy targets
def get-pipeline-conf [
  dest: string = 'dev',     # 单应用部署时，指定要部署的目标
  --apps: string,           # 指定需要批量部署的应用，多个应用以英文逗号分隔
  --list,                   # 列出所有可能的部署目标及应用信息
  --grep: string,           # 仅在与 `-l` 一起使用时生效，从部署配置里面搜索name,alias或description里包含特定字符串的部署目标
  --override(-o): record,   # 覆盖部署配置里面的同名配置项
] {
  # 本地配置文件名，优先从 i 分支上的 .termixrc 文件中读取配置
  # 如果 i 分支不存在则从当前目录下的 .termixrc 文件中读取配置
  # 如果都不存在则从 termix-nu 仓库的 .termixrc 文件中读取配置
  # 如果以上都不存在则提示用户创建 .termixrc 文件
  cd $env.JUST_INVOKE_DIR
  let useI = (has-ref origin/i)
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
  let useRc = ($LOCAL_CONFIG | path exists)
  let configFile = if $useI { 'origin/i:.termixrc' } else { $LOCAL_CONFIG }
  if not ($useI or $useRc) {
    print $'No (ansi r)origin/i branch or ($LOCAL_CONFIG)(ansi reset) exits, please create it before running this command...'
    exit $ECODE.MISSING_DEPENDENCY
  }

  let repoConf = if $useI {
    git fetch origin i -q; (git show 'origin/i:.termixrc' | from toml)
  } else { (open $LOCAL_CONFIG | from toml) }
  # Print available deploy targets and apps with more detail
  if $list { show-available-targets $configFile $repoConf --grep $grep }

  let pipeline = ($repoConf.erda | get -i $dest)
  if ($pipeline | is-empty) {
    print $'Please set the App configs for (ansi r)erda.($dest)(ansi reset) in (ansi r)($configFile)(ansi reset) first...'
    exit $ECODE.INVALID_PARAMETER
  }
  # 批量处理模式必须指定 App
  if (not $useI) and ($apps | str trim | is-empty) {
    print $'You are running the command in (ansi p)batch mode(ansi reset), Please specify the apps to handle by (ansi r)`--apps` or `-a`(ansi reset) flag(ansi reset)...'
    exit $ECODE.INVALID_PARAMETER
  }
  let batchMode = ($pipeline | describe) =~ 'table'
  let conf = if $batchMode { $pipeline } else { [$pipeline] }
  mut merged = []
  for c in $conf { $merged = ($merged ++ ($c | merge ($override | default {}))) }
  check-pipeline-conf $merged
  if not $batchMode { return $merged }
  # The condition to filter the matched apps
  let cond = {|x| $apps | split row ',' | any {|it| $it in [$x.appName ($x | get -i alias)] }}
  let matched = if $apps == 'all' { $merged } else if not ($apps | is-empty) { $merged | filter $cond }
  return $matched
}

# 列出所有可用的执行目标
def show-available-targets [
  configFile: string,  # 配置文件路径
  repoConf: record,    # 配置文件内容
  --grep(-g): string,  # 仅在与 `-l` 一起使用时生效，从部署配置里面搜索name,alias或description里包含特定字符串的部署目标
] {
  if ($grep | is-empty) {
    print $'Available deploy targets in ($configFile) are:(char nl)'
  } else {
    print $'Available deploy targets in ($configFile) which contains ($grep) are:(char nl)'
  }

  for target in ($repoConf.erda | columns) {
    mut deployTarget = (
      $repoConf.erda
        | get $target
        | upsert alias {|it| $it.alias? | default 'N/A' }
        | upsert description {|it| $it.description? | default '-' }
        | upsert srcBranch {|it| get-source-branch $it $repoConf }
        | select appName alias srcBranch branch env pipeline description
        | rename -c { appName: name }
      )
    let isTable = ($deployTarget | describe) =~ 'table'
    let isRecord = ($deployTarget | describe) =~ 'record'

    if $isTable { $deployTarget = ($deployTarget | reject srcBranch) }
    if not ($grep | is-empty) {
      if ($isRecord and $'($deployTarget.name)($deployTarget.alias)($deployTarget.description)' !~ $grep) { continue }
      if $isTable {
        $deployTarget = ($deployTarget | reject srcBranch | where {|it| $'($it.name)($it.alias)($it.description)' =~ $grep })
        if ($deployTarget | is-empty) { continue }
      }
    }
    print $'Target (ansi p)($target)(ansi reset):'; hr-line 60 -c navy

    $deployTarget = if $isRecord and ($deployTarget.branch == $deployTarget.srcBranch) { $deployTarget | reject srcBranch } else { $deployTarget }
    $deployTarget | print
    if $isRecord { print -n (char nl) }
  }
  exit $ECODE.SUCCESS
}

# It's a bit hack here
# Get the source branch for the target to deploy in source repository
def get-source-branch [
  target: record,       # Deploy target config
  repoConf: record,     # 配置文件内容
] {
  if ($repoConf.branches? | is-empty) { return $target.branch }
  mut repoAlias = null
  mut srcBranch = null
  for r in ($repoConf.repos | columns) {
    let repoUrl = $repoConf.repos | get $r | get url
    if ($repoUrl =~ $'/($target.pid)/') and ($repoUrl =~ $'/($target.appid)/') {
      $repoAlias = $r
      break
    }
  }
  for r in ($repoConf.branches | columns) {
    if ($repoConf.branches | get $r | where dest == $target.branch and repo == $repoAlias | length) > 0 {
      $srcBranch = $r
      break
    }
  }
  if ($srcBranch | is-empty) { $target.branch } else { $srcBranch }
}

# 根据 AppID、Branch、Pipeline 查询最近的流水线执行记录
def query-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string, count?: int = 20, --host: string = $ERDA_HOST] {
  # Possible env values: DEV,TEST,STAGING,PROD
  let cicd = {
    ymlNames: $'($aid)/($erdaEnv)/($branch)/($pipeline)',
    appID: $aid, branches: $branch, sources: 'dice', pageNo: 1, pageSize: $count
  }
  let cicdUrl = $'($host)/api/terminus/cicds?($cicd | url build-query)'

  # Query the id of newly created CICD
  mut ci = (curl --silent -H (get-erda-auth $host) $cicdUrl | from json)
  # Check session expired, and renew if needed
  let check = should-retry-req $ci
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $ci = (curl --silent -H (get-erda-auth $host) $cicdUrl | from json)
  }
  # log 'Query CICD: ' ($ci.data.pipelines | select id commit status | table -e)
  if ($ci | describe) == 'string' or ($ci | is-empty) {
    print $'Query CICD failed with message: (ansi r)($ci)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  if not $ci.success {
    print $'(ansi r)Query CICD failed, Please try again ...(ansi reset)'
    print ($ci | table -e)
    exit $ECODE.SERVER_ERROR
  }
  return $ci
}

# 格式化流水线查询结果，以更友好的方式呈现
def format-pipeline-data [pipelines: any, orgName: string] {
  const NA = 'N/A'
  return (
    $pipelines
      | select -i id commit status normalLabels extra timeBegin timeUpdated filterLabels
      | upsert id {|it| $it | get-pipeline-url $orgName }
      | upsert timeBegin {|it| if ($it | get -i timeBegin | is-empty) { $NA } else { $it.timeBegin } }
      | update commit {|it| $it.commit | str substring 0..9 }
      | upsert Comment {|it| $it.normalLabels.commitDetail | from json | get -i comment | str trim }
      | upsert Author {|it| $it.normalLabels.commitDetail | from json | get -i author }
      | update status {|it| $'(ansi pb)($it.status)(ansi reset)' }
      | upsert Runner {|it| $it.extra | get -i runUser | default {name: $NA} | get name? }
      | upsert Begin {|it| if $it.timeBegin == $NA { $it.timeBegin } else { $it.timeBegin | into datetime | date humanize } }
      | upsert Updated {|it| $it.timeUpdated | into datetime | date humanize }
      | reject -i extra timeBegin timeUpdated normalLabels filterLabels
      | rename ID Commit Status
  )
}

# Render pipeline ID as a clickable link while querying latest CICDs
def get-pipeline-url [orgName:string, --as-raw-string, --host: string = $ERDA_HOST] {
  let $pipeline = $in
  let id = $pipeline.id
  let appid = $pipeline.filterLabels.appID
  let pid = $pipeline.filterLabels.projectID
  let link = $'($host)/($orgName)/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
  if $as_raw_string { $link } else {
    $link | ansi link --text $'($id)'
  }
}

# 查询指定目标上最新的N条流水线执行结果
def query-latest-cicd [dest: string, --apps: string, --override: record, --show-running-detail] {
  let apps = get-pipeline-conf $dest --apps $apps --override=$override
  check-erda-envs
  for app in $apps {
    print $'Querying latest CICDs for (ansi pb)($app.appName) on ($app.branch)(ansi reset) branch:'; hr-line -c pb
    let ci = (query-cicd $app.appid $app.appName $app.branch $app.env $app.pipeline 10)
    if ($ci.data.total == 0) {
      print $'No CICD found for (ansi pb)($app.appName)(ansi reset) on (ansi g)($app.branch)(ansi reset) branch'
      exit $ECODE.SUCCESS
    }
    let orgName = (fetch-cicd-detail $ci.data.pipelines.0.id).data.orgName
    let pipelines = (format-pipeline-data $ci.data.pipelines $orgName)
    print ($pipelines | table -e)
    print 'URL of the latest pipeline:'; hr-line
    print ($ci.data.pipelines | first | get-pipeline-url $orgName --as-raw-string)
    print (char nl)
    if ($show_running_detail) {
      let running = $ci.data.pipelines | where status == 'Running'
      if ($running | length) == 0 { return }
      print $'Detail of the running pipelines:'; hr-line
      $running | get ID | each {|it| query-cicd-by-id $it }
    }
  }
}

# 检查是否有正在执行的流水线，如果有则显示其概要信息并退出
def check-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string] {
  print $'Checking running CICDs for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'
  let ci = (query-cicd $aid $appName $branch $erdaEnv $pipeline)
  if ($ci.data.total == 0) { return true }

  # Update the remote-tracking branches to get the latest commit ID
  # git fetch origin $branch
  # Always use the remote commit id for checking, `str trim` is required here
  let commitID = if (has-ref $'origin/($branch)') { git rev-parse $'origin/($branch)' | str trim } else { '' }
  # Possible pipeline status: Running,Success,Failed,StopByUser
  let running = ($ci.data.pipelines | where status == 'Running')
  # log 'latest' ($ci.data.pipelines | select id commit status)
  let deployed = ($ci.data.pipelines | where commit == $commitID | where status == 'Success')
  let nRunning = ($running | length)
  let nDeployed = ($deployed | length)
  # 没有正在部署的流水线，也未曾部署过则直接返回以执行下一步
  if $nRunning == 0 and $nDeployed == 0 { return true }
  if $nRunning > 0 {
    print $'There are running pipelines, please wait with patience or re-run with `-f` flag.'
  } else if $nDeployed > 0 {
    print $'The commit (ansi p)($commitID | str substring 0..9)@($branch)(ansi reset) has been deployed, re-run with `-f` flag to deploy it again.'
  }
  let result = if $nRunning > 0 { $running } else { $deployed }
  let orgName = (fetch-cicd-detail $result.0.id).data.orgName
  hr-line 96 -abc pb
  print (format-pipeline-data $result $orgName)
  return false
}

# 创建 CICD 流水线并返回其对应 ID
export def create-cicd [aid: int, appName: string, branch: string, pipeline: string, --host: string = $ERDA_HOST] {
  let cicdUrl = $'($host)/api/terminus/cicds'
  let cicd = { appID: $aid, branch: $branch, pipelineYmlName: $pipeline }
  print $'Initialize CICD for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'

  # Query the ID of newly created CICD
  mut ci = (curl --silent -H (get-erda-auth $host) --data-raw $'($cicd | to json)' $cicdUrl | from json)
  # Check session expired, and renew if needed
  let check = should-retry-req $ci
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $ci = (curl --silent -H (get-erda-auth $host) --data-raw $'($cicd | to json)' $cicdUrl | from json)
  }
  if ($ci | describe) == 'string' {
    print $'Initialize CICD failed with message: (ansi r)($ci)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  if $ci.success { print $'(ansi g)Initialize CICD successfully...(ansi reset)'; return $ci.data.id }
  print $'(ansi r)Initialize CICD failed, Please try again ...(ansi reset)'
  print ($ci | table -e)
  exit $ECODE.SERVER_ERROR
}

# 执行指定 ID 的流水线，如有必要则持续轮询并显示执行结果
export def run-cicd [id: int, appid: int, pid: int, --watch, --host: string = $ERDA_HOST] {
  let runUrl = $'($host)/api/terminus/cicds/($id)/actions/run'
  mut run = (curl --silent -H (get-erda-auth $host) -X POST $runUrl | from json)
  # Check session expired, and renew if needed
  let check = should-retry-req $run
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $run = (curl --silent -H (get-erda-auth $host) -X POST $runUrl | from json)
  }
  if $run.success {
    print $'CICD started, You can query the pipeline running status with id: (ansi g)($id)(ansi reset)'
    let orgName = (fetch-cicd-detail $id).data.orgName
    let url = $'($host)/($orgName)/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
    print $'Or visit ($url) for more details'
  }
  if $watch { watch-cicd-status $id }
}

# POST https://erda.cloud/api/terminus/cicds/1248053184433812/actions/cancel
# 停止指定 ID 的流水线
def stop-cicd [id: int, --host: string = $ERDA_HOST] {
  let cancelUrl = $'($host)/api/terminus/cicds/($id)/actions/cancel'
  mut run = (curl --silent -H (get-erda-auth $host) -X POST $cancelUrl | from json)
  # Check session expired, and renew if needed
  let check = should-retry-req $run
  if ($check.shouldRetry) {
    if $check.noAuth { renew-erda-session $host }
    $run = (curl --silent -H (get-erda-auth $host) -X POST $cancelUrl | from json)
  }
  if $run.success {
    print $'CICD stopped, pipeline current status of id: (ansi g)($id)(ansi reset)'
    query-cicd-by-id $id
  }
}

# 根据流水线 ID 轮询流水线执行结果并显示, 轮询间隔为 2 秒
export def watch-cicd-status [id: int] {
  let stages = polling-stage-status $id
  let total = $stages | length
  const UNFINISHED_STATUS = [Born, Created, Analyzed, Queue, Running]
  const FINISH_STATUS = [Success, Failed, StopByUser, NoNeedBySystem]
  print $'(char nl)Pipeline Running Detail:'; hr-line

  # pipelineTasks status: Created,Analyzed,Success,Queue,Running,Failed,StopByUser,NoNeedBySystem
  for stage in $stages -n {
    let stageStatus = $stage.item.pipelineTasks | get status
    let tasks = $stage.item.pipelineTasks | get name | str join ', '
    let duration = $'($stage.item.pipelineTasks | get costTimeSec | math sum)sec' | into duration
    let stageSuccess = $stageStatus | all {|it| $it == 'Success' }
    let stageFailed = $stageStatus | any {|it| $it == 'Failed' }
    let stageStopped = $stageStatus | any {|it| $it == 'StopByUser' }
    let stageSkipped = $stageStatus | all {|it| $it == 'NoNeedBySystem' }
    let stageUnfinished = $stageStatus | any {|it| $it in $UNFINISHED_STATUS }
    let indicator = if $stageSuccess {
        $'(ansi g)✓(ansi reset)  Stage: (ansi g)($tasks)(ansi reset) Finished Successfully! Time cost: ($duration)'
      } else if $stageSkipped {
        $'(ansi y)☕(ansi reset) Stage: (ansi y)($tasks)(ansi reset) Was skipped!' # 💥 💭 👻 💨 ☕
      } else if $stageFailed {
        $'(ansi y)⚠(ansi reset)  Stage: (ansi y)($tasks)(ansi reset) Failed! Time cost: ($duration)'
      } else if $stageStopped {
        $'(ansi y)👻(ansi reset) Stage: (ansi y)($tasks)(ansi reset) Was stopped! Time cost: ($duration)'
      } else if $stageUnfinished {
        $'(ansi pb)🪄(ansi reset) Stage: (ansi g)($tasks)(ansi reset) is Running...'
      } else {
        $'(ansi r)✗(ansi reset) Unknown Status: ($stageStatus | str join ",")'
      }

    $env.config.table.mode = 'psql'
    print $'Stage ($stage.index + 1)/($total): ($indicator)'
    mut counter = 0
    mut keepPolling = $stageUnfinished
    while $keepPolling {
      print -n '*'  # * 💤 👣 ✨ 🍵 ⚡ 🎉 🔹 🔸
      $counter += 1
      if ($counter == 90) { $counter = 0; print -n (char nl) }
      let pollingStages = polling-stage-status $id --sid $stage.item.id
      let tasks = $pollingStages | flatten | get pipelineTasks
      let status = $tasks | get status
      if ($status | any {|it| $it in $UNFINISHED_STATUS }) {
        $keepPolling = true
      } else {
        $keepPolling = false
        let duration = $'($tasks | get costTimeSec | math sum)sec' | into duration
        print $'(char nl)Stage finished with status:(char nl)'
        $tasks | select name status | rename Name Status | print
        print $'(char nl)Time cost of this stage: ($duration)'
        hr-line 60 -c grey66
      }
      sleep $PIPELINE_POLLING_INTERVAL
    }
  }
  # Refresh the query result and print the final costTimeSec
  let query = fetch-cicd-detail $id
  let totalTime = $'($query.data.costTimeSec)sec' | into duration
  print $'(char nl)Pipeline run finished with status: (ansi p)($query.data.status)(ansi reset)! Total time cost: ($totalTime)'
}

# 查询流水线执行结果的相应阶段的详细信息
def polling-stage-status [id: int, --sid: int] {
  let query = fetch-cicd-detail $id
  const PIPELINE_TASK_COLUMNS = [id name type status costTimeSec queueTimeSec timeBegin timeEnd extra]
  # pipelineTasks status: Created,Success,Queue,Running,Failed,StopByUser
  let stages = $query.data.pipelineStages
    | select id pipelineTasks
    | upsert pipelineTasks {|it| $it.pipelineTasks | select ...$PIPELINE_TASK_COLUMNS }
  let stages = if not ($sid | is-empty) { $stages | where id == $sid } else { $stages }
  $stages
}

# 查询流水线执行结果的详细信息
export def fetch-cicd-detail [id: int, --host: string = $ERDA_HOST] {
  let queryUrl = $'($host)/api/terminus/pipelines/($id)'
  mut query = (curl --silent -H (get-erda-auth $host) $queryUrl | from json)

  # Check session expired, and renew if needed
  loop {
    let check = should-retry-req $query
    if not $check.shouldRetry { break }
    if $check.noAuth { renew-erda-session $host }
    $query = (curl --silent -H (get-erda-auth $host) $queryUrl | from json)
  }
  $query
}

# 根据流水线 ID 查询流水线执行结果
export def query-cicd-by-id [id: int, --watch, --host: string = $ERDA_HOST] {
  let query = fetch-cicd-detail $id --host $host
  if ($query | describe) == 'string' {
    print $'Query CICD failed with message: (ansi r)($query)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  if (not $query.success ) {
    print $'Query CICD failed with error message: (ansi r)($query.err.msg)(ansi reset)'
    exit $ECODE.SERVER_ERROR
  }
  let timeEnd = if ($query.data.timeEnd | is-empty) { $'(ansi wd)---Not Yet!---(ansi reset)' } else { $query.data.timeEnd }

  let output = {
    App: $query.data.applicationName
    Branch: $query.data.branch
    Status: $'(ansi pb)($query.data.status)(ansi reset)'
    Runner: $query.data.extra.runUser.name
    Committer: $query.data.commitDetail.author
    Commit: ($query.data.commit | str substring 0..9)
    Comment: ($query.data.commitDetail.comment | str trim)
    Begin: $query.data.timeBegin
    End: $timeEnd
    Duration: ($'($query.data.costTimeSec)sec' | into duration)
    # 此处之所以没有直接用 $appid & $pid 是因为可能存在在 A 应用仓库中查询 B 应用的流水线执行结果的情况，故而以返回数据为准
    URL: $'($host)/($query.data.orgName)/dop/projects/($query.data.projectID)/apps/($query.data.applicationID)/pipeline/obsoleted?pipelineID=($id)'
  }
  print $'(char nl)(ansi pb)Current Running Status of CICD ($id):(ansi reset)'
  hr-line; print $output
  # print ($query | table -e)     # Just for debugging purpose
  if $watch { watch-cicd-status $id }
}

# 创建 Erda 流水线并执行，同时可以查询流水线执行结果
export def main [
  operation: string,          # 目前支持两种操作类型，run 和 query, run 用于创建并执行 CICD, query 用于查询 CICD 执行结果
  dest?: string = 'dev',      # 当操作为 run 时必须指定，用于指定流水线执行的目标环境，如 dev, test, staging, prod 等, query 时按需指定, 默认为 dev
  --list(-l),                 # 当操作为 run 时生效，用于列出所有可用的执行目标
  --watch(-w),                # 持续轮询并显示正在执行的流水线的详细信息
  --grep(-g): string,         # 仅在与 `-l` 一起使用时生效，从部署配置里面搜索name,alias或description里包含特定字符串的部署目标
  --force(-f),                # 当操作为 run 时生效，即便已经有正在运行的流水线或者已经部署过也会强制重新执行
  --cid(-i): int,             # 当操作为 query 时生效，用于查询 CICD 执行结果，如果不传则查询最近 10 条流水线执行结果
  --apps(-a): string,         # 指定需要批量部署的应用，多个应用以英文逗号分隔
  --stop-by-id(-s): int,      # 当操作为 run 时生效，用于根据流水线ID停止对应的正在运行的流水线
  --override(-o): record,     # 覆盖部署配置里面的同名配置项
] {
  check-erda-envs

  match $operation {
    run | r => {
      # 根据流水线 ID 查询无需加载其他环境变量，也不需要 .termixrc 文件
      let isIdQuery = ($operation in ['query', 'q']) and ($cid > 0)
      if not ($stop_by_id | is-empty) { stop-cicd $stop_by_id; exit $ECODE.SUCCESS }
      let apps = (if $list {
          get-pipeline-conf $dest --apps $apps --list --grep $grep
        } else if (not $isIdQuery) {
          get-pipeline-conf $dest --apps $apps --override=$override
        })
      for app in $apps {
        # 以下为应用级别配置，应用的所有开发者保持一致，可以放在代码仓库里面
        let pid = $app.pid
        let appid = $app.appid
        let branch = $app.branch
        let appName = $app.appName
        let pipeline = $app.pipeline
        # 检查是否有正在执行的流水线以及是否该 Commit 已经部署过
        if not $force {
          if not (check-cicd $appid $appName $branch $app.env $pipeline) { continue }
        }
        let cicdid = (create-cicd $appid $appName $branch $pipeline)
        run-cicd ($cicdid | into int) $appid $pid --watch=$watch
      }
    }
    query | q => {
      # 未指定 cid 则查询最近 10 条流水线执行结果
      if ($cid | is-empty) { query-latest-cicd $dest --apps $apps --override=$override; exit $ECODE.SUCCESS }
      if ($cid | describe) != 'int' {
        print $'Invalid value for --cid: (ansi r)($cid)(ansi reset), should be an integer number.'
        exit $ECODE.INVALID_PARAMETER
      }
      query-cicd-by-id $cid --watch=$watch
    }
    _ => {
      print $'Unsupported operation: (ansi r)($operation)(ansi reset), should be (ansi g)run(ansi reset) or (ansi g)query(ansi reset)'
      exit $ECODE.INVALID_PARAMETER
    }
  }
}

# 创建 Erda 流水线并执行，默认情况下会检查是否有流水线正在执行或者是否该 Commit 已经部署过，若有则停止并给予提示
export def erda-deploy [
  dest?: string = 'dev',    # 用于指定流水线执行的目标环境，如 dev, test, staging, prod 等, 默认为 dev
  --list(-l),               # 列出所有可能的部署目标及应用信息
  --watch(-w),              # 执行流水线时持续轮询并显示该流水线各个 Stage 的详细执行信息
  --grep(-g): string,       # 仅在与 `-l` 一起使用时生效，从部署配置里面搜索name,alias或description里包含特定字符串的部署目标
  --force(-f),              # 即便已经有正在运行的流水线，或者即便该 Commit 对应的分支已经部署过也会强制重新部署
  --apps(-a): string,       # 指定需要批量部署的应用，多个应用以","分隔，在多应用模式下必须指定(`all` 代表所有)，单应用模式忽略
  --stop-by-id(-s): int,    # 根据流水线ID 停止对应的正在运行的流水线
  --override(-o): record,   # 覆盖部署配置里面的同名配置项
] {
  main run $dest --apps $apps --force=$force --list=$list --watch=$watch --grep $grep --stop-by-id $stop_by_id --override=$override
}

# 根据流水线 ID 或目标环境查询流水线执行结果, 例如: 单应用: t dq 997636681239659; t dq test, 多应用: t dq dev -a all
export def erda-query [
  dest?: string = 'dev',  # 用于指定流水线查询目标环境，如 dev, test, staging, prod 等, 默认为 dev
  --watch(-w),            # 持续轮询并显示指定流水线各个 Stage 的详细执行信息
  --cid(-i): any,         # 用于通过流水线的执行 ID 查询 CICD 执行结果，如果指定该参数则忽略 dest 参数
  --apps(-a): string,     # 指定需要批量查询的应用，多个应用以","分隔，在多应用模式下必须指定(`all` 代表所有)，单应用模式忽略
  --override(-o): record, # 覆盖部署配置里面的同名配置项
] {
  # 允许非指定流水线ID的查询
  if ($cid | is-empty) {
    # 需要同时支持 t dq 997636681239659 & t dq test
    let cidParsed = (do -i {$dest | into int})
    if ($cidParsed | describe) == 'int' {
      main query --cid $cidParsed --watch=$watch
    } else {
      main query $dest --apps $apps --override=$override
    }
  } else { main query --cid $cid --watch=$watch }
}
