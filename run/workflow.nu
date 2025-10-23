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

const QUERY_INTERVAL = 5sec
const GH_REPO = 'hustcer/release-app'
const TIME_FMT = '%Y-%m-%dT%H:%M:%SZ'

# Mobile App build and query from Github workflow
export def github-workflow [
  action: string@[run query polling],       # Action to perform, e.g. run, query, polling, etc.
  --silent(-s),                             # Silent mode
  --run-id(-i): string,                     # Workflow run ID
  --src-branch: string = 'develop',         # Source branch to build the App from
  --branch(-b): string = 'release/app',     # Branch to run workflow on
  --workflow(-w): string = 'terp-app.yml',  # Workflow file to run
] {
  match $action {
    run => { run-workflow $src_branch $branch $workflow },
    query => { query-workflow $run_id $branch --silent=$silent },
    polling => { polling-workflow $run_id $branch },
    _ => { print $'Invalid action: (ansi r)($action)(ansi reset)' },
  }
}

# Run Github workflow on a specified branch with specified inputs
def run-workflow [
  srcBranch: string = 'develop',      # Source branch to build the App from
  branch: string = 'release/app',     # Branch to run workflow on
  workflow: string = 'terp-app.yml',  # Workflow file to run
] {
  # Generate unique distinct ID for tracking this workflow run
  let distinctId = $'run-(date now | format date '%Y%m%d-%H%M%S')-(random int 1000..9999)'

  let payload = {
    ref: $branch,
    inputs: {
      ios: false,
      android: true,
      'build-branch': $srcBranch,
      'distinct-id': $distinctId  # Add distinct ID to inputs
    }
  }
  print $'Running workflow (ansi g)($workflow)(ansi reset) on branch (ansi g)($branch)(ansi reset) with payload:'
  hr-line; $payload | table -e | print
  if ($env.PIPELINE_ID? | is-not-empty) {
    print $'action meta: sourceBranch=($srcBranch)'
    print $'action meta: ghBranch=($branch)'
    print $'action meta: workflow=($workflow)'
    print $'action meta: distinctId=($distinctId)'
  }
  let HEADERS = [Authorization $'token ($env.GITHUB_TOKEN)']
  let CALL_URL = $'https://api.github.com/repos/($GH_REPO)/actions/workflows/($workflow)/dispatches'
  let startTime = (date now) - 8hr | format date $TIME_FMT
  http post --content-type application/json -H $HEADERS $CALL_URL $payload | table -e

  # Get workflow run ID using distinct ID
  let workflowRunID = get-workflow-run-id $distinctId $workflow $branch
  print $'workflowRunID: ($workflowRunID)'
  if ($workflowRunID | is-not-empty) and ($env.PIPELINE_ID? | is-not-empty) {
    print $'action meta: workflowRunID=($workflowRunID)'
  }
  $workflowRunID
}

# Query Github workflow run status
def query-workflow [
  runId: string,    # Workflow run ID
  branch: string = 'release/app',
  --silent,         # Silent mode
] {
  let HEADERS = [Authorization $'token ($env.GITHUB_TOKEN)']
  let CALL_URL = $'https://api.github.com/repos/($GH_REPO)/actions/runs/($runId)'
  if not $silent { print $'Querying workflow run: (ansi g)($CALL_URL)(ansi reset)' }
  let run = (try { http get --max-time 60sec --allow-errors --headers $HEADERS $CALL_URL } catch { null })
  if ($run == null) {
    if not $silent { print $'(ansi y)Warning: Workflow run not found or network error(ansi reset)' }
    return null
  }
  if not $silent { print $'You can check the workflow run at: (ansi g)($run.html_url)(ansi reset)' }
  $run | select id status conclusion html_url
}

# Polling Github workflow run status until it's completed or failed
def polling-workflow [
  runId: string,   # Workflow run ID
  branch: string = 'release/app',
] {
  mut counter = 0
  mut keepPolling = true
  let startTime = date now
  mut query = query-workflow $runId $branch
  while ($query | is-empty) or ($query == null) {
    sleep $QUERY_INTERVAL
    $query = query-workflow $runId $branch --silent=true
  }
  if ($env.PIPELINE_ID? | is-not-empty) {
    print $'action meta: ghRunID=($query.id)'
    print $'action meta: detailUrl=https://github.com/($GH_REPO)/actions/runs/($query.id)'
  }
  loop {
    $counter += 1
    print -n '*'
    if not $keepPolling { break }
    if ($counter == 90) { $counter = 0; print -n (char nl) }
    sleep $QUERY_INTERVAL
    $query = query-workflow $runId $branch --silent=true
    if ($query != null) and ($query.status == 'completed') { $keepPolling = false }
  }
  let endTime = date now
  let conclusion = if $query.conclusion in [failure, cancelled] {
      $'(ansi r)($query.conclusion)(ansi reset)'
    } else { $'(ansi g)($query.conclusion)(ansi reset)' }
  if ($env.PIPELINE_ID? | is-not-empty) {
    print $'(char nl)action meta: finalStatus=($query.conclusion)'
  }
  print $'(char nl)Workflow run completed with status: (ansi g)($query.status)(ansi reset) and conclusion: ($conclusion)'
  print $'Total time elapsed: (ansi g)($endTime - $startTime)(ansi reset)'
}

# Get workflow run ID by searching for distinct ID in workflow inputs
# Implementation inspired by: https://github.com/Codex-/return-dispatch
def get-workflow-run-id [
  distinctId: string,                  # Unique identifier to search for
  workflow: string,                    # Workflow file name
  branch: string = 'release/app',      # Branch name
  --timeout: duration = 120sec,        # Timeout duration (default: 120sec)
  --verbose(-v),                       # Show detailed progress
] {
  let HEADERS = [Authorization $'token ($env.GITHUB_TOKEN)']
  let RUNS_URL = $'https://api.github.com/repos/($GH_REPO)/actions/workflows/($workflow)/runs'

  if $verbose { print $'Searching for workflow run with distinct ID: (ansi c)($distinctId)(ansi reset)' }

  # Wait for workflow to initialize
  sleep 3sec

  let result = poll_for_run $distinctId $RUNS_URL $HEADERS $branch --timeout $timeout --verbose=$verbose

  if ($result == null) {
    print $'(ansi r)✗ Could not find workflow run with distinct ID(ansi reset)'
    if not $verbose { print $'  Tip: Use --verbose flag to see detailed search progress' }
    return null
  }

  if $verbose { print $'(ansi g)✓ Found workflow run ID: ($result)(ansi reset)' }

  $result
}

# Poll for workflow run by checking inputs and step names
def poll_for_run [
  distinctId: string,
  runsUrl: string,
  headers: list,
  branch: string,
  --timeout: duration = 120sec,
  --verbose,
] {
  mut retryCount = 0
  let startTime = date now

  loop {
    $retryCount += 1
    if $startTime + $timeout < (date now) {
      if $verbose { print $'(ansi y)Timeout after ($timeout)(ansi reset)' }
      return null
    }

    # Fetch recent workflow runs
    let runs = fetch_workflow_runs $runsUrl $headers $branch

    if ($runs | is-empty) {
      if $verbose { print $'Retry ($retryCount): Waiting for workflow runs...' }
      sleep $QUERY_INTERVAL
      continue
    }

    if $verbose { print $'Retry ($retryCount): Checking ($runs | length) runs...' }

    # Search for matching run
    let matchedRunId = search_runs_for_distinct_id $runs $distinctId $headers --verbose=$verbose

    if ($matchedRunId != null) { return $matchedRunId }

    # Not found, wait and retry
    print -n '.'  # Progress indicator
    sleep $QUERY_INTERVAL
  }
}

# Fetch recent workflow runs
def fetch_workflow_runs [
  runsUrl: string,
  headers: list,
  branch: string,
] {
  let query = { per_page: 10, branch: $branch, event: 'workflow_dispatch' } | url build-query

  try {
    http get --headers $headers $'($runsUrl)?($query)' | get workflow_runs? | default []
  } catch {
    []
  }
}

# Search runs for distinct ID match
def search_runs_for_distinct_id [
  runs: list,
  distinctId: string,
  headers: list,
  --verbose,
] {
  for run in $runs {
    # Check step names
    let matched = check_run_steps $run $distinctId $headers $verbose
    if ($matched != null) { return $matched }
  }

  null
}

# Check if any step in the run contains the distinct ID
def check_run_steps [
  run: record,
  distinctId: string,
  headers: list,
  verbose: bool,
] {
  let jobsUrl = $'https://api.github.com/repos/($GH_REPO)/actions/runs/($run.id)/jobs'
  let jobs = try { http get --headers $headers $jobsUrl | get jobs? | default [] } catch { [] }

  for job in $jobs {
    let steps = $job.steps? | default []
    for step in $steps {
      let stepName = $step.name? | default ''
      if ($stepName | str contains $distinctId) {
        if $verbose { print $'  Found match in run ($run.id) step: ($stepName)' }
        return $run.id
      }
    }
  }

  null
}

# alias main = github-workflow
