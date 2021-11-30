# Author: hustcer
# Created: 2021/09/11 23:33:05
# Usage:
#   t ls-redev-refs
#   t ls-redev-refs true

# Show Branches and Tags of redevelop related repos
def 'git ls-redev-refs' [
  --show-branches: string   # Set true to show remote branches last commit info
] {

  let repoPath = (get-tmp-path)
  let redevRepos = (open $TERMIX_CONF | get redevRepos)
  $'(ansi p)---------------> List remote refs <--------------- (char nl)(ansi reset)'

  $redevRepos | each {
    let url = (echo $it | get url)
    let repoNameIdx = (($url | str index-of -e '/') + 1)
    let repoName = ($url | str substring $'($repoNameIdx),')
    # 单一二开仓库完整路径
    let destRepoPath = $'($repoPath)/($repoName)'
    let os = (version | pivot name value | match name build_os | get value)
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
    if ($os =~ 'windows') {
      # Git for Windows does't support sort by `creatordate` field?
      git tag --format='%(refname:strip=2)%09%(creatordate:iso)' --sort=-v:refname   # Reverse
    } {
      git tag --format='%(refname:strip=2)%09%(creatordate:iso)' --sort=-creatordate # Reverse sort
    }
  }
  char nl
}
