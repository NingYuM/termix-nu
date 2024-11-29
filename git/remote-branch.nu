#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-branch
#   t git-remote-branch origin
#   t git-remote-branch origin -t

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref hr-line windows?]

# Creates a table listing the remote branches of
# a git repository and the time of the last commit
export def git-remote-branch [
  remote: string = 'origin',  # The remote name of git repo, default is 'origin'
  --show-tags(-t),             # Show all the tags
] {

  $env.config.table.mode = 'light'
  cd $env.JUST_INVOKE_DIR
  let remoteUrl = (git remote get-url $remote)
  let nameIdx = ($remoteUrl | str index-of -e '/')
  let repoName = ($remoteUrl | str substring ($nameIdx + 1).. | str trim)
  git fetch $remote -p
  print $'(char nl)Branches of (ansi gb)($repoName)(ansi reset) for remote ($remote)(char nl)'

  let basic = (
    git ls-remote --heads --refs $remote
    | lines
    | par-each -k { str substring 52.. }
    | wrap name
    | upsert local { |it|  if (has-ref $it.name) { '   √' }}
    | upsert author { |it| git show $'remotes/($remote)/($it.name)' -s --format='%an' | str trim }
    | upsert SHA {|it| do -i { git rev-parse $'($remote)/($it.name)' | str substring 0..<9 } }
    | upsert last-commit { |it| git show $'remotes/($remote)/($it.name)' --no-patch --format=%ci | into datetime }
  )
  print (append-desc $basic)

  if (not $show_tags) { exit $ECODE.SUCCESS }

  print $'Tags of (ansi gb)($repoName)(ansi reset) for remote ($remote)'; hr-line
  git ls-remote --tags -q --sort="-v:refname"
    | lines
    | where $it !~ '{}'
    | str join "\n"
    | str replace -a 'refs/tags/' ''
    | detect columns -n
    | rename SHA tag
    | move tag --before SHA
    | upsert SHA { |it| str substring 0..<9 }
}

# $env | transpose
# git-remote-branch $env.JUST_INVOKE_DIR $env.REMOTE_ALIAS
