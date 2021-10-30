
## 前言

`termix` ，`termi` 是公司英文简称前缀，也是命令行终端 `terminal` 的前缀，`mix` 可以理解为工具箱，`termix` 就是公司内部使用的命令行工具箱了。`termix-nu` 主要为[`Nushell`](https://github.com/nushell/nushell) 版本的`termix`, 与之对应的还有个JS版本的[`termix`](https://fe-docs.app.terminus.io/docs/termix/termix), 为了避免重复开发两者虽然名字上有关联，但是功能原则上是不重叠的。

:::tip
既然可以用JS写为什么还要采用 `Nushell`？
1. 用JS写的脚本在使用前需要安装`node_modules`依赖, 使用上稍有不便，`termix-nu`里面的脚本希望单独把脚本文件发给其他人的时候对方可以直接执行(前提是本机安装过`Nushell`)，另一方面本仓库里面的脚本主要用于日常开发的时候完成一些“微不足道”的小功能: 这些能力看似可有可无，比较杂，且不设限，不适合也没有放到`@terminus/termix`里面的必要，它的定位就是**"尽可能地通过脚本化的方式消灭日常开发过程中一切低效、重复的工作"**;
2. 没有选择`Bash`脚本是因为`Bash`是一种比较糟糕的脚本语言: 阅读维护都不太方便、而且不适合处理结构化的数据，比如JSON、TOML、CSV等等，更重要的是不能跨平台(或者比较有限)；
3. 选用 `Nushell`则是因为其更加现代、强大、语法更优雅，代码可读性和可维护性有质的提升，天生支持结构化数据、支持多平台等等，至少相比`bash`而言`nushell`是个更好的选择。更多详情可以查看其官网文档: https://www.nushell.sh/ ；
:::

## 安装

本工具集需要你在本机安装[`Nushell`](https://github.com/nushell/nushell) 和 [`just`](https://github.com/casey/just)

### Install nushell and just on macOS

```bash
# 请始终安装以下应用的最新版
brew install just
brew install nushell
# 如果你之前已经安装过建议升级到最新版
brew upgrade nushell just
```

### Install nushell and just on Windows

```cmd
# For more detail: https://github.com/lukesampson/scoop
scoop install just
winget install Nushell.Nushell
```

### Install latest version of nu

如果`brew`里面的 `Nushell` 版本没有及时更新可以自己通过 `cargo` 安装最新版:

```bash
# Install the latest version of nushell, extra features included.
cargo install nu --features=extra
# Install nushell of the specified version
cargo +stable install nu --all-features --version 0.39.0
```

## 配置

1. Clone `termix-nu` 源码:
   `git clone https://erda.cloud/terminus/dop/gaia-app-redev/termix-nu`

2. 配置环境变量:
   ```bash
   cd termix-nu
   cp .env-example .env     # 然后根据自己的情况修改 .env 里面的环境变量
   ```

3. 在`termix-nu` 目录下执行 `just` 即可查看当前提供的所有命令或者工具，如下所示:

   ```bash
    ➜  $ just
    Available recipes:
    ··· default                       # List available commands by default
    ··· dir-batch-exec cmd +DIRS=('') # 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
    ··· git-age                       # Listing the branches of a git repo and the time of the last commit
    ··· git-batch-exec cmd +branches=('') # 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用空格分隔
    ··· git-batch-reset n +branches=('') # 将指定Git分支硬回滚N个commit
    ··· git-remote-age remote=('origin') showTag=('false') # Listing the remote branches of a git repo and the day of the last commit
    ··· git-sync-branch localRef localOid remoteRef # 批量同步本地分支到远程指定分支,git pre-push hooks调用,请勿手工触发
    ··· ls-node minVer=('12')         # 查询已发布Node版本，支持指定最低版本号
    ··· ls-redev-refs showBranch=('false') # Show Branches and Tags of redevelop related repos
    ··· pull-all                      # Pull all local branches from remote repo
    ··· pull-redev branch=('master') diff=('false') # 更新远程二开仓库代码到本地
    ··· rename-branch from=('') to=('') remote=('origin') # Rename remote branch, and delete old branch after rename
    ··· show-env                      # 显示本机安装应用版本及环境变量相关信息
    ··· tag-redev tag=('') branch=('master') delete=('false') # 给远程二开仓库批量打 Tag
    ··· ver                           # Display termix current version number
   ```

5. 如果你希望在本机任意位置都可以使用`termix-nu`提供的功能，需要建立软连接:

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

6. 简化命令行输入

   可以像下面这样建一个alias，这样以后就直接输入`t`就可以了(Task)的简称：

   ```bash
    # Edit ~/.zshrc or ~/.bashrc and add:
    alias t="just --justfile ~/.justfile --working-directory ."
    # After source the profile you have edit, you can use `t` now
   ```

## 目录结构说明

```bash
.
├── Justfile      # `Just` 配置文件
├── README.md     # 本文件
├── actions       # 非 Git 相关脚本，通过 `just` 管理
├── git           # Git 仓库相关脚本，通过 `just` 管理
├── mall          # 电商标品里面的脚本，目前还在建设中...
├── run           # 不在 `just` 管理范围内的临时测试脚本
├── termix.toml   # termix-nu 的全局配置文件，toml格式, 参考: https://toml.io/
├── .env          # termix-nu 的全局环境变量，如果一个配置在termix.toml和.env里面都有，通常.env里面的优先级更高
├── .env-example  # .env 配置样本文件，可以由此拷贝到 .env 并根据个人需要进行修改
└── utils         # 通用脚本函数
```

## 使用说明

直接在`termix-nu`目录执行`just`命令即可列出所有可用命令及其参数。命令支持`tab`键自动补全，所以不用全部输完的哈。
`just`本身也支持定义**alias**, 不过考虑到alias记起来比较麻烦，而且由于已经支持自动补全了，对于alias的需求就没那么迫切了，所以把alias注释掉了，需要的可以在`Justfile`里面自己改下。

### 1. 查询本地 `termix-nu` 的版本号

可以通过 `just ver` 命令查看本地 `termix-nu` 的版本号;

### 1. 更新 `termix-nu` 到最新版本

可以通过 `just upgrade` 命令更新 `termix-nu` 到最新版本;

### 2. 指定目录批量执行特定命令

**功能描述**: 在指定目录里面执行特定命令，如果没有指定目录则会在当前目录的所有子目录内执行对应命令
**命令格式**: `just dir-batch-exec cmd +DIRS=('')`
**参数说明**:
- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `DIRS`: 可选，需要执行上述命令的目录，目录可以指定一个或者多个，多个目录中间用空格隔开，也可以为空，为空则会在当前目录的所有子目录内执行对应命令;

**使用举例**:
```bash
# 更新gaia-mall gaia-mobile gaia-picker这三个仓库的develop分支到本地
just dir-batch-exec 'git co develop; git pull' gaia-mall gaia-mobile gaia-picker
# 在 mall-base/packages 目录下通过 `npm-check-updates` 检查所有 lerna 管理的包的依赖是否有新版本:
cd ./mall-base/packages;
just dir-batch-exec 'pwd;ncu'
```

### 3. 查询已发布Node版本，支持指定最低版本号

**功能描述**: 通过[`fnm`](https://github.com/Schniz/fnm)查询已发布Node版本，支持指定最低版本号, 虽然目前依赖`fnm`, 但是若想去除该依赖是很容易的，以后有需求再说吧。
**命令格式**: `just ls-node minVer=('12') isLts=('false')`
**参数说明**:
-  `minVer`: 可选，指定查询`Node.js`的最小起始版本号，可以为空，默认值为 12, 版本号前面可以加`v`也可以不加;
-  `isLts`: 可选，是否只查询`LTS`版本，可以为空，默认值为`false`;

**使用举例**:
```bash
# 查询`12`及以后的已经发布的Node版本号
just ls-node
# 查询`16`及以后的已经发布的Node版本号
just ls-node 16
# OR
just ls-node v16
# 查询`12`及以后已经发布的Node LTS 版本号
just ls-node 12 true
```

### 4. 显示本机安装应用版本及环境变量相关信息

**功能描述**: 显示本机安装应用版本及环境变量相关信息, 这个主要方便排查问题
**命令格式**: `just show-env`
**参数说明**: N/A
**使用举例**: Run `just show-env`
**输出样例**:
![Show-Env Output](https://img.alicdn.com/imgextra/i2/O1CN01fOhVIk1vNKTl9ubIz_!!6000000006160-2-tps-902-944.png)

### 5. [Git] 查看本地Git仓库的分支及其最后提交时间

**功能描述**: 查看本地Git仓库的分支及其最后提交时间, 按最后提交时间升序排序
**命令格式**: `just git-age`
**参数说明**: N/A
**使用举例**: Run `just git-age` in a git repo.
**输出样例**:
![Git-Age Output](https://img.alicdn.com/imgextra/i1/O1CN01TSmh2F1ImH2PuFvU0_!!6000000000935-2-tps-476-190.png)

### 6. [Git] 在Git指定分支上批量执行特定命令

**功能描述**: 在指定Git分支上执行指定命令
**命令格式**: `just git-batch-exec cmd +branches=('')`
**参数说明**:
- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `branches`: 必填，需要执行上述命令的分支，分支可以指定一个或者多个，多个分支中间用空格隔开；

**使用举例**:
```bash
# 在 develop feature/latest 这两个分支上 cherry-pick 特定的 commit并推送到远程
just git-batch-exec 'git cherry-pick abcxyzuvw; git push' develop feature/latest
```

### 7. [Git] 将指定Git分支硬回滚N个commit

**功能描述**: 将指定Git分支硬回滚N个Commit, 这个命令的使用场景可能不是很多，当时是为了测试后面的 `just pull-all` 用的前置命令
**命令格式**: `just git-batch-reset n +branches=('')`
**参数说明**:
- `n`: 必填，整数，需要回滚的Commit数目;
- `branches`: 必填，需要回滚代码的分支，分支可以指定一个或者多个，多个分支中间用空格隔开；

**使用举例**:
```bash
# 将 develop feature/latest 两个分支上的代码硬回滚2个commit
just git-batch-reset 2 develop feature/latest
```

### 8. [Git] 显示Git仓库远程地址所有的分支及其最后提交信息

**功能描述**: 显示当前Git仓库远程地址所有的分支及其最后提交信息
**命令格式**: `just git-remote-age remote=('origin') showTag=('false')`
**参数说明**:
- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`;
- `showTag`: 可选，是否需要显示仓库已有标签信息，默认值`false`;

**使用举例**:
```bash
# 执行该命令前先切换到一个Git仓库
just git-remote-age
# 显示远程分支及分支最后提交时间，同时显示已有Tag及其创建时间
just git-remote-age origin true
```
**输出样例**:
![Git-Remote-Age Output](https://img.alicdn.com/imgextra/i3/O1CN01Nif5F31Bun5nC7Fpl_!!6000000000006-2-tps-561-249.png)

### 9. [Git] Git Push Hook自动将代码同步到多个目标仓库

**功能描述**: 通过Git Pre Push Hook在将指定分支Push到远程的时候自动将对应分支同步到多个目标仓库，该命令应该通过 Git Hook 自动调用，不建议手工调用；
**命令格式**: `just git-sync-branch localRef localOid remoteRef`
**使用场景**:
由于前端代码需要部署多个环境，比如PC端可能需要部署Mix、BBC、CE等环境，而且PC端的业务包括国内和海外，移动端也类似，在这种情况下如果要求开发在提交代码后手工推到各个仓库就太麻烦了，而且也很容易遗漏。当前是通过Erda的Pipeline进行代码自动同步的，这个已经不需要手工去操作了，但是发现个问题：如果要同步的目标仓库很多的话一方面耗时比较大、另一方面经常会因为服务器资源紧张而导致同步失败，即便可以成功这个同步耗时普遍也要3分钟以上，所以可以通过**Git Pre Push Hook**当开发将代码推到源码仓库的时候会自动根据配置文件顺便把代码推送到其他目的仓库，这样代码同步时间就可以缩短到秒级，而开发的代码推送关注点仍然只有一个。
**配置步骤**:

### 10. [Git] 从远程更新本地所有分支代码到最新的Commit

**功能描述**: 从远程更新本地所有分支代码到最新的Commit, 如果执行命令前本地仓库有变更会自动执行 `stash` 操作;
**命令格式**: `just pull-all`
**参数说明**: N/A
**使用举例**: Try `just pull-all` in your git repo.

### 11. [Git] Git 远程分支重命名

**功能描述**: Git 远程分支重命名, 重命名成功之后会删除旧的分支
**命令格式**: `just rename-branch from=('') to=('') remote=('origin')`
**参数说明**:
- `from`: 必填，待重命名的分支名，旧分支名所对应分支应该存在于本地或者远程;
- `to`: 必填，重命名之后新的分支名称, 新分支名所对应分支应该是本地和远程都不存在的;
- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`;

**使用举例**:
```bash
just rename-branch feature/old feature/new
```

### 12. [二开] 显示标品二开仓库的远程分支及Tag信息

**功能描述**:

显示标品二开仓库的所有Tag及其对应创建时间，也可以额外显示分支及其最后提交时间，该功能需要将所有的二开仓库 clone 到本地，所以需要有二开仓库权限才能操作; 二开仓库代码 clone 路径可以在 .env 文件里面 `REDEV_REPO_PATH` 配置项里面进行配置，如果该配置项找不到会读取 `termix.toml` 里面的 `redevRepoPath` 配置;

**命令格式**: `just ls-redev-refs showBranch=('false')`
**参数说明**:
- `showBranch`: 可选，是否显示远程分支信息，默认值 `false`;

**使用举例**:
```bash
# 仅显示所有Tag及其对应创建时间信息
just ls-redev-refs
# 同时显示二开仓库Tag及分支信息
just ls-redev-refs true
```

### 13. [二开] 更新远程二开仓库代码到本地

**功能描述**: 更新远程二开仓库代码到本地，该功能需要将所有的二开仓库 clone 到本地，所以需要有二开仓库权限才能操作; 二开仓库代码 clone 路径可以在 .env 文件里面 `REDEV_REPO_PATH` 配置项里面进行配置，如果该配置项找不到会读取 `termix.toml` 里面的 `redevRepoPath` 配置;
**命令格式**: `just pull-redev branch=('master') diff=('false')`
**参数说明**:
- `branch`: 可选，需要更新代码的二开分支，默认值 `master`；
- `diff`: 可选，是否显示与指定Tag相比变化的文件，默认值 `false`，待比较的Tag可以在 .env 环境变量里面通过`REDEV_PREV_TAG`变量指定;

**使用举例**:
```bash
# 更新二开master分支代码到本地，不显示变化的文件列表
just pull-redev
# 更新二开develop分支代码到本地，并显示变化的文件名列表
just pull-redev develop true
```

### 14. [二开] 给远程二开仓库批量打 Tag

**功能描述**: 给远程二开仓库指定分支批量打 Tag, 也可以用于删除指定Tag
**命令格式**: `just tag-redev tag=('') branch=('master') delete=('false')`
**参数说明**:
- `tag`: 必填，需要新增的Tag前缀，创建Tag的时候默认会加上日期信息，比如当指定Tag为`v2.2.0`的时候实际生成的可能为`v2.2.0-2021.10.27`；
- `branch`: 可选，需要打Tag的二开分支，默认值 `master`；
- `delete`: 可选，`true`表示删除指定Tag且不重新添加对应Tag，默认值 `false` 表示Tag不存在则新增Tag，存在则先删除再新增;

**使用举例**:
```bash
# 从二开仓库master分支创建新的Tag，比如 `v2.2.0-2021.10.27`
just tag-redev v2.2.0
# 删除`v2.2.0`对应的当天的Tag
just tag-redev v2.2.0 master true
# 从二开仓库develop分支创建新的Tag `v2.5.0`
just tag-redev v2.5.0 develop
```

### 15. 查看团队成员当前EMP工时填报情况

**功能描述**: 查看团队成员当前EMP工时填报情况
**命令格式**: `just emp`
**配置说明**:
**使用举例**:

## TODO

[] `ls-node` 去除对 `fnm` 的依赖;
[] 电商里面的`bash`脚本转成基于`nushell`的;
[] 常用应用安装脚本? 帮助新mac快速配置开发环境;
