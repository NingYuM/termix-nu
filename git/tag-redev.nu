# Author: hustcer
# Created: 2021/09/13 18:39:15

# 给远程二开仓库批量打 Tag
def 'git tag-redev' [
  tag: string               # Specify the tag you want to create
  --delete-tag(-d): string  # Set to 'true' if you want to delete the specified tag
] {

  let currentBeTag = $tag;
  let DATE_FMT = '%Y.%m.%d';
  let actionConf = (open $'($nu.env.TERMIX_DIR)/actions.toml');

  let delete = (if $delete-tag == 'true' { $true } { $false });
  let TAG_COMMENT = ($actionConf | get redevTagComment);
  # 这个条件赋值表达式真复杂啊: 如果调用命令的时候传参了则覆盖配置文件里面的标签
  let TAG = (if ($currentBeTag | empty?) { ($actionConf | get redevCurrentTag) } { $currentBeTag });
  # let tagName = 'v1.0.0-2021.08.09';
  let tagName = $'($TAG)-(date now | date format $DATE_FMT)';
  echo $'Delete tag ($tagName) ---> ($delete)(char nl)(char nl)';

  # 所有二开仓库存放临时路径
  let repoPath = ($actionConf | get redevRepoPath);
  let tagRepository = ($actionConf | get tagRepository);
  let exists = ($repoPath | path exists);
  # 不存在则创建临时路径
  if $exists {} { mkdir $repoPath; }
  # 保存当前路径方便后期跳回
  let currentDir = (pwd);

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
    cd $destRepoPath;
    # Delete tags that not exist in remote repo
    git fetch origin --prune '+refs/tags/*:refs/tags/*';
    # Check the tag status, if exists just recrete it.
    let parse = (git rev-parse -q --verify $'refs/tags/($tagName)');
    if ($parse | empty?) {} { git tag -d $tagName; git push origin --delete $tagName; };

    if $delete {} {
      # Add a tag and push it to the remote repo
      git tag $tagName -am $TAG_COMMENT; git push origin --tags;
    }
  };
  cd $currentDir; ls $repoPath;
}

git tag-redev $nu.env.CURRENT_BE_TAG -d $nu.env.TAG_DELETE_MODE;
