# Changelog
All notable changes to this project will be documented in this file.

## [1.31.0] - 2023-08-01

### Miscellaneous Tasks

- Adapt to Nushell v0.82.1
- Fix compare-ver, Ignore `-beta` or `-rc` suffix
- Update config add `install-all-nu` command

### Refactor

- Use `not` if necessary

## [1.30.0] - 2023-07-10

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

## [1.28.0] - 2023-07-06

### Features

- Support query the latest 10 pipeline running results by `t dq` or `t dq test`, etc.

### Miscellaneous Tasks

- Add some comments

### Refactor

- Use module if possible
- Extract some small custom commands

## [1.27.0] - 2023-07-04

### Bug Fixes

- Fix the display of git committer for the pipeline check

### Features

- Checking if a commit has been deployed before running a new pipeline
- Check remote branch SHA instead of local SHA before running the pipeline

### Miscellaneous Tasks

- Change the column header of the running pipelines to title case
- Adapt to Nushell v0.82.1 and above

## [1.26.0] - 2023-07-01

### Bug Fixes

- Fix version check

### Features

- Check if there is any running pipeline before running it
- Use `--force` or `-f` to run a pipeline even if there is already one running
- Enable set default value for `deploy` command

### Refactor

- Some code refactor, extract Erda host variable, etc.

## [1.25.0] - 2023-06-30

### Features

- Add query deploy targets by `t dp -l` support
- Enable query pipeline running status from any directory

### Miscellaneous Tasks

- Bump version to v1.25.0

## [1.23.0] - 2023-06-29

### Bug Fixes

- Fix pipeline query result return URL

## [1.22.0] - 2023-06-29

### Miscellaneous Tasks

- Remove unnecessary ERDA_TOKEN env var for Erda pipelines

## [1.21.0] - 2023-06-29

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

## [1.20.0] - 2023-06-28

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

## [1.19.0] - 2023-05-23

### Bug Fixes

- Fix `nudown` command
- Add a small patch for nushell #9265 issue

### Miscellaneous Tasks

- Update tags from origin

## [1.18.0] - 2023-05-17

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

## [1.17.0] - 2023-04-10

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

## [1.16.0] - 2023-03-21

### Bug Fixes

- Fix str trim for nu v0.77
- Update `has-ref` git util helper
- Fix `emp` and `prune-synced-branches` command

### Miscellaneous Tasks

- Add ignore patch for nu v0.76
- Update nushell config for v0.76.1
- Adapt to nu v0.77.1+, use `print` explicitly
- Bump version v1.16.0

## [1.15.0] - 2023-02-23

### Bug Fixes

- Adapt to nu v0.75.1+
- Fix `emp` command for nu v0.76, after dataframe commands changed

### Features

- Bump to v1.15.0

### Miscellaneous Tasks

- Update nu install command

## [1.13.0] - 2023-02-01

### Bug Fixes

- Fix home env var for Windows

### Features

- Update nushell config, enable fuzzy search for history

### Miscellaneous Tasks

- Update nushell config file
- Update nushell cursor shape config
- Bump version v1.13 for nu v0.75
- Adapt to nu v0.75

## [1.12.0] - 2023-01-13

### Bug Fixes

- Fix mall/redevelop-all.nu script for nu v0.73
- Fix mall/redevelop-main.nu script for nu v0.73
- Fix `emp` command with empty response of working hours or leaving records case
- Fix plugin register for nushell v0.74
- Fix tilde expansion issue for nu v0.75

### Opt

- Optimize plugin register for nu v0.74

## [1.11.0] - 2022-12-26

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

## [1.10.0] - 2022-12-02

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

## [1.9.0] - 2022-09-29

### Miscellaneous Tasks

- Change default history format to sqlit
- Remove protocol for plugin register with nu 0.68.1
- Change `str collect` to `str join` for nu 0.68.2+
- Update bump version custom command

## [1.8.0] - 2022-09-08

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

## [1.7.0] - 2022-07-27

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

# Changelog
All notable changes to this project will be documented in this file.

## [1.6.0] - 2022-06-22

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

## [1.5.0] - 2022-03-26

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

## [1.2.12] - 2022-01-17

### Bug Fixes

- Fix empty working-hours exception for `t emp`

### Documentation

- Add `brew-speed-up` related docs

### Features

- Add feature of checking if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to set much faster brew mirrors quickly

## [1.2.11] - 2022-01-04

### Bug Fixes

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature, make its config compatible with previous version
- Fix force upgrading feature, improve version check strategy

### Features

- Add force upgrade feature, if a force-upgrade version was released all commands will stop running before upgrading termix-nu

### Miscellaneous Tasks

- Add test case in comments for force upgrade feature

## [1.2.10] - 2021-12-31

### Bug Fixes

- Fix emp working hours query while there are leaving records

### Documentation

- Add lock related docs for git auto sync and trigger-sync

### Features

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

### Miscellaneous Tasks

- Bump version v1.2.10

## [1.2.12] - 2022-01-17

### Bug Fixes

- Fix empty working-hours exception for `t emp`

### Documentation

- Add `brew-speed-up` related docs

### Features

- Add feature of checking if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to set much faster brew mirrors quickly

## [1.2.11] - 2022-01-04

### Bug Fixes

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature, make its config compatible with previous version
- Fix force upgrading feature, improve version check strategy

### Features

- Add force upgrade feature, if a force-upgrade version was released all commands will stop running before upgrading termix-nu

### Miscellaneous Tasks

- Add test case in comments for force upgrade feature

## [1.2.10] - 2021-12-31

### Bug Fixes

- Fix emp working hours query while there are leaving records

### Documentation

- Add lock related docs for git auto sync and trigger-sync

### Features

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

### Miscellaneous Tasks

- Bump version v1.2.10

## [1.2.9] - 2021-12-30

### Bug Fixes

- Fix emp query error while there is no leaving record

### Features

- Add local branch existence check for `git-remote-age` command

### Miscellaneous Tasks

- REMOVE unused files
- Update min nushell version to v0.42.0, bump version v1.2.9

## [1.2.8] - 2021-12-23

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

## [1.2.7] - 2021-12-16

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

## [1.2.6] - 2021-12-06

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

- Add global date format constant: _DATE_FMT

## [1.2.5] - 2021-12-02

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

## [1.2.3] - 2021-11-26

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

## [1.2.2] - 2021-11-22

### Bug Fixes

- Fix `upgrade` command for termix-nu: use latest release tag instead of master branch as upgrading source

### Features

- Bump version v1.2.2
- Use `git cliff --output CHANGELOG.md` to generate a change log

### Miscellaneous Tasks

- Update CHANGELOG.md to v1.2.2
- Add changelog create instruction
- Update CHANGELOG.md

## [1.2.1] - 2021-11-22

### Features

- Add `release` command for termix-nu
- Update `check-desc` command: add more branch info to cmd output

### Miscellaneous Tasks

- Fix some code indentions
- Update doc for release command
- Update min nushell version from `0.39.0` to `v0.40.0`

### Refactor

- Refactor `working-hours` command: extract more functions

## [1.2.0] - 2021-11-17

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

## [1.0.0] - 2021-10-12

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
<!-- Generate changelog for specified release: git cliff --unreleased --tag 1.2.1 --prepend CHANGELOG.md  -->
