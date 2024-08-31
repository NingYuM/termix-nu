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

# 在指定目录或者当前目录的所有子目录里执行指定命令,多个目录用`,`分隔
export def main [
  cmd: string,           # The command to execute in directories
  dirs?: string,         # The directories to execute the command
  --parent(-p): string,  # If no dirs specified, run the command in all subdirs of specified parent dir
] {

  let parent = if ($parent | is-empty) { $env.JUST_INVOKE_DIR } else { $parent }
  let dest = $dirs | str trim | split row ','| compact | par-each -k { |it| [$parent $it] | path join }
  let children = ls $parent | where type == dir | get name
  let destDirs = if ($dirs | is-empty) { $children } else { $dest }
  let cmdToExec = compose-command $cmd
  for d in ($destDirs | where ($it | path exists)) {
    cd $d
    print $'(char nl)Start to run (ansi r)“($cmdToExec)”(ansi reset) in dir ($d):(char nl)'
    nu --no-std-lib -c $cmdToExec
    hr-line
  }
}

# $env | transpose
# dir-batch-exec $env.BATCH_EXEC_CMD $env.BATCH_EXEC_DIRS --parent=$env.JUST_INVOKE_DIR
