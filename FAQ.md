

## FAQ:

1. "Could not find `cygpath` executable to translate recipe..." on Windows

Install git by `winget install Git.Git` and `cygpath` will be available in `C:\Program Files\Git\usr\bin`, add this dir in global `PATH` environment variable should work.


2. 执行 `t` 的时候报类似如下错误:
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
即可(这个配置文件在后续使用过程中会自动生成的)，如果你没有手工修改过 Nushell 的配置文件也可以通过执行 ` nu -c 'config reset -w' ` 命令重置下 Nushell 配置应该就可以了
