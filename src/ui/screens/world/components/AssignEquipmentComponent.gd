extends Control
class_name AssignEquipmentComponent

## Assign Equipment Component - Equipment Management System
## Implements Core Rules p.85 - Transfer items between crew members and stash
## Characters can trade items, leave items in stash, or take items from stash

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# UI Components
@onready var crew_list: ItemList = %CrewList
@onready var crew_equipment_list: ItemList = %CrewEquipmentList
@onready var stash_list: ItemList = %StashList
@onready var transfer_to_stash_button: Button = %TransferToStashButton
@onready var transfer_to_crew_button: Button = %TransferToCrewButton
@onready var transfer_between_crew_button: Button = %TransferBetweenCrewButton
@onready var confirm_button: Button = %ConfirmButton
@onready var selected_crew_label: Label = %SelectedCrewLabel

# State
var crew_data: Array = []
var stash_items: Array = []
var selected_crew_index: int = -1
var selected_target_crew_index: int = -1
var assignment_completed: bool = false

func _ready() -> void:
	name = "AssignEquipmentComponent"
	print("AssignEquipmentComponent: Initialized - Five Parsecs equipment management")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()
	_apply_touch_target_sizing()

## Sprint C: Apply 48px minimum touch targets for mobile UX
func _apply_touch_target_sizing() -> void:
	## Apply 48px minimum item height to all ItemLists for touch compliance
	const TOUCH_TARGET_MIN := 48
	if crew_list:
		crew_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if crew_equipment_list:
		crew_equipment_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if stash_list:
		stash_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)

func _initialize_event_bus() -> void:
	## Connect to the centralized event bus
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("AssignEquipmentComponent: Connected to event bus")

func _exit_tree() -> void:
	## Cleanup event bus subscriptions to prevent memory leaks
	if event_bus:
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

func _connect_ui_signals() -> void:
	## Connect UI button signals
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
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
	_update_ui_display()

	print("AssignEquipmentComponent: Initialized with %d crew, %d stash items" % [crew.size(), stash.size()])

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
	_populate_crew_equipment()
	_update_ui_display()

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
				print("AssignEquipmentComponent: Transferred %s to ship stash via EquipmentManager" % item.get("name", "Unknown"))
			else:
				push_warning("AssignEquipmentComponent: EquipmentManager transfer failed - stash may be full")
				return
		else:
			# Fallback to local state update only
			equipment.remove_at(item_index)
			_set_member_equipment(member, equipment)
			stash_items.append(item)
			print("AssignEquipmentComponent: Transferred %s to stash (local only)" % str(item))

		_populate_crew_equipment()
		_populate_stash_list()
		_populate_crew_list()
		_update_ui_display()

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
				print("AssignEquipmentComponent: Transferred %s to crew member via EquipmentManager" % item.get("name", "Unknown"))
			else:
				push_warning("AssignEquipmentComponent: EquipmentManager transfer from stash failed")
				return
		else:
			# Fallback to local state update only
			stash_items.remove_at(item_index)
			var equipment = _get_member_equipment(member)
			equipment.append(item)
			_set_member_equipment(member, equipment)
			print("AssignEquipmentComponent: Transferred %s to crew member (local only)" % str(item))

		_populate_crew_equipment()
		_populate_stash_list()
		_populate_crew_list()
		_update_ui_display()

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
			print("AssignEquipmentComponent: Transferred %s from %s to %s via EquipmentManager" % [item_name, source_name, target_name])
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
		print("AssignEquipmentComponent: Transferred %s from %s to %s (local only)" % [item_name, source_name, target_name])

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
		print("AssignEquipmentComponent: %s" % message)

func _on_confirm_pressed() -> void:
	## Confirm equipment assignments
	assignment_completed = true

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

			print("AssignEquipmentComponent: Persisted equipment for %d crew and %d stash items" % [
				crew_data.size(), stash_items.size()
			])

	print("AssignEquipmentComponent: Equipment assignments confirmed")

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
		print("AssignEquipmentComponent: Equipment phase started")

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
	assignment_completed = false
	_update_ui_display()
	print("AssignEquipmentComponent: Reset for new turn")
