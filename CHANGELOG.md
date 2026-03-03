# CHANGELOG
All notable changes to this project will be documented in this file.

## v1.99.0 - 2026-03-03

**Bug Fixes**

- Fix case sensitivity and strict `Content-Type` checks in `terp-doctor`
- Fix `t git-branch` on Nu 0.111
- Fix `t git-remote-branch` on Nu 0.111
- Fix `t show-env` on Nu 0.111
- Fix various Git-related commands on Nu 0.111
- Fix the `--all` flag for the `t msync` command
- Fix tests for `diff` and `compare-ver`
- Fix `tests/test-s5cmd.nu`
- Add a CI workflow to run tests automatically
- Attempt to fix Docker image build failures on Nu 0.111

**Features**

- Add `t rgba2h` command to convert RGB colors to hex
- Add metadata tag creation, metadata installation, and cookie-based auth support to `t msync`
- Support creating metadata tags and importing metadata across environments
- Add `tests/test-semver.nu`
- Remove the `--verbose` flag from the `t git-pick` command

**Miscellaneous Tasks**

- Use `$nu.home-dir` for Nu 0.110 compatibility
- Refactor and add a shared `poll-task` helper
- Update `README.md`
- Update `tests/test-compare-ver.nu`
- Update `tests/test-diff.nu`
- Update `tests/test-from-env.nu`

**Refactor**

- Add `utils/iam.nu` and simplify IAM login logic

## v1.98.0 - 2026-01-18

**Bug Fixes**

- Fix `t git-branch -c` flag to correctly handle multi-word arguments
- Add more corner case checks for `t query-deps` command
- Fix `SecondLevelDomainForbidden` error in `t ta` command for certain edge cases
- Fix `t upgrade` command to support more tools and improve robustness
- Improve latest version check by adding default version as fallback
- Fix force upgrade behavior in specific edge cases
- Auto-detect S3 addressing style for `s5cmd` related operations
- Add error checking for `t ta init` command

**Documentation**

- Add shortcut usage tips for `t git-remote-branch` command
- Update artifact deployment documentation

**Features**

- Add geojson data syncing support for `t ta init` command
- Add `--stat` flag to `t ta detect` command
- Show asset statistics in `t ta revert` preview panel

**Miscellaneous Tasks**

- Adapt to Nu 0.110 regarding `$nu` changes
- Add `--help` to `setup-termix.sh` and enhance nu plugin removal
- Refactor `actions/working-hours.nu` and fix potential bugs
- Improve `t ta init` command
- Show less detail for `t ta init` and refactor code

**Performance**

- Optimize performance for `t query-deps` command
- Optimize performance for `t git-remote-branch` command

**Refactor**

- Improve string replacement logic for Nu 0.109.0

## v1.97.2 - 2026-01-05

**Miscellaneous Tasks**

- Update `trantor-artifact-transfer.sh` & fix artifact consume

## v1.97.1 - 2025-12-29

**Bug Fixes**

- Adapt to the new erda auth OpenAPI

## v1.97.0 - 2025-11-28

**Bug Fixes**

- Normalize cherry-pick error detection for `t git-pick` command
- Fix `t gsync` error when local branch is ahead of remote
- Fix `t gsync -l` error when `.termixrc` is not found in `origin/i` branch
- Fix syncing multiple branches for `t gsync` command
- Fix potential bugs in `t git-remote-branch` command
- Exclude main branch from selection in `t git-remote-branch -c`
- Check main branch existence before running `t git-remote-branch -c`

**Documentation**

- Add examples for `t git-remote-branch` command
- Add examples for `t git-pick` and `t rename-branch` commands
- Add examples for `t git-stat` command

**Features**

- Improve auto-resolving conflict messages for `t git-pick` command
- Support branch selection via fzf for `t git-remote-branch -c`
- Add confirmation prompt before deleting branches in `t git-remote-branch -c`
- Enhance remote branch merge detection using git cherry patch-id

**Miscellaneous Tasks**

- Improve error display for `t git-pick` command
- Improve `--list-only` flag behavior for `t git-pick` when no matches found
- Add `rb`, `gb`, and `pa` aliases

**Refactor**

- Refactor `t gsync` command with Claude 4.5
- Refactor `t git-remote-branch` command

**Deps**

- Upgrade `actions/checkout` to v6

## v1.96.0 - 2025-11-08

**Bug Fixes**

- Fix EMP working hours notification
- Enhance `trantor-artifact-transfer.sh` script handling
- Fix potential bugs in `t git-pick` command
- Fix TERP host diagnosis in `t doctor` command

**Features**

- Improve TUI of `t art` command when the operator lacks Trantor2 admin authorization
- Add `t ta revert` command to revert TERP assets, powered by `s5cmd`
- Add `repos.toml` example file
- Automatically resolve lock file conflicts for `t git-pick` command
- Ignore commit messages starting with `skip:` in `t git-pick` command

**Miscellaneous Tasks**

- Add descriptions for `agent` and `agent-mobile` modules

## v1.95.0 - 2025-10-16

**Features**

- Do not sync members by default; use `--sync-member` to enable it for `t erda-transfer`
- Add branch syncing support for `t erda-transfer` command
- Show more details for confirmation before running `t erda-transfer` command

**Bug Fixes**

- Fix potential git repo sync error for `t erda-transfer` command
- Fix EMP working hours query hosts
- Attempt to fix "unexpected disconnect while reading sideband packet" error during branch syncing

## v1.93.1 - 2025-09-16

**Bug Fixes**

- Always renew Erda session for `t erda-transfer` command

## v1.93.0 - 2025-09-15

**Bug Fixes**

- Attempt to fix `t upgrade` error on Windows
- Fix version display for upgraded tools

**Features**

- Add `t erda-transfer` command to transfer apps between Erda projects
- Validate selected app names to ensure they all exist in the source project
- Use `fzf` to select apps to transfer and confirm before transferring
- Validate that the operator has access to all selected apps before transfer
- Support transferring runtime environment variables
- Support transferring pipeline environment variables
- Transfer encrypted environment variables and replace values with placeholders
- Add members in batch mode for `t erda-transfer` command
- Speed up app authorization checks via user permissions API

**Miscellaneous Tasks**

- Update `trantor-artifact-transfer.sh`
- Use AGENTS.md for AI coding instead of CLAUDE.md or .cursor files

**Performance**

- Get Homebrew app versions from API instead of web crawling
- Use `par-each` for app authorization checking
- Improve member addition for `t erda-transfer` command

**Refactor**

- Refactor `sync-env-vars` helper for better readability
- Reduce calls to `get-app-list` API, especially when querying source apps

## v1.92.0 - 2025-09-08

**Bug Fixes**

- Relax JS content-type checking using regex for `t doctor $hosts`
- Fix Nu config checking issue for `t doctor --fix` command
- Fix Trantor artifact consumption for `t art` command
- Fix `tests/test-compare-ver.nu`
- Fix client-copy tests for `s5cmd`

**Features**

- Update `run/trantor-artifact-transfer.sh` to the latest version
- Add `tests/test-s5cmd.nu` tests
- Use forked version of `hustcer/s5cmd` instead of `peak/s5cmd`

**Deps**

- Upgrade `actions/checkout` to v5

## v1.91.0 - 2025-08-12

**Bug Fixes**

- Attempt to fix termix-nu upgrade when branches have diverged
- Fix error in `t git-stat` command
- Add protocol validation for `t doctor $host`
- Fix Nushell config checks for `t doctor` command
- Fix tool installation and upgrades on Ubuntu
- Fix `t git-branch` path positional argument and add usage examples
- Fix bucket validation for `t doctor $host` command
- Fix Nu config checks in `t doctor` command

**Features**

- Show Homebrew-managed tools required by termix-nu
- Add `terp-doctor` to diagnose `terp-assets`
- Add `t doctor ${host}` command
- Add host pattern validation for `t doctor $host` command
- Add CLAUDE.md
- Update `compare-ver` to support comparing semver, including prereleases
- Add `--filter` flag for `t ls-tags` command
- Add asset download and transfer for `ai-assets`
- Add examples for `t msync` command
- Add examples for `t art` command
- Add examples for `t go` and `t query-deps` commands
- Add usage examples for `t ta` command
- Add examples for `t gsync` command
- Add examples for `t tp` and `t dq` commands
- Update `latest.json` checks for `t doctor $host` command
- Add storage provider checks for `t doctor $host` command
- Add frontend module checks for `t doctor $host` command
- Update fix tips for `t doctor $host` command
- Add batch URL check support for `t doctor` command
- Add `latest.json` response status checks for `t doctor` command

**Miscellaneous Tasks**

- Update `t doctor` checking tips
- Show shell responses from `trantor-artifact-transfer.sh`
- Add usage examples for `t pull-all` and `t doctor`; fix `t show-env`
- Add examples for `t ls-tags` and `t ls-node` commands
- Update essential rules and warning tips

**Refactor**

- Fix `open-tools.nu` script for Nu 0.105 and later
- Refactor code for `t doctor $host` command

## v1.90.0 - 2025-07-21

**Bug Fixes**

- Fix `t dp -i` to add `srcBranch` if it differs from the syncing source branch
- Update type checks to use `describe -d` for erda-pipeline ops
- Fix `t doctor` for Nu plugin checking
- Add GitHub token header for fetching nightly releases
- Fix `t go` command for URL finding
- Fix `t msync` command and make `path` optional
- Trim empty mount point or module for `t ta` command
- Improve `run/setup-termix.sh` with `shellcheck`
- Fix getting Nu binary path for Nushell 0.106
- Fix `get-latest-nightly-build` for Nu 0.106

**Features**

- Try using **debian** as the base image for termix-extra
- Install the latest version of `neovim` in termix-extra image
- Add `run/img-check.nu` script
- Use `erdaOpenApiHost` or fall back to `erdaHost` for session renewal in `t art` command
- Use `fzf` to select modules for `t msync` command
- Query available backend modules from Trantor Console for `t msync` command
- Add `monitor` custom command to Nu config
- Attempt to add `s5cmd` installation and upgrade support
- Add `t ta init` command to initialize static assets for TERP
- Add progress indicator for `t ta init` command

**Miscellaneous Tasks**

- Add ACL control to object
- Use the latest Nu for uploading binary dependencies
- Attempt to add a Docker image for runtime
- Fix `fnm` setup for bash
- Use `ansi rst` instead of `ansi reset` for Nu 0.106.0
- Replace `get -i` with `get -o` for Nu 0.106
- Replace `select -i` and `reject -i` for Nu 0.106

**Refactor**

- Extract `enrich-target-data` helper function for `t dp -i` command
- Refactor `t ta` command with Cursor

## v1.89.2 - 2025-06-24

**Bug Fixes**

- Fix plugin registration for Nu 0.106
- Fix `t cr` for Nu 0.105.0

**Features**

- Add support for syncing TERP assets to iFlytek OSS
- Add support for syncing TERP assets to Volcengine OSS

**Miscellaneous Tasks**

- Update `fnm` config for Nu
- Add `with-progress` to Nu config
- Add `simple-pv` helper

## v1.89.1 - 2025-06-16

**Bug Fixes**

- Fix producing and consuming of non-trantor artifacts

## v1.89.0 - 2025-06-11

**Bug Fixes**

- Use `str contains` for nightly tag filtering
- Fix carapace init script for Nu 0.105.0
- Fix `t pull-all` command for Nu v0.105
- Fix `t query-deps` command for Nu v0.105.0

**Features**

- Set default `temperature` to **0.3** for code review
- Add new Trantor artifact consumption support via `t art consume` command

**Miscellaneous Tasks**

- Fix `pretty-oss` output in Nu config
- Add `charts-mobile` description for terp-assets
- Add `run/trantor-artifact-transfer.sh`
- Use `where` instead of `filter` for Nu 0.105
- Increase default `fzf` panel height from 50% to 70%

**Deps**

- Upgrade `nutest` to v1.1.0 for test running

## v1.88.0 - 2025-04-18

**Bug Fixes**

- Fix `EMP` cookie key for man-hour query
- Read default `include` and `exclude` patterns from configuration for code review

**Documentation**

- Update code review documentation for `t cr` command

**Features**

- Add storage type validation for TERP assets syncing
- Add local code review support with **DeepSeek** models via `t cr` command
- Add support for code review of `git show head:path/to/file` command
- Add ability to write code review results to markdown file with `t cr` command
- Add support for code review on specified files using `--paths` flag
- Make system prompt optional, now using user prompt instead for `t cr` command
- Add default settings for `t cr` command

**Miscellaneous Tasks**

- Add DeepSeek code review example configurations
- Update `t ls-node` command and set minimum query version to v18 by default
- Improve error handling to print error messages to `stderr`

**Refactor**

- Implement the new `get-diff` method and remove `AWK` dependency

## v1.87.0 - 2025-03-21

**Bug Fixes**

- Fix `run/setup-termix.sh` setup script in Docker

**Documentation**

- Update README.md

**Features**

- Add support for importing metadata by path or directory
- Add `Dockerfile` to create a Docker image for termix-nu
- Add `docker-compose.yml` example
- Add GitHub workflow to build termix-nu Docker image
- Push Docker image tags according to branch
- Build Docker images for each release tag
- Add support for manually specifying Docker release image tag
- Add Docker image tests for each build

**Miscellaneous Tasks**

- Update rio terminal font config
- Read path from config file for importing metadata by path
- Optimize termix-nu Dockerfile
- Update docker-compose.yml image address
- Add openssl to Alpine Docker image
- Update docker-compose.yml pull policy
- Remove unnecessary Nu plugins

## v1.86.1 - 2025-03-11

**Bug Fixes**

- Fix `run/setup-termix.sh` script
- Fix DingTalk notification for Nu v0.102

**Features**

- Add `--until` option for `git-pick` command

**Miscellaneous Tasks**

- Add `from env` to Nu config file
- Add `parse-semver` to Nu config

## v1.86.0 - 2025-02-05

**Bug Fixes**

- Fix Nushell plugin existence checking for `t doctor` command
- Update `zoxide` init script for Nu v0.102
- Fix `t nu-use-nightly` command for the latest Nu nightly releases
- Fix `t ta` command for Nu v0.102

**Features**

- Add `merged` column to `t git-remote-branch` command
- Add `--clean` flag for `t git-remote-branch` command to remove merged branches
- Add `ignoreHash` config to run Erda pipelines without checking commit hash
- Add Erda interactive batch deploy support for `t dp` command
- Add confirmation before running Erda pipelines for `t dp -i` command
- Refactor semver comparison and add `is-semver` common command

**Miscellaneous Tasks**

- Add fix tip for `t doctor` command
- Fix Nushell config for Nu v0.102

**Performance**

- Use multiple threads to speed up branch info collection for `t git-remote-branch` command

## v1.85.1 - 2024-12-24

**Bug Fixes**

- Fix possible `t doctor` error
- Fix create-snapshot error check for metadata syncing

## v1.85.0 - 2024-12-19

**Bug Fixes**

- Fix table display mode for Nu v0.101.0
- Fix `t emp` command and add staff status checking
- Fix `t git-stat` command for Nu v0.101.0
- Fix `t git-branch` when `i:d.toml` does not exist
- Fix permission error in `t nu-use-nightly` command
- Fix `t nu-use-nightly` for Windows

**Documentation**

- Update README.md

**Features**

- Make `t ta detect` support URLs without `/fe-resources/` in them
- Add `pretty-oss` custom command to Nu config file
- Add `--install` or `-i` flag for `t msync` command for Trantor 2.5.24.0930 and later
- Add `install` field for UploadObjectToOSSTask of Trantor 2.5.24.0930 and later
- Add `fzf` upload support for GitHub workflow
- Add `run/setup-termix.sh` to set up termix-nu without Homebrew
- Make `t upgrade` work for users who installed termix-nu via `setup.nu` or `setup-termix.sh`
- Add `t doctor` command to diagnose and fix termix-nu settings
- Add Nu config directory checking for `t doctor`
- Add macOS version check for `t doctor` command
- Add Nu, just, and fzf outdated checking for `t doctor` command
- Add termix-nu version check for `t doctor` command
- Add package-tools version check for `t doctor` command

**Miscellaneous Tasks**

- Update `t emp` command monthly query output
- Adapt to Nu v0.101 for `++` operator
- Simplify Nushell config for Nu v0.101
- Read minPkgToolVer from termix.toml for `t terp-assets` command
- Update Nu env config

**Deps**

- Upgrade minimum `@terminus/t-package-tools` to v0.5.2

## v1.83.0 - 2024-11-13

**Bug Fixes**

- Fix `t git-pick` for non-origin remote repo source picking

**Features**

- Add `--tag` flag for `t nu-use-nightly` command
- `t gsync` now supports syncing multiple branches separated by `,`

**Miscellaneous Tasks**

- Update EMP man-hour filling DingTalk notification for the new EMP API
- Update Nu config for v0.100.0

**Refactor**

- Adapt to `Nushell` v0.100 by using the new `encode` and `decode base64` commands

## v1.82.2 - 2024-10-23

**Features**

- Support Trantor 0330 for `t msync` command

## v1.82.1 - 2024-10-17

**Miscellaneous Tasks**

- Improve `package-tools` upgrade tip

## v1.82.0 - 2024-10-16

**Breaking Changes**

- Upgrade @terminus/t-package-tools minimum version to 0.5.0 for TERP assets syncing

**Bug Fixes**

- Fix `t go` error for Nu v0.98
- Fix upload-tools.yml workflow
- Fix fzf selection and trim selected item
- Fix bad response check
- Fix metadata syncing for Trantor v2.5.24.0830

**Features**

- Add TERP frontend assets revert command: `t ta revert`
- Add support for reverting TERP frontend modules to Minio
- Improve `t ta revert` command: add revert metadata and display it in detect mode
- Update `t show-env` command to add more info
- Add repo alias argument for `t pull-all` command

**Miscellaneous Tasks**

- Update rio config for v0.16
- Update commit auto-pick tip
- Update kitty and ghostty config
- Adapt to Nushell v0.99
- Update @terminus/t-package-tools to 0.5.0

## v1.81.0 - 2024-09-18

**Bug Fixes**

- Fix base64 encode and decode commands for Nu v0.98.0
- Fix `fzf` history find for Nu
- Fix utils/common.nu and update Nu config for v0.98.0
- Fix `t art` command with `fzf` for Nu v0.98.0
- Fix `t gsync` for Nu v0.98.0
- Fix zoxide for Nu v0.98.0

**Features**

- Make Nu config file work on both macOS and Windows
- Add app artifact consumption support for `t art` command
- Add `gco` to Nu config for checking out git branches with `fzf`
- Add `base32-hash` command to common.nu
- Add `charts` module for `t ta transfer` command

**Miscellaneous Tasks**

- Update Nu config file and minimum just & Nu versions
- Update cursor config for rio v0.1.12
- Update zoxide config

**Performance**

- Improve `nu -c` performance

## v1.80.0 - 2024-08-22

**Bug Fixes**

- Fix `t git-branch` error
- Fix batch deploy and query errors for Nu 0.96+

**Features**

- Add lock feature for Erda deploy
- Add `kitty.conf` for `kitty` terminal
- Add run/color.nu
- Add `--verbose` flag for `t git-pick` command
- Support querying and displaying multiple TERP assets metadata for `t ta detect` command

**Miscellaneous Tasks**

- Update `Nushell` config
- Update `wezterm` config for macOS M1
- Update minNuVer to v0.97.1 and fix grab nu binary commands
- Update minJustVer to 1.33.0

**Performance**

- Improve `http post` performance for `Nu`

**Deps**

- Update `Nu` in GitHub workflow

## v1.79.0 - 2024-06-26

**Bug Fixes**

- Fix version detection in open-tools script

**Features**

- Add `menv` to Nu config
- Add frontend module descriptions for `t ta` command's module selection TUI
- Add `c` command to Nu config for favorite directory jumping
- Hide deprecated field if there are no deprecated items for `t ta detect` command
- Remove `--verbose` and add `--quiet` flag for `t ta` command

**Miscellaneous Tasks**

- Remove deprecated modules for `t ta` command
- Format module selection descriptions for `t ta` command
- Adapt to Nu 0.95 by using `enumerate` instead of `for -n`
- Update minJustVer config
- Extract some FZF constants to common.nu

## v1.78.0 - 2024-05-28

**Breaking Changes**

- Adapt to `Nu` v0.93.1

**Bug Fixes**

- Fix pipeline query detail URL for `t dp` or `t dq` command
- Fix actions/nu-nightly.nu for `Nu` nightly installation

**Features**

- Add `--all` flag to `t git-pick` command to show empty or merged commit picking errors
- Update `t dp` command and add `--override` flag
- Update `t dq` command and add `--override` flag
- Add groups for all available just commands
- Prettify default `just` command output

**Miscellaneous Tasks**

- Add set proxy for Nu tip in `t git-proxy` command
- Update dotfiles/yazi.toml
- Add dotfiles/lazygit.yml
- Update `Nu` config for v0.93.1

## v1.77.3 - 2024-05-18

**Bug Fixes**

- Fix potential artifact preview error
- Fix artifact query and show `createdBy` tip for `t art` command

**Features**

- Update `fzf` theme for better artifact selection and previewing

**Miscellaneous Tasks**

- Update `t git-pick` command: simplify `commitAt` field and add more error detection

## v1.77.2 - 2024-05-14

**Features**

- Add pre-check of `TERMIX_DIR` environment variable to ensure it is set correctly

**Miscellaneous Tasks**

- Register `polars` plugin for `Nu` v0.93
- Change `buildTime` to `buildAt` for `t ta detect` command

## v1.77.1 - 2024-05-06

**Bug Fixes**

- Ensure that app artifact version and project artifact version are different for `t art pack` command

## v1.77.0 - 2024-05-05

**Bug Fixes**

- Fix `t git-pick` abort error

**Features**

- Add `t art pack` command to pack an app artifact into a project artifact
- Add `GIT_PICK_IGNORE` environment config for `t git-pick` command
- Add commits-ahead counter for `t git-pick` command
- Add tip when no matched commits are found for `t git-pick` command
- Add `--ignore-file` flag for `t git-pick` command
- Add `--since` option for `t git-pick` command

**Miscellaneous Tasks**

- Adapt to `Nushell` v0.93.0

## v1.76.0 - 2024-04-28

**Features**

- Add `t git-pick` command to perform `cherry-pick` automatically
- Support transferring static assets to multiple mount points for `t ta transfer` command
- Show failure reason for `t git-pick` command
- Add run/auto-pick.nu script and add successfully picked counter for `t git-pick` command
- Add `resetModuleForInstall` config for `t msync` command
- Display `Trantor` version for `t msync` command

**Bug Fixes**

- Fix static assets metadata syncing for `t ta transfer` command
- Pick commits while preserving the order for `t git-pick` command
- Fix cherry-pick by SHA for `t git-pick` command

## v1.75.1 - 2024-04-23

**Bug Fixes**

- Fix IAM host returned without `https://` error for `t msync` command

## v1.75.0 - 2024-04-22

**Bug Fixes**

- Fix destination URL output of `latest.json` for `t ta transfer` command
- Fix Erda pipeline query and add `Born` status check
- Add task execution status check for `t msync` command
- Add authentication failed tip for `t msync` command
- Fix upgrade check: set force upgrade if any newer version has the force upgrade tag
- Fix backend server error check for `t msync` command

**Documentation**

- Update documentation for `t ta detect` command
- Update documentation for `t msync` command

**Features**

- Add `t ta detect` command to display the overview of frontend modules
- Add user authentication support for `t msync` command
- Add security code parameter for metadata importing
- Add `Trantor2-Team` header for `t msync` command
- Query and set IAM host automatically for `t msync` command

## v1.73.1 - 2024-04-15

**Features**

- Keep static assets module deprecation status for `t ta transfer` command
- Remove module alias from `t ta` command for static assets transfer

## v1.73.0 - 2024-04-15

**Bug Fixes**

- Fix `t ls-tags` when no tag exists locally
- Fix possible Erda pipeline query error
- Fix `t upgrade` when the same tag name exists locally

**Features**

- Update `t pull-all` command and add colorful output for code changes
- Do not ignore new modules while syncing assets for `t ta` command
- Add `--from`, `--to`, and `--summary-only` options to `t git-stat` command
- Add `--json` option to `t git-stat` command
- Update `t ls-node` command and remove `fnm` dependency

**Miscellaneous Tasks**

- Update layout of CHANGELOG.md

## v1.72.1 - 2024-04-07

**Miscellaneous Tasks**

- Use `cd` instead of `enter` to change working directory
- Register plugins for upgrade

**Performance**

- Add `ellie` custom command and start Nu without loading std lib for better performance

## v1.72.0 - 2024-04-03

**Breaking Changes**

- Rename `t desc` to `t git-desc` for git branch description query

**Bug Fixes**

- Fix `WORKDAYS_TILL_MONTH_END` check for `t emp` command

**Features**

- Add `--watch` flag to `t dp` command to watch pipeline status after it starts
- Add `VALIDATE_MODULES` environment switch for `t ta` command to turn off module validation
- Don't validate module names by default for `t ta` command
- Ignore new modules while transferring `all` assets for `t ta` command
- Add total time cost tip for `t ta` command
- Show proxy share address for `t git-proxy` command
- Show commit SHA for `t git-branch` and `t git-remote-branch`
- Show `srcBranch` for `t dp -l` if code syncing config exists

**Miscellaneous Tasks**

- Fix Nu config file indentation and add `yy` command
- Add dotfiles folder

**Refactor**

- Adapt to Nu v0.92.0 by using `print` instead of `echo` to print output to screen

## v1.71.1 - 2024-03-24

**Bug Fixes**

- Fix `t git-stat` command for non-text file changes

**Features**

- Improve `t git-stat` command and add `uniqFileChanged` stat

## v1.71.0 - 2024-03-22

**Features**

- Validate modules before static asset syncing for `t ta` command
- Add `--summary` and `--exclude` flags to `t git-stat` command

**Miscellaneous Tasks**

- Add video casts for TERP assets syncing
- Add Erda pipeline operation related Asciinema casts
- Update README.md and add Asciinema video casts support
- Add hash href for video casts

## v1.70.1 - 2024-03-20

**Bug Fixes**

- Adapt `t art consume` to Nu v0.91

## v1.70.0 - 2024-03-19

**Bug Fixes**

- Fix `t art deploy` for Windows and improve TUI output
- Query latest Erda pipeline records for Nu v0.92
- Fix TERP asset syncing output for Nu v0.92

**Documentation**

- Update README.md for artifact assistant

**Features**

- Remove Nu plugin config file automatically after upgrading Nu
- Add `t artifact` command with `deploy`, `consume`, and `produce` actions supported
- Add artifact helper related configs and arguments
- Confirm deploy order details before execution
- Add custom Erda host support for artifact and pipeline related commands
- Install `fzf` if it doesn't exist for artifact version and deploy group selection
- Add `fzf` upgrade support
- Use `fzf` to select the artifact version to deploy
- Add deploy group selection by fzf with preview support for `t art deploy` command
- Add orgAlias config for artifact assistant
- Add detailUrl to artifact metadata output
- Add support for selecting multiple application groups to deploy with artifact assistant
- Support `t art deploy --combine` which includes produce and consume
- Add `--list` flag to `t art` command
- Support multiple deploy groups separated by comma from settings or input for artifact assistant
- Support login with username and password from settings for artifact assistant

**Miscellaneous Tasks**

- Add casts/produce.cast for `t art produce`
- Add casts/deploy.cast for `t art deploy`
- Add casts/art-consume.cast for `t art consume` command
- Add `asciinema` demos for artifact assistant
- Ensure at most one default is set for source and destination

**Refactor**

- Improve select artifact by `fzf` to deploy feature

## v1.68.1 - 2024-03-06

**Bug Fixes**

- Fix `t ding-msg` to show error details for failed DingTalk notifications
- Fix selection from list by using spread operator instead for Nu v0.91

**Miscellaneous Tasks**

- Update README.md and add Nu installation and upgrade tips
- Update Nushell config to v0.91.0

## v1.68.0 - 2024-02-22

**Bug Fixes**

- Fix `t emp` working hours query for unfilled teams

**Features**

- Add `get help` custom command to Nu config
- Add `--month` flag for `t emp` command to query working hours filling status by month
- Add module selection support for TERP static assets download and sync command: `t ta`
- Add `--watch` flag for `t dq` command to watch a running pipeline by pipeline ID

## v1.67.1 - 2024-02-18

**Bug Fixes**

- Fix `t msync` int to string conversion error after upgrading to `Nu` v0.90.1

## v1.67.0 - 2024-02-07

**Bug Fixes**

- Fix `atAllMinCount` check for `t emp` command
- Fix `t query-deps` command for Windows
- Fix last day check in `t emp-daily` command
- Fix commit metadata extraction algorithm for `t query-deps` command

**Documentation**

- Update documentation for `t git-branch` and `t emp-daily` commands
- Update documentation for `t query-deps` command

**Features**

- Add `WORKDAYS_TILL_MONTH_END` environment variable to specify total workdays until month end for gap calculation
- Add `--contains` flag for `t git-branch` command
- Add `t query-deps` command to query node dependencies in all package.json files from specified branches
- Add `LAST_DAY` and `LASTDAY_MSG` to `t emp-daily` command for holidays
- Add `rc` command to reload Nushell config
- Add `SKIP_UNTIL` environment variable to specify the time to start DingTalk reminding for `t emp-daily` command
- Rename `t trigger-sync` command to `t gsync`
- Add `t desc -a` to show all branch descriptions from the `i` branch

**Miscellaneous Tasks**

- Fix ghostty terminal config

**Refactor**

- Update `t query-deps` and remove usage of `grep` command

## v1.66.0 - 2024-01-29

**Bug Fixes**

- Fix working hours rounding bug for `t emp` command
- Fix query begin and end date calculation for `t emp` command
- Fix @All checking for `t emp-daily` command
- Fix type conversion error for `t gsync -l` command
- Fix working hours polling on Monday for `t emp-daily` command

**Features**

- `t terp-assets` now supports syncing modules by their full name
- `t terp-assets transfer all` will sync all assets registered in `latest.json`
- Display destination latest.json URL after transferring TERP static assets
- Fall back to getting users from API if not configured in `.termixrc` for `t emp` command
- Add `atAllMinCount` option to mention all if the count of mentioned users exceeds the specified count for `t emp` command
- Quit `t emp-daily` scheduled task if all teams have finished filling their working hours

## v1.65.0 - 2024-01-25

**Bug Fixes**

- Fix EMP working hours query and display

**Features**

- Validate user mobile number before sending DingTalk notification for `t emp` command
- Add `--debug` and `--no-ignore` flags to `t emp` command
- Check if all working hours have been filled via `surplusPercentage` response for `t emp` command

**Miscellaneous Tasks**

- Add `Lilex` and `Sarasa Term SC` fonts to terminal configs
- Update online documentation for all refactored commands

**Refactor**

- Add `-h` flag for `ls-node`, `release`, `desc`, `git-branch`, `git-remote-branch`, `rename-branch`, and `repo-transfer` to show help documentation
- Add `-h` flag for `dir-batch-exec`, `git-batch-exec`, and `git-stat` commands to show help documentation
- Refactor `t git-branch` and `t git-remote-branch` and add `--show-tags` flag

## v1.63.0 - 2024-01-22

**Documentation**

- Update documentation for `t brew` and `t upgrade` commands

**Features**

- Install `just` and `nushell` via `brew` on `macOS`
- Add `tuna` mirror support for `t brew` command with `--tuna` flag
- Add `aliyun` mirror support for `t brew` command with `--aliyun` flag

## v1.62.0 - 2024-01-19

**Bug Fixes**

- Allow apps downloaded from anywhere on macOS

## v1.61.0 - 2024-01-18

**Bug Fixes**

- Fix WezTerm config for Nushell installed via Homebrew
- Fix DingTalk Robot Ak&Sk environment key naming to work properly with EMP man-hour filling notification
- Attempt to fix `Nushell` and `just` upgrade for macOS with M-series chips
- Add tip when no EMP config is found for `t emp*` commands

**Features**

- Add `--force` flag to `t upgrade` for force upgrading open source tools

## v1.60.1 - 2024-01-18

**Bug Fixes**

- Fix open source tools upgrade

## v1.60.0 - 2024-01-18

**Bug Fixes**

- Fix latest version check for termix-nu
- Fix Erda pipeline deploy and query for Nu v0.89.1
- Fix open source tools installation on Windows

**Documentation**

- Update documentation for `t upgrade` command
- Update documentation for `t emp` and `t emp-daily` commands

**Features**

- Don't print the result if `--silent` is set for `t emp` command
- Notify members who didn't fill working hours via DingTalk Robot for `t emp -n` command
- Add `EMP_WORKING_HOURS_NOTIFY` environment variable to turn on or off EMP working hours notification via DingTalk Robot
- Add `working-hours-daily-checking` job for EMP working hours notification
- On last day (Monday and month end), keep polling and notify with specified interval for `t emp-daily`
- Add GitHub action to upload the latest version of `nushell` and `just` packages to Aliyun OSS daily
- Add `t upgrade` command to upgrade `nushell`, `just`, or `termix-nu`
- Ignore teams with `ignore = true` in config file for EMP working hours query and notification
- Add `t upgrade --all` command to upgrade `Nushell`, `Just`, and `Termix-nu` all at once

**Miscellaneous Tasks**

- Add config file for `ghostty` terminal (beta)
- Add `publishAt` and `repo` fields to `latest.json` of uploaded open source tools
- Standardize released package names for open tools
- Add upgrade Nu and Just cast

**Refactor**

- Simplify the usage of working hours query via `t emp` command

## v1.55.0 - 2024-01-09

**Features**

- Add initial metadata syncing feature
- Enable importing specified modules for `meta sync`
- Add module selection support for `meta sync`
- Add metadata syncing related configs and validate them before synchronization
- Select and show selected modules before confirmation of metadata syncing
- Require specifying `source` and `destination` if no default source and destination is set for `meta sync`
- Add `teamId`, `teamCode`, and `host` checking for each source and destination before running `meta sync`
- Add `asciinema` casts for metadata syncing operations
- Show git commit SHA in `meta sync` command
- Remove `resetModuleForInstall` parameter for metadata importing
- Add `--list` flag support for `meta sync` command
- Support adding `ddlAutoUpdate` parameter in `.termixrc` config for metadata syncing
- Add `--snapshot` flag to create and upload snapshot of `TERP` metadata without importing
- Add ANSI links to task ID for `t msync` command
- Add tab completion support for `meta sync` command in Nushell REPL
- Add `terp assets` command for static assets synchronization of `TERP`
- Update `terp assets` command and add syncing metadata to `latest.json`
- Add common `progress` custom command

**Bug Fixes**

- Fix default source and destination filter for `meta sync`
- Fix metadata syncing with `--selected` flag
- Handle 500 error properly for the last step of metadata syncing
- Fix `zoxide` init script for Nu v0.89.0
- Fix `just ver` error for unpublished releases
- Fix `nu-use-nightly` command

**Miscellaneous Tasks**

- Adapt `rio` config file to v0.0.33
- Sync documentation from feature/extra
- Adapt boolean flags for Nu v0.89.0
- Update .env-example
- Encode `syncBy` field for `terp-assets` syncing metadata
- Upgrade minimum Nushell and Just versions

**Refactor**

- Refactor `compare-ver` and `is-lower-ver`
- Use readable exit codes with string enums

**Documentation**

- Update documentation for `t msync` (metadata synchronization) command
- Update FAQ.md and CHANGELOG.md
- Update FAQ.md and add `.env` config error case
- Update FAQ.md and add running Erda pipeline failure case

## v1.53.0 - 2023-12-13

**Bug Fixes**

- Fix upsert input parameter for Nu v0.88
- Fix git-diff-commit for Nu v0.88

**Miscellaneous Tasks**

- Add run/cast2gif.nu
- Update Nushell config for v0.88.0

## v1.52.0 - 2023-12-05

**Bug Fixes**

- Fix printing of `pull-all` detailed output
- Fix `trigger-sync` command when no syncing config is available

**Features**

- Add `--repo` flag support for `trigger-sync` command
- Add `--grep` flag for `t dp -l` command

## v1.51.0 - 2023-11-15

**Bug Fixes**

- Fix `git-proxy` error for the latest ClashX version
- Fix commit SHA detection for `just ver` command
- Fix `t go` error for Nu v0.86.1 (should work for Nu v0.86.0)
- Add empty response check for Erda pipeline related commands
- Fix `t nu-use-nightly` for Nu binaries installed via `brew` and add non-aria2c installation support
- Fix `t nu-use-nightly` for Windows

**Documentation**

- Update FAQ.md
- Update README.md and add DingTalk related documentation
- Update README.md
- Add documentation for `git-diff-commit` command

**Features**

- Add `t git-diff-commit` command to show commit info diff between two commits, with grep support for Author, SHA, Date, and Message
- Update `git-diff-commit` command and add `--not-contain`, `--exclude-shas`, and `--exclude-authors` flags
- Add stop pipeline support by running `t dp --stop-by-id 123`
- Add manual link to `t ver` and `t go`
- Add support for sending messages to multiple DingTalk robots
- Add ANSI link for querying latest CICDs
- Add `t nu-use-nightly` private command
- Add empty description tip for `t desc`
- Fetch latest full release for `nu-fetch-latest` in config.nu

**Miscellaneous Tasks**

- Add `nu-fetch-nightly` and `nu-use-nightly` to config.nu
- Update Nu config to nushell/nushell SHA: e8e0526f5
- Update termix-nu documentation

**Refactor**

- Use `par-each` instead of `each` whenever possible for better performance

## v1.50.0 - 2023-10-18

**Bug Fixes**

- Fix `get-tmp-path` for Windows
- Fix hide-env tip for `git-proxy off`
- Fix `gsync -a` error when the remote branch does not exist

**Documentation**

- Add FAQ.md
- Update README.md

**Features**

- Add `get-ip` custom command to Nu config
- Make `TERMIX_TMP_PATH` environment config optional and fall back to `($env.HOME)/.termix-nu`
- Add `dingtalk notify` command to send messages to DingTalk groups via custom robot (see `t ding-msg -h` for more help)
- Add `--force` or `-f` switch to `trigger-sync` command
- Add `trigger-sync -l` to list all branch syncing configs of the current repo
- Add `gsync` as an alias for `trigger-sync`
- Render pipeline ID as a clickable link when querying latest CICDs
- Show the latest pipeline link when querying latest CICDs
- Fetch remote HEAD before running pipelines or syncing branches
- Add description field to available deploy targets for `dp -l`

**Miscellaneous Tasks**

- Adapt to Nu v0.86.0 by using `bool` type for flags
- Update `Nushell` config
- Adapt to Nu v0.86 by using `def --env` instead of `def-env`

**Refactor**

- Change `$nothing` to `null` for Nu v0.86
- Fix some `any` types

## v1.38.1 - 2023-09-20

**Bug Fixes**

- Fix Nushell version check so it does not exit if an update is not required

## v1.38.0 - 2023-09-20

**Features**

- Add `Rio.toml` config file for Rio terminal
- Add `--all(-a)` flag to `trigger-sync` command to sync all local branches that have syncing configs

**Miscellaneous Tasks**

- Use `eza` instead of `exa` in Nu config
- Adapt to Nu v0.85 for `echo` command
- Use `std repeat` instead of string multiply operator
- Update Homebrew environment for Nu config
- Update Nushell config for v0.85
- Set `$env.config.color_config.leading_trailing_space_bg` for Nu v0.85
- Update code formatting

**Refactor**

- Use `reduce` for `build-line` for better compatibility
- Change command naming style

## v1.37.0 - 2023-09-04

**Features**

- Add support for merging quick navs from local `.termixrc` file

**Miscellaneous Tasks**

- Update README.md

## v1.36.0 - 2023-09-01

**Features**

- Renew Erda session automatically if expired using username and password

**Miscellaneous Tasks**

- Update README.md and use build-query for session renewal

## v1.35.0 - 2023-08-30

**Bug Fixes**

- Fix `just upgrade` bug

## v1.33.0 - 2023-08-30

**Bug Fixes**

- Fix git ref checking custom command `has-ref`

**Features**

- Add `symlink` and `unpack` custom commands
- Enable reading `.termixrc` from `termix-nu` directory when running Erda pipelines

**Miscellaneous Tasks**

- Change the proportional UI/title font family for `wezterm` config

## v1.32.0 - 2023-08-23

**Bug Fixes**

- Fix common version comparison algorithm
- Fix `Nushell` installation with dataframe feature

**Chore**

- Update `wezterm` config for Windows

**Features**

- Fix spawn of Nu and launcher menu for `wezterm`
- Add `ua` and `hr-line` custom utilities

**Miscellaneous Tasks**

- Add `wezterm` config file
- Add `atuin` setup for `Nushell` config
- Adapt to Nu v0.84 by changing `date format` to `format date`
- Add ignore as a workaround for unnecessary each output
- Update command palette config for `wezterm`
- Add key mapping config for `wezterm`
- Update `wezterm` key mapping
- Update theme config for `wezterm`
- Add keyboard shortcut to modify tab name
- Update `zoxide` config for Nu 0.83.1
- Update config for `wezterm`
- Update launch menu config for `wezterm`
- Update Nu config: disable date & time display on the right side of prompt
- Update config for `fnm`
- Update comments for some custom commands
- Add `--plugin-only` for `install-all-nu` command
- Update `.termixrc-example`
- Add comments for aliases in Nu config file

**Refactor**

- Adapt to Nu v0.84 and use const and modules where possible

## v1.31.0 - 2023-08-01

**Miscellaneous Tasks**

- Adapt to Nushell v0.82.1
- Fix compare-ver to ignore `-beta` or `-rc` suffix
- Update config and add `install-all-nu` command

**Refactor**

- Use `not` where necessary

## v1.30.0 - 2023-07-10

**Bug Fixes**

- Fix pipeline checking with the same SHA
- Fix pipeline data formatting issue for newly created pipelines
- Fix display of horizontal line
- Fix no CICD data error for query or pre-deploy checking

**Features**

- Add support for deploying or querying multiple apps with local `.termixrc` config
- Print available deploy targets and apps with more details
- Add help tips for `erda-deploy` and `erda-query` commands

**Miscellaneous Tasks**

- Add deploy config for multiple apps
- Adapt to `Nushell` v0.82
- Add `.termixrc-example` config for batch deploy

## v1.28.0 - 2023-07-06

**Features**

- Support querying the latest 10 pipeline running results via `t dq` or `t dq test`, etc.

**Miscellaneous Tasks**

- Add some comments

**Refactor**

- Use modules where possible
- Extract some small custom commands

## v1.27.0 - 2023-07-04

**Bug Fixes**

- Fix the display of git committer for pipeline check

**Features**

- Check if a commit has been deployed before running a new pipeline
- Check remote branch SHA instead of local SHA before running the pipeline

**Miscellaneous Tasks**

- Change column header of running pipelines to title case
- Adapt to Nushell v0.82.1 and above

## v1.26.0 - 2023-07-01

**Bug Fixes**

- Fix version check

**Features**

- Check if there is any running pipeline before starting a new one
- Use `--force` or `-f` to run a pipeline even if one is already running
- Enable setting default value for `deploy` command

**Refactor**

- Code refactoring: extract Erda host variable, etc.

## v1.25.0 - 2023-06-30

**Features**

- Add query deploy targets support via `t dp -l`
- Enable querying pipeline running status from any directory

**Miscellaneous Tasks**

- Bump version to v1.25.0

## v1.23.0 - 2023-06-29

**Bug Fixes**

- Fix pipeline query result return URL

## v1.22.0 - 2023-06-29

**Miscellaneous Tasks**

- Remove unnecessary ERDA_TOKEN environment variable for Erda pipelines

## v1.21.0 - 2023-06-29

**Bug Fixes**

- Ensure origin/i branch exists before deploying or querying pipeline

**Features**

- Add Erda pipeline `run` and `query` feature
- Read Erda pipeline config from `.termixrc` to run CICDs
- Output pipeline detail URL while creating and running it
- Check if pipeline config exists before running it

**Miscellaneous Tasks**

- Add Erda auth environment config examples
- Bump version to v1.21.0
- Fix code indentation for actions/pipeline.nu
- Refactor code

## v1.20.0 - 2023-06-28

**Bug Fixes**

- Remove Nu env patch for issue #9265

**Features**

- Add `nun` custom command to Nu config
- Add `nuc` and `nucc` command aliases for Nushell config

**Miscellaneous Tasks**

- Update config for Nu v0.82 and update quick navs
- Upgrade minimum required Nushell version to v0.82

**Breaking**

- Adapt to Nushell v0.82

## v1.19.0 - 2023-05-23

**Bug Fixes**

- Fix `nudown` command
- Add a small patch for Nushell #9265 issue

**Miscellaneous Tasks**

- Update tags from origin

## v1.18.0 - 2023-05-17

**Features**

- Add some Nu-related custom commands
- Add sort by tag support for `ls-tags` command
- Add `parallel` common helper and `gh-pr` custom command
- Add `topf` to Nu config

**Miscellaneous Tasks**

- Adapt to Nushell v0.78.1+
- Optimize semver comparison algorithm
- Update Nushell config file to v0.79.1
- Fix `exit --now` breaking change for v0.80
- Fix git/remote-branch.nu
- Update minimum Nu version to v0.80

## v1.17.0 - 2023-04-10

**Bug Fixes**

- Fix `git-proxy` for Windows

**Features**

- Add proxy support for v2ray
- Update `git-proxy` command and add ClashX support (works on Mac)
- Add `ls-tags` command
- Hide some rarely used commands (most of them are gaia or gaia-redev related)

**Miscellaneous Tasks**

- Adapt to Nushell v0.78 and set minimum required Nushell version to v0.78
- Adapt to Nu v0.78 and fix `expected operator` error

## v1.16.0 - 2023-03-21

**Bug Fixes**

- Fix str trim for Nu v0.77
- Update `has-ref` git utility helper
- Fix `emp` and `prune-synced-branches` commands

**Miscellaneous Tasks**

- Add ignore patch for Nu v0.76
- Update Nushell config for v0.76.1
- Adapt to Nu v0.77.1+ by using `print` explicitly
- Bump version v1.16.0

## v1.15.0 - 2023-02-23

**Bug Fixes**

- Adapt to Nu v0.75.1+
- Fix `emp` command for Nu v0.76 after dataframe commands changed

**Features**

- Bump to v1.15.0

**Miscellaneous Tasks**

- Update Nu installation command

## v1.13.0 - 2023-02-01

**Bug Fixes**

- Fix HOME environment variable for Windows

**Features**

- Update Nushell config to enable fuzzy search for history

**Miscellaneous Tasks**

- Update Nushell config file
- Update Nushell cursor shape config
- Bump version v1.13 for Nu v0.75
- Adapt to Nu v0.75

## v1.12.0 - 2023-01-13

**Bug Fixes**

- Fix mall/redevelop-all.nu script for Nu v0.73
- Fix mall/redevelop-main.nu script for Nu v0.73
- Fix `emp` command for empty response of working hours or leaving records case
- Fix plugin registration for Nushell v0.74
- Fix tilde expansion issue for Nu v0.75

**Opt**

- Optimize plugin registration for Nu v0.74

## v1.11.0 - 2022-12-26

**Bug Fixes**

- Fix `pull-all` command by using `git branch` instead of `git br`
- Fix config saving for Nu v0.72

**Features**

- Update upgrade tips
- Update Nushell config file and add carapace completer support

**Miscellaneous Tasks**

- Fix config: re-register plugins needed for v0.71+
- Adapt to Nu v0.72
- Update config file for Nu v0.72
- Update minimum Nu version to v0.72 and minimum just version to v1.9; bump version to v1.10.0
- Adapt to Nu version v0.73
- Fix emp command for Nu v0.73
- Bump v1.11.0
- Fix `prune-synced-branches` for Nu v0.73.1

## v1.10.0 - 2022-12-02

**Bug Fixes**

- Fix `pull-all` command by using `git branch` instead of `git br`
- Fix config saving for Nu v0.72

**Features**

- Update upgrade tips

**Miscellaneous Tasks**

- Fix config: re-register plugins needed for v0.71+
- Adapt to Nu v0.72
- Update config file for Nu v0.72
- Update minimum Nu version to v0.72 and minimum just version to v1.9; bump version to v1.10.0

## v1.9.0 - 2022-09-29

**Miscellaneous Tasks**

- Change default history format to sqlite
- Remove protocol for plugin registration with Nu 0.68.1
- Change `str collect` to `str join` for Nu 0.68.2+
- Update bump version custom command

## v1.8.0 - 2022-09-08

**Bug Fixes**

- Fix some variable names for Nu v0.66.1 or above
- Fix `git-remote-branch` command
- Fix error when running `git-proxy off` multiple times
- Fix EMP working hours query

**Features**

- Upgrade mall/redevelop-main.nu script to deploy from generated redevelop source
- Update `tag-redev` and `gaia-release` commands and add enable field filter

**Miscellaneous Tasks**

- Fix plugin registration protocol
- Rename variable names for flags
- Adapt to Nu v0.68

## v1.7.0 - 2022-07-27

**Features**

- Rename `git-age` to `git-branch` and `git-remote-age` to `git-remote-branch`
- Add support for querying working hours from previous week for `emp` command
- Rename `check-desc` to `check-branch` and display removed branches that have syncing configs

**Bug Fixes**

- Fix working hours query and `pull-redev` command for Nu v0.65
- Improve `git-age`/`git-remote-age` and `check-desc` command output
- Improve redevelop-all script: exit if termix exec failed
- Improve redevelop-main script: exit if termix exec failed

**Miscellaneous Tasks**

- Try to use bare string where possible
- Update config for Nu v0.65.1
- Update default config to the latest sample
- Update git branch sorting output when descriptions are not available
- Remove unnecessary brackets where possible
- Upgrade minimum Nu version to v0.66 and minimum just version to v1.3.0; bump to v1.7.0

## v1.6.0 - 2022-06-22

**Bug Fixes**

- Improve redevelop-all script
- Fix mall/redevelop-main.nu
- Update nu-stat script to use `size` instead of `wc`
- Fix EMP auth check for working hours query
- Add code syncing support for branches whose names contain `.`
- Fix `pull-redev` command

**Documentation**

- Add documentation for `git-stat` command

**Features**

- Add `get-locale` related script
- Add mall/upload-locale.nu script
- Add mall/clean-locale.nu script
- Add mall/redevelop-all.nu script
- Add mall/redevelop-main.nu script
- Add run/nu-stat.nu for source line counter for Nushell
- Add `load-direnv` command
- Update zoxide and other configs
- Add multiple team support for `emp` command
- Add `git stat` command to display modification stats for each commit
- Add light theme related config
- Upgrade for Nu v0.64

**Miscellaneous Tasks**

- Adapt to Nushell v0.61.0
- Update config to Nushell v0.61.1

**Refactor**

- Simplify boolean flags for scripts
- Optimize plugin registration for Nushell v0.61.0

## v1.5.0 - 2022-03-26

**Bug Fixes**

- Disable `_check-ver` for `upgrade` command
- Fix bug in semver comparison
- Rename Nu plugins for registration and fix `git proxy` command for Nu 0.60
- Update the new `each` syntax
- Adapt `gaia-release` for Nu v0.59+
- Change boolean flags from string to bool and fix plugin import for Windows
- Fix `git-age`, `git-remote-age`, and `show-env` commands for Windows
- Fix table layout broken for `ls-redev-refs` and `check-desc` on Windows; fix `go` command
- Adapt `emp` command again to v0.59+
- Remove unnecessary hack for Windows by using latest main branch
- Fix `emp` command for Windows with Nu v0.59+
- Use true/false instead of $true/$false and fix `trigger-sync` command
- Adapt `go` and `tag-redev` commands for Nu v0.60
- Update default just file path for Windows and fix `tag-redev` command for Windows
- Fix `prune-synced-branches` command for Windows
- Fix `repo-transfer` and git repo check strategy
- Fix `trigger-sync` and `git sync-branch` commands' lock issue
- Update query EMP working hours related config
- Fix zoxide script
- Adapt to the new `default` syntax
- Ignore repos without access permission for `prune-synced-branches` command
- Update oh-my-posh prompt command
- Remove unnecessary hacks for Windows and fix `trigger-sync` command
- Update `pull-all` command to ignore i branch when possible
- Change capnp to json for plugin registration
- Fix `repo-transfer` issue: output sync messages should be displayed
- Fix `brew-speed-up off` command
- Fix `emp` command

**Features**

- Add pull-all support for local branches ahead of remote
- Add config file for Nu 0.60 and fix `check-desc` command
- Add `!` command for common
- Update termix-nu related documentation
- Add get-icon.nu script for gaia-mobile
- Add mall/upload-image.nu script
- Add mall/compress-image.nu script
- Update config for Nu and add `cargo search` custom command

**Miscellaneous Tasks**

- Update Nushell minimum version check
- Upgrade minimum just version to v0.11.0
- Numerous modifications to adapt to Nushell v0.60
- Adapt to Nu v0.60
- Remove unnecessary print command usage
- Adapt to the latest Nushell
- Update `nu` and `just` versions and fix version check
- Update `release` command
- Update Nu config and fix `go` command
- Remove unnecessary hacks
- Update Nushell config to the latest version
- Update Nushell config file
- Add `#!/usr/bin/env nu` header for each script
- Adapt to the latest Nu syntax and change `update` to `upsert`
- Fix script indentation and refactor by using `into duration`
- Update minimum just and Nu versions required

**Refactor**

- Adapt to Nu v0.60: add log utility and fix Justfile
- Adapt `check-ver` and `quick-nav` commands to Nu v0.60
- Adapt `pull-all` command to Nu 0.60.0 by using $false check instead of empty blocks
- Adapt `tag-redev`, `check-desc`, `desc`, and `repo-transfer` commands to Nu v0.59
- Adapt `emp` command to Nu v0.60
- Adapt `dir-batch-exec` for Nu v0.60
- Some optimization

**Opt**

- Adapt to Nushell next release v0.60
- Adapt `git-proxy`, `trigger-sync`, `sync-branch`, and `release` commands for Nushell v0.60
- Use just to register plugins dynamically for Nushell
- Add common host OS checking command
- Improve get-icon.nu for a better user experience

## v1.2.12 - 2022-01-17

**Bug Fixes**

- Fix empty working-hours exception for `t emp`

**Documentation**

- Add `brew-speed-up` related docs

**Features**

- Add feature of checking if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to set much faster brew mirrors quickly

## v1.2.11 - 2022-01-04

**Bug Fixes**

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature, make its config compatible with previous version
- Fix force upgrading feature, improve version check strategy

**Features**

- Add force upgrade feature, if a force-upgrade version was released all commands will stop running before upgrading termix-nu

**Miscellaneous Tasks**

- Add test case in comments for force upgrade feature

## v1.2.10 - 2021-12-31

**Bug Fixes**

- Fix EMP working hours query when there are leaving records

**Documentation**

- Add lock-related documentation for git auto sync and trigger-sync

**Features**

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

**Miscellaneous Tasks**

- Bump version v1.2.10

## v1.2.12 - 2022-01-17

**Bug Fixes**

- Fix empty working hours exception for `t emp`

**Documentation**

- Add `brew-speed-up` related documentation

**Features**

- Add feature to check if local branch exists in remote repo for `git-age` command
- Add `brew-speed-up` command to quickly set faster Homebrew mirrors

## v1.2.11 - 2022-01-04

**Bug Fixes**

- Fix repo syncing with lock error when the remote branch does not exist
- Fix force upgrade feature to make its config compatible with previous versions
- Fix force upgrade feature and improve version check strategy

**Features**

- Add force upgrade feature: if a force-upgrade version is released, all commands will stop running before upgrading termix-nu

**Miscellaneous Tasks**

- Add test case in comments for force upgrade feature

## v1.2.10 - 2021-12-31

**Bug Fixes**

- Fix EMP working hours query when there are leaving records

**Documentation**

- Add lock-related documentation for git auto sync and trigger-sync

**Features**

- Add lock feature for git auto sync while pushing commits
- Add lock feature for `trigger-sync` command

**Miscellaneous Tasks**

- Bump version v1.2.10

## v1.2.9 - 2021-12-30

**Bug Fixes**

- Fix EMP query error when there is no leaving record

**Features**

- Add local branch existence check for `git-remote-age` command

**Miscellaneous Tasks**

- Remove unused files
- Update minimum Nushell version to v0.42.0; bump version v1.2.9

## v1.2.8 - 2021-12-23

**Bug Fixes**

- Fix error: fatal: could not open '<' for reading: No such file or directory
- Fix repo syncing issue when doing a redirect push like `git push origin a:b`

**Documentation**

- Add `prune-synced-branches` related documentation
- Update documentation for redevelop related commands

**Features**

- Add `prune-synced-branches` command
- Add gap column for EMP working hours stat table
- Add redevelop repos for mbr/brand and point malls
- Add b2b mobile to redevelop repos
- Update redevelop related commands and add grouping support

**Miscellaneous Tasks**

- Change FORCE_PUSH to FORCE for simpler force push
- Use internal `str find-replace` instead of external `tr`

## v1.2.7 - 2021-12-16

**Bug Fixes**

- Fix `check-desc` command when all branches have been described
- Fix some issues for `pull-redev` command
- Fix default command list display issue when another justfile exists in the invoke directory
- Fix `emp` working hours query command for the new EMP

**Documentation**

- Update nav menu in README.md
- Add `git-proxy` related documentation and update `emp` documentation

**Features**

- `check-desc` command now supports checking branches that have a description but were removed from remote
- Add b2c brand site related config
- Add `git-proxy` command (only works when AliLang speed up is enabled)
- Add git proxy status to `show-env` command

**Miscellaneous Tasks**

- Add b2b/srm/mbr repo navs
- Update minimum Nushell version to v0.41.0

## v1.2.6 - 2021-12-06

**Bug Fixes**

- Add temp directory existence check and notify user if it does not exist
- Fix `error: Coercion error` for `sync-branch` and `trigger-sync`

**Documentation**

- Update README.md and add .env and git branch sync related tips

**Features**

- Add source branch name to branch syncing summary table
- Add `trigger-sync` feature for repo syncing and related documentation
- Add `SYNC_IGNORE_ALIAS` to `show-env` output

**Miscellaneous Tasks**

- Add source code counter for each folder or file
- Move temp git.nu to run directory

**Refactor**

- Add global date format constant: _DATE_FMT

## v1.2.5 - 2021-12-02

**Bug Fixes**

- Add repo not exist error handler for `git repo-transfer`

**Documentation**

- Update README.md and add `Just` & `nu` upgrade check related documentation
- Reorder command documentation
- Improve documentation

**Features**

- Add minimum just version check and add warning tips to upgrade just if required
- Add source repo release new version support via `gaia-release` command
- Add latest termix-nu version check support
- Add git repo transfer feature via `git repo-transfer` command
- Improve `git-age` command and add last commit author name

**Refactor**

- Change `REDEV_REPO_PATH` to `TERMIX_TMP_PATH` in .env config, and `redevRepoPath` to `termixTmpPath` in TOML config
- Add $TERMIX_CONF constant and get-tmp-path helper
- Use `path join` instead of string concatenation
- Move redev related scripts from git to actions directory

## v1.2.3 - 2021-11-26

**Bug Fixes**

- Fix `check-desc` command: fetch remote before checking
- Fix CHANGELOG.md commit message
- Update pre-push hook demo in README file and fix for remote branch deletion
- Ignore code syncing when remote branch of origin does not exist
- Fix `rename-branch` command source branch check

**Documentation**

- Update recipes list in README.md
- Format documentation with Prettier
- Update README.md

**Features**

- Update CHANGELOG.md automatically for `release` command
- Add switch to update CHANGELOG.md and update `release` command related documentation
- Change branch description file from JSON to TOML format for `desc` related commands
- Add URL nav alias anchor for README.md
- Add force push support for branch syncing
- Use remote branch syncing config instead of local
- Add web nav URL output support in terminal for branch syncing
- Add code syncing .env config `SYNC_IGNORE_ALIAS` to ignore syncing for some repos
- Add support for reading config from origin/i branch

**Miscellaneous Tasks**

- Remove unused termix config for macCliApps

**Refactor**

- Add `get-conf` common helper in utils/common.nu

## v1.2.2 - 2021-11-22

**Bug Fixes**

- Fix `upgrade` command for termix-nu: use latest release tag instead of master branch as upgrade source

**Features**

- Bump version v1.2.2
- Use `git cliff --output CHANGELOG.md` to generate a changelog

**Miscellaneous Tasks**

- Update CHANGELOG.md to v1.2.2
- Add changelog creation instructions
- Update CHANGELOG.md

## v1.2.1 - 2021-11-22

**Features**

- Add `release` command for termix-nu
- Update `check-desc` command: add more branch info to command output

**Miscellaneous Tasks**

- Fix some code indentation
- Update documentation for release command
- Update minimum Nushell version from `0.39.0` to `v0.40.0`

**Refactor**

- Refactor `working-hours` command: extract more functions

## v1.2.0 - 2021-11-17

**Bug Fixes**

- Fix git age and remote age date display
- Fix git-remote-age git check issue
- Fix git check on Windows
- Fix empty check for working hours
- Fix weekday calculation for working hours
- Improve join after upgrading just to v0.10.3
- Add invalid login info check for working hours
- Update tag-redev command
- Find navs from key only
- Fix open quick nav for Windows
- Fix check-desc

**Features**

- Add mall related scripts
- Add git repo tags display support
- Add latest Nushell version check
- Add git command and git repo check
- Add redevelop branches display support
- Update README.md documentation
- Update README.md and add `working-hours` script
- Add EMP working hours script
- Add LTS support for `ls-node`
- Update documentation
- Update emp
- Add just upgrade feature
- Add view git branch description command
- Add `just go` command for quick navigation
- Update README.md and add sync-branch documentation
- Update EMP documentation
- Add `just check-desc` command
- Bump version v1.2.0

**Miscellaneous Tasks**

- Change command name for rename branch
- Update emp query command
- Bump version to v1.1.0
- Fix some code indentation

**Refactor**

- Refactor quick-nav command

**Opt**

- Add has-ref utilities
- Refactor show nav items

## v1.0.0 - 2021-10-12

**Bug Fixes**

- Fix git/remote-age.nu
- Git pre-push hooks now work!
- List remote tags and sort by creator date
- Update path for Windows
- Fix just invocation directory
- Update justfile for Windows compatibility
- Update justfile: all works on macOS
- Use open and save instead of bat for Windows
- Fix dir-batch-exec
- Fix justfile for empty args or args with spaces
- Add command availability check
- Fix pull-redev script
- Fix ls-redev-tags for Windows
- Fix ls-redev-tags sort by tag version for Windows
- Update pull-redev script
- Update git branch rename

**Features**

- Add `git-age` command to show local branch age information
- Add `pull-all` command to update all local branches to the latest commit
- Add `git-remote-age` command to show all remote branch info
- Add `ls-redev-tags` to show all tags for redevelop repos
- Add `show-env` to show local environment information
- Add `ls-node` to query node versions
- Add `pull-redev` to pull the latest commit for all redevelop repos
- Add `tag-redev` to create tags for redevelop repos
- Add `git-sync-branch` for git branch syncing support
- Add `git-batch-exec` to execute custom commands for specified branches
- Add `dir-batch-exec` to execute custom commands for specified directories
- Add branch selection for redev repo operations
- Update sync command
- Add git alias and config script
- Add .env example file
- Add custom shell support for git-batch-exec
- Update dir-batch-exec and add custom shell support
- Use bat instead of cat for Windows compatibility
- Add REDEV_REPO_PATH config in .env
- Add show version and env command related scripts
- Add merge performance
- Add Nu config init script
- Add query node version support
- Add actions/setup-mac.nu script; rename actions.toml to termix.toml
- Add soft link example for Windows
- Add version command to show termix-nu version
- Add git rename remote branch feature

**Miscellaneous Tasks**

- Refactor commands
- Change ls-remote-tag to ls-redev-tag
- Remove unnecessary semicolons and echo

**Refactor**

- Optimize branch syncing for pre-push hooks by using query JSON instead of table
- Add common helper for utilities
- Change some file directories

**Opt**

- Use structured redevRepos config for redev related commands
- Enable common utilities script sharing
- Refactor show-env and add get-ver and get-env helpers
- Refactor script calling to use source in some cases
- Refactor code to use source and then call commands
- Refactor git/git-batch-exec.nu to use source instead of script concatenation
- Update dir-batch-exec action to use source instead of file concatenation

**Update**

- Use bash instead of Nu for user-specified commands

<!-- generated by git-cliff -->
<!-- Generate new changelog: `git cliff --output CHANGELOG.md` -->
<!-- Generate changelog for specified release: git cliff --unreleased --prepend CHANGELOG.md --tag 1.80.0  -->
