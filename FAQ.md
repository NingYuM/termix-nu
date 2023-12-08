
## FAQ:

1. 初次执行 `t` 的时候报错:
  ```console
  Error: nu::shell::plugin_failed_to_load

    × Plugin failed to load: No such file or directory (os error 2)

  error: Recipe `_register_plugins` failed with exit code 1
  ```
这可能是因为 `Nushell` 安装后还没有使用过，也没有为其初始化配置文件，可以尝试在命令行执行下 `nu`，然后会有两个交互式提问，直接输入 `y` 即可。这样就会为 `nu` 创建默认的配置文件。接下来可以再次执行 `t` 试试。


2. "Could not find `cygpath` executable to translate recipe..." on Windows

Install git by `winget install Git.Git` and `cygpath` will be available in `C:\Program Files\Git\usr\bin`, add this dir in global `PATH` environment variable should work.


3. 执行 `t` 的时候报类似如下错误:
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

这是因为用 `brew` 升级 `nu` 后之前旧的 Nushell 插件配置文件里面记录了老版本的插件路径，只需要将老的插件配置文件删掉:
```sh
rm '/Users/abc/Library/Application Support/nushell/plugin.nu'
```
即可, 这个配置文件在后续使用过程中会自动生成的
