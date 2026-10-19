extends Node2D
## PROTOTYPE, throwaway. Not production code, never merged.
## Answers "How should controller aim feel?" (snackpackgames/Rubbley#73).
## 2D stand-in for the Play Plane: screen x/y here are world x/z in the game.

enum Mode { HYBRID, LOCK_ON, ABSOLUTE }
const MODE_NAMES := ["Hybrid", "Directional lock-on", "Absolute offset + snap"]
enum Aim { SELF, BODY, POINT }

const PARAM_ORDER := [
	"deadzone", "cone_deg", "hysteresis_deg", "dist_bias_deg", "range_frac",
	"reach_frac", "lockon_dist_frac", "snap_px", "release_grace_ms", "nudge_px",
	"attract_accel", "self_attract_accel", "well_accel", "well_radius", "repel_impulse",
	"pulse_impulse", "ripple_impulse", "effect_radius", "rubbley_share", "damping",
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
	"damping": 0.5,               # velocity decay per second
}
const STEPS := {
	"deadzone": 0.05, "cone_deg": 5.0, "hysteresis_deg": 2.5, "dist_bias_deg": 2.5,
	"range_frac": 0.05, "reach_frac": 0.1, "lockon_dist_frac": 0.05, "snap_px": 10.0,
	"release_grace_ms": 20.0, "nudge_px": 20.0,
	"attract_accel": 100.0, "self_attract_accel": 100.0, "well_accel": 100.0, "well_radius": 20.0,
	"repel_impulse": 100.0, "pulse_impulse": 100.0, "ripple_impulse": 100.0, "effect_radius": 20.0,
	"rubbley_share": 0.05, "damping": 0.1,
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
var bodies: Array = []  # {pos, glow, r, anchor, orbit_r, speed, phase, name}

var stick := Vector2.ZERO
var stick_len := 0.0
var tilt := 0.0
var stick_active := false
var last_tilt_ms := -100000
var aim_kind := Aim.SELF
var aim_target := -1
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
	var n := 0
	for i in 22:
		var glow := i < 8
		var a := rng.randf() * TAU
		var d := rng.randf_range(120.0, 900.0)
		var anchor := rubbley + Vector2.from_angle(a) * d
		var orbit := rng.randf() < 0.4
		bodies.append({
			"pos": anchor, "glow": glow, "r": rng.randf_range(14.0, 34.0) if glow else rng.randf_range(6.0, 16.0),
			"anchor": anchor, "orbit_r": rng.randf_range(40.0, 150.0) if orbit else 0.0,
			"speed": rng.randf_range(0.3, 1.0) * (1 if rng.randf() < 0.5 else -1), "phase": rng.randf() * TAU,
			"name": "G%d" % n if glow else "", "vel": Vector2.ZERO,
		})
		if glow:
			n += 1
	# A tight cluster of three glowing bodies, to test picking between neighbours.
	var c := rubbley + Vector2.from_angle(rng.randf() * TAU) * 320.0
	for k in 3:
		var p := c + Vector2.from_angle(k * TAU / 3.0) * 45.0
		bodies.append({"pos": p, "glow": true, "r": 18.0, "anchor": p, "orbit_r": 0.0, "speed": 0.0, "phase": 0.0, "name": "C%d" % k, "vel": Vector2.ZERO})
	rub_vel = Vector2.ZERO
	aim_target = -1
	held_target = -1


func range_px() -> float:
	var s := get_viewport_rect().size
	return params.range_frac * minf(s.x, s.y) * 0.5


func _physics_process(delta: float) -> void:
	time += delta
	var damp := exp(-params.damping * delta)
	for b in bodies:
		if b.orbit_r > 0.0:
			var ang: float = b.phase + time * b.speed
			b.pos = b.anchor + Vector2.from_angle(ang) * b.orbit_r
			b.vel = Vector2.from_angle(ang + PI / 2.0) * b.orbit_r * b.speed
		else:
			b.pos += b.vel * delta
			b.vel *= damp
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
	rubbley += rub_vel * delta
	rub_vel *= damp
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
		aim_point = rubbley
		return
	last_tilt_ms = now
	var dir := stick / stick.length()
	var rng := range_px()
	var t := -1
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
	aim_target = t
	if t >= 0:
		aim_kind = Aim.BODY
		aim_point = bodies[t].pos
	else:
		aim_kind = Aim.POINT
		aim_point = rubbley + aim_offset


func _cone_pick(dir: Vector2) -> int:
	var half: float = params.cone_deg * 0.5
	var reach: float = range_px() * params.reach_frac
	if aim_target >= 0:
		var to: Vector2 = bodies[aim_target].pos - rubbley
		if to.length() <= reach and rad_to_deg(absf(dir.angle_to(to))) <= half + params.hysteresis_deg:
			return aim_target
	var best := -1
	var best_score := INF
	for i in bodies.size():
		var b = bodies[i]
		if not b.glow:
			continue
		var to: Vector2 = b.pos - rubbley
		var d := to.length()
		if d > reach or d < 1.0:
			continue
		var ang := rad_to_deg(absf(dir.angle_to(to)))
		if ang > half:
			continue
		var score: float = ang + params.dist_bias_deg * d / reach
		if score < best_score:
			best_score = score
			best = i
	return best


func _snap_pick(p: Vector2) -> int:
	if aim_target >= 0 and bodies[aim_target].pos.distance_to(p) <= params.snap_px * 1.5 + bodies[aim_target].r:
		return aim_target
	var best := -1
	var best_d := INF
	for i in bodies.size():
		var b = bodies[i]
		if not b.glow:
			continue
		var d: float = b.pos.distance_to(p) - b.r
		if d <= params.snap_px and d < best_d:
			best_d = d
			best = i
	return best


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
	if attract_held and held_kind == Aim.BODY and held_target >= 0:
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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK, JOY_BUTTON_RIGHT_SHOULDER:
				_set_mode((mode + 1) % 3)
			JOY_BUTTON_LEFT_SHOULDER:
				_set_mode((mode + 2) % 3)
			JOY_BUTTON_DPAD_UP:
				param_index = (param_index + PARAM_ORDER.size() - 1) % PARAM_ORDER.size()
			JOY_BUTTON_DPAD_DOWN:
				param_index = (param_index + 1) % PARAM_ORDER.size()
			JOY_BUTTON_DPAD_LEFT:
				_adjust(-1)
			JOY_BUTTON_DPAD_RIGHT:
				_adjust(1)
			JOY_BUTTON_A, JOY_BUTTON_B:
				effects.append({"kind": "spin", "pos": rubbley, "t0": time})
				last_fired = "Spin"
			JOY_BUTTON_X:
				layout_seed += 1
				_regen()
			JOY_BUTTON_Y:
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
			KEY_P: print(JSON.stringify({"mode": MODE_NAMES[mode], "params": params}))


func _set_mode(m: int) -> void:
	mode = m as Mode
	aim_target = -1


func _adjust(sign: int) -> void:
	var k: String = PARAM_ORDER[param_index]
	params[k] = maxf(0.0, snappedf(params[k] + sign * STEPS[k], 0.001))


func _process(_delta: float) -> void:
	camera.position = rubbley + nudge_offset
	gizmo.queue_redraw()
	queue_redraw()
	var lines := PackedStringArray()
	lines.append("PROTOTYPE controller aim  |  mode: %s  (LB/RB or Back)" % MODE_NAMES[mode])
	lines.append("pad: %s" % (Input.get_joy_name(dev) if Input.get_connected_joypads().size() > 0 else "NONE CONNECTED"))
	lines.append("stick %s  len %.2f  tilt %.2f  %s" % [_fmt(stick, 2), stick_len, tilt, "active" if stick_active else ("grace" if in_grace else "rest")])
	var tname: String = bodies[aim_target].name if aim_target >= 0 else "-"
	lines.append("aim: %s  target %s  offset %s" % [["SELF", "BODY", "POINT"][aim_kind], tname, _fmt(aim_point - rubbley)])
	var held := "-"
	if attract_held:
		held = ["self", "body " + (bodies[held_target].name if held_target >= 0 else "?"), ""][held_kind] if held_kind >= 0 else "(well placed)"
	lines.append("attract held: %s   last fired: %s" % [held, last_fired])
	lines.append("Rubbley speed %.0f px/s" % rub_vel.length())
	lines.append("")
	for i in PARAM_ORDER.size():
		var k: String = PARAM_ORDER[i]
		lines.append("%s %-18s %s" % [">" if i == param_index else " ", k, str(params[k])])
	lines.append("")
	lines.append("LT Attract  RT Repel  A/B Spin  R-stick Nudge  D-pad tune  X new layout  Y drift %s  Start reset  (P prints params)" % ("on" if drift else "off"))
	hud.text = "\n".join(lines)


func _draw() -> void:
	var rng := range_px()
	draw_arc(rubbley, rng, 0.0, TAU, 128, Color(1, 1, 1, 0.25), 2.0)
	if mode != Mode.ABSOLUTE and stick_active:
		var dir := stick / stick.length()
		var half := deg_to_rad(params.cone_deg * 0.5)
		var reach: float = rng * params.reach_frac
		var pts := PackedVector2Array([rubbley])
		for i in 17:
			pts.append(rubbley + dir.rotated(lerpf(-half, half, i / 16.0)) * reach)
		draw_colored_polygon(pts, Color(0.4, 0.8, 1.0, 0.08))
		draw_arc(rubbley, reach, dir.angle() - half, dir.angle() + half, 24, Color(0.4, 0.8, 1.0, 0.3), 1.0)
	if mode == Mode.ABSOLUTE and stick_active:
		draw_arc(raw_point, params.snap_px, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, 0.4), 1.0)
		draw_circle(raw_point, 3.0, Color(0.4, 0.8, 1.0, 0.6))

	for i in bodies.size():
		var b = bodies[i]
		if b.glow:
			draw_circle(b.pos, b.r + 6.0, Color(1.0, 0.85, 0.3, 0.15))
			draw_circle(b.pos, b.r, Color(1.0, 0.8, 0.25))
		else:
			draw_circle(b.pos, b.r, Color(0.45, 0.45, 0.5))
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
