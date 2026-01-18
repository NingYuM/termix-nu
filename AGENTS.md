# AGENTS.md

Open format guidelines for coding agents working with the Termix-Nu repository.

## Project Context

Termix-Nu is a comprehensive command-line toolkit written in Nushell (0.110.0+) that provides utilities for development workflows, Git operations, deployment automation, and TERP (Terminus Enterprise Resource Platform) management. It's designed to streamline daily development tasks for the Terminus ecosystem.

### Version Requirements

| Tool                      | Minimum Version | Check Command      |
| ------------------------- | --------------- | ------------------ |
| Nushell                   | 0.110.0         | `nu --version`     |
| Just                      | 1.39.0          | `just --version`   |
| @terminus/t-package-tools | 0.5.5           | For frontend tools |

## Core Principles for AI Coding Agents

### 1. Understand the Architecture First

- **Modular Design**: The project follows clear separation of concerns with dedicated directories
- **Entry Points**: Use `Justfile` as the primary task runner, `termix.toml` and `.termixrc` file for configuration
- **Core Utilities**: Reference `utils/common.nu` for shared functions and constants
- **Directory Structure**:
  - `actions/`: Core tool implementations (doctor.nu, pipeline.nu, terp-assets.nu, pnpm-patch.nu, etc.)
  - `git/`: Git operation scripts (branch.nu, git-pick.nu, sync-branch.nu, etc.)
  - `utils/`: Shared utilities (common.nu, git.nu, erda.nu)
  - `tests/`: Test files using nutest framework
  - `mall/`: Gaia Mall related scripts (i18n, locale, redevelop)
  - `run/`: Helper and setup scripts
  - `dotfiles/`: Configuration examples for terminal tools (yazi, lazygit, wezterm)

### 2. Follow Nushell Conventions

- **Function Naming**: Use kebab-case (e.g., `check-assets`, `git-batch-exec`)
- **Data Flow**: Prefer pipeline operations (`|`) for data transformation
- **Error Handling**: Use `try` blocks and `do` wrappers with English error messages
- **Type Safety**: Define explicit parameter types in function signatures
- **Documentation**: Include `--help` documentation for complex functions
- **String Format Preference** (in order of priority):
  1. **Bare word**: `hello` - for simple word-character-only strings in data contexts
  2. **Raw string**: `r#'pattern with 'quotes''#` - for regex, paths with quotes, or multi-line
  3. **Single-quoted**: `'simple string'` - for strings without single quotes
  4. **Backtick**: `` `path with spaces` `` - for paths/globs with spaces
  5. **Double-quoted/Interpolation**: `$"value: ($var)"` - only when escapes or interpolation needed

  ```nushell
  # PREFER: Bare words and single quotes
  let name = 'Alice'
  let items = [foo bar baz]

  # PREFER: Raw strings for regex patterns
  let pattern = r#'(?:a/|b/)?(?:original|modified)/'#
  $content | str replace -ar $pattern 'replacement'

  # PREFER: Backticks for paths with spaces
  ls `./my directory/*.nu`

  # ONLY WHEN NEEDED: Interpolation for dynamic content
  let result = $"Hello ($name), you have ($count) items"
  ```
- **Modern Features**:
  - Use closure-based `str replace` for complex replacements:
    ```nushell
    # Combine multiple replacements with closure
    $input | str replace -ar '[/@]' { if $in == '/' { '__' } else { '' } }
    ```
  - Use raw strings `r#'...'#` for regex patterns to avoid parser issues with `(?:` etc.
  - Use `match` expressions for pattern matching instead of nested `if` statements

### 3. Development Workflow Guidelines

- **Command Discovery**: Run `just` without arguments to see available commands
- **Environment Check**: Use `just doctor` to verify dependencies and system state
- **Testing**: Execute `just test` using nutest framework
- **Comments**: Only add ENGLISH comments when necessary or when the logic is relatively complex
- **Code Quality**: Run `just typos` for spell checking, `just cr` for code review

### 4. File and Directory Standards

- **Configuration**: Check `.env` and `.termixrc` for environment-specific settings
- **Module Imports**: Import from `utils/common.nu` for utilities, `utils/git.nu` for Git operations
- **Script Location**: Assume execution from project root directory
- **File Types**:
  - `.nu` files: Nushell scripts following project conventions
  - Configuration files: TOML, YAML, Justfile formats
  - Docker files: Multi-architecture build patterns

### 5. Integration Awareness

- **External Systems**: Understand integration with Erda Platform, DingTalk, Terminus Ecosystem
- **Plugin Dependencies**:
  - `nu_plugin_query`: JSON/XML querying (required)
  - `nu_plugin_gstat`: Git status information (required)
  - `nu_plugin_polars`: High-performance data manipulation (required for `emp` command)
  - Plugins are auto-registered via Justfile
- **Cross-Platform**: Support macOS, Linux, Windows with appropriate adaptations

## Agent Behavior Guidelines

### Generic Tool Selection

When you need to call tools from the shell, use this rubric:

- Find files by name: `fd <pattern>` or `fd -p <file-path>`
- List files in a directory: `fd . <directory>`
- Find files with extension: `fd -e <extension> <pattern>`
- Find text: `rg` (ripgrep)
- Find code structure: `ast-grep --lang <language> -p '<pattern>'`
- Select among matches: pipe to `fzf`
- JSON processing: `jaq` (jq clone focused on correctness and speed)
- YAML/XML processing: `yq`

Use `rg` for plain-text searches and `ast-grep` for syntax-aware matching when available.

### DO:

- **Analyze Before Acting**: Read existing code patterns before making changes
- **Follow Existing Patterns**: Mimic the codebase's style, libraries, and conventions
- **Use Project Tools**: Leverage `just` commands and existing utilities
- **Maintain Modularity**: Keep functionality separated in appropriate directories
- **Provide Progress Feedback**: Important operations should show progress and confirmations
- **Test Changes**: Run relevant tests after modifications
- **Document Functions**: Complex functions should include help documentation

### DON'T:

- **Create Unnecessary Files**: Prefer editing existing files over creating new ones
- **Break Dependencies**: Ensure all required tools (Nushell, Just, fzf) are considered
- **Ignore Error Handling**: Always include proper error management in scripts
- **Skip Documentation**: Major changes should update relevant documentation
- **Assume Library Availability**: Check if libraries/frameworks are already in use
- **Bypass Project Structure**: Respect the established directory organization

## Code Quality Standards

### Nushell Script Requirements

Always indent with **2 spaces**

```nushell
# Function definition pattern
def command-name [
  param1: string        # Parameter with type
  --flag: string        # Optional flag with type
  --help(-h)            # Help flag for documentation
] {
  # Implementation with error handling
  try {
    # Main logic using pipeline operations
    $input | where condition | select columns
  } catch {
    # Error handling with descriptive messages
    error make { msg: "The detailed failure reason" }
  }
}
```

### Configuration Management

- **`.termixrc`**: Local project configuration (TOML format), typically read from `origin/i` branch
  - OSS credentials (OSS_AK, OSS_SK, OSS_BUCKET, OSS_REGION, OSS_ENDPOINT)
  - Erda pipeline targets and environment-specific settings
- **`termix.toml`**: Global project configuration
  - Version requirements (minNuVer, minJustVer, minPkgToolVer)
  - Repository configurations (redevRepos, gaiaSrcRepos)
- **`.env`**: Environment variables for local development
- Use existing configuration patterns and refer to `.termixrc-example` for examples

### Testing and Validation

- Write tests in `tests/` directory using nutest framework
- Run tests with `just test` command
- For module-specific tests: `PROJECT_ROOT=/path/to/project nu tests/test-xxx.nu`
- Test functions should use `use std assert` for assertions
- Validate scripts can execute without errors
- Check integration points work correctly
- Ensure cross-platform compatibility

## Development Commands Reference

### Essential Commands

```bash
just                   # List all available commands
just ver               # Display current version
just doctor            # Check dependencies and system state
just doctor --fix      # Auto-fix common issues
just test              # Run test suite with nutest
just typos             # Spell checking
just cr                # AI-powered code review with DeepSeek
just upgrade           # Upgrade termix-nu, just, or nushell
just show-env          # Show installed app versions and environment info
```

### Git Operations

```bash
just gb                # Local branches with commit info (alias: git-branch)
just rb                # Remote branch information (alias: git-remote-branch)
just git-stat          # Git insertions/deletions statistics
just gsync             # Branch synchronization
just git-pick          # Auto cherry-pick commits between branches
just ls-tags           # List git tags by time
just pa                # Pull all local branches (alias: pull-all)
just git-desc          # Show branch description from `i` branch
```

### Deployment and Assets

```bash
just dp <env>          # Execute Erda pipeline (alias: deploy)
just dq                # Query pipeline status (alias: deploy-query)
just ta                # TERP asset management (alias: terp-assets)
just msync             # Metadata synchronization
just art               # Artifact management (create, download, upload, deploy)
```

### Standalone Scripts

Some scripts in `actions/` can run independently:

```bash
# Example: pnpm-patch tool for offline patching
nu actions/pnpm-patch.nu <package@version>

# Example: Check TERP app configuration
just doctor <host>
```

These scripts include `@example` annotations for usage documentation.

## Integration Context

### TERP Ecosystem

- Metadata synchronization capabilities
- Asset management across environments
- Integration with Terminus platform services

### Git Workflow Enhancement

- Advanced branching strategies
- Batch operations across multiple branches
- Automated synchronization and cherry-picking

### Deployment Automation

- Erda platform integration
- Pipeline management and monitoring
- Artifact production and deployment

## Agent Success Metrics

A successful coding agent working with this repository should:

1. **Maintain Code Quality**: Follow established patterns and conventions
2. **Preserve Functionality**: Ensure changes don't break existing features
3. **Enhance Productivity**: Improve or extend the toolkit's capabilities
4. **Document Changes**: Update relevant documentation and help text
5. **Test Thoroughly**: Validate changes work across supported platforms

## Notes for Agent Developers

- This is a production toolkit used in real development workflows
- Changes should be backward compatible when possible
- Consider the impact on existing users and workflows
- Respect the established architecture and design decisions
- When in doubt, follow existing patterns rather than introducing new approaches

---

_This document serves as a comprehensive guide for AI coding agents to effectively contribute to the Termix-Nu project while maintaining its quality, consistency, and functionality._
