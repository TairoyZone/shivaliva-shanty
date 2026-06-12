## TouchEnv — the ONE source of truth for "should we show touch controls?". Every mobile branch (the virtual
## joystick, the puzzle button bars, touch-sized UI) reads THIS, so the desktop build stays untouched and a dev
## can force it on/off for testing. Static helper, no instances. See [[touch-input-foundation]] + MOBILE_WEB_PLAN.md.
class_name TouchEnv
extends Object

const _SETTINGS : String = "user://settings.cfg"


## True when touch controls should be shown: a real touchscreen, OR the web build (phones run it), UNLESS a
## settings override flips it. A desktop dev sets [code]force_touch[/code] to test without a phone, or
## [code]force_desktop[/code] to suppress it.
static func is_touch() -> bool:

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
