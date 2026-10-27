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
A temporary point of pull that Rubbley places in empty space with an untargeted Attract. It pulls but is never pulled, drags on what moves inside it, and fades out at the end.
_Avoid_: well (unqualified), black hole

**Gravity Ripple**:
A one-off push outward from a point in space, made with an untargeted Repel. It shoves everything nearby away, Rubbley included, but stuns nothing.
_Avoid_: ripple (unqualified), shockwave, anti-well

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

### Collecting

**Debris**:
Loose Passive Bodies floating or orbiting in a stage that Rubbley absorbs into his Mass.
_Avoid_: resources, junk, pickups (as a general term)

**Material**:
A collectible Rubbley carries out of a stage to fuel progression. Materials lie in trails or are dropped by enemies.
_Avoid_: resources, currency, loot

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

### Stats and Tuning

**Mass**:
How heavy Rubbley or any other body is. For Rubbley it is also his health and his size: damage takes Mass away, absorbed debris adds it, and he grows and shrinks with it.
_Avoid_: health, HP, weight, size (as a separate stat)

**Stamina**:
The single pool that all three moves draw on. It drains while a move is used and refills while none is.
_Avoid_: energy, mana, spin stamina (as a separate pool)

**Stats**:
A character's numbers that advancement can change, such as Mass limits, Stamina and Gravega strength.
_Avoid_: attributes, tuning (for upgradeable values)

**Stat Modifier**:
One change to a single Stat, either added or multiplied, that lasts for good or for a set time. Upgrades, power-ups and consumables are all Stat Modifiers.
_Avoid_: buff, perk, bonus

**Tuning**:
The fixed numbers that set how the game feels and how the simulation behaves, such as Capture Radius, speed caps, Drift strength and input thresholds. Advancement never changes them.
_Avoid_: config, constants, settings (which are the player's options)

### Platforms

**Minimum-Spec Device**:
The weakest device Rubbley promises to run well on, which defines the support floor for its platform. Weaker devices may install the game but are unsupported.
_Avoid_: low-end device, min spec (unqualified), test phone

**Playtest Build**:
The Full Game build that every merge to `main` publishes for playtesters on web. It is never sold, and it is always the latest `main`.
_Avoid_: dev build, nightly, demo

### Monetisation

**Full Game**:
Every level and feature Rubbley offers. It is what Steam and Epic sell and what the Unlock grants.
_Avoid_: paid version, pro, premium (as a noun)

**Free Tier**:
The set of always-free levels anyone can play without paying. It is all itch.io offers and where mobile players start.
_Avoid_: demo, lite, trial

**Unlock**:
The single one-time purchase on mobile that turns the Free Tier into the Full Game.
_Avoid_: IAP (unqualified), upgrade, premium unlock

### Characters

**Character**:
Any body that has a Floating Face and animates its body. It is an animation-side idea that cuts across the gravity classes: a Character can be a Celestial Body or a Passive Body.
_Avoid_: NPC, actor, creature

**Floating Face**:
A flat 2D face that hovers just off one side of a body, showing its current Expression. It is a separate layer, not painted onto the body's surface. Any body can have one; Rubbley, planets and large enemies are the usual cases.
_Avoid_: decal, face texture, portrait, face (unqualified)

**Expression**:
One named state a Floating Face can show, such as neutral, hurt or talking. It may be a single still or a short loop.
_Avoid_: emotion, mood, emote

**Reaction**:
A Character's named response to something that happens to it, such as being hit, captured into Orbit or breaking apart. One Reaction sets the Expression, the body animation and where the eyes look, all together.
_Avoid_: emote, animation event
