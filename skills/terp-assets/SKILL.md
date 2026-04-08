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
TERMIX_DIR=<repo-root> nu -c 'overlay use actions/terp-assets.nu; terp assets ...'
```

Important:

- `t ta ...` usually works through the project alias and dotenv wiring.
- Raw `nu -c 'overlay use ...'` execution does not guarantee `TERMIX_DIR` is set.
- When using the raw fallback, explicitly set `TERMIX_DIR` to the repository root unless you have already verified it is present in the environment.

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

### Test fixture environment variables

The following env vars enable offline/unit-test mode by replacing real HTTP and S3 calls with local fixture files:

| Variable                           | Purpose                                             |
| ---------------------------------- | --------------------------------------------------- |
| `TERP_ASSETS_ENABLE_FIXTURES=true` | Master switch; must be `true` to activate fixtures. |
| `TERP_ASSETS_FIXTURE_LATEST`       | Path to a local `latest.json` fixture file.         |
| `TERP_ASSETS_FIXTURE_MANIFESTS`    | Path to a JSON map of manifest URL → manifest body. |
| `TERP_ASSETS_FIXTURE_REVISIONS`    | Path to a JSON array of available revision strings. |

These variables are used by `tests/test-terp-assets.nu`. When debugging agent-mode behavior without real cloud access, set these vars and point them at the fixture files under `tests/fixtures/`.

Important:

- These variables are **test-only** and should not remain set for real cloud operations.
- Before any real `detect`, `download`, `transfer`, `init`, or `revert` against remote storage, unset all `TERP_ASSETS_FIXTURE_*` variables and `TERP_ASSETS_ENABLE_FIXTURES`.
- If fixture variables are present, call that out explicitly in your reply because validation and planning results may be based on local test data instead of the real remote state.

## Action Matrix

| action     | Mutates remote state | Required inputs                                                      | Important notes                                                                                                                                                                                                                                                                  |
| ---------- | -------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `detect`   | No                   | `--from`                                                             | `--from` can be a mount point or a full `latest.json` URL. Multiple sources separated by `,` are supported only here. `--stat` can be combined with multiple sources.                                                                                                            |
| `download` | No                   | `modules`, `--from`                                                  | `--to` is optional. If `--to` is empty or the path does not exist, the implementation **silently falls back** to a temp dir without any warning. Do not assume the user's intended dir will be used unless it already exists. Verify existence before running.                   |
| `transfer` | Yes                  | `modules`, `--from`, `--to`, `--dest-store`                          | Downloads first, then uploads. `--to` may contain multiple comma-separated targets. Requires `@terminus/t-package-tools` and git user identity. `OSS_OPTIONS` in `.termixrc` is forwarded to `package-tools s3` as extra flags (optional).                                       |
| `init`     | Yes                  | `--dest-store`                                                       | Bucket-level initialization to `terp-assets/`. Requires `s5cmd`. Store config must contain `OSS_AK`, `OSS_SK`, `OSS_BUCKET`. Optional `OSS_STYLE` (`virtual`/`path`) controls S3 addressing style; minio/ifly default to path-style, aliyun auto-detects.                        |
| `revert`   | Yes                  | `modules` (single module only), `--to`, `--dest-store`, `--revision` | Agent mode must use explicit `--revision`; no `fzf`. `--to` supports `<mount>@<alias>` format; the `@<alias>` suffix is stripped before use. Operation rewrites remote `latest.json` metadata and leaves revert trace fields (`revertAt`, `revertBy`, `revertFrom`, `revertTo`). |

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
TERMIX_DIR=<repo-root> nu -c 'overlay use actions/terp-assets.nu; terp assets detect --from <from> --agent --output json'
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

- `init`: verify `s5cmd` is installed. Confirm the `.termixrc` store config contains `OSS_AK`, `OSS_SK`, and `OSS_BUCKET`. Note `OSS_STYLE` (`virtual`/`path`) is optional; minio/ifly default to path-style, aliyun auto-detects.
- `transfer`: verify `package-tools` is installed and meets `termix.toml.minPkgToolVer`; verify git user identity is available (see note below). Optional `OSS_OPTIONS` in `.termixrc` is forwarded as extra flags.
- `revert`: verify `s5cmd` is installed; verify git user identity is available (see note below).

> **Git user identity note**: `transfer` and `revert` both record the operator who performed the action. The implementation checks `$env.DICE_OPERATOR_NAME` first; if set (e.g. in an Erda CI/CD pipeline), `git config user.name` is not consulted. Only verify `git config --get user.name` when `DICE_OPERATOR_NAME` is absent from the environment.

When `download --to <dir>` is requested:

- Check whether `<dir>` already exists **before** running the command.
- If it does not exist, the implementation **silently falls back** to the temp directory with no warning or error. Tell the user this would happen and ask whether to create the directory first or accept the temp fallback. Do not assume the command will fail or warn on its own.

### 5. Resolve revert revisions safely

For `revert`, only after `module`, `--to`, and `--dest-store` are known, probe available revisions with:

```bash
t ta revert <module> -t <to> -d <store> --agent --yes -o json
```

Fallback:

```bash
TERMIX_DIR=<repo-root> nu -c 'overlay use actions/terp-assets.nu; terp assets revert <module> --to <to> --dest-store <store> --agent --yes --output json'
```

This is safe for planning because the command will stop with `INTERACTION_REQUIRED` before mutating anything when `--revision` is missing, and it returns `availableRevisions` in the JSON error details.

After that:

- validate the user-selected revision is in `availableRevisions`
- never guess the revision

## Command Construction Rules

- Prefer showing the user-facing command as `t ta ...`.
- Prefer executing the raw `nu -c 'overlay use ...'` fallback if the shell environment does not have the `t` alias.
- When using the raw fallback, prefix the command with `TERMIX_DIR=<repo-root>` unless `TERMIX_DIR` has already been verified in the environment.
- For AI execution, use agent mode:
  - non-mutating actions: `--agent -o json`
  - mutating actions after confirmation: `--agent --yes -o json`
- Use comma-separated module and target lists exactly as confirmed by the user; do not reorder or expand them unless the user asked for `all`.

Environment precheck:

- Before any raw `nu -c 'overlay use actions/terp-assets.nu; ...'` execution, check whether `TERMIX_DIR` is available.
- If it is missing, do not retry the same command unchanged.
- Re-run with `TERMIX_DIR` explicitly set to the repository root.

## Explanation Contract

Before executing any command, always present:

1. The exact command you plan to run
2. A parameter explanation table
3. The expected effect
4. Any notable risks or prerequisites
5. A direct confirmation request

Default to a rendered, aligned plain-text table for parameter explanation.

Do not rely on Markdown table rendering for alignment. The user should see columns already lined up in a monospace block.

Preferred format:

```text
╭────────────┬──────────────┬───────────────┬──────────────────────┬──────────────────────────────────╮
│ param      │ value        │ required      │ status               │ meaning                          │
├────────────┼──────────────┼───────────────┼──────────────────────┼──────────────────────────────────┤
│ action     │ transfer     │ yes           │ valid                │ 同步动作，先下载后上传           │
│ modules    │ base,service │ yes           │ valid                │ 要同步的前端模块                 │
│ from       │ dev          │ yes           │ valid                │ 源挂载点或 latest.json 来源      │
│ to         │ terp-dev     │ yes           │ valid                │ 目标挂载点                       │
│ dest-store │ oss          │ yes           │ valid                │ .termixrc 中的目标存储配置名     │
│ agent      │ true         │ no            │ valid                │ 禁用交互并输出稳定协议           │
│ yes        │ true         │ mutation only │ pending confirmation │ 确认后才允许远端变更             │
╰────────────┴──────────────┴───────────────┴──────────────────────┴──────────────────────────────────╯
```

If needed, build the rows with Nushell and render them before replying, for example with:

```nu
$rows | table -e -t light
```

Then paste the rendered table into a fenced `text` block. Do not show the user the source expression unless they explicitly ask for it.

Only use a fenced `nu` code block when you are explicitly showing a command the user may run themselves. For display tables, prefer rendered plain-text tables in a fenced `text` block.

Avoid this style in user-facing output:

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

Instead, show the rendered table directly.

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

## JSON Protocol Reference

All agent-mode responses are written to **stdout** as a single-line JSON object. Informational output (progress, tables) is written to stderr and can be ignored by scripts.

### Success response

```json
{
  "success": true,
  "action": "<action>",
  "data": {
    "mountpoint": "<string|null>",
    "latestUrl": "<string|null>",
    "modules": "<list|null>",
    "reverted": "<list|null>",
    "counts": "<record|null>",
    "stats": "<record|null>",
    "target": "<string|null>",
    "targets": "<list|null>",
    "destStore": "<string|null>",
    "destination": "<string|null>",
    "revision": "<string|null>",
    "raw": "<original return value>"
  },
  "warnings": []
}
```

### Cancelled response

```json
{
  "success": true,
  "action": "<action>",
  "cancelled": true,
  "message": "<reason>",
  "details": {}
}
```

### Failure response (non-zero exit code)

```json
{
  "success": false,
  "action": "<action>",
  "error": {
    "code": "<ERROR_CODE>",
    "message": "<human-readable message>",
    "details": {}
  }
}
```

### Known error codes

This list is common, not exhaustive. Always inspect the actual `error.code` and `error.details` returned by the command instead of assuming only the codes below can appear.

| Error code                        | Meaning                                                                                                                                          |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `INTERACTION_REQUIRED`            | Agent mode hit a step that requires interactive input (e.g. `fzf`). `details.availableRevisions` or `details.availableModules` contains options. |
| `MUTATION_NOT_CONFIRMED`          | Mutating action called in agent mode without `--yes`.                                                                                            |
| `MISSING_MODULE`                  | `modules` argument is required but was not provided.                                                                                             |
| `MISSING_TARGET`                  | `--to` is required but was not provided.                                                                                                         |
| `MISSING_DEST_STORE`              | `--dest-store` is required but was not provided.                                                                                                 |
| `MISSING_BINARY`                  | A required binary (`s5cmd`, `fzf`, `package-tools`) is not installed. `details.tips` contains install hints.                                     |
| `MISSING_STORE_CONFIG`            | `.termixrc` store config is missing required keys (`OSS_AK`, `OSS_SK`, `OSS_BUCKET`).                                                            |
| `MISSING_STORAGE_ENV`             | S3 credential env vars are not set before a storage operation.                                                                                   |
| `INVALID_MODULES`                 | One or more module names are not present in `latest.json`. `details.availableModules` lists valid options.                                       |
| `INVALID_REVISION`                | The specified `--revision` does not exist. `details.availableRevisions` lists valid options.                                                     |
| `INVALID_STORE_TYPE`              | The store `TYPE` in `.termixrc` is not one of `aliyun`, `minio`, `volc`, `ifly`.                                                                 |
| `INVALID_OUTPUT`                  | `--output` value is not `text` or `json`.                                                                                                        |
| `INVALID_LATEST_JSON`             | The fetched `latest.json` contains unrecognized module names.                                                                                    |
| `MULTI_MODULE_REVERT_UNSUPPORTED` | `revert` does not support comma-separated multiple modules.                                                                                      |
| `PACKAGE_TOOLS_TOO_OLD`           | Installed `package-tools` version is below `termix.toml.minPkgToolVer`.                                                                          |
| `GIT_USER_REQUIRED`               | Git user name is not configured and `DICE_OPERATOR_NAME` is not set.                                                                             |
| `NO_REVISIONS_FOUND`              | No revision directories were found for the module in remote storage.                                                                             |
| `REVERT_REVISION_LIST_FAILED`     | `s5cmd ls` call to enumerate available revisions failed.                                                                                         |
| `REVERT_NAMESPACE_FETCH_FAILED`   | Failed to copy `namespace.json` for the selected revision.                                                                                       |
| `REVERT_LATEST_FETCH_FAILED`      | Failed to copy `latest.json` from remote before revert write.                                                                                    |
| `REVERT_SYNC_FAILED`              | Failed to upload the updated `latest.json` back to remote storage.                                                                               |
| `MANIFEST_FETCH_FAILED`           | Failed to fetch `manifest.json` for a module during download.                                                                                    |
| `TRANSFER_FAILED`                 | `package-tools s3` upload returned a non-zero exit code.                                                                                         |
| `INIT_CHECK_FAILED`               | `s5cmd --dry-run sync` returned errors during `init` pre-check.                                                                                  |
| `SYNC_FAILED`                     | One or more asset directories failed to sync via `s5cmd`.                                                                                        |
| `CONFIRMATION_MISMATCH`           | User's typed confirmation does not match the expected mount point.                                                                               |

## Execution Gate

Do not run the final command until the user explicitly confirms.

After confirmation:

- execute the validated command
- summarize the real result
- include returned URLs, target mount points, downloaded directory, or revision details when available
- if execution fails, report the exact structured error and next unblock step
