# Author: hustcer
# Created: 2021/11/29 13:50:05
# Description: Script to release gaia-mall,gaia-mobile,gaia-picker
# TODO:
# [√] Release的时候允许跳过某些仓库
# [√] 新版本对应 Tag 不存在则创建，存在则删除并重新创建
# [√] 自动生成 Tag, 并推送远程
# Usage:
# 	just gaia-release

def 'gaia-release' [
  version: string   # Gaia FE release version
  repos: string     # The repos to creat a release tag, multi repo could be separated by ','
  --delete-tag(-d): string  # Set to 'true' if you want to delete the specified tag
] {

  let repoPath = (get-tmp-path)
  let gaiaSrcRepos = (open $_TERMIX_CONF | get gaiaSrcRepos)
  $'Using global repo path: (ansi p)($repoPath)(ansi reset)(char nl)'

  $gaiaSrcRepos | find name --regex ($repos | str find-replace -a ',' '|') | each { |repo|
    # 单一仓库完整路径
    let destRepoPath = ([$repoPath $repo.name] | path join)
    let dateSuffix = (date now | date format $_DATE_FMT)
    let releaseTag = (if ($repo.suffix | empty?) { $'($version)-($dateSuffix)' } else { $'($version)-($repo.suffix)-($dateSuffix)' })
    # let tagName = 'v1.0.0-2021.08.09'
    # 如果传入的是完整的带时间戳的 Tag 名就不用再重复加时间戳了
    let tagName = (if ($version | str contains '-') { $version } else { $releaseTag })
    # 仓库存在则更新，不存在则 clone
    if ($destRepoPath | path exists) {
      cd $destRepoPath
      git checkout $repo.branch; git pull
    } else {
      cd $repoPath; print (git clone -b $repo.branch $repo.url)
      cd $destRepoPath; git checkout $repo.branch
    }
    cd $destRepoPath;
    # Delete tags that not exist in remote repo
    print (git fetch origin --prune '+refs/tags/*:refs/tags/*')

    let tagExists = (has-ref $'refs/tags/($tagName)')
    # Check the tag status, if exists just recrete it.
    if ($tagExists) { print (git tag -d $tagName; git push origin --delete $tagName) }

    if ($delete-tag == 'true') {
      print $'(ansi g)Tag delete successfully!(ansi reset)'
    } else {
      let tagComment = $'A new release for version: ($tagName) created by gaia-release command of termix-nu'
      # Add a tag and push it to the remote repo
      print (git checkout $repo.branch; git tag $tagName -am $tagComment; git push origin --tags)
      print $'(ansi g)New tag created successfully!(ansi reset)'
    }
    hr-line
  }
}
