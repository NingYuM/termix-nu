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
# [√] 为各 Mono Repo NPM 包自动查找并更新 pkgFile 字段
# [√] 创建一个总的压缩包，包含所有源码包和清单文件
# [√] 为各 Mono Repo NPM 包自动清理源码包，只保留 package.json 所在的目录，最小化源码披露范围
# [√] 提供工具检查 npm 包发布产物里面是否包含源码
# [ ] 将源码包上传到公司 OSS，并提供下载链接？
# Perf:
#   性能优化点
#    - 版本-提交映射缓存 - 新增 build-version-commit-map，一次性构建所有版本到提交的映射表，避免重复扫描 git 历史
#    - 批量准备 - 将 tag 创建分为准备和执行两阶段，先收集所有需要的信息，再批量执行
#    - 减少 git 调用 - 从 O(n*m) 降低到 O(n)，其中 n 是提交数，m 是目标版本数
#   预期性能提升
#    - Multi-repo: 如果有 100 个 tag 要创建，从调用 100 次 git log 优化为只调用 1 次
#    - Mono-repo: 同样的优化，大幅减少 git 历史扫描次数
#    - 实际速度: 对于有大量提交历史的仓库，性能提升可达 10-50 倍
# REPOS.TOML 字段说明：
#   - name: npm 包名
#   - url: 仓库浏览器访问 URL
#   - repo: 仓库 Git Clone URL
#   - tagged: 该包是否已经打 Tag
#   - monoRepo: 是否是 mono repo，默认为 false
#   - downloadable: 当前 npm 包是否可以下载源码，默认为 true
#   - srcPublished: npm 包发布的时候是否附带了源码, 默认为 false
#   - pkgFile: Mono Repo 仓库中子包 package.json 文件路径, 可以借助工具自动更新该字段
#   - standalone: Mono Repo 仓库是否是独立发包模式，true 表示是，false 表示所有的包可能一起发布新版本，默认为 false
# Usage:
#   - Format repos.toml: open repos.toml | update repos { sort-by repo } | save -f repos.toml
#   - Step1: Update repos.toml with the latest repo information
#   - Step2: Run prepare-repo-tags to create tags for all downloadable and untagged repositories
#   - Step3: Run download-all-src-pkgs to download all source code packages
#   - e.g.: t tag-repo --pkgs @terminus/bricks=1.1.1,@terminus/mall-utils=1.3.9
#   - e.g.: t fe-src @terminus/bricks=1.1.1,@terminus/mall-utils=1.3.9,@terminus/nusi-slim=2.2.30

use ../utils/erda.nu [ERDA_HOST, get-erda-auth, renew-erda-session]
use ../utils/common.nu [ECODE get-tmp-path hr-line has-ref is-lower-ver]

# 最大连续失败次数, 超出则停止为该包创建 Tag
const MAX_FAILURE = 15

# Clone a repository and pull all branches and tags
@example 'Clone a repository and pull all branches and tags' {
  clone-repo https://erda.cloud/terminus/dop/t-erp/a.git
} --result 'Clone the repository and pull all branches and tags'
export def --env clone-repo [repo: string] {
  let tmpPath = get-tmp-path
  # 移除可能存在的 .git 后缀
  let repoName = $repo | path basename | str replace -r '\.git$' ''
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
  } | compact -e)
  let missingTags = $versions | where $it not-in $existingVers
  let missingTags = if $hasV { $missingTags | each {|it| $'v($it)' } } else { $missingTags }
  $missingTags
}

# Helpers
# Normalize target tags list from input; fallback to all missing tags
def normalize-targets [missing: list<string>, tags?: string] {
  match ($tags | is-empty) {
    true => { $missing }
    false => {
      let wanted = $tags | split row , | each { str trim } | compact -e
      $missing | where {|t| ($t | str trim -c v) in $wanted }
    }
  }
}

# Build a version-to-commit map for the given file path
# Returns: record with version as keys and commit hash as values
# 一次性构建所有版本到提交的映射表，避免重复扫描 git 历史
def build-version-commit-map [path: string] {
  let commits = try { git log --all --format=%H -- $path | lines } catch { [] }
  if ($commits | is-empty) { return {} }

  # Use git show with batch processing
  let versionMap = $commits | each {|commit|
    let content = try { git show $'($commit):($path)' | from json } catch { null }
    if ($content | is-empty) or ($content.version? | is-empty) {
      null
    } else {
      { version: $content.version, commit: $commit }
    }
  } | compact -e

  # Group by version and take the last commit for each version
  $versionMap | group-by version | items {|ver, entries|
    { key: $ver, value: ($entries | last | get commit) }
  } | transpose -r -d | into record
}

# Find the last commit that updated the file to the specific version in its JSON
# Returns: commit hash string or null
def last-commit-for-version [path: string, version: string, versionMap?: record] {
  if ($versionMap | is-not-empty) {
    return ($versionMap | get -o $version)
  }

  # Fallback to old method if no map provided
  let commits = try { git log --all --format=%H -- $path | lines } catch { [] }
  let matches = $commits | each {|commit|
    let content = try { git show $'($commit):($path)' | from json } catch { { version: "" } }
    if $content.version? == $version { $commit } else { null }
  } | compact
  if ($matches | is-empty) { null } else { $matches | last }
}

# Create tags for a multi-repo package
# 创建 Tag 的过程：
#   - 根据已经发布的版本计算缺失的 Tag，已完成
#   - 使用 git 命令分析 package.json 文件的变更记录，找出版本变更的 Commit hash, 然后从这个 Commit hash 创建 Tag，备注信息为: `A new release Tag for version: ($tagName) created by termix-nu`
#   - 切记：不要修改或者删除仓库里面先前已经有的 Tag
export def create-tag-for-multi-repo [pkg: record, --tags(-t): string] {
  print $'(char nl)(ansi c)Creating tags for multi repo: (ansi rst) (ansi g)($pkg.name)(ansi rst)'; hr-line
  let missingTags = get-missing-tags $pkg
  let targets = normalize-targets $missingTags $tags
  print $'(ansi c)Package:(ansi rst) (ansi g)($pkg.name)(ansi rst)'
  print $'(ansi c)Missing tags:(ansi rst) ($targets | length)'

  if ($targets | is-empty) {
    return { name: $pkg.name, missingTags: $missingTags }
  }

  # Build version-to-commit map once for all versions
  print $'(ansi c)Building version-commit map...(ansi rst)'
  let versionMap = build-version-commit-map package.json

  # Batch create tags
  mut failed = 0
  mut tagCmds = []
  for tag in ($targets | enumerate) {
    let idx = $'#($tag.index + 1)'
    let version = $tag.item | str trim -c v
    let commitHash = last-commit-for-version package.json $version $versionMap

    if ($commitHash | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) No commit found for version ($version) ($idx) ...'
      $failed = $failed + 1
      if $failed > $MAX_FAILURE {
        print $'(ansi r)ERROR:(ansi rst) Too many consecutive failures. Stop creating tags for this package.'
        break
      }
      continue
    }

    let message = $'A new release Tag for version: ($tag.item) created by termix-nu'
    $tagCmds = $tagCmds | append { tag: $tag.item, commit: $commitHash, msg: $message, idx: $idx }
  }

  # Execute tag creation
  for cmd in $tagCmds {
    try {
      git tag -a $cmd.tag $cmd.commit -m $cmd.msg; $failed = 0
      print $'(ansi g)✓(ansi rst) Created tag ($cmd.tag) at commit ($cmd.commit | str substring 0..7) ($cmd.idx) ...'
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to create tag ($cmd.tag): ($e.msg) ($cmd.idx) ...'
    }
  }

  { name: $pkg.name, missingTags: $missingTags }
}

# Create tags for a mono-repo package
export def create-tag-for-mono-repo [pkg: record, --tags(-t): string] {
  print $'(char nl)(ansi c)Creating tags for mono repo: (ansi rst) (ansi g)($pkg.name)(ansi rst)'; hr-line
  let missingTags = get-missing-tags $pkg
  let targets = normalize-targets $missingTags $tags
  print $'(ansi c)Package:(ansi rst) (ansi g)($pkg.name)(ansi rst)'
  print $'(ansi c)Missing tags:(ansi rst) ($targets | length)'
  let pkgFile = $pkg.pkgFile?
  let standalone = $pkg.standalone? | default false

  if ($targets | is-empty) {
    return { name: $pkg.name, missingTags: $missingTags }
  }

  if ($pkgFile | is-empty) {
    print $'(ansi y)WARNING:(ansi rst) No pkgFile specified for package: ($pkg.name)'
    return { name: $pkg.name, missingTags: $missingTags }
  }

  # Build version-to-commit map once for all versions
  print $'(ansi c)Building version-commit map...(ansi rst)'
  let versionMap = build-version-commit-map $pkgFile

  # Batch prepare tag information
  mut failed = 0
  mut tagCmds = []
  for tag in ($targets | enumerate) {
    let idx = $'#($tag.index + 1)'
    let version = $tag.item | str trim -c v
    let newTag = $'($pkg.name)@($version)'

    if (has-ref $newTag) {
      print $'(ansi y)INFO:(ansi rst) Tag ($newTag) already exists, skip ($idx) ...'
      continue
    }

    let commitHash = last-commit-for-version $pkgFile $version $versionMap

    if ($commitHash | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) No commit found for version ($version) ($idx) ...'
      $failed = $failed + 1
      if $failed > $MAX_FAILURE {
        print $'(ansi r)ERROR:(ansi rst) Too many consecutive failures. Stop creating tags for this package.'
        break
      }
      continue
    }

    # 检查该提交修改的文件，若修改了多个 /package.json 则使用版本标签，否则使用 name@version 标签
    let changedFiles = try { git diff-tree --no-commit-id --name-only -r $commitHash | lines } catch { [] }
    let pkgJsonChangedCnt = $changedFiles | where {|p| $p | str ends-with '/package.json' } | length
    let finalTag = if $pkgJsonChangedCnt == 1 or $standalone { $newTag } else { $tag.item }
    let message = $'A new release Tag for version: ($finalTag) created by termix-nu'

    $tagCmds = $tagCmds | append { tag: $finalTag, commit: $commitHash, msg: $message, idx: $idx }
  }

  # Execute tag creation
  for cmd in $tagCmds {
    try {
      git tag -a $cmd.tag $cmd.commit -m $cmd.msg; $failed = 0
      print $'(ansi g)✓(ansi rst) Created tag (ansi g)($cmd.tag)(ansi rst) at commit ($cmd.commit | str substring 0..7) ($cmd.idx) ...'
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to create tag ($cmd.tag): ($e.msg) ($cmd.idx) ...'
    }
  }

  { name: $pkg.name, missingTags: $missingTags }
}

# Create git tags for all downloadable and untagged repositories
# e.g.: `t tag-repo --pkgs @terminus/bricks=1.1.1,@terminus/mall-utils=1.3.9`
export def prepare-repo-tags [--push-tags(-p), --pkgs: string] {
  update-pkg-json-for-mono-repos

  let allRepos = open repos.toml | get repos
    | default true downloadable
    | default false monoRepo
    | where downloadable == true
    | where ($it.repo | is-not-empty)

  let repos = match ($pkgs | is-not-empty) {
    true => {
      let specs = $pkgs | split row , | each { str trim }
        | compact -e | each { parse '{name}={version}' | into record }
      $specs | each {|sp|
        let match = $allRepos | where name == $sp.name
        if ($match | is-empty) {
          print $'(ansi y)WARNING:(ansi rst) Package not found in repos.toml: (ansi y)($sp.name)(ansi rst)'; null
        } else {
          ($match | first) | upsert __target_tags $sp.version
        }
      } | compact -e
    }
    false => { $allRepos | default false tagged | where tagged != true }
  }

  $repos | each { |repo|
    clone-repo $repo.repo
    let has_tags = not ($repo.__target_tags? | is-empty)
    match ($repo.monoRepo? | default false) {
      true => {
        if $has_tags {
          create-tag-for-mono-repo $repo --tags $repo.__target_tags
        } else { create-tag-for-mono-repo $repo }
      }
      _ => {
        if $has_tags {
          create-tag-for-multi-repo $repo --tags $repo.__target_tags
        } else { create-tag-for-multi-repo $repo }
      }
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
        } | compact -e | where date >= $threshold | length)
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
    let match = $repos | where name == $name
    if ($match | is-empty) {
      print $'(ansi r)ERROR:(ansi rst) Repository not found for package: ($name)'
      continue
    }
    let repoUrl = $match | get repo | first | str replace 'terminus/dop' 'api/terminus/repo'
    let dest = $'pkg-src/($name)-($ver).tar.gz'
    let url = $'($repoUrl)/archive/($ver).tar.gz'
    let vUrl = $'($repoUrl)/archive/v($ver).tar.gz'
    let pkgUrl = $'($repoUrl)/archive/($name)@($ver).tar.gz'
    try {
      try { http get --headers $headers $url } catch { http get --headers $headers $vUrl }
    } catch { http get --headers $headers $pkgUrl } | save -rfp $dest
    print $'(ansi g)✓(ansi rst) Downloaded (ansi g)($name)@($ver)(ansi rst) source code to (ansi g)($dest)(ansi rst)'
  }
}

# 下载 SPECIAL_PKGS 列表中的包（自定义 URL）
export def download-custom-pkgs [pkgs: table, repos: table] {
  let headers = get-erda-auth $ERDA_HOST --type nu
  for pkg in $pkgs {
    let name = $pkg.name
    let ver = $pkg.version
    let url = custom-pkg-url $name $ver $repos
    let dest = $'pkg-src/($name)-($ver).tar.gz'
    try { http get --headers $headers $url } | save -rfp $dest
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

# Helper: Get tar file path for a package (handles scoped packages)
def get-tar-path [name: string, ver: string, baseDir: string] {
  if ($name | str starts-with '@') {
    let parts = $name | split row '/'
    $baseDir | path join $'pkg-src/($parts.0)/($parts.1)-($ver).tar.gz'
  } else {
    $baseDir | path join $'pkg-src/($name)-($ver).tar.gz'
  }
}

# Helper: Get safe package name for directory naming
def get-safe-pkg-name [name: string] {
  $name | str replace -a '/' '-' | str replace -a '@' ''
}

# Helper: Find package source directory in extracted tar
def find-pkg-source-dir [extractDir: string, pkgFile: string] {
  let pkgRelDir = $pkgFile | path dirname
  let directPath = $extractDir | path join $pkgRelDir

  if ($directPath | path exists) {
    return $directPath
  }

  # Look for single root directory
  let dirs = try { ls $extractDir | where type == dir } catch { [] }
  if ($dirs | length) != 1 {
    return null
  }

  let rootPath = ($dirs | first).name | path join $pkgRelDir
  if ($rootPath | path exists) { $rootPath } else { null }
}

# Helper: Clean up temporary directories
def cleanup-temp-dirs [dirs: list<string>] {
  $dirs | each {|dir| try { rm -rf $dir } catch {} } | ignore
}

# Helper: Clean a single mono repo package
def clean-single-pkg [pkg: record, pkgFile: string, baseDir: string] {
  let name = $pkg.name
  let ver = $pkg.version
  let tarFile = get-tar-path $name $ver $baseDir

  if not ($tarFile | path exists) {
    print $'(ansi y)WARNING:(ansi rst) Package file not found: ($tarFile)'
    return false
  }

  let safeName = get-safe-pkg-name $name
  let tmpExtract = $baseDir | path join $'pkg-src/.tmp-extract-($safeName)-($ver)'
  let tmpClean = $baseDir | path join $'pkg-src/.tmp-clean-($safeName)-($ver)'

  cleanup-temp-dirs [$tmpExtract, $tmpClean]

  try {
    # Extract
    print $'  Extracting ($name)@($ver)...'
    mkdir $tmpExtract
    tar xzf $tarFile -C $tmpExtract

    # Find source directory
    let srcDir = find-pkg-source-dir $tmpExtract $pkgFile
    if ($srcDir | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) Package directory not found (pkgFile: ($pkgFile))'
      cleanup-temp-dirs [$tmpExtract]
      return false
    }

    # Copy to clean directory
    print $'  Copying package directory...'
    mkdir $tmpClean
    let newPkgDir = $tmpClean | path join $safeName
    cp -r $srcDir $newPkgDir

    # Create new archive
    print $'  Creating cleaned archive...'
    let newTar = $tmpClean | path join 'new.tar.gz'
    do -i { cd $tmpClean; tar czf new.tar.gz $safeName }

    if not ($newTar | path exists) {
      print $'(ansi r)ERROR:(ansi rst) Failed to create archive'
      cleanup-temp-dirs [$tmpExtract, $tmpClean]
      return false
    }

    # Replace original
    mv -f $newTar $tarFile
    cleanup-temp-dirs [$tmpExtract, $tmpClean]

    print $'(ansi g)✓(ansi rst) Cleaned: (ansi g)($name)@($ver)(ansi rst)'
    true
  } catch {|e|
    print $'(ansi r)ERROR:(ansi rst) Failed to clean ($name)@($ver): ($e.msg)'
    cleanup-temp-dirs [$tmpExtract, $tmpClean]
    false
  }
}

# Clean mono repo packages to only include the npm package directory
def clean-mono-repo-pkgs [pkgs: table, repos: table] {
  print $'(ansi c)Cleaning mono repo packages...(ansi rst)'; hr-line

  let monoRepos = $repos | default false monoRepo | where monoRepo == true
  let baseDir = $env.PWD

  $pkgs | each {|pkg|
    let match = $monoRepos | where name == $pkg.name
    if ($match | is-empty) { return }

    let pkgFile = ($match | first).pkgFile?
    if ($pkgFile | is-empty) {
      print $'(ansi y)WARNING:(ansi rst) No pkgFile for ($pkg.name)'
      return
    }

    clean-single-pkg $pkg $pkgFile $baseDir
  } | ignore
}

# 下载所有源码包, e.g.: `t fe-src @terminus/bricks=1.1.1,@terminus/mall-utils=1.3.9`
export def download-all-src-pkgs [
  pkgs: string        # Npm pkgs to download, format: pkg1=ver1,pkg2=ver2,...
  --compress-all(-c)  # Compress pkg-src directory to fe-src.tar.gz
  --clean             # Clean mono repo packages to only include the npm package directory
] {
  renew-erda-session
  let tmpPath = get-tmp-path
  let repos = open repos.toml | get repos
  cd $tmpPath
  print $'Source code will be downloaded to (ansi g)($tmpPath)/pkg-src(ansi rst)'; hr-line
  if ('pkg-src' | path exists) { rm -rf pkg-src }
  mkdir pkg-src/@terminus
  let categoryPkgs = category-pkgs $pkgs $repos
  download-src-pkgs $categoryPkgs.srcPkgs $repos
  download-npm-pkgs $categoryPkgs.noSrcPkgs $repos
  download-custom-pkgs $categoryPkgs.customPkgs $repos

  # Clean mono repo packages if --clean flag is set
  if $clean {
    # Combine all downloaded packages for cleaning
    let allDownloadedPkgs = $categoryPkgs.srcPkgs | append $categoryPkgs.noSrcPkgs | append $categoryPkgs.customPkgs
    clean-mono-repo-pkgs $allDownloadedPkgs $repos
  }

  # 生成下载文件清单：文件名与 sha256 哈希
  let files = glob pkg-src/**/*.tar.gz
  let manifest = $files | each {|f| { file: ($f | path basename), sha256: (open $f | hash sha256) } }
  $manifest | sort-by file | to md -p | save -rf pkg-src/manifest.md
  print $'(ansi g)✓(ansi rst) Manifest saved to (ansi g)pkg-src/manifest.md(ansi rst)'

  if $compress_all {
    print $'(ansi g)Compressing pkg-src directory to fe-src.tar.gz...(ansi rst)'
    tar czf fe-src.tar.gz pkg-src
    print $'(ansi g)✓(ansi rst) Compressed to (ansi g)fe-src.tar.gz(ansi rst)'
  }
}

# 特殊处理的包名列表
const SPECIAL_PKGS = [
  '@terminus/nusi-slim',
  '@terminus/nusi-saas',
  '@terminus/nusi-ease',
  '@terminus/nusi-flex',
]

# 根据包名和版本号，生成自定义的源码包 URL
def custom-pkg-url [name: string, ver: string, repos: table] {
  let match = $repos | where name == $name
  if ($match | is-empty) {
    error make { msg: $'Repository not found for package: ($name)' }
  }
  let repoUrl = $match | get repo | first | str replace 'terminus/dop' 'api/terminus/repo'
  match $name {
    '@terminus/nusi-flex' if (is-lower-ver $ver 1.0.0) => { $'($repoUrl)/archive/v($ver).tar.gz' }
    '@terminus/nusi-flex' if (is-lower-ver 1.0.0 $ver) => { $'($repoUrl)/archive/next-v($ver).tar.gz' }
    '@terminus/nusi-slim' if (is-lower-ver $ver 2.0.0) => { $'($repoUrl)/archive/nusi-v($ver).tar.gz' }
    '@terminus/nusi-slim' if (is-lower-ver 2.0.0 $ver) => { $'($repoUrl)/archive/next-v($ver).tar.gz' }
    _ => { $'($repoUrl)/archive/($name)@($ver).tar.gz' }
  }
}

# 根据包名和仓库信息，分类出需要下载源码包的包、没有源码包的包以及需要自定义 URL 下载的包
export def category-pkgs [pkgs: string, repos: table] {
  # repo 存在表示源码可从仓库获取；repo 缺失表示需从 npm 下载
  let allPkgs = $repos | get name
  let forbiddenPkgs = $repos | where {|it| $it.downloadable? == false } | get name
  let srcAvailablePkgs = $repos | where {|it| $it.repo? | is-not-empty } | get name
  let srcMissingPkgs = $repos | where {|it| $it.repo? | is-empty } | get name
  let pkgs = $pkgs | split row , | each { parse '{name}={version}' | into record }
  let missingPkgs = $pkgs | where $it.name not-in $allPkgs
  let forbidden = $pkgs | where $it.name in $forbiddenPkgs
  if ($forbidden | is-not-empty) {
    print $'(ansi r)ERROR:(ansi rst) The following packages are forbidden to download source code:(char nl)'
    print $forbidden
    exit $ECODE.INVALID_PARAMETER
  }
  if ($missingPkgs | is-empty) {
    let noSrcPkgs = $pkgs | where $it.name in $srcMissingPkgs
    let srcPkgsAll = $pkgs | where $it.name in $srcAvailablePkgs
    let customPkgs = $srcPkgsAll | where $it.name in $SPECIAL_PKGS
    let srcPkgs = $srcPkgsAll | where $it.name not-in $SPECIAL_PKGS
    return { noSrcPkgs: $noSrcPkgs, srcPkgs: $srcPkgs, customPkgs: $customPkgs }
  }
  print $'(ansi r)ERROR:(ansi rst) The following packages are not found in repos.toml:(char nl)'
  print $missingPkgs
  exit $ECODE.INVALID_PARAMETER
}

# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2
# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2,@terminus/typescript-checker=1.0.7,@terminus/rollup-plugin-alias=2.2.1
# @terminus/mp-barcode=1.0.4,@terminus/trnw-tools=5.0.0-beta2,@terminus/typescript-checker=1.0.7,@terminus/rollup-plugin-alias=2.2.1,@terminus/rollup-plugin-typescript=4.0.11,@terminus/react-native-octopus=4.1.1

# 为 mono repo 自动查找并更新 pkgFile 字段
export def update-pkg-json-for-mono-repos [] {
  print $'(ansi c)Updating pkgFile for mono repos...(ansi rst)'; hr-line

  # 保存当前工作目录的绝对路径，以便后续保存文件
  let workDir = $env.PWD
  let reposPath = $workDir | path join 'repos.toml'
  mut data = open $reposPath
  let repos = $data.repos | default false monoRepo

  # 找出所有 monoRepo = true 但没有 pkgFile 的仓库
  let missingPkgFile = $repos | where {|it|
    ($it.monoRepo? == true) and ($it.pkgFile? | is-empty) and ($it.repo? | is-not-empty)
  }

  if ($missingPkgFile | is-empty) {
    print $'(ansi g)✓(ansi rst) All mono repos already have pkgFile configured.'
    return
  }

  print $'Found ($missingPkgFile | length) mono repos without pkgFile:'
  $missingPkgFile | select name repo | print

  let tmpPath = get-tmp-path
  # 按仓库分组处理，避免重复克隆同一仓库
  let groupedByRepo = $missingPkgFile | group-by repo

  mut updated = []
  for repoUrl in ($groupedByRepo | columns) {
    let pkgs = $groupedByRepo | get $repoUrl
    print $'(char nl)(ansi c)Processing repository:(ansi rst) (ansi g)($repoUrl)(ansi rst)'; hr-line

    clone-repo $repoUrl
    # 移除可能的 .git 后缀，与 clone-repo 的目录名保持一致
    let repoName = $repoUrl | path basename | str replace -r '\.git$' ''
    let repoPath = $tmpPath | path join $repoName

    # 在最新的 HEAD 中搜索所有 package.json 文件
    cd $repoPath
    let pkgJsonFiles = try {
      glob **/package.json | where {|f| not ($f | str contains 'node_modules') }
    } catch { [] }

    print $'(ansi c)Found ($pkgJsonFiles | length) package.json files(ansi rst)'

    # 为每个缺失 pkgFile 的包查找对应的 package.json
    for pkg in $pkgs {
      let pkgName = $pkg.name
      print $'(ansi c)Searching for:(ansi rst) (ansi g)($pkgName)(ansi rst)'

      let matchedFile = $pkgJsonFiles | each {|f|
        let content = try { open $f } catch { { name: "" } }
        if $content.name? == $pkgName { $f } else { null }
      } | compact -e

      if ($matchedFile | is-not-empty) {
        let absolutePath = $matchedFile | first
        # 转换为相对于仓库根目录的相对路径
        let relativePath = $absolutePath | path relative-to $repoPath
        print $'(ansi g)✓(ansi rst) Found match: (ansi g)($relativePath)(ansi rst)'
        $updated = $updated | append { name: $pkgName, pkgFile: $relativePath }
      } else {
        print $'(ansi y)WARNING:(ansi rst) No matching package.json found for ($pkgName)'
      }
    }
  }

  if ($updated | is-empty) {
    print $'(char nl)(ansi y)No pkgFile updates found.(ansi rst)'
    return
  }

  print $'(char nl)(ansi c)Updating repos.toml...(ansi rst)'; hr-line
  # 将 updated 转换为不可变变量以便在闭包中使用
  let updatedList = $updated
  let updatedRepos = $data.repos | each {|repo|
    let match = $updatedList | where name == $repo.name
    if ($match | is-not-empty) { $repo | upsert pkgFile ($match | first).pkgFile } else { $repo }
  }

  $data | upsert repos $updatedRepos | update repos { sort-by repo } | save -f $reposPath
  print $'(ansi g)✓(ansi rst) Updated ($updatedList | length) packages in repos.toml:'
  $updatedList | print
}

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

# 检查指定的 npm 包是否发布时附带了源码
export def check-src-published [--pkgs(-p): string, --clean(-c)] {
  let tmpPath = get-tmp-path
  let workDir = $tmpPath | path join 'pkg-src-check'
  let repos = open repos.toml | get repos
  let todo = $repos | where ($it.srcPublished? | default false) == false
  let pkgs = if ($pkgs | is-not-empty) { $pkgs | split row , | compact -e } else { $todo | get name }

  # Clean up and create work directory
  if ($workDir | path exists) { rm -rf $workDir }
  mkdir $workDir

  # Check each package and collect results
  let results = $pkgs | each {|pkg|
    print $'(ansi c)Checking package: (ansi rst) (ansi g)($pkg)(ansi rst)'

    # Get package info
    let pkgInfo = try {
      npm info $pkg --json | from json
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to get package info: ($e.msg)'
      return { name: $pkg, hasSource: null, error: $'Failed to get info: ($e.msg)' }
    }

    let url = $pkgInfo | get dist.tarball
    let pkgName = get-safe-pkg-name $pkg
    let pkgDir = $workDir | path join $pkgName
    let tarFile = $pkgDir | path join 'package.tar.gz'

    try {
      # Create package directory and download
      mkdir $pkgDir
      http get $url | save -f $tarFile
      # Extract tarball
      tar xzf $tarFile -C $pkgDir

      # npm tarball creates a 'package/' subdirectory
      let extractDir = if (($pkgDir | path join 'package') | path exists) {
        $pkgDir | path join 'package'
      } else {
        $pkgDir
      }

      # Check for source code files (TypeScript, JSX)
      let sourceFiles = try {
        glob ($extractDir)/{src,source}/**/*.{ts,tsx,jsx} | where {|f| not ($f | str contains 'node_modules') } | each {|f| $f | path relative-to $workDir }
      } catch { [] }

      # Check for common source directories
      let srcDirs = ['src', 'source']
        | each {|d| $extractDir | path join $d }
        | where {|p| $p | path exists }

      let hasSource = ($sourceFiles | length) > 0 or ($srcDirs | length) > 0

      if $hasSource {
        print $'(ansi g)✓(ansi rst) Package: (ansi g)($pkg)(ansi rst) has source code'
        if ($sourceFiles | length) > 0 {
          print $'  Source files: ($sourceFiles | length) TypeScript/JSX files'
        }
        if ($srcDirs | length) > 0 {
          print $'  Source dirs: ($srcDirs | each { path basename } | str join ", ")'
        }
        hr-line
        { name: $pkg, hasSource: true, sourceFiles: ($sourceFiles | first 20) }
      } else {
        print $'(ansi y)WARNING:(ansi rst) Package:  (ansi g)($pkg)(ansi rst) has no source code'
        { name: $pkg, hasSource: false }
      }
    } catch {|e|
      print $'(ansi r)ERROR:(ansi rst) Failed to check ($pkg): ($e.msg)'
      { name: $pkg, hasSource: null, error: $e.msg }
    }
  }

  # Summary
  print $'(char nl)(ansi c)Summary:(ansi rst)'; hr-line
  let withSource = $results | where hasSource == true | length
  let withoutSource = $results | where hasSource == false | length
  let failed = $results | where hasSource == null | length

  print $'Packages with source: (ansi g)($withSource)(ansi rst)'
  print $'Packages without source: (ansi y)($withoutSource)(ansi rst)'
  if $failed > 0 { print $'Failed to check: (ansi r)($failed)(ansi rst)' }

  # Clean up
  if $clean { rm -rf $workDir }

  $results
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
