extends Control

## Bug Hunt Equipment Panel — Step 3 of 4
## Shows standard equipment (Service Pistol + Trooper Armor) and explains
## that additional weapons are selected per-mission during the Mission Phase.
## Every profile is read from data/bug_hunt/ through BugHuntReferenceText.

signal equipment_updated(data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_ACCENT := _UC.COLOR_ACCENT
const RefText := preload("res://src/ui/screens/bug_hunt/BugHuntReferenceText.gd")

var _coordinator = null


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()
	# Auto-complete since standard equipment is fixed
	_emit_update()


func set_coordinator(coord) -> void:
	_coordinator = coord
	_emit_update()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Never sideways (test_bug_hunt_screen_fit.gd): every row below wraps instead.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "STANDARD EQUIPMENT"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	# Every profile below is READ from the data the battle reads (BugHuntReferenceText). This
	# step used to print them as literals beside the Mission step's data-driven copy.
	var std_card := _create_card("Standard Issue (All Characters)", vbox)
	for w in RefText.standard_weapons():
		_add_equipment_row(std_card, str(w.get("name", "")), RefText.profile(w),
			RefText.trait_lines(w))
	for a in RefText.standard_armor():
		_add_equipment_row(std_card, str(a.get("name", "")), RefText.armor_line(a))

	var loadout: Dictionary = RefText.loadout()
	var loadout_card := _create_card("Mission Loadout (Selected Each Mission)", vbox)
	_add_prose(loadout_card, str(loadout.get("description", "")), COLOR_TEXT)
	for wid in loadout.get("mission_weapon_choices", []):
		var w: Dictionary = RefText.weapon(str(wid))
		if not w.is_empty():
			_add_equipment_row(loadout_card, str(w.get("name", "")), RefText.profile(w),
				RefText.trait_lines(w))
	var cannon: Dictionary = RefText.weapon("hand_cannon")
	if not cannon.is_empty():
		_add_prose(loadout_card, str(loadout.get("hand_cannon_swap", "")), COLOR_TEXT_SEC)
		_add_equipment_row(loadout_card, str(cannon.get("name", "")), RefText.profile(cannon),
			RefText.trait_lines(cannon))

	var support_card := _create_card("Mission Support", vbox)
	_add_prose(support_card, "Support is rolled for during Mission Generation, based on "
		+ "the mission's Priority.", COLOR_TEXT)
	var fire_team := RefText.free_fire_team_rule()
	var contents := RefText.fire_team_contents()
	if not contents.is_empty():
		fire_team += " (%s)" % contents
	_add_prose(support_card, fire_team, COLOR_TEXT)


func _add_prose(parent: VBoxContainer, text: String, color: Color) -> void:
	if text.strip_edges().is_empty():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(_UC.SPACING_LG)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", _UC.SPACING_SM)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text.to_upper()
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	return vbox


## Name beside its profile where the width allows, the profile on its own line where it
## does not (a flow row: the profile keeps 180 px, so on a phone it drops under the name
## instead of wrapping one word per line beside a 160 px name column).
func _add_equipment_row(parent: VBoxContainer, item_name: String, details: String,
		notes: PackedStringArray = PackedStringArray()) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 2)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	name_lbl.custom_minimum_size.x = 160
	row.add_child(name_lbl)

	var detail_lbl := Label.new()
	detail_lbl.text = details
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	detail_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_lbl.custom_minimum_size.x = 180
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail_lbl)

	for note in notes:
		var note_lbl := Label.new()
		note_lbl.text = note
		note_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		note_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(note_lbl)


func _emit_update() -> void:
	var data := {"standard_equipment_confirmed": true}
	equipment_updated.emit(data)
