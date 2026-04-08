---
name: terp-assets
description: |
  Plan, validate, explain, and safely execute `t terp-assets` / `t ta` operations for TERP
  static assets. Use when the user wants to inspect `latest.json`, initialize bucket-level
  public assets, download frontend assets, transfer modules between mount points or stores,
  or revert a module to a previous revision. Triggers: "terp-assets", "t ta", "t terp-assets",
  "TERP 静态资源", "latest.json", "静态资源同步", "同步模块", "下载静态资源", "初始化静态资源",
  "回滚静态资源", "transfer assets", "revert module", "detect assets".
---

# TERP Assets

This skill is for AI-assisted `terp-assets` work in this repository.

User-facing canonical command:

```bash
t ta ...
```

Shell fallback when `t` is unavailable:

```bash
nu -c 'overlay use actions/terp-assets.nu; terp assets ...'
```

## Safety Contract

- Never guess missing `modules`, `--from`, `--to`, `--dest-store`, or `--revision`.
- For `init`, `transfer`, and `revert`, do not execute anything until the user explicitly confirms.
- Prefer `--agent -o json` for AI-driven probing and execution so errors are structured and no interactive UI is entered.
- In agent mode, mutation actions require `--yes`. Only add `--yes` after the user has confirmed execution.
- If a required tool, config, credential, or git identity is missing, stop and say exactly what is missing.
- Treat `all` as high risk. Call out the blast radius and require especially explicit confirmation.

## Source of Truth

Consult these files as needed:

- [`actions/terp-assets.nu`](../../actions/terp-assets.nu): command contract and real behavior
- [`README.md`](../../README.md): section `### 29. TERP 静态资源云端同步`
- [`tests/test-terp-assets.nu`](../../tests/test-terp-assets.nu): agent-mode failure contracts
- [`Justfile`](../../Justfile): `t terp-assets` / `t ta` entrypoint
- [`termix.toml`](../../termix.toml): TERP assets configuration tips

## Action Matrix

| action | Mutates remote state | Required inputs | Important notes |
| --- | --- | --- | --- |
| `detect` | No | `--from` | `--from` can be a mount point or a full `latest.json` URL. Multiple sources separated by `,` are supported only here. |
| `download` | No | `modules`, `--from` | `--to` is optional. If `--to` is empty or the path does not exist, the implementation silently falls back to a temp dir. Do not assume the user's intended dir will be used unless it already exists. |
| `transfer` | Yes | `modules`, `--from`, `--to`, `--dest-store` | Downloads first, then uploads. `--to` may contain multiple comma-separated targets. Requires `@terminus/t-package-tools` and git user identity. |
| `init` | Yes | `--dest-store` | Bucket-level initialization to `terp-assets/`. Requires `s5cmd` and valid destination store config. |
| `revert` | Yes | `modules` (single module only), `--to`, `--dest-store`, `--revision` | Agent mode must use explicit `--revision`; no `fzf`. Operation rewrites remote `latest.json` metadata and leaves revert trace fields. |

## Validation Workflow

### 1. Determine the action

Map the user's intent to one of:

- `detect`
- `download`
- `transfer`
- `init`
- `revert`

If the intent is ambiguous, ask a focused question instead of guessing.

### 2. Gather required parameters

Collect the exact values required by the chosen action.

Do not rely on interactive flows for AI execution:

- Do not omit `modules` and expect manual selection.
- Do not omit `--revision` and expect `fzf`.
- Do not rely on text-mode confirmation prompts.

### 3. Validate the source and modules first

For `detect`, `download`, and `transfer`, probe the source with:

```bash
t ta detect -f <from> --agent -o json
```

Fallback:

```bash
nu -c 'overlay use actions/terp-assets.nu; terp assets detect --from <from> --agent --output json'
```

Use the returned JSON to validate:

- the mount point or `latest.json` URL is readable
- the module list exists
- requested modules are valid

Validate `modules` against `data.raw.modules[].module` from the JSON response. If the requested module is absent, stop and ask the user to correct it.

### 4. Validate destination store and local prerequisites

When `--dest-store` is involved:

- Check that `.termixrc` contains that store key.
- Confirm its `TYPE` is supported: `aliyun`, `minio`, `volc`, or `ifly`.

When action-specific tools are required:

- `init`: verify `s5cmd` is installed.
- `transfer`: verify `package-tools` is installed and meets `termix.toml.minPkgToolVer`; verify `git config --get user.name` is non-empty.
- `revert`: verify `s5cmd` is installed; verify `git config --get user.name` is non-empty.

When `download --to <dir>` is requested:

- Check whether `<dir>` already exists.
- If it does not exist, explicitly tell the user the implementation will fall back to the temp directory instead of using the missing path.
- Ask whether they want to use the temp directory or provide an existing path. Do not silently proceed.

### 5. Resolve revert revisions safely

For `revert`, only after `module`, `--to`, and `--dest-store` are known, probe available revisions with:

```bash
t ta revert <module> -t <to> -d <store> --agent --yes -o json
```

Fallback:

```bash
nu -c 'overlay use actions/terp-assets.nu; terp assets revert <module> --to <to> --dest-store <store> --agent --yes --output json'
```

This is safe for planning because the command will stop with `INTERACTION_REQUIRED` before mutating anything when `--revision` is missing, and it returns `availableRevisions` in the JSON error details.

After that:

- validate the user-selected revision is in `availableRevisions`
- never guess the revision

## Command Construction Rules

- Prefer showing the user-facing command as `t ta ...`.
- Prefer executing the raw `nu -c 'overlay use ...'` fallback if the shell environment does not have the `t` alias.
- For AI execution, use agent mode:
  - non-mutating actions: `--agent -o json`
  - mutating actions after confirmation: `--agent --yes -o json`
- Use comma-separated module and target lists exactly as confirmed by the user; do not reorder or expand them unless the user asked for `all`.

## Explanation Contract

Before executing any command, always present:

1. The exact command you plan to run
2. A parameter explanation table
3. The expected effect
4. Any notable risks or prerequisites
5. A direct confirmation request

Prefer a Nushell-style table for parameter explanation, for example:

```nu
[
  { param: action, value: transfer, required: yes, status: valid, meaning: '同步动作，先下载后上传' }
  { param: modules, value: 'base,service', required: yes, status: valid, meaning: '要同步的前端模块' }
  { param: from, value: dev, required: yes, status: valid, meaning: '源挂载点或 latest.json 来源' }
  { param: to, value: 'terp-dev', required: yes, status: valid, meaning: '目标挂载点' }
  { param: dest-store, value: oss, required: yes, status: valid, meaning: '.termixrc 中的目标存储配置名' }
  { param: agent, value: true, required: no, status: valid, meaning: '禁用交互并输出稳定协议' }
  { param: yes, value: true, required: 'mutation only', status: pending_confirmation, meaning: '确认后才允许远端变更' }
] | table -e
```

When any required field is missing or uncertain, be explicit:

- state what is missing
- explain why it is required
- ask the user for the exact value

Do not guess.

## Effect Summary Rules

Explain the effect in action-specific terms:

- `detect`: reads `latest.json` and optionally aggregates manifest statistics; no remote mutation
- `download`: writes `latest-<mount>.json` and per-module downloaded assets under the destination directory or temp directory
- `transfer`: downloads assets locally, updates `namespace.json` sync metadata, uploads module artifacts to the target mount point(s), and makes target `latest.json` reachable at the destination store
- `init`: downloads the public `terp-assets.tar.gz` package and syncs bucket-level static assets into `s3://<bucket>/terp-assets`
- `revert`: rewrites the selected module entry in remote `latest.json` to point to the chosen revision and records `revertAt`, `revertBy`, `revertFrom`, and `revertTo`

## Execution Gate

Do not run the final command until the user explicitly confirms.

After confirmation:

- execute the validated command
- summarize the real result
- include returned URLs, target mount points, downloaded directory, or revision details when available
- if execution fails, report the exact structured error and next unblock step
