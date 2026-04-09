extends Control

## Tactics Roster Panel — Step 2 of 5
## Army builder: add units from species book, configure upgrades,
## validate composition against TacticsCompositionValidator.
## Points counter, validation messages, responsive layout.

signal roster_updated(entries: Array)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_DANGER := _UC.COLOR_DANGER
const COLOR_WARNING := _UC.COLOR_WARNING
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_MIN := _UC.TOUCH_TARGET_MIN
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _coordinator = null
var _species_book: TacticsSpeciesBook = null
var _roster_entries: Array = []  # Array of dict: {unit_id, display_name, model_count, platoon_index, selected_upgrades, entry_id}

## UI references
var _points_label: Label
var _available_list: VBoxContainer
var _roster_list: VBoxContainer
var _validation_box: VBoxContainer
var _main_container: Control
var _entry_counter: int = 0


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


## Called by CreationUI when species changes or panel becomes visible
func refresh() -> void:
	if _coordinator and _coordinator.has_method("get_species_book"):
		var book: TacticsSpeciesBook = _coordinator.get_species_book()
		if book != _species_book:
			_species_book = book
			_roster_entries.clear()
			_rebuild_available_list()
			_rebuild_roster_list()
			_update_points_display()
			_update_validation()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(outer)

	# Title + Points counter
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_MD)
	outer.add_child(header)

	var title := Label.new()
	title.text = "ARMY ROSTER"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_points_label = Label.new()
	_points_label.text = "0 / 500 pts"
	_points_label.add_theme_font_size_override("font_size", _scaled_font(20))
	_points_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	header.add_child(_points_label)

	# Main content — two sections stacked (responsive: would be side-by-side on wide)
	_main_container = VBoxContainer.new()
	_main_container.add_theme_constant_override("separation", SPACING_LG)
	outer.add_child(_main_container)

	# Available units section
	var avail_header := Label.new()
	avail_header.text = "Available Units"
	avail_header.add_theme_font_size_override("font_size", _scaled_font(18))
	avail_header.add_theme_color_override("font_color", COLOR_ACCENT)
	_main_container.add_child(avail_header)

	_available_list = VBoxContainer.new()
	_available_list.add_theme_constant_override("separation", SPACING_SM)
	_main_container.add_child(_available_list)

	# Current roster section
	var roster_header := Label.new()
	roster_header.text = "Your Roster"
	roster_header.add_theme_font_size_override("font_size", _scaled_font(18))
	roster_header.add_theme_color_override("font_color", COLOR_ACCENT)
	_main_container.add_child(roster_header)

	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", SPACING_SM)
	_main_container.add_child(_roster_list)

	# Validation messages
	_validation_box = VBoxContainer.new()
	_validation_box.add_theme_constant_override("separation", 2)
	outer.add_child(_validation_box)


func _rebuild_available_list() -> void:
	for child in _available_list.get_children():
		child.queue_free()

	if not _species_book:
		var empty := Label.new()
		empty.text = "Select a species first"
		empty.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_available_list.add_child(empty)
		return

	# Group units by org slot
	var slot_names := {
		TacticsUnitProfile.OrgSlot.LEADER: "Leaders",
		TacticsUnitProfile.OrgSlot.TROOP: "Troops",
		TacticsUnitProfile.OrgSlot.SUPPORT: "Support",
		TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT: "Specialists",
	}

	for slot in slot_names:
		var units: Array = _species_book.get_units_for_slot(slot)
		if units.is_empty():
			continue

		var slot_label := Label.new()
		slot_label.text = slot_names[slot]
		slot_label.add_theme_font_size_override("font_size", _scaled_font(14))
		slot_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_available_list.add_child(slot_label)

		for unit in units:
			if unit is TacticsUnitProfile:
				var row := _create_available_unit_row(unit)
				_available_list.add_child(row)


func _create_available_unit_row(profile: TacticsUnitProfile) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	row.custom_minimum_size.y = TOUCH_TARGET_MIN

	var name_lbl := Label.new()
	name_lbl.text = "%s (%dpts, %d models)" % [
		profile.unit_name, profile.points_cost, profile.base_models]
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.custom_minimum_size = Vector2(70, TOUCH_TARGET_MIN)
	var uid: String = profile.unit_id
	add_btn.pressed.connect(func(): _add_unit_to_roster(uid))
	row.add_child(add_btn)

	return row


func _add_unit_to_roster(unit_id: String) -> void:
	if not _species_book:
		return
	var profile: TacticsUnitProfile = _species_book.get_unit_profile(unit_id)
	if not profile:
		return

	_entry_counter += 1
	var entry: Dictionary = {
		"entry_id": "entry_%d" % _entry_counter,
		"unit_id": unit_id,
		"display_name": profile.unit_name,
		"model_count": profile.base_models,
		"platoon_index": 0,
		"selected_upgrades": [],
	}
	_roster_entries.append(entry)
	_rebuild_roster_list()
	_update_points_display()
	_update_validation()
	_emit_update()


func _remove_from_roster(entry_id: String) -> void:
	for i in range(_roster_entries.size() - 1, -1, -1):
		if _roster_entries[i].get("entry_id", "") == entry_id:
			_roster_entries.remove_at(i)
			break
	_rebuild_roster_list()
	_update_points_display()
	_update_validation()
	_emit_update()


func _rebuild_roster_list() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	if _roster_entries.is_empty():
		var empty := Label.new()
		empty.text = "No units added yet. Add units from the list above."
		empty.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		empty.add_theme_font_size_override("font_size", _scaled_font(14))
		_roster_list.add_child(empty)
		return

	for entry in _roster_entries:
		var row := _create_roster_entry_row(entry)
		_roster_list.add_child(row)


func _create_roster_entry_row(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(hbox)

	# Unit info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = entry.get("display_name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	info.add_child(name_lbl)

	# Cost + models
	var cost := _get_entry_cost(entry)
	var detail_lbl := Label.new()
	detail_lbl.text = "%dpts — %d models — Platoon %d" % [
		cost, entry.get("model_count", 1), entry.get("platoon_index", 0) + 1]
	detail_lbl.add_theme_font_size_override("font_size", _scaled_font(11))
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info.add_child(detail_lbl)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	var eid: String = entry.get("entry_id", "")
	remove_btn.pressed.connect(func(): _remove_from_roster(eid))
	hbox.add_child(remove_btn)

	return card


func _get_entry_cost(entry: Dictionary) -> int:
	if not _species_book:
		return 0
	var profile: TacticsUnitProfile = _species_book.get_unit_profile(
		entry.get("unit_id", ""))
	if profile:
		return profile.points_cost
	return 0


func _get_total_points() -> int:
	var total: int = 0
	for entry in _roster_entries:
		total += _get_entry_cost(entry)
	return total


func _update_points_display() -> void:
	if not _points_label:
		return
	var total := _get_total_points()
	var limit: int = 500
	if _coordinator and "config_data" in _coordinator:
		limit = _coordinator.config_data.get("points_limit", 500)
	_points_label.text = "%d / %d pts" % [total, limit]
	if total > limit:
		_points_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif total > limit * 0.9:
		_points_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		_points_label.add_theme_color_override("font_color", COLOR_SUCCESS)


func _update_validation() -> void:
	for child in _validation_box.get_children():
		child.queue_free()

	if _roster_entries.is_empty():
		return

	if _coordinator and _coordinator.has_method("get_validation_errors"):
		var errors: Array[String] = _coordinator.get_validation_errors()
		for err in errors:
			var lbl := Label.new()
			lbl.text = "• " + err
			lbl.add_theme_font_size_override("font_size", _scaled_font(12))
			lbl.add_theme_color_override("font_color", COLOR_DANGER)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_validation_box.add_child(lbl)

		if errors.is_empty():
			var ok := Label.new()
			ok.text = "Composition valid"
			ok.add_theme_font_size_override("font_size", _scaled_font(12))
			ok.add_theme_color_override("font_color", COLOR_SUCCESS)
			_validation_box.add_child(ok)


func _emit_update() -> void:
	roster_updated.emit(_roster_entries.duplicate(true))
