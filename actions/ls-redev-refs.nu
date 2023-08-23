#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:05
# Usage:
#   t ls-redev-refs
#   t ls-redev-refs true

use ../git/branch.nu [git-branch]
use ../utils/common.nu [get-tmp-path windows?]

# Show Branches and Tags of redevelop related repos
export def 'git ls-redev-refs' [
  group: string             # Specify the groups of repo to list their refs
  --show-branches: any      # Set true to show remote branches last commit info, defined as `any` acutually `bool`
] {

  # FIXME
  let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)
  let repoPath = get-tmp-path
  let redevRepos = (open $_TERMIX_CONF | get redevRepos)
  let filteredRepos = ($redevRepos | where $',($group),' =~ $it.group)

  if ($filteredRepos | length) > 0 {
    print $'(ansi p)Found the following matched repos:(ansi reset)(char nl)(char nl)'; $filteredRepos
  } else {
    print $'(ansi r)Can not find any matched repos, bye...(ansi reset)(char nl)'; exit 3
  }
  print $'(ansi p)---------------> List remote refs <--------------- (char nl)(ansi reset)'

  $filteredRepos | each { |it|
    let url = (echo $it | get url)
    let repoNameIdx = ($url | str index-of -e '/') + 1
    let repoName = ($url | str substring $repoNameIdx..)
    # 单一二开仓库完整路径
    let destRepoPath = ([$repoPath $repoName] | path join)
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath; git pull
    } else {
      cd $repoPath; git clone $url
    }

    if ($show_branches) {
      print $'(char nl)Branches of repo (ansi gb)($repoName)(ansi reset): (char nl)'
      git-branch $destRepoPath
    }

    print $'(char nl)Tags of repo (ansi gb)($repoName)(ansi reset): (char nl)'
    # git ls-remote --tags $url | grep -v '{}'
    cd $destRepoPath
    # Git for Windows does't support sort by `creatordate` field?
    let sort = if (windows?) { '--sort=-v:refname' } else { '--sort=-creatordate' }
    git tag --format='%(refname:strip=2)%09%(creatordate:iso)' $sort
    print ''  # 作为清理空行之用
  }
}
