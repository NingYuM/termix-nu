# Useful commands for daily works
# Create: 2021/09/11 21:47:29
# Ref:
#   1. https://github.com/casey/just
#   2. https://www.nushell.sh/book/
#   3. https://github.com/dylanaraps/pure-bash-bible
#   4. https://github.com/Idnan/bash-guide
#   5. https://github.com/denysdovhan/bash-handbook
# Author: M.J.

set shell := ['nu', '-c']

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
# Used to handle the path seperator issue
_s := if os_family() == "windows" { '\' } else { '/' }
JUST_FILE_PATH := justfile()
# FIXME: A just bug: invalid directory path by invoking invocation_directory
JUST_INVOKE_DIR := replace(replace(invocation_directory(), '/', _s), '\d\', 'D:\')

# Just commands aliases
# alias ag := git-age
# alias pa := pull-all
# alias rt := tag-redev
# alias pr := pull-redev
# alias ra := git-remote-age
# alias lt := ls-redev-tags

# To pass arguments to a dependency, put the dependency
# in parentheses along with the arguments, just like:
# default: (sh-cmd "main")

# List available commands by default
default: _nu-ver-check
  @just --list --list-prefix '··· '

# Display termix current version number
ver: _nu-ver-check
  @^echo (open $'($nu.env.TERMIX_DIR)/termix.toml' | get version)

# Upgrade termix-nu repo to the latest version
upgrade: _nu-ver-check
  @cd {{_termix}}; git checkout master; git pull;

# Quickly open the matched nav url in default browser, for mac only
go nav=('list'): _nu-ver-check
  @source {{ join(_termix, 'actions', 'quick-nav.nu') }}; \
    go {{nav}}

# Listing the branches of a git repo and the time of the last commit
git-age: _nu-ver-check
  @# The following two statement must be written in one line
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'age.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git age {{JUST_INVOKE_DIR}}

# Show branch description from branch description file `d` of `i` branch
desc branch=(`git branch --show-current`)  showNotes=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'branch-desc.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; branch-desc {{branch}} --show-notes={{showNotes}}

# Check whether all remote branches have related description
check-desc: _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'check-desc.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; check-desc

# Pull all local branches from remote repo
pull-all: _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'pull-all.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git pull-all {{JUST_INVOKE_DIR}} 'origin'

# Rename remote branch, and delete old branch after rename
rename-branch from=('') to=('') remote=('origin'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'rename-branch.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git branch-rename {{from}} {{to}} {{remote}}

# Listing the remote branches of a git repo and the day of the last commit
git-remote-age remote=('origin')  showTag=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'remote-age.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git remote-age {{JUST_INVOKE_DIR}} {{remote}} --show-tag={{showTag}}

# Show Branches and Tags of redevelop related repos
ls-redev-refs showBranch=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'age.nu') }}; \
    source {{ join(_termix, 'git', 'ls-redev-refs.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; git ls-redev-refs --show-branches={{showBranch}}

# 显示本机安装应用版本及环境变量相关信息
show-env: _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'actions', 'show-env.nu') }}; \
    show-env

# 查询已发布Node版本，支持指定最低版本号
ls-node minVer=('12') isLts=('false'): _nu-ver-check
  @source {{ join(_termix, 'actions', 'ls-node.nu') }}; \
    ls-node-remote {{minVer}} {{isLts}}

# 查询电商前端团队本周工时填报情况
emp showAll=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'actions', 'working-hours.nu') }}; \
    working-hours --show-all={{showAll}}

# t pull-redev true
# 更新远程二开仓库代码到本地
pull-redev branch=('master') diff=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'pull-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; git pull-redev {{branch}} --show-diff={{diff}}

# Use tag=('v2.0.2') to set default $1
# delete: 是否删除当前日期对应的二开标签，且不重新打标, 只有为true的时候才删除，其他情况会重新打标
# 给远程二开仓库批量打 Tag
tag-redev tag=('') branch=('master') delete=('false'): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'tag-redev.nu') }}; \
    git-check --check-repo=0 {{JUST_INVOKE_DIR}}; git tag-redev '{{tag}}' {{branch}} --delete-tag={{delete}}

# 批量同步本地分支到远程指定分支,git pre-push hooks调用,请勿手工触发
git-sync-branch localRef localOid remoteRef: _nu-ver-check
  @source {{ join(_termix, 'git', 'sync-branch.nu') }}; \
    git sync-branch {{localRef}} {{localOid}} {{remoteRef}}

# 复用 utils 里面定义的公用方法: nu 不支持动态 source 只能拼接下了
# 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用空格分隔
git-batch-exec cmd +branches=(''): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'utils', 'compose-cmd.nu') }}; \
    source {{ join(_termix, 'git', 'git-batch-exec.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-exec '{{cmd}}' '{{branches}}'

# 将指定Git分支硬回滚N个commit
git-batch-reset n +branches=(''): _nu-ver-check
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'git', 'git-batch-reset.nu') }}; \
    git-check --check-repo=1 {{JUST_INVOKE_DIR}}; git batch-reset {{n}} '{{branches}}'

# 拼接复用 utils 里面定义的公用方法: https://github.com/nushell/nushell/issues/2990
# 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
dir-batch-exec cmd +DIRS=(''): _nu-ver-check
  @# load-env [[name, value]; ['BATCH_EXEC_CMD', '{{cmd}}'] ['BATCH_EXEC_DIRS', '{{DIRS}}']]
  @source {{ join(_termix, 'utils', 'common.nu') }}; \
    source {{ join(_termix, 'utils', 'compose-cmd.nu') }}; \
    source {{ join(_termix, 'actions', 'dir-batch-exec.nu') }}; \
    dir-batch-exec '{{cmd}}' '{{DIRS}}' --parent={{JUST_INVOKE_DIR}}

_nu-ver-check:
  @nu {{ join(_termix, 'actions', 'nu-ver.nu') }}
