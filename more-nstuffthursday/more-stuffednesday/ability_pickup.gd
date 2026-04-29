@tool
extends Area2D
class_name AbilityPickup

@export_enum("dash", "wall_jump") var ability: String = "dash": set = set_ability

@export_group("Visuals • Sprite2D (optional)")
@export var dash_texture: Texture2D
@export var wall_jump_texture: Texture2D

@export_group("Visuals • AnimatedSprite2D (optional)")
@export var prefer_animated_first: bool = true
@export var dash_animation: StringName = &"dash"
@export var wall_jump_animation: StringName = &"wall_jump"

@export_group("Behavior")
@export var destroy_on_pickup: bool = true

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func set_ability(value: String) -> void:
	ability = value
	if Engine.is_editor_hint():
		_update_visuals()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _on_body_entered(body: Node) -> void:
	if body and body.has_method("unlock_ability"):
		body.unlock_ability(StringName(ability))

		# Screen-wide flash + brief pause (requires ScreenFX.tscn autoloaded as "FX")
		var fx := get_node_or_null("/root/FX") as ScreenFX
		if fx:
			fx.play_pickup(ability, true, global_position)


		if destroy_on_pickup:
			queue_free()

func _update_visuals() -> void:
	var used_anim := false

	# Try AnimatedSprite2D first (if present and preferred)
	if _anim and prefer_animated_first and _anim.sprite_frames:
		var anim_name := String(dash_animation) if ability == "dash" else String(wall_jump_animation)	# FIXED
		if _anim.sprite_frames.has_animation(anim_name):
			_anim.visible = true
			_anim.play(anim_name)
			used_anim = true

	# Fallback / or explicit Sprite2D use
	if _sprite:
		if used_anim:
			_sprite.visible = false
		else:
			if _anim:
				_anim.visible = false
			_sprite.visible = true
			_sprite.texture = dash_texture if ability == "dash" else wall_jump_texture	# FIXED
