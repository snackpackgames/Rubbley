# One Platform Services seam, a backend per store picked by export feature tag

The game talks to every store through the Platform Services autoload (ADR 0016). It is a thin node that wraps one `StoreBackend`, a plain `RefCounted` contract with an implementation per store: Steam, Epic, Apple, Google Play, and a null backend for itch.io, web and the editor. Each export preset sets one `store_*` feature tag, and Platform Services loads the matching backend by path. Other stores' code and addons are never parsed in that build. Whether a build is the Full Game is a backend answer, not a separate setting. This keeps four unrelated store APIs (`research/godot-storefront-integrations`) behind one typed interface that tests can fake.

## The contract

- **Unlock:** `has_full_game() -> bool`, `purchase_unlock()`, `restore_purchases()`.
- **Achievements and leaderboards:** `unlock_achievement(id)`, `submit_score(board, score)`. The ids are the game's typed `Achievement` and `Leaderboard` enums. Each store maps them to its own ids in a mapping `.tres` in `game/store/<store>/`.
- **Cloud saves:** `cloud_capability` is `none`, `file_sync` or `in_code`. `in_code` backends add `push_save(bytes)` and `pull_save()`.
- **Capabilities:** flags for `leaderboards`, `achievements`, `unlock_purchase` and `cloud_saves`. The UI reads them to hide what a store doesn't have, such as the online board on itch.io and web, or Unlock and Restore on desktop.
- **Async results** are signals that Platform Services re-emits (`full_game_changed`, `unlock_purchase_finished(result)`, `leaderboard_loaded`, …). Callers call down into the autoload and listen for its signals (ADR 0016).
- Store-specific extras, such as Steam stats or the native Game Center panels, stay out of the contract until a feature needs them.

## Backend selection

| Feature tag | Backend | `has_full_game()` | Cloud saves |
|---|---|---|---|
| `store_steam` | GodotSteam | always true | `file_sync` (Auto-Cloud) |
| `store_epic` | EOSG | always true | `file_sync` (launcher) |
| `store_apple` | GodotApplePlugins | StoreKit 2 entitlement for the Unlock | `in_code` (Game Center saved games) |
| `store_play` | Play Billing + Play Games Services | Play Billing purchase of the Unlock | `in_code` (Play Games snapshots) |
| `store_itch` | null | false (Free Tier only) | `none` |
| `store_none`, or no tag (editor) | null | true (Full Game) | `none` |

- There is one export preset for each store and platform pair (`steam-windows`, `epic-macos`, `itch-linux`, `itch-web`, `ios`, `android`, `web-playtest`, …). `itch-web` is the shipping Free Tier web build, and `web-playtest` is the Full Game Playtest Build ([ADR 0020](0020-playtest-build-on-github-pages.md)).
- Each store's backend and SDK adapter live in `game/store/<store>/`. A preset excludes the other stores' folders and addons, so an Android build never parses a script that names `Steam`.
- The editor and the CI `--check-only` gate have every addon present, so every adapter stays statically typed (ADR 0014). The Play plugins ship typed GDScript wrappers (`BillingClient`, the Play Games client nodes) that hide their Android singleton, so no adapter needs `Engine.get_singleton()`.
- Steam and Epic do no ownership check, because the store already gated the download.
- The Free Tier gate (ADR 0015) reads only `PlatformServices.has_full_game()` and the free-levels list. Editor and debug builds take a command-line switch that forces Free Tier, so the gate can be tested without an itch.io build.

## Saves

- `application/config/use_custom_user_dir` is on and named `Rubbley`, so `user://` is `%APPDATA%\Rubbley`, `~/Library/Application Support/Rubbley` or `~/.local/share/Rubbley`. Steam Auto-Cloud's root overrides and Epic's portal settings point at the save file there. Save files are closed between writes so the launchers can sync on exit. How Epic's form takes that path is unchecked ([Check how Epic's cloud-save form takes Rubbley's save path](https://github.com/snackpackgames/Rubbley/issues/85)).
- Save/Settings (ADR 0016) owns the save format. On `in_code` stores it pulls at launch and pushes after each save, debounced.
- Conflicts between two cloud saves merge automatically with no dialog: the union of completed levels and owned Stat Modifier ids (ADR 0017), and the higher of each best score. The merge is a pure function with unit tests. A new save field that can't merge this way gets its own merge rule when it's added. Steam and Epic resolve conflicts in their launchers.
- Settings live in a separate local file and never sync, because they are per device.

## When the store can't answer

- Save/Settings caches the last known `has_full_game()`. The store's answer always replaces it, and the cache only covers a failed check, for example when a phone is offline. This makes the Unlock spoofable on a rooted device, which is an acceptable cost for a single one-time purchase.
- Achievements and scores are fire and forget. The store SDKs queue them offline, so the game keeps no queue of its own.
- Steam calls `restartAppIfNecessary`, so launching outside Steam relaunches through it. On Epic, if the launcher's exchange code is missing, achievements are off for that session and the game still runs as the Full Game.

## Testing

- Unit tests in `test/unit/game/store/` (ADR 0011) inject a `FakeStoreBackend` and drive its signals: purchase succeeded, cancelled or failed, Restore found the Unlock, store offline. They also cover the Free Tier gate, capability hiding and the save merge.
- One contract suite runs against every backend that builds headless: Null and Fake.
- Each store backend splits into translation logic, a plain class tested against a fake SDK object that records calls and emits SDK-shaped callbacks, and a thin SDK adapter, the only file that touches the plugin. Adapters have no CI tests. Each store gets a manual smoke checklist on its sandbox or test track before a release.
- The shipped-values suite (ADR 0017) checks that every `Achievement` and `Leaderboard` value is mapped for every store that has them.

## Considered Options

- **An autoload per service (Achievements, Leaderboards, Purchases):** rejected. It breaks ADR 0016's autoload list and splits every store across three files.
- **A per-preset config `.tres` to pick the backend:** rejected. It's one more file to forget, and feature tags already exist per preset.
- **Detecting the store at runtime:** rejected. Steam, Epic and itch.io builds run on the same OS and can't be told apart.
- **A separate tier setting:** rejected. itch.io and web would both use the null backend with different tiers anyway, so the tier lives where the answer comes from.
- **Untyped `Engine.get_singleton()` access in every adapter:** rejected. Loading by path and excluding per preset keeps the adapters typed.
- **A "keep which save?" dialog:** rejected. Save data only grows, so a merge loses nothing.
