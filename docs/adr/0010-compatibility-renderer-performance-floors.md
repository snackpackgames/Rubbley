# Compatibility renderer on every platform; support floors set by performance

Rubbley uses Godot's Compatibility renderer on every platform: iOS, Android, Windows, macOS, Linux and web. Web builds can only use Compatibility, and web is where we playtest (ADR 0001), so one renderer everywhere means playtests show exactly what ships, and there is one shader and lighting path to test. Compatibility is also the fastest renderer on low-end phones and sidesteps the Vulkan driver bugs on Mali GPUs. Nothing planned needs Mobile's features (toon materials, a procedural starfield, unshaded Floating Face quads).

Support is defined by performance, not OS version. The **Minimum-Spec Device** for Android is the Samsung Galaxy A16 5G (Exynos 1330, Mali-G68, 4 GB): it must hold a steady 60 fps through a level's heaviest moments. Any device Godot 4.7's default Android min SDK allows can install the game, but only the Minimum-Spec Device's class and above are supported, and nothing is excluded at launch.

| Platform | Minimum | Reference device / bar |
|---|---|---|
| Android | Godot 4.7 default min SDK | Galaxy A16 5G, 60 fps |
| iOS | iOS 17 | iPhone SE (2nd gen), 60 fps |
| macOS | macOS 14, universal (Apple Silicon + Intel) | 60 fps at 1080p |
| Windows | Windows 10/11, x86_64 | Intel UHD 620-class iGPU, 60 fps at 1080p |
| Linux | x86_64 | Steam Deck, 60 fps at native 800p |

The Apple minimums are set by GodotApplePlugins (Game Center, StoreKit 2, iCloud), which needs iOS 17 / macOS 14, so the storefront decision can use it without raising the floor. There are no arm64 builds for Windows or Linux at launch.

Rendering runs at the display's refresh rate with vsync and physics interpolation. Physics stays at a fixed 60 Hz, and 60 fps is the guaranteed minimum.

## Considered Options

- **Mobile on phones and desktop, Compatibility on web**: rejected. Playtests would stop showing the shipped look, and every visual change would need checking on two renderers.
- **Mobile on phones, Forward+ on desktop, Compatibility on web**: rejected. Three render paths for a toon game that uses none of Forward+'s features.
- **An OS-version floor (e.g. Android 9 for Vulkan)**: rejected. Compatibility doesn't need Vulkan, and the floor that matters is whether the game holds 60 fps, which only a device can show.

## Consequences

- We give up RGBA16F colour (Compatibility renders RGBA8), SSR, SDFGI, volumetric fog and some post effects. If the art-direction map needs any of them, it reopens this ADR. Godot's docs warn that moving from Compatibility to Mobile takes more scene and lighting rework than Mobile to Forward+.
- The N-body benchmark runs on Compatibility against the 60 fps bar on the Minimum-Spec Device.
- Android 15 caps games at 60 fps on 120 Hz screens (godot#104179), so on phones the display-rate rendering mostly matters for iPads and desktops.
