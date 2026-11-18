class_name RubbleyAbsorbPop
extends Node
## Swells Rubbley's mesh each time he absorbs debris, so every pickup reads on screen. It
## adapts [AbsorbPop] to the scene: [RubbleyMass] signals each absorb, and the pop scales
## a pivot above the mesh, so it never fights the size [RubbleyMass] sets on the mesh.

## How far and how long the mesh swells.
@export var tuning: AbsorbPopTuning
## Rubbley's Mass, which signals each absorb.
@export var mass: RubbleyMass
## The pivot holding Rubbley's mesh, scaled by the pop.
@export var pivot: Node3D

var _pop: AbsorbPop


func _ready() -> void:
	assert(tuning != null, "%s needs AbsorbPopTuning" % name)
	assert(mass != null, "%s needs RubbleyMass" % name)
	assert(pivot != null, "%s needs a pivot" % name)
	_pop = AbsorbPop.new(tuning)
	mass.absorbed.connect(_on_absorbed)


func _process(delta: float) -> void:
	_pop.advance(delta)
	pivot.scale = Vector3.ONE * _pop.scale()


func _on_absorbed(_mass_kg: float) -> void:
	_pop.start()
