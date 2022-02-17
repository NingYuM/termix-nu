# Author: hustcer
# Created: 2021/11/30 11:06:52
# Usage:
#   t repo-transfer $source-repo $dest-repo

# Transfer repo from source to dest
def 'git repo-transfer' [
  source: string   # The source repo git url
  dest: string     # The dest repo git url
] {
  let tmpPath = (get-tmp-path)
  cd $tmpPath
  $'(char nl)Sync git repo from ($source)(char nl)'
  $'to dest:      (ansi g)---> ($dest)(ansi reset)(char nl)'
  $'(ansi g)─────────────────────────────────────────────────────────────────────(ansi reset)(char nl)'
  let nameIndexStart = ($source | str index-of -e '/')
  let repoName = $'($source | str substring $'($nameIndexStart + 1),')-sync'
  let exists = ([$tmpPath $repoName] | path join | path exists)

  if $exists {
    cd $repoName
    # Trim is required here to make it equal to $source
    let prevFetchUrl = (git remote get-url origin | str trim)
    if ($prevFetchUrl == $source) {
      $'Repo ($repoName) already exists, just sync code from source to dest.(char nl)(char nl)'
      git fetch origin -p
      git remote set-url origin --push $dest
      do-push $dest
    } else {
      $'(ansi r)Path ($tmpPath)/($repoName) already exists(ansi reset), Please remove it and try again...(char nl)'
      exit --now
    }
  } else {
    $'Cloning code to: (ansi g)($tmpPath)/($repoName)(ansi reset)(char nl)'
    git clone --mirror $source $repoName
    cd $repoName; git remote set-url origin --push $dest
    do-push $dest
  }
}

def 'do-push' [
  dest: string      # The dest repo git url
] {
  $'(ansi g)Push code to the remote dest:(ansi reset)(char nl)'
  # FIXME: fatal: repository 'xxx' not found, use ^git instead of bash -c
  let output = ((sh -c 'git push --mirror 2>&1') | compact | str collect)
  echo $output
  if $output =~ 'not found' {
    $'(ansi r)Error: The dest repo does not exist, please create it and try again, bye...(ansi reset)(char nl)'
  } else {
    $'(ansi g)Bravo! Repo transfer successfully!(ansi reset)(char nl)'
  }
}
