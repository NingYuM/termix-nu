#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/15 11:39:56
# [√] 目录名称支持通配符比如 mall-*
# REF: https://github.com/nushell/nushell/discussions/4477
# Usage:
#   t dir-batch-exec 'pwd && echo "--------> " && ncu'
#   t dir-batch-exec 'pwd; git remote -v; git push origin master; git push origin --tags'

use ../utils/common.nu [hr-line]
use ../utils/compose-cmd.nu [compose-command]

# Run a command in specified directories or in all subdirectories of the current directory
@example '在当前目录的所有子目录中执行命令' {
  t dir-batch-exec 'ls'
} --result '遍历当前目录下的所有子目录，并在每个子目录中执行 `ls`'
@example '在指定的多个目录中批量执行命令' {
  t dir-batch-exec 'git status' 'repo-a,repo-b'
} --result '仅在 `repo-a` 与 `repo-b` 这两个目录中执行 `git status`'
@example '指定父目录后，在其所有子目录中执行命令' {
  t dir-batch-exec 'pnpm test' --parent ~/iWork/refs
} --result '以 `~/iWork/refs` 作为父目录，遍历其下所有子目录执行测试命令'
@example '执行包含 `&` 等 shell 操作符的复合命令' {
  t dir-batch-exec 'ls & git pull'
} --result '将整个复合命令作为一个字符串传入，并在每个目标目录中交给 shell 执行'
export def main [
  cmd: string,           # The command to run in each target directory
  dirs?: string,         # Target directories separated by commas, such as `repo-a,repo-b`
  --parent(-p): string,  # Parent directory whose subdirectories will be used when `dirs` is omitted
] {

  let wrapped = $cmd | parse --regex '^"\\\"(?P<inner>.*)\\\""$'
  let cmd = if ($wrapped | is-not-empty) {
    $wrapped | get 0.inner
  } else { $cmd }
  let cmd = if (($cmd =~ '^".*"$') or ($cmd =~ "^'.*'$")) {
    $cmd | str substring 1..-2
  } else { $cmd }
  let parent = if ($parent | is-empty) { $env.JUST_INVOKE_DIR } else { $parent }
  let dest = $dirs | default '' | str trim | split row ',' | compact | par-each -k { |it| [$parent $it] | path join }
  let children = ls $parent | where type == dir | get name
  let destDirs = if ($dirs | is-empty) { $children } else { $dest }
  let cmdToExec = compose-command $cmd
  for d in ($destDirs | where ($it | path exists)) {
    cd $d
    print $'(char nl)Start to run (ansi r)“($cmdToExec)”(ansi rst) in dir ($d):(char nl)'
    nu --no-std-lib -n -c $cmdToExec
    hr-line
  }
}

# $env | transpose
# dir-batch-exec $env.BATCH_EXEC_CMD $env.BATCH_EXEC_DIRS --parent=$env.JUST_INVOKE_DIR
