#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/04/19 15:52:00
# Description: Scan source code and Generate components list for Trantor Designer
# [√] Scan components from terp-ui, b2b-ui, material-ui, service-ui, emp-trantor2-fronted
# [√] Output result in json format
# [√] Get changed components list between two git commits
# [ ] Scan multiple repos at one time support
# [ ] Grep from components list
# [ ] Scan hidden components for material-ui
# [ ] Check duplicate components
# 组件变更检查不足：
# 1. 对后端接口变化不敏感，可能漏检
# 2. 当前变更检测方式为变更文件名搜索，可能出现假阳性
# 3. 组件名与组件文件名转换成 TitleCase 后要匹配，否则也会漏检

use ../utils/common.nu [is-installed, is-lower-ver, hr-line, ECODE]

const AST_GREP_VERSION = '0.23.1'
const MODULE_NAME_MAP = {
  'emp2': 'emp',
  'b2b-ui': 'b2b',
  'terp-ui': 'terp',
  'material-ui': 'base',
  'service-ui': 'service',
  'emp-trantor2-fronted': 'emp',
}

# 通过额外的组件名到文件名的映射来降低漏检的可能性
const EXTRA_PATTERN = {
  IssuingInvoiceFinancialAuditing: [FinancialAuditing]
  ReceivingInvoiceFinancialAuditing: [FinancialAuditing]
}

# Description: Scan source code and display components list for Trantor Designer
export def 'get components' [
  --modified(-m): string,               # Get modified components between two git commits, eg: develop...release/2.5.24.0330
  --strategy(-s): string = 'behavior',  # Scan strategy: behavior, json
  --json(-j),                           # Output in json format
] {
  match $strategy {
    'behavior' => { list components --json=$json --modified=$modified },
    'json' => { list components --json=$json --modified=$modified --from-json },
    _ => { print $'Invalid scan strategy: ($strategy)' },
  }
}

# Description: Scan source code and display components list
export def 'list components' [
  --json(-j),               # Output in json format
  --from-json,              # Scan components from json schema
  --grep(-g): string,       # Grep component by pattern
  --modified(-m): string,   # Get modified components between two git commits, eg: develop...release/2.5.24.0330
] {
  let basename = $env.JUST_INVOKE_DIR | path basename
  if $basename not-in $MODULE_NAME_MAP {
    print $'(ansi r)Unsupported repo, bye...(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  let pkgName = $MODULE_NAME_MAP | get $basename

  if not (is-installed sg) {
    print $'Please install ast-grep by (ansi r)`brew install ast-grep`(ansi reset) and try again ...'
    exit $ECODE.MISSING_BINARY
  }
  let sgVer = sg --version | str replace 'ast-grep' '' | str trim
  if (is-lower-ver $sgVer $AST_GREP_VERSION) {
    print $'Please upgrade ast-grep to version (ansi r)($AST_GREP_VERSION)(ansi reset) or higher and try again ...'
    exit $ECODE.OUTDATED
  }

  let startTime = (date now)
  $env.config.table.mode = 'light'
  mut components = scan-components $pkgName --from-json=$from_json
  if ($modified | is-not-empty) {
    let currentBranch = git branch --show-current
    let commits = $modified | split row ','
    let diffTo = if ($commits | length) > 1 { $commits.1 } else { $currentBranch }
    let diff = git diff $commits.0 $diffTo --name-only | lines | each { str title-case | str replace -a ' ' '' }
    $components = ($components | upsert modified {|it| is-modified $it.name $diff } | where modified | uniq)
    print $'(char nl)All possibly modified designer components for (ansi g)($pkgName)(ansi reset):'; hr-line -b
  } else {
    print $'(char nl)All designer components for (ansi g)($pkgName)(ansi reset):'; hr-line -b
  }
  let endTime = (date now)
  if $json { $components | to json -i 2 | print } else { print $components }
  print $'(ansi p)Scan completed. Total time cost: (ansi g)($endTime - $startTime)(char nl)(ansi reset)'
}

# Check if a component is modified
def is-modified [name: string, diff: list] {
  if ($diff | find $name | is-not-empty) { return true }
  if ($name in $EXTRA_PATTERN) {
    for p in ($EXTRA_PATTERN | get $name) {
      if ($diff | find $p | is-not-empty) { return true }
    }
  }
  false
}

# Trim all ' or " from input
def trim-quotes [] { $in | str trim -c "'" | str trim -c '"' }

def get-module-name [pkgName: string] {
  let isMobile = ($in =~ '/mobile/') or ($in =~ '\\mobile\\') or ($in =~ 'mobile-behaviors')
  if $isMobile { $'($pkgName)-mobile' } else { $pkgName }
}

# Scan components list from source code
def scan-components [
  pkgName: string,
  --from-json,              # Scan components from json schema
] {
  if $from_json { return (scan-components-by-json $pkgName) }
  let pattern = match $pkgName {
    emp => 'registry.add($_, {$$$, name: $NAME, $$$, title: $TITLE, $$$, group: $GROUP, $$$})',
    _ => 'export const $$$ = {$$$, name: $NAME, $$$, title: $TITLE, $$$, group: $GROUP, $$$}',
  }
  let components = sg -p $pattern --json
    | from json
    | select metaVariables.single.NAME.text metaVariables.single.TITLE.text metaVariables.single.GROUP.text file
    | rename name title group
    | upsert name { $in | trim-quotes }
    | upsert title { $in | trim-quotes }
    | upsert group { $in | trim-quotes }
    | upsert module {|it| $it.file | get-module-name $pkgName }
    | sort-by module name
    | reject file
  $components
}

def scan-components-by-json [
  pkgName: string,
] {
  glob packages/**/*/*.behavior.json
    | wrap file
    | upsert cmp {|it| open $it.file | select -o name title group }
    | flatten
    | where {|it| $it.group | is-not-empty }
    | upsert module {|it| $it.file | get-module-name $pkgName }
    | sort-by module group name
    | reject file
}

alias main = get components
