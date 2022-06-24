#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/31 10:50:56
# 在本地或远程，比如编译期通过 Erda Actions 生成全量二开工程
# 需要安装 Nushell， 最低版本 v0.65.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# Usage:
# In local ~/redevelop directory:
# nu redevelop-main.nu -t rn_b2c -c support/release-2.5 -k YOUR_TOKEN
#     --redev-dir=/Users/abc/redevelop/gaia-mobile-b2c-redev
#     --redev-git=https://erda.cloud/terminus/dop/gaia-app-redev/b2c-mobile-redev
#     --test-branch=support/release-2.5
# TODO:
#   [ ] rm .husky/pre-push
#   [ ] Check .dice in redevelop repo

def 'hr-line' [ --blank-line(-b): bool ] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank-line { char nl }
}

# Check if some command available in current shell
def 'is-installed' [ app: string ] {
  ((which $app | length) > 0)
}

def 'has-ref' [
  ref: string   # The git ref to check
] {
  let parse = (git rev-parse --verify -q $ref)
  if ($parse | empty?) { false } else { true }
}

# 创建二开仓库并推送到 erda.cloud, 需要用到的环境变量: GIT_TOKEN, COMMIT_MSG, GIT_TOKEN 为流水线编译时环境变量, COMMIT_MSG 为Commit相关信息
def main [
  --template(-t): string      # termix redevelop template value
  --checkout(-c): string      # termix redevelop checkout value
  --token(-k): string         # git 账号对应的 Access Token
  --redev-dir: string         # 二开全量仓库对应代码目录,比如对于alias为redev-repo的git-checkout Action可以传 ${redev-repo}
  --redev-git: string         # 二开全量仓库Git地址
  --test-branch: string       # 需要映射到测试环境 develop 分支的源码仓库分支名
] {
  # We don't need herd image, a raw linux distro image with node installed is okay
  # npm config set registry https://registry.npm.terminus.io/
  if (is-installed 'termix') == false {
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
  termix redevelop redev-app --template $template --checkout $checkout --user='git' --access-token $token
  if ('redev-app/origin' | path exists) == false {
    '(ansi r)Redevelop repo generating failed! Bye...(ansi reset)'
    exit 1 --now
  }
  # 清除生成的二开仓库里面的git信息
  rm -rf redev-app/.git

  # 从源码仓库特定分支的代码生成的二开仓库应该提交到二开同名仓库分支上
  if ($'($redev-dir)/.git' | path exists) == false { git clone $redev-git $redev-dir }
  cd $redev-dir;
  # 如果二开仓库对应分支不存在则创建，存在则更新二开对应分支的代码
  if has-ref $checkout { git checkout $checkout; git pull; } else { git checkout -b $checkout; }
  cd ..

  # 删除二开全量仓库里面除了 .git 以外的内容，用新生成的二开内容替换，防止冲突
  cp -r $'($redev-dir)/.git' $'($redev-dir)/../.git-back'
  rm -rf $redev-dir; mkdir $redev-dir
  mv $'($redev-dir)/../.git-back' $'($redev-dir)/.git'
  $'Empty repo done! Redevelop repo contents:'; ls -a $redev-dir
  cp -r redev-app/* $redev-dir

  let src-msg = if 'COMMIT_MSG' in (env).name { $env.COMMIT_MSG } else { 'Test redevelop locally' }
  let commit-msg = $"($src-msg), Redevelop from checkout:($checkout) by termix@(termix --version)"

  # 推送全量二开仓库
  cd $redev-dir; git remote add gaia $redev-git
  # https://stackoverflow.com/questions/492558/removing-multiple-files-from-a-git-repo-that-have-already-been-deleted-from-disk
  git add --ignore-removal .
  if (git diff-index --quiet HEAD | complete | get exit_code) == 1 {
    git commit -am $commit-msg
  }
  let current = (git branch --show-current | str trim)
  $'(ansi g)Redevelop repo git status:(ansi reset)'; git status; hr-line
  git push gaia $'($current):($checkout)' --force; hr-line
  # 如果配置了需要映射到测试环境 develop 分支的分支名，并且与当前分支为同一分支
  if $test-branch == $checkout {
    git push gaia $'($current):develop' --force
  }
}
