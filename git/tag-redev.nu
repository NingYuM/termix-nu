# Author: hustcer
# Created: 2021/09/13 18:39:15
# Usage:
#   t tag-redev v2.2.0.9
#   t tag-redev v2.2.0.9 master true

# 给远程二开仓库批量打 Tag
def 'git tag-redev' [
  tag: string               # Specify the tag you want to create
  branch: string            # Specify the branch to create a tag from
  --delete-tag(-d): string  # Set to 'true' if you want to delete the specified tag
] {

  let currentBeTag = $tag
  let DATE_FMT = '%Y.%m.%d'
  let envConf = ($nu.env | pivot key value)
  let actionConf = (open $'($nu.env.TERMIX_DIR)/termix.toml')

  let delete = (if $delete-tag == 'true' { $true } { $false })
  let TAG_COMMENT = ($actionConf | get redevTagComment)
  # 先从环境变量里面查找待创建的新标签的前缀
  let redevCurrentTag = ($envConf | match key REDEV_CURRENT_TAG | get value)
  # 这个条件赋值表达式真复杂啊: 如果调用命令的时候传参了则覆盖.env文件里面的标签
  let TAG = (if ($currentBeTag | empty?) { $redevCurrentTag } { $currentBeTag })
  # let tagName = 'v1.0.0-2021.08.09'
  let tagName = $'($TAG)-(date now | date format $DATE_FMT)'
  $'Delete tag ($tagName) ---> ($delete)(char nl)(char nl)'

  # 先从环境变量里面查找所有二开仓库存放临时路径
  let localRepoDir = ($envConf | match key REDEV_REPO_PATH | get value)
  let repoPath = (if ($localRepoDir | empty?) { ($actionConf | get redevRepoPath) } { $localRepoDir })
  let redevRepos = ($actionConf | get redevRepos)
  let exists = ($repoPath | path exists)
  # 不存在则创建临时路径
  if $exists {} { mkdir $repoPath }
  # 保存当前路径方便后期跳回
  let currentDir = (pwd)

  $redevRepos | each { |repo|
    let repoNameIdx = (($repo.url | str index-of -e '/') + 1)
    let repoName = ($repo.url | str substring $'($repoNameIdx),')
    # 单一二开仓库完整路径
    let destRepoPath = $'($repoPath)/($repoName)'
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath; git checkout $branch; git pull
    } {
      cd $repoPath; git clone $repo.url
      cd $destRepoPath; git checkout $branch
    }
    # Delete tags that not exist in remote repo
    git fetch origin --prune '+refs/tags/*:refs/tags/*'
    # Check the tag status, if exists just recrete it.
    let parse = (git rev-parse -q --verify $'refs/tags/($tagName)')
    if ($parse | empty?) {} { git tag -d $tagName; git push origin --delete $tagName }

    if $delete {} {
      # Add a tag and push it to the remote repo
      git checkout $branch; git tag $tagName -am $TAG_COMMENT; git push origin --tags
    }
    ^echo $'(ansi g)──────────────────────────────────────────────────────────────────────>(ansi reset)'
  }
  cd $currentDir; ls $repoPath
}
