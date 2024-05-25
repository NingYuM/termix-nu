# This script is used to add milestone to PRs that are merged after a specific PR.
# Usage: nu run/pr-milestone.nu 2c1560e28 v0.90.0

# Add milestone to PRs that are merged after a specific PR SHA.
def main [
    fromSha: string,        # The SHA of the PR that we want to start from.
    milestone: string,      # The milestone that we want to add to the PRs.
    --limit(-l): int = 999, # The limit of PRs to fetch.
] {
    let fields = [url, title, milestone, mergeCommit, mergedAt] | str join ','
    let prs = gh pr list -R nushell/nushell --state merged --limit $limit --json $fields
        | from json
        | sort-by -r mergedAt
        | upsert milestone {|it| ($it.milestone).title? }
        | upsert mergeCommit {|it| ($it.mergeCommit).oid | str substring 0..<12 }
    let startPRMergedAt = $prs
        | where $it.mergeCommit =~ $fromSha
        | get 0.mergedAt
        | into datetime
    let filtered = $prs | where ($it.mergedAt | into datetime) >= $startPRMergedAt
    $filtered | drop | each {|it|
        if ($it.milestone | is-empty) {
            print $'Try to add milestone (ansi p)($milestone)(ansi reset) to PR (ansi p)($it.url)(ansi reset) ...'
            gh pr edit $it.url --milestone $milestone
        }
    } | ignore
}
