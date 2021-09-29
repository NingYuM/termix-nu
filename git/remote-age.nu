# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-age
#   t git-remote-age origin

# Creates a table listing the remote branches of
# a git repository and the time of the last commit
def 'git remote-age' [
  repo: string  # The git repo to display branch ages
  alias: string # The remote url alias for git repo
] {

  cd $repo;
  let remoteUrl = (git remote get-url $alias);
  let nameIdx = (echo $remoteUrl | str index-of -e '/');
  let repoName = (echo $remoteUrl | str substring $'($nameIdx + 1),' | str trim);
  git fetch $alias -p;
  echo $'(char nl)Branches of (ansi gb)($repoName)(ansi reset) for remote ($alias)(char nl)';

  git ls-remote --heads --refs $alias |
    lines |
    str substring 52, |
    wrap name |
    insert author {
      get name | each { git show $"remotes/($alias)/($it)" -s --format='%an'; }
    } |
    insert last_commit {
      get name |
      each {
        git show $"remotes/($alias)/($it)" --no-patch --format=%ai | str to-datetime
      };
    } |
    sort-by last_commit;
}

# $nu.env | pivot;
git remote-age $nu.env.JUST_INVOKE_DIR $nu.env.REMOTE_ALIAS;
