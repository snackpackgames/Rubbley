# Rubbley

A 2.5D top-down physics action-puzzle game where the player fights by manipulating gravity.

## Language

**Play Plane**:
The single flat surface where all gameplay happens: movement, collision, gravity, aiming and pickups. Anything off it (backgrounds, camera height, cosmetic tumble) is presentation only.
_Avoid_: ground, field, arena, plane (unqualified)

### Gravity

**Celestial Body**:
A body that both pulls and is pulled by gravity. Only a few exist at once: Rubbley, planets, asteroids, large enemies.
_Avoid_: attractor, planet (as a general term)

**Passive Body**:
A body that is pulled by gravity but pulls nothing itself: debris, materials, small enemies.
_Avoid_: test particle, non-attractor

**Anchored Body**:
A Celestial Body that level design holds in place. It pulls but is never moved.

**Gravity Well**:
A temporary point of pull that Rubbley places in empty space with an untargeted Attract. It pulls but is never pulled.
_Avoid_: well (unqualified), black hole

**Gravega**:
Rubbley's power to change the gravity between himself and other bodies. Attract and Repel are uses of Gravega.
_Avoid_: Graviga (the old name, dropped because it evokes the Final Fantasy spell)

**Orbit**:
The state of a lighter body circling a heavier one under gravity. Orbit is a state, not a move: a body enters it by being captured and leaves it by being pushed out.
_Avoid_: using "Orbit" as the name of a move (the moves are Attract, Repel, Spin)

**Capture Radius**:
The distance around a Celestial Body inside which a slower, lighter body is helped into Orbit.

**Drift**:
The gentle, steady push that carries Rubbley along a stage's path. Rubbley has no other movement of his own; he steers only with Gravega.
_Avoid_: auto-scroll, thrust

### Moves

**Repel Pulse**:
A one-off burst of Repel from Rubbley in all directions, triggered on Rubbley himself. It shoves nearby bodies away and stuns enemies.
_Avoid_: shockwave, flick

**Spin**:
A brief shield all the way around Rubbley that deflects whatever hits it. Spin is about timing, not aiming.
_Avoid_: deflector (as the move's name), parry

### Camera

**Nudge**:
A temporary shift of the view away from Rubbley that the player holds to peek ahead. It springs back to centre when released and never pushes Rubbley off screen.
_Avoid_: pan, camera drag, look

**Camera Zone**:
A region of a level that widens the view while Rubbley is inside it, such as a boss arena. It can show more of the level but never less than Rubbley's size calls for.
_Avoid_: camera trigger, framing volume
