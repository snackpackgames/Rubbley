# Godot 4.7 storefront integrations and CI submission

Research for [#42](https://github.com/snackpackgames/Rubbley/issues/42). Gathered 2026-10-14. Repo stats (last push, latest release, licence) come from the GitHub API on that date unless another source is cited.

Context: Rubbley is GDScript-only on Godot 4.7 (latest stable is [4.7.2, released 2026-08-18](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)). It ships on iOS, Android, Windows, macOS and Linux, including Steam Deck.

## Summary

| Store | Integration | Covers | Godot 4.7 | GDScript-only | Licence | Maintenance |
|---|---|---|---|---|---|---|
| Steam | GodotSteam (now on Codeberg) | Achievements, stats, leaderboards, Steam Cloud, and the rest of Steamworks | Yes: GDExtension for 4.4+, and module builds for 4.7.2 | Yes, if you use the GDExtension in the stock editor | MIT | Active: v4.23.1 released 2026-10-07 |
| App Store / Mac App Store | GodotApplePlugins (Miguel de Icaza) | Game Center (achievements, leaderboards, saved games), StoreKit 2, iCloud key-value | Yes: GDExtension, `compatibility_minimum = 4.2` | Yes, with prebuilt binaries | MIT | Active: automated builds through 2026-10 |
| App Store (alternative) | godot-sdk-integrations/godot-ios-plugins (`gamecenter`, `inappstore`, `icloud`) | Game Center, the legacy StoreKit 1 API, iCloud | Builds for 4.4 to 4.6 are confirmed; 4.7 is unverified | Yes, but you build it from source on a Mac | MIT | Slow: last fix 2026-01, and no 4.x binary release |
| Google Play | godot-google-play-billing | IAP and subscriptions (Billing Library 9.1) | Yes: Android v2 plugin for 4.2+ | Yes | MIT | Active: 3.3.0 released 2026-07-27 |
| Google Play | godot-play-game-services | Sign-in, achievements, leaderboards, snapshots (cloud saves) | Yes: 4.3+ (badge shows 4.5) | Yes | MIT | Active: v3.4.0 released 2026-07-20 |
| itch.io | None needed | No achievements, leaderboards, cloud saves or IAP. The server-side API covers only purchases and download keys | n/a | n/a | n/a | n/a |
| Epic Games Store (optional) | epic-online-services-godot (EOSG) | Achievements, stats, leaderboards, auth, lobbies | Yes: 4.2+ | Yes, through high-level GDScript classes | MIT | Active: 2.3.1 released 2026-09-15 |

| Store | CI upload tool | Secrets | Runner | Manual gates |
|---|---|---|---|---|
| Steam | steamcmd/SteamPipe, e.g. `game-ci/steam-deploy` | Build-account username and password, plus a TOTP shared secret or a base64 `config.vdf` | Linux (ubuntu-latest) | The default branch can't be set live from a script |
| App Store | fastlane `pilot`/`deliver` with an App Store Connect API key | Key ID, Issuer ID, `.p8` key, plus signing certificate and profile (e.g. via `match`) | **macOS with Xcode** | App review. `produce` (app creation) isn't supported with an API key |
| Google Play | Play Developer API through fastlane `supply` or `r0adkll/upload-google-play` | Service-account JSON | Linux | The first build must be uploaded by hand. New personal accounts need a closed test with 12 testers for 14 days |
| itch.io | butler | `BUTLER_API_KEY` | Any | None: a build is live once its upload finishes |

## Steam: GodotSteam

- **It has moved.** The GitHub repo `GodotSteam/GodotSteam` is archived, and its README says "This repository has been moved to Codeberg" ([GitHub README](https://github.com/GodotSteam/GodotSteam)). The canonical home is now [codeberg.org/godotsteam/godotsteam](https://codeberg.org/godotsteam/godotsteam). Old GitHub links and tutorials point at the archive.
- **Releases** ([Codeberg releases](https://codeberg.org/godotsteam/godotsteam/releases)):
  - v4.23.1 (2026-10-07): "Godot 4.4+ - Steamworks 1.65 - GodotSteam GDExtension 4.23.1", which "Works on any Godot version 4.4 and up".
  - v4.23 (2026-10-05): a module build with editor and export templates in "Godot 4.7.2 and 4.5.2 variants".
- **Licence:** MIT ([Codeberg repo](https://codeberg.org/godotsteam/godotsteam)).
- **Platforms:** Windows, Linux and macOS ([Codeberg repo](https://codeberg.org/godotsteam/godotsteam)). Steam Deck runs the Linux build.
- **GDScript usability:** You can drop the GDExtension plugin into a stock Godot 4.7 editor, so no custom engine build is needed. The module variant replaces the editor and export templates. The API is GDScript-callable, for example `setAchievement`, `storeStats`, `findLeaderboard` (which returns its result through the `leaderboard_find_result` signal) and `uploadLeaderboardScore` ([GodotSteam User Stats docs](https://godotsteam.com/classes/user_stats/)).
- **Cloud saves:** Steam Auto-Cloud syncs the file groups you list in Steamworks settings at launch and exit, with no code changes. The `ISteamRemoteStorage` API gives finer control. Dynamic Cloud Sync was designed for Steam Deck suspend and resume, and a game may need code to react to files that change mid-session ([Steam Cloud docs](https://partner.steamgames.com/doc/features/cloud)). Auto-Cloud alone could cover Rubbley's saves on Steam.
- **Caveat:** Under GodotSteam's 4.20 compatibility entry, its README says "Godot 4.7 changed callable_method_pointer.h to callable_mp.h which will break backwards compatibility" ([Codeberg repo](https://codeberg.org/godotsteam/godotsteam)). Use releases built for 4.7 (GodotSteam 4.20+).

## Apple: Game Center and StoreKit

### GodotApplePlugins (recommended candidate)

- It ships bindings for Game Center, StoreKit 2, Sign in with Apple, iCloud key-value storage, ARKit and CoreMotion, for macOS, iOS and visionOS ([README](https://github.com/migueldeicaza/GodotApplePlugins)).
- The releases contain prebuilt binaries: macOS dynamic libraries and an iOS xcframework. On Windows and Linux it loads "empty stubs so that your project can reference the API without compile errors" ([README](https://github.com/migueldeicaza/GodotApplePlugins)). That matters for a project that also exports to Windows and Linux.
- It requires iOS 17.0 and macOS 14.0 ([README](https://github.com/migueldeicaza/GodotApplePlugins)).
- The `.gdextension` files declare `compatibility_minimum = 4.2` ([godot_apple_plugins_game_center.gdextension](https://github.com/migueldeicaza/GodotApplePlugins/blob/main/addons/GodotApplePluginsGameCenter/godot_apple_plugins_game_center.gdextension)).
- The Game Center guide shows GDScript for achievements (`GKAchievement.load_achievements`), leaderboards (`GKLeaderboard.load_leaderboards`, `submit_score`) and saved games, including conflict resolution (`conflicting_saved_games`, `resolve_conflicting_saved_games`) ([GameCenterGuide.md](https://github.com/migueldeicaza/GodotApplePlugins/blob/main/Sources/GodotGameCenter/GameCenterGuide.md)). Game Center saved games would give cloud saves on iOS and macOS.
- The API "is to be as close to possible to the Apple APIs" and uses Godot callbacks instead of delegates ([README](https://github.com/migueldeicaza/GodotApplePlugins)). It adds no cross-store abstraction, so Rubbley would write its own.
- Licence: MIT. Last push was 2026-10-12, and CI builds have run regularly (latest 2026-10-01) (GitHub API). It is listed on the [Godot Asset Library](https://godotengine.org/asset-library/asset/4552). It is a single-maintainer project with no version-tagged releases, only `build-<sha>` tags.

### godot-sdk-integrations/godot-ios-plugins (legacy option)

- It contains `gamecenter`, `inappstore`, `icloud`, `apn` and other plugins (repo `plugins/` directory). For Godot 4.x you build Godot's iOS headers and run `generate_xcframework.sh` yourself on a Mac with scons ([README](https://github.com/godotengine/godot-ios-plugins)). The only binary releases are for 3.x, with the latest being 3.5-stable from 2022 (GitHub API).
- Recent commits are "Fix build with Godot 4.4" (2025-01) and "Fix build with Godot 4.5/4.6" (2025-08, merged 2026-01). Nothing explicitly covers 4.7 (GitHub API commit log).
- The Godot iOS plugin docs that describe the `InAppStore` singleton are flagged as possibly outdated ([Godot docs: plugins for iOS](https://docs.godotengine.org/en/4.4/tutorials/platform/ios/plugins_for_ios.html)).

Other options are smaller single-purpose plugins: the MIT-licensed StoreKit 2 plugin [atlasapplications/godot-store-kit](https://github.com/atlasapplications/godot-store-kit) (v1.5.0, 2025-12, 5 stars) and [GameCenterKit](https://store.godotengine.org/asset/keremvatandas/gamecenterkit/), which covers authentication, scores, achievements and native panels on Godot 4.5 to 4.7, but not saved games.

## Google Play

### Play Billing: godot-google-play-billing

- "The master branch supports Godot 4.2 and above" ([README](https://github.com/godot-sdk-integrations/godot-google-play-billing)). It is installed as an editor plugin and needs `gradle/use_gradle_build` enabled in the Android export ([README](https://github.com/godot-sdk-integrations/godot-google-play-billing)).
- 3.3.0 (2026-07-27) bumped it to Billing Library v9.1.0. 3.2.0 added one-time-product purchase options and offers, and changed the `purchase(...)` and `update_subscription(...)` signatures ([releases](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases)). The docs are at [godot-sdk-integrations.github.io/godot-google-play-billing](https://godot-sdk-integrations.github.io/godot-google-play-billing).
- **Compliance:** Google requires Billing Library 8+ for new apps and updates by 2026-08-31 (extension to 2026-11-01), and v8 itself reaches its deadline on 2027-08-31 ([Billing deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq)). Plugin 3.3.0 (v9.1) meets that. Rubbley has to keep the plugin current, because the requirement moves up a version each year.
- Licence: MIT. It is hosted in the Godot Foundation's `godot-sdk-integrations` organization.

### Play Games Services: godot-play-game-services

- A "Godot 4.3+ plugin" for the current Play Games Services v2 SDK. The README badges show Godot 4.5, Android API 35 and play-services-games-v2 21.0.0 ([README](https://github.com/godot-sdk-integrations/godot-play-game-services)).
- Since 3.0 its features (sign-in, leaderboards, snapshots and so on) are exposed as Nodes, and the main `GodotPlayGamesServices` autoload needs manual initialization ([README](https://github.com/godot-sdk-integrations/godot-play-game-services)). Snapshots are the cloud-save mechanism, and v3.4.0 added a `snapshotDeleted` signal ([v3.4.0 release](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.4.0)).
- Its maintainer is Iakobs, and it moved into the Godot Foundation's organization in October 2024 ([README](https://github.com/godot-sdk-integrations/godot-play-game-services)). Licence: MIT. Latest release v3.4.0, 2026-07-20 (GitHub API).
- Both Play plugins are Android-only. Rubbley needs its own wrapper so desktop and iOS builds don't reference them.

## itch.io

- itch.io offers no achievements, leaderboards, cloud saves or IAP. Its server-side API covers purchases, download keys, ownership checks and credentials ([itch.io server-side API](https://itch.io/docs/api/serverside)). No Godot plugin is needed.
- butler is MIT-licensed and actively maintained, with v15.32.0 released 2026-10-06 ([itchio/butler](https://github.com/itchio/butler)) ([butler docs](https://itch.io/docs/butler/)).

## Epic Games Store (optional)

EOSG supports "Godot 4.2+" with EOS SDK 1.19.1.2 on Windows, Linux, Android, macOS and iOS. Its high-level GDScript classes include `HAuth`, `HAchievements`, `HStats` and `HLeaderboards`. It is not affiliated with Epic ([README](https://github.com/3ddelano/epic-online-services-godot)). Licence: MIT. Latest release 2.3.1, 2026-09-15 (GitHub API). This research found no Godot 4 integrations for GOG Galaxy or the Microsoft Store.

## CI submission from GitHub Actions

Runner cost: standard GitHub-hosted runners are free in public repositories, and `snackpackgames/Rubbley` is currently public. Private repos get 2,000 included minutes a month on GitHub Free. List prices are $0.006/min for Linux, $0.010 for Windows and $0.062 for macOS ([Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)). If the repo goes private, iOS jobs cost about 10 times as much per minute as Linux jobs.

### Steam (steamcmd / SteamPipe)

- An app build VDF lists `AppID`, `Desc`, `ContentRoot`, `BuildOutput` and per-depot scripts, and you run it with `+login <account> <password> +run_app_build` ([SteamPipe uploading](https://partner.steamgames.com/doc/sdk/uploading)).
- Use a dedicated build account with app permissions. Each password login can trigger Steam Guard. `SetLive` can push a build live on a beta branch automatically, but "the 'default' branch can not be set live automatically", so that step happens in the App Admin panel. Setting builds live on a released app also requires the account to have a phone or the Steam Mobile App ([SteamPipe uploading](https://partner.steamgames.com/doc/sdk/uploading)).
- `game-ci/steam-deploy` (MIT, v3.2.1, 2026-08-18) needs `username` and `password`, plus either `totp` (generated from a `STEAM_SHARED_SECRET`) or a base64 `configVdf` captured after an interactive steamcmd login. It also takes `appId`, `depotNPath` and `releaseBranch`. Its example runs on `ubuntu-latest` ([steam-deploy README](https://github.com/game-ci/steam-deploy)). With the `config.vdf` method, you regenerate the secret whenever Steam asks for a new code.

### App Store (fastlane)

- Godot itself requires macOS for this step: "You must export for iOS from a computer running macOS with Xcode installed" ([Godot 4.7 docs: exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)). The job therefore needs a `macos-*` runner.
- Use an App Store Connect API key (`key_id`, `issuer_id`, `.p8` contents) rather than an Apple ID, because it needs "No 2FA". The key works with `pilot` (TestFlight), `deliver` (App Store metadata and submission), `match`, `sigh` and `cert`. `produce` (creating the app record) and `pem` don't support it ([fastlane: App Store Connect API](https://docs.fastlane.tools/app-store-connect-api/)). Create the app record by hand once. The `.p8` file can't be downloaded again later, so store it as a secret straight away.
- Signing secrets come on top of that: a distribution certificate and provisioning profile, which `match` can manage ([fastlane: App Store Connect API](https://docs.fastlane.tools/app-store-connect-api/)). Mac App Store builds follow the same path. Notarized direct downloads are a separate flow that this research did not cover.

### Google Play (Play Developer API)

- Setup: create a Google Cloud project, enable the Google Play Developer API, create a service account, and invite its email in Play Console under Users & Permissions. Linking the developer account to a Cloud project is no longer needed ([Play Developer API getting started](https://developers.google.com/android-publisher/getting_started)).
- fastlane `supply` uses the service-account JSON key, which you can check with `fastlane run validate_play_store_json_key`. "You'll need to set up your app manually first by uploading at least one build to Google Play Store" ([fastlane supply](https://docs.fastlane.tools/actions/supply/)).
- `r0adkll/upload-google-play` (MIT, v1.1.5) takes `serviceAccountJsonPlainText` or `serviceAccountJson`, `packageName` (which "must already exist in the play console account"), `releaseFiles` (`.aab`/`.apk`), `tracks` and `status` (`completed`, `inProgress`, `halted` or `draft`). Before targeting production, at least one release has to go through an earlier track ([README](https://github.com/r0adkll/upload-google-play)). It also supports workload identity federation through `google-github-actions/auth`, which avoids storing a long-lived key.
- **Policy gate:** personal developer accounts created after 2023-11-13 must run a closed test with at least 12 testers, opted in continuously for 14 days, before they can apply for production access ([Play Console help](https://support.google.com/googleplay/android-developer/answer/14151465)). Plan this into the launch schedule.

### itch.io (butler)

- `butler push <dir> <user>/<game>:<channel>`. Channel names containing `windows`, `linux`, `mac`/`osx` or `android` set the platform tags. `--userversion` or `--userversion-file` sets your own version number. Only changed blocks are uploaded, and "As soon as the upload finishes, the build is live" ([butler: pushing](https://itch.io/docs/butler/pushing.html)).
- In CI, set the `BUTLER_API_KEY` environment variable to the key whose source is `wharf` on the API keys page ([butler: login](https://itch.io/docs/butler/login.html)). It runs on any runner, which makes it a good fit for playtest web and desktop builds.

## Implications for Rubbley

- All the main store services can be called from GDScript in stock Godot 4.7 through GDExtensions or Android v2 plugins, with no C#, C++ or custom engine build. The exception is godot-ios-plugins, which is build-from-source. Every integration listed here is MIT-licensed.
- None of them share an API. Rubbley needs one GDScript service interface for achievements, leaderboards, cloud saves and IAP, with a backend per store selected by feature tag or platform, plus a null backend for itch.io and web.
- Cloud saves: Steam Auto-Cloud (no code), Game Center saved games, and Play Games snapshots. Each has its own conflict model.
- CI: Linux runners cover Steam, Play and itch. iOS and Mac App Store builds need a macOS runner. Three steps stay manual: creating the App Store app record, the first Play upload with the 12-tester closed test, and setting Steam's default branch live.

## Open questions

- Is IAP in scope at all? The GDD would decide whether Play Billing and StoreKit are needed or only leaderboards and achievements.
- Does GodotApplePlugins' iOS 17 / macOS 14 minimum fit Rubbley's target OS versions?
- Is the Epic Games Store a launch target? If so, EOSG adds another backend.
