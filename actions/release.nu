#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/12 10:06:56
# Description: Script to release termix-nu
# TODO:
# [√] 版本检查确保新版本版本号更大(需要再考虑是否合理？)
# [√] 确保新版本对应 Tag 不存在
# [√] 确保没有未提交的变更
# [√] 自动生成 Tag, 并推送远程
# [√] 更新 Change Log
# Usage:
# 	just release

export def main [
  --update-log: any      # Set to `true` do enable updating CHANGELOG.md, defined as `any` acutually `bool`
  --force-upgrade: any   # Add `$-FORCE-UPGRADE-$` to release tag commit message, defined as `any` acutually `bool`
] {

  # FIXME
  let _UPGRADE_TAG = '$-FORCE-UPGRADE-$'
  cd $env.TERMIX_DIR
  let releaseVer = get-conf version
  let greatestVer = (git tag -l --sort=-v:refname | lines | select 0)

  if (has-ref $releaseVer) {
  	print $'The version ($releaseVer) already exists, Please choose another version.(char nl)'
  	exit --now
  }
  if (is-lower-ver $releaseVer $greatestVer) {
  	print $'The release version should be greater than ($greatestVer), however, current release ver: ($releaseVer)(char nl)'
  	exit --now
  }
  let statusCheck = git status --porcelain
  if ($statusCheck | is-empty) == false {
  	print $'You have uncommit changes, please commit them and try `release` again!(char nl)'
  	exit --now
  }
  if $update_log {
    git cliff --unreleased --tag ($releaseVer | str replace 'v' '') --prepend CHANGELOG.md;
    git commit CHANGELOG.md -m $'update CHANGELOG.md for ($releaseVer)'
  }
  # Delete tags that not exist in remote repo
  git fetch origin --prune '+refs/tags/*:refs/tags/*'
  let commitMsg = $'A new release for version: ($releaseVer) created by Release command of termix-nu'
  let tagMsg = if $force_upgrade { $'($commitMsg). ($_UPGRADE_TAG)' } else { $commitMsg }
  git tag $releaseVer -am $tagMsg; git push origin --tags
}
