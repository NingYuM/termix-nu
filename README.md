
## 前言

`termix` ，`termi` 是公司英文简称前缀，也是命令行终端 `terminal` 的前缀，`mix` 可以理解为工具箱，`termix` 就是公司内部使用的命令行工具箱了。`termix-nu` 主要为[`Nushell`](https://github.com/nushell/nushell) 版本的`termix`, 与之对应的还有个JS版本的[`termix`](https://fe-docs.app.terminus.io/docs/termix/termix), 为了避免重复开发两者虽然名字上有关联，但是功能原则上是不重叠的。

:::tip
既然可以用JS写为什么还要采用 `Nushell`？
1. 用JS写的脚本在使用前需要安装`node_modules`依赖, 使用上稍有不便，`termix-nu`里面的脚本希望单独把脚本文件发给其他人的时候对方可以直接执行(前提是本机安装过`Nushell`)，另一方面本仓库里面的脚本主要用于日常开发的时候完成一些“微不足道”的小功能：这些能力看似可有可无，比较杂，且不设限，不适合也没有放到`@terminus/termix`里面的必要;
2. 没有选择`Bash`脚本是因为`Bash`是一种比较糟糕的脚本语言：阅读维护都不太方便、而且不适合处理结构化的数据，比如JSON、TOML、CSV等等，更重要的是不能跨平台(或者比较有限)；
3. 选用 `Nushell`则是因为其更加现代、强大、语法更优雅，代码可读性和可维护性有质的提升，天生支持结构化数据、支持多平台，等等；
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

如果`brew`里面的 `Nushell` 版本没有及时更新可以自己通过 `cargo` 安装最新版：

```bash
# Change the version number to the latest one
cargo +stable install nu --all-features --version 0.38.0
# Simplified version
cargo install nu --features=extra
```

## 配置

1. Clone `termix-nu` 源码:
   `git clone https://erda.cloud/terminus/dop/gaia-app-redev/termix-nu`

2. 配置环境变量:
   ```bash
   cd termix-nu
   cp .env-example .env     # 然后根据自己的情况修改 .env 里面的环境变量
   ```

3. 在`termix-nu` 目录下执行 `just` 即可查看当前提供的所有命令或者工具，如下所示：

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

5. 如果你希望在本机任意位置都可以使用`termix-nu`提供的功能，需要建立软连接：

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

   ```bash
    # Edit ~/.zshrc or ~/.bashrc and add:
    alias t="just --justfile ~/.justfile --working-directory ."
    # After source the profile you have edit, you can use `t` now
   ```

## 使用说明

### 查询本地 `termix-nu` 的版本号

### 指定目录批量执行特定命令

### 查询已发布Node版本，支持指定最低版本号

### 显示本机安装应用版本及环境变量相关信息

### [Git] 查看本地Git仓库的分支及其最后提交时间

### [Git] 在Git指定分支上批量执行特定命令

### [Git] 将指定Git分支硬回滚N个commit

### [Git] 显示Git仓库远程地址所有的分支及其最后提交信息

### [Git] Git Push Hook自动将代码同步到多个目标仓库

### [Git] 从远程更新本地所有分支代码到最新的提交

### [Git] Git 远程分支重命名

### [二开] 显示标品二开仓库的远程分支及Tag信息

### [二开] 更新远程二开仓库代码到本地

### [二开] 给远程二开仓库批量打 Tag

