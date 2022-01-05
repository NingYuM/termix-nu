# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-age

# Creates a table listing the branches of a git repository and the day of the last commit
def 'git age' [
  repo: path    # The repo path to show git age
] {

  $'(ansi p)(char nl)Last commit info of local branches: (ansi reset)(char nl)(char nl)'
  cd $repo
  git branch |
    lines |
    str substring 2, |
    wrap name |
    insert remote {
      get name | each { if (has-ref $'origin/($it)') { '   √' } {}  }
    } |
    insert author {
      get name | each { git show $it -s --format='%an' }
    } |
    insert last-commit {
      get name |
      each {
        git show $it --no-patch --format=%ci | str to-datetime
      }
    } |
    sort-by last-commit
}
