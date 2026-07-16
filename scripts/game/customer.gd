class_name Customer
extends Node2D
## One customer at the stall: a procedurally-drawn face with an order,
## a draining patience bar, and a mood that sours in real time.
## Built entirely in code (no art assets) — head, cap, eyes, mouth are
## Polygon2D shapes; expressions swap with patience level.

signal stormed_off(customer: Customer)

const SKIN_TONES: Array[Color] = [
	Color(0.78, 0.53, 0.26), Color(0.55, 0.33, 0.14),
	Color(0.88, 0.67, 0.41), Color(0.63, 0.40, 0.25),
]
const CAP_COLORS: Array[Color] = [
	Color(0.95, 0.45, 0.15), Color(0.15, 0.65, 0.6),
	Color(0.8, 0.25, 0.55), Color(0.3, 0.6, 0.25), Color(0.9, 0.75, 0.2),
]
const MOUTH_SMILE: PackedVector2Array = [
	Vector2(-15, 14), Vector2(0, 22), Vector2(15, 14),
	Vector2(12, 20), Vector2(0, 28), Vector2(-12, 20),
]
const MOUTH_FLAT: PackedVector2Array = [
	Vector2(-13, 17), Vector2(13, 17), Vector2(13, 23), Vector2(-13, 23),
]
const MOUTH_FROWN: PackedVector2Array = [
	Vector2(-15, 26), Vector2(0, 18), Vector2(15, 26),
	Vector2(12, 30), Vector2(0, 24), Vector2(-12, 30),
]

var order_size := 5
var filled := 0
var is_active := false

var _patience := 30.0
var _patience_max := 30.0
var _warned := false
var _skin: Color

var _head: Polygon2D
var _cap: Polygon2D
var _mouth: Polygon2D
var _bar_fill: ColorRect
var _order_label: Label
var _front_marker: Polygon2D


func _ready() -> void:
	_head = _add_polygon(_circle(46.0), Color.WHITE)
	_cap = _add_polygon(_half_disc(48.0), Color.WHITE)
	_cap.position = Vector2(0, -8)
	_add_polygon(_circle(5.0), Color(0.1, 0.08, 0.08)).position = Vector2(-15, -8)
	_add_polygon(_circle(5.0), Color(0.1, 0.08, 0.08)).position = Vector2(15, -8)
	_mouth = _add_polygon(MOUTH_SMILE, Color(0.35, 0.12, 0.1))

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(-50, -92)
	bar_bg.size = Vector2(100, 12)
	bar_bg.color = Color(0.1, 0.08, 0.1, 0.8)
	add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(-48, -90)
	_bar_fill.size = Vector2(96, 8)
	_bar_fill.color = Color(0.4, 0.9, 0.4)
	add_child(_bar_fill)

	_order_label = Label.new()
	_order_label.position = Vector2(-40, 52)
	_order_label.size = Vector2(80, 36)
	_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_order_label.add_theme_font_size_override("font_size", 27)
	_order_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	add_child(_order_label)

	_front_marker = _add_polygon(
		PackedVector2Array([Vector2(-13, -122), Vector2(13, -122), Vector2(0, -102)]),
		Color(1, 0.85, 0.25))
	_front_marker.visible = false
	deactivate()


func activate(new_order_size: int, patience_seconds: float) -> void:
	order_size = new_order_size
	filled = 0
	_patience_max = patience_seconds
	_patience = patience_seconds
	_warned = false
	_skin = SKIN_TONES.pick_random()
	_cap.color = CAP_COLORS.pick_random()
	modulate = Color.WHITE
	scale = Vector2.ONE
	is_active = true
	visible = true
	set_process(true)
	_refresh()


func deactivate() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_front(false)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_patience -= delta
	if not _warned and patience_ratio() < 0.3:
		_warned = true
		EffectsManager.score_popup("Bhaiya jaldi!!", global_position + Vector2(0, -130), Color(1, 0.6, 0.4))
	_refresh()
	if _patience <= 0.0:
		stormed_off.emit(self)


## Returns true when the order is complete.
func add_puri() -> bool:
	filled += 1
	_refresh()
	return filled >= order_size


func burn_plate() -> void:
	filled = 0
	_refresh()


## Knock off a fraction of max patience (chili/fly accidents).
func hit_patience(fraction: float) -> void:
	_patience = maxf(_patience - _patience_max * fraction, 0.01)
	_refresh()


func patience_ratio() -> float:
	return clampf(_patience / _patience_max, 0.0, 1.0)


func set_front(front: bool) -> void:
	if _front_marker != null:
		_front_marker.visible = front
	scale = Vector2.ONE * (1.12 if front else 0.95)


func _refresh() -> void:
	var ratio := patience_ratio()
	_bar_fill.size.x = 96.0 * ratio
	_bar_fill.color = Color(0.4, 0.9, 0.4).lerp(Color(1.0, 0.25, 0.2), 1.0 - ratio)
	_order_label.text = "%d/%d" % [filled, order_size]
	if ratio > 0.6:
		_mouth.polygon = MOUTH_SMILE
		_head.color = _skin
	elif ratio > 0.3:
		_mouth.polygon = MOUTH_FLAT
		_head.color = _skin
	else:
		_mouth.polygon = MOUTH_FROWN
		_head.color = _skin.lerp(Color(1, 0.3, 0.2), 0.3)


func _add_polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	add_child(poly)
	return poly


func _circle(radius: float, segments: int = 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


func _half_disc(radius: float, segments: int = 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		var angle := PI + PI * i / segments
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out
