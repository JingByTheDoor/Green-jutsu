extends CharacterBody2D
class_name BasicEnemy

@onready var sfx_atk1: AudioStreamPlayer2D = get_node_or_null("SFX/Attack1")
@onready var sfx_atk2: AudioStreamPlayer2D = get_node_or_null("SFX/Attack2")
@onready var sfx_hurt: AudioStreamPlayer2D = get_node_or_null("SFX/Hurt")
@onready var sfx_die:  AudioStreamPlayer2D = get_node_or_null("SFX/Die")
@onready var sfx_run:  AudioStreamPlayer2D = get_node_or_null("SFX/Run")

var _next_step_time := 0.0

func _play_sfx(p: AudioStreamPlayer2D, base_db := -7.0, pitch_jitter := 0.06, vol_jitter_db := 1.2) -> void:
	if p == null or p.stream == null:
		return
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.volume_db = base_db + randf_range(-vol_jitter_db, vol_jitter_db)
	p.play()




# -----------------------------
# Clips / visuals
# -----------------------------
@export var clip_idle:     StringName = &"idle"
@export var clip_move:     StringName = &"run"
@export var clip_attack1:  StringName = &"attack1"
@export var clip_attack2:  StringName = &"attack2"
@export var clip_hurt:     StringName = &"hurt"
@export var clip_dead:     StringName = &"dead"
@export var invert_facing: bool = false   # tick if your art faces LEFT by default

# If you drive hit-timing from AnimatedSprite2D frames:
@export var attack1_fire_frame: int = 3
@export var attack2_fire_frame: int = 5

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var anim:   AnimationPlayer  = get_node_or_null("AnimationPlayer")

# -----------------------------
# Project dependencies
# -----------------------------
const HitBox := preload("res://CODE/combat/HitBox.gd")
const HitLog := preload("res://CODE/combat/HitLog.gd")

# -----------------------------
# Movement / general tuning
# -----------------------------
@export var stats: Stats
@export var move_speed: float = 90.0
@export var chase_speed: float = 135.0
@export var accel: float = 900.0
@export var friction: float = 1200.0
@export var gravity: float = 1600.0
@export var max_fall_speed: float = 2200.0
@export var detection_range: float = 220.0

# -----------------------------
# Attack 1 tuning
# -----------------------------
@export var attack1_range: float    = 46.0
@export var attack1_windup: float   = 0.12
@export var attack1_lifetime: float = 0.10
@export var attack1_cooldown: float = 0.60
@export var attack1_offset: Vector2 = Vector2(32, -6)
@export var attack1_shape_path: NodePath
@export var attack1_shape: Shape2D  # optional direct resource

# -----------------------------
# Attack 2 tuning
# -----------------------------
@export var attack2_range: float    = 60.0
@export var attack2_windup: float   = 0.20
@export var attack2_lifetime: float = 0.12
@export var attack2_cooldown: float = 0.80
@export var attack2_offset: Vector2 = Vector2(48, -6)
@export var attack2_shape_path: NodePath
@export var attack2_shape: Shape2D  # optional direct resource

# When both attacks are possible, chance to pick attack2 (0..1)
@export var attack2_chance: float = 0.5

# -----------------------------
# Scene wiring
# -----------------------------
@export var hurtbox_path: NodePath = ^"HurtBox"
@export var patrol_a_path: NodePath
@export var patrol_b_path: NodePath
@export var target_group: StringName = &"player"

@onready var hurtbox: Hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
@onready var patrol_a: Node2D = get_node_or_null(patrol_a_path) as Node2D
@onready var patrol_b: Node2D = get_node_or_null(patrol_b_path) as Node2D
@onready var attack1_src: CollisionShape2D = get_node_or_null(attack1_shape_path) as CollisionShape2D
@onready var attack2_src: CollisionShape2D = get_node_or_null(attack2_shape_path) as CollisionShape2D

# -----------------------------
# State
# -----------------------------
enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }
var state: int = State.PATROL
var facing_dir: int = 1  # -1 = left, 1 = right

# Timers
var cooldown_left: float = 0.0
var windup_left: float = 0.0
var active_left: float = 0.0


# Internals
var _patrol_target: Node2D
var _attack_fired: bool = false
var _current_attack: int = 1  # 1 or 2

func _ready() -> void:
	add_to_group(&"enemies")

	if sprite != null and not sprite.is_connected("frame_changed", Callable(self, "_on_sprite_frame_changed")):
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	# Make sure non-loop clips won't trap death
	_ensure_non_loop_sprite_clips()

	if stats != null:
		stats.recalculate_stats()
		if stats.health <= 0.0:
			stats.fill_health()

	if hurtbox != null and not hurtbox.is_connected("hit_received", Callable(self, "_on_hit_received")):
		hurtbox.hit_received.connect(_on_hit_received)

	if patrol_a != null and patrol_b != null:
		_patrol_target = patrol_b
		state = State.PATROL
	else:
		state = State.IDLE

func _physics_process(delta: float,) -> void:
	if cooldown_left > 0.0: cooldown_left -= delta
	if windup_left   > 0.0: windup_left   -= delta
	if active_left   > 0.0: active_left   -= delta


	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)

		State.CHASE:
			_process_chase(delta)

		State.ATTACK:
			_process_attack(delta)

		State.DEAD:
			_play_sfx(sfx_die, -20)
			velocity *= 0.9
			move_and_slide()
			return

	move_and_slide()
	_update_facing_from_velocity()
	_play_anim()

# -----------------------------
# States
# -----------------------------
func _process_idle(_delta: float) -> void:
	velocity.x = _approach(velocity.x, 0.0, friction * _delta)
	var t := _get_target()
	if t != null and _distance_x_to(t) <= detection_range:
		state = State.CHASE

func _process_patrol(delta: float) -> void:
	#_play_sfx(sfx_run, -6.0)
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

	if absf(global_position.x - _patrol_target.global_position.x) < 6.0:
		_patrol_target = patrol_a if _patrol_target == patrol_b else patrol_b

func _process_chase(_delta: float) -> void:

	var t := _get_target()
	if t == null:
		state = (State.PATROL if (patrol_a != null and patrol_b != null) else State.IDLE)
		return

	var dx: float = t.global_position.x - global_position.x
	var abs_dx: float = absf(dx)
	var dir: float = -1.0 if dx < 0.0 else 1.0
	velocity.x = _approach(velocity.x, dir * chase_speed, accel * _delta)

	if cooldown_left <= 0.0 and is_on_floor():
		var chosen := _pick_attack(abs_dx)
		if chosen != 0:
			_begin_attack(chosen)

func _process_attack(delta: float,) -> void:
	velocity.x = _approach(velocity.x, 0.0, friction * delta)

	if not _attack_fired:
		if windup_left > 0.0:
			windup_left -= delta
			return
		_spawn_hitbox_for_current()      # <— no arg
		_attack_fired = true
		active_left = max(_attack_lifetime(), 0.01)
		return

	if active_left > 0.0:
		active_left -= delta
		return

	cooldown_left = _attack_cooldown()
	_attack_fired = false
	state = State.CHASE


# -----------------------------
# Hit / Damage
# -----------------------------
func _on_hit_received(damage: int, source: Node) -> void:
	on_hurt(damage, source)

func on_hurt(dmg: int, source: Node) -> void:
	if stats != null:
		stats.health -= dmg
	
	
	
	var dir: int = 1
	if source is Node2D:
		dir = -1 if (source as Node2D).global_position.x < global_position.x else 1
	velocity.x = dir * 180.0
	velocity.y = -140.0
	_flash_hurt()

	if stats != null and stats.health <= 0.0:
		_die()

# -----------------------------
# Attacks
# -----------------------------
func _pick_attack(abs_dx: float) -> int:
	var can1: bool = abs_dx <= attack1_range
	var can2: bool = abs_dx <= attack2_range
	if can1 and can2:
		return 2 if randf() < clamp(attack2_chance, 0.0, 1.0) else 1
	elif can1:
		return 1 
	elif can2:
		return 2
	return 0

func _begin_attack(which: int) -> void:
	state = State.ATTACK
	_attack_fired = false
	_current_attack = which

	var t := _get_target()
	if t != null:
		facing_dir = -1 if t.global_position.x < global_position.x else 1

	windup_left = (attack1_windup if which == 1 else attack2_windup)
	_play(clip_attack1 if which == 1 else clip_attack2, true)
	

	
	
func _spawn_hitbox_for_current() -> void:
	var hb := HitBox.new()

	# SFX chosen by current attack
	if _current_attack == 1:
		_play_sfx(sfx_atk1, -9.0)
	else:
		_play_sfx(sfx_atk2, -9.0)

	hb.attacker_stats = stats
	hb.lifetime = (attack1_lifetime if _current_attack == 1 else attack2_lifetime)
	hb.hitlog = HitLog.new()
	hb.faction = HitBox.Faction.ENEMY

	var sh: Shape2D = null
	if _current_attack == 1:
		sh = attack1_shape if attack1_shape != null else (attack1_src.shape.duplicate(true) if attack1_src != null and attack1_src.shape != null else null)
	else:
		sh = attack2_shape if attack2_shape != null else (attack2_src.shape.duplicate(true) if attack2_src != null and attack2_src.shape != null else null)
	if sh == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(56, 36) if _current_attack == 1 else Vector2(72, 40)
		sh = rect

	var cs := CollisionShape2D.new()
	cs.shape = sh
	hb.add_child(cs)

	var dirf := float(facing_dir)
	if invert_facing:
		dirf = -dirf
	var off := (attack1_offset if _current_attack == 1 else attack2_offset)
	off.x *= dirf

	get_tree().current_scene.add_child(hb)
	hb.global_position = global_position + off
	hb.global_rotation = global_rotation
	hb.scale.x = dirf

func _attack_lifetime() -> float:
	return attack1_lifetime if _current_attack == 1 else attack2_lifetime

func _attack_cooldown() -> float:
	return attack1_cooldown if _current_attack == 1 else attack2_cooldown

# -----------------------------
# Utilities
# -----------------------------
func _get_target() -> Node2D:
	var arr := get_tree().get_nodes_in_group(target_group)
	if arr.is_empty(): return null
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

func _approach(current: float, target: float, step: float) -> float:
	if current < target: return min(current + step, target)
	if current > target: return max(current - step, target)
	return target

# Animation helpers
func _ensure_non_loop_sprite_clips() -> void:
	if sprite != null and sprite.sprite_frames != null:
		for n in [clip_attack1, clip_attack2, clip_hurt, clip_dead]:
			if sprite.sprite_frames.has_animation(String(n)):
				sprite.sprite_frames.set_animation_loop(String(n), false)

func _play_anim() -> void:
	if anim == null and sprite == null:
		return
	# Don't stomp the active attack/death playback
	if state == State.ATTACK and (_is_playing(clip_attack1) or _is_playing(clip_attack2)):
		return
	if state == State.DEAD and _is_playing(clip_dead):
		return

	match state:
		State.IDLE:
			_play(clip_idle)
		State.PATROL, State.CHASE:
			_play(clip_move if absf(velocity.x) > 5.0 else clip_idle)

			var spd: float = absf(velocity.x)
			if is_on_floor() and spd > 30.0 and sprite != null and StringName(sprite.animation) == clip_move:
				var now: float = float(Time.get_ticks_msec()) / 16000.0
				var period: float = clampf(0.45 - 0.0025 * spd, 0.18, 0.45)
				if now >= _next_step_time:
					_next_step_time = now + period
					_play_sfx(sfx_run, -10.0)


		State.ATTACK:
			_play(clip_attack1 if _current_attack == 1 else clip_attack2)

		State.DEAD:
			#_play_sfx(sfx_die, -10)
			_play(clip_dead)

func _play(name: StringName, force: bool=false) -> void:
	var nm := String(name)
	var sprite_has := sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(nm)
	var anim_has   := anim != null and anim.has_animation(nm)
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

func _update_facing_from_velocity() -> void:
	if absf(velocity.x) > 1.0:
		facing_dir = -1 if velocity.x < 0.0 else 1
	var flip := (facing_dir < 0)
	if invert_facing: flip = not flip
	if sprite != null:
		sprite.flip_h = flip

func _flash_hurt() -> void:
	_play_sfx(sfx_hurt, -6.0)
	if sprite == null: return
	sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		sprite.modulate = Color(1, 1, 1, 1))

func _die() -> void:
	state = State.DEAD
	_play_sfx(sfx_die, -6.0)
	if hurtbox != null:
		hurtbox.monitorable = false
	if anim != null and anim.has_animation(String(clip_dead)):
		_play(clip_dead, true)
		if not anim.is_connected("animation_finished", Callable(self, "_on_anim_finished")):
			anim.animation_finished.connect(_on_anim_finished)
		return
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(String(clip_dead)):
		_play(clip_dead, true)
		if not sprite.is_connected("animation_finished", Callable(self, "_on_sprite_finished")):
			sprite.animation_finished.connect(_on_sprite_finished)
		return
	get_tree().create_timer(0.45).timeout.connect(queue_free)

func _on_anim_finished(name: StringName) -> void:
	#_play_sfx(sfx_die, -10)
	if name == clip_dead:
		queue_free()

func _on_sprite_finished() -> void:
	#_play_sfx(sfx_die, -10)
	if sprite != null and StringName(sprite.animation) == clip_dead:
		queue_free()

# Spawn on specific sprite frame (if you prefer frame-accurate timing)
func _on_sprite_frame_changed() -> void:
	if state != State.ATTACK or sprite == null or _attack_fired:
		return
	var cur := StringName(sprite.animation)
	if cur == clip_attack1 and sprite.frame >= attack1_fire_frame:
		_spawn_hitbox_for_current()
		_attack_fired = true
		active_left = max(attack1_lifetime, 0.01)
	elif cur == clip_attack2 and sprite.frame >= attack2_fire_frame:
		_spawn_hitbox_for_current()
		_attack_fired = true
		active_left = max(attack2_lifetime, 0.01)
