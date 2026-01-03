extends Control
class_name MissionPrepComponent

## Mission Prep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs mission preparation
## Implements Core Rules p.82-85 - Equipment assignment and crew readiness

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const FPCM_DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components
@onready var mission_prep_container: VBoxContainer = %MissionPrepContainer
@onready var mission_briefing_label: Label = %MissionBriefingLabel
@onready var crew_list: ItemList = %CrewMembersList
@onready var equipment_list: ItemList = %EquipmentList
@onready var assign_button: Button = %AssignEquipmentButton
@onready var ready_button: Button = %ReadyForBattleButton
@onready var readiness_status_label: Label = %ReadinessStatusLabel

# Mission prep state
var mission_data: Dictionary = {}
var crew_data: Array[Dictionary] = []
var available_equipment: Array[Dictionary] = []
var crew_equipment_assignments: Dictionary = {}  # crew_id -> [equipment_ids]
var selected_crew_index: int = -1
var selected_equipment_index: int = -1
var prep_completed: bool = false
var automation_enabled: bool = false

func _ready() -> void:
	name = "MissionPrepComponent"
	print("MissionPrepComponent: Initialized - handling Five Parsecs mission preparation")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	# Find or create event bus
	event_bus = get_node("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"

	# Subscribe to relevant events
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, _on_job_accepted)

	print("MissionPrepComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button and list signals"""
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
	if equipment_list:
		equipment_list.item_selected.connect(_on_equipment_selected)
	if assign_button:
		assign_button.pressed.connect(_on_assign_equipment_pressed)
	if ready_button:
		ready_button.pressed.connect(_on_ready_for_battle_pressed)

func _setup_initial_state() -> void:
	"""Initialize the component state"""
	prep_completed = false
	selected_crew_index = -1
	selected_equipment_index = -1
	crew_equipment_assignments.clear()
	_update_ui_display()

## Public API: Initialize mission prep phase with campaign data
func initialize_mission_prep(mission: Dictionary, crew: Array, equipment: Array) -> void:
	"""Initialize mission prep with mission and crew data"""
	mission_data = mission.duplicate()
	crew_data = crew.duplicate()
	available_equipment = equipment.duplicate()

	print("MissionPrepComponent: Initialized prep for mission: %s with %d crew, %d equipment" % [
		mission_data.get("objective", "Unknown"),
		crew_data.size(),
		available_equipment.size()
	])

	# Reset assignments
	crew_equipment_assignments.clear()
	for member in crew_data:
		crew_equipment_assignments[member.get("id", "")] = []

	prep_completed = false
	_update_ui_display()

	# Publish mission prep started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.MISSION_PREP_STARTED, {
			"mission": mission_data,
			"crew_size": crew_data.size()
		})

## Equipment assignment logic
func assign_equipment_to_crew(crew_id: String, equipment_id: String) -> bool:
	"""Assign equipment to crew member (Core Rules p.83)"""
	# Validate equipment is available
	var equipment_item = null
	for item in available_equipment:
		if item.get("id", "") == equipment_id:
			equipment_item = item
			break

	if not equipment_item:
		print("MissionPrepComponent: Equipment %s not found" % equipment_id)
		return false

	# Check if equipment is already assigned
	for assignments in crew_equipment_assignments.values():
		if equipment_id in assignments:
			print("MissionPrepComponent: Equipment %s already assigned" % equipment_id)
			return false

	# Add to crew's equipment
	if not crew_equipment_assignments.has(crew_id):
		crew_equipment_assignments[crew_id] = []

	crew_equipment_assignments[crew_id].append(equipment_id)

	print("MissionPrepComponent: Assigned %s to crew %s" % [
		equipment_item.get("name", "Unknown"),
		crew_id
	])

	_update_ui_display()
	return true

func unassign_equipment_from_crew(crew_id: String, equipment_id: String) -> bool:
	"""Remove equipment assignment from crew member"""
	if not crew_equipment_assignments.has(crew_id):
		return false

	var assignments = crew_equipment_assignments[crew_id]
	var index = assignments.find(equipment_id)
	if index >= 0:
		assignments.remove_at(index)
		print("MissionPrepComponent: Unassigned equipment %s from crew %s" % [equipment_id, crew_id])
		_update_ui_display()
		return true

	return false

## Crew readiness checks (Core Rules p.84)
func check_crew_readiness() -> Dictionary:
	"""Check if crew is ready for battle"""
	var readiness = {
		"is_ready": true,
		"warnings": [],
		"crew_count": crew_data.size(),
		"equipped_crew": 0,
		"total_equipment": 0
	}

	# Check each crew member
	for member in crew_data:
		var member_id = member.get("id", "")
		var equipment_count = crew_equipment_assignments.get(member_id, []).size()

		readiness.total_equipment += equipment_count

		if equipment_count > 0:
			readiness.equipped_crew += 1
		else:
			readiness.warnings.append("Warning: %s has no equipment assigned" % member.get("name", "Unknown"))

	# Core Rules p.84: Minimum crew size for mission
	if readiness.crew_count < 1:
		readiness.is_ready = false
		readiness.warnings.append("Error: No crew members available")

	# Check if mission has special requirements
	var required_crew = mission_data.get("required_crew_size", 1)
	if readiness.crew_count < required_crew:
		readiness.is_ready = false
		readiness.warnings.append("Error: Mission requires at least %d crew members" % required_crew)

	print("MissionPrepComponent: Readiness check - %d/%d crew equipped, Ready: %s" % [
		readiness.equipped_crew,
		readiness.crew_count,
		readiness.is_ready
	])

	return readiness

## Auto-equip crew with best available gear
func auto_equip_crew() -> void:
	"""Automatically assign equipment to crew based on roles"""
	print("MissionPrepComponent: Auto-equipping crew...")

	# Sort equipment by effectiveness (weapons first, then gear)
	var weapons = []
	var gear = []

	for equipment in available_equipment:
		var equipment_type = equipment.get("type", "gear")
		if equipment_type == "weapon":
			weapons.append(equipment)
		else:
			gear.append(equipment)

	# Assign weapons first
	var crew_index = 0
	for weapon in weapons:
		if crew_index >= crew_data.size():
			break

		var crew_id = crew_data[crew_index].get("id", "")
		assign_equipment_to_crew(crew_id, weapon.get("id", ""))
		crew_index += 1

	# Then assign remaining gear
	crew_index = 0
	for item in gear:
		var crew_id = crew_data[crew_index % crew_data.size()].get("id", "")
		assign_equipment_to_crew(crew_id, item.get("id", ""))
		crew_index += 1

	print("MissionPrepComponent: Auto-equip complete")

## UI Event Handlers
func _on_crew_selected(index: int) -> void:
	"""Handle crew selection from list"""
	selected_crew_index = index
	_update_button_states()

func _on_equipment_selected(index: int) -> void:
	"""Handle equipment selection from list"""
	selected_equipment_index = index
	_update_button_states()

func _on_assign_equipment_pressed() -> void:
	"""Handle assign equipment button press"""
	if selected_crew_index < 0 or selected_crew_index >= crew_data.size():
		return
	if selected_equipment_index < 0 or selected_equipment_index >= available_equipment.size():
		return

	var crew_id = crew_data[selected_crew_index].get("id", "")
	var equipment_id = available_equipment[selected_equipment_index].get("id", "")

	assign_equipment_to_crew(crew_id, equipment_id)

func _on_ready_for_battle_pressed() -> void:
	"""Handle ready for battle button press"""
	var readiness = check_crew_readiness()

	if not readiness.is_ready:
		print("MissionPrepComponent: Crew not ready - showing warnings")
		_show_readiness_warnings(readiness.warnings)
		return

	prep_completed = true
	print("MissionPrepComponent: Mission prep complete - ready for battle")

	# Publish mission prep completed event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.MISSION_PREPARED, {
			"mission": mission_data,
			"crew_assignments": crew_equipment_assignments,
			"readiness": readiness
		})

	_update_ui_display()

## UI Updates
func _update_ui_display() -> void:
	"""Update UI display with current prep data"""
	_update_mission_briefing()
	_update_crew_list()
	_update_equipment_list()
	_update_readiness_status()
	_update_button_states()

func _update_mission_briefing() -> void:
	"""Update mission briefing display"""
	if not mission_briefing_label:
		return

	var briefing = """Mission Briefing:

Objective: %s
Enemy: %s
Danger Level: %d
Location: %s
Pay: %d credits

Prepare your crew and assign equipment for battle.""" % [
		mission_data.get("objective", "Unknown"),
		mission_data.get("enemy_type", "Unknown"),
		mission_data.get("danger_level", 0),
		mission_data.get("location", "Unknown"),
		mission_data.get("pay", 0)
	]

	mission_briefing_label.text = briefing

func _update_crew_list() -> void:
	"""Update crew list display"""
	if not crew_list:
		return

	crew_list.clear()
	for i in range(crew_data.size()):
		var member = crew_data[i]
		var member_id = member.get("id", "")
		var equipment_count = crew_equipment_assignments.get(member_id, []).size()

		var crew_text = "%s (%d equipment)" % [
			member.get("name", "Unknown"),
			equipment_count
		]
		crew_list.add_item(crew_text)

func _update_equipment_list() -> void:
	"""Update equipment list display"""
	if not equipment_list:
		return

	equipment_list.clear()
	for equipment_item in available_equipment:
		var equipment_id = equipment_item.get("id", "")
		var is_assigned = false

		# Check if already assigned
		for assignments in crew_equipment_assignments.values():
			if equipment_id in assignments:
				is_assigned = true
				break

		var equipment_text = "%s%s" % [
			equipment_item.get("name", "Unknown"),
			" (assigned)" if is_assigned else ""
		]
		equipment_list.add_item(equipment_text)

		# Disable if assigned
		if is_assigned:
			equipment_list.set_item_disabled(equipment_list.item_count - 1, true)

func _update_readiness_status() -> void:
	"""Update readiness status display"""
	if not readiness_status_label:
		return

	var readiness = check_crew_readiness()

	var status_text = "Status: %s\n%d/%d crew equipped" % [
		"READY" if readiness.is_ready else "NOT READY",
		readiness.equipped_crew,
		readiness.crew_count
	]

	readiness_status_label.text = status_text

	if readiness.is_ready:
		readiness_status_label.modulate = Color.GREEN
	else:
		readiness_status_label.modulate = Color.ORANGE

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	var has_crew = selected_crew_index >= 0 and selected_crew_index < crew_data.size()
	var has_equipment = selected_equipment_index >= 0 and selected_equipment_index < available_equipment.size()

	if assign_button:
		assign_button.disabled = not (has_crew and has_equipment) or prep_completed

	if ready_button:
		ready_button.disabled = prep_completed

func _show_readiness_warnings(warnings: Array) -> void:
	"""Display readiness warnings to player"""
	print("MissionPrepComponent: Readiness warnings:")
	for warning in warnings:
		print("  - %s" % warning)

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "mission_prep":
		print("MissionPrepComponent: Mission prep phase started")

func _on_automation_toggled(data: Dictionary) -> void:
	"""Handle automation toggle events"""
	automation_enabled = data.get("enabled", false)
	if automation_enabled:
		auto_equip_crew()
	print("MissionPrepComponent: Automation %s" % ("enabled" if automation_enabled else "disabled"))

func _on_job_accepted(data: Dictionary) -> void:
	"""Handle job accepted events - auto-initialize prep phase"""
	var job_data = data.get("job_data", {})
	if not job_data.is_empty():
		print("MissionPrepComponent: Job accepted - preparing for mission")

		# Get crew from GameState
		var crew: Array[Dictionary] = []
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.current_campaign:
			var campaign = game_state.current_campaign
			# FiveParsecsCampaign has crew_members (Array[Character]) and get_crew_members() method
			if campaign.has_method("get_crew_members"):
				crew = campaign.get_crew_members()
			elif campaign.crew_members.size() > 0:
				# Sprint 26.3: Character-Everywhere - crew_members are always Character objects
				for member in campaign.crew_members:
					if member != null and member.has_method("to_dictionary"):
						crew.append(member.to_dictionary())
					elif member is Dictionary:
						crew.append(member)

		# Get equipment from stash (stored in campaign settings or resources)
		var equipment: Array[Dictionary] = []
		if game_state and game_state.current_campaign:
			var campaign = game_state.current_campaign
			# Check for ship stash in settings
			if campaign.settings.has("ship") and campaign.settings["ship"].has("stash"):
				var stash = campaign.settings["ship"]["stash"]
				for item in stash:
					if item is Dictionary:
						equipment.append(item)
			# Also gather equipment from crew members
			for member in campaign.crew_members:
				if member != null and member.has_method("get_equipment"):
					var member_equipment = member.get_equipment()
					for item in member_equipment:
						if item is Dictionary:
							equipment.append(item)
						elif item != null and item.has_method("to_dictionary"):
							equipment.append(item.to_dictionary())

		print("MissionPrepComponent: Initializing with %d crew, %d equipment" % [crew.size(), equipment.size()])

		# Initialize with actual data
		initialize_mission_prep(job_data, crew, equipment)

## Public API for integration
func is_prep_completed() -> bool:
	"""Check if mission prep is completed"""
	return prep_completed

## Sprint 22.1: Alias for WorldPhaseController compatibility
func is_mission_prepared() -> bool:
	"""Alias for is_prep_completed() - used by WorldPhaseController"""
	return is_prep_completed()

func get_crew_assignments() -> Dictionary:
	"""Get crew equipment assignments"""
	return crew_equipment_assignments.duplicate()

func get_mission_data() -> Dictionary:
	"""Get mission data"""
	return mission_data.duplicate()

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	"""Get step results for phase completion (standardized interface)"""
	return {
		"prep_completed": prep_completed,
		"mission_data": mission_data.duplicate(),
		"crew_assignments": crew_equipment_assignments.duplicate(),
		"crew_data": crew_data.duplicate(),
		"available_equipment": available_equipment.duplicate()
	}

func reset_mission_prep() -> void:
	"""Reset mission prep for new mission"""
	prep_completed = false
	selected_crew_index = -1
	selected_equipment_index = -1
	crew_equipment_assignments.clear()
	mission_data.clear()
	crew_data.clear()
	available_equipment.clear()
	_update_ui_display()
	print("MissionPrepComponent: Reset for new mission")
