---
name: trantor-artifact
description: |
  Safely plan, validate, explain, and execute `t art` / ERDA artifact operations for Trantor
  and downstream ERDA projects. Use when the user wants to list artifact configs, inspect
  releases, build artifacts, pack app artifacts into project artifacts, consume upstream
  artifacts, create deploy orders, deploy by version, deploy by deploy-order ID, or explain
  `actions/artifact.nu` behavior. Triggers: "t art", "artifact", "art deploy", "art consume",
  "art produce", "art pack", "ERDA 制品", "制品部署", "部署单", "deploy order",
  "Trantor artifact", "artifact version", "list releases".
---

# Trantor Artifact

This skill is for AI-assisted `t art` work in this repository.

User-facing canonical command:

```bash
t art ...
```

Shell fallback when `t` is unavailable:

```bash
TERMIX_DIR=<repo-root> nu -c 'overlay use actions/artifact.nu; artifacts ...'
```

Important:

- Prefer `t art ...` when the alias is available.
- The raw Nushell fallback must run with `TERMIX_DIR` pointing at the repository root.
- Treat read-only helper actions and `--dry-run` as the default planning surface.

## Safety Contract

- Never guess `--version`, `--doid`, `--dest-env`, `--deploy-group`, `--from`, `--to`, or `--branch`.
- Default source, destination, branch, or deploy-group values may be used only after you verify them from config or command output and explicitly tell the user that a verified default will be used.
- Prefer `--non-interactive --output json` for AI probing and execution so the contract is stable.
- Mutation-capable actions require explicit confirmation before execution.
- In non-interactive mode, mutation-capable actions require `--yes`. Only add `--yes` after the user has confirmed.
- ERDA authentication may come from either `.termixrc` artifact config (`username` / `password`) or `TERMIX_DIR/.env` (`ERDA_USERNAME` / `ERDA_PASSWORD`). When planning a real mutation, verify that at least one of these sources is available and say which source will be used.
- If a required parameter is missing or any value is uncertain, stop and ask the user for the exact value. Do not infer from naming patterns or prior releases.
- Never execute a destructive or state-changing `t art` command in the same response where you first assemble it.

## Source of Truth

Consult these sources as needed:

- [`actions/artifact.nu`](../../actions/artifact.nu): real command contract and execution behavior
- [`README.md`](../../README.md): section `### 31. ERDA 制品部署助手`
- [`tests/test-artifact.nu`](../../tests/test-artifact.nu): non-interactive and JSON contract
- [`Justfile`](../../Justfile): `t art` entrypoint
- `t art -h`: CLI help surface

If the user asks what a command really does, read the relevant implementation block in `actions/artifact.nu` and explain the actual side effects instead of paraphrasing the README.

> **Note:** `fzf-preview` is an internal exported command invoked by fzf preview windows (`nu actions/artifact.nu <version> artifact|release|group`). It is not a user-facing action and must never appear in suggested `t art` commands.

## Action Matrix

| action | Mutates remote state | Required confirmed inputs | Recommended probe | Notes |
| --- | --- | --- | --- | --- |
| `-l` / `--list` | No | none | `t art -l --output json --non-interactive` | Shows merged global settings plus source/destination configs. |
| `list-sources` | No | none | `t art list-sources --output json --non-interactive` | Helper action from source code, useful for validating `--from`. |
| `list-destinations` | No | none | `t art list-destinations --output json --non-interactive` | Helper action from source code, useful for validating `--to`. |
| `list-releases` | No | `--to` when target-specific listing is needed | `t art list-releases --to <alias> --output json --non-interactive` | Use before `deploy` or `show-release`. |
| `show-release` | No | `--to`, `--version` | `t art show-release --to <alias> --version <ver> --output json --non-interactive` | Use to inspect one release in detail. |
| `list-deploy-groups` | No | `--to`, `--version` | `t art list-deploy-groups --to <alias> --version <ver> --output json --non-interactive` | Fails without `--version` in agent mode. |
| `show-deploy-order` | No | `--doid`; usually `--to` too | `t art show-deploy-order --to <alias> --doid <id> --output json --non-interactive` | Use before `deploy -i`. |
| `produce` | Yes | verified source context; branch if not using a verified default | `t art produce --dry-run --from <alias> --branch <branch> --output json --non-interactive` | Triggers pipeline-based artifact creation. |
| `pack` | Yes | `--version`; verified `--from` if not using a verified default | `t art pack --dry-run --version <ver> --from <alias> --output json --non-interactive` | Packs an app artifact into a project artifact. |
| `consume` | Yes | `--dest-env`; `--version`; verified `--to`; verified `--from` if needed | `t art consume --dry-run --to <alias> --dest-env <env> --version <ver> --output json --non-interactive` | Downloads, uploads, creates deploy order, and optionally deploys. |
| `deploy` | Yes | one of: `--doid`; or `--version` + `--dest-env`; or `--combine` + source context + `--dest-env` | `t art deploy --dry-run ... --output json --non-interactive` | Supports direct deploy, deploy by order ID, and `--combine`. |

## Common Flags

Always explain these flags when they appear in the final command:

| flag | Meaning |
| --- | --- |
| `--list` / `-l` | List configured source and destination settings |
| `--non-interactive` | Fail instead of opening prompts or `fzf` selectors |
| `--yes` / `-y` | Approve mutation in non-interactive mode |
| `--output` / `-o` | Output format: `text` (default) or `json`; use `--output json` for AI handling |
| `--dry-run` | Validate inputs and preview the execution plan without mutating remote state |
| `--combine` / `-c` | For `deploy`, produce upstream artifact first, then continue download/upload/deploy flow |
| `--no-deploy` / `-n` | Create deploy order but stop before actual deployment |
| `--from` / `-f` | Source config alias |
| `--to` / `-t` | Destination config alias |
| `--doid` / `-i` | Deploy order ID |
| `--branch` / `-b` | Branch used for artifact production |
| `--version` / `-v` | Artifact version |
| `--dest-env` / `-e` | Destination environment: `DEV`, `TEST`, `STAGING`, or `PROD` |
| `--deploy-group` / `-g` | Deploy group list, comma-separated |

## JSON Response Schema

When `--output json`, all responses follow one of three shapes.

**Success:**

```json
{
  "success": true,
  "action": "<action>",
  "data": {
    "version": "<string | null>",
    "releaseId": "<string | null>",
    "deployOrderId": "<string | null>",
    "detailUrl": "<string | null>",
    "projectId": "<number | null>",
    "sourceProjectId": "<number | null>",
    "destinationProjectId": "<number | null>",
    "deployGroup": ["<string>"] | null,
    "dryRun": false,
    "raw": {}
  },
  "warnings": []
}
```

**Failure:**

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

**Cancelled (user typed `q` at the confirmation prompt):**

```json
{
  "success": true,
  "action": "<action>",
  "cancelled": true,
  "message": "<reason>",
  "details": {}
}
```

Parsing rules for AI:

- Always check `success` first.
- If `success` is `false`, read `error.code` to classify the failure; see the Error Code Reference below.
- If `cancelled` is `true`, treat it as a no-op and ask the user what they want to do next.
- In dry-run mode, `data.dryRun` will be `true` and `data.raw` holds the plan object returned by the relevant `dry-run-*` function.

## Error Code Reference

| error.code | Likely cause | Recommended next action |
| --- | --- | --- |
| `INTERACTION_REQUIRED` | Non-interactive mode needs user input (fzf selection, confirmation) | Add the missing flag (`--version`, `--deploy-group`, etc.) and re-run |
| `MUTATION_NOT_CONFIRMED` | Mutation action in non-interactive mode without `--yes` | Add `--yes` only after user confirms |
| `MISSING_VERSION` | `--version` not provided and cannot be resolved interactively | Ask user for the exact version string |
| `MISSING_DEST_ENV` | `--dest-env` not provided | Ask user for environment: `DEV`, `TEST`, `STAGING`, or `PROD` |
| `MISSING_DEPLOY_ORDER_ID` | `--doid` not provided for `show-deploy-order` or `deploy -i` | Ask user for the deploy order ID |
| `INVALID_DEST_ENV` | `--dest-env` value is not one of the valid environments | Correct to `DEV`, `TEST`, `STAGING`, or `PROD` |
| `INVALID_DEPLOY_GROUP` | One or more specified deploy groups do not exist in the release | Run `list-deploy-groups` and pick from available names |
| `INVALID_OUTPUT` | `--output` value is not `text` or `json` | Correct to `text` or `json` |
| `INVALID_ACTION` | Action name is not in the supported list | Check the Action Matrix for valid action names |
| `SOURCE_CONFIG_NOT_FOUND` | `--from` alias not found or no default source configured | Run `list-sources` and verify the alias |
| `DESTINATION_CONFIG_NOT_FOUND` | `--to` alias not found or no default destination configured | Run `list-destinations` and verify the alias |
| `MULTIPLE_DEFAULT_SETTINGS` | More than one source or destination is marked `default = true` in `.termixrc` | Fix `.termixrc` to have at most one default per type |
| `ARTIFACT_NOT_FOUND` | No release found for the specified version and project | Verify the version with `show-release` or `list-releases` |
| `EMPTY_DEPLOY_GROUPS` | The release has no deploy groups (modes) | Release may be malformed; check with `show-release` |
| `CONFIRMATION_MISMATCH` | User input at the confirmation prompt did not match the expected value | Re-run and type the exact expected value at the prompt |
| `SHELL_BOOTSTRAP_FAILED` | `run/trantor-artifact-transfer.sh` returned non-zero exit code | Check ERDA permissions; user needs Admin or Owner role for the `trantor2` app |
| `EMPTY_SHELL_OUTPUT` | Shell script returned empty output | Check ERDA session, base URL, and app name; then retry |
| `INVALID_SHELL_OUTPUT` | Shell script output could not be parsed as JSON | Check ERDA session validity and retry |
| `ARTIFACT_BUILD_FAILED` | Pipeline completed but at least one task has `Failed` status | Inspect the pipeline detail URL for root cause |
| `AUTH_FAILED` | ERDA API returned `Unauthorized` | Renew ERDA session and retry |
| `UPLOAD_FILE_FAILED` | File upload to Erda Cloud failed | Check ERDA credentials and network |
| `UPLOAD_ARTIFACT_FAILED` | Release upload to ERDA project failed | Check ERDA credentials and artifact version uniqueness |
| `CREATE_PROJECT_ARTIFACT_FAILED` | Creating a project artifact from an app artifact failed | Check ERDA permissions for the source project |
| `CREATE_DEPLOY_ORDER_FAILED` | Deploy order creation failed | Check ERDA credentials and release validity |
| `DEPLOYMENT_START_FAILED` | Triggering deployment failed | Check ERDA permissions for the target environment |
| `EMPTY_ARTIFACT_VERSION` | Pipeline metadata did not contain a version field | Pipeline may have failed silently; inspect ERDA pipeline logs |
| `RELEASE_DETAIL_QUERY_FAILED` | Release detail API returned failure | Check releaseId validity and ERDA session |
| `INVALID_DEPLOY_ORDER_DETAIL_RESPONSE` | Deploy order API response has no `data` field | Deploy order ID may be invalid or expired |

## Validation Workflow

### 1. Identify the exact intent

Map the request to one of these workflows:

- inspect config
- inspect release
- inspect deploy order
- produce
- pack
- consume
- deploy

If the user says something broad like “帮我发版” or “看下制品”, ask a focused question instead of assuming the action.

### 2. Collect the minimal required parameters

Use this decision table:

| workflow | Required parameters |
| --- | --- |
| inspect config | none |
| inspect release | `--to`, `--version` |
| inspect deploy order | `--doid`; confirm `--to` when available |
| produce | `--from` and `--branch` unless verified defaults exist |
| pack | `--version`; `--from` unless a verified default exists |
| consume | `--dest-env`, `--version`, `--to`; `--from` if user does not want the verified default source |
| deploy by version | `--dest-env`, `--version`, `--to` |
| deploy by deploy order | `--doid`; `--to` if needed to inspect or execute against a specific destination |
| deploy with `--combine` | `--dest-env`, `--to`, plus source context for `produce`; `--branch` if not using a verified default |

Do not rely on interactive selection in AI mode:

- do not omit `--version` and expect `fzf`
- do not omit `--deploy-group` if the user named a specific group set
- do not omit `--branch` unless you verified a default branch is configured and the user accepts using it

### 3. Validate source and destination aliases

Before building a mutation command, probe aliases with helper actions:

```bash
t art list-sources --output json --non-interactive
t art list-destinations --output json --non-interactive
```

Use these results to:

- verify the alias exists
- discover whether a default source or destination exists
- tell the user exactly which verified default will be used if they omitted `--from` or `--to`

If the alias does not exist, stop and ask the user to provide a correct alias.

### 4. Validate version, release, deploy groups, and deploy order

Use the narrowest helper command that proves the value is real:

```bash
t art list-releases --to <alias> --output json --non-interactive
t art show-release --to <alias> --version <ver> --output json --non-interactive
t art list-deploy-groups --to <alias> --version <ver> --output json --non-interactive
t art show-deploy-order --to <alias> --doid <id> --output json --non-interactive
```

Rules:

- Use `show-release` to validate an exact `--version`.
- Use `list-deploy-groups` only after `--version` is known.
- Use `show-deploy-order` before `deploy -i` if the user wants safety review or if the order ID came from outside the current session.
- `list-releases` returns at most 150 releases. If the target version does not appear in the list, use `show-release --version <ver>` to look it up directly rather than concluding it does not exist.
- If validation fails, surface the exact missing or invalid field instead of trying another guessed value.

### 4.5. Validate authentication source before real mutation

Before executing `produce`, `pack`, `consume`, or `deploy`, check where ERDA credentials will come from:

- First, inspect the resolved `.termixrc` artifact config. If the selected source or destination config, or `artifact.settings`, contains `username` and `password`, say that `.termixrc` will supply the credentials.
- Otherwise, check `TERMIX_DIR/.env` for `ERDA_USERNAME` and `ERDA_PASSWORD`.
- If neither source is available, stop before execution and tell the user exactly which credentials are missing.

Important:

- `just` / `t` typically load `.env` automatically through `Justfile`, but raw `nu -c 'overlay use actions/artifact.nu; ...'` execution may not.
- The current implementation in [`utils/erda.nu`](../../utils/erda.nu) falls back to `TERMIX_DIR/.env` when the shell environment does not already contain `ERDA_USERNAME` / `ERDA_PASSWORD`.
- When using the raw fallback command, make sure `TERMIX_DIR` points at the repository root; otherwise the `.env` fallback cannot be resolved correctly.

### 5. Prefer dry-run before real execution

For mutation-capable actions, first build a dry-run command when supported:

```bash
t art produce --dry-run ...
t art pack --dry-run ...
t art consume --dry-run ...
t art deploy --dry-run ...
```

Dry-run is especially useful for:

- `consume`
- `deploy`
- `deploy --combine`

Important dry-run behavior from the implementation:

- `consume --dry-run --non-interactive` still requires `--version`
- `deploy --dry-run --non-interactive` still requires `--version` unless deploying by `--doid` or another validated branch of the command contract
- `produce` and `pack` dry-runs return a plan and do not mutate remote state

### 6. Build the exact command

Command construction rules:

- Prefer showing the user-facing command as `t art ...`.
- For actual AI execution, prefer adding `--non-interactive --output json`.
- Only add `--yes` after the user confirms the exact command.
- Preserve the user’s parameter order when practical; do not reorder values in a way that makes review harder.
- If `t` is unavailable, execute the raw fallback with `TERMIX_DIR=<repo-root>`.

## Explanation Contract

Before executing any real mutation, always present:

1. the exact command to be executed
2. a parameter explanation table
3. the expected effect
4. notable risks, prerequisites, or defaults being relied on
5. a direct confirmation request

If any required field is missing or uncertain, do not ask for confirmation yet. Ask only for the missing exact values.

Use a rendered plain-text table in a fenced `text` block. Suggested columns:

- `param`
- `value`
- `required`
- `status`
- `meaning`

Recommended status values:

- `valid`
- `missing`
- `uncertain`
- `verified default`
- `pending confirmation`

If helpful, render the table with Nushell first, for example:

```nu
$rows | table -e -t light
```

Then paste the rendered output into a fenced `text` block.

## Effect Summary Rules

Explain the effect in action-specific terms:

- `produce`: triggers the source pipeline, waits for artifact metadata, then returns version, release ID, and detail URL
- `pack`: looks up an app artifact and creates the corresponding project artifact version when needed
- `consume`: resolves the upstream artifact; if the resolved version exists as an **app artifact** but not yet as a project artifact, it is automatically packed into a project artifact first; then downloads the artifact locally, checks whether the destination project already has that version, uploads only when the destination project does not already contain it, creates a deploy order, and optionally deploys
- `deploy`: either deploys an existing deploy order, or resolves a release and creates a new deploy order, and optionally deploys it
- `deploy --combine`: runs the `produce` flow first, then continues with downstream upload and deployment steps
- `show-release`: fetches one release's detail for explanation or validation
- `show-deploy-order`: fetches deploy-order detail for explanation or validation

Important implementation details:

- Versions starting with `R.` go through the Trantor-specific transfer flow in `consume`, which invokes `run/trantor-artifact-transfer.sh` to bootstrap artifact handling before upload/deploy. Call this out explicitly because the side effects are broader than a simple release lookup.
- When `--deploy-group` contains `All` mixed with other named groups (e.g., `-g Dors,All`), the command prints a notice and then drops `All`, deploying only the named groups. Use `All` alone to deploy all groups.
- `list-releases` returns at most 150 releases (hard-coded `pageSize=150`). If the target version does not appear, use `show-release --version <ver>` to query it directly instead of assuming it does not exist.
- Authentication: `.termixrc` source/destination configs may include `username` and `password` fields for ERDA login. If present, these are used automatically; credentials are never logged in JSON output.

## Confirmation Gate

Only execute after the user clearly confirms.

Acceptable confirmation patterns:

- “确认执行”
- “按这个命令执行”
- “继续”
- explicit approval after you show the final command

Before execution, your reply should end with a clear request such as:

> 请确认是否按上面的命令执行；如果有任何参数需要修改，请直接指出具体值。

### Interactive confirmation input contract

When running without `--yes`, the implementation prompts the user to type an exact value — not just "yes" — before proceeding:

| action | What the user must type at the prompt |
| --- | --- |
| `produce` | The exact **branch name** (e.g. `release/3.0.2506`) |
| `consume` | The exact **version string** (e.g. `R.3.0.2506+20250721162706.810`) |
| `deploy` | The exact **version string** (e.g. `R.3.0.2506+20250721162706.810`) |
| `pack` | The exact **version string** (e.g. `Portal-3.0.2506-f785ce9+250607.213036`) |

Typing `q` at any prompt cancels the operation cleanly (`cancelled: true` in JSON output).

In agent mode always use `--non-interactive --yes` (after user approval) to bypass this prompt — never assume the user typed the correct value in a prior interactive run.

## Failure Handling

When blocked:

- say exactly which parameter, config, credential, or command capability is missing
- explain why it is required
- propose the smallest safe next step, usually a helper query or a request for one exact value

Never hide uncertainty. The rule is: 宁可不动，也不要错动.
