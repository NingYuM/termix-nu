#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/06/28 15:33:15
# TODO:
#  [x] 执行流水线要求在仓库目录下，且要有 i 分支 & .termixrc 文件里面的配置正确
#  [x] `t dp -l` 列出所有可用的执行目标
#  [x] 查询流水线可以在任意目录下执行，不一定要在仓库目录下，只要流水线 ID 正确即可
#  [x] 执行新流水线之前可以查询是否有正在运行的流水线，如果有则停止执行，也可以加上 `-f` 强制执行
#  [x] 执行新流水线之前可以查询同一 Commit 是否已经被部署过，如果部署过则停止执行，也可以加上 `-f` 强制执行
#  [x] 允许查询某个 target 下的最近20条流水线记录
#  [x] 批量部署模式下不会检查该 Commit 是否部署过，但是会检查同一分支上是否有流水线正在部署
#  [x] 支持一次部署多个应用，比如 `t dp dev --apps app1,app2,app3` or `t dp --apps all`
#  [x] 支持一次查询多个应用的部署情况，比如 `t dq dev --apps app1,app2,app3`
# Description: 创建 Erda 流水线并执行，同时可以查询流水线执行结果
#   可以 deploy 的 target 可以为 dev、test 等，对应的流水线配置文件为 .termixrc 中的 erda.dev、erda.test, etc.
#   执行流水线时要求在仓库的 i 分支上的 .termixrc 文件中配置了对应 dest 的 pid、appid、appName、alias、branch、pipeline 信息
#   如果不存在 origin/i 分支则会尝试从当前文件夹下的 .termixrc 文件中读取配置
#   查询流水线结果时可以通过流水线ID，应用名，或者单应用模式下不输入也可以
# Usage:
#   t dp -l
#   t dp; t dp dev; t dp test -f
#   t dq 997636681239659
#   t dq --cid 997636681239659
#   t dq; t dq test
#   t dp dev --apps app1,app2; t dp test -a all
#   t dq dev --apps app1,app2; t dq test -a all

use ../utils/common.nu *

def erda-host [] { 'https://erda.cloud' }

# Check if the required environment variable was set, quit if not
def check-envs [] {
  # 部署/查询 Pipeline 操作需要先配置 ERDA_SESSION
  let envs = ['ERDA_SESSION']
  let empties = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in your environment first...'
    exit 1
  }
}

# Check if the pipeline config was set correctly, quit if not
def check-pipeline-conf [pipeline: any] {
  let keys = ['pid', 'appid', 'branch', 'env', 'appName', 'pipeline']
  $pipeline | each {|conf|
    let empties = ($keys | filter {|it| $conf | get -i $it | is-empty })
    if ($empties | length) > 0 {
      print $'Please set (ansi r)($empties | str join ',')(ansi reset) in the following pipeline config:'
      print $conf; exit 1
    }
  }
}

# Try to load pipeline config variables from .termixrc file on i branch or current dir, or list available deploy targets
def get-pipeline-conf [dest: string = 'dev', --apps: string, --list: bool] {
  # 本地配置文件名，优先从 i 分支上的 .termixrc 文件中读取配置
  # 如果 i 分支不存在则从当前目录下的 .termixrc 文件中读取配置
  cd $env.JUST_INVOKE_DIR
  let useI = (has-ref origin/i)
  let LOCAL_CONFIG = '.termixrc'
  let useRc = ($LOCAL_CONFIG | path exists)
  let configFile = if $useI { 'origin/i:.termixrc' } else { $LOCAL_CONFIG }
  if ($useI or $useRc) {
    let repoConf = if $useI { (git show 'origin/i:.termixrc' | from toml) } else { (open $LOCAL_CONFIG | from toml) }
    # Print available deploy targets and apps with more detail
    if $list {
      print $'Available deploy targets in ($configFile) are:(char nl)'
      let upsertAlias = {|it| if ($it | get -i alias | is-empty) { 'N/A' } else { $it.alias } }
      for target in ($repoConf.erda | columns) {
        print $'Target (ansi p)($target)(ansi reset):'; hr-line -c pb
        print ($repoConf.erda | get $target | upsert alias $upsertAlias | select appName alias branch env pipeline)
        if ($repoConf.erda | get $target | describe) =~ 'record' { print -n (char nl) }
      }
      exit 0
    }

    let pipeline = ($repoConf.erda | get -i $dest)
    if ($pipeline | is-empty) {
      print $'Please set the App configs for (ansi r)erda.($dest)(ansi reset) in (ansi r)($configFile)(ansi reset) first...'; exit 1
    }
    # 批量处理模式必须指定 App
    if (not $useI) and ($apps | str trim | is-empty) {
      print $'You are running the command in (ansi p)batch mode(ansi reset), Please specify the apps to handle by (ansi r)`--apps` or `-a`(ansi reset) flag(ansi reset)...'; exit 1
    }
    let batchMode = ($pipeline | describe) =~ 'table'
    let conf = if $batchMode { $pipeline } else { [$pipeline] }
    check-pipeline-conf $conf
    if not $batchMode { return $conf }
    # The condition to filter the matched apps
    let cond = {|x| $apps | split row ',' | any {|it| $it in [$x.appName ($x | get -i alias)] }}
    let matched = if $apps == 'all' { $conf } else if not ($apps | is-empty) { $conf | filter $cond }
    return $matched
  }
  print $'No (ansi r)origin/i branch or ($LOCAL_CONFIG)(ansi reset) exits, please create it before running this command...'; exit 1
}

# 根据 AppID、Branch、Pipeline 查询最近的流水线执行记录
def query-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string, count?: int = 20, --auth: string] {
  # Possible env values: DEV,TEST,STAGING,PROD
  let cicd = {
    ymlNames: $'($aid)/($erdaEnv)/($branch)/($pipeline)',
    appID: $aid, branches: $branch, sources: 'dice', pageNo: 1, pageSize: $count
  }
  let cicdUrl = $'(erda-host)/api/terminus/cicds?($cicd | url build-query)'

  # Query the id of newly created CICD
  let ci = (curl --silent -H $auth $cicdUrl | from json)
  # log 'Query CICD: ' ($ci.data.pipelines | select id commit status | table -e)
  if ($ci | describe) == 'string' or ($ci | is-empty) {
    print $'Query CICD failed with message: (ansi r)($ci)(ansi reset)'; exit 1
  }
  if not $ci.success {
    print $'(ansi r)Query CICD failed, Please try again ...(ansi reset)'
    print ($ci | table -e)
    exit 1
  }
  return $ci
}

# 格式化流水线查询结果，以更友好的方式呈现
def format-pipeline-data [pipelines: list] {
  let na = 'N/A'
  return (
    $pipelines
      | select -i id commit status normalLabels extra timeBegin timeUpdated
      | upsert timeBegin {|it| if ($it | get -i timeBegin | is-empty) { $na } else { $it.timeBegin } }
      | update commit {|it| $it.commit | str substring 0..9 }
      | upsert Comment {|it| $it.normalLabels.commitDetail | from json | get -i comment | str trim }
      | upsert Author {|it| $it.normalLabels.commitDetail | from json | get -i author }
      | update status {|it| $'(ansi pb)($it.status)(ansi reset)' }
      | upsert Runner {|it| $it.extra | get -i runUser | default {name: $na} | get name }
      | upsert Begin {|it| if $it.timeBegin == $na { $it.timeBegin } else { $it.timeBegin | into datetime | date humanize } }
      | upsert Updated {|it| $it.timeUpdated | into datetime | date humanize }
      | reject extra timeBegin timeUpdated normalLabels
      | rename ID Commit Status
  )
}

# 查询指定目标上最新的N条流水线执行结果
def query-latest-cicd [dest: string, --apps: string, --auth: string] {
  let apps = (get-pipeline-conf $dest --apps $apps)
  check-envs
  for app in $apps {
    print $'Querying latest CICDs for (ansi pb)($app.appName) on ($app.branch)(ansi reset) branch:'; hr-line -c pb
    let ci = (query-cicd --auth $auth $app.appid $app.appName $app.branch $app.env $app.pipeline 10)
    let pipelines = (format-pipeline-data $ci.data.pipelines)
    print ($pipelines | table -e)
  }
}

# 检查是否有正在执行的流水线，如果有则显示其概要信息并退出
def check-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string, --auth: string] {
  print $'Checking running CICDs for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'
  let ci = (query-cicd $aid $appName $branch $erdaEnv $pipeline --auth $auth)

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
  hr-line 96 -abc pb
  print (format-pipeline-data $result)
  return false
}

# 创建 CICD 流水线并返回其对应 ID
def create-cicd [aid: int, appName: string, branch: string, pipeline: string, --auth: string] {
  let cicdUrl = $'(erda-host)/api/terminus/cicds'
  let cicd = { appID: $aid, branch: $branch, pipelineYmlName: $pipeline }
  print $'Initialize CICD for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'

  # Query the ID of newly created CICD
  let ci = (curl --silent -H $auth --data-raw $'($cicd | to json)' $cicdUrl | from json)
  if ($ci | describe) == 'string' { print $'Initialize CICD failed with message: (ansi r)($ci)(ansi reset)'; exit 1 }
  if $ci.success { print $'(ansi g)Initialize CICD successfully...(ansi reset)'; return $ci.data.id }
  print $'(ansi r)Initialize CICD failed, Please try again ...(ansi reset)'
  print ($ci | table -e)
  exit 1
}

# 执行指定 ID 的流水线
def run-cicd [id: int, appid: int, pid: int, --auth: string] {
  let runUrl = $'(erda-host)/api/terminus/cicds/($id)/actions/run'
  let run = (curl --silent -H $auth -X POST $runUrl | from json)
  let url = $'(erda-host)/terminus/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
  if $run.success {
    print $'CICD started, You can query the pipeline running status with id: (ansi g)($id)(ansi reset)'
    print $'Or visit ($url) for more details'
  }
}

# 根据流水线 ID 查询流水线执行结果
def query-cicd-by-id [id: int, --auth: string] {
  let queryUrl = $'(erda-host)/api/terminus/pipelines/($id)'
  let query = (curl --silent -H $auth $queryUrl | from json)

  if ($query | describe) == 'string' { print $'Query CICD failed with message: (ansi r)($query)(ansi reset)'; exit 1 }
  if (not $query.success ) { print $'Query CICD failed with error message: (ansi r)($query.err.msg)(ansi reset)'; exit 1 }
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
    URL: $'(erda-host)/terminus/dop/projects/($query.data.projectID)/apps/($query.data.applicationID)/pipeline/obsoleted?pipelineID=($id)'
  }
  print $'(char nl)(ansi pb)Current Running Status of CICD ($id):(ansi reset)'
  print '----------------------------------------------------------'
  print $output
  # print ($query | table -e)     # Just for debugging purpose
}

# 创建 Erda 流水线并执行，同时可以查询流水线执行结果
export def main [
  operation: string,      # 目前支持两种操作类型，run 和 query, run 用于创建并执行 CICD, query 用于查询 CICD 执行结果
  dest?: string = 'dev',  # 当操作为 run 时必须指定，用于指定流水线执行的目标环境，如 dev, test, staging, prod 等, query 时按需指定, 默认为 dev
  --cid(-i): int,         # 当操作为 query 时生效，用于查询 CICD 执行结果，如果不传则查询最近 10 条流水线执行结果
  --list(-l): bool,       # 当操作为 run 时生效，用于列出所有可用的执行目标
  --force(-f): bool,      # 当操作为 run 时生效，即便已经有正在运行的流水线或者已经部署过也会强制重新执行
  --apps(-a): string,     # 指定需要批量部署的应用，多个应用以英文逗号分隔
] {
  check-envs

  # 用户级别配置，每个开发者根据自己的情况配置, 请注意保密，建议放在本地环境变量里面
  let session = $env.ERDA_SESSION
  # 个人全局身份验证信息，如果过期请重新获取并更新
  let auth = $'cookie: OPENAPISESSION=($session)'

  match $operation {
    run | r => {
      # 根据流水线 ID 查询无需加载其他环境变量，也不需要 .termixrc 文件
      let isIdQuery = ($operation in ['query', 'q']) and ($cid > 0)
      let apps = (if $list { get-pipeline-conf $dest --apps $apps --list } else if (not $isIdQuery) { get-pipeline-conf $dest --apps $apps })
      for app in $apps {
        # 以下为应用级别配置，应用的所有开发者保持一致，可以放在代码仓库里面
        let pid = $app.pid
        let appid = $app.appid
        let branch = $app.branch
        let appName = $app.appName
        let pipeline = $app.pipeline
        # 检查是否有正在执行的流水线以及是否该 Commit 已经部署过
        if not $force {
          if not (check-cicd --auth $auth $appid $appName $branch $app.env $pipeline) { continue }
        }
        let cicdid = (create-cicd --auth $auth $appid $appName $branch $pipeline)
        run-cicd --auth $auth ($cicdid | into int) $appid $pid
      }
    }
    query | q => {
      # 未指定 cid 则查询最近 10 条流水线执行结果
      if ($cid | is-empty) { query-latest-cicd --apps $apps --auth $auth $dest; exit 0 }
      if ($cid | describe) != 'int' {
        print $'Invalid value for --cid: (ansi r)($cid)(ansi reset), should be an integer number.'; exit 1
      }
      query-cicd-by-id --auth $auth $cid
    }
    _ => {
      print $'Unsupported operation: (ansi r)($operation)(ansi reset), should be (ansi g)run(ansi reset) or (ansi g)query(ansi reset)'
      exit 1
    }
  }
}

# 创建 Erda 流水线并执行，同时可以查询流水线执行结果
export def erda-deploy [
  operation: string,      # 目前支持两种操作类型，run 和 query, run 用于创建并执行 CICD, query 用于查询 CICD 执行结果
  dest?: string = 'dev',  # 当操作为 run 时必须指定，用于指定流水线执行的目标环境，如 dev, test, staging, prod 等, query 时无需指定, 默认为 dev
  --cid(-i): any,         # 当操作为 query 时必须指定，用于查询 CICD 执行结果
  --list(-l): bool,       # 当操作为 run 时生效，用于列出所有可用的执行目标
  --force(-f): bool,      # 当操作为 run 时生效，即便已经有正在运行的流水线也会强制执行
  --apps(-a): string,     # 指定需要批量部署的应用，多个应用以英文逗号分隔
] {
  match $operation {
    run | r => {
      if $list { main run $dest --apps $apps --list } else {
        if $force { main run $dest --apps $apps --force } else { main run $dest --apps $apps }
      }
    }
    query | q => {
      # 允许非指定流水线ID的查询
      if ($cid | is-empty) {
        # 需要同时支持 t dq 997636681239659 & t dq test
        let cidParsed = (do -i {$dest | into int})
        if ($cidParsed | describe) == 'int' { main query --cid $cidParsed } else { main query $dest --apps $apps }
      } else { main query --cid $cid }
    }
    _ => { main $operation }
  }
}
