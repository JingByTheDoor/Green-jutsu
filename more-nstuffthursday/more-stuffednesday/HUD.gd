extends CanvasLayer
class_name AuraHUD

@export var player_path: NodePath
@onready var bar_container: Node = %AuraBar    # can be Range (legacy) or Control with Pos/Neg children
@onready var legacy_bar: Range = %AuraBar as Range
@onready var pos_rect: ColorRect = (bar_container.get_node_or_null("Pos") if bar_container else null)
@onready var neg_rect: ColorRect = (bar_container.get_node_or_null("Neg") if bar_container else null)
@onready var pct_label: Label = (bar_container.get_node_or_null("Pct") if bar_container else null)

var player: Node = null
var aura: Aura = null

# smoothed display to avoid sudden pops when dashing
var _pos_disp := 0.0
var _neg_disp := 0.0

func _ready() -> void:
	player = get_node_or_null(player_path)
	if player and player.has_node("Aura"):
		aura = player.get_node("Aura") as Aura

	# LEGACY: if the node is a ProgressBar/Range, keep it working but map -1..1 into 0..1 fill
	if legacy_bar:
		legacy_bar.min_value = 0.0
		legacy_bar.max_value = 1.0
		legacy_bar.show_percentage = false

func _process(dt: float) -> void:
	if not aura or not bar_container:
		return

	# Compute signed portions (0..1 each side, exclusive of the other)
	var pos := 0.0
	var neg := 0.0

	if aura.meter >= 0.0:
		var m := 0.0
		if aura.has_method("_max_meter"):
			m = float(aura._max_meter())
		elif aura.has_method("max_meter"):
			m = float(aura.max_meter())
		if m > 0.0:
			pos = clampf(aura.meter / m, 0.0, 1.0)
	else:
		var neg_max := 0.0
		var v = aura.get("debt_floor")
		if typeof(v) == TYPE_FLOAT:
			neg_max = absf(float(v))
		if neg_max > 0.0:
			neg = clampf(absf(aura.meter) / neg_max, 0.0, 1.0)

	# Smooth a bit so dash doesn't "snap" visually
	var k := 1.0 - pow(0.0001, dt)  # ~quick but not instant
	_pos_disp = lerp(_pos_disp, pos, k)
	_neg_disp = lerp(_neg_disp, neg, k)

	# Signed-bar path (preferred)
	if pos_rect and neg_rect:
		_update_signed_bar(_pos_disp, _neg_disp)
		if pct_label:
			var signed_pct := int(round((pos - neg) * 100.0))
			pct_label.text = (("%+d%%") % signed_pct)
		return

	# Legacy single ProgressBar path (fallback):
	if legacy_bar:
		# value shows magnitude only (0..1), text label (if you added one) shows signed
		legacy_bar.value = max(_pos_disp, _neg_disp)
		legacy_bar.modulate = Color(0.95, 0.35, 0.35) if (neg > 0.0 or aura.meter < 0.0) else _tier_color(_safe_tier())

func _safe_tier() -> int:
	var t = aura.get("tier")
	return int(t) if typeof(t) == TYPE_INT else 0

func _tier_color(t: int) -> Color:
	match t:
		0: return Color(0.618, 1.0, 0.683, 1.0)
		1: return Color(0.0,   0.831, 0.212, 1.0)
		2: return Color(0.0,   0.659, 0.086, 1.0)
		3: return Color(0.0,   0.541, 0.102, 1.0)
		_: return Color(0.0,   0.404, 0.039, 1.0)

func _update_signed_bar(pos_ratio: float, neg_ratio: float) -> void:
	# Layout assumptions:
	# - AuraBar is a Control (min size ~500x70)
	# - child "BG" fills background (optional)
	# - child "Mid" is a 2px center marker (optional)
	# - child "Pos" anchored to center-left, grows right
	# - child "Neg" anchored to center-right, grows left
	# We'll size Pos/Neg by half-width * ratio
	var w := (bar_container as Control).size.x
	var h := (bar_container as Control).size.y
	var half := w * 0.5

	var pos_w := half * clampf(pos_ratio, 0.0, 1.0)
	var neg_w := half * clampf(neg_ratio, 0.0, 1.0)

	# Positive fill
	pos_rect.position = Vector2(half, 0)
	pos_rect.size = Vector2(pos_w, h)
	pos_rect.pivot_offset = Vector2(0, 0)

	# Negative fill (rendered as a rect whose X starts at (half - neg_w))
	neg_rect.position = Vector2(half - neg_w, 0)
	neg_rect.size = Vector2(neg_w, h)

	# Colors
	pos_rect.modulate = _tier_color(_safe_tier())
	neg_rect.modulate = Color(0.95, 0.35, 0.35)
