# AGENTS.md

Open format guidelines for coding agents working with the Termix-Nu repository.

## Project Context

Termix-Nu is a comprehensive command-line toolkit written in Nushell (0.107.0+) that provides utilities for development workflows, Git operations, deployment automation, and TERP (Terminus Enterprise Resource Platform) management. It's designed to streamline daily development tasks for the Terminus ecosystem.

## Core Principles for AI Coding Agents

### 1. Understand the Architecture First
- **Modular Design**: The project follows clear separation of concerns with dedicated directories
- **Entry Points**: Use `Justfile` as the primary task runner, `termix.toml` and `.termixrc` file for configuration
- **Core Utilities**: Reference `utils/common.nu` for shared functions and constants

### 2. Follow Nushell Conventions
- **Function Naming**: Use kebab-case (e.g., `check-assets`, `git-batch-exec`)
- **Data Flow**: Prefer pipeline operations (`|`) for data transformation
- **Error Handling**: Use `try` blocks and `do` wrappers with English error messages
- **Type Safety**: Define explicit parameter types in function signatures
- **Documentation**: Include `--help` documentation for complex functions

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
- **Plugin Dependencies**: Be aware of `nu_plugin_query`, `nu_plugin_gstat`, `nu_plugin_polars`
- **Cross-Platform**: Support macOS, Linux, Windows with appropriate adaptations

## Agent Behavior Guidelines

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
- Environment variables through `.env` file
- Project settings via `.termixrc` (TOML format)
- Global configuration in `termix.toml`
- Use existing configuration patterns

### Testing and Validation
- Write tests in `tests/` directory using nutest
- Validate scripts can execute without errors
- Check integration points work correctly
- Ensure cross-platform compatibility

## Development Commands Reference

### Essential Commands
```bash
just                   # List all available commands
just doctor            # Check dependencies and system state
just doctor --fix      # Auto-fix common issues
just test              # Run test suite
just typos             # Spell checking
just cr                # AI-powered code review
```

### Git Operations
```bash
just git-branch        # Local branches with commit info
just git-remote-branch # Remote branch information
just git-stat          # Git statistics
just gsync             # Branch synchronization
```

### Deployment and Assets
```bash
just deploy <env>      # Deploy via Erda pipeline
just terp-assets       # TERP asset management
just msync             # Metadata synchronization
```

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

*This document serves as a comprehensive guide for AI coding agents to effectively contribute to the Termix-Nu project while maintaining its quality, consistency, and functionality.*
