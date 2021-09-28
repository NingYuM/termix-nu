# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t pull-redev
#   t pull-redev develop
#   t pull-redev master true

# 列出远程二开仓库 Tags
def 'git pull-redev' [
  branch: string            # Specify the branch to pull
  --show-diff(-d): string   # Set to 'true' if you want to see the files changed since prev tag
] {

  let actionConf = (open $'($nu.env.TERMIX_DIR)/actions.toml');
  # 所有二开仓库存放临时路径
  let repoPath = ($actionConf | get redevRepoPath);
  let tagRepository = ($actionConf | get tagRepository);
  echo $'Pull remote redevelop repos in directory (ansi g)($repoPath)(ansi reset):(char nl)';

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
    echo '─────────────────────────────────────────────────────────────────────────────────>';
    echo $'(char nl)Pull repo (ansi gb)($repoName)(ansi reset): (char nl)';

    let dest = (git rev-parse -q --verify $branch);
    if ($dest | empty?) { echo $'Dest branch: ($branch) does not exist, bye...(char nl)'; exit --now; } {}
    cd $destRepoPath; git checkout $branch; git pull;
    # 强制更新远程的Tag到本地
    git fetch origin --tags --force;
    echo $'(char nl)Last commit of (ansi gb)($repoName)(ansi reset): (char nl)';
    git show --abbrev-commit --no-patch;

    let prevTagName = ($actionConf | get redevPrevTag);
    # Check the tag status, if exists just recrete it.
    let parse = (git rev-parse -q --verify $'refs/tags/($prevTagName)');
    if ($parse | empty?) {
      # 使用原生 echo 命令
      ^echo $'(char nl) (ansi r)Tag: ($prevTagName) does not exist in repo: ($repoName) (ansi reset)(char nl)';
    } {
      if $show-diff == 'true' {
        echo $'========Update since latest tag========:(char nl)';
        git --no-pager diff $prevTagName $branch --name-only;
      } {}
    };
  };
}

git pull-redev $nu.env.DEST_REDEV_BRANCH --show-diff=$nu.env.SHOW_REDEV_DIFF
