---
name: upgrade-termix
description: |
  Upgrade termix-nu and all related binary dependencies (nushell, just, fzf, s5cmd) to
  the latest versions. Use when:
  (1) User wants to upgrade termix-nu or its dependencies
  (2) User encounters version compatibility issues between nushell and termix-nu scripts
  (3) Nushell binary is too old to run updated termix-nu scripts
  (4) User wants to check and fix outdated tools
  Triggers: "upgrade termix", "update termix", "upgrade nushell", "upgrade just",
  "version mismatch", "nu version too old", "script compatibility error",
  "t upgrade", "upgrade all tools", "升级 termix", "升级 nushell"
---

# Upgrade Termix-Nu

Agent policy: if the user asks to upgrade `termix` or `termix-nu` without explicitly limiting
the request to a specific tool such as `nushell`, `just`, `fzf`, or `s5cmd`, treat it as an
ambiguous upgrade request and prefer the full upgrade flow with the `--all` flag. This is an
agent decision rule; the CLI default `t upgrade` / `just upgrade` behavior still upgrades
`termix-nu` only unless `--all` is specified.

## Standard Upgrade

Run from the termix-nu directory:

```bash
t upgrade -a
just upgrade -a
```

This upgrades all tools: termix-nu scripts, nushell, just, fzf, and s5cmd.

Notes:

- Default `t upgrade -a` / `just upgrade -a` flow upgrades `termix-nu` first, then upgrades
  just, nushell, fzf, and s5cmd
- If termix-nu was originally installed via `setup.nu` / `setup-termix.sh`, upgrade reuses
  that path and runs `setup-termix --all --in-place-update`, which upgrades binaries first
  and then upgrades termix-nu

To upgrade a single tool:

```bash
t upgrade                    # termix-nu only (default)
t upgrade nu                 # nushell only
t upgrade just               # just only
t upgrade fzf                # fzf only
t upgrade s5cmd              # s5cmd only

just upgrade              # termix-nu only (default)
just upgrade nu           # nushell only
just upgrade nushell      # nushell only
just upgrade just         # just only
just upgrade fzf          # fzf only
just upgrade s5cmd        # s5cmd only
```

Use `--force` to force reinstall even if the current tool already appears up to date:

```bash
t upgrade -a --force
just upgrade -a --force
```

## Post-Upgrade Diagnostics

After upgrading, run diagnostics to verify everything works:

```bash
just doctor
```

To auto-fix detected issues:

```bash
just doctor --fix
```

Common issues `doctor --fix` resolves:

- Plugin version mismatch (deletes plugin registry, re-registers plugins)
- Outdated binary dependencies (triggers upgrade)
- Nu config syntax errors (resets config)
- Some package-tools version issues

`doctor --fix` does not recreate `.env`, rewrite `TERMIX_DIR`, or recreate `.termixrc`.
If those are broken, repair them manually or rerun post-setup.

## Handling Nushell Version Compatibility Issues

When the default `just upgrade -a` / `t upgrade -a` flow updates termix-nu scripts to a newer
version but the nushell binary fails to upgrade (network issues, permission errors, etc.), a
compatibility mismatch occurs: the updated scripts may use syntax or features not supported by
the current nushell version.

Symptoms:

- Parse errors or unknown command errors after upgrading
- `just` commands fail with nushell syntax errors
- `termix.toml` shows a `minNuVer` higher than the installed `nu --version`

### Recovery Steps

1. Check the current nushell version and the required minimum version:

```bash
nu --version
# Then check termix.toml for minNuVer
```

2. If `minNuVer` in `termix.toml` is higher than the installed nushell version, roll back
   termix-nu scripts to a compatible tag. First make sure the worktree is clean or stash/commit
   local changes, because the recovery path below changes the checked out revision. Then find the
   tag where `minNuVer` matches the current nushell version:

```bash
cd $TERMIX_DIR
git fetch origin --tags --force
# List tags in reverse chronological order
git tag -l --sort=-v:refname
```

3. For each candidate tag (starting from the most recent), check its `minNuVer`:

```bash
git show <tag>:termix.toml | grep minNuVer
```

4. Once a compatible tag is found (where `minNuVer` <= current nu version), first verify it with
   a non-destructive checkout:

```bash
git switch --detach <compatible-tag>
```

5. If you want an isolated recovery environment without touching the current worktree, prefer a
   temporary worktree:

```bash
git worktree add /tmp/termix-recovery <compatible-tag>
cd /tmp/termix-recovery
```

6. Only if the user explicitly wants to roll the current local checkout back to that tag, and
   they have confirmed the current worktree is safe to overwrite, use this destructive fallback:

```bash
git reset --hard <compatible-tag>
```

7. Now retry the full upgrade. If your install method is `setup`, that retry path upgrades
   binaries first and then upgrades termix-nu; otherwise the default `upgrade-tool --all`
   path still upgrades termix-nu first and then the binaries:

```bash
just upgrade -a
```

8. If you created a temporary worktree and no longer need it after the recovery/upgrade flow,
   remove it explicitly:

```bash
cd $TERMIX_DIR
git worktree remove /tmp/termix-recovery
```

9. Verify the upgrade succeeded:

```bash
just doctor
```

### Alternative: Use Nushell MCP or Direct Diagnostics

If the mismatch is not straightforward, diagnose interactively:

```bash
# Check all versions and compare
nu --version
just --version
cat termix.toml | grep -E 'minNuVer|minJustVer|version'
```

Then based on the error messages, either:

- Roll back termix-nu scripts as described above
- Manually download and install the required nushell version
- Run `nu actions/doctor.nu --fix` if nushell can still execute the doctor script

### Windows Note

When upgrading Nushell on Windows, the running `nu.exe` cannot be overwritten in place. In that
case the upgrade flow may leave a `nu-latest.exe` next to the existing binary and require a manual
replacement step afterward.

## Key Files

- `actions/upgrade.nu` — Core upgrade logic; upgrades termix-nu repo, nushell, just, fzf, s5cmd
- `actions/setup.nu` — Setup and install logic with version comparison
- `actions/open-tools.nu` — Binary upgrade logic for regular installs; uses Homebrew on macOS and OSS downloads on Linux/Windows
- `actions/doctor.nu` — Diagnostics and auto-fix for common termix-nu issues
- `termix.toml` — Version requirements (`minNuVer`, `minJustVer`, `version`)
- `Justfile` — Entry point for `just upgrade` and `just doctor` commands
