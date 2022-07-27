#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/30 11:20:56
# 在本地或远程比如编译期通过 Erda Actions 生成全量和增量二开工程
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# Usage:
# In local ~/redevelop directory:
# nu redevelop-all.nu -t rn_b2c -c support/release-2.4 -k YOUR_TOKEN
#     --redev-dir=/Users/abc/redevelop/gaia-mobile-b2c-redev
#     --redev-origin-dir=/Users/abc/redevelop/gaia-mobile-b2c-redev-origin
#     --redev-git=https://erda.cloud/terminus/dop/gaia-app-redev/b2c-mobile-redev
#     --redev-origin-git=https://erda.cloud/terminus/dop/gaia-app-redev/b2c-mobile-redev-origin
# TODO:
#   [ ] Check .dice in redevelop repo

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank-line { char nl }
}

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  (which $app | length) > 0
}

# 创建二开仓库并推送到 erda.cloud, 需要用到的环境变量: GIT_TOKEN, COMMIT_MSG, GIT_TOKEN 为流水线编译时环境变量, COMMIT_MSG 为Commit相关信息
def main [
  --template(-t): string      # termix redevelop template value
  --checkout(-c): string      # termix redevelop checkout value
  --redev-dir: string         # 二开全量仓库对应代码目录,比如对于alias为redev-repo的git-checkout Action可以传 ${redev-repo}
  --redev-origin-dir: string  # 二开增量仓库对应代码目录,比如对于alias为redev-origin-repo的git-checkout Action可以传 ${redev-origin-repo}
  --redev-git: string         # 二开全量仓库Git地址
  --redev-origin-git: string  # 二开增量仓库Git地址
  --token(-k): string         # git 账号对应的 Access Token
  --dest-branch(-d): string = 'master'    # 需要推送到的二开仓库目的分支, 默认为 master, 也可以另外指定
] {
  # We don't need herd image, a raw linux distro image with node installed is okay
  # npm config set registry https://registry.npm.terminus.io/
  if not (is-installed 'termix') {
    npm i -g @terminus/termix@latest
  }
  $'(ansi pr) Termix version: (termix --version | str trim) (ansi reset)'; hr-line
  # Disable `initial branch name` hints from git
  git config --global init.defaultBranch master
  if (git config --global --get user.name | empty?) {
    git config --global user.name 'git'
    git config --global user.email 'erda@terminus.io'
  }
  # 通过 Termix 生成标品二开仓库
  let action = (termix redevelop redev-app --template $template --checkout $checkout --user='git' --access-token $token | complete)
  print $action.stdout; print $action.stderr
  if ('redev-app/origin' | path exists) == false || $action.exit_code != 0 {
    $'(ansi r)Redevelop repo generating failed! Bye...(ansi reset)'
    exit 1 --now
  }
  # 清除生成的二开仓库里面的git信息
  rm -rf redev-app/.git
  # 删除二开全量仓库里面除了 .git 以外的内容，用新生成的二开内容替换，防止冲突
  cp -r $'($redev-dir)/.git' $'($redev-dir)/../.git-back'
  rm -rf $redev-dir; mkdir $redev-dir
  mv $'($redev-dir)/../.git-back' $'($redev-dir)/.git'
  $'Empty repo done! Redevelop repo contents:'; ls -a $redev-dir
  cp -r redev-app/* $redev-dir

  # Origin 为可升级部分代码，需要单独另放一个仓库里面
  # 删除二开增量仓库里面除了.git以外的内容，用新生成的二开内容替换，防止冲突
  cp -r $'($redev-origin-dir)/.git' $'($redev-origin-dir)/../.git-back'
  rm -rf $redev-origin-dir; mkdir $redev-origin-dir
  mv $'($redev-origin-dir)/../.git-back' $'($redev-origin-dir)/.git'
  $'Empty repo done! Redevelop origin dir contents:'; ls -a $redev-origin-dir
  cp -r redev-app/origin/* $redev-origin-dir; cd $redev-origin-dir
  git add --ignore-removal .

  let src-msg = if 'COMMIT_MSG' in (env).name { $env.COMMIT_MSG } else { 'Test redevelop locally' }
  let commit-msg = $"($src-msg), Redevelop from checkout:($checkout) by termix@(termix --version)"
  # https://stackoverflow.com/questions/8123674/how-to-git-commit-nothing-without-an-error
  if (git diff-index --quiet HEAD | complete | get exit_code) == 1 {
    git commit -am $commit-msg
  }
  $'(ansi g)Redevelop origin repo git status:(ansi reset)'; git status; hr-line
  # 推送可升级部分增量代码到另外仓库
  git remote add gaia $redev-origin-git; git push gaia $dest-branch --force

  # 推送全量二开仓库
  cd $redev-dir; git remote add gaia $redev-git
  # https://stackoverflow.com/questions/492558/removing-multiple-files-from-a-git-repo-that-have-already-been-deleted-from-disk
  git add --ignore-removal .
  if (git diff-index --quiet HEAD | complete | get exit_code) == 1 {
    git commit -am $commit-msg
  }
  $'(ansi g)Redevelop repo git status:(ansi reset)'; git status; hr-line
  git push gaia $dest-branch --force
}
