# Author: hustcer
# Created: 2021/09/11 23:33:03

# 列出远程二开仓库 Tags
def 'git pull-redev' [
  --show-diff(-d): string   # Set to 'true' if you want to see the files changed since prev tag
] {

  let actionConf = (open $'($nu.env.TERMIX_DIR)/actions.toml');
  # 所有二开仓库存放临时路径
  let repoPath = ($actionConf | get redevRepoPath);
  let tagRepository = ($actionConf | get tagRepository);
  echo $'Pull remote redevelop repos in directory (ansi g)($repoPath)(ansi reset):(char newline)';

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
    echo $'(char newline)Pull repo (ansi gb)($repoName)(ansi reset): (char newline)';
    cd $destRepoPath; git co master; git pull;
    # 强制更新远程的Tag到本地
    git fetch origin --tags --force;
    echo $'(char newline)Last commit of (ansi gb)($repoName)(ansi reset): (char newline)';
    git show --abbrev-commit --no-patch;

    let prevTagName = ($actionConf | get redevPrevTag);
    # Check the tag status, if exists just recrete it.
    let parse = (git rev-parse -q --verify $'refs/tags/($prevTagName)');
    if ($parse | empty?) {
      # 使用原生 echo 命令
      ^echo $'(char newline) (ansi r)Tag: ($prevTagName) does not exist in repo: ($repoName) (ansi reset)(char newline)';
    } {
      if $show-diff == 'true' {
        let diff = (git --no-pager diff $prevTagName master --name-only);
        echo $'========Update since latest tag========:(char newline)';
        ^echo $diff;
      } {}
    };
  };
}

git pull-redev --show-diff=$nu.env.SHOW_REDEV_DIFF
