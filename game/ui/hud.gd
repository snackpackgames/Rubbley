class_name Hud
extends CanvasLayer
## The placeholder HUD in the top left: a green Stamina bar, which flashes red all over
## when Rubbley refuses a move for want of Stamina, empty part and outline too, since an
## empty bar has no fill to show it, and a Mass bar showing where his Mass sits
## between his least and most. It reads Rubbley's live Stats and Mass each frame, and
## listens to [RubbleyMoves] for refusals. It scales with the screen's short side.

## The short side, in pixels, at which the HUD is drawn at its authored size.
const REFERENCE_SHORT_SIDE_PX := 720.0

## Rubbley's live Stats, for his Stamina and its max, and his Mass limits.
@export var live_stats: RubbleyLiveStats
## Rubbley's Mass.
@export var mass: RubbleyMass
## Rubbley's moves, which signal a refusal.
@export var moves: RubbleyMoves
## The bars' container, scaled with the screen.
@export var panel: Control
## The Stamina bar.
@export var stamina_bar: HudBar
## The Mass bar.
@export var mass_bar: HudBar
## The Stamina bar's colour.
@export var stamina_color := Color(0.35, 0.9, 0.4)
## The colour the Stamina bar flashes when a move is refused.
@export var refused_color := Color(1.0, 0.2, 0.2)
## How long the refusal flash takes to fade, in seconds.
@export_range(0.05, 2.0, 0.01) var refused_flash_s := 0.4

var _refused: FadeFlash
# The Stamina bar's own empty-part and outline colours, which the flash tints.
var _back_color: Color
var _outline_color: Color


func _ready() -> void:
	assert(live_stats != null, "%s needs RubbleyLiveStats" % name)
	assert(mass != null, "%s needs RubbleyMass" % name)
	assert(moves != null, "%s needs RubbleyMoves" % name)
	assert(panel != null and stamina_bar != null and mass_bar != null, "%s needs bars" % name)
	_refused = FadeFlash.new(refused_flash_s)
	_back_color = stamina_bar.back_color
	_outline_color = stamina_bar.outline_color
	moves.move_refused.connect(_refused.strike)


func _process(delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	panel.scale = Vector2.ONE * maxf(minf(screen.x, screen.y) / REFERENCE_SHORT_SIDE_PX, 1.0)
	var stats := live_stats.effective
	stamina_bar.value = live_stats.stamina.current() / stats.stamina_max
	_refused.advance(delta)
	var flash := _refused.strength()
	stamina_bar.fill_color = stamina_color.lerp(refused_color, flash)
	stamina_bar.back_color = _back_color.lerp(Color(refused_color, 0.6), flash)
	stamina_bar.outline_color = _outline_color.lerp(refused_color, flash)
	mass_bar.value = inverse_lerp(stats.min_mass_kg, stats.max_mass_kg, mass.body.mass)
