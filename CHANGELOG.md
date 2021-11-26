# Changelog
All notable changes to this project will be documented in this file.

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
- Remove unnecessary semicoln and echo

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
