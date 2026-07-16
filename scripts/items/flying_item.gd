class_name FlyingItem
extends Node2D
## One flying item (puri, chili, ...). Pooled and reused forever — `launch()`
## activates it, `deactivate()` returns it to the pool. Motion is simple
## ballistic math (no physics bodies — cheap on budget Androids).
##
## Visuals come entirely from ItemData: silhouette, color, kind.
## Chilis get a pulsing red danger glow; puris get a golden sheen.

signal caught(item: FlyingItem)
signal missed(item: FlyingItem)

const GRAVITY := 2200.0
## Once falling below this Y the item is gone for good (viewport is 1280).
const KILL_Y := 1450.0
## Fallback silhouette if a data file defines no shape.
const DEFAULT_SHAPE: PackedVector2Array = [
	Vector2(46, 0), Vector2(42.5, 17.6), Vector2(32.5, 32.5), Vector2(17.6, 42.5),
	Vector2(0, 46), Vector2(-17.6, 42.5), Vector2(-32.5, 32.5), Vector2(-42.5, 17.6),
	Vector2(-46, 0), Vector2(-42.5, -17.6), Vector2(-32.5, -32.5), Vector2(-17.6, -42.5),
	Vector2(0, -46), Vector2(17.6, -42.5), Vector2(32.5, -32.5), Vector2(42.5, -17.6),
]

var data: ItemData
var is_active := false

## Blade hit distance from the item's center, before node scale.
var _catch_radius := 55.0
var _velocity := Vector2.ZERO
var _spin := 0.0

@onready var _glow: Polygon2D = $Glow
@onready var _body: Polygon2D = $Body
@onready var _shine: Polygon2D = $Shine


func launch(new_data: ItemData, start_position: Vector2, velocity: Vector2) -> void:
	data = new_data
	position = start_position
	_velocity = velocity
	rotation = randf_range(0.0, TAU)
	_apply_visuals()
	is_active = true
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	rotation += _spin * delta
	if data.kind == ItemData.Kind.CHILI:
		# Menacing heartbeat on the glow — reads DANGER instantly.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		_glow.color.a = 0.25 + 0.35 * pulse
	elif data.kind == ItemData.Kind.FLY:
		# Erratic buzzing zigzag.
		position.x += sin(Time.get_ticks_msec() * 0.02) * 90.0 * delta
	if _velocity.y > 0.0 and position.y > KILL_Y:
		deactivate()
		missed.emit(self)


## True if the swipe segment [from_point, to_point] crosses this item.
func intersects_segment(from_point: Vector2, to_point: Vector2) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(global_position, from_point, to_point)
	var hit_radius := _catch_radius * scale.x
	return closest.distance_squared_to(global_position) <= hit_radius * hit_radius


func catch() -> void:
	if not is_active:
		return
	deactivate()
	caught.emit(self)


func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)


func _apply_visuals() -> void:
	var shape := data.shape if data.shape.size() >= 3 else DEFAULT_SHAPE
	_body.polygon = shape
	_glow.polygon = shape
	_body.color = data.color
	match data.kind:
		ItemData.Kind.CHILI:
			_glow.color = Color(1.0, 0.25, 0.1, 0.45)
			# Green stem highlight at the chili's top.
			_shine.polygon = _scaled(shape, 0.3)
			_shine.position = Vector2(0, -30)
			_shine.color = Color(0.3, 0.75, 0.3, 0.95)
			_spin = randf_range(-2.0, 2.0)
			scale = Vector2.ONE * randf_range(0.9, 1.05)
		ItemData.Kind.FLY:
			_glow.color = Color(0.5, 0.55, 0.7, 0.2)
			# Pale wing sheen.
			_shine.polygon = _scaled(shape, 0.55)
			_shine.position = Vector2(0, -8)
			_shine.color = Color(0.75, 0.8, 0.95, 0.5)
			_spin = randf_range(-6.0, 6.0)
			scale = Vector2.ONE * randf_range(0.8, 0.95)
		_:
			# Golden fried sheen for puris (and a soft warm glow).
			_glow.color = Color(data.color, 0.25)
			_shine.polygon = _scaled(shape, 0.45)
			_shine.position = Vector2(-9, -13)
			_shine.color = Color(1.0, 0.97, 0.85, 0.3)
			_spin = randf_range(-3.5, 3.5)
			scale = Vector2.ONE * randf_range(0.85, 1.1)


func _scaled(shape: PackedVector2Array, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(shape.size())
	for i in shape.size():
		out[i] = shape[i] * factor
	return out
