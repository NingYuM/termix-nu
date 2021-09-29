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

# If positional-arguments is true, recipe arguments will be
# passed as positional arguments to commands. For linewise
# recipes, argument $0 will be the name of the recipe.

set positional-arguments := true

# Use `just --evaluate` to show env vars

JUST_INVOKE_DIR := invocation_directory()
TERMIX_DIR := '/Users/hustcer/github/terminus/termix-nu'

# Just commands aliases
# alias ag := git-age
# alias pa := pull-all
# alias rt := tag-redev
# alias pr := pull-redev
# alias ra := git-remote-age
# alias lt := ls-remote-tags

# To pass arguments to a dependency, put the dependency
# in parentheses along with the arguments, just like:
# default: (sh-cmd "main")

# List available commands by default
default:
    @just --list --list-prefix '··· '

# Listing the branches of a git repo and the day of the last commit
git-age:
    # The following two statement must be written in one line
    @let-env JUST_INVOKE_DIRECTORY = {{ invocation_directory() }}; \
      nu "$TERMIX_DIR/git/age.nu";

# Pull all local branches from remote repo
pull-all:
    @nu "$TERMIX_DIR/git/pull-all.nu";

# Listing the remote branches of a git repo and the day of the last commit
git-remote-age remote=('origin'):
    #!/usr/bin/env bash
    set -euo pipefail;

    export REMOTE_ALIAS="$remote";
    nu "$TERMIX_DIR/git/remote-age.nu";

# 列出远程二开仓库 Tags
ls-remote-tags:
    @nu "$TERMIX_DIR/git/ls-remote-tag.nu";

# t pull-redev true
# 更新远程二开仓库代码到本地
pull-redev branch=('master') diff=('false'):
    #!/usr/bin/env bash
    set -euo pipefail;

    export SHOW_REDEV_DIFF="$diff";
    export DEST_REDEV_BRANCH="$branch";
    nu "$TERMIX_DIR/git/pull-redev.nu";

# Use tag=('v2.0.2') to set default $1
# delete: 是否删除当前日期对应的二开标签，且不重新打标, 只有为true的时候才删除，其他情况会重新打标
# 给远程二开仓库批量打 Tag
tag-redev tag=('') branch=('master') delete=('false'):
    #!/usr/bin/env bash
    # set -e makes bash exit if a command fails.
    # set -u makes bash exit if a variable is undefined.
    # set -x makes bash print each script line before it’s run.
    # set -o pipefail makes bash exit if a command in a pipeline fails.
    set -euo pipefail

    export CURRENT_BE_TAG="$tag";
    export TAG_DELETE_MODE="$delete";
    export DEST_REDEV_BRANCH="$branch";
    nu "$TERMIX_DIR/git/tag-redev.nu";

# 批量同步本地分支到远程指定分支
git-sync-branch localRef localOid:
    #!/usr/bin/env bash
    set -euo pipefail;

    export PUSH_LOCAL_REF="$localRef";
    export PUSH_LOCAL_OID="$localOid";
    nu "$TERMIX_DIR/git/sync-branch.nu";

# 在指定git分支上执行指定命令, cmd为待执行命令字符串
git-batch-exec cmd +branches=(''):
    #!/usr/bin/env bash
    set -euo pipefail;

    export BATCH_EXEC_CMD="$cmd";
    export BATCH_EXEC_BRANCHES="$branches";
    nu "$TERMIX_DIR/git/git-batch-exec.nu";

# 将指定Git分支硬回滚N个commit
git-batch-reset n +branches=(''):
    #!/usr/bin/env bash
    set -euo pipefail;

    export BATCH_RESET_COUNT="$n";
    export BATCH_RESET_BRANCHES="$branches";
    nu "$TERMIX_DIR/git/git-batch-reset.nu";

# 在指定目录下的所有子目录里执行指定命令, cmd为待执行命令字符串
dir-batch-exec cmd +DIRS=(''):
    #!/usr/bin/env bash
    set -euo pipefail;

    export BATCH_EXEC_CMD="$cmd";
    export BATCH_EXEC_DIRS="$DIRS";
    nu "$TERMIX_DIR/actions/dir-batch-exec.nu";
