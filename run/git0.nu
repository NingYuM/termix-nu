#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 22:57:23

# 清理不在白名单里面的远程分支
def 'git clean-remote' [] {
  let remoteAlias = [ 'mix', 'bbc', 'sea', 'src' ]
  let whiteList = [
    'develop'
    'master'
    'feature/sea'
    'support/sea'
    'feature/scrm'
    'feature/latest'
    'feature/seldon2'
    'feature/seldon3'
    'support/latest'
    'support/seldon2'
    'support/seldon3'
    'release/latest'
    'release/redevelop'
  ]
  $remoteAlias | each { |remote|
    let branches = (git ls-remote --heads --refs $remote | lines | each { |line| $line | str substring 52.. })
    $'Remote branches of ($remote):(char nl)'
    $branches | each { |branch|
      let keep = ($whiteList | any {|it| $it == $branch })
      if $keep {
        $"($remote) ---> ($branch) keep: ($keep)"
      } else {
        $"(ansi rb)($remote) ---> ($branch) keep: ($keep)(ansi rst)"
      }
    }
  }
}

# git clean-remote
