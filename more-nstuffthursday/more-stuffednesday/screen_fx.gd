extends CanvasLayer
class_name ScreenFX

# --- Timings ---
@export var fade_in_duration: float = 0.25
@export var fade_out_duration: float = 0.25

# --- Blackout intensity (matches shader's overlay alpha) ---
@export var max_alpha: float = 0.75
@export var ease_edges: bool = true

# --- Hints ---
@export var show_hint: bool = true
@export var use_ability_hints: bool = true
@export var default_hint_text: String = "Press a button to continue"
@export var dash_hint_text: String = "Dash unlocked — press Dash to continue"
@export var wall_jump_hint_text: String = "Wall jump unlocked — press Jump to continue"

# --- Input to resume ---
@export var resume_on_actions: Array[StringName] = [&"ui_accept", &"jump", &"dash"]
@export var resume_on_mouse_click: bool = true
@export var require_matching_action: bool = false	# if true: Dash pickup waits for "dash", Wall-jump waits for "jump"

# --- Icon (AnimatedSprite2D) ---
@export var show_icon: bool = true
@export var dash_icon_anim: StringName = &"dash"
@export var wall_jump_icon_anim: StringName = &"wall_jump"
@export_enum("center", "pickup") var icon_anchor: String = "pickup"
@export var icon_offset: Vector2 = Vector2.ZERO

@onready var _flash: ColorRect = get_node_or_null("Flash") as ColorRect
@onready var _hint: Label = get_node_or_null("Hint") as Label
@onready var _hint_dash: Label = get_node_or_null("HintDash") as Label
@onready var _hint_wall: Label = get_node_or_null("HintWall") as Label
@onready var _icon: AnimatedSprite2D = get_node_or_null("Icon") as AnimatedSprite2D

var _mat: ShaderMaterial = null

const S_IDLE := 0
const S_IN := 1
const S_HOLD := 2
const S_OUT := 3

var _state: int = S_IDLE
var _elapsed: float = 0.0
var _was_paused: bool = false
var _current_ability: String = ""	# "dash" or "wall_jump"
var _pickup_world_pos: Vector2 = Vector2.INF

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if _flash:
		_flash.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.anchor_left = 0.0
		_flash.anchor_top = 0.0
		_flash.anchor_right = 1.0
		_flash.anchor_bottom = 1.0
		_flash.offset_left = 0.0
		_flash.offset_top = 0.0
		_flash.offset_right = 0.0
		_flash.offset_bottom = 0.0
		_flash.visible = false
		_flash.z_index = 0

		_mat = _flash.material as ShaderMaterial
		if _mat:
			_mat.set_shader_parameter("t", 0.0)
			_mat.set_shader_parameter("overlay_color", Color(0, 0, 0, max_alpha))

	if _hint:
		_hint.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_hint.visible = false
	if _hint_dash:
		_hint_dash.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_hint_dash.visible = false
	if _hint_wall:
		_hint_wall.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_hint_wall.visible = false

	if _icon:
		_icon.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_icon.visible = false
		_icon.z_index = 1	# draw above Flash

func _process(delta: float) -> void:
	match _state:
		S_IN:
			_elapsed += delta
			var k_in: float = min(1.0, _elapsed / max(0.001, fade_in_duration))
			var t_in: float = _ease(k_in) if ease_edges else k_in
			if _mat:
				_mat.set_shader_parameter("t", t_in)
			if k_in >= 1.0:
				_elapsed = 0.0
				_show_hint_for_ability()
				_state = S_HOLD

		S_HOLD:
			if _mat:
				_mat.set_shader_parameter("t", 1.0)
			if _any_resume_input_pressed():
				_hide_all_hints()
				_elapsed = 0.0
				_state = S_OUT

		S_OUT:
			_elapsed += delta
			var k_out: float = min(1.0, _elapsed / max(0.001, fade_out_duration))
			var t_out: float = 1.0 - (_ease(k_out) if ease_edges else k_out)
			if _mat:
				_mat.set_shader_parameter("t", t_out)
			if k_out >= 1.0:
				_cleanup()

		_:
			pass

func _unhandled_input(event: InputEvent) -> void:
	if _state != S_HOLD or not resume_on_mouse_click:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed:
		_hide_all_hints()
		_elapsed = 0.0
		_state = S_OUT

# ability: "dash" | "wall_jump"
# world_pos: pickup global_position (used if icon_anchor = "pickup")
func play_pickup(ability: String, pause_game: bool = true, world_pos: Vector2 = Vector2.INF, hold_until_input: bool = true) -> void:
	_current_ability = ability
	_pickup_world_pos = world_pos

	if _flash:
		_flash.visible = true

	_place_icon()

	var tree := get_tree()
	var was_paused: bool = tree.paused
	if pause_game:
		tree.paused = true
	_was_paused = was_paused

	_elapsed = 0.0
	_state = S_IN

func _place_icon() -> void:
	if not _icon or not show_icon or _icon.sprite_frames == null:
		if _icon:
			_icon.visible = false
		return

	var anim_name: String = String(dash_icon_anim) if _current_ability == "dash" else String(wall_jump_icon_anim)
	if _icon.sprite_frames.has_animation(anim_name):
		_icon.play(anim_name)
	else:
		_icon.visible = false
		return

	var pos: Vector2
	if icon_anchor == "pickup" and _pickup_world_pos.is_finite():
		pos = _world_to_screen(_pickup_world_pos)
	else:
		var vp: Rect2 = get_viewport().get_visible_rect()
		pos = vp.size * 0.5

	_icon.position = pos + icon_offset
	_icon.visible = true

func _show_hint_for_ability() -> void:
	if not show_hint:
		return
	_hide_all_hints()
	var used_specific: bool = false

	if _current_ability == "dash" and _hint_dash:
		_hint_dash.visible = true
		used_specific = true
	elif _current_ability == "wall_jump" and _hint_wall:
		_hint_wall.visible = true
		used_specific = true

	if not used_specific:
		if _hint:
			_hint.text = dash_hint_text if _current_ability == "dash" else wall_jump_hint_text if use_ability_hints else default_hint_text
			_hint.visible = true

func _hide_all_hints() -> void:
	if _hint:
		_hint.visible = false
	if _hint_dash:
		_hint_dash.visible = false
	if _hint_wall:
		_hint_wall.visible = false

func _cleanup() -> void:
	_state = S_IDLE
	if _flash and _mat:
		_mat.set_shader_parameter("t", 0.0)
	if _flash:
		_flash.visible = false
	_hide_all_hints()
	if _icon:
		_icon.stop()
		_icon.visible = false

	var tree := get_tree()
	tree.paused = _was_paused

func _any_resume_input_pressed() -> bool:
	if require_matching_action:
		var required: String = "dash" if _current_ability == "dash" else "jump"
		if Input.is_action_just_pressed(required):
			return true
	for a in resume_on_actions:
		if Input.is_action_just_pressed(String(a)):
			return true
	return false


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _world_to_screen(p: Vector2) -> Vector2:
	# Map world position -> screen pixels using Flash's canvas transform
	if _flash == null:
		return get_viewport().get_visible_rect().size * 0.5
	var to_local: Transform2D = _flash.get_global_transform_with_canvas().affine_inverse()
	var local: Vector2 = to_local * p
	return local
