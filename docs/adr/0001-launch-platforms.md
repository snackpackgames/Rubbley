# Launch on iOS, Android, Windows, macOS and Linux together; web ships only as the itch.io Free Tier

Rubbley launches on iOS, Android, Windows, macOS and Linux at the same time, from one Godot project with no platform forks. The game is designed touch first, but all three control schemes count at launch: touch, controller, and mouse + keyboard. We considered mobile-only and desktop-first launches and chose a single launch because desktop and Steam Deck are where we playtest anyway. Web exports are required for playtests and CI artifacts. Web ships in exactly one place, the itch.io Free Tier web build, supported on desktop browsers only ([ADR 0020](0020-playtest-build-on-github-pages.md)). Consoles are out of scope: Godot has no official console export.

## Consequences

- Each first-class platform has a test device: an iOS phone, a low-end Android phone (Samsung Galaxy A16 5G, see `research/android-min-spec-phone`), Windows/macOS desktop, and Steam Deck for Linux.
- CI runs tests headless on desktop, does iOS export and signing on a macOS runner, and publishes a web export as an artifact. The `main` Playtest Build is hosted on GitHub Pages ([ADR 0020](0020-playtest-build-on-github-pages.md)).
- Web builds always use the Compatibility renderer.
