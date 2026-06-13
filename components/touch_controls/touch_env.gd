## TouchEnv — the ONE source of truth for "should we show touch controls?". Every mobile branch (the virtual
## joystick, the puzzle button bars, touch-sized UI) reads THIS, so the desktop build stays untouched and a dev
## can force it on/off for testing. Static helper, no instances. See [[touch-input-foundation]] + MOBILE_WEB_PLAN.md.
class_name TouchEnv
extends Object

const _SETTINGS : String = "user://settings.cfg"

## Memoised [method is_touch] result (-1 = not computed yet, 0 = false, 1 = true). is_touch() is read EVERY FRAME
## by ChatBox + on every input event by PinchZoom, and it used to re-load settings.cfg each call — a per-frame
## file read (extra-costly on web, where user:// is IndexedDB). The answer only changes when a dev flips a flag,
## so we compute once and cache; [method set_flag] invalidates it (Troy 2026-06-13, the mobile perf pass).
static var _cached_touch : int = -1


## True when touch controls should be shown: a real touchscreen, OR the web build (phones run it), UNLESS a
## settings override flips it. A desktop dev sets [code]force_touch[/code] to test without a phone, or
## [code]force_desktop[/code] to suppress it. CACHED after the first call (see [member _cached_touch]).
static func is_touch() -> bool:

	if _cached_touch < 0:
		_cached_touch = 1 if _compute_is_touch() else 0
	return _cached_touch == 1


static func _compute_is_touch() -> bool:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(_SETTINGS) == OK:
		if bool(cfg.get_value("dev", "force_desktop", false)):
			return false
		if bool(cfg.get_value("dev", "force_touch", false)):
			return true
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web")


## Dev mode (slash-command cheats on the web RELEASE build, force-touch testing, …) — same settings file, read by
## ChatBox + the options panel. Off by default, so players never get the dev tools.
static func dev_mode() -> bool:

	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(_SETTINGS) == OK:
		return bool(cfg.get_value("dev", "dev_mode", false))
	return false


## Persist a dev flag (load-then-save preserves the other sections, e.g. Audio's volumes).
static func set_flag(key: String, value: bool) -> void:

	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(_SETTINGS)
	cfg.set_value("dev", key, value)
	cfg.save(_SETTINGS)
	_cached_touch = -1   # a force_touch/force_desktop change must re-resolve is_touch() on the next call
