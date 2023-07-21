#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t pull-redev
#   t pull-redev develop
#   t pull-redev master true

# 列出远程二开仓库 Tags
export def 'git pull-redev' [
  branch: string            # Specify the branch to pull
  group: string             # Specify the groups of repo to update
  --show-diff(-d): any      # Set to 'true' if you want to see the files changed since prev tag, defined as `any` acutually `bool`
] {

  # FIXME
  let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)
  let repoPath = (get-tmp-path)
  let redevRepos = (open $_TERMIX_CONF | get redevRepos)
  let filteredRepos = ($redevRepos | where $',($group),' =~ $it.group)
  if ($filteredRepos | length) > 0 {
    print $'(ansi p)Found the following matched repos:(ansi reset)(char nl)(char nl)'
    print $filteredRepos
  } else {
    print $'(ansi r)Can not find any matched repos, bye...(ansi reset)(char nl)'
    exit 3
  }
  print $'Pull remote redevelop repos in directory (ansi g)($repoPath)(ansi reset):(char nl)'

  # 此处迭代变量不要采用默认的 `$it`, 否则会出错，坑爹啊……
  # It's better to have a named param on blocks because $it can be consumed and lost.
  # Ref: https://github.com/nushell/nushell/issues/4060
  $filteredRepos | each { |repo|
    let repoNameIdx = ($repo.url | str index-of -e '/') + 1
    let repoName = ($repo.url | str substring $repoNameIdx..)
    # 单一二开仓库完整路径
    let destRepoPath = ([$repoPath $repoName] | path join)
    # 仓库存在则更新，不存在则 clone
    if not ($destRepoPath | path exists) {
      cd $repoPath; git clone -b $branch $repo.url
    }
    hr-line
    print $'(char nl)Pull repo (ansi gb)($repoName)(ansi reset): (char nl)'

    cd $destRepoPath;
    if not ((has-ref $branch) or (has-ref origin/($branch))) {
      print $'Dest branch: ($branch) does not exist, bye...(char nl)'
      exit 3
    }
    git checkout $branch; git pull
    # 强制更新远程的Tag到本地
    git fetch origin --tags --force
    print $'(char nl)Last commit of (ansi gb)($repoName)(ansi reset): (char nl)'
    git show --abbrev-commit --no-patch

    # 先从环境变量里面查找待比较的上一个标签的完整名称
    let prevTagName = (get-env REDEV_PREV_TAG '')
    # Check the tag status, if exists just recreate it.
    if (has-ref refs/tags/($prevTagName)) {
      if $show_diff and (git --no-pager diff $prevTagName $branch --name-only | lines | length) > 0 {
        print $'---------> Update since latest tag <---------:(char nl)(ansi y)'
        git --no-pager diff $prevTagName $branch --name-only
      }
    } else {
      if $show_diff {
        # 使用原生 echo 命令
        print $'(char nl) (ansi r)Tag: ($prevTagName) does not exist in repo: ($repoName) (ansi reset)(char nl)'
      }
    }
  }
}
