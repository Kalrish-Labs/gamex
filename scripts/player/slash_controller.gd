class_name SlashController
extends Node2D
## Turns the player's swipe (touch on Android, mouse on PC) into:
##  1. a glowing blade trail rendered on screen
##  2. `slash_segment` signals — other systems listen to these to answer
##     "did the blade just cross me?" The controller knows nothing about
##     crystals; it only reports geometry ("signals up").

signal slash_started(start_position: Vector2)
signal slash_segment(from_point: Vector2, to_point: Vector2)
signal slash_ended

## Seconds a trail point stays on screen before fading away.
const POINT_LIFETIME := 0.35
## Drags shorter than this (pixels) are finger jitter — ignored.
const MIN_SEGMENT_LENGTH := 8.0
## Hard cap so the trail can never grow unbounded on fast circular swipes.
const MAX_POINTS := 24

@onready var _core_line: Line2D = $CoreLine
@onready var _glow_line: Line2D = $GlowLine

var _is_slashing := false
var _points: Array[Vector2] = []
var _point_times: Array[float] = []  # birth time of each point, parallel array


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_slash(_to_canvas(event.position))
		else:
			_end_slash()
	elif event is InputEventScreenDrag and _is_slashing:
		_extend_slash(_to_canvas(event.position))


func _process(_delta: float) -> void:
	_expire_old_points()
	_redraw_trail()


func _start_slash(at: Vector2) -> void:
	_is_slashing = true
	_points.clear()
	_point_times.clear()
	_add_point(at)
	slash_started.emit(at)


func _extend_slash(to: Vector2) -> void:
	var last: Vector2 = _points[_points.size() - 1]
	if last.distance_to(to) < MIN_SEGMENT_LENGTH:
		return
	_add_point(to)
	slash_segment.emit(last, to)


func _end_slash() -> void:
	if not _is_slashing:
		return
	_is_slashing = false
	slash_ended.emit()


func _add_point(point: Vector2) -> void:
	_points.append(point)
	_point_times.append(_now())
	if _points.size() > MAX_POINTS:
		_points.pop_front()
		_point_times.pop_front()


func _expire_old_points() -> void:
	var cutoff := _now() - POINT_LIFETIME
	while not _point_times.is_empty() and _point_times[0] < cutoff:
		_points.pop_front()
		_point_times.pop_front()


func _redraw_trail() -> void:
	var packed := PackedVector2Array(_points)
	_core_line.points = packed
	_glow_line.points = packed


## Converts a raw screen position to canvas space, so the trail stays correct
## even when we add camera shake later.
func _to_canvas(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
