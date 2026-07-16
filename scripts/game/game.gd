extends Node2D
## Game — the Pani Puri Panic gameplay scene. Wires the swipe input, the
## flying-item field, and the customer queue together. Rules of thumb:
##  - Catch puris -> they go to the FRONT customer's plate
##  - Complete an order -> served! tips + score, queue shifts
##  - Chili -> burns the front plate; Fly -> disgusts the customer
##  - A customer whose patience runs out storms off; 3 storm-offs = closed.

const PURI_POINTS := 10
const SERVE_POINTS := 50

const PRAISE_LINES: Array[String] = ["Wah bhaiya!", "Ek dum mast!", "Sabse tez!", "Kya baat hai!"]
const ANGRY_LINES: Array[String] = ["Hadd hai yaar!", "Kitna wait karau?!", "Bekaar service!"]

var _plates_served := 0

@onready var slash_controller: SlashController = $SlashController
@onready var item_spawner: ItemSpawner = $ItemSpawner
@onready var customer_queue: CustomerQueue = $CustomerQueue
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _lives_label: Label = $HUD/LivesLabel
@onready var _game_over_panel: Control = $HUD/GameOverPanel
@onready var _final_score_label: Label = $HUD/GameOverPanel/FinalScoreLabel
@onready var _best_label: Label = $HUD/GameOverPanel/BestLabel
@onready var _play_again_button: Button = $HUD/GameOverPanel/PlayAgainButton


func _ready() -> void:
	slash_controller.slash_started.connect(_on_slash_started)
	slash_controller.slash_segment.connect(_on_slash_segment)
	item_spawner.item_caught.connect(_on_item_caught)
	customer_queue.customer_served.connect(_on_customer_served)
	customer_queue.customer_angry.connect(_on_customer_angry)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.game_ended.connect(_on_game_ended)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_start_run()
	print("[Game] ready — the stall is open!")


func _start_run() -> void:
	_plates_served = 0
	customer_queue.reset()
	item_spawner.clear_field()
	GameManager.start_game(GameManager.GameMode.CLASSIC)


func _on_slash_started(_start_position: Vector2) -> void:
	AudioManager.play_sfx(&"slice", 0.25)


func _on_slash_segment(from_point: Vector2, to_point: Vector2) -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	item_spawner.test_slash_segment(from_point, to_point)


func _on_item_caught(data: ItemData, at_position: Vector2) -> void:
	match data.kind:
		ItemData.Kind.PURI:
			GameManager.register_slice(PURI_POINTS)
			AudioManager.play_sfx(&"crystal_break", 0.15)
			EffectsManager.crystal_burst(data.color, at_position)
			EffectsManager.shake(8.0)
			customer_queue.add_puri()
		ItemData.Kind.CHILI:
			GameManager.register_miss()
			AudioManager.play_sfx(&"explosion")
			EffectsManager.crystal_burst(Color(1.0, 0.35, 0.15), at_position)
			EffectsManager.score_popup("MIRCHI! Plate kharab!", at_position, Color(1.0, 0.45, 0.3))
			EffectsManager.shake(26.0)
			customer_queue.burn_front_plate()
		ItemData.Kind.FLY:
			GameManager.register_miss()
			AudioManager.play_sfx(&"explosion", 0.3)
			EffectsManager.crystal_burst(Color(0.4, 0.45, 0.6), at_position)
			EffectsManager.score_popup("CHHEE! Makkhi!", at_position, Color(0.7, 0.75, 0.9))
			EffectsManager.shake(14.0)
			customer_queue.hit_front_patience(0.35)


func _on_customer_served(tip_coins: int, at_position: Vector2) -> void:
	_plates_served += 1
	GameManager.register_slice(SERVE_POINTS)
	SaveManager.add_coins(tip_coins)
	AudioManager.play_sfx(&"powerup")
	EffectsManager.score_popup(PRAISE_LINES.pick_random() + "  +%d tip" % tip_coins,
		at_position, Color(0.6, 1.0, 0.6))
	EffectsManager.shake(12.0)


func _on_customer_angry(at_position: Vector2) -> void:
	AudioManager.play_sfx(&"explosion", 0.2)
	EffectsManager.score_popup(ANGRY_LINES.pick_random(), at_position, Color(1.0, 0.35, 0.3))
	EffectsManager.shake(20.0)
	GameManager.register_bomb_hit()


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score  %d" % score


func _on_combo_changed(combo: int, multiplier: int) -> void:
	_combo_label.text = "Streak %d    x%d" % [combo, multiplier]
	if combo > 0:
		_combo_label.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "Gussa  %d/3" % (GameManager.MAX_LIVES - lives)


func _on_game_ended(final_score: int, is_new_high_score: bool) -> void:
	AudioManager.play_sfx(&"game_over")
	_final_score_label.text = "Plates served  %d   |   Score  %d" % [_plates_served, final_score]
	_best_label.text = "NAYA RECORD!" if is_new_high_score else "Best  %d" % SaveManager.data.high_score
	_game_over_panel.visible = true


func _on_play_again_pressed() -> void:
	_game_over_panel.visible = false
	AudioManager.play_sfx(&"button")
	_start_run()
