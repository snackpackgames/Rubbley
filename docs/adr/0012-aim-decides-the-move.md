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
| Aim | Pinch centre | Left stick (see below) | Mouse position |
| Spin | One-finger swipe anywhere | Any face button | Spacebar |
| Nudge | Two-finger drag | Right stick | WASD (arrows as alias) |

One press or swipe fires one Spin, followed by a short lockout. Holding or mashing doesn't extend it. Spin can fire during any other move, including as a third finger on touch.

## Considered Options

- **Rub on Rubbley for Spin** (the GDD's Controls section): rejected. A rub needs several strokes before it can be recognised, which costs a few hundred milliseconds on a move that's all about timing, and the finger covers Rubbley at the worst moment.
- **A tap-placed aim cursor on touch** (the GDD's Controls section): rejected. It competes with the pinch centre as a second aim source. On touch you aim directly, with a reticle shown while pinching, a forgiving hit radius, and Rubbley winning ties.
- **Held targeted Repel**: rejected, because a pinch-out can't comfortably be held.
- **Alt+drag for Nudge** (the GDD's Controls section): rejected as awkward. WASD keeps the left hand on the keyboard.
- **Controller aim as an absolute offset, directional lock-on only, or a relative virtual cursor**: set aside in favour of the hybrid below, pending a prototype.

## Consequences

- **Two-finger gestures are classified once, early, and locked until lift.** If the gap between the fingers changes before their midpoint moves, it's a pinch; if the midpoint moves first, it's a Nudge. The thresholds are tuning data.
- **Controller aim is provisional** until [How should controller aim feel?](https://github.com/snackpackgames/Rubbley/issues/73) settles it. The current pick is a hybrid: stick direction picks a glowing body in a cone, and with no body there the point is Rubbley + direction × tilt × range. Stick at rest means self. The range is a circle centred on Rubbley that fits inside the screen's short side, and Nudge doesn't move it.
- **Touch and mouse can aim anywhere on screen.** The controller's circle is a limit of the stick, not a rule of the game.
- **WASD Nudge is digital.** A held key pushes Nudge to full in that direction, diagonals combine, and Nudge springs back on release.
- Touch emulation of mouse input has to be filtered or turned off, so one tap doesn't also fire a mouse click.
- The physics side of one-shot targeted Repel and Gravity Ripple is in [ADR 0006](0006-newtonian-gravity-emergent-orbits.md).
