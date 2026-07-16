extends CanvasLayer
## EffectsManager — all visual juice, fully pooled: crystal shatter bursts,
## floating score popups, camera shake. Gameplay code fires one call and
## never allocates a node. Lives on a high CanvasLayer so effects always
## draw above the play field.

const BURST_POOL_SIZE := 12
const POPUP_POOL_SIZE := 12
## How fast shake fades (higher = snappier).
const SHAKE_DECAY := 9.0

var _bursts: Array[CPUParticles2D] = []
var _popups: Array[Label] = []
var _next_burst := 0
var _next_popup := 0
var _shake_strength := 0.0
var _shard_scale_curve: Curve


func _ready() -> void:
	layer = 5
	_shard_scale_curve = Curve.new()
	_shard_scale_curve.add_point(Vector2(0.0, 1.0))
	_shard_scale_curve.add_point(Vector2(1.0, 0.0))
	for i in BURST_POOL_SIZE:
		_bursts.append(_create_burst())
	for i in POPUP_POOL_SIZE:
		_popups.append(_create_popup())
	print("[EffectsManager] ready — %d bursts, %d popups pooled" % [BURST_POOL_SIZE, POPUP_POOL_SIZE])


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if _shake_strength > 0.5:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength *= exp(-SHAKE_DECAY * delta)
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
		_shake_strength = 0.0


## Colored shard explosion where a crystal died.
func crystal_burst(color: Color, at_position: Vector2) -> void:
	var burst := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % BURST_POOL_SIZE
	burst.position = at_position
	burst.color = color
	burst.restart()


## Floating "+30"-style text that rises and fades.
func score_popup(text: String, at_position: Vector2, color: Color = Color(0.95, 0.98, 1.0)) -> void:
	var popup := _popups[_next_popup]
	_next_popup = (_next_popup + 1) % POPUP_POOL_SIZE
	var old_tween: Variant = popup.get_meta("tween", null)
	if old_tween is Tween and (old_tween as Tween).is_valid():
		(old_tween as Tween).kill()
	popup.text = text
	popup.position = at_position + Vector2(-popup.size.x * 0.5, -50.0)
	popup.modulate = Color(color, 1.0)
	popup.scale = Vector2(0.6, 0.6)
	popup.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 90.0, 0.7)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.16)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(popup, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(func() -> void: popup.visible = false)
	popup.set_meta("tween", tween)


## Kick the screen. Bigger slices/explosions pass bigger strength.
func shake(strength: float = 8.0) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _create_burst() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 1400.0)
	particles.initial_velocity_min = 220.0
	particles.initial_velocity_max = 560.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.scale_amount_curve = _shard_scale_curve
	add_child(particles)
	return particles


func _create_popup() -> Label:
	var label := Label.new()
	label.visible = false
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.05, 0.65))
	add_child(label)
	return label
