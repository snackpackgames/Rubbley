# Premium on Steam and Epic, a Free Tier with one Unlock on mobile and itch.io, platform-native store services

On desktop, Rubbley sells the Full Game as a premium title on Steam (Windows, macOS and Linux) and the Epic Games Store (Windows and macOS). itch.io carries only the Free Tier, a permanent demo with no Unlock, and links to Steam and Epic. On mobile, the App Store and Google Play offer a free download of the Free Tier plus a single non-consumable Unlock IAP that turns it into the Full Game, with Restore Purchases on both stores. There are no other IAPs. Leaderboards, achievements and cloud saves use each platform's own service, not a cross-platform backend of ours. That keeps the launch to existing plugins and no server. The cost is that scores and saves stay inside each store.

## Considered Options

- **Premium everywhere:** rejected for mobile, because paid-upfront games sell poorly there.
- **Free-to-play (consumables, ads):** rejected. It would pull the design toward monetisation and need an ad SDK and consent flows on day one.
- **One cross-platform leaderboard owned by the game:** rejected. It needs a backend and accounts, and we'd own it forever. Platform leaderboards are free and already in the plugins (see `research/godot-storefront-integrations`).
- **Cross-platform save sync:** rejected for the same reason.
- **Mac App Store, other Android stores, EU alternative iOS marketplaces:** not launch targets. Steam and Epic already cover macOS.

## Consequences

- **Four store backends:** Steam (GodotSteam), Epic (EOSG), Apple (GodotApplePlugins: Game Center, StoreKit 2, iCloud) and Google Play (Play Billing plus Play Games Services). itch.io and web need none. The store integration only answers "is the Full Game unlocked?" plus achievements, leaderboards and cloud saves. How they plug in is [ADR 0019](0019-platform-services-store-seam.md).
- **Epic is Windows and macOS only.** Epic's docs show no way to publish Linux builds, and its cloud saves cover only Windows and macOS. Linux and Steam Deck players buy on Steam. Revisit if Epic opens Linux publishing.
- **Epic achievements need EOS code.** Epic requires achievements on EGS when the game has them on another PC store, and EGS achievements are built on EOS achievements, so the Epic backend uses EOSG for them ([Epic achievements](https://dev.epicgames.com/docs/epic-games-store/services/epic-achievements/overview)). macOS builds are exempt.
- **The Free Tier gate ships at launch** in the mobile and itch.io builds. It is one rule in game data: a set of always-free levels, and nothing else is gated. How many levels are free is a design decision for a later map. A Steam or Epic demo can reuse the gate later.
- **Ads are not shipped, but stay possible.** If revenue needs them, ads appear only in the mobile Free Tier and the Unlock also removes them. The ad SDK, ATT/GDPR consent and privacy disclosures come in only then.
- **The `main` web playtest build (ADR 0011) is always the Full Game.** It never ships, so there is nothing to gate.
- **No platform leaderboard on itch.io and web.** The end-of-level screen shows a local best score there, and the online board hides whenever no backend is available. Scores are compared per store, never across stores.
- **Cloud saves:** Steam Auto-Cloud, Epic cloud saves, iCloud/Game Center saved games on Apple, and Play Games snapshots on Android. itch.io and web saves stay local. Epic cloud saves are set up in the Developer Portal and synced by the launcher, with no game code ([Epic cloud save](https://dev.epicgames.com/docs/epic-games-store/services/cloud-save)).
- **Google Play account:** it is registered as an organisation account once the Snackpack Games LLC exists, which comes before the D-U-N-S number. If there is still no LLC close to release, fall back to a personal account. That puts Play's mandatory closed test (12 testers for 14 days) on the release path as a gate.
- **Signing and CI:** the App Store build needs a macOS runner and signing secrets. Steam, Play and itch.io uploads run on Linux. Epic's upload tooling has not been checked yet.
