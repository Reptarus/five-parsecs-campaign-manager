extends Control

## Bug Hunt Equipment Panel — Step 3 of 4
## Shows standard equipment (Service Pistol + Trooper Armor) and explains
## that additional weapons are selected per-mission during the Mission Phase.

signal equipment_updated(data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")

var _coordinator = null


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
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "STANDARD EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Standard Issue card
	var std_card := _create_card("Standard Issue (All Characters)", vbox)

	_add_equipment_row(std_card, "Service Pistol", "Range 14\" | 1 Shot | Damage 0 | Pistol (+1 Brawl)")
	_add_equipment_row(std_card, "Trooper Armor", "Saving throw on 5-6")

	# Mission Loadout info
	var loadout_card := _create_card("Mission Loadout (Selected Each Mission)", vbox)

	var info := Label.new()
	info.text = "Before each mission, each Main Character selects one additional weapon:"
	info.add_theme_color_override("font_color", COLOR_TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_card.add_child(info)

	_add_equipment_row(loadout_card, "Combat Rifle", "Range 26\" | 1 Shot | Damage 0")
	_add_equipment_row(loadout_card, "Shotgun", "Range 12\" | 2 Shots | Damage 1 | Focused")
	_add_equipment_row(loadout_card, "Boarding Sword", "Melee | +2 Brawl")

	var swap_info := Label.new()
	swap_info.text = "\nOne Main Character may also swap their Service Pistol for a Hand Cannon (Range 8\" | 1 Shot | Damage 1 | Pistol) for the mission."
	swap_info.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	swap_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_card.add_child(swap_info)

	# Support Teams info
	var support_card := _create_card("Mission Support", vbox)
	var support_info := Label.new()
	support_info.text = "Support troops are rolled for during Mission Generation based on Priority. You always receive one free Fire Team (4 grunts with Combat Rifles). Additional support (Sarge, Sniper, Recon Patrol, etc.) requires 2D6 rolls against target numbers."
	support_info.add_theme_color_override("font_color", COLOR_TEXT)
	support_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	support_card.add_child(support_info)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox


func _add_equipment_row(parent: VBoxContainer, item_name: String, details: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.custom_minimum_size.x = 160
	hbox.add_child(name_lbl)

	var detail_lbl := Label.new()
	detail_lbl.text = details
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	detail_lbl.add_theme_font_size_override("font_size", 14)
	detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(detail_lbl)


func _emit_update() -> void:
	var data := {"standard_equipment_confirmed": true}
	equipment_updated.emit(data)
