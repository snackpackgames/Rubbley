class_name RubbleyHitFlash
extends Node
## Flashes Rubbley's rock when a hit hurts him, so every hit reads on screen: a tint over
## the rock that jumps to full and fades out ([FadeFlash]). It listens to [RubbleyMass].

## The flash's colour and length.
@export var tuning: HitFlashTuning
## Rubbley's Mass, which signals each hit.
@export var mass: RubbleyMass
## Rubbley's rock, which the flash tints through its material overlay.
@export var mesh: GeometryInstance3D

var _flash: FadeFlash
var _overlay := StandardMaterial3D.new()


func _ready() -> void:
	assert(tuning != null, "%s needs HitFlashTuning" % name)
	assert(mass != null, "%s needs RubbleyMass" % name)
	assert(mesh != null, "%s needs a mesh" % name)
	_flash = FadeFlash.new(tuning.duration_s)
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(tuning.color, 0.0)
	mass.hurt.connect(_on_hurt)


func _process(delta: float) -> void:
	_flash.advance(delta)
	var now := _flash.strength()
	_overlay.albedo_color.a = tuning.color.a * now
	mesh.material_overlay = _overlay if now > 0.0 else null


## How strong the flash is now, from 1 just hurt to 0 once faded.
func strength() -> float:
	return _flash.strength()


func _on_hurt(_lost_kg: float) -> void:
	_flash.strike()
