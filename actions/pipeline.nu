#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/06/28 15:33:15
# Description: 创建 Erda 流水线并执行，同时可以查询流水线执行结果

# Check if the required environment variable was set, quit if not
def check-envs [] {
    let emptys = ($in | filter {|it| $env | get -i $it | is-empty })
    if ($emptys | length) > 0 {
        print $'Please set (ansi r)($emptys | str join ',')(ansi reset) in your environment first...'
        exit 1
    }
}

# Try to load environment variables from .termixrc file on i branch
def-env try-load-envs [dest: string = 'dev'] {
    cd $env.JUST_INVOKE_DIR
    if (has-ref origin/i) {
        let repoConf = (git show 'origin/i:.termixrc' | from toml)
        let pipeline = ($repoConf.erda | get -i $dest)
        if not ($pipeline | is-empty) {
            load-env {
                ERDA_APP_ID: $pipeline.appid,
                ERDA_BRANCH: $pipeline.branch,
                ERDA_PROJECT_ID: $pipeline.pid,
                ERDA_APP_NAME: $pipeline.appName,
                ERDA_PIPELINE:'.erda/pipelines/nusi.yml',
            }
        }
    }
}

# 创建 CICD 流水线并返回其对应 ID
def create-cicd [aid: int, appName: string, branch: string, pipeline: string, --auth: string] {
    let cicdUrl = 'https://erda.cloud/api/terminus/cicds'
    let cicd = {
        appID: $aid,
        branch: $branch,
        pipelineYmlName: $pipeline
    }
    print $'Initialize CICD for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'
    # Query the id of newly created CICD
    let ci = (curl --silent -H $auth --data-raw $'($cicd | to json)' $cicdUrl | from json)
    if $ci.success {
        print $'(ansi g)Initialize CICD successfully...(ansi reset)'
        return $ci.data.id
    } else {
        print $'(ansi r)Initialize CICD failed, Please try again ...(ansi reset)'
        print ($ci | table -e)
        exit 1
    }
}

# 执行指定 ID 的流水线
def run-cicd [id: int, --auth: string] {
    let runUrl = $'https://erda.cloud/api/terminus/cicds/($id)/actions/run'
    let run = (curl --silent -H $auth -X POST $runUrl | from json)
    if $run.success {
        print $'CICD started, You can query the pipeline running status with id: (ansi g)($id)(ansi reset)'
    }
}

# 根据流水线 ID 查询流水线执行结果
def query-cicd [id: int, appid: int, pid: int, --auth: string] {
    let queryUrl = $'https://erda.cloud/api/terminus/pipelines/($id)'
    let query = (curl --silent -H $auth $queryUrl | from json)
    if (not $query.success ) {
        print $'Query CICD failed with error message: (ansi r)($query.err.msg)(ansi reset)'; exit 1
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
        URL: $'https://erda.cloud/terminus/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
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
] {
    try-load-envs $dest
    ['ERDA_SESSION', 'ERDA_TOKEN', 'ERDA_PROJECT_ID', 'ERDA_APP_ID', 'ERDA_APP_NAME', 'ERDA_PIPELINE', 'ERDA_BRANCH'] | check-envs
    # 以下为应用级别配置，应用的所有开发者保持一致，可以放在代码仓库里面
    let pid = $env.ERDA_PROJECT_ID
    let appid = $env.ERDA_APP_ID
    let appName = $env.ERDA_APP_NAME
    let pipeline = $env.ERDA_PIPELINE
    let branch = $env.ERDA_BRANCH

    # 以下为用户级别配置，每个开发者根据自己的情况配置, 请注意保密，建议放在本地环境变量里面
    let token = $env.ERDA_TOKEN
    let session = $env.ERDA_SESSION

    # 个人全局身份验证信息，如果过期请重新获取并更新
    let auth = $'cookie: u_c_erda_cloud=($token);OPENAPISESSION=($session)'
    match $operation {
        run | r => {
            let cicdid = (create-cicd --auth $auth $appid $appName $branch $pipeline)
            run-cicd --auth $auth ($cicdid | into int)
        }
        query | q => {
            if ($cid | is-empty) {
                print $'Please specify the id of the CICD to query with --cid'
                exit 1
            }
            query-cicd --auth $auth $cid $appid $pid
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
    --cid(-i): int,         # 当操作为 query 时必须指定，用于查询 CICD 执行结果
] {
    if ($cid | is-empty) { main $operation $dest } else { main query --cid $cid }
}
