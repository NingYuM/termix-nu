# Author: hustcer
# Created: 2021/09/15 11:39:56

# t dir-batch-exec 'pwd; echo $"(char newline)"; ncu'
# repos $ t dir-batch-exec 'pwd; ^echo ':'; git remote -v; git push o master; git push o --tags'
# 在指定目录下的所有子目录里执行指定命令
def 'dir-batch-exec' [
  cmd: string  # The command to execute in directories
  dirs: string # The directoies to execute the command
  --parent(-p): string # If no dirs specified, run the command in all subdirs of specified parent dir
] {

    let dest = ($dirs | str trim | split row ' '| compact | each { [$parent $it] | path join });
    let children = (ls $parent | where type == Dir | get name);
    let destDirs = (if ($dirs | empty?) { $children } { $dest });
    # echo $dest; exit --now;

    $destDirs | each {
      if ($it | path exists) {
        cd $it; nu -c $cmd;
      } {}
    }
}

# $nu.env | pivot;
dir-batch-exec $nu.env.BATCH_EXEC_CMD $nu.env.BATCH_EXEC_DIRS --parent=$nu.env.JUST_INVOKE_DIR;
