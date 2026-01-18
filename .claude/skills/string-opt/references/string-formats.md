# Nushell String Formats Reference

## Complete String Type Reference

### 1. Bare Words

Simple unquoted strings for word-character-only content.

```nushell
let name = hello
let items = [foo bar baz]
match $type { absolute => "abs" relative => "rel" }
```

**Valid characters**: Letters, numbers, underscores, hyphens (when not at start)

**Use in**:

- Array literals: `[git patch npm]`
- Path joins: `[$root patches]`
- Match patterns: `match $x { escape => ... }`
- Record keys: `{ name: value }`

### 2. Raw Strings `r#'...'#`

Literal strings with no escape interpretation.

```nushell
# Regex patterns
let pattern = r#'(?:a/|b/)?(?:original|modified)/'#

# Paths with quotes
let path = r#'C:\Users\'John's Files'\doc.txt'#

# Multi-line content
let text = r#'Line 1
Line 2
Line 3'#
```

**Nesting**: Add more `#` to include `'#` in content:

```nushell
r##'Contains r#'nested'#'##
```

### 3. Single-Quoted Strings `'...'`

Simple strings without escape interpretation.

```nushell
let msg = 'Hello, world!'
let path = 'C:\Users\name'  # Backslashes are literal
```

**Cannot contain**: Literal single quotes (use raw strings instead)

### 4. Single-Quoted Interpolation `$'...'`

Interpolated strings without escape interpretation.

```nushell
let greeting = $'Hello, ($name)!'
let info = $'Version: ($version)'
let path = $'($base_dir)/config'
```

**Expressions**: Any valid Nushell expression in `(...)`:

```nushell
$'Sum: (1 + 2)'
$'Length: ($list | length)'
$'Upper: ($name | str upcase)'
```

**IMPORTANT**: `\'` is NOT an escape, it's literal `\` + `'`

### 5. Backtick Strings `` `...` ``

For paths and globs with spaces or special characters.

```nushell
ls `./my directory/*.nu`
cd `C:\Program Files\App`
glob `**/*.{ts,tsx}`
```

### 6. Double-Quoted Strings `"..."`

Strings with C-style escape sequences.

```nushell
let newline = "\n"
let tab = "\t"
let quote = "\""
let backslash = "\\"
let multiline = "Line 1\nLine 2"
```

**Escape sequences**:
| Escape | Character |
|--------|-----------|
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Tab |
| `\"` | Double quote |
| `\\` | Backslash |
| `\0` | Null |

### 7. Double-Quoted Interpolation `$"..."`

Interpolation WITH escape sequence support.

```nushell
print $"Hello, ($name)\n"
info $"\nProcessing ($file)..."
let msg = $"Line 1: ($a)\nLine 2: ($b)"
```

**Use only when**: You need BOTH interpolation AND escape sequences

## Decision Tree

```
Need a string?
├── Is it a simple word (letters/numbers/underscore only)?
│   └── YES → Use bare word: foo, bar, myVar
│
├── Contains regex special chars like (?:, \d, etc.?
│   └── YES → Use raw string: r#'(?:pattern)'#
│
├── Need to embed variables/expressions?
│   ├── Need escape sequences (\n, \t, etc.)?
│   │   └── YES → Use $"...": $"Hello ($name)\n"
│   └── NO → Use $'...': $'Hello ($name)'
│
├── Contains spaces and used as path/glob?
│   └── YES → Use backtick: `path with spaces`
│
├── Need escape sequences?
│   └── YES → Use "...": "line1\nline2"
│
└── Simple string?
    └── Use '...': 'hello world'
```

## Common Patterns

### Path Building

```nushell
# Preferred - bare words in arrays
let path = [$root node_modules '.pnpm'] | path join

# Avoid
let path = [$root, "node_modules", ".pnpm"] | path join
```

### Error Messages

```nushell
# Without interpolation - single quotes
err 'File not found'

# With interpolation, no escapes - single-quoted interpolation
err $'Cannot find ($file)'

# With escapes - double-quoted interpolation
err $"Error processing ($file):\n($details)"
```

### Regex Patterns

```nushell
# Raw string for complex patterns
let pattern = r#'(?:a/|b/)?(?:original|modified)/'#
$content | str replace -ar $pattern 'replacement'

# Simple patterns can use single quotes
$text | str replace -a '.' '_'
```

### Multi-line Strings

```nushell
# Raw string - preserves literal content
let text = r#'
First line
Second line
Third line
'#

# Double-quoted - interprets \n
let text = "First line\nSecond line\nThird line"
```
