# Useful commands for daily works
# Create: 2021/09/11 21:47:29
# Ref:
#   1. https://github.com/casey/just
#   2. https://www.nushell.sh/book/
#   3. https://github.com/dylanaraps/pure-bash-bible
#   4. https://github.com/Idnan/bash-guide
#   5. https://github.com/denysdovhan/bash-handbook
# Author: M.J.

set shell := ['nu', '-m', 'light', '-c']

# The export setting causes all just variables
# to be exported as environment variables.

set export := true
set dotenv-load := true

# If positional-arguments is true, recipe arguments will be
# passed as positional arguments to commands. For linewise
# recipes, argument $0 will be the name of the recipe.

set positional-arguments := true

# Use `just --evaluate` to show env vars

_termix := env_var('TERMIX_DIR')
# Used to handle the path separator issue
JUST_FILE_PATH := justfile()
NU_DIR := parent_directory(`(which nu).path.0`)
_s := if os_family() == 'windows' { '\' } else { '/' }
_home_env := if os_family() == 'windows' { 'USERPROFILE' } else { 'HOME' }
# FIXME: A just bug: invalid directory path by invoking invocation_directory
JUST_INVOKE_DIR := replace(invocation_directory_native(), '/', _s)
_default_just_file := join(env_var(_home_env), '.justfile')
_null_device := if os_family() == 'windows' { '\\.\NUL' } else { '/dev/null' }
_query_plugin := if os_family() == 'windows' { 'nu_plugin_query.exe' } else { 'nu_plugin_query' }
_gstat_plugin := if os_family() == 'windows' { 'nu_plugin_gstat.exe' } else { 'nu_plugin_gstat' }

# Just commands aliases
# alias pa := pull-all
# alias rt := tag-redev
# alias gb := git-branch
# alias pr := pull-redev
# alias lt := ls-redev-tags
# alias rb := git-remote-branch
alias dp := deploy
alias ta := terp-assets
alias dq := deploy-query

# To pass arguments to a dependency, put the dependency
# in parentheses along with the arguments, just like:
# default: (sh-cmd "main")

# List available commands by default
default: _setup
  @let defaultJustFile = '{{_default_just_file}}'; \
    let justfile = if ($defaultJustFile | path expand | path exists) { $defaultJustFile } else { "Justfile" }; \
    just --justfile $justfile --list --list-prefix "··· "

# Display termix current version number
ver: _setup
  @cd $env.TERMIX_DIR; let ver = (open termix.toml | get version); { \
  version: $ver, commit: (git rev-parse $ver e> {{_null_device}} | str substring 0..7), \
  manual: 'https://fe-docs.app.terminus.io/termix/termix-nu' } | print

# Synchronize doc from termix-nu to fe-docs repo
[private]
sync-doc: _setup
  @let doc = '../fe-docs/docs/termix'; cd $env.TERMIX_DIR; cp README.md $'($doc)/termix-nu.md'; \
    cp FAQ.md $'($doc)/termix-FAQ.md'; cp CHANGELOG.md $'($doc)/termix-CHANGELOG.md';

# Upgrade termix-nu repo, just or nushell to the latest version
upgrade *OPTIONS:
  @overlay use {{ join(_termix, 'actions', 'upgrade.nu') }}; upgrade-tool {{OPTIONS}}

# Release a new version for termix-nu
[private]
release  *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'actions', 'release.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    release {{OPTIONS}}

# Quickly open the matched nav url in default browser, for mac or windows with powershell
go nav=('list'): _setup
  @overlay use {{ join(_termix, 'actions', 'quick-nav.nu') }}; \
    go {{nav}}

# TERP Meta data synchronization tool
msync *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'meta-sync.nu') }}; \
    meta sync {{OPTIONS}}

# Download, transfer or sync TERP assets
terp-assets *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'terp-assets.nu') }}; \
    terp assets {{OPTIONS}}

# Run an Erda pipeline, the target can be queried by `dp -l`, default is `dev`, and use `--app` to specify the apps to deploy
deploy *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'pipeline.nu') }}; \
    erda-deploy {{OPTIONS}}

# Query the Erda pipeline running status by CICD id or `--app`
deploy-query *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'pipeline.nu') }}; \
    erda-query {{OPTIONS}}

# Send a message to DingTalk Group by a custom robot
ding-msg *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'dingtalk-notify.nu') }}; \
    dingtalk notify {{OPTIONS}}

# Query node dependencies in all package.json files on specified branches
query-deps *OPTIONS: _setup
  @# The following two statement must be written in one line
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'actions', 'query-deps.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; query deps {{OPTIONS}}

# Listing the branches of a git repo and the time of the last commit
git-branch *OPTIONS: _setup
  @# The following two statement must be written in one line
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git-branch {{OPTIONS}}

# Show insertions/deletions and number of files changed for each commit
git-stat *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'git-stat.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git stat {{OPTIONS}}

# Listing the remote branches of a git repo with the extra info
git-remote-branch *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'remote-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    git-remote-branch {{OPTIONS}}

# Show commit info diff between two commits, e.g. t git-diff-commit 051da464 0ab1df2d
git-diff-commit *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'diff-commit.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    git diff-commit {{OPTIONS}}

# Show branch description from branch description file `d` of `i` branch
desc *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'branch-desc.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    branch-desc {{OPTIONS}}

# Check whether all remote branches have descriptions or whether synced branches exist in the remote repo
check-branch: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'check-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; check-branch

# Pull all local branches from remote repo
pull-all: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'pull-all.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git pull-all {{JUST_INVOKE_DIR}} 'origin'

# Rename remote branch, and delete old branch after rename
rename-branch *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'rename-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git branch-rename {{OPTIONS}}

# 显示本机安装应用版本及环境变量相关信息
show-env: _setup
  @overlay use {{ join(_termix, 'actions', 'show-env.nu') }}; \
    show-env

# 查询已发布Node版本，支持指定最低版本号
ls-node *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'ls-node.nu') }}; \
    ls-node-remote {{OPTIONS}}

# 按时间顺序列出所有的 git tags, 默认按 `time` 排序，可选按 `tag` 排序：ls-tags tag
ls-tags by=('time'): _setup
  @let sort = if ('{{by}}' != 'time') { '--sort=-v:refname' } else { '--sort=-creatordate' }; print (char nl); \
    git tag --format='%(refname:strip=2)%09%(creatordate:iso)' $sort \
      | detect columns -n \
      | rename tag date time \
      | upsert time {|e| $'($e.date) ($e.time)' } \
      | select tag time

# 通过 Brew 国内镜像加速执行 brew 相关命令
brew *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'brew-speed-up.nu') }}; \
    fast-brew {{OPTIONS}}

# 开启或者关闭 git 代理, 目前仅支持在阿里郎加速模式下开启 git 代理
git-proxy status=('on'): _setup
  @load-env { GIT_PROXY_STATUS: '{{status}}' }; \
    nu {{ join(_termix, 'git', 'git-proxy.nu') }}

# 查询团队本周工时填报情况
emp *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'working-hours.nu') }}; \
    query-hours-by-team-codes {{OPTIONS}}

# 手工执行定时任务检查 EMP 工时填报情况并提醒
[private]
emp-daily *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'working-hours.nu') }}; \
    working-hours-daily-checking {{OPTIONS}}

# Get the latest nightly build of Nu
[private]
nu-use-nightly *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'nu-nightly.nu') }}; get-latest-nightly-build {{OPTIONS}}

# 给标品源码仓库打 Release Tag
[private]
gaia-release version=('') repos=('mall,mobile,picker') delete=('false'): _setup
  @overlay use {{ join(_termix, 'actions', 'gaia-release.nu') }}; \
    gaia-release {{version}} {{repos}} --delete-tag={{delete}}

# Transfer a git repo from source to the dest
repo-transfer *OPTIONS: _setup
  @overlay use {{ join(_termix, 'git', 'repo-transfer.nu') }}; \
    git repo-transfer {{OPTIONS}}

# t pull-redev true
# 更新远程二开仓库代码到本地, 可以指定分支和仓库分组多个分组之间用`,`隔开
[private]
pull-redev branch=('master') group=('b2c,b2b,mbr,pik') diff=('false'): _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'actions', 'pull-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git pull-redev {{branch}} {{group}} --show-diff={{diff}}

# Use tag=('v2.0.2') to set default $1
# delete: 是否删除当前日期对应的二开标签，且不重新打标, 只有为true的时候才删除，其他情况会重新打标
# 给远程二开仓库批量打 Tag, 可以指定分支和仓库分组多个分组之间用`,`隔开
[private]
tag-redev tag=('') branch=('master') group=('b2c,b2b,mbr,pik') delete=('false'): _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'actions', 'tag-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git tag-redev '{{tag}}' {{branch}} {{group}} --delete-tag={{delete}}

# Show Branches and Tags of redevelop related repos, 可以指定仓库分组多个分组之间用`,`隔开
[private]
ls-redev-refs group=('b2c,b2b,mbr,pik') showBranch=('false'): _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'actions', 'ls-redev-refs.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git ls-redev-refs {{group}} --show-branches={{showBranch}}

# 批量同步本地分支到远程指定分支,git pre-push hooks调用,请勿手工触发
[private]
git-sync-branch localRef localOid remoteRef: _setup
  @overlay use {{ join(_termix, 'git', 'sync-branch.nu') }}; \
    git sync-branch {{localRef}} {{localOid}} {{remoteRef}}

# 手工触发批量同步本地分支到远程指定分支
gsync *OPTIONS: _setup
  @overlay use {{ join(_termix, 'git', 'trigger-sync.nu') }}; \
    git trigger-sync {{OPTIONS}}

# Clean possibly unused branches of synced dest repos
[private]
prune-synced-branches dryRun=('true') user=('git') ak=('-'): _setup
  @overlay use {{ join(_termix, 'actions', 'prune-synced-branches.nu') }}; \
    prune-synced-branches --dry-run={{dryRun}} --user={{user}} --ak={{ak}}

# 复用 utils 里面定义的公用方法: nu 不支持动态 source 只能拼接下了
# 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用`,`分隔
git-batch-exec *OPTIONS: _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'git-batch-exec.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-exec {{OPTIONS}}

# 将指定Git分支硬回滚N个commit
[private]
git-batch-reset n +branches=(''): _setup
  @use {{ join(_termix, 'utils', 'common.nu') }} [git-check]; \
    overlay use {{ join(_termix, 'git', 'git-batch-reset.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-reset {{n}} '{{branches}}'

# 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
dir-batch-exec *OPTIONS: _setup
  @overlay use {{ join(_termix, 'actions', 'dir-batch-exec.nu') }}; \
    dir-batch-exec {{OPTIONS}}

# 版本检查前置操作
_setup: _register_plugins
  @overlay use {{ join(_termix, 'actions', 'check-ver.nu') }}; \
    termix-ver; nu-ver; just-ver

# 从 Nu v0.61.0 开始插件只需注册一次即可
_register_plugins:
  #!/usr/bin/env nu
  let gstatExists = not (scope commands | where name == 'gstat' | is-empty)
  let queryExists = not (scope commands | where name == 'query json' | is-empty)
  if not $queryExists { register {{ join(NU_DIR, _query_plugin) }} }
  if not $gstatExists { register {{ join(NU_DIR, _gstat_plugin) }} }
