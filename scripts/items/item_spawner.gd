class_name ItemSpawner
extends Node2D
## Launches flying items (puris, chilis, ...) from the karahi below the
## screen and owns the object pool. Nothing is instantiated during gameplay —
## POOL_SIZE items are created once at startup and recycled forever.

## For gameplay/effects: fired for every caught item, with what and where.
signal item_caught(data: ItemData, at_position: Vector2)

const ITEM_SCENE := preload("res://scenes/items/flying_item.tscn")
const POOL_SIZE := 24
## Seconds of survival until waves reach maximum intensity.
const RAMP_DURATION := 90.0

const TYPE_PATHS: Array[String] = [
	"res://scenes/items/data/puri.tres",
	"res://scenes/items/data/chili.tres",
	"res://scenes/items/data/fly.tres",
]

## Items spawn just below the visible screen (viewport is 720x1280).
const SPAWN_Y := 1360.0

var _types: Array[ItemData] = []
var _pool: Array[FlyingItem] = []
var _time_to_next_wave := 1.0
## Seconds survived this run — drives the difficulty ramp.
var _run_time := 0.0


func _ready() -> void:
	for path in TYPE_PATHS:
		_types.append(load(path) as ItemData)
	for i in POOL_SIZE:
		_pool.append(_create_item())
	GameManager.state_changed.connect(_on_state_changed)
	print("[ItemSpawner] ready — %d types, pool of %d" % [_types.size(), _pool.size()])


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_run_time += delta
	_time_to_next_wave -= delta
	if _time_to_next_wave <= 0.0:
		_spawn_wave()
		var d := _difficulty()
		_time_to_next_wave = randf_range(lerpf(0.9, 0.45, d), lerpf(1.6, 0.8, d))


## 0.0 (fresh run) -> 1.0 (maximum rush) over RAMP_DURATION seconds.
func _difficulty() -> float:
	return clampf(_run_time / RAMP_DURATION, 0.0, 1.0)


## Called by the Game scene for every swipe movement. One swipe can catch
## several puris at once — that's what makes fast swipes feel great.
func test_slash_segment(from_point: Vector2, to_point: Vector2) -> void:
	for item in _pool:
		if item.is_active and item.intersects_segment(from_point, to_point):
			item.catch()


## Deactivate every flying item (used when restarting after game over).
func clear_field() -> void:
	for item in _pool:
		item.deactivate()


func _spawn_wave() -> void:
	# Waves grow from 1-3 items to 3-5 at full rush.
	var d := _difficulty()
	for i in randi_range(1 + int(d * 2.0), 3 + int(d * 2.0)):
		_launch_one()


func _launch_one() -> void:
	var item := _get_inactive()
	if item == null:
		return  # Pool exhausted — safe to just skip a spawn.
	var d := _difficulty()
	var x := randf_range(100.0, 620.0)
	# Horizontal push toward screen center so arcs stay on screen.
	var vx := (360.0 - x) * randf_range(0.3, 0.8)
	var vy := randf_range(-2350.0, -1900.0) - 150.0 * d
	item.launch(_pick_type(), Vector2(x, SPAWN_Y), Vector2(vx, vy))


func _create_item() -> FlyingItem:
	var item: FlyingItem = ITEM_SCENE.instantiate()
	add_child(item)
	item.deactivate()
	item.caught.connect(_on_item_caught)
	item.missed.connect(_on_item_missed)
	return item


func _get_inactive() -> FlyingItem:
	for item in _pool:
		if not item.is_active:
			return item
	return null


## Weighted random pick — spawn_weight makes chilis rarer than puris.
func _pick_type() -> ItemData:
	var total := 0.0
	for t in _types:
		total += t.spawn_weight
	var roll := randf() * total
	for t in _types:
		roll -= t.spawn_weight
		if roll <= 0.0:
			return t
	return _types[0]


func _on_item_caught(item: FlyingItem) -> void:
	# Consequences (scoring, plates, patience) are decided by the Game scene.
	item_caught.emit(item.data, item.global_position)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_run_time = 0.0
		_time_to_next_wave = 0.6


func _on_item_missed(item: FlyingItem) -> void:
	# Letting a chili fall is the CORRECT move — only missed puris break the streak.
	if not item.data.is_hazard():
		GameManager.register_miss()
