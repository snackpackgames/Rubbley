class_name RubbleyStats
extends Resource
## Rubbley's numbers that advancement can change (ADR 0017): his Stamina, what each move
## costs and his Gravega values. Read-only at runtime: [RubbleyStatsBuilder] folds Stat
## Modifiers over a copy. Mass joins them with its feature.

## Every Stat a [StatModifier] can change, one per field below. Adding a Stat means adding
## its field, its entry here and its arm in [RubbleyStatsBuilder].
enum Stat {
	STAMINA_MAX,
	STAMINA_REGEN_PER_SECOND,
	STAMINA_REGEN_DELAY_S,
	ATTRACT_SELF_DRAIN_PER_SECOND,
	ATTRACT_CELESTIAL_DRAIN_PER_SECOND,
	REPEL_COST,
	REPEL_PULSE_COST,
	SPIN_COST,
	ATTRACT_SELF_MULTIPLIER,
	ATTRACT_CELESTIAL_MULTIPLIER,
	GRAVITY_WELL_STRENGTH_M_PER_S2,
	GRAVITY_WELL_RADIUS_M,
	GRAVITY_WELL_DURATION_S,
	GRAVITY_WELL_FADE_S,
	REPEL_PULSE_SPEED_M_PER_S,
	REPEL_PULSE_RADIUS_M,
	REPEL_PULSE_STUN_S,
	GRAVITY_RIPPLE_SPEED_M_PER_S,
	GRAVITY_RIPPLE_RADIUS_M,
	RADIAL_REPEL_REFERENCE_MASS_KG,
	RADIAL_REPEL_MASS_FALLOFF,
	TARGETED_REPEL_IMPULSE_N_S,
}

## The most Stamina Rubbley can hold. Every move draws on this one pool.
@export_range(1.0, 1000.0, 0.1, "or_greater") var stamina_max := 100.0
## How fast Stamina refills while no move uses it, per second.
@export_range(0.0, 1000.0, 0.1, "or_greater") var stamina_regen_per_second := 25.0
## How long after a move last used Stamina before it starts to refill, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater") var stamina_regen_delay_s := 0.0
## The Stamina Attract on self drains per second while held.
@export_range(0.0, 1000.0, 0.1, "or_greater") var attract_self_drain_per_second := 20.0
## The Stamina a Targeted Attract on a glowing Celestial Body drains per second while
## held. Lower than on self (GDD).
@export_range(0.0, 1000.0, 0.1, "or_greater") var attract_celestial_drain_per_second := 10.0
## The Stamina a Targeted Repel or a Gravity Ripple costs. A Gravity Well costs half the
## current Stamina instead, a rule in [RubbleyMoves] rather than a Stat.
@export_range(0.0, 1000.0, 0.1, "or_greater") var repel_cost := 15.0
## The Stamina a Repel Pulse costs.
@export_range(0.0, 1000.0, 0.1, "or_greater") var repel_pulse_cost := 25.0
## The Stamina one Spin costs. A Spin its lockout refuses costs nothing.
@export_range(0.0, 1000.0, 0.1, "or_greater") var spin_cost := 10.0

## The Gravega multiplier on every pair Rubbley is in while he Attracts on self.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_self_multiplier := 3.0
## The Gravega multiplier on Rubbley's pair with a glowing Celestial Body while he
## Attracts it. The body's other pairs keep their pull.
@export_range(1.0, 10.0, 0.01, "or_greater") var attract_celestial_multiplier := 2.0
## How hard a Gravity Well pulls at its centre, in m/s². The pull falls off to nothing
## at its edge. Strong enough to fling Rubbley through, which can leave him nearly
## stopped against Drift for a while after it ends (ADR 0018).
@export_range(0.0, 200.0, 0.1, "or_greater") var gravity_well_strength_m_per_s2 := 50.0
## How far a Gravity Well reaches, in metres.
@export_range(0.1, 100.0, 0.1, "or_greater") var gravity_well_radius_m := 24.0
## How long a Gravity Well pulls at full strength, in seconds.
@export_range(0.1, 30.0, 0.1, "or_greater") var gravity_well_duration_s := 3.0
## How long a Gravity Well's pull then takes to fade to nothing, in seconds.
@export_range(0.0, 30.0, 0.1, "or_greater") var gravity_well_fade_s := 0.0
## The speed change a Repel Pulse gives a body at Rubbley's centre, in m/s, falling off
## to nothing at its radius; bodies past the reference mass take less. The controller-aim
## prototype's 800 px/s.
@export_range(0.0, 100.0, 0.1, "or_greater") var repel_pulse_speed_m_per_s := 36.4
## How far a Repel Pulse reaches from Rubbley, in metres. The prototype's 380 px.
@export_range(0.1, 100.0, 0.1, "or_greater") var repel_pulse_radius_m := 17.3
## How long a Repel Pulse stuns what it reaches, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater") var repel_pulse_stun_s := 1.5
## The speed change a Gravity Ripple gives a body at its centre, in m/s, Rubbley's
## included, falling off to nothing at its radius; bodies past the reference mass take
## less. Weaker than a Repel Pulse.
@export_range(0.0, 100.0, 0.1, "or_greater") var gravity_ripple_speed_m_per_s := 27.3
## How far a Gravity Ripple reaches, in metres.
@export_range(0.1, 100.0, 0.1, "or_greater") var gravity_ripple_radius_m := 17.3
## The heaviest a body can be and still take a Repel Pulse's or Gravity Ripple's whole
## speed change, in kg. Heavier bodies take less, by [member radial_repel_mass_falloff].
## Five times Rubbley's 10 kg, so debris, Rubbley and small planets all take the whole push.
@export_range(0.1, 1000.0, 0.1, "or_greater") var radial_repel_reference_mass_kg := 50.0
## How fast a heavier body's share of a radial push shrinks: (reference ÷ mass) to this.
## 0 pushes every body alike, as in the prototype; 1 gives bodies past the reference mass
## the same impulse. At 0.5 a 400 kg planet takes about a third, picked from recorded
## variants as moving heavy planets noticeably but slowly.
@export_range(0.0, 2.0, 0.01, "or_greater") var radial_repel_mass_falloff := 0.5
## The impulse a Targeted Repel pushes Rubbley and its target apart with, in N·s; each moves
## by it divided by its own mass. The prototype's 550 px/s slingshot on Rubbley's 10 kg.
@export_range(0.0, 2000.0, 1.0, "or_greater") var targeted_repel_impulse_n_s := 250.0
