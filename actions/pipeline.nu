#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/06/28 15:33:15
# TODO:
#  [x] 执行流水线要求在仓库目录下，且要有 i 分支 & .termixrc 文件里面的配置正确
#  [x] `t dp -l` 列出所有可用的执行目标
#  [x] 查询流水线可以在任意目录下执行，不一定要在仓库目录下，只要流水线 ID 正确即可
#  [x] 执行新流水线之前可以查询是否有正在运行的流水线，如果有则停止执行，也可以加上 -f 强制执行
#  [x] 执行新流水线之前可以查询同一 Commit 是否已经被部署过，如果部署过则停止执行，也可以加上 -f 强制执行
# Description: 创建 Erda 流水线并执行，同时可以查询流水线执行结果
#   可以 deploy 的 dest 可以为 dev、test、staging、prod 等，对应的流水线配置文件为 .termixrc 中的 erda.dev、erda.test、erda.staging、erda.prod, etc.
#   执行流水线时要求在仓库的 i 分支上的 .termixrc 文件中配置了对应 dest 的 pid、appid、branch、appName、pipeline 信息
#   查询流水线结果时要求流水线ID正确，其他信息不作要求
#   https://erda.cloud/api/terminus/cicds?branches=develop&appID=11147&ymlNames=11147%2FTEST%2Fdevelop%2F.erda%2Fpipelines%2Fnusi.yml%2C%2F.erda%2Fpipelines%2Fnusi.yml&pageNo=1&pageSize=10

def erda-host [] { 'https://erda.cloud' }

# Check if the required environment variable was set, quit if not
def check-envs [operation: string] {
  let envs = $in
  # 部署需要配置全部环境变量，查询操作只需要配置 ERDA_SESSION
  let envs = (match $operation { run|r => $envs, _ => ['ERDA_SESSION'] })
  let emptys = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($emptys | length) > 0 {
    print $'Please set (ansi r)($emptys | str join ',')(ansi reset) in your environment first...'
    exit 1
  }
}

# Try to load environment variables from .termixrc file on i branch, or list available deploy targets
def-env pipeline-prepare [operation: string, dest: string = 'dev', --list: bool] {
  cd $env.JUST_INVOKE_DIR
  # 查询无需加载其他环境变量，也不需要 .termixrc 文件
  if $operation in ['query', 'q'] { return }
  if (has-ref origin/i) {
    let repoConf = (git show 'origin/i:.termixrc' | from toml)
    let targets = ($repoConf.erda | columns | str join ", ")
    if $list { print $'Available deploy targets in origin/i:.termixrc are: (ansi pb)($targets)(ansi reset)'; exit 0 }
    let pipeline = ($repoConf.erda | get -i $dest)
    if ($pipeline | is-empty) {
      print $'Please set the App configs for (ansi r)erda.($dest)(ansi reset) in (ansi r)origin/i:.termixrc(ansi reset) first...'; exit 1
    }
    load-env {
      ERDA_ENV: $pipeline.env,
      ERDA_APP_ID: $pipeline.appid,
      ERDA_BRANCH: $pipeline.branch,
      ERDA_PROJECT_ID: $pipeline.pid,
      ERDA_APP_NAME: $pipeline.appName,
      ERDA_PIPELINE: $pipeline.pipeline,
    }
    return
  }
  print $'No (ansi r)origin/i(ansi reset) branch exits, please create it before running this script...'; exit 1
}

# 检查是否有正在执行的流水线，如果有则显示其概要信息并退出
def check-cicd [aid: int, appName: string, branch: string, pipeline: string, --auth: string] {
  # Possible env values: DEV,TEST,STAGING,PROD
  let cicd = {
    ymlNames: $'($aid)/($env.ERDA_ENV)/($branch)/($pipeline)',
    appID: $aid, branches: $branch, sources: 'dice', pageNo: 1, pageSize: 20
  }
  let cicdUrl = $'(erda-host)/api/terminus/cicds?($cicd | url build-query)'
  print $'Checking running CICDs for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'

  # Query the id of newly created CICD
  let ci = (curl --silent -H $auth $cicdUrl | from json)
  if ($ci | describe) == 'string' { print $'Checking CICD failed with message: (ansi r)($ci)(ansi reset)'; exit 1 }
  # Possible pipeline status: Running,Success,Failed,StopByUser
  if $ci.success {
    let commitID = (git rev-parse $branch)
    let match = ($ci.data.pipelines | where status == 'Running')
    let deployed = ($ci.data.pipelines | where commit == $commitID)
    let nMatch = ($match | length)
    let nDeployed = ($deployed | length)
    if $nMatch == 0 and $nDeployed == 0 { return }
    if $nMatch > 0 {
      print $'There are running pipelines, please wait with patience or re-run with `-f` flag.'
    } else if $nDeployed > 0 {
      print $'The commit (ansi p)($commitID | str substring 0..9)@($branch)(ansi reset) has been deployed, to deploy it again please re-run with `-f` flag.'
    }
    let result = if $nMatch > 0 { $match } else { $deployed }
    print $'------------------------------------------------------------------------------------------------(char nl)'
    print (
      $result
        | select id commit status normalLabels extra timeBegin timeUpdated
        | update commit {|it| $it.commit | str substring 0..9 }
        | upsert Comment {|it| $it.normalLabels.commitDetail | from json | get -i comment | str trim }
        | upsert Commiter {|it| $it.normalLabels.commitDetail | from json | get -i author }
        | update status {|it| $'(ansi pb)($it.status)(ansi reset)' }
        | upsert Runner {|it| $it.extra.runUser.name }
        | upsert Begin {|it| $it.timeBegin | into datetime | date humanize }
        | upsert Updated {|it| $it.timeUpdated | into datetime | date humanize }
        | reject extra timeBegin timeUpdated normalLabels
        | rename ID Commit Status
    )
    exit 0
  }
  print $'(ansi r)Checking CICD failed, Please try again ...(ansi reset)'
  print ($ci | table -e)
  exit 1
}

# 创建 CICD 流水线并返回其对应 ID
def create-cicd [aid: int, appName: string, branch: string, pipeline: string, --auth: string] {
  let cicdUrl = $'(erda-host)/api/terminus/cicds'
  let cicd = { appID: $aid, branch: $branch, pipelineYmlName: $pipeline }
  print $'Initialize CICD for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'

  # Query the id of newly created CICD
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
def query-cicd [id: int, --auth: string] {
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
  dest?: string = 'dev',  # 当操作为 run 时必须指定，用于指定流水线执行的目标环境，如 dev, test, staging, prod 等, query 时无需指定, 默认为 dev
  --cid(-i): int,         # 当操作为 query 时必须指定，用于查询 CICD 执行结果
  --list(-l): bool,       # 当操作为 run 时生效，用于列出所有可用的执行目标
  --force(-f): bool,      # 当操作为 run 时生效，即便已经有正在运行的流水线也会强制执行
] {
  if $list { pipeline-prepare $operation $dest --list } else { pipeline-prepare $operation $dest }
  ['ERDA_SESSION', 'ERDA_ENV', 'ERDA_PROJECT_ID', 'ERDA_APP_ID', 'ERDA_APP_NAME', 'ERDA_PIPELINE', 'ERDA_BRANCH'] | check-envs $operation

  # 用户级别配置，每个开发者根据自己的情况配置, 请注意保密，建议放在本地环境变量里面
  let session = $env.ERDA_SESSION
  # 个人全局身份验证信息，如果过期请重新获取并更新
  let auth = $'cookie: OPENAPISESSION=($session)'

  match $operation {
    run | r => {
      # 以下为应用级别配置，应用的所有开发者保持一致，可以放在代码仓库里面
      let appid = $env.ERDA_APP_ID
      let branch = $env.ERDA_BRANCH
      let pid = $env.ERDA_PROJECT_ID
      let appName = $env.ERDA_APP_NAME
      let pipeline = $env.ERDA_PIPELINE
      if not $force { check-cicd --auth $auth $appid $appName $branch $pipeline }
      let cicdid = (create-cicd --auth $auth $appid $appName $branch $pipeline)
      run-cicd --auth $auth ($cicdid | into int) $appid $pid
    }
    query | q => {
      if ($cid | is-empty) { print $'Please specify the id of the CICD to query with --cid'; exit 1 }
      query-cicd --auth $auth $cid
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
] {
  if not ($cid | is-empty) {
    if ($cid | describe) != 'int' {
      print $'Invalid value for --cid: (ansi r)($cid)(ansi reset), should be an integer number.'; exit 1
    }
    main query --cid $cid; return
  }
  if $list { main $operation $dest --list } else {
    if $force { main $operation $dest --force } else { main $operation $dest }
  }
}
