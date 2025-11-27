# Color variable replacement script for NUSI UI migration
# REF:
#   - https://github.com/chmln/sd
#   - https://ast-grep.github.io

# ============================================================================
# Configuration
# ============================================================================

const RULES_DIR = '/tmp/ast-grep-color-rules'
const SOURCE = '/Users/hustcer/iWork/terminus/terp-ui/packages/pc/src'
const COLOR_IMPORT = "import { COLOR } from '@/constants/style-variables';"
const EXCLUDE_FILES = ['style-variables.ts', '/dist/', '/node_modules/']

# LESS color variable mapping: css-value -> less-variable
const LESS_COLOR_MAP = {
  # Primary colors
  'rgb(var(--nusi-primary))'   : '@primary'
  'rgb(var(--nusi-primary-1))' : '@primary-1'
  'rgb(var(--nusi-primary-2))' : '@primary-2'
  'rgb(var(--nusi-primary-3))' : '@primary-3'
  'rgb(var(--nusi-primary-4))' : '@primary-4'
  # Neutral colors
  'rgb(var(--nusi-neutral))'    : '@middle'
  'rgb(var(--nusi-neutral-1))'  : '@middle-1'
  'rgb(var(--nusi-neutral-2))'  : '@middle-2'
  'rgb(var(--nusi-neutral-3))'  : '@middle-3'
  'rgb(var(--nusi-neutral-4))'  : '@middle-4'
  'rgb(var(--nusi-neutral-5))'  : '@middle-5'
  'rgb(var(--nusi-neutral-6))'  : '@middle-6'
  'rgb(var(--nusi-neutral-7))'  : '@middle-7'
  'rgb(var(--nusi-neutral-10))' : '@middle-4'
  'rgb(var(--nusi-neutral-20))' : '@middle-4'
  'rgb(var(--nusi-neutral-40))' : '@middle-3'
  'rgb(var(--nusi-neutral-55))' : '@middle-2'
  'rgb(var(--nusi-neutral-85))' : '@middle-1'
  # Error colors
  'rgb(var(--nusi-error))'   : '@error'
  'rgb(var(--nusi-error-1))' : '@error-light'
  'rgb(var(--nusi-error-2))' : '@error-dark'
  'rgb(var(--nusi-error-3))' : '@error-heavy'
  # Warning colors
  'rgb(var(--nusi-warn))'   : '@warn'
  'rgb(var(--nusi-warn-1))' : '@warn-light'
  'rgb(var(--nusi-warn-2))' : '@warn-dark'
  # Info colors
  'rgb(var(--nusi-info))'   : '@info'
  'rgb(var(--nusi-info-1))' : '@info-light'
  'rgb(var(--nusi-info-2))' : '@info-dark'
  # Success colors
  'rgb(var(--nusi-success))'   : '@success'
  'rgb(var(--nusi-success-1))' : '@success-light'
  'rgb(var(--nusi-success-2))' : '@success-dark'
  # Other colors
  'rgb(var(--nusi-text))'        : '@color-text'
  'rgb(var(--nusi-color-white))' : '@color-white'
}

# TypeScript COLOR constant mapping: COLOR.KEY -> css-value
const TS_COLOR_MAP = {
  WHITE        : 'rgb(var(--nusi-color-white))'
  PRIMARY      : 'rgb(var(--nusi-primary))'
  PRIMARY1     : 'rgb(var(--nusi-primary-1))'
  PRIMARY2     : 'rgb(var(--nusi-primary-2))'
  PRIMARY3     : 'rgb(var(--nusi-primary-3))'
  PRIMARY4     : 'rgb(var(--nusi-primary-4))'
  MIDDLE       : 'rgb(var(--nusi-neutral))'
  MIDDLE1      : 'rgb(var(--nusi-neutral-1))'
  MIDDLE2      : 'rgb(var(--nusi-neutral-2))'
  MIDDLE3      : 'rgb(var(--nusi-neutral-3))'
  MIDDLE4      : 'rgb(var(--nusi-neutral-4))'
  MIDDLE5      : 'rgb(var(--nusi-neutral-5))'
  MIDDLE6      : 'rgb(var(--nusi-neutral-6))'
  MIDDLE7      : 'rgb(var(--nusi-neutral-7))'
  ERROR        : 'rgb(var(--nusi-error))'
  ERROR_LIGHT  : 'rgb(var(--nusi-error-1))'
  ERROR_DARK   : 'rgb(var(--nusi-error-2))'
  ERROR_HEAVY  : 'rgb(var(--nusi-error-3))'
  WARN         : 'rgb(var(--nusi-warn))'
  WARN_LIGHT   : 'rgb(var(--nusi-warn-1))'
  WARN_DARK    : 'rgb(var(--nusi-warn-2))'
  INFO         : 'rgb(var(--nusi-info))'
  INFO_LIGHT   : 'rgb(var(--nusi-info-1))'
  INFO_DARK    : 'rgb(var(--nusi-info-2))'
  SUCCESS      : 'rgb(var(--nusi-success))'
  SUCCESS_LIGHT: 'rgb(var(--nusi-success-1))'
  SUCCESS_DARK : 'rgb(var(--nusi-success-2))'
  TEXT         : 'rgb(var(--nusi-text))'
}

# ============================================================================
# Helper Functions
# ============================================================================

# Generate ast-grep YAML rule for color replacement
# lang: 'tsx' for TSX files (needs context), 'typescript' for TS files (simple)
# context: 'jsx' for JSX attributes, 'obj' for object properties, 'any' for simple
# quote: 'single' or 'double'
def make-ast-rule [
  css: string
  color_key: string
  lang: string
  context: string
  quote: string
]: nothing -> string {
  let pattern = match $quote {
    'single' => $"\"'($css)'\""
    'double' => ("'\"" + $css + "\"'")
  }

  # For TypeScript files, use simple replacement (no JSX context needed)
  if $lang == 'typescript' {
    return ([
      $"id: ts-($quote)-replace"
      "language: typescript"
      "rule:"
      $"  pattern: ($pattern)"
      $"fix: ($color_key)"
    ] | str join "\n")
  }

  # For TSX files, distinguish between JSX attributes and object pairs
  let fix = match $context {
    'jsx' => $"\"{($color_key)}\""
    'obj' => $color_key
  }
  let kind = match $context {
    'jsx' => 'jsx_attribute'
    'obj' => 'pair'
  }
  [
    $"id: ($context)-($quote)-replace"
    "language: tsx"
    "rule:"
    $"  pattern: ($pattern)"
    "  inside:"
    $"    kind: ($kind)"
    $"fix: ($fix)"
  ] | str join "\n"
}

# Execute ast-grep rule from a YAML string
def run-ast-rule [rule: string, name: string] {
  let rule_file = $'($RULES_DIR)/($name).yml'
  $rule | save -f $rule_file
  # Include all ts/tsx files first, then exclude specific files/directories
  ast-grep scan -r $rule_file $SOURCE -U --globs '**/*.ts' --globs '**/*.tsx' --globs '!**/style-variables.ts' --globs '!**/dist/**' --globs '!**/node_modules/**'
}

# Check if file already has COLOR import
def has-color-import [content: string]: nothing -> bool {
  [
    "import { COLOR }"
    "{ COLOR }"
    "{ COLOR,"
    ", COLOR }"
    ", COLOR,"
  ] | any {|pattern| $content | str contains $pattern }
}

# Find the last import line index in file content
def find-last-import-idx [lines: list<string>]: nothing -> int {
  let imports = ($lines
    | enumerate
    | where { $in.item | str starts-with 'import ' }
    | get index)

  if ($imports | is-empty) { -1 } else { $imports | last }
}

# Insert COLOR import after the last import statement
def insert-color-import [content: string]: nothing -> string {
  let lines = ($content | lines)
  let last_idx = (find-last-import-idx $lines)

  match $last_idx {
    -1 => { [$COLOR_IMPORT] | append $lines | str join "\n" }
    _  => {
      $lines
        | enumerate
        | each {|row|
            if $row.index == $last_idx { [$row.item, $COLOR_IMPORT] } else { [$row.item] }
          }
        | flatten
        | str join "\n"
    }
  }
}

# ============================================================================
# Main Functions
# ============================================================================

# Replace LESS color variables using sd
def replace-less-colors [] {
  print "Replacing LESS color variables..."
  $LESS_COLOR_MAP | items {|css, less_var|
    sd -F $css $less_var ($'($SOURCE)/**/*.less' | into glob)
  }
}

# Replace TS/TSX color variables using ast-grep
def replace-ts-colors [] {
  print "Replacing TypeScript color variables..."
  mkdir $RULES_DIR

  # Build replacement rules for each color
  $TS_COLOR_MAP | items {|key, css|
    let color_key = $'COLOR.($key)'
    print $'  ($css) -> ($color_key)'

    # TSX: Apply rules for JSX attributes and object pairs
    for ctx in ['jsx', 'obj'] {
      for quote in ['single', 'double'] {
        let rule = (make-ast-rule $css $color_key 'tsx' $ctx $quote)
        run-ast-rule $rule $'tsx-($ctx)-($quote)'
      }
    }

    # TypeScript: Simple replacement (no JSX context)
    for quote in ['single', 'double'] {
      let rule = (make-ast-rule $css $color_key 'typescript' 'any' $quote)
      run-ast-rule $rule $'ts-($quote)'
    }
  }

  rm -rf $RULES_DIR
}

# Check if file should be excluded
def should-exclude [file: string]: nothing -> bool {
  $EXCLUDE_FILES | any {|pattern| $file | str contains $pattern }
}

# Add COLOR import to files that need it
def add-color-imports [] {
  print "Adding COLOR imports..."

  glob $'($SOURCE)/**/*.{ts,tsx}'
    | where { not (should-exclude $in) }
    | each {|file|
        let content = (open --raw $file)

        # Skip if no COLOR usage or already has import
        if not ($content | str contains 'COLOR.') { return }
        if (has-color-import $content) { return }

        print $'  Adding import to: ($file)'
        insert-color-import $content | save -f $file
      }
  null
}

# ============================================================================
# Main Entry Point
# ============================================================================

def main [] {
  print $"(ansi g)=== NUSI Color Migration ===(ansi rst)\n"

  print $"(ansi g)Step 1: LESS files(ansi rst)"
  replace-less-colors
  print -n (char nl)

  print $"(ansi g)Step 2: TypeScript/TSX files(ansi rst)"
  replace-ts-colors
  print -n (char nl)

  print $"(ansi g)Step 3: Add COLOR imports(ansi rst)"
  add-color-imports

  print $"\n(ansi g)=== Done! ===(ansi rst)"
}
