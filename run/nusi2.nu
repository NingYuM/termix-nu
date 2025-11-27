# REF:
#   1.  https://github.com/chmln/sd

const LESS_COLOR_MAP = {
    # 主题色替换
    'rgb(var(--nusi-primary))' : '@primary'
    'rgb(var(--nusi-primary-1))' : '@primary-1'
    'rgb(var(--nusi-primary-2))' : '@primary-2'
    'rgb(var(--nusi-primary-3))' : '@primary-3'
    'rgb(var(--nusi-primary-4))' : '@primary-4'
    # 中性色替换
    'rgb(var(--nusi-neutral))' : '@middle'
    'rgb(var(--nusi-neutral-1))' : '@middle-1'
    'rgb(var(--nusi-neutral-2))' : '@middle-2'
    'rgb(var(--nusi-neutral-3))' : '@middle-3'
    'rgb(var(--nusi-neutral-4))' : '@middle-4'
    'rgb(var(--nusi-neutral-5))' : '@middle-5'
    'rgb(var(--nusi-neutral-6))' : '@middle-6'
    'rgb(var(--nusi-neutral-7))' : '@middle-7'
    'rgb(var(--nusi-neutral-55))' : '@middle-2'
    'rgb(var(--nusi-neutral-85))' : '@middle-1'
    'rgb(var(--nusi-neutral-20))' : '@middle-4'
    'rgb(var(--nusi-neutral-10))' : '@middle-4'
    'rgb(var(--nusi-neutral-40))' : '@middle-3'
    # 错误色替换
    'rgb(var(--nusi-error))': '@error'
    'rgb(var(--nusi-error-1))': '@error-light'
    'rgb(var(--nusi-error-2))': '@error-dark'
    'rgb(var(--nusi-error-3))': '@error-heavy'
    # 警告色替换
    'rgb(var(--nusi-warn))': '@warn'
    'rgb(var(--nusi-warn-1))': '@warn-light'
    'rgb(var(--nusi-warn-2))': '@warn-dark'
    # 提示色替换
    'rgb(var(--nusi-info))': '@info'
    'rgb(var(--nusi-info-1))': '@info-light'
    'rgb(var(--nusi-info-2))': '@info-dark'
    # 成功色替换
    'rgb(var(--nusi-success))': '@success'
    'rgb(var(--nusi-success-1))': '@success-light'
    'rgb(var(--nusi-success-2))': '@success-dark'
    # 其他颜色替换
    'rgb(var(--nusi-text))': '@color-text'
    'rgb(var(--nusi-color-white))': '@color-white'
};

const TS_COLOR_MAP = {
  WHITE: 'rgb(var(--nusi-color-white))',
  PRIMARY: 'rgb(var(--nusi-primary))',
  PRIMARY1: 'rgb(var(--nusi-primary-1))',
  PRIMARY2: 'rgb(var(--nusi-primary-2))',
  PRIMARY3: 'rgb(var(--nusi-primary-3))',
  PRIMARY4: 'rgb(var(--nusi-primary-4))',
  MIDDLE: 'rgb(var(--nusi-neutral))',
  MIDDLE1: 'rgb(var(--nusi-neutral-1))',
  MIDDLE2: 'rgb(var(--nusi-neutral-2))',
  MIDDLE3: 'rgb(var(--nusi-neutral-3))',
  MIDDLE4: 'rgb(var(--nusi-neutral-4))',
  MIDDLE5: 'rgb(var(--nusi-neutral-5))',
  MIDDLE6: 'rgb(var(--nusi-neutral-6))',
  MIDDLE7: 'rgb(var(--nusi-neutral-7))',
  ERROR: 'rgb(var(--nusi-error))',
  ERROR_LIGHT: 'rgb(var(--nusi-error-1))',
  ERROR_DARK: 'rgb(var(--nusi-error-2))',
  ERROR_HEAVY: 'rgb(var(--nusi-error-3))',
  WARN: 'rgb(var(--nusi-warn))',
  WARN_LIGHT: 'rgb(var(--nusi-warn-1))',
  WARN_DARK: 'rgb(var(--nusi-warn-2))',
  INFO: 'rgb(var(--nusi-info))',
  INFO_LIGHT: 'rgb(var(--nusi-info-1))',
  INFO_DARK: 'rgb(var(--nusi-info-2))',
  SUCCESS: 'rgb(var(--nusi-success))',
  SUCCESS_LIGHT: 'rgb(var(--nusi-success-1))',
  SUCCESS_DARK: 'rgb(var(--nusi-success-2))',
  TEXT: 'rgb(var(--nusi-text))',
};

const source = '/Users/hustcer/iWork/terminus/terp-ui/packages/pc/src'

# LESS Color replacement using sd
for ky in ($LESS_COLOR_MAP | columns) {
    sd -F $ky ($LESS_COLOR_MAP | get $ky) ($'($source)/**/*.less' | into glob)
}

# COLOR import statement to add
const COLOR_IMPORT = "import { COLOR } from '@/constants/style-variables';"

# TS/TSX Color replacement using ast-grep
# Replace rgb(var(--nusi-*)) with COLOR.* constants
# REF: https://ast-grep.github.io/

# Step 1: Use ast-grep to find files containing nusi color variables
def find-files-with-colors [] {
  # Search for files containing rgb(var(--nusi- pattern using ast-grep
  let result = (do { ast-grep run --pattern "'rgb(var(--nusi-$$$))'" --lang tsx $source --json } | complete)
  if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
    $result.stdout | from json | get file | uniq
  } else {
    []
  }
}

# Step 2: Replace color values using ast-grep for each color pattern
def replace-colors-with-ast-grep [] {
  # Build reverse map: css-value -> COLOR.KEY
  let color_replacements = ($TS_COLOR_MAP | transpose key val
    | each {|row| { css: $row.val, color_key: $'COLOR.($row.key)' } })

  # Create temporary directory for ast-grep rules
  let rules_dir = '/tmp/ast-grep-color-rules'
  mkdir $rules_dir

  # Run ast-grep replacement for each color
  # We need two different replacement strategies:
  # 1. JSX attributes: 'xxx' or "xxx" → {COLOR.XXX}
  # 2. Object properties: 'xxx' or "xxx" → COLOR.XXX
  for repl in $color_replacements {
    print $'Replacing ($repl.css) with ($repl.color_key)...'

    # For YAML, we need to properly escape the pattern
    # Single-quoted pattern in YAML: pattern: "'rgb(...)'"
    # Double-quoted pattern in YAML: pattern: '"rgb(...)"'

    # Create YAML rule for JSX attribute context (needs curly braces)
    # Using list and str join for cleaner YAML generation
    let jsx_rule_single = ([
      "id: jsx-color-replace-single"
      "language: tsx"
      "rule:"
      $"  pattern: \"'($repl.css)'\""
      "  inside:"
      "    kind: jsx_attribute"
      $"fix: \"{($repl.color_key)}\""
    ] | str join "\n")

    let jsx_rule_double = ([
      "id: jsx-color-replace-double"
      "language: tsx"
      "rule:"
      ("  pattern: '\"" + $repl.css + "\"'")
      "  inside:"
      "    kind: jsx_attribute"
      $"fix: \"{($repl.color_key)}\""
    ] | str join "\n")

    # Create YAML rule for object property context (no curly braces)
    let obj_rule_single = ([
      "id: obj-color-replace-single"
      "language: tsx"
      "rule:"
      $"  pattern: \"'($repl.css)'\""
      "  inside:"
      "    kind: pair"
      $"fix: ($repl.color_key)"
    ] | str join "\n")

    let obj_rule_double = ([
      "id: obj-color-replace-double"
      "language: tsx"
      "rule:"
      ("  pattern: '\"" + $repl.css + "\"'")
      "  inside:"
      "    kind: pair"
      $"fix: ($repl.color_key)"
    ] | str join "\n")

    # Write and execute JSX attribute rules
    $jsx_rule_single | save -f $'($rules_dir)/jsx-single.yml'
    ast-grep scan -r $'($rules_dir)/jsx-single.yml' $source -U

    $jsx_rule_double | save -f $'($rules_dir)/jsx-double.yml'
    ast-grep scan -r $'($rules_dir)/jsx-double.yml' $source -U

    # Write and execute object property rules
    $obj_rule_single | save -f $'($rules_dir)/obj-single.yml'
    ast-grep scan -r $'($rules_dir)/obj-single.yml' $source -U

    $obj_rule_double | save -f $'($rules_dir)/obj-double.yml'
    ast-grep scan -r $'($rules_dir)/obj-double.yml' $source -U
  }

  # Clean up temporary rules directory
  rm -rf $rules_dir
}

# Step 3: Add COLOR import to files that use COLOR.* but don't have the import
def add-color-imports [] {
  # Find all ts/tsx files that contain COLOR. but don't have the import
  let files = (glob $'($source)/**/*.{ts,tsx}')

  for file in $files {
    # Skip files in node_modules or dist
    if ($file | str contains 'node_modules') or ($file | str contains '/dist/') {
      continue
    }

    let content = (open --raw $file)

    # Check if file contains COLOR. usage
    if not ($content | str contains 'COLOR.') {
      continue
    }

    # Check if COLOR import already exists
    if ($content | str contains "import { COLOR }") or ($content | str contains "{ COLOR }") or ($content | str contains "{ COLOR,") or ($content | str contains ", COLOR }") or ($content | str contains ", COLOR,") {
      continue
    }

    print $'Adding COLOR import to: ($file)'

    # Find a good place to insert the import - after the last import statement
    let lines = ($content | lines)
    mut result_lines = []
    mut last_import_idx = -1

    # First pass: find the last import line index
    for idx in 0..<($lines | length) {
      let line = ($lines | get $idx)
      if ($line | str starts-with 'import ') {
        $last_import_idx = $idx
      }
    }

    # Second pass: build result with import inserted after last import
    for idx in 0..<($lines | length) {
      let line = ($lines | get $idx)
      $result_lines = ($result_lines | append $line)

      if $idx == $last_import_idx {
        $result_lines = ($result_lines | append $COLOR_IMPORT)
      }
    }

    # If no imports found, add at the beginning
    if $last_import_idx == -1 {
      $result_lines = ([$COLOR_IMPORT] | append ($content | lines))
    }

    # Save the modified file
    $result_lines | str join "\n" | save -f $file
  }
}

# Execute the replacement workflow
def replace-ts-colors [] {
  print "Step 1: Replacing color values using ast-grep..."
  replace-colors-with-ast-grep

  print "\nStep 2: Adding COLOR imports to modified files..."
  add-color-imports

  print "\nDone! Color replacement completed."
}

# Execute the replacement function
replace-ts-colors
