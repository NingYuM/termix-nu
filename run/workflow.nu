#!/usr/bin/env nu

# Author: hustcer
# Created: 2024/11/30 18:05:20
# Description:
#   Run Github workflow on a specified branch with specified inputs.
#   Polling and query the status of the workflow run.
# REF:
#   - https://docs.github.com/en/rest/reference/actions#create-a-workflow-dispatch-event
#   - https://api.github.com/repos/hustcer/release-app/actions/runs/12096272615
#   - https://docs.erda.cloud/next/manual/dop/guides/reference/pipeline.html

use ../utils/common.nu [hr-line]

# Configuration constants
const API_TIMEOUT = 60sec
const QUERY_INTERVAL = 5sec
const DEFAULT_TIMEOUT = 120sec
const PROGRESS_INDICATOR_WIDTH = 90
const WORKFLOW_INIT_DELAY = 3sec
const GH_REPO = 'hustcer/release-app'
const TIME_FMT = '%Y-%m-%dT%H:%M:%SZ'

# Mobile App build and query from Github workflow
export def github-workflow [
  action: string@[run query polling],       # Action to perform, e.g. run, query, polling, etc.
  --silent(-s),                             # Silent mode
  --run-id(-i): string,                     # Workflow run ID, required by `query` & `polling`
  --src-branch: string = 'develop',         # Source branch to build the App from, required by `run`
  --branch(-b): string = 'release/app',     # Branch to run workflow on, required by `run`
  --workflow(-w): string = 'terp-app.yml',  # Workflow file to run, required by `run`
  --enable-ios(-I),                         # Enable iOS build, default is `false`, work for `run`
] {
  # Validate required parameters based on action
  match $action {
    'query' | 'polling' => {
      if ($run_id | is-empty) {
        error make {
          msg: $"--run-id is required for action '($action)'"
          label: { text: "Missing required parameter" }
        }
      }
    }
  }

  match $action {
    'polling' => { polling-workflow $run_id $branch }
    'query' => { query-workflow $run_id $branch --silent=$silent }
    'run' => { run-workflow $src_branch $branch $workflow --silent=$silent --enable-ios=$enable_ios }
    _ => {
      error make {
        msg: $'Invalid action: ($action)'
        label: {
          text: "Valid actions are: run, query, polling"
        }
      }
    }
  }
}

# Generate unique distinct ID for workflow tracking
def generate-distinct-id [] {
  $'run-(date now | format date '%Y%m%d-%H%M%S')-(random int 1000..9999)'
}

# Build workflow dispatch payload
def build-workflow-payload [
  src_branch: string,
  branch: string,
  distinct_id: string
  --enable-ios(-I),       # Enable iOS build, default is `false`
] {
  {
    ref: $branch,
    inputs: { ios: $enable_ios, android: true, 'build-branch': $src_branch, 'distinct-id': $distinct_id }
  }
}

# Make GitHub API POST request with error handling
def github-api-post [url: string, payload: record] {
  try {
    http post --content-type application/json --headers (build-api-headers) $url $payload
  } catch { |err|
    error make {
      msg: $"GitHub API request failed: ($err.msg)"
      label: { text: $"Failed to POST to ($url)" }
    }
  }
}

# Run Github workflow on a specified branch with specified inputs
def run-workflow [
  src_branch: string = 'develop',     # Source branch to build the App from
  branch: string = 'release/app',     # Branch to run workflow on
  workflow: string = 'terp-app.yml',  # Workflow file to run
  --enable-ios(-I),                   # Enable iOS build, default is `false`
  --silent,                           # Silent mode
] {
  # Generate unique distinct ID for tracking this workflow run
  let distinct_id = generate-distinct-id
  let payload = build-workflow-payload $src_branch $branch $distinct_id --enable-ios=$enable_ios

  print $'Running workflow (ansi g)($workflow)(ansi reset) on branch (ansi g)($branch)(ansi reset) with payload:'
  hr-line
  $payload | table -e | print

  # Log metadata for pipeline tracking
  print-action-meta 'sourceBranch' $src_branch
  print-action-meta 'ghBranch' $branch
  print-action-meta 'workflow' $workflow
  print-action-meta 'distinctId' $distinct_id

  # Trigger workflow dispatch
  let call_url = $'https://api.github.com/repos/($GH_REPO)/actions/workflows/($workflow)/dispatches'
  github-api-post $call_url $payload | table -e

  # Get workflow run ID using distinct ID
  let workflow_run_id = get-workflow-run-id $distinct_id $workflow $branch --silent=$silent
  print $'(char nl)Workflow Run ID: (ansi g)($workflow_run_id)(ansi reset)'
  print-action-meta 'workflowRunID' ($workflow_run_id | into string)

  $workflow_run_id
}

# Make GitHub API GET request with error handling
def github-api-get [url: string, --silent] {
  try {
    http get --max-time $API_TIMEOUT --allow-errors --headers (build-api-headers) $url
  } catch { |err|
    if not $silent { print $'(ansi y)Warning: API request failed - ($err.msg)(ansi reset)' }
    null
  }
}

# Query Github workflow run status
def query-workflow [
  run_id: string,               # Workflow run ID
  branch: string = 'release/app',
  --silent,                     # Silent mode
] {
  let call_url = $'https://api.github.com/repos/($GH_REPO)/actions/runs/($run_id)'
  if not $silent { print $'Querying workflow run: (ansi g)($call_url)(ansi reset)' }
  let run = github-api-get $call_url --silent=$silent
  if ($run == null) {
    if not $silent {
      print $'(ansi y)Warning: Workflow run not found or network error(ansi reset)'
    }
    return null
  }

  if not $silent {
    print $'You can check the workflow run at: (ansi g)($run.html_url)(ansi reset)'
  }
  $run | select id status conclusion html_url
}

# Wait for workflow query to return valid result
def wait-for-workflow-query [run_id: string, branch: string] {
  mut query = query-workflow $run_id $branch
  while ($query | is-empty) or ($query == null) {
    sleep $QUERY_INTERVAL
    $query = query-workflow $run_id $branch --silent=true
  }
  $query
}

# Format workflow conclusion with colors
def format-conclusion [conclusion: string] {
  if $conclusion in [failure, cancelled] {
    $'(ansi r)($conclusion)(ansi reset)'
  } else {
    $'(ansi g)($conclusion)(ansi reset)'
  }
}

# Polling Github workflow run status until it's completed or failed
def polling-workflow [
  run_id: string,               # Workflow run ID
  branch: string = 'release/app',
] {
  let start_time = date now
  # Wait for initial query result
  mut query = wait-for-workflow-query $run_id $branch
  # Log metadata for pipeline tracking
  print-action-meta 'ghRunID' ($query.id | into string)
  print-action-meta 'detailUrl' $'https://github.com/($GH_REPO)/actions/runs/($query.id)'

  # Poll until workflow completes
  mut counter = 0
  mut keep_polling = true

  loop {
    $counter += 1
    print -n '*'
    if not $keep_polling { break }
    if ($counter == $PROGRESS_INDICATOR_WIDTH) {
      $counter = 0
      print -n (char nl)
    }

    sleep $QUERY_INTERVAL
    $query = query-workflow $run_id $branch --silent=true
    if ($query != null) and ($query.status == 'completed') { $keep_polling = false }
  }

  let end_time = date now
  let conclusion = format-conclusion $query.conclusion
  print-action-meta 'finalStatus' $query.conclusion
  print $'(char nl)Workflow run completed with status: (ansi g)($query.status)(ansi reset) and conclusion: ($conclusion)'
  print $'Total time elapsed: (ansi g)($end_time - $start_time)(ansi reset)'
}

# Get workflow run ID by searching for distinct ID in workflow inputs
# Implementation inspired by: https://github.com/Codex-/return-dispatch
def get-workflow-run-id [
  distinct_id: string,                    # Unique identifier to search for
  workflow: string,                       # Workflow file name
  branch: string = 'release/app',         # Branch name
  --timeout: duration = $DEFAULT_TIMEOUT, # Timeout duration (default: 120sec)
  --silent,                               # Silent mode
] {
  let runs_url = $'https://api.github.com/repos/($GH_REPO)/actions/workflows/($workflow)/runs'
  if not $silent { print $'Searching for workflow run with distinct ID: (ansi c)($distinct_id)(ansi reset)' }

  # Wait for workflow to initialize
  sleep $WORKFLOW_INIT_DELAY
  let result = poll-for-run $distinct_id $runs_url $branch --timeout $timeout --silent=$silent

  if ($result == null) {
    print $'(ansi r)✗ Could not find workflow run with distinct ID(ansi reset)'
    if not $silent { print $'  Tip: Use --silent flag to hide detailed search progress' }
    return null
  }

  if not $silent { print $'(ansi g)✓ Found workflow run ID: ($result)(ansi reset)' }
  $result
}

# Fetch recent workflow runs from GitHub API
def fetch-workflow-runs [runs_url: string, branch: string] {
  let query = { per_page: 10, branch: $branch, event: 'workflow_dispatch' } | url build-query
  try {
    github-api-get $'($runs_url)?($query)' --silent | get workflow_runs? | default []
  } catch { [] }
}

# Poll for workflow run by checking inputs and step names
def poll-for-run [
  distinct_id: string,
  runs_url: string,
  branch: string,
  --timeout: duration = $DEFAULT_TIMEOUT,
  --silent,
] {
  mut retry_count = 0
  let start_time = date now

  loop {
    $retry_count += 1
    # Check timeout
    if $start_time + $timeout < (date now) {
      if not $silent { print $'(ansi y)Timeout after ($timeout)(ansi reset)' }
      return null
    }

    # Fetch recent workflow runs
    let runs = fetch-workflow-runs $runs_url $branch
    if ($runs | is-empty) {
      if not $silent { print $'Retry ($retry_count): Waiting for workflow runs...' }
      sleep $QUERY_INTERVAL
      continue
    }

    if not $silent { print $'Retry ($retry_count): Checking ($runs | length) runs...' }
    # Search for matching run
    let matched_run_id = search-runs-for-distinct-id $runs $distinct_id --silent=$silent
    if ($matched_run_id != null) { return $matched_run_id }
    # Not found, wait and retry
    print -n '.'  # Progress indicator
    sleep $QUERY_INTERVAL
  }
}

# Check if any step in the run contains the distinct ID
def check-run-steps [run: record, distinct_id: string, --silent] {
  let jobs_url = $'https://api.github.com/repos/($GH_REPO)/actions/runs/($run.id)/jobs'
  let jobs = try {
    github-api-get $jobs_url --silent | get jobs? | default []
  } catch { [] }

  for job in $jobs {
    let steps = $job.steps? | default []
    for step in $steps {
      let step_name = $step.name? | default ''
      if ($step_name | str contains $distinct_id) {
        if not $silent { print $'  Found match in run ($run.id) step: ($step_name)' }
        return $run.id
      }
    }
  }

  null
}

# Search runs for distinct ID match
def search-runs-for-distinct-id [
  runs: list,
  distinct_id: string,
  --silent,
] {
  for run in $runs {
    # Check step names
    let matched = check-run-steps $run $distinct_id --silent=$silent
    if ($matched != null) { return $matched }
  }

  null
}

# Validate and get GitHub token from environment
def get-github-token [] {
  if ($env.GITHUB_TOKEN? | is-empty) {
    error make {
      msg: "GITHUB_TOKEN environment variable is not set"
      label: { text: "Required for GitHub API authentication" }
    }
  }
  $env.GITHUB_TOKEN
}

# Build GitHub API headers with authentication
def build-api-headers [] {
  [Authorization $'token (get-github-token)']
}

# Print action metadata for pipeline tracking
def print-action-meta [key: string, value: string] {
  if ($env.PIPELINE_ID? | is-not-empty) {
    print $'action meta: ($key)=($value)'
  }
}
