# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Termix-nu is a comprehensive command-line toolkit written in Nushell that provides utilities for development workflows, Git operations, deployment automation, and TERP (Terminus Enterprise Resource Platform) management. It's designed to streamline daily development tasks for the Terminus ecosystem.

## Architecture

The project follows a modular architecture with clear separation of concerns:

- **actions/**: Core functionality modules for various operations (deployment, meta-sync, asset management, etc.)
- **git/**: Git-specific operations and workflows
- **utils/**: Common utilities and helper functions
- **mall/**: E-commerce platform specific tools
- **dotfiles/**: Configuration files for various tools (Nu, Helix, Kitty, etc.)
- **run/**: Standalone scripts and utilities
- **tests/**: Test files

### Key Files

- `Justfile`: Main command definitions and task runner configuration
- `termix.toml`: Global configuration file with version requirements and settings
- `utils/common.nu`: Core utility functions and constants
- `cr`: Code review script entry point

## Development Commands

### Setup and Prerequisites

The project requires:
- Nushell (>= 0.106.0)
- Just (>= 1.39.0)
- fzf (for interactive selections)
- Optional: @terminus/t-package-tools (>= 0.5.5) for asset management

### Common Development Commands

```bash
# List all available commands
just

# Check system dependencies and diagnose issues
just doctor

# Self-diagnosis with automatic fixes
just doctor --fix

# Upgrade termix-nu and dependencies
just upgrade

# Check current version
just ver

# Show environment information
just show-env
```

### Git Operations

```bash
# List local branches with commit info
just git-branch

# Show remote branches
just git-remote-branch

# Git statistics for commits
just git-stat

# Branch description management
just git-desc

# Batch operations on multiple branches
just git-batch-exec "command" branch1,branch2

# Cherry-pick commits
just git-pick

# Branch synchronization
just gsync
```

### Frontend Development

```bash
# Query Node.js dependencies across branches
just query-deps <dependency> --branches develop,master

# List available Node.js versions
just ls-node

# Manage TERP assets
just terp-assets download all --from dev --to staging
just ta # alias for terp-assets
```

### Deployment and Pipeline Management

```bash
# Deploy via Erda pipeline
just deploy dev
just dp # alias for deploy

# Query deployment status
just deploy-query <pipeline-id>
just dq # alias for deploy-query

# Artifact management
just art deploy --env dev --version 2.5.24.0130
just art produce --from trantor --branch release/latest
```

### Meta Data Operations

```bash
# Synchronize TERP metadata
just msync --all
just msync HR_ATT,HR_PER,HR_REC --from dev --to test
```

## Configuration

### Environment Setup

1. Copy `.env-example` to `.env` and configure variables
2. Optionally copy `.termixrc-example` to `.termixrc` for project-specific settings
3. Set up `TERMIX_DIR` environment variable pointing to the repository root

### Key Configuration Files

- `.env`: Environment variables (credentials, API keys, etc.)
- `.termixrc`: Project-specific configuration (TOML format)
- `termix.toml`: Global settings and version requirements

## Testing

```bash
# Run tests using nutest
just test
```

## Code Quality

- The project uses cSpell for spell checking: `just typos`
- Code review can be performed with the built-in AI tool: `just cr`
- All scripts follow Nushell best practices and conventions

## Plugin System

The project uses several Nushell plugins that are automatically registered:
- `nu_plugin_query`: JSON/XML query capabilities
- `nu_plugin_gstat`: Git statistics
- `nu_plugin_polars`: Data manipulation

## Integration Points

- **Erda Platform**: Pipeline deployment and artifact management
- **DingTalk**: Notification system
- **Terminus Ecosystem**: TERP metadata and asset synchronization
- **Git Workflows**: Advanced branching and synchronization strategies

## Important Notes

- All commands are prefixed with `just` or aliased as `t` when properly configured
- The system automatically checks and suggests upgrades for dependencies
- Interactive commands use fzf for enhanced user experience
- Cross-platform support (macOS, Linux, Windows) with platform-specific adaptations
