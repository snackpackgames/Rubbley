# State of Godot 4.x for Rubbley (as of 2026-10-11)

Research for [#22](https://github.com/snackpackgames/Rubbley/issues/22), part of map #20 (Unity to Godot migration).
Rubbley's needs: a touch-first 2.5D top-down physics game, mobile first, desktop second, web optional, with mostly agent-written code.

## Summary

- **The current stable release is Godot 4.7.2**, released 2026-08-18. 4.7 shipped on 2026-06-18, and 4.8 is in dev snapshots (4.8-dev7, 2026-09-29). [1]
- **C#**: you can export to Android and iOS, but the docs still call both "experimental". You **cannot export C# to the web**. The web PR is still a draft with no committed release. [2][3][4]
- **Physics**: Jolt has been the default 3D engine for new projects since 4.6. It is 3D only. Godot says physics "is not deterministic" whichever engine you use, and Godot does not build Jolt in its cross-platform-deterministic mode. [5][6][7][8]
- **Renderers**: Mobile is the default on mobile and Compatibility is the default (and the only option) on web. Forward+ is "desktop only". Mobile runs *slower* than Compatibility on old or low-end hardware. [9]
- **Mobile blockers**: none of the open issues found would block the game outright. Some do matter: C# on mobile is still experimental, Android 15 caps the frame rate at 60 fps on 120 Hz screens (#104179), there are Vulkan glitches on some Android GPUs, and some C#/iOS signing and NativeAOT issues are open. [10]

## 1. Current stable release

From the official download archive [1]:

| Version | Date | Type |
|---|---|---|
| 4.8-dev7 | 2026-09-29 | pre-release |
| 4.7.2-stable | 2026-08-18 | **latest stable** |
| 4.7.1-stable | 2026-07-14 | stable |
| 4.7-stable | 2026-06-18 | stable |

What 4.7 changes for Rubbley [11]:
- A built-in **VirtualJoystick** node, with Fixed, Dynamic and Following modes and theming support. This is directly useful for touch controls.
- The **Mobile renderer** "now matches or outperforms Compatibility in some benchmarks".
- Controller support on iOS now goes through SDL3, as it does on desktop.
- The Android editor can now export and publish projects (GABE companion).

What 4.6 changes for Rubbley [7]:
- Jolt became the default 3D physics engine for new projects.
- Fixes for "a series of crashes affecting devices with certain Mali and Adreno mobile GPUs" in the Vulkan Mobile renderer.
- Direct3D 12 became the default on Windows.

## 2. C# / .NET export

The official docs, version 4.7 [2][3]:

> Since Godot 4.2, projects written in C# support all desktop platforms (Windows, Linux, and macOS), as well as Android and iOS.
> Android support is currently experimental.
> iOS support is currently experimental and has a few limitations. [The iOS simulator template is x64 only; exporting to iOS requires macOS.]
> Currently, projects written in C# cannot be exported to the web platform. To use C# on that platform, consider Godot 3 instead.

- **.NET version**: "Godot 4.5 requires .NET 8 or later, but exporting to Android requires .NET 9 or later." The 4.7 C# basics page still says this. [3]
- **C# needs the separate .NET build of the editor.** The standard build cannot compile C#. [3]
- **Web**: the PR [godotengine/godot#106125](https://github.com/godotengine/godot/pull/106125) "[.NET] Add web export support" is a **draft**, milestone `4.x`, last updated 2026-09-14. [4] The PR description lists these limits:
  - The Mono runtime is statically linked.
  - Globalization is forced into invariant mode.
  - Some BCL APIs, such as crypto, don't work.
  - You have to patch the exported `.js` by hand.
  - The demo needs WASM threads.

  The 2025 blog post on the prototype says the team "cannot commit to a specific timeline yet". [12]
- **Open C# mobile issues** (sample) [10]:
  - NuGet native libraries are not bundled on Android (#97859).
  - A 4.6 Android crash at initialization (#115678).
  - A code-signing identifier mismatch on iOS (#116165).
  - Node instantiation fails under NativeAOT in iOS release exports (#96072).

**Implication**: picking C# means giving up the web target. Mobile would depend on export paths that are still labelled experimental. GDScript has neither problem.

## 3. Physics: Jolt vs Godot Physics

- **Jolt has been the default** for new 3D projects since 4.6. It no longer carries the experimental label, and existing projects keep their current setting. [6][7]
- **Jolt is 3D only.** 2D physics is still Godot Physics 2D. The Jolt docs cover only the 3D nodes (`RigidBody3D`, `Area3D` and so on). [6] For Rubbley this depends on a later decision: does "2.5D" mean 3D physics on a plane, or 2D physics with 3D visuals? Only the 3D route can use Jolt.
- **How Jolt differs from Godot Physics** [6]:
  - Many joint soft-limit properties are unsupported.
  - Single-body joints attach to `node_b`.
  - Shapes are shrunk before the margin is applied.
  - Baumgarte stabilization is position-only, so there is no overshoot, but penetration resolves more slowly.
  - Contact impulses are estimates.
  - Contact reporting for kinematic bodies is opt-in.
  - `WorldBoundaryShape3D` has a smaller effective size.
  - Thread safety and running physics on a separate thread are experimental.
- **Determinism**:
  - Godot docs: "Physics in Godot, regardless of physics engine, is not deterministic." [8]
  - Upstream Jolt is deterministic on the same binary and platform if API calls happen in the same order. Cross-platform determinism needs the `CROSS_PLATFORM_DETERMINISTIC` build option (about 8% slower), precise floating-point flags and other conditions. Even then, broadphase queries and callback order are not deterministic. [13]
  - Godot's Jolt build script (`modules/jolt_physics/SCsub`, 4.7 branch) defines only `JPH_ENABLE_ASSERTS`, `JPH_DEBUG_RENDERER` and `JPH_DOUBLE_PRECISION`, each under a condition. It does **not** set cross-platform determinism. [5]
  - Conclusion: don't design features that need determinism (replays, lockstep, puzzle solutions verified by re-simulation) on top of the engine's physics.
- **Mobile performance**: no official Jolt-vs-Godot-Physics benchmark for mobile exists. The Jolt docs page does not mention mobile at all. [6] We would have to measure it ourselves.
- **Tick rate**: physics runs at a fixed 60 Hz by default. [8] Physics interpolation smooths rendering when the display refreshes faster than the physics tick. [14]

## 4. Renderers

From the official renderers page [9]:

| | Forward+ | Mobile | Compatibility |
|---|---|---|---|
| Target | Desktop only | Mobile and desktop | Low-end desktop, mobile, web |
| API | Vulkan / D3D12 / Metal | Vulkan / D3D12 / Metal | OpenGL (ES 3 / WebGL 2) |
| Default on | Desktop | Mobile | Web (only option) |
| Lights per mesh | 512 per cluster | 8 per mesh, 256 per view | 8 per mesh |
| Color precision | RGBA16F | RGB10A2 | RGBA8 |

- **Feature differences**:
  - Forward+ only: SDFGI, VoxelGI, SSR, volumetric fog, TAA and FSR2.
  - SSAO: Compatibility and Forward+, but not Mobile.
  - MSAA 3D: all three renderers.
- **On mobile hardware**:
  - Forward+ is "poorly optimized" on mobile.
  - Mobile needs Vulkan, D3D12 or Metal hardware, and on old or low-end hardware it runs slower than Compatibility.
  - Compatibility supports the widest range of hardware.
  - Since 4.4, if no RenderingDevice backend is available, the engine falls back to Compatibility automatically. You can turn this off.
- **Switching renderers**: going from Compatibility to Mobile takes more scene and lighting rework than going from Mobile to Forward+. [9]
- **Minimum specs** for exported mobile games [15]:
  - Android 7.0 with OpenGL ES 3.0 for Compatibility.
  - Android 9.0 with Vulkan 1.0 for Mobile and Forward+.
  - iOS 12 (Vulkan via MoltenVK) or iOS 16 (Metal 3).
  - Recommended: Vulkan 1.2 or OpenGL ES 3.2, and 2 GB RAM (4 GB for web).
  - The docs say: "It is strongly recommended to do your own testing on low-end hardware." They do not define "mid-range".
- **Toon shader**: a toon look (the Unity prototype has one) needs neither GI nor SSR. Mobile or Compatibility should both work, and Compatibility is the only option if web is a target.

## 5. Known issues for a touch-first mobile physics game

None of the open issues found would stop the game from shipping. These are the risks to keep track of:

- **Touch input**:
  - `InputEventScreenTouch` and `InputEventScreenDrag` support multi-touch. [16]
  - Gesture events (magnify, pan) exist.
  - Mouse/touch emulation settings affect how GUI controls behave (#39101).
  - `InputEventPanGesture` deltas differ between screens (#83743). [10]
  - Gestures should be built from raw touch events rather than relying on emulation.
- **Frame rate**: Android 15 caps the frame rate at 60 fps on 120 Hz screens (#104179, open, updated 2026-08). [10]
- **Rendering**:
  - Vulkan glitches appear on some Android devices (#115217, #73384).
  - Low-end Android devices freeze for several seconds while adding 3D scenes in Compatibility (#102665).
  - 4.6 fixed several Mali and Adreno crashes. [7][10]
- **C# on mobile**: experimental, with the open issues listed in section 2.
- **Physics determinism**: not available (section 3).

## Open questions this raises (candidate decision tickets)

1. GDScript or C#? Both the web target and the experimental mobile status point toward GDScript. Also weigh how good agents are at writing each language.
2. Is 2.5D built on 3D physics (Jolt available) or 2D physics with 3D visuals?
3. Mobile or Compatibility renderer? This depends on the minimum device spec and whether web stays in scope.
4. What is the minimum supported device (Android/iOS version, GPU class)?
5. Does any design feature need deterministic physics (replays, ghost runs, puzzle verification)?
6. Pin a version: 4.7.x stable now, or wait for 4.8?

## Sources

1. Godot download archive: https://godotengine.org/download/archive/
2. C# docs index, "C# platform support" (4.7): https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html; source: https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/c_sharp/index.rst
3. C# basics (4.7): https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html
4. PR "[.NET] Add web export support": https://github.com/godotengine/godot/pull/106125
5. Godot Jolt module build script (4.7): https://github.com/godotengine/godot/blob/4.7/modules/jolt_physics/SCsub
6. Using Jolt Physics (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html
7. Godot 4.6 release page: https://godotengine.org/releases/4.6/
8. Physics introduction (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
9. Overview of renderers (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
10. godotengine/godot issues: #104179, #115217, #73384, #102665, #39101, #83743, #97859, #115678, #116165, #96072 (searched 2026-10-11)
11. Godot 4.7 release page: https://godotengine.org/releases/4.7/
12. "Live from GodotCon Boston: Web .NET prototype": https://godotengine.org/article/live-from-godotcon-boston-web-dotnet-prototype/
13. Jolt Physics docs, determinism section: https://jrouwe.github.io/JoltPhysics/index.html
14. Physics interpolation intro (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html
15. System requirements (4.7 docs): https://docs.godotengine.org/en/stable/about/system_requirements.html
16. Using InputEvent (4.7 docs): https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
