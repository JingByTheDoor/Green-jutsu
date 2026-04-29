extends Node
class_name Aura

signal tier_changed(new_tier: int)
signal broke

@export var negative_move_gain_mult: float = 1.0  # per-second gain from clean movement while negative



@export var hold_negative_while_gain_allowed: bool = true
@export var zero_settle_seconds: float = 0.20
var _zero_settle: float = 0.0

@export var speed_epsilon_px: float = 10.0        # below this X speed, we treat you as 'standing still'
@export var decay_tier_factor: float = 1.20       # multiplicative decay per tier (e.g., tier 3 → 1.2^3)
@export var negative_bursts_stay_negative: bool = true  # prevent add_burst from crossing 0 when meter < 0


signal hard_death

@export_group("Debt")
@export var debt_floor: float = -150.0        # hard reset threshold
@export var debt_step: float = 25.0           # deeper each soft death while negative
@export var debt_recover_per_sec: float = 15.0

var debt_streak: int = 0


@export_group("Build / Decay")
@export var speed_threshold_ratio: float = 0.60
@export var grace_time: float = 0.0
@export var decay_rate_mult: float = 3.0
@export var tech_burst_seconds: float = 0.75

@export_group("Tier times (seconds of clean motion)")
@export var tier_times: Array[float] = [2.0, 5.0, 20.0, 40.0]

@export_group("Multipliers by tier index (0..4)")
@export var speed_mults: Array[float]        = [1.0, 1.10, 1.20, 1.40, 1.60]
@export var jump_mults: Array[float]         = [1.0, 1.10, 1.17, 1.28, 1.39]
@export var dash_cd_mults: Array[float]      = [1.0, 0.98, 0.90, 0.85, 0.40]
@export var apex_gravity_mults: Array[float] = [1.0, 0.98, 0.95, 0.92, 0.90]

var meter: float = 0.0
var tier: int = 0
var _grace: float = 0.0

var meter_norm: float:
	get:
		var m: float = _max_meter()
		if m <= 0.0:
			return 0.0
		return clampf(meter / m, 0.0, 1.0)

var debt_norm: float:
	get:
		if debt_floor >= 0.0:
			return 0.0
		return clampf(-meter / abs(debt_floor), 0.0, 1.0)


func reset() -> void:
	meter = 0.0
	_set_tier(0)
	broke.emit()

func hard_break() -> void:
	reset()

func note_damage() -> void:
	_drop_tiers(2)

func add_burst(sec: float = tech_burst_seconds) -> void:
	if negative_bursts_stay_negative and meter < 0.0:
		meter = min(meter + sec, 0.0)  # recover toward 0, but never above
	else:
		meter = clampf(meter + sec, 0.0, _max_meter())
	_recompute_tier()


func tick(delta: float, vel: Vector2, base_run_speed: float, on_floor: bool) -> void:
	# NEGATIVE SIDE: passive recover + movement-based recover (no cross above 0)
	if meter < 0.0:
		var base: float = debt_recover_per_sec * delta
		var speed_ok: bool = absf(vel.x) >= maxf(base_run_speed * speed_threshold_ratio, speed_epsilon_px)
		var qualifies: bool = speed_ok or (not on_floor)
		var move_gain: float = (delta * negative_move_gain_mult) if qualifies else 0.0
		meter = min(meter + base + move_gain, 0.0)
		if meter >= 0.0:
			debt_streak = 0
		return

	# POSITIVE SIDE: regen vs decay (standing still decays)
	var speed_ok_pos: bool = absf(vel.x) >= maxf(base_run_speed * speed_threshold_ratio, speed_epsilon_px)
	var qualifies_pos: bool = speed_ok_pos or (not on_floor)

	if qualifies_pos:
		_grace = grace_time
		meter = clampf(meter + delta, 0.0, _max_meter())
	else:
		if _grace > 0.0:
			_grace = maxf(_grace - delta, 0.0)
		else:
			meter = clampf(meter - delta * _current_decay_rate(), 0.0, _max_meter())

	_recompute_tier()




func tick_gated(delta: float, vel: Vector2, base_run_speed: float, on_floor: bool, allow_gain: bool, extra_drain_sec: float) -> void:
	# Brief pause at 0 to avoid ping-ponging across zero
	if _zero_settle > 0.0:
		_zero_settle = maxf(_zero_settle - delta, 0.0)
		return

	# NEGATIVE SIDE: passive recover + movement-based recover (no cross above 0)
	if meter < 0.0:
		var base: float = debt_recover_per_sec * delta
		var speed_ok: bool = absf(vel.x) >= maxf(base_run_speed * speed_threshold_ratio, speed_epsilon_px)
		var qualifies: bool = speed_ok or (not on_floor)
		# Airborne always allowed; on ground require allow_gain (mirrors positive logic)
		var allow_regen: bool = qualifies and ((not on_floor) or allow_gain)
		var move_gain: float = (delta * negative_move_gain_mult) if allow_regen else 0.0

		meter = min(meter + base + move_gain, 0.0)
		if meter >= 0.0:
			debt_streak = 0
			_zero_settle = zero_settle_seconds
		return

	# POSITIVE SIDE: regen vs decay (standing still decays)
	var speed_ok_pos: bool = absf(vel.x) >= maxf(base_run_speed * speed_threshold_ratio, speed_epsilon_px)
	var qualifies_pos: bool = speed_ok_pos or (not on_floor)
	var allow_regen_pos: bool = qualifies_pos and ((not on_floor) or allow_gain)

	if allow_regen_pos:
		_grace = grace_time
		meter = clampf(meter + delta, 0.0, _max_meter())
	else:
		_decay(delta)

	if extra_drain_sec > 0.0:
		meter = clampf(meter - extra_drain_sec, 0.0, _max_meter())

	_recompute_tier()





func _decay(delta: float) -> void:
	if _grace > 0.0:
		_grace = max(_grace - delta, 0.0)
	else:
		meter = clampf(meter - delta * _current_decay_rate(), 0.0, _max_meter())


func _current_decay_rate() -> float:
	var mult: float = decay_rate_mult
	if decay_tier_factor != 1.0:
		var t := tier
		if t < 0:
			t = 0
		mult *= pow(decay_tier_factor, float(t))
	return mult



func mod_speed() -> float:        return _pick(speed_mults)
func mod_jump() -> float:         return _pick(jump_mults)
func mod_dash_cd() -> float:      return _pick(dash_cd_mults)
func mod_apex_gravity() -> float: return _pick(apex_gravity_mults)

func _max_meter() -> float:
	if tier_times.is_empty():
		return 0.0
	return tier_times[tier_times.size() - 1]

func _recompute_tier() -> void:
	var new_tier: int = 0
	for i in range(tier_times.size()):
		if meter >= float(tier_times[i]):
			new_tier = i + 1
	_set_tier(new_tier)

func _set_tier(n: int) -> void:
	if n != tier:
		tier = n
		tier_changed.emit(tier)

func _drop_tiers(n: int) -> void:
	var t: int = tier - n
	if t < 0:
		t = 0
	_set_tier(t)
	var limit: float = 0.0
	if t > 0:
		limit = float(tier_times[t - 1])
	meter = min(meter, limit)

func _pick(a: Array[float]) -> float:
	var i: int = tier
	var last_index: int = a.size() - 1
	if i > last_index:
		i = last_index
	if i < 0:
		i = 0
	return a[i]


func register_soft_death() -> void:
	if meter >= 0.0:
		debt_streak = 1
	else:
		debt_streak += 1

	meter = max(-debt_step * debt_streak, debt_floor)
	_set_tier(0)
	broke.emit()

	if meter <= debt_floor:
		hard_death.emit()


# -1..0..+1 for HUD (negative fills left, positive fills right)
# -1 .. 0 .. +1 for HUD
var meter_norm_signed: float:
	get:
		if meter >= 0.0:
			var m: float = _max_meter()
			if m <= 0.0:
				return 0.0
			return clampf(meter / m, 0.0, 1.0)
		else:
			var neg: float = absf(debt_floor)   # e.g., 150
			if neg <= 0.0:
				return 0.0
			# IMPORTANT: divide by +neg (NOT -neg)
			return clampf(meter / neg, -1.0, 0.0)
