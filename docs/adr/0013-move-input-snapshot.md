# Gameplay reads one device-agnostic Move Input frame per tick

All three control schemes feed one autoload, Move Input, which once per physics tick produces a frame with the following fields. Gameplay and the CameraRig read only that frame and never see a device.

- **Attract**: pressed, held or released
- **Repel fired** and **Spin fired**
- **Aim**: a world point on the Play Plane
- **Nudge**: a vector of length ≤ 1

Bindings for controller and keyboard are named actions in Godot's native `InputMap`. The touch recognisers are hand-rolled. A polled frame keeps every scheme on the same path through gameplay, and tests can inject frames without faking devices.

## Considered Options

- **G.U.I.D.E for every scheme**: rejected. It's pre-1.0, and it can't classify a two-finger gesture early and lock it until lift, or recognise a one-finger swipe. We'd write the hard touch recognisers anyway, so it would only cover the easy parts. Same reasoning as Phantom Camera in [ADR 0007](0007-player-centred-camera-rig.md).
- **Signals per move instead of a polled frame**: rejected. One-shots could fall between render frames and physics ticks, and gameplay would have to rebuild held state from events.
- **A Move Input node in each level scene**: rejected in favour of an autoload, because input and interruptions such as focus loss are app-wide. A singleton rule from the architecture-conventions decision takes precedence over this.

## Consequences

- **Edges are latched between ticks.** A press and release inside one tick shows up as pressed on that tick and released on the next. An untargeted Attract still places its Gravity Well, and a held Attract lasts at least one tick. Several Repel or Spin presses within one tick fire once.
- **Move Input computes the aim; gameplay resolves the target.** Touch and mouse cast a ray from the screen through the camera onto y = 0, so the CameraRig registers itself with Move Input. A controller stick at rest aims at Rubbley. A tilted stick runs the cone pick against a targetable-bodies query that gameplay registers ([ADR 0012](0012-aim-decides-the-move.md), still provisional). Gameplay then decides what is under the point, the same way for every scheme.
- **Every scheme is live at once.** Button inputs are OR'd. The scheme that last moved the aim owns the aim, the button prompts and whether a reticle or cursor is shown. Mouse-from-touch and touch-from-mouse emulation are both off in project settings.
- **Touch fingers are allocated as follows:**
  - The first finger down is a swipe candidate and fires Spin once it passes the swipe thresholds.
  - A second finger inside a short window cancels the swipe candidate and starts two-finger classification.
  - Repel fires, or Attract starts, at the moment of classification, not at lift. The aim (pinch centre) and the target are taken at that moment.
  - Attract ends when either pinch finger lifts. The remaining finger is ignored until it lifts too.
  - Resting fingers that haven't crossed any threshold stay unclassified, with no timeout.
  - Any further finger is a swipe candidate only.
- **Interruptions release everything.** A touch cancel, focus loss, controller disconnect, pause or open menu releases a held Attract, zeroes Nudge and drops recogniser state. Input is then swallowed until every finger, button and key has been released.
- **Thresholds are tuning data.** These live in one input tuning resource, whose format follows the tuning-data decision:
  - Trigger press points, with hysteresis
  - Swipe distance and speed
  - The second-finger window
  - The pinch-vs-Nudge thresholds
  - The stick deadzones
  - The Spin lockout
- **Recognisers are plain GDScript classes.** They take timestamped touch events and use no Node and no `Input` singleton, so their tests run headless in `test/unit/`. Each scheme gets one end-to-end smoke test through `Input.parse_input_event` in `test/input/`, run under xvfb ([ADR 0011](0011-gdunit4-split-suites-linux-ci.md)).
- **No rebind UI yet.** Bindings are named `InputMap` actions, so a rebind screen can be added later. Touch gestures are fixed. Steam Input already lets Deck and Steam players remap.
