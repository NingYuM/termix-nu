#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-branch

# Creates a table listing the branches of a git repository and the day of the last commit
export def 'git-branch' [
  repo: path    # The repo path to show git branch info
] {

  print $'(ansi p)(char nl)Last commit info of local branches: (ansi reset)(char nl)'
  cd $repo
  let basic = (
    git branch
      | lines
      | str substring 2..
      | wrap name
      | upsert remote { |it| if (has-ref origin/($it.name)) { '   √' } else { '' } }
      | upsert author { |it| git show $it.name -s --format='%an' | str trim }
      | upsert last-commit {|it| git show $it.name --no-patch --format=%ci | into datetime }
  )
  print (append-desc $basic)
}
