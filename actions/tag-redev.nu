#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/13 18:39:15
# Usage:
#   t tag-redev v2.2.0.9
#   t tag-redev v2.2.0.9 master true

# 给远程二开仓库批量打 Tag
export def 'git tag-redev' [
  tag: string               # Specify the tag you want to create
  branch: string            # Specify the branch to create a tag from
  group: string             # Specify the groups of repo to create a tag for
  --delete-tag(-d): any     # Set to 'true' if you want to delete the specified tag, defined as `any` acutually `bool`
] {

  # FIXME
  let _DATE_FMT = '%Y.%m.%d'
  # FIXME
  let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)
  let currentBeTag = $tag
  let actionConf = (open $_TERMIX_CONF)

  let TAG_COMMENT = ($actionConf | get redevTagComment)
  # 先从环境变量里面查找待创建的新标签的前缀
  let redevCurrentTag = (get-env REDEV_CURRENT_TAG '')
  # 这个条件赋值表达式真复杂啊: 如果调用命令的时候传参了则覆盖.env文件里面的标签
  let TAG = if ($currentBeTag | is-empty) { $redevCurrentTag } else { $currentBeTag }
  # let tagName = 'v1.0.0-2021.08.09'
  # 如果传入的是完整的带时间戳的 Tag 名就不用再重复加时间戳了
  let tagName = if ($TAG | str contains '-') { $TAG } else { $'($TAG)-(date now | date format $_DATE_FMT)' }

  let repoPath = (get-tmp-path)
  let redevRepos = ($actionConf | get redevRepos)
  let filteredRepos = ($redevRepos | where $',($group),' =~ $it.group | where enable == true)
  if ($filteredRepos | length) > 0 {
    print $'(ansi p)Found the following matched repos:(ansi reset)(char nl)(char nl)'
    print $filteredRepos
  } else {
    print $'(ansi r)Can not find any matched repos, bye...(ansi reset)(char nl)'
    exit --now
  }

  print $'Delete tag ($tagName) ---> (ansi r)($delete_tag)(ansi reset)(char nl)'
  # 不存在则创建临时路径
  if ($repoPath | path exists) == false { mkdir $repoPath }
  # 保存当前路径方便后期跳回
  let currentDir = ($env.PWD | str trim)

  $filteredRepos | each { |repo|

    let repoNameIdx = ($repo.url | str index-of -e '/') + 1
    let repoName = ($repo.url | str substring $repoNameIdx..)
    # 单一二开仓库完整路径
    let destRepoPath = ([$repoPath $repoName] | path join)
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath; git checkout $branch; git pull
    } else {
      cd $repoPath; git clone -b $branch $repo.url
      cd $destRepoPath; git checkout $branch
    }
    # Note: in nu v0.60+ we need this to keep the path be changed
    cd $destRepoPath;
    # Delete tags that not exist in remote repo
    git fetch origin --prune '+refs/tags/*:refs/tags/*'
    # Check the tag status, if exists just recrete it.
    if (has-ref $'refs/tags/($tagName)') {
      git tag -d $tagName; git push origin --delete $tagName
      print $'Tag: (ansi p)($tagName)(ansi reset) delete successfully!(char nl)'
    }

    if (! $delete_tag) {
      # Add a tag and push it to the remote repo
      git checkout $branch; git tag $tagName -am $TAG_COMMENT; git push origin --tags
      print $'Tag: (ansi p)($tagName)(ansi reset) created successfully!'
    }
    hr-line
  }
  cd $repoPath; ls; cd $currentDir
}
