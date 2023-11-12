# Termix-Nu 使用说明

## 前言

`termix` ，`termi` 是公司英文简称前缀，也是命令行终端 `terminal` 的前缀，`mix` 可以理解为工具箱，`termix` 就是公司内部使用的命令行工具箱了。`termix-nu` 即 [`Nushell`](https://github.com/nushell/nushell) 版本的`termix`, 与之对应的还有个 JS 版本的 [`termix`](https://fe-docs.app.terminus.io/standard-product/termix), 为了避免重复造轮子两者虽然名字上有关联，但实际上功能是不重叠的。

:::info
既然可以用 JS 写为什么还要采用 `Nushell`？

1. 用 JS 写的脚本在使用前需要安装`node_modules`依赖, 使用上稍有不便，`termix-nu`里面的脚本希望单独把脚本文件发给其他人的时候对方可以直接执行(前提是本机安装过`Nushell`)，另一方面本仓库里面的脚本主要用于日常开发的时候完成一些“微不足道”的小功能: 这些能力看似可有可无，比较杂，且不设限，不适合也没有放到`@terminus/termix`里面的必要，它的定位就是 **"尽可能地通过脚本化的方式消灭日常开发过程中一切低效、重复或者人工操作起来不太方便的工作"**;
2. 没有选择`Bash`脚本是因为`Bash`是一种比较糟糕的脚本语言: 阅读维护都不太方便、而且不适合处理结构化的数据，比如 JSON、TOML、CSV 等等，更重要的是不能跨平台(或者比较有限)；
3. 选用 `Nushell`则是因为其更加现代、强大、语法更优雅，代码可读性和可维护性都有质的提升，天生支持结构化数据、可以跨平台、具有函数式风格和强大的表现力等等，甚至可以用来完成一些数据分析任务，而且最近新增了模块化以及部分场景下的并行执行等能力，至少相比`bash`而言`nushell`是个更好的选择。更多详情可以查看其官网文档: https://www.nushell.sh/ ；

:::

另外，不管是`Nushell`以及后面即将要用到的`just`，还是此脚本工具集都只是标品开发辅助工具，不会侵入业务代码因而不是强依赖，也不会出现在项目二开或者实施过程中，所以不会增加客户或者合作伙伴的学习成本。

## 安装{#install}

本工具集需要你在本机安装 [`Nushell`](https://github.com/nushell/nushell) 和 [`just`](https://github.com/casey/just)

### Install nushell and just on macOS

```bash
# 请始终安装以下应用的最新版
brew update
brew install just
brew install nushell
# 如果你之前已经安装过建议升级到最新版
brew update
brew upgrade nushell just
```

### Install nushell and just on Windows

```bash
# For more detail: https://github.com/lukesampson/scoop
scoop install just
scoop install nu
# Or you can install Nu by winget
winget install Nushell.Nushell
```

### Install latest version of nu

如果`brew`里面的 `Nushell` 版本没有及时更新, 可以自己下载最新版本的 `nightly` 包: https://github.com/nushell/nightly/releases

### `Just` & `nu` 更新提示

本仓库的脚本工具执行的时候会检查本机安装的 `just` & `nu` 的版本, 如果当前安装的版本小于 `termix.toml` 里面的 `minNuVer` 或者 `minJustVer` 指定的最低版本要求，就会在终端提示您升级`just` 或者 `nu` 到最新版本，尤其是当本地 `termix-nu` 版本更新后出于兼容性考虑对`just` & `nu`的最低版本有要求，如果版本过低可能会导致工具脚本无法正常运行。

## 配置{#config}

1. Clone `termix-nu` 源码:

   Erda 地址: https://erda.cloud/terminus/dop/projects/213/apps/8053/repo

   ```bash
   git clone https://erda.cloud/terminus/dop/frontend-product/termix-nu
   ```

2. 配置环境变量:

   ```bash
   cd termix-nu
   cp .env-example .env     # 然后根据自己的情况修改 .env 里面的环境变量
   ```

3. 在`termix-nu` 目录下执行 `just` 即可查看当前提供的所有命令或者工具，如下所示:

   ```bash
   ➜  $ just
   Available recipes:
   ··· brew-speed-up status=('on')   # 开启或者关闭 Brew 国内镜像加速
   ··· check-branch                  # Check whether all remote branches have descriptions or whether synced branches exist in the remote repo
   ··· default                       # List available commands by default
   ··· deploy *OPTIONS               # Run an Erda pipeline, the target can be queried by `dp -l`, default is `dev`, and use `--app` to specify the apps to deploy
   ··· dp *OPTIONS                   # alias for `deploy`
   ··· deploy-query *OPTIONS         # Query the Erda pipeline running status by CICD id or `--app`
   ··· dq *OPTIONS                   # alias for `deploy-query`
   ··· desc branch=(`git branch --show-current`) showNotes=('false') # Show branch description from branch description file `d` of `i` branch
   ··· ding-msg *OPTIONS             # Send a message to DingTalk Group by a custom robot
   ··· dir-batch-exec cmd +DIRS=('') # 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
   ··· emp showAll=('false') showPrev=('false') # 查询电商前端团队本周工时填报情况
   ··· git-batch-exec cmd +branches=('') # 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用空格分隔
   ··· git-branch                    # Listing the branches of a git repo and the time of the last commit
   ··· git-diff-commit *OPTIONS      # Show commit info diff between two commits, e.g. t git-diff-commit 051da464 0ab1df2d
   ··· git-proxy status=('on')       # 开启或者关闭 git 代理, 目前仅支持在阿里郎加速模式下开启 git 代理
   ··· git-remote-branch remote=('origin') showTag=('false') # Listing the remote branches of a git repo with the extra info
   ··· git-stat count=('20') author=('*') # Show insertions/deletions and number of files changed for each commit
   ··· go nav=('list')               # Quickly open the matched nav url in default browser, for mac or windows with powershell
   ··· ls-node minVer=('12') isLts=('false') # 查询已发布Node版本，支持指定最低版本号
   ··· ls-tags by=('time')           # 按时间顺序列出所有的 git tags, 默认按 `time` 排序，可选按 `tag` 排序：ls-tags tag
   ··· pull-all                      # Pull all local branches from remote repo
   ··· release updateLog=('false') forceUpgrade=('false') # Release a new version for termix-nu
   ··· rename-branch from=('') to=('') remote=('origin') # Rename remote branch, and delete old branch after rename
   ··· repo-transfer from=('') to=('') # Transfer a git repo from source to the dest
   ··· show-env                      # 显示本机安装应用版本及环境变量相关信息
   ··· trigger-sync branch=(`git branch --show-current`) # 手工触发批量同步本地分支到远程指定分支
   ··· gsync branch=(`git branch --show-current`) # alias for `trigger-sync`
   ··· upgrade                       # Upgrade termix-nu repo to the latest version
   ··· ver                           # Display termix current version number
   ```

4. 如果你希望在本机任意位置都可以使用`termix-nu`提供的功能，需要建立软连接:

   ```bash
    # Mac or Linux
    ln -s /Users/path/to/termix-nu/Justfile ~/.justfile
    ln -s /Users/path/to/termix-nu/.env ~/.env
    # On Windows, 以下只是示例，请根据情况修改
    # 在 Windows 下创建软连接后可以在对应磁盘(以下为D盘)的任意位置执行
    # Create soft link on Windows by cmd:
    gsudo mklink /d "D:\.env" "D:\Data\iWork\termix-nu\.env"
    gsudo mklink /d "D:\.justfile" "D:\Data\iWork\termix-nu\Justfile"
    # Create soft link on Windows by pwsh:
    gsudo New-Item -ItemType SymbolicLink -Path "D:\.env" -Target "D:\Data\iWork\termix-nu\.env"
    gsudo New-Item -ItemType SymbolicLink -Path "D:\.justfile" -Target "D:\Data\iWork\termix-nu\Justfile"
   ```

5. 简化命令行输入（推荐）

   完成前面四步就可以使用所有命令了，不过为了简化输入可以像下面这样建一个 alias，这样以后就直接输入`t`就可以了(Task)的简称(该操作除了简化输入外还可以跟系统其他 Just 管理的脚本进行区分，如果有的话)：

   ```bash
    # Edit ~/.zshrc or ~/.bashrc and add:
    alias t="just --justfile ~/.justfile --dotenv-path ~/.env --working-directory ."
    # After source the profile you have edit, you can use `t` now
   ```

   这样执行`t`命令的时候当对应的`Justfile`里面设置了`set dotenv-load := true`则会自动从 `~/.env` 加载环境变量。

## 目录结构说明{#structure}

```bash
.
├── Justfile            # `Just` 配置文件
├── README.md           # 本文件
├── actions             # 非 Git 相关脚本，通过 `just` 管理
├── git                 # Git 仓库相关脚本，通过 `just` 管理
├── mall                # 电商标品里面的脚本，目前还在建设中...
├── run                 # 不在 `just` 管理范围内的临时测试脚本
├── termix.toml         # termix-nu 的全局配置文件，toml格式, 参考: https://toml.io/
├── .env                # termix-nu 的全局环境变量，如果一个配置在termix.toml和.env里面都有，通常.env里面的优先级更高
├── .env-example        # .env 配置示例文件，可以由此拷贝到 .env 并根据个人需要进行修改
├── .termixrc-example   # .termixrc 配置示例文件，可以由此拷贝到 .termixrc 并根据个人需要进行修改, 目前包含Erda流水线配置等信息
└── utils               # 通用脚本函数
```

## 辅助支持命令{#helper-cmd}

---

直接在`termix-nu`目录执行`t`(即 `just` 命令，以下均假设大家已经在本地为其创建了 `t` Alias)命令即可列出所有可用命令及其参数。命令支持`tab`键自动补全，所以不用全部输完的哈。
`just`本身也支持定义**alias**, 不过考虑到 alias 记起来比较麻烦，而且由于已经支持自动补全了，对于 alias 的需求就没那么迫切了，所以把 alias 注释掉了，需要的可以在`Justfile`里面自己改下。

### 1. 查询本地 `termix-nu` 的版本号{#ver}

可以通过 `t ver` 命令查看本地 `termix-nu` 的版本号;

---

### 2. 更新 `termix-nu` 到最新版本{#upgrade}

此工具箱里面的脚本每天第一次执行的时候会检查远程是否有新版本，如果有可以通过 `t upgrade` 命令更新 `termix-nu` 到最新版本, 本质上是将本地脚本仓库更新到远程最新的 Release Tag 对应的提交，所以如果命令更新失败你也可以进入到 `termix-nu` 代码仓库所在目录直接更新 `master` 分支代码;

---

### 3. 发布 `termix-nu` 新版本{#release}

可以通过 `t release` 命令发布 `termix-nu` 的最新版本，版本发布前要做的工作：

1. 修改`termix.toml`文件里面的`version`字段到将要发布的版本号(需要确保该版本不存在，且相对于上一个版本号更大);
2. 确保 `termix-nu` 仓库里面没有未提交的变更;

发布新版本的过程主要做了如下操作：

1. 如果 `updateLog=('true')`则会利用 [git-cliff](https://github.com/orhun/git-cliff) 根据 commit 记录更新最新的`CHANGELOG.md`(需要大家在创建 commit 的过程中遵循[Commit 规范](https://fe-docs.app.terminus.io/docs/mall/spec/git))并提交，`updateLog`默认值为`false`;
2. 新建了一个以版本号命名的 Tag 并推送到远程；

**命令格式**: `t release updateLog=('false')`

**参数说明**:

- `updateLog`: 选填，是否需要通过提交记录生成最新的`CHANGELOG.md`并提交，默认`false`(需要自己手工生成并检查、更正)；

**使用举例**:

```bash
# 根据`termix.toml`文件里面的`version`配置生成对应版本的Release Tag并推送至远程，但不自动更新`CHANGELOG.md`
t release
# 自动更新`CHANGELOG.md`，然后根据`termix.toml`文件里面的`version`配置生成对应版本的Release Tag并推送至远程
t release true
```

---

### 4. 显示本机 CLI 应用版本及环境变量信息{#show-env}

**功能描述**: 显示本机安装应用版本及环境变量相关信息, 这个主要为了方便排查问题

**命令格式**: `t show-env`

**参数说明**: N/A

**使用举例**: Run `t show-env`

**输出样例**:
![Show-Env Output](https://img.alicdn.com/imgextra/i4/O1CN01WIxUKw1tHGBAAxVZK_!!6000000005876-2-tps-1223-888.png)

---

## 通用脚本工具{#common-cmd}

---

### 5. 浏览器快捷导航{#go}

**功能描述**: 在命令行通过 `t go xx` 快速在浏览器里面打开 `xx` 对应的链接

**命令格式**: `t go nav=('list')`

**参数说明**:

- `nav`: 必填，需要打开的链接的简称，默认值为 `list`, 不打开任何链接，只列出所有支持快捷导航的链接及相应简称；

**使用说明**:
自从`Erda`发布新版本以后发现要打开对应应用的代码仓库需要的鼠标点击次数增多了，所以才有了这个脚本，可以在`termix.toml`里面按需定义一些链接，比如：

```toml
# 快捷导航
[quickNavs]
base = 'https://erda.cloud/terminus/dop/projects/213/apps/4280/repo'
docs = 'https://erda.cloud/terminus/dop/projects/213/apps/7542/repo'
```

然后通过`t go docs`就可以在默认浏览器里面打开`docs`对应的链接了，而且`docs`不用全部输入，如果`do`只能匹配一个简称用`t go do`也可以达到同样效果, 如果找不到任何匹配项将列出所有可用链接。考虑到不同人的常用链接可能差别很大，所以允许使用者自由定制：脚本会自动将执行`t go`命令时所在目录里面的`.termixrc`文件里面的`quickNavs`配置项与`termix.toml`里面的同名配置进行合并，如果**链接简称**重复则`.termixrc`文件里面的优先级更高。

另：当`termix.toml`里面的`useConfFromBranch`配置项值为`_current_`时`.termixrc`配置会从当前分支对应的远程分支读取，当该配置的值为`i`时会从`origin/i`分支上读取，关于`i`分支的更多说明请看[后文](#desc)。

---

### 6. 指定目录批量执行特定命令{#dir-batch-exec}

**功能描述**: 在指定目录里面执行特定命令，如果没有指定目录则会在当前目录的所有子目录内执行对应命令

**命令格式**: `t dir-batch-exec cmd +DIRS=('')`

**参数说明**:

- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `DIRS`: 可选，需要执行上述命令的目录，目录可以指定一个或者多个，多个目录中间用空格隔开，也可以为空，为空则会在当前目录的所有子目录内执行对应命令;

**使用举例**:

```bash
# 更新gaia-mall gaia-mobile gaia-picker这三个仓库的develop分支到本地
t dir-batch-exec 'git co develop; git pull' gaia-mall gaia-mobile gaia-picker
# 在 mall-base/packages 目录下通过 `npm-check-updates` 检查所有 lerna 管理的包的依赖是否有新版本:
cd ./mall-base/packages;
t dir-batch-exec 'pwd;ncu'
```

---

### 7. 查询已发布 Node 版本{#ls-node}

**功能描述**: 通过[`fnm`](https://github.com/Schniz/fnm)查询已发布 `Node` 版本，支持指定最低版本号, 虽然目前依赖`fnm`, 但是若想去除该依赖是很容易的，以后有需求再说吧。

**命令格式**: `t ls-node minVer=('12') isLts=('false')`

**参数说明**:

- `minVer`: 可选，指定查询`Node.js`的最小起始版本号，可以为空，默认值为 12, 版本号前面可以加`v`也可以不加;
- `isLts`: 可选，是否只查询`LTS`版本，可以为空，默认值为`false`;

**使用举例**:

```bash
# 查询`12`及以后的已经发布的Node版本号
t ls-node
# 查询`16`及以后的已经发布的Node版本号
t ls-node 16
# OR
t ls-node v16
# 查询`12`及以后已经发布的Node LTS 版本号
t ls-node 12 true
```

---

### 8. 查看本地 Git 仓库分支及最后提交时间{#git-branch}

**功能描述**: 查看本地 Git 仓库的分支及其最后提交时间, 按最后提交时间升序排序

**命令格式**: `t git-branch`

**参数说明**: N/A

**使用举例**: Run `t git-branch` in a git repo.

**输出样例**:

![Git-Branch Output](https://img.alicdn.com/imgextra/i4/O1CN01EPuq6a1hwEDWqFiwa_!!6000000004341-2-tps-714-205.png)

注：如果 `remote` 列标记了 `√` 表示该分支在远程存在。

---

### 9. 显示 Git 仓库远程分支及其最后提交信息{#git-remote-branch}

**功能描述**: 显示当前 Git 仓库远程地址所有的分支及其最后提交信息

**命令格式**: `t git-remote-branch remote=('origin') showTag=('false')`

**参数说明**:

- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`;
- `showTag`: 可选，是否需要显示仓库已有标签信息，默认值`false`;

**使用举例**:

```bash
# 执行该命令前先切换到一个Git仓库
t git-remote-branch
# 显示远程分支及分支最后提交时间，同时显示已有Tag及其创建时间
t git-remote-branch origin true
```

**输出样例**:

![Git-Remote-Branch Output](https://img.alicdn.com/imgextra/i2/O1CN01lC4u5Z1uIvESQqbIp_!!6000000006015-2-tps-645-206.png)

注：如果 `local` 列标记了 `√` 表示该分支在本地存在。

---

### 10. 在指定 Git 分支上批量执行特定命令{#git-batch-exec}

**功能描述**: 在指定 Git 分支上执行指定命令

**命令格式**: `t git-batch-exec cmd +branches=('')`

**参数说明**:

- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `branches`: 必填，需要执行上述命令的分支，分支可以指定一个或者多个，多个分支中间用空格隔开；

**使用举例**:

```bash
# 在 develop feature/latest 这两个分支上 cherry-pick 特定的 commit并推送到远程
t git-batch-exec 'git cherry-pick abcxyzuvw; git push' develop feature/latest
```

---

### 11. 统计各 git commit 增删改信息{#git-stat}

**功能描述**: 统计各 git commit 的增加、删除代码行数以及所修改文件数

**命令格式**: `t git-stat count=('20') author=('*')`

**参数说明**:

- `count`: 选填，需要统计的 commit 记录数，默认前 20 条;
- `author`: 选填，需要统计的 commit 提交者 ID，默认所有提交者；

**使用举例**:

```bash
# 统计当前仓库当前分支的 commit 数据
t git-stat
# 统计当前仓库当前分支 git 账号为 hustcer 的用户的 前30条 commit 数据
t git-stat 30 hustcer
```

**输出样例**:

```shell

Modification stat info for each commit:

  #    commit           name         changes   insertions   deletions
───────────────────────────────────────────────────────────────────────
  0   e4601d729         xyz            17        1908         941
  1   675f685a8         abc            1         12657        21886
  2   9c157b1d3         abc            2         11           60
  3   bd2c3c111         abc            1         2            2
  4   ce8a4a121         opq            1         1            1
  5   a9c3f287d         xyz            2         3            9
  6   eb9ee1ea9         opq            7         396          3
  7   562868eb6         rst            1         6            5

```

---

### 12. 将指定 Git 分支硬回滚 N 个 commit{#git-batch-reset}

**功能描述**: 将指定 Git 分支硬回滚 N 个 Commit, 这个命令的使用场景可能不是很多，当时是为了测试后面的 `t pull-all` 用的前置命令

**命令格式**: `t git-batch-reset n +branches=('')`

**参数说明**:

- `n`: 必填，整数，需要回滚的 Commit 数目;
- `branches`: 必填，需要回滚代码的分支，分支可以指定一个或者多个，多个分支中间用空格隔开；

**使用举例**:

```bash
# 将 develop feature/latest 两个分支上的代码硬回滚2个commit
t git-batch-reset 2 develop feature/latest
```

---

### 13. 从远程更新本地所有分支代码到最新{#pull-all}

**功能描述**: 从**远程更新本地所有分支代码**到最新的 Commit, 如果执行命令前本地仓库有变更会自动执行 `stash` 操作;

**命令格式**: `t pull-all`

**参数说明**: N/A

**使用举例**: Just Try `t pull-all` in your git repo to update them all ! 再也不用反复切换到某一个分支去挨个更新代码了。

### 14. Git 远程 & 本地分支重命名{#rename-branch}

**功能描述**: Git 远程分支重命名, 重命名成功之后会删除旧的分支

**命令格式**: `t rename-branch from=('') to=('') remote=('origin')`

**参数说明**:

- `from`: 必填，待重命名的分支名，旧分支名所对应分支应该存在于本地或者远程;
- `to`: 必填，重命名之后新的分支名称, 新分支名所对应分支应该是本地和远程都不存在的;
- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`;

**使用举例**:

```bash
t rename-branch feature/old feature/new
```

---

### 15. Git 仓库迁移{#repo-transfer}

**功能描述**: 将 Git 仓库迁移到新的地址：迁移内容包含代码、提交历史记录、分支、Tag 等

**命令格式**: `t repo-transfer from=('') to=('')`

**参数说明**:

- `from`: 必填，源仓库 Git 地址;
- `to`: 必填，目的仓库 Git 地址;

**使用举例**:

```bash
t repo-transfer https://old.source-repo.url https://new.dest-repo.url
```

---

### 16. Git 请求代理{#git-proxy}

**功能描述**: 开启或者关闭 git 代理, 目前仅支持在阿里郎加速模式下开启 git 代理

**命令格式**: `t git-proxy status=('on')`

**参数说明**:

- `status`: 必填，`on/off`，默认值`on`开启代理，不过需要打开阿里郎加速模式才能启用。`off`关闭代理则无须开启阿里郎加速, git 代理开启成功后可以通过`git config --global --list|grep proxy` 命令查看 git 代理信息；

**补充说明**:

- git 代理开通或者关闭后也会输出相应的开启或者关闭终端代理的命令，可以根据需要手动执行(本脚本之所以没添加对终端代理开启、关闭支持是因为脚本是新开 Nushell Session 执行的，无法直接影响当前终端所在 Session)；
- 通过 `t show-env` 命令也可以看到当前 git 代理状态是开启还是关闭(On/Off)；

**使用举例**:

```bash
# 开启git代理
t git-proxy
# 关闭git代理
t git-proxy off
```

---

### 17. 查看 Git 分支描述信息{#desc}

**功能描述**: 查看 Git 分支描述信息

**使用背景**:
由于标品仓库分支动辄 10~20 个甚至更多，为方便分支管理和识别特拟此规范:

- 新增`i` 分支(information)是唯一可以不用遵循分支命名规范的分支;
- `i` 分支只有一个文件 `d.toml`, d 为 description 简称, 这两个名字起得简单主要为了后续操作方便;
- 初次创建 i 分支: `git checkout --orphan i`, 并在其中添加 `d.toml` 文件用于对其他分支进行描述;
- 每一个生命周期超过**5**天的分支都应在 i 分支的唯一文件 `d.toml` 里面添加该分支的说明，并推送远程;
- 如果分支被删除或者分支用途发生变更也应该同步更新 i 分支里面的 `d.toml` 文件;
- 其他同学可以通过 `git fetch origin i:i` 命令在不改变当前分支的情况下更新 i 分支;
- 更新完毕后可以在该仓库任意分支任意位置通过此命令查看分支说明: `git show i:d.toml`;
- 如果不想把 i 分支拉到本地可以在执行`git fetch origin i`后通过`git show origin/i:d.toml`查看;
- 以上通过`git show`查看分支描述显示的是整个描述文件，找起来还是不方便所以可以通过本工具定向查询

**分支描述配置**

分支描述文件`d.toml`为`toml`格式，大致如下:

```toml
[descriptions]
master = "测试通过的主分支, support/master 可以合并到该分支"
develop = "国内版移动端最新开发分支，support/seldon2可以合并到该分支"
"support/seldon2" = "谢顿二期移动端国内版Bug修复以及测试环境对应部署分支"
"support/sea" = "谢顿二期移动端海外版Bug修复以及测试环境对应部署分支"
"support/release-2.4" = '''Gaia v2.4.2 对应国内版二开发布分支, 将发布到二开仓库 develop分支,
support/master 可以合并到该分支'''
```

**命令格式**: `t desc branch=(`git branch --show-current`) showNotes=('false')`

**参数说明**:

- `branch`: 选填，待查看描述信息的分支名，默认`git branch --show-current`输出的当前分支;
- `showNotes`: 选填，是否显示分支描述说明文档, `true` 则显示, 默认 `false`;

**使用举例**:

```bash
# 查看当前分支描述信息
t desc
# 查看 develop 分支描述信息以及分支描述说明文档
t desc develop true
```

---

### 18. Git 分支检查{#check-branch}

**功能描述**: 基于前面一项所述分支描述规则，检查哪些 Git 分支没有添加对应描述信息, 以及哪些关联了同步配置的分支在远程仓库已经被删除

**命令格式**: `t check-branch`

**使用举例**:

```bash
# 查看当前仓库哪些分支没有对应描述信息, 以及哪些关联了同步配置的分支在远程仓库已经被删除
t check-branch
```

**输出样例**:

![Just Check Branch Output](https://img.alicdn.com/imgextra/i2/O1CN017Irkdq1asNZohq8El_!!6000000003385-2-tps-855-403.png)

---

### 19. Git Push 自动将代码同步到多个仓库{#git-sync-branch}

**功能描述**: 通过 Git Pre Push Hook 在将分支 Push 到远程的时候自动将该分支同步到多个目标仓库，该命令应该通过 Git Hook 自动调用，不建议手工调用；

**命令格式**: `t git-sync-branch localRef localOid remoteRef`

**使用场景**:
由于前端代码目前是基于源码部署的，而且可能需要部署多个环境，比如 PC 端可能需要部署 Mix、BBC、CE 等环境，而且 PC 端的业务包括国内和海外，移动端也类似，在这种情况下如果要求开发在提交代码后手工推到各个环境对应仓库就太麻烦了，而且也很容易遗漏。**之前是通过 Erda 的 Pipeline 进行代码自动同步**的，这种情况下已经不需要手工操作了，但是存在一些问题：如果要同步的目标仓库很多的话一方面耗时比较长、另一方面经常会因为服务器资源紧张等原因导致同步失败，即便可以成功耗时普遍也要 3 分钟以上，所以可以通过**Git Pre Push Hook**当开发将代码推到源码仓库的时候，自动根据配置文件的同步规则把代码推送到其他目的仓库，这样代码同步时间就可以缩短到秒级（第一次推送是全量的耗时稍久，之后都是增量推送耗时很短），而研发人员的代码直接推送仓库仍然只有一个，即 Gaia-App-Source 源码仓库。

**配置步骤**:

1. 如果项目里面没有配置过[Husky](https://typicode.github.io/husky/#/)需要初始化配置：
   ```bash
   # Install husky
   npm install husky --save-dev
   # Enable Git hooks
   npx husky install
   # To automatically have Git hooks enabled after install, edit package.json
   # And add `"prepare": "husky install"` to `scripts`
   # 添加 `pre-push` Hook Demo
   npx husky add .husky/pre-push "echo push"
   ```
2. 如果项目里面之前正确配置过 `Husky` 只需要执行 `npm install` 即可
3. 配置 `pre-push` Hook(只需配置一次，一个人配置完毕后其他成员更新仓库即可), 将 `.husky/pre-push` Demo 脚本改为以下内容:

   ```bash
   #!/bin/sh
   # Git pre push hooks, need just/nu and related nu scripts to run.

   . "$(dirname "$0")/_/husky.sh"

   while read local_ref local_oid remote_ref remote_oid
   do
      # 检查 just 和 nushell 是否安装，for Mac Only
      if ! command -v just &> /dev/null; then
         echo "Command 'just' could not be found, Please install it by 'brew install just', and try again!\n"
         break;
      fi
      if ! command -v nu &> /dev/null; then
         echo "Command 'nu' could not be found, Please install it by 'brew install nushell', and try again!\n"
         break;
      fi

      # 本地分支删除的时候 local_ref="(delete)"，just 解析 `(delete)` 参数的时候有问题
      # 所以需要Hack一下：将其进行转换，反正删除时候的 `local_ref` 值对脚本用处不大
      if [[ $local_ref == '(delete)' ]]; then local_ref='_delete_'; fi
      just --justfile ~/.justfile --dotenv-path ~/.env git-sync-branch $local_ref $local_oid $remote_ref;
      # Break is important here, to stop another loop
      break;
   done

   exit 0
   ```

4. 修改仓库同步配置:
   在仓库根目录里面创建`.termixrc`文件，该文件为 [`toml`](https://toml.io/en/v1.0.0) 格式内容大致如下:

   ```toml
   # 远程仓库地址清单, 列出所有要同步到的目的仓库地址, git 地址为仓库地址，后面的 url 为浏览器访问地址，也会在终端中输出方便点击跳转访问
   [repos]
   mix = { git = "https://erda.cloud/terminus/dop/gaia-app-mix/gaia-mall", url = 'https://erda.cloud/terminus/dop/projects/420/apps/6701/repo' }
   bbc = { git = "https://erda.cloud/terminus/dop/gaia-app-bbc/gaia-mall", url = 'https://erda.cloud/terminus/dop/projects/394/apps/6124/repo' }

   [branches]
   # 本地 develop 分支push操作发生后自动将本地 develop 分支推送到远程对应仓库的对应分支
   "develop" = [
      { repo = "mix", dest = "develop" },
      { repo = "bbc", dest = "develop" },
   ]

   # 本地 feature/hooks 分支 push 操作发生后自动将本地 feature/hooks 分支
   # push 到 mix 的 feature/hooks 分支以及 bbc 仓库的 feature/hooks-sync 分支
   "feature/hooks" = [
      { repo = "mix", dest = "feature/hooks" },
      { repo = "bbc", dest = "feature/hooks-sync" },
      # 同步配置里面可以添加`lock`字段，该字段的值为字符串 `"true"` 或者 某一个 Commit ID
      # 当该字段的值为字符串 `"true"` 时同步的时候会跳过该分支对相应仓库的同步
      # 当该字段的值为某一个 Commit ID 时同步的时候会将指定的 Commit 同步到相应仓库
      { repo = "b2b", dest = "feature/hooks-sync", lock = "719afc0" },
   ]
   ```

   **该配置文件创建后需要提交到线上才能生效, 之所以如此设计是为了排查问题方便同时也让所有人的同步配置都保持一致。**

**其他说明**:

经过上述配置当用户 push develop 或者 feature/hooks 分支的时候会自动触发同步操作，并将代码同步到 mix 和 bbc 环境。

1. 如果想禁用某次 push 同步则 push 的时候加上`--no-verify`参数即可；
2. 如果在同步的时候想采用强制推送策略需要：`FORCE=1 git push --force ...`；
3. 代码能够同步成功的前提是你有对应目标仓库的 push 权限，如果没有可以申请权限或者在本地环境变量里面设置忽略推送，需要修改`.env`环境变量里面的`SYNC_IGNORE_ALIAS`配置项，将需要忽略推送的仓库别名加进去，多个别名之间用`,`隔开即可；
4. `.termixrc`配置文件可以从当前分支对应的远程分支读取也可以从远程`origin/i`分支读取，`termix.toml` 里面有个配置项 `useConfFromBranch` 该配置项可以指定`.termixrc`配置文件从哪个分支读取，当该配置项的值为 `_current_` 的时候表示从当前分支对应的**远程分支**读取，否则从`origin/i`分支读取，默认也是从`origin/i`分支读取（**事实证明该默认行为也是最佳实践，避免了后续配置文件各分支不同步的不便，强烈建议大家采用该方式**）, 此时`origin/i`分支相当于是一个可以存储全局数据的地方，所有开发成员从任何分支都可以读取该分支的数据，也避免了各成员、各分支配置文件不同步的情况，关于`i`分支[前面](#desc)已经有所说明；

:::caution
同步配置变更后下次 push 生效！！！

1. 当 `useConfFromBranch` 配置为 `_current_` 时，如果开发修改了`.termixrc`同步配置并 push 到`origin`对应的 remote 上的时候建议加上`--no-verify`参数，因为此时同步配置还没有更新到线上，故而此时依然用的是老的配置，所以建议跳过同步，而之后的 push 就可以使用刚才提交的同步配置了；
2. 同样道理：如果远程`origin`上对应的分支不存在或者被删除，在该分支存在之前即便 push 的时候没有加`--no-verify`参数也是不会执行同步操作的，因为找不到远程同步配置文件；

:::

相比原来利用 Erda Pipeline 进行代码同步的方式，该同步方式具有以下优点：

1. **同步更迅速**：原来利用流水线同步需要 3~8 分钟不等，而且经常失败，对服务器资源也有一定要求，新的方式可以在秒级完成；
2. **更轻量、灵活**：原来的同步方式每增加一个同步目标，需要在默认 Pipeline 里面增加一个 `custom-script`节点，新的方式只需要改 1~2 行配置就可以了，而且可读性更好；
3. 这次是 **“真”同步**，同步后目的分支和源分支的内容完全一样，提交记录完全一样，原来 Erda 同步时为了避免“**递归同步**”需要对目的仓库的默认 Pipeline 做修改, 以免触发由自动同步导致的自动同步；
4. 不仅支持分支创建、更新同步还**支持分支同步删除**，原来用 Erda 同步的时候源分支删除后目的分支并未被删除；

:::tip
为什么没有采用`git`内置的**多 push 地址**的方式同步？

git 本身也是可以通过简单的配置支持一次推送多个目的仓库的：
`git remote set-url origin --push --add https://git.dest/dest1` & `git remote set-url origin --push --add https://git.dest/dest2`
然后执行`git push origin branch/name` 可以同时将`branch/name`分支推送到以上两个仓库，但是这种方式缺乏灵活性 —— 要求同一源分支在两个目的仓库同步后的分支名始终保持一致，但是我们实际开发过程中因为多业态的原因可能有多个活跃分支，比如：`support/b2c-iter2` & `support/b2b-iter3`，这两个分支最终会分别部署到 `b2c` 和 `b2b` 的测试环境，而测试环境支持的分支只有 `develop`, 这就需要 `support/b2c-iter2 ---> b2c's develop` 且 `support/b2b-iter3 ---> b2b's develop`, 这种情况下采用`git`内置的**多 push 地址**的方式同步就无法满足要求了。

:::

---

### 20. 手工触发分支批量同步{#trigger-sync}

**功能描述**: 前文所说的同步是由本地执行 `git push` 操作自动触发的，但是如果代码是通过线上提 MR 然后合并进 Git 仓库的话是不会触发 Pre Push Hook 的，此时可以通过该命令手工触发。该命令执行前不需要用户手工更新代码，命令执行的时候会自动更新的，而且这个命令可以随时、重复执行，除了将指定分支代码更新到本地以及根据关联配置同步到远程之外没有其他副作用。

**命令格式**: `trigger-sync branch=(`git branch --show-current`)`

**参数说明**:

- `branch`: 选填，待触发同步的分支名，默认`git branch --show-current`输出的当前分支;
- `--list` 或者 `-l` 参数: 列出所有已经配置的分支同步信息
- `--all` 或者 `-a` 参数: 批量同步所有有同步配置的分支
- `--force` 或者 `-f` 参数: 强制同步，效果类似于 `git push -f`(从 v1.50 版本开始加`-f`即可，不需要在命令前加 `FORCE=1`)；
- 对于 v1.50 之前的版本如果在同步的时候想采用强制推送策略需要：`FORCE=1 t trigger-sync ...`；

**使用举例**:

```bash
# 触发当前分支的批量同步
t trigger-sync
# 触发 `feature/sync` 分支所关联的批量同步操作
t trigger-sync feature/sync
```

---

### 21. Git 提交记录比较{#git-diff-commit}

**功能描述**:

在项目上线后的每一次发版都要很谨慎，尤其是对于预发和生产的分支，在某些情况下需要知道当前分支的最近一次发布和最新的 Commit 之间究竟有哪些 Commit, 这些 Commit 是谁在什么时候提交的？提交信息是什么样的？SHA 值是什么？你可能需要这个数据跟每一位研发确认，或者可能需要拉个 hotfix 分支并 cherry-pick 其中的某些 Commit 然后单独发个修复版本。这种情况就比较适合用这个命令：`git-diff-commit`

**命令格式**: `git-diff-commit {flags}`

**参数说明**:

- `-f`, `--from` <String> - 需要比较的起始 Commit SHA
- `-t`, `--to` <String> - 需要比较的终止 Commit SHA 或 ref (默认: 'HEAD')
- `-g`, `--grep` <String> - 在Commit的 Author,SHA,Date 和备注字段搜索指定关键字
- `-C`, `--not-contain` <String> - 筛选提交备注里面不包含特定关键字的 Commit
- `-H`, `--exclude-shas` <String> - 排除特定的 SHA，多个值可以用 `,` 分隔
- `-A`, `--exclude-authors` <String> - 排除特定的 Author，多个值可以用 `,` 分隔
- `-h`, `--help` - 显示本命令的帮助信息

**使用举例**:

```bash
# 基本使用
t git-diff-commit -f d3d9e66e7 -t 1d70d99b
# -t 的默认值是 HEAD，所以这个参数也可以不加
t git-diff-commit -f d3d9e66e7 -t HEAD
t git-diff-commit -f HEAD~9 -t HEAD
# Commit diff 结果里面搜索特定关键字
t git-diff-commit -f develop -t feature/latest -g 'feat:'
# Commit diff 结果里面排除特定提交者
t git-diff-commit -f HEAD~9 -A author1,author2
```

**输出样例**:

![Git Commit Diff Output](https://img.alicdn.com/imgextra/i3/O1CN01vvK30h1jCXwdRze9m_!!6000000004512-2-tps-2848-684.png)

---

### 22. 从命令行执行 Erda 流水线{#run-pipeline}

**功能描述**:

自从 Erda 启用多因子认证后想通过快捷方式部署 Erda 流水线变得很困难，本命令行工具可以通过一条命令执行指定流水线（也支持终止指定流水线的运行）。相比于通过浏览器登录 Erda 找到对应项目里对应应用的对应流水线，然后手工创建并执行来说还是方便许多。而且本工具不仅支持单个应用的部署，还支持多个应用批量部署（不限于前端应用或者后端应用，理论上只要能通过流水线部署的应用都可以支持）。

在执行流水线部署之前默认会做两重检查：

1. 检查当前分支上是否有正在部署的流水线；
2. 如果没有正在执行的流水线继续检查将要部署的分支的最新提交是否已经部署过（在单应用仓库内部署有效，**多应用模式下跳过此检查**）；

如果其中任意一个检查的结果为“是”则停止部署并给予相应提示以避免重复部署，如果都没有则执行部署。也可以通过 `--force` 或者 `-f` 参数跳过检查，强制部署。
可以通过 `t erda-deploy -h` 或者 `t dp -h` 查看更多帮助信息。

**配置步骤**:

1. 配置环境变量

   需要在 `termix-nu` 的 `.env` 文件里面加一个环境变量(使用该功能的每位用户都需要配置):

   ```bash
   # 户级别配置，每个开发者根据自己的情况配置, 请注意保密
   # 该配置用于执行或者查询 Erda Pipeline， 如果不使用该功能可以不配
   ERDA_USERNAME='18000000000'
   ERDA_PASSWORD='passWordXY.'
   ```

2. 配置应用流水线信息(**单应用模式**)

   该步骤只需要团队里面的某一位同学配置下即可，需要修改 `i` 分支(关于 `i` 分支[前面](#desc)已经有所说明)上的 `.termixrc` 配置, 在该 **toml** 文件的**前面**添加类似如下配置：

   ```toml
   # pid 为项目 ID，appid 为应用 ID
   # 如果代码仓库访问链接为: https://erda.cloud/terminus/dop/projects/1124/apps/11147/repo，则从URL里面可以获取这两个值
   # Possible env values: DEV, TEST, STAGING, PROD
   erda.test = { pid = 1124, appid = 11147, appName = 'nusi-slim', env = 'TEST', branch = 'develop', pipeline = '.erda/pipelines/nusi.yml' }
   erda.dev = { pid = 1124, appid = 11147, appName = 'nusi-slim', env = 'DEV', branch = 'feature/nusi', pipeline = '.erda/pipelines/nusi.yml' }
   ```

   **注意：** 该配置文件提交并推送到远程以后其他人需要执行 `git fetch origin i:i` 命令在不改变当前分支的情况下更新 i 分支, 之后才能使配置生效

3. 配置应用流水线信息(**多应用模式**)

   如果你只需要部署一个应用只完成**步骤 2**即可，如果你需要同时部署多个应用可以跳过**步骤 2**，通过该步骤完成多应用的配置。该步骤需要你在执行部署命令的目录里面有一个 `.termixrc` 文件，内容如下（参考 `.termixrc-example` 示例文件）：

   ```toml
   # appName & alias 会作为多应用模式下 `--apps` 参数的检索字段
   erda.test = [
      { pid = 213, appid = 7542, appName = 'fe-docs', alias = 'docs', env = 'TEST', branch = 'develop', pipeline = 'pipeline.yml' },
      { pid = 1124, appid = 11147, appName = 'nusi-slim', alias = 'nusi', env = 'TEST', branch = 'develop', pipeline = '.erda/pipelines/nusi.yml' },
   ]

   erda.dev = [
      { pid = 213, appid = 7542, appName = 'fe-docs', alias = 'docs', env = 'DEV', branch = 'feature/latest', pipeline = 'pipeline.yml' },
      { pid = 1124, appid = 11147, appName = 'nusi-slim', alias = 'nusi', env = 'DEV', branch = 'feature/nusi', pipeline = '.erda/pipelines/nusi.yml' },
   ]

   erda.staging = [
      { pid = 213, appid = 7542, appName = 'fe-docs', alias = 'docs', env = 'STAGING', branch = 'release/latest', pipeline = 'pipeline.yml' }
   ]

   erda.prod = [
      { pid = 213, appid = 7542, appName = 'fe-docs', alias = 'docs', env = 'PROD', branch = 'master', pipeline = 'pipeline.yml' }
   ]
   ```

   在多应用模式下必须通过 `--apps` 或 `-a` 参数指定要部署或查询的应用，多个应用之间用英文逗号分隔，输入的应用名会在上述配置里面的 `appName` 和 `alias` 里面进行精确匹配，只有匹配到的应用才会被部署。可以通过 `t dp -l` 命令查询可部署的目标及应用信息。

**命令格式**:

- 单应用：`deploy dest=('dev')`;
- 多应用：`deploy dest=('dev') --apps nusi,docs`;

**参数说明**:

- `dest`: 选填，待执行的目标流水线，默认值为 `dev`，对于上述**步骤 2**的 **toml** 配置 `erda` 下面有两个 Key：`dev` & `test`, 所以 `dest` 的取值也只能是这两个(可以通过 `t dp -l` 查询所有可能的部署目标);
- `--force` 或者 `-f` 参数跳过检查步骤，强制部署应用
- `--list` 或者 `-l` 列出所有可能的部署目标及应用信息
- `--stop-by-id` 或 `-s` 根据流水线 ID 终止对应的正在运行的流水线
- `--apps` 或者 `-a` 指定需要批量部署的应用，多个应用以","分隔，在多应用模式下必须指定(`-a all`或者`--apps all`代表选择指定目标下的所有应用)，单应用模式忽略
- `--help` 或者 `-h` 查看帮助信息

**使用举例**:

```bash
# 触发默认的 `dev` 配置对应的流水线的创建和执行, 或者 `t dp` (dp 为 deploy 的别名)
t deploy
# 查询所有可能的部署目标
t dp -l
# 触发 `test` 配置对应的流水线的创建和执行
t deploy test
# 通过 dp 别名执行部署，并且强制部署测试环境
t dp test -f
# 部署测试环境所有应用
t dp test -a all
# 查找测试环境里面 appName 或者 alias 为 nusi 的应用并部署
t dp test -a nusi
```

**输出样例**:

CLI 部署示例：

![Run Erda Pipeline from CLI](https://img.alicdn.com/imgextra/i4/O1CN01aVjqNd1MQWsGrQAcR_!!6000000001429-2-tps-1561-190.png)

---

### 23. 从命令行查询 Erda 流水线的执行情况{#query-pipeline}

**功能描述**:

对于通过上述 `deploy` 命令执行的流水线会在输出里面告诉你当前触发执行的流水线的 ID，比如上图中的 **988218150879331**，此时可以通过 `deploy-query` 命令来查询流水线的执行情况。

执行查询命令时如果不指定流水线 ID 则查询指定目标的最近 **10** 条部署记录并以表格形式显示, 在多应用查询模式下必须通过 `--apps` 或 `-a` 参数指定要查询的应用，多个应用之间用英文逗号分隔，输入的应用名会在配置里面的 `appName` 和 `alias` 里面进行精确匹配。

**命令格式**:

- 根据 ID 查询单条部署记录：`deploy-query [id]`;
- 单应用查询最近 10 条部署记录：`deploy-query test`;
- 多应用查询最近 10 条部署记录：`deploy-query test -a all`;

**参数说明**:

- `id`: 选填，待查询的目标流水线对应的 ID，比如上图中的 **988218150879331**; 如果不填则查询默认目标的最近**10**条部署记录
- `--apps` 或者 `-a` 指定需要批量查询的应用，多个应用以","分隔，在多应用模式下必须指定(`-a all`或者`--apps all`代表查询指定目标下的所有应用)，单应用模式忽略
- `--help` 或者 `-h` 查看帮助信息

**使用举例**:

```bash
# 根据流水线 ID 查询其执行情况, 或者 `t dq` (dq 为 deploy-query 的别名)
t deploy-query 988218150879331
# 查询测试环境最近的10条部署记录
t dq test
# 多应用模式下查询开发环境所有应用的最近10条部署记录
t dq dev -a all
```

**输出样例**:

![Query Erda Pipeline Running Status from CLI](https://img.alicdn.com/imgextra/i1/O1CN01415e4m1ir1HspRbuv_!!6000000004465-2-tps-1434-409.png)

---

### 24. 在手机端执行或者查询 Erda 流水线{#erda-pipeline-in-mobile}

本功能并非 `termix-nu` 直接提供的，但使用的基础能力是基于 `termix-nu` 的，所以也放在这里顺便提一下。要想在手机端执行或者查询 Erda 流水线需要在手机上安装 GitHub App，借助其可以在手机端执行 Workflow 的能力达到目的。为了方便大家使用特封装了一个 Github Action: [`hustcer/erda-pipeline`](https://github.com/hustcer/erda-pipeline)，并附有配套的使用文档。大家可以参考文档配置试试，有问题随时反馈。

### 25. 钉钉机器人群发消息{#dingtalk-msg}

**功能描述**:

本命令对钉钉机器人消息发送接口进行了一些简单的封装，使得您通过简单的命令即可通过钉钉群自定义机器人发送消息。目前支持的消息类型有: `text`, `link`, `markdown`, 默认消息类型为 `text`。支持通过环境变量关闭消息发送；支持同时向多个钉钉机器人发送消息。

**命令格式**: `ding-msg *OPTIONS`

**参数说明**:

- `--help` 或者 `-h` 查看本命令的帮助信息
- `--type` 或 `-t` 消息类型，默认为：`text`, 其他可选类型：`link`, `markdown`
- `--title` 消息标题, 对 `link`, `markdown` 类型消息有效
- `--text` 消息内容, 对 `text`, `link`, `markdown` 类型消息有效
- `--msg-url` 消息链接, 对 `link` 类型消息有效
- `--pic-url` 图片链接, 对 `link` 类型消息有效
- `--at-all` 是否@所有人, 若是则不再单独@指定人, 不支持 `link` 类型消息
- `--at-mobiles` 被@人的手机号, 多个手机号用 `,` 分隔, 不支持 `link` 类型消息

**环境变量**:

本命令的执行依赖三个环境变量, 可以在 `termix-nu` 的 `.env` 文件里面进行配置，也可以参考 `.env-example` 里的配置：

- `DINGTALK_NOTIFY`: `on` 表示打开, `off` 关闭, 没有设置也是关闭。
- `DINGTALK_ROBOT_AK`: 钉钉机器人的 Access Token，多个 Token 之间用英文 `,` 分隔；
- `DINGTALK_ROBOT_SECRET`: 钉钉机器人的加签密钥，多个密钥之间用英文 `,` 分隔；
- 如果 **AK** 和 **SECRET** 配置了多个需要确保二者的数目相等，而且顺序一致；

**使用举例**:

```bash
# 发送文本类型消息
t ding-msg --text 你好啊
# 发送文本类型消息，并@所有人
t ding-msg --text 你好啊 --at-all
# 发送文本类型消息，并通过手机号@指定人
t ding-msg --text 你好啊 --at-mobiles 13800138000,13800138001
# 发送链接类型消息
t ding-msg --type link --title 欢迎访问端点科技 --msg-url https://terminus.io/ --text '作为国内领先的新商业软件提供商，致力于用平台化、端到端的软件生态方式，为全球各行各业的客户提供全方位的软件产品、解决方案和技术服务'
# 发送 MarkDown 类型消息, 注意：中英混排的时候为了防止文案被解析为多个参数可以在外面多加一对引号，如下：
t ding-msg --type markdown --title 欢迎访问端点科技 --text "'## 端点科技 <br/> 欢迎访问 <br/> 友情链接 <br/> [端点科技](https://terminus.io/)'"
```

---

### 26. 在 Erda 流水线里通过钉钉机器人群发消息{#dingtalk-msg-in-erda}

本功能并非 `termix-nu` 直接提供的，但使用的基础能力是基于 `termix-nu` 的 `ding-msg` 命令。为了方便大家在 Erda 流水线中使用对配置步骤进行了简化，按照如下操作即可。

:::info

Erda 其实提供了 [`dingtalk-robot-msg`](https://www.erda.cloud/market/action/dingtalk-robot-msg), 但是这个 Action 不太能满足我的需求：

1. 允许同一个流水线配置文件在开发、测试环境不必发送通知，只在预发和生产执行成功后发送通知；
2. 或许可以通过 [`if`](https://docs.erda.cloud/2.2/manual/dop/guides/reference/pipeline.html#if) 让 Action 根据条件来执行，但是如果条件不满足的时候直接标记为执行失败，这个不是我希望的结果，另外“目前 pipeline 执行的时候假如没有加入条件执行，那么当一个任务失败，下面的任务就会自动失败”，这个也不是我希望的；
3. 需要支持同时向多个钉钉机器人发送通知，因为关心这条流水线执行结果的群可能不止一个；

正是因为如上原因才重新实现了这个功能。当然为了方便大家使用，未来不排除会将本功能封装为一个 Erda Action。
:::

步骤一:

在应用目录里面添加一个脚本文件比如 `dingtalk-notify.nu`, 内容如下:

```bash
const DINGTALK_API = 'https://oapi.dingtalk.com/robot/send'
# 链接类型消息的默认图片
const DEFAULT_PIC = 'https://img.alicdn.com/imgextra/i3/O1CN014pnilM25N0WkhbzTq_!!6000000007513-2-tps-1385-1249.png'

# Send a message to DingTalk Group by a custom robot
# 依赖环境变量:
#   - `DINGTALK_NOTIFY`: 'on' 打开, 'off' 关闭, 未设置也是关闭;
#   - `DINGTALK_ROBOT_AK`, `DINGTALK_ROBOT_SECRET`: 钉钉群通知机器人的 `Access Token` 和 `Secret`;
export def 'dingtalk notify' [
  --type(-t): string = 'text',  # 消息类型，默认为：`text`, 其他可选类型：`link`, `markdown`
  --title: string,              # 消息标题, 对 `link`, `markdown` 类型消息有效
  --text: string,               # 消息内容, 对 `text`, `link`, `markdown` 类型消息有效
  --msg-url: string,            # 消息链接, 对 `link` 类型消息有效
  --pic-url: string,            # 图片链接, 对 `link` 类型消息有效
  --at-all,                     # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  --at-mobiles: string = '',    # 被@人的手机号,多个手机号用 `,` 分隔, 不支持 'link' 类型消息
] {
  let enableNotify = (get-env DINGTALK_NOTIFY 'off' | str trim | str downcase) == 'on'
  let notifyTip = $'DingTalk notification is (ansi r)disabled(ansi reset), to enable it (ansi g)set `DINGTALK_NOTIFY` to `on`(ansi reset) in pipeline environment. Bye~'
  if not $enableNotify { echo $notifyTip; exit 0 }
  if $type not-in ['text', 'link', 'markdown'] { echo $'(ansi r)Invalid message type. Bye~(ansi reset)'; exit 7 }

  check-envs
  let tokens = $env.DINGTALK_ROBOT_AK | str trim | split row ','
  let secrets = $env.DINGTALK_ROBOT_SECRET | str trim | split row ','
  if ($tokens | length) != ($secrets | length) {
    echo 'Invalid DINGTALK_ROBOT_AK or DINGTALK_ROBOT_SECRET config, length mismatch!'; exit 7
  }

  for tk in $tokens --numbered {
    let sign = get-sign ($secrets | get $tk.index)
    let query = { access_token: $tk.item, timestamp: $sign.timestamp, sign: $sign.sign }
    let payload = get-msg-payload --type $type --title $title --text $text --msg-url $msg_url --pic-url $pic_url --at-all $at_all --at-mobiles $at_mobiles
    let ding = http post -t application/json $'($DINGTALK_API)?($query | url build-query)' $payload
    if ($ding.errcode != 0) { echo $ding.errmsg; exit 7 }
  }
  echo 'Bravo, DingTalk message sent successfully.'
}

# Get the specified env key's value or ''
def get-env [
  key: string,       # The key to get it's env value
  default?: string,  # The default value for an empty env
] {
  $env | get -i $key | default $default
}

# Check if some command available in current shell
def is-installed [ app: string ] {
  (which $app | length) > 0
}

# Get message payload for DingTalk Robot
def get-msg-payload [
  --type(-t): string = 'text',  # 消息类型，默认为：`text`, 其他可选类型：`link`, `markdown`
  --title: string,              # 消息标题, 对 `link`, `markdown` 类型消息有效
  --text: string,               # 消息内容, 对 `text`, `link`, `markdown` 类型消息有效
  --msg-url: string,            # 消息链接, 对 `link` 类型消息有效
  --pic-url: string,            # 图片链接, 对 `link` 类型消息有效
  --at-all: bool = false,       # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  --at-mobiles: string = '',    # 被@人的手机号,多个手机号用 `,` 分隔, 不支持 'link' 类型消息
] {
  let mention = {
    atMobiles: ($at_mobiles | str replace -a ' ' '' | split row ',')
    isAtAll: $at_all,     # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  }

  let TEXT_MSG = {
    at: $mention, msgtype: 'text', text: { 'content': $text }
  }

  let picUrl = if ($pic_url | str trim | is-empty) { $DEFAULT_PIC } else { $pic_url }
  let LINK_MSG = {
    msgtype: 'link',
    link: { title: $title, text: $text, messageUrl: $msg_url, picUrl: $picUrl }
  }

  let MARKDOWN_MSG = {
    at: $mention, msgtype: 'markdown', markdown: { title: $title, text: $text }
  }

  match $type { 'text' => $TEXT_MSG, 'link' => $LINK_MSG, 'markdown' => $MARKDOWN_MSG, _ => $TEXT_MSG }
}

# Get signature and timestamp for DingTalk query params by secret
def get-sign [secret: string] {
  if not (is-installed openssl) { echo 'Please install `openssl` first.'; exit 2 }
  let timestamp = date now | format date '%s000'
  let sign = $'($timestamp)(char nl)($secret)' | openssl dgst -sha256 -hmac $secret -binary | encode base64
  { timestamp: $timestamp, sign: $sign }
}

# Check if the required environment variable was set, quit if not
def check-envs [] {
  let envs = ['DINGTALK_ROBOT_AK' 'DINGTALK_ROBOT_SECRET']
  let empties = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in your environment first...'
    exit 5
  }
}

alias main = dingtalk notify
```

步骤二：

在流水线里添加如下节点，可根据情况作调整:

```yml
- stage:
    - custom-script:
        alias: dingtalk-notify
        version: '2.0'
        image: registry.erda.cloud/erda-actions/terminus-debian-node:18.17-lts
        commands: |-
          pnpm i nushell@0.86 -g
          nu -c "version"
          cd ${{ dirs.git-checkout }}
          COMMIT_SHA=$(git rev-parse HEAD | cut -c 1-8)
          OPERATOR_NAME=$([ "((pipeline.trigger.mode))" == "cron" ]  && echo "定时任务" || echo "((dice.operator.name))")
          nu dingtalk-notify.nu --type link \
             --title "🎉 Terp-UI ($GITTAR_BRANCH 分支) 移动端部署完成 🎉" \
             --text "$OPERATOR_NAME 部署了 Terp-UI $DICE_WORKSPACE 环境，SHA: $COMMIT_SHA，点击查看详情！" \
             --msg-url "https://erda.cloud/terminus/dop/projects/190/apps/11969/pipeline/obsoleted?pipelineID=$PIPELINE_ID"
```

步骤三：

配置以下流水线环境变量：

- `DINGTALK_NOTIFY`: `on` 表示打开, `off` 关闭, 没有设置也是关闭，关闭钉钉通知不影响流水线的其他节点继续执行，本通知节点也不会被标记为失败。
- `DINGTALK_ROBOT_AK`: 钉钉机器人的 Access Token，多个 Token 之间用英文 `,` 分隔；
- `DINGTALK_ROBOT_SECRET`: 钉钉机器人的加签密钥，多个密钥之间用英文 `,` 分隔；
- 如果 **AK** 和 **SECRET** 配置了多个需要确保二者的数目相等，而且顺序一致；

完成以上三步应该就可以发送钉钉群机器人通知了，赶紧试试吧。

---

### 27. Homebrew 镜像加速{#brew-speed-up}

**功能描述**: 由于众所周知的原因 `brew` 更新或者安装应用的时候会比较慢，本工具可以通过给 `brew` 设置国内镜像的方式来提速，同时允许用户恢复到初始设置。

**命令格式**: `brew-speed-up status=('on')`

**参数说明**:

- `status`: 选填，默认值为 `on`, 表示启用 brew 国内镜像加速，如需关闭国内镜像可以执行 `brew-speed-up off`;

**补充说明**:

- 执行完以上命令后还需要根据提示对当前 **Shell** 的配置文件进行相应修改，如果你使用的是`bash`需要修改的配置文件为 `~/.bashrc`, 如果你使用的是`zsh`需要修改的配置文件为 `~/.zshrc`，修改完配置文件需要使用 `source <配置文件名>` 使当前配置生效；

**使用举例**:

```bash
# 启用 brew 国内镜像加速
t brew-speed-up
# 关闭国内镜像加速恢复初始设置
t brew-speed-up off
```

---

### 28. 查看团队成员当前 EMP 工时填报情况{#emp}

**功能描述**: 查看团队成员当前 EMP 工时填报情况

**命令格式**: `t emp showAll=('false') showPrev=('false')`

**配置说明**:

- `showAll`: 可选参数，是否显示所有成员的填报情况，默认值为`false`，表示只显示当前未填满的成员；
- `showPrev`: 可选参数，是否显示前一周的工时填报情况，默认值为`false`，表示显示本周工时填报明细；
- `EMP_UC_COOKIE`: 必填, `.env`里面环境变量配置项, EMP `emp_stage_u_c_local` 对应的 Cookie Value, 貌似每周需要更新一次，否则会超时失效；
- `EMP_PROJECT_CODE`: 必填, `.env`里面环境变量配置项, 可以在 EMP 查看部门工时页面的 `/api/trantor/func/worktime_GetStaffByBaseProjectFunc` 请求的 Request Payload 里面找到；
- `EMP_WORKING_HOUR_TITLE`: 必填, `.env`里面环境变量配置项，控制台输出内容的标题，默认值为"本周工时填报"可以自己按需修改；

**使用举例**:

```bash
# 查看本周团队成员当前工时填报情况，只显示截止到当前未全部填报的成员
t emp
# 查看当前所有团队成员的工时填报情况，无论是否填满都显示
t emp true
# 查看所有团队成员的前一周工时填报情况，无论是否填满都显示
t emp true true
```

---

## 业务脚本工具{#biz-cmd}

---

### 29. 给标品源码仓库批量打 Tag{#gaia-release}

**功能描述**: 在标品前端需要发布新版本的时候将标品 `gaia-mall,gaia-mobile,gaia-picker` 等源码仓库指定分支批量打 Release Tag, 也可以用于删除指定 Tag

**命令格式**: `gaia-release version=('') repos=('mall,mobile,picker') delete=('false')`

**参数说明**:

- `version`: 必填，需要新增的 Tag 前缀，创建 Tag 的时候默认会加上日期信息，比如当指定 Tag 为`v2.2.0`的时候实际生成的可能为`v2.2.0-2021.10.27`, 也可以自己指定时间戳，如果指定了时间戳则以指定时间戳为准，不再添加默认时间戳；
- `repos`: 可选，需要打 Tag 的源码仓库简称：`mall/mobile/picker`，多个简称之间用 `,` 分隔 ，默认值 `mall,mobile,picker`；
- `delete`: 可选，`true`表示删除指定 Tag 且不重新添加对应 Tag，默认值 `false` 表示 Tag 不存在则创建 Tag，存在则先删除再创建;
- 其他说明: 创建 Tag 的时候可以指定分支及其 Tag 后缀，具体可以在`termix.toml`里面的`gaiaSrcRepos`配置项里根据需要作调整;

**使用举例**:

```bash
# 给`mall/mobile/picker`三个源码仓库创建新的Tag，比如 `v2.2.0-2021.10.27`
t gaia-release v2.2.0
# 删除mall,mobile,picker三个仓库`v2.2.0`对应的当天的Tag
t gaia-release v2.2.0 mall,mobile,picker true
# 在`mall,mobile`仓库创建Tag时以给定完整的包含时间戳的Tag名称为准，取代默认添加的时间戳
t gaia-release v2.2.0.21-2021.11.09 mall,mobile
```

---

### 30. 给远程二开仓库批量打 Tag{#tag-redev}

**功能描述**: 给远程二开仓库指定分支批量打 Release Tag, 目前前端二开仓库含增量、全量及所有业态有 13 个，人工挨个仓库打 Tag 是不现实的，也很容易出错。另外，该命令也可以用于删除指定 Tag。

**命令格式**: `t tag-redev tag=('') branch=('master') group=('b2c,b2b,mbr,pik') delete=('false')`

**参数说明**:

- `tag`: 必填，需要新增的 Tag 前缀，创建 Tag 的时候默认会加上日期信息，比如当指定 Tag 为`v2.2.0`的时候实际生成的可能为`v2.2.0-2021.10.27`, 也可以自己指定时间戳，如果指定了时间戳则以指定时间戳为准，不再添加默认时间戳；
- `branch`: 可选，需要打 Tag 的二开分支，默认值 `master`；
- `group`: 可选，需要创建 Tag 的二开仓库分组，多个分组之间用`,`分隔, 默认值 `b2c,b2b,mbr,pik`，具体分组配置可以查看`termix.toml`里面的`redevRepos`配置项；
- `delete`: 可选，`true`表示删除指定 Tag 且不重新添加对应 Tag，默认值 `false` 表示 Tag 不存在则新增 Tag，存在则先删除再新增;

**使用举例**:

```bash
# 从二开仓库master分支创建新的Tag，比如 `v2.2.0-2021.10.27`
t tag-redev v2.2.0
# 删除`v2.2.0`对应的当天的Tag
t tag-redev v2.2.0 master b2c,b2b,mbr,pik true
# 从二开仓库develop分支创建新的Tag `v2.5.0`
t tag-redev v2.5.0 develop
# 创建Tag时以给定完整的包含时间戳的Tag名称为准，取代默认添加的时间戳
t tag-redev v2.2.0.21-2021.11.09 master
```

---

### 31. 查询二开仓库的远程分支及 Tag 信息{#ls-redev-refs}

**功能描述**:

显示标品二开仓库的所有 Tag 及其对应创建时间，也可以额外显示分支及其最后提交时间，该功能需要将所有的二开仓库 clone 到本地，所以需要有二开仓库权限才能操作; 二开仓库代码 clone 路径可以在 .env 文件里面 `TERMIX_TMP_PATH` 配置项里面进行配置，如果该配置项找不到会读取 `termix.toml` 里面的 `termixTmpPath` 配置;

**命令格式**: `t ls-redev-refs group=('b2c,b2b,mbr,pik') showBranch=('false')`

**参数说明**:

- `group`: 可选，需要查询分支和 Tag 的二开仓库分组，多个分组之间用`,`分隔, 默认值 `b2c,b2b,mbr,pik`，具体分组配置可以查看`termix.toml`里面的`redevRepos`配置项；
- `showBranch`: 可选，是否显示远程分支信息，默认值 `false`;

**使用举例**:

```bash
# 仅显示所有Tag及其对应创建时间信息
t ls-redev-refs
# 同时显示所有 b2c,b2b 相关业态的二开仓库Tag及分支信息
t ls-redev-refs b2c,b2b true
```

---

### 32. 批量更新远程二开仓库代码到本地{#pull-redev}

**功能描述**: 更新远程二开仓库代码到本地，该功能需要将所有的二开仓库 clone 到本地，所以需要有二开仓库权限才能操作; 二开仓库代码 clone 路径可以在 .env 文件里面 `TERMIX_TMP_PATH` 配置项里面进行配置，如果该配置项找不到会读取 `termix.toml` 里面的 `termixTmpPath` 配置;

**命令格式**: `t pull-redev branch=('master') group=('b2c,b2b,mbr,pik') diff=('false')`

**参数说明**:

- `branch`: 可选，需要更新代码的二开分支，默认值 `master`；
- `group`: 可选，需要更新代码的二开仓库分组，多个分组之间用`,`分隔, 默认值 `b2c,b2b,mbr,pik`，具体分组配置可以查看`termix.toml`里面的`redevRepos`配置项；
- `diff`: 可选，是否显示与指定 Tag 相比变化的文件，默认值 `false`，待比较的 Tag 可以在 .env 环境变量里面通过`REDEV_PREV_TAG`变量指定;

**使用举例**:

```bash
# 更新二开master分支代码到本地，不显示变化的文件列表
t pull-redev
# 更新二开develop分支代码到本地，并显示变化的文件名列表
t pull-redev develop true
```

### 33. 扫描(清理)同步仓库里面冗余分支{#prune-branches}

**功能描述**: 随着时间的推移各个部署环境的仓库里面可能存在很多不需要的分支，尤其是之前通过流水线同步的方式不会自动清理源分支不存在的同步分支，这些分支需要被清理掉，否则部署的时候找流水线也不太方便(这真的不是强行加的理由)，本脚本的作用就是扫描出这些分支，但是安全起见不会直接执行删除操作，只是提示用户这些分支是可以被清理掉的，最终还是需要用户去手工确认删掉, 可清理分支的判定原则就是读取全局同步配置: `i` 分支上的 `.termixrc` 文件然后不在同步配置里面的**部署仓库分支**即为可删除分支，如果确认的时候该分支也不是部署中的分支大概率是可以删掉的了;

**命令格式**: `t prune-synced-branches`

**参数说明**:

- 目前没有参数，只是显示可以被清理掉的分支，不做删除操作，需要手工确认删除；

**使用举例**:

```bash
# 执行该命令的时候先确保已经切换到源码仓库gaia-mall, gaia-mobile, etc.
t prune-synced-branches
```

## TODO{#todo}

- [] `just emp` 支持团队群接入，自动@工时未填满的团队成员；
- [] `ls-node` 去除对 `fnm` 的依赖;
- [] 常用应用安装脚本? 帮助新 mac 快速配置开发环境;
