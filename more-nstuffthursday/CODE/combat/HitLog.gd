# HitLog.gd (Godot 4)
extends RefCounted
class_name HitLog

var _seen := {} # Dictionary[int, bool]

func has_hit(obj: Object) -> bool:
	if obj == null:
		return false
	return _seen.has(obj.get_instance_id())

func log_hit(obj: Object) -> void:
	if obj == null:
		return
	_seen[obj.get_instance_id()] = true

func clear() -> void:
	_seen.clear()
