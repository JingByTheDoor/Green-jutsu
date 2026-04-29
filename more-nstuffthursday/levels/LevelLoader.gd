extends Node

func _ready() -> void:
	if Save.has_pending():
		var payload: Dictionary = Save.take_pending()
		var player: Node = get_tree().get_first_node_in_group("Player")
		if player and payload.has("player") and player.has_method("apply_save_state"):
			player.apply_save_state(payload["player"] as Dictionary)
