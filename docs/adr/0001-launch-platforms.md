# Launch on iOS, Android, Windows, macOS and Linux together; web for playtests only

Rubbley launches on iOS, Android, Windows, macOS and Linux at the same time, from one Godot project with no platform forks. The game is designed touch first, but all three control schemes count at launch: touch, controller, and mouse + keyboard. We considered mobile-only and desktop-first launches and chose a single launch because desktop and Steam Deck are where we playtest anyway. Web exports are required for playtests, demos and CI artifacts, but web is not a shipping platform. Consoles are out of scope: Godot has no official console export.

## Consequences

- Each first-class platform has a test device: an iOS phone, a low-end Android phone (Samsung Galaxy A16 5G, see `research/android-min-spec-phone`), Windows/macOS desktop, and Steam Deck for Linux.
- CI runs tests headless on desktop, does iOS export and signing on a macOS runner, and publishes a web export (itch.io or a downloadable HTML build) as an artifact.
- Web builds always use the Compatibility renderer.
