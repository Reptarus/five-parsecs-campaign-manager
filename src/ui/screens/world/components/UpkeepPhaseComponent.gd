extends Control
class_name UpkeepPhaseComponent

## Upkeep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs upkeep rules only
## Implements Core Rules p.76 - Ship maintenance and crew upkeep calculations

const RulesHelpText = preload("res://src/data/rules_help_text.gd")

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")

# UI Components
@onready var upkeep_container: VBoxContainer = %UpkeepContainer
@onready var credits_display: Label = %CreditsDisplay
@onready var maintenance_cost_label: Label = %MaintenanceCostLabel
@onready var crew_upkeep_label: Label = %CrewUpkeepLabel
@onready var total_cost_label: Label = %TotalCostLabel
@onready var auto_calculate_button: Button = %AutoCalculateButton
@onready var manual_calculate_button: Button = %ManualCalculateButton
@onready var progress_bar: ProgressBar = %UpkeepProgressBar
@onready var help_button: Button = %HelpButton

# Design System Colors
const COLOR_AMBER := Color("#f59e0b")
const COLOR_EMERALD := Color("#10b981")
const COLOR_RED := Color("#ef4444")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# Help dialog reference
var _help_dialog: AcceptDialog = null

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
	
	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	## Connect to the centralized event bus

	# Access the globally registered CampaignTurnEventBus singleton (autoload)
	event_bus = get_node("/root/CampaignTurnEventBus")

	# Validate event_bus type (for editor and runtime safety)
	assert(event_bus is CampaignTurnEventBus, "UpkeepPhaseComponent: Event bus is not of type CampaignTurnEventBus")

	# Subscribe to relevant events
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)


func _exit_tree() -> void:
	## Cleanup event bus subscriptions to prevent memory leaks
	if event_bus:
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		event_bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	## Connect UI button signals
	if auto_calculate_button:
		auto_calculate_button.pressed.connect(_on_auto_calculate_pressed)
	if manual_calculate_button:
		manual_calculate_button.pressed.connect(_on_manual_calculate_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

func _setup_initial_state() -> void:
	## Initialize the component state
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
	## Initialize upkeep phase with current ship and crew data
	ship_data = ship.duplicate()
	crew_data = crew.duplicate()

	# Reset state for new calculation
	upkeep_completed = false
	# Auto-calculate costs immediately so the player sees real values on entry
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.UPKEEP_STARTED, {
			"ship_data": ship_data,
			"crew_size": crew_data.size()
		})

## Core Five Parsecs upkeep calculation (Core Rules p.76)
func calculate_upkeep_costs() -> Dictionary:
	## Calculate upkeep costs according to Five Parsecs rules
	var results = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"total_cost": 0,
		"can_afford": false,
		"current_credits": 0
	}
	
	# Get current credits from campaign data
	results.current_credits = GameStateManager.get_credits()
	
	# Calculate crew upkeep with world trait modifiers (Core Rules p.76, p.87-89)
	var effective_crew_size: int = crew_data.size()
	
	# Apply "high_cost" world trait modifier (Core Rules p.87-89)
	# "Your crew size counts as being 2 higher for the purpose of Upkeep costs"
	var world_traits: Array = _get_current_world_traits()
	if "high_cost" in world_traits:
		effective_crew_size += 2
	
	# Base upkeep: 1 credit per crew member (scales with crew size)
	results.crew_upkeep = effective_crew_size * BASE_CREW_UPKEEP_PER_MEMBER
	
	# Calculate ship maintenance (Core Rules p.76)
	results.ship_maintenance = _calculate_ship_maintenance()
	
	# Total cost
	results.total_cost = results.crew_upkeep + results.ship_maintenance
	
	# Check if can afford
	results.can_afford = results.current_credits >= results.total_cost
	
	return results

func _calculate_ship_maintenance() -> int:
	## Calculate ship maintenance costs based on ship condition
	var maintenance_cost = SHIP_MAINTENANCE_BASE_COST
	
	# Check if ship is damaged (Core Rules p.76)
	var ship_condition = ship_data.get("condition", "good")
	if ship_condition == "damaged":
		maintenance_cost = int(maintenance_cost * DAMAGED_SHIP_MULTIPLIER)
	
	# Check for special ship equipment that affects maintenance
	var ship_equipment = ship_data.get("equipment", [])
	for equipment in ship_equipment:
		if equipment.get("increases_maintenance", false):
			maintenance_cost += equipment.get("maintenance_cost", 0)
	
	return maintenance_cost

func _get_current_world_traits() -> Array:
	## Get world traits for current location from campaign data
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var campaign = gs.get_current_campaign()
		if campaign and "world_data" in campaign:
			var wd: Dictionary = campaign.world_data
			if wd.has("traits"):
				return wd.get("traits", [])
	return []

## Apply upkeep costs to campaign data
func apply_upkeep_costs(upkeep_results: Dictionary) -> bool:
	## Apply calculated upkeep costs to campaign data
	if not upkeep_results.can_afford:
		_handle_insufficient_funds(upkeep_results)
		return false
	
	# Deduct credits from campaign
	var success = GameStateManager.remove_credits(upkeep_results.total_cost)
	if success:
		upkeep_completed = true
		current_upkeep_data = upkeep_results


		# Publish completion event
		if event_bus:
			event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
				"phase_name": "upkeep",
				"costs_applied": upkeep_results,
				"remaining_credits": GameStateManager.get_credits()
			})

		return true
	
	return false

func _handle_insufficient_funds(upkeep_results: Dictionary) -> void:
	## Handle case where crew cannot afford upkeep
	
	# In Five Parsecs, this could trigger debt, crew leaving, etc.
	# For now, just show error and publish event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.UPKEEP_ERROR, {
			"error_type": "insufficient_funds",
			"required": upkeep_results.total_cost,
			"available": upkeep_results.current_credits,
			"deficit": upkeep_results.total_cost - upkeep_results.current_credits
		})

## Help System
func _on_help_button_pressed() -> void:
	## Show upkeep rules help dialog
	_show_help_dialog("Upkeep Phase", RulesHelpText.get_tooltip("upkeep_phase"))

func _show_help_dialog(title: String, content: String) -> void:
	## Show a help dialog with rules text
	if not _help_dialog:
		_help_dialog = AcceptDialog.new()
		_help_dialog.dialog_hide_on_ok = true
		add_child(_help_dialog)
	
	_help_dialog.title = title
	
	# Create or update content
	var existing_content := _help_dialog.get_node_or_null("HelpContent")
	if existing_content:
		existing_content.queue_free()
	
	var rich_text := RichTextLabel.new()
	rich_text.name = "HelpContent"
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.custom_minimum_size = Vector2(400, 200)
	rich_text.text = content
	rich_text.add_theme_color_override("default_color", Color("#f3f4f6"))
	_help_dialog.add_child(rich_text)
	
	_help_dialog.popup_centered()

## UI Event Handlers
func _on_auto_calculate_pressed() -> void:
	## Handle auto-calculate upkeep button press
	
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
	## Handle manual calculation for player review
	
	var results = calculate_upkeep_costs()
	current_upkeep_data = results
	_update_ui_display()
	
	# Don't automatically apply - let player confirm

## UI Updates
func _update_ui_display() -> void:
	## Update UI display with current upkeep data
	var current_credits: int = GameStateManager.get_credits()
	
	if credits_display:
		var credit_text := "Available Credits: %d" % current_credits
		if upkeep_completed:
			credit_text += " (Paid: -%d)" % current_upkeep_data.get("total_cost", 0)
		credits_display.text = credit_text
		# Color based on affordability
		var can_afford: bool = current_upkeep_data.get("can_afford", true)
		credits_display.add_theme_color_override("font_color", COLOR_EMERALD if can_afford else COLOR_RED)

	if not current_upkeep_data.is_empty():
		if crew_upkeep_label:
			crew_upkeep_label.text = "%d credits" % current_upkeep_data.get("crew_upkeep", 0)

		if maintenance_cost_label:
			maintenance_cost_label.text = "%d credits" % current_upkeep_data.get("ship_maintenance", 0)

		if total_cost_label:
			var total_cost: int = current_upkeep_data.get("total_cost", 0)
			var status := " ✓" if upkeep_completed else ""
			total_cost_label.text = "%d credits%s" % [total_cost, status]
			# Color: amber normally, green if paid, red if can't afford
			var color := COLOR_EMERALD if upkeep_completed else (COLOR_AMBER if current_upkeep_data.get("can_afford", true) else COLOR_RED)
			total_cost_label.add_theme_color_override("font_color", color)

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "upkeep":
		# Initialize if needed
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle events
	automation_enabled = data.get("enabled", false)
	if auto_calculate_button:
		auto_calculate_button.visible = automation_enabled

## Public API for integration
func is_upkeep_completed() -> bool:
	## Check if upkeep phase is completed
	return upkeep_completed

func get_upkeep_results() -> Dictionary:
	## Get the results of upkeep calculation
	return current_upkeep_data.duplicate()

func reset_upkeep_phase() -> void:
	## Reset upkeep phase for new turn
	upkeep_completed = false
	current_upkeep_data.clear()
	ship_data.clear()
	crew_data.clear()
	_update_ui_display()
