class_name Level
extends Node3D
## What every level shows Main, which owns the UI layer (ADR 0016): the Rubbley in it, for
## the HUD to watch, plus the stage seed that seeds bodies placed directly in the level
## scene (ADR 0018).

## The level's Rubbley, through his Mass, which leads to his live Stats and moves.
@export var rubbley_mass: RubbleyMass
## Seeds bodies placed directly in this level scene (Rubbley, planets, loose debris), so
## building the same level twice yields identical looks and starting spins (ADR 0018).
@export var stage_seed := 1


func _ready() -> void:
	var stage_rng := RandomNumberGenerator.new()
	stage_rng.seed = stage_seed
	_seed_placed_nodes(self, stage_rng)


# Walks the level in deterministic tree order, seeding any body or debris look that was
# not already seeded by its own spawner (such as a [DebrisField]).
func _seed_placed_nodes(node: Node, stage_rng: RandomNumberGenerator) -> void:
	var body := node as PlayPlaneBody
	if body != null and not body.is_spin_seeded():
		body.apply_starting_spin(stage_rng)
	var look := node as DebrisLook
	if look != null and not look.is_seeded():
		look.apply_look(stage_rng)
	for child in node.get_children():
		_seed_placed_nodes(child, stage_rng)
