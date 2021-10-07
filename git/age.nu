# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-age

# Creates a table listing the branches of a git repository and the day of the last commit
def 'git age' [
  repo: path    # The repo path to show git age
] {

  cd $repo
  git branch |
    lines |
    str substring 2, |
    wrap name |
    insert last_commit {
      get name |
      each {
        git show $it --no-patch --format=%ai | str to-datetime
      }
    } |
    sort-by last_commit
}
