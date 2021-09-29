# Author: hustcer
# Created: 2021/09/28 19:50:20
# Usage:
#   This is a git push hook, don't call it manually

# Sync local branches to remote according to .pushrc config file
def 'git sync-branch' [
  localRef: string   # Local git push ref
  localOid: string   # Local git commit object id
] {

  cd $nu.env.JUST_INVOKE_DIR;
  # 一定要 trim 啊，否则后面可能匹配不到，哎呦……
  let current = ($localRef | str find-replace 'refs/heads/' '');
  let pushConf = (open .pushrc | from toml);
  # The following line not work: ^^^ Expected column path, found string
  # let matchBranch = ($pushConf | get branches | default $current '' | select $current | compact | length);
  # Boolean value can not be reused later
  # let matchBranch = ($pushConf | get branches | pivot | rename branch dest | any? branch == $current);
  let syncDests = ($pushConf | get branches | pivot | rename branch dest | where branch == $current);
  if (($syncDests | length) >= 0) {
    echo $'(char nl)Found the following matched dests:(char nl)';
  } { exit --now; }

  # 获取待同步目的仓库及目的分支映射
  let dests = ($syncDests | pivot | rename c0 c1 | where c0 == 'dest' | get c1);
  echo $dests;
  let repos = ($pushConf | get repos | pivot | rename repo url);

  echo $dests | each {
    # FIXME: match works but where not work?
    let url = ($repos | match repo $'^($it.repo)$' | get url);
    ^echo $'Sync from local (ansi g)($current)(ansi reset) to remote (ansi p)($it.dest) of repo ($it.repo)(ansi reset) -->(char nl)'
    git push $url $'($current):($it.dest)';
    ^echo '';
  }
  char nl;
  exit --now;
}

# $nu.env | pivot;
git sync-branch $nu.env.PUSH_LOCAL_REF $nu.env.PUSH_LOCAL_OID;
