#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-branch

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref, hr-line, windows?]

# Creates a table listing the branches of a git repository and the day of the last commit
export def git-branch [
  path?: string,        # The path of the git repository, current directory by default
  --show-tags(-t),      # Show all the local tags
] {

  let path = if ($path | is-empty) { $env.JUST_INVOKE_DIR } else { $path }
  print $'(ansi p)(char nl)Last commit info of local branches: (ansi reset)(char nl)'
  cd $path
  let basic = (
    git branch
      | lines
      | par-each -k { str substring 2.. }
      | wrap name
      | upsert remote { |it| if (has-ref origin/($it.name)) { '   √' } else { '' } }
      | upsert author { |it| git show $it.name -s --format='%an' | str trim }
      | upsert last-commit {|it| git show $it.name --no-patch --format=%ci | into datetime }
  )
  print (append-desc $basic)

  if (not $show_tags) { exit $ECODE.SUCCESS }

  print $'Tags of current repo:'; hr-line
  # Git for Windows does't support sort by `creatordate` field?
  let sort = if (windows?) { '--sort=-v:refname' } else { '--sort=-creatordate' }
  git tag --format=%(align:1,30)%(color:green)%(refname:strip=2)%(end)%09%09%(color:yellow)%(creatordate:iso) $sort
}
