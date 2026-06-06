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
}

## The music bank (looping ambient beds — procedural, see tools/music_gen.gd).
var _music : Dictionary = {
	"overworld": preload("res://audio/music/overworld.wav"),
}

var _sfx_player : AudioStreamPlayer
var _music_player : AudioStreamPlayer


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # sound keeps going through a paused tree (result panels, etc.)
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
	# Start the ambient bed from the title onward (a quiet loop under everything). Force the loop on the
	# stream itself so it never depends on the .wav import's loop flag.
	var bed : AudioStream = _music.get("overworld")
	if bed is AudioStreamWAV:
		(bed as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	play_music(bed, -9.0)
	# SYSTEM-WIDE UI CLICK: every BaseButton in the game (code- OR scene-built) clicks on press, via one
	# hook on the tree's node_added — so new buttons inherit it for free. (System-wide SFX phase 2026-06-06.)
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)


# Fire a one-shot SFX by name (no-op if unknown). A little random pitch per play kills repetition fatigue.
func play_sfx(snd: String, volume_db: float = 0.0, pitch_jitter: float = 0.07) -> void:

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
