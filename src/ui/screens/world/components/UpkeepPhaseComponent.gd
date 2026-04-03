extends WorldPhaseComponent
class_name UpkeepPhaseComponent

## Upkeep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs upkeep rules only
## Implements Core Rules p.76 - Ship maintenance and crew upkeep calculations

const RulesHelpText = preload("res://src/data/rules_help_text.gd")

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

# Design System Colors — use UIColors singleton (no local duplicates)

# Upkeep calculation state
var current_upkeep_data: Dictionary = {}
var ship_data: Dictionary = {}
var crew_data: Array = []
var automation_enabled: bool = false
var upkeep_completed: bool = false

# Travel state (folded into Step 1 — Core Rules p.69)
var travel_decision_made: bool = false
var chose_to_travel: bool = false
var has_ship: bool = true
const SHIP_TRAVEL_COST := 5
const COMMERCIAL_TRAVEL_COST_PER_CREW := 1

# Travel UI references (built in code)
var _travel_panel: PanelContainer
var _stay_button: Button
var _travel_button: Button
var _travel_event_container: VBoxContainer
var _travel_status_label: Label

# Five Parsecs upkeep constants (Core Rules p.76)
const BASE_CREW_UPKEEP_PER_MEMBER: int = 1  # 1 credit per crew member
const SHIP_MAINTENANCE_BASE_COST: int = 1   # 1 credit base maintenance

func _ready() -> void:
	name = "UpkeepPhaseComponent"
	super._ready()

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

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
	travel_decision_made = false
	chose_to_travel = false
	current_upkeep_data = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"total_cost": 0,
		"can_afford": false
	}
	_build_travel_section()
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
	## Calculate ship maintenance costs (Core Rules p.76)
	## Note: Core Rules has no damage multiplier on maintenance.
	## Ship damage is repaired by paying credits per hull point (separate from maintenance).
	var maintenance_cost = SHIP_MAINTENANCE_BASE_COST

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
	var deficit: int = upkeep_results.total_cost - upkeep_results.current_credits

	# QA-FIX: Show visible error dialog — previously only published an event bus
	# message that was never rendered, causing silent failure on "Pay Upkeep" click
	var msg := (
		"Cannot pay upkeep! Need %d credits but only have %d (short %d).\n"
		+ "Per Core Rules: crew may go into debt or members may leave."
	) % [upkeep_results.total_cost, upkeep_results.current_credits, deficit]
	_show_help_dialog("Insufficient Credits", msg)

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.UPKEEP_ERROR, {
			"error_type": "insufficient_funds",
			"required": upkeep_results.total_cost,
			"available": upkeep_results.current_credits,
			"deficit": deficit
		})

## Help System
func _on_help_button_pressed() -> void:
	## Show upkeep rules help dialog
	_show_help_dialog("Upkeep Phase", RulesHelpText.get_tooltip("upkeep_phase"))

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
		credits_display.add_theme_color_override("font_color", UIColors.COLOR_EMERALD if can_afford else UIColors.COLOR_RED)

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
			var color := UIColors.COLOR_EMERALD if upkeep_completed else (UIColors.COLOR_AMBER if current_upkeep_data.get("can_afford", true) else UIColors.COLOR_RED)
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

## ============================================================================
## TRAVEL SECTION (Core Rules p.69 — folded into Step 1)
## ============================================================================

func _build_travel_section() -> void:
	## Build the travel decision UI and insert above upkeep content
	if _travel_panel and is_instance_valid(_travel_panel):
		_travel_panel.queue_free()
		await get_tree().process_frame

	# --- Panel container with same styling as upkeep header ---
	_travel_panel = PanelContainer.new()
	_travel_panel.name = "TravelPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.067, 0.094, 0.153, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.216, 0.255, 0.318, 0.5)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_top = 20.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 20.0
	_travel_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Title
	var title := Label.new()
	title.text = "Travel Decision"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override(
		"font_color", Color(0.953, 0.957, 0.965, 1))
	vbox.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = "Choose whether to stay or travel to a new world (Core Rules p.69)."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override(
		"font_color", Color(0.624, 0.639, 0.686, 1))
	vbox.add_child(desc)

	# Current world
	var world_name := _get_current_world_name_for_travel()
	var world_label := Label.new()
	world_label.text = "Current Location: %s" % world_name
	world_label.add_theme_font_size_override("font_size", 16)
	world_label.add_theme_color_override(
		"font_color", Color(0.31, 0.765, 0.969, 1))
	vbox.add_child(world_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Stay button
	_stay_button = Button.new()
	_stay_button.text = "Stay in Current Location"
	_stay_button.custom_minimum_size = Vector2(220, 48)
	var stay_style := StyleBoxFlat.new()
	stay_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	stay_style.border_width_left = 1
	stay_style.border_width_top = 1
	stay_style.border_width_right = 1
	stay_style.border_width_bottom = 1
	stay_style.border_color = Color(0.216, 0.255, 0.318, 1)
	stay_style.set_corner_radius_all(8)
	stay_style.content_margin_left = 16.0
	stay_style.content_margin_top = 8.0
	stay_style.content_margin_right = 16.0
	stay_style.content_margin_bottom = 8.0
	_stay_button.add_theme_stylebox_override("normal", stay_style)
	_stay_button.add_theme_color_override(
		"font_color", Color(0.953, 0.957, 0.965, 1))
	_stay_button.pressed.connect(_on_stay_pressed)
	btn_row.add_child(_stay_button)

	# Travel button
	_travel_button = Button.new()
	has_ship = _check_has_ship_for_travel()
	var credits := GameStateManager.get_credits()
	var crew_size := _get_crew_size_for_travel()
	_update_travel_button_text(credits, crew_size)
	_travel_button.custom_minimum_size = Vector2(260, 48)
	var travel_style := StyleBoxFlat.new()
	travel_style.bg_color = Color(0.231, 0.51, 0.965, 1)
	travel_style.set_corner_radius_all(8)
	travel_style.content_margin_left = 16.0
	travel_style.content_margin_top = 8.0
	travel_style.content_margin_right = 16.0
	travel_style.content_margin_bottom = 8.0
	_travel_button.add_theme_stylebox_override("normal", travel_style)
	_travel_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_travel_button.pressed.connect(_on_travel_pressed)
	btn_row.add_child(_travel_button)

	vbox.add_child(btn_row)

	# Status label (shown after decision)
	_travel_status_label = Label.new()
	_travel_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_status_label.add_theme_font_size_override("font_size", 14)
	_travel_status_label.visible = false
	vbox.add_child(_travel_status_label)

	# Travel event container (populated after travel choice)
	_travel_event_container = VBoxContainer.new()
	_travel_event_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_travel_event_container)

	_travel_panel.add_child(vbox)

	# Insert as first child of UpkeepContainer (above HeaderPanel)
	if upkeep_container:
		upkeep_container.add_child(_travel_panel)
		upkeep_container.move_child(_travel_panel, 0)

	# If travel was already decided (e.g. restoring state), update UI
	if travel_decision_made:
		_update_travel_ui_after_decision()

func _update_travel_button_text(
		credits: int, crew_size: int) -> void:
	## Update travel button text/state based on affordability
	if not _travel_button:
		return
	if has_ship:
		if credits >= SHIP_TRAVEL_COST:
			_travel_button.text = (
				"Travel to New World (%d cr)" % SHIP_TRAVEL_COST)
			_travel_button.disabled = false
		else:
			_travel_button.text = (
				"Travel (Need %d cr)" % SHIP_TRAVEL_COST)
			_travel_button.disabled = true
	else:
		var cost := crew_size * COMMERCIAL_TRAVEL_COST_PER_CREW
		if credits >= cost:
			_travel_button.text = (
				"Commercial Passage (%d cr)" % cost)
			_travel_button.disabled = false
		else:
			_travel_button.text = (
				"Passage (Need %d cr)" % cost)
			_travel_button.disabled = true

func _on_stay_pressed() -> void:
	## Handle stay in current location
	travel_decision_made = true
	chose_to_travel = false
	_update_travel_ui_after_decision()
	_travel_status_label.text = "✓ Staying in current location"
	_travel_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_EMERALD)
	_travel_status_label.visible = true

func _on_travel_pressed() -> void:
	## Handle travel to new world — deduct cost and generate event
	var travel_cost: int
	if has_ship:
		travel_cost = SHIP_TRAVEL_COST
	else:
		travel_cost = (
			_get_crew_size_for_travel() * COMMERCIAL_TRAVEL_COST_PER_CREW)

	GameStateManager.modify_credits(-travel_cost)

	travel_decision_made = true
	chose_to_travel = true
	_update_travel_ui_after_decision()
	_travel_status_label.text = (
		"✓ Traveling to new world (-%d cr)" % travel_cost)
	_travel_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_AMBER)
	_travel_status_label.visible = true

	# Generate D100 travel event (Core Rules pp.70-71)
	_generate_travel_event()

	# Refresh upkeep display (credits changed)
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()

func _update_travel_ui_after_decision() -> void:
	## Disable travel buttons after a decision is made
	if _stay_button:
		_stay_button.disabled = true
	if _travel_button:
		_travel_button.disabled = true

func _generate_travel_event() -> void:
	## Generate travel event using Five Parsecs D100 table (pp.70-71)
	var dice_mgr := get_node_or_null("/root/DiceManager")
	var roll: int = 0
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		roll = dice_mgr.roll_dice("Travel Event", "D100")
	else:
		roll = randi_range(1, 100)

	var event := _process_travel_event_roll(roll)
	_display_travel_event(event, roll)

func _process_travel_event_roll(roll: int) -> Dictionary:
	## Process D100 travel event roll (Core Rules pp.70-71)
	if roll <= 7:
		return {"type": "danger", "title": "Asteroids",
			"desc": "Rocky debris everywhere! Roll to navigate safely or take Hull damage."}
	elif roll <= 12:
		return {"type": "setback", "title": "Navigation Trouble",
			"desc": "Is this place even on the star maps? Lose 1 story point."}
	elif roll <= 17:
		return {"type": "hostile", "title": "Raided",
			"desc": "Pirates have spotted your vessel! Prepare for potential combat."}
	elif roll <= 25:
		return {"type": "opportunity", "title": "Deep Space Wreckage",
			"desc": "Found an old wreck drifting through space. Roll twice on the Gear Table."}
	elif roll <= 29:
		return {"type": "setback", "title": "Drive Trouble",
			"desc": "It's not supposed to make that sound. May be grounded next turn."}
	elif roll <= 38:
		return {"type": "beneficial", "title": "Down-time",
			"desc": "Select a crew member to earn +1 XP. Repair 1 damaged item for free."}
	elif roll <= 44:
		return {"type": "choice", "title": "Distress Call",
			"desc": "'This is Licensed Trader Cyberwolf.' Do you respond?"}
	elif roll <= 50:
		return {"type": "neutral", "title": "Patrol Ship",
			"desc": "A Unity patrol vessel hails you. They may confiscate contraband."}
	elif roll <= 53:
		return {"type": "rare", "title": "Cosmic Phenomenon",
			"desc": "A crew member sees something strange... and gains +1 Luck!"}
	elif roll <= 60:
		return {"type": "choice", "title": "Escape Pod",
			"desc": "You find an escape pod drifting through space. Rescue them?"}
	elif roll <= 70:
		return {"type": "beneficial", "title": "Uneventful Trip",
			"desc": "A lot of time playing cards and cleaning guns. You can Repair one damaged item."}
	elif roll <= 80:
		return {"type": "beneficial", "title": "Cargo Run",
			"desc": "A merchant vessel offers work hauling cargo. Earn 1D6 credits."}
	elif roll <= 90:
		return {"type": "neutral", "title": "Rumor Mill",
			"desc": "Crew picks up spacer gossip. Add a Quest Rumor."}
	else:
		return {"type": "beneficial", "title": "Smooth Sailing",
			"desc": "An easy trip with favorable conditions. All crew are well-rested."}

func _display_travel_event(
		event: Dictionary, roll: int) -> void:
	## Display travel event result in the event container
	if not _travel_event_container:
		return

	# Clear previous events
	for child in _travel_event_container.get_children():
		child.queue_free()

	# Event card
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.122, 0.137, 0.216, 0.9)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	# Color border by event type
	match event.get("type", "neutral"):
		"danger", "hostile":
			card_style.border_color = Color(0.863, 0.149, 0.149, 1)
		"setback":
			card_style.border_color = Color(0.851, 0.467, 0.024, 1)
		"beneficial":
			card_style.border_color = Color(0.063, 0.725, 0.506, 1)
		"opportunity", "rare":
			card_style.border_color = Color(0.31, 0.765, 0.969, 1)
		_:
			card_style.border_color = Color(0.216, 0.255, 0.318, 1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 16.0
	card_style.content_margin_top = 12.0
	card_style.content_margin_right = 16.0
	card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)

	var roll_label := Label.new()
	roll_label.text = "Travel Event Roll: %d" % roll
	roll_label.add_theme_font_size_override("font_size", 12)
	roll_label.add_theme_color_override(
		"font_color", Color(0.42, 0.451, 0.502, 1))
	card_vbox.add_child(roll_label)

	var title_label := Label.new()
	title_label.text = event.get("title", "Unknown Event")
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override(
		"font_color", Color(0.953, 0.957, 0.965, 1))
	card_vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = event.get("desc", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override(
		"font_color", Color(0.624, 0.639, 0.686, 1))
	card_vbox.add_child(desc_label)

	card.add_child(card_vbox)
	_travel_event_container.add_child(card)

func _get_current_world_name_for_travel() -> String:
	## Get current world name for travel display
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var wd = gs.current_campaign.get("world_data")
		if wd is Dictionary:
			return wd.get("name", "Fringe World")
	return "Fringe World"

func _check_has_ship_for_travel() -> bool:
	## Check if crew has a ship for travel cost calculation
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var sd = gs.current_campaign.get("ship_data")
		return sd != null and sd is Dictionary
	return true

func _get_crew_size_for_travel() -> int:
	## Get crew size for commercial travel cost
	if crew_data.size() > 0:
		return crew_data.size()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_crew_size"):
		return gsm.get_crew_size()
	return 4

## Public API: Travel completion check
func is_travel_completed() -> bool:
	## Check if travel decision has been made
	return travel_decision_made

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
	travel_decision_made = false
	chose_to_travel = false
	current_upkeep_data.clear()
	ship_data.clear()
	crew_data.clear()
	_build_travel_section()
	_update_ui_display()
