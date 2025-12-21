#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 22:57:20
# Usage:
#   t git-branch

use ../utils/git.nu [append-desc]
use ../utils/common.nu [has-ref, hr-line, windows?]

# Creates a table listing the branches of a git repository and the day of the last commit
@example '查看本地 Git 仓库分支及最后提交时间' {
  t git-branch
} --result '按最后提交时间升序显示各分支，远程存在的分支 remote 列会被标记为 √'
@example '根据提交信息关键字筛选包含该提交的分支' {
  t git-branch -c "deps-0330: upgrade nusi-slim to v2.2.22"
} --result '仅显示提交信息包含指定关键字的分支列表'
@example '显示当前仓库所有本地 Tags' {
  t git-branch -t
} --result '按创建时间显示本地 Tag 列表'
@example '指定仓库路径查看其分支信息' {
  t git-branch /path/to/repo
} --result '在指定路径下统计并展示分支信息'
export def git-branch [
  ...rest: string,          # Extra arguments (to handle justfile word splitting)
  --show-tags(-t),          # Show all the local tags
  --contains(-c): string,   # Show only branches that contain the specified keyword in their commit messages
] {

  $env.config.table.mode = 'light'
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
  # Handle justfile splitting "-c 'multi word'" into separate args
  # Also restore backticks for args that were parsed as raw strings (contain spaces)
  let parsed = $rest | reduce --fold { path: null, extra: [] } {|arg, acc|
    let is_new_path = ($acc.path == null) and ($arg | path exists) and (($arg | path type) == 'dir')
    match $is_new_path {
      true => { path: $arg, extra: $acc.extra }
      # Wrap in backticks if arg contains space (was likely a raw string `...`)
      _ => {
        let val = if ($arg =~ ' ') { $"`($arg)`" } else { $arg }
        { path: $acc.path, extra: ($acc.extra | append $val) }
      }
    }
  }
  let contains = match [($contains | is-empty), ($parsed.extra | is-empty)] {
    [true, true] => null
    _ => ([$contains, ...$parsed.extra] | compact | str join ' ')
  }
  # Strip wrapping single quotes if present (from `"'...'"` form)
  let contains = if ($contains | is-not-empty) and ($contains =~ "^'") and ($contains =~ "'$") {
    $contains | str substring 1..-2
  } else { $contains }
  let path = $parsed.path | default $env.JUST_INVOKE_DIR
  let title = if ($contains | is-empty) {
      $'(ansi p)(char nl)Last commit info of local branches: (ansi rst)(char nl)'
    } else {
      $'(char nl)Local branches contain (ansi p)($contains)(ansi rst) in commit messages: (char nl)'
    }
  print $title
  cd $path
  let branches = git branch | lines | par-each -k { str substring 2.. }
  let branches = if ($contains | is-empty) { $branches } else {
    $branches | where { |it| not (git log $it $"--grep=($contains)" | is-empty) }
  }
  let basic = ($branches | par-each -k {|name|
      {
        name: $name,
        remote: (if (has-ref $'origin/($name)') { '   √' } else { '' }),
        author: (git show $name -s --format='%an' | str trim),
        SHA: (do -i { git rev-parse $name | str substring 0..<9 }),
        last-commit: (git show $name --no-patch --format=%ci | into datetime)
      }
    }
  )
  print (append-desc $basic)

  if (not $show_tags) { return }

  print $'(char nl)Tags of current repo:'; hr-line
  # Git for Windows does't support sort by `creatordate` field?
  let sort = if (windows?) { '--sort=-v:refname' } else { '--sort=-creatordate' }
  git tag --format='%(align:1,30)%(color:green)%(refname:strip=2)%(end)%09%09%(color:yellow)%(creatordate:iso)' $sort
}
