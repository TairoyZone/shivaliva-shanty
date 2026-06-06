## Audio — the game's sound spine (autoload). `Audio.play_sfx("coin")` fires a one-shot from the SFX bank
## on a POLYPHONIC player, so a 5-piece cascade layers five clinks instead of cutting itself off; a small
## random pitch keeps repeats from sounding robotic. `Audio.play_music(stream)` loops a track. The bank is
## PLACEHOLDER procedural .wav (synthesised by tools/sfx_gen.gd — no lifted audio); swap any for a real
## clip by overwriting res://audio/sfx/<name>.wav, no code change. PROCESS_MODE_ALWAYS so UI/result sounds
## still play while the tree is paused (panels, the READY beat). See [[godot-borrow-todo]].
extends Node


## The SFX bank: name -> imported clip. Add a line + a .wav to add a sound.
var _sfx : Dictionary = {
	"coin": preload("res://audio/sfx/coin.wav"),
	"clack": preload("res://audio/sfx/clack.wav"),
	"pop": preload("res://audio/sfx/pop.wav"),
	"whoosh": preload("res://audio/sfx/whoosh.wav"),
	"thunk": preload("res://audio/sfx/thunk.wav"),
	"chime": preload("res://audio/sfx/chime.wav"),
	"buzz": preload("res://audio/sfx/buzz.wav"),
	"click": preload("res://audio/sfx/click.wav"),
	"toss": preload("res://audio/sfx/toss.wav"),
	# --- Borrowed library SFX — richer designed/recorded sounds alongside the procedural placeholders.
	# --- Licenses + attribution in audio/CREDITS.md: GDQuest CC-BY 4.0 · Kenney + Junkala CC0 ·
	# --- tcarisland CC-BY-SA 4.0 (voice) · unicaegames CC0 (type_key).
	"voice": preload("res://audio/sfx/voice_talk.ogg"),
	"voice2": preload("res://audio/sfx/voice_talk2.ogg"),
	"type_key": preload("res://audio/sfx/type_key.wav"),
	"pickup": preload("res://audio/sfx/pickup.wav"),
	"powerup": preload("res://audio/sfx/powerup.wav"),
	"hit": preload("res://audio/sfx/hit.wav"),
	"bop": preload("res://audio/sfx/bop.wav"),
	"hurt": preload("res://audio/sfx/hurt.wav"),
	"ko": preload("res://audio/sfx/ko.wav"),
	"pain": preload("res://audio/sfx/pain.wav"),
	"laser": preload("res://audio/sfx/laser.wav"),
	"whoosh2": preload("res://audio/sfx/whoosh2.ogg"),
	"explosion": preload("res://audio/sfx/explosion.ogg"),
}

## The music bank (looping ambient beds — procedural, see tools/music_gen.gd).
var _music : Dictionary = {
	"overworld": preload("res://audio/music/overworld.wav"),
	"title": preload("res://audio/music/title.ogg"),   # Juhani Junkala (CC0) — a chiptune title theme (audition)
}

var _sfx_player : AudioStreamPlayer
var _music_player : AudioStreamPlayer
var _current_music : String = ""   # the playing track key — guards play_music_track against restarts
var _current_music_vol : float = -9.0

## Player settings (persisted to user://settings.cfg) — toggled from the Options panel, saved on change.
const SETTINGS_PATH : String = "user://settings.cfg"
var music_enabled : bool = true
var sfx_enabled : bool = true


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # sound keeps going through a paused tree (result panels, etc.)
	_load_settings()   # music / sfx on-off, restored from disk before anything plays
	# One POLYPHONIC SFX player — play_stream layers overlapping one-shots (a cascade of clears) without
	# the machine-gun cut-off you get re-triggering a single AudioStreamPlayer.
	_sfx_player = AudioStreamPlayer.new()
	var poly : AudioStreamPolyphonic = AudioStreamPolyphonic.new()
	poly.polyphony = 12
	_sfx_player.stream = poly
	add_child(_sfx_player)
	_sfx_player.play()
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -8.0
	add_child(_music_player)
	# Music is driven PER-SCENE now: main.gd plays "title", BaseLocation plays "overworld" (both via
	# play_music_track, guarded so walking between locations never restarts the bed).
	# SYSTEM-WIDE UI CLICK: every BaseButton in the game (code- OR scene-built) clicks on press, via one
	# hook on the tree's node_added — so new buttons inherit it for free. (System-wide SFX phase 2026-06-06.)
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)


# Fire a one-shot SFX by name (no-op if unknown). A little random pitch per play kills repetition fatigue.
func play_sfx(snd: String, volume_db: float = 0.0, pitch_jitter: float = 0.07) -> void:

	if not sfx_enabled:
		return
	if _sfx_player == null or not _sfx.has(snd):
		return
	var pb : AudioStreamPlaybackPolyphonic = _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if pb == null:
		return
	pb.play_stream(_sfx[snd], 0.0, volume_db, 1.0 + randf_range(-pitch_jitter, pitch_jitter))


func play_music(stream: AudioStream, volume_db: float = -8.0) -> void:

	if _music_player == null or stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


## Play a NAMED looping track, guarded so re-entering the same scene doesn't restart it. main.gd plays
## "title"; every BaseLocation plays "overworld". Forces the loop on the stream (WAV or Ogg).
func play_music_track(track: String, volume_db: float = -9.0) -> void:

	if track == _current_music or not _music.has(track):
		return
	_current_music = track
	_current_music_vol = volume_db
	_apply_music()


## (Re)start or stop the current track to match music_enabled. Called on a track change + on the toggle.
func _apply_music() -> void:

	if _music_player == null:
		return
	if not music_enabled or _current_music == "" or not _music.has(_current_music):
		_music_player.stop()
		return
	var s : AudioStream = _music[_current_music]
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	play_music(s, _current_music_vol)


func stop_music() -> void:

	if _music_player != null:
		_music_player.stop()


## Every button added to the tree gets a click on press — the system-wide UI sound in ONE place, so no
## button is ever silent and new ones need no wiring. (Opt a button out by playing your own sound instead.)
func _on_node_added(node: Node) -> void:

	if node is BaseButton:
		var b : BaseButton = node as BaseButton
		if not b.pressed.is_connected(_play_ui_click):
			b.pressed.connect(_play_ui_click)


func _play_ui_click() -> void:

	play_sfx("click", -3.0)


# --- Settings (the Options panel) -----------------------------------------------------------------------

func set_music_enabled(on: bool) -> void:

	if music_enabled == on:
		return
	music_enabled = on
	_apply_music()
	_save_settings()


func set_sfx_enabled(on: bool) -> void:

	if sfx_enabled == on:
		return
	sfx_enabled = on
	_save_settings()


func _load_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return   # no settings file yet — keep the defaults (both on)
	music_enabled = bool(cfg.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", true))


func _save_settings() -> void:

	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.save(SETTINGS_PATH)
