# Godot 4.x
extends CharacterBody2D

# --- Aura on Hit ---
@export_group("Aura on Hit")
@export var aura_gain_on_hit_seconds: float = 0.75


@onready var sfx_step: AudioStreamPlayer2D       = $SFX/Step
@onready var sfx_jump: AudioStreamPlayer2D       = $SFX/Jump
@onready var sfx_land: AudioStreamPlayer2D       = $SFX/Land
@onready var sfx_swish: AudioStreamPlayer2D      = $SFX/AttackSwish

@onready var sfx_hit: AudioStreamPlayer2D        = $SFX/HitConfirm
@onready var sfx_hurt: AudioStreamPlayer2D       = $SFX/Hurt
@onready var sfx_die: AudioStreamPlayer2D        = $SFX/Die
@onready var sfx_dash: AudioStreamPlayer2D       = $SFX/DashLoop

@onready var sfx_swisher: AudioStreamPlayer2D    = $SFX/AttackSwish2

var _next_step_time := 0.0


@export var knockback_speed: Vector2 = Vector2(0, -600
)

const Hitbox = preload("res://CODE/combat/HitBox.gd")
const HitLog = preload("res://CODE/combat/HitLog.gd")


@onready var _attack_shape_src: CollisionShape2D = _find_attack_shape()

func _find_attack_shape() -> CollisionShape2D:
	var candidates := [
		"Attack/HitBox Template/CollisionShape2D",
		"Attack/CollisionShape2D",
		"Attack/HIT BOX"
	]
	for p in candidates:
		var n := get_node_or_null(p)
		if n is CollisionShape2D:
			return n
	return null








@onready var attack_anim: AnimatedSprite2D = get_node("Attack/Attack")

@export_group("Combat Locks")
@export var lock_movement_during_attack: bool = true     # freeze run/jump/dash while a hit anim plays
@export var lock_attack_inputs_while_anim: bool = true    # block next J/K during the current hit clip
@export var attack_input_buffer_time: float = 0.18        # lets you press slightly early and queue it


var _buf_letter: String = ""
var _buf_timer: float = 0.0

@onready var body_anim: AnimatedSprite2D   = $AnimatedSprite2D            # movement sprite
		# attack sprite

var _attack_active: bool = false
var _attack_anim_hold: float = 0.0


func _attack_locked() -> bool:
	return _attack_anim_hold > 0.0

const HAZARD_LAYER := 4

const ATTACK_ANIMS: Dictionary = {
	"opener_j": "opener_j",
	"opener_k": "opener_k",
	"linker_j": "linker_j",
	"linker_k": "linker_k",
	# tolerate typo

	"finisher_jjj": "finisher_jjj",
	"finisher_jjk": "finisher_jjk",
	"finisher_jkk": "finisher_jkk",
	"finisher_kjj": "finisher_kjj",
	"finisher_kjk": "finisher_kjk",
	"finisher_kkj": "finisher_kkj",
	"finisher_kkk": "finisher_kkk",
	"finisher_jkj": "finisher_jkj",
	 # tolerate typo
}


@onready var combo: Node = $Attack



# --- Low-health / negative-aura overlay ---
# --- Aura overlays ---
@export var close_to_aura_threshold: float = 0.70
@onready var _close_to_death: ColorRect = get_node_or_null("Close_to_death")
@onready var _close_to_aura:  ColorRect = get_node_or_null("Close_to_aura")

var _aura_pulse_tween: Tween

# --- INSERT A: ability flags + unlock API ---
@export var has_dash: bool = false
@export var has_wall_jump: bool = false

func unlock_ability(ability: StringName) -> void:
	match ability:
		&"dash":
			has_dash = true
			print("Unlocked: DASH")
		&"wall_jump":
			has_wall_jump = true
			print("Unlocked: WALL JUMP")
		_:
			push_warning("Unknown ability: %s" % String(ability))



@export var respawn_grace_time: float = 0.15
var _respawn_grace: float = 0.2

@export var stats: Stats

#aura anit cheese
@export_group("Aura Anti-Cheese")
@export var aura_use_breadcrumb_gate: bool = true
@export var aura_touch_radius_px: float = 28.0
@export var aura_window_seconds: float = 1.2
@export var aura_min_unique_crumbs: int = 3
@export var aura_repeat_extra_drain_per_sec: float = 0.75




# --- BREADCRUMB RESPAWN -------------------------------------------------------
@export_group("Breadcrumb Respawn")
@export var crumb_max: int = 10
@export var crumb_min_distance_px: float = 56.0
@export var crumb_drop_cooldown: float = 0.20
@export var platform_activation_after_no_floor: float = 1.5
@export var allow_platform_breadcrumbs: bool = true
@export var floor_layer: int = 1
@export var respawn_snap_up_px: float = 10.0
@export var debug_draw_breadcrumbs: bool = false

var _breadcrumbs: Array = []       # {"pos":Vector2,"is_floor":bool,"is_platform":bool,"t":float}
var _crumb_cd: float = 0.0
var _last_crumb_pos: Vector2 = Vector2.INF
var _time_since_floor: float = 0.0
# -----------------------------------------------------------------------------


# ---- Wall slide / jump (HK-like) ----
@export var wall_slide_enter_vy: float = 30.0
@export var wall_slide_anim_speed: float = 1.0
@export var wall_slide_max_speed: float = 110.0
@export var wall_slide_requires_input: bool = true
@export var wall_stick_time: float = 0.2
@export var wall_coyote_time: float = 0.10
@export var wall_slide_min_anim_time: float = 1.0
@export var wall_jump_min_attach_time: float = 0.1

@export var wall_jump_horizontal_speed: float = 700.0
@export var wall_jump_vertical_velocity: float = -700.0
@export var wall_jump_lock_time: float = 0.18
@export var wall_jump_control_recover_time: float = 0.25

# ---- Movement / jump base ----
@export var speed: float = 700.0
@export var jump_velocity: float = -700.0
@export var coyote_time: float = 0.08
@export var jump_buffer: float = 0.15

# ---- Variable jump tuning ----
@export var gravity_scale_up: float = 0.95
@export var gravity_scale_release: float = 2.1
@export var gravity_scale_fall: float = 1.35
@export var jump_release_damp: float = 0.45
@export var max_fall_speed: float = 2400.0
@export var air_drag: float = 4200.0

# ---- Height-driven jump frames (0-10) ----
@export var jump_up_px: PackedFloat32Array = PackedFloat32Array()
@export var peak_px: PackedFloat32Array = PackedFloat32Array()
@export var jump_down_px: PackedFloat32Array = PackedFloat32Array()

# ---- Drop-through one-way platforms ----
@export var platform_layer: int = 2
@export var drop_through_time: float = 0.22
@export var drop_nudge_speed: float = 300.0

# ---- Landing (HK-like) ----
@export var land_trigger_vy: float = 1500.0
@export var land_min_play_time: float = 0.12
@export var land_anim_speed: float = 1.1
@export var land_lock_time: float = 0.3
@export var land_disable_jump_during_lock: bool = true
@export var land_zero_horizontal_on_lock: bool = true

# ---- Dash ----
@export var dash_speed: float = 1500.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 0.6
@export var dash_buffer: float = 0.10
@export var air_dashes: int = 1
@export var dash_gravity_scale: float = -0.5
@export var dash_cancel_on_wall: bool = true
var is_dashing = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@onready var dash_fx = get_node("Dash") # GPUParticles2D/CPUParticles2D

# --- Aura (Flow) ---
@onready var aura: Aura = get_node_or_null("Aura") as Aura






var _aura_touch_log: Array = []   # each: {"id": int, "t": float}
var _aura_last_touched_id: int = -1




var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

# Air-cycle state
var _air_cycle: bool = false
var _entered_air_by_jump: bool = false
var _jump_start_y: float = 0.0
var _apex_y: float = 0.0
var _apex_reached: bool = false
var _was_on_floor: bool = false

# Wall tech state
var _was_on_wall: bool = false
var _wall_stick_timer: float = 0.0
var _wall_coyote_timer: float = 0.0
var _wall_slide_anim_timer: float = 0.0
var _wall_attach_timer: float = 0.0
var _last_wall_normal_x: float = 0.0
var _wall_jump_lock_timer: float = 0.0
var _wall_jump_recover_timer: float = 0.0

# Drop-through state
var _dropping: bool = false
var _saved_snap: float = 0.0

# Landing state
var _land_anim_timer: float = 0.0
var _land_lock_timer: float = 0.0

# Dash state
var _dash_timer: float = 0.0
var _dash_cd_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _dash_dir: float = 0
var _air_dashes_left: int = 0




func _ready() -> void:
	
	if stats != null:
		stats.health_changed.connect(_on_stats_health_changed)
		stats.died.connect(_on_stats_died)
	
	#_atk.hit_started.connect(_on_hit_started)
	
	if attack_anim:
		attack_anim.visible = false
	
	if has_node("Attack"):
		combo = $Attack
		if not combo.is_connected("hit_started", Callable(self, "_on_hit_started")):
			combo.connect("hit_started", Callable(self, "_on_hit_started"))

		if not combo.is_connected("hit_started", Callable(self, "_on_attack_hit_started")):
			combo.connect("hit_started", Callable(self, "_on_attack_hit_started"))
		

		
	if _close_to_death:
		_close_to_death.visible = false
		_close_to_death.modulate = Color(1,1,1,1)

	if _close_to_aura:
		_close_to_aura.visible = false
		_close_to_aura.modulate = Color(1,1,1,1)   # ← important
		var c := _close_to_aura.color
		c.a = 0.0
		_close_to_aura.color = c





	_was_on_floor = is_on_floor()
	_compute_default_jump_thresholds_if_empty()
	_air_dashes_left = air_dashes

	# Seed initial FLOOR breadcrumb at spawn
	_push_breadcrumb(global_position, true, false)
	_last_crumb_pos = global_position
	_crumb_cd = 0.0
	_time_since_floor = 0.0

	# HurtBox → hazards (Layer 4)
	if has_node("HurtBox"):
		var hb: Area2D = $HurtBox
		hb.monitoring = true
		hb.monitorable = true
		hb.set_collision_mask_value(HAZARD_LAYER, true)
		if hb.has_node("CollisionShape2D"):
			hb.get_node("CollisionShape2D").disabled = false

		# Clean old connections, wire new


		if not hb.body_entered.is_connected(_on_hurtbox_body_entered):
			hb.body_entered.connect(_on_hurtbox_body_entered)
		if not hb.area_entered.is_connected(_on_hurtbox_area_entered):
			hb.area_entered.connect(_on_hurtbox_area_entered)
			
		if has_node("Aura"):
			aura = $Aura as Aura
			if aura and not aura.hard_death.is_connected(_on_aura_hard_death):
				aura.hard_death.connect(_on_aura_hard_death)

func _on_hurtbox_body_entered(_body: Node) -> void:

	_respawn_to_nearest_breadcrumb()

func _on_hurtbox_area_entered(_area: Area2D) -> void:

	_respawn_to_nearest_breadcrumb()



func _read_controls() -> void:
	# --- ATTACK INPUTS ---
	if lock_attack_inputs_while_anim and _attack_active:
		if Input.is_action_just_pressed("attack_j"):
			_buf_letter = "J"; _buf_timer = attack_input_buffer_time
		elif Input.is_action_just_pressed("attack_k"):
			_buf_letter = "K"; _buf_timer = attack_input_buffer_time
	else:
		if Input.is_action_just_pressed("attack_j"):
			combo.accept_input("J")
		elif Input.is_action_just_pressed("attack_k"):
			combo.accept_input("K")

	# --- MOVEMENT INPUTS ---
	if _attack_active and lock_movement_during_attack:
		# Ignore left/right/jump/dash while the clip plays.
		# Example: hard-stop horizontal velocity; keep gravity.
		velocity.x = move_toward(velocity.x, 0.0, 5000.0 * get_physics_process_delta_time())
		return


func _physics_process(delta: float) -> void:
	

	
	
	
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
	_read_controls()

	# Decay the small input buffer
	if _buf_timer > 0.0:
		_buf_timer = maxf(_buf_timer - delta, 0.0)

	# Keep your combo timer updated
	if combo:
		combo.step(delta)
		
	
	
	
	_respawn_grace = max(_respawn_grace - delta, 0.0)

	
	

	
	if _attack_anim_hold > 0.0:
		_attack_anim_hold = maxf(_attack_anim_hold - delta, 0.0)


	# Watchdog
	if not _dropping and not get_collision_mask_value(platform_layer):
		set_collision_mask_value(platform_layer, true)

	# Timers
	_coyote_timer = max(_coyote_timer - delta, -1.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, -1.0)
	_wall_stick_timer = max(_wall_stick_timer - delta, 0.0)
	_wall_coyote_timer = max(_wall_coyote_timer - delta, 0.0)
	_wall_slide_anim_timer = max(_wall_slide_anim_timer - delta, 0.0)
	_wall_jump_lock_timer = max(_wall_jump_lock_timer - delta, 0.0)
	_land_anim_timer = max(_land_anim_timer - delta, 0.0)
	_land_lock_timer = max(_land_lock_timer - delta, 0.0)
	_dash_timer = max(_dash_timer - delta, 0.0)
	_dash_cd_timer = max(_dash_cd_timer - delta, 0.0)
	_dash_buffer_timer = max(_dash_buffer_timer - delta, 0.0)

	if _wall_jump_lock_timer <= 0.0:
		_wall_jump_recover_timer = min(_wall_jump_recover_timer + delta, wall_jump_control_recover_time)

	# Aura tick (uses current velocity + floor state)


	
	var raw_x_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var jump_just_pressed: bool = Input.is_action_just_pressed("jump")
	var landing_locked: bool = _land_lock_timer > 0.0
	var dash_pressed: bool = Input.is_action_just_pressed("dash")
	if dash_pressed and has_dash:
		_dash_buffer_timer = dash_buffer
		_play_var(sfx_dash)
	
		
	# Reset air-dashes when grounded or on wall
	if is_on_floor() or is_on_wall():
		_air_dashes_left = air_dashes

	# Drop-through
	if Input.is_action_just_pressed("down") and is_on_floor() and not landing_locked:
		_start_drop_through()

	# Dash (start)
	var can_start_dash: bool = has_dash and (_dash_timer <= 0.0 and _dash_cd_timer <= 0.0 and (is_on_floor() or _air_dashes_left > 0))
	if _dash_buffer_timer > 0.0 and can_start_dash and not landing_locked:
		_dash_dir = -1.0 if anim.flip_h else 1.0
		_dash_timer = dash_time
		_dash_cd_timer = dash_cooldown * _aura_dash_cd()
		if not is_on_floor() and not is_on_wall():
			_air_dashes_left = max(_air_dashes_left - 1, 0)
		velocity.x = dash_speed * _dash_dir
		if abs(velocity.y) < 200.0:
			velocity.y = 0.0
		_dash_buffer_timer = 0.0
		if aura and aura.has_method("add_burst"):
			aura.add_burst()

	# Horizontal
	if _dash_timer > 0.0:
		pass
	elif is_on_floor():
		if landing_locked:
			velocity.x = 0.0 if land_zero_horizontal_on_lock else velocity.x
		else:
			velocity.x = raw_x_input * speed * _aura_speed()
	else:
		if _wall_jump_lock_timer > 0.0 or landing_locked:
			pass
		elif raw_x_input != 0.0:
			var t := 0.0
			if wall_jump_control_recover_time > 0.0:
				t = clamp(_wall_jump_recover_timer / wall_jump_control_recover_time, 0.0, 1.0)
			var control_scale: float = lerp(0.35, 1.0, t)
			velocity.x = raw_x_input * speed * control_scale * _aura_speed()
		else:
			velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)

	# Vertical / Gravity
	if _dash_timer > 0.0:
		var gmul_d: float = dash_gravity_scale
		velocity.y += _gravity * gmul_d * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif not is_on_floor():
		var gmul: float = gravity_scale_fall
		if velocity.y < 0.0:
			gmul = gravity_scale_up if Input.is_action_pressed("jump") else gravity_scale_release
			gmul *= _aura_apex_gravity()
		velocity.y += _gravity * gmul * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		_coyote_timer = coyote_time

	# Jump buffer
	if jump_just_pressed and (not landing_locked or not land_disable_jump_during_lock):
		_jump_buffer_timer = jump_buffer

	# Ground/coyote jump
	var did_ground_like_jump: bool = false
	var can_jump_ground: bool = (is_on_floor() or _coyote_timer > 0.0)
	if not landing_locked and can_jump_ground and _jump_buffer_timer > 0.0 and _dash_timer <= 0.0:
		velocity.y = jump_velocity * _aura_jump()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_start_air_cycle(true)
		did_ground_like_jump = true

	# Short-hop cut
	if Input.is_action_just_released("jump") and velocity.y < 0.0 and (not landing_locked or not land_disable_jump_during_lock) and _dash_timer <= 0.0:
		velocity.y *= jump_release_damp

	# Move
	var vy_before_move := velocity.y
	move_and_slide()
	if _dash_timer > 0.0 and dash_cancel_on_wall and is_on_wall():
		_dash_timer = 0.0

	# Contact & wall logic
	var now_on_floor: bool = is_on_floor()
	var nx: float = _wall_normal_x()
	if nx != 0.0:
		_last_wall_normal_x = nx
	var now_on_wall_contact: bool = is_on_wall() and not now_on_floor
	var pressing_into_wall: bool = (nx != 0.0 and raw_x_input != 0.0 and raw_x_input * nx < 0.0)
	var now_on_wall_slide: bool = now_on_wall_contact and (pressing_into_wall or not wall_slide_requires_input)

	# Air-cycle transitions
	if not _was_on_floor and now_on_floor:
		_end_air_cycle()
	elif _was_on_floor and not now_on_floor and not _air_cycle:
		_start_air_cycle(false)

	# Wall stick timers
	if now_on_wall_slide:
		if not _was_on_wall:
			_wall_stick_timer = wall_stick_time
			_wall_attach_timer = 0.0
			_wall_slide_anim_timer = wall_slide_min_anim_time
		else:
			_wall_attach_timer += delta
	else:
		if _was_on_wall:
			_wall_coyote_timer = wall_coyote_time
			_wall_attach_timer = 0.0
	_was_on_wall = now_on_wall_slide

	# Landing detection
	# Landing detection
	var just_landed: bool = (not _was_on_floor and now_on_floor)
	if just_landed and vy_before_move >= land_trigger_vy and anim.sprite_frames and anim.sprite_frames.has_animation("land"):
		_play_var(sfx_land, -8.0)
		var hold := land_min_play_time
		if anim.sprite_frames.has_method("get_frame_count") and anim.sprite_frames.has_method("get_animation_speed"):
			var fc: int = anim.sprite_frames.get_frame_count("land")
			var fps: float = anim.sprite_frames.get_animation_speed("land")
			if fps <= 0.0: fps = 12.0
			hold = max(hold, float(fc) / (fps * max(land_anim_speed, 0.01)))

		_land_anim_timer = hold
		_land_lock_timer = land_lock_time

	# Only trigger the visual on *this* landing frame, and only if not attacking
		if not _attack_active:
			_safe_play("land")
			anim.speed_scale = land_anim_speed

	# If you want to cancel ground speed on the impact frames:
		if land_zero_horizontal_on_lock:
			velocity.x = 0.0



	# Sprite facing
	if now_on_wall_slide:
		anim.flip_h = (nx > 0.0)
	elif raw_x_input != 0.0:
		anim.flip_h = (raw_x_input < 0.0)

	# Wall slide
	if now_on_wall_slide and velocity.y > 0.0 and not did_ground_like_jump:
		var cap: float = wall_slide_max_speed
		if _wall_stick_timer > 0.0:
			cap = min(cap, 20.0)
		velocity.y = min(velocity.y, cap)

	# Wall jump
	var did_wall_jump: bool = false
	var wall_jump_allowed_on_wall: bool = now_on_wall_slide and (_wall_attach_timer >= wall_jump_min_attach_time)
	var wall_jump_allowed: bool = (wall_jump_allowed_on_wall or _wall_coyote_timer > 0.0) and not now_on_floor
	if has_wall_jump and wall_jump_allowed and _jump_buffer_timer > 0.0 and not landing_locked:
		var jnx := nx
		if jnx == 0.0:
			jnx = _last_wall_normal_x
		if jnx == 0.0:
			jnx = -1.0 if anim.flip_h else 1.0
		velocity.x = wall_jump_horizontal_speed * jnx
		velocity.y = wall_jump_vertical_velocity
		_wall_jump_lock_timer = wall_jump_lock_time
		_wall_jump_recover_timer = 0.0
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_start_air_cycle(true)
		did_wall_jump = true

	# Anim state
	# --- ATTACK GATE ---
	if _attack_active:
		return
	else:
		if _land_anim_timer > 0.0:
			_safe_play("land")
			anim.speed_scale = land_anim_speed
			
		elif did_wall_jump:
			_safe_play("jump")
			anim.speed_scale = 0.0
			_update_jump_frame()
		elif now_on_wall_slide and (velocity.y > wall_slide_enter_vy or _wall_slide_anim_timer > 0.0):
			_safe_play("wall_slide")
			anim.speed_scale = wall_slide_anim_speed
		elif not now_on_floor:
			_safe_play("jump")
			anim.speed_scale = 0.0
			_update_jump_frame()
		elif abs(velocity.x) > 5.0 and not landing_locked:
			_safe_play("run")
			anim.speed_scale = 1.0
			var now := float(Time.get_ticks_msec()) / 2500.0
			if now < _next_step_time:
				return
			_next_step_time = now + 0.1
			_play_var(sfx_step, -10.0)
		else:
			_safe_play("idle")
			anim.speed_scale = 1.0


	if dash_fx:
		dash_fx.emitting = (_dash_timer > 0.0)
		dash_fx.scale.x = -1 if anim.flip_h else 1
		if not sfx_dash.playing:
			sfx_dash.volume_db = -12.0
			sfx_dash.pitch_scale = 1.0
			sfx_dash.play()
		else:
			if sfx_dash.playing:
				sfx_dash.stop()
			
			
		
	_was_on_floor = now_on_floor

	# Breadcrumb timers & dropping
	if _support_layer() == 1:
		_time_since_floor = 0.0
	else:
		_time_since_floor += delta
	_maybe_drop_breadcrumb(delta)
	queue_redraw()
	
	_aura_breadcrumb_tick(delta)


	# Hazard watchdog
	if _touched_hazard_this_frame():
		_respawn_to_nearest_breadcrumb()
	


	
# ===== Drop-through helpers =====
func _start_drop_through() -> void:
	if _dropping:
		return
	_dropping = true
	_saved_snap = floor_snap_length
	floor_snap_length = 0.0
	set_collision_mask_value(platform_layer, false)
	velocity.y = max(velocity.y, drop_nudge_speed)
	_resume_collision_after_delay()

func _resume_collision_after_delay() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(drop_through_time)
	await t.timeout
	set_collision_mask_value(platform_layer, true)
	floor_snap_length = _saved_snap
	_dropping = false

# ===== Jump-frame helpers =====
func _start_air_cycle(from_jump: bool) -> void:
	_play_var(sfx_jump, -8.0)
	_air_cycle = true
	_entered_air_by_jump = from_jump
	_apex_reached = false
	_jump_start_y = global_position.y
	_apex_y = _jump_start_y
	_safe_play("jump")
	anim.speed_scale = 0.0
	anim.frame = 0

	if not _attack_locked():
		_safe_play("jump")
		anim.speed_scale = 0.0
		anim.frame = 0
		
func _end_air_cycle() -> void:
	_air_cycle = false
	_entered_air_by_jump = false
	_apex_reached = false
	anim.speed_scale = 1.0

func _update_jump_frame() -> void:
	if not _air_cycle:
		return
	if anim.animation != "jump":
		return
	if not _air_cycle:
		return
	if velocity.y >= 0.0 and not _apex_reached:
		_apex_reached = true
		_apex_y = global_position.y
	if velocity.y < 0.0 or not _apex_reached:
		var risen: float = (_jump_start_y - global_position.y)
		anim.frame = _frame_by_thresholds(risen, jump_up_px, 0, 2)
	else:
		var fallen_from_apex: float = (global_position.y - _apex_y)
		var apex_total: float = 0.0
		if peak_px.size() > 0:
			apex_total = peak_px[peak_px.size() - 1]
		if fallen_from_apex < apex_total:
			anim.frame = _frame_by_thresholds(fallen_from_apex, peak_px, 3, 7)
			return
		var d: float = fallen_from_apex - apex_total
		anim.frame = _frame_by_thresholds(d, jump_down_px, 8, 10)

func _frame_by_thresholds(dist: float, thresholds: PackedFloat32Array, start_frame: int, end_frame: int) -> int:
	var n: int = thresholds.size()
	for i in range(n):
		if dist < thresholds[i]:
			return start_frame + i
	return end_frame

func _compute_default_jump_thresholds_if_empty() -> void:
	if jump_up_px.is_empty() or peak_px.is_empty() or jump_down_px.is_empty():
		var g_up: float = _gravity * gravity_scale_up
		var v0: float = -jump_velocity
		var h_ideal: float = (v0 * v0) / (2.0 * g_up)
		if jump_up_px.is_empty():
			jump_up_px = PackedFloat32Array([h_ideal * 0.30, h_ideal * 0.65, h_ideal * 0.90])
		if peak_px.is_empty():
			var apex_total: float = clamp(h_ideal * 0.10, 18.0, 48.0)
			var step: float = apex_total / 5.0
			peak_px = PackedFloat32Array([step * 1.0, step * 2.0, step * 3.0, step * 4.0, step * 5.0])
		if jump_down_px.is_empty():
			jump_down_px = PackedFloat32Array([h_ideal * 0.20, h_ideal * 0.50, h_ideal * 0.85])

# ===== Helpers =====

func _update_close_to_death_overlay() -> void:
	if _close_to_death == null:
		return
	var is_negative := (aura != null and aura.meter < -60.0)
	_close_to_death.visible = is_negative


func _wall_normal_x() -> float:
	var n: Vector2 = get_wall_normal()
	if abs(n.x) > 0.01:
		return n.x
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		if c:
			var nx := c.get_normal().x
			if abs(nx) > 0.3:
				return nx
	return 0.0

func _touched_hazard_this_frame() -> bool:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		if col:
			var collider := col.get_collider()
			if collider is CollisionObject2D and _is_on_layer(collider, HAZARD_LAYER):
				return true
	return false



func _on_hurt_box_area_entered(area: Area2D) -> void:

	if _is_on_layer(area, HAZARD_LAYER):
		_respawn_to_nearest_breadcrumb()

func _is_on_layer(obj: CollisionObject2D, layer_number: int) -> bool:
	return (obj.collision_layer & (1 << (layer_number - 1))) != 0

func _is_rid_on_layer(rid: RID, layer_number: int) -> bool:
	if not rid.is_valid():
		return false
	var bits := PhysicsServer2D.body_get_collision_layer(rid)
	return (bits & (1 << (layer_number - 1))) != 0

# ---------- Breadcrumb internals ----------
func _support_layer() -> int:
	if not is_on_floor():
		return 0
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		if c and c.get_normal().dot(Vector2.UP) > 0.5:
			var rid: RID = c.get_collider_rid()
			if _is_rid_on_layer(rid, floor_layer):
				return 1
			if _is_rid_on_layer(rid, platform_layer):
				return 2
	return 0

func _maybe_drop_breadcrumb(delta: float) -> void:
	_crumb_cd = max(_crumb_cd - delta, 0.0)
	var support := _support_layer()
	if support == 0 or _dropping:
		return
	if _crumb_cd > 0.0:
		return
	var pos := global_position
	if _last_crumb_pos != Vector2.INF and pos.distance_to(_last_crumb_pos) < crumb_min_distance_px:
		return
	var is_floor := (support == 1)
	var is_platform := (support == 2)
	if is_platform and not allow_platform_breadcrumbs:
		return

	_push_breadcrumb(pos, is_floor, is_platform)
	_crumb_cd = crumb_drop_cooldown
	_last_crumb_pos = pos
	queue_redraw()

func _push_breadcrumb(pos: Vector2, is_floor: bool, is_platform: bool) -> void:
	var crumb := {
		"pos": pos,
		"is_floor": is_floor,
		"is_platform": is_platform,
		"t": float(Time.get_ticks_msec()) / 1000.0
	}
	_breadcrumbs.append(crumb)
	while _breadcrumbs.size() > crumb_max:
		_breadcrumbs.pop_front()

	# Persist this crumb as the 'Continue' checkpoint
	_save_checkpoint_safely()


func _eligible_breadcrumbs() -> Array:
	var out: Array = []
	var allow_platform := (_time_since_floor >= platform_activation_after_no_floor)
	for c in _breadcrumbs:
		if c.get("is_floor", false):
			out.append(c)
		elif allow_platform and c.get("is_platform", false):
			out.append(c)
	return out

func _nearest_breadcrumb() -> Dictionary:
	var elig := _eligible_breadcrumbs()
	if elig.is_empty():
		return {}
	var here := global_position
	var best := {}
	var best_d := INF
	for c in elig:
		var d := here.distance_squared_to(c["pos"])
		if d < best_d:
			best_d = d
			best = c
	return best

func _do_respawn_to(pos: Vector2) -> void:
	# Aura: hard break on respawn
	if aura and aura.has_method("register_soft_death"):
		aura.register_soft_death()


	var p := pos
	if respawn_snap_up_px > 0.0:
		p.y -= respawn_snap_up_px
	global_position = p

	var hold := land_min_play_time
	if anim.sprite_frames and anim.sprite_frames.has_animation("land"):
		var fc: int = anim.sprite_frames.get_frame_count("land")
		var fps: float = anim.sprite_frames.get_animation_speed("land")
		if fps <= 0.0:
			fps = 12.0
		hold = max(hold, float(fc) / (fps * max(land_anim_speed, 0.01)))
	_land_anim_timer = hold
	_land_lock_timer = land_lock_time
	anim.speed_scale = land_anim_speed
	if land_zero_horizontal_on_lock:
		velocity = Vector2.ZERO

	# Keep Continue in sync with the actual respawn point
	_save_checkpoint_safely()


func _respawn_to_nearest_breadcrumb() -> void:
	_play_var(sfx_hurt, -6.0)
	if _respawn_grace > 0.0:
		return
	# Aura: hard break when taking damage/respawning
	if aura and aura.has_method("register_soft_death"):
		aura.register_soft_death()

	var c := _nearest_breadcrumb()
	if not c.is_empty():
		_do_respawn_to(c["pos"])

	_respawn_grace = respawn_grace_time


func _safe_play(name: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name:
			anim.play(name)

func get_save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"has_dash": has_dash,
		"has_wall_jump": has_wall_jump,
	}

static func _as_vec2(v) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary and v.has("x") and v.has("y"):
		return Vector2(float(v["x"]), float(v["y"]))
	if v is String:
		var rx := RegEx.new()
		rx.compile("(-?\\d+(?:\\.\\d+)?)") # Godot-safe regex
		var m := rx.search_all(v)
		if m and m.size() >= 2:
			return Vector2(m[0].get_string().to_float(), m[1].get_string().to_float())
	# Fallback for any other shape
	return Vector2.ZERO


func apply_save_state(data: Dictionary) -> void:
	if data.has("position"):
		global_position = _as_vec2(data["position"])
	if data.has("has_dash"):
		has_dash = bool(data["has_dash"])
	if data.has("has_wall_jump"):
		has_wall_jump = bool(data["has_wall_jump"])


func _aura_breadcrumb_tick(delta: float) -> void:
	# negative aura overlay
	if _close_to_death:
		_close_to_death.visible = (aura != null and aura.meter < 0.0)

	# high aura overlay (>= 70%)
	if _close_to_aura:
		var r := _get_aura_ratio_01()
		var show := (r >= close_to_aura_threshold)
		_close_to_aura.visible = show
		if show:
			_start_aura_pulse()   # remove these two lines if you only want on/off
		else:
			_stop_aura_pulse()
	
	
	# If you don’t want gating (for testing), default to normal tick:
	if not aura_use_breadcrumb_gate:
		aura.tick(delta, velocity, speed, is_on_floor())
		return
	_update_aura_overlays()

	var now: float = float(Time.get_ticks_msec()) / 1000.0

	# prune old touches outside the time window
	for i in range(_aura_touch_log.size() - 1, -1, -1):
		var it: Dictionary = _aura_touch_log[i]
		if now - float(it["t"]) > aura_window_seconds:
			_aura_touch_log.remove_at(i)

	# Airborne always allowed to gain (prevents punishing long jumps)
	var support: int = _support_layer()
	var allow_gain: bool = (support == 0) or (_dash_timer > 0.0)
	var extra_drain: float = 0.0

	# When on floor/platform, we gate by unique breadcrumb flow
	if support != 0:
		var current_id: int = _crumb_id_within_radius(aura_touch_radius_px)

		# record a new touch if we entered a different crumb circle
		if current_id != -1 and current_id != _aura_last_touched_id:
			_aura_touch_log.append({"id": current_id, "t": now})
			_aura_last_touched_id = current_id

		# count uniques in the recent window
		var uniques: Dictionary = {}
		for it in _aura_touch_log:
			uniques[it["id"]] = true
		var uniq_count: int = uniques.size()

		# need enough *distinct* crumbs recently to count as spatial progress
		allow_gain = (uniq_count >= aura_min_unique_crumbs)

		# detect obvious A-B-A-B bounce in-window → add a small drain
		if not allow_gain and _aura_touch_log.size() >= 4:
			var n: int = _aura_touch_log.size()
			var id_a: int = int(_aura_touch_log[n - 1]["id"])
			var id_b: int = int(_aura_touch_log[n - 2]["id"])
			var id_c: int = int(_aura_touch_log[n - 3]["id"])
			var id_d: int = int(_aura_touch_log[n - 4]["id"])
			if id_a == id_c and id_b == id_d and id_a != id_b:
				extra_drain = aura_repeat_extra_drain_per_sec * delta

	# Use the gated tick (falls back if someone kept the old Aura)
	if aura.has_method("tick_gated"):
		aura.tick_gated(delta, velocity, speed, is_on_floor(), allow_gain, extra_drain)
	else:
		aura.tick(delta, velocity, speed, is_on_floor())
		if extra_drain > 0.0:
			aura.add_burst(-extra_drain)
	_update_close_to_death_overlay()
	



func _crumb_id_within_radius(r: float) -> int:
	if _breadcrumbs.is_empty():
		return -1
	var r2: float = r * r
	var here: Vector2 = global_position
	var best_id: int = -1
	var best_d2: float = INF
	for c in _breadcrumbs:
		var p: Vector2 = c["pos"]
		var d2: float = here.distance_squared_to(p)
		if d2 <= r2 and d2 < best_d2:
			best_d2 = d2
			var tt: float = float(c["t"])  # we use 't' as a unique crumb id basis
			best_id = int(round(tt * 1000.0))
	return best_id



func _draw() -> void:
	if not debug_draw_breadcrumbs:
		return
	for c in _breadcrumbs:
		var is_floor: bool = bool(c.get("is_floor", false))
		var pos: Vector2 = (c.get("pos", Vector2.ZERO) as Vector2)
		var color: Color = Color(0, 1, 0, 0.8) if is_floor else Color(1, 0.75, 0, 0.8)
		draw_circle(to_local(pos), 3.0, color)





func _save_checkpoint_safely() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var cs := tree.current_scene
	if cs == null:
		return
	Save.save_checkpoint(cs.scene_file_path, get_save_state())  # ← call Save here, not self




# ---- Aura helper accessors (no-op if Aura node missing) ----
func _aura_speed() -> float:
	return aura.mod_speed() if aura and aura.has_method("mod_speed") else 1.0

func _aura_jump() -> float:
	return aura.mod_jump() if aura and aura.has_method("mod_jump") else 1.0

func _aura_dash_cd() -> float:
	return aura.mod_dash_cd() if aura and aura.has_method("mod_dash_cd") else 1.0

func _aura_apex_gravity() -> float:
	return aura.mod_apex_gravity() if aura and aura.has_method("mod_apex_gravity") else 1.0



func _on_aura_hard_death() -> void:
	
	call_deferred("_reload_scene_safe")

func _reload_scene_safe() -> void:

	get_tree().reload_current_scene()


func _get_aura_ratio_01() -> float:
	if aura == null:
		return 0.0

	# Best: direct normalized 0-1
	var n = aura.get("meter_norm")
	if n is float:
		return clampf(n, 0.0, 1.0)

	# Fallback: positive half of signed -1-+1
	var s = aura.get("meter_norm_signed")
	if s is float:
		return clampf(maxf(s, 0.0), 0.0, 1.0)

	# Last-resort manual ratio
	var m: float = 0.0
	if aura.has_method("_max_meter"):
		m = float(aura._max_meter())
	elif aura.has_method("max_meter"):
		m = float(aura.max_meter())
	if m > 0.0:
		return clampf(maxf(aura.meter, 0.0) / m, 0.0, 1.0)
	return 0.0

	# Prefer a direct ratio if your Aura exposes it
	if aura.has_method("get_ratio_01"):
		return clampf(aura.get_ratio_01(), 0.0, 1.0)

	# Try common max fields/methods
	var max_v := 0.0
	var v

	v = aura.get("max")                     # exported var max
	if v is float and v > 0.0: max_v = float(v)

	if max_v <= 0.0 and aura.has_method("get_max"):
		max_v = float(aura.get_max())

	if max_v <= 0.0 and aura.has_method("max_meter"):
		max_v = float(aura.max_meter())

	# Fallback: clamp meter to 01 if no max is discoverable
	if max_v <= 0.0:
		return clampf(maxf(aura.meter, 0.0), 0.0, 1.0)

	return clampf(maxf(aura.meter, 0.0) / max_v, 0.0, 1.0)

func _start_aura_pulse() -> void:
	if _close_to_aura == null:
		return
	if _aura_pulse_tween and _aura_pulse_tween.is_running():
		return
	# start from a gentle visible alpha
	_close_to_aura.modulate.a = 0.20
	_aura_pulse_tween = get_tree().create_tween().set_loops()
	_aura_pulse_tween.tween_property(_close_to_aura, "modulate:a", 0.55, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aura_pulse_tween.tween_property(_close_to_aura, "modulate:a", 0.20, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_aura_pulse() -> void:
	if _aura_pulse_tween:
		_aura_pulse_tween.kill()
		_aura_pulse_tween = null
	if _close_to_aura:
		_close_to_aura.modulate.a = 0.0


func _update_aura_overlays() -> void:
	# negative aura overlay
	if _close_to_death:
		_close_to_death.visible = (aura != null and aura.meter < 0.0)

	# high aura overlay (>= threshold, default 0.70)
	if _close_to_aura:
		var r := _get_aura_ratio_01()
		var show := (r >= close_to_aura_threshold)
		_close_to_aura.visible = show
		if show:
			_start_aura_pulse()
		else:
			_stop_aura_pulse()


func _on_attack_hit_started(_stage: int, label: String) -> void:
	_play_var(sfx_swish, -10.0)
	print("SWING ▶ ", label)
	var key := label.strip_edges().to_lower()

	# (optional tiny sanitizer, in case labels ever come in weird)
	if key.begins_with("finisher_"):
		var letters := ""
		for c in key:
			if c == "j" or c == "k":
				letters += c
		if letters.length() == 3:
			key = "finisher_%s" % letters


	_attack_active = true
	if body_anim: body_anim.visible = false
	if attack_anim:
		attack_anim.visible = true
		attack_anim.frame = 0
		attack_anim.speed_scale = maxf(attack_anim.speed_scale, 0.0001)
		attack_anim.flip_h = anim.flip_h
		attack_anim.play(key)



	if attack_anim.animation_finished.is_connected(_on_attack_anim_finished):
		attack_anim.animation_finished.disconnect(_on_attack_anim_finished)
	attack_anim.animation_finished.connect(_on_attack_anim_finished, Object.CONNECT_ONE_SHOT)

	if attack_anim and attack_anim.sprite_frames and attack_anim.sprite_frames.has_animation(key):
		_attack_active = true
		if body_anim: body_anim.visible = false
		attack_anim.visible = true
		attack_anim.play(key)

	var frames: int  = attack_anim.sprite_frames.get_frame_count(key)
	var fps: float   = attack_anim.sprite_frames.get_animation_speed(key)
	if fps <= 0.0: fps = 12.0
	var scale: float = max(attack_anim.speed_scale, 0.0001) as float
# or: var scale: float = float(max(attack_anim.speed_scale, 0.0001))

	_attack_anim_hold = float(frames) / (fps * scale)





func _attack_label_to_anim(label: String) -> String:
	var s := label.strip_edges().to_lower()

	# Normalize common typos
	s = s.replace("fnisher", "finisher")

	if ATTACK_ANIMS.has(s):
		return ATTACK_ANIMS[s]

	# Fallback: derive finisher name from its J/K letters if needed
	if s.begins_with("finisher_"):
		var letters := ""
		for c in s:
			if c == "j" or c == "k":
				letters += c
		if letters.length() == 3:
			return "finisher_%s" % letters

	return ""
	
	
func _end_attack_visuals() -> void:
	_attack_active = false
	if attack_anim:
		attack_anim.stop()
		attack_anim.visible = false
	if body_anim:
		body_anim.visible = true

func _play_move_anim(name: String) -> void:
	if _attack_active: return
	if body_anim: body_anim.play(name)

func _on_attack_anim_finished() -> void:
	# If we were blocking J/K during the clip, let a buffered press fire now
	if lock_attack_inputs_while_anim and _buf_timer > 0.0 and _buf_letter != "":
		var l := _buf_letter
		_buf_letter = ""
		_buf_timer = 0.0
		combo.accept_input(l)   # this will immediately emit the next hit_started
		return

	_end_attack_visuals()



func _on_hit_started(_stage: int, label: String) -> void:
	_play_var(sfx_swish, -10.0)
	var log := HitLog.new()           # shared by all shapes in THIS swing
	var life := 0.10                  # ~6 frames @60fps feels snappy
	var offs := _swing_offsets_for(label)

	for off in offs:
		_spawn_hitbox(off, life, log)

func _swing_offsets_for(label: String) -> Array[Vector2]:
	match label:
		"opener_J":
			return [Vector2(22, -4)]
		"linker_K":
			return [Vector2(18, -6), Vector2(34, -2)]
		"finisher_jkj":
			return [Vector2(16, -10), Vector2(30, -2), Vector2(40, 4)]
		_:
			return [Vector2(24, -4)]


func _spawn_hitbox(local_offset: Vector2, life: float, log: HitLog) -> void:
	if _attack_shape_src == null or _attack_shape_src.shape == null:
		return

	# 1) Duplicate the reference shape from your Attack/CollisionShape2D
	var dup: Shape2D = _attack_shape_src.shape.duplicate(true)

	# 2) Create the hitbox and configure it *before* adding to the tree
	var hb := Hitbox.new()
	hb.attacker_stats = stats
	hb.lifetime = life
	hb.hitlog = log
	# Optional if your Hitbox has a faction enum and you want to be explicit:
	# hb.faction = Hitbox.Faction.PLAYER

	# 3) Give the hitbox its collision shape now (so _ready sees a shape)
	var cs := CollisionShape2D.new()
	cs.shape = dup
	hb.add_child(cs)

	# 4) Add to the scene and place/mirror relative to facing
	var face := -1.0 if anim.flip_h else 1.0
	var world_off := Vector2(local_offset.x * face, local_offset.y)


	if not hb.hit_confirmed.is_connected(_on_hit_confirmed):
		hb.hit_confirmed.connect(_on_hit_confirmed)
	
	
	get_tree().current_scene.add_child(hb)
	hb.global_position = global_position + world_off
	hb.global_rotation = global_rotation
	hb.scale.x = face
	

	
func on_player_hurt(dmg: int, source: Node) -> void:
	var dir: int = 1
	if source is Node2D:
		dir = -1 if (source as Node2D).global_position.x < global_position.x else 1
	
	velocity.x = dir * knockback_speed.x
	velocity.y = knockback_speed.y

	
	if aura != null:
		aura.note_damage()
	if _respawn_grace > 0.0:
		return
	stats.health -= dmg
	# trigger your Close_to_death overlay and aura effects here
	if stats.health <= -0:
		_respawn_to_nearest_breadcrumb()
		
func on_hurt(dmg: int, source: Node) -> void:

	on_player_hurt(dmg, source)


func _on_stats_health_changed(new_value: float, _old_value: float) -> void:
	if aura == null:
		return
	# If health > 0, mirror it onto Aura’s positive side.
	# If health == 0, let Aura keep (or enter) negative debt via your normal flow.
	if new_value > 0.0:
		aura.meter = new_value

func _on_stats_died() -> void:
	if aura != null:
		# Convert a 0-HP death into your negative-aura “debt” state.
		aura.register_soft_death()



func _play_var(p: AudioStreamPlayer2D, base_db := -6.0, pitch_jitter := 0.05, vol_jitter_db := 1.5) -> void:
	if p == null or p.stream == null:
		return
	if pitch_jitter > 0.0:
		p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	else:
		p.pitch_scale = 1.0
	p.volume_db = base_db + randf_range(-vol_jitter_db, vol_jitter_db)
	p.play()


func _on_hit_confirmed(_target: Node, _damage: int) -> void:
	_play_var(sfx_hit, -6.0)        # little “hit confirm” sound
	if aura:
		aura.add_burst(aura_gain_on_hit_seconds)  # +aura per confirmed hit
