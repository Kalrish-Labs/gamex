extends Node
## SaveManager — the single source of truth for all persistent player data.
## Everything the player owns or has achieved lives in `data` and is written
## to disk as JSON. Other systems never touch the file — they go through here.

signal coins_changed(new_amount: int)
signal high_score_changed(new_high_score: int)

const SAVE_PATH := "user://save.json"

## Defaults double as the save-file schema. New fields added in future updates
## are merged into old save files automatically (see _merge_defaults).
const DEFAULT_DATA: Dictionary = {
	"coins": 0,
	"high_score": 0,
	"unlocked_swords": ["basic"],
	"equipped_sword": "basic",
	"settings": {
		"music_enabled": true,
		"sfx_enabled": true,
		"haptics_enabled": true,
	},
	"stats": {
		"games_played": 0,
		"best_combo": 0,
		"highest_score": 0,
		"puris_caught": 0,
		"chilis_hit": 0,
		"time_played_sec": 0.0,
	},
}

var data: Dictionary = {}


func _ready() -> void:
	load_game()
	print("[SaveManager] ready — coins: %d, high score: %d" % [data.coins, data.high_score])


func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] could not open save file, using defaults")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge_defaults(data, parsed)
	else:
		push_warning("[SaveManager] save file corrupted, using defaults")


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] could not write save file")
		return
	file.store_string(JSON.stringify(data, "\t"))


func add_coins(amount: int) -> void:
	data.coins += amount
	coins_changed.emit(data.coins)
	save_game()


func spend_coins(amount: int) -> bool:
	if data.coins < amount:
		return false
	data.coins -= amount
	coins_changed.emit(data.coins)
	save_game()
	return true


## Returns true if this score is a new record.
func submit_score(score: int) -> bool:
	if score <= data.high_score:
		return false
	data.high_score = score
	high_score_changed.emit(score)
	save_game()
	return true


func is_music_enabled() -> bool:
	return data.settings.music_enabled


func is_sfx_enabled() -> bool:
	return data.settings.sfx_enabled


func add_stat(stat_name: String, amount: float = 1.0) -> void:
	if not data.stats.has(stat_name):
		push_warning("[SaveManager] unknown stat: %s" % stat_name)
		return
	data.stats[stat_name] += amount


## Copies values from `saved` onto `defaults`, keeping any new default keys
## that older save files don't have yet. Runs recursively for nested sections.
func _merge_defaults(defaults: Dictionary, saved: Dictionary) -> void:
	for key: Variant in saved:
		if not defaults.has(key):
			continue
		if defaults[key] is Dictionary and saved[key] is Dictionary:
			_merge_defaults(defaults[key], saved[key])
		else:
			defaults[key] = saved[key]
