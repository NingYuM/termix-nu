# FAQ:

1. 每天第一次执行 `t`（或者 `termix-nu` 目录的 `just`）命令的时候似乎比较慢？

> 是的，每天第一次执行 `t` 的时候会检查有没有新版本, 如果有新版本的话会提示升级，这个过程是同步阻塞的所以会感觉有点慢(`Nushell` 目前不支持异步操作)，不过这个检查每天只会进行一次，后续再次执行就会快一些。

2. 对于 `termix-nu` 的升级提示到底是升还是不升？

> 执行 `t` 命令的时候有时会在终端输出升级提示信息，提醒你 `nushell` 或者 `just` 等的版本较低，如果该提示不影响命令的正常执行可以忽略，但是如果执行命令报错建议按照提示进行升级。尤其是提示 `nushell` 版本过低的时候尽量能升则升，由于 `nushell` 目前还处在活跃开发阶段，在到达 **1.0** 版本前不兼容的变更也会比较多，为了降低维护成本，本工具将始终跟进支持最新版本的 `nushell`，没有兼容老版本的打算。

3. `termix-nu` 有 `master`、`develop` 等分支，这些分支有啥差别？

> 一般情况下建议大家使用 `master` 分支，该分支通常会适配当前已经正式发布的最新版本的 `nushell`。而 `develop` 分支通常会适配**下一个**即将发布的 `nushell` 版本，该分支上也可能会有一些正在开发中的新特性，一般会在 `nushell` 新版本发布并更新到 `brew` 仓库后的 **0~2** 个工作日内发布 `termix-nu` 的新版本。

> 如果你想尝鲜 `develop` 分支可以自己从源码编译 `nushell`，当然还有更简单的办法: 试试 `t nu-use-nightly` 该命令为私有命令，不过你可以用其下载每日构建的最新完整功能版本的 `nushell`，而且会自动根据你的 CPU 架构下载匹配的版本。下载后安装位置就在原来的位置，直接替换原来的 `nushell` 二进制文件(Windows 系统不允许对当前正在运行的可执行文件进行写操作，所以需要根据提示进行手工操作)。

4. 初次执行 `t` 的时候报错:

```console
Error: nu::shell::plugin_failed_to_load

  × Plugin failed to load: No such file or directory (os error 2)

error: Recipe `_register_plugins` failed with exit code 1
```

> 这可能是因为 `Nushell` 安装后还没有使用过，也没有为其初始化配置文件，可以尝试在命令行执行下 `nu`，然后会有两个交互式提问，直接输入 `y` 即可。这样就会为 `nu` 创建默认的配置文件。接下来可以再次执行 `t` 试试。

5. 首次执行 `t`（或者 `termix-nu` 目录的 `just`）命令的时候报错:

```console
Error: nu::parser::module_not_found

  × Module not found.
   ╭─[source:1:1]
 1 │ overlay use /Users/terminus/termix-nu/actions/check-ver.nu; termix-ver; nu-ver; just-ver
   ·             ───────────────────────┬──────────────────────
   ·                                    ╰── module not found
   ╰────
  help: module files and their paths must be available before your script is run as parsing occurs before anything is evaluated

error: Recipe `_setup` failed on line 281 with exit code 1
```

> 请检查 .env 环境变量 `TERMIX_DIR` 的配置，确保其值为 `termix-nu` 的绝对路径，这个环境变量目前是必须要配的，其他环境变量可以根据使用情况选择配置。

6. "Could not find `cygpath` executable to translate recipe..." on Windows

> Install git by `winget install Git.Git` and `cygpath` will be available in `C:\Program Files\Git\usr\bin`, add this dir in global `PATH` environment variable should work.

7. 执行 `t` 的时候报类似如下错误:

```console
Error: nu::parser::registered_file_not_found

  × File not found
  ╭─[/Users/abc/Library/Application Support/nushell/plugin.nu:1:1]
1 │ register /usr/local/Cellar/nushell/0.85.0/bin/nu_plugin_gstat  {
  ·          ──────────────────────────┬─────────────────────────
  ·                                    ╰── File not found: /usr/local/Cellar/nushell/0.85.0/bin/nu_plugin_gstat
2 │   "sig": {
  ╰────
  help: registered files need to be available before your script is run
```

> 这是因为用 `brew` 升级 `nu` 后之前旧的 Nushell 插件配置文件里面记录了老版本的插件路径，只需要将老的插件配置文件删掉:

```sh
rm '/Users/abc/Library/Application Support/nushell/plugin.nu'
```

> 即可, 这个配置文件在后续使用过程中会自动生成的。

8. 用 CLI 执行 Erda 流水线的时候提示如下错误：

```console
  Renewing Erda session...
  Erda session renew failed with message: failed to PwdLogin: pwdAuth: /oauth/token statuscode: 500, body: {"error": "server_error",
  "error description": "Internal Server Error"}
  error: Recipe 'deploy' failed on line 90 with exit code 8
```

> 如果大家都报这个错误那应该是 Erda 的用户中心后端服务有问题。如果其他人都是好的，只有个别人遇到这个问题，大概率是因为密码过期了，可以改一下密码试试。
