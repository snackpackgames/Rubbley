# Can the cloud routines build and test Rubbley? (as of 2026-11-28)

Research for [#177](https://github.com/snackpackgames/Rubbley/issues/177), part of map [#140](https://github.com/snackpackgames/Rubbley/issues/140) (fiber's AFK pipeline, ported to Rubbley).
Question: can the unattended routines build and test Rubbley where they run, and what can a routine verify before it opens a PR?

## Summary

- **Cloud sessions run Ubuntu 24.04 on x86_64**, as root in setup scripts, with 4 vCPUs, 16 GB RAM and 30 GB disk. The Default environment's **Limited** network access allowlists `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` and the Ubuntu apt mirrors. [1][2]
- **`source scripts/env.sh --install` should work unchanged.** It downloads the Linux x86_64 Godot zip from `github.com/godotengine/godot/releases`, which is the same URL and the same tools (`curl`, `unzip`) that fiber's `ensure-godot.sh` uses. Fiber's cloud routines have done this download and then run GUT headless in many PRs, most recently on 2026-11-27. [3][4][5] Nobody has run Rubbley's own script in a cloud session yet.
- **`scripts/import.sh`, `scripts/check.sh` and `scripts/test.sh unit` need nothing a cloud VM lacks**, as far as the docs and fiber's record show. `check.sh` also downloads the GDQuest formatter from github.com releases. There is one known trap: its skipped-tests gate calls `gh issue view`, which uses GraphQL, and the cloud GitHub proxy refuses GraphQL. That gate fails in the cloud as soon as any test is quarantined. No test is quarantined today. [2][6]
- **The `input` suite isn't covered by the docs.** The cloud image doesn't list `xvfb`, Mesa or any display package. [2] A setup script can `apt install` them, because the Ubuntu mirrors are allowlisted, but whether Godot's Compatibility (OpenGL 3.3) renderer starts under Xvfb on that VM, and whether input events then arrive, **can only be confirmed by running it in a cloud session**.
- **GitHub Actions routines can rely on CI's `check` job.** It's the required check on `main`, and it runs `check.sh`, both suites under `xvfb-run`, and a web export, on `ubuntu-latest`. [7][8] A cloud routine that can't run `input` can leave that suite to CI.
- **`/schedule` setup:** none of this is strictly required, because the Default environment already allows the downloads. A setup script that pre-installs Godot, the formatter and (if it works) `xvfb` would be cached, so runs would skip the download. Fiber configures no setup script: each run downloads Godot itself. [1][4]

## 1. What a cloud session is

Every cloud session, including each run of a `/schedule` routine, runs in a *cloud environment*, which sets network access, environment variables and a setup script. A scheduled task "inherits the environment's network policy on every run". [1][9]

From the cloud-environments page [1]:

- **Image:** "each session gets a fresh virtual machine (VM) running Ubuntu 24.04 on x86_64". Pre-installed tools include Python, Node, Java, Go, Rust, GCC/Clang, Docker, Chrome for Testing, `git`, `gh`, `jq`, `yq` and `ripgrep`. The list doesn't mention `xvfb`, X11, Mesa, `curl` or `unzip`. (`curl` and `unzip` are evidently present: fiber's `ensure-godot.sh` uses both and works, see section 4.)
- **Resources:** about 4 vCPUs, 16 GB RAM and 30 GB disk.
- **Time limits:** a foreground command waits 2 minutes by default and can ask for up to 10. A command that hits its timeout moves to the background and gets up to 30 more minutes. `BASH_DEFAULT_TIMEOUT_MS` and `BASH_MAX_TIMEOUT_MS` raise the limits per environment.
- **Setup scripts:** "Scripts run as root on Ubuntu 24.04, so `apt install` and most language package managers work." They run before Claude Code starts. If the script finishes in roughly five minutes, the filesystem is snapshotted and reused by later sessions. The cache rebuilds when the script or allowed hosts change, and after about seven days. The script must exit zero, or the session fails to start.
- **SessionStart hooks** in the repo's `.claude/settings.json` run on every start and resume, locally and in the cloud. `CLAUDE_CODE_REMOTE=true` tells a script it's in the cloud. They don't run in sessions with several repositories, or in project threads.

### Network

The Default environment is **Limited** with **Allow package managers** checked. [1] Its default allowlist includes `github.com`, `api.github.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` and `codeload.github.com`, plus `archive.ubuntu.com`, `security.ubuntu.com`, `*.ubuntu.com` and `ppa.launchpad.net`. [1]

GitHub traffic also goes through a separate **GitHub proxy** [1]:

- It serves API requests only for the repositories attached to the session. "A source archive you fetch over a `github.com/{owner}/{repo}/archive/` or `codeload.github.com` URL gets that same 403 when the repository isn't attached, even a public one." The docs don't say whether **release-asset** downloads from an unattached repo (`godotengine/godot`, `GDQuest/GDScript-formatter`) are scoped the same way. Fiber's runs show they aren't, at least up to 2026-11-27 (section 4).
- It refuses GraphQL: "`gh` subcommands that use GraphQL, such as `gh pr` and `gh issue`, get the same 403", whatever token you set. Fiber's `issue-tracker.md` documents the same restriction and its REST workarounds. [6]

## 2. Rubbley's scripts, step by step

| Step | What it needs | In a cloud session |
|---|---|---|
| `source scripts/env.sh --install` | `uname`, `curl`, `unzip`; downloads `Godot_v4.7.2-stable_linux.x86_64.zip` from `github.com/godotengine/godot/releases` into `.tools/godot/4.7.2/` (gitignored) [10] | Expected to work: the same asset, host and tools as fiber's `ensure-godot.sh`. Not yet run for Rubbley. |
| `scripts/import.sh` | `$GODOT_BIN --headless --import` [10] | Expected to work. Fiber's routines run the same command. [5] |
| `scripts/check.sh` | Godot import and `--check-only` per script; downloads `gdscript-formatter-0.27.0-linux-x86_64.zip` from `github.com/GDQuest/GDScript-formatter/releases`; `awk`; `gh issue view` for each quarantined test [10] | Everything but the last gate is expected to work. **`gh issue view` uses GraphQL and gets a 403**, so the skipped-tests gate fails once any test is quarantined (none today). Swapping it for `gh api repos/snackpackgames/Rubbley/issues/<n> --jq .state` would work locally, in CI and in the cloud. |
| `scripts/test.sh unit` | `--headless --ignoreHeadlessMode --fixed-fps 60` through gdUnit4 6.2.2's `runtest.sh`; writes `reports/unit/` [10][11] | Expected to work. Headless needs no display or GPU. Fiber's cloud runs prove headless Godot 4.7.2 works there, though with GUT, not gdUnit4. |
| `scripts/test.sh input` | No `--headless`; `--audio-driver Dummy`; a display server ("xvfb in CI, the desktop locally") [10][12] | **Unconfirmed.** See section 3. |
| `scripts/test.sh` (both) | as above | Runs `unit`, then fails on `input` without a display, so a cloud routine should run `unit` alone unless `input` is confirmed to work. |

Two things in the scripts help here:

- `env.sh` checks the version first: it accepts any Godot whose `--version` starts with `4.7.2.stable`, from `$GODOT_BIN`, `PATH` or `.tools/`. A setup script that installs Godot somewhere on `PATH`, or into `.tools/`, is picked up with no other change. [10]
- `rubbley_os` reports `linux` on the VM, and `rubbley_arch` reports `x86_64`, which picks the right Godot and formatter assets. [10]

Time: the 2-minute default foreground limit could cut off a full `check.sh` (a `--check-only` launch per script) or a slow first import. A command that hits it moves to the background rather than failing [1], so this costs time, not correctness. A routine prompt can ask for the 10-minute timeout, or the environment can set `BASH_DEFAULT_TIMEOUT_MS`.

## 3. The `input` suite

ADR 0011 puts every test that injects InputEvents in `test/input/`, because "Godot doesn't deliver input events under `--headless`, so this suite needs a display server". [12] There are four test files today. [13]

What the sources establish:

- The cloud image lists no display server or GL stack. [2]
- A setup script runs as root with the Ubuntu mirrors allowlisted, so `apt install -y xvfb` (and Mesa's software GL, such as `libgl1-mesa-dri`) should install. [1] The docs don't say so for these packages specifically.
- Rubbley renders with `gl_compatibility` on desktop and mobile, which is OpenGL 3.3, so under Xvfb it needs Mesa's software renderer rather than Vulkan. [14]
- CI already runs this suite under `xvfb-run` on `ubuntu-latest`, and it passes there. [7]
- Fiber's PR #1126, opened from a cloud session, reports launching a scene "under `xvfb-run`" that "boots and quits with no script errors". [15] But it ran that command with `--headless` as well, which makes Xvfb irrelevant, and it doesn't say how `xvfb-run` got there. So it shows at most that `xvfb-run` was available in that session once, not that Godot rendered or received input.

**What would have to be tried in a cloud session:** install `xvfb` and the Mesa GL packages (in a setup script, or by hand mid-session), then run `xvfb-run --auto-servernum scripts/test.sh input` and see whether Godot opens a window and the four files pass. Until that has been tried, a cloud routine should treat `input` as CI's job, and the triage rules should not trust a routine's claim to have run it.

## 4. How fiber does it

Fiber is the same stack apart from its test framework (Godot 4.7.2, GDScript, GUT instead of gdUnit4).

- **Getting Godot:** `scripts/ensure-godot.sh` downloads `Godot_v<pin>-stable_linux.x86_64.zip` from github.com releases with `curl -fsSL`, unzips it into `$HOME/.cache/godot-fiber`, and writes `GODOT=` into `.env`. Its header says it's "intended for disposable sandboxes (cloud agent runs)", and that CI uses `chickensoft-games/setup-godot@v2` instead. [4] Its CLAUDE.md tells a sandbox with no user to run it. [16] It landed in fiber PR #738, whose test plan left "verify in a real cloud sandbox run" unchecked. [17]
- **Where it's called:** the routine prompts call it, not a `/schedule` setup script. The fix-up routine runs it before its review step, which runs tests, and the wayfinding routine runs it before building a prototype. [18][19] The Daily Issue Pickup prompt just says to run `bash scripts/test.sh`. Its runs rely on the session following CLAUDE.md's instruction to call `ensure-godot.sh` first. [16][20]
- **Running GUT:** `scripts/test.sh` runs `"$GODOT" -v --headless -s addons/gut/gut_cmdln.gd ...`. All of fiber's tests are headless, and it has no display-bound suite. [21]
- **Evidence it works:** cloud-session PRs report `ensure-godot.sh` downloading Godot and then full GUT runs, for example #792 (2758/2758 passing), #945 (2957 tests, 0 failures), #1019 (3027/3027) and #1126 (3074 of 3075). [5] On 2026-11-27 the fix-up routine commented on PR #1302 with "Tests run: `bash scripts/test.sh addons` (5/5 passing)". [22] (Earlier PRs downloaded 4.6.1, the pin at the time.)
- **`/schedule` configuration:** fiber's `cloud-routines.md` says a routine "is configured with this bootstrap and nothing else" (a prompt that reads the real prompt from `main`). Schedule, model and connectors are set in `/schedule`. It records no setup script, custom network access or environment variables. [3] Each run therefore downloads Godot itself, and nothing is cached.
- **Display work** (fiber's playtest captures) runs on Actions, which `apt-get install`s `xvfb` first, or in a Docker image (`scripts/playtest-ci.sh`). Fiber's cloud routines don't do it. [23]
- **GitHub:** fiber's prompts use `gh api` REST calls instead of `gh issue`/`gh pr edit`, because of the GraphQL block. `gh pr create` "is **not** affected and stays in use". [6][20]

## 5. What GitHub Actions routines get from `ci.yml`

Rubbley's `ci.yml` has one job that matters here, `check`, which "the main ruleset requires ... by name". It runs on every PR and on every push to `main`, on `ubuntu-latest` with a 30-minute timeout [7]:

1. `chickensoft-games/setup-godot@v2` installs the `.godot-version` pin with export templates.
2. `scripts/check.sh` runs with `GH_TOKEN` set, and with `issues: read` permission so the quarantine gate can look issues up.
3. `xvfb-run --auto-servernum scripts/test.sh` runs both suites.
4. A `web-playtest` export is uploaded as an artifact.

On `main`, a `deploy` job publishes that export to GitHub Pages. [7] The repo has one ruleset, `main`. [8]

For the Actions-based routines in #140:

- **PR triage and agent-merge** can read the `check` status of a PR's head commit. It is a complete signal: compile, format, lint, global-RNG and quarantine gates, both suites, and a working web export. Fiber's agent-merge goes further and re-runs its whole suite (through a shared composite action, `.github/actions/godot-tests`) on the combined commit of a merge batch before pushing to `main`. [24] Rubbley has no such composite action yet: `check`'s steps live inline in `ci.yml`, so an agent-merge port would either duplicate them or first move them into a shared action.
- **Fiber's `claude.yml`** (the `@claude` Action) installs Godot with `setup-godot`, writes `.env` and imports before Claude runs, so Claude can run the scripts inside Actions. [25] A Rubbley port would do the same with `GODOT_BIN`, and would add `xvfb-run` if it should run `input`.
- **Factory metrics** runs no Godot.

## 6. What to set up in `/schedule`

Nothing is required for headless work if the routine uses the **Default** environment. Limited network access already allows github.com and its release-asset hosts. [1][9] Options, from least to most setup:

1. **Like fiber:** the routine prompt (or CLAUDE.md) says to run `source scripts/env.sh --install` first. Each run downloads Godot (and `check.sh` downloads the formatter) into `.tools/`.
2. **A setup script on the routine's environment**, so the downloads are cached for about seven days. It would clone nothing (the repo is already cloned) and could run `source scripts/env.sh --install`, plus `scripts/check.sh` once to fetch the formatter, or copy the binaries to a path outside the repo and put Godot on `PATH`. Whether `.tools/` inside the cloned repo survives the snapshot into later sessions isn't documented. Installing outside the repo avoids the question. It must exit zero and finish in about five minutes. [1]
3. **For `input`:** add `apt install -y xvfb` and Mesa GL packages to that setup script, then confirm in a cloud session (section 3).
4. **Timeouts:** consider `BASH_DEFAULT_TIMEOUT_MS=600000` on the environment, so `check.sh` and the test runs aren't sent to the background at 2 minutes. [1]

Environment variables set on the environment aren't available to the setup script. [1]

## Not confirmed and needing a cloud run

- That `source scripts/env.sh --install`, `scripts/check.sh` and `scripts/test.sh unit` pass in a Rubbley cloud session. The evidence is from fiber's equivalent scripts, not these ones.
- That gdUnit4 6.2.2's CLI runner behaves headless on the cloud VM as it does on `ubuntu-latest`.
- That `xvfb`, Mesa and a non-headless Godot 4.7.2 with the Compatibility renderer work on the VM, and that the `input` suite's events arrive.
- How long a cold `check.sh` plus `test.sh unit` takes on 4 vCPUs.
- That the GitHub proxy keeps allowing release-asset downloads from repositories not attached to the session. The docs say nothing either way, and fiber's record is the only evidence.

## Sources

1. Claude Code docs, "Configure cloud environments": The Default environment, Network access, Access levels, GitHub proxy, Installed tools, Resource limits, Time limits, Setup scripts, Environment caching, Setup scripts vs. SessionStart hooks, Default allowed domains. https://code.claude.com/docs/en/cloud-environments
2. Same page, "Installed tools" and "GitHub proxy" (GraphQL restrictions). https://code.claude.com/docs/en/cloud-environments#installed-tools
3. fiber `documentation/agents/cloud-routines.md` (at fiber `41dd4f9d`).
4. fiber `scripts/ensure-godot.sh` and `scripts/godot_version.sh` (pin 4.7.2).
5. fiber PRs from cloud sessions: [#792](https://github.com/snackpackgames/fiber/pull/792), [#945](https://github.com/snackpackgames/fiber/pull/945), [#1019](https://github.com/snackpackgames/fiber/pull/1019), [#1126](https://github.com/snackpackgames/fiber/pull/1126), test-plan sections.
6. fiber `documentation/agents/issue-tracker.md`, "Cloud sessions (Claude Code on the web)".
7. Rubbley `.github/workflows/ci.yml`.
8. `gh api repos/snackpackgames/Rubbley/rulesets` (one ruleset, `main`), 2026-11-28.
9. Claude Code docs, "Automate work with scheduled tasks": Environments and network access, Permission prompts during a run. https://code.claude.com/docs/en/routines
10. Rubbley `scripts/env.sh`, `scripts/lib.sh`, `scripts/import.sh`, `scripts/check.sh`, `scripts/test.sh`, `.godot-version` (4.7.2), `.gdscript-formatter-version` (0.27.0), `.gitignore`.
11. Rubbley `addons/gdUnit4/runtest.sh`, `addons/gdUnit4/plugin.cfg` (6.2.2).
12. Rubbley `docs/adr/0011-gdunit4-split-suites-linux-ci.md`.
13. Rubbley `test/input/` (four `*_test.gd` files).
14. Rubbley `project.godot`, `[rendering]`.
15. fiber PR [#1126](https://github.com/snackpackgames/fiber/pull/1126), "What still needs human eyes" and "Test plan".
16. fiber `CLAUDE.md`, local setup section.
17. fiber PR [#738](https://github.com/snackpackgames/fiber/pull/738).
18. fiber `documentation/agents/fixup-routine-prompt.md`, STEP 3.
19. fiber `documentation/agents/wayfinding-routine-prompt.md`, `wayfinder:prototype`.
20. fiber `documentation/agents/scheduled-routine-prompt.md`.
21. fiber `scripts/test.sh`, `scripts/config.sh`.
22. fiber PR [#1302](https://github.com/snackpackgames/fiber/pull/1302), PR fix-up comment of 2026-11-27.
23. fiber `.github/workflows/playtest.yml`, `scripts/playtest.sh`, `scripts/playtest-ci.sh`.
24. fiber `.github/workflows/agent-merge.yml`, `.github/actions/godot-tests/action.yml`.
25. fiber `.github/workflows/claude.yml`.
