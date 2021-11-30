# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-age
#   t git-remote-age origin
#   t git-remote-age origin true

# Creates a table listing the remote branches of
# a git repository and the time of the last commit
def 'git remote-age' [
  repo: string  # The git repo to display branch ages
  alias: string # The remote url alias for git repo
  --show-tag(-t): string  # Set to 'true' if you want to show all the tags
] {

  cd $repo
  let remoteUrl = (git remote get-url $alias)
  let nameIdx = ($remoteUrl | str index-of -e '/')
  let repoName = ($remoteUrl | str substring $'($nameIdx + 1),' | str trim)
  git fetch $alias -p
  $'(char nl)Branches of (ansi gb)($repoName)(ansi reset) for remote ($alias)(char nl)'

  git ls-remote --heads --refs $alias |
    lines |
    str substring 52, |
    wrap name |
    insert author {
      get name | each { git show $"remotes/($alias)/($it)" -s --format='%an' }
    } |
    insert last-commit {
      get name |
      each {
        git show $"remotes/($alias)/($it)" --no-patch --format=%ci | str to-datetime
      }
    } |
    sort-by last-commit

  if $show-tag == 'false' { exit --now } {}
  $'Tags of (ansi gb)($repoName)(ansi reset) for remote ($alias)(char nl)'
  $'(ansi g)───────────────────────────────────────────────────────────────────────>(ansi reset)(char nl)'
  # git ls-remote --tags origin
  let tagFormat = '%(align:1,30)%(color:green)%(refname:strip=2)%(end)%09%09%(color:yellow)%(creatordate:iso)'
  if ($_OS =~ 'windows') {
    # Git for Windows does't support sort by `creatordate` field?
    git tag $'--format=($tagFormat)' --sort=-v:refname   # Reverse
  } {
    git tag $'--format=($tagFormat)' --sort=-creatordate # Reverse sort
  }
}

# $nu.env | pivot
# git remote-age $nu.env.JUST_INVOKE_DIR $nu.env.REMOTE_ALIAS
