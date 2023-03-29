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
_query_plugin := if os_family() == 'windows' { 'nu_plugin_query.exe' } else { 'nu_plugin_query' }
_gstat_plugin := if os_family() == 'windows' { 'nu_plugin_gstat.exe' } else { 'nu_plugin_gstat' }

# Just commands aliases
# alias pa := pull-all
# alias rt := tag-redev
# alias gb := git-branch
# alias pr := pull-redev
# alias lt := ls-redev-tags
# alias rb := git-remote-branch

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
  @print (open $'($env.TERMIX_DIR)/termix.toml' | get version)

# Upgrade termix-nu repo to the latest version
upgrade:
  @cd {{_termix}}; git checkout master; git pull origin (git tag -l --sort=-v:refname | lines | select 0) --ff-only;

# Release a new version for termix-nu
release  updateLog=('false') forceUpgrade=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'release.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    release --update-log={{updateLog}} --force-upgrade={{forceUpgrade}}

# Quickly open the matched nav url in default browser, for mac or windows with powershell
go nav=('list'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'quick-nav.nu') }}; \
    go {{nav}}

# Listing the branches of a git repo and the time of the last commit
git-branch: _setup
  @# The following two statement must be written in one line
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'git.nu') }}; \
    overlay use {{ join(_termix, 'git', 'branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git-branch {{JUST_INVOKE_DIR}}

# Show insertions/deletions and number of files changed for each commit
git-stat count=('20') author=('*'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'git-stat.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git stat {{JUST_INVOKE_DIR}} --count={{count}} --author={{author}}

# Listing the remote branches of a git repo with the extra info
git-remote-branch remote=('origin')  showTag=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'git.nu') }}; \
    overlay use {{ join(_termix, 'git', 'remote-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    git-remote-branch {{JUST_INVOKE_DIR}} {{remote}} --show-tag={{showTag}}

# Show branch description from branch description file `d` of `i` branch
desc branch=(`git branch --show-current`) showNotes=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'branch-desc.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; \
    branch-desc {{branch}} --show-notes={{showNotes}}

# Check whether all remote branches have descriptions or whether synced branches exist in the remote repo
check-branch: _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'check-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; check-branch

# Pull all local branches from remote repo
pull-all: _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'pull-all.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git pull-all {{JUST_INVOKE_DIR}} 'origin'

# Rename remote branch, and delete old branch after rename
rename-branch from=('') to=('') remote=('origin'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'rename-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git branch-rename {{from}} {{to}} {{remote}}

# 显示本机安装应用版本及环境变量相关信息
show-env: _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'show-env.nu') }}; \
    show-env

# 查询已发布Node版本，支持指定最低版本号
ls-node minVer=('12') isLts=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'ls-node.nu') }}; \
    ls-node-remote '{{minVer}}' {{isLts}}

# 开启或者关闭 Brew 国内镜像加速
brew-speed-up status=('on'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'brew-speed-up.nu') }}; \
    brew-speed-up {{status}}

# 开启或者关闭 git 代理, 目前仅支持在阿里郎加速模式下开启 git 代理
git-proxy status=('on'): _setup
  @load-env { GIT_PROXY_STATUS: '{{status}}' }; \
    overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    nu {{ join(_termix, 'git', 'git-proxy.nu') }}

# 查询电商前端团队本周工时填报情况
emp showAll=('false') showPrev=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'working-hours.nu') }}; \
    let codes = (get-env EMP_PROJECT_CODE '' | split row ','); \
    $codes | each { |code| working-hours $code --show-all={{showAll}} --show-prev={{showPrev}} } | flatten | uniq

# 给标品源码仓库打 Release Tag
gaia-release version=('') repos=('mall,mobile,picker') delete=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'gaia-release.nu') }}; \
    gaia-release {{version}} {{repos}} --delete-tag={{delete}}

# Transfer a git repo from source to the dest
repo-transfer from=('') to=(''): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'repo-transfer.nu') }}; \
    git repo-transfer {{from}} {{to}}

# t pull-redev true
# 更新远程二开仓库代码到本地, 可以指定分支和仓库分组多个分组之间用`,`隔开
pull-redev branch=('master') group=('b2c,b2b,mbr,pik') diff=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'pull-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git pull-redev {{branch}} {{group}} --show-diff={{diff}}

# Use tag=('v2.0.2') to set default $1
# delete: 是否删除当前日期对应的二开标签，且不重新打标, 只有为true的时候才删除，其他情况会重新打标
# 给远程二开仓库批量打 Tag, 可以指定分支和仓库分组多个分组之间用`,`隔开
tag-redev tag=('') branch=('master') group=('b2c,b2b,mbr,pik') delete=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'tag-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git tag-redev '{{tag}}' {{branch}} {{group}} --delete-tag={{delete}}

# Show Branches and Tags of redevelop related repos, 可以指定仓库分组多个分组之间用`,`隔开
ls-redev-refs group=('b2c,b2b,mbr,pik') showBranch=('false'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'git.nu') }}; \
    overlay use {{ join(_termix, 'git', 'branch.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'ls-redev-refs.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; \
    git ls-redev-refs {{group}} --show-branches={{showBranch}}

# 批量同步本地分支到远程指定分支,git pre-push hooks调用,请勿手工触发
[private]
git-sync-branch localRef localOid remoteRef: _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'git.nu') }}; \
    overlay use {{ join(_termix, 'git', 'sync-branch.nu') }}; \
    git sync-branch {{localRef}} {{localOid}} {{remoteRef}}

# 手工触发批量同步本地分支到远程指定分支
trigger-sync branch=(`git branch --show-current`): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'git.nu') }}; \
    overlay use {{ join(_termix, 'git', 'trigger-sync.nu') }}; \
    git trigger-sync {{branch}}

# Clean possibly unused branches of synced dest repos
prune-synced-branches dryRun=('true') user=('git') ak=('-'): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'prune-synced-branches.nu') }}; \
    prune-synced-branches --dry-run={{dryRun}} --user={{user}} --ak={{ak}}

# 复用 utils 里面定义的公用方法: nu 不支持动态 source 只能拼接下了
# 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用空格分隔
git-batch-exec cmd +branches=(''): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'compose-cmd.nu') }}; \
    overlay use {{ join(_termix, 'git', 'git-batch-exec.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-exec '{{cmd}}' '{{branches}}'

# 将指定Git分支硬回滚N个commit
git-batch-reset n +branches=(''): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'git', 'git-batch-reset.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-reset {{n}} '{{branches}}'

# 拼接复用 utils 里面定义的公用方法: https://github.com/nushell/nushell/issues/2990
# 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
dir-batch-exec cmd +DIRS=(''): _setup
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'utils', 'compose-cmd.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'dir-batch-exec.nu') }}; \
    dir-batch-exec "{{cmd}}" "{{DIRS}}" --parent={{JUST_INVOKE_DIR}}

# 版本检查前置操作
_setup: _register_plugins
  @overlay use {{ join(_termix, 'utils', 'common.nu') }}; \
    overlay use {{ join(_termix, 'actions', 'check-ver.nu') }}; \
    termix-ver; nu-ver; just-ver

# 从 Nu v0.61.0 开始插件只需注册一次即可
_register_plugins:
  #!/usr/bin/env nu
  let gstatExists = not ($nu.scope.commands | where name == 'gstat' | is-empty)
  let queryExists = not ($nu.scope.commands | where name == 'query json' | is-empty)
  if not $queryExists { register {{ join(NU_DIR, _query_plugin) }} }
  if not $gstatExists { register {{ join(NU_DIR, _gstat_plugin) }} }
