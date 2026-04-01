---
name: setup-termix
description: |
  Initialize and configure termix-nu after cloning the repository. Use when:
  (1) Setting up termix-nu on a new machine
  (2) Troubleshooting termix-nu installation or configuration issues
  (3) Fixing broken termix-nu environment (plugins, config, dependencies)
  Triggers: "setup termix", "install termix", "configure termix", "termix not working",
  "t command not found", "nushell error", "plugin error", "fix termix"
---

# Setup Termix-Nu

Termix-nu is a Nushell-based CLI toolkit for Terminus development workflows.

## Quick Setup

Run from the termix-nu repository root:

```bash
bash run/setup-termix.sh [DEST_DIR]
```

- Default `DEST_DIR`: `/usr/local/bin/`
- First ensures `nu` is installed or upgraded, then calls `actions/setup.nu`
- `actions/setup.nu` installs or upgrades: nushell, just, fzf, s5cmd
- Auto-runs `run/post-setup.nu` for configuration unless `TERMIX_SKIP_POST_SETUP=1`

### What Post-Setup Does

1. Creates `.env` from `.env-example` if not exists, sets `TERMIX_DIR`
2. Creates `.termixrc` from `.termixrc-example` if not exists
3. Creates or reuses symlinks: `~/.env` → `.env`, `~/.justfile` → `Justfile`
4. Keeps existing plain files unchanged; refuses to overwrite symlinks that point outside the current termix directory
5. Adds `t` alias to auto-detected shells (bash, zsh, fish, nu, sh); also supports ksh, csh, tcsh via `--shells`
6. Refuses to overwrite a conflicting existing `t` alias; asks for manual reconciliation instead

## Diagnosing Issues

Run from termix-nu directory:

```bash
# Check for problems
nu actions/doctor.nu

# Auto-fix problems
nu actions/doctor.nu --fix

# Or via just (if working)
just doctor
just doctor --fix
```

`doctor --fix` can repair Nu config, plugin registration, outdated dependencies, and some
package-tools issues. It does not rewrite `.env`, recreate `.termixrc`, or repair an invalid
`TERMIX_DIR`; use `nu run/post-setup.nu` or edit `.env` manually for those.

### Doctor Checks

| Check          | Description                                         |
| -------------- | --------------------------------------------------- |
| `TERMIX_DIR`   | Environment variable points to valid termix-nu root |
| Nu config      | Syntax valid, resets if corrupted                   |
| Plugins        | Version matches nu, files exist                     |
| macOS version  | Compatibility check                                 |
| Dependencies   | nu, just, fzf, s5cmd versions                       |
| termix version | Local repo version                                  |
| package-tools  | npm package version                                 |

For upgrading termix-nu or binary dependencies as a primary goal, use the `upgrade-termix`
skill instead.

## Manual Configuration

If auto-setup fails, configure manually:

```bash
cd termix-nu
cp .env-example .env
cp .termixrc-example .termixrc
# Edit .env: set TERMIX_DIR to absolute path of termix-nu

# Create symlinks
ln -s $(pwd)/.env ~/.env
ln -s $(pwd)/Justfile ~/.justfile

# Add to shell config (~/.zshrc, ~/.bashrc, etc.)
alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'
```

## Common Issues

### Plugin Version Mismatch

Symptoms: Nu startup errors about plugins

```bash
nu -c 'rm $nu.plugin-path'
just doctor --fix
```

If `nu` itself cannot start, reinstall or upgrade `nu` first, then rerun doctor.

### Config Syntax Error

Symptoms: Nu won't start, config parse errors

```bash
nu -c 'config reset -n'
```

### Missing Dependencies

Symptoms: `command not found` for just, fzf, etc.

```bash
bash run/setup-termix.sh
```

### TERMIX_DIR Not Set

Symptoms: `t` commands fail, "TERMIX_DIR not set"

Edit `.env` and ensure:

```bash
TERMIX_DIR='/absolute/path/to/termix-nu'
```

## Platform Notes

- **macOS/Linux**: Use `bash run/setup-termix.sh`
- **Windows**: `run/setup-termix.sh` is not supported; install `nu` and `just` manually first,
  and install `fzf` / `s5cmd` as needed, then configure `.env`, `.termixrc`, `.justfile`, and
  shell alias yourself
- **Docker**: `registry.erda.cloud/terp/termix:latest` (stable) or `termix:bleeding` (dev)

## Re-running Post-Setup

If symlinks or aliases need reconfiguration:

```bash
nu run/post-setup.nu [termix_dir] [--shells bash,zsh,nu,ksh] [--home-dir /path] [--nu-config-path /path]
```

## Version Requirements

Check `termix.toml` for minimum versions:

- `minNuVer`: Minimum Nushell version
- `minJustVer`: Minimum Just version
- `minPkgToolVer`: Minimum @terminus/t-package-tools version

## Debugging with Nushell MCP

When diagnosing issues programmatically:

1. Check environment: `$env.TERMIX_DIR`
2. Verify paths: `[$env.TERMIX_DIR 'termix.toml'] | path join | path exists`
3. Check versions: `nu --version`, `just --version`
4. Read config: `open termix.toml`
5. Test plugins: `open $nu.plugin-path`
