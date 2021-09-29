# Author: hustcer
# Created: 2021/09/28 19:50:20
# Usage:
#   This is a git push hook, don't call it manually

# Sync local branches to remote according to .pushrc config file
def 'git sync-branch' [
  localRef: string   # Local git push ref
  localOid: string   # Local git commit object id
  remoteRef: string  # Remote git push ref
] {

  cd $nu.env.JUST_INVOKE_DIR;
  # 一定要 trim 啊，否则后面可能匹配不到，哎呦……
  let zero = (git hash-object --stdin < /dev/null | tr '[0-9a-f]' '0' | str trim);
  let useRef = (if ($localOid == $zero) { $remoteRef } { $localRef });
  let current = ($useRef | str find-replace 'refs/heads/' '');
  let pushConf = (open .pushrc | from toml);
  # The following line not work: ^^^ Expected column path, found string
  # let matchBranch = ($pushConf | get branches | default $current '' | select $current | compact | length);
  # Boolean value can not be reused later
  # let matchBranch = ($pushConf | get branches | pivot | rename branch dest | any? branch == $current);
  let syncDests = ($pushConf | get branches | pivot | rename branch dest | where branch == $current);
  if ($syncDests | empty?) { exit --now; } {
    echo $'(char nl)Found the following matched dests:(char nl)';
  }

  # 获取待同步目的仓库及目的分支映射
  let dests = ($syncDests | pivot | rename c0 c1 | where c0 == 'dest' | get c1);
  echo $dests;
  let repos = ($pushConf | get repos | pivot | rename repo url);

  echo $dests | each {
    # FIXME: match works but where not work?
    let url = ($repos | match repo $'^($it.repo)$' | get url);
    if ($localOid == $zero) {
      ^echo $'Remove remote branch (ansi p)($it.dest) of repo ($it.repo)(ansi reset) -->(char nl)';
      # You MUST use '--no-verify' to prevent infinit loops!!!
      git push --no-verify $url $':($it.dest)';
    } {
      ^echo $'Sync from local (ansi g)($current)(ansi reset) to remote (ansi p)($it.dest) of repo ($it.repo)(ansi reset) -->(char nl)';
      # You MUST use '--no-verify' to prevent infinit loops!!!
      git push --no-verify $url $'($current):($it.dest)';
    }
    ^echo '';
  }
  char nl;
}

# $nu.env | pivot;
git sync-branch $nu.env.PUSH_LOCAL_REF $nu.env.PUSH_LOCAL_OID $nu.env.PUSH_REMOTE_REF;
