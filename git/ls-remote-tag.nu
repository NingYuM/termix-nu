# Author: hustcer
# Created: 2021/09/11 23:33:05

# 列出远程二开仓库 Tags
def 'git ls-remote-tags' [] {
  let actionConf = (open $'($nu.env.IWORK_DIR)/actions.toml');
  # 所有二开仓库存放临时路径
  let repoPath = ($actionConf | get redevRepoPath);
  let tagRepository = ($actionConf | get tagRepository);
  echo $'List remote tags:(char nl)';

  $tagRepository | each {
    let idx = ($it | str index-of '@');
    # 取得 git 仓库地址
    let url = ($it | str substring $'($idx + 1),');
    let repoNameIdx = (($it | str index-of -e '/') + 1);
    let repoName = ($it | str substring $'($repoNameIdx),');
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
    cd $destRepoPath; git tag --format='%(refname:strip=2)%09%(creatordate:iso)';
  };
  char nl;
}

git ls-remote-tags
