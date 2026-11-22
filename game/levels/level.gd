class_name Level
extends Node3D
## What every level shows Main, which owns the UI layer (ADR 0016): the Rubbley in it, for
## the HUD to watch.

## The level's Rubbley, through his Mass, which leads to his live Stats and moves.
@export var rubbley_mass: RubbleyMass
