# The Playtest Build is public on GitHub Pages; web ships only as the itch.io Free Tier

Every merge to `main` deploys the Playtest Build (ADR 0011) to GitHub Pages at `snackpackgames.github.io/Rubbley/`, using `actions/upload-pages-artifact` and `actions/deploy-pages`. It is public and unlisted, with no password. The repo is public, so anyone can already export the Full Game, and a password would only add a step for every tester. GitHub Pages is the only free host that serves a stock Godot 4.7.2 web export publicly without listing it anywhere (see `research/playtest-web-hosting`). Web also ships in exactly one place: itch.io offers the Free Tier as a web build playable on the page, next to the native desktop downloads (ADRs 0001 and 0015, amended).

## Consequences

- **Finding it:** the Playtest Build URL goes in the README and the repo's About website field. Nothing outside the repo links to it.
- **Latest `main` only.** Each deploy replaces the last. There is no build history and no hosted PR preview. Each PR's web export artifact (ADR 0011) covers reviews, and old builds can be rebuilt from git.
- **Both web builds are single-threaded**, the 4.7 default. They need no cross-origin isolation headers and no service worker. Audio has to work without AudioEffects, reverb or doppler on web, or degrade gracefully there, and positional audio may be unreliable. If the audio design needs those on web, revisit before the itch.io Free Tier web build launches. Switching it to threads afterwards means itch.io's SharedArrayBuffer option, which moves the game to a new domain and strands every player's local saves.
- **Texture compression:** the `web-playtest` preset enables both desktop (S3TC/BPTC) and mobile (ETC2/ASTC) compression, because the Playtest Build is played on phones. The larger `.pck` is accepted.
- **The itch.io Free Tier web build supports desktop browsers only**, at the desktop floor (ADR 0010). itch.io's "Mobile Friendly" option stays off, so phone visitors get itch.io's warning, and the page points them to the App Store and Google Play. Phones get the Free Tier natively there, and every iOS browser inherits Safari's WebGL 2 problems.
- **Saves don't collide.** The Playtest Build lives on the `snackpackgames.github.io` origin and the Free Tier web build on itch.io's, so the shared `Rubbley` user dir (ADR 0019) never mixes the two in a tester's browser.
- **If the repo goes private,** GitHub Pages stops working on the org's GitHub Free plan. The Playtest Build then moves to a separate itch.io page set to Restricted with a password, pushed with butler. Gating makes sense once the source is private. That build needs its own user dir (such as `Rubbley Playtest`), because every classic itch.io HTML game shares the `html-classic.itch.zone` origin and would otherwise read the Free Tier's saves. Paying for GitHub Team keeps Pages instead.

## Considered Options

- **A Restricted itch.io page now:** rejected. It needs a password, which buys little while the repo is public. itch.io's docs also don't confirm that a password-protected page can run a browser build. A Public itch.io page would be listed in browse, next to the Free Tier.
- **Cloudflare Pages:** rejected. Its 25 MiB per-file cap is below the stock 37.7 MiB `godot.wasm`, so it would need a custom size-optimised engine template built in CI.
- **Netlify:** rejected. Password protection needs Pro ($20/month), and the free plan pauses every site after about 20 production deploys a month.
- **A threaded web build:** rejected. Without host headers it needs the PWA service worker, which has no cache busting, so testers could play a stale build after a merge.
