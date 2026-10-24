class_name CameraZone
extends Area3D
## A Camera Zone (ADR 0007): a region of a level that widens the view while Rubbley is
## inside it. It joins the [code]camera_zones[/code] group, which the [CameraRig] reads
## every frame.

## The group every [CameraZone] joins.
const GROUP := &"camera_zones"

## How the view is framed while Rubbley is inside.
@export var framing: CameraZoneFraming


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	assert(framing != null, "%s needs a CameraZoneFraming" % name)
