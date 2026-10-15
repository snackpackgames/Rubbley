# Contributing

## Pull requests

Open every PR with its metadata set, either in the `gh pr create` call or immediately after with `gh pr edit`:

- **Assignee**: the dev driving the work (`--assignee @me`).
- **Labels**: one or more topic labels that describe the change (`documentation`, `game mechanic`, `visuals`, `workflow`, `bug`). A PR that came out of a wayfinder ticket also gets that ticket's type label (`wayfinder:research`, `wayfinder:grilling`, `wayfinder:prototype`, `wayfinder:task`). Run `gh label list` to see the full set.
- **Linked issues**: name each issue the PR came from and link it. Use `Closes #<n>` for an open issue the PR completes; GitHub then lists it under Development and closes it on merge. Use `Refs #<n>` for an issue that is already closed or stays open, such as a wayfinder ticket that was resolved before its ADR PR.
- **Milestone**: the same milestone as the linked issue, if it has one.

Before you finish, check the metadata with `gh pr view <n> --json assignees,labels,milestone,closingIssuesReferences`.
