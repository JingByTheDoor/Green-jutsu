extends Node

const SAVE_PATH: String = "user://savegame.json"

var _pending: Dictionary = {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_checkpoint(level_path: String, player_state: Dictionary) -> void:
	var data: Dictionary = {
		"level_path": level_path,
		"player": player_state
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func continue_game() -> void:
	if not has_save():
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed_v: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed_v) != TYPE_DICTIONARY:
		return
	_pending = parsed_v as Dictionary
	if _pending.has("level_path"):
		get_tree().change_scene_to_file(String(_pending["level_path"]))

func has_pending() -> bool:
	return _pending.size() > 0

func take_pending() -> Dictionary:
	var d: Dictionary = _pending
	_pending = {}
	return d

func erase_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
