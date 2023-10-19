

## FAQ:

1. "Could not find `cygpath` executable to translate recipe..." on Windows

Install git by `winget install Git.Git` and `cygpath` will be available in `C:\Program Files\Git\usr\bin`, add this dir in global `PATH` environment variable should work.


Error: nu::parser::registered_file_not_found

  × File not found
   ╭─[/Users/wubingyan/Library/Application Support/nushell/plugin.nu:1:1]
 1 │ register /usr/local/Cellar/nushell/0.85.0/bin/nu_plugin_gstat  {
   ·          ──────────────────────────┬─────────────────────────
   ·                                    ╰── File not found: /usr/local/Cellar/nushell/0.85.0/bin/nu_plugin_gstat
 2 │   "sig": {
   ╰────
  help: registered files need to be available before your script is run
