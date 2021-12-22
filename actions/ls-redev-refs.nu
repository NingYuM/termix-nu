# Author: hustcer
# Created: 2021/09/11 23:33:05
# Usage:
#   t ls-redev-refs
#   t ls-redev-refs true

# Show Branches and Tags of redevelop related repos
def 'git ls-redev-refs' [
  group: string             # Specify the groups of repo to list their refs
  --show-branches: string   # Set true to show remote branches last commit info
] {

  let repoPath = (get-tmp-path)
  let redevRepos = (open $_TERMIX_CONF | get redevRepos)
  let filteredRepos = ($redevRepos | where $',($group),' =~ $it.group)

  if ($filteredRepos | length) > 0 {
    $'(ansi p)Found the following matched repos:(ansi reset)(char nl)(char nl)'; $filteredRepos
  } { $'(ansi r)Can not find any matched repos, bye...(ansi reset)(char nl)'; exit --now }
  $'(ansi p)---------------> List remote refs <--------------- (char nl)(ansi reset)'

  $filteredRepos | each {
    let url = (echo $it | get url)
    let repoNameIdx = (($url | str index-of -e '/') + 1)
    let repoName = ($url | str substring $'($repoNameIdx),')
    # 单一二开仓库完整路径
    let destRepoPath = ([$repoPath $repoName] | path join)
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath; git pull
    } {
      cd $repoPath; git clone $url
    }

    if ($show-branches == 'true') {
      $'(char nl)Branches of repo (ansi gb)($repoName)(ansi reset): (char nl)(char nl)'
      git age $destRepoPath
    } {}

    $'(char nl)Tags of repo (ansi gb)($repoName)(ansi reset): (char nl)'
    # git ls-remote --tags $url | grep -v '{}'
    cd $destRepoPath
    if ($_OS =~ 'windows') {
      # Git for Windows does't support sort by `creatordate` field?
      git tag --format='%(refname:strip=2)%09%(creatordate:iso)' --sort=-v:refname   # Reverse
    } {
      git tag --format='%(refname:strip=2)%09%(creatordate:iso)' --sort=-creatordate # Reverse sort
    }
  }
  char nl
}
