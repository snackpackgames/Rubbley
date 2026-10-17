# Godot 4 input options for Rubbley: touch gestures, controller, mouse + keyboard

Research for [#27](https://github.com/snackpackgames/Rubbley/issues/27), part of map #20 (Unity to Godot migration). Researched 2026-10-11 against Godot **4.7** docs (`/en/stable/` currently serves 4.7; latest release is `4.7.2-stable`, 2026-08-18) and the `godotengine/godot` master source.

## Short answer

- **Raw multi-touch is native and complete on every platform.** `InputEventScreenTouch` and `InputEventScreenDrag` give per-finger index, position, velocity and press/release/cancel. Everything Rubbley needs can be built on these two events.
- **Native gesture events cover very little, and not uniformly.** `InputEventMagnifyGesture` (pinch) and `InputEventPanGesture` (two-finger pan) are emitted only by Android (opt-in setting), macOS trackpads and Linux Wayland touchpads. iOS, Web and Windows touch never emit them. Rubbley can't rely on them for a touch-first game.
- **No native swipe, flick, rub, tap or long-press recogniser exists.** Godot 4.7 added a `VirtualJoystick` node with a `flicked` signal, but that's an on-screen stick, not a free-form gesture.
- **Controller and M+KB are fully native** through `InputMap` actions. Triggers are analog axes (`get_action_strength`), sticks use `get_vector` with a circular deadzone, and alt+drag and left/right click are plain events. Desktop joypads use SDL3 since 4.5.
- **Runtime scheme switching has no built-in "active device" API.** You infer it from the type and `device` of the last event. Addons wrap this.
- **Addons:** G.U.I.D.E is actively maintained (v0.14.0, Jul 2026). It unifies touch, mouse, key and joy behind actions and contexts, and has touch-distance, angle and axis inputs plus a virtual-cursor modifier. Input Helper (v4.7.0, Jun 2025) handles device detection and remapping only, with no touch gestures. Godot Touch Input Manager has the richest gesture set (swipe, pinch, twist, multi-drag) but has been dormant since 2024 (last release May 2023).
- **Rubbley needs custom recognisers for:** pinch-in vs pinch-out including pinch-and-hold on a target, rub, flick-out-from-Rubbley, swipe, tap-to-aim (tap vs drag thresholds), two-finger camera drag (disambiguated from pinch), and controller button-mash and spacebar-mash for Spin.

## GDD inputs this has to satisfy

From [`docs/gdd/rubbley-gdd.md`](../gdd/rubbley-gdd.md), the Moveset and Controls sections:

| Action | Touch | Controller | Mouse + keyboard |
|---|---|---|---|
| Attract | pinch-in; pinch-and-hold on Rubbley or a body; place well at pinch centre | trigger | left click |
| Repel | pinch-out; flick-out on Rubbley = stun pulse | trigger | right click |
| Spin | "rub on Rubbley" (Controls); "swipe in any direction" (Spin section) | mash face buttons | mash spacebar |
| Aim (secondary cursor) | tap to place | left stick moves cursor | mouse position |
| Camera nudge | multi-touch drag | right stick | Alt + drag |

**GDD inconsistency:** the Description says "swipe to spin, hold to attract, rub to repel". Controls says rub = Spin and pinch-out = Repel. The Spin section says swipe = Spin. The touch recogniser set depends on which one is right (see "Open questions").

## Native touch

### Raw events (all platforms)

- `InputEventScreenTouch`: `index` ("One index = one finger"), `position`, `pressed`, `canceled`, `double_tap`. [class ref](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html)
- `InputEventScreenDrag`: `index`, `position`, `relative`, `velocity`, plus `screen_relative` and `screen_velocity` (unscaled). The docs say `screen_relative` "should be preferred over relative for touch aiming regardless of the project's stretch mode". It also has `pressure`, `tilt` and `pen_inverted`. [class ref](https://docs.godotengine.org/en/stable/classes/class_inputeventscreendrag.html)

A recogniser tracks a `Dictionary` of index to state from these events. `screen_velocity` gives swipe and flick speed directly, so you don't need to differentiate positions yourself.

### Native gesture events (limited platforms)

- `InputEventMagnifyGesture.factor` (pinch) and `InputEventPanGesture.delta` (two-finger pan) both extend `InputEventGesture`. On Android they need `input_devices/pointing/android/enable_pan_and_scale_gestures` (default `false`). [Magnify](https://docs.godotengine.org/en/stable/classes/class_inputeventmagnifygesture.html), [Pan](https://docs.godotengine.org/en/stable/classes/class_inputeventpangesture.html), [ProjectSettings.xml](https://github.com/godotengine/godot/blob/master/doc/classes/ProjectSettings.xml)
- A source search of `godotengine/godot` for code that constructs these events found them only in `platform/android/android_input_handler.cpp`, `platform/macos/godot_content_view.mm` (trackpad) and `platform/linuxbsd/wayland/wayland_thread.cpp` (touchpad gestures). No iOS, Web or Windows platform code emits them.
- On Android, `GodotGestureHandler.kt` wraps `ScaleGestureDetector`. It drops scale events while a one-finger drag is in progress, and it clamps each event to a factor between 0.8 and 1.2. Pan is sent only for 2+ pointers. [source](https://github.com/godotengine/godot/blob/master/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotGestureHandler.kt)

**Implication:** a Rubbley pinch built on `MagnifyGesture` would work on Android and Mac trackpads and do nothing on iPhone or iPad. Build pinch from raw touches.

### Other native touch pieces

- `VirtualJoystick` (new in 4.7; absent from the 4.5 and 4.6 docs) is a Control with Fixed, Dynamic and Following modes, writes to actions, and has `pressed`, `released(input_vector)`, `flicked(input_vector)`, `flick_canceled` and `tapped` signals. It could serve as an optional touch-accessibility scheme, but it isn't the GDD's gesture model. [class ref](https://docs.godotengine.org/en/stable/classes/class_virtualjoystick.html)
- `TouchScreenButton` is an on-screen button that maps to an action. [class ref](https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html)
- Emulation settings:
  - `input_devices/pointing/emulate_mouse_from_touch` (default **true**): "sends mouse input events when tapping or swiping on the touchscreen".
  - `emulate_touch_from_mouse` (default false): "sends touch input events when clicking or dragging the mouse".
  - Emulated events carry `device == InputEvent.DEVICE_ID_EMULATION` (-1), so code can tell them apart from real mouse or touch. [InputEvent.xml](https://github.com/godotengine/godot/blob/master/doc/classes/InputEvent.xml)
  - Rubbley has separate touch and M+KB schemes, so either turn mouse-from-touch off or filter `DEVICE_ID_EMULATION`. Otherwise one tap counts as both a touch aim and a left-click Attract.
  - `emulate_touch_from_mouse` lets one-finger gestures be tested on desktop, but not two-finger ones.
- `input_devices/pointing/android/enable_long_press_as_right_click` (default false) should stay off.

## Native controller

From the [Controllers, gamepads and joysticks](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) tutorial and the [Input class ref](https://docs.godotengine.org/en/stable/classes/class_input.html):

- **Triggers** are analog axes (`JOY_AXIS_TRIGGER_LEFT/RIGHT`). Bind them to `attract`/`repel` actions and read `Input.get_action_strength()` (0 to 1, past the deadzone). The tutorial recommends exactly this "for handling a trigger".
- **Sticks:** `Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone)` returns a vector capped at length 1 with a circular deadzone. The tutorial says it handles deadzones "in a correct way for most use cases". The tutorial gives the default action deadzone as 0.5 (Input Map tab). `InputMap.add_action()` defaults to 0.2.
- **Secondary cursor from the left stick:** there's no native virtual-cursor node, so integrate the `get_vector` output into a cursor position each frame. That's a few lines of code. G.U.I.D.E ships one as `GUIDEModifierVirtualCursor`.
- **Face-button mashing:** there's no native "mash" detector. Count `is_action_just_pressed("spin")` within a time window. Holding a button doesn't auto-repeat ("will **not** generate repeated input events"), so held buttons won't false-trigger a mash.
- **Backend:** desktop uses SDL3 since 4.5 (input only), with mappings from the SDL DB plus `godotcontrollerdb.txt`. Custom mappings go through `Input.add_joy_mapping()`. Windows supports at most 4 controllers (XInput). Android uses a custom implementation. Web quality "tends to vary wildly across browsers".
- **Extras:** vibration (`start_joy_vibration`; macOS needs 11+), hotplug (`joy_connection_changed`), `get_joy_name`/`get_joy_info`, and newer joypad motion-sensor and LED APIs (Windows, Linux, macOS, iOS). `ignore_joypad_on_unfocused_application` is available.

## Native mouse + keyboard

- Left and right click are `InputEventMouseButton` with `MOUSE_BUTTON_LEFT/RIGHT`, bound to the same `attract`/`repel` actions as the triggers.
- For the cursor, use the mouse position (`get_viewport().get_mouse_position()`, or `InputEventMouseMotion.position`).
- Alt + drag: `InputEventMouseMotion` with `alt_pressed` (inherited from `InputEventWithModifiers`), using `relative`/`screen_relative` for the camera nudge.
- Spacebar mash uses the same counter as face-button mash, bound to one `spin_mash` action.
- `Input.warp_mouse` works only on Windows, macOS and Linux ("no effect on Android, iOS and Web"). This matters only if the cursor ever needs re-centring.

## Switching schemes at runtime

- **Native:** there is no "current device" property. The usual pattern is a global `_input(event)` that classifies by event class and `device`:
  - `InputEventScreenTouch/Drag` means touch.
  - `InputEventJoypadButton`, or `InputEventJoypadMotion` above a deadzone, means controller.
  - `InputEventKey` or `InputEventMouse*` with `device != DEVICE_ID_EMULATION` means M+KB.

  On a change, emit a signal so the UI swaps prompts and the aim cursor swaps driver. `joy_connection_changed` covers hotplug.
- **One action set across schemes:** `InputMap` lets one action hold several events (trigger, mouse button, key). That covers controller and M+KB together. Touch gestures don't map to `InputMap` events, so the touch recogniser has to feed the same actions. `Input.action_press/action_release` or `Input.parse_input_event(InputEventAction)` do this. Gameplay code then reads only actions.
- **Addons:**
  - **Input Helper** (`nathanhoad/godot_input_helper`, MIT, v4.7.0, Jun 2025): `device_changed(device, index)` signal with keyboard and per-brand controller identifiers, `guess_device_name()`, runtime remapping and rumble. It has no touch gestures. [repo](https://github.com/nathanhoad/godot_input_helper), [Devices.md](https://github.com/nathanhoad/godot_input_helper/blob/main/docs/Devices.md)
  - **G.U.I.D.E**: mapping contexts can be enabled and disabled at runtime, with prompts and icons that follow the device in use (see below).

## Addons for gestures and unified input

| Addon | Status | Gestures / features relevant to Rubbley | Fit |
|---|---|---|---|
| [G.U.I.D.E](https://github.com/godotneers/G.U.I.D.E) (godotneers) | MIT; v0.14.0 (2026-07-14), pushed 2026-10-07; README warns it "hasn't seen a lot of use yet". [docs](https://godotneers.github.io/G.U.I.D.E/) | Inputs: `TouchPosition`, `TouchAxis1D/2D`, `TouchDistance` (pinch as distance change), `TouchAngle` (twist), joy and mouse axes, keys. Triggers: Tap, Hold, Pressed, Released, Pulse, Chorded, Combo, Stability. Modifiers: Deadzone, VirtualCursor, Canvas/3D coordinates, Curve, Scale. Contexts, rebinding, device-aware prompts. | Best match for one action layer across all three schemes. Pinch-distance and multi-finger axes cover pinch and camera-drag building blocks. Rub, flick-out-on-Rubbley and mash still need custom code (possibly as custom GUIDE triggers). Pre-1.0. |
| [Godot Touch Input Manager](https://github.com/Federico-Ciuffardi/GodotTouchInputManager) | MIT; 595 stars; last release `4.x-v2.1.2` (2023-05-02); last code commit 2024-03-16 | Autoload that emits custom events and signals: single and multi tap, long press, drag, swipe, pinch, twist, raw gesture. Mouse emulation of gestures for desktop testing. | Most gestures, but dormant. Useful as a reference implementation; risky as a dependency. |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | MIT; v4.7.0 (2025-06-08) | Device detection, remapping, rumble | Scheme switching only |
| [Controller Icons](https://github.com/rsubtil/controller_icons) | MIT; v3.1.8 (2026-07-28) | Device-aware button prompts | UI prompts only; G.U.I.D.E overlaps |

## Gesture-by-gesture verdict

| GDD gesture | Native? | Addon? | Needs a custom recogniser because... |
|---|---|---|---|
| Tap to aim | Raw touch only | GTIM `single_tap`, GUIDE Tap trigger | Tap vs drag vs pinch-start thresholds (time, distance) need tuning so a tap doesn't fire while a second finger is landing. Small. |
| Pinch-in / pinch-out (Attract / Repel) | `MagnifyGesture` on Android, macOS, Wayland only | GTIM `pinch`, GUIDE `TouchDistance` | Cross-platform support requires raw-touch pinch. The GDD also needs the pinch **centre** (well placement), a **target hit-test** at the start, **hold** (continuous drain) and in/out direction committed early. **Custom.** |
| Flick out on Rubbley (Repel stun pulse) | No | GTIM swipe (no origin constraint) | The touch must start on Rubbley's screen area and release fast outward, distinct from swipe-to-Spin. **Custom.** |
| Swipe (Spin, per Spin section) | No | GTIM `single_swipe` | Direction feeds the shield direction. Simple velocity threshold on release. **Custom** but small. |
| Rub on Rubbley (Spin, per Controls) | No | None | Count direction reversals of one finger within a radius of Rubbley within a time window. **Custom**, and no prior art in either addon. |
| Multi-touch drag (camera nudge) | `PanGesture` on Android, macOS, Wayland only | GTIM `multi_drag`, GUIDE `TouchAxis2D` | It has to be disambiguated from pinch, since both use two fingers: centroid translation vs inter-finger distance change. **Custom** arbitration. |
| Triggers (Attract / Repel) | Yes (`get_action_strength`) | n/a | No |
| Left-stick secondary cursor | Stick yes; cursor no | GUIDE VirtualCursor | Small integration |
| Right-stick camera nudge | Yes (`get_vector`) | n/a | No |
| Mash face buttons / spacebar | Presses yes; mash no | GUIDE Pulse/Combo are not mash | Small press-rate counter |
| L/R click, mouse aim, Alt+drag | Yes | n/a | No |

## Open questions (candidate decision tickets)

1. **Touch gesture mapping is contradictory in the GDD.** Is Spin rub or swipe? Is Repel pinch-out, rub, or flick-out? The designer needs to settle this before recognisers are built.
2. **Two-finger arbitration:** how pinch (Attract/Repel), two-finger camera drag and pinch-and-hold-on-target coexist. This also covers whether Spin and gestures can run at the same time (stamina rules).
3. **Input architecture:** plain `InputMap` plus a hand-rolled touch recogniser autoload, or G.U.I.D.E (pre-1.0, single maintainer) as the unified action layer. This is ADR-worthy and depends on the engine-version and language tickets on map #20.
4. **Target platforms for touch:** if iOS or Web are in scope, native gesture events are out entirely. If only Android, they're usable but still clamped and suppressed during drags.
5. **Accessibility / alternative touch scheme:** whether to offer `VirtualJoystick` / `TouchScreenButton` controls alongside gestures.
6. **Aim-cursor semantics across schemes:** whether the touch tap-placed cursor persists, and whether the controller cursor is clamped to the screen or to a radius around Rubbley.

## Sources

- Godot 4.7 class reference: [InputEventScreenTouch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html), [InputEventScreenDrag](https://docs.godotengine.org/en/stable/classes/class_inputeventscreendrag.html), [InputEventMagnifyGesture](https://docs.godotengine.org/en/stable/classes/class_inputeventmagnifygesture.html), [InputEventPanGesture](https://docs.godotengine.org/en/stable/classes/class_inputeventpangesture.html), [Input](https://docs.godotengine.org/en/stable/classes/class_input.html), [VirtualJoystick](https://docs.godotengine.org/en/stable/classes/class_virtualjoystick.html), [TouchScreenButton](https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html)
- Godot tutorial: [Controllers, gamepads, and joysticks](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html)
- Godot source (master): [ProjectSettings.xml](https://github.com/godotengine/godot/blob/master/doc/classes/ProjectSettings.xml), [InputEvent.xml](https://github.com/godotengine/godot/blob/master/doc/classes/InputEvent.xml), [InputMap.xml](https://github.com/godotengine/godot/blob/master/doc/classes/InputMap.xml), [GodotGestureHandler.kt](https://github.com/godotengine/godot/blob/master/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotGestureHandler.kt); GitHub code search for `InputEventMagnifyGesture` and `InputEventPanGesture` in `godotengine/godot`
- Addon repos (stars, releases and push dates read via GitHub API on 2026-10-11): [G.U.I.D.E](https://github.com/godotneers/G.U.I.D.E), [GodotTouchInputManager](https://github.com/Federico-Ciuffardi/GodotTouchInputManager), [godot_input_helper](https://github.com/nathanhoad/godot_input_helper), [controller_icons](https://github.com/rsubtil/controller_icons)
