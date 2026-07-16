extends Node
## AudioManager — every sound in the game goes through here.
## SFX play through a fixed pool of players (round-robin), so rapid slicing
## never cuts sounds off and never allocates at runtime. Music has its own
## dedicated player with a simple fade.

const SFX_POOL_SIZE := 8
const MUSIC_FADE_SEC := 0.6

## Where each named sound lives. Regenerate the files any time with
## tools/generate_sfx.gd (or drop in hand-made replacements — same names).
const SFX_PATHS: Dictionary = {
	&"slice": "res://assets/sounds/slice.wav",
	&"crystal_break": "res://assets/sounds/crystal_break.wav",
	&"explosion": "res://assets/sounds/explosion.wav",
	&"button": "res://assets/sounds/button.wav",
	&"powerup": "res://assets/sounds/powerup.wav",
	&"game_over": "res://assets/sounds/game_over.wav",
	&"knock": "res://assets/sounds/knock.wav",
	&"pocket": "res://assets/sounds/pocket.wav",
	&"flick": "res://assets/sounds/flick.wav",
}

## Sound library: StringName -> AudioStream, loaded once at boot.
var _sfx_library: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0


func _ready() -> void:
	# Audio must keep working while the game is paused (button clicks, menu music).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	for sfx_name: StringName in SFX_PATHS:
		var path: String = SFX_PATHS[sfx_name]
		if ResourceLoader.exists(path):
			_sfx_library[sfx_name] = load(path)
		else:
			push_warning("[AudioManager] missing sound file: %s" % path)
	print("[AudioManager] ready — %d SFX players, %d sounds loaded" % [SFX_POOL_SIZE, _sfx_library.size()])


## Play a named sound effect, e.g. AudioManager.play_sfx(&"knock").
## volume_db lets impact sounds scale with hit strength (0 = full volume).
func play_sfx(sfx_name: StringName, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if not SaveManager.is_sfx_enabled():
		return
	var stream: AudioStream = _sfx_library.get(sfx_name)
	if stream == null:
		return  # Asset not added yet — silently skip so gameplay code never breaks.
	var player := _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = volume_db
	player.play()


func play_music(stream: AudioStream) -> void:
	if not SaveManager.is_music_enabled() or stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_SEC)


func stop_music() -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, MUSIC_FADE_SEC)
	tween.tween_callback(_music_player.stop)
