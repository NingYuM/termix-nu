---
name: string-opt
description: Optimize string usage in Nushell scripts following best practices. Use when you need to refactor .nu files to follow Nushell string conventions (bare words, raw strings, single quotes, single-quoted interpolation over double-quoted). Also performs English spelling/grammar checks and proofreading for code comments and messages to make them more fluent, professional, and native-sounding.
---

# Nushell String Optimization Skill

Optimize string usage in Nushell scripts following established conventions, and proofread English text for clarity and professionalism.

## String Format Priority (High to Low)

1. **Bare word** - Simple word-character-only strings in data contexts
2. **Raw string** `r#'...'#` - Regex patterns, paths with quotes, multi-line content
3. **Single-quoted** `'...'` - Simple strings without single quotes
4. **Single-quoted interpolation** `$'...'` - Interpolation without escape sequences
5. **Backtick** `` `...` `` - Paths/globs with spaces
6. **Double-quoted** `"..."` - Only when escape sequences needed (`\n`, `\t`, `\"`, etc.)
7. **Double-quoted interpolation** `$"..."` - Only when both interpolation AND escapes needed

## Conversion Rules

### Convert TO bare words when:

- Inside arrays: `[foo bar baz]` not `["foo", "bar", "baz"]`
- Path join arrays: `[$dir patches]` not `[$dir, "patches"]`
- Match patterns: `match $x { absolute => ... }` not `match $x { "absolute" => ... }`

### Convert TO raw strings when:

- Regex patterns with special chars: `r#'(?:pattern)'#` not `"(?:pattern)"`
- Strings containing both quote types

### Convert TO single quotes when:

- Simple strings: `'hello world'` not `"hello world"`
- No escape sequences needed
- No interpolation needed

### Convert TO single-quoted interpolation when:

- Variables/expressions but NO escape sequences:
  - `$'Package: ($pkg.name)'` not `$"Package: ($pkg.name)"`
  - `$'Error: ($msg)'` not `$"Error: ($msg)"`

### Keep double quotes ONLY when:

- Escape sequences present: `"\n"`, `"\t"`, `"\r"`, `"\""`
- Single-quoted interpolation with escapes: `$"\nNext steps:"`, `$"Line: ($n)\n"`
- String contains literal single quotes AND needs interpolation

### IMPORTANT: Single quotes don't escape

In Nushell, `\'` inside `$'...'` is NOT an escape - it's literal backslash + quote.
To include a literal single quote in an interpolated string, use double-quoted interpolation:

```nushell
# Correct - use double quotes when literal single quotes needed
let marker = $"'($pkg)@($ver)':"

# Wrong - backslash doesn't escape in single quotes
let marker = $'\'($pkg)@($ver)\':'  # This produces literal backslashes!
```

### IMPORTANT: Nushell command expressions require `$` prefix

Strings containing Nushell command expressions wrapped in `()` MUST keep the `$` prefix for interpolation. Common examples include:

- `(ansi g)`, `(ansi r)`, `(ansi rst)` - ANSI color codes
- `(char nl)`, `(char tab)` - special characters
- Any other command call like `(date now)`, `(pwd)`, etc.

```nushell
# Correct - $ prefix required for command expressions
print $'(char nl)Artifact created successfully:'
print $'(ansi g)Success!(ansi rst)'

# Wrong - without $ these are literal text, not command calls
print '(char nl)Artifact created successfully:'  # Prints literal "(char nl)"
print '(ansi g)Success!(ansi rst)'               # Prints literal "(ansi g)"
```

**Rule**: If a string contains `(...)` that should be evaluated as a command, always use `$'...'` or `$"..."`.

## English Text Proofreading

Check and improve English in:

- Code comments
- Error messages
- User-facing strings
- Documentation strings

### Proofreading Guidelines

1. **Spelling**: Fix typos and misspellings
2. **Grammar**: Correct grammatical errors
3. **Clarity**: Simplify complex sentences
4. **Consistency**: Use consistent terminology
5. **Tone**: Professional, concise, native-sounding
6. **Technical accuracy**: Preserve technical meaning

### Common Improvements

| Before             | After                                                        |
| ------------------ | ------------------------------------------------------------ |
| "Can not find"     | "Cannot find"                                                |
| "Please to ensure" | "Please ensure"                                              |
| "the datas"        | "the data"                                                   |
| "informations"     | "information"                                                |
| "Succeed to do"    | "Successfully did"                                           |
| "Failed to do xxx" | "Could not do xxx" or "Failed to do xxx" (context-dependent) |

## Workflow

1. **Read the target .nu file(s)**
2. **Identify string optimization opportunities**:
   - Double-quoted strings that can be single-quoted
   - Double-quoted interpolation that can be single-quoted
   - Quoted strings in arrays that can be bare words
   - Regex patterns that should use raw strings
3. **Identify English text issues**:
   - Scan comments and string literals
   - Check spelling with context
   - Review grammar and phrasing
4. **Apply changes carefully**:
   - Ensure no escape sequences are lost
   - Verify syntax remains valid
   - Preserve original functionality
5. **Run tests if available** to verify no breakage
6. **Summarize changes made**

## Examples

### Array Optimization

```nushell
# Before
let dirs = [$root, "node_modules", ".pnpm"]
let tools = ["git", "patch"]

# After
let dirs = [$root node_modules '.pnpm']
let tools = [git patch]
```

### Interpolation Optimization

```nushell
# Before
info $"Package: ($pkg.name)"
err $"Error: ($tool) not found"

# After
info $'Package: ($pkg.name)'
err $'Error: ($tool) not found'
```

### Keep Double Quotes for Escapes

```nushell
# Keep - has \n escape
info $"\nNext steps:"
let content = "line1\nline2"

# Keep - contains literal single quote
let marker = $"'($name)@($ver)':"
```

### Regex with Raw Strings

```nushell
# Before
let pattern = "(?:a/|b/)?"

# After
let pattern = r#'(?:a/|b/)?'#
```

### English Proofreading

```nushell
# Before
# This function will helps to parse the datas
err "Can not found the file, please to check"

# After
# This function parses the data
err 'Cannot find the file. Please check the path.'
```

## Validation

After optimization:

1. Run the script to check for syntax errors: `nu -c "source file.nu"`
2. Run unit tests if available
3. Verify interpolation still works as expected
4. Confirm escape sequences are preserved where needed
