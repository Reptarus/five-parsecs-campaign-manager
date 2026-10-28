extends Control

## Planetfall Creation Step 3: Character Backgrounds (pp.21-23).
## "Select which characters to define as experienced" (four of the eight), then roll:
## every character rolls a Motivation, the experienced ones also Prior Experience and a
## Notable Event. PlanetfallBackgrounds rolls and owns the tables; this screen asks for
## the four, shows every die and result, and hands the records to the coordinator.
##
## Until 2026-10-28 this step was a stub that rolled raw randi(), made the first four on
## the list experienced, and showed the player no result at all.

signal backgrounds_updated(data: Dictionary)

const BackgroundsScript := preload("res://src/core/systems/PlanetfallBackgrounds.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
const TOUCH_TARGET_MIN := 48

var _coordinator = null
## Character id -> the record PlanetfallBackgrounds produced. A character with a record
## has rolled; its experienced choice is fixed by then.
var _records: Dictionary = {}
## Character id -> experienced, for characters that have not rolled yet.
var _chosen: Dictionary = {}
var _counter: Label
var _roll_btn: Button
var _rows: VBoxContainer


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build()
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())


## Re-read the roster and the stored results, e.g. after the roster step changed.
func refresh() -> void:
	if _coordinator:
		_records = (_coordinator.background_data as Dictionary).duplicate(true)
	var ids: Dictionary = {}
	for c in _roster():
		ids[str(c.get("id", ""))] = true
	for cid in _chosen.keys():
		if not ids.has(cid):
			_chosen.erase(cid)
	_render()


## Roll for every character that has not rolled yet, with the four experienced chosen.
func roll_all() -> void:
	if _experienced_total() != _target():
		return
	for c in _roster():
		var cid: String = str(c.get("id", ""))
		if not _records.has(cid):
			_records[cid] = BackgroundsScript.roll_character(bool(_chosen.get(cid, false)))
	_changed()


## Mark `cid` experienced or not; ignored once it has rolled or when it would pass four.
func set_experienced(cid: String, on: bool) -> void:
	if _records.has(cid):
		return
	if on and _experienced_total() >= _target():
		return
	_chosen[cid] = on
	_render()


## ============================================================================
## BUILD
## ============================================================================

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var header := Label.new()
	header.text = "CHARACTER BACKGROUNDS"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(18))
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	content.add_child(_prose("Four of your characters have had longer careers. Tick the "
			+ "four you want to be experienced, then roll. Everyone rolls a Motivation, which "
			+ "matters at the campaign's end. Experienced characters also roll Prior "
			+ "Experience, which can raise a score, and a Notable Event (pp.21-22).",
			UIColors.COLOR_TEXT_SECONDARY))

	_counter = _prose("", UIColors.COLOR_TEXT_PRIMARY)
	content.add_child(_counter)
	_roll_btn = Button.new()
	_roll_btn.text = "Roll backgrounds"
	_roll_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_btn.pressed.connect(roll_all)
	content.add_child(_roll_btn)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	content.add_child(_rows)


func _prose(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
	lbl.add_theme_color_override("font_color", color)
	return lbl


## ============================================================================
## RENDER
## ============================================================================

func _render() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	var roster: Array = _roster()
	if roster.is_empty():
		_counter.text = "Build the roster in the previous step first."
		_roll_btn.disabled = true
		return
	var unrolled: int = 0
	for c in roster:
		if not _records.has(str(c.get("id", ""))):
			unrolled += 1
		_rows.add_child(_character_card(c))
	var chosen: int = _experienced_total()
	_counter.text = "Experienced: %d of %d chosen." % [chosen, _target()]
	_counter.add_theme_color_override("font_color", UIColors.COLOR_EMERALD
			if chosen == _target() else UIColors.COLOR_AMBER)
	_roll_btn.disabled = unrolled == 0 or chosen != _target()
	_roll_btn.text = "Roll backgrounds" if unrolled > 0 else "Backgrounds rolled"
	TouchScrollOpenerRef.open_subtree(self)


func _character_card(c: Dictionary) -> Control:
	var cid: String = str(c.get("id", ""))
	var record: Dictionary = _records.get(cid, {})
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var experienced: bool = bool(record.get("experienced", false)) if not record.is_empty() \
			else bool(_chosen.get(cid, false))
	if not record.is_empty():
		# Rolled: the choice is fixed, so the character's name is a heading, not a greyed
		# disabled checkbox that reads as an inactive character.
		var heading := _prose("%s, %s%s" % [str(c.get("name", "")),
				str(c.get("class", "")).capitalize(), " (experienced)" if experienced else ""],
				UIColors.COLOR_TEXT_PRIMARY)
		heading.add_theme_font_size_override("font_size", ScreenChrome.font_size(16))
		box.add_child(heading)
		_add_results(box, cid, record)
		return card
	var check := CheckBox.new()
	check.text = "%s, %s: experienced" % [str(c.get("name", "")),
			str(c.get("class", "")).capitalize()]
	check.button_pressed = experienced
	check.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.disabled = not record.is_empty() \
			or (not experienced and _experienced_total() >= _target())
	check.toggled.connect(func(on: bool) -> void: set_experienced(cid, on))
	box.add_child(check)
	return card


## What `record` rolled for character `cid`, and the optional story-only rolls.
func _add_results(box: VBoxContainer, cid: String, record: Dictionary) -> void:
	box.add_child(_prose("Motivation (D100 %d): %s. %s" % [int(record.get("motivation_roll", 0)),
			str(record.get("motivation", "")), str(record.get("motivation_notes", ""))],
			UIColors.COLOR_TEXT_PRIMARY))
	if not bool(record.get("experienced", false)):
		return
	var bonus: String = BackgroundsScript.bonus_text(record)
	if record.has("earlier_experience"):
		box.add_child(_prose("Earlier career (D100 %d, no bonus): %s." % [
				int(record.get("earlier_roll", 0)), str(record.get("earlier_experience", ""))],
				UIColors.COLOR_TEXT_SECONDARY))
	box.add_child(_prose("Prior Experience (D100 %d): %s. %s%s" % [
			int(record.get("prior_roll", 0)), str(record.get("prior_experience", "")),
			str(record.get("prior_notes", "")), ("  Bonus: %s." % bonus) if bonus != "" else ""],
			UIColors.COLOR_TEXT_PRIMARY))
	var events: Array = [{"event": record.get("notable_event", ""),
			"roll": record.get("notable_roll", 0), "notes": record.get("notable_notes", "")}]
	events.append_array(record.get("extra_events", []))
	for e in events:
		box.add_child(_prose("Notable Event (D100 %d): %s. %s" % [int(e.get("roll", 0)),
				str(e.get("event", "")), str(e.get("notes", ""))], UIColors.COLOR_TEXT_PRIMARY))

	var extras := HFlowContainer.new()
	extras.add_theme_constant_override("h_separation", 8)
	extras.add_theme_constant_override("v_separation", 8)
	box.add_child(extras)
	if not record.has("earlier_experience"):
		# p.21: "roll twice, treating the first roll as history just after adulthood ...
		# Claim the bonus for the second roll only." The roll already made is the second.
		extras.add_child(_small_button("Roll an earlier career (story only)", func() -> void:
			_records[cid] = _with_earlier_career(_records[cid])
			_changed()))
	if events.size() < BackgroundsScript.MAX_NOTABLE_EVENTS:
		# p.22: "you can roll up to three times". "Rolls on this table do not affect
		# gameplay."
		extras.add_child(_small_button("Roll another Notable Event (story only)", func() -> void:
			_records[cid] = BackgroundsScript.roll_extra_event(_records[cid])
			_changed()))


func _small_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(handler)
	return btn


## ============================================================================
## STATE
## ============================================================================

func _roster() -> Array:
	return (_coordinator.roster_data as Array) if _coordinator else []


func _target() -> int:
	return mini(BackgroundsScript.experienced_count(), _roster().size())


func _experienced_total() -> int:
	var n: int = 0
	for c in _roster():
		var cid: String = str(c.get("id", ""))
		var record: Dictionary = _records.get(cid, {})
		if record.is_empty() and bool(_chosen.get(cid, false)):
			n += 1
		elif bool(record.get("experienced", false)):
			n += 1
	return n


func _with_earlier_career(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	var earlier: Dictionary = BackgroundsScript.roll_earlier_career()
	out["earlier_experience"] = str(earlier.get("experience", ""))
	out["earlier_roll"] = int(earlier.get("roll", 0))
	return out


func _changed() -> void:
	_render()
	backgrounds_updated.emit(_records.duplicate(true))
