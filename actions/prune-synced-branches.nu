# Author: hustcer
# Created: 2021/12/16 17:15:20
# Usage:
#   Clean possibly unused branches of synced dest repos
#   just prune-synced-branches
#   just prune-synced-branches false

# Clean possibly unused branches of synced dest repos
def 'prune-synced-branches' [
  --dry-run(-d): string   # In dry-run mode no branch will be deleted, just show all deletable branches
] {

  cd $env.JUST_INVOKE_DIR
  let current = (git branch --show-current | str trim)

  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { $current } else { 'i' })

  if (has-ref $'origin/($confBr)') {} else {
    $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit --now
  }
  let pushConf = (git show $'origin/($confBr):.termixrc' | from toml | to json)
  let repos = ($pushConf | query json $'repos')
  # 获取待同步目的仓库及目的分支映射
  let branches = ($pushConf | query json $'branches')
  let repoName = (prepare-repo $repos)
  let syncs = ($branches | transpose branch dests | each {|sync|
    echo $sync.dests
  })

  $'(ansi p)All available syncing configs:(ansi reset)(char nl)(char nl)'
  $syncs | flatten | select repo dest | sort-by repo dest

  $repos | transpose | rename alias | get alias | each { |alias|
    let cleanable = (
      git ls-remote --heads --refs $alias | detect columns -n | rename cid br | each {|branch|
        let brnm = ($branch.br | str find-replace 'refs/heads/' '')
        let noUse = ($syncs | where repo == $alias && dest == $brnm | length) == 0
        if $noUse { $brnm }
      } | str collect $'(char nl)'
    )

    if (($cleanable | str trim) != '') {
      $'Possibly unused branches in (ansi g)($alias):(ansi reset)(char nl)(char nl)'
      $cleanable | lines | wrap branch-name
      let url = ($repos|get $alias).url
      ^echo $'Visit repo url: ($url)'
      ^echo '---------------------------------------------------------------------------->'
    }
  } | str collect
}

# Clone or update repo, setup all dest remote alias
def 'prepare-repo' [
  repos: any
] {
  if ($repos | empty?) {
    $'No dest repos to be cleaned, bye...(char nl)'
    exit --now
  }

  let repoPath = (get-tmp-path)
  let sampleRepo = ($repos | first | transpose k repo | select 0).repo
  let repoName = ($'prune-(pwd | path basename)' | str trim)
  # 待清理仓库完整路径
  let destRepoPath = ([$repoPath $repoName] | path join)
  # 仓库存在则更新，不存在则 clone
  if ($destRepoPath | path exists) {
    cd $destRepoPath;
  } else {
    cd $repoPath; git clone $sampleRepo.git $repoName
    cd $destRepoPath;
  }
  # echo $repos | transpose name repo
  $repos | transpose name repo | each {|dest|
    let aliasExists = (git remote -v | detect columns -n | rename alias git | where alias == $dest.name | length) > 0
    if ($aliasExists) { git remote set-url $dest.name $dest.repo.git } else { git remote add $dest.name $dest.repo.git }
    # 更新远程仓库信息到本地
    git fetch $dest.name -p
  } | str collect ''
  echo $repoName
}
