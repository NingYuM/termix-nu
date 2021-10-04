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
_compose_cmd := join(_termix, join('utils', 'compose-cmd.nu'))
_git_batch_exec := join(_termix, join('git', 'git-batch-exec.nu'))
_dir_batch_exec := join(_termix, join('actions', 'dir-batch-exec.nu'))
_git_batch_exec_all := join(_termix, join('run', '.git-batch-exec-compose.nu'))
_dir_batch_exec_all := join(_termix, join('run', '.dir-batch-exec-compose.nu'))

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
default:
    @just --list --list-prefix '··· '

# Listing the branches of a git repo and the time of the last commit
git-age:
    # The following two statement must be written in one line
    @let-env JUST_INVOKE_DIRECTORY = {{JUST_INVOKE_DIR}}; \
      nu {{ join(_termix, join('git', 'age.nu')) }}

# Pull all local branches from remote repo
pull-all:
    @nu {{ join(_termix, join('git', 'pull-all.nu')) }}

# Listing the remote branches of a git repo and the day of the last commit
git-remote-age remote=('origin'):
    @let-env REMOTE_ALIAS = {{remote}}; \
      nu {{ join(_termix, join('git', 'remote-age.nu')) }}

# 列出远程二开仓库 Tags
ls-redev-tags:
    @nu {{ join(_termix, join('git', 'ls-redev-tag.nu')) }}

# 显示本机安装应用版本及环境变量相关信息
show-env:
    @nu {{ join(_termix, join('actions', 'show-env.nu')) }}

# t pull-redev true
# 更新远程二开仓库代码到本地
pull-redev branch=('master') diff=('false'):
    @let-env SHOW_REDEV_DIFF = {{diff}}; \
      let-env DEST_REDEV_BRANCH = {{branch}}; \
      nu {{ join(_termix, join('git', 'pull-redev.nu')) }}

# Use tag=('v2.0.2') to set default $1
# delete: 是否删除当前日期对应的二开标签，且不重新打标, 只有为true的时候才删除，其他情况会重新打标
# 给远程二开仓库批量打 Tag
tag-redev tag=('') branch=('master') delete=('false'):
    @let-env CURRENT_BE_TAG = '{{tag}}'; \
      let-env TAG_DELETE_MODE = {{delete}}; \
      let-env DEST_REDEV_BRANCH = {{branch}}; \
      nu {{ join(_termix, join('git', 'tag-redev.nu')) }}

# 批量同步本地分支到远程指定分支,git pre-push hooks调用,请勿手工触发
git-sync-branch localRef localOid remoteRef:
    @let-env PUSH_LOCAL_REF = {{localRef}}; \
      let-env PUSH_LOCAL_OID = {{localOid}}; \
      let-env PUSH_REMOTE_REF = {{remoteRef}}; \
      nu {{ join(_termix, join('git', 'sync-branch.nu')) }}

# 复用 utils 里面定义的公用方法: nu 不支持动态 source 只能拼接下了
# 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用空格分隔
git-batch-exec cmd +branches=(''):
    @let-env BATCH_EXEC_CMD = '{{cmd}}'; \
      let-env BATCH_EXEC_BRANCHES = '{{branches}}'; \
      [(open {{_git_batch_exec}}) $'(char nl)' (open {{_compose_cmd}})] | str collect | save {{_git_batch_exec_all}}; \
      nu {{ _git_batch_exec_all }}

# 将指定Git分支硬回滚N个commit
git-batch-reset n +branches=(''):
    @let-env BATCH_RESET_COUNT = {{n}}; \
      let-env BATCH_RESET_BRANCHES = '{{branches}}'; \
      nu {{ join(_termix, join('git', 'git-batch-reset.nu')) }}

# 拼接复用 utils 里面定义的公用方法: https://github.com/nushell/nushell/issues/2990
# 在指定目录或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
dir-batch-exec cmd +DIRS=(''):
    @load-env [[name, value]; ['BATCH_EXEC_CMD', '{{cmd}}'] ['BATCH_EXEC_DIRS', '{{DIRS}}']]; \
      [(open {{_dir_batch_exec}}) $'(char nl)' (open {{_compose_cmd}})] | str collect | save {{_dir_batch_exec_all}}; \
      nu {{ _dir_batch_exec_all }}
