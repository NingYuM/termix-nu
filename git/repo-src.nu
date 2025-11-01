#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/10/29 10:06:52
# Description: A tool to handle frontend repositories
# [√] 列出所有 URL 为空的仓库及其维护者信息
# [√] 遍历生成所有阿里云 OSS 上的 GitLab Backup 仓库，生成仓库清单并保存为 JSON 文件
# [√] 生成文件清单
# [√] 提供统一源码下载工具，生成包含所有指定版本 npm 包的源码包
# [√] 如果没有源码仓库并且 srcPublished 为 true，则直接从 npm 包中下载源码
# [√] 为各 Multi Repo NPM 包的每一个发布版本生成 TAG, 不影响已有 Tag，考虑多分支情况
# [√] 为各 Mono Repo NPM 包的每一个发布版本生成 TAG, 不影响已有 Tag，考虑多分支情况
# [ ] 创建一个总的压缩包，包含所有源码包和清单文件
# [ ] 将源码包上传到公司 OSS，并提供下载链接？
# [ ] 提供工具检查 npm 包发布产物里面是否包含源码
# Usage:
#   - Format repos.toml: open repos.toml | update repos { sort-by repo } | save -f repos.toml
#   - Step1: Update repos.toml with the latest repo information
#   - Step2: Run prepare-repo-tags to create tags for all downloadable and untagged repositories
#   - Step3: Run download-all-src-pkgs to download all source code packages

use ../utils/common.nu [ECODE get-tmp-path hr-line has-ref]
use ../utils/erda.nu [ERDA_HOST, get-erda-auth, renew-erda-session]

# 最大连续失败次数, 超出则停止为该包创建 Tag
const MAX_FAILURE = 15

# 列出所有 URL 为空的仓库及其维护者信息
export def get-repo-maintainers [--show-maintainers(-m)] {
  let empties = open repos.toml
    | get repos
    | where {|it| $it.url? | is-empty }

  $empties | print; print -n (char nl)
  if not $show_maintainers { return }
  $empties | each {|it|
    print $'(ansi g)($it.name)(ansi rst)'; hr-line 60;
    print $'(ansi g)Maintainers:(ansi rst)'
    # 使用 --json 让 npm 输出 JSON，再 from json 转成结构化数据，避免 byte stream
    let raw = (npm view --json $it.name maintainers)
    let parsed = (try { $raw | from json } catch { [] })
    $parsed | to yaml | print
  }
}

# 列出所有 GitLab 仓库及其内容，保存为 JSON 文件
export def list-gitlab-repos [] {
  mut repos = {}
  let projects = ossutil ls -i $env.OSS_AK -k $env.OSS_SK oss://($env.OSS_BUCKET)/repositories/ -d | lines | drop 3
  for p in $projects {
    let r = ossutil ls -i $env.OSS_AK -k $env.OSS_SK $p -d | lines | drop 3
    $repos = $repos | upsert $p $r
  }
  $repos | to json | save -rf tmp/gitlab-repos.json
}

# Clone a repository and pull all branches and tags
@example 'Clone a repository and pull all branches and tags' {
  clone-repo https://erda.cloud/terminus/dop/t-erp/a.git
} --result 'Clone the repository and pull all branches and tags'
export def --env clone-repo [repo: string] {
  let tmpPath = get-tmp-path
  let repoName = $repo | path basename
  let repoPath = $tmpPath | path join $repoName

  cd $tmpPath
  print $'Cloning repository: (ansi g)($repo)(ansi rst)(char nl)'
  if not ($repoPath | path exists) {
    git clone $repo $repoPath
  }
  cd $repoPath
  # Ensure local repository mirrors remote branches and tags
  git fetch --all --tags --prune

  # Create local tracking branches for all remote branches without overwriting existing ones
  let remoteBranches = (try { git branch -r | lines | each { str trim } | where {|l| not ($l | str contains '->') } } catch { [] })
  for rb in $remoteBranches {
    let branch = ($rb | split row '/' | skip 1 | str join '/')
    if ($branch | is-empty) or ($branch == 'HEAD') { continue }
    let exists = (try { git show-ref --verify --quiet $'refs/heads/($branch)'; true } catch { false })
    if not $exists {
      try {
        git branch --track $branch $rb
        print $'(ansi g)✓(ansi rst) Tracking branch created: ($branch)'
      } catch {|e|
        print $'(ansi y)WARNING:(ansi rst) Failed to create tracking for ($branch): ($e.msg)'
      }
    }
  }
}

# Calculate missing tags for a package
def get-missing-tags [pkg: record] {
  let releases = npm info $pkg.name time --json | from json | reject created modified
  let versions = $releases | columns | where $it !~ 'alpha'
  let tags = git tag -l | lines | each { str trim }
  let hasV = $tags | any {|t| $t | str starts-with 'v' }
  # Normalize existing tags to versions: supports '1.2.3', 'v1.2.3', '@scope/name@1.2.3'
  let existingVers = ($tags | each {|t|
    let plain = ($t | str trim -c v)
    if ($plain =~ '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)') { $plain } else {
      if ($t | str contains '@') {
        let last = ($t | split row '@' | last)
        let cleaned = ($last | str trim -c v)
        if ($cleaned =~ '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)') { $cleaned } else { null }
      } else { null }
    }
  } | compact)
  let missingTags = $versions | where $it not-in $existingVers
  let missingTags = if $hasV { $missingTags | each {|it| $'v($it)' } } else { $missingTags }
  $missingTags
}

# Create tags for a multi-repo package
# 创建 Tag 的过程：
#   - 根据已经发布的版本计算缺失的 Tag，已完成
#   - 使用 git 命令分析 package.json 文件的变更记录，找出版本变更的 Commit hash, 然后从这个 Commit hash 创建 Tag，备注信息为: `A new release Tag for version: ($tagName) created by termix-nu`
#   - 切记：不要修改或者删除仓库里面先前已经有的 Tag
export def create-tag-for-multi-repo [pkg: record] {
  print $'(char nl)(ansi c)Creating tags for multi repo: (ansi rst) (ansi g)($pkg.name)(ansi rst)'; hr-line
  let missingTags = get-missing-tags $pkg

  print $'(ansi c)Package:(ansi rst) (ansi g)($pkg.name)(ansi rst)'
  print $'(ansi c)Missing tags:(ansi rst) ($missingTags | length)'

  # 为每个缺失的 Tag 创建标签
  mut failed = 0
  for tag in ($missingTags | enumerate) {
    let idx = $'#($tag.index + 1)'
    let version = $tag.item | str trim -c v
    # 获取所有修改 package.json 的 commits，然后检查每个 commit 的版本号
    let allCommits = try { git log --all --format=%H -- package.json | lines } catch { [] }

    # 找到版本号匹配的最后一个 commit
    let commitHash = $allCommits | each {|commit|
      let content = try { git show $'($commit):package.json' | from json } catch { { version: "" } }
      if $content.version? == $version { $commit } else { null }
    } | compact

    if ($commitHash | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) No commit found for version ($version) ($idx) ...'
      $failed = $failed + 1
      if $failed > $MAX_FAILURE {
        print $'(ansi r)ERROR:(ansi rst) Too many consecutive failures. Stop creating tags for this package.'
        break
      }
      continue
    }

    let commitHash = $commitHash | last
    let message = $'A new release Tag for version: ($tag.item) created by termix-nu'

    try {
      git tag -a $tag.item $commitHash -m $message; $failed = 0
      print $'(ansi g)✓(ansi rst) Created tag ($tag.item) at commit ($commitHash | str substring 0..7) ($idx) ...'
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to create tag ($tag.item): ($e.msg) ($idx) ...'
    }
  }

  { name: $pkg.name, missingTags: $missingTags }
}

# Create tags for a mono-repo package
export def create-tag-for-mono-repo [pkg: record] {
  print $'(char nl)(ansi c)Creating tags for mono repo: (ansi rst) (ansi g)($pkg.name)(ansi rst)'; hr-line
  let missingTags = get-missing-tags $pkg

  print $'(ansi c)Package:(ansi rst) (ansi g)($pkg.name)(ansi rst)'
  print $'(ansi c)Missing tags:(ansi rst) ($missingTags | length)'
  let pkgFile = $pkg.pkgFile?
  let standalone = $pkg.standalone? | default false

  # 为每个缺失的标签创建标签
  mut failed = 0
  for tag in ($missingTags | enumerate) {
    let idx = $'#($tag.index + 1)'
    let version = $tag.item | str trim -c v
    let newTag = $'($pkg.name)@($version)'
    if (has-ref $newTag) {
      print $'(ansi y)INFO:(ansi rst) Tag ($newTag) already exists, skip ($idx) ...'
      continue
    }

    # 获取所有修改 package.json 的 commits
    let allCommits = if ($pkgFile | is-not-empty) {
      try { git log --all --format=%H -- $pkgFile | lines } catch { [] }
    } else {
      print $'(ansi y)WARNING:(ansi rst) No pkgFile specified for package: ($pkg.name) ($idx) ...'
      []
    }

    # 找到版本号匹配的最后一个 commit
    let commitHash = $allCommits | each {|commit|
      let content = if ($pkgFile | is-not-empty) {
        try { git show $'($commit):($pkgFile)' | from json } catch { { version: "" } }
      } else {
        { version: "" }
      }
      if $content.version? == $version { $commit } else { null }
    } | compact

    if ($commitHash | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) No commit found for version ($version) ($idx) ...'
      $failed = $failed + 1
      if $failed > $MAX_FAILURE {
        print $'(ansi r)ERROR:(ansi rst) Too many consecutive failures. Stop creating tags for this package.'
        break
      }
      continue
    }

    let commitHash = $commitHash | last
    # 检查该提交修改的文件，若修改了多个 /package.json 则使用版本标签，否则使用 name@version 标签
    let changedFiles = try { git diff-tree --no-commit-id --name-only -r $commitHash | lines } catch { [] }
    let pkgJsonChangedCnt = $changedFiles | where {|p| $p | str ends-with '/package.json' } | length
    let finalTag = if $pkgJsonChangedCnt == 1 or $standalone { $newTag } else { $tag.item }
    let message = $'A new release Tag for version: ($finalTag) created by termix-nu'

    try {
      git tag -a $finalTag $commitHash -m $message; $failed = 0
      print $'(ansi g)✓(ansi rst) Created tag (ansi g)($finalTag)(ansi rst) at commit ($commitHash | str substring 0..7) ($idx) ...'
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to create tag ($finalTag): ($e.msg) ($idx) ...'
    }
  }

  { name: $pkg.name, missingTags: $missingTags }
}

# Create git tags for all downloadable and untagged repositories
export def prepare-repo-tags [--push-tags(-p)] {
  let repos = open repos.toml | get repos
    | default true downloadable
    | default false monoRepo
    | default false tagged
    | where downloadable == true
    | where tagged != true
    | where ($it.repo | is-not-empty)

  $repos | each { |repo|
    clone-repo $repo.repo
    if $repo.monoRepo? and $repo.monoRepo == true {
      create-tag-for-mono-repo $repo
    } else {
      create-tag-for-multi-repo $repo
    }
    if $push_tags {
      git push origin --tags
      print $'(ansi g)Tags pushed successfully!(ansi rst)(char nl)'
    }
  }
}

# Count tags created within the last N days
export def count-latest-tags [--days(-d): int = 2] {
  let tmpPath = get-tmp-path
  let duration = $days * 1day
  let threshold = (date now) - $duration

  cd $tmpPath
  let repos = ls | where type == dir | get name
  mut total = 0

  for repo in $repos {
    if not (($tmpPath | path join $repo | path join '.git') | path exists) { continue }
    let lines = (try { git -C ($tmpPath | path join $repo) for-each-ref --format='%(refname:short)|%(creatordate:iso-strict)' refs/tags | lines } catch { [] })
    let cnt = (
        $lines | each {|l|
          let p = ($l | split row '|')
          if ($p | length) < 2 { null } else { { name: ($p | get 0), date: (($p | get 1) | into datetime) } }
        }
      | compact | where date >= $threshold | length)
    $total += $cnt
  }
  $total
}

# @terminus/mp-barcode=1.0.4,@terminus/mp-calendar=1.0.6,@terminus/react-imageview=1.3.4
# https://erda.cloud/api/terminus/repo/frontend-product/mp-calendar/archive/1.0.6.tar.gz
export def download-src-pkgs [pkgs: table, repos: table] {
  let headers = get-erda-auth $ERDA_HOST --type nu
  for pkg in $pkgs {
    let name = $pkg.name
    let ver = $pkg.version
    let repoUrl = $repos | where name == $name | get repo | first | str replace 'terminus/dop' 'api/terminus/repo'
    let url = $'($repoUrl)/archive/($ver).tar.gz'
    let vUrl = $'($repoUrl)/archive/v($ver).tar.gz'
    let pkgUrl = $'($repoUrl)/archive/($name)@($ver).tar.gz'
    let dest = $'pkg-src/($name)-($ver).tar.gz'
    try {
      try { http get --headers $headers $url } catch { http get --headers $headers $vUrl }
    } catch {
      http get --headers $headers $pkgUrl
    } | save -rfp $dest
    print $'(ansi g)✓(ansi rst) Downloaded (ansi g)($name)@($ver)(ansi rst) source code to (ansi g)($dest)(ansi rst)'
  }
}

# 从 npm 下载没有源码包的包，前提是这些包发布的时候附带了源码
export def download-npm-pkgs [pkgs: table, repos: table] {
  let srcNotPublished = $repos | default false srcPublished | where srcPublished == false | get name
  let skipped = $pkgs | where name in $srcNotPublished
  let todo = $pkgs | where name not-in $srcNotPublished
  if ($skipped | length) > 0 {
    print $'(ansi y)WARNING:(ansi rst) Some packages are not published with source code: (ansi rst)'
    print $skipped
  }
  for pkg in $todo {
    let name = $pkg.name
    let ver = $pkg.version
    let url = npm info ($name)@($ver) --json | from json | get dist.tarball
    let dest = $'pkg-src/($name)-($ver).tar.gz'
    try { http get $url } | save -rfp $dest
    print $'(ansi g)✓(ansi rst) Downloaded (ansi g)($name)@($ver)(ansi rst) source code to (ansi g)($dest)(ansi rst)'
  }
}

# 下载所有源码包
export def download-all-src-pkgs [pkgs: string] {
  renew-erda-session
  let tmpPath = get-tmp-path
  let repos = open repos.toml | get repos
  cd $tmpPath
  print $'Source code will be downloaded to (ansi g)($tmpPath)/pkg-src(ansi rst)'; hr-line
  if ('pkg-src' | path exists) { rm -rf 'pkg-src' }
  mkdir pkg-src/@terminus
  let categoryPkgs = category-pkgs $pkgs $repos
  download-npm-pkgs $categoryPkgs.noSrcPkgs $repos
  download-src-pkgs $categoryPkgs.srcPkgs $repos

  # 生成下载文件清单：文件名与 sha256 哈希
  let files = glob pkg-src/**/*.tar.gz
  let manifest = $files | each {|f| { file: ($f | path basename), sha256: (open $f | hash sha256) } }
  $manifest | sort-by file | to md -p | save -rf pkg-src/manifest.md
  print $'(ansi g)✓(ansi rst) Manifest saved to (ansi g)pkg-src/manifest.md(ansi rst)'
}

# 根据包名和仓库信息，分类出需要下载源码包的包和没有源码包的包
export def category-pkgs [pkgs: string, repos: table] {
  # repo 存在表示源码可从仓库获取；repo 缺失表示需从 npm 下载
  let allPkgs = $repos | get name
  let srcAvailablePkgs = $repos | where {|it| $it.repo? | is-not-empty } | get name
  let srcMissingPkgs = $repos | where {|it| $it.repo? | is-empty } | get name
  let pkgs = $pkgs | split row ,  | each { parse '{name}={version}' | into record }
  let missingPkgs = $pkgs | where $it.name not-in $allPkgs
  if ($missingPkgs | is-empty) {
    let noSrcPkgs = $pkgs | where $it.name in $srcMissingPkgs
    let srcPkgs = $pkgs | where $it.name in $srcAvailablePkgs
    return { noSrcPkgs: $noSrcPkgs, srcPkgs: $srcPkgs }
  }
  print $'(ansi r)ERROR:(ansi rst) The following packages are not found in repos.toml:(char nl)'
  print $missingPkgs
  exit $ECODE.INVALID_PARAMETER
}

# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2
# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2,@terminus/typescript-checker=1.0.7,@terminus/rollup-plugin-alias=2.2.1
# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2,@terminus/typescript-checker=1.0.7,@terminus/rollup-plugin-alias=2.2.1,@terminus/rollup-plugin-typescript=4.0.11,@terminus/react-native-octopus=4.1.1
