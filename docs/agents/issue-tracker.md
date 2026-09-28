# Issue tracker: GitHub

Issues and PRDs for this repo live in GitHub Issues for `armaan-io/rhythmic`.
Use the `gh` CLI for all operations.

## Conventions

Use `--repo armaan-io/rhythmic` with issue and PR commands to target this
repository explicitly. Inside the clone, `gh` can also infer it from `origin`.

- **Create an issue**: `gh issue create --repo armaan-io/rhythmic --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --repo armaan-io/rhythmic --comments`. Fetch labels too; use JSON output and `jq` when filtering comments.
- **List issues**: `gh issue list --repo armaan-io/rhythmic --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`. Adjust label and state filters as needed.
- **Comment**: `gh issue comment <number> --repo armaan-io/rhythmic --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --repo armaan-io/rhythmic --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --repo armaan-io/rhythmic --comment "..."`

## Pull requests as a triage surface

**PRs as a request surface: no.**

If enabled later, use the corresponding `gh pr` commands to read, comment,
label, and close PRs; use `gh pr diff` to inspect changes. Include only external
contributors (`CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` author
associations), excluding owners, members, and collaborators.

GitHub shares one number space across issues and PRs. Resolve an ambiguous
reference with `gh pr view <number>` and fall back to `gh issue view <number>`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --repo armaan-io/rhythmic --comments`.

## Wayfinding operations

Used by `/wayfinder`. The map is a single issue with child issues as tickets.

- **Map**: an issue labelled `wayfinder:map`, holding Notes / Decisions-so-far / Fog.
- **Child ticket**: link to the map as a GitHub sub-issue using `gh api`. If sub-issues are unavailable, add the child to a task list in the map and put `Part of #<map>` at the top of the child body. Use `wayfinder:<type>` labels (`research`, `prototype`, `grilling`, or `task`).
- **Blocking**: use native GitHub issue dependencies. Add an edge with `gh api --method POST repos/armaan-io/rhythmic/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`. Obtain the database ID with `gh api repos/armaan-io/rhythmic/issues/<blocker> --jq .id`; do not use the issue number or node ID. If dependencies are unavailable, use a `Blocked by: #<n>, #<n>` line in the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children, scoped by sub-issues or its task list. Exclude assigned tickets and tickets with open blockers (`issue_dependencies_summary.blocked_by > 0`, or open issues referenced in `Blocked by`). First in map order wins.
- **Claim**: `gh issue edit <number> --repo armaan-io/rhythmic --add-assignee @me` — the session's first write.
- **Resolve**: comment with the answer, close the child issue, then append a gist and link to the map's Decisions-so-far.
