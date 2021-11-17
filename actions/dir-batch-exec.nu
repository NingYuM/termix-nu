# Author: hustcer
# Created: 2021/09/15 11:39:56
# [√] 目录名称支持通配符比如 mall-*
# Usage:
#   t dir-batch-exec 'pwd && echo "--------> " && ncu'
#   t dir-batch-exec 'pwd; git remote -v; git push origin master; git push origin --tags'

# 在指定目录或者当前目录的所有子目录里执行指定命令,多个目录用空格分隔
def 'dir-batch-exec' [
  cmd: string           # The command to execute in directories
  dirs: string          # The directoies to execute the command
  --parent(-p): string  # If no dirs specified, run the command in all subdirs of specified parent dir
] {

  let dest = ($dirs | str trim | split row ' '| compact | each { [$parent $it] | path join })
  let children = (ls $parent | where type == Dir | get name)
  let destDirs = (if ($dirs | empty?) { $children } { $dest })
  let cmdToExec = (compose-cmd $cmd)
  $destDirs | where ($it | path exists) | each {
    $'(char nl)Start to run (ansi r)“($cmdToExec)”(ansi reset) in dir ($it): (char nl)'
    cd $it; nu -c $cmdToExec
  }
}

# $nu.env | pivot
# dir-batch-exec $nu.env.BATCH_EXEC_CMD $nu.env.BATCH_EXEC_DIRS --parent=$nu.env.JUST_INVOKE_DIR
