class_name Level
extends Node3D
## What every level shows Main, which owns the UI layer (ADR 0016): the Rubbley in it, for
## the HUD to watch, plus the stage seed that seeds every [Rng] node in the level scene
## (ADR 0018).

## The level's Rubbley, through his Mass, which leads to his live Stats and moves.
@export var rubbley_mass: RubbleyMass
## Seeds every [Rng] node in this level (Rubbley, planets, debris fields and loose debris),
## so building the same level twice yields identical looks, layouts and spins (ADR 0018).
@export var stage_seed := 1


func _ready() -> void:
	var stage_rng := RandomNumberGenerator.new()
	stage_rng.seed = stage_seed
	Rng.seed_subtree(self, stage_rng)
