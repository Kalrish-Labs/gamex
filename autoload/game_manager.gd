extends Node
## GameManager — owns the state of the current round: score, combo, lives, mode.
## UI and gameplay scenes never store these themselves; they listen to the
## signals below and stay in sync automatically ("signals up, calls down").

signal state_changed(new_state: GameState)
signal score_changed(score: int)
signal combo_changed(combo: int, multiplier: int)
signal lives_changed(lives: int)
signal game_ended(final_score: int, is_new_high_score: bool)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
enum GameMode { CLASSIC, ARCADE, ZEN, CHALLENGE }

const MAX_LIVES := 3
## Every N consecutive slices raises the score multiplier by 1.
const COMBO_PER_MULTIPLIER := 5
const MAX_MULTIPLIER := 8

var state: GameState = GameState.MENU
var mode: GameMode = GameMode.CLASSIC
var score: int = 0
var combo: int = 0
var multiplier: int = 1
var lives: int = MAX_LIVES

var _best_combo_this_run: int = 0
var _run_start_ticks_ms: int = 0


func _ready() -> void:
	print("[GameManager] ready")


func start_game(new_mode: GameMode) -> void:
	mode = new_mode
	score = 0
	combo = 0
	multiplier = 1
	lives = MAX_LIVES
	_best_combo_this_run = 0
	_run_start_ticks_ms = Time.get_ticks_msec()
	_set_state(GameState.PLAYING)
	score_changed.emit(score)
	combo_changed.emit(combo, multiplier)
	lives_changed.emit(lives)


## Called by the slicing system every time a crystal is destroyed.
func register_slice(base_points: int) -> void:
	if state != GameState.PLAYING:
		return
	combo += 1
	_best_combo_this_run = maxi(_best_combo_this_run, combo)
	multiplier = mini(1 + combo / COMBO_PER_MULTIPLIER, MAX_MULTIPLIER)
	score += base_points * multiplier
	SaveManager.add_stat("puris_caught")
	combo_changed.emit(combo, multiplier)
	score_changed.emit(score)


## Called when a crystal falls off-screen unsliced.
func register_miss() -> void:
	if state != GameState.PLAYING or mode == GameMode.ZEN:
		return
	combo = 0
	multiplier = 1
	combo_changed.emit(combo, multiplier)


## Called when the player slices a bomb.
func register_bomb_hit() -> void:
	if state != GameState.PLAYING:
		return
	SaveManager.add_stat("chilis_hit")
	combo = 0
	multiplier = 1
	combo_changed.emit(combo, multiplier)
	if mode == GameMode.ZEN:
		return
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		end_game()


func set_paused(paused: bool) -> void:
	if state != GameState.PLAYING and state != GameState.PAUSED:
		return
	get_tree().paused = paused
	_set_state(GameState.PAUSED if paused else GameState.PLAYING)


func end_game() -> void:
	if state == GameState.GAME_OVER:
		return
	_set_state(GameState.GAME_OVER)
	var run_seconds := (Time.get_ticks_msec() - _run_start_ticks_ms) / 1000.0
	SaveManager.add_stat("games_played")
	SaveManager.add_stat("time_played_sec", run_seconds)
	SaveManager.data.stats.best_combo = maxi(SaveManager.data.stats.best_combo, _best_combo_this_run)
	SaveManager.data.stats.highest_score = maxi(SaveManager.data.stats.highest_score, score)
	var is_new_high_score := SaveManager.submit_score(score)
	SaveManager.save_game()
	game_ended.emit(score, is_new_high_score)


func go_to_menu() -> void:
	get_tree().paused = false
	_set_state(GameState.MENU)


func _set_state(new_state: GameState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
