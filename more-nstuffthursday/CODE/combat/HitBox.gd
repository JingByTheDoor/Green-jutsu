# res://CODE/combat/HitBox.gd
extends Area2D
class_name HitBox


signal hit_confirmed(target: Node, damage: int)

# --- Local faction + layer setup (no external Layers singleton needed) ---
enum Faction { PLAYER, ENEMY }

# Layer *indices* (1..32). You set 4096 (2^12) on enemy hurtbox, i.e. index 13.
# Use the *actual* indices from your scenes
const LAYER_PLAYER_HURTBOX := 12
const LAYER_ENEMY_HURTBOX  := 13
const LAYER_PLAYER_HITBOX  := 14
const LAYER_ENEMY_HITBOX   := 15


# ------------------------------------------------------------------------
var attacker_stats: Stats = null        # your Stats resource
var hitlog: HitLog = null     
var lifetime: float = 0.08

var faction: int = Faction.PLAYER

# Optional: call this right after .new() to configure
func setup(_stats: Stats, _life: float, _hitlog: HitLog, _faction: int) -> HitBox:
	attacker_stats = _stats
	lifetime = _life
	hitlog = _hitlog
	faction = _faction
	return self

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask  = 0

	# Put this hitbox on the correct layer and target opposite hurtboxes
	if faction == Faction.PLAYER:
		set_collision_layer_value(LAYER_PLAYER_HITBOX, true)
		set_collision_mask_value(LAYER_ENEMY_HURTBOX,  true)
	else:
		set_collision_layer_value(LAYER_ENEMY_HITBOX, true)
		set_collision_mask_value(LAYER_PLAYER_HURTBOX, true)

	# Ensure we actually have a collision shape (you can also add it from the spawner)
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		# Default rectangle; your spawner can override this shape before adding the node
		var rect := RectangleShape2D.new()
		rect.size = Vector2(70, 40)
		cs.shape = rect
		add_child(cs)

	# Auto-despawn after lifetime
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(self.queue_free)

	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	
	# Avoid multi-hitting the same target during this hitbox life
	if hitlog and hitlog.has_method("has_hit") and hitlog.has_hit(area):
		return

	# Deliver damage via the target's receive_hit (your HurtBox provides this)
	var dmg: int = 1
	if attacker_stats != null:
		dmg = int(round(attacker_stats.current_attack))  # adjust to your field name


	if area.has_method("receive_hit"):
		area.receive_hit(dmg, self)
		emit_signal("hit_confirmed", area, dmg)   # ← add this line
	
	if hitlog and hitlog.has_method("log_hit"):
		hitlog.log_hit(area)
