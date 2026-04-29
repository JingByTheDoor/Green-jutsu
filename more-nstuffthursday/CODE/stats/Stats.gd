extends Resource
class_name Stats

@export var faction: int = 0  # 0 = PLAYER, 1 = ENEMY (matches Layers.Faction)


@export var base_xp: float = 100.0

@export var base_max_health: float = 20.0
@export var base_attack: float = 5.0
@export var base_defense: float = 1.0
@export var base_move_speed: float = 80.0

# Per-stat growth curves (multipliers). Assign Curve resources in the Inspector.
@export var health_curve: Curve
@export var attack_curve: Curve
@export var defense_curve: Curve
@export var move_speed_curve: Curve

signal health_changed(new_value: float, old_value: float)
signal died()
signal leveled_up(new_level: int)
signal stats_recalculated()

# Cached "current" values (after curves/level are applied)
var current_max_health: float = 0.0
var current_attack: float = 0.0
var current_defense: float = 0.0
var current_move_speed: float = 0.0

# Backing field for health
var _health: float = 0.0
var health: float:
	get:
		return _health
	set(value):
		var old := _health
		_health = clampf(value, 0.0, current_max_health)
		if _health != old:
			health_changed.emit(_health, old)
			if _health <= 0.0:
				died.emit()

# XP with setter (auto recalculates + emits leveled_up)
var _xp: float = 0.0
@export var xp: float:
	get:
		return _xp
	set(value):
		var old_level := level
		_xp = max(value, 0.0)
		var new_level := level
		if new_level != old_level:
			_recalculate_stats(true)
			leveled_up.emit(new_level)

# Computed level (unlimited cap). Formula mirrors your transcript.
var level: int:
	get:
		var lv := int(floor(max(1.0, sqrt(_xp / max(base_xp, 0.0001)) + 0.5)))
		return lv

func _init() -> void:
	# Export values are applied after _init(); defer real setup.
	setup_stats.call_deferred()

func setup_stats() -> void:
	_recalculate_stats(false)
	health = current_max_health

func _curve_mul(curve: Curve, lv: int) -> float:
	if curve == null:
		return 1.0
	# Sample level in [0..1]; slight -0.01 shift to align L1 near start of curve (per tutorial idea).
	var t := clampf(float(lv) / 100.0 - 0.01, 0.0, 1.0)
	return curve.sample(t)

func _recalculate_stats(preserve_health_ratio: bool) -> void:
	var ratio := 1.0
	if current_max_health > 0.0:
		ratio = _health / current_max_health

	current_max_health = base_max_health * _curve_mul(health_curve, level)
	current_attack = base_attack * _curve_mul(attack_curve, level)
	current_defense = base_defense * _curve_mul(defense_curve, level)
	current_move_speed = base_move_speed * _curve_mul(move_speed_curve, level)

	if preserve_health_ratio:
		var old := _health
		_health = clampf(ratio * current_max_health, 0.0, current_max_health)
		if _health != old:
			health_changed.emit(_health, old)

	stats_recalculated.emit()

# Public helper to trigger a recalc if you change bases/curves via code
func recalculate_stats() -> void:
	_recalculate_stats(true)

func add_xp(amount: float) -> int:
	var before := level
	xp = _xp + amount
	return level - before

# Damage model: final = attacker_attack - this.current_defense (negative is allowed → heals)
func apply_damage(raw_attack: float, source: Object = null) -> float:
	var final := raw_attack - current_defense
	# Negative final heals, positive final damages.
	health = health - final
	return final

func heal(amount: float) -> float:
	var old := health
	health = health + absf(amount)
	return health - old

func fill_health() -> void:
	health = current_max_health

func is_dead() -> bool:
	return health <= 0.0
