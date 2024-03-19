# CHANGELOG
All notable changes to this project will be documented in this file.

## 1.70.0 - 2024-03-19

### Bug Fixes

- Fix `t art deploy` for Windows and improve TUI output
- Query latest Erda pipeline records for Nu v0.92
- Fix TERP asset syncing output for Nu v0.92

### Documentation

- Update README.md for artifact assistant

### Features

- Remove Nu plugin config file automatically after upgrading Nu
- Add `t artifact` command with `deploy`,`consume`,`produce` actions supported
- Add artifact helper related config and args
- Confirm the deploy order detail before execution
- Add customize Erda host support for artifact and pipeline related commands
- Install `fzf` if doesn't exist for artifact version and deploy group selection
- Add `fzf` upgrade support
- Use `fzf` to select the artifact version to deploy
- Add select deploy group by fzf and preview support for `t art deploy` command
- Add orgAlias config for artifact assistant
- Add detailUrl to artifact meta output
- Add select multiple application groups to deploy support for artifact assistant
- Support `t art deploy --combine` which contains produce and consume
- Add `--list` flag to `t art` command
- Multiple deploy group separated by comma from setting or input support for artifact assistant
- Login with username and password from settings support for artifact assistant

### Miscellaneous Tasks

- Add casts/produce.cast for `t art produce`
- Add casts/deploy.cast for `t art deploy`
- Add casts/art-consume.cast for `t art consume` command
- Add `asciinema` demos for artifact assistant
- Make sure at most one default was set for source and destination

### Refactor

- Improve select artifact by `fzf` to deploy feature

## 1.68.1 - 2024-03-06

### Bug Fixes

- Fix `t ding-msg` show error detail of failed ding notification
- Fix select of list, use spread operator instead for Nu v0.91

### Miscellaneous Tasks

- Update README.md add nu install and upgrade tip
- Update Nushell config to v0.91.0

## 1.68.0 - 2024-02-22

### Bug Fixes

- Fix `t emp` working hours query for unfilled teams

### Features

- Add `get help` custom command to Nu config
- Add `--month` flag for `t emp` command to query working hours filling status by month
- Add module selection support for TERP static assets download and sync command: `t ta`
- Add `--watch` flag for `t dq` command to watch a running pipeline by pipeline ID

## 1.67.1 - 2024-02-18

### Bug Fixes

- Fix `t msync` int to string converting error after upgrading to `Nu` v0.90.1

## 1.67.0 - 2024-02-07

### Bug Fixes

- Fix `atAllMinCount` check for `t emp` command
- Fix `t query-deps` command for Windows
- Fix last day check of `t emp-daily` command
- Fix commit meta extract algorithm for `t query-deps` command

### Documentation

- Update docs for `t git-branch` and `t emp-daily` commands
- Update docs for `t query-deps` command

### Features

- Add `WORKDAYS_TILL_MONTH_END` env var to specify total workdays till month end of current week for gap calc
- Add `--contains` flag for `t git-branch` command
- Add `t query-deps` command to query node dependencies in all package.json files from the specified branches
- Add `LAST_DAY`, `LASTDAY_MSG` to `t emp-daily` command for Holidays
- Add `rc` command to reload Nushell config
- Add `SKIP_UNTIL` env variable to specify the time to start DingTalk reminding for `t emp-daily` command
- Rename `t trigger-sync` command to `t gsync`
- Add `t desc -a` to show all branch descriptions from the `i` branch

### Miscellaneous Tasks

- Fix ghostty terminal config

### Refactor

- Update `t query-deps`, remove usage of `grep` command

## 1.66.0 - 2024-01-29

### Bug Fixes

- Fix working hours rounding bug for `t emp` command
- Fix query begin and end date calc for `t emp` command
- Fix @All checking for `t emp-daily` command
- Fix type convert error for `t gsync -l` command
- Fix working-hours polling on monday for `t emp-daily` command

### Features

- `t terp-assets` add Syncing modules by their full name support
- `t terp-assets transfer all` will sync all assets registered in `latest.json`
- Display dest latest.json url after transfer TERP static assets
- Fallback to get users from API if not configured in `.termixrc` for `t emp` command
- Add `atAllMinCount` option to mention all if the count of mention users is above specified count for `t emp` command
- Quit `t emp-daily` scheduled task if all teams have finished filling their working-hours

## 1.65.0 - 2024-01-25

### Bug Fixes

- Fix emp working hours query and display

### Features

- Valid user mobile number before sending DingTalk Notification for `t emp` command
- Add `--debug` and `--no-ignore` flag to `t emp` command
- Check if all working hours have been filled by `surplusPercentage` response for `t emp` command

### Miscellaneous Tasks

- Add `Lilex` and `Sarasa Term SC` fonts to terminal configs
- Update online docs for all refactored commands

### Refactor

- Add `-h` for `ls-node`, `release`, `desc`, `git-branch`, `git-remote-branch`, `rename-branch` and `repo-transfer` to show help docs
- Add `-h` flag for `dir-batch-exec`, `git-batch-exec` and `git-stat` command to show help docs
- Refactor `t git-branch` and `t git-remote-branch` add `--show-tags` flag

## 1.63.0 - 2024-01-22

### Documentation

- Update docs for `t brew` and `t upgrade` command

### Features

- Install `just` and `nushell` by `brew` for `macOS`
- Add `tuna` mirror support for `t brew` command by adding `--tuna` flag
- Add `aliyun` mirror support for `t brew` command by adding `--aliyun` flag

## 1.62.0 - 2024-01-19

### Bug Fixes

- Allow apps downloaded from anywhere in MacOS

## 1.61.0 - 2024-01-18

### Bug Fixes

- Fix WezTerm config for Nushell that installed by Homebrew
- Fixed DingTalk Robot Ak&Sk env key naming to work properly with EMP man-hour filling notification
- Try to fix `Nushell` & `just` upgrade for macOS of M chip set
- Add no emp config tip for `t emp*` command

### Features

- Add `--force` flag to `t upgrade` to do a force upgrade of open source tools

## 1.60.1 - 2024-01-18

### Bug Fixes

- Fix open source tools upgrade

## 1.60.0 - 2024-01-18

### Bug Fixes

- Fix latest version check of termix-nu
- Fix Erda pipeline deploy and query for Nu v0.89.1
- Fix open source tools install for windows

### Documentation

- Update doc for `t upgrade` command
- Update doc for `t emp` and `t emp-daily` command

### Features

- Don't print the result if `--silent` is set for `t emp` command
- Notify the members who didn't fill the working hours by DingTalk Robot for `t emp -n` command
- Add `EMP_WORKING_HOURS_NOTIFY` env var to turn on or off EMP working hour notify by DingTalk Robot
- Add `working-hours-daily-checking` job for EMP working hours notify
- Last day(Monday and Month end) keep on polling and notify with specified interval for `t emp-daily`
- Add Github action to upload latest version of `nushell` and `just` packages to Aliyun OSS everyday automatically
- Add `t upgrade` command to upgrade `nushell`, `just` or `termix-nu`
- Ignore teams with `ignore = true` in config file for EMP working hours query and notify
- Add `t upgrade --all` command to upgrade `Nushell`, `Just` and `Termix-nu` all at once

### Miscellaneous Tasks

- Add a config file for `ghostty` terminal (beta)
- Add `publishAt` and `repo` fields for `latest.json` of uploaded open source tools
- Standardize released package names of open tools
- Add upgrade nu and just cast

### Refactor

- Simplify the usage of query working hours by `t emp` command

## 1.55.0 - 2024-01-09

### Features

- Add initial meta data syncing feature
- Enable import specified modules for `meta sync`
- Add module select support for `meta sync`
- Add meta data syncing related configs and validate it before synchronization
- Select and show selected modules before confirmation of meta syncing
- Must specify `source` and `destination` if no default source and destination was set for `meta sync`
- Add `teamId`, `teamCode`, `host` checking for each source and destination before running `meta sync`
- Add `asciinema` casts for meta data syncing operations
- Show git commit SHA in `meta sync` command
- Remove `resetModuleForInstall` param for meta data importing
- Add `--list` flag support for `meta sync` command
- Support adding `ddlAutoUpdate` param in `.termixrc` config for meta data syncing
- Add `--snapshot` flag to create and upload snapshot of `TERP` meta data without importing
- Add ansi links to task id for `t msync` command
- Add tab completion support for `meta sync` command in Nushell REPL
- Add `terp assets` command for static assets synchronization of `TERP`
- Update `terp assets` command, add syncing meta data to `latest.json`
- Add common `progress` custom command

### Bug Fixes

- Fix default source and destination filter for `meta sync`
- Fix meta data syncing with `--selected` flag
- Handle 500 error properly for the last step of meta data syncing
- Fix `zoxide` init script for Nu v0.89.0
- Fix `just ver` error for unpublished release
- Fix `nu-use-nightly` command

### Miscellaneous Tasks

- Adapt `rio` config file to v0.0.33
- Sync doc from feature/extra
- Adapt bool flags for Nu v0.89.0
- Update .env-example
- Encode `syncBy` field of `terp-assets` syncing meta data
- Upgrade min Nushell and Just version

### Refactor

- Refactor `compare-ver` and `is-lower-ver`
- Use readable exit code by string enums

### Documentation

- Update docs for `t msync`(meta data synchronization) command
- Update FAQ.md and CHANGELOG.md
- Update FAQ.md add `.env` config error case
- Update FAQ.md, add running Erda pipeline failed case

## 1.53.0 - 2023-12-13

### Bug Fixes

- Fix upsert input param for Nu v0.88
- Fix git-diff-commit for Nu v0.88

### Miscellaneous Tasks

- Add run/cast2gif.nu
- Update Nushell config for v0.88.0

## 1.52.0 - 2023-12-05

### Bug Fixes

- Fix printing of `pull-all` detail output
- Fix `trigger-sync` command when no syncing config available

### Features

- Add `--repo` flag support for `trigger-sync` command
- Add `--grep` flag for `t dp -l` command

## 1.51.0 - 2023-11-15

### Bug Fixes

- Fix `git-proxy` error for the latest clashX version
- Fix commit SHA detection for `just ver` command
- Fix `t go` error for Nu v0.86.1, should work for Nu v0.86.0
- Add empty response check for ERDA pipeline related commands
- Fix `t nu-use-nightly` for nu binaries that installed by `brew` and add non-aria2c install support
- Fix `t nu-use-nightly` for Windows

### Documentation

- Update FAQ.md
- Update README.md add DingTalk related doc
- Update README.md
- Add doc for `git-diff-commit` command

### Features

- Add `t git-diff-commit` command to Show commit info diff between two commits, support grep in Author,SHA,Date and Message
- Update `git-diff-commit` command add `--not-contain`, `--exclude-shas` and `--exclude-authors` flags
- Add stop pipeline support by running command like `t dp --stop-by-id 123`
- Add manual link to `t ver` and `t go`
- Add sending messages to multiple DingTalk robots support
- Add ansi link for querying latest CICDs
- Add `t nu-use-nightly` private command
- Add empty description tip for `t desc`
- Fetch latest full release for `nu-fetch-latest` in config.nu

### Miscellaneous Tasks

- Add `nu-fetch-nightly` and `nu-use-nightly` to config.nu
- Update Nu config to nushell/nushell SHA: e8e0526f5
- Update termix-nu docs

### Refactor

- Use `par-each` instead of `each` whenever possible for better performance

## 1.50.0 - 2023-10-18

### Bug Fixes

- Fix `get-tmp-path` for Windows
- Fix hide-env tip for `git-proxy off`
- Fix `gsync -a` error when the remote branch does not exists

### Documentation

- Add FAQ.md
- Update README.md

### Features

- Add `get-ip` custom command to Nu config
- Make `TERMIX_TMP_PATH` env config optional and fallback to `($env.HOME)/.termix-nu`
- Add `dingtalk notify` command to send a message to DingTalk Group by custom robot, see `t ding-msg -h` for more help
- Add `--force` or `-f` switch to `trigger-sync` command
- Add `trigger-sync -l` to list all branch syncing configs of current repo
- Add `gsync` as an alias for `trigger-sync`
- Render pipeline ID as a clickable link while querying latest CICDs
- Show the latest pipeline link while querying latest CICDs
- Fetch remote head before running pipelines or syncing branches
- Add description field to available deploy targets for `dp -l`

### Miscellaneous Tasks

- Adapt to Nu v0.86.0, use `bool` type for flags
- Update `Nushell` config
- Adapt to Nu v0.86, use `def --env` instead of `def-env`

### Refactor

- Change `$nothing` to `null` for Nu v0.86
- Fix some `any` type

## 1.38.1 - 2023-09-20

### Bug Fixes

- Fix Nushell version check, do not exit if we don't have to update

## 1.38.0 - 2023-09-20

### Features

- Add `Rio.toml` config file for Rio terminal
- Add `--all(-a)` flag to `trigger-sync` command to sync all local branches that have a syncing config

### Miscellaneous Tasks

- Use `eza` instead of `exa` in Nu config
- Adapt to Nu v0.85 for `echo` command
- Use `std repeat` instead of string multiply operator
- Update brew env for Nu config
- Update Nushell config for v0.85
- Set `$env.config.color_config.leading_trailing_space_bg` for Nu v0.85
- Update code formatting

### Refactor

- Use `reduce` for `build-line` for better compatibility
- Change command naming style

## 1.37.0 - 2023-09-04

### Features

- Add merge quick navs from local `.termixrc` file support

### Miscellaneous Tasks

- Update README.md

## 1.36.0 - 2023-09-01

### Features

- Renew Erda session automatically if expired by username and password

### Miscellaneous Tasks

- Update README.md and use build-query for session renew

## 1.35.0 - 2023-08-30

### Bug Fixes

- Fix `just upgrade` bug

## 1.33.0 - 2023-08-30

### Bug Fixes

- Fix git ref checking custom command `has-ref`

### Features

- Add `symlink` and `unpack` custom command
- Enable reading `.termixrc` from `termix-nu` dir while running Erda pipelines

### Miscellaneous Tasks

- Change the proportional UI/title font family for `wezterm` config

## 1.32.0 - 2023-08-23

### Bug Fixes

- Fix common version compare algorithm
- Fix `Nushell` install with dataframe feature

### Chore

- Update `wezterm` config for Windows

### Features

- Fix spawn of Nu and launcher menu for `wezterm`
- Add `ua` and `hr-line` custom utils

### Miscellaneous Tasks

- Add `wezterm` config file
- Add `atuin` setup for `Nushell` config
- Adapt to nu v0.84, change `date format` to `format date`
- Add ignore as a workaround for unnecessary each output
- Update command palette config for `wezterm`
- Add key mapping config for `wezterm`
- Update `wezterm` key mapping
- Update theme config for `wezterm`
- Add keyboard shortcut to modify tab name
- Update `zoxide` config for Nu 0.83.1
- Update config for `wezterm`
- Update launch menu config for `wezterm`
- Update Nu config, Disable the date & time displaying on the right of prompt
- Update config for `fnm`
- Update comments for some custom commands
- Add `--plugin-only` for `install-all-nu` command
- Update `.termixrc-example`
- Add comments for alias in nu config file

### Refactor

- Adapt to Nu v0.84 and use const and module if possible

## 1.31.0 - 2023-08-01

### Miscellaneous Tasks

- Adapt to Nushell v0.82.1
- Fix compare-ver, Ignore `-beta` or `-rc` suffix
- Update config add `install-all-nu` command

### Refactor

- Use `not` if necessary

## 1.30.0 - 2023-07-10

### Bug Fixes

- Fix pipeline checking with the same SHA
- Fix pipeline data formatting issue for newly created pipelines
- Fix display of horizontal line
- Fix no CICD data error for query or pre-deploy checking

### Features

- Add deploy or query multiple apps support with local `.termixrc` config
- Print available deploy targets and apps with more detail
- Add help tips for `erda-deploy` and `erda-query` command

### Miscellaneous Tasks

- Add deploy config for multiple apps
- Adapt to `nushell` v0.82
- Add `.termixrc-example` config for batch deploy

## 1.28.0 - 2023-07-06

### Features

- Support query the latest 10 pipeline running results by `t dq` or `t dq test`, etc.

### Miscellaneous Tasks

- Add some comments

### Refactor

- Use module if possible
- Extract some small custom commands

## 1.27.0 - 2023-07-04

### Bug Fixes

- Fix the display of git committer for the pipeline check

### Features

- Checking if a commit has been deployed before running a new pipeline
- Check remote branch SHA instead of local SHA before running the pipeline

### Miscellaneous Tasks

- Change the column header of the running pipelines to title case
- Adapt to Nushell v0.82.1 and above

## 1.26.0 - 2023-07-01

### Bug Fixes

- Fix version check

### Features

- Check if there is any running pipeline before running it
- Use `--force` or `-f` to run a pipeline even if there is already one running
- Enable set default value for `deploy` command

### Refactor

- Some code refactor, extract Erda host variable, etc.

## 1.25.0 - 2023-06-30

### Features

- Add query deploy targets by `t dp -l` support
- Enable query pipeline running status from any directory

### Miscellaneous Tasks

- Bump version to v1.25.0

## 1.23.0 - 2023-06-29

### Bug Fixes

- Fix pipeline query result return URL

## 1.22.0 - 2023-06-29

### Miscellaneous Tasks

- Remove unnecessary ERDA_TOKEN env var for Erda pipelines

## 1.21.0 - 2023-06-29

### Bug Fixes

- Make sure origin/i branch exits before deploy or query pipeline

### Features

- Add Erda pipeline `run` and `query` feature
- Read Erda pipeline config from `.termixrc` to run the CICDs
- Output pipeline detail url while creating and running it
- Check if the pipeline config exists before running it

### Miscellaneous Tasks

- Add Erda auth env config examples
- Bump version to v1.21.0
- Fix code indention for actions/pipeline.nu
- Refactor code

## 1.20.0 - 2023-06-28

### Bug Fixes

- Remove Nu env patch for issue #9265

### Features

- Add `nun` custom command for nu config
- Add `nuc` and `nucc` command alias for Nushell config

### Miscellaneous Tasks

- Update config for nu v0.82 and update quick navs
- Upgrade min required Nushell version to v0.82

### Breaking

- Adapt to Nushell v0.82

## 1.19.0 - 2023-05-23

### Bug Fixes

- Fix `nudown` command
- Add a small patch for nushell #9265 issue

### Miscellaneous Tasks

- Update tags from origin

## 1.18.0 - 2023-05-17

### Features

- Add some nu related custom commands
- Add sort by tag support for `ls-tags` command
- Add `parallel` common helper and `gh-pr` custom command
- Add `topf` for nu config

### Miscellaneous Tasks

- Adapted to nushell v0.78.1+
- Optimize semver comparing algorithm
- Update nushell config file to v0.79.1
- Fix `exit --now `breaking change for v0.80
- Fix git/remote-branch.nu
- Update min nu ver to v0.80

## 1.17.0 - 2023-04-10

### Bug Fixes

- Fix `git-proxy` for windows

### Features

- Add proxy support for v2ray
- Update `git-proxy` command add ClashX support, works on mac
- Add `ls-tags` command
- Hide some rarely used commands most of them are gaia or gaia redev related

### Miscellaneous Tasks

- Adapted to Nushell v0.78, set min required Nushell version to v0.78
- Adapted to nu v0.78 fix `expected operator` error

## 1.16.0 - 2023-03-21

### Bug Fixes

- Fix str trim for nu v0.77
- Update `has-ref` git util helper
- Fix `emp` and `prune-synced-branches` command

### Miscellaneous Tasks

- Add ignore patch for nu v0.76
- Update nushell config for v0.76.1
- Adapt to nu v0.77.1+, use `print` explicitly
- Bump version v1.16.0

## 1.15.0 - 2023-02-23

### Bug Fixes

- Adapt to nu v0.75.1+
- Fix `emp` command for nu v0.76, after dataframe commands changed

### Features

- Bump to v1.15.0

### Miscellaneous Tasks

- Update nu install command

## 1.13.0 - 2023-02-01

### Bug Fixes

- Fix home env var for Windows

### Features

- Update nushell config, enable fuzzy search for history

### Miscellaneous Tasks

- Update nushell config file
- Update nushell cursor shape config
- Bump version v1.13 for nu v0.75
- Adapt to nu v0.75

## 1.12.0 - 2023-01-13

### Bug Fixes

- Fix mall/redevelop-all.nu script for nu v0.73
- Fix mall/redevelop-main.nu script for nu v0.73
- Fix `emp` command with empty response of working hours or leaving records case
- Fix plugin register for nushell v0.74
- Fix tilde expansion issue for nu v0.75

### Opt

- Optimize plugin register for nu v0.74

## 1.11.0 - 2022-12-26

### Bug Fixes

- Fix `pull-all` command, use `git branch` instead of `git br`
- Fix config saving for nu v0.72

### Features

- Update upgrade tips
- Update nushell config file, add carapace completer support

### Miscellaneous Tasks

- Fix config, re-register plugins needed for v0.71+
- Adapt to nu v0.72
- Update config file for nu v0.72
- Update min nu version to v0.72 and min just version to v1.9, bump version to v1.10.0
- Adapt to nu version v0.73
- Fix emp command for nu v0.73
- Bump v1.11.0
- Fix `prune-synced-branches` for nu v0.73.1

## 1.10.0 - 2022-12-02

### Bug Fixes

- Fix `pull-all` command, use git branch instead of git br
- Fix config saving for nu v0.72

### Features

- Update upgrade tips

### Miscellaneous Tasks

- Fix config, re-register plugins needed for v0.71+
- Adapt to nu v0.72
- Update config file for nu v0.72
- Update min nu version to v0.72 and min just version to v1.9, bump version to v1.10.0

## 1.9.0 - 2022-09-29

### Miscellaneous Tasks

- Change default history format to sqlit
- Remove protocol for plugin register with nu 0.68.1
- Change `str collect` to `str join` for nu 0.68.2+
- Update bump version custom command

## 1.8.0 - 2022-09-08

### Bug Fixes

- Fix some variable names for nu v0.66.1 or above
- Fix `git-remote-branch` command
- Fix error of run `git-proxy off` multiple times
- Fix emp working hours query

### Features

- Upgrade mall/redevelop-main.nu script to deploy from generated redevelop source
- Update `tag-redev` and `gaia-release` command, add enable field filter

### Miscellaneous Tasks

- Fix plugin register protocol
- Rename variable name for flags
- Adapted to Nu v0.68

## 1.7.0 - 2022-07-27

### Features

- Rename `git-age` to `git-branch` and `git-remote-age` to `git-remote-branch`
- Add query working hours of previous week support for `emp` command
- Rename `check-desc` to `check-branch`, display removed branches who have syncing configs

### Bug Fixes

- Fix query working hours and `pull-redev` command for nu v0.65
- Improve `git-age`/`git-remote-age` and `check-desc` command output
- Improve redevelop all script, exit if termix exec failed
- Improve redevelop main script, exit if termix exec failed

### Miscellaneous Tasks

- Try to use bare string if possible
- Update config for nu v0.65.1
- Update default config to the latest sample
- Update git branch sorting output when descriptions are not available
- Remove unnecessary brackets if possible
- Upgrade min nu version to v0.66, and min just version to v1.3.0, bump to v1.7.0

## 1.6.0 - 2022-06-22

### Bug Fixes

- Improve redevelop-all script
- Mall/redevelop-main.nu
- Update nu-stat script use `size` instead of `wc`
- Fix emp auth check for working hours query
- Add code syncing support for branches whose name contain `.`
- Fix `pull-redev` command

### Documentation

- Add doc for `git-stat` command

### Features

- Add `get-locale` related script
- Add mall/upload-locale.nu script
- Add mall/clean-locale.nu script
- Add mall/redevelop-all.nu script
- Add mall/redevelop-main.nu script
- Add run/nu-stat.nu of source line counter for nushell
- Add command `load-direnv`
- Update zoxide and other configs
- Add multiple team support for `emp` command
- Add `git stat` command to display modification stats for each commit
- Add light theme related config
- Upgrade for nu v0.64

### Miscellaneous Tasks

- Adapt to nushell v0.61.0
- Update config to nushell v0.61.1

### Refactor

- Simplify bool flags for scripts
- Optimize plugin register for nushell v0.61.0

## 1.5.0 - 2022-03-26

### Bug Fixes

- Disable `_check-ver` for `upgrade` command
- Fix bug of semver compare
- Rename nu plugins for register, fix `git proxy` command for nu 0.60
- Update the new `each` syntax
- Adapt `gaia-release` for nu v0.59+
- Change bool flags from string to bool, fix plugin import for windows
- `git-age`, `git-remote-age`, `show-env` commands for Windows
- Fix table layout broken for `ls-redev-refs`, `check-desc` on windows, fix `go` command
- Adapt `emp` command again to v0.59+
- Remove unnecessary hack for windows by using latest main branch
- Fix `emp` command for windows with nu v0.59+
- Use true/false instead of $true/$false and fix `trigger-sync` command
- Adapt `go` and `tag-redev` command for nu v0.60
- Update default just file path for windows, fix `tag-redev` command for win
- `prune-synced-branches` command for windows
- Fix `repo-transfer` and git repo check strategy
- Fix `trigger-sync` and `git sync-branch` commands' lock issue
- Update query emp working hours related config
- Fix zoxide script
- Adapt the new `default` syntax
- Ignore the repos that don't have access permission for `prune-synced-branches` command
- Update oh-my-posh prompt command
- Remove unnecessary hacks for Win, fix `trigger-sync` command
- Update `pull-all` command ignore i branch when possible
- Change capnp to json for plugin register
- Fix `repo-transfer` issue, output sync messages should be displayed
- Fix `brew-speed-up off` command
- `emp` command

### Features

- Add pull-all for local ahead support
- Add config file for nu 0.60, fix `check-desc` command
- Add `!` command for common
- Update termix-nu related docs
- Add get-icon.nu script for gaia-mobile
- Add mall/upload-image.nu script
- Add mall/compress-image.nu script
- Update config for nu, add `cargo search` custom command

### Miscellaneous Tasks

- Update nushell min version check
- Upgrade min just version to v 0.11.0
- Lots of modification in order to adapt to nushell v0.60
- Adapt to nu v0.60
- Remove unnecessary print command usage
- Adapt to latest nushell
- Update `nu` and `just` version, fix version check
- Update `release` command
- Update nu config, fix `go` command
- Remove unnecessary hacks
- Update nushell config to the latest version
- Update nushell config file
- Add `#!/usr/bin/env nu` header for each script
- Adapt to the latest nu syntax, and change `update` to `upsert`
- Fix script indention and refactor by using `into duration`
- Update minimum just and nu version required

### Refactor

- Adapt to nu v0.60, add log util, fix Justfile
- Adapt `check-ver` and `quick-nav` command to nu v0.60
- Adapt `pull-all` command with nu 0.60.0, use $false check instead of empty blocks
- Adapt `tag-redev`, `check-desc`, `desc`, `repo-transfer` commands to nu v0.59
- Adapt `emp` cmd to nu v0.60
- Adapt `dir-batch-exec` for nu v0.60
- Some optimization

### Opt

- Adapt to nushell next release v0.60
- Adapt `git-proxy`, `trigger-sync`, `sync-branch`, and `release` command for nushell v0.60
- Use just to register plugin dynamically for nushell
- Add common host os checking command
- Improve get-icon.nu for a better user experience

## 1.2.12 - 2022-01-17

### Bug Fixes

- Fix empty working-hours exception for `t emp`

### Documentation

- Add `brew-speed-up` related docs

### Features

- Add feature of checking if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to set much faster brew mirrors quickly

## 1.2.11 - 2022-01-04

### Bug Fixes

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature, make its config compatible with previous version
- Fix force upgrading feature, improve version check strategy

### Features

- Add force upgrade feature, if a force-upgrade version was released all commands will stop running before upgrading termix-nu

### Miscellaneous Tasks

- Add test case in comments for force upgrade feature

## 1.2.10 - 2021-12-31

### Bug Fixes

- Fix emp working hours query while there are leaving records

### Documentation

- Add lock related docs for git auto sync and trigger-sync

### Features

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

### Miscellaneous Tasks

- Bump version v1.2.10

## 1.2.12 - 2022-01-17

### Bug Fixes

- Fix empty working-hours exception for `t emp`

### Documentation

- Add `brew-speed-up` related docs

### Features

- Add feature of checking if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to set much faster brew mirrors quickly

## 1.2.11 - 2022-01-04

### Bug Fixes

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature, make its config compatible with previous version
- Fix force upgrading feature, improve version check strategy

### Features

- Add force upgrade feature, if a force-upgrade version was released all commands will stop running before upgrading termix-nu

### Miscellaneous Tasks

- Add test case in comments for force upgrade feature

## 1.2.10 - 2021-12-31

### Bug Fixes

- Fix emp working hours query while there are leaving records

### Documentation

- Add lock related docs for git auto sync and trigger-sync

### Features

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

### Miscellaneous Tasks

- Bump version v1.2.10

## 1.2.9 - 2021-12-30

### Bug Fixes

- Fix emp query error while there is no leaving record

### Features

- Add local branch existence check for `git-remote-age` command

### Miscellaneous Tasks

- REMOVE unused files
- Update min nushell version to v0.42.0, bump version v1.2.9

## 1.2.8 - 2021-12-23

### Bug Fixes

- Fix error of fatal: could not open '<' for reading: No such file or directory
- Fix repo syncing issue while doing a redirect push like `git push origin a:b`

### Documentation

- Add `prune-synced-branches` related docs
- Update docs for redevelop related commands

### Features

- Add `prune-synced-branches` command
- Add gap column for emp working hours stat table
- Add redevelop repos for mbr/brand and point malls
- Add b2b mobile to redevelop repos
- Update redevelop related commands add grouping support

### Miscellaneous Tasks

- Change FORCE_PUSH to FORCE, make it more simple to do a force push
- Use internal `str find-replace` instead of external `tr`

## 1.2.7 - 2021-12-16

### Bug Fixes

- Fix `check-desc` command when all branches have been described
- Fix some issues for `pull-redev` command
- Fix default command list display issue while another justfile exists in invoke dir
- Fix `emp` working hour query command for the new emp

### Documentation

- Update nav menu of README.md
- Add `git-proxy` related docs, update `emp` doc

### Features

- `check-desc` command add checking branches that have a description but were removed from remote support
- Add b2c brand site related config
- Add `git-proxy` command only works when AliLang speed up was enabled
- Add git proxy status for `show-env` command

### Miscellaneous Tasks

- Add b2b/srm/mbr repo navs
- Update min nushell version to v0.41.0

## 1.2.6 - 2021-12-06

### Bug Fixes

- Add temp dir existence check, notify user if it does not exist.
- Fix `error: Coercion error` for `sync-branch` and `trigger-sync`

### Documentation

- Update readme.md add .env and git branch sync related tips

### Features

- Add source branch name to branch syncing summary table
- Add `trigger-sync` feature for repo syncing and related docs
- Add `SYNC_IGNORE_ALIAS` in `show-env` output

### Miscellaneous Tasks

- Add source code counter for each folder or file
- Move temp git.nu to run dir

### Refactor

- Add global date format constant: \_DATE_FMT

## 1.2.5 - 2021-12-02

### Bug Fixes

- Add repo not exist error handler for `git repo-transfer`

### Documentation

- Update readme.md, add `Just` & `nu` upgrade check related docs
- Reorder command docs
- Improve docs

### Features

- Add min just version check, add warning tips to upgrade just if required
- Add source repo release new version support by `gaia-release` command
- Add latest termix-nu version check support
- Add git repo transfer feature by `git repo-transfer` command
- Improve `git-age` command add last commit author name

### Refactor

- Change `REDEV_REPO_PATH` to `TERMIX_TMP_PATH` in .env config, and `redevRepoPath` to `termixTmpPath` in toml conf
- Add $TERMIX_CONF constant and get-tmp-path helper
- Use `path join` instead of string concatenation
- Move redev related scripts from git to actions dir

## 1.2.3 - 2021-11-26

### Bug Fixes

- Fix `check-desc` command, do fetch remote before check
- Fix CHANGELOG.md commit message
- Update pre push hook demo in README file, fix for remote branch deleting
- Ignore code syncing when remote branch of origin does not exist
- Fix `rename-branch` command source branch check

### Documentation

- Update recipes list for readme.md
- Format docs by prettier
- Update README.md

### Features

- Update CHANGELOG.md automatically for `release` command
- Add a switch to update CHANGELOG.md, and update `release` command related docs
- Change branch description file from json to toml format for `desc` related commands
- Add url nav alias anchor for readme.md
- Add force push support for branch syncing
- Use remote branch syncing config instead of local
- Add web nav url output support in terminal for branch syncing
- Add code syncing .env config `SYNC_IGNORE_ALIAS` to ignore syncing of some repo
- Add read conf from origin/i branch support

### Miscellaneous Tasks

- Remove unused termix conf of macCliApps

### Refactor

- Add `get-conf` common helper in utils/common.nu

## 1.2.2 - 2021-11-22

### Bug Fixes

- Fix `upgrade` command for termix-nu: use latest release tag instead of master branch as upgrading source

### Features

- Bump version v1.2.2
- Use `git cliff --output CHANGELOG.md` to generate a change log

### Miscellaneous Tasks

- Update CHANGELOG.md to v1.2.2
- Add changelog create instruction
- Update CHANGELOG.md

## 1.2.1 - 2021-11-22

### Features

- Add `release` command for termix-nu
- Update `check-desc` command: add more branch info to cmd output

### Miscellaneous Tasks

- Fix some code indentions
- Update doc for release command
- Update min nushell version from `0.39.0` to `v0.40.0`

### Refactor

- Refactor `working-hours` command: extract more functions

## 1.2.0 - 2021-11-17

### Bug Fixes

- Fix git age and remote age date display
- Git-remote-age git check issue
- Fix git check on windows
- Empty check for working hours
- Fix weekday calc for working hours
- Improve join after upgrade just to v0.10.3
- Add invalid login info check for working hours
- Update tag-redev command
- Find navs from key only
- Fix open quick nav for win
- Fix check-desc

### Features

- Add mall related scripts
- Add show git repo tags support
- Add latest nushell version check
- Add git command and git repo check
- Add show redevelop branches support
- Update README.md docs
- Update Readme.md and add `working-hours` script
- Add emp working hours script
- Add lts support for `ls-node`
- Update docs
- Update emp
- Add just upgrade feature
- Add view git branch description command
- Add `just go` command for quick navigation
- Update readme.md add sync-branch docs
- Update emp docs
- Add `just check-desc` command
- Bump version v1.2.0

### Miscellaneous Tasks

- Change command name of rename branch
- Update emp query command
- Bump version to v1.1.0
- Fix some code indentions

### Refactor

- Refactor quick-nav command

### Opt

- Add has-ref utils
- Refactor show nav items

## 1.0.0 - 2021-10-12

### Bug Fixes

- Fix git/remote-age.nu
- Git pre push hooks works now!!
- List remote tag and sorting by creator date
- Update path for windows
- Fix just invocation directory
- Update justfile for windows compatibility
- Update justfile, all works on macOS
- Use open and save instead of bat for windows
- Fix dir-batch-exec
- Fix justfile for empty args or args with spaces in it
- Add command available check
- Fix pull-redev script
- Ls-redev-tags for windows
- Ls-redev-tags sort by tag version for windows
- Update pull-redev script
- Update git branch rename

### Features

- Add `git-age` command to show local branch age information
- Add `pull-all` command to update all local branches to latest commit
- Add `git-remote-age` command to show all remote branch info
- Add `ls-redev-tags` to show all tags for redevelop repos
- Add `show-env` to show local environment information
- Add `ls-node` to query node versions
- Add `pull-redev` to pull latest commit for all redevelop repos
- Add `tag-redev` to create tag for redevelop repos
- Add `git-sync-branch` for git branch syncing support
- Add `git-batch-exec` to execute custom command for specified branches
- Add `dir-batch-exec` to execute custom command for specified dirs
- Add branch selection for redev repo ops
- Update sync command
- Add git alias and config script
- Add .env example file
- Add custom shell support for git-batch-exec
- Update dir-batch-exec add custom shell support
- Use bat instead of cat for windows compatibility
- Add REDEV_REPO_PATH config in .env
- Add show version and env command related script
- Add merge perf
- Add nu config init script
- Add query node version support
- Add actions/setup-mac.nu script, rename actions.toml to termix.toml
- Add soft link example for windows
- Add version command to show termix-nu version
- Add git rename remote branch feature

### Miscellaneous Tasks

- Refactor commands
- Change ls-remote-tag to ls-redev-tag
- Remove unnecessary semicolon and echo

### Refactor

- Optimize branch syncing for pre push hooks, use query json instead of table
- Add common helper for utils
- Change some file dirs

### Opt

- Use structured redevRepos config for redev related commands
- Enable common utils script sharing
- Refactor show-env, add get-ver and get-env helper
- Refactor script calling use source in some cases
- Refactor code use source and then call commands
- REFACTOR git/git-batch-exec.nu USE SOURCE INSTEAD OF SCRIPT CONCATENATION
- Update dir-batch-exec action, use source instead of file concatenation

### Update

- Use bash instead of nu for user specified command

<!-- generated by git-cliff -->
<!-- Generate new changelog: `git cliff --output CHANGELOG.md` -->
<!-- Generate changelog for specified release: git cliff --unreleased --tag 1.68.0 --prepend CHANGELOG.md  -->
