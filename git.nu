# Author: hustcer
# Created: 2021/09/11 22:57:23

# 清理不在白名单里面的远程分支
def 'git clean-remote' [] {
  let remoteAlias = [ 'mix', 'bbc', 'sea', 'src' ];
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
  ];
  $remoteAlias | each { |remote|
    let branches = (git ls-remote --heads --refs $remote | lines | each { |line| echo $line | str substring 52, });
    echo $'Remote branches of ($remote):(char newline)';
    $branches | each { |branch|
      let keep = (echo $whiteList | any? $it == $branch);
      if $keep {
        echo $"($remote) ---> ($branch) keep: ($keep)";
      } {
        echo $"(ansi rb)($remote) ---> ($branch) keep: ($keep)(ansi reset)";
      }
    };
  }
}

# git clean-remote
