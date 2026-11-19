class_name Hud
extends CanvasLayer
## The placeholder HUD in the top left, in Main's UI layer, so it outlives levels (ADR
## 0016). Main tells it which Rubbley to watch when a level loads. It shows:
## [br]- a green Stamina bar, which flashes red all over when Rubbley refuses a move for
## want of Stamina, empty part and outline too, since an empty bar has no fill to show it;
## [br]- a Mass bar, where his Mass sits between his least and most, in kg;
## [br]- a Size bar, where his radius sits between his least and most, by his Stats'
## Mass→size curve, so it moves as much as he visibly grows or shrinks.
## [br]Each of the last two can be turned off. It reads Rubbley's live Stats and Mass
## each frame, listens to [RubbleyMoves] for refusals, and scales with the screen's
## short side.

## The short side, in pixels, at which the HUD is drawn at its authored size.
const REFERENCE_SHORT_SIDE_PX := 720.0

## The bars' container, scaled with the screen.
@export var panel: Control
## The Stamina bar.
@export var stamina_bar: HudBar
## The Mass bar, by kg, and its label.
@export var mass_bar: HudBar
@export var mass_label: Control
## The Size bar, by radius, and its label.
@export var size_bar: HudBar
@export var size_label: Control
## Whether the Mass bar shows.
@export var show_mass_bar := true:
	set(on):
		show_mass_bar = on
		_show_bars()
## Whether the Size bar shows.
@export var show_size_bar := true:
	set(on):
		show_size_bar = on
		_show_bars()
## The Stamina bar's colour.
@export var stamina_color := Color(0.35, 0.9, 0.4)
## The colour the Stamina bar flashes when a move is refused.
@export var refused_color := Color(1.0, 0.2, 0.2)
## How long the refusal flash takes to fade, in seconds.
@export_range(0.05, 2.0, 0.01) var refused_flash_s := 0.4

# The Rubbley being watched, through his Mass, or null between levels.
var _mass: RubbleyMass
var _refused: FadeFlash
# The Stamina bar's own empty-part and outline colours, which the flash tints.
var _back_color: Color
var _outline_color: Color


func _ready() -> void:
	assert(panel != null and stamina_bar != null, "%s needs a Stamina bar" % name)
	assert(mass_bar != null and size_bar != null, "%s needs Mass and Size bars" % name)
	_refused = FadeFlash.new(refused_flash_s)
	_back_color = stamina_bar.back_color
	_outline_color = stamina_bar.outline_color
	panel.visible = false
	_show_bars()


func _process(delta: float) -> void:
	if not is_watching():
		return
	var screen := get_viewport().get_visible_rect().size
	panel.scale = Vector2.ONE * maxf(minf(screen.x, screen.y) / REFERENCE_SHORT_SIDE_PX, 1.0)
	var stats := _mass.live_stats.effective
	stamina_bar.value = _mass.live_stats.stamina.current() / stats.stamina_max
	_refused.advance(delta)
	var flash := _refused.strength()
	stamina_bar.fill_color = stamina_color.lerp(refused_color, flash)
	stamina_bar.back_color = _back_color.lerp(Color(refused_color, 0.6), flash)
	stamina_bar.outline_color = _outline_color.lerp(refused_color, flash)
	mass_bar.value = inverse_lerp(stats.min_mass_kg, stats.max_mass_kg, _mass.body.mass)
	var least_m := stats.mass_to_radius_m.sample(stats.min_mass_kg)
	var most_m := stats.mass_to_radius_m.sample(stats.max_mass_kg)
	size_bar.value = inverse_lerp(least_m, most_m, _mass.radius_m())


## Shows [param mass]'s Rubbley: his Stamina, Mass and size, and his refused moves.
## Main calls it when a level loads.
func watch(mass: RubbleyMass) -> void:
	unwatch()
	_mass = mass
	_mass.moves.move_refused.connect(_refused.strike)
	panel.visible = true


## Stops showing a Rubbley and hides the bars. Main calls it before unloading a level.
func unwatch() -> void:
	if is_instance_valid(_mass) and _mass.moves.move_refused.is_connected(_refused.strike):
		_mass.moves.move_refused.disconnect(_refused.strike)
	_mass = null
	panel.visible = false


## Whether the HUD is showing a Rubbley.
func is_watching() -> bool:
	return is_instance_valid(_mass)


func _show_bars() -> void:
	if mass_bar == null or size_bar == null:
		return
	mass_bar.visible = show_mass_bar
	mass_label.visible = show_mass_bar
	size_bar.visible = show_size_bar
	size_label.visible = show_size_bar
