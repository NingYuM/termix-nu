#!/usr/bin/env nu

# Author: hustcer
# Created: 2022/03/31 10:50:56
# 在本地或远程，比如编译期通过 Erda Actions 生成全量二开工程, 将其添加到新建的 orphan 分支上并推至源码仓库
# 需要安装 Nushell， 最低版本 v0.66.0; 可以通过 brew 或者 winget 安装, REF: https://www.nushell.sh/book/installation.html;
# Usage:
# In local ~/redevelop directory:
# nu redevelop-main.nu -t rn_b2c -c support/iter3 -k YOUR_TOKEN
#     --src-dir=/Users/abc/redevelop/gaia-mobile
#     --test-branch=support/iter3

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
  --token(-k): string         # git 账号对应的 Access Token
  --deploy-repo: string       # 部署仓库 Git 地址，生成的二开代码将推送到该仓库对应的孤儿分支
  --src-dir: string           # 源码仓库对应代码目录,比如对于 alias 为 git-checkout 的 git-checkout Action 可以传 ${git-checkout}
  --test-branch: string       # 需要映射到测试环境 develop 分支的源码仓库分支名
] {
  cd $src-dir
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
  # 如果部署分支为 develop 需要还原回原来对应的源码分支
  let $checkref = if $checkout == 'develop' { $test-branch } else { $checkout }
  # 通过 Termix 生成标品二开仓库
  let action = (termix redevelop redev-app --template $template --checkout $checkref --user='git' --access-token $token | complete)
  print $action.stdout; print $action.stderr
  if ('redev-app/origin' | path exists) == false || $action.exit_code != 0  {
    $'(ansi r)Redevelop repo generating failed! Bye...(ansi reset)'
    exit 1 --now
  }
  # 切换到一个空的 orphan 分支，用于保存生成的全量二开代码，方便后续排查问题
  git switch --orphan $'redev/($checkout)'
  # 将生成的全量二开文件全部移动到 git 仓库根目录
  mv redev-app/* .
  git add --ignore-removal .

  let src-msg = if 'COMMIT_MSG' in (env).name { $env.COMMIT_MSG } else { 'Test redevelop locally' }
  let commit-msg = $"($src-msg), Redevelop from checkout:($checkout) by termix@(termix --version)"

  git commit -am $commit-msg; hr-line -b
  let repoUrl = if not ($token | empty?) {
    ($deploy-repo | str replace 'https://' $'https://git:($token)@')
  } else { $deploy-repo }
  git remote add deploy $repoUrl
  let current = (git branch --show-current | str trim)
  $'(ansi g)Redevelop repo git status:(ansi reset)'; git status; hr-line
  git remote -v
  $'Current branch: (ansi g)($current)(ansi reset)'
  git push deploy $current -f
}
