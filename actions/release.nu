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

def 'release' [
  --update-log: string      # Set to `true` do enable updating CHANGELOG.md
  --force-upgrade: string   # Add `$-FORCE-UPGRADE-$` to release tag commit message
] {

  cd $env.TERMIX_DIR
  let releaseVer = (get-conf version)
  let greatestVer = (git tag -l --sort=-v:refname | lines | nth 0)

  if (has-ref $releaseVer) {
  	$'The version ($releaseVer) already exists, Please choose another version.(char nl)'
  	exit --now
  }
  if (is-lower-ver $releaseVer $greatestVer) {
  	$'The release version sould be greater than ($greatestVer), however, current release ver: ($releaseVer)(char nl)'
  	exit --now
  }
  let statusCheck = (git status --porcelain)
  if ($statusCheck | empty?) {} else {
  	$'You have uncommit changes, please commit them and try `release` again!(char nl)'
  	exit --now
  }
  if ($update-log == 'true') {
    git cliff --unreleased --tag ($releaseVer | str find-replace 'v' '') --prepend CHANGELOG.md;
    git commit CHANGELOG.md -m $'update CHANGELOG.md for ($releaseVer)'
  }
  let commitMsg = $'A new release for version: ($releaseVer) created by Release command of termix-nu'
  let tagMsg = (if $force-upgrade == 'true' { $'($commitMsg). ($_UPGRADE_TAG)' } else { $commitMsg })
  git tag $releaseVer -am $tagMsg; git push origin --tags
}
