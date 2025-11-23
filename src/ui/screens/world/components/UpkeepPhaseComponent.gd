extends Control
class_name UpkeepPhaseComponent

## Upkeep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs upkeep rules only
## Implements Core Rules p.76 - Ship maintenance and crew upkeep calculations

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const FPCM_DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components
@onready var upkeep_container: VBoxContainer = %UpkeepContainer
@onready var credits_display: Label = %CreditsDisplay
@onready var maintenance_cost_label: Label = %MaintenanceCostLabel
@onready var crew_upkeep_label: Label = %CrewUpkeepLabel
@onready var total_cost_label: Label = %TotalCostLabel
@onready var auto_calculate_button: Button = %AutoCalculateButton
@onready var manual_calculate_button: Button = %ManualCalculateButton
@onready var progress_bar: ProgressBar = %UpkeepProgressBar

# Upkeep calculation state
var current_upkeep_data: Dictionary = {}
var ship_data: Dictionary = {}
var crew_data: Array = []
var automation_enabled: bool = false
var upkeep_completed: bool = false

# Five Parsecs upkeep constants (Core Rules p.76)
const BASE_CREW_UPKEEP_PER_MEMBER: int = 1  # 1 credit per crew member
const SHIP_MAINTENANCE_BASE_COST: int = 1   # 1 credit base maintenance
const DAMAGED_SHIP_MULTIPLIER: float = 2.0  # Double cost if ship damaged

func _ready() -> void:
	name = "UpkeepPhaseComponent"
	print("UpkeepPhaseComponent: Initialized - handling Five Parsecs upkeep rules")
	
	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""

	# Access the globally registered CampaignTurnEventBus singleton (autoload)
	event_bus = get_node("/root/CampaignTurnEventBus")

	# Validate event_bus type (for editor and runtime safety)
	assert(event_bus is CampaignTurnEventBus, "UpkeepPhaseComponent: Event bus is not of type CampaignTurnEventBus")

	# Subscribe to relevant events
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

	print("UpkeepPhaseComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
	if auto_calculate_button:
		auto_calculate_button.pressed.connect(_on_auto_calculate_pressed)
	if manual_calculate_button:
		manual_calculate_button.pressed.connect(_on_manual_calculate_pressed)

func _setup_initial_state() -> void:
	"""Initialize the component state"""
	upkeep_completed = false
	current_upkeep_data = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"total_cost": 0,
		"can_afford": false
	}
	_update_ui_display()

## Public API: Initialize upkeep phase with campaign data
func initialize_upkeep_phase(ship: Dictionary, crew: Array) -> void:
	"""Initialize upkeep phase with current ship and crew data"""
	ship_data = ship.duplicate()
	crew_data = crew.duplicate()
	
	print("UpkeepPhaseComponent: Initialized with ship: %s, crew size: %d" % [ship_data.get("name", "Unknown"), crew_data.size()])
	
	# Reset state for new calculation
	upkeep_completed = false
	_setup_initial_state()
	_update_ui_display()
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.UPKEEP_STARTED, {
			"ship_data": ship_data,
			"crew_size": crew_data.size()
		})

## Core Five Parsecs upkeep calculation (Core Rules p.76)
func calculate_upkeep_costs() -> Dictionary:
	"""Calculate upkeep costs according to Five Parsecs rules"""
	var results = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"total_cost": 0,
		"can_afford": false,
		"current_credits": 0
	}
	
	# Get current credits from campaign data
	results.current_credits = GameStateManager.get_credits()
	
	# Calculate crew upkeep - 1 credit per crew member (Core Rules p.76)
	results.crew_upkeep = crew_data.size() * BASE_CREW_UPKEEP_PER_MEMBER
	
	# Calculate ship maintenance (Core Rules p.76)
	results.ship_maintenance = _calculate_ship_maintenance()
	
	# Total cost
	results.total_cost = results.crew_upkeep + results.ship_maintenance
	
	# Check if can afford
	results.can_afford = results.current_credits >= results.total_cost
	
	print("UpkeepPhaseComponent: Calculated upkeep - Crew: %d, Ship: %d, Total: %d, Credits: %d" % [
		results.crew_upkeep, results.ship_maintenance, results.total_cost, results.current_credits
	])
	
	return results

func _calculate_ship_maintenance() -> int:
	"""Calculate ship maintenance costs based on ship condition"""
	var maintenance_cost = SHIP_MAINTENANCE_BASE_COST
	
	# Check if ship is damaged (Core Rules p.76)
	var ship_condition = ship_data.get("condition", "good")
	if ship_condition == "damaged":
		maintenance_cost = int(maintenance_cost * DAMAGED_SHIP_MULTIPLIER)
		print("UpkeepPhaseComponent: Ship damaged - maintenance cost doubled")
	
	# Check for special ship equipment that affects maintenance
	var ship_equipment = ship_data.get("equipment", [])
	for equipment in ship_equipment:
		if equipment.get("increases_maintenance", false):
			maintenance_cost += equipment.get("maintenance_cost", 0)
	
	return maintenance_cost

## Apply upkeep costs to campaign data
func apply_upkeep_costs(upkeep_results: Dictionary) -> bool:
	"""Apply calculated upkeep costs to campaign data"""
	if not upkeep_results.can_afford:
		print("UpkeepPhaseComponent: Cannot afford upkeep costs!")
		_handle_insufficient_funds(upkeep_results)
		return false
	
	# Deduct credits from campaign
	var success = GameStateManager.remove_credits(upkeep_results.total_cost)
	if success:
		upkeep_completed = true
		current_upkeep_data = upkeep_results

		print("UpkeepPhaseComponent: Upkeep costs applied successfully")

		# Publish completion event
		if event_bus:
			event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
				"phase_name": "upkeep",
				"costs_applied": upkeep_results,
				"remaining_credits": GameStateManager.get_credits()
			})

		return true
	
	print("UpkeepPhaseComponent: Failed to apply upkeep costs")
	return false

func _handle_insufficient_funds(upkeep_results: Dictionary) -> void:
	"""Handle case where crew cannot afford upkeep"""
	print("UpkeepPhaseComponent: Insufficient funds for upkeep")
	
	# In Five Parsecs, this could trigger debt, crew leaving, etc.
	# For now, just show error and publish event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.UPKEEP_ERROR, {
			"error_type": "insufficient_funds",
			"required": upkeep_results.total_cost,
			"available": upkeep_results.current_credits,
			"deficit": upkeep_results.total_cost - upkeep_results.current_credits
		})

## UI Event Handlers
func _on_auto_calculate_pressed() -> void:
	"""Handle auto-calculate upkeep button press"""
	print("UpkeepPhaseComponent: Auto-calculating upkeep...")
	
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
	
	# Publish progress events
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PROGRESS_UPDATED, {
			"component": "upkeep",
			"progress": 0.0,
			"status": "calculating"
		})
	
	# Perform calculation
	var results = calculate_upkeep_costs()
	
	# Simulate processing time for feedback
	await get_tree().create_timer(0.5).timeout
	
	if progress_bar:
		progress_bar.value = 100
	
	# Apply costs
	var success = apply_upkeep_costs(results)

	# Update current_upkeep_data with new credits after payment
	if success:
		current_upkeep_data["current_credits"] = GameStateManager.get_credits()

	if progress_bar:
		progress_bar.visible = false

	_update_ui_display()
	
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PROGRESS_UPDATED, {
			"component": "upkeep",
			"progress": 1.0,
			"status": "completed" if success else "failed"
		})

func _on_manual_calculate_pressed() -> void:
	"""Handle manual calculation for player review"""
	print("UpkeepPhaseComponent: Manual upkeep calculation")
	
	var results = calculate_upkeep_costs()
	current_upkeep_data = results
	_update_ui_display()
	
	# Don't automatically apply - let player confirm
	print("UpkeepPhaseComponent: Manual calculation complete - awaiting player confirmation")

## UI Updates
func _update_ui_display() -> void:
	"""Update UI display with current upkeep data"""
	if not current_upkeep_data.is_empty():
		if credits_display:
			var credit_text = "Credits: %d" % GameStateManager.get_credits()
			if upkeep_completed:
				credit_text += " (Upkeep Paid: -%d)" % current_upkeep_data.get("total_cost", 0)
			credits_display.text = credit_text

		if crew_upkeep_label:
			crew_upkeep_label.text = "Crew Upkeep: %d credits" % current_upkeep_data.get("crew_upkeep", 0)

		if maintenance_cost_label:
			maintenance_cost_label.text = "Ship Maintenance: %d credits" % current_upkeep_data.get("ship_maintenance", 0)

		if total_cost_label:
			var can_afford = current_upkeep_data.get("can_afford", false)
			var color = Color.GREEN if upkeep_completed else (Color.GREEN if can_afford else Color.RED)
			var status = " ✓ PAID" if upkeep_completed else ""
			total_cost_label.text = "Total Cost: %d credits%s" % [current_upkeep_data.get("total_cost", 0), status]
			total_cost_label.modulate = color

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "upkeep":
		print("UpkeepPhaseComponent: Upkeep phase started")
		# Initialize if needed

func _on_automation_toggled(data: Dictionary) -> void:
	"""Handle automation toggle events"""
	automation_enabled = data.get("enabled", false)
	if auto_calculate_button:
		auto_calculate_button.visible = automation_enabled
	print("UpkeepPhaseComponent: Automation %s" % ("enabled" if automation_enabled else "disabled"))

## Public API for integration
func is_upkeep_completed() -> bool:
	"""Check if upkeep phase is completed"""
	return upkeep_completed

func get_upkeep_results() -> Dictionary:
	"""Get the results of upkeep calculation"""
	return current_upkeep_data.duplicate()

func reset_upkeep_phase() -> void:
	"""Reset upkeep phase for new turn"""
	upkeep_completed = false
	current_upkeep_data.clear()
	ship_data.clear()
	crew_data.clear()
	_update_ui_display()
	print("UpkeepPhaseComponent: Reset for new turn")
