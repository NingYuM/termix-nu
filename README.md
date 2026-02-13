import AsciiPlayer from '../../src/components/asciinema.tsx';

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

**注**：新用户建议通过 termix-nu 里面自带的 `setup-termix.sh` 脚本进行安装以减少后续升级问题，而且速度也更快，见后文**提示**部分。

```bash
# 请始终安装以下应用的最新版
brew update
brew install just
brew install nushell
# 如果你之前已经安装过建议升级到最新版
brew update
brew upgrade nushell just
```

**提示：**

如果由于系统版本太低的原因导致安装失败，或者 `brew` 安装太慢，或者你使用 Linux 系统，无法使用 `brew`，可以通过：`bash run/setup-termix.sh` 进行安装(需要先克隆 `termix-nu` 仓库, 参见后文说明)，该脚本会自动安装 `nushell`, `just`, `fzf` 等后续可能会用到的二进制文件到 `/usr/local/bin/` 目录（如果你想安装到其他目录，可以传参，比如：`bash run/setup-termix.sh /usr/bin/`），而且该命令直接从 OSS 上下载安装，速度非常快！

### Install nushell and just on Windows

```bash
# For more detail: https://github.com/lukesampson/scoop
scoop install just
scoop install nu
# Or you can install Nu by winget
winget install Nushell.Nushell
```

:::info 注意事项

对于通过 `brew` 安装 `nushell` 的用户在后续升级之后由于 `nushell` 二进制文件存储路径发生了变化(`brew` 安装的版本号会在路径里得到体现)，`nushell` 的插件配置文件会因找不到之前注册的插件而报错，此时直接把插件注册文件（比如: `/Users/hustcer/Library/Application Support/nushell/plugin.nu`）删掉即可，后续在使用工具的过程中会自动重新注册插件。

:::

### Install latest version of nu

如果`brew`里面的 `Nushell` 版本没有及时更新, 可以自己下载最新版本的 `nightly` 包: https://github.com/nushell/nightly/releases

### `Just` & `nu` 更新提示

本仓库的脚本工具执行的时候会检查本机安装的 `just` & `nu` 的版本, 如果当前安装的版本小于 `termix.toml` 里面的 `minNuVer` 或者 `minJustVer` 指定的最低版本要求，就会在终端提示您升级`just` 或者 `nu` 到最新版本，尤其是当本地 `termix-nu` 版本更新后出于兼容性考虑对`just` & `nu`的最低版本有要求，如果版本过低可能会导致工具脚本无法正常运行。

## 配置{#config}

1. Clone `termix-nu` 源码:

   Erda Web 访问地址: https://erda.cloud/terminus/dop/projects/213/apps/8053/repo

   ```bash
   # Clone source code to local disk
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
   Available commands:

    [-- Backend --]
    msync *OPTIONS             # TERP Meta data synchronization tool

    [-- Common  --]
    art *OPTIONS               # Create, download, upload and deploy from the artifacts
    brew *OPTIONS              # 通过 Brew 国内镜像加速执行 brew 相关命令
    default                    # List available commands by default
    deploy *OPTIONS            # 执行Erda流水线,可通过`dp -l`列出所有部署目标,在批量部署模式下通过`--app`指定待部署应用
    dp *OPTIONS                # alias for `deploy`
    deploy-query *OPTIONS      # Query the Erda pipeline running status by CICD id or `--app`
    dq *OPTIONS                # alias for `deploy-query`
    ding-msg *OPTIONS          # Send a message to DingTalk Group by a custom robot
    dir-batch-exec *OPTIONS    # 在指定目录(支持'*'通配符)或者当前目录的所有子目录里执行指定命令, cmd为待执行命令字符串
    emp *OPTIONS               # 查询团队本周工时填报情况
    go nav=('list')            # 快速在默认浏览器里打开匹配的链接
    show-env                   # 显示本机安装应用版本及环境变量相关信息
    upgrade *OPTIONS           # Upgrade termix-nu repo, just or nushell to the latest version
    ver                        # Display termix current version number

    [-- Frontend --]
    ls-node *OPTIONS           # 查询已发布Node版本，支持指定最低版本号
    query-deps *OPTIONS        # Query node dependencies in all package.json files on specified branches
    terp-assets *OPTIONS       # Download, transfer or sync TERP assets
    ta *OPTIONS                # alias for `terp-assets`

    [-- Git --]
    check-branch               # 分支检查: 检查是否所有分支都有描述信息以及是否有可同步分支在远程仓库被删除
    git-batch-exec *OPTIONS    # 在指定git分支上执行指定命令,cmd为待执行命令字符串,多个分支用`,`分隔
    git-branch *OPTIONS        # Listing the branches of a git repo and the time of the last commit
    git-desc *OPTIONS          # Show branch description from branch description file `d` of `i` branch
    git-diff-commit *OPTIONS   # Show commit info diff between two commits, e.g. t git-diff-commit 051da464 0ab1df2d
    git-pick *OPTIONS          # Pick matched commits from one branch to another branch.
    git-proxy status=('on')    # 开启或者关闭 git 代理, 目前仅支持在阿里郎加速模式下开启 git 代理
    git-remote-branch *OPTIONS # Listing the remote branches of a git repo with the extra info
    git-stat *OPTIONS          # Show insertions/deletions and number of files changed for each commit
    gsync *OPTIONS             # 手工触发批量同步本地分支到远程指定分支
    ls-tags by=('time')        # 按时间顺序列出所有的 git tags, 默认按 `time` 排序，可选按 `tag` 排序：ls-tags tag
    pull-all                   # Pull all local branches from remote repo
    rename-branch *OPTIONS     # Rename remote branch, and delete old branch after rename
    repo-transfer *OPTIONS     # Transfer a git repo from source to the dest
   ```

4. 如果你希望在本机任意位置都可以使用`termix-nu`提供的功能，需要建立软连接（也强烈建议你这么做）:

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

## Docker 镜像{#docker-image}

为了方便大家使用，从 `v1.87.0` 版本开始每个发布版本都会同时构建一个 Docker 镜像(基于 Alpine Linux)，比如：

- 特定版本镜像：`registry.erda.cloud/terp/termix:1.87`;
- 如果需要最新版本稳定镜像也可以从 `registry.erda.cloud/terp/termix:latest` 拉取;
- 如果想尝试正在开发中的镜像可以从 `registry.erda.cloud/terp/termix:bleeding` 获取;

Docker 镜像里面已经配置好了 `t` 命令（以及各种运行时所需依赖），默认情况下通过 `docker run -it --rm registry.erda.cloud/terp/termix:latest` 启动时会进入 `nushell` 会话，之后可以根据情况调整镜像里面的 `termix-nu` 配置: `/home/termix/.termixrc` & `/home/termix/.env`, 在 `nushell` 会话中你可以执行各种 Alpine Linux 命令，如果你执行的命令在 `nushell` 里面也存在会默认执行 `nushell` 版本，比如 `ls`, 若想强制执行发行版自带的 `ls` 使用 `^ls` 即可。

如果你想使用其它 Shell 比如 `sh` 进入镜像，可通过 `docker run -it --rm registry.erda.cloud/terp/termix:latest sh --login` 启动，之所以要加 `--login` 是为了加载 `sh` 配置文件并设置 `t` alias。

每次输入这么长的命令还是比较繁琐的，也可以创建一个 `docker-compose.yml` 文件，比如：

```yml
# Run the container with: docker compose up
# Or for a one-time run: docker compose run --rm termix
# Home dir of termix-nu in the container: /home/termix/termix-nu
services:
  termix:
    tty: true
    stdin_open: true
    # always: Always pull the image from the registry, ignoring any locally cached copies
    # if_not_present: Only fetching an image if it hasn't been downloaded yet
    pull_policy: always
    image: registry.erda.cloud/terp/termix:latest
    volumes:
      # - ./.env:/home/termix/.env
      - ./.termixrc:/home/termix/.termixrc
```

这样就可以通过 `docker compose up` 或者 `docker compose run --rm termix` 启动了。需要注意的是在这个配置文件中将本地目录里面的 `.termixrc` 配置文件映射到容器里面的 `/home/termix/.termixrc` 位置，这样就可以复用本地配置文件了。

## 辅助支持命令{#helper-cmd}

---

直接在`termix-nu`目录执行`t`(即 `just` 命令，以下均假设大家已经在本地为其创建了 `t` Alias)命令即可列出所有可用命令及其参数。命令支持`tab`键自动补全，所以不用全部输完的哈。
`just`本身也支持定义**alias**, 不过考虑到 alias 记起来比较麻烦，而且由于已经支持自动补全了，对于 alias 的需求就没那么迫切了，所以把 alias 注释掉了，需要的可以在`Justfile`里面自己改下。

### 1. 查询本地 `termix-nu` 的版本号{#ver}

可以通过 `t ver` 命令查看本地 `termix-nu` 的版本号;

---

### 2. 30秒极速更新 `termix-nu` 及相关依赖{#upgrade}

此工具箱里面的脚本每天第一次执行的时候会检查远程是否有新版本，如果有可以通过 `t upgrade` 命令更新 `termix-nu` 到最新版本, 本质上是将本地脚本仓库更新到远程最新的 Release Tag 对应的提交，所以如果命令更新失败你也可以进入到 `termix-nu` 代码仓库所在目录直接更新 `master` 分支代码;

`termix-nu` 的版本与 `nushell` 的版本是对应的，前者往往依赖 `nushell` 最新版本的一些特性, 所以如果通过 `t upgrade` 命令更新 `termix-nu` 后发现功能不正常或者提示 Nushell 版本过低可以通过 `brew outdated; brew upgrade nushell`（对于 Windows 系统可以通过 `scoop update nushell` 或者 `winget upgrade Nushell.Nushell`）命令更新 `nushell`。

考虑到通过 `brew` 等工具更新 `nushell` 和 `just` 时候可能会从 GitHub 上下载对应的包，这个速度通常会比较慢，从 `v1.60.0` 开始 `t upgrade` 内置支持更新 `nushell` & `just` 只需要执行 `t upgrade nu` 和 `t upgrade just` 即可，这两个命令会检查本地是不是最新版本，如果不是对于`Windows` & `Linux` 系统会从 Aliyun OSS 上下载最新的 `nushell` & `just` 并安装到本地，直接替换原来老的二进制文件。工具会根据你的操作系统和CPU架构自动选择正确的发行版，所以你也不用操心到底该下载哪个安装包。最重要的是不用在意一墙之隔，下载速度可达 10MB/s 左右, 让您不再畏惧升级。

而对于 `MacOS` 会使用 `brew` 命令通过国内的镜像升级`nushell` & `just`，这样由于二进制文件是从国内镜像下载的，更新速度依然飞快，眨眼间即可完成。

终极更新大法：`t upgrade --all` 或 `t upgrade -a` 同时更新 `termix-nu`, `just` & `nushell`，从此升级不用愁。

:::info

如何确保 Aliyun OSS 上的 `nushell` 和 `just` 是最新的？

这个当然不是靠人工上传的，实际上背后是通过 Github 的 WorkFlow 每天定时执行，自动检查有没有新的 `nushell` 或 `just` 发布，如果有就把 Aliyun OSS 上老的安装包删掉并上传最新的安装包，所以 OSS 上始终只有一个版本的 `nushell` 和 `just` 并且应该是官方最新发布的版本。只要这个机制不出问题你应该可以相信 `t upgrade` 帮你安装的是最新的版本。

不过通过`t upgrade`更新 `nushell` 和 `just` 也是有瑕疵的：

`Windows` 不支持对正在运行的可执行文件进行写操作，由于 `t upgrade` 是 `nushell` 脚本驱动的，所以在执行 `t upgrade nu` 的时候会在 `nu.exe` 所在的目录里面创建一个 `nu-latest.exe` 文件，这个文件需要你后续自己手工替换下，好在其他 `nu_plugin_*` 文件会自动更新掉。不过只有在更新 `nu` 的时候有这个问题，而且仅限于 `Windows` 系统；

:::

---

### 3. `termix-nu` 自检、问题修复以及 Trantor 前端应用配置诊断{#doctor}

可以通过 `t doctor` 命令对 `termix-nu` 的常见问题进行自检，自检完毕后会输出当前配置存在的问题及相关修复建议, 甚至可以通过 `--fix` 参数对 `termix-nu` 的配置问题进行自动修复。

除了诊断 `termix-nu` 的配置问题之外，还可以诊断 Trantor 前端应用(**Console**, **Portal**, **Portal-H5**)的常见部署配置问题，目前诊断项包括：

- 是否配置了 `latest.json` 网关转发策略，如果没配会给予修复提示；
- 配置了 `latest.json` 网关情况下是否配置了 `x-trantor-endpoint` Nginx 业务策略，如果没配会给予修复提示；
- 检查 `latest.json` 的响应类型、状态码和缓存策略是否有问题；
- 是否缺少 `base`,`base-mobile`,`service`,`service-mobile`,`iam`,`terp`,`terp-mobile` 等必要前端模块；
- 是否配置了 `terp-assets` 网关转发策略，如果没配会给予修复提示；
- 是否将 `terp-assets` 静态资源上传到客户云存储的正确位置，如果没有也会给出修复提示；

未来还会增加更多诊断项，并且会针对诊断出来的问题给出修复提示，方便迅速排查应用部署问题，不过这些问题都是需要负责人去手工修复的，无法通过 `--fix` 自动修复。

**命令格式**: `t doctor *OPTIONS`

**参数说明**:

- `-f, --fix`: 对诊断发现的问题进行自动修复（如果没问题不会执行任何操作）；
- `-d, --debug`: 显示诊断过程中的 Debug 信息；
- `host <string>`: 可选，待诊断的 Trantor 前端应用的域名

**使用举例**:

```bash
# 诊断本机 termix-nu 存在的问题，并给出修复建议
t doctor
# 对诊断发现的问题进行自动修复
t doctor --fix
# 诊断 Trantor 前端应用配置问题
t doctor t-erp-portal-test.app.terminus.io
# 同时诊断多个 Trantor 前端应用发现潜在的配置问题
t doctor t-erp-portal-test.app.terminus.io,t-erp-console-test.app.terminus.io
```

---

### 4. 发布 `termix-nu` 新版本{#release}

可以通过 `t release` 命令发布 `termix-nu` 的最新版本，版本发布前要做的工作：

1. 修改`termix.toml`文件里面的`version`字段到将要发布的版本号(需要确保该版本不存在，且相对于上一个版本号更大);
2. 确保 `termix-nu` 仓库里面没有未提交的变更;

发布新版本的过程主要做了如下操作：

1. 如果加上 `--update-log(-l)`则会利用 [git-cliff](https://github.com/orhun/git-cliff) 根据 commit 记录更新最新的`CHANGELOG.md`(需要大家在创建 commit 的过程中遵循[Commit 规范](https://fe-docs.app.terminus.io/docs/mall/spec/git))并提交;
2. 新建了一个以版本号命名的 Tag 并推送到远程；

**命令格式**: `t release *OPTIONS`

**参数说明**:

- `-l, --update-log`: 是否需要通过提交记录生成最新的`CHANGELOG.md`并提交；

**使用举例**:

```bash
# 根据`termix.toml`文件里面的`version`配置生成对应版本的Release Tag并推送至远程，但不自动更新`CHANGELOG.md`
t release
# 自动更新`CHANGELOG.md`，然后根据`termix.toml`文件里面的`version`配置生成对应版本的Release Tag并推送至远程
t release --update-log
```

---

### 5. 显示本机 CLI 应用版本及环境变量信息{#show-env}

**功能描述**: 显示本机安装应用版本及环境变量相关信息, 这个主要为了方便排查问题

**命令格式**: `t show-env`

**参数说明**: N/A

**使用举例**: Run `t show-env`

**输出样例**:
![Show-Env Output](https://img.alicdn.com/imgextra/i4/O1CN01WIxUKw1tHGBAAxVZK_!!6000000005876-2-tps-1223-888.png)

---

## 通用脚本工具{#common-cmd}

---

### 6. 浏览器快捷导航{#go}

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

另：当`termix.toml`里面的`useConfFromBranch`配置项值为`_current_`时`.termixrc`配置会从当前分支对应的远程分支读取，当该配置的值为`i`时会从`origin/i`分支上读取，关于`i`分支的更多说明请看[后文](#git-desc)。

---

### 7. 指定目录批量执行特定命令{#dir-batch-exec}

**功能描述**: 在指定目录里面执行特定命令，如果没有指定目录则会在当前目录的所有子目录内执行对应命令

**命令格式**: `t dir-batch-exec {flags} <cmd> (dirs)`

**参数说明**:

- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `dirs`: 可选，需要执行上述命令的目录，目录可以指定一个或者多个，多个目录中间用`,`隔开，也可以为空，为空则会在当前目录的所有子目录内执行对应命令;
- `-p` 或 `--parent`：如果 `dirs` 参数为空则会在该参数指定目录的所有子目录内执行对应命令;
- `-h` 或 `--help`: 查看帮助文档

**使用举例**:

```bash
# 更新gaia-mall gaia-mobile gaia-picker这三个仓库的develop分支到本地
t dir-batch-exec 'git co develop; git pull' gaia-mall,gaia-mobile,gaia-picker
# 在 mall-base/packages 目录下通过 `npm-check-updates` 检查所有 lerna 管理的包的依赖是否有新版本:
cd ./mall-base/packages;
t dir-batch-exec 'pwd;ncu'
```

---

### 8. 查询已发布 Node 版本{#ls-node}

**功能描述**: 查询已发布 `Node` 版本以及内置的 `npm` 版本和发布时间，支持指定最低 `Node` 主版本号，默认 `16`

**命令格式**: `t ls-node {flags} (minVer)`

**参数说明**:

- `minVer`: 可选，指定查询`Node.js`的最小起始版本号，可以为空，默认值为 `16`, 版本号前面可以加`v`也可以不加;
- `--lts`: 是否只查询`LTS`版本;
- `-h` 或 `--help`: 查看帮助文档;

**使用举例**:

```bash
# 查询`16`及以后的已经发布的Node版本号
t ls-node
# 查询`18`及以后的已经发布的Node版本号
t ls-node 18
# OR
t ls-node v18
# 查询`16`及以后已经发布的Node LTS 版本号
t ls-node 16 --lts
```

---

### 9. 查看本地 Git 仓库分支及最后提交时间{#git-branch}

**功能描述**: 查看本地 Git 仓库的分支及其最后提交时间, 按最后提交时间升序排序

**命令格式**: `t git-branch {flags} (path)`

**参数说明**:

- `path` - 可选，Git 仓库路径，默认为当前路径
- `-c` 或 `--contains` - 在分支上查询是否有 Commit Message 里面包含指定字符串的提交，有则在结果中显示，如果你希望知道某一个 Commit 被 `cherry-pick` 到了哪些分支上可以使用此参数；
- `-t` 或 `--show-tags` - 按时间倒序显示所有本地 Tag
- `-h` 或 `--help `- 显示此命令相关帮助文档

**使用举例**:

```bash
# 查看本地 Git 仓库分支及最后提交时间
t git-branch
# 根据提交信息查询某一个 Commit 被 `cherry-pick` 到哪些分支上
t git-branch --contains "这是一个重要的补丁，需要被 cherry-pick 到多个分支"
```

**输出样例**:

![Git-Branch Output](https://img.alicdn.com/imgextra/i4/O1CN01EPuq6a1hwEDWqFiwa_!!6000000004341-2-tps-714-205.png)

注：如果 `remote` 列标记了 `√` 表示该分支在远程存在。

---

### 10. 显示 Git 仓库远程分支及其最后提交信息{#git-remote-branch}

**功能描述**: 显示当前 Git 仓库远程地址所有的分支及其最后提交信息

**命令格式**: `t git-remote-branch {flags} (remote)`

**参数说明**:

- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`
- `-t` 或 `--show-tags`: 显示仓库已有 TAG 列表
- `-c` 或 `--clean`: 以交互式方式清理已合并分支
- `-m` 或 `--main-branch`: 分支清理或者检查分支合并状态时所基于的主分支，默认按先后顺序会依次检查 `master` 或者 `main` 或者 `develop`
- `-h` 或 `--help `：显示此命令相关帮助文档

**使用举例**:

```bash
# 执行该命令前先切换到一个Git仓库
t git-remote-branch
# 显示远程分支及分支最后提交时间，同时显示已有Tag及其创建时间
t git-remote-branch origin --show-tags
# 检查远程仓库已经合并到 master 分支的所有分支，并列出可以清理的分支，允许用户手工选择对应分支并批量删除
t git-remote-branch -c -m master
```

**输出样例**:

![Git-Remote-Branch Output](https://img.alicdn.com/imgextra/i2/O1CN01lC4u5Z1uIvESQqbIp_!!6000000006015-2-tps-645-206.png)

注：如果 `local` 列标记了 `√` 表示该分支在本地存在。

---

### 11. 在指定 Git 分支上批量执行特定命令{#git-batch-exec}

**功能描述**: 在指定 Git 分支上执行指定命令

**命令格式**: `git-batch-exec <cmd> (branches)`

**参数说明**:

- `cmd`: 必填，待执行的命令，如果有空格需要用引号包裹，`cmd`参数对应命令默认通过`bash`执行(默认值在 `termix.toml` 的 `shellToRunCmd.currentSelected`里面指定)，如果你需要更改命令解释、执行器可以修改`.env`里面的`SHELL_TO_RUN_CMD`环境变量，可选值：`nu`/`sh`/`cmd`/`zsh`/`fish`/`node`/`bash`/`python3`/`powershell`等;
- `branches`: 必填，需要执行上述命令的分支，分支可以指定一个或者多个，多个分支中间用 `,` 隔开；

**使用举例**:

```bash
# 在 develop feature/latest 这两个分支上 cherry-pick 特定的 commit并推送到远程
t git-batch-exec 'git cherry-pick abcxyzuvw; git push' develop,feature/latest
```

---

### 12. 统计各 git commit 增删改信息{#git-stat}

**功能描述**: 统计各 git commit 的增加、删除代码行数以及所修改文件数

**命令格式**: `t git-stat *OPTIONS`

**参数说明**:

- `-j` 或 `--json`: 输出 JSON 格式的统计数据；
- `-s` 或 `--summary`: 显示统计汇总信息；
- `--summary-only`: 只输出统计汇总信息；
- `-f` 或 `--from`: 需要统计的 commit 记录起始时间，格式为 `YYYY/MM/DD`；
- `-t` 或 `--to`: 需要统计的 commit 记录结束时间，格式为 `YYYY/MM/DD`，默认值为当前日期；
- `-c` 或 `--max-count`: 需要统计的 commit 记录最大条数，默认前 20 条;
- `-a` 或 `--author`: 需要统计的 commit 提交者 ID，默认所有提交者；
- `-e` 或 `--exclude <String>`: 需要在统计中排除的文件，多个文件之间用 `,` 分隔，比如 `pnpm-lock.yaml` 等，若文件不存在不会报错；
- `-h` 或 `--help`: 查看该命令的相关帮助；

**使用举例**:

```bash
# 统计当前仓库当前分支的 commit 数据
t git-stat
# 统计当前仓库当前分支 git 账号为 hustcer 的用户的 前30条 commit 数据
t git-stat -c 30 -a hustcer
# 在上述统计结果的基础上显示统计汇总信息
t git-stat -c 30 -a hustcer -s
# 将 pnpm-lock.yaml 文件的变更排除在统计结果之外
t git-stat -c 30 -a hustcer -s -e pnpm-lock.yaml
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

### 13. 将指定 Git 分支硬回滚 N 个 commit{#git-batch-reset}

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

### 14. 从远程更新本地所有分支代码到最新{#pull-all}

**功能描述**: 从**远程更新本地所有分支代码**到最新的 Commit, 如果执行命令前本地仓库有变更会自动执行 `stash` 操作;

**命令格式**: `t pull-all alias=('origin')`

**参数说明**:

- `alias`: 可选，远程仓库地址对应的 **alias** 名称，默认值 `origin`;

**使用举例**:

```bash
# 从远程 origin 更新本地所有分支代码到最新的Commit
t pull-all
# 从远程地址 alias 为 deploy 的仓库更新本地所有分支代码到最新的Commit
t pull-all deploy
```

---

### 15. Git 远程 & 本地分支重命名{#rename-branch}

**功能描述**: Git 远程分支重命名, 重命名成功之后会删除旧的分支

**命令格式**: `t rename-branch <from> <to> (remote)`

**参数说明**:

- `from`: 必填，待重命名的分支名，旧分支名所对应分支应该存在于本地或者远程;
- `to`: 必填，重命名之后新的分支名称, 新分支名所对应分支应该是本地和远程都不存在的;
- `remote`: 可选，远程仓库地址对应的 alias 名称，默认值 `origin`;

**使用举例**:

```bash
t rename-branch feature/old feature/new
```

---

### 16. Git 仓库迁移{#repo-transfer}

**功能描述**: 将 Git 仓库迁移到新的地址：迁移内容包含代码、提交历史记录、分支、Tag 等

**命令格式**: `t repo-transfer <source> <dest>`

**参数说明**:

- `source`: 必填，源仓库 Git 地址;
- `dest`: 必填，目的仓库 Git 地址;

**使用举例**:

```bash
t repo-transfer https://old.source-repo.url https://new.dest-repo.url
```

---

### 17. Git 请求代理{#git-proxy}

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

### 18. 查看 Git 分支描述信息{#git-desc}

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

**命令格式**: `t git-desc {flags} (branch)`

**参数说明**:

- `branch`: 选填，待查看描述信息的分支名，默认`git branch --show-current`输出的当前分支;
- `-a` 或 `--all`: 显示所有分支描述信息;
- `-n` 或 `--show-notes`: 是否显示分支描述说明文档;
- `-h` 或 `--help`: 显示该命令的帮助文档;

**使用举例**:

```bash
# 查看当前分支描述信息
t git-desc
# 查看当前仓库所有分支描述信息
t git-desc -a
# 查看 develop 分支描述信息以及分支描述说明文档
t git-desc develop --show-notes
```

---

### 19. Git 分支检查{#check-branch}

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

### 20. Git Push 自动将代码同步到多个仓库{#git-sync-branch}

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
4. `.termixrc`配置文件可以从当前分支对应的远程分支读取也可以从远程`origin/i`分支读取，`termix.toml` 里面有个配置项 `useConfFromBranch` 该配置项可以指定`.termixrc`配置文件从哪个分支读取，当该配置项的值为 `_current_` 的时候表示从当前分支对应的**远程分支**读取，否则从`origin/i`分支读取，默认也是从`origin/i`分支读取（**事实证明该默认行为也是最佳实践，避免了后续配置文件各分支不同步的不便，强烈建议大家采用该方式**）, 此时`origin/i`分支相当于是一个可以存储全局数据的地方，所有开发成员从任何分支都可以读取该分支的数据，也避免了各成员、各分支配置文件不同步的情况，关于`i`分支[前面](#git-desc)已经有所说明；

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

### 21. 手工触发分支批量同步{#git-sync}

**功能描述**: 前文所说的同步是由本地执行 `git push` 操作自动触发的，但是如果代码是通过线上提 MR 然后合并进 Git 仓库的话是不会触发 Pre Push Hook 的，此时可以通过该命令手工触发。该命令执行前不需要用户手工更新代码，命令执行的时候会自动更新的，而且这个命令可以随时、重复执行，除了将指定分支代码更新到本地以及根据关联配置同步到远程之外没有其他副作用。

**命令格式**: `gsync branch=(`git branch --show-current`)`

**参数说明**:

- `branch`: 选填，待触发同步的分支名，默认`git branch --show-current`输出的当前分支;
- `--list` 或者 `-l` 参数: 列出所有已经配置的分支同步信息
- `--all` 或者 `-a` 参数: 批量同步所有有同步配置的分支
- `--repo <String>` 或者 `-r` 参数：指定要同步到的目的仓库，该参数会忽略分支的同步配置信息，直接将指定分支同步到对应仓库，要求 `repos` 配置项里面有该仓库的配置信息
- `--force` 或者 `-f` 参数: 强制同步，效果类似于 `git push -f`(从 v1.50 版本开始加`-f`即可，不需要在命令前加 `FORCE=1`)；
- 对于 v1.50 之前的版本如果在同步的时候想采用强制推送策略需要：`FORCE=1 t gsync ...`；

**使用举例**:

```bash
# 触发当前分支的批量同步
t gsync
# 触发 `feature/sync` 分支所关联的批量同步操作
t gsync feature/sync
# 将 release/2.5.23.1116 分支同步到 terp-rls 仓库，要求 toml 的 `repos` 配置项里面有 `terp-rls` 的配置信息
t gsync release/2.5.23.1116 -r terp-rls
```

---

### 22. Git 提交记录比较{#git-diff-commit}

**功能描述**:

在项目上线后的每一次发版都要很谨慎，尤其是对于预发和生产的分支，在某些情况下需要知道当前分支的最近一次发布和最新的 Commit 之间究竟有哪些 Commit, 这些 Commit 是谁在什么时候提交的？提交信息是什么样的？SHA 值是什么？你可能需要这个数据跟每一位研发确认，或者可能需要拉个 hotfix 分支并 cherry-pick 其中的某些 Commit 然后单独发个修复版本。这种情况就比较适合用这个命令：`git-diff-commit`

**命令格式**: `git-diff-commit {flags}`

**参数说明**:

- `-f`, `--from <String>` - 需要比较的起始 Commit SHA
- `-t`, `--to <String>` - 需要比较的终止 Commit SHA 或 ref (默认: 'HEAD')
- `-g`, `--grep <String>` - 在Commit的 Author,SHA,Date 和备注字段搜索指定关键字
- `-C`, `--not-contain <String>` - 筛选提交备注里面不包含特定关键字的 Commit
- `-H`, `--exclude-shas <String>` - 排除特定的 SHA，多个值可以用 `,` 分隔
- `-A`, `--exclude-authors <String>` - 排除特定的 Author，多个值可以用 `,` 分隔
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

### 23. Git Commit 批量 cherry-pick {#git-batch-pick}

**功能描述**:

目前前端 `terp-ui` & `service-ui` 强制要求每个 **Commit** 在提交信息里面必须包含其所属迭代信息比如 `fix-0330: xxx`, `feat-0330: xxx` 等等，这样做的好处是每个 **Commit** 归属哪个迭代一目了然，在该迭代提测及发布之后可以通过该工具批量 `cherry-pick`，确保该迭代的所有 **Commit** 都被 `pick` 到对应的 `release/*` 分支, 也确保在相应版本的 `release/*` 分支上的所有缺陷修复等都万无一失地 `pick` 到主分支, 尤其当一个分支上有下个迭代的 **Commit** 不能直接通过 `merge` 合并时通过该工具可以大大节省时间并防止遗漏。

该工具具有如下特性:

- 批量 `cherry-pick` 时会按时间先后顺序进行，早提交的会先被 `cherry-pick` 到目标分支，保持先后顺序；
- 批量 `cherry-pick` 时会保证每个 Commit 的提交时间保持不变(使用 `git cherry-pick` 会修改提交时间为当前时间)；
- 如果 `cherry-pick` 时没有冲突或其他错误则自动提交，否则会跳过该 Commit，并最终给出 `cherry-pick` 失败的清单及原因；
- 支持通过 `GIT_PICK_IGNORE` 环境变量或者 `--ignore-file` 参数指定忽略某些 Commit 进行批量 `cherry-pick` 操作；
- 支持通过提交信息关键字搜索或者 **SHA** 值精确匹配 Commit 进行批量 `cherry-pick` 操作；
- 可以只列出匹配到的 Commit 列表以供查看，而不执行 `cherry-pick` 操作；

**命令格式**: `git-pick {flags} <match>`

**参数说明**:

- `-v`, `--verbose` - 显示更多信息
- `-l`, `--list-only` - 只显示匹配到的 Commit 列表，不执行 `cherry-pick` 操作
- `-f`, `--from <String>` - 待**Pick**的源分支，默认为当前分支
- `-t`, `--to <String>` - 待**Pick**到的目标分支，默认为当前分支
- `-s`, `--since <String>` - 待筛选的 Commits 的起始时间, 比如：2024/03/12 or 2024-03-12
- `-u`, `--until <string>` - 待筛选的 Commits 的截止时间, 比如：2025/03/12 or 2025-03-12
- `-i`, `--ignore-file <String>` - 通过该文件指定忽略某些 Commit 进行批量 `cherry-pick` 操作，文件为 TOML 格式，内容示例如下：
  ```toml
  GIT_PICK_IGNORE = [
    # 待忽略的 Commit SHA 值
    "ff987867",
    # 或者待忽略的 Commit Message，精确匹配
    "feat-0330: Rename t-service to service as the new module name"
  ]
  ```
- `-h`, `--help` - 显示帮助信息
- `match <string>`: 可以为精确的**Commit SHA**值，多个值用`,`分隔，也可以为待搜索的关键字，该关键字会从 Commit Message 里面搜索匹配

**使用举例**:

```bash
# 批量 cherry-pick 指定SHA值对应的 commit 到当前分支
t git-pick d3d9e66e7,1d70d99b
# 从 develop 上将所有属于 0330 迭代的 commit 批量 cherry-pick 到 release/2.5.24.0330 分支
t git-pick 0330 -f develop -t release/2.5.24.0330
# 对于上述操作只列出匹配到的 Commit 列表，不执行 cherry-pick 操作
t git-pick 0330 -f develop -t release/2.5.24.0330 --list-only
# 将 release/2.5.24.0330 分支上的包含 0330 关键字的 commit 批量 cherry-pick 到当前分支
t git-pick 0330 -f release/2.5.24.0330
```

---

### 24. 从命令行执行 Erda 流水线{#run-pipeline}

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

   该步骤只需要团队里面的某一位同学配置下即可，需要修改 `i` 分支(关于 `i` 分支[前面](#git-desc)已经有所说明)上的 `.termixrc` 配置, 在该 **toml** 文件的**前面**添加类似如下配置：

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

:::info
其它说明：

1. 以上配置中 `env` 的可能值只能为 `DEV`, `TEST`, `STAGING`, `PROD` 中的一个，这个参数是查询流水线执行记录不可缺少的;
2. 在上述配置文件中还可以添加可选的 `description` 字段，用于描述该流水线是干什么的，这个描述在 `dp -l` 的时候会显示出来;
3. 如果你在一个环境中有两个分支，这两个分支除了名字外其他配置都一样，在执行流水线的时候可能一条命令同时触发了这两条流水线，如果你只想执行其中一条流水线可以设置不同的 `alias` 来达到目的；
4. erda.[test|dev|staging|prod] 只是示例，实际上这个字段名不重要你可以随便命名比如: `erda.xyz`, 只需要保证其值里面的数组元素结构符合要求即可；
5. 在某些情况下，比如给客户演示期间可以锁定发布，只需要在对应部署配置里面加上 `lock = true` 即可，此时还可以添加一个锁定说明比如: `lockTip = '今天下午给客户演示，期间禁止发布预发环境'`，不过需要说明的是这个锁定功能只有在通过 `termix-nu` CLI 进行部署的时候才生效, 如果通过浏览器部署则不受此控制；

:::

**命令格式**:

- 单应用：`deploy dest=('dev')`;
- 多应用：`deploy dest=('dev') --apps nusi,docs`;

**参数说明**:

- `dest`: 选填，待执行的目标流水线，默认值为 `dev`，对于上述**步骤 2**的 **toml** 配置 `erda` 下面有两个 Key：`dev` & `test`, 所以 `dest` 的取值也只能是这两个(可以通过 `t dp -l` 查询所有可能的部署目标);
- `-i` 或 `--interactive`: 以交互式模式选择部署目标，支持模糊匹配
- `-m` 或 `--multiple`: 交互式模式下允许选择多个应用
- `--force` 或者 `-f` 参数跳过检查步骤，强制部署应用
- `--list` 或者 `-l` 列出所有可能的部署目标及应用信息
- `--watch` 或者 `-w` - 执行流水线时持续轮询并显示该流水线各个 Stage 的详细执行信息
- `--grep <String>` 或 `-g` 仅在与 `-l` 一起使用时生效，从部署配置里面搜索 name, alias 或 description 字段里包含特定字符串的部署目标
- `--stop-by-id` 或 `-s` 根据流水线 ID 终止对应的正在运行的流水线
- `--apps` 或者 `-a` 指定需要批量部署的应用，多个应用以","分隔，在多应用模式下必须指定(`-a all`或者`--apps all`代表选择指定目标下的所有应用)，单应用模式忽略
- `--override` 或 `-o` 该参数的格式为 JS Object, 用于覆盖部署配置里面的同名配置项, 比如已有部署目标 `prod` 对应的部署分支是 `master`, 但是你需要部署 `hotfix/abc` 分支，由于这是个临时分支如果为部署这个分支去改配置还是比较麻烦的，此时可以通过 `t dp prod -o {branch: 'hotfix/abc'}` 来部署，表示除了分支不一样外其他的部署配置跟 `prod` 保持一致。该参数在 `sh/bash/fish/nushell` 下可以正常使用，但是 `zsh` 因为 `{}` 解析问题貌似不支持
- `--help` 或者 `-h` 查看帮助信息

**使用举例**:

```bash
# 触发默认的 `dev` 配置对应的流水线的创建和执行, 或者 `t dp` (dp 为 deploy 的别名)
t deploy
# 查询所有可能的部署目标
t dp -l
# 以交互方式选择多个部署目标进行批量部署
t dp -im
# 触发 `test` 配置对应的流水线的创建和执行
t deploy test
# 通过 dp 别名执行部署，并且强制部署测试环境
t dp test -f
# 部署测试环境时持续轮询并显示流水线执行结果
t dp test -w
# 部署测试环境所有应用
t dp test -a all
# 查找测试环境里面 appName 或者 alias 为 nusi 的应用并部署
t dp test -a nusi
# 以测试环境部署配置为基础进行部署，并在部署时将分支覆写为 release/2.5.24.0330
t dp test -o {branch: 'release/2.5.24.0330'}
```

#### 从 CLI 运行流水线演示{#run-pipeline-cast}

<AsciiPlayer cast="/casts/erda-dp.cast" poster="npt:0:39" />

---

### 25. 从命令行查询 Erda 流水线的执行情况{#query-pipeline}

**功能描述**:

对于通过上述 `deploy` 命令执行的流水线会在输出里面告诉你当前触发执行的流水线的 ID，比如上图中的 **988218150879331**，此时可以通过 `deploy-query` 命令来查询流水线的执行情况。

执行查询命令时如果不指定流水线 ID 则查询指定目标的最近 **10** 条部署记录并以表格形式显示, 在多应用查询模式下必须通过 `--apps` 或 `-a` 参数指定要查询的应用，多个应用之间用英文逗号分隔，输入的应用名会在配置里面的 `appName` 和 `alias` 里面进行精确匹配。

**命令格式**:

- 根据 ID 查询单条部署记录：`deploy-query [id]`;
- 单应用查询最近 10 条部署记录：`deploy-query test`;
- 多应用查询最近 10 条部署记录：`deploy-query test -a all`;

**参数说明**:

- `id`: 选填，待查询的目标流水线对应的 ID，比如上图中的 **988218150879331**; 如果不填则查询默认目标的最近**10**条部署记录
- `--watch` 或者 `-w` 持续轮询并显示指定流水线各个 Stage 的执行信息，轮询间隔 2秒
- `--apps` 或者 `-a` 指定需要批量查询的应用，多个应用以","分隔，在多应用模式下必须指定(`-a all`或者`--apps all`代表查询指定目标下的所有应用)，单应用模式忽略
- `--override` 或 `-o` 该参数的格式为 JS Object, 用于覆盖部署配置里面的同名配置项, 比如已有部署目标 `prod` 对应的部署分支是 `master`, 但是你需要查询 `hotfix/abc` 分支的部署记录，由于这是个临时分支如果为查询这个分支的部署记录去改配置还是比较麻烦的，此时可以通过 `t dq prod -o {branch: 'hotfix/abc'}` 来查询，表示除了分支不一样外其他的查询配置跟 `prod` 保持一致。该参数在 `sh/bash/fish/nushell` 下可以正常使用，但是 `zsh` 因为 `{}` 解析问题貌似不支持
- `--help` 或者 `-h` 查看帮助信息

**使用举例**:

```bash
# 根据流水线 ID 查询其执行情况, 或者 `t dq` (dq 为 deploy-query 的别名)
t deploy-query 988218150879331
# 查询测试环境最近的10条部署记录
t dq test
# 多应用模式下查询开发环境所有应用的最近10条部署记录
t dq dev -a all
# 以测试环境部署配置为基础查询部署记录，并在查询时将分支覆写为 release/2.5.24.0330
t dq test -o {branch: 'release/2.5.24.0330'}
```

#### 从 CLI 查询流水线演示{#query-pipeline-cast}

<AsciiPlayer cast="/casts/erda-dq.cast" poster="npt:0:39" />

---

### 26. 在手机端执行或者查询 Erda 流水线{#erda-pipeline-in-mobile}

本功能并非 `termix-nu` 直接提供的，但使用的基础能力是基于 `termix-nu` 的，所以也放在这里顺便提一下。要想在手机端执行或者查询 Erda 流水线需要在手机上安装 GitHub App，借助其可以在手机端执行 Workflow 的能力达到目的。为了方便大家使用特封装了一个 Github Action: [`hustcer/erda-pipeline`](https://github.com/hustcer/erda-pipeline)，并附有配套的使用文档。大家可以参考文档配置试试，有问题随时反馈。

### 27. 钉钉机器人群发消息{#dingtalk-msg}

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

### 28. 在 Erda 流水线里通过钉钉机器人群发消息{#dingtalk-msg-in-erda}

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
  let notifyTip = $'DingTalk notification is (ansi r)disabled(ansi rst), to enable it (ansi g)set `DINGTALK_NOTIFY` to `on`(ansi rst) in pipeline environment. Bye~'
  if not $enableNotify { echo $notifyTip; exit 0 }
  if $type not-in ['text', 'link', 'markdown'] { echo $'(ansi r)Invalid message type. Bye~(ansi rst)'; exit 7 }

  check-envs
  let tokens = $env.DINGTALK_ROBOT_AK | str trim | split row ','
  let secrets = $env.DINGTALK_ROBOT_SECRET | str trim | split row ','
  if ($tokens | length) != ($secrets | length) {
    echo 'Invalid DINGTALK_ROBOT_AK or DINGTALK_ROBOT_SECRET config, length mismatch!'; exit 7
  }

  for tk in ($tokens | enumerate) {
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
  $env | get -o $key | default $default
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
  --at-all,                     # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
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
  let empties = ($envs | filter {|it| $env | get -o $it | is-empty })
  if ($empties | length) > 0 {
    print -e $'Please set (ansi r)($empties | str join ',')(ansi rst) in your environment first...'
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
          pnpm i nushell@0.89 -g
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

### 29. TERP 静态资源云端同步{#terp-assets-transfer}

**使用场景**:

在 `TERP` 项目实施过程中，不希望在项目环境里面通过源码部署前端 Portal、H5-Portal、Console 等应用，而是统一采用标品的制品镜像部署，以降低项目与 Portal、Console 的耦合程度，如此以来就需要项目侧的自定义组件静态资源统一走线上云存储然后通过网关转发，这在线上存储在公网的情况下很容易做到，直接通过流水线发布到云上即可。但是假如线上存储在企业私有网络的 Minio 里面就没法通过流水线直接将资源发布过去（VPN问题暂时没法解决）因此才有了本工具，其具有如下作用：

- 允许操作者在本机连接 VPN，然后通过该脚本把项目需要的静态资源从某个公网云存储地址上下载下来，然后上传到项目私有化部署的 Minio 存储上。
- 允许操作者在本机连接 VPN，然后通过该脚本把 Minio 预发环境经过测试验证的静态资源”同步“到 Minio 生产环境地址，以配合完成通过制品部署生产环境的目的。
- 也允许比如 EMP 等产品在不用自己发布 `material-ui` 和 `terp-ui` 的情况下将二者的静态资源构建产物从标品发布地址同步到 EMP 环境里面，加上 EMP 自己开发的特有自定义组件满足其个性化搭建需求。

**命令格式**: `terp-assets {flags} <action> <modules>`

其中 `action` 目前支持 `init`, `detect`, `download`, `transfer` & `revert`:

- 资源摘要查看：`terp-assets detect --from <from>`
- 资源下载：`terp-assets download <modules> --from <from> --to <to>`
- 低修改频率公共静态资源初始化：`terp-assets init --dest-store <store>` （支持 Aliyun OSS 和 minio）有些静态资源比如 PDF 和富文本字体，XSLX & PDF 文件解析类库，函数编辑器依赖的 `monaco-editor` 等这些资源体积比较大而且基本不会修改，所以适合在应用部署的时候直接初始化传输过去，然后配置网关转发即可，没有必要走打包或每次发布都要同步一次的流程以节省时间。而且这个静态资源的初始化是 Bucket 级别的，跟环境无关，每个 Bucket 里面初始化一份然后配置好网关转发就可以了，所以初始化参数里面只有 `--dest-store` 或者 `-d`。初始化成功后在对应 Bucket 的 **terp-assets** 目录下可以找到对应的静态资源；
- 资源同步：`terp-assets transfer <modules> --from <from> --to <to> --dest-store <store>`，资源同步时会先下载然后再上传，实际同步操作的时候不需要单独执行下载操作。资源上传需要在本机安装 `@terminus/t-package-tools`, 执行 `npm i -g @terminus/t-package-tools@latest --registry https://registry.npm.terminus.io` 即可(Node.js 建议 v20 或者以上版本)，版本不低于 `0.5.5`;
- 资源回滚：`terp-assets revert <modules> --to <to> --dest-store <store>`, TERP 静态资源回滚，每次只能针对单个模块进行操作，不支持多个模块批量回滚。另外在进行回滚操作的过程中需要选择回滚的静态资源版本所以需要依赖 `fzf` 工具。BTW, 回滚操作会留痕，会记录下执行回滚操作的人、时间及模块等信息，方便排查问题。

**命令别名**: `terp-assets` 的别名为 `ta`

**参数说明**:

- `<modules>` - 待下载或者同步的前端模块
  1. 目前的可能值为：`terp`, `terp-mobile`, `service`, `service-mobile`, `base`, `base-mobile`, `dors`, `dors-mobile`, `iam`, `all`, 分别代表TERP自定义组件的PC和移动端、通用自定义组件的PC和移动端、Material-UI的PC和移动端，Dors, IAM 以及所有模块静态资源。也可以同时指定多个前端模块并用 `,` 分隔。
  2. 对于不在上述列表里面的模块，可以使用 `latest.json` 里面的完整模块名，比如 `b2b`, `emp`等。
  3. 当传入模块为 `all` 时会自动下载或者同步 `latest.json` 里面的所有模块，最终目标和源的静态资源应该是完全一致的。
  4. 如果你不记得模块名也可以不传，此时会自动出现前端静态资源模块选择界面，可以手工选择模块并进行同步或者下载。在这个交互中可以使用的快捷键: `Space` 选择某一项，`a` 选择所有或取消全部选择，`q` 或 `ESC` 取消并退出，上下箭头切换模块, `Enter` 确认选择；
- `-f, --from <String>` - 资源的源挂载目录或者源 `latest.json` 完整 URL 地址，`from` 的 host 为 `https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com` 时可以只指定资源挂载的目录，否则需要 `latest.json` 的完整 URL 地址。对于 `detect` 操作的 `--from` 可以指定多个源，多个源之间用 `,` 分隔；
- `-t, --to <String>` - 对于 `download` 代表资源下载保存的本机路径，对于 `transfer` 代表资源上传到云存储后的目标挂载目录
- `-q`, `--quiet` - 不显示资源下载明细信息
- `-d, --dest-store <String>` - 对于 `transfer` 命令必须在 `.termixrc` 里面配置对应云存储的秘钥等信息
- `-h, --help` - 显示本帮助信息

**云存储配置**:

Note: 参考 `termix-nu` 根目录下的 `.termixrc-example` 文件，可以将其拷贝到 `.termixrc` 然后修改其中的配置比如:

```toml
# Minio 配置, 后面几个配置项的 `minio` 前缀即为 `transfer` 操作 `--dest-store` 参数的候选值
minio.TYPE = 'minio'       # MinIO 的 TYPE 值一定不要配错，否则会资源导致上传失败
minio.OSS_AK = 'YOUR-MINIO-AK'
minio.OSS_SK = 'YOUR-MINIO-SK'
minio.OSS_BUCKET = 'YOUR-BUCKET-NAME'
minio.OSS_REGION = 'oss-cn-hangzhou'
minio.OSS_ENDPOINT = 'https://oss-cn-hangzhou.aliyuncs.com'
```

**使用举例**:

```bash
# 将 terp-assets 公共静态资源同步到上面配置的 minio 存储里面
t ta init --dest-store minio
# 从 OSS 上 dev 目录（即 https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json）
# 下载所有 TERP 依赖的静态资源到本地，注：实际资源同步的过程中是不需要单独执行该命令的，只需要执行后面的两条命令之一即可
t ta download all -f dev
# 查看 terp-dev 这个资源挂载点上的静态资源摘要信息
t ta detect -f terp-dev
# 当你从测试环境打制品部署预发环境时可以通过以下命令将测试环境的所有
# TERP 需要的静态资源下载下来然后上传到 `minio` 的 staging 目录
t ta transfer all --from test --to staging --dest-store minio -v
# 在预发环境验证通过后即可将预发环境经过验证的所有 TERP 依赖静态资源下载到本地然后上传到 minio 的 prod 目录
t ta transfer all --from http://minio.terp.terminus.com/terminus-trantor/fe-resources/staging/latest.json --to prod --dest-store minio -v
# 回滚 OSS 云存储里面 dev 挂载点上的 base 前端模块
t ta revert base -t dev -d oss
# 回滚 minio 云存储里面 dev 挂载点上的 base-mobile 前端模块
t ta revert base-mobile -t dev -d minio
```

资源同步完毕后记得修改网关配置以使线上的静态资源生效。

**演示视频**:

#### 同步指定前端模块演示{#sync-assets-cast}

<AsciiPlayer cast="/casts/ta-module.cast" poster="npt:0:26" />

#### 同步选中前端模块演示{#sync-selected-cast}

<AsciiPlayer cast="/casts/ta-selected.cast" poster="npt:0:35" />

---

### 30. TERP 元数据一站式极简同步工具{#meta-data-syncing}

目前 `TERP` 后端元数据同步的操作较为复杂：需要用 `Postman` 之类工具手工调一个接口，产生一个异步任务，等异步任务结束后拿到出参再调一个接口生成第二个异步任务，然后在第二个异步任务结束之后将其出参连同第一个异步任务的出参一起传给第三个手工调用的接口并等待该异步任务结束。整个操作连贯性较差：每个异步任务什么时候结束是未知的，导致操作者要么需要不断地去查询异步任务执行结果，要么就是任务结束很久才察觉，对操作者的精力牵扯也比较大，不够丝滑。针对这种操作复杂、频率较高的刚性需求很有必要对其进行优化，这正是本工具的初衷，其具有如下特点：

- 一站式同步：所有操作都可以在 CLI 里完成，不用切换到其他工具;
- 配置检查：在开始同步前会对配置文件和入参进行检查，确保没问题后才会执行(可能还有些分支场景未考虑周全，有问题及时反馈)；
- 支持自动登录(从 0330 版本开始要求登录后才能使用)，需要在配置文件里面配置好 Console 应用的用户名和密码 (此功能需要本机安装 `openSSL` 3.0.0 以上版本, 一般系统内置)；
- 操作简单：在配置得当的情况下只需一条命令即可，比如 `t msync -a`;
- 支持同步所有模块或者选择指定模块同步(指定模块同步功能以后可能会被废弃，详询元数据团队);
- 支持通过 `--tag` 参数在源项目中为元数据创建指定版本的制品（调用 BuildTagTask API），搭配 `--to` 可将元数据制品导入目标环境（SyncAllInOneTask），搭配 `--install --to` 则将元数据制品安装到目标环境（InstallAndUpgradeAppTask）；
- 支持通过 Cookie 进行认证：当目标环境未开启账密登录时，可在 `meta.settings` 或对应的 `source`/`destination` 配置中设置 `cookie` 字段来完成认证；
- 对于 Trantor 2.5.24.1130 及以后版本支持按目录导入元数据：在同步源配置里面加上 `path` 配置项即可，参考示例中 `meta.source.dir-import` 的配置；
- 同步所有模块时根据需要支持输入**安全码**(0330 版本后新特性), 同步指定模块时无需输入安全码；
- 所有需要确认或者选择的操作前置，如此以来就可以提前把各种准备工作做好，剩下的只需要喝喝茶等待工具执行完成就可以了；
- 元数据导入时支持配置文件里面的 `ddlAutoUpdate`, `resetModuleForInstall` 等参数透传（对于 0930 及以后版本不再支持 `resetModuleForInstall` 参数，若需安装为非原生模块请使用 `--install` 参数）；
- 同步任务本身仍然是 `Trantor` 的 **API** 完成的，本工具只是对这些接口进行 `TUI` 封装，结果跟原始的手工操作是一致的；
- 对于所有的异步任务工具会定时轮询(目前每秒一次)并更新状态和进度（然而并不是真实的百分比进度，本质上是一个以进度条形式显示的计时器，告诉你程序还没挂掉）;
- 分秒必争，所有的任务会无缝串行，同时会显示每条任务和所有任务总执行耗时；
- 除 `Nushell` 之外不依赖其他二进制文件或者 `Node` 模块(`Just` 只提供一个命令入口，没有 `Just`仍然可以正常工作);
- 后续会持续对接 `Trantor` 元数据团队，及时跟进最新的变化，确保工具一直可用；

**命令格式**: `msync *OPTIONS (modules)`

**参数说明**:

- `modules`: 可选，需要同步元数据的模块标识，多个模块之间用英文逗号分隔
- `-f`, `--from <String>` - 指定同步源名称，可以从配置文件的 `meta.source` Key 值中获取，不传则使用默认同步源
- `-t`, `--to <String>` - 指定同步目标名称，可以从配置文件的 `meta.destination` Key 值中获取，不传则使用默认同步目标
- `-a`, `--all` - 加上这个开关就表示同步所有模块，搭配 `--tag --to` 使用时表示全量导入所有模块（SyncAllInOneTask），无需进入交互式选择
- `-l`, `--list` - 列出所有的同步源和同步目标
- `-i`, `--install` - 安装或者升级标准模块的元数据到目标项目，支持 Trantor 2.5.24.0930 及以后版本，表示安装为非原生模块
- `-S`, `--snapshot` - 只创建并上传元数据的 SnapShot 不做导入元数据的操作
- `-T`, `--tag <String>` - 在源项目中为元数据创建指定版本的制品，例如 `20260212.1730`。搭配 `--to` 可将元数据制品导入目标环境（SyncAllInOneTask），搭配 `--all --to` 则全量导入所有模块无需交互式选择，搭配 `--install --to` 则将元数据制品安装到目标环境（InstallAndUpgradeAppTask），搭配 `modules` 位置参数指定导入或安装的模块，未指定模块且未使用 `--all` 时会进入交互式选择模式
- `-h`, `--help` - 查看帮助信息
- 如果在调用命令的时候没有传 `--all` 或 `modules` 参数会让你选择需要同步的模块, 如下图所示，在这个交互中可以使用的快捷键: `Tab` 选择某一项，`Ctrl+a` 选择所有, `Ctrl+d` 取消全部选择，`ESC` 取消并退出，上下箭头切换模块, `Enter` 确认选择, 也可以输入模块标识或名称进行过滤 & 模糊匹配；

![Select Modules To Import](https://fe-docs.app.terminus.io/img/select-modules.png)

**配置说明**:

为了简化命令执行，在使用本工具之前需要先修改配置文件，配置文件路径: `termix-nu/.termixrc`, 该文件为 `toml` 格式，有一个 `.termixrc-example` 文件可以作为参考，接下来详细解释具体配置：

```toml
# 通用配置，可以被源和目标中的同名配置覆盖
[meta.settings]
username = 'your-username'
password = 'your-password'
# 如果目标环境未开启账密登录，可以在此配置 cookie 进行认证，也可以在具体的 source/destination 中单独配置
# cookie = 't_iam_dev=eyJ0eXAiOiJKV1QiLCJh...'

# Meta data syncing source config
# 此处将定义一个名为 dev 的同步源，可以作为后续 --from 参数的入参，你可以定义多个同步源，名字自定
[meta.source.dev]
# 默认启用的同步源：如果你在使用同步工具的时候没有通过 --from 指定同步源则使用该同步源，故而默认源最多只能有一个
default = true
# 同步源 Team ID
teamId = 666
# 同步源 Team Code
teamCode = 'TERP'
# 用户名和密码此处如果配置了则会覆盖 meta.settings 中的配置，如果未配置则使用 meta.settings 中的配置
username = 'your-username'
password = 'your-password'
# 同步源 Console 地址，后面不要加 `/`
host = 'https://abc-console-dev.app.terminus.io'
# 此描述信息会在使用 --list Flag 时展示
description = '标品 TERP 开发环境'

[meta.source.dir-import]
teamId = 666
teamCode = 'TERP'
# 同步源 Console 地址，后面不要加 `/`
host = 'https://abc-console-dev.app.terminus.io'
# 按目录导入元数据，在该模式下只能选择一个模块
path = '通用管理/打印'
# 此描述信息会在使用 --list Flag时展示
description = 'Trantor TERP 开发环境按目录导入元数据'

# [meta.source.dev0]
# 若需配置更多同步源参考以上配置

# Meta data syncing destination config
# 此处将定义一个名为 test 的同步目标，可以作为后续 --to 参数的入参，你可以定义多个同步目标，名字自定
[meta.destination.test]
# 默认使用的同步目标：如果你在使用同步工具的时候没有通过 --to 指定同步目标则使用该同步目标，故而默认目标最多只能有一个
default = true
# 同步目标 Team ID
teamId = 666
# 同步目标 Team Code
teamCode = 'TERP'
# 导入元数据时的 ddlAutoUpdate 配置值, 默认为 true
ddlAutoUpdate = false
# 是否导入为非原生模块，默认为 false, false：导入为原生模块，可以修改；true：安装为非原生模块, 不能修改
# 这个参数只有在按模块导入时生效（即 resetModuleKeys 不为空）
# 注意：该参数在 0930 及以后版本不再支持，若需安装为非原生模块请使用 --install 参数
resetModuleForInstall = false
# 用户名和密码此处如果配置了则会覆盖 meta.settings 中的配置，如果未配置则使用 meta.settings 中的配置
username = 'your-username'
password = 'your-password'
# 同步目标 Console 地址，后面不要加 `/`
host = 'https://abc-console-test.app.terminus.io'
# 此描述信息会在使用 --list Flag 时展示
description = '标品 TERP 测试环境'

# [meta.destination.test0]
# 若需配置更多同步目标参考以上配置
```

**使用举例**:

```bash
# 从默认同步源同步到默认同步目标，由于没有使用--all 或位置参数指定模块在命令执行过程中会让你手工选择要同步的模块
t msync
# 从默认同步源同步到默认同步目标，导入所有模块
t msync -a
# 从默认同步源同步到默认同步目标，导入 HR_ATT,HR_PER,HR_REC 模块的元数据
t msync HR_ATT,HR_PER,HR_REC
# 可以通过 --from --to 参数分别指定同步的源和目标，建议始终同步所有模块，因为同步指定模块功能未来可能废弃
t msync -a --from dev0 --to test0
# 从 dev 源创建元数据 SnapShot 并上传到 OSS，不做元数据导入操作
t msync --snapshot --from dev
# 在默认源项目中为元数据创建指定版本的标签
t msync --tag '20260202.0935'
# 指定源项目创建元数据制品
t msync --tag '20260202.0935' --from dev
# 创建元数据制品并安装到目标环境，未指定模块时会进入交互式选择模式（InstallAndUpgradeAppTask）
t msync --from terp-saas --tag 20260212.1730 --install --to sanlux-dev
# 创建制品并将指定模块安装到目标环境（InstallAndUpgradeAppTask）
t msync SCM_DEL,ERP_FI,ERP_FIN --from terp-saas --tag 20260212.1730 --install --to sanlux-dev
# 创建制品并全量导入到目标环境（SyncAllInOneTask），会提示输入安全码
t msync --from sanlux-dev --tag 20260213.0930 --all --to sanlux-staging
# 创建制品并将指定模块导入到目标环境（SyncAllInOneTask）
t msync SCM_DEL,ERP_FI --from sanlux-dev --tag 20260213.0930 --to sanlux-staging
# 创建制品并交互式选择模块导入到目标环境（SyncAllInOneTask），未指定模块且未使用 --all 时进入 fzf 选择模式
t msync --from sanlux-dev --tag 20260213.0930 --to sanlux-staging
```

**演示视频**:

#### 同步所有模块元数据演示{#sync-meta-cast}

<AsciiPlayer cast="/casts/meta-sync-all.cast" poster="npt:0:39" />

#### 同步选中模块元数据演示{#sync-selected-meta-cast}

<AsciiPlayer cast="/casts/meta-sync-selected.cast" />

:::info

此元数据同步 **TUI** 工具本身的实现还是挺复杂的，但是 `Nushell` 却可以轻松驾驭，甚至不需要依赖 `curl`, `jq` 等二进制文件，这是 `Bash` 所无法做到的，也充分证明了其解决复杂问题的表现力。开发 **TUI** 类 **CLI** 工具是 `Nushell` 的典型使用场景之一，从这个角度来看 `Nushell` 相当于 `TS + HTML + CSS`, 因为其自身具备逻辑实现(而且`Nushell`也是可以有类型的)、UI结构渲染输出 & 简单的样式控制能力。所以这种脚本语言完全值得你去花时间学习下。

:::

---

### 31. ERDA 制品部署助手{#erda-artifacts}

**功能描述**:

目前 Erda 对制品的构建、部署等一系列操作已经相当友好了，操作起来也比较简单，尤其是基本的选择制品创建部署单并部署，鼠标点几下就可以了。但是制品生命周期中还涉及到其他一些操作，这些操作的执行人可能只限于小范围的几个人，而且有些操作是异步、离散的，考虑到在标品 & 项目中制品操作的重要性有必要将这些操作串起来并标准化。

该工具可以通过 **CLI** 完成制品(**Artifact**)生命周期中的各项基本操作：运行某个应用的制品构建流水线构建制品、构建完毕输出制品相关信息、从源项目里面下载构建的制品到本地、将下载的制品上传到 Erda 目标项目、将应用制品包装成项目制品(目前只支持高频的单应用制品转项目制品)、通过目标项目里面指定版本的制品或者选择某个版本的制品创建部署单、执行部署单部署制品、输出制品部署结果。工具内置四种操作五种模式, 如下图所示：

![Artifact Assistant](https://img.alicdn.com/imgextra/i4/O1CN01uQNDoY1Vgra6Zan75_!!6000000002683-0-tps-979-365.jpg)

- 生产者模式(`art produce`)：比如 `Trantor` 团队可以通过该模式运行某个应用的制品构建流水线构建制品，并在构建完毕后输出制品相关信息，最后再把这个输出信息对外发布;
- 消费者模式(`art consume`): 比如 `TERP` 团队可以根据上游 `Trantor` 团队给出的制品信息(主要是制品版本号)将 `Trantor` 构建完成的制品下载到本地，然后再上传到 `TERP` 项目里面，并通过该制品创建指定环境(开发/测试/预发/生产)的部署单，然后执行部署并输出部署结果（也可以只创建部署单但是并不部署）, 所有这些操作一条命令即可完成；`consume` 的制品可是项目制品也可以是单一应用制品，如果是单一应用制品则会自动将其包装成项目制品，然后再执行剩下的操作；从 Trantor 2.5.25.0130 开始 Trantor 制品输出格式发生变化，需要用官方提供的脚本进行部署，本工具也对接了官方的脚本方便大家使用，直接使用 `t art consume -e dev -t terp` 就可以在 CLI 里面选择 Trantor 制品并部署到 TERP 开发环境。
- 普通部署模式(`art deploy`)：这种模式应该是最常用的模式，允许你通过指定版本号的制品部署目标项目的指定环境，当然如果你不记得准确的版本号也可以搜索 & 选择一个版本然后部署, 在制品选择模式下随着选择版本的变化也会在预览窗口给出当前选中版本的基本信息：制品所在项目、创建人、创建时间、所包含的部署应用组，甚至 **CHANGELOG**。选择制品后你可以以预先指定的应用组部署，也可以选择部署应用组(若要选择多个应用组可以使用 [`Tab` 键进行多选](https://junegunn.github.io/fzf/reference/#-m---multi)), 同样道理在选择应用组过程中也会显示该应用组所包含的各个应用的部署前置检查信息：比如是否有权限等；
- 联合部署模式(`art deploy --combine`)：这种模式就是上述 `生产者模式` + `消费者模式` 的联合, 在此用一条命令把上述两种模式所包含的一系列操作串起来了，佛燃项目的发布过程基本按照这种模式执行的：佛燃发布时会通过一条流水线构建 TERP 各应用的制品，然后把这个制品下载并上传到另一个私有化部署的 Erda 项目里面，然后通过该制品创建部署单并部署对应的环境；
- 单应用制品转项目制品(`art pack`): 目前只支持比较高频的场景 —— 将单个应用制品转换为项目制品，要求应用制品和目标项目制品在同一个 Erda 项目，项目制品的版本从应用制品版本计算而来并确保不超过 30 个字符(Erda的限制)。对于其他场景可在 Erda 上按原流程操作。

**命令格式**: `t art <action> {flags}` (其中 `action` 为 `deploy`, `produce`, `consume` 或 `pack` 中的一个)

**参数说明**:

- `-l`, `--list` - 显示所有可用的源和目标配置信息
- `-c`, `--combine` - `deploy` Action下有效，包含制品构建、下载、上传、创建部署单、部署等一系列操作
- `-n`, `--no-deploy` - `deploy`/`consume` Action下有效, 只创建制品部署单，但是并不执行部署操作
- `-f`, `--from <String>` - `deploy`/`consume`/`produce`/`pack` Action均可能使用此参数，用于指定源项目以及制品构建应用对应的配置别名
- `-t`, `--to <String>` - `deploy`/`consume` Action下有效，用于指定制品部署目标项目对应的配置别名
- `-i`, `--doid <String>` - `deploy` Action下有效，用于通过指定的部署单 ID 部署制品
- `-b`, `--branch <String>` - `produce` Action下有效，用于指定构建制品的分支名
- `-v`, `--version <String>` - `deploy`/`consume`/`pack` Action下有效, 用于指定需要部署或者消费的项目制品完整版本号，对于 `pack` 操作，该值为应用制品的完整版本号
- `-e`, `--dest-env <String>` - `deploy`/`consume` Action下有效, 用于指定需要部署的目标环境比如：DEV,TEST,STAGING,PROD, 不区分大小写
- `-g`, `--deploy-group <String>` - 待部署的制品应用组, 默认为 `All`
- `-h`, `--help` - 显示命令相关帮助信息

**配置说明**:

为了简化命令执行，在使用本工具之前需要先修改配置文件，配置文件路径: `termix-nu/.termixrc`, 该文件为 `toml` 格式，有一个 `.termixrc-example` 文件可以作为参考，接下来详细解释具体配置：

```toml
# -------------------------- Artifact Related Config Begin --------------------------
[artifact.settings]                 # 一些公共的配置信息，如果 source/destination 里面有同名的配置会将其覆盖
orgId = 2                           # 可以被源和目标中的同名配置覆盖, 默认值为 2
orgAlias = 'terminus'               # 可以被源和目标中的同名配置覆盖, 默认值为 terminus
username = '19999999999'            # 可以被源和目标中的同名配置覆盖，默认值为 .env 配置文件里面的 ERDA_USERNAME
password = 'Your-Password.'         # 可以被源和目标中的同名配置覆盖，默认值为 .env 配置文件里面的 ERDA_PASSWORD
erdaHost = 'https://erda.cloud'     # 可以被源和目标中的同名配置覆盖，默认值为 https://erda.cloud

[artifact.source.trantor]           # `trantor` 为源配置别名，也是 `--from` 参数可传的入参
default = true                      # 是否默认使用的源，默认源最多只能有一个，如果执行命令的时候没有 `--from` 参数则使用该默认源
projectId = 190                     # 用于构建制品的应用或下载制品所在 Project ID
projectName = 'Trantor2'            # 用于构建的应用或下载制品所在 Project 名称,建议填写方便识别
appId = 10384                       # 用于构建制品的 App ID
appName = 'Trantor2-Release'        # 用于构建制品的 App 名称
env = 'TEST'                        # 构建制品的环境比如：DEV, TEST, STAGING, PROD
branch = 'release/2.5.24.0130'                      # 用于构建制品的分支, 可以被 --branch 参数覆盖
artifactNode = 'trantor2-artifacts'                 # 输出制品 releaseID & version 信息的节点名称
pipeline = '.erda/pipelines/combine-artifact.yml'   # 用于构建制品的 Pipeline 文件路径

[artifact.destination.terp]         # `terp` 为目标配置别名，也是 `--to` 参数可传的入参
default = true                      # 是否默认的部署目标，默认目标最多只能有一个，如果执行命令的时候没有 `--to` 参数则使用该默认目标
projectId = 1158                    # 用于部署制品的应用或者上传制品所在的 Project ID
projectName = 'TERP'                # 用于部署制品的应用或者上传制品所在的 Project 名称,建议填写方便识别
deployGroup = 'All'                 # 部署应用集合，All: 部署所有应用, 或者指定其他部署应用集合名称,多个应用组用`,`分隔，如果有任意一个不匹配则停下来让用户选择
username = 'terminus'               # 部署目标所在 Erda 平台的用户名, 未填则使用 artifact.settings 中的默认值
password = 'terminus'               # 部署目标所在 Erda 平台的密码, 未填则使用 artifact.settings 中的默认值
erdaHost = 'https://erda.cloud'     # 部署目标所在 Erda 平台的 Host，未填则使用 artifact.settings 中的默认值

# 跨组织部署制品
[artifact.destination.sanlux]
orgId = 1000029                     # 可以被源和目标中的同名配置覆盖, 默认值为 2
orgAlias = 'sanlux'                 # 可以被源和目标中的同名配置覆盖, 默认值为 terminus
projectId = 1000171                 # 用于部署制品的应用或者上传制品所在 Project ID
projectName = 'Sanlux'              # 用于部署制品的应用或者上传制品所在 Project 名称,建议填写方便识别
deployGroup = 'select'              # 部署应用集合，All: 部署所有应用, 或者指定其他部署应用集合名称
# --------------------------- Artifact Related Config End ---------------------------
```

*跨组织部署制品补充说明*：

跨组织部署制品时最关键的是找到目标项目的 `orgId` & `orgAlias`(如上例所示)，其中 `orgAlias` 可以从浏览器 URL 里面获得，比如对于三力士项目的 URL: `https://erda.cloud/sanlux/dop/projects/1000171` 其中 `erda.cloud/` 后面的 `sanlux` 就是 `orgAlias`。`orgId` 需要从浏览器请求中获取: 打开浏览器网络请求面板，刷新页面，可以看到一个获取项目详细信息的调用，比如: https://erda.cloud/api/sanlux/projects/1000171, 这个接口里面返回的数据有 `orgId` 字段正是我们需要的值。

**使用举例**:

```bash
# 用指定版本的制品部署默认目标的开发环境
t art deploy -e dev -v 2.5.24.0130+20240313165219
# 未指定版本则通过版本选择器选择版本然后使用该版本的制品部署 terp 目标的开发环境, 部署时选择的应用组为 Dors & IAM
t art deploy -e dev -t terp -g Dors,IAM
# 通过选择制品版本在 terp 目标的开发环境创建部署单, 并输出部署单ID，但是并不执行部署操作
t art deploy -e dev -t terp -n
# 通过上述命令输出的部署单ID执行部署单
t art deploy -i 1b39da9d-9a7b-4122-9369-7e51a35eab8f
# 从 trantor 项目里面的制品构建应用的 release/2.5.24.0228 分支构建制品，并在构建完毕后输出制品信息
t art produce --from trantor -b release/2.5.24.0228
# 从默认源所在项目里下载版本号为 2.5.24.0130+20240313165219 的制品，并将该制品上传到 terp 项目里面，然后通过该制品部署 terp 的开发环境
t art consume -e dev -v 2.5.24.0130+20240313165219 -t terp
# 将默认源所在项目里面的指定版本的应用制品包装为项目制品，并下载、上传到 Terp 项目里面，然后部署到 Terp 的预发环境
t art consume -v Portal-2.5.24.0630-9c9e732+240912.110027 -e staging -t terp
# 从 Trantor 2.5.25.0130 开始在 CLI 里面选择 Trantor 制品并部署到 TERP 开发环境
t art consume -e dev -t terp
# 将默认源所在项目里面指定版本的应用制品包装为项目制品，并输出转换后的项目制品信息，如版本、releaseID等
t art pack -v Console-fe-2.5.24.0228-f785ce9+240504.214042
# 将 trantor 项目里面指定版本的应用制品包装为项目制品，并输出转换后的项目制品信息
t art pack -f trantor -v Portal-2.5.24.0330-9da3f82+240430.114744
# 从 terp-runtime 这个应用的 release/millgrid-uat 分支创建应用制品，再将该应用制品包装为
# 项目制品，并将其下载到本机、再上传到 millgrid 项目，最后从该项目制品部署 millgrid 预发环境
t art deploy --combine --from terp-runtime --branch release/millgrid-uat --to millgrid --dest-env staging
```

**演示视频**:

#### 制品制作演示{#produce-artifact-cast}

<AsciiPlayer cast="/casts/art-produce.cast" poster="npt:0:39" />

#### 制品部署演示{#deploy-artifact-cast}

<AsciiPlayer cast="/casts/art-deploy.cast" />

:::tip

1. 制品助手依赖二进制可执行文件 [fzf](https://github.com/junegunn/fzf)，使用前如果检测到未安装本工具会自动安装；
2. 对于私有化部署的 Erda 的支持目前尚未经过充分测试，使用过程中可能有问题，但是在 `https://erda.cloud` 上使用应该问题不大；

:::

---

### 32. Erda 应用批量迁移助手{#erda-transfer}

本工具可以一键式迁移多个 Erda 应用到另一个项目。迁移内容包括应用仓库的所有分支、Tag、项目成员、应用成员、流水线环境变量、运行时环境变量。而且该命令可以重复执行以用于增量同步。

**使用前提**：

1. 源项目和目标项目必须在 Terminus 组织下，目前也只支持这个组织
2. 需要有源项目和目标项目的管理员权限:
   - 操作者至少需要先有源项目里所选择应用的访问权限;
   - 操作者需要在目标项目里有创建应用的权限;

**功能描述**:

- 可以交互式选择要迁移的应用，支持多选、模糊搜索;
- 也可以通过 `--apps` 参数直接指定要迁移的应用名(小写), 多个应用间用 `,` 分隔;
- 前置检查操作者是否拥有所选择应用的访问权限，只有在拥有所有已选择应用的访问权限时才会进行后续操作;
- 在新项目里面批量创建新应用（如果应用不存在），而且新应用的名称、描述、应用类型等与源应用保持一致;
- 在新项目里添加成员，新增成员跟源项目的成员权限保持一致，如果之后修改了新项目里面的成员角色后续不会被覆盖，只增不改;
- 在新应用里面添加成员，新增成员跟源应用权限保持一致，如果之后修改了新应用里的成员角色后续不会被覆盖，只增不改;
- 新应用创建后操作者即为新应用所有者，不因其在源应用里的角色配置而改变;
- 同步新应用的流水线及运行时环境变量与源应用保持一致，后续增量同步不会覆盖新应用已有环境变量，只增不改;
- 加密的环境变量首次同步值会被替换为 '请修改该值并加密存储' 并以明文存储，迁移完毕需自行检查修改;
- 源项目或者源应用删除的成员或者环境变量在后续增量同步过程中如果目标项目/应用里面有不会被删掉，只增不减;
- 可以全量或增量同步 Git 代码仓库所有分支及 Tag;
- 可以全量或增量同步指定的 Git 分支，多个分支用 `,` 分隔(分支同步采用强推策略，会强制覆盖目标仓库的同名分支)；
- 几乎所有操作都是直接调用 Erda 提供的 API 完成的，所以需要在 `.env` 里面配置 `ERDA_USERNAME` & `ERDA_PASSWORD`;

**分支同步注意事项**:

当同步指定分支时，作为最佳实践如果要在迁移后的分支上修改建议拉新分支修改（定制开发），这样后续再次同步的时候可以把新的改动 `cherry-pick` 到定开分支上，保持延续性，如果直接在迁移分支上改除非后面不需要再次同步，否则重新同步会强制覆盖同名分支的改动，造成代码丢失 ！！！

**命令格式**: `t erda-transfer *OPTIONS`

**参数说明**:

- `-f`, `--from <int>`: ERDA 源项目 ID
- `-t`, `--to <int>`: ERDA 目标项目 ID
- `-a`, `--apps <string>`: 指定要迁移的应用名，多个应用之间用英文逗号分隔，未指定该参数则进入交互式选择应用界面
- `-m`, `--sync-member`: 同步项目成员和应用成员
- `-b`, `--branches <string>`: 指定要同步的分支，多个分支之间用英文逗号分隔：e.g. main,develop
- `-h`, `--help`: 显示该命令的帮助文档

**使用举例**:

```bash
# 将 Terminus 组织下编号为 213 的项目里面的 termix-nu,nusi-slim 应用迁移到编号为 1000226 的项目
# 迁移内容包括应用仓库所有分支、Tags、项目成员、应用成员、环境变量。该命令可以重复执行用于增量同步
t erda-transfer --from 213 --to 1000226 --sync-member --apps termix-nu,nusi-slim

# 选择 Terminus 组织下编号为 213 的项目里面的应用，并批量迁移到编号为 1000226 的项目
# 迁移内容同上，需拥有源项目所选择应用的访问权限
t erda-transfer --from 213 --to 1000226 --sync-member

# 仅同步指定分支（例如 main 与 develop），而非所有分支与 Tags，可以重复执行用于增量同步
t erda-transfer --from 213 --to 1000226 --apps termix-nu -b main,develop
```

**演示视频**:

#### Erda 应用批量迁移演示{#app-transfer-cast}

<AsciiPlayer cast="/casts/erda-transfer.cast" poster="npt:0:06" />

---

### 33. 本地代码仓库 AI Code Review{#ai-code-review}

**功能描述**: 利用 **DeepSeek** 大模型对本地代码仓库进行 **Code Review**，具有如下特性：

- 开箱即用：可以不用配置就直接使用，也可以按需配置；
- 支持 **DeepSeek** `V3` & `R1` 模型；
- 除了支持官方 API 以外，还支持[SiliconFlow](https://cloud.siliconflow.cn/i/rqCdIxzS)、OpenRouter、Infinigence等服务商提供的 **DeepSeek** 服务；
- 支持通过本地 Ollama 启动的 **DeepSeek** 模型；
- 支持流式输出，也支持将代码审查结果输出到 Markdown 文件，生成代码审查报告；
- 支持设定代码审查允许的最大长度，超过长度则跳过审查，节省 **Token**；
- 支持审查任何本地仓库的指定提交变更，或者审查指定文件；
- 允许通过自定义 `git show`/`git diff` 命令生成变更记录并进行审查；
- 允许配置代码审查时排除特定文件或只包含指定文件；
- 允许配置默认选择模型、**Temperature**、Base URL 和提示词；

**命令格式**: `t cr *OPTIONS`

**参数说明**:

- `-d`, `--debug`: 调试模式
- `-o`, `--output <string>`: 代码审查结果输出文件路径
- `-p`, `--paths <string>`: 待审查文件路径，多个文件用`,`分隔，支持 Glob 模式
- `-f`, `--diff-from <string>`: 待审查的 Git diff 起始提交 SHA
- `-t`, `--diff-to <string>`: 待审查的 Git diff 终止提交 SHA
- `-c`, `--patch-cmd <string>`: 用于生成待审查差异内容的自定义 `git show` 或 `git diff` 命令
- `-l`, `--max-length <int>`: 审查内容的允许最大长度（0 表示无限制），默认值 50000
- `-m`, `--model <string>`: ​模型名称, 或者从 CHAT_MODEL 环境变量读取, 默认 `deepseek-chat`
- `-b`, `--base-url <string>`: ​DeepSeek API 基础 URL（默认读取 BASE_URL 环境变量）
- `-U`, `--chat-url <string>`: DeepSeek 模型聊天接口完整 URL, 如: `http://localhost:11535/api/chat`
- `-s`, `--sys-prompt <string>`: 系统提示词（默认读取 SYSTEM_PROMPT 环境变量）
- `-u`, `--user-prompt <string>`: 用户提示词, 默认为 `$DEFAULT_OPTIONS.USER_PROMPT`,
- `-i`, `--include <string>`: ​包含的文件模式（逗号分隔）
- `-x`, `--exclude <string>`: ​排除的文件模式（逗号分隔）
- `-T`, `--temperature <float>`: ​模型随机性参数（范围 0-2，默认 0.3）
- `-h`, `--help`: 显示帮助文档

**配置说明**:

为了方便大家使用，工具已经预设了一些默认配置，所以大家可以不用配置就直接使用，不过仍然保留了个性化配置的可能性，方便大家根据个人情况进行调整，目前预置的接口调用 **Token** 是公司提供的，不过也有很多免费的 **DeepSeek** 服务，比如 **SiliconFlow** [注册](https://cloud.siliconflow.cn/i/rqCdIxzS) 就**免费赠送 2000 万 Token**。完整的示例配置文件如下:

```toml
# DeepSeek 本地代码审查配置说明
[cr.settings]
# 采用的模型提供商名称，你可以在后面定义多个模型提供商，然后在这里修改下名称即可轻松切换
provider = "Infinigence"
# 待审查内容的允许最大长度（0 表示无限制）, 默认值 50000
# 如果該值非 0，而且待审查内容超过这个长度则直接跳过审查，防止意外消耗过多 Token
# 注意：这里的长度是指 Unicode Width，而不是 Token 长度
max-length = 50000
# ​模型随机性参数（范围 0-2，默认 0.3），不建议超过 1.0
temperature = 0.3
# 输入给 DeepSeek API 进行代码审查的用户提示词名称
# 可以预定义多个用户提示词，然后在此通过名称进行切换
# 比如这个配置示例文件预定义了三组用户提示词: default,frontend,java
user-prompt = "default"
# 系统提示词，跟上面的用户提示词使用方式类似，不过官方不建议使用系统提示词
# 尽量使用用户提示词来完成代码审查
system-prompt = ""
# ​包含的待审查的文件模式，默认为空
# 该配置项不适用于通过 `--paths` 或者 `--patch-cmd` 参数进行审查
include-patterns = ""
# 待​排除的文件模式，默认值如下，可以在通过 diff 命令生成待审查内容时自动忽略一些文件的变更
# 该配置项不适用于通过 `--paths` 或者 `--patch-cmd` 参数进行审查
exclude-patterns = "pnpm-lock.yaml,package-lock.json,*.lock"

# 你可以在这里定义一系列的 DeepSeek 模型提供商并为其指定一个名称
# 然后通过修改上面 `cr.settings.provider` 的值来快速切换服务商
# 这是一个使用 Ollama 上运行的 DeepSeek 模型进行代码审查的配置示例
[[cr.providers]]
name = "ollama-local"
token = "empty"
chat-url = "http://localhost:11434/api/chat"
models = [
  { name = "deepseek-r1", alias = "r1", enabled = true, description = "DeepSeek R1 model running on Ollama" }
]

# DeepSeek 官方提供 API 配置示例
[[cr.providers]]
name = "DeepSeek"
token = "sk-*****"
base-url = "https://api.deepseek.com"
# 可以在此定义多个模型，但是 `enabled`的只能有一个，表示默认使用的模型
# 也可以通过 `-m alias` 在命令调用的时候指定模型，比如 `-m r1` 或者 `-m v3`
models = [
  { name = "deepseek-chat", alias = "v3", enabled = true, description = "DeepSeek V3 model" },
  { name = "deepseek-reasoner", alias = "r1", enabled = false, description = "DeepSeek R1 model" }
]

# SiliconFlow 提供的模型服务配置示例
[[cr.providers]]
name = "SiliconFlow"
token = "sk-******"
base-url = "https://api.siliconflow.cn/v1"
models = [
  { name = "deepseek-ai/DeepSeek-V3", alias = "v3", description = "SiliconFlow DeepSeek V3 model" },
  { name = "deepseek-ai/DeepSeek-R1", alias = "r1", enabled = true, description = "SiliconFlow DeepSeek R1 model" }
]

# 无问芯穹提供的模型服务配置示例
[[cr.providers]]
name = "Infinigence"
token = "sk-*****"
base-url = "https://cloud.infini-ai.com/maas/v1"
models = [
  { name = "deepseek-v3", alias = "v3", enabled = true, description = "Infinigence DeepSeek V3 model" },
  { name = "deepseek-r1", alias = "r1", description = "Infinigence DeepSeek R1 model" }
]

# OpenRouter 提供的模型服务配置示例
[[cr.providers]]
name = "OpenRouter"
token = "sk-or-v1-******"
base-url = "https://openrouter.ai/api/v1"
models = [
  { name = "deepseek/deepseek-chat-v3-0324:free", alias = "v3", enabled = true, description = "OpenRouter DeepSeek V3 model" },
  { name = "deepseek/deepseek-r1:free", alias = "r1", description = "OpenRouter DeepSeek R1 model" }
]

# 可以在此定义一系列的用户提示词或者系统提示词，并指定名称
# 然后通过修改 `cr.settings.user-prompt` 或 `cr.settings.system-prompt` 的值来切换提示词
[cr.prompts.user.default]
name = "default"
prompt = """
您是一名专业的代码审查助手和精通 Java/Spring Boot/React/ReactNative 的全栈开发专家，负责分析Git仓库中的代码变更。需识别潜在问题（如代码风格违规、逻辑错误、安全漏洞等）并提供改进建议。请以简洁的方式清晰列出问题与优化方案。并在最后给出整体代码质量
评分（1-5分），比如: `**整体质量：​** 评分（1-5）`。请审查以下代码变更并给出具体的性能优化或者改进建议,并以中文输出:
"""

[cr.prompts.system.default]
name = "default"
prompt = """
您是一名专业的代码审查助手，负责分析Git仓库中的代码变更。需识别潜在问题（如代码风格违规、逻辑错误、安全漏洞等）并提供改进建议。请以简洁的方式清晰列出问题与优化方案。并在最后给出整体代码质量评分（1-5分），比如: `**整体质量：​** 评分（1-5）`。
"""

[cr.prompts.user.frontend]
name = "frontend"
prompt = """
作为资深前端工程师，执行全面的代码审查，重点关注：
...
请审查以下代码变更并给出具体的性能优化或者改进建议,并以中文输出:
"""

[cr.prompts.user.java]
name = "java"
prompt = """
作为一名高级Java后端工程师，进行全面的代码审查，重点关注:
...
请审查以下代码变更并给出具体的性能优化或者改进建议,并以中文输出:
"""
```

**使用举例**:

```bash
# 对当前仓库 `git diff` 修改内容进行代码审查
t cr
# 对当前仓库 `git diff` 修改内容进行代码审查,且指定模型为 r1
t cr -m r1
# 对当前仓库 `git diff f536acc` 修改内容进行代码审查
t cr -f f536acc
# 对当前仓库的上一次提交内容进行代码审查
t cr -f head~1
# 对当前仓库指定文件进行代码审查
t cr -f utils/a.ts,utils/b.ts
# 对当前仓库 `git diff f536acc` 修改内容进行代码审查并将审查结果输出到 review.md
t cr --diff-from f536acc --output review.md
# 对当前仓库 `git diff f536acc 0dd0eb5` 修改内容进行代码审查
t cr -f f536acc -t 0dd0eb5
# 通过 --patch-cmd 参数对当前仓库变更内容进行审查
t cr --patch-cmd 'git diff head~3'
t cr -c 'git show head~3'
t cr -c 'git diff 2393375 71f5a31'
t cr -c 'git diff 2393375 71f5a31 nu/*'
t cr -c 'git diff 2393375 71f5a31 :!nu/*'
# 像 `t cr -c 'git show head~3; rm ./*'` 这样危险的命令将会被禁止
```

### 34. EMP 工时填报查询 & 钉钉强力提醒工具{#emp-query-super-notify}

**功能描述**: 该工具允许你通过 CLI 查看团队成员当前 EMP 工时填报情况, 并且可以通过钉钉群机器人@工时未填满的同学进行多次提醒，包你不会忘记。具有如下特性：

- 支持在 CLI 里面一键查询团队成员工时填报情况，而且可以同时查询多个团队的工时填报并在终端以表格形式展示；
- 支持通过钉钉群机器人@工时未填满的同学，进行提醒；
- 如果工时未填满的人数较多会自动转换为 `@所有人`，转换条件可以通过各团队内的 `atAllMinCount` 配置来指定，如果团队内所有人都没填满也自动会转换成 `@所有人`；
- 提供可以**每日重复执行**的提醒任务，该任务只有在周五、周六、周日、周一(查询上周)、月底才会对工时没填满的同学进行提醒；
- 如果当前时间是周一或者月底(**最后期限**)提醒会转为间隔提醒：比如每隔30分钟(轮询间隔可配置)查询并提醒没填满的同学填写工时(称之为强力提醒是因为你可以把间隔时间设定得很短，然后对未填满工时的同学进行轰炸式提醒)，如果都已填满则不再提醒；
- 支持将某一天设置为 **Last Day** 然后开启间隔提醒模式，并且可以通过环境变量配置提醒文案（针对特殊节假日前的提醒场景）；
- 支持从某一天后开始提醒，尤其是放长假情况下可以通过此配置使得长假期间不用提醒，节后第一个工作日再开启正常提醒模式；
- 每天的提醒文案可以自由配置，做到提醒每天不重样儿，降低提醒阅读疲劳；
- 允许跳过对某些团队工时的查询和提醒；
- 支持通过修改环境变量 `EMP_WORKING_HOURS_NOTIFY` 配置关闭所有提醒；

**命令格式**: `t emp *OPTIONS`

**参数说明**:

- `-s`, `--silent` - 不要打印工时查询结果(通常在定时任务中使用，不显示结果，只启动必要的钉钉提醒)
- `-n`, `--notify` - 通过钉钉群机器人@工时没填满的同学提醒其填报工时
- `-p`, `--show-prev` - 查询前一周的工时填表情况，通常周一会有这个需求
- `-a`, `--show-all` - 显示所有团队成员工时填报情况，哪怕其已经填满了工时（但是提醒仍然只针对工时没填满的人）
- `-m`, `--month <Int>` - 按月份查询团队工时填报情况, 可以搭配 `--show-all` 参数一起使用
- `--keep-polling` - 持续轮询查询或提醒，直到团队所有成员都已经填满了工时
- `-h`, `--help` - 显示帮助文档

**配置说明**:

为了简化命令执行，在使用本工具之前需要先修改配置文件，配置文件路径: `termix-nu/.termixrc`, 该文件为 `toml` 格式，有一个 `.termixrc-example` 文件可以作为参考，接下来详细解释具体配置：

```toml
[emp.settings]
lastdayNotifyInterval = '30min'     # 周一 & 月底最后一天的提醒间隔, 格式：1sec, 1min, 1hr, 1day, 1wk, 默认 30min

[emp.settings.messages]   # 以下为各天的提醒文案，可以自己根据需要进行修改
friday = '终于到周五了，EMP 工时记得填下哦'
saturday = '周末了，本不想打扰您的，可是您的工时咋还没填完呢？'
sunday = '这周要结束了，您的工时还没填满呢，麻烦填下工时吧'
monday = 'OMG, 今天是可以补填上周工时的最后一天了，劳驾您填下工时吧，十万火急！'
monthEnd = '掐指一算今天是月底？麻烦填下工时吧, 过了今天就没救了！重要！紧急！'

[emp.teams.A]      # 此处的 `A` 可以随便定义，只要跟后面的不重复即可，没有特别意义
name = 'TERP前端'   # 终端查询的时候会显示标题: TERP前端本周工时填报
code = '000'       # EMP Project Code, 从 emp 查看部门工时的 worktime_GroupCountStaffWorkTimeSummaryFunc 接口参数中获取
alias = 'terp-fe'  # 需要对应配置 `TERP_FE_DINGTALK` 环境变量格式：`${DINGTALK_ROBOT_AK},${DINGTALK_ROBOT_SK}` 以使用钉钉群机器人提醒
ignore = false     # 设置为 `true` 的时候会忽略对该组的查询和钉钉提醒，也可以不填，默认值为 `false`
atAllMinCount = 3  # 如果工时未填满人数等于或超过该值则钉钉提醒时 @所有人, 该配置默认值为 30
users = [          # 群通知提醒的人员列表，真实用户名 + 手机号
    { name = '张三', mobile = '18000000000'},
    { name = '李四', mobile = '18000000000'},
    { name = '王五', mobile = '18000000000'},
  ]

[emp.teams.B]
# 其他配置参考上一个...
```

依赖的环境变量:

- `EMP_WORKING_HOURS_NOTIFY`: `on` | `off` 分别代表开启和关闭 `EMP` 钉钉机器人工时提醒通知, 默认值是 `off`;
- `*_DINGTALK`: 钉钉群机器人的 `AK` & `SK`, 格式：`${DINGTALK_ROBOT_AK},${DINGTALK_ROBOT_SK}`, 其中 `*` 部分用团队 `alias` 转大写并将`-`换成`_`后的值替换；
- `LAST_DAY`: `on` | `off` 分别代表开启和关闭特殊 **Last Day** 提醒，比如接下来要放春节长假了，而最后一个工作日并非周五、周六、周日、或月底，此时可以设置为 `on` 开启 **Last Day** 提醒；
- `LASTDAY_MSG`: 开启特殊 **Last Day** 提醒时的提醒文案；
- `SKIP_UNTIL`: 对于国庆、春节等长假放假期间你可能不希望有任何提醒干扰，可通过将此环境变量设置为节后第一个工作日时间，比如: `2024-02-18 08:00:00`, 这样从当前时间到设定时间之前就不会有工时提醒，一旦超过设定时间则会自动开始提醒；
- `WORKDAYS_TILL_MONTH_END`: 本周周初到月底有几个工作日，这个数据一般会自动计算，但是如果这期间有特殊假期计算就不准确，此时可以通过这个环境变量来修正月底工时计算误差；

**提醒定时任务**

如果 **TL** 每天手工去查询并提醒工时填报还是很不方便的（如果你不嫌麻烦的话这也是个办法），所以本工具添加了一个定时任务 `t emp-daily` 这个定时任务可以每天定时执行，比如设置 Crontab 为 `0 10 17 * * *` 每天下午 17:10:00 执行。该任务在周二、周三、周四什么都不会做除非是月底最后一天，在周五、周六、周日会发送钉钉提醒一次，在周一会查询上周工时填报情况并一直提醒工时未填满的同学直到其填满为止，在月底会查询当周工时并一直提醒工时未填满的同学直到其填满为止，提醒的时间间隔根据 `emp.settings.lastdayNotifyInterval` 的配置来定。

除了可以在本机或者服务器上执行该定时任务之外你还可以通过 `Erda` 的定时启动流水线来执行该任务，这个稍有难度，最重要的是要设置下任务的超时时间比如 `timeout: 28800`，确保该超时时间大于(24:00:00 - 定时任务启动时间)否则轮询查询工时并提醒的任务会因为超时被终止。

最简单的办法是找人帮忙代为提醒，因为本工具是支持多团队查询和提醒的，你需要提供的是 —— 团队的 EMP 编号、团队成员姓名&手机号以及钉钉群机器人的 `AK`/`SK`。

**使用举例**:

```bash
# 查看本周团队成员当前工时填报情况，只显示截止到当前未全部填报的成员
t emp
# 查看当前所有团队成员的工时填报情况，无论是否填满都显示
t emp -a
# 查看所有团队成员的前一周工时填报情况，无论是否填满都显示
t emp -a -p
```

:::caution
免责声明：

请勿过度依赖本工具，如其因为某些原因没有达到预期的效果本人可以尽力解决但是不会承担您的损失，还请见谅。

:::

---

### 35. 让 Homebrew 飞起来{#brew-speed-up}

**功能描述**: 由于众所周知的原因 `brew` 更新或者安装应用的时候会比较慢，本工具可以通过给 `brew` 设置国内镜像的方式来提速。具有如下特点：

- 这种设置对 `brew` 是无侵入的，只在运行时有效，运行结束后恢复原来状态；
- 无论你是使用 `bash`, `zsh`, `sh` 还是 `fish` 都有效（因为脚本是由 `nushell` 驱动的）；
- 使用简单: 只需要在你使用 `brew` 命令的时候在前面加个 `t ` 即可，比如 `t brew install ...`，且对 `brew` 命令的使用没有限制，不加 `t ` 则使用系统原本的 `brew`；
- 默认使用 `USTC`(中国科学技术大学)的镜像进行加速，经测试这个下载速度很快，不过你可以切换镜像，加上 `--tuna` 则会通过清华大学镜像加速；

**命令格式**: `t brew ...`

**参数说明**:

- `--tuna`: 通过清华大学镜像加速, 默认使用中科大镜像加速;

**使用举例**:

```bash
# 通过默认镜像加速安装 docker
t brew install docker
# 通过清华镜像加速安装 nushell
t brew install --tuna nushell
```

---

### 36. 查询各分支上某依赖的版本及提交信息{#query-deps}

**使用场景**:

一个前端仓库里面可能有一个或者多个 `package.json`, 其中又会有很多 `devDependencies` & `dependencies`，在日常的开发过程中通常又会有很多个分支，某个依赖模块在每个分支上是什么版本？该依赖又是谁在什么时候升级的？或者有个依赖的版本有问题，哪些分支引入了有问题的依赖版本？或者你需要在所有的分支上对某个依赖进行升级。在这些情况下知道各个分支上某个依赖的版本及其对应提交信息无疑是很有帮助的，而且本工具会搜索Git仓库里面所有的 `package.json` 文件, 并在结果中显示对应文件路径。

**命令格式**: `t query-deps {flags} <dep>`

**参数说明**:

- `-d`, `--dev` - 查询 `devDependencies` 里的依赖。如果不加该参数则查询 `dependencies` 里的依赖；
- `-b`, `--branches <String>` - 想要查询的分支, 多个分支间可以用 `,` 分隔；
- `-l`, `--all-local-branches` - 查询所有本地分支里的依赖；
- `-r`, `--all-remote-branches` - 查询所有远程分支里的依赖；
- `-h`, `--help` - 显示帮助信息；

**使用举例**:

```bash
# 查询所有远程分支上的 @terminus/nusi-slim 版本及提交信息
t query-deps @terminus/nusi-slim -r

# 查询所有本地分支上的 vite 版本及提交信息
t query-deps vite -dl

# 查询develop,feature/latest,master三个分支上的 vite 版本及提交信息
t query-deps vite -d -b develop,feature/latest,master
```

**输出样例**:

![Query Node Deps Output](https://img.alicdn.com/imgextra/i3/O1CN018vHMfQ1XYHNPsRY9L_!!6000000002935-0-tps-1345-426.jpg)
