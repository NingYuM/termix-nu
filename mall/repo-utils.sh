#!/bin/bash

# 脚本只要发生错误，就终止执行
# 对于管道命令只要一个子命令失败，整个管道命令就失败，脚本终止执行
set -exo pipefail

# 通用 bash 方法

# description: 将git分支从一个仓库同步到另一个仓库
# 需要用到的几个环境变量：GITTAR_AUTHOR, GITTAR_COMMIT_ABBREV, GITTAR_MESSAGE
# $1 源仓库checkout后的路径，比如对于alias为mall-repo的git-checkout Action可以传 ${mall-repo}
# $2 待同步仓库源地址
# $3 仓库待同步到的目的地址
# $4 用于替换默认pipeline的文件，防止同步到目的仓库后继续自动执行, 位于 $1/.dice/pipelines/ 目录下
# $5 需要强制推送到目的仓库 develop 分支的源分支名
# $6 需要强制推送到目的仓库的目的分支名
function sync_repo () {
  cp -ar $1/* ./
  # 保留git仓库信息及其他隐藏文件
  cp -aR $1/.[^.]* ./
  echo "Current git version: `git --version`"
  # https://stackoverflow.com/questions/6842687/the-remote-end-hung-up-unexpectedly-while-git-cloning
  git config --global http.postBuffer 1048576000
  # Fix Remote rejected (shallow update not allowed) after changing Git remote URL
  # Fix Remote rejected by (fetch first)
  git remote set-url origin $2
  git fetch --unshallow origin
  # 切换到当前推送的分支，由于dice更新的原因该信息丢失了
  git checkout $GITTAR_BRANCH
  # 用已有的其他Pipeline替换默认的自动执行 pipeline，防止同步到目的仓库后继续自动执行
  cp $1/.dice/pipelines/$4 ./pipeline.yml
  git config --global user.name 'git'
  git config --global user.email 'erda@terminus.io'
  # 此处的 comment 必须用双引号否则环境变量无法解析
  git add ./pipeline.yml && git commit -m "Previous commit by $GITTAR_AUTHOR at $GITTAR_COMMIT_ABBREV with msg：$GITTAR_MESSAGE"
  # 添加要推送的目的仓库, 标记远程地址为 dest
  git remote add dest $3
  # 将当前变更的分支同步到远程
  git remote -v
  git push dest $GITTAR_BRANCH --force
  PUSH_STATUS=$?
  if [[ $PUSH_STATUS != 0 ]]; then echo 'Sync repo failed! Bye' && exit 1; fi
  # 目的仓库的目的分支默认为 develop，也可以另外指定
  DEST_BRANCH="develop" && [[ $# == 6 ]]  && DEST_BRANCH=$6;
  # 将 $5 分支特殊处理同步到目的仓库 $DEST_BRANCH 分支
  if [[ $# -ge 5 && "$GITTAR_BRANCH" = $5 ]]; then git push dest $GITTAR_BRANCH:$DEST_BRANCH --force; fi
}

# description: 创建二开仓库并推送到 erda.cloud
# 需要用到的环境变量: GIT_TOKEN, COMMIT_MSG
# GIT_TOKEN 为流水线编译时环境变量, COMMIT_MSG 为 git commit 相关信息
# $1 termix redevelop template value
# $2 termix redevelop checkout value
# $3 二开全量仓库对应代码目录,比如对于alias为redev-repo的git-checkout Action可以传 ${redev-repo}
# $4 二开增量仓库对应代码目录,比如对于alias为redev-origin-repo的git-checkout Action可以传 ${redev-origin-repo}
# $5 二开全量仓库Git地址
# $6 二开增量仓库Git地址
# $7 git 账号对应的 Access Token
# $8 需要推送到的二开仓库目的分支
function gen_redevelop_repos () {
  # We don't need this for herd image
  # npm config set registry https://registry.npm.terminus.io/
  npm i -g @terminus/termix@latest
  echo "Termix Version: `termix --version`"
  git config --global user.name 'git'
  git config --global user.email 'erda@terminus.io'
  # 通过 termix 生成标品二开仓库
  termix redevelop redev-app --template=$1 --checkout=$2 --user='git' --access-token=$7
  if [ ! -d redev-app/origin ]; then echo 'Generate repo failed! Bye' && exit 1; fi
  # 清除生成的二开仓库里面的git信息
  rm -rf redev-app/.git
  # 删除二开全量仓库里面除了 .git 以外的内容，用新生成的二开内容替换，防止冲突
  cp -aR $3/.git $3/../.git-back && rm -rf $3 && mkdir -p $3 && mv $3/../.git-back $3/.git
  echo 'Empty repo done! Redevelop repo contents:' && ls -la $3
  cp -aR redev-app/* $3/
  # 隐藏目录拷贝, 如果有的话
  [ -d redev-app/.dice ] && cp -aR redev-app/.dice $3/.dice
  # 隐藏文件拷贝
  find redev-app/ -maxdepth 1 -type f -exec cp {} $3/ \;
  find redev-app/origin/ -maxdepth 1 -type f -exec cp {} $3/origin/ \;
  # Origin 为可升级部分代码，需要单独另放一个仓库里面
  # 删除二开增量仓库里面除了.git以外的内容，用新生成的二开内容替换，防止冲突
  cp -aR $4/.git $4/../.git-back && rm -rf $4 && mkdir -p $4 && mv $4/../.git-back $4/.git
  echo 'Empty repo done! Redevelop origin dir contents:' && ls -la $4
  # 隐藏文件拷贝
  find redev-app/origin/ -maxdepth 1 -type f -exec cp {} $4/ \;
  cp -aR redev-app/origin/* $4/ && cd $4
  git add --ignore-removal .
  # https://stackoverflow.com/questions/8123674/how-to-git-commit-nothing-without-an-error
  git diff-index --quiet HEAD || git commit -am "$COMMIT_MSG, Redevelop from checkout:$2 by termix@`termix --version`"
  echo 'Redevelop origin repo git status:' && git status

  # 二开仓库待推送的目的分支默认为 master, 也可以另外指定
  DEST_BRANCH="master" && [[ $# == 8 ]]  && DEST_BRANCH=$8;
  # 推送可升级部分增量代码到另外仓库
  git remote add gaia $6 && git push gaia $DEST_BRANCH --force
  # 推送全量二开仓库
  cd $3 && git remote add gaia $5
  # https://stackoverflow.com/questions/492558/removing-multiple-files-from-a-git-repo-that-have-already-been-deleted-from-disk
  git add --ignore-removal .
  git diff-index --quiet HEAD || git commit -am "$COMMIT_MSG, Redevelop from checkout:$2 by termix@`termix --version`"
  echo 'Redevelop repo git status:' && git status
  git push gaia $DEST_BRANCH --force
}

# description: 创建二开全量仓库并推送到 erda.cloud，主要服务于直接部署二开项目验证其可用性的场景
# 需要用到的环境变量: GIT_TOKEN, COMMIT_MSG
# GIT_TOKEN 为流水线编译时环境变量, COMMIT_MSG 为 git commit 相关信息
# $1 termix redevelop template value
# $2 termix redevelop checkout value
# $3 二开全量仓库对应代码目录,比如对于alias为redev-repo的git-checkout Action可以传 ${redev-repo}
# $4 二开全量仓库Git地址
# $5 需要映射到测试环境 develop 分支的分支名
# $6 git 账号对应的 Access Token
function gen_redevelop_main () {
  # We don't need this for herd image
  # npm config set registry https://registry.npm.terminus.io/
  npm i -g @terminus/termix@latest
  echo "Termix Version: `termix --version`"
  git config --global user.name 'git'
  git config --global user.email 'erda@terminus.io'
  # 通过 termix 生成标品二开仓库
  termix redevelop redev-app --template=$1 --checkout=$2 --user='git' --access-token=$6
  if [ ! -d redev-app/origin ]; then echo 'Generate repo failed! Bye' && exit 1; fi
  # 清除生成的二开仓库里面的git信息
  rm -rf redev-app/.git
  # 删除二开全量仓库里面除了 .git 以外的内容，用新生成的二开内容替换，防止冲突
  cp -aR $3/.git $3/../.git-back && rm -rf $3 && mkdir -p $3 && mv $3/../.git-back $3/.git
  echo 'Empty repo done! Redevelop repo contents:' && ls -la $3
  cp -aR redev-app/* $3/
  # 隐藏目录拷贝, 如果有的话
  [ -d redev-app/.dice ] && cp -aR redev-app/.dice $3/.dice
  # 隐藏文件拷贝
  find redev-app/ -maxdepth 1 -type f -exec cp {} $3/ \;
  find redev-app/origin/ -maxdepth 1 -type f -exec cp {} $3/origin/ \;
  # 推送全量二开仓库
  cd $3 && git remote add gaia $4
  # https://stackoverflow.com/questions/492558/removing-multiple-files-from-a-git-repo-that-have-already-been-deleted-from-disk
  git add --ignore-removal .
  git diff-index --quiet HEAD || git commit -am "$COMMIT_MSG, Redevelop from checkout:$2 by termix@`termix --version`"
  echo 'Redevelop repo git status:' && git status
  git push gaia $2 --force
  # 如果配置了需要映射到测试环境 develop 分支的分支名，并且与当前分支为同一分支
  if [[ $# == 5 &&  $2 == $5 ]]; then git push gaia $2:develop --force; fi
}
