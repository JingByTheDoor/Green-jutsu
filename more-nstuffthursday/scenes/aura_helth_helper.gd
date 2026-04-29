extends Node

@export var stats: Stats

# in Player.gd (strict-typed)
@onready var aura: Aura = get_node_or_null("Aura") as Aura  # ← adjust the path

func _physics_process(delta: float) -> void:
	# 1) Update Aura from movement
	if aura != null and stats != null:
		# allow_gain: true when normal regen is allowed (e.g., not during dash lock)
		var allow_gain: bool = true
		var extra_drain_sec: float = 0.0  # set >0 to drain while dashing, etc.

		aura.tick_gated(
			delta,
			velocity,                          # your CharacterBody2D velocity
			stats.current_move_speed,          # max run speed from Stats
			is_on_floor(),
			allow_gain,
			extra_drain_sec
		)

		# 2) Push Aura → Stats.health (positive side is health, negative = 0 HP)
		var hp_target: float = clampf(maxf(aura.meter, 0.0), 0.0, stats.current_max_health)
		if not is_equal_approx(hp_target, stats.health):
			stats.health = hp_target
