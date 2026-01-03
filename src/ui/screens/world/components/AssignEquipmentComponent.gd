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

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("AssignEquipmentComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
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
	"""Initialize component state"""
	selected_crew_index = -1
	assignment_completed = false
	_update_ui_display()

## Public API
func initialize_equipment_phase(crew: Array, stash: Array) -> void:
	"""Initialize equipment assignment with crew and stash data"""
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
	"""Populate crew member list"""
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
	"""Populate stash items list"""
	if not stash_list:
		return

	stash_list.clear()
	for item in stash_items:
		var item_name = item.get("name", "Unknown Item") if item is Dictionary else str(item)
		var damaged = item.get("damaged", false) if item is Dictionary else false
		var suffix = " [DAMAGED]" if damaged else ""
		stash_list.add_item(item_name + suffix)

func _populate_crew_equipment() -> void:
	"""Populate selected crew member's equipment"""
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
	"""Get equipment array from crew member (Sprint 26.3: Character-Everywhere)"""
	if not member:
		return []
	# Character objects may store equipment directly or via EquipmentManager
	if member.has_method("get_equipment"):
		return member.get_equipment()
	elif "equipment" in member:
		return member.equipment
	return []

func _set_member_equipment(member, equipment: Array) -> void:
	"""Set equipment array for crew member (Sprint 26.3: Character-Everywhere)"""
	if not member:
		return
	# Character objects may have set_equipment method or direct property
	if member.has_method("set_equipment"):
		member.set_equipment(equipment)
	elif "equipment" in member:
		member.equipment = equipment

func _get_equipment_count(member) -> int:
	"""Get count of equipment for crew member"""
	return _get_member_equipment(member).size()

## Transfer Actions
func _on_crew_selected(index: int) -> void:
	"""Handle crew member selection"""
	selected_crew_index = index
	_populate_crew_equipment()
	_update_ui_display()

	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	if selected_crew_label and index >= 0 and index < crew_data.size():
		var member = crew_data[index]
		var crew_name: String = member.character_name if "character_name" in member else "Crew %d" % (index + 1)
		selected_crew_label.text = "Selected: %s" % crew_name

func _on_transfer_to_stash_pressed() -> void:
	"""Transfer selected item from crew to stash"""
	if selected_crew_index < 0 or not crew_equipment_list:
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
	"""Transfer selected item from stash to crew"""
	if selected_crew_index < 0 or not stash_list:
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
	"""Transfer item between crew members (simplified - select target next)"""
	# For now, just transfer to next crew member as placeholder
	# Full implementation would show target selection dialog
	print("AssignEquipmentComponent: Transfer between crew - feature pending full UI")

func _on_confirm_pressed() -> void:
	"""Confirm equipment assignments"""
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
	"""Update all UI elements"""
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
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "assign_equipment":
		print("AssignEquipmentComponent: Equipment phase started")

## Public API
func is_assignment_completed() -> bool:
	"""Check if equipment assignment is completed"""
	return assignment_completed

func get_crew_data() -> Array:
	"""Get updated crew data with equipment assignments"""
	return crew_data.duplicate(true)

func get_stash_data() -> Array:
	"""Get updated stash data"""
	return stash_items.duplicate(true)

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	"""Get step results for phase completion (standardized interface)"""
	return {
		"assignment_completed": assignment_completed,
		"crew_data": crew_data.duplicate(true),
		"stash_data": stash_items.duplicate(true),
		"selected_crew_index": selected_crew_index
	}

func reset_equipment_phase() -> void:
	"""Reset for new turn"""
	selected_crew_index = -1
	assignment_completed = false
	_update_ui_display()
	print("AssignEquipmentComponent: Reset for new turn")
