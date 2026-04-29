extends Area2D
class_name Hurtbox

signal hit_received(damage: int, source: Node)

@export var stats: Node = null          # change to your Stats type if you have one
@export var faction: int = 0            # 0 = player, 1 = enemy (or match your enum)

const LAYER_PLAYER_HURTBOX: int = 12    # adjust to your indices
const LAYER_ENEMY_HURTBOX:  int = 13

func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 0
	collision_mask  = 0

	var f: int = faction                  # <-- explicitly typed, no Variant inference
	if f == 0:
		set_collision_layer_value(LAYER_PLAYER_HURTBOX, true)
	else:
		set_collision_layer_value(LAYER_ENEMY_HURTBOX, true)

func receive_hit(damage: int, source: Node = null) -> void:
	# if you track hp on stats, do it here strictly typed
	if stats != null and stats.has_variable("health"):
		var hp: int = int(stats.health)
		hp -= damage
		stats.health = hp
	emit_signal("hit_received", damage, source)

	# notify owner in a neutral way
	if owner != null and owner.has_method("on_hurt"):
		owner.on_hurt(damage, source)

	# optional kill on zero hp
	if stats != null and stats.has_variable("health") and int(stats.health) <= 0:
		get_parent().queue_free()
