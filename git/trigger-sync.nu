#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/06 19:50:20
# Usage:
#   Manually trigger code syncing to all related dests for specified branch
#   just trigger-sync
#   just trigger-sync -a
#   just trigger-sync feature/latest

use ../utils/git.nu [get-sync-ref do-sync]
use ../utils/common.nu [ECODE get-conf get-env has-ref hr-line]

# Constants
const CONFIG_FILE = '.termixrc'
const DEFAULT_CONF_BRANCH = 'i'
const SYNC_MARK = { ignored: '   x', synced: '   √' }

export-env {
  $env.config.table.mode = 'light'
  # FIXME: 去除前导空格背景色
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
}

# Manually trigger code syncing to all related dests for specified branch
@example '触发当前分支的代码同步' {
  t gsync
} --result '更新当前分支并根据 .termixrc 的 branches 配置同步到各目标仓库'
@example '触发指定分支的代码同步' {
  t gsync feature/latest
} --result '先更新远程最新提交到本地再同步该分支到配置的目的仓库'
@example '强制同步 feature/sync 分支(等效于 git push -f)' {
  t gsync feature/sync -f
} --result '以强制推送策略同步到目标仓库，如果没有指定分支名则代表当前分支'
@example '列出所有已配置的分支同步信息' {
  t gsync -l
} --result '显示 Source/Dest/Repo/Lock 与 SYNC 状态以及其他信息'
@example '批量同步所有有同步配置的分支' {
  t gsync -a
} --result '对所有存在同步配置且本地存在的分支依次执行代码同步，同步前会先更新代码到最新提交'
@example '将分支同步到指定仓库(忽略分支同步配置)' {
  t gsync release/2.5.23.1116 -r terp-rls
} --result '直接将该分支推送到指定仓库的同名分支'
export def 'git trigger-sync' [
  branch?: string,    # Local git branch/ref to push
  --all(-a),          # Whether to sync all branches that have syncing config
  --list(-l),         # List all branches that have syncing config
  --repo(-r): string, # Specify which repo to sync to, and ignore the branch syncing config
  --force(-f),        # Whether to force sync even if refused by remote
] {
  cd $env.JUST_INVOKE_DIR
  let current = git branch --show-current | str trim
  let branches = parse-branches $branch $current
  validate-branches $branches

  let ignored = get-env SYNC_IGNORE_ALIAS ''
  let conf = get-push-config $current --all=$all | get pushConf
  let repos = $conf | query json 'repos' | default {}
  let allSyncs = $conf | query json 'branches' | default {}

  if $list {
    match ([$repos $allSyncs] | all {|it| ($it | is-empty)}) {
      true => {
        print -e $'(ansi y)No sync configuration found in ($CONFIG_FILE). Please add [repos] and [branches] sections.(ansi rst)'
        exit $ECODE.SUCCESS
      }
      false => {
        show-available-syncs $allSyncs --repos $repos --ignored $ignored
        exit $ECODE.SUCCESS
      }
    }
  }

  let candidates = select-candidates $all $allSyncs $branches
  show-sync-plan $candidates

  for branch in $candidates {
    update-branch $branch
    sync-branch $branch --all=$all --ignored $ignored --repo $repo --force=$force
  }
}

# Parse and normalize branch names from input
def parse-branches [
  branch: any,      # Branch input string (nullable)
  current: string,  # Current branch name
]: nothing -> list<string> {
  match ($branch | is-empty) {
    true => [$current]
    false => ($branch | str trim | split row ',')
  }
}

# Validate that all branches exist
def validate-branches [branches: list<string>] {
  let invalid = $branches | where {|it| not (has-ref $it)}
  match ($invalid | is-not-empty) {
    false => {}
    true => {
      print -e $'Branch (ansi r)($invalid | str join ,)(ansi rst) does not exist, please check it again.'
      exit $ECODE.INVALID_PARAMETER
    }
  }
}

# Select candidate branches based on sync mode
def select-candidates [
  all: bool,        # Whether to sync all configured branches
  allSyncs: any,    # All sync configurations
  branches: list,   # User-specified branches
]: nothing -> list {
  match $all {
    false => $branches
    true => ($allSyncs | columns | where {|it| has-ref $it })
  }
}

# Display sync plan if multiple branches
def show-sync-plan [candidates: list] {
  if ($candidates | compact -e | length) > 1 {
    print 'The following branches will be synced:'
    hr-line
    print $candidates
  }
}

# Show All available branch syncing configs with a readable output
def show-available-syncs [
  syncs: record,          # All available branch syncing configs
  --repos: record,        # All available repos
  --ignored(-i): string,  # 代码同步需要忽略推送的仓库简称，多个仓库用英文逗号分隔
] {
  match ($syncs | is-empty) {
    true => {
      print -e $'(ansi y)No branch syncing configuration found in ($CONFIG_FILE).(ansi rst)'
      print -e $'(ansi y)Please add [branches] section with sync rules.(ansi rst)'
    }
    false => {
      print $'(char nl)The following branches have code syncing config:'; hr-line -b
      let results = build-sync-status-table $syncs $ignored
      $results | sort-by Source | print

      print $'(char nl)REPO INFO:'; hr-line
      match ($repos | is-empty) {
        false => { $repos | table -e | print }
        true => { print -e $'(ansi y)No repositories configured in [repos] section.(ansi rst)' }
      }
      print (char nl)
    }
  }
}

# Build sync status table from configurations
def build-sync-status-table [
  syncs: record,    # All sync configurations
  ignored: string,  # Ignored repo aliases
]: nothing -> table {
  $syncs | columns | each {|branch|
    $syncs | get $branch | each {|dest|
      create-sync-status-row $branch $dest $ignored
    }
  } | flatten
}

# Create a single sync status row
def create-sync-status-row [
  branch: string,   # Source branch name
  dest: record,     # Destination configuration
  ignored: string,  # Ignored repo aliases
]: nothing -> record {
  let is_ignored = $',($ignored),' =~ $',($dest.repo),'
  {
    Source: $branch
    Dest: $'--->  ($dest.dest)'
    Repo: $dest.repo
    Lock: ($dest | get -o lock | default '-')
    SYNC: (match $is_ignored { true => $SYNC_MARK.ignored, false => $SYNC_MARK.synced })
    Local: (match (has-ref $branch) { true => $SYNC_MARK.synced, false => $SYNC_MARK.ignored })
    Remote: (match (has-ref $'origin/($branch)') { true => $SYNC_MARK.synced, false => $SYNC_MARK.ignored })
    Update: (match (has-ref $'origin/($branch)') {
      false => null
      true => (git show $'origin/($branch)' --no-patch --format=%ci | into datetime)
    })
  }
}

# Update local branch from remote
def update-branch [branch: string] {
  match (has-ref $'origin/($branch)') {
    false => {
      # Remote branch does not exist, push local branch
      git push origin $branch -u; return
    }
    true => {
      update-branch-from-remote $branch
      let diff = get-branch-diff $branch
      # If local branch is ahead, push to trigger batch sync
      match ($diff.remote == 0 and $diff.local > 0) {
        false => {}
        true => { git push origin $branch; return }
      }
    }
  }
}

# Update branch from remote origin
def update-branch-from-remote [branch: string] {
  let current = git branch --show-current | str trim
  match ($current == $branch) {
    true => { git pull origin $branch }
    false => {
      # For non-current branch: fetch then force update local ref
      git fetch origin $branch
      let diff = get-branch-diff $branch
      # Only update local branch if it is strictly behind remote (fast-forward)
      if $diff.local == 0 and $diff.remote > 0 {
        git update-ref $'refs/heads/($branch)' $'refs/remotes/origin/($branch)'
      }
    }
  }
}

# Get branch diff status (ahead/behind counts)
def get-branch-diff [branch: string]: nothing -> record {
  git rev-list --left-right $'($branch)...origin/($branch)' --count
    | detect columns -n
    | rename local remote
    | update local { into int }
    | update remote { into int }
    | first
}

# Get push configuration from .termixrc
def get-push-config [
  branch: string,   # Local git branch/ref to push
  --all(-a),        # Whether to sync all branches that have syncing config
]: nothing -> record {
  let confBr = resolve-config-branch $branch $all
  validate-config-branch $confBr
  # Fetch latest commit from config branch
  git fetch origin $confBr -q
  # Try to get .termixrc file content
  let configContent = do -i { git show $'origin/($confBr):($CONFIG_FILE)' } | complete

  match ($configContent.exit_code != 0) {
    true => {
      print -e $'(ansi r)Error: ($CONFIG_FILE) file not found in branch (ansi y)origin/($confBr)(ansi rst)'
      exit $ECODE.MISSING_DEPENDENCY
    }
    false => {
      let pushConf = try {
        $configContent.stdout | from toml | to json
      } catch {
        print -e $'(ansi r)Error: Failed to parse ($CONFIG_FILE) file. Please check TOML syntax.(ansi rst)'
        exit $ECODE.INVALID_PARAMETER
      }
      { pushConf: $pushConf, confBr: $confBr }
    }
  }
}

# Resolve which branch to get configuration from
def resolve-config-branch [
  branch: string,  # Current branch
  all: bool,       # Batch sync mode
]: nothing -> string {
  match $all {
    true => $DEFAULT_CONF_BRANCH
    false => {
      let useConfBr = get-conf useConfFromBranch
      match $useConfBr { '_current_' => $branch, _ => $DEFAULT_CONF_BRANCH }
    }
  }
}

# Validate that config branch exists in remote
def validate-config-branch [confBr: string] {
  match (has-ref $'origin/($confBr)') {
    true => {}
    false => {
      print $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi rst)...(char nl)'
      exit $ECODE.SUCCESS
    }
  }
}

def sync-branch [
  branch: string,         # Local git branch/ref to sync
  --all(-a),              # Whether to sync all branches that have syncing config
  --ignored(-i): string,  # 代码同步需要忽略推送的仓库简称，多个仓库用英文逗号分隔
  --repo(-r): string,     # Specify which repo to sync to, and ignore the branch syncing config
  --force(-f),            # Whether to force sync even if refused by remote
] {
  let pushConf = get-push-config $branch --all=$all
  let confBr = $pushConf.confBr
  let pushConf = $pushConf.pushConf

  let dests = resolve-sync-destinations $branch $repo $pushConf
  match ($dests == null) {
    true => { return }
    false => {
      let syncDests = add-sync-status $dests $branch $ignored
      match ($syncDests | is-empty) {
        true => { return }
        false => {
          print-sync-header $repo $confBr
          print-sync-dests $syncDests
          perform-sync $syncDests $branch $pushConf $force
        }
      }
    }
  }
}

# Resolve sync destinations based on branch and repo config
def resolve-sync-destinations [
  branch: string,   # Branch to sync
  repo: any,        # Specific repo (nullable)
  pushConf: any,    # Push configuration
]: nothing -> any {
  let escapedBranch = $branch | str replace -a '.' '\.'
  match (not ($repo | is-empty) and ($repo in ($pushConf | query json 'repos'))) {
    true => [ { repo: $repo, dest: $branch } ]
    false => ($pushConf | query json $'branches.($escapedBranch)')
  }
}

# Add sync status marks to destinations
def add-sync-status [
  dests: list,      # Destination configs
  branch: string,   # Source branch
  ignored: string,  # Ignored repos
]: nothing -> list {
  $dests
    | insert SYNC {|d|
        match ($',($ignored),' =~ $',($d.repo),') {
          true => $SYNC_MARK.ignored
          false => $SYNC_MARK.synced
        }
      }
    | insert source $branch
    | move source --before dest
    | sort-by SYNC
}

# Print sync operation header
def print-sync-header [
  repo: any,        # Specific repo (nullable)
  confBr: string,   # Config branch
] {
  match ($repo | is-empty) {
    false => { print $'(char nl)Going to sync to (ansi g)($repo)(ansi rst) specified by `--repo`:(char nl)' }
    true => { print $'(char nl)Found the following matched dests from (ansi g)`origin/($confBr):($CONFIG_FILE)`(ansi rst):(char nl)' }
  }
}

# Print sync destinations table
def print-sync-dests [syncDests: list] {
  $syncDests
    | insert lock {|it| $it | get -o lock | default '-' }
    | move lock --before SYNC
    | print
}

# Perform sync operations for all enabled destinations
def perform-sync [
  syncDests: list,  # Prepared sync destinations
  branch: string,   # Source branch
  pushConf: any,    # Push configuration
  force: bool,      # Force sync flag
] {
  $syncDests
    | where SYNC == $SYNC_MARK.synced
    | each {|iter|
        let syncFrom = get-sync-ref $branch $iter
        match ($syncFrom | is-empty) {
          true => { }
          false => {
            let gitUrl = $pushConf | query json $'repos.($iter.repo).git'
            let navUrl = $pushConf | query json $'repos.($iter.repo).url'
            do-sync $syncFrom $gitUrl $iter --force-sync $force

            match ($navUrl != '' and $syncFrom != null) {
              false => {}
              true => {
                print $'You can check the result from: (ansi g)($navUrl)(ansi rst)'; hr-line
              }
            }
          }
        }
      }
    | ignore # FIXME: remove ignore after `each` bug fixed
}

alias main = git trigger-sync
