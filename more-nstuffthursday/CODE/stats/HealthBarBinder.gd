extends Node
class_name HealthBarBinder

@export var stats: Stats
@export var bar: ProgressBar

func _ready() -> void:
	if stats == null or bar == null:
		push_warning("HealthBarBinder: assign 'stats' and 'bar' in the Inspector.")
		return
	bar.show_percentage = false
	_sync_all()
	stats.health_changed.connect(_on_health_changed)
	stats.stats_recalculated.connect(_on_stats_recalculated)
	stats.leveled_up.connect(_on_leveled_up)
	stats.died.connect(_on_died)

func _sync_all() -> void:
	bar.max_value = max(stats.current_max_health, 0.0001)
	bar.value = clampf(stats.health, 0.0, bar.max_value)

func _on_health_changed(new_value: float, _old_value: float) -> void:
	bar.value = clampf(new_value, 0.0, bar.max_value)

func _on_stats_recalculated() -> void:
	_sync_all()

func _on_leveled_up(_new_level: int) -> void:
	_sync_all()

func _on_died() -> void:
	# Keep visible for debugging; hide if you want:
	# bar.visible = false
	pass
