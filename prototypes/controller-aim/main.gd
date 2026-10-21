extends Node2D
## PROTOTYPE, throwaway. Not production code, never merged.
## Answers "How should controller aim feel?" (snackpackgames/Rubbley#73).
## 2D stand-in for the Play Plane: screen x/y here are world x/z in the game.

enum Mode { HYBRID, LOCK_ON, ABSOLUTE }
const MODE_NAMES := ["Hybrid", "Directional lock-on", "Absolute offset + snap"]
enum Aim { SELF, BODY, POINT }

const PARAM_ORDER := [
	"deadzone", "cone_deg", "hysteresis_deg", "dist_bias_deg", "range_frac",
	"reach_frac", "lockon_dist_frac", "snap_px", "fulltilt_tilt", "fulltilt_cone_deg",
	"fulltilt_reach_frac", "release_grace_ms", "nudge_px",
	"attract_accel", "self_attract_accel", "well_accel", "well_radius", "repel_impulse",
	"pulse_impulse", "ripple_impulse", "effect_radius", "rubbley_share", "damping",
	"zoom", "size_aware", "planet_surface_g", "gravity_range_mult", "capture_mult",
	"capture_speed_mult", "capture_strength", "attract_mult", "slingshot_impulse", "rubbley_damping",
]
const DEFAULTS := {
	"deadzone": 0.2,          # radial, of stick length
	"cone_deg": 30.0,         # full cone width
	"hysteresis_deg": 10.0,   # extra degrees a picked body keeps the lock
	"dist_bias_deg": 5.0,     # score penalty at full reach (prefers nearer bodies)
	"range_frac": 0.9,        # range circle radius, fraction of half the short side
	"reach_frac": 1.3,        # cone pick max distance, multiple of range
	"lockon_dist_frac": 0.5,  # lock-on: free point distance, fraction of range
	"snap_px": 60.0,          # absolute: snap radius around the free point
	"fulltilt_tilt": 0.95,    # absolute: tilt at which full-tilt reach kicks in
	"fulltilt_cone_deg": 12.0, # absolute: full width of the narrow full-tilt cone
	"fulltilt_reach_frac": 2.0, # absolute: full-tilt reach, multiple of range
	"release_grace_ms": 120.0, # keep last aim this long after the stick returns to rest
	"nudge_px": 220.0,        # right stick camera peek
	# Crude feedback physics: px/s² for held pulls, px/s for one-shot impulses.
	# Not the ADR 0006 model; numbers don't carry over to Tuning.
	"attract_accel": 1200.0,      # targeted Attract, body toward Rubbley
	"self_attract_accel": 900.0,  # Attract on self, everything in effect_radius
	"well_accel": 1100.0,         # Gravity Well pull, everything in well_radius
	"well_radius": 320.0,
	"repel_impulse": 900.0,       # targeted Repel
	"pulse_impulse": 800.0,       # Repel Pulse, falls off over effect_radius
	"ripple_impulse": 800.0,      # Gravity Ripple, falls off over effect_radius, moves Rubbley too
	"effect_radius": 380.0,
	"rubbley_share": 0.3,         # fraction of a pair force Rubbley feels
	"damping": 0.5,               # small-body velocity decay per second
	# Planets: huge, heavy, stationary Celestial Bodies for orbit-and-slingshot traversal.
	"zoom": 0.6,                  # camera zoom, < 1 shows more world
	"size_aware": 1.0,            # 1 = cone measures to a body's edge, 0 = to its centre
	"planet_surface_g": 700.0,    # planet pull on Rubbley at the surface, px/s²; falls off as (r/d)²
	"gravity_range_mult": 6.0,    # pull cuts off at this many planet radii
	"capture_mult": 2.6,          # Capture Radius, in planet radii
	"capture_speed_mult": 1.3,    # assist only if Rubbley is slower than this × circular speed
	"capture_strength": 1.5,      # how fast the assist steers toward a circular orbit, per second
	"attract_mult": 3.0,          # Attract on a planet (or on self) multiplies its pull on Rubbley
	"slingshot_impulse": 550.0,   # targeted Repel on a planet kicks Rubbley away, px/s
	"rubbley_damping": 0.03,      # Rubbley keeps momentum
}
const STEPS := {
	"deadzone": 0.05, "cone_deg": 5.0, "hysteresis_deg": 2.5, "dist_bias_deg": 2.5,
	"range_frac": 0.05, "reach_frac": 0.1, "lockon_dist_frac": 0.05, "snap_px": 10.0,
	"release_grace_ms": 20.0, "nudge_px": 20.0,
	"attract_accel": 100.0, "self_attract_accel": 100.0, "well_accel": 100.0, "well_radius": 20.0,
	"repel_impulse": 100.0, "pulse_impulse": 100.0, "ripple_impulse": 100.0, "effect_radius": 20.0,
	"rubbley_share": 0.05, "damping": 0.1,
	"zoom": 0.05, "size_aware": 1.0, "planet_surface_g": 50.0, "gravity_range_mult": 0.5, "capture_mult": 0.2,
	"capture_speed_mult": 0.1, "capture_strength": 0.25, "attract_mult": 0.5, "slingshot_impulse": 50.0,
	"rubbley_damping": 0.01,
	"fulltilt_tilt": 0.01, "fulltilt_cone_deg": 2.0, "fulltilt_reach_frac": 0.1,
}
## Aim values that only some modes use; anything not listed applies to every mode.
const MODE_PARAMS := {
	"cone_deg": [Mode.HYBRID, Mode.LOCK_ON], "hysteresis_deg": [Mode.HYBRID, Mode.LOCK_ON, Mode.ABSOLUTE],
	"dist_bias_deg": [Mode.HYBRID, Mode.LOCK_ON, Mode.ABSOLUTE], "reach_frac": [Mode.HYBRID, Mode.LOCK_ON],
	"lockon_dist_frac": [Mode.LOCK_ON], "snap_px": [Mode.ABSOLUTE], "fulltilt_tilt": [Mode.ABSOLUTE],
	"fulltilt_cone_deg": [Mode.ABSOLUTE], "fulltilt_reach_frac": [Mode.ABSOLUTE],
}
const PRESS := 0.6
const RELEASE := 0.4

var params := DEFAULTS.duplicate()
var param_index := 0
var mode := Mode.HYBRID
var dev := 0

var rubbley := Vector2.ZERO
var rub_vel := Vector2.ZERO
var drift := false
var drift_heading := 0.0
var time := 0.0
var layout_seed := 1
var bodies: Array = []  # {pos, glow, r, anchor, orbit_r, speed, phase, name, vel, planet}
var planets: Array = []  # the planet entries of bodies, same dictionaries
var orbiting := "-"
var trail := PackedVector2Array()

var stick := Vector2.ZERO
var stick_len := 0.0
var tilt := 0.0
var stick_active := false
var last_tilt_ms := -100000
var aim_kind := Aim.SELF
var aim_target := -1
var candidates: Array = []  # selectable bodies this tick, best first
var aim_point := Vector2.ZERO
var aim_offset := Vector2.ZERO  # free point relative to Rubbley, kept through grace
var raw_point := Vector2.ZERO  # absolute mode, before snap
var in_grace := false

var attract_held := false
var held_kind := -1
var held_target := -1
var repel_down := false
var effects: Array = []  # {kind, pos, body, t0}
var last_fired := "-"

var nudge_offset := Vector2.ZERO
var camera := Camera2D.new()
var hud := Label.new()
var gizmo := Control.new()


func _ready() -> void:
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 14)
	layer.add_child(hud)
	gizmo.draw.connect(_draw_gizmo)
	layer.add_child(gizmo)
	_regen()


func _regen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	bodies.clear()
	planets.clear()
	trail.clear()
	# A winding chain of planets, Rubbley starting in orbit around the first.
	var heading := rng.randf() * TAU
	var r0 := rng.randf_range(110.0, 170.0)
	var ppos := rubbley + Vector2.from_angle(heading) * r0 * 2.0
	for k in 4:
		var pr := r0 if k == 0 else rng.randf_range(90.0, 190.0)
		if k > 0:
			heading += rng.randf_range(-0.9, 0.9)
			ppos += Vector2.from_angle(heading) * rng.randf_range(1200.0, 1700.0)
		var p := {"pos": ppos, "glow": true, "r": pr, "anchor": ppos, "orbit_r": 0.0, "speed": 0.0, "phase": 0.0,
			"name": "P%d" % (k + 1), "vel": Vector2.ZERO, "planet": true, "mass": pr * pr / 100.0}
		bodies.append(p)
		planets.append(p)
	var n := 0
	for i in 22:
		var glow := i < 8
		var a := rng.randf() * TAU
		var d := rng.randf_range(120.0, 900.0)
		var anchor := rubbley + Vector2.from_angle(a) * d
		for p in planets:
			if anchor.distance_to(p.pos) < p.r + 60.0:
				anchor = p.pos + (anchor - p.pos).normalized() * (p.r * 2.6 + 80.0)
		var orbit := rng.randf() < 0.4
		bodies.append({
			"pos": anchor, "glow": glow, "r": rng.randf_range(14.0, 34.0) if glow else rng.randf_range(6.0, 16.0),
			"anchor": anchor, "orbit_r": rng.randf_range(40.0, 150.0) if orbit else 0.0,
			"speed": rng.randf_range(0.3, 1.0) * (1 if rng.randf() < 0.5 else -1), "phase": rng.randf() * TAU,
			"name": "G%d" % n if glow else "", "vel": Vector2.ZERO, "planet": false,
		})
		if glow:
			n += 1
	# A tight cluster of three glowing bodies, to test picking between neighbours.
	var c := rubbley + Vector2.from_angle(heading + PI) * 320.0
	for k in 3:
		var p := c + Vector2.from_angle(k * TAU / 3.0) * 45.0
		bodies.append({"pos": p, "glow": true, "r": 18.0, "anchor": p, "orbit_r": 0.0, "speed": 0.0, "phase": 0.0, "name": "C%d" % k, "vel": Vector2.ZERO, "planet": false})
	# Start in a circular orbit around P1.
	var p1 = planets[0]
	var to: Vector2 = rubbley - p1.pos
	var g: float = params.planet_surface_g * pow(p1.r / to.length(), 2.0)
	rub_vel = to.normalized().orthogonal() * sqrt(g * to.length())
	aim_target = -1
	held_target = -1


func range_px() -> float:
	var s := get_viewport_rect().size
	return params.range_frac * minf(s.x, s.y) * 0.5 / maxf(params.zoom, 0.05)


func _physics_process(delta: float) -> void:
	time += delta
	var damp := exp(-params.damping * delta)
	for b in bodies:
		if b.planet:
			continue
		if b.orbit_r > 0.0:
			var ang: float = b.phase + time * b.speed
			b.pos = b.anchor + Vector2.from_angle(ang) * b.orbit_r
			b.vel = Vector2.from_angle(ang + PI / 2.0) * b.orbit_r * b.speed
		else:
			b.pos += b.vel * delta
			b.vel *= damp
		for p in planets:
			_contact(b, p.pos, p.r + b.r, Vector2.ZERO)
		# Crude contact with Rubbley so pulled bodies don't pass through.
		var to: Vector2 = b.pos - rubbley
		var min_d: float = b.r + 22.0
		if to.length() < min_d:
			var n := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
			b.orbit_r = 0.0
			b.pos = rubbley + n * min_d
			var vn: float = (b.vel - rub_vel).dot(n)
			if vn < 0.0:
				b.vel -= n * vn * 1.3
	_planet_gravity(delta)
	rub_vel *= exp(-params.rubbley_damping * delta)
	rub_vel = rub_vel.limit_length(2500.0)
	rubbley += rub_vel * delta
	for p in planets:
		var to: Vector2 = rubbley - p.pos
		var min_d: float = p.r + 22.0
		if to.length() < min_d:
			var n := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
			rubbley = p.pos + n * min_d
			var vn := rub_vel.dot(n)
			if vn < 0.0:
				rub_vel -= n * vn * 1.2
	trail.append(rubbley)
	if trail.size() > 240:
		trail.remove_at(0)
	if drift:
		drift_heading += delta * 0.4 * sin(time * 0.3)
		rubbley += Vector2.from_angle(drift_heading) * 90.0 * delta

	var pads := Input.get_connected_joypads()
	dev = pads[0] if pads.size() > 0 else 0
	stick = Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	stick_len = minf(stick.length(), 1.0)
	var dz: float = params.deadzone
	stick_active = stick_len >= dz
	tilt = clampf((stick_len - dz) / maxf(0.95 - dz, 0.01), 0.0, 1.0) if stick_active else 0.0
	_compute_aim()
	_triggers()
	_apply_forces(delta)

	var nraw := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	var nudge := nraw if nraw.length() > 0.2 else Vector2.ZERO
	nudge_offset = nudge_offset.lerp(nudge.limit_length(1.0) * params.nudge_px, 1.0 - exp(-10.0 * delta))
	effects = effects.filter(func(e): return time - e.t0 < (3.0 if e.kind == "well" else 0.8))


func _compute_aim() -> void:
	var now := Time.get_ticks_msec()
	in_grace = false
	if not stick_active:
		if now - last_tilt_ms < params.release_grace_ms:
			in_grace = true
			if aim_kind == Aim.POINT:
				aim_point = rubbley + aim_offset
			elif aim_kind == Aim.BODY:
				aim_point = bodies[aim_target].pos
			return
		aim_kind = Aim.SELF
		aim_target = -1
		candidates = []
		aim_point = rubbley
		return
	last_tilt_ms = now
	var dir := stick / stick.length()
	var rng := range_px()
	var t := -1
	candidates = []
	match mode:
		Mode.HYBRID:
			t = _cone_pick(dir)
			aim_offset = dir * tilt * rng
		Mode.LOCK_ON:
			t = _cone_pick(dir)
			aim_offset = dir * params.lockon_dist_frac * rng
		Mode.ABSOLUTE:
			aim_offset = dir * tilt * rng
			raw_point = rubbley + aim_offset
			t = _snap_pick(raw_point)
			if t < 0 and tilt >= params.fulltilt_tilt:
				t = _cone_pick(dir, params.fulltilt_cone_deg, params.fulltilt_reach_frac)
	aim_target = t
	if t >= 0:
		aim_kind = Aim.BODY
		aim_point = bodies[t].pos
	else:
		aim_kind = Aim.POINT
		aim_point = rubbley + aim_offset


func _cone_pick(dir: Vector2, cone_deg: float = -1.0, reach_frac: float = -1.0) -> int:
	var half: float = (params.cone_deg if cone_deg < 0.0 else cone_deg) * 0.5
	var reach: float = range_px() * (params.reach_frac if reach_frac < 0.0 else reach_frac)
	candidates = _cone_candidates(dir, half, reach)
	if aim_target >= 0:
		var m := _cone_measure(dir, bodies[aim_target])
		if m.y <= reach and m.x <= half + params.hysteresis_deg:
			return aim_target
	return candidates[0] if candidates.size() > 0 else -1


## Glowing bodies in the cone, best score first. Triangle cycles through these.
func _cone_candidates(dir: Vector2, half: float, reach: float) -> Array:
	var scored := []
	for i in bodies.size():
		var b = bodies[i]
		if not b.glow:
			continue
		var m := _cone_measure(dir, b)
		if m.y > reach or m.x > half:
			continue
		scored.append([m.x + params.dist_bias_deg * m.y / reach, i])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	return scored.map(func(s): return s[1])


## x: degrees between the stick and the body, y: distance. With size_aware on,
## both are measured to the body's edge, so a big planet is easy to pick up close.
func _cone_measure(dir: Vector2, b: Dictionary) -> Vector2:
	var to: Vector2 = b.pos - rubbley
	var d := maxf(to.length(), 1.0)
	var ang := rad_to_deg(absf(dir.angle_to(to)))
	if params.size_aware > 0.5:
		ang = maxf(0.0, ang - rad_to_deg(asin(minf(1.0, b.r / d))))
		d = maxf(0.0, d - b.r)
	return Vector2(ang, d)


func _snap_pick(p: Vector2) -> int:
	var scored := []
	for i in bodies.size():
		var b = bodies[i]
		if not b.glow:
			continue
		var d: float = b.pos.distance_to(p) - b.r
		if d <= params.snap_px:
			scored.append([d, i])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	candidates = scored.map(func(s): return s[1])
	if aim_target >= 0 and bodies[aim_target].pos.distance_to(p) <= params.snap_px * 1.5 + bodies[aim_target].r:
		return aim_target
	return candidates[0] if candidates.size() > 0 else -1


## Triangle: step to the next selectable body, in score order. The pick's
## stickiness then holds it while it stays selectable.
func _cycle_target() -> void:
	if candidates.is_empty():
		return
	var i := candidates.find(aim_target)
	aim_target = candidates[(i + 1) % candidates.size()]
	aim_kind = Aim.BODY
	aim_point = bodies[aim_target].pos
	last_fired = "cycled to %s (%d selectable)" % [bodies[aim_target].name, candidates.size()]


func _triggers() -> void:
	var lt := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT)
	if not attract_held and lt > PRESS:
		attract_held = true
		match aim_kind:
			Aim.SELF:
				held_kind = Aim.SELF
				last_fired = "Attract on self (held)"
			Aim.BODY:
				held_kind = Aim.BODY
				held_target = aim_target
				last_fired = "Targeted Attract on %s (held)" % bodies[aim_target].name
			Aim.POINT:
				held_kind = -1
				effects.append({"kind": "well", "pos": aim_point, "t0": time})
				last_fired = "Gravity Well at %s" % _fmt(aim_point - rubbley)
	elif attract_held and lt < RELEASE:
		attract_held = false
		held_kind = -1
		held_target = -1
	if not repel_down and rt > PRESS:
		repel_down = true
		match aim_kind:
			Aim.SELF:
				effects.append({"kind": "pulse", "pos": rubbley, "t0": time})
				_radial(rubbley, params.pulse_impulse, params.effect_radius, false)
				last_fired = "Repel Pulse"
			Aim.BODY:
				effects.append({"kind": "flash", "body": aim_target, "pos": aim_point, "t0": time})
				var dir: Vector2 = (bodies[aim_target].pos - rubbley).normalized()
				if bodies[aim_target].planet:
					# The planet is too heavy to move: Rubbley takes the whole kick.
					rub_vel -= dir * params.slingshot_impulse
				else:
					_kick(bodies[aim_target], dir * params.repel_impulse)
					rub_vel -= dir * params.repel_impulse * params.rubbley_share
				last_fired = "Targeted Repel on %s" % bodies[aim_target].name
			Aim.POINT:
				effects.append({"kind": "ripple", "pos": aim_point, "t0": time})
				_radial(aim_point, params.ripple_impulse, params.effect_radius, true)
				last_fired = "Gravity Ripple at %s" % _fmt(aim_point - rubbley)
	elif repel_down and rt < RELEASE:
		repel_down = false


## Frees a scripted orbiter and adds a velocity change.
func _kick(b: Dictionary, dv: Vector2) -> void:
	if b.planet:
		return
	b.orbit_r = 0.0
	b.vel += dv


## One-shot radial push from a point, linear falloff to zero at radius.
func _radial(from: Vector2, impulse: float, radius: float, moves_rubbley: bool) -> void:
	for b in bodies:
		var to: Vector2 = b.pos - from
		var f := 1.0 - to.length() / radius
		if f > 0.0 and to.length() > 0.01:
			_kick(b, to.normalized() * impulse * f)
	if moves_rubbley:
		var to := rubbley - from
		var f := 1.0 - to.length() / radius
		if f > 0.0 and to.length() > 0.01:
			rub_vel += to.normalized() * impulse * f


## Held and lingering pulls: targeted Attract, Attract on self, Gravity Wells.
func _apply_forces(delta: float) -> void:
	if attract_held and held_kind == Aim.BODY and held_target >= 0 and not bodies[held_target].planet:
		var b = bodies[held_target]
		var dir: Vector2 = (rubbley - b.pos).normalized()
		_kick(b, dir * params.attract_accel * delta)
		rub_vel -= dir * params.attract_accel * params.rubbley_share * delta
	if attract_held and held_kind == Aim.SELF:
		_pull(rubbley, params.self_attract_accel, params.effect_radius, delta, false)
	for e in effects:
		if e.kind == "well":
			_pull(e.pos, params.well_accel, params.well_radius, delta, true)


func _pull(to_point: Vector2, accel: float, radius: float, delta: float, moves_rubbley: bool) -> void:
	for b in bodies:
		var to: Vector2 = to_point - b.pos
		var f := 1.0 - to.length() / radius
		if f > 0.0 and to.length() > 8.0:
			_kick(b, to.normalized() * accel * f * delta)
	if moves_rubbley:
		var to := to_point - rubbley
		var f := 1.0 - to.length() / radius
		if f > 0.0 and to.length() > 8.0:
			rub_vel += to.normalized() * accel * f * delta


## Pushes a small body out of a circle and removes its inward speed.
func _contact(b: Dictionary, centre: Vector2, min_d: float, centre_vel: Vector2) -> void:
	var to: Vector2 = b.pos - centre
	if to.length() >= min_d:
		return
	var n := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
	b.orbit_r = 0.0
	b.pos = centre + n * min_d
	var vn: float = (b.vel - centre_vel).dot(n)
	if vn < 0.0:
		b.vel -= n * vn * 1.3


## Planets pull Rubbley only (small bodies are left out to keep the scene readable).
## Attract on a planet, or on self, multiplies the pull. Inside the Capture Radius,
## a slow Rubbley is steered toward a circular orbit, as in ADR 0006's capture assist.
func _planet_gravity(delta: float) -> void:
	orbiting = "-"
	for p in planets:
		var to: Vector2 = p.pos - rubbley
		var d := to.length()
		if d > p.r * params.gravity_range_mult or d < 1.0:
			continue
		var g: float = params.planet_surface_g * pow(p.r / d, 2.0)
		var boosted: bool = attract_held and (held_kind == Aim.SELF or (held_kind == Aim.BODY and held_target >= 0 and bodies[held_target] == p))
		var mult: float = params.attract_mult if boosted else 1.0
		rub_vel += to / d * g * mult * delta
		if boosted or d > p.r * params.capture_mult:
			continue
		var tangent := (-to / d).orthogonal()
		var sgn := 1.0 if rub_vel.dot(tangent) >= 0.0 else -1.0
		var v_circ := sqrt(g * d)
		if rub_vel.length() < v_circ * params.capture_speed_mult:
			rub_vel = rub_vel.lerp(tangent * sgn * v_circ, 1.0 - exp(-params.capture_strength * delta))
			orbiting = p.name


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK:
				_set_mode((mode + 1) % 3)
			JOY_BUTTON_LEFT_SHOULDER:
				_set_mode((mode + 2) % 3)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_target()
			JOY_BUTTON_DPAD_UP:
				param_index = (param_index + PARAM_ORDER.size() - 1) % PARAM_ORDER.size()
			JOY_BUTTON_DPAD_DOWN:
				param_index = (param_index + 1) % PARAM_ORDER.size()
			JOY_BUTTON_DPAD_LEFT:
				_adjust(-1)
			JOY_BUTTON_DPAD_RIGHT:
				_adjust(1)
			JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_Y:
				effects.append({"kind": "spin", "pos": rubbley, "t0": time})
				last_fired = "Spin"
			JOY_BUTTON_X:
				layout_seed += 1
				_regen()
			JOY_BUTTON_RIGHT_STICK:
				drift = not drift
			JOY_BUTTON_START:
				params = DEFAULTS.duplicate()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_mode(Mode.HYBRID)
			KEY_2: _set_mode(Mode.LOCK_ON)
			KEY_3: _set_mode(Mode.ABSOLUTE)
			KEY_UP: param_index = (param_index + PARAM_ORDER.size() - 1) % PARAM_ORDER.size()
			KEY_DOWN: param_index = (param_index + 1) % PARAM_ORDER.size()
			KEY_LEFT: _adjust(-1)
			KEY_RIGHT: _adjust(1)
			KEY_R:
				layout_seed += 1
				_regen()
			KEY_D: drift = not drift
			KEY_T: _cycle_target()
			KEY_P: print(JSON.stringify({"mode": MODE_NAMES[mode], "params": params}))


func _set_mode(m: int) -> void:
	mode = m as Mode
	aim_target = -1


func _adjust(sign: int) -> void:
	var k: String = PARAM_ORDER[param_index]
	params[k] = maxf(0.0, snappedf(params[k] + sign * STEPS[k], 0.001))


func _process(_delta: float) -> void:
	camera.position = rubbley + nudge_offset
	camera.zoom = Vector2.ONE * maxf(params.zoom, 0.05)
	gizmo.queue_redraw()
	queue_redraw()
	var lines := PackedStringArray()
	lines.append("PROTOTYPE controller aim  |  mode: %s  (Back next, LB previous)" % MODE_NAMES[mode])
	lines.append("pad: %s" % (Input.get_joy_name(dev) if Input.get_connected_joypads().size() > 0 else "NONE CONNECTED"))
	lines.append("stick %s  len %.2f  tilt %.2f  %s" % [_fmt(stick, 2), stick_len, tilt, "active" if stick_active else ("grace" if in_grace else "rest")])
	var tname: String = bodies[aim_target].name if aim_target >= 0 else "-"
	lines.append("aim: %s  target %s  offset %s  selectable %d" % [["SELF", "BODY", "POINT"][aim_kind], tname, _fmt(aim_point - rubbley), candidates.size()])
	var held := "-"
	if attract_held:
		held = ["self", "body " + (bodies[held_target].name if held_target >= 0 else "?"), ""][held_kind] if held_kind >= 0 else "(well placed)"
	lines.append("attract held: %s   last fired: %s" % [held, last_fired])
	lines.append("Rubbley speed %.0f px/s   capture assist: %s" % [rub_vel.length(), orbiting])
	lines.append("")
	for i in PARAM_ORDER.size():
		var k: String = PARAM_ORDER[i]
		var unused := not (MODE_PARAMS.get(k, [Mode.HYBRID, Mode.LOCK_ON, Mode.ABSOLUTE]) as Array).has(mode)
		lines.append("%s %-18s %s%s" % [">" if i == param_index else " ", k, str(params[k]), "   (unused in this mode)" if unused else ""])
	lines.append("")
	lines.append("LT Attract  RT Repel  A/B/Y Spin  RB cycle  R-stick Nudge  D-pad tune  X new layout  R3 drift %s  Start reset  (P prints params)" % ("on" if drift else "off"))
	hud.text = "\n".join(lines)


func _draw() -> void:
	var rng := range_px()
	draw_arc(rubbley, rng, 0.0, TAU, 128, Color(1, 1, 1, 0.25), 2.0)
	if mode == Mode.ABSOLUTE and stick_active and tilt >= params.fulltilt_tilt:
		var fdir := stick / stick.length()
		var fhalf := deg_to_rad(params.fulltilt_cone_deg * 0.5)
		var freach: float = rng * params.fulltilt_reach_frac
		_fill(PackedVector2Array([rubbley, rubbley + fdir.rotated(-fhalf) * freach, rubbley + fdir.rotated(fhalf) * freach]), Color(0.4, 0.8, 1.0, 0.08))
	if mode != Mode.ABSOLUTE and stick_active:
		var dir := stick / stick.length()
		var half := deg_to_rad(params.cone_deg * 0.5)
		var reach: float = rng * params.reach_frac
		var pts := PackedVector2Array([rubbley])
		for i in 17:
			pts.append(rubbley + dir.rotated(lerpf(-half, half, i / 16.0)) * reach)
		_fill(pts, Color(0.4, 0.8, 1.0, 0.08))
		draw_arc(rubbley, reach, dir.angle() - half, dir.angle() + half, 24, Color(0.4, 0.8, 1.0, 0.3), 1.0)
		# Hysteresis: a picked body keeps its lock until it leaves these outer edges.
		var hh := half + deg_to_rad(params.hysteresis_deg)
		for e in [-hh, hh]:
			draw_dashed_line(rubbley, rubbley + dir.rotated(e) * reach, Color(1.0, 0.8, 0.4, 0.45), 1.5, 12.0)
	if mode == Mode.ABSOLUTE and stick_active:
		draw_arc(raw_point, params.snap_px, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, 0.4), 1.0)
		draw_circle(raw_point, 3.0, Color(0.4, 0.8, 1.0, 0.6))

	if trail.size() > 1:
		draw_polyline(trail, Color(0.9, 0.9, 1.0, 0.25), 2.0)
	for p in planets:
		draw_arc(p.pos, p.r * params.capture_mult, 0.0, TAU, 96, Color(0.5, 0.7, 1.0, 0.25 if orbiting == p.name else 0.1), 2.0)
		draw_arc(p.pos, p.r * params.gravity_range_mult, 0.0, TAU, 128, Color(0.5, 0.7, 1.0, 0.05), 1.0)
	for i in bodies.size():
		var b = bodies[i]
		if b.planet:
			draw_circle(b.pos, b.r + 14.0, Color(1.0, 0.85, 0.3, 0.12))
			draw_circle(b.pos, b.r, Color(0.35, 0.45, 0.75))
			draw_string(ThemeDB.fallback_font, b.pos + Vector2(-30, 8), "%s  m%.0f" % [b.name, b.mass], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		elif b.glow:
			draw_circle(b.pos, b.r + 6.0, Color(1.0, 0.85, 0.3, 0.15))
			draw_circle(b.pos, b.r, Color(1.0, 0.8, 0.25))
		else:
			draw_circle(b.pos, b.r, Color(0.45, 0.45, 0.5))
		if i != aim_target and candidates.has(i):
			draw_arc(b.pos, b.r + 10.0, 0.0, TAU, 48, Color(0.3, 1.0, 1.0, 0.35), 1.5)
		if i == aim_target:
			draw_arc(b.pos, b.r + 10.0, 0.0, TAU, 48, Color(0.3, 1.0, 1.0), 3.0)

	for e in effects:
		var age: float = time - e.t0
		match e.kind:
			"well":
				var a := 1.0 - age / 3.0
				draw_arc(e.pos, params.well_radius, 0.0, TAU, 64, Color(0.7, 0.4, 1.0, 0.2 * a), 1.0)
				for k in 3:
					draw_arc(e.pos, 12.0 + k * 12.0, time * 3.0 + k, time * 3.0 + k + 4.0, 24, Color(0.7, 0.4, 1.0, a), 2.0)
			"pulse", "ripple":
				var c := Color(1.0, 0.4, 0.3) if e.kind == "pulse" else Color(1.0, 0.6, 0.2)
				c.a = 1.0 - age / 0.8
				draw_arc(e.pos, 20.0 + age * 300.0, 0.0, TAU, 64, c, 3.0)
			"flash":
				draw_arc(bodies[e.body].pos, bodies[e.body].r + 4.0 + age * 60.0, 0.0, TAU, 48, Color(1, 0.4, 0.3, 1.0 - age / 0.8), 3.0)
			"spin":
				draw_arc(rubbley, 34.0, time * 20.0, time * 20.0 + TAU * 0.8, 32, Color(0.6, 1.0, 0.6, 1.0 - age / 0.8), 4.0)

	if attract_held and held_kind == Aim.BODY and held_target >= 0:
		draw_line(rubbley, bodies[held_target].pos, Color(0.7, 0.4, 1.0, 0.8), 3.0)
	if attract_held and held_kind == Aim.SELF:
		draw_arc(rubbley, 40.0 + 6.0 * sin(time * 12.0), 0.0, TAU, 48, Color(0.7, 0.4, 1.0), 3.0)

	draw_circle(rubbley, 22.0, Color(0.9, 0.9, 1.0))
	var rc := Color(0.3, 1.0, 1.0) if aim_kind != Aim.SELF else Color(1, 1, 1, 0.6)
	draw_arc(aim_point, 14.0, 0.0, TAU, 32, rc, 2.0)
	draw_line(aim_point - Vector2(20, 0), aim_point + Vector2(20, 0), rc, 1.0)
	draw_line(aim_point - Vector2(0, 20), aim_point + Vector2(0, 20), rc, 1.0)


func _draw_gizmo() -> void:
	var s := get_viewport_rect().size
	var c := Vector2(80, s.y - 80)
	gizmo.draw_arc(c, 60.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 1.0)
	gizmo.draw_arc(c, 60.0 * params.deadzone, 0.0, TAU, 32, Color(1, 0.4, 0.3, 0.7), 1.0)
	gizmo.draw_circle(c + stick.limit_length(1.0) * 60.0, 6.0, Color(0.3, 1.0, 1.0) if stick_active else Color(1, 1, 1, 0.6))


func _fmt(v: Vector2, digits := 0) -> String:
	var f := "%." + str(digits) + "f"
	return "(" + f % v.x + ", " + f % v.y + ")"


## Skips wedges too thin to triangulate (e.g. a cone tuned to 0°) instead of logging errors.
func _fill(pts: PackedVector2Array, c: Color) -> void:
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, c)
