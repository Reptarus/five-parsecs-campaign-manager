extends WorldPhaseComponent
class_name AssignEquipmentComponent

## Assign Equipment Component - Equipment Management System
## Implements Core Rules p.85 - Transfer items between crew members and stash
## Characters can trade items, leave items in stash, or take items from stash

# UI Components
@onready var crew_list: ItemList = %CrewList
@onready var crew_equipment_list: ItemList = %CrewEquipmentList
@onready var stash_list: ItemList = %StashList
@onready var transfer_to_stash_button: Button = %TransferToStashButton
@onready var transfer_to_crew_button: Button = %TransferToCrewButton
@onready var transfer_between_crew_button: Button = %TransferBetweenCrewButton
@onready var confirm_button: Button = %ConfirmButton
@onready var selected_crew_label: Label = %SelectedCrewLabel

# Design system constants
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_DANGER := UIColors.COLOR_DANGER
const COLOR_ACCENT := UIColors.COLOR_ACCENT

# Trait color mapping
const _BENEFICIAL_TRAITS := ["Snap Shot", "Critical", "Piercing", "Elegant"]
const _NEGATIVE_TRAITS := ["Clumsy", "Terrifying"]

# State
var crew_data: Array = []
var stash_items: Array = []
var selected_crew_index: int = -1
var selected_target_crew_index: int = -1
var assignment_completed: bool = false

# Detail strip state
var _detail_strip: HBoxContainer
var _crew_stats_panel: PanelContainer
var _item_stats_panel: PanelContainer
var _equipment_db: Dictionary = {}
var _selected_equipment_index: int = -1
var _selected_stash_index: int = -1

func _ready() -> void:
	name = "AssignEquipmentComponent"
	super._ready()
	_apply_touch_target_sizing()
	_load_equipment_database()
	_build_detail_strip()

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

## Sprint C: Apply 48px minimum touch targets for mobile UX
func _apply_touch_target_sizing() -> void:
	const TOUCH_TARGET_MIN := 48
	if crew_list:
		crew_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if crew_equipment_list:
		crew_equipment_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if stash_list:
		stash_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)

func _connect_ui_signals() -> void:
	## Connect UI button signals
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
	if crew_equipment_list:
		crew_equipment_list.item_selected.connect(
			_on_equipment_item_selected)
	if stash_list:
		stash_list.item_selected.connect(
			_on_stash_item_selected)
	if transfer_to_stash_button:
		transfer_to_stash_button.pressed.connect(_on_transfer_to_stash_pressed)
	if transfer_to_crew_button:
		transfer_to_crew_button.pressed.connect(_on_transfer_to_crew_pressed)
	if transfer_between_crew_button:
		transfer_between_crew_button.pressed.connect(_on_transfer_between_crew_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

func _setup_initial_state() -> void:
	## Initialize component state
	selected_crew_index = -1
	assignment_completed = false
	_update_ui_display()

## Public API
func initialize_equipment_phase(crew: Array, stash: Array) -> void:
	## Initialize equipment assignment with crew and stash data
	crew_data = crew.duplicate(true)
	stash_items = stash.duplicate(true)
	selected_crew_index = -1
	assignment_completed = false

	_populate_crew_list()
	_populate_stash_list()

	# UX-092 FIX: Auto-select first crew member so transfer buttons are immediately usable
	if crew_data.size() > 0 and crew_list and crew_list.item_count > 0:
		crew_list.select(0)
		selected_crew_index = 0
		_populate_crew_equipment()

	_update_ui_display()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "assign_equipment",
			"crew_count": crew.size(),
			"stash_count": stash.size()
		})

func _populate_crew_list() -> void:
	## Populate crew member list
	if not crew_list:
		return

	crew_list.clear()
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	for i in range(crew_data.size()):
		var member = crew_data[i]
		var member_name: String = member.character_name if "character_name" in member else "Crew %d" % (i + 1)
		var equipment_count = _get_equipment_count(member)
		crew_list.add_item("%s (%d items)" % [member_name, equipment_count])

func _populate_stash_list() -> void:
	## Populate stash items list
	if not stash_list:
		return

	stash_list.clear()
	for item in stash_items:
		var item_name = item.get("name", "Unknown Item") if item is Dictionary else str(item)
		var damaged = item.get("damaged", false) if item is Dictionary else false
		var suffix = " [DAMAGED]" if damaged else ""
		stash_list.add_item(item_name + suffix)

func _populate_crew_equipment() -> void:
	## Populate selected crew member's equipment
	if not crew_equipment_list:
		return

	crew_equipment_list.clear()

	if selected_crew_index < 0 or selected_crew_index >= crew_data.size():
		return

	var member = crew_data[selected_crew_index]
	var equipment = _get_member_equipment(member)

	for item in equipment:
		var item_name = item.get("name", "Unknown") if item is Dictionary else str(item)
		crew_equipment_list.add_item(item_name)

func _get_member_equipment(member) -> Array:
	## Get equipment array from crew member
	if not member:
		return []
	if member is Dictionary:
		return member.get("equipment", [])
	if member is Object and member.has_method("get_equipment"):
		return member.get_equipment()
	elif "equipment" in member:
		return member.equipment
	return []

func _set_member_equipment(member, equipment: Array) -> void:
	## Set equipment array for crew member
	if not member:
		return
	if member is Dictionary:
		member["equipment"] = equipment
	elif member is Object and member.has_method("set_equipment"):
		member.set_equipment(equipment)
	elif "equipment" in member:
		member.equipment = equipment

func _get_equipment_count(member) -> int:
	## Get count of equipment for crew member
	return _get_member_equipment(member).size()

## Transfer Actions
func _on_crew_selected(index: int) -> void:
	## Handle crew member selection
	selected_crew_index = index
	_selected_equipment_index = -1
	_selected_stash_index = -1
	_populate_crew_equipment()
	_update_ui_display()
	_update_detail_strip()

	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	if selected_crew_label and index >= 0 and index < crew_data.size():
		var member = crew_data[index]
		var crew_name: String = member.character_name if "character_name" in member else "Crew %d" % (index + 1)
		selected_crew_label.text = "Selected: %s" % crew_name

func _on_transfer_to_stash_pressed() -> void:
	## Transfer selected item from crew to stash
	if selected_crew_index < 0 or selected_crew_index >= crew_data.size() or not crew_equipment_list:
		return

	var selected = crew_equipment_list.get_selected_items()
	if selected.is_empty():
		return

	var item_index = selected[0]
	var member = crew_data[selected_crew_index]
	var equipment = _get_member_equipment(member)

	if item_index >= 0 and item_index < equipment.size():
		var item = equipment[item_index]

		# Get character and equipment IDs (Sprint 26.3: Character-Everywhere)
		var character_id: String = member.character_id if "character_id" in member else ""
		var equipment_id: String = item.get("id", "") if item is Dictionary else ""
		
		# Try EquipmentManager first for proper state management
		var equipment_manager = get_node_or_null("/root/EquipmentManager")
		if equipment_manager and equipment_manager.has_method("transfer_to_ship_stash") and not character_id.is_empty() and not equipment_id.is_empty():
			if equipment_manager.transfer_to_ship_stash(character_id, equipment_id):
				# Update local state to match EquipmentManager
				equipment.remove_at(item_index)
				_set_member_equipment(member, equipment)
				stash_items.append(item)
				pass # Transferred to ship stash via EquipmentManager
			else:
				push_warning("AssignEquipmentComponent: EquipmentManager transfer failed - stash may be full")
				return
		else:
			# Fallback to local state update only
			equipment.remove_at(item_index)
			_set_member_equipment(member, equipment)
			stash_items.append(item)
			pass # Transferred to stash (local only)

		_selected_equipment_index = -1
		_populate_crew_equipment()
		_populate_stash_list()
		_populate_crew_list()
		_update_ui_display()
		_update_detail_strip()

func _on_transfer_to_crew_pressed() -> void:
	## Transfer selected item from stash to crew
	if selected_crew_index < 0 or selected_crew_index >= crew_data.size() or not stash_list:
		return

	var selected = stash_list.get_selected_items()
	if selected.is_empty():
		return

	var item_index = selected[0]
	if item_index >= 0 and item_index < stash_items.size():
		var item = stash_items[item_index]
		var member = crew_data[selected_crew_index]

		# Get character and equipment IDs (Sprint 26.3: Character-Everywhere)
		var character_id: String = member.character_id if "character_id" in member else ""
		var equipment_id: String = item.get("id", "") if item is Dictionary else ""
		
		# Try EquipmentManager first for proper state management
		var equipment_manager = get_node_or_null("/root/EquipmentManager")
		if equipment_manager and equipment_manager.has_method("transfer_from_ship_stash") and not character_id.is_empty() and not equipment_id.is_empty():
			if equipment_manager.transfer_from_ship_stash(equipment_id, character_id):
				# Update local state to match EquipmentManager
				stash_items.remove_at(item_index)
				var equipment = _get_member_equipment(member)
				equipment.append(item)
				_set_member_equipment(member, equipment)
				pass # Transferred to crew member via EquipmentManager
			else:
				push_warning("AssignEquipmentComponent: EquipmentManager transfer from stash failed")
				return
		else:
			# Fallback to local state update only
			stash_items.remove_at(item_index)
			var equipment = _get_member_equipment(member)
			equipment.append(item)
			_set_member_equipment(member, equipment)

		_selected_stash_index = -1
		_populate_crew_equipment()
		_populate_stash_list()
		_populate_crew_list()
		_update_ui_display()
		_update_detail_strip()

func _on_transfer_between_crew_pressed() -> void:
	## Transfer item between crew members - Sprint C: Complete crew-to-crew transfer
	if selected_crew_index < 0 or not crew_equipment_list:
		return

	var selected_items = crew_equipment_list.get_selected_items()
	if selected_items.is_empty():
		_show_notification("Select an item to transfer")
		return

	# Get other crew members to transfer to
	var other_crew: Array = []
	for i in range(crew_data.size()):
		if i != selected_crew_index:
			other_crew.append({"index": i, "member": crew_data[i]})

	if other_crew.is_empty():
		_show_notification("No other crew members to transfer to")
		return

	# Show crew selection popup
	var popup = _create_crew_selection_popup(other_crew)
	add_child(popup)
	popup.popup_centered()

## Sprint C: Create crew selection popup for equipment transfer
func _create_crew_selection_popup(crew_options: Array) -> Window:
	## Create a popup window to select target crew member
	var popup := Window.new()
	popup.name = "CrewSelectionPopup"
	popup.title = "Transfer To..."
	popup.size = Vector2i(300, 250)
	popup.transient = true
	popup.exclusive = true
	popup.unresizable = true

	# Deep Space theme background
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A1A2E")
	panel.add_theme_stylebox_override("panel", style)
	popup.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "Select crew member to receive item:"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("#E0E0E0"))
	vbox.add_child(header)

	# Crew list
	var crew_list := ItemList.new()
	crew_list.name = "TargetCrewList"
	crew_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crew_list.add_theme_constant_override("item_height", 48)

	for option in crew_options:
		var member = option["member"]
		var member_name: String = member.character_name if "character_name" in member else "Crew %d" % (option["index"] + 1)
		var equipment_count = _get_equipment_count(member)
		crew_list.add_item("%s (%d items)" % [member_name, equipment_count])
		crew_list.set_item_metadata(crew_list.item_count - 1, option["index"])

	vbox.add_child(crew_list)

	# Buttons row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 48)
	cancel_btn.pressed.connect(func(): popup.queue_free())
	button_row.add_child(cancel_btn)

	var transfer_btn := Button.new()
	transfer_btn.text = "Transfer"
	transfer_btn.custom_minimum_size = Vector2(100, 48)
	transfer_btn.disabled = true

	# Style transfer button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#2D5A7B")
	btn_style.set_corner_radius_all(6)
	transfer_btn.add_theme_stylebox_override("normal", btn_style)
	transfer_btn.add_theme_color_override("font_color", Color("#E0E0E0"))

	# Enable transfer button when selection made
	crew_list.item_selected.connect(func(_idx): transfer_btn.disabled = false)

	# Handle transfer
	transfer_btn.pressed.connect(func():
		var selected = crew_list.get_selected_items()
		if selected.is_empty():
			return
		var target_index = crew_list.get_item_metadata(selected[0])
		_execute_crew_to_crew_transfer(target_index)
		popup.queue_free()
	)

	button_row.add_child(transfer_btn)

	popup.close_requested.connect(func(): popup.queue_free())

	return popup

## Sprint C: Execute the crew-to-crew equipment transfer
func _execute_crew_to_crew_transfer(target_crew_index: int) -> void:
	## Transfer selected equipment from current crew member to target
	if selected_crew_index < 0 or selected_crew_index >= crew_data.size() or target_crew_index < 0 or target_crew_index >= crew_data.size():
		return

	if selected_crew_index == target_crew_index:
		_show_notification("Cannot transfer to same crew member")
		return

	var selected_items = crew_equipment_list.get_selected_items()
	if selected_items.is_empty():
		return

	var item_index = selected_items[0]
	var source_member = crew_data[selected_crew_index]
	var target_member = crew_data[target_crew_index]
	var source_equipment = _get_member_equipment(source_member)

	if item_index >= source_equipment.size():
		return

	var item = source_equipment[item_index]

	# Get names for logging
	var source_name: String = source_member.character_name if "character_name" in source_member else "Crew %d" % (selected_crew_index + 1)
	var target_name: String = target_member.character_name if "character_name" in target_member else "Crew %d" % (target_crew_index + 1)
	var item_name: String = item.get("name", "Unknown") if item is Dictionary else str(item)

	# Try EquipmentManager first for proper state management
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	var source_id: String = source_member.character_id if "character_id" in source_member else ""
	var target_id: String = target_member.character_id if "character_id" in target_member else ""
	var equipment_id: String = item.get("id", "") if item is Dictionary else ""

	if equipment_manager and equipment_manager.has_method("transfer_equipment") and not source_id.is_empty() and not target_id.is_empty() and not equipment_id.is_empty():
		if equipment_manager.transfer_equipment(source_id, target_id, equipment_id):
			# Update local state to match
			source_equipment.remove_at(item_index)
			_set_member_equipment(source_member, source_equipment)
			var target_equipment = _get_member_equipment(target_member)
			target_equipment.append(item)
			_set_member_equipment(target_member, target_equipment)
		else:
			_show_notification("Transfer failed")
			return
	else:
		# Fallback to local state update only
		source_equipment.remove_at(item_index)
		_set_member_equipment(source_member, source_equipment)
		var target_equipment = _get_member_equipment(target_member)
		target_equipment.append(item)
		_set_member_equipment(target_member, target_equipment)

	# Refresh displays
	_populate_crew_equipment()
	_populate_crew_list()
	_update_ui_display()

	_show_notification("Transferred %s to %s" % [item_name, target_name])

## Sprint C: Show notification to user
func _show_notification(message: String) -> void:
	## Show notification via NotificationManager if available
	var notification_mgr = get_node_or_null("/root/NotificationManager")
	if notification_mgr and notification_mgr.has_method("show_info"):
		notification_mgr.show_info(message)
	else:
		pass

func _on_confirm_pressed() -> void:
	## Confirm equipment assignments
	assignment_completed = true
	_lock_after_confirm()

	# Persist equipment assignments to campaign (Sprint 26.3: Character-Everywhere)
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Campaign is a Resource, get crew members directly
		if campaign and campaign.has_method("get_crew_members"):
			var campaign_crew = campaign.get_crew_members()
			for i in range(mini(crew_data.size(), campaign_crew.size())):
				var local_member = crew_data[i]
				var campaign_member = campaign_crew[i]
				# Both are Character objects - copy equipment directly
				if "equipment" in local_member and "equipment" in campaign_member:
					campaign_member.equipment = _get_member_equipment(local_member).duplicate()

			# Update stash via campaign method if available
			if campaign.has_method("set_ship_stash"):
				campaign.set_ship_stash(stash_items.duplicate())
			elif "ship_stash" in campaign:
				campaign.ship_stash = stash_items.duplicate()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "assign_equipment",
			"crew_count": crew_data.size(),
			"stash_count": stash_items.size()
		})

## UI Updates
func _update_ui_display() -> void:
	## Update all UI elements
	var has_selection = selected_crew_index >= 0

	if transfer_to_stash_button:
		transfer_to_stash_button.disabled = not has_selection
	if transfer_to_crew_button:
		transfer_to_crew_button.disabled = not has_selection
	if transfer_between_crew_button:
		transfer_between_crew_button.disabled = not has_selection

	if not has_selection and selected_crew_label:
		selected_crew_label.text = "Select a crew member"

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "assign_equipment":
		pass

## Post-confirm lockdown — prevent edits after assignments finalized
func _lock_after_confirm() -> void:
	if confirm_button:
		confirm_button.disabled = true
	for btn in [transfer_to_stash_button, transfer_to_crew_button, transfer_between_crew_button]:
		if btn:
			btn.disabled = true
	for list_ctrl in [crew_list, crew_equipment_list, stash_list]:
		if list_ctrl:
			list_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			list_ctrl.modulate.a = 0.5

## Public API
func is_assignment_completed() -> bool:
	## Check if equipment assignment is completed
	return assignment_completed

## WP-3: Method expected by WorldPhaseController
func is_equipment_assigned() -> bool:
	## Check if any crew member has equipment assigned.
	## Returns true if at least one crew member has equipment OR the user explicitly confirmed 'proceed without'.
	return assignment_completed

func get_crew_data() -> Array:
	return crew_data.duplicate(true)

func get_stash_data() -> Array:
	## Get updated stash data
	return stash_items.duplicate(true)

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	## Get step results for phase completion (standardized interface)
	return {
		"assignment_completed": assignment_completed,
		"crew_data": crew_data.duplicate(true),
		"stash_data": stash_items.duplicate(true),
		"selected_crew_index": selected_crew_index
	}

func reset_equipment_phase() -> void:
	## Reset for new turn
	selected_crew_index = -1
	_selected_equipment_index = -1
	_selected_stash_index = -1
	assignment_completed = false
	_update_ui_display()
	_update_detail_strip()

# ============================================================
# DETAIL STRIP — Equipment stats + crew stats display
# ============================================================

func _on_equipment_item_selected(index: int) -> void:
	## Handle crew equipment item selection
	_selected_equipment_index = index
	_selected_stash_index = -1
	if stash_list:
		stash_list.deselect_all()
	_update_detail_strip()

func _on_stash_item_selected(index: int) -> void:
	## Handle stash item selection
	_selected_stash_index = index
	_selected_equipment_index = -1
	if crew_equipment_list:
		crew_equipment_list.deselect_all()
	_update_detail_strip()

func _load_equipment_database() -> void:
	## Cache equipment data from all canonical JSON sources
	# Primary: equipment_database.json (commerce data with full stats)
	var path := "res://data/equipment_database.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_equipment_db = json.data if json.data is Dictionary else {}

	# Secondary: weapons.json (Core Rules weapon stats — same structure)
	var wp := FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if wp:
		var json2 := JSON.new()
		if json2.parse(wp.get_as_text()) == OK:
			var wp_data: Dictionary = json2.data if json2.data is Dictionary else {}
			# Merge weapons not already present (by name, case-insensitive)
			var existing_names := {}
			for w in _equipment_db.get("weapons", []):
				if w is Dictionary:
					existing_names[w.get("name", "").to_lower()] = true
			for w in wp_data.get("weapons", []):
				if w is Dictionary:
					var wname: String = w.get("name", "").to_lower()
					if wname not in existing_names:
						if not _equipment_db.has("weapons"):
							_equipment_db["weapons"] = []
						_equipment_db["weapons"].append(w)
						existing_names[wname] = true

	# Tertiary: armor.json
	var ap := FileAccess.open("res://data/armor.json", FileAccess.READ)
	if ap:
		var json3 := JSON.new()
		if json3.parse(ap.get_as_text()) == OK:
			var ap_data: Dictionary = json3.data if json3.data is Dictionary else {}
			var armor_arr: Array = ap_data.get("armor", [])
			if not armor_arr.is_empty() and _equipment_db.get("armor", []).is_empty():
				_equipment_db["armor"] = armor_arr

func _resolve_item(item: Variant) -> Dictionary:
	## Normalize an equipment item to a full Dictionary record.
	## Handles String IDs/names and partial Dictionaries by
	## looking up the full record in equipment_database.json.
	if item is Dictionary:
		# Already has full stats?
		if item.has("shots") or item.has("damage") \
				or item.has("saving_throw"):
			return item
		# Partial dict — try to enrich from DB
		var item_id: String = item.get("id", "")
		var item_name: String = item.get("name", "")
		var found := _search_db(item_id, item_name)
		if not found.is_empty():
			return found
		return item
	if item is String:
		var found := _search_db(item, item)
		if not found.is_empty():
			return found
		return {"name": item, "type": "Unknown"}
	return {"name": str(item), "type": "Unknown"}

func _search_db(id_or_name: String, name_fallback: String) -> Dictionary:
	## Search equipment DB arrays by id then by name (case-insensitive)
	var id_lower := id_or_name.to_lower()
	var fb_lower := name_fallback.to_lower()
	for category: String in ["weapons", "armor", "gear"]:
		var items: Array = _equipment_db.get(category, [])
		for entry in items:
			if entry is Dictionary:
				if entry.get("id", "").to_lower() == id_lower:
					return entry
				var ename: String = str(entry.get("name", "")).to_lower()
				if ename == id_lower:
					return entry
				if not fb_lower.is_empty() and ename == fb_lower:
					return entry
	return {}

func _determine_item_category(item: Dictionary) -> String:
	## Classify an equipment item by stat keys or type field
	if item.has("shots") or item.has("damage") \
			or item.has("range"):
		return "weapon"
	if item.has("saving_throw"):
		return "armor"
	# Fallback: use "type" or "category" field from partial dicts
	var item_type: String = str(
		item.get("type", item.get("category", ""))).to_lower()
	if item_type in ["weapon", "slug", "energy", "melee", "special",
			"grenade"]:
		return "weapon"
	if item_type in ["armor", "screen"]:
		return "armor"
	if item.has("description"):
		return "gear"
	return "unknown"

# ── Detail Strip Build ────────────────────────────────────

func _build_detail_strip() -> void:
	## Build the detail strip and insert before ConfirmButton
	_detail_strip = HBoxContainer.new()
	_detail_strip.name = "DetailStrip"
	_detail_strip.add_theme_constant_override("separation", SPACING_MD)
	_detail_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_strip.visible = false # Hidden until a crew member is selected

	# Crew stats panel (left)
	_crew_stats_panel = PanelContainer.new()
	_crew_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_stats_panel.size_flags_stretch_ratio = 1.0
	_apply_glass_style(_crew_stats_panel)
	_detail_strip.add_child(_crew_stats_panel)

	# Item stats panel (right)
	_item_stats_panel = PanelContainer.new()
	_item_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_stats_panel.size_flags_stretch_ratio = 2.0
	_apply_glass_style(_item_stats_panel)
	_item_stats_panel.visible = false
	_detail_strip.add_child(_item_stats_panel)

	# Insert into VBoxContainer before ConfirmButton
	var vbox: VBoxContainer = get_node_or_null("VBoxContainer")
	if vbox and confirm_button:
		var btn_idx: int = confirm_button.get_index()
		vbox.add_child(_detail_strip)
		vbox.move_child(_detail_strip, btn_idx)

func _apply_glass_style(panel: PanelContainer) -> void:
	## Apply glass morphism card style to a PanelContainer
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		COLOR_SECONDARY.r, COLOR_SECONDARY.g,
		COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(
		COLOR_BORDER.r, COLOR_BORDER.g,
		COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(float(SPACING_SM))
	panel.add_theme_stylebox_override("panel", style)

func _update_detail_strip() -> void:
	## Rebuild detail strip content based on current selection
	if not _detail_strip:
		return

	# Crew stats panel
	_clear_children(_crew_stats_panel)
	if selected_crew_index >= 0 \
			and selected_crew_index < crew_data.size():
		var member = crew_data[selected_crew_index]
		var content := _build_crew_stats_content(member)
		_crew_stats_panel.add_child(content)
		_detail_strip.visible = true
	else:
		_detail_strip.visible = false
		return

	# Item stats panel
	_clear_children(_item_stats_panel)
	var selected_item: Dictionary = _get_selected_item()
	if not selected_item.is_empty():
		var member = crew_data[selected_crew_index]
		var content := _build_item_stats_content(selected_item)
		_item_stats_panel.add_child(content)
		# Synergy hints
		var hints := _build_synergy_hints(member, selected_item)
		if hints:
			content.add_child(hints)
		_item_stats_panel.visible = true
	else:
		_item_stats_panel.visible = false

func _get_selected_item() -> Dictionary:
	## Get the currently selected equipment item (crew or stash)
	if _selected_equipment_index >= 0 \
			and selected_crew_index >= 0 \
			and selected_crew_index < crew_data.size():
		var member = crew_data[selected_crew_index]
		var equipment := _get_member_equipment(member)
		if _selected_equipment_index < equipment.size():
			return _resolve_item(
				equipment[_selected_equipment_index])
	if _selected_stash_index >= 0 \
			and _selected_stash_index < stash_items.size():
		return _resolve_item(stash_items[_selected_stash_index])
	return {}

func _clear_children(node: Control) -> void:
	## Remove all children from a node
	if not node:
		return
	for child in node.get_children():
		child.queue_free()

# ── Crew Stats Panel ─────────────────────────────────────

func _build_crew_stats_content(member) -> VBoxContainer:
	## Build a compact crew stats grid (6 stats)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)

	var header := Label.new()
	header.text = "CREW STATS"
	header.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	header.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	vbox.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_XS)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rea: int = member.reactions \
		if "reactions" in member else 1
	var spd: int = member.speed \
		if "speed" in member else 4
	var cbt: int = member.combat \
		if "combat" in member else 0
	var tgh: int = member.toughness \
		if "toughness" in member else 3
	var sav: int = member.savvy \
		if "savvy" in member else 0
	var lck: int = member.luck \
		if "luck" in member else 0

	var stats := [
		{"label": "REA", "value": str(rea),
			"color": Color("#10b981")},
		{"label": "SPD", "value": str(spd) + '"',
			"color": Color("#3b82f6")},
		{"label": "CBT", "value": _fmt_mod(cbt),
			"color": Color("#f59e0b")},
		{"label": "TGH", "value": str(tgh),
			"color": Color("#ef4444")},
		{"label": "SAV", "value": _fmt_mod(sav),
			"color": Color("#8b5cf6")},
		{"label": "LCK", "value": str(lck),
			"color": Color("#06b6d4")},
	]

	for stat: Dictionary in stats:
		grid.add_child(_create_stat_box(
			stat["label"], stat["value"], stat["color"]))

	vbox.add_child(grid)
	return vbox

func _create_stat_box(
		label_text: String, value_text: String,
		accent_color: Color) -> PanelContainer:
	## Create a compact stat badge (adapted from CharacterCard)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(44, 44)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.161, 0.216, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(float(SPACING_XS))
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	vbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	val.add_theme_color_override("font_color", accent_color)
	vbox.add_child(val)

	panel.add_child(vbox)
	return panel

func _fmt_mod(value: int) -> String:
	## Format stat modifier with + prefix
	return ("+" + str(value)) if value >= 0 else str(value)

# ── Item Stats Panel ──────────────────────────────────────

func _build_item_stats_content(item: Dictionary) -> VBoxContainer:
	## Build stats display for a weapon, armor, or gear item
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)

	var category := _determine_item_category(item)
	match category:
		"weapon":
			_build_weapon_stats(vbox, item)
		"armor":
			_build_armor_stats(vbox, item)
		_:
			_build_gear_stats(vbox, item)
	return vbox

func _build_weapon_stats(
		container: VBoxContainer, item: Dictionary) -> void:
	## Build weapon stat display
	# Row 1: Name + type + stats
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	row.add_child(name_lbl)

	# Type badge
	var wtype: String = item.get("type", "")
	if not wtype.is_empty():
		row.add_child(_create_type_badge(wtype))

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Stat labels
	var rng: int = item.get("range", 0)
	var shots: int = item.get("shots", 0)
	var dmg: int = item.get("damage", 0)

	if rng > 0:
		row.add_child(_stat_label("Range: %d\"" % rng))
	elif wtype == "Melee":
		row.add_child(_stat_label("Melee"))
	if shots > 0:
		row.add_child(_stat_label("Shots: %d" % shots))
	row.add_child(_stat_label("Dmg: %s" % _fmt_mod(dmg)))

	container.add_child(row)

	# Row 2: Trait badges
	var traits: Array = item.get("traits", [])
	if not traits.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", SPACING_XS)
		flow.add_theme_constant_override("v_separation", SPACING_XS)
		for t in traits:
			flow.add_child(_create_trait_badge(str(t)))
		container.add_child(flow)

func _build_armor_stats(
		container: VBoxContainer, item: Dictionary) -> void:
	## Build armor stat display
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	row.add_child(name_lbl)

	row.add_child(_create_type_badge(
		item.get("type", "Armor")))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var save_val: String = item.get("saving_throw", "none")
	if save_val != "none":
		row.add_child(_stat_label("Save: %s" % save_val))

	container.add_child(row)

	# Stat bonuses
	var stat_bonus: Dictionary = item.get("stat_bonus", {})
	if not stat_bonus.is_empty():
		var bonus_lbl := Label.new()
		var parts: Array[String] = []
		for key: String in stat_bonus:
			if key.ends_with("_cap"):
				continue
			var val: int = int(stat_bonus[key])
			var cap: int = int(stat_bonus.get(key + "_cap", 0))
			var text := "+%d %s" % [val, key.capitalize()]
			if cap > 0:
				text += " (max %d)" % cap
			parts.append(text)
		bonus_lbl.text = ", ".join(parts)
		bonus_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		bonus_lbl.add_theme_color_override(
			"font_color", COLOR_SUCCESS)
		container.add_child(bonus_lbl)

	# Conditional bonuses
	var cond: Dictionary = item.get("conditional_bonus", {})
	if not cond.is_empty():
		var cond_lbl := Label.new()
		var stat_name: String = ""
		var val: int = 0
		var condition: String = cond.get("condition", "")
		for key: String in cond:
			if key == "condition" or key.ends_with("_cap"):
				continue
			stat_name = key.capitalize()
			val = int(cond[key])
		cond_lbl.text = "+%d %s (%s)" % [
			val, stat_name,
			condition.replace("_", " ")]
		cond_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		cond_lbl.add_theme_color_override(
			"font_color", COLOR_WARNING)
		container.add_child(cond_lbl)

	# Description
	var desc: String = item.get("description", "")
	if not desc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_XS)
		desc_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED)
		container.add_child(desc_lbl)

func _build_gear_stats(
		container: VBoxContainer, item: Dictionary) -> void:
	## Build gear/consumable stat display
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	row.add_child(name_lbl)

	var gtype: String = item.get("type", "Gear")
	row.add_child(_create_type_badge(gtype))

	if item.get("single_use", false):
		var warn := Label.new()
		warn.text = "SINGLE USE"
		warn.add_theme_font_size_override(
			"font_size", FONT_SIZE_XS)
		warn.add_theme_color_override(
			"font_color", COLOR_WARNING)
		row.add_child(warn)

	container.add_child(row)

	var desc: String = item.get("description", "")
	if not desc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		desc_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY)
		container.add_child(desc_lbl)

func _stat_label(text: String) -> Label:
	## Create a compact stat label for weapon rows
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return lbl

func _create_type_badge(type_name: String) -> PanelContainer:
	## Create a small type badge (Slug, Energy, Armor, etc.)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g,
		COLOR_ACCENT.b, 0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = type_name
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	panel.add_child(lbl)
	return panel

func _create_trait_badge(trait_name: String) -> PanelContainer:
	## Create a color-coded trait pill badge
	var panel := PanelContainer.new()
	var color: Color
	if trait_name in _BENEFICIAL_TRAITS:
		color = COLOR_SUCCESS
	elif trait_name in _NEGATIVE_TRAITS:
		color = COLOR_DANGER
	else:
		color = COLOR_WARNING

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = trait_name
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)
	return panel

# ── Synergy Hints ─────────────────────────────────────────

func _build_synergy_hints(
		member, item: Dictionary) -> VBoxContainer:
	## Build contextual synergy callouts between crew stats
	## and the selected equipment item
	var category := _determine_item_category(item)
	var hints: Array[String] = []
	var hint_colors: Array[Color] = []

	var cbt: int = member.combat \
		if "combat" in member else 0
	var spd: int = member.speed \
		if "speed" in member else 4
	var rea: int = member.reactions \
		if "reactions" in member else 1
	var tgh: int = member.toughness \
		if "toughness" in member else 3

	if category == "weapon":
		var traits: Array = item.get("traits", [])
		var is_melee: bool = "Melee" in traits \
			or item.get("type", "") == "Melee"

		# Combat skill synergy
		if not is_melee and cbt != 0:
			hints.append(
				"Combat %s adds to hit rolls" % _fmt_mod(cbt))
			hint_colors.append(
				COLOR_SUCCESS if cbt > 0 else COLOR_DANGER)

		# Snap Shot
		if "Snap Shot" in traits:
			var total: int = cbt + 1
			hints.append(
				"Snap Shot: +1 to Hit (total %s)" \
				% _fmt_mod(total))
			hint_colors.append(COLOR_SUCCESS)

		# Heavy trait
		if "Heavy" in traits:
			hints.append(
				"Heavy: must stay stationary to fire")
			hint_colors.append(COLOR_WARNING)

		# Critical
		if "Critical" in traits:
			hints.append(
				"Critical: natural 6 does double damage")
			hint_colors.append(COLOR_SUCCESS)

		# Piercing
		if "Piercing" in traits:
			hints.append("Piercing: ignores armor saves")
			hint_colors.append(COLOR_SUCCESS)

		# Melee traits
		if is_melee:
			if "Elegant" in traits:
				hints.append("Elegant: +1 to Brawl rolls")
				hint_colors.append(COLOR_SUCCESS)
			if "Clumsy" in traits:
				hints.append("Clumsy: -1 to Brawl rolls")
				hint_colors.append(COLOR_DANGER)

	elif category == "armor":
		# Stat bonus synergy
		var stat_bonus: Dictionary = item.get("stat_bonus", {})
		for key: String in stat_bonus:
			if key.ends_with("_cap"):
				continue
			var bonus: int = int(stat_bonus[key])
			var cap: int = int(stat_bonus.get(key + "_cap", 0))
			var current: int = 0
			match key:
				"reactions": current = rea
				"toughness": current = tgh
				"speed": current = spd
			var effective: int = current + bonus
			if cap > 0:
				effective = mini(effective, cap)
			hints.append("%s: %d \u2192 %d (with this armor)" \
				% [key.capitalize(), current, effective])
			hint_colors.append(COLOR_ACCENT)

		# Conditional bonus synergy
		var cond: Dictionary = item.get(
			"conditional_bonus", {})
		if not cond.is_empty():
			for key: String in cond:
				if key == "condition" \
						or key.ends_with("_cap"):
					continue
				var bonus: int = int(cond[key])
				var current: int = 0
				match key:
					"toughness": current = tgh
					"reactions": current = rea
				var condition: String = cond.get(
					"condition", "").replace("_", " ")
				hints.append(
					"%s: %d \u2192 %d (if %s)" \
					% [key.capitalize(), current,
						current + bonus, condition])
				hint_colors.append(COLOR_WARNING)

	if hints.is_empty():
		return null

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var sep := HSeparator.new()
	sep.modulate = Color(COLOR_BORDER.r, COLOR_BORDER.g,
		COLOR_BORDER.b, 0.3)
	vbox.add_child(sep)

	for i: int in range(hints.size()):
		var lbl := Label.new()
		lbl.text = "\u25b8 " + hints[i]
		lbl.add_theme_font_size_override(
			"font_size", FONT_SIZE_XS)
		lbl.add_theme_color_override(
			"font_color", hint_colors[i])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	return vbox
