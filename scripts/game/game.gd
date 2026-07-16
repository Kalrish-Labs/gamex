extends Node2D
## CARROM CLASH — the whole game: a physics carrom board built in code.
##
## How to play:
##  - Drag the striker sideways along the baseline to position it
##  - Drag anywhere else to aim (slingshot: pull back, release to shoot)
##  - Pocket coins for points: white/black 10, red queen 50
##  - Pocket a coin -> you shoot AGAIN. Pocket the striker -> foul, -20
##  - Board empty -> highest score wins. 2 players, one phone, pass and play.

enum Phase { READY, DRAG_STRIKER, AIMING, ROLLING, GAME_OVER }

const BOARD_CENTER := Vector2(360, 620)
const BOARD_HALF := 310.0
const FRAME_WIDTH := 46.0
const POCKET_RADIUS := 40.0
const COIN_RADIUS := 21.0
const STRIKER_RADIUS := 29.0
const BASELINE_OFFSET := 92.0           # baseline distance from board's bottom edge
const STRIKER_X_RANGE := 190.0          # striker travel from board center
const MAX_DRAG := 260.0                 # pull-back cap (pixels)
const IMPULSE_PER_PIXEL := 11.0
const SETTLE_SPEED_SQ := 90.0           # bodies below this speed² count as stopped
const MAX_ROLL_SECONDS := 8.0           # safety: force-resolve a stuck shot

const COIN_POINTS := 10
const QUEEN_POINTS := 50
const FOUL_PENALTY := 20

const COLOR_SURFACE := Color(0.87, 0.76, 0.55)
const COLOR_FRAME := Color(0.32, 0.19, 0.1)
const COLOR_WHITE_COIN := Color(0.95, 0.91, 0.8)
const COLOR_BLACK_COIN := Color(0.22, 0.19, 0.17)
const COLOR_QUEEN := Color(0.75, 0.13, 0.12)

var phase: Phase = Phase.READY
var current_player := 0                 # 0 = P1, 1 = P2
var scores: Array[int] = [0, 0]

var _striker: RigidBody2D
var _coins: Array[RigidBody2D] = []
var _aim_line: Line2D
var _touch_start := Vector2.ZERO
var _drag_current := Vector2.ZERO
var _pocketed_this_shot := 0
var _foul_this_shot := false
var _settle_delay := 0.0
var _rolling_time := 0.0
var _last_knock_ms := 0
var _striker_hints: Node2D
var _aim_ghost: Node2D
var _target_line: Line2D

@onready var _p1_label: Label = $HUD/P1Label
@onready var _p2_label: Label = $HUD/P2Label
@onready var _turn_label: Label = $HUD/TurnLabel
@onready var _game_over_panel: Control = $HUD/GameOverPanel
@onready var _title_label: Label = $HUD/GameOverPanel/TitleLabel
@onready var _final_score_label: Label = $HUD/GameOverPanel/FinalScoreLabel
@onready var _play_again_button: Button = $HUD/GameOverPanel/PlayAgainButton


func _ready() -> void:
	_build_board()
	_spawn_coins()
	_spawn_striker()
	_aim_line = Line2D.new()
	_aim_line.width = 5.0
	_aim_line.default_color = Color(1.0, 0.65, 0.2, 0.85)
	add_child(_aim_line)
	_build_striker_hints()
	_build_aim_guides()
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_update_hud()
	print("[CarromClash] board ready — P1 ka shot")


func _process(_delta: float) -> void:
	# Pulsing side-arrows on the striker while waiting — "you can drag me".
	_striker_hints.visible = phase == Phase.READY or phase == Phase.DRAG_STRIKER
	if _striker_hints.visible:
		_striker_hints.position = _striker.position
		_striker_hints.modulate.a = 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.006)


# ---------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ROLLING or phase == Phase.GAME_OVER:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(_to_canvas(event.position))
		else:
			_end_touch()
	elif event is InputEventScreenDrag:
		_update_touch(_to_canvas(event.position))


func _begin_touch(at: Vector2) -> void:
	_touch_start = at
	_drag_current = at
	if at.distance_to(_striker.position) <= STRIKER_RADIUS * 2.4:
		phase = Phase.DRAG_STRIKER
	else:
		phase = Phase.AIMING


func _update_touch(at: Vector2) -> void:
	_drag_current = at
	match phase:
		Phase.DRAG_STRIKER:
			var x := clampf(at.x, BOARD_CENTER.x - STRIKER_X_RANGE, BOARD_CENTER.x + STRIKER_X_RANGE)
			_striker.position = Vector2(x, _baseline_y())
		Phase.AIMING:
			_draw_aim()


func _end_touch() -> void:
	if phase == Phase.AIMING:
		# Direct flick: the striker goes WHERE you dragged, from either side.
		var flick := _drag_current - _touch_start
		if flick.length() > 18.0:
			_shoot(flick.limit_length(MAX_DRAG))
		else:
			phase = Phase.READY
	elif phase == Phase.DRAG_STRIKER:
		phase = Phase.READY
	_clear_aim_guides()


const AIM_CAST_LENGTH := 1200.0

func _draw_aim() -> void:
	var flick := _drag_current - _touch_start
	_clear_aim_guides()
	if flick.length() < 18.0:
		return
	var capped := flick.limit_length(MAX_DRAG)
	var direction := capped.normalized()
	var power := capped.length() / MAX_DRAG
	# Orange -> red and thicker as power rises.
	_aim_line.default_color = Color(1.0, 0.65, 0.2, 0.85).lerp(Color(1.0, 0.18, 0.1, 0.95), power)
	_aim_line.width = 5.0 + 3.0 * power
	# Physically project the shot: the line ends exactly at first contact,
	# a ghost striker marks the impact, and a white tick shows where the
	# struck coin will head.
	var impact := _project_shot(direction)
	_aim_line.add_point(_striker.position)
	_aim_line.add_point(impact.position)
	if impact.hit:
		_aim_ghost.position = impact.position
		_aim_ghost.visible = true
		if impact.target != null:
			var target: Node2D = impact.target
			# Green = your coin (or the queen), red = opponent's coin.
			var owner: int = target.get_meta("owner") if target.has_meta("owner") else -1
			_target_line.default_color = Color(1.0, 0.35, 0.3, 0.8) \
				if owner == 1 - current_player else Color(0.4, 1.0, 0.5, 0.8)
			_target_line.add_point(target.position)
			_target_line.add_point(target.position + impact.deflect * 130.0)


## Sweeps the striker's own circle along the aim direction through real
## physics space. Returns where it first hits, and what it hits.
func _project_shot(direction: Vector2) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = STRIKER_RADIUS
	params.shape = circle
	params.transform = Transform2D(0.0, _striker.position)
	params.motion = direction * AIM_CAST_LENGTH
	params.exclude = [_striker.get_rid()]
	var cast := space.cast_motion(params)
	var hit := cast[0] < 1.0
	var contact := _striker.position + direction * AIM_CAST_LENGTH * cast[0]
	var result := {hit = hit, position = contact, target = null, deflect = Vector2.ZERO}
	if hit:
		# Identify the coin at the contact point to predict its deflection.
		params.transform = Transform2D(0.0, contact + direction * 4.0)
		params.motion = Vector2.ZERO
		for entry: Dictionary in space.intersect_shape(params, 4):
			var collider := entry.collider as Node2D
			if collider is RigidBody2D and collider != _striker:
				result.target = collider
				result.deflect = (collider.position - contact).normalized()
				break
	return result


func _clear_aim_guides() -> void:
	_aim_line.clear_points()
	_target_line.clear_points()
	_aim_ghost.visible = false


func _shoot(pull: Vector2) -> void:
	phase = Phase.ROLLING
	_pocketed_this_shot = 0
	_foul_this_shot = false
	_settle_delay = 0.4
	_rolling_time = 0.0
	_striker.freeze = false
	_striker.apply_central_impulse(pull * IMPULSE_PER_PIXEL)
	AudioManager.play_sfx(&"flick", 0.2)


# ------------------------------------------------------------ turn flow --

func _physics_process(delta: float) -> void:
	if phase != Phase.ROLLING:
		return
	_settle_delay -= delta
	_rolling_time += delta
	if _rolling_time > MAX_ROLL_SECONDS:
		_freeze_all_motion()
		_resolve_shot()
		return
	if _settle_delay > 0.0 or not _all_settled():
		return
	_resolve_shot()


func _freeze_all_motion() -> void:
	_striker.linear_velocity = Vector2.ZERO
	for coin in _coins:
		coin.linear_velocity = Vector2.ZERO
		coin.angular_velocity = 0.0


func _all_settled() -> bool:
	if not _striker.freeze and _striker.linear_velocity.length_squared() > SETTLE_SPEED_SQ:
		return false
	for coin in _coins:
		if coin.linear_velocity.length_squared() > SETTLE_SPEED_SQ:
			return false
	return true


func _resolve_shot() -> void:
	if _coins.is_empty():
		_end_game()
		return
	# Strict alternation — every shot changes hands. (The classic
	# "pocket = shoot again" rule let one player monopolize the board.)
	current_player = 1 - current_player
	EffectsManager.score_popup("Player %d ka shot" % (current_player + 1),
		BOARD_CENTER + Vector2(0, -80), Color(1.0, 0.8, 0.4))
	_reset_striker()
	phase = Phase.READY
	_update_hud()


func _reset_striker() -> void:
	_striker.freeze = true
	_striker.linear_velocity = Vector2.ZERO
	_striker.angular_velocity = 0.0
	_striker.position = Vector2(BOARD_CENTER.x, _baseline_y())
	_striker.visible = true


func _end_game() -> void:
	phase = Phase.GAME_OVER
	AudioManager.play_sfx(&"game_over")
	var line := ""
	if scores[0] > scores[1]:
		line = "PLAYER 1 JEET GAYA!"
	elif scores[1] > scores[0]:
		line = "PLAYER 2 JEET GAYA!"
	else:
		line = "BARABAR! DRAW!"
	_title_label.text = line
	_final_score_label.text = "P1  %d   —   P2  %d" % [scores[0], scores[1]]
	SaveManager.submit_score(maxi(scores[0], scores[1]))
	_game_over_panel.visible = true


func _on_play_again_pressed() -> void:
	AudioManager.play_sfx(&"button")
	get_tree().reload_current_scene()


# ------------------------------------------------------------- pockets --

func _on_pocket_entered(body: Node2D) -> void:
	if body == _striker:
		_foul_this_shot = true
		scores[current_player] = maxi(scores[current_player] - FOUL_PENALTY, 0)
		AudioManager.play_sfx(&"explosion", 0.2)
		EffectsManager.score_popup("FOUL! -%d" % FOUL_PENALTY, _striker.position, Color(1.0, 0.4, 0.3))
		EffectsManager.shake(14.0)
		_striker.set_deferred("freeze", true)
		_striker.visible = false
		_update_hud()
		return
	var coin := body as RigidBody2D
	if coin == null or not _coins.has(coin):
		return
	_coins.erase(coin)
	_pocketed_this_shot += 1
	var points: int = coin.get_meta("points")
	var owner: int = coin.get_meta("owner")
	var is_queen: bool = coin.get_meta("is_queen")
	AudioManager.play_sfx(&"pocket", 0.15)
	if owner == 1 - current_player:
		# Pocketed the OPPONENT's coin — the points go to them.
		scores[owner] += points
		EffectsManager.score_popup("GALAT GOTI! P%d ko +%d" % [owner + 1, points],
			coin.global_position, Color(1.0, 0.45, 0.35))
	else:
		scores[current_player] += points
		EffectsManager.score_popup("RANI! +%d" % points if is_queen else "+%d" % points,
			coin.global_position, COLOR_QUEEN.lightened(0.4) if is_queen else Color(1.0, 0.95, 0.7))
	EffectsManager.crystal_burst(Color(1.0, 0.85, 0.4), coin.global_position)
	EffectsManager.shake(8.0)
	coin.queue_free()
	_update_hud()


# ------------------------------------------------------- board building --

func _build_board() -> void:
	var half := BOARD_HALF
	# Frame (dark wood) then playing surface.
	_add_rect_visual(BOARD_CENTER, Vector2(half + FRAME_WIDTH, half + FRAME_WIDTH) * 2.0, COLOR_FRAME)
	_add_rect_visual(BOARD_CENTER, Vector2(half, half) * 2.0, COLOR_SURFACE)
	# Center circle decoration + baselines.
	_add_circle_visual(BOARD_CENTER, 95.0, Color(0.72, 0.5, 0.32, 0.5))
	_add_circle_visual(BOARD_CENTER, 82.0, COLOR_SURFACE)
	_add_circle_visual(BOARD_CENTER, 12.0, COLOR_QUEEN.darkened(0.2))
	for side in [-1.0, 1.0]:
		_add_rect_visual(BOARD_CENTER + Vector2(0, side * (half - BASELINE_OFFSET)),
			Vector2(STRIKER_X_RANGE * 2.0 + 60.0, 5.0), Color(0.5, 0.3, 0.15, 0.7))
	# Walls (static physics).
	var walls := StaticBody2D.new()
	walls.physics_material_override = _material(0.45, 0.2)
	for i in 4:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var vertical := i >= 2
		rect.size = Vector2(40.0, (half + 40.0) * 2.0) if vertical else Vector2((half + 40.0) * 2.0, 40.0)
		shape.shape = rect
		var dir := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][i] as Vector2
		shape.position = BOARD_CENTER + dir * (half + 20.0)
		walls.add_child(shape)
	add_child(walls)
	# Pockets (sensors in the four corners).
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var pos: Vector2 = BOARD_CENTER + corner * (half - 34.0)
		_add_circle_visual(pos, POCKET_RADIUS, Color(0.1, 0.07, 0.05))
		var pocket := Area2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = POCKET_RADIUS - 12.0
		shape.shape = circle
		pocket.add_child(shape)
		pocket.position = pos
		pocket.body_entered.connect(_on_pocket_entered)
		add_child(pocket)


func _spawn_coins() -> void:
	_coins.clear()
	# Queen in the center — open to both players.
	var queen := _create_disc(BOARD_CENTER, COIN_RADIUS, COLOR_QUEEN, QUEEN_POINTS, true)
	queen.set_meta("owner", -1)
	_coins.append(queen)
	# Inner ring of 6, outer ring of 12, alternating white (P1) / black (P2).
	for ring in [{count = 6, radius = 47.0}, {count = 12, radius = 94.0}]:
		for i: int in ring.count:
			var angle := TAU * i / float(ring.count)
			var pos: Vector2 = BOARD_CENTER + Vector2(cos(angle), sin(angle)) * ring.radius
			var is_white := i % 2 == 0
			var coin := _create_disc(pos, COIN_RADIUS,
				COLOR_WHITE_COIN if is_white else COLOR_BLACK_COIN, COIN_POINTS, false)
			coin.set_meta("owner", 0 if is_white else 1)
			_coins.append(coin)


func _spawn_striker() -> void:
	_striker = _create_disc(Vector2(BOARD_CENTER.x, _baseline_y()), STRIKER_RADIUS,
		Color(0.85, 0.89, 0.95), 0, false)
	_striker.mass = 2.2
	_striker.linear_damp = 1.7
	_striker.freeze = true
	# Decorative inner ring so it reads as "the striker".
	var ring := Polygon2D.new()
	ring.polygon = _circle_points(STRIKER_RADIUS * 0.55)
	ring.color = Color(0.25, 0.45, 0.8)
	_striker.add_child(ring)


func _create_disc(pos: Vector2, radius: float, color: Color, points: int, is_queen: bool) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.gravity_scale = 0.0
	body.linear_damp = 2.0
	body.angular_damp = 7.0
	body.position = pos
	body.physics_material_override = _material(0.4, 0.15)
	body.set_meta("points", points)
	body.set_meta("is_queen", is_queen)
	# Fast shots must never tunnel through coins or walls.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Collision knocks: every real impact makes a clack, scaled by force.
	body.contact_monitor = true
	body.max_contacts_reported = 2
	body.body_entered.connect(_on_body_knock.bind(body))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = _circle_points(radius)
	visual.color = color
	body.add_child(visual)
	var highlight := Polygon2D.new()
	highlight.polygon = _circle_points(radius * 0.62)
	highlight.position = Vector2(-radius * 0.18, -radius * 0.18)
	highlight.color = Color(1, 1, 1, 0.14)
	body.add_child(highlight)
	add_child(body)
	return body


## A physics body hit something — play a clack whose volume tracks impact
## speed. Throttled so a scatter of coins doesn't machine-gun the speakers.
func _on_body_knock(other: Node, body: RigidBody2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_knock_ms < 60:
		return
	var impact_speed := body.linear_velocity.length()
	if other is RigidBody2D:
		impact_speed = maxf(impact_speed, (body.linear_velocity - (other as RigidBody2D).linear_velocity).length())
	if impact_speed < 50.0:
		return
	_last_knock_ms = now
	var volume_db := clampf(remap(impact_speed, 50.0, 1400.0, -16.0, 0.0), -16.0, 0.0)
	AudioManager.play_sfx(&"knock", 0.18, volume_db)


func _build_aim_guides() -> void:
	_aim_ghost = Node2D.new()
	var ghost_fill := Polygon2D.new()
	ghost_fill.polygon = _circle_points(STRIKER_RADIUS)
	ghost_fill.color = Color(1, 1, 1, 0.18)
	_aim_ghost.add_child(ghost_fill)
	var ghost_ring := Polygon2D.new()
	ghost_ring.polygon = _circle_points(STRIKER_RADIUS * 0.55)
	ghost_ring.color = Color(0.25, 0.45, 0.8, 0.35)
	_aim_ghost.add_child(ghost_ring)
	_aim_ghost.visible = false
	add_child(_aim_ghost)
	_target_line = Line2D.new()
	_target_line.width = 3.0
	_target_line.default_color = Color(1, 1, 1, 0.55)
	add_child(_target_line)


func _build_striker_hints() -> void:
	_striker_hints = Node2D.new()
	for side in [-1.0, 1.0]:
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(side * (STRIKER_RADIUS + 34.0), 0.0),
			Vector2(side * (STRIKER_RADIUS + 16.0), -12.0),
			Vector2(side * (STRIKER_RADIUS + 16.0), 12.0),
		])
		arrow.color = Color(1.0, 1.0, 1.0, 0.8)
		_striker_hints.add_child(arrow)
	add_child(_striker_hints)


# --------------------------------------------------------------- helpers --

func _update_hud() -> void:
	_p1_label.text = "P1  %d" % scores[0]
	_p2_label.text = "P2  %d" % scores[1]
	_turn_label.text = "Player 1 ka shot — SAFED goti" if current_player == 0 \
		else "Player 2 ka shot — KALI goti"
	_p1_label.modulate = Color(1, 0.85, 0.4) if current_player == 0 else Color(1, 1, 1, 0.6)
	_p2_label.modulate = Color(1, 0.85, 0.4) if current_player == 1 else Color(1, 1, 1, 0.6)


## Each player shoots from their own side: P1 from the bottom baseline,
## P2 from the top one — like sitting across a real board.
func _baseline_y() -> float:
	if current_player == 0:
		return BOARD_CENTER.y + BOARD_HALF - BASELINE_OFFSET
	return BOARD_CENTER.y - BOARD_HALF + BASELINE_OFFSET


func _material(bounce: float, friction: float) -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.bounce = bounce
	mat.friction = friction
	return mat


func _add_rect_visual(center: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = center - size * 0.5
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _add_circle_visual(center: Vector2, radius: float, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = _circle_points(radius)
	poly.position = center
	poly.color = color
	add_child(poly)


func _circle_points(radius: float, segments: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


func _to_canvas(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position
