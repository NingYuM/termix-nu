#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-branch

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref, hr-line, windows?]

# Creates a table listing the branches of a git repository and the day of the last commit
@example '查看本地 Git 仓库分支及最后提交时间' {
  t git-branch
} --result '按最后提交时间升序显示各分支，远程存在的分支 remote 列会被标记为 √'
@example '根据提交信息关键字筛选包含该提交的分支' {
  t git-branch -c "'deps-0330: upgrade nusi-slim to v2.2.22'"
} --result '仅显示提交信息包含指定关键字的分支列表, 提交信息中有空格时需要用两重引号包裹'
@example '显示当前仓库所有本地 Tags' {
  t git-branch -t
} --result '按创建时间显示本地 Tag 列表'
@example '指定仓库路径查看其分支信息' {
  t git-branch /path/to/repo
} --result '在指定路径下统计并展示分支信息'
export def git-branch [
  path?: string,            # The path of the git repository, current directory by default
  --show-tags(-t),          # Show all the local tags
  --contains(-c): string,   # Show only branches that contain the specified keyword in their commit messages
] {

  $env.config.table.mode = 'light'
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
  let path = if ($path | is-empty) { $env.JUST_INVOKE_DIR } else { $path }
  let title = if ($contains | is-empty) {
      $'(ansi p)(char nl)Last commit info of local branches: (ansi rst)(char nl)'
    } else {
      $'(char nl)Local branches contain (ansi p)($contains)(ansi rst) in commit messages: (char nl)'
    }
  print $title
  cd $path
  let branches = git branch | lines | par-each -k { str substring 2.. }
  let branches = if ($contains | is-empty) { $branches } else {
    $branches | where { |it| not (git log $it --grep $contains | is-empty) }
  }
  let basic = (
    $branches
      | wrap name
      | upsert remote {|it| if (has-ref origin/($it.name)) { '   √' } else { '' } }
      | upsert author {|it| git show $it.name -s --format='%an' | str trim }
      | upsert SHA {|it| do -i { git rev-parse $it.name | str substring 0..<9 } }
      | upsert last-commit {|it| git show $it.name --no-patch --format=%ci | into datetime }
  )
  print (append-desc $basic)

  if (not $show_tags) { exit $ECODE.SUCCESS }

  print $'(char nl)Tags of current repo:'; hr-line
  # Git for Windows does't support sort by `creatordate` field?
  let sort = if (windows?) { '--sort=-v:refname' } else { '--sort=-creatordate' }
  git tag --format='%(align:1,30)%(color:green)%(refname:strip=2)%(end)%09%09%(color:yellow)%(creatordate:iso)' $sort
}
