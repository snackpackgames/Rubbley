# The aim decides which use of a move fires

Every scheme has the same three inputs: Attract, Repel and Spin, plus one aim point. Whatever is under the aim when the input starts decides which use of the move fires, and that target is locked until release. There are no separate inputs for self, targeted and untargeted uses. Attract is the only held move. Repel and Spin are one-shot, because a pinch-out can't comfortably be held.

| Under the aim | Attract (held) | Repel (one-shot) |
|---|---|---|
| Rubbley | Attract on self | Repel Pulse |
| Glowing Celestial Body | Targeted Attract | Targeted Repel |
| Anything else | Gravity Well (one-shot) | Gravity Ripple |

| | Touch | Controller | Mouse + keyboard |
|---|---|---|---|
| Attract / Repel | Pinch-in / pinch-out | Left / right trigger | Left / right click |
| Aim | Pinch centre | Left stick, absolute cursor (see below) | Mouse position |
| Cycle target | n/a | R1 / RB | n/a |
| Spin | One-finger swipe anywhere | Any face button | Spacebar |
| Nudge | Two-finger drag | Right stick | WASD (arrows as alias) |

One press or swipe fires one Spin, followed by a short lockout. Holding or mashing doesn't extend it. Spin can fire during any other move, including as a third finger on touch.

## Considered Options

- **Rub on Rubbley for Spin** (the GDD's Controls section): rejected. A rub needs several strokes before it can be recognised, which costs a few hundred milliseconds on a move that's all about timing, and the finger covers Rubbley at the worst moment.
- **A tap-placed aim cursor on touch** (the GDD's Controls section): rejected. It competes with the pinch centre as a second aim source. On touch you aim directly, with a reticle shown while pinching, a forgiving hit radius, and Rubbley winning ties.
- **Held targeted Repel**: rejected, because a pinch-out can't comfortably be held.
- **Alt+drag for Nudge** (the GDD's Controls section): rejected as awkward. WASD keeps the left hand on the keyboard.
- **Hybrid controller aim** (the provisional pick: stick direction picks a glowing body in a cone, otherwise the point is Rubbley + direction × tilt × range): rejected after the [controller aim prototype](https://github.com/snackpackgames/Rubbley/issues/73). A point that scales with tilt is hard to hold still, and a cone that picks by angle gives no control over which body in a cluster you get.
- **Directional lock-on only** (no free point, wells and ripples at a fixed distance): rejected in the same prototype. It has the hybrid's cluster problem, and you can't choose where a Gravity Well lands.
- **A relative virtual cursor** (the stick moves a cursor that stays where it's left): rejected. A cursor that stays put can't use "stick at rest means Rubbley", so self-moves would need a recentre button.
- **Targeted moves that move only the target**: considered after the prototype, then dropped in favour of the mutual pair forces in [ADR 0006](0006-newtonian-gravity-emergent-orbits.md), with the recoil Rubbley feels kept small in tuning. The slingshot off a planet depends on Rubbley taking the push.

## Consequences

- **Two-finger gestures are classified once, early, and locked until lift.** If the gap between the fingers changes before their midpoint moves, it's a pinch; if the midpoint moves first, it's a Nudge. The thresholds are tuning data.
- **Controller aim is an absolute cursor with a small snap**, settled by [How should controller aim feel?](https://github.com/snackpackgames/Rubbley/issues/73):
  - The cursor sits at Rubbley + stick × range. The range is a circle centred on Rubbley that fits inside the screen's short side, and Nudge doesn't move it. Stick at rest (inside the deadzone) means Rubbley.
  - If a glowing body's edge is within the snap radius of the cursor, the aim snaps to it, the nearest edge first. In a cluster you choose by moving the cursor.
  - **Full-tilt reach:** at full tilt with nothing to snap to, a narrow cone picks the best glowing body in that direction out to about the screen edge, so a distant planet can still be targeted.
  - **Picks measure to a body's edge**, not its centre, so a planet you're orbiting stays easy to pick.
  - **R1 / RB cycles** through the bodies selectable right now, best first, and wraps. A picked or cycled body stays picked while it stays near the cursor (1.5× the snap radius) or inside the cone plus a hysteresis margin.
  - **Release grace:** for a short time after the stick returns to rest, the last aim is kept, so flicking back while pressing a trigger doesn't fire on Rubbley.
- **Starting controller tuning** from the prototype, all in the input tuning resource ([ADR 0013](0013-move-input-snapshot.md)): deadzone 0.2 of stick travel; range 0.9 of half the short side; snap radius about 1/6 of half the short side; full tilt at 0.95, a 12° cone, reach 2× the range; hysteresis 10°; distance bias 5° (prefers nearer bodies in the cone); release grace 120 ms.
- **Touch and mouse can aim anywhere on screen.** The controller's circle is a limit of the stick, not a rule of the game.
- **WASD Nudge is digital.** A held key pushes Nudge to full in that direction, diagonals combine, and Nudge springs back on release.
- Touch emulation of mouse input has to be filtered or turned off, so one tap doesn't also fire a mouse click.
- The physics side of one-shot targeted Repel and Gravity Ripple is in [ADR 0006](0006-newtonian-gravity-emergent-orbits.md).
