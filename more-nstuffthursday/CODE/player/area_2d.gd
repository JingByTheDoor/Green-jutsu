extends Area2D

const FILE_FMT := "res://levels/level_%d.tscn"

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	var path := get_tree().current_scene.scene_file_path
	var re := RegEx.new()
	re.compile("level_(\\d+)\\.tscn$")
	var m := re.search(path)
	var next := 1
	if m:
		next = int(m.get_string(1)) + 1
	get_tree().change_scene_to_file(FILE_FMT % next)
