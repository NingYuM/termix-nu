# Author: hustcer
# Created: 2021/09/11 23:33:05
# Usage:
#   t ls-redev-tags

# 列出远程二开仓库 Tags
def 'git ls-redev-tags' [] {
  let actionConf = (open $'($nu.env.TERMIX_DIR)/actions.toml');
  # 所有二开仓库存放临时路径
  let repoPath = ($actionConf | get redevRepoPath);
  let redevRepos = ($actionConf | get redevRepos);
  echo $'List remote tags:(char nl)';

  $redevRepos | each {
    let url = (echo $it | get url);
    let repoNameIdx = (($url | str index-of -e '/') + 1);
    let repoName = ($url | str substring $'($repoNameIdx),');
    # 单一二开仓库完整路径
    let destRepoPath = $'($repoPath)/($repoName)';
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath; git pull;
    } {
      cd $repoPath; git clone $url;
    }
    echo $'(char nl)Tags of repo (ansi gb)($repoName)(ansi reset): (char nl)';
    # git ls-remote --tags $url | grep -v '{}';
    cd $destRepoPath;
    git tag --format='%(refname:strip=2)%09%(creatordate:iso)' --sort='-creatordate';
  };
  char nl;
}

git ls-redev-tags
