class_name CustomerQueue
extends Node2D
## The line at the stall. Manages up to 3 visible customers: arrivals,
## who is being served (the front customer gets your puris), serving,
## and angry storm-offs. Emits signals — game rules stay in the Game scene.

signal customer_served(tip_coins: int, at_position: Vector2)
signal customer_angry(at_position: Vector2)

const SLOT_POSITIONS: Array[Vector2] = [Vector2(150, 250), Vector2(380, 250), Vector2(600, 250)]
const CUSTOMER_POOL := 4
## The rush: patience shrinks and the queue fills as a run progresses.
const RAMP_DURATION := 90.0

var _pool: Array[Customer] = []
## Active customers, index 0 = front (being served).
var _line: Array[Customer] = []
var _arrival_timer := 0.5
var _run_time := 0.0


func _ready() -> void:
	for i in CUSTOMER_POOL:
		var customer := Customer.new()
		add_child(customer)
		customer.stormed_off.connect(_on_stormed_off)
		_pool.append(customer)
	GameManager.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_run_time += delta
	_arrival_timer -= delta
	if _arrival_timer <= 0.0:
		_try_arrival()
		_arrival_timer = randf_range(lerpf(4.0, 1.5, _difficulty()), lerpf(6.0, 3.0, _difficulty()))


func front() -> Customer:
	return _line[0] if not _line.is_empty() else null


## A caught puri goes to the front customer. Serves them when complete.
func add_puri() -> void:
	var customer := front()
	if customer == null:
		return
	if customer.add_puri():
		_serve(customer)


func burn_front_plate() -> void:
	var customer := front()
	if customer != null:
		customer.burn_plate()
		customer.hit_patience(0.15)


func hit_front_patience(fraction: float) -> void:
	var customer := front()
	if customer != null:
		customer.hit_patience(fraction)


func reset() -> void:
	for customer in _pool:
		customer.deactivate()
	_line.clear()
	_run_time = 0.0
	_arrival_timer = 0.5


func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_run_time = 0.0
		_arrival_timer = 0.5


func _difficulty() -> float:
	return clampf(_run_time / RAMP_DURATION, 0.0, 1.0)


func _max_concurrent() -> int:
	return mini(1 + int(_difficulty() * 2.5), SLOT_POSITIONS.size())


func _try_arrival() -> void:
	if _line.size() >= _max_concurrent():
		return
	var customer := _get_inactive()
	if customer == null:
		return
	var order := randi_range(4, 6)
	var patience := lerpf(30.0, 16.0, _difficulty())
	customer.activate(order, patience)
	_line.append(customer)
	_layout()


func _serve(customer: Customer) -> void:
	var tip := 5 + customer.order_size
	var at := customer.global_position
	_remove_from_line(customer)
	customer_served.emit(tip, at)


func _on_stormed_off(customer: Customer) -> void:
	var at := customer.global_position
	_remove_from_line(customer)
	customer_angry.emit(at)


func _remove_from_line(customer: Customer) -> void:
	customer.deactivate()
	_line.erase(customer)
	_layout()


func _layout() -> void:
	for i in _line.size():
		var customer := _line[i]
		customer.position = SLOT_POSITIONS[i]
		customer.set_front(i == 0)


func _get_inactive() -> Customer:
	for customer in _pool:
		if not customer.is_active:
			return customer
	return null
