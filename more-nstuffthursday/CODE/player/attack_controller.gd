# res://CODE/player/attack_controller.gd
extends Node
class_name AttackController

@export var link_wait_time: float = 1.0  # seconds to press the next button

var _stage: int = 0            # 0 idle, 11 waiting linker, 22 waiting finisher
var _seq: Array[String] = []   # e.g., ["J","K","J"]
var _wait_timer: float = 0.0

signal combo_started(b1: String)
signal hit_started(stage: int, label: String)   # "opener_J", "linker_K", "finisher_jkj" (lowercase)
signal combo_finished(sequence: Array[String])

func accept_input(letter: String) -> void:
	var l: String = letter.to_upper()
	if l != "J" and l != "K":
		return

	if _stage == 0:
		_seq.clear()
		_seq.append(l)
		emit_signal("combo_started", l)
		emit_signal("hit_started", 1, "opener_%s" % l)  # opener_J / opener_K
		_stage = 11
		_wait_timer = link_wait_time
		return

	if _stage == 11:
		_seq.append(l)
		emit_signal("hit_started", 2, "linker_%s" % l)  # linker_J / linker_K
		_stage = 22
		_wait_timer = link_wait_time
		return

	if _stage == 22:
		_seq.append(l)

		# Build exact finisher name that matches your SpriteFrames: "finisher_jkj"
		var letters := ""
		for s in _seq: letters += s
		var finisher := "finisher_%s" % letters.to_lower()

		emit_signal("hit_started", 3, finisher)
		emit_signal("combo_finished", _seq.duplicate())
		_reset()
		return

func step(delta: float) -> void:
	if _stage == 0:
		return
	if _wait_timer > 0.0:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_reset()

func is_busy() -> bool:
	return _stage != 0

func _reset() -> void:
	_stage = 0
	_seq.clear()
	_wait_timer = 0.0
