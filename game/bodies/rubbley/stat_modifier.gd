class_name StatModifier
extends Resource
## One change to one of Rubbley's Stats (ADR 0017), added or multiplied, for good or for a
## set time. Owned upgrades, in-level power-ups and consumables are all Stat Modifiers.
## Read-only at runtime.

## How a modifier changes its Stat. [RubbleyStatsBuilder] applies every add before any
## multiply.
enum Operation {
	ADD,
	MULTIPLY,
}

## The Stat it changes.
@export var stat := RubbleyStats.Stat.STAMINA_MAX
## Whether [member value] is added to the Stat or multiplies it.
@export var operation := Operation.ADD
## The amount added, in the Stat's own unit, or the factor it is multiplied by.
@export var value := 0.0
## How long it lasts once added, in seconds. 0 lasts for good.
@export_range(0.0, 600.0, 0.1, "or_greater") var duration_s := 0.0
