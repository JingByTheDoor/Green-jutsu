extends CharacterBody2D

@onready var sfx_hit: AudioStreamPlayer2D        = $SFX/HitConfirm1
var _next_step_time := 0.0

@export var attack_fire_frame: int = 3

@export var clip_idle:   StringName = &"idle"
@export var clip_move:   StringName = &"run"      # set to &"walk" if that’s your name
@export var clip_attack: StringName = &"attack"   # change to &"slash" etc. if needed
@export var clip_hurt:   StringName = &"hurt"
@export var clip_dead:   StringName = &"dead"
@export var invert_facing: bool = true           # tick if your art faces left by default

@onready var sprite: AnimatedSprite2D   = get_node_or_null("AnimatedSprite2D")
@onready var anim:   AnimationPlayer    = get_node_or_null("AnimationPlayer")


# --- Project dependencies (update paths if yours differ) ---
const HitBox := preload("res://CODE/combat/HitBox.gd")
const HitLog := preload("res://CODE/combat/HitLog.gd")
# Stats is assumed to have `class_name Stats` elsewhere in your project.



# --- Tuning ---
@export var stats: Stats
@export var move_speed: float = 90.0
@export var chase_speed: float = 135.0
@export var accel: float = 900.0
@export var friction: float = 1200.0
@export var gravity: float = 1600.0
@export var max_fall_speed: float = 2200.0

@export var detection_range: float = 220.0
@export var attack_range: float = 46.0
@export var attack_windup: float = 0.12
@export var attack_lifetime: float = 0.10
@export var attack_cooldown: float = 0.60
@export var attack_offset: Vector2 = Vector2(32, -6)  # relative to enemy origin

# Knockback + stun when hit
@export var stun_time: float = 0.18
@export var knockback_speed: Vector2 = Vector2(180.0, -140.0)

# --- Scene wiring (override in Inspector if your paths differ) ---
@export var hurtbox_path: NodePath = ^"HurtBox"
@export var patrol_a_path: NodePath
@export var patrol_b_path: NodePath
@export var attack_shape_path: NodePath  # e.g. ^"Attack/CollisionShape2D"
@export var attack_shape: Shape2D        # alternative to NodePath; use either

@export var target_group: StringName = &"player"

# --- Optional visuals ---


# --- Resolved nodes ---
@onready var hurtbox: Hurtbox      = get_node_or_null(hurtbox_path) as Hurtbox
@onready var patrol_a: Node2D      = get_node_or_null(patrol_a_path) as Node2D
@onready var patrol_b: Node2D      = get_node_or_null(patrol_b_path) as Node2D
@onready var attack_src: CollisionShape2D = get_node_or_null(attack_shape_path) as CollisionShape2D

# --- State machine ---
enum State { IDLE, PATROL, CHASE, ATTACK, STUN, DEAD }
var state: int = State.PATROL
var facing_dir: int = 1  # -1 = left, 1 = right

# --- Timers (seconds) ---
var cooldown_left: float = 0.0
var windup_left: float = 0.0
var active_left: float = 0.0
var stun_left: float = 0.0

# --- Internals ---
var _patrol_target: Node2D
var _attack_fired: bool = false

func _ready() -> void:
	
	print_rich(
	"[color=khaki]AnimPlayer attack:[/color] ", anim != null and anim.has_animation(String(clip_attack)),
	"   [color=khaki]SpriteFrames attack:[/color] ", sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(String(clip_attack))
)


	if sprite != null and not sprite.is_connected("frame_changed", Callable(self, "_on_sprite_frame_changed")):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	
	add_to_group(&"enemies")

	# Stats sanity
	if stats != null:
		stats.recalculate_stats()
		if stats.health <= 0.0:
			stats.fill_health()

	# Hurtbox signal -> call our on_hurt pipeline
	if hurtbox != null and not hurtbox.is_connected("hit_received", Callable(self, "_on_hit_received")):
		hurtbox.hit_received.connect(_on_hit_received)

	# Start patrol only if both points exist, else idle
	if patrol_a != null and patrol_b != null:
		_patrol_target = patrol_b
		state = State.PATROL
	else:
		state = State.IDLE

func _physics_process(delta: float) -> void:
	# Timers decrement
	if cooldown_left > 0.0: cooldown_left -= delta
	if windup_left   > 0.0: windup_left   -= delta
	if active_left   > 0.0: active_left   -= delta
	if stun_left     > 0.0: stun_left     -= delta

	# Gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# FSM
	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.STUN:
			_process_stun(delta)
		State.DEAD:
			velocity = velocity * 0.9  # simple damp
			move_and_slide()
			return

	# Move and animate
	move_and_slide()
	_update_facing_from_velocity()
	_play_anim()

# ------------------------------
# States
# ------------------------------

func _process_idle(delta: float) -> void:
	# Slow to stop
	velocity.x = _approach(velocity.x, 0.0, friction * delta)
	var t := _get_target()
	if t != null and _distance_x_to(t) <= detection_range:
		state = State.CHASE

func _process_patrol(delta: float) -> void:
	var t := _get_target()
	if t != null and _distance_x_to(t) <= detection_range:
		state = State.CHASE
		return

	if _patrol_target == null:
		state = State.IDLE
		return

	var dx: float = _patrol_target.global_position.x - global_position.x
	var dir: float = 1.0 if dx > 0.0 else (-1.0 if dx < 0.0 else 0.0)

	velocity.x = _approach(velocity.x, dir * move_speed, accel * delta)

	# Swap when close
	if absf(global_position.x - _patrol_target.global_position.x) < 6.0:
		_patrol_target = patrol_a if _patrol_target == patrol_b else patrol_b

func _process_chase(delta: float) -> void:
	var t := _get_target()
	if t == null:
		state = State.IDLE if (patrol_a == null or patrol_b == null) else State.PATROL
		return

	var dx := t.global_position.x - global_position.x
	var abs_dx := absf(dx)

	# Move towards player
	var dir := -1.0 if dx < 0.0 else 1.0
	velocity.x = _approach(velocity.x, dir * chase_speed, accel * delta)

	# Attack if close and cooled down
	if abs_dx <= attack_range and cooldown_left <= 0.0 and is_on_floor():
		_begin_attack()
		return

func _process_attack(delta: float) -> void:
	# Root during windup/active
	velocity.x = _approach(velocity.x, 0.0, friction * delta)

	# Fire once when windup finishes
	if not _attack_fired and windup_left <= 0.0:
		_spawn_hitbox()
		_attack_fired = true
		active_left = max(attack_lifetime, 0.01)

	# When active window ends, go back to chase with cooldown
	if _attack_fired and active_left <= 0.0:
		cooldown_left = attack_cooldown
		_attack_fired = false
		state = State.CHASE

func _process_stun(delta: float) -> void:
	# During stun, let knockback and gravity act; friction on X
	velocity.x = _approach(velocity.x, 0.0, friction * 0.6 * delta)
	if stun_left <= 0.0:
		state = State.CHASE

# ------------------------------
# Hit / Damage
# ------------------------------

func _on_hit_received(damage: int, source: Node) -> void:

	on_hurt(damage, source)

func on_hurt(dmg: int, source: Node) -> void:
	_play_var(sfx_hit)
	# Apply damage
	if stats != null:
		stats.health -= dmg

	# Knockback direction from source
	var dir: int = 1
	if source is Node2D:
		dir = -1 if (source as Node2D).global_position.x < global_position.x else 1

	velocity.x = dir * knockback_speed.x
	velocity.y = knockback_speed.y
	stun_left = stun_time
	state = State.STUN

	_flash_hurt()

	# Death
	if stats != null and stats.health <= 0.0:
		_die()

# ------------------------------
# Attack Helpers
# ------------------------------

func _begin_attack() -> void:
	state = State.ATTACK
	_attack_fired = false
	var t := _get_target()
	if t != null:
		facing_dir = -1 if t.global_position.x < global_position.x else 1
	windup_left = attack_windup                 # <-- add this
	_play(clip_attack, true)                    # keep this

func _spawn_hitbox() -> void:
	var hb: HitBox = HitBox.new()
	hb.attacker_stats = stats
	hb.lifetime = attack_lifetime
	hb.hitlog = HitLog.new()
	hb.faction = HitBox.Faction.ENEMY

	# Shape: prefer exported resource, then node path, else a default rectangle
	var shape_to_use: Shape2D = attack_shape
	if shape_to_use == null and attack_src != null and attack_src.shape != null:
		shape_to_use = attack_src.shape.duplicate(true)
	if shape_to_use == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(56, 36)
		shape_to_use = rect

	var cs := CollisionShape2D.new()
	cs.shape = shape_to_use
	hb.add_child(cs)

	var dir := float(facing_dir)
	if invert_facing:
		dir = -dir
	var off := Vector2(attack_offset.x * dir, attack_offset.y)

	get_tree().current_scene.add_child(hb)
	hb.global_position = global_position + off
	hb.global_rotation = global_rotation
	hb.scale.x = dir


# ------------------------------
# Utilities
# ------------------------------

func _get_target() -> Node2D:
	var arr := get_tree().get_nodes_in_group(target_group)
	if arr.is_empty():
		return null
	# Pick nearest by X (cheap)
	var best: Node2D = null
	var best_dx: float = 1e9
	for n in arr:
		if n is Node2D:
			var dx := absf((n as Node2D).global_position.x - global_position.x)
			if dx < best_dx:
				best_dx = dx
				best = n
	return best

func _distance_x_to(n: Node2D) -> float:
	return absf(n.global_position.x - global_position.x)

func _approach(current: float, target: float, delta_step: float) -> float:
	if current < target:
		return min(current + delta_step, target)
	elif current > target:
		return max(current - delta_step, target)
	return target



func _play_anim() -> void:
	if anim == null and sprite == null:
		return

	# Don’t stomp on explicit attack/death once they started
	if state == State.ATTACK and _is_playing(clip_attack):
		return
	if state == State.DEAD and _is_playing(clip_dead):
		return

	match state:
		State.IDLE:
			_play(clip_idle)
		State.PATROL, State.CHASE:
			_play(clip_move if absf(velocity.x) > 5.0 else clip_idle)
		State.ATTACK:
			_play(clip_attack)  # ensure it starts if not already
		State.STUN:
			_play(clip_hurt)
		State.DEAD:
			_play(clip_dead)


func _anim(name: String) -> void:
	if anim != null and anim.has_animation(name):
		if not anim.is_playing() or anim.current_animation != name:
			anim.play(name)
	elif sprite != null:
		# AnimatedSprite2D uses sprite names, keep same naming for simplicity
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(name):
			if sprite.animation != name:
				sprite.play(name)

func _flash_hurt() -> void:

	
	if sprite == null:
		return
	sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func() -> void:
		sprite.modulate = Color(1, 1, 1, 1))

func _die() -> void:
	state = State.DEAD
	if hurtbox != null:
		hurtbox.monitorable = false

	# Try AnimationPlayer first
	if anim != null and anim.has_animation(String(clip_dead)):
		_play(clip_dead, true)
		if not anim.is_connected("animation_finished", Callable(self, "_on_anim_finished")):
			anim.animation_finished.connect(_on_anim_finished)
		return

	# Then AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(String(clip_dead)):
		_play(clip_dead, true)
		if not sprite.is_connected("animation_finished", Callable(self, "_on_sprite_finished")):
			sprite.animation_finished.connect(_on_sprite_finished)
		return

	# Fallback if no 'dead' clip exists
	get_tree().create_timer(0.45).timeout.connect(queue_free)


func _on_sprite_frame_changed() -> void:
	if state == State.ATTACK and sprite != null and StringName(sprite.animation) == clip_attack and not _attack_fired:
		if sprite.frame >= attack_fire_frame:
			_spawn_hitbox()
			_attack_fired = true
			active_left = max(attack_lifetime, 0.01)


func _sprite_anim(name: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(name):
		if sprite.animation != name:
			sprite.play(name)

func _update_facing_from_velocity() -> void:
	if absf(velocity.x) > 1.0:
		facing_dir = -1 if velocity.x < 0.0 else 1
	var flip := (facing_dir < 0)
	if invert_facing:
		flip = not flip
	if sprite != null:
		sprite.flip_h = flip


func _anim_first_available(names: Array[String]) -> void:
	for n in names:
		if anim != null and anim.has_animation(n):
			if not anim.is_playing() or anim.current_animation != n:
				anim.play(n)
			return
		if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(n):
			if sprite.animation != n:
				sprite.play(n)
			return

func _has_anim(name: StringName) -> bool:
	if anim != null and anim.has_animation(String(name)):
		return true
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(String(name))

func _play(name: StringName, force: bool=false) -> void:
	var nm := String(name)
	var sprite_has := sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(nm)
	var anim_has   := anim != null and anim.has_animation(nm)

	# Prefer AnimatedSprite2D if it actually has the clip
	if sprite_has:
		if force or sprite.animation != nm:
			sprite.play(nm)
		return

	if anim_has:
		if force or anim.current_animation != nm or not anim.is_playing():
			anim.play(nm)
		return

func _is_playing(name: StringName) -> bool:
	if anim != null and anim.current_animation == String(name) and anim.is_playing():
		return true
	if sprite != null and sprite.animation == String(name) and sprite.is_playing():
		return true
	return false



func _on_anim_finished(name: StringName) -> void:
	if name == clip_dead:
		queue_free()

func _on_sprite_finished() -> void:
	# AnimatedSprite2D doesn’t pass a name; assume it’s the current animation
	if sprite != null and StringName(sprite.animation) == clip_dead:
		queue_free()


func _play_var(p: AudioStreamPlayer2D, base_db := -6.0, pitch_jitter := 0.05, vol_jitter_db := 1.5) -> void:
	if p == null or p.stream == null:
		return
	if pitch_jitter > 0.0:
		p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	else:
		p.pitch_scale = 1.0
	p.volume_db = base_db + randf_range(-vol_jitter_db, vol_jitter_db)
	p.play()
