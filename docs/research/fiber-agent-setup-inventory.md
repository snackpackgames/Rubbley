# Fiber's agent setup: keep, adapt or drop for Rubbley

Research for [#176](https://github.com/snackpackgames/Rubbley/issues/176), on the map [#140](https://github.com/snackpackgames/Rubbley/issues/140). Gathered 2026-11-28.

**Source:** a local checkout of `snackpackgames/fiber` at commit [`41dd4f9d9bf62e3e0182ae37b8c1c4adcd0f9b3f`](https://github.com/snackpackgames/fiber/tree/41dd4f9d9bf62e3e0182ae37b8c1c4adcd0f9b3f). That checkout has uncommitted changes, but none in `documentation/agents/`, `.claude/`, `.github/`, `scripts/`, `skills-lock.json` or `CONTRIBUTING.md` (`git status` is empty for those paths), so everything cited below matches the commit. Fiber paths are relative to the fiber repo root. Rubbley paths are relative to this repo, at `main` `389b55f`. Facts about Rubbley's GitHub settings come from the GitHub API on 2026-11-28.

**Already settled on the map, and applied below:** one repo with no ideas split, no project board, `docs/` with plans in `docs/plans/`, gdUnit4 run through `scripts/test.sh`, no multiplayer gate (it becomes a GDD-section-plus-feel check), milestones only, and all five automations in scope.

**Left open here on purpose:** the triage rules (#178), the gameplay gate and the issue template (#179), and the schedules and budget (#180). Where a file depends on one of those, the table says "input for #17x" and the [Inputs for the grilling tickets](#inputs-for-the-grilling-tickets) section lists what each ticket has to decide.

## Rubbley facts that change the port

These come from Rubbley's own files and its GitHub settings. Each one changes at least one fiber file.

1. **Rubbley is a public repo** (`gh repo view`: `visibility: PUBLIC`). Fiber is private, and several of its choices follow from that: the Actions-minutes budgeting in `factory_metrics.py` and the cost notes in `pr-triage.yml`. GitHub-hosted standard runners are free on public repos, so the minutes cost model doesn't carry over. Forks and outside comments are also possible, which matters for H12 and `claude.yml`.
2. **`main` has a ruleset**: no deletion, no non-fast-forward, and a required status check `check` from GitHub Actions (integration 15368), with **no bypass actors** (`gh api repos/snackpackgames/Rubbley/rulesets/25293060`). Fiber's `main` has no branch protection (`pr-triage-routine-prompt.md`, *Repo configuration*: "which has no branch protection (not available on this plan)"). Fiber's `agent-merge` pushes merge commits it made on the runner straight to `main`. On Rubbley those new SHAs have never had a `check` run, so the ruleset should refuse the push. One of three things has to change: add the merge App as a ruleset bypass actor, report `check` on the tested commit before pushing, or merge through GitHub's merge API instead of a direct push. This needs a decision.
3. **`[skip ci]` would skip the Playtest Build deploy.** `agent-merge.yml` adds `[skip ci]` to the last merge commit so `main` doesn't re-run CI. Rubbley's `ci.yml` deploys GitHub Pages from the push to `main` (ADR 0020), so a `[skip ci]` merge would leave the playtest build out of date. Fiber knew `[skip ci]` skips every push-triggered workflow and guarded against it with H1/H2 paths (`pr-triage-routine-prompt.md`, *What it costs*). Rubbley's deploy runs on every push, so the guard doesn't apply.
4. **CI has no `paths-ignore`, and its job is named `check`.** Fiber's H6 lets a docs-only PR through without a `CI` run, because fiber's CI skips `notes/`, `documentation/` and `*.md` (`scripts/pr_triage_rules.py`, `DOCS_ONLY`). On Rubbley every PR gets a `CI` run (the workflow is also named `CI`), so that exception goes away.
5. **There is no shared test action.** Fiber's CI and `agent-merge` both use `.github/actions/godot-tests`. Rubbley's `ci.yml` runs `scripts/check.sh`, then `xvfb-run --auto-servernum scripts/test.sh`, then a web export, all inline. `agent-merge` needs that same sequence, so it has to be pulled out into a composite action or a script. The required check must still be named `check`.
6. **The input suite needs a display.** `scripts/test.sh input` doesn't run headless ("Godot drops InputEvents under --headless", `ci.yml`). In a cloud routine sandbox, `scripts/test.sh unit` is safe. Whether `xvfb-run` exists there hasn't been checked.
7. **`scripts/check.sh` calls `gh issue view`**, which is GraphQL-backed, to look up quarantine issues for skipped tests. Fiber's `issue-tracker.md` (*Cloud sessions*) says cloud sessions refuse GraphQL. Rubbley has no `do_skip` in `test/` today, so the gate passes. Once a test is quarantined, `check.sh` fails in every cloud routine. Switching to `gh api repos/snackpackgames/Rubbley/issues/<n> --jq .state` fixes it.
8. **No Branches convention.** Fiber's routine prompts require "CONTRIBUTING.md → Branches", topic-prefixed and never a `claude/` codename branch. Rubbley's `CONTRIBUTING.md` covers PR metadata only. Its recent branches do use `docs/`, `fix/` and `research/` prefixes.
9. **Labels missing on Rubbley** (from `gh label list`): `merge:low-risk`, `merge:high-risk`, `fixup:skip`, `process`, `regression`, `wayfinder:parked`, and `playtest` (H11 reads it). The five triage labels and the four `wayfinder:` ticket types plus `wayfinder:map` already exist.
10. **Secrets and variables:** the only Actions secret is `UNITY_LICENSE`. There are no Actions variables.
11. **GitHub Apps:** the org has `claude`, `snackpack-fiber-merge` and `snackpack-fiber-triage` installed with *selected* repositories (`gh api orgs/snackpackgames/installations`). Fiber's docs say the two `snackpack-fiber-*` Apps are "installed on `fiber` only". This research couldn't check whether `claude` covers Rubbley: listing an installation's repos needs an App token.
12. **Test conventions:** gdUnit4 suites are `*_test.gd` under `test/unit/` and `test/input/`, with helpers in `test/support/`. Assertions are `assert_float`, `assert_bool`, `assert_vector`, `assert_int` and so on, so fiber's H9 count of `assert_` lines still works. Skips are `do_skip`/`skip_reason` parameters, quarantined by `check.sh` (ADR 0018). GUT's `pending(` and `skip_script` don't exist in gdUnit4.
13. **Autoloads** (`project.godot`): `MoveInput` and `PlatformServices`. Fiber's H3 reads autoloads from the checkout, so this needs no code change.

## Inventory

Verdicts: **keep** means copy as is. **adapt** means copy, then change what's listed. **drop** means don't port it. "Provisioning" covers secrets, GitHub Apps, labels and branch protection. A dash means nothing is needed.

### `documentation/agents/`

| Fiber path | Verdict | Reason | Fiber-specific parameters to change | Provisioning |
|---|---|---|---|---|
| `documentation/agents/afk-pipeline.md` | adapt | The pipeline's only definition of destination types, handoff preconditions and parking. `/wayfinder-chart`, `/wayfinder-handoff` and the routines all read it | `fiber-ideas` everywhere and the *Where maps live* section (ADR 0012); precondition 0 (repo placement); `/wayfinder-scope promote`; `documentation/plans/` → `docs/plans/`, `documentation/adr/` → `docs/adr/`, `documentation/<system>_system.md` → a Rubbley location for `system-spec` (none exists yet); the Multiplayer section, the `network_system.md` checklist and ADR 0011 (multiplayer) → the GDD-section-plus-feel check (input for #179); the issue template's "GUT tests pass (`bash scripts/test.sh`)" line → gdUnit4 and `scripts/check.sh` (input for #179); parked issues go in Rubbley, with same-repo `blocked_by` edges; `repos/snackpackgames/fiber` → `Rubbley`; "issue #1001" example | Labels: `wayfinder:parked` |
| `documentation/agents/cloud-routines.md` | adapt | The bootstrap pattern (prompt read from `main` at run time, under a reviewed path) is what makes the routines safe to change | Routine names ("Fiber: …"); the bootstrap's "Fiber project (snackpackgames/fiber)"; `documentation/agents/` → `docs/agents/`; the schedule column (input for #180); the `fiber-ideas` `add_repo` note goes | Claude GitHub App installed on Rubbley (for `/schedule` cloud sessions) |
| `documentation/agents/scheduled-routine-prompt.md` | adapt | Issue pickup, automation 1 of 5 | Repo `snackpackgames/fiber` in every `gh api` call; "80+ issues" sizing note; step 4's `fiber-ideas` research pointer and ADR 0012; step 4's multiplayer gate, `network_system.md` and ADR 0011 → the #179 gameplay gate; step 6 `bash scripts/import.sh` → `source scripts/env.sh --install` then `scripts/import.sh`; step 7 GUT under `test/unit/`, client RPC tests → gdUnit4 `*_test.gd`, `scripts/test.sh unit` (the input suite needs a display) and `scripts/check.sh`; step 8's project board/Status line goes (milestone only); "CONTRIBUTING.md → Branches" needs a Rubbley section | Labels: `ready-for-agent` (exists); Claude GitHub App on Rubbley |
| `documentation/agents/wayfinding-routine-prompt.md` | adapt | Daily wayfinding, automation 2 of 5. Its loop guard (never re-grill a ticket whose last comment is the routine's own) is worth keeping as is | The two-repo frontier, `<repo>` placeholders, the `add_repo` fallback and the *Two-repo change* notes all go; research output: `fiber-ideas` `research/<n>-<slug>.md` → Rubbley's `docs/research/` (which branch, and whether it merges, needs stating: this ticket's own file sits on an unmerged `research/` branch); prototypes under `prototypes/<name>/` on a `research/` branch as a draft PR (Rubbley's `check.sh` already prunes `./prototypes`); `scripts/ensure-godot.sh` → `source scripts/env.sh --install`; `test/unit/prototypes/` path; issue refs #645; ADR 0012 references | Claude GitHub App on Rubbley |
| `documentation/agents/pr-triage-routine-prompt.md` | adapt | PR triage policy and the live prompt for `pr-triage.yml`. The design (rules first, model can only escalate, fail closed, pinned to the head SHA) carries over unchanged | The H1–H12 table and the J1–J5 checks are fiber's (input for #178); "Godot 4.7 / GDScript project Fiber"; `snackpack-fiber-triage`/`-merge` App names; J3's fiber base classes (`state.gd`, `StatSheet`, `DamageCalculator`, `Hitbox/Hurtbox`); J2's "GUT … under test/unit/"; `documentation/plans/`; the "no branch protection" line and the Actions cost notes (#1526); the Identities table | Secrets: `TRIAGE_APP_ID`, `TRIAGE_APP_PRIVATE_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `AGENT_MERGE_APP_ID`, `AGENT_MERGE_APP_PRIVATE_KEY`. Variables: `AGENT_MERGE_ENABLED`, `AGENT_MERGE_MAX` (optional), `TRIAGE_ACTOR`. Two GitHub Apps installed on Rubbley. Labels: `merge:low-risk`, `merge:high-risk`. Ruleset: see fact 2 |
| `documentation/agents/fixup-routine-prompt.md` | adapt | PR fix-up, automation 4 of 5. Its limits (add commits only, at most two pushes per PR, `fixup:skip` opt-out, marker comments) are generic | The set of fixable rules is fiber's (the map's open "mechanical fixes" item, which depends on #178); the H1 `CLAUDE.md` "System Documentation" table case → `documentation/README.md` is fiber-only and goes; STEP 3's multiplayer defect check (`NetUtils.is_authority`, `NetworkBridge`, ADR 0011) → the #179 gate; GUT, `pending()`/`skip_script` → gdUnit4 `do_skip`; `scripts/ensure-godot.sh` → `scripts/env.sh --install`; `snackpack-fiber-triage[bot]` login; "CONTEXT.md term" → `GLOSSARY.md`; schedule (input for #180) | Labels: `fixup:skip`; Claude GitHub App on Rubbley (it pushes to PR branches) |
| `documentation/agents/factory-metrics.md` | adapt | Explains the weekly report, automation 5 of 5 | The `fiber-ideas` map count; "The repo is private … GitHub Free: 2,000 minutes": Rubbley is public, so the cost section either goes or changes meaning (input for #180); the `regression` and `process` labels; schedule | Labels: `process`, `regression` |
| `documentation/agents/issue-tracker.md` | adapt (merge into Rubbley's) | Rubbley's `docs/agents/issue-tracker.md` is already its own version, written against newer `gh` (sub-issues through `gh issue create --parent`). Fiber's adds two sections Rubbley lacks: *Destination types and handoff* and *Cloud sessions* (the REST table, needed by every cloud routine) | In what's carried over: `fiber`/`fiber-ideas` repo names, the `/wayfinder-scope` and cross-repo bullets, the `Fiber v1.0` board paragraph | — |
| `documentation/agents/triage-labels.md` | drop | Rubbley's `docs/agents/triage-labels.md` says the same thing (canonical names as is) | — | — |
| `documentation/agents/domain.md` | drop | Rubbley's `docs/agents/domain.md` is already adapted (`GLOSSARY.md`, `docs/adr/`). Fiber's reads `CONTEXT.md` and `documentation/adr/` | — | — |
| `documentation/agents/handoffs/2026-11-fiberkin-hand-animation.md` | drop | A one-off resume prompt about fiber's Aseprite player animation, not part of the pipeline | — | — |

### `.claude/skills/`

Fiber keeps its skills in `.claude/skills/`. Most are symlinks into `.agents/skills/`, vendored from `mattpocock/skills` and pinned in fiber's `skills-lock.json`. Only six aren't in the lockfile, so fiber owns them: `aseprite`, `groom-backlog`, `pixel-composer`, `wayfinder-chart`, `wayfinder-handoff` and `wayfinder-scope`.

| Fiber path | Verdict | Reason | Fiber-specific parameters to change | Provisioning |
|---|---|---|---|---|
| `.claude/skills/wayfinder-chart/SKILL.md` | adapt | Required by the map's destination. It makes the destination type a choice from a fixed menu and adds the *Notes* disclaimer | Chart in Rubbley, not `fiber-ideas` (step 4's override goes); the parked-fog check loops over `fiber-ideas fiber` → Rubbley only; `documentation/agents/afk-pipeline.md` → `docs/agents/`; ADR 0012 references and the research/prototype placement paragraph; step 8's `/wayfinder-scope promote` pointer; the note about the vendored `wayfinder` hash drift (Rubbley's lockfile should be checked separately) | Labels: `wayfinder:parked` |
| `.claude/skills/wayfinder-handoff/SKILL.md` | adapt | Required by the map's destination. It reads `afk-pipeline.md` and runs the gates in order, including resuming after the merge pause | Precondition 0 (repo placement, the `docs/ideas-<n>-` branch names) goes; `documentation/plans/` → `docs/plans/` (it already warns against `docs/superpowers/plans/`); the Multiplayer section and ADR 0011 → the #179 gate; parking in `fiber-ideas` → Rubbley; issue #1001 references; "leave the project board to the maintainer" goes | Labels: `wayfinder:parked`, `ready-for-agent`, `ready-for-human` (the last two exist) |
| `.claude/skills/wayfinder-scope/SKILL.md` | drop | Moves maps between `fiber-ideas` and `fiber` and on/off the `Fiber v1.0` board. #140 rules out an ideas repo and `/wayfinder-scope` | (names Stephen and Brendon, board, ADR 0012) | — |
| `.claude/skills/groom-backlog/SKILL.md` | drop | Grooms the `Fiber v1.0` Projects board (org project 1). Rubbley has no board | — | — |
| `.claude/skills/aseprite/SKILL.md` | drop | A reference skill for an art tool, not part of the agent pipeline | — | — |
| `.claude/skills/pixel-composer/SKILL.md` | drop | Same: a reference skill for a pixel-art VFX tool | — | — |
| `.claude/skills/wayfinder/` (vendored) | drop the fiber copy | Rubbley already vendors a newer `wayfinder` from `mattpocock/skills` (the diff against fiber's copy is wording only) | — | — |
| `.claude/skills/implement/`, `code-review/`, `research/`, `tdd/`, `to-spec/`, `to-tickets/` (vendored) | drop the fiber copies | Rubbley vendors newer versions of each. For example, Rubbley's `implement` fetches the ticket and calls skills through the Skill tool, and fiber's doesn't | — | — |
| `.claude/skills/to-issues/`, `to-prd/` (vendored) | drop | Upstream's older names. Rubbley has `to-tickets` and `to-spec`, and no fiber routine or skill calls either | — | — |
| `.claude/skills/qa/`, `ubiquitous-language/`, `design-an-interface/` (vendored) | drop | Fiber's own lockfile pins them from upstream's `skills/deprecated/`. Rubbley has `domain-modeling` and `codebase-design` instead | — | — |
| `.claude/skills/resolving-merge-conflicts/` (vendored) | drop (optional add) | No routine names it. It would suit the fix-up routine's H7 case, and upstream still lists it under `skills/engineering/`. If wanted, add it with `npx skills add mattpocock/skills -a claude-code --copy -s resolving-merge-conflicts` rather than copying fiber's copy | — | — |

Both wayfinder skills and `afk-pipeline.md` call `superpowers:writing-plans`. Rubbley already enables the `superpowers` plugin in `.claude/settings.json`, so that needs no extra setup.

### `.github/`

| Fiber path | Verdict | Reason | Fiber-specific parameters to change | Provisioning |
|---|---|---|---|---|
| `.github/workflows/pr-triage.yml` | adapt | Automation 3a: runs the rules script, then Claude limited to `Read,Glob,Grep,Bash(gh api:*)` with the prompt extracted from `main` | App name in step names and comments; prompt path `documentation/agents/` → `docs/agents/`; cron `30 2,17 * * *` (input for #180); the Actions-minutes cost comment (#1526) doesn't apply to a public repo; `--model claude-sonnet-5-5` | Secrets: `TRIAGE_APP_ID`, `TRIAGE_APP_PRIVATE_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`. A triage GitHub App on Rubbley with Issues, Pull requests and Commit statuses write, and Actions, Checks and Contents read |
| `.github/workflows/agent-merge.yml` | adapt (large) | Automation 3b: the deterministic batch merge queue. The way it handles risk (selection runs no PR code, the test job gets no secrets, it pushes only the exact tested tip, and it starts in shadow mode) is the part worth porting | The push step has to work with the ruleset (fact 2); `[skip ci]` on the last merge commit has to go or the Pages deploy has to be triggered another way (fact 3); `uses: ./.github/actions/godot-tests` → a Rubbley equivalent of the `check` job, with xvfb for the input suite and `issues: read` for `check.sh`'s quarantine lookup (fact 5); hardcoded bot identity `snackpack-fiber-merge[bot]` and user id `357134133` in `git config`; `GODOT: godot` env; failure classification by `test_results_*.xml` (GUT junit) → gdUnit4's reports under `reports/<suite>/`; the sparse checkout list is fine (`project.godot`, `*.uid`) | Secrets: `AGENT_MERGE_APP_ID`, `AGENT_MERGE_APP_PRIVATE_KEY`. Variables: `AGENT_MERGE_ENABLED` (leave unset at first, for shadow mode), `AGENT_MERGE_MAX`, `TRIAGE_ACTOR`. A merge GitHub App on Rubbley with Contents, Pull requests and Issues write, and Actions, Checks and Commit statuses read. Ruleset bypass or another merge path (fact 2) |
| `.github/workflows/factory-metrics.yml` | adapt (small) | Automation 5: no model, `GITHUB_TOKEN` only | Cron `23 12 * * 1` (input for #180); sparse checkout of `scripts` is fine | Labels: `process` (the script files the report with it). No secrets: `issues: write` on `GITHUB_TOKEN` |
| `.github/workflows/claude.yml` | adapt | `@claude` mentions on issues and PRs. The map's five automations don't include it, but the ticket asks for it, and the PR fix-up work overlaps with what it does | Godot `4.7.2` hardcoded → read `.godot-version` as `ci.yml` does; `pip install gdtoolkit` and `GODOT="godot" > .env` go (Rubbley uses the GDQuest formatter through `check.sh`, and `env.sh` finds `godot` on PATH); `--allowed-tools` `scripts/lint.sh`, `format.sh` → `scripts/check.sh`, `scripts/test.sh`, `scripts/import.sh`. On a public repo, check who can trigger it: confirm the action only acts for users with write access before enabling | Secret: `CLAUDE_CODE_OAUTH_TOKEN`. Claude GitHub App on Rubbley |
| `.github/actions/godot-tests/action.yml` | adapt (rewrite) | The idea, one test sequence shared by CI and `agent-merge`, is needed. The contents are all fiber's (gdlint, GUT batching and retries for fiber issue #623, leak ceilings, GTraits/ResourceGroup freshness) | Replace with Rubbley's `check` steps: `.godot-version` pin, `scripts/check.sh`, `xvfb-run scripts/test.sh`, plus `python -m unittest discover -s scripts/tests` for the ported triage scripts | — |
| `.github/workflows/godot-ci.yml` | drop (reference only) | Rubbley has its own `ci.yml`. Two fiber pieces the port touches: the `python -m unittest` step for the triage rules (add to Rubbley's CI) and the `ci_already_tested.py` skip (see below) | — | — |
| `.github/pull_request_template.md` | adapt (optional) | Rubbley has no PR template. Fiber's checklist covers multiplayer, the board and playtests, so the content would be new (input for #179) | Multiplayer line → the #179 gate; `Fiber v1.0` board → milestone; GUT → gdUnit4 | — |

### `scripts/`

| Fiber path | Verdict | Reason | Fiber-specific parameters to change | Provisioning |
|---|---|---|---|---|
| `scripts/pr_triage_rules.py` | adapt | The hard rules, and the shared `GitHub` client that `factory_metrics.py` imports. The machinery (gather facts, first match wins, fail closed, `SKIP` for drafts and running CI) is generic | `REPO` default `snackpackgames/fiber`; `CLOSING_LINK`'s `snackpackgames/fiber` prefix; `H1_DIRS`/`H1_FILES` (`documentation/agents/`, `tools/`, `art/pipeline/`, `test/hooks/`, `.gutconfig.json`, `.gdlintrc`, `docker-compose.yml`, `.gitmodules`, `documentation/wiki`); `H2_DIRS` (`nakama/`, `network/`, `save/`); H3's `signals/`; `MEDIA_EXTENSIONS` (`.aseprite`, `.pxc`; Rubbley's 3D assets aren't listed); `REVIEWED_SCENE_DIRS` (`maps/`, `dungeon/`, `ui/`); `MAX_FILES`/`MAX_LINES`; `DOCS_ONLY` (fact 4); `_is_gut_test` (`test/unit/`, `test_*.gd`) → gdUnit4 (`test/unit/` or `test/input/`, `*_test.gd`); `TEST_DISABLING` (`pending(`, `skip_script`) → gdUnit4 `do_skip`; the `playtest` label in H11. Every rule value is input for #178 | Labels: `ready-for-agent`, `ready-for-human`, `playtest` (if H11 keeps it) |
| `scripts/tests/test_pr_triage_rules.py` | adapt | Keeps the rules honest in CI | Its fixtures use fiber paths and GUT names, so it changes with every rule above | — |
| `scripts/agent-merge.sh` | adapt (small) | Deterministic select, verify and comment. Almost nothing in it is fiber-specific | `REPO` default `snackpackgames/fiber` (and its usage comment); policy link `documentation/agents/` | Labels: `merge:low-risk`, `merge:high-risk` |
| `scripts/factory_metrics.py` | adapt | Weekly report | `IDEAS_REPO = "snackpackgames/fiber-ideas"` and the `fiber`/`fiber_ideas` map counts → one count; `MERGE_BOT`/`TRIAGE_BOT` logins; the cost section (billed-minutes reconstruction, which has no cost on a public repo; input for #180); `regression` and `process` labels | Labels: `process`, `regression` |
| `scripts/tests/test_factory_metrics.py` | adapt | Tests the report | Follows the script's changes | — |
| `scripts/ci_already_tested.py` | drop | It lets a push to `main` skip CI when its PR already tested the same tree. On Rubbley the push to `main` also deploys the Playtest Build, so CI on `main` has to run anyway | — | — |
| `scripts/tests/test_ci_already_tested.py` | drop | Goes with the script | — | — |
| `scripts/ensure-godot.sh` | drop | Rubbley's `source scripts/env.sh --install` already downloads the pinned Godot into `.tools/`. The routine prompts just need to call it | — | — |
| `scripts/check-branch-name.sh` | drop (input) | Enforces fiber's branch names in a pre-push hook. Rubbley has no Branches section in `CONTRIBUTING.md` for it to enforce, and the routine prompts point at one (fact 8) | — | — |

## Routines and workflows: what each depends on

### Daily issue pickup (`/schedule` cloud routine)

- **Prompt:** `docs/agents/scheduled-routine-prompt.md` on `main`, read by the bootstrap in `cloud-routines.md`.
- **Runs as:** the person whose Claude account owns the `/schedule` routine, through the cloud GitHub proxy (REST only; `gh pr create` works).
- **Needs:** the Claude GitHub App on Rubbley; `ready-for-agent` issues created by `/wayfinder-handoff` with native `blocked_by` edges; plans merged to `docs/plans/` before the issues exist; Godot in the sandbox (`source scripts/env.sh --install`); `scripts/test.sh unit` and `scripts/check.sh` working without GraphQL (fact 7); a Branches section in `CONTRIBUTING.md`.
- **Must not touch:** the `merge:*` labels or the `pr-triage` status.
- **Depends on:** #179 (what the gameplay gate asks before it may start) and #180 (when it runs).

### Daily wayfinding (`/schedule` cloud routine)

- **Prompt:** `docs/agents/wayfinding-routine-prompt.md`.
- **Needs:** the Claude GitHub App on Rubbley; `wayfinder:map` issues with sub-issues and `wayfinder:grilling|prototype|research` labels (all exist); for prototypes, Godot through `env.sh --install` and a `prototypes/<name>/` convention; for research, a stated home in `docs/research/`.
- **Keeps unchanged:** the loop guard (it skips a grilling ticket whose last comment is its own).
- **Depends on:** #180 (schedule).

### PR triage (`pr-triage.yml`, GitHub Actions)

- **Prompt:** `docs/agents/pr-triage-routine-prompt.md`, extracted by the workflow from the `## The prompt` text block.
- **Runs as:** a triage GitHub App. Fiber's docs say why it can't be a cloud routine: the cloud proxy blocks the App-token endpoints, replaces `Authorization`, and refuses to post commit statuses.
- **Needs:** secrets `TRIAGE_APP_ID`, `TRIAGE_APP_PRIVATE_KEY` and `CLAUDE_CODE_OAUTH_TOKEN`; the App installed on Rubbley; labels `merge:low-risk` and `merge:high-risk`; `scripts/pr_triage_rules.py` ported, with tests running in CI.
- **Depends on:** #178 (every hard rule and judgment check, including how "gameplay feel changes are always high-risk" is detected) and #180 (cron).

### Agent merge (`agent-merge.yml`, GitHub Actions)

- **Trigger:** `workflow_run` after a successful `pr-triage` run, or by hand.
- **Runs as:** a merge GitHub App.
- **Needs:** secrets `AGENT_MERGE_APP_ID` and `AGENT_MERGE_APP_PRIVATE_KEY`; variables `TRIAGE_ACTOR` (the triage App's bot login), `AGENT_MERGE_MAX` and `AGENT_MERGE_ENABLED` (unset means shadow mode); a shared test action matching the `check` job.
- **Blockers specific to Rubbley:** the `main` ruleset's required `check` with no bypass (fact 2), and `[skip ci]` against the Pages deploy (fact 3). Both have to be solved before `AGENT_MERGE_ENABLED=true`. Shadow mode never pushes, so it can run before they are.
- **Depends on:** #178 (it re-runs the hard rules at merge time).

### PR fix-up (`/schedule` cloud routine)

- **Prompt:** `docs/agents/fixup-routine-prompt.md`.
- **Needs:** the Claude GitHub App on Rubbley with push access to PR branches; label `fixup:skip`; the triage comment marker `<!-- pr-triage v1 ... -->` and the triage bot's login (it filters comments by author); Godot in the sandbox.
- **Depends on:** #178 (which findings count as mechanical, the map's open item) and #179 (what its STEP 3 review checks in place of multiplayer). For #180: fiber runs it an hour after issue pickup so the two never overlap.

### Factory metrics (`factory-metrics.yml`, GitHub Actions)

- **Model:** none.
- **Needs:** `GITHUB_TOKEN` with `issues: write`; labels `process` and `regression`; the triage and fix-up marker formats; the two bot logins.
- **Note:** it reads earlier reports for week-on-week deltas, so old report issues mustn't be edited.
- **Depends on:** #180 (schedule, and whether the Actions-minutes section stays).

### `@claude` (`claude.yml`, GitHub Actions)

- **Trigger:** comments and issues that mention `@claude`.
- **Needs:** `CLAUDE_CODE_OAUTH_TOKEN`; the Claude GitHub App on Rubbley; `id-token: write`; Godot set up from `.godot-version`.
- **Before enabling:** on a public repo, confirm that only collaborators can trigger it.

## Provisioning checklist

What the inventory says is needed. #140 lists "Provisioning" as not yet specified, so this is the list it can work from, not a decision.

- **GitHub Apps:** a triage App and a merge App installed on Rubbley, with the permissions in fiber's Identities table (`pr-triage-routine-prompt.md`, *Identities*). The org's existing `snackpack-fiber-triage` and `snackpack-fiber-merge` could be installed on Rubbley as well, or new Rubbley-named Apps created; their names are hardcoded in the scripts and the `TRIAGE_ACTOR` variable either way. Also confirm the `claude` App covers Rubbley.
- **Actions secrets:** `TRIAGE_APP_ID`, `TRIAGE_APP_PRIVATE_KEY`, `AGENT_MERGE_APP_ID`, `AGENT_MERGE_APP_PRIVATE_KEY` and `CLAUDE_CODE_OAUTH_TOKEN`. None exist today.
- **Actions variables:** `TRIAGE_ACTOR`, `AGENT_MERGE_ENABLED` (leave unset at first), and `AGENT_MERGE_MAX` (optional).
- **Labels:** `merge:low-risk`, `merge:high-risk`, `fixup:skip`, `process`, `regression` and `wayfinder:parked`, plus `playtest` if H11 keeps it.
- **Branch protection:** the `main` ruleset needs a merge path for `agent-merge` (fact 2). Its required check `check` must stay the name of the shared test job.
- **Repo docs:** a Branches section in `CONTRIBUTING.md`; `docs/plans/`; a home for `system-spec` docs.

## Inputs for the grilling tickets

### #178: triage rules

These are fiber's values. Each needs a Rubbley value or a decision to drop it.

- **H1 (policy and tooling paths).** Fiber's are listed in the `pr_triage_rules.py` row above. Rubbley candidates: `.github/`, `.claude/`, `scripts/`, `docs/agents/`, `addons/` (vendored gdUnit4), `CLAUDE.md`, `CONTRIBUTING.md`, `skills-lock.json`, `project.godot` (fiber lets added `[autoload]` and `[input]` entries through), `export_presets.cfg`, `.godot-version`, `.gdscript-formatter-version`, `.gitignore`, `.gitattributes`, and possibly `unity/` (frozen reference).
- **H2 (backend, network, persistence).** Rubbley has none of fiber's three directories. Decide whether `game/store/` (platform services, ADRs 0015 and 0019) or any save code takes its place.
- **H3 (autoloads and the global signal surface).** Works from `project.godot` as is (`MoveInput`, `PlatformServices`). There is no `signals/` directory.
- **H4 (not reviewable from the diff).** Rubbley's binary and 3D formats (for example `.glb`, `.gltf`, `.res`, textures, audio), and which `.tscn` directories (perhaps `game/levels/`) need eyes.
- **H5 (size).** Fiber allows 25 files and 500 lines.
- **H9 (test weakening).** In gdUnit4 terms: a `*_test.gd` moved out of `test/unit/` or `test/input/`; any new `do_skip` (whether `check.sh`'s quarantine is enough or it's always high-risk); `test/support/` changes, since `SimulationTestSuite` is shared.
- **H11 (agent-ready spec).** The open-decision heading list, and whether to keep the `playtest` label.
- **H12 (untrusted origin).** On a public repo this rule carries more weight. Fiber trusts `OWNER`, `MEMBER` and `COLLABORATOR`.
- **J3 (shared code).** Rubbley's equivalents of fiber's shared base classes, perhaps `game/gravity/`, `game/common/`, the play-plane bodies, `test/support/simulation_test_suite.gd` and tuning `.tres` resources (ADR 0017).
- **Feel is always high-risk** (settled on #140). How does code detect a feel change? By path (`game/`), by resource type (stats and tuning resources), or only through a judgment check?
- **The fix-up routine's fixable set.** Fiber fixes H7, H10, H11 (closing link only), J2, and one fiber-only H1 case. The map's open item asks which of these Rubbley allows.

### #179: gameplay gate and issue template

- **Where fiber puts the multiplayer gate**, which the GDD-section-plus-feel check replaces: the plan's Multiplayer section (`afk-pipeline.md`, handoff step 2), the issue template's client-visibility acceptance criterion, the scheduled routine's step 4 stop condition ("comment on the issue naming what's missing, remove your assignment"), the fix-up routine's STEP 3 defect check, the PR template checklist, and handoff precondition 3.
- **The issue template's test line.** Fiber's says "All new and existing GUT tests pass (`bash scripts/test.sh`)". Rubbley needs gdUnit4 through `scripts/test.sh`, `scripts/check.sh`, and a decision on whether routines must run the input suite.
- **Which GDD sections** the check points at (`docs/gdd/rubbley-gdd.md`), what a plan has to say to pass the feel check, and who signs it off.
- **Whether Rubbley adds a PR template.**

### #180: schedules and budget

- **Fiber's schedules:** issue pickup at 02:12 and 08:12 Eastern; wayfinding at 07:08 Eastern; fix-up at 03:12 and 09:12 Eastern (an hour after pickup); `pr-triage` at 02:30 and 17:30 UTC, with `agent-merge` chained after it; `factory-metrics` on Mondays at 07:23 Eastern (`cloud-routines.md`, and each workflow's `cron`).
- **Fiber's costs:** triage about 4 Actions minutes a run, `agent-merge` about 5, metrics about 3. On public Rubbley, standard-runner minutes cost nothing, so the budget is Claude usage: the `/schedule` routines and the triage model's `CLAUDE_CODE_OAUTH_TOKEN` runs both draw on a Claude subscription. If that is the same account as fiber's routines, the two projects share one budget.
- **Ordering constraints in fiber:** fix-up runs after pickup so they never overlap; triage runs before agent-merge. Triage then re-checks fix-up pushes the same day.
- **What factory metrics should report on cost**, given that Actions minutes cost nothing here and routine runs aren't visible to Actions (`factory-metrics.md`, *Limits*).

## Not covered

- Fiber's `.claude/commands/`, `.claude/memory/` and `.claude/agents/level-design-expert.md`, and the scripts the pipeline doesn't use (art, export, playtest and Nakama). They are outside the ticket's list.
- Whether the `claude` App, `snackpack-fiber-triage` or `snackpack-fiber-merge` is installed on Rubbley today. The installation repo lists need an App token.
- Whether `claude-code-action` limits triggers to users with write access by default. That needs checking in the action's docs before `claude.yml` is enabled.
