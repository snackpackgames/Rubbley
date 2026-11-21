extends SimulationTestSuite
## The placeholder HUD on the shipped Rubbley and HUD scenes: its bars show Rubbley's
## Stamina, where his Mass sits between his limits and where his size does, and the
## Stamina bar flashes red when he refuses a move for want of Stamina.

const RUBBLEY_SCENE := preload("res://game/bodies/rubbley/rubbley.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")
const TOLERANCE := 0.02

var _world: Node3D
var _rubbley: PlayPlaneBody
var _live_stats: RubbleyLiveStats
var _hud: Hud
var _frame: MoveInputFrame


## Builds Rubbley reading injected frames, with the HUD watching him.
func before_test() -> void:
	_world = auto_free(Node3D.new())
	add_child(_world)
	_rubbley = RUBBLEY_SCENE.instantiate()
	_world.add_child(_rubbley)
	_live_stats = _rubbley.get_node("LiveStats") as RubbleyLiveStats
	var moves := _rubbley.get_node("Moves") as RubbleyMoves
	_frame = MoveInputFrame.new()
	moves.injected_frame = _frame
	_hud = HUD_SCENE.instantiate()
	_world.add_child(_hud)
	_hud.watch(_rubbley.get_node("Mass") as RubbleyMass)


## The Stamina bar shows the share of Stamina left, the Mass bar where his Mass sits
## between his least and most, and the Size bar where his radius sits between the radii
## of those Masses.
func test_the_bars_show_stamina_and_mass() -> void:
	var stats := _live_stats.effective
	_live_stats.stamina.spend(stats.stamina_max * 0.75)
	await get_tree().process_frame
	var mass_share := inverse_lerp(stats.min_mass_kg, stats.max_mass_kg, _rubbley.mass)
	assert_float(_hud.stamina_bar.value).is_equal_approx(0.25, TOLERANCE)
	assert_float(_hud.mass_bar.value).is_equal_approx(mass_share, TOLERANCE)
	assert_float(_hud.mass_bar.value).is_between(0.01, 0.99)
	var size_m := stats.mass_to_radius_m
	var size_share := inverse_lerp(
		size_m.sample(stats.min_mass_kg),
		size_m.sample(stats.max_mass_kg),
		size_m.sample(_rubbley.mass),
	)
	assert_float(_hud.size_bar.value).is_equal_approx(size_share, TOLERANCE)
	assert_float(_hud.size_bar.value).is_between(0.01, 0.99)


## A refused move turns the Stamina bar red, its empty part too, since a refusal comes
## when it is near empty, and it fades back.
func test_a_refused_move_flashes_the_stamina_bar_red() -> void:
	var resting := _hud.stamina_bar.fill_color
	var resting_back := _hud.stamina_bar.back_color
	_live_stats.stamina.spend(_live_stats.stamina.current())
	await get_tree().physics_frame
	_frame.repel_fired = true
	await get_tree().physics_frame
	_frame.repel_fired = false
	await get_tree().process_frame
	var flashed := _hud.stamina_bar.fill_color
	var flashed_back := _hud.stamina_bar.back_color
	await step_seconds(_hud.refused_flash_s + 0.1)

	assert_float(flashed.r).is_greater(flashed.g)
	assert_float(flashed_back.r).is_greater(flashed_back.g + 0.3)
	assert_float(resting.g).is_greater(resting.r)
	assert_bool(_hud.stamina_bar.fill_color.is_equal_approx(resting)).is_true()
	assert_bool(_hud.stamina_bar.back_color.is_equal_approx(resting_back)).is_true()


## Unwatched, the HUD hides its bars and ignores the Rubbley it watched.
func test_unwatching_hides_the_bars() -> void:
	_hud.unwatch()
	await get_tree().process_frame
	assert_bool(_hud.is_watching()).is_false()
	assert_bool(_hud.panel.visible).is_false()


## Either of the Mass and Size bars can be turned off, label and all.
func test_the_mass_and_size_bars_can_be_turned_off() -> void:
	_hud.show_mass_bar = false
	var mass_shown := _hud.mass_bar.visible or _hud.mass_label.visible
	_hud.show_mass_bar = true
	_hud.show_size_bar = false
	assert_bool(mass_shown).is_false()
	assert_bool(_hud.mass_bar.visible).is_true()
	assert_bool(_hud.size_bar.visible or _hud.size_label.visible).is_false()


## The shipped HUD shows his size as his Health, and keeps the Mass bar off.
func test_the_shipped_hud_shows_size_as_health_and_hides_mass() -> void:
	assert_bool(_hud.size_bar.visible).is_true()
	assert_str((_hud.size_label as Label).text).is_equal("HEALTH")
	assert_bool(_hud.mass_bar.visible or _hud.mass_label.visible).is_false()
