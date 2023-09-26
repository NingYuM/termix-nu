#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/16 17:15:20
# Usage:
#   Clean possibly unused branches of synced dest repos
#   just prune-synced-branches
#   just prune-synced-branches false

use ../utils/common.nu [hr-line has-ref get-tmp-path get-conf]

# Clean possibly unused branches of synced dest repos
export def main [
  --user: string,        # Git repo access user name
  --ak: string,          # Git repo access token
  --dry-run(-d): bool,   # In dry-run mode no branch will be deleted, just show all deletable branches
] {

  cd $env.JUST_INVOKE_DIR
  let current = (git branch --show-current | str trim)

  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = if $useConfBr == '_current_' { $current } else { 'i' }

  if not (has-ref $'origin/($confBr)') {
    print $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit 3
  }
  let pushConf = (git show $'origin/($confBr):.termixrc' | from toml | to json)
  let repos = ($pushConf | query json $'repos')
  # 获取待同步目的仓库及目的分支映射
  let branches = ($pushConf | query json $'branches')
  let repoName = (prepare-repo $repos --user=$user --ak=$ak)
  let syncs = ($branches | transpose branch dests | each { |sync|
    $sync.dests
  })

  print $'(ansi p)All available syncing configs:(ansi reset)(char nl)'
  print ($syncs | flatten | select repo dest | sort-by repo dest)

  # Must change to the scopped directory before doing the following work
  let repoPath = (get-tmp-path)
  cd $repoPath; cd $repoName

  $repos | transpose | rename alias | get alias | each { |alias|
    let remoteBranches = (do -i { git ls-remote --heads --refs $alias } | complete)
    let cleanable = if $remoteBranches.exit_code == 0 { (
      git ls-remote --heads --refs $alias | detect columns -n | rename cid br | each { |branch|
        # Ignore the repos that don't have access permission
        if $branch != null {
          let brnm = ($branch.br | str replace 'refs/heads/' '')
          let noUse = ($syncs | where repo == $alias and dest == $brnm | length) == 0
          if $noUse { $brnm }
        }
      } | str join $'(char nl)'
    ) } else { '' }

    if (($cleanable | str trim) != '') {
      print $'Possibly unused branches in (ansi g)($alias):(ansi reset)(char nl)(char nl)'
      print ($cleanable | lines | wrap branch-name)
      let url = ($repos | get $alias).url
      print $'Visit repo url: ($url)'
      hr-line
    }
  }
}

# Clone or update repo, setup all dest remote alias
def prepare-repo [
  repos: any,
  --user: string,        # Git repo access user name
  --ak: string,          # Git repo access token
] {
  if ($repos | is-empty) {
    print $'No dest repos to be cleaned, bye...(char nl)'
    exit 3
  }

  let repoPath = (get-tmp-path)
  let sampleRepo = ($repos | values | first)
  let repoName = ($'prune-($env.PWD | path basename)' | str trim)
  # 待清理仓库完整路径
  let destRepoPath = ([$repoPath $repoName] | path join)
  # 仓库存在则更新，不存在则 clone
  if ($destRepoPath | path exists) {
    print $'(ansi p)Updating remote repos to local...(ansi reset)'; hr-line
  } else {
    let gitUrl = if ($user != '' and $ak != '-') {
      ($sampleRepo.git | str replace '//' $'//($user):($ak)@' )
    } else { $sampleRepo.git }
    cd $repoPath; git clone $gitUrl $repoName
  }

  cd $destRepoPath;
  $repos | transpose name repo | flatten | each { |dest|
    let aliasExists = (git remote -v | detect columns -n | rename alias git | where alias == $dest.name | length) > 0
    let gitDest = if ($user != '' and $ak != '-') { ($dest.git | str replace '//' $'//($user):($ak)@' ) } else { $dest.git }

    if ($aliasExists) {
      git remote set-url $dest.name $gitDest
    } else {
      git remote add $dest.name $gitDest
    }
    # 更新远程仓库信息到本地
    let output = (do -i { git fetch $dest.name -p } | complete)
    if ($output.exit_code == 0) { print -n ($output.stdout | str trim) }
    if ($output.exit_code == 128) { print $'(ansi y)WARN:(ansi reset) --- No permission for ($dest.name): ($dest.git)' }
  }
  print 'Repo preparing done!'; hr-line
  $repoName
}
