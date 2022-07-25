#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-branch
#   t git-remote-branch origin
#   t git-remote-branch origin true

# Creates a table listing the remote branches of
# a git repository and the time of the last commit
def 'git-remote-branch' [
  repo: string          # The git repo to display remote branch info
  alias: string         # The remote url alias for git repo
  --show-tag(-t): any   # Set to 'true' if you want to show all the tags, defined as `any` acutually `bool`
] {

  cd $repo
  let remoteUrl = git remote get-url $alias
  let nameIdx = ($remoteUrl | str index-of -e '/')
  let repoName = ($remoteUrl | str substring $'($nameIdx + 1),' | str trim)
  git fetch $alias -p
  $'(char nl)Branches of (ansi gb)($repoName)(ansi reset) for remote ($alias)(char nl)'

  let basic = (
    git ls-remote --heads --refs $alias
    | lines
    | str substring '52,'
    | wrap name
    | upsert local { |it|  if (has-ref $it.name) { '   √' }}
    | upsert author { |it| git show $"remotes/($alias)/($it.name)" -s --format='%an' | str trim }
    | upsert last-commit { |it| git show $"remotes/($alias)/($it.name)" --no-patch --format=%ci | into datetime }
  )
  append-desc $basic

  if (! $show-tag) { exit --now }

  $'Tags of (ansi gb)($repoName)(ansi reset) for remote ($alias)'; hr-line
  # Git for Windows does't support sort by `creatordate` field?
  let sort = if (windows?) { '--sort=-v:refname' } else { '--sort=-creatordate' }
  git tag --format=%(align:1,30)%(color:green)%(refname:strip=2)%(end)%09%09%(color:yellow)%(creatordate:iso) $sort
}

# $env | transpose
# git-remote-branch $env.JUST_INVOKE_DIR $env.REMOTE_ALIAS
