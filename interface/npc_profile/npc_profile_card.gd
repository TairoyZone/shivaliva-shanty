## NpcProfileCard — a character page for any NPC (the mirror of the player's ★ Profile), opened from the NPC
## radial menu's "Profile". SINGLE-COLUMN (header → crew → standing → about → favour) so it can't overflow.
## The CREW section is the foundation for "start a crew": recruit a CONFIDANT, then promote / demote / dismiss
## them (all via PlayerState's crew model). Modal family (dim + panel + ESC + ModalFx). Built 2026-06-08.
class_name NpcProfileCard
extends Modal


const GROUP : StringName = &"npc_profile_card"

## What each cast member does — shown under their name. Data-driven; falls back to a generic role.
const ROLES : Dictionary = {
	"Flint Kerr": "Bladesmith", "Cinder Troy": "Blacksmith", "Hearty Brian": "Innkeeper",
	"Merry Geneva": "Inn hostess", "Spritely Mia": "Whittler", "Mossy Jade": "Gym healer",
	"Cogwise Godfrey": "Tinker", "Stormy Jericho": "Skydock master", "Hollow Ellison": "Gym master",
}
## Where each is usually found (for the "About" line).
const HAUNTS : Dictionary = {
	"Flint Kerr": "the Forge", "Cinder Troy": "the Forge", "Hearty Brian": "the Inn",
	"Merry Geneva": "the Inn", "Spritely Mia": "the Inn", "Mossy Jade": "the Cradle Gym",
	"Cogwise Godfrey": "the Workshop", "Stormy Jericho": "the Skydock", "Hollow Ellison": "the Cradle Gym",
}

var _npc_name : String = ""
var _color : Color = Color(0.6, 0.6, 0.7, 1.0)
var _bio : String = ""
var _locale : String = ""
var _favor : Dictionary = {}


static func open(host: Node, config: Dictionary) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var c : NpcProfileCard = NpcProfileCard.new()
	c._npc_name = String(config.get("npc_name", "Stranger"))
	c._color = config.get("npc_color", Color(0.6, 0.6, 0.7, 1.0))
	c._bio = String(config.get("bio", ""))
	c._locale = String(config.get("locale", ""))
	var fav : Variant = config.get("favor", {})
	c._favor = (fav as Dictionary).duplicate() if fav is Dictionary else {}
	host.get_tree().root.add_child(c)


# --- Modal config -----------------------------------------------------

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(460.0, 504.0)

func _modal_scrollable() -> bool:
	return true

func _modal_content_separation() -> int:
	return 8


func _build_content() -> void:

	PlayerState.crew_changed.connect(_render)   # any crew change re-renders (single source of truth)
	_render()


# --- render -----------------------------------------------------------

func _render() -> void:

	for c in _content.get_children():
		_content.remove_child(c)   # immediate removal so the rebuild never overlaps the old rows for a frame
		c.queue_free()

	_content.add_child(_header())
	_content.add_child(_rule())
	_content.add_child(_abilities_section())   # the "why hire them" info, up top
	_content.add_child(_rule())
	_content.add_child(_crew_section())
	_content.add_child(_rule())

	# Your standing with them.
	_content.add_child(_section("Standing"))
	_content.add_child(_kv("Rapport", PlayerState.affinity_tier(_npc_name)))
	var rom : String = _romance_standing()
	if not rom.is_empty():
		_content.add_child(_kv("Romance", rom))
	var done : int = int(PlayerState.npc_favor_done.get(_npc_name, 0))
	if done > 0:
		_content.add_child(_muted("Favours done for them: %d" % done))

	# About.
	var haunt : String = String(HAUNTS.get(_npc_name, ""))
	if not _bio.is_empty() or not haunt.is_empty():
		_content.add_child(_rule())
		_content.add_child(_section("About"))
		if not _bio.is_empty():
			_content.add_child(_body(_bio))
		if not haunt.is_empty():
			_content.add_child(_muted("Usually found at %s." % haunt))

	# Their standing favour.
	if not _favor.is_empty():
		_content.add_child(_rule())
		_content.add_child(_section("Could use a hand"))
		_content.add_child(_body("Wants %d %s — drop by for a Favour to help." % [int(_favor.get("amount", 0)), _item_name()]))

	_content.add_child(_gap(6))
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close : Button = _btn("Close", Palette.ACCENT)
	close.pressed.connect(_close)
	row.add_child(close)
	_content.add_child(row)


func _header() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# Portrait disc (colour + initial), centred.
	var disc_row : HBoxContainer = HBoxContainer.new()
	disc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var disc : Panel = Panel.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = _color
	ds.border_color = Color(1, 1, 1, 0.85)
	ds.set_border_width_all(3)
	ds.set_corner_radius_all(48)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(86.0, 86.0)
	var initial : Label = Label.new()
	initial.text = _short().substr(0, 1).to_upper()
	initial.add_theme_font_size_override("font_size", 38)
	initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	initial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	initial.add_theme_constant_override("outline_size", 4)
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(initial)
	disc_row.add_child(disc)
	box.add_child(disc_row)

	var name_l : Label = Label.new()
	name_l.text = _npc_name
	name_l.add_theme_font_size_override("font_size", 26)
	UiStyle.apply_title(name_l)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_l)
	var role_l : Label = Label.new()
	role_l.text = String(ROLES.get(_npc_name, "Cradle Rock local"))
	role_l.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_muted(role_l)
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(role_l)
	return box


# The CREW section — recruit / rank / dismiss (the foundation for "start a crew").
func _crew_section() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section("Crew"))
	if PlayerState.is_in_crew(_npc_name):
		_content_note(box, "Aboard your crew  ·  %s" % PlayerState.crew_rank(_npc_name), Palette.TEXT_PRIMARY)
		var idx : int = int(PlayerState.crew.get(_npc_name, 0))
		var row : HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var up : Button = _btn("Promote ▲", Palette.POSITIVE)
		up.disabled = idx >= PlayerState.CREW_RANKS.size() - 1
		up.pressed.connect(_promote)
		row.add_child(up)
		var down : Button = _btn("Demote ▼", Palette.ACCENT)
		down.disabled = idx <= 0
		down.pressed.connect(_demote)
		row.add_child(down)
		var off : Button = _btn("Dismiss", Palette.DANGER)
		off.pressed.connect(_dismiss)
		row.add_child(off)
		box.add_child(row)
	elif PlayerState.can_recruit(_npc_name):
		_content_note(box, "They'd sail with you.", Palette.TEXT_MUTED)
		var row : HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var hire : Button = _btn("Hire to crew  ▸", Palette.POSITIVE)
		hire.pressed.connect(_hire)
		row.add_child(hire)
		box.add_child(row)
	else:
		var aff : int = PlayerState.get_affinity(_npc_name)
		if aff < 0:
			_content_note(box, "They've soured on you (%s) — mend things before they'd ever crew for you." % \
				PlayerState.affinity_tier(_npc_name), Palette.DANGER)
		else:
			_content_note(box, "Earn their trust to recruit — become their Confidant.  (rapport %d / %d)" % [
				aff, PlayerState.RECRUIT_MIN_AFFINITY], Palette.TEXT_MUTED)
	return box


# --- actions ----------------------------------------------------------

func _hire() -> void:
	PlayerState.hire_crew(_npc_name)

func _dismiss() -> void:
	PlayerState.dismiss_crew(_npc_name)

## This NPC's romance standing line, or "": your Sweetheart / an active courtship / "Married to X" for the
## partnered cast (resolved from their .tres). Surfaces the Sweethearts state on the NPC's profile card.
func _romance_standing() -> String:

	if PlayerState.is_sweetheart(_npc_name):
		return "Your sweetheart"
	if PlayerState.romance_stage(_npc_name) > 0:
		return "Courting — %s" % PlayerState.romance_stage_name(_npc_name)
	for p in NpcRegistry.all():
		if p.npc_name == _npc_name and not p.partner.is_empty():
			return "Married to %s" % p.partner
	return ""


func _promote() -> void:
	PlayerState.cycle_crew_rank(_npc_name, 1)

func _demote() -> void:
	PlayerState.cycle_crew_rank(_npc_name, -1)


# --- abilities (the "why hire them" readout) ---------------------------

func _abilities_section() -> Control:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(_section("Abilities"))
	for s in CrewSkills.SKILLS:
		box.add_child(_skill_row(s, CrewSkills.rating(_npc_name, s)))
	return box


func _skill_row(skill: String, value: int) -> Control:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l : Label = Label.new()
	l.text = skill
	l.add_theme_font_size_override("font_size", 14)
	UiStyle.apply_primary(l)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var st : Label = Label.new()
	st.text = CrewSkills.tier_name(value)
	st.add_theme_font_size_override("font_size", 14)
	st.add_theme_color_override("font_color", Palette.ACCENT)
	row.add_child(st)
	return row


# --- small builders ----------------------------------------------------

func _section(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	UiStyle.apply_title(l)
	return l


func _kv(key: String, value: String) -> Label:
	var l : Label = Label.new()
	l.text = "%s:  %s" % [key, value]
	l.add_theme_font_size_override("font_size", 15)
	UiStyle.apply_primary(l)
	return l


func _body(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	UiStyle.apply_primary(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _muted(text: String) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	UiStyle.apply_muted(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _content_note(box: VBoxContainer, text: String, color: Color) -> void:
	var l : Label = _body(text)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _rule() -> Control:
	var r : ColorRect = ColorRect.new()
	r.color = Color(Palette.BORDER.r, Palette.BORDER.g, Palette.BORDER.b, 0.55)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _gap(h: float) -> Control:
	var c : Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _item_name() -> String:
	var id : String = String(_favor.get("item", ""))
	return String((PlayerState.ITEM_DEFS.get(id, {}) as Dictionary).get("name", id.capitalize()))


func _short() -> String:
	var parts : PackedStringArray = _npc_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else _npc_name


func _btn(text: String, font_color: Color) -> Button:
	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_outline_color", Palette.OUTLINE_HARD)
	b.add_theme_constant_override("outline_size", 2)
	var styles : Dictionary = UiStyle.button_styles(Palette.CARD_BG, Palette.BORDER)
	for st in styles:
		var s : StyleBoxFlat = styles[st]
		s.content_margin_left = 13
		s.content_margin_right = 13
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, s)
	return b
