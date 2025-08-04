class_name TravelPhaseUI
extends Control

## Travel Phase UI for Five Parsecs Campaign Manager
## Handles upkeep and travel decisions for the campaign turn flow

signal phase_completed()
signal upkeep_completed()
signal travel_completed()

# UI References
@onready var step_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StepLabel
@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer
@onready var upkeep_details: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Upkeep/UpkeepDetails
@onready var upkeep_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Upkeep/UpkeepButton
@onready var travel_options: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Travel/TravelOptions
@onready var travel_event_details: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Travel/TravelEventDetails
@onready var log_book: RichTextLabel = $LogBook
@onready var back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/BackButton
@onready var next_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/NextButton

# State tracking
var campaign_data: Resource = null
var is_upkeep_completed: bool = false
var travel_decision_made: bool = false
var current_step: int = 0

# Manager references
var alpha_manager: Node = null
var campaign_manager: Node = null
var upkeep_system: Node = null

func _ready() -> void:
	_initialize_managers()
	_setup_ui()
	_connect_additional_signals()
	_setup_travel_icons()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

	if alpha_manager and alpha_manager.has_method("get_upkeep_system"):
		upkeep_system = alpha_manager.get_upkeep_system()

func _setup_ui() -> void:
	"""Setup initial UI state"""
	tab_container.current_tab = 0 # Start with upkeep tab
	step_label.text = "Step 1: Upkeep Phase"
	next_button.disabled = true
	_update_upkeep_display()

func _connect_additional_signals() -> void:
	"""Connect any additional signals needed"""
	if upkeep_system and upkeep_system.has_signal("upkeep_calculated"):
		upkeep_system.upkeep_calculated.connect(_on_upkeep_calculated)
	
	# Connect to CampaignPhaseManager for campaign flow integration
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if campaign_phase_manager:
		# Connect UI completion signal to phase manager
		phase_completed.connect(campaign_phase_manager._on_travel_phase_completed)
		print("TravelPhaseUI: Connected to CampaignPhaseManager")
	else:
		push_warning("TravelPhaseUI: CampaignPhaseManager not found - phase transitions may not work")

func setup_phase(data: Resource) -> void:
	"""Setup the travel phase with campaign data"""
	campaign_data = data
	_reset_phase_state()
	_update_upkeep_display()
	_add_log_entry("Travel Phase started")

func _reset_phase_state() -> void:
	"""Reset phase state for new campaign turn"""
	is_upkeep_completed = false
	travel_decision_made = false
	current_step = 0
	tab_container.current_tab = 0
	step_label.text = "Step 1: Upkeep Phase"
	next_button.disabled = true

func _update_upkeep_display() -> void:
	"""Update the upkeep information display"""
	if not upkeep_system or not campaign_data:
		upkeep_button.text = "Perform Upkeep (No Data)"
		upkeep_button.disabled = true
		return

	# Clear existing upkeep details
	for child in upkeep_details.get_children():
		child.queue_free()

	# Get upkeep costs
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(campaign_data)

	var total_cost = upkeep_costs.get("total_cost", 0)

	var crew_cost = upkeep_costs.get("crew_cost", 0)

	var ship_cost = upkeep_costs.get("ship_cost", 0)
	var current_credits = campaign_data.get_meta("credits", 0) if campaign_data else 0

	# Create upkeep cost display
	var cost_label: Label = Label.new()
	cost_label.text = "Upkeep Costs:\n• Crew: %d credits\n• Ship: %d credits\n• Total: %d credits" % [crew_cost, ship_cost, total_cost]
	upkeep_details.add_child(cost_label)

	var credits_label: Label = Label.new()
	credits_label.text = "Current Credits: %d" % current_credits
	upkeep_details.add_child(credits_label)

	# Update button state
	if current_credits >= total_cost:
		upkeep_button.text = "Pay Upkeep (%d credits)" % total_cost
		upkeep_button.disabled = false
	else:
		upkeep_button.text = "Insufficient Credits (%d needed)" % total_cost
		upkeep_button.disabled = true

func _add_log_entry(text: String) -> void:
	"""Add an entry to the log book"""
	var timestamp = Time.get_datetime_string_from_system()
	log_book.append_text("[%s] %s\n" % [timestamp, text])

# Signal handlers

func _on_upkeep_button_pressed() -> void:
	"""Handle upkeep button press"""
	if not upkeep_system or not campaign_data:
		_add_log_entry("Error: Cannot perform upkeep - missing data")
		return

	var result: Variant = upkeep_system.perform_upkeep(campaign_data)

	if result.get("success", false):
		is_upkeep_completed = true
		upkeep_button.text = "Upkeep Complete ✓"
		upkeep_button.disabled = true
		_add_log_entry("Upkeep completed successfully")
		_advance_to_travel()
	else:
		var error: int = result.get("error", "Unknown error")
		_add_log_entry("Upkeep failed: %s" % error)

func _advance_to_travel() -> void:
	"""Advance to travel step"""
	current_step = 1
	step_label.text = "Step 2: Travel Decision"
	tab_container.current_tab = 1
	upkeep_completed.emit()

func _on_stay_button_pressed() -> void:
	"""Handle stay in current location"""
	travel_decision_made = true
	_add_log_entry("Decided to stay in current location")
	_complete_travel_phase()

func _on_travel_button_pressed() -> void:
	"""Handle travel to new location with Five Parsecs travel mechanics"""
	travel_decision_made = true
	_add_log_entry("Decided to travel to new location")
	
	# Five Parsecs travel event generation (Core Rules p.58-61)
	_generate_travel_event()
	_complete_travel_phase()

func _on_next_event_button_pressed() -> void:
	"""Generate next travel event using Five Parsecs tables"""
	_generate_travel_event()
	_add_log_entry("Travel event generated")

func _complete_travel_phase() -> void:
	"""Complete the travel phase"""
	next_button.disabled = false
	travel_completed.emit() # warning: return value discarded (intentional)
	_add_log_entry("Travel phase completed")

func _on_back_button_pressed() -> void:
	"""Handle back button press"""
	# Go back to previous phase or step
	if current_step > 0:
		current_step -= 1
		if current_step == 0:
			tab_container.current_tab = 0
			step_label.text = "Step 1: Upkeep Phase"

func _on_next_button_pressed() -> void:
	"""Handle next button press"""
	if is_upkeep_completed and travel_decision_made:
		phase_completed.emit() # warning: return value discarded (intentional)
		_add_log_entry("Travel phase complete - advancing to World phase")

func _on_upkeep_calculated(costs: Dictionary) -> void:
	"""Handle upkeep calculation completion"""
	_update_upkeep_display()

func get_phase_status() -> Dictionary:
	"""Get the current phase status"""
	return {
		"upkeep_completed": is_upkeep_completed,
		"travel_decision_made": travel_decision_made,
		"current_step": current_step,
		"can_advance": is_upkeep_completed and travel_decision_made
	}

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for this phase"""
	campaign_data = data
	_update_upkeep_display()


## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## Setup travel phase icons for enhanced visual navigation
func _setup_travel_icons() -> void:
	"""Setup icons for travel phase buttons to improve visual clarity"""
	# Phase 2: Travel Phase Icons Integration
	
	# Next Button (primary travel action) - icon_campaign_travel.svg
	if next_button:
		next_button.icon = preload("res://assets/basic icons/icon_campaign_travel.svg")
		next_button.expand_icon = true
		next_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("TravelPhaseUI: Travel phase icon applied to next button successfully")
	else:
		push_warning("TravelPhaseUI: Next button not found for icon assignment")

func _generate_travel_event() -> void:
	"""Generate travel event using Five Parsecs travel tables"""
	# Five Parsecs Travel Event Generation (Core Rules p.58-61)
	var dice_manager = get_node_or_null("/root/DiceManager")
	var travel_roll = 0
	
	if dice_manager and dice_manager.has_method("roll_dice"):
		travel_roll = dice_manager.roll_dice("Travel Event", "D100")
	else:
		travel_roll = randi_range(1, 100)
	
	_add_log_entry("Travel event roll: %d" % travel_roll)
	
	# Five Parsecs travel event table
	var event_result = _process_travel_event_roll(travel_roll)
	_display_travel_event(event_result)

func _process_travel_event_roll(roll: int) -> Dictionary:
	"""Process travel event roll using Five Parsecs tables"""
	var event = {
		"type": "none",
		"title": "Uneventful Journey",
		"description": "The journey passes without incident.",
		"effects": []
	}
	
	# Five Parsecs travel event probability table
	if roll <= 10: # Hostile encounter
		event.type = "hostile"
		event.title = "Hostile Encounter"
		event.description = "Your crew encounters hostile forces during travel. Prepare for battle!"
		event.effects = ["combat_encounter"]
		_add_log_entry("Warning: Hostile encounter detected!")
	elif roll <= 25: # Equipment malfunction
		event.type = "malfunction"
		event.title = "Equipment Malfunction"
		event.description = "Ship systems malfunction during travel. Repair costs required."
		event.effects = ["repair_cost_100"]
		_add_log_entry("Ship malfunction: 100 credits repair cost")
	elif roll <= 40: # Delayed arrival
		event.type = "delay"
		event.title = "Travel Delays"
		event.description = "Navigation issues cause delays. Arrive late at destination."
		event.effects = ["time_delay"]
		_add_log_entry("Travel delayed - late arrival")
	elif roll <= 60: # Opportunity
		event.type = "opportunity"
		event.title = "Trading Opportunity"
		event.description = "Encounter traders during journey. Opportunity for profitable exchange."
		event.effects = ["trading_opportunity"]
		_add_log_entry("Trading opportunity available")
	elif roll <= 80: # Information
		event.type = "information"
		event.title = "Useful Information"
		event.description = "Crew learns valuable information about the destination."
		event.effects = ["information_bonus"]
		_add_log_entry("Valuable information acquired")
	else: # Beneficial encounter
		event.type = "beneficial"
		event.title = "Helpful Encounter"
		event.description = "Meet friendly travelers who provide assistance or supplies."
		event.effects = ["credits_50", "supplies"]
		_add_log_entry("Beneficial encounter: gained supplies and credits")
	
	return event

func _display_travel_event(event: Dictionary) -> void:
	"""Display travel event details in the UI"""
	# Clear existing event details
	for child in travel_event_details.get_children():
		child.queue_free()
	
	# Create event display
	var title_label = Label.new()
	title_label.text = event.title
	title_label.add_theme_font_size_override("font_size", 18)
	travel_event_details.add_child(title_label)
	
	var description_label = Label.new()
	description_label.text = event.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	travel_event_details.add_child(description_label)
	
	# Process event effects
	_process_travel_event_effects(event.effects)
	
	# Add event resolution button if needed
	if event.type in ["hostile", "opportunity", "malfunction"]:
		var resolve_button = Button.new()
		resolve_button.text = "Resolve Event"
		resolve_button.pressed.connect(_on_resolve_travel_event.bind(event))
		travel_event_details.add_child(resolve_button)

func _process_travel_event_effects(effects: Array) -> void:
	"""Process the effects of a travel event"""
	for effect in effects:
		match effect:
			"combat_encounter":
				_schedule_combat_encounter()
			"repair_cost_100":
				_apply_repair_costs(100)
			"time_delay":
				_apply_time_delay()
			"trading_opportunity":
				_create_trading_opportunity()
			"information_bonus":
				_apply_information_bonus()
			"credits_50":
				_add_credits(50)
			"supplies":
				_add_supplies()

func _schedule_combat_encounter() -> void:
	"""Schedule a combat encounter for the next phase"""
	if campaign_data:
		campaign_data.set_meta("pending_combat", true)
		campaign_data.set_meta("combat_type", "travel_encounter")
	_add_log_entry("Combat encounter scheduled for arrival")

func _apply_repair_costs(cost: int) -> void:
	"""Apply repair costs to campaign funds"""
	if campaign_data:
		var current_credits = campaign_data.get_meta("credits", 0)
		var new_credits = max(0, current_credits - cost)
		campaign_data.set_meta("credits", new_credits)
		_add_log_entry("Repair costs applied: -%d credits" % cost)

func _apply_time_delay() -> void:
	"""Apply time delay effect"""
	if campaign_data:
		campaign_data.set_meta("arrival_delayed", true)
	_add_log_entry("Arrival delayed - some opportunities may be missed")

func _create_trading_opportunity() -> void:
	"""Create a trading opportunity"""
	if campaign_data:
		campaign_data.set_meta("trading_opportunity_available", true)
	_add_log_entry("Trading opportunity available at destination")

func _apply_information_bonus() -> void:
	"""Apply information bonus"""
	if campaign_data:
		campaign_data.set_meta("information_bonus", true)
	_add_log_entry("Information bonus: +1 to next mission roll")

func _add_credits(amount: int) -> void:
	"""Add credits to campaign funds"""
	if campaign_data:
		var current_credits = campaign_data.get_meta("credits", 0)
		campaign_data.set_meta("credits", current_credits + amount)
		_add_log_entry("Credits gained: +%d" % amount)

func _add_supplies() -> void:
	"""Add supplies to inventory"""
	if campaign_data:
		var current_supplies = campaign_data.get_meta("supplies", 0)
		campaign_data.set_meta("supplies", current_supplies + 2)
		_add_log_entry("Supplies gained: +2 units")

func _on_resolve_travel_event(event: Dictionary) -> void:
	"""Resolve a travel event that requires player interaction"""
	match event.type:
		"hostile":
			_resolve_hostile_encounter()
		"opportunity":
			_resolve_trading_opportunity()
		"malfunction":
			_resolve_equipment_malfunction()
	
	_add_log_entry("Travel event resolved: %s" % event.title)

func _resolve_hostile_encounter() -> void:
	"""Resolve hostile encounter during travel"""
	# Create dialog for player choice
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Hostile forces approach! Choose your action:"
	dialog.title = "Hostile Encounter"
	
	# Add custom buttons
	dialog.add_button("Fight", false, "fight")
	dialog.add_button("Evade", false, "evade")
	dialog.add_button("Negotiate", false, "negotiate")
	
	dialog.custom_action.connect(_on_hostile_encounter_choice)
	add_child(dialog)
	dialog.popup_centered()

func _resolve_trading_opportunity() -> void:
	"""Resolve trading opportunity"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Trading opportunity available! Gain 150 credits for 1 supply unit?"
	dialog.title = "Trading Opportunity"
	
	var accept_button = dialog.add_button("Accept Trade", false, "accept")
	var decline_button = dialog.add_button("Decline", false, "decline")
	
	dialog.custom_action.connect(_on_trading_choice)
	add_child(dialog)
	dialog.popup_centered()

func _resolve_equipment_malfunction() -> void:
	"""Resolve equipment malfunction"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Equipment malfunction detected! Pay 100 credits for repairs or risk continued problems?"
	dialog.title = "Equipment Malfunction"
	
	dialog.add_button("Pay Repairs", false, "repair")
	dialog.add_button("Risk It", false, "risk")
	
	dialog.custom_action.connect(_on_malfunction_choice)
	add_child(dialog)
	dialog.popup_centered()

func _on_hostile_encounter_choice(action: String) -> void:
	"""Handle hostile encounter choice"""
	match action:
		"fight":
			_schedule_combat_encounter()
			_add_log_entry("Chose to fight - combat encounter scheduled")
		"evade":
			# Evasion attempt
			var dice_manager = get_node_or_null("/root/DiceManager")
			var evasion_roll = 0
			if dice_manager:
				evasion_roll = dice_manager.roll_dice("Evasion", "D6")
			else:
				evasion_roll = randi_range(1, 6)
			
			if evasion_roll >= 4:
				_add_log_entry("Successfully evaded hostile forces!")
			else:
				_schedule_combat_encounter()
				_add_log_entry("Evasion failed - combat encounter scheduled")
		"negotiate":
			# Negotiation attempt
			var negotiation_roll = randi_range(1, 6)
			if negotiation_roll >= 5:
				_add_credits(-50) # Bribe cost
				_add_log_entry("Negotiation successful - paid 50 credits to avoid conflict")
			else:
				_schedule_combat_encounter()
				_add_log_entry("Negotiation failed - combat encounter scheduled")

func _on_trading_choice(action: String) -> void:
	"""Handle trading opportunity choice"""
	match action:
		"accept":
			var current_supplies = campaign_data.get_meta("supplies", 0) if campaign_data else 0
			if current_supplies >= 1:
				_add_supplies() # Remove 1 supply
				campaign_data.set_meta("supplies", current_supplies - 1)
				_add_credits(150)
				_add_log_entry("Trade completed: -1 supply, +150 credits")
			else:
				_add_log_entry("Insufficient supplies for trade")
		"decline":
			_add_log_entry("Trading opportunity declined")

func _on_malfunction_choice(action: String) -> void:
	"""Handle equipment malfunction choice"""
	match action:
		"repair":
			_apply_repair_costs(100)
			_add_log_entry("Equipment repaired - no further issues")
		"risk":
			if campaign_data:
				campaign_data.set_meta("equipment_unreliable", true)
			_add_log_entry("Equipment remains unreliable - may cause problems later")