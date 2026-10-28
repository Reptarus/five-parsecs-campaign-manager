extends Control

## Planetfall Creation Step 2: Your Colony Crew (pp.14-20).
## Eight characters, each a Scientist, Scout or Trooper (p.14: "any combination ... but
## you must include at least one of each"; "we recommend 2 scouts, 2 scientists, and 4
## troopers"), optionally a Human sub-species (p.19) or the one Soulless emissary (p.20).
## An imported veteran takes one of the eight slots (p.14 "they count against your roster
## limit"). The rules live in PlanetfallRosterRules; this screen shows them and the
## coordinator's Next gate reads the same roster_problems().
##
## Until 2026-10-28 this step was a self-described "functional stub": one button made
## eight "Colonist N" characters in the recommended mix, sub-species could not be picked,
## and the coordinator accepted any roster of three or more.

signal roster_updated(characters: Array)

const ImportPanelClass = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd")
const RosterRules = preload("res://src/core/systems/PlanetfallRosterRules.gd")
const CharacterTableRoller := preload(
	"res://src/core/character/Generation/CharacterTableRoller.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

## p.14: "we recommend 2 scouts, 2 scientists, and 4 troopers".
const RECOMMENDED := ["scientist", "scientist", "scout", "scout",
		"trooper", "trooper", "trooper", "trooper"]
const CLASSES := ["scientist", "scout", "trooper"]
## "" is an ordinary Human; the rest are the p.19 sub-species and the p.20 emissary.
const SUBSPECIES := ["", "feral", "hulker", "stalker", "soulless_emissary"]
const TOUCH_TARGET_MIN := 48

var _coordinator = null
var _roster: Array = []
var _rows: VBoxContainer
var _problems: VBoxContainer
var _import_btn: Button


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build()
	if _roster.is_empty():
		use_recommended_roster(false)
	_render()
	# The wizard connects roster_updated only after every panel is built, so the roster
	# is announced when the step is shown, not from _ready().
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			roster_updated.emit(_roster.duplicate(true)))


func get_roster() -> Array:
	return _roster.duplicate(true)


## The p.14 recommended mix in every slot an imported character does not hold, each with
## a fresh name.
func use_recommended_roster(announce: bool = true) -> void:
	var kept: Array = _roster.filter(func(c: Dictionary) -> bool:
		return bool(c.get("is_imported", false)))
	_roster = kept
	var i: int = 0
	while _roster.size() < _size():
		_roster.append(_new_character(RECOMMENDED[i % RECOMMENDED.size()]))
		i += 1
	if announce:
		_changed()


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
	header.text = "YOUR COLONY CREW"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(18))
	header.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	content.add_child(_prose("Eight characters lead your colony. Give each a class: you "
			+ "need at least one Scientist, Scout and Trooper, and the book recommends two "
			+ "Scientists, two Scouts and four Troopers. Any of them may be a Human "
			+ "sub-species (pp.14-20). You also start with 12 grunts and one colony bot, "
			+ "who are not on this roster.", UIColors.COLOR_TEXT_SECONDARY))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	content.add_child(actions)
	var mix_btn := Button.new()
	mix_btn.text = "Reset to the recommended mix"
	mix_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	mix_btn.pressed.connect(func() -> void: use_recommended_roster())
	actions.add_child(mix_btn)
	_import_btn = Button.new()
	# Short on purpose: an unwrapped Button's text is its minimum width, and the long
	# form ("... from another campaign") measured 343 px against a 338 px phone column.
	_import_btn.text = "Import a character"
	_import_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_import_btn.pressed.connect(_on_import_pressed)
	actions.add_child(_import_btn)

	_problems = VBoxContainer.new()
	_problems.add_theme_constant_override("separation", 4)
	content.add_child(_problems)

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
	for i in range(_roster.size()):
		_rows.add_child(_character_card(i))
	for child in _problems.get_children():
		child.queue_free()
	var problems: Array = RosterRules.roster_problems(_roster)
	if problems.is_empty():
		_problems.add_child(_prose("Roster ready: %d characters." % _roster.size(),
				UIColors.COLOR_EMERALD))
	for p in problems:
		_problems.add_child(_prose(str(p), UIColors.COLOR_AMBER))
	_import_btn.disabled = _free_slot() < 0
	TouchScrollOpenerRef.open_subtree(self)


func _character_card(i: int) -> Control:
	var c: Dictionary = _roster[i]
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var imported: bool = bool(c.get("is_imported", false))
	var name_edit := LineEdit.new()
	name_edit.text = str(c.get("name", ""))
	name_edit.placeholder_text = "Name"
	name_edit.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String) -> void:
		_roster[i]["name"] = t
		roster_updated.emit(_roster.duplicate(true)))
	box.add_child(name_edit)

	var pickers := HFlowContainer.new()
	pickers.add_theme_constant_override("h_separation", 8)
	pickers.add_theme_constant_override("v_separation", 8)
	box.add_child(pickers)
	if imported:
		box.add_child(_prose("Imported from %s. Their class and profile come with them "
				% str(c.get("source_campaign", "another campaign")).capitalize()
				+ "(pp.26-27).", UIColors.COLOR_TEXT_SECONDARY))
		var remove := Button.new()
		remove.text = "Remove"
		remove.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		remove.pressed.connect(func() -> void:
			_roster[i] = _new_character("trooper")
			_changed())
		pickers.add_child(remove)
	else:
		pickers.add_child(_class_picker(i))
		pickers.add_child(_subspecies_picker(i))

	box.add_child(_prose(RosterRules.profile_line(c), UIColors.COLOR_TEXT_PRIMARY))
	var abilities: Array = []
	for a in c.get("abilities", []):
		if a is Dictionary:
			abilities.append(str(a.get("name", "")))
	if not abilities.is_empty():
		box.add_child(_prose(", ".join(PackedStringArray(abilities)),
				UIColors.COLOR_TEXT_SECONDARY))
	return card


func _class_picker(i: int) -> OptionButton:
	var c: Dictionary = _roster[i]
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	var classes: Dictionary = RosterRules.class_data().get("classes", {})
	for k in range(CLASSES.size()):
		opt.add_item(str(classes.get(CLASSES[k], {}).get("name", str(CLASSES[k]).capitalize())), k)
		if CLASSES[k] == str(c.get("class", "")):
			opt.select(k)
	# p.20: the Soulless emissary "can only occupy the Trooper class".
	opt.disabled = str(c.get("subspecies", "")) == "soulless_emissary"
	opt.item_selected.connect(func(k: int) -> void:
		var changed: Dictionary = _roster[i].duplicate(true)
		changed["class"] = CLASSES[k]
		_roster[i] = RosterRules.with_subspecies(changed, str(changed.get("subspecies", "")))
		_changed())
	return opt


func _subspecies_picker(i: int) -> OptionButton:
	var c: Dictionary = _roster[i]
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(180, TOUCH_TARGET_MIN)
	var data: Dictionary = RosterRules.subspecies_data()
	for k in range(SUBSPECIES.size()):
		var sid: String = SUBSPECIES[k]
		opt.add_item("Human" if sid == "" else str(data.get(sid, {}).get("name", sid)), k)
		opt.set_item_disabled(k, not _subspecies_allowed(i, sid))
		if sid == str(c.get("subspecies", "")):
			opt.select(k)
	opt.item_selected.connect(func(k: int) -> void:
		var changed: Dictionary = _roster[i].duplicate(true)
		if SUBSPECIES[k] == "soulless_emissary":
			changed["class"] = "trooper"
		_roster[i] = RosterRules.with_subspecies(changed, SUBSPECIES[k])
		_changed())
	return opt


## Whether slot `i` may take `sid` without breaking p.19 ("a maximum of one Feral plus
## one sub-species of choice (Hulker, Stalker, or a second Feral)") or p.20 ("a single
## Soulless emissary"), counting every other slot.
func _subspecies_allowed(i: int, sid: String) -> bool:
	var feral: int = 0
	var other: int = 0
	var soulless: int = 0
	for j in range(_roster.size()):
		if j == i:
			continue
		match str(_roster[j].get("subspecies", "")):
			"feral":
				feral += 1
			"hulker", "stalker":
				other += 1
			"soulless_emissary":
				soulless += 1
	match sid:
		"feral":
			return feral + 1 <= 2 and feral + 1 + other <= 2
		"hulker", "stalker":
			return other + 1 <= 1 and feral + other + 1 <= 2
		"soulless_emissary":
			return soulless == 0
	return true


## ============================================================================
## CHANGES
## ============================================================================

func _changed() -> void:
	_render()
	roster_updated.emit(_roster.duplicate(true))


func _size() -> int:
	return int(RosterRules.class_data().get("roster_rules", {}).get("initial_roster_size", 8))


func _new_character(cls: String) -> Dictionary:
	var used: Dictionary = {}
	for c in _roster:
		used[str(c.get("id", ""))] = true
	var n: int = 0
	while used.has("pf_char_%d" % n):
		n += 1
	return RosterRules.standard_character(cls, "pf_char_%d" % n,
			CharacterTableRoller.generate_random_name(false))


## The last slot an imported character could take: the last character built here.
## -1 when all eight are imported.
func _free_slot() -> int:
	for i in range(_roster.size() - 1, -1, -1):
		if not bool(_roster[i].get("is_imported", false)):
			return i
	return -1


func _on_import_pressed() -> void:
	if _free_slot() < 0:
		return
	var panel = ImportPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(panel)
	panel.set_existing_roster(_roster)
	panel.character_imported.connect(func(pf_char: Dictionary) -> void:
		var slot: int = _free_slot()
		if slot < 0:
			return
		var imported: Dictionary = pf_char.duplicate(true)
		imported["is_imported"] = true
		_roster[slot] = imported
		_changed())
	panel.load_all_sources()
