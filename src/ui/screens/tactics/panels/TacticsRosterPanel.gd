extends Control

## Tactics Roster Panel — Step 2 of 4
## Army builder: add units from the species book and the p.141 vehicle table, assign
## each to a platoon or the company (p.135), pick its listed options (pp.136-139), give
## a squad a transport (p.138), and validate against TacticsCompositionValidator.
## Every price shown comes from TacticsCreationCoordinator.entry_cost(), the same
## resolver the validator uses.

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
const TouchScrollOpenerRef = preload("res://src/ui/components/common/TouchScrollOpener.gd")
const DisplayText = preload("res://src/ui/components/common/DisplayText.gd")

var _UnitProfile: GDScript
## Loaded at runtime rather than preloaded by class_name, matching _UnitProfile above —
## this panel deliberately carries no parse-time dependency on the tactics data layer.
var _Validator: GDScript
var _Roster: GDScript
var _UpgradeGroup: GDScript

var _coordinator = null
var _species_book = null
var _roster_entries: Array = []  # Array of dict: {unit_id, display_name, model_count, platoon_index, selected_upgrades, entry_id, role, transport_vehicle_id}

## UI references
var _points_label: Label
var _available_list: VBoxContainer
var _roster_list: VBoxContainer
var _validation_box: VBoxContainer
var _limits_label: Label
var _main_container: Control
var _entry_counter: int = 0


func _scaled_font(base: int) -> int:
	var rm = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_UnitProfile = load("res://src/data/tactics/TacticsUnitProfile.gd")
	_Validator = load("res://src/data/tactics/TacticsCompositionValidator.gd")
	_Roster = load("res://src/data/tactics/TacticsRoster.gd")
	_UpgradeGroup = load("res://src/data/tactics/TacticsUpgradeGroup.gd")
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


## Called by CreationUI when species changes or panel becomes visible. The roster is
## rebuilt either way, because the platoon count and armored platoons may have changed
## on the Configuration step since it was last shown.
func refresh() -> void:
	if _coordinator and _coordinator.has_method("get_species_book"):
		var book = _coordinator.get_species_book()
		if book != _species_book:
			_species_book = book
			_roster_entries.clear()
			_rebuild_available_list()
		_rebuild_roster_list()
		_update_points_display()
		_update_validation()


func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(outer)

	# Title + Points counter. A flow row: on a phone the counter moves under the title
	# instead of pushing the page past the right edge.
	var header = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", SPACING_MD)
	outer.add_child(header)

	var title = Label.new()
	title.text = "ARMY ROSTER"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_points_label = Label.new()
	_points_label.text = "0 / 500 pts · 0 units"
	_points_label.add_theme_font_size_override("font_size", _scaled_font(20))
	_points_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	header.add_child(_points_label)

	# Available Units and Your Roster. ⚠ They were stacked on every screen (this comment
	# read "responsive: would be side-by-side on wide"), so the roster a player was
	# building sat below ~24 "+ Add" rows and a tap changed nothing they could see but the
	# points total. Side by side wherever ResponsiveManager offers more than one column;
	# stacked in portrait, where the header's unit count is the feedback.
	_main_container = GridContainer.new()
	_main_container.name = "RosterColumns"
	_main_container.add_theme_constant_override("h_separation", SPACING_LG)
	_main_container.add_theme_constant_override("v_separation", SPACING_LG)
	outer.add_child(_main_container)

	var avail_col := VBoxContainer.new()
	avail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avail_col.add_theme_constant_override("separation", SPACING_SM)
	_main_container.add_child(avail_col)
	var avail_header = Label.new()
	avail_header.text = "Available Units"
	avail_header.add_theme_font_size_override("font_size", _scaled_font(18))
	avail_header.add_theme_color_override("font_color", COLOR_ACCENT)
	avail_col.add_child(avail_header)

	_available_list = VBoxContainer.new()
	_available_list.add_theme_constant_override("separation", SPACING_SM)
	avail_col.add_child(_available_list)

	var roster_col := VBoxContainer.new()
	roster_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_col.add_theme_constant_override("separation", SPACING_SM)
	_main_container.add_child(roster_col)
	var roster_header = Label.new()
	roster_header.text = "Your Roster"
	roster_header.add_theme_font_size_override("font_size", _scaled_font(18))
	roster_header.add_theme_color_override("font_color", COLOR_ACCENT)
	roster_col.add_child(roster_header)

	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", SPACING_SM)
	roster_col.add_child(_roster_list)
	_apply_columns()
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		rm.layout_class_changed.connect(_on_layout_class_changed)

	# Composition limits — the caps a player builds against, always visible.
	_limits_label = Label.new()
	_limits_label.name = "LimitsSummary"
	_limits_label.add_theme_font_size_override("font_size", _scaled_font(11))
	_limits_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_limits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_limits_label)

	# Validation messages
	_validation_box = VBoxContainer.new()
	_validation_box.add_theme_constant_override("separation", 2)
	outer.add_child(_validation_box)

	# Populate the caps at construction: refresh() only reaches _update_validation()
	# once a species book exists, and the limits do not depend on one.
	_refresh_limits_summary()


## Two columns where the layout class allows more than one, one in portrait.
func _apply_columns() -> void:
	if not (_main_container is GridContainer):
		return
	var one := true
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("should_collapse_to_single_column"):
		one = rm.should_collapse_to_single_column()
	(_main_container as GridContainer).columns = 1 if one else 2


func _on_layout_class_changed(_effective_columns: int) -> void:
	_apply_columns()


func _rebuild_available_list() -> void:
	for child in _available_list.get_children():
		_available_list.remove_child(child)
		child.queue_free()

	if not _species_book:
		var empty = Label.new()
		empty.text = "Select a species first"
		empty.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		_available_list.add_child(empty)
		return

	# Group units by org slot; vehicles get their own heading (p.141: every army may
	# field every vehicle in the table).
	var slot_names = {
		_UnitProfile.OrgSlot.LEADER: "Leaders",
		_UnitProfile.OrgSlot.TROOP: "Troops",
		_UnitProfile.OrgSlot.SUPPORT: "Support",
		_UnitProfile.OrgSlot.SPECIALIST_SLOT: "Specialists",
	}
	var vehicles: Array = []
	for slot in slot_names:
		var units: Array = []
		for unit in _species_book.get_units_for_slot(slot):
			if unit and unit.is_vehicle():
				vehicles.append(unit)
			elif unit:
				units.append(unit)
		_add_available_group(slot_names[slot], units)
	_add_available_group("Vehicles (Tactics pp.141-147)", vehicles)
	TouchScrollOpenerRef.open_subtree(_available_list)


func _add_available_group(heading: String, units: Array) -> void:
	if units.is_empty():
		return
	var slot_label = Label.new()
	slot_label.text = heading
	slot_label.add_theme_font_size_override("font_size", _scaled_font(14))
	slot_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_available_list.add_child(slot_label)
	for unit in units:
		if "unit_id" in unit:
			_available_list.add_child(_create_available_unit_row(unit))


func _create_available_unit_row(profile) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	row.custom_minimum_size.y = TOUCH_TARGET_MIN

	var name_lbl = Label.new()
	if profile.is_vehicle():
		var cap: int = profile.vehicle_profile.transport_capacity if profile.vehicle_profile else 0
		name_lbl.text = "%s (%dpts%s)" % [profile.unit_name, profile.points_cost,
			", carries %d" % cap if cap > 0 else ""]
	else:
		name_lbl.text = "%s (%dpts, %s)" % [profile.unit_name, profile.points_cost,
			DisplayText.pluralize(profile.base_models, "model")]
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_lbl)

	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.custom_minimum_size = Vector2(70, TOUCH_TARGET_MIN)
	var uid: String = profile.unit_id
	add_btn.pressed.connect(func(): _add_unit_to_roster(uid))
	row.add_child(add_btn)

	return row


func _add_unit_to_roster(unit_id: String) -> void:
	if not _species_book:
		return
	var profile = _species_book.get_unit_profile(unit_id)
	if not profile:
		return

	_entry_counter += 1
	_roster_entries.append(new_entry(profile, _entry_counter))
	_on_roster_changed()


## The one definition of a roster entry the wizard builds. The layout sweeps' Tactics
## fixture builds its army through here too, so it cannot drift from what a player adds.
static func new_entry(profile, counter: int) -> Dictionary:
	return {
		"entry_id": "entry_%d" % counter,
		"unit_id": profile.unit_id,
		"display_name": profile.unit_name,
		"model_count": profile.base_models,
		"platoon_index": 0,
		"selected_upgrades": [],
		"role": "",
		"transport_vehicle_id": "",
	}


func _remove_from_roster(entry_id: String) -> void:
	for i in range(_roster_entries.size() - 1, -1, -1):
		if _roster_entries[i].get("entry_id", "") == entry_id:
			_roster_entries.remove_at(i)
			break
	_on_roster_changed()


func _on_roster_changed() -> void:
	_rebuild_roster_list()
	_update_points_display()
	_update_validation()
	_emit_update()


func _rebuild_roster_list() -> void:
	for child in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()

	if _roster_entries.is_empty():
		var empty = Label.new()
		empty.text = "No units added yet. Add units from the list above."
		empty.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		empty.add_theme_font_size_override("font_size", _scaled_font(14))
		_roster_list.add_child(empty)
		return

	for entry in _roster_entries:
		_roster_list.add_child(_create_roster_entry_row(entry))
	TouchScrollOpenerRef.open_subtree(_roster_list)


func _config() -> Dictionary:
	if _coordinator and "config_data" in _coordinator:
		return _coordinator.config_data
	return {}


func _create_roster_entry_row(entry: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_SM
	style.content_margin_right = SPACING_SM
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)
	col.add_child(hbox)

	# Unit info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)

	var name_lbl = Label.new()
	name_lbl.text = entry.get("display_name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_lbl)

	var profile = _species_book.get_unit_profile(entry.get("unit_id", "")) \
		if _species_book else null
	var detail_lbl = Label.new()
	detail_lbl.name = "EntryCost"
	detail_lbl.text = "%dpts — %s" % [_get_entry_cost(entry),
		"vehicle" if profile and profile.is_vehicle()
		else DisplayText.pluralize(int(entry.get("model_count", 1)), "model")]
	detail_lbl.add_theme_font_size_override("font_size", _scaled_font(11))
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info.add_child(detail_lbl)

	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	var eid: String = entry.get("entry_id", "")
	remove_btn.pressed.connect(func(): _remove_from_roster(eid))
	hbox.add_child(remove_btn)

	if profile:
		_add_assignment_controls(col, entry, profile)
		_add_transport_control(col, entry, profile)
		_add_upgrade_controls(col, entry, profile)
	return card


## Where the unit serves: a platoon, or (company only) the company itself (p.135), and
## for a vehicle in an armored platoon whether it is the Leader or a Troop.
func _add_assignment_controls(col: VBoxContainer, entry: Dictionary, profile) -> void:
	var cfg: Dictionary = _config()
	var company: bool = str(cfg.get("org_type", "platoon")) == "company"
	var count: int = int(cfg.get("platoon_count", 1))
	var idx: int = int(entry.get("platoon_index", 0))
	if company:
		var opt := _small_option()
		opt.name = "PlatoonPicker"
		var values: Array = []
		for i in range(count):
			opt.add_item("Platoon %d" % (i + 1))
			values.append(i)
		opt.add_item("Company (p.135)")
		values.append(-1)
		opt.select(maxi(0, values.find(idx)))
		opt.item_selected.connect(func(i: int):
			entry["platoon_index"] = values[i]
			_on_roster_changed())
		col.add_child(opt)

	var armored: Array = cfg.get("armored_platoons", [])
	if profile.is_vehicle() and idx >= 0 and armored.has(idx):
		var role := _small_option()
		role.name = "RolePicker"
		role.add_item("Troop vehicle")
		role.add_item("Leader vehicle")
		role.select(1 if str(entry.get("role", "")) == "leader" else 0)
		role.item_selected.connect(func(i: int):
			entry["role"] = "leader" if i == 1 else "troop"
			_on_roster_changed())
		col.add_child(role)


## p.138 Mechanized Infantry: a squad may ride in any transport that can carry it.
func _add_transport_control(col: VBoxContainer, entry: Dictionary, profile) -> void:
	if not (profile.unit_type in [_UnitProfile.UnitType.INFANTRY,
			_UnitProfile.UnitType.RECON, _UnitProfile.UnitType.STORM]):
		return
	var models: int = int(entry.get("model_count", profile.base_models))
	var opt := _small_option()
	opt.name = "TransportPicker"
	opt.add_item("On foot")
	var ids: Array = [""]
	var vids: Array = _species_book.vehicles.keys()
	vids.sort()
	for vid in vids:
		var vp = _species_book.vehicles[vid]
		if vp and vp.transport_capacity >= models:
			opt.add_item("Mechanized: %s (carries %d, +%dpts)" % [
				vp.vehicle_name, vp.transport_capacity, vp.points_cost])
			ids.append(str(vid))
	opt.select(maxi(0, ids.find(str(entry.get("transport_vehicle_id", "")))))
	opt.item_selected.connect(func(i: int):
		entry["transport_vehicle_id"] = ids[i]
		_on_roster_changed())
	col.add_child(opt)


## The unit's listed options (pp.136-139, p.142 Civilian crew). A pick-one group is a
## dropdown; any other group is a set of checkboxes, capped where the group says so.
func _add_upgrade_controls(col: VBoxContainer, entry: Dictionary, profile) -> void:
	var picked: Array = entry.get("selected_upgrades", [])
	for group in profile.upgrade_groups:
		if group == null or group.options.is_empty():
			continue
		var head := Label.new()
		head.text = group.get_header_text()
		head.add_theme_font_size_override("font_size", _scaled_font(11))
		head.add_theme_color_override("font_color", COLOR_TEXT_SEC)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(head)
		var names: Array = []
		for o in group.options:
			names.append(o.upgrade_name)
		if group.selection_mode == _UpgradeGroup.SelectionMode.PICK_ONE:
			var opt := _small_option()
			opt.add_item("None")
			var current := 0
			for i in range(group.options.size()):
				opt.add_item(group.options[i].get_display_name())
				if picked.has(names[i]):
					current = i + 1
			opt.select(current)
			opt.item_selected.connect(func(i: int):
				for nm in names:
					picked.erase(nm)
				if i > 0:
					picked.append(names[i - 1])
				entry["selected_upgrades"] = picked
				_on_roster_changed())
			col.add_child(opt)
		else:
			var cap: int = group.max_selections \
				if group.selection_mode == _UpgradeGroup.SelectionMode.PICK_UP_TO_N \
				else group.options.size()
			var held := 0
			for nm in names:
				if picked.has(nm):
					held += 1
			for i in range(group.options.size()):
				var cb := CheckBox.new()
				cb.text = group.options[i].get_display_name()
				cb.custom_minimum_size.y = TOUCH_TARGET_MIN
				cb.button_pressed = picked.has(names[i])
				cb.disabled = not cb.button_pressed and held >= cap
				cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var nm: String = names[i]
				cb.toggled.connect(func(on: bool):
					if on and not picked.has(nm):
						picked.append(nm)
					elif not on:
						picked.erase(nm)
					entry["selected_upgrades"] = picked
					_on_roster_changed())
				col.add_child(cb)


func _small_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size.y = TOUCH_TARGET_MIN
	opt.fit_to_longest_item = false
	opt.clip_text = true
	return opt


func _get_entry_cost(entry: Dictionary) -> int:
	if not _species_book or not _coordinator or not _coordinator.has_method("entry_cost"):
		return 0
	return _coordinator.entry_cost(entry)


func _get_total_points() -> int:
	var total: int = 0
	for entry in _roster_entries:
		total += _get_entry_cost(entry)
	return total


func _update_points_display() -> void:
	if not _points_label:
		return
	var total = _get_total_points()
	var limit: int = 500
	if _coordinator and "config_data" in _coordinator:
		limit = _coordinator.config_data.get("points_limit", 500)
	# The unit count beside the points: in portrait the roster is below the list, so this
	# is what tells a player a "+ Add" landed.
	var n: int = _roster_entries.size()
	_points_label.text = "%d / %d pts · %d unit%s" % [total, limit, n, "" if n == 1 else "s"]
	if total > limit:
		_points_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif total > limit * 0.9:
		_points_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		_points_label.add_theme_color_override("font_color", COLOR_SUCCESS)


## Refresh the composition caps, rendered from the SAME constants the validator enforces.
## ⚠ TacticsCompositionValidator.get_limits_summary() was a ZERO-CALLER function until
## 2026-09-06 — reachable only from its own test — while its docstring claimed the
## strings are "what a player reads while building". The caps were correct, tested, and
## shown to nobody; the builder announced a limit only AFTER one was broken. Wiring it
## here is what makes that docstring true, and the text is set even for an EMPTY roster,
## which is exactly when a player most needs to know what they may take.
## ⚠ This is a PERSISTENT label built once in _build_ui() (like _points_label), not a
## child of _validation_box: that box is cleared with queue_free(), which is deferred, so
## anything re-added there in the same frame can briefly stack with what it replaced.
func _refresh_limits_summary() -> void:
	if not _limits_label or not _Validator or not _Roster:
		return

	var org_str: String = "platoon"
	var points: int = 500
	if _coordinator and "config_data" in _coordinator:
		org_str = str(_coordinator.config_data.get("org_type", "platoon"))
		points = int(_coordinator.config_data.get("points_limit", 500))
	# Same String -> enum conversion as TacticsCreationCoordinator._build_temp_roster(),
	# so the summary can never describe a different organisation than the one validated.
	var org_type: int = _Roster.OrgType.COMPANY if org_str == "company" \
		else _Roster.OrgType.PLATOON

	_limits_label.text = _Validator.get_limits_summary(org_type, points)
	var armored: Array = _coordinator.config_data.get("armored_platoons", []) \
		if _coordinator and "config_data" in _coordinator else []
	if not armored.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for i in armored:
			names.append(str(int(i) + 1))
		_limits_label.text += "\nArmored: Platoon " + ", ".join(names)


func _update_validation() -> void:
	for child in _validation_box.get_children():
		child.queue_free()

	_refresh_limits_summary()

	if _roster_entries.is_empty():
		return

	if _coordinator and _coordinator.has_method("get_validation_errors"):
		var errors: Array[String] = _coordinator.get_validation_errors()
		for err in errors:
			var lbl = Label.new()
			lbl.text = "• " + err
			lbl.add_theme_font_size_override("font_size", _scaled_font(12))
			lbl.add_theme_color_override("font_color", COLOR_DANGER)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_validation_box.add_child(lbl)

		if errors.is_empty():
			var ok = Label.new()
			ok.text = "Composition valid"
			ok.add_theme_font_size_override("font_size", _scaled_font(12))
			ok.add_theme_color_override("font_color", COLOR_SUCCESS)
			_validation_box.add_child(ok)


func _emit_update() -> void:
	roster_updated.emit(_roster_entries.duplicate(true))
