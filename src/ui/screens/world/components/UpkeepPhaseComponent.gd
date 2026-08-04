extends WorldPhaseComponent
class_name UpkeepPhaseComponent

## Upkeep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs upkeep rules only
## Implements Core Rules p.76 - Ship maintenance and crew upkeep calculations

const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")
const WorldTraitEffectsClass = preload("res://src/core/world/WorldTraitEffects.gd")
const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const RulesHelpText = preload("res://src/data/rules_help_text.gd")
const UpkeepSystemClass = preload("res://src/core/systems/UpkeepSystem.gd")
const NewWorldArrivalClass = preload("res://src/core/campaign/NewWorldArrival.gd")
const TravelEventResolverClass = preload("res://src/core/world/TravelEventResolver.gd")
const RedZoneSystem = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystem = preload("res://src/core/mission/BlackZoneSystem.gd")
const WorldGeneratorClass = preload("res://src/core/campaign/WorldGenerator.gd")
const PsionicSystemRef = preload("res://src/core/systems/PsionicSystem.gd")

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
var costs_calculated: bool = false  # Gate: Pay requires Calculate first

# Travel state (folded into Step 1 — Core Rules p.69)
var travel_decision_made: bool = false
var chose_to_travel: bool = false
## Set when the Core Rules p.69 flee roll FAILS — WorldPhaseController reads it
## via get_forced_invasion_mission() and makes it the turn's mission, overriding
## any accepted job ("you MUST fight an Invasion Battle").
var _forced_invasion_mission: Dictionary = {}

## Travel-event resolution state (Core Rules pp.70-72). Choices are keyed by
## event title so a re-entry after a button press resolves with the answer.
var _travel_choices: Dictionary = {}
var _travel_event_depth: int = 0
## p.70 Raided: set when the intimidation roll fails. Consumed like the invasion
## mission, but it is an "out of sequence" encounter and does not replace the
## turn's Battle stage.
var _forced_travel_battle: Dictionary = {}
## p.60 Emergency Take-off — only present while the hull is damaged.
var _emergency_button: Button = null
## Starship fuel (p.79) spent against the most recent trip, for the status line.
var _fuel_offset_last_trip: int = 0
var has_ship: bool = true
const SHIP_TRAVEL_COST := 5
const COMMERCIAL_TRAVEL_COST_PER_CREW := 1
## Core Rules p.62, verbatim: "You can have up to 4 crew members Suspended at
## any one time."
const MAX_SUSPENDED_CREW := 4

# Travel UI references (built in code)
var _travel_panel: PanelContainer
var _stay_button: Button
var _travel_button: Button
var _travel_event_container: VBoxContainer
var _travel_status_label: Label

# Zone selection state (Core Rules Appendix III pp.148-151)
var selected_zone: int = 0  # 0=normal, 1=red_zone, 2=black_zone
var _red_zone_button: Button
var _black_zone_button: Button
var _zone_info_label: Label
var _license_dialog: ConfirmationDialog

# Five Parsecs upkeep constants (Core Rules p.76)
# Upkeep = 1 credit for 4-6 crew, +1 per crew member past 6
const CREW_UPKEEP_THRESHOLD: int = 4   # Upkeep kicks in at 4+ crew
const CREW_UPKEEP_CAP: int = 6         # Base 1 credit covers up to 6 crew
const SHIP_MAINTENANCE_BASE_COST: int = 0   # No mandatory ship maintenance (Core Rules p.76)

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
	costs_calculated = false
	travel_decision_made = false
	chose_to_travel = false
	selected_zone = 0
	current_upkeep_data = {
		"crew_upkeep": 0,
		"ship_maintenance": 0,
		"total_cost": 0,
		"can_afford": false
	}
	_build_travel_section()
	_update_ui_display()
	_update_gating_state()

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

	# Black Zone: upkeep waived (Core Rules Appendix III p.150)
	if selected_zone == 2:
		results.current_credits = GameStateManager.get_credits()
		results.can_afford = true
		results["zone_waiver"] = (
			"Black Zone: Upkeep waived, ship loan frozen")
		return results

	# Get current credits from campaign data
	results.current_credits = GameStateManager.get_credits()
	
	# Calculate crew upkeep with world trait modifiers (Core Rules p.76, p.87-89)
	# Exclude unavailable/departed crew — Business Elsewhere has no_upkeep (Core Rules p.128)
	# Exclude Sick Bay crew — "You do not have to count crew in Sick Bay" (Core Rules p.76)
	var upkeep_exempt_count: int = 0
	for member in crew_data:
		var member_status: String = str(member.get("status", "ACTIVE"))
		if member_status in ["DEPARTED", "DEAD", "RETIRED", "MISSING"]:
			upkeep_exempt_count += 1
			continue
		# Sick Bay exclusion (Core Rules p.76)
		var in_sick_bay: bool = member.get("in_sick_bay", false)
		if not in_sick_bay:
			in_sick_bay = member.get("recovery_turns", 0) > 0
		if in_sick_bay:
			upkeep_exempt_count += 1
			continue
		for eff in member.get("status_effects", []):
			if eff.get("no_upkeep", false) \
					or str(eff.get("type", "")) in ["unavailable", "departed"]:
				upkeep_exempt_count += 1
				break
	var effective_crew_size: int = crew_data.size() - upkeep_exempt_count
	var component_effects: Array = []

	# Suspension Pod: exclude suspended crew (Core Rules p.62)
	var gs: Variant = get_node_or_null("/root/GameState")
	if gs and ShipComponentQuery.has_component("suspension_pod"):
		var campaign: Variant = gs.get_current_campaign() if gs.has_method(
			"get_current_campaign") else null
		if campaign and "progress_data" in campaign:
			var suspended: Array = campaign.progress_data.get(
				"suspended_crew", [])
			if suspended.size() > 0:
				var before_sus: int = effective_crew_size
				effective_crew_size = maxi(
					0, effective_crew_size - suspended.size())
				component_effects.append({
					"component": "suspension_pod",
					"description": "%d crew suspended (counted %d instead of %d)" % [
						suspended.size(), effective_crew_size, before_sus],
				})

	# Living Quarters: count crew as 2 fewer (Core Rules p.62)
	if ShipComponentQuery.has_component("living_quarters"):
		var before_lq: int = effective_crew_size
		effective_crew_size = maxi(0, effective_crew_size - 2)
		component_effects.append({
			"component": "living_quarters",
			"description": "Crew counted as %d instead of %d for upkeep" % [
				effective_crew_size, before_lq],
		})

	# "High cost — Your crew size counts as being 2 higher for the purpose of
	# Upkeep costs" (Core Rules p.75 World Trait; the old citation "p.87-89" here
	# was wrong). Routed through WorldTraitEffects so the +2 lives in
	# data/world_traits.json with the other 30 campaign-side trait values rather
	# than as a second hardcoded copy.
	var world_traits: Array = _get_current_world_traits()
	effective_crew_size = WorldTraitEffectsClass.upkeep_crew_size(
		effective_crew_size, world_traits)

	# Core Rules p.76: 1 credit for 4-6 crew, +1 per crew member past 6.
	#
	# Compendium p.32 "Money is Tight" REPLACES that scale outright: "Upkeep
	# costs change to 0 credits for a single crew, 1 credit for a crew of 2-4
	# figures, and +1 credit for each crew member past 4."
	if CompendiumTogglesRef.is_toggle_active("slaves_to_stargrind_money"):
		if effective_crew_size <= 1:
			results.crew_upkeep = 0
		else:
			results.crew_upkeep = 1 + max(0, effective_crew_size - 4)
		results["money_is_tight"] = true
	elif effective_crew_size >= CREW_UPKEEP_THRESHOLD:
		results.crew_upkeep = 1 + max(0, effective_crew_size - CREW_UPKEEP_CAP)
	else:
		results.crew_upkeep = 0

	results["component_effects"] = component_effects
	
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

		# Log ship component effects to CampaignJournal
		var effects: Array = upkeep_results.get(
			"component_effects", [])
		if effects.size() > 0:
			var journal: Node = get_node_or_null(
				"/root/CampaignJournal")
			if journal and journal.has_method("create_entry"):
				for effect in effects:
					var comp_name: String = str(
						effect.get("component", "")
					).capitalize().replace("_", " ")
					journal.create_entry({
						"type": "upkeep",
						"title": "Ship Component: %s" % comp_name,
						"description": effect.get("description", ""),
						"tags": [
							"ship_component",
							effect.get("component", ""),
							"upkeep"],
						"auto_generated": true,
						"mood": "neutral",
					})

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
	## Handle case where crew cannot afford upkeep (Core Rules p.76)
	## First offer to sell equipment, then lock out 1 crew per credit short.
	var deficit: int = upkeep_results.total_cost - upkeep_results.current_credits
	# Store for the sell dialog callback
	_pending_upkeep_results = upkeep_results
	_pending_deficit = deficit

	# Check if stash has items to sell
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	var stash_items: Array = []
	if eq_mgr and eq_mgr.has_method("get_ship_stash"):
		stash_items = eq_mgr.get_ship_stash()

	if stash_items.size() > 0:
		# Offer to sell equipment first (Core Rules p.76)
		_show_sell_for_upkeep_dialog(deficit, stash_items)
	else:
		# No items to sell — go straight to lockout
		_finalize_upkeep_shortfall(upkeep_results, deficit)

var _pending_upkeep_results: Dictionary = {}
var _pending_deficit: int = 0
var _sell_dialog: Window
var _sell_deficit_label: Label
var _sell_item_container: VBoxContainer

func _show_sell_for_upkeep_dialog(
	deficit: int, stash_items: Array
) -> void:
	## Show dialog allowing player to sell stash items to cover upkeep
	## Core Rules p.76: "you may sell equipment to pay Upkeep.
	## For each item sold, you gain 1 credit worth of Upkeep."
	if _sell_dialog:
		_sell_dialog.queue_free()

	_sell_dialog = Window.new()
	_sell_dialog.title = "Sell Equipment for Upkeep"
	_sell_dialog.size = Vector2i(450, 400)
	_sell_dialog.exclusive = true
	_sell_dialog.close_requested.connect(_on_sell_dialog_done)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_sell_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = (
		"Short %d credit(s) for upkeep.\n"
		+ "Sell items from stash (1 credit each):"
	) % deficit
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	# Deficit counter
	_sell_deficit_label = Label.new()
	_sell_deficit_label.text = "Still need: %d credit(s)" % deficit
	_sell_deficit_label.add_theme_color_override(
		"font_color", UIColors.COLOR_AMBER)
	vbox.add_child(_sell_deficit_label)

	# Scrollable item list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(scroll)

	_sell_item_container = VBoxContainer.new()
	_sell_item_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_sell_item_container)

	for item in stash_items:
		var item_name: String = ""
		if item is Dictionary:
			item_name = item.get("name", item.get("item_name", "Unknown"))
		elif item is Resource and "name" in item:
			item_name = str(item.name)
		else:
			item_name = str(item)
		var item_id: String = ""
		if item is Dictionary:
			item_id = item.get("id", item.get("equipment_id", ""))
		elif item is Resource and "id" in item:
			item_id = str(item.id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_sell_item_container.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var sell_btn := Button.new()
		sell_btn.text = "Sell (1 cr)"
		sell_btn.custom_minimum_size = Vector2(90, 36)
		sell_btn.pressed.connect(
			_on_sell_item_pressed.bind(row, item_id, item_name))
		row.add_child(sell_btn)

	# Done button
	var done_btn := Button.new()
	done_btn.text = "Done Selling"
	done_btn.custom_minimum_size = Vector2(0, 44)
	done_btn.pressed.connect(_on_sell_dialog_done)
	vbox.add_child(done_btn)

	add_child(_sell_dialog)
	_sell_dialog.popup_centered()

func _on_sell_item_pressed(
	row: HBoxContainer, item_id: String, item_name: String
) -> void:
	## Sell one item, reduce deficit
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	if eq_mgr and eq_mgr.has_method("sell_equipment"):
		var sold: int = eq_mgr.sell_equipment(item_id)
		if sold > 0:
			_pending_deficit -= 1
			row.queue_free()
			if _pending_deficit <= 0:
				_sell_deficit_label.text = "Upkeep fully covered!"
				_sell_deficit_label.add_theme_color_override(
					"font_color", UIColors.COLOR_EMERALD)
			else:
				_sell_deficit_label.text = (
					"Still need: %d credit(s)" % _pending_deficit)

func _on_sell_dialog_done() -> void:
	## Close sell dialog and apply remaining deficit as lockout
	if _sell_dialog:
		_sell_dialog.queue_free()
		_sell_dialog = null
	var remaining_deficit: int = maxi(0, _pending_deficit)
	_finalize_upkeep_shortfall(
		_pending_upkeep_results, remaining_deficit)

func _finalize_upkeep_shortfall(
	upkeep_results: Dictionary, deficit: int
) -> void:
	## Apply partial payment and crew lockout for remaining deficit
	# Pay what we can afford
	var available: int = GameStateManager.get_credits()
	var to_pay: int = mini(available, upkeep_results.total_cost)
	if to_pay > 0:
		GameStateManager.remove_credits(to_pay)

	# Apply lockout if still short
	var locked_names: Array = []
	if deficit > 0:
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign:
			var upkeep_sys = UpkeepSystemClass.new()
			var consequences: Dictionary = (
				upkeep_sys.handle_upkeep_failure(
					gs.current_campaign, deficit))
			locked_names = consequences.get(
				"locked_out_members", [])
			# Also mark in crew_data (Dictionary path)
			for member in crew_data:
				var mname: String = member.get(
					"character_name", member.get("name", ""))
				if mname in locked_names:
					member["locked_out_this_turn"] = true

	# Show consequences dialog
	if deficit > 0 and locked_names.size() > 0:
		var msg: String = "Short %d credit(s) after selling.\n\n" % deficit
		msg += "The following crew refuse to work this turn:\n"
		for n in locked_names:
			msg += "  • %s\n" % n
		msg += "\n(Core Rules p.76)"
		_show_help_dialog("Upkeep Shortfall", msg)
	elif deficit <= 0:
		_show_help_dialog("Upkeep Covered",
			"Equipment sales covered the upkeep shortfall!")

	# Mark upkeep as completed (partial payment — game continues)
	upkeep_completed = true
	current_upkeep_data = upkeep_results

	if event_bus:
		event_bus.publish_event(
			CampaignTurnEventBus.TurnEvent.UPKEEP_ERROR, {
				"error_type": "partial_payment",
				"required": upkeep_results.total_cost,
				"deficit": deficit,
				"locked_out": locked_names
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
	_update_gating_state()

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
	costs_calculated = true
	_update_ui_display()
	_update_gating_state()

	# Don't automatically apply - let player confirm

## UI Updates
func _update_ui_display() -> void:
	## Update UI display with current upkeep data
	var current_credits: int = GameStateManager.get_credits()

	if credits_display:
		var credit_text := "Available Credits: %d" % current_credits
		if upkeep_completed:
			credit_text += (
				" (Paid: -%d)"
				% current_upkeep_data.get("total_cost", 0))
		credits_display.text = credit_text
		# Color based on affordability
		var can_afford: bool = current_upkeep_data.get(
			"can_afford", true)
		var credit_color: Color = (
			UIColors.COLOR_EMERALD if can_afford
			else UIColors.COLOR_RED)
		credits_display.add_theme_color_override(
			"font_color", credit_color)

	# Black Zone waiver display
	var zone_waiver: String = current_upkeep_data.get(
		"zone_waiver", "")
	if not zone_waiver.is_empty():
		if crew_upkeep_label:
			crew_upkeep_label.text = "WAIVED"
			crew_upkeep_label.add_theme_color_override(
				"font_color", Color(0.4, 0.1, 0.6, 1))
		if maintenance_cost_label:
			maintenance_cost_label.text = "WAIVED"
			maintenance_cost_label.add_theme_color_override(
				"font_color", Color(0.4, 0.1, 0.6, 1))
		if total_cost_label:
			total_cost_label.text = zone_waiver
			total_cost_label.add_theme_color_override(
				"font_color", Color(0.4, 0.1, 0.6, 1))
		return

	if not current_upkeep_data.is_empty():
		if crew_upkeep_label:
			crew_upkeep_label.text = (
				"%d credits"
				% current_upkeep_data.get("crew_upkeep", 0))

		if maintenance_cost_label:
			maintenance_cost_label.text = (
				"%d credits"
				% current_upkeep_data.get("ship_maintenance", 0))

		if total_cost_label:
			var total_cost: int = current_upkeep_data.get(
				"total_cost", 0)
			var status := " ✓" if upkeep_completed else ""
			total_cost_label.text = "%d credits%s" % [total_cost, status]
			# Color: amber normally, green if paid, red if can't afford
			var color := UIColors.COLOR_EMERALD if upkeep_completed else (UIColors.COLOR_AMBER if current_upkeep_data.get("can_afford", true) else UIColors.COLOR_RED)
			total_cost_label.add_theme_color_override("font_color", color)

## Sequential Gating (Core Rules: Travel → Calculate → Pay)
func _update_gating_state() -> void:
	## Enforce sequential flow: travel decision → calculate costs → pay upkeep
	# Gate 1: Calculate Costs locked until travel decided
	if manual_calculate_button:
		manual_calculate_button.disabled = not travel_decision_made or upkeep_completed
	# Gate 2: Pay Upkeep locked until costs calculated
	if auto_calculate_button:
		auto_calculate_button.disabled = not travel_decision_made or not costs_calculated or upkeep_completed
	# Visual: dim upkeep section when travel not yet decided
	var cost_panel = get_node_or_null("UpkeepContainer/CostBreakdownPanel")
	if cost_panel:
		cost_panel.modulate.a = 1.0 if travel_decision_made else 0.4
	var btn_container = get_node_or_null("UpkeepContainer/ButtonContainer")
	if btn_container:
		btn_container.modulate.a = 1.0 if travel_decision_made else 0.4
	# Notify WorldPhaseController to re-evaluate "Next Step". This hook runs after
	# EVERY upkeep state change (stay/travel/calculate/pay), so it's the single
	# point that unblocks the turn once travel is decided AND upkeep is paid.
	# (B1 soft-lock fix — the upkeep step had no completion notification, unlike
	# crew-task/job/mission-prep which notify via the event bus.)
	step_state_changed.emit()

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
	style.set_corner_radius_all(4)
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
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override(
		"font_color", Color(0.953, 0.957, 0.965, 1))
	vbox.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = "Choose whether to stay or travel to a new world (Core Rules p.69)."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	desc.add_theme_color_override(
		"font_color", Color(0.624, 0.639, 0.686, 1))
	vbox.add_child(desc)

	# Current world
	var world_name := _get_current_world_name_for_travel()
	var world_label := Label.new()
	world_label.text = "Current Location: %s" % world_name
	world_label.add_theme_font_size_override("font_size", _scaled_font(16))
	world_label.add_theme_color_override(
		"font_color", Color(0.31, 0.765, 0.969, 1))
	vbox.add_child(world_label)

	# View Galaxy Map — the map is a JOURNEY RECORD (Core Rules p.69 travel is
	# roll-based, not map-navigated), so this opens the read-only Galaxy Log.
	var map_btn := Button.new()
	map_btn.text = "🗺  View Galaxy Map"
	# 40 was under the 48dp touch floor (40 design px = 41.8dp). `flat` removes the
	# themed stylebox, so this button gets no padding from the theme and its height
	# is whatever is set here — TOUCH_TARGET_MIN, like every other tappable control.
	map_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	map_btn.flat = true
	map_btn.add_theme_color_override(
		"font_color", Color(0.31, 0.765, 0.969, 1))
	map_btn.add_theme_font_size_override("font_size", _scaled_font(14))
	map_btn.pressed.connect(_on_view_galaxy_map_pressed)
	vbox.add_child(map_btn)

	# Hull repair (Core Rules p.59). Shown only while the ship is damaged — it is
	# also the release valve for the travel prohibition on the same page.
	_build_hull_repair_prompt(vbox)

	# Crew management: Suspension Pod (p.62) and Dismiss Crew (p.76). Both are
	# Upkeep-step actions and neither had any way in — the Suspension Pod was
	# purchasable and inert, and show_dismiss_crew_dialog() had ZERO callers.
	_build_crew_management_entry(vbox)

	# World Step 1 payments the book puts here and the app never built
	# (Core Rules p.76).
	_build_ship_debt_entry(vbox)
	_build_medical_care_entry(vbox)

	# Mission-required travel prompt (Core Rules p.119 — a Quest step on another
	# world). Encourages (never forces) travel; "Quests will wait for you".
	_build_quest_travel_prompt(vbox)

	# Invasion warning (Core Rules pp.88-90)
	var gsm_inv = get_node_or_null("/root/GameStateManager")
	if gsm_inv and gsm_inv.has_method("has_pending_invasion"):
		if gsm_inv.has_pending_invasion():
			var inv_banner := PanelContainer.new()
			var inv_style := StyleBoxFlat.new()
			inv_style.bg_color = Color(0.55, 0.1, 0.1, 0.8)
			inv_style.border_color = UIColors.COLOR_RED
			inv_style.set_border_width_all(2)
			inv_style.set_corner_radius_all(4)
			inv_style.content_margin_left = 12
			inv_style.content_margin_right = 12
			inv_style.content_margin_top = 8
			inv_style.content_margin_bottom = 8
			inv_banner.add_theme_stylebox_override(
				"panel", inv_style)
			var inv_lbl := Label.new()
			inv_lbl.text = (
				"INVASION IMMINENT — You must flee"
				+ " (2D6, 8+) or fight when departing")
			inv_lbl.autowrap_mode = (
				TextServer.AUTOWRAP_WORD_SMART)
			inv_lbl.add_theme_color_override(
				"font_color", Color("#FF6B6B"))
			inv_lbl.add_theme_font_size_override(
				"font_size", _scaled_font(15))
			inv_banner.add_child(inv_lbl)
			vbox.add_child(inv_banner)

	# Button row — a BoxContainer that goes VERTICAL in portrait via
	# _register_responsive_box(), NOT an HFlowContainer, and its buttons EXPAND.
	#
	# The expand flag is not cosmetic: a horizontal BoxContainer hands each child only
	# its MINIMUM width, which for an autowrapping button is its longest word — so
	# without it the same two buttons rendered as thin vertical slabs in landscape even
	# after the container was fixed. Expanding, they share the row and wrap inside it.
	#
	# These buttons autowrap (their labels are long), and autowrap inside an HFlow is a
	# trap: HFlow asks an autowrapping child for its height at its NARROWEST width — its
	# longest word — and gets back the line count for the whole string, so each button
	# rendered as a ~40px-wide, 300px-tall slab with no readable text. In a vertical
	# BoxContainer each button gets the full column width and wraps to at most two lines,
	# which is what a full-width mobile button should look like. Landscape and desktop
	# keep them side by side, sized to their text.
	var btn_row := BoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_register_responsive_box(btn_row)

	# Stay button (may be disabled below — see _apply_story_forced_travel)
	_stay_button = Button.new()
	_stay_button.text = "Stay in Current Location"
	_stay_button.custom_minimum_size = Vector2(0, 48)
	_stay_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stay_style := StyleBoxFlat.new()
	stay_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	stay_style.border_width_left = 1
	stay_style.border_width_top = 1
	stay_style.border_width_right = 1
	stay_style.border_width_bottom = 1
	stay_style.border_color = Color(0.216, 0.255, 0.318, 1)
	stay_style.set_corner_radius_all(4)
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
	_travel_button.custom_minimum_size = Vector2(0, 48)
	_travel_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_travel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var travel_style := StyleBoxFlat.new()
	travel_style.bg_color = Color(0.231, 0.51, 0.965, 1)
	travel_style.set_corner_radius_all(4)
	travel_style.content_margin_left = 16.0
	travel_style.content_margin_top = 8.0
	travel_style.content_margin_right = 16.0
	travel_style.content_margin_bottom = 8.0
	_travel_button.add_theme_stylebox_override("normal", travel_style)
	_travel_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_travel_button.pressed.connect(_on_travel_pressed)
	btn_row.add_child(_travel_button)

	vbox.add_child(btn_row)

	# --- Zone Selection Row (Core Rules Appendix III pp.148-151) ---
	_build_zone_buttons(vbox)

	# --- Colony World Buttons (Compendium pp.15, 17) ---
	_build_colony_world_buttons(vbox)

	# Zone info label (eligibility status)
	_zone_info_label = Label.new()
	_zone_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_info_label.add_theme_font_size_override(
		"font_size", _scaled_font(12))
	_zone_info_label.add_theme_color_override(
		"font_color", Color(0.42, 0.451, 0.502, 1))
	vbox.add_child(_zone_info_label)
	_update_zone_info_label()

	# Status label (shown after decision)
	_travel_status_label = Label.new()
	_travel_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_status_label.add_theme_font_size_override("font_size", _scaled_font(14))
	_travel_status_label.visible = false
	vbox.add_child(_travel_status_label)

	# Story Event forced travel (Core Rules Appendix V). Event 5 p.157: "You will
	# have to Travel immediately." Event 7 p.159: "you must Travel, following the
	# normal rules." Both were parsed into campaign_turn_mods, printed by
	# StoryPhasePanel, and enforced nowhere — so the player could simply Stay on
	# a turn the book gives them no choice about. Called HERE, after
	# _travel_status_label exists, so the explanation can actually be shown.
	_apply_story_forced_travel()

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

	# Core Rules p.59, verbatim: "If a ship has Hull Point damage, it cannot
	# safely leave for another planet, prohibiting you from traveling during the
	# campaign turn. Even trivial drive damage can be catastrophic."
	#
	# Not a soft-lock: the same panel offers paid repair right below (p.59
	# "1 credit pays off 1 Hull Point"), and the free 1-point-per-turn repair
	# runs at rollover, so a damaged crew always has a way forward.
	# The book does NOT forbid it outright — p.60 Emergency Take-off: "If you
	# insist on traveling while your ship is damaged, your ship suffers 3D6 Hull
	# Points of damage as the drive vents super-heated plasma throughout the
	# vessel." Disabling the button removed that choice entirely, and
	# get_emergency_takeoff_damage() was called only from the dead TravelPhase.gd.
	# The normal Travel button stays disabled; the risk is opt-in and separate.
	if has_ship:
		var damage: int = _hull_damage()
		if damage > 0:
			_travel_button.text = "Cannot Travel — Hull Damaged (%d)" % damage
			_travel_button.disabled = true
			_ensure_emergency_takeoff_button()
			return
		_remove_emergency_takeoff_button()

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

func _apply_story_forced_travel() -> void:
	## Disable "Stay" when the current Story Event compels travel.
	## Core Rules Appendix V — Event 5 p.157 "You will have to Travel
	## immediately"; Event 7 p.159 "you must Travel, following the normal rules".
	if _stay_button == null:
		return
	var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if cpm == null or not cpm.has_method("get_story_turn_mods"):
		return
	var mods: Dictionary = cpm.get_story_turn_mods()
	if mods.is_empty():
		return
	if not (bool(mods.get("must_travel_immediately", false))
			or bool(mods.get("must_travel", false))):
		return

	_stay_button.disabled = true
	_stay_button.tooltip_text = (
		"This Story Event requires you to travel (Core Rules Appendix V).")
	if _travel_status_label:
		_travel_status_label.visible = true
		_travel_status_label.text = \
			"Story Event: you must travel this campaign turn."

func _on_stay_pressed() -> void:
	## Handle stay in current location
	selected_zone = 0
	travel_decision_made = true
	chose_to_travel = false
	_update_travel_ui_after_decision()
	_travel_status_label.text = "✓ Staying in current location"
	_travel_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_EMERALD)
	_travel_status_label.visible = true
	_update_gating_state()

func _ensure_emergency_takeoff_button() -> void:
	## Core Rules p.60. Offered only while the hull is damaged, and destructive
	## enough that it is styled as a danger action and never the default.
	if _emergency_button and is_instance_valid(_emergency_button):
		_emergency_button.visible = true
		return
	if _travel_button == null or _travel_button.get_parent() == null:
		return
	_emergency_button = Button.new()
	_emergency_button.text = "Emergency Take-off (3D6 Hull damage)"
	_emergency_button.accessibility_name = (
		"Take off anyway, suffering 3D6 Hull Point damage")
	_emergency_button.tooltip_text = (
		"Core Rules p.60: \"If you insist on traveling while your ship is"
		+ " damaged, your ship suffers 3D6 Hull Points of damage as the drive"
		+ " vents super-heated plasma throughout the vessel.\"")
	_emergency_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_emergency_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emergency_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_emergency_button.add_theme_color_override("font_color", UIColors.COLOR_RED)
	_emergency_button.pressed.connect(_on_emergency_takeoff_pressed)
	_travel_button.get_parent().add_child(_emergency_button)


func _remove_emergency_takeoff_button() -> void:
	if _emergency_button and is_instance_valid(_emergency_button):
		_emergency_button.queue_free()
	_emergency_button = null


func _on_emergency_takeoff_pressed() -> void:
	## p.60: the damage is taken FIRST, so a hull that cannot survive the vent is
	## wrecked in transit — which is exactly the "being without a ship" outcome
	## (p.59) rather than the grounded scrap payout.
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null:
		return
	var damage: int = 3 * 6
	if gsm.has_method("get_emergency_takeoff_damage"):
		damage = int(gsm.get_emergency_takeoff_damage())
	var dealt: int = damage
	if gsm.has_method("apply_ship_damage"):
		dealt = int(gsm.apply_ship_damage(damage, true))

	_journal_invasion(
		"Emergency take-off",
		"The drive vented plasma through the vessel on lift-off: %d Hull Points"
		% dealt + " of damage (Core Rules p.60).")
	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_warning"):
		notif.show_warning("Emergency take-off — %d Hull Point damage." % dealt)

	# The ship may not have survived the vent; if it did not, travel is over.
	var campaign: Resource = _get_campaign_resource()
	if campaign != null and "has_ship" in campaign and not campaign.has_ship:
		_remove_emergency_takeoff_button()
		_refresh_after_upkeep_payment()
		return

	_remove_emergency_takeoff_button()
	_on_travel_pressed()


func _on_travel_pressed() -> void:
	## Handle travel to new world (normal zone) — deduct cost and generate event
	selected_zone = 0
	_fuel_offset_last_trip = 0

	# Flee Invasion (Core Rules p.69) — resolved BEFORE anything is paid for or
	# generated, because a failed roll means the crew does not leave at all.
	if _invasion_pending() and not _attempt_invasion_escape():
		return

	# "Bureaucratic mess — When attempting to leave, you must roll 2D6. On a 2-4,
	# you are delayed and cannot leave this campaign turn without a bribe equal
	# to the roll in credits. You may try again next campaign turn."
	# (Core Rules p.73 World Trait.) The trait was flavour text: departure was
	# never checked. The bribe is offered rather than forced — the book makes it
	# the player's choice to pay or to wait.
	var _departure_traits: Array = _get_current_world_traits()
	if WorldTraitEffectsClass.departure_check_required(_departure_traits):
		var bureaucracy_roll: int = randi_range(1, 6) + randi_range(1, 6)
		if WorldTraitEffectsClass.departure_is_blocked(
				bureaucracy_roll, _departure_traits):
			var bribe: int = bureaucracy_roll
			if GameStateManager.get_credits() >= bribe:
				GameStateManager.modify_credits(-bribe)
				_travel_status_label.text = (
					"Bureaucratic mess: rolled %d — delayed. Paid a %d-credit bribe "
					% [bureaucracy_roll, bribe] + "to leave anyway (p.73).")
			else:
				_travel_status_label.text = (
					"Bureaucratic mess: rolled %d — delayed and cannot afford the "
					% bureaucracy_roll
					+ "%d-credit bribe. Try again next campaign turn (p.73)." % bribe)
				_travel_status_label.add_theme_color_override(
					"font_color", UIColors.COLOR_AMBER)
				return

	var travel_cost: int
	if has_ship:
		travel_cost = SHIP_TRAVEL_COST
	else:
		travel_cost = (
			_get_crew_size_for_travel() * COMMERCIAL_TRAVEL_COST_PER_CREW)

	# Starship fuel bought by a crew task offsets the cost (Core Rules p.79:
	# "credits worth of starship fuel, which can be used to offset travel
	# costs"). CrewTaskComponent has always banked these into
	# progress_data["fuel_credits"] and the only consumer lived in TravelPhase,
	# a file nothing instantiates — so the fuel was unspendable.
	# World Traits that change what leaving costs (Core Rules pp.74-75):
	#   "Fuel refinery — Traveling from this world costs only 3 credits."
	#   "Fuel shortage — The cost to travel from this world is raised by 1D3
	#    credits."
	# Both were flavour text: the world you picked to launch from made no
	# difference to the bill. The refinery OVERRIDES the base cost ("costs only
	# 3"); the shortage ADDS to whatever it then is. The 1D3 is rolled here so
	# the die can be shown to the player rather than buried in a helper.
	var _traits: Array = _get_current_world_traits()
	var _surcharge: int = 0
	if WorldTraitEffectsClass.travel_surcharge_dice(_traits) != "":
		_surcharge = randi_range(1, 3)
	var _base_travel_cost: int = travel_cost
	travel_cost = WorldTraitEffectsClass.travel_cost(
		travel_cost, _traits, _surcharge)
	var _trait_note: String = ""
	if travel_cost != _base_travel_cost:
		_trait_note = "  [world trait: %d cr → %d cr%s]" % [
			_base_travel_cost, travel_cost,
			(", 1D3 surcharge %d" % _surcharge) if _surcharge > 0 else ""]

	travel_cost = _apply_fuel_credits(travel_cost)

	GameStateManager.modify_credits(-travel_cost)

	travel_decision_made = true
	chose_to_travel = true
	_update_travel_ui_after_decision()
	_travel_status_label.text = (
		"✓ Traveling to new world (-%d cr)" % travel_cost
		+ _trait_note
		+ ("  [%d cr covered by fuel]" % _fuel_offset_last_trip
			if _fuel_offset_last_trip > 0 else ""))
	_travel_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_AMBER)
	_travel_status_label.visible = true

	# Generate D100 travel event (Core Rules pp.70-71).
	#
	# p.69 is explicit for commercial passage: "When traveling commercially, do
	# not roll for Starship Travel Events." This branched on has_ship only to pick
	# the COST, then rolled unconditionally — so a shipless crew riding a liner
	# was shown "Asteroids: your ship takes Hull damage" and "Drive trouble: your
	# ship is grounded" about a ship they do not own.
	if has_ship:
		_generate_travel_event()

	# New World Arrival (Core Rules p.69): generate the world we travel TO and
	# route it through the campaign's single world_data writer, which fires
	# world_changed → PlanetDataManager sync (Galaxy Log) + world-arrival event.
	_arrive_at_new_world()

	# Refresh upkeep display (credits changed)
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()
	_update_gating_state()

# ============================================================================
# FLEE INVASION (Core Rules p.69) + starship fuel (p.79)
#
# All of this existed only in src/core/campaign/phases/TravelPhase.gd, a file
# with ZERO instantiations anywhere in src/. Travel actually happens here, in
# the World Phase upkeep step. The consequences of that dead file were not
# cosmetic: record_invaded_planet() had exactly one caller (in it), so
# `invaded_planets` was never populated, so GalacticWarProcessor returned at its
# own is_empty() guard every turn and the Core Rules p.126 step 14 Galactic War
# table has never once rolled in a real campaign. This screen even rendered an
# "INVASION IMMINENT — You must flee (2D6, 8+) or fight when departing" banner
# above a button that did neither.
# ============================================================================

func _campaign_progress_data() -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return {}
	var campaign = gs.current_campaign
	if not ("progress_data" in campaign) or not (campaign.progress_data is Dictionary):
		return {}
	return campaign.progress_data

func _build_crew_management_entry(vbox: VBoxContainer) -> void:
	## One row of Upkeep-step crew actions. Dismiss is always available (p.76);
	## Suspend/Revive only with the ship component installed (p.62).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss Crew"
	dismiss_btn.accessibility_name = "Dismiss a crew member"
	dismiss_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	dismiss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismiss_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dismiss_btn.pressed.connect(show_dismiss_crew_dialog)
	row.add_child(dismiss_btn)

	if ShipComponentQuery.has_component("suspension_pod"):
		var susp_btn := Button.new()
		var n: int = _suspended_ids().size()
		susp_btn.text = "Suspension Pod (%d/%d)" % [n, MAX_SUSPENDED_CREW]
		susp_btn.accessibility_name = "Suspend or revive crew, %d of %d pods used" % [
			n, MAX_SUSPENDED_CREW]
		susp_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		susp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		susp_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		susp_btn.pressed.connect(show_suspension_pod_dialog)
		row.add_child(susp_btn)

	vbox.add_child(row)

const MEDICAL_CARE_COST := 4  # Core Rules p.76


func _refresh_after_upkeep_payment() -> void:
	## Same refresh the suspension-pod flow uses: the payment changed credits, so
	## the upkeep affordability line and the gating both have to be recomputed.
	current_upkeep_data = calculate_upkeep_costs()
	_build_travel_section()
	_update_ui_display()
	_update_gating_state()


func _build_ship_debt_entry(vbox: VBoxContainer) -> void:
	## Core Rules p.76, verbatim: "Ship Debt — You can make payments on your ship,
	## if you owe money."
	##
	## There was no way to pay. ShiplessSystem's interest ladder had zero callers
	## and the Upkeep step contained no debt UI at all, so a loan financed at
	## creation (real saves carry 12-36 credits) sat frozen for the whole campaign.
	## Interest now accrues at rollover; this is the payment window that precedes
	## it, which is the order the book states.
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_ship_debt"):
		return
	var debt: int = int(gsm.get_ship_debt())
	if debt <= 0:
		return

	var credits: int = 0
	if gsm.has_method("get_credits"):
		credits = int(gsm.get_credits())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	# p.76 interest ladder, shown so the player can weigh paying down below 31.
	var interest: int = 2 if debt >= 31 else 1
	label.text = "Ship debt: %d cr (+%d/turn)" % [debt, interest]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if debt >= 60:
		label.add_theme_color_override("font_color", UIColors.COLOR_RED)
	row.add_child(label)

	for amount: int in [1, 5, 10]:
		if credits < amount or debt < amount:
			continue
		var btn := Button.new()
		btn.text = "Pay %d" % amount
		btn.accessibility_name = "Pay %d credits toward the ship debt" % amount
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.pressed.connect(_on_pay_ship_debt.bind(amount))
		row.add_child(btn)

	var payoff: int = mini(debt, credits)
	if payoff > 0 and payoff not in [1, 5, 10]:
		var all_btn := Button.new()
		all_btn.text = "Pay %d" % payoff
		all_btn.accessibility_name = "Pay %d credits toward the ship debt" % payoff
		all_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		all_btn.pressed.connect(_on_pay_ship_debt.bind(payoff))
		row.add_child(all_btn)

	vbox.add_child(row)


func _on_pay_ship_debt(amount: int) -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_ship_debt"):
		return
	var debt: int = int(gsm.get_ship_debt())
	var credits: int = int(gsm.get_credits()) if gsm.has_method("get_credits") else 0
	var pay: int = mini(amount, mini(debt, credits))
	if pay <= 0:
		return

	if gsm.has_method("modify_credits"):
		gsm.modify_credits(-pay)
	if gsm.has_method("set_ship_debt"):
		gsm.set_ship_debt(debt - pay)

	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success("Paid %d credits — ship debt now %d." % [pay, debt - pay])
	_refresh_after_upkeep_payment()


func _build_medical_care_entry(vbox: VBoxContainer) -> void:
	## Core Rules p.76, verbatim: "Pay for Medical Care — If you have crew in Sick
	## Bay, you may now pay 4 credits to remove 1 campaign turn from a single
	## character's recovery time. This can be done as often as you can afford it
	## ... Repair times for Bot characters can be sped up through the same
	## process, and at the same cost."
	##
	## This step did not exist anywhere in the app. UpkeepSystem defined the
	## 4-credit cost and had zero callers, and InjurySystemService's comment
	## pointed at "handled in UpkeepPhaseComponent" — which contained no medical
	## code at all. An injured crew member always sat out the full recovery and
	## the player's credits could not help.
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null:
		return
	var campaign: Resource = _get_campaign_resource()
	if campaign == null:
		return
	var injured: Array = _crew_in_sick_bay(campaign)
	if injured.is_empty():
		return

	var credits: int = int(gsm.get_credits()) if gsm.has_method("get_credits") else 0

	var header := Label.new()
	header.text = "Medical Care — %d cr removes 1 turn of recovery (p.76)" % MEDICAL_CARE_COST
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	for entry: Dictionary in injured:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label := Label.new()
		var turns: int = int(entry.get("turns", 0))
		label.text = "%s — %d turn%s" % [
			str(entry.get("name", "Crew")), turns, "" if turns == 1 else "s"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Treat (%d cr)" % MEDICAL_CARE_COST
		btn.accessibility_name = "Pay %d credits to speed %s's recovery by one turn" % [
			MEDICAL_CARE_COST, str(entry.get("name", "this crew member"))]
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.disabled = credits < MEDICAL_CARE_COST
		btn.pressed.connect(_on_pay_medical_care.bind(str(entry.get("id", ""))))
		row.add_child(btn)

		vbox.add_child(row)


func _crew_in_sick_bay(campaign: Resource) -> Array:
	## Members with recovery time left, in either shape the roster uses.
	var out: Array = []
	var crew: Array = []
	if campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	elif "crew_data" in campaign:
		crew = campaign.crew_data.get("members", [])
	for member: Variant in crew:
		var turns: int = _recovery_turns_of(member)
		if turns <= 0:
			continue
		var name: String = "Crew"
		var id: String = _member_id_of(member)
		if member is Dictionary:
			name = str(member.get("character_name", member.get("name", "Crew")))
		elif member != null and "character_name" in member:
			name = str(member.character_name)
		out.append({"id": id, "name": name, "turns": turns})
	return out


func _recovery_turns_of(member: Variant) -> int:
	## Recovery lives on the member OR inside its injuries list, depending on the
	## path that wrote it (see the sick-bay countdown in CampaignPhaseManager).
	var direct: int = 0
	if member is Dictionary:
		direct = int(member.get("recovery_turns", 0))
	elif member != null and "recovery_turns" in member:
		direct = int(member.recovery_turns)
	if direct > 0:
		return direct

	var injuries: Array = []
	if member is Dictionary:
		var raw: Variant = member.get("injuries", [])
		injuries = raw if raw is Array else []
	elif member != null and "injuries" in member and member.injuries is Array:
		injuries = member.injuries
	var most: int = 0
	for inj: Variant in injuries:
		if inj is Dictionary:
			most = maxi(most, int(inj.get("recovery_turns", 0)))
	return most


func _on_pay_medical_care(member_id: String) -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	var campaign: Resource = _get_campaign_resource()
	if gsm == null or campaign == null or member_id.is_empty():
		return
	var credits: int = int(gsm.get_credits()) if gsm.has_method("get_credits") else 0
	if credits < MEDICAL_CARE_COST:
		return

	var crew: Array = []
	if campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	elif "crew_data" in campaign:
		crew = campaign.crew_data.get("members", [])

	var treated: bool = false
	var treated_name: String = "Crew"
	for member: Variant in crew:
		if _member_id_of(member) != member_id:
			continue
		treated_name = _entity_display_name(member, "Crew")
		treated = _decrement_recovery(member)
		break

	if not treated:
		return
	if gsm.has_method("modify_credits"):
		gsm.modify_credits(-MEDICAL_CARE_COST)

	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success("Paid %d cr — %s recovers one turn sooner." % [
			MEDICAL_CARE_COST, treated_name])
	_refresh_after_upkeep_payment()


func _decrement_recovery(member: Variant) -> bool:
	## Mirror of the sick-bay countdown: reduce whichever field is carrying the
	## remaining time. Returns false when there was nothing left to reduce, so the
	## caller never charges the player for a no-op.
	var changed: bool = false
	if member is Dictionary:
		if int(member.get("recovery_turns", 0)) > 0:
			member["recovery_turns"] = int(member["recovery_turns"]) - 1
			changed = true
		var raw: Variant = member.get("injuries", [])
		if not changed and raw is Array:
			for inj: Variant in raw:
				if inj is Dictionary and int(inj.get("recovery_turns", 0)) > 0:
					inj["recovery_turns"] = int(inj["recovery_turns"]) - 1
					changed = true
					break
		if changed and int(member.get("recovery_turns", 0)) <= 0:
			if _recovery_turns_of(member) <= 0:
				member["in_sick_bay"] = false
		return changed

	if member != null and "recovery_turns" in member and int(member.recovery_turns) > 0:
		member.recovery_turns = int(member.recovery_turns) - 1
		changed = true
	if changed and "in_sick_bay" in member and _recovery_turns_of(member) <= 0:
		member.in_sick_bay = false
	return changed


func _suspended_ids() -> Array:
	var pd: Dictionary = _campaign_progress_data()
	if pd.is_empty():
		return []
	var ids: Variant = pd.get("suspended_crew", [])
	return ids if ids is Array else []

func _member_id_of(member) -> String:
	if member is Dictionary:
		return str(member.get("character_id", member.get("id", "")))
	if member != null and "character_id" in member:
		return str(member.character_id)
	return ""

var _suspend_dialog: Window

func show_suspension_pod_dialog() -> void:
	## Suspension Pod (Core Rules p.62). THE PRODUCER THAT DID NOT EXIST:
	## progress_data["suspended_crew"] had four readers — the upkeep cost
	## exclusion, the recovery-skip at turn rollover, UpkeepSystem, and this
	## component — and NOTHING ever wrote to it, so a purchased Suspension Pod
	## did precisely nothing.
	if _suspend_dialog:
		_suspend_dialog.queue_free()

	_suspend_dialog = Window.new()
	_suspend_dialog.title = "Suspension Pod"
	_suspend_dialog.size = Vector2i(440, 420)
	_suspend_dialog.exclusive = true
	_suspend_dialog.close_requested.connect(
		func(): _suspend_dialog.queue_free(); _suspend_dialog = null)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_suspend_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var suspended: Array = _suspended_ids()
	var header := Label.new()
	header.text = ("Suspended crew take no part in events, tasks or missions, do "
		+ "not recover from Injuries, and cost no Upkeep. Up to %d at a time. "
		+ "(Core Rules p.62)  —  %d/%d in use.") % [
			MAX_SUSPENDED_CREW, suspended.size(), MAX_SUSPENDED_CREW]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for member in crew_data:
		var mid: String = _member_id_of(member)
		if mid.is_empty():
			continue
		var mname: String = str(member.get("character_name", member.get("name", "Unknown"))) \
			if member is Dictionary else "Unknown"
		# The captain runs the ship; suspending them is not a meaningful option.
		if member is Dictionary and bool(member.get("is_captain", false)):
			continue

		var is_susp: bool = mid in suspended
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		list.add_child(r)

		var lbl := Label.new()
		lbl.text = mname + ("  [SUSPENDED]" if is_susp else "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, TOUCH_TARGET_MIN)
		if is_susp:
			btn.text = "Revive"
			btn.accessibility_name = "Revive " + mname
			btn.pressed.connect(_on_revive_crew.bind(mid))
		else:
			btn.text = "Suspend"
			btn.accessibility_name = "Suspend " + mname
			btn.disabled = suspended.size() >= MAX_SUSPENDED_CREW
			btn.pressed.connect(_on_suspend_crew.bind(mid, mname))
		r.add_child(btn)

	add_child(_suspend_dialog)
	_suspend_dialog.popup_centered()

func _on_suspend_crew(character_id: String, character_name: String) -> void:
	var pd: Dictionary = _campaign_progress_data()
	if pd.is_empty():
		return
	var ids: Array = _suspended_ids()
	if character_id in ids or ids.size() >= MAX_SUSPENDED_CREW:
		return
	ids.append(character_id)
	pd["suspended_crew"] = ids
	_journal_crew_suspension("Crew suspended",
		"%s entered a Suspension Pod — no Upkeep, tasks, missions or Injury recovery while suspended (Core Rules p.62)." % character_name)
	_refresh_after_suspension_change()

func _on_revive_crew(character_id: String) -> void:
	var pd: Dictionary = _campaign_progress_data()
	if pd.is_empty():
		return
	var ids: Array = _suspended_ids()
	if character_id not in ids:
		return
	ids.erase(character_id)
	pd["suspended_crew"] = ids
	# p.62: "They must be counted as part of your crew during the Upkeep step of
	# that campaign turn" — recalculating costs below is what makes that true.
	_journal_crew_suspension("Crew revived",
		"Revived from suspension; counts toward Upkeep from this step onward (Core Rules p.62).")
	_refresh_after_suspension_change()

func _refresh_after_suspension_change() -> void:
	if _suspend_dialog:
		_suspend_dialog.queue_free()
		_suspend_dialog = null
	current_upkeep_data = calculate_upkeep_costs()
	_build_travel_section()
	_update_ui_display()
	_update_gating_state()

func _journal_crew_suspension(title: String, description: String) -> void:
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "event",
			"auto_generated": true,
			"title": title,
			"description": description,
			"tags": ["ship", "upkeep"],
		})

func _build_hull_repair_prompt(vbox: VBoxContainer) -> void:
	## Paid hull repair (Core Rules p.59). Only rendered while damaged.
	var damage: int = _hull_damage()
	if damage <= 0 or not has_ship:
		return

	var pd: Dictionary = _campaign_progress_data()
	var parts: int = int(pd.get("repair_part_credits", 0)) if not pd.is_empty() else 0
	var credits: int = int(GameStateManager.get_credits()) if GameStateManager else 0
	var affordable: int = mini(damage, parts + credits)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.22, 0.05, 0.75)
	style.border_color = UIColors.COLOR_AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "HULL DAMAGE: %d point(s) — the ship cannot leave orbit until repaired" % damage
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	lbl.add_theme_font_size_override("font_size", _scaled_font(15))
	box.add_child(lbl)

	var detail := Label.new()
	detail.text = "1 credit repairs 1 Hull Point. Repair parts on hand: %d." % parts
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	detail.add_theme_font_size_override("font_size", _scaled_font(13))
	box.add_child(detail)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if affordable > 0:
		btn.text = "Repair %d Hull Point(s)" % affordable
		btn.accessibility_name = "Repair %d hull points" % affordable
		btn.pressed.connect(_on_repair_hull_pressed.bind(affordable))
	else:
		btn.text = "Repair (no credits or parts)"
		btn.disabled = true
	box.add_child(btn)

	panel.add_child(box)
	vbox.add_child(panel)

func _on_repair_hull_pressed(points: int) -> void:
	var repaired: int = repair_hull_points(points)
	if repaired > 0:
		var journal = get_node_or_null("/root/CampaignJournal")
		if journal and journal.has_method("create_entry"):
			journal.create_entry({
				"type": "event",
				"auto_generated": true,
				"title": "Paid hull repairs",
				"description": "Repaired %d Hull Point(s) (Core Rules p.59)." % repaired,
				"tags": ["ship", "upkeep"],
			})
	# Rebuild so the banner, the repair button and the travel gate all re-read
	# the new hull state together.
	_build_travel_section()
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()
	_update_gating_state()

func _hull_damage() -> int:
	## Outstanding Hull Point damage on the ship, 0 if undamaged/shipless.
	var gs = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return 0
	var campaign = gs.current_campaign
	if not ("ship_data" in campaign) or not (campaign.ship_data is Dictionary):
		return 0
	var ship: Dictionary = campaign.ship_data
	if ship.is_empty():
		return 0
	var current: int = int(ship.get("hull_points", 0))
	var max_hull: int = int(ship.get("max_hull", current))
	return maxi(0, max_hull - current)

func repair_hull_points(points: int) -> int:
	## Paid repair (Core Rules p.59): "1 credit pays off 1 Hull Point of damage,
	## and any amount can be repaired this way during a campaign turn."
	##
	## Banked repair parts are spent FIRST. Crew tasks have always written
	## progress_data["repair_part_credits"] (p.79, "credits worth of Hull Point
	## repair parts") and NOTHING read the key back, so those credits were
	## unspendable — the exact mirror of the fuel-credits gap next door.
	## Returns the number of points actually repaired.
	if points <= 0:
		return 0
	var outstanding: int = _hull_damage()
	if outstanding <= 0:
		return 0
	var want: int = mini(points, outstanding)

	var pd: Dictionary = _campaign_progress_data()
	var parts: int = int(pd.get("repair_part_credits", 0)) if not pd.is_empty() else 0
	var from_parts: int = mini(parts, want)
	if from_parts > 0 and not pd.is_empty():
		pd["repair_part_credits"] = parts - from_parts

	var from_credits: int = want - from_parts
	if from_credits > 0:
		var available: int = int(GameStateManager.get_credits())
		from_credits = mini(from_credits, available)
		if from_credits > 0:
			GameStateManager.modify_credits(-from_credits)

	var repaired: int = from_parts + from_credits
	if repaired > 0 and GameStateManager.has_method("repair_hull"):
		GameStateManager.repair_hull(repaired)
	return repaired

func _apply_fuel_credits(travel_cost: int) -> int:
	## Spend banked starship fuel against this trip (Core Rules p.79).
	var pd: Dictionary = _campaign_progress_data()
	if pd.is_empty() or travel_cost <= 0:
		return travel_cost
	var fuel: int = int(pd.get("fuel_credits", 0))
	if fuel <= 0:
		return travel_cost
	var offset: int = mini(fuel, travel_cost)
	pd["fuel_credits"] = fuel - offset
	_fuel_offset_last_trip = offset
	return travel_cost - offset

func _invasion_pending() -> bool:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("has_pending_invasion"):
		return bool(gsm.has_pending_invasion())
	return false

func _attempt_invasion_escape() -> bool:
	## Core Rules p.69, verbatim: "you must attempt to flee. Roll 2D6. A score of
	## 8+ is required to get safely off-world."
	##
	## Modifiers come from ship components and are quoted verbatim in
	## data/ship_components.json (both re-verified against the PDF):
	##   shuttle      p.61 "If a planet is Invaded, you may add +2 to the roll to
	##                      get off-world."
	##   auto_turrets p.62 "If you have to flee from a world that is being
	##                      Invaded, you may add +1 to the roll."
	##
	## Returns true when the crew gets away. On a failure the world is still
	## recorded as Invaded and a forced Invasion Battle is armed for the mission
	## hand-off (p.69: "you MUST fight an Invasion Battle").
	var dice = get_node_or_null("/root/DiceManager")
	var roll: int = 0
	if dice and dice.has_method("roll_2d6"):
		roll = int(dice.roll_2d6("Flee Invasion (Core Rules p.69)"))
	elif dice and dice.has_method("roll_d6"):
		roll = int(dice.roll_d6()) + int(dice.roll_d6())
	else:
		roll = randi_range(1, 6) + randi_range(1, 6)

	var modifier: int = 0
	var sources: Array[String] = []
	if ShipComponentQuery.has_component("shuttle"):
		modifier += 2
		sources.append("shuttle +2")
	if ShipComponentQuery.has_component("auto_turrets"):
		modifier += 1
		sources.append("auto-turrets +1")
	var total: int = roll + modifier

	# The world is Invaded either way — that is what the Galactic War table
	# tracks (p.126 step 14), not whether you personally escaped it.
	_record_invaded_world()

	var detail: String = "2D6 %d%s = %d vs 8+" % [
		roll,
		(" (%s)" % ", ".join(sources)) if not sources.is_empty() else "",
		total,
	]

	if total >= 8:
		_clear_pending_invasion()
		_forced_invasion_mission = {}
		_journal_invasion("Fled the invasion", "Escaped off-world — %s (Core Rules p.69)." % detail)
		return true

	# Failed: the crew is pinned here and must fight.
	_clear_pending_invasion()
	_forced_invasion_mission = _build_invasion_mission()
	_journal_invasion("Trapped by the invasion",
		"Failed to get off-world — %s. An Invasion Battle is unavoidable (Core Rules p.69)." % detail)
	travel_decision_made = true
	chose_to_travel = false
	_update_travel_ui_after_decision()
	if _travel_status_label:
		_travel_status_label.text = "✗ Could not escape (%s) — Invasion Battle" % detail
		_travel_status_label.add_theme_color_override("font_color", UIColors.COLOR_RED)
		_travel_status_label.visible = true
	_update_gating_state()
	return false

func _record_invaded_world() -> void:
	## The single call that un-dead-ends Core Rules p.126 step 14.
	var gs = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return
	var campaign = gs.current_campaign
	if not campaign.has_method("record_invaded_planet"):
		return
	var pdm = get_node_or_null("/root/PlanetDataManager")
	var planet_id: String = ""
	var planet_name: String = ""
	if pdm:
		planet_id = str(pdm.current_planet_id) if "current_planet_id" in pdm else ""
		if pdm.has_method("get_current_planet"):
			var cur = pdm.get_current_planet()
			if cur is Dictionary:
				planet_name = str((cur as Dictionary).get("name", ""))
	if planet_id.is_empty():
		return
	campaign.record_invaded_planet(planet_id, planet_name)

func _clear_pending_invasion() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_invasion_pending"):
		gsm.set_invasion_pending(false)

func _build_invasion_mission() -> Dictionary:
	## Shaped like WorldPhaseController's mission_dict so the battle funnel needs
	## no special case: `mission_source == "invasion"` is what
	## BattleSetupRules.is_invasion() and the post-battle gates all key off.
	return {
		"objective": "survive",
		"objective_description": "Hold out against the invasion force (Core Rules p.92).",
		"enemy_type": "Invasion Force",
		"pay": 0,
		"danger_pay": 0,
		"danger_level": 3,
		"time_frame": "",
		"conditions": [],
		"benefits": [],
		"hazards": [],
		"location": "",
		"source": "invasion",
		"mission_source": "invasion",
		"is_invasion": true,
		"title": "Invasion Battle",
		"description": "You failed to escape the invasion and must fight (Core Rules p.69).",
	}

func get_forced_invasion_mission() -> Dictionary:
	## Non-empty when the p.69 flee roll failed this turn. WorldPhaseController
	## writes this as current_mission instead of any accepted job.
	return _forced_invasion_mission

func _journal_invasion(title: String, description: String) -> void:
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "event",
			"title": title,
			"description": description,
			"tags": ["invasion", "travel"],
			"auto_generated": true,
		})

func _update_travel_ui_after_decision() -> void:
	## Disable travel buttons after a decision is made
	if _stay_button:
		_stay_button.disabled = true
	if _travel_button:
		_travel_button.disabled = true
	if _red_zone_button:
		_red_zone_button.disabled = true
	if _black_zone_button:
		_black_zone_button.disabled = true

## ============================================================================
## ZONE SELECTION (Core Rules Appendix III pp.148-151)
## ============================================================================

func _build_zone_buttons(parent: VBoxContainer) -> void:
	## Build Red/Black Zone travel buttons below the normal travel row
	var campaign: Resource = _get_campaign_resource()
	if not campaign:
		return

	# Check eligibility — only show buttons when relevant
	var turns_played: int = 0
	if "progress_data" in campaign:
		turns_played = campaign.progress_data.get("turns_played", 0)
	# Hide zone buttons entirely before turn 10
	if turns_played < 10:
		return

	# Same treatment as the Stay/Travel row above, for the same two reasons. Side by side
	# "Travel to Red Zone" and "Accept Black Zone Mission" demand 456px — more than a
	# phone's entire design space, which clipped the whole World Phase on both edges once
	# a campaign reached turn 10 — and their labels autowrap, which an HFlow would turn
	# into tall thin slabs. A BoxContainer that goes vertical in portrait solves both.
	var zone_row := BoxContainer.new()
	zone_row.name = "ZoneButtonRow"
	zone_row.add_theme_constant_override("separation", 16)
	zone_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_register_responsive_box(zone_row)

	# Red Zone button
	_red_zone_button = Button.new()
	_red_zone_button.text = "Travel to Red Zone"
	_red_zone_button.tooltip_text = (
		"Red Zone: Dangerous endgame missions with "
		+ "increased opposition and improved rewards "
		+ "(Core Rules Appendix III)")
	_red_zone_button.custom_minimum_size = Vector2(0, 48)
	_red_zone_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_red_zone_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rz_style := StyleBoxFlat.new()
	rz_style.bg_color = Color(0.55, 0.08, 0.08, 0.9)
	rz_style.border_width_left = 1
	rz_style.border_width_top = 1
	rz_style.border_width_right = 1
	rz_style.border_width_bottom = 1
	rz_style.border_color = Color(0.86, 0.15, 0.15, 1)
	rz_style.set_corner_radius_all(4)
	rz_style.content_margin_left = 16.0
	rz_style.content_margin_top = 8.0
	rz_style.content_margin_right = 16.0
	rz_style.content_margin_bottom = 8.0
	_red_zone_button.add_theme_stylebox_override("normal", rz_style)
	_red_zone_button.add_theme_color_override(
		"font_color", Color(1, 0.85, 0.85, 1))
	_red_zone_button.pressed.connect(_on_red_zone_travel_pressed)
	zone_row.add_child(_red_zone_button)

	# Black Zone button (only if Red Zone licensed + 10 RZ turns)
	var bz_check: Dictionary = BlackZoneSystem.can_accept_mission(
		campaign)
	_black_zone_button = Button.new()
	_black_zone_button.text = "Accept Black Zone Mission"
	_black_zone_button.tooltip_text = (
		"Black Zone: Near-suicide Unity missions. "
		+ "No upkeep, 3 free weapons, massive rewards "
		+ "(Core Rules Appendix III)")
	_black_zone_button.custom_minimum_size = Vector2(0, 48)
	_black_zone_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_black_zone_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bz_style := StyleBoxFlat.new()
	bz_style.bg_color = Color(0.15, 0.05, 0.25, 0.9)
	bz_style.border_width_left = 1
	bz_style.border_width_top = 1
	bz_style.border_width_right = 1
	bz_style.border_width_bottom = 1
	bz_style.border_color = Color(0.4, 0.1, 0.6, 1)
	bz_style.set_corner_radius_all(4)
	bz_style.content_margin_left = 16.0
	bz_style.content_margin_top = 8.0
	bz_style.content_margin_right = 16.0
	bz_style.content_margin_bottom = 8.0
	_black_zone_button.add_theme_stylebox_override("normal", bz_style)
	_black_zone_button.add_theme_color_override(
		"font_color", Color(0.85, 0.75, 1.0, 1))
	_black_zone_button.pressed.connect(_on_black_zone_accepted)
	# Disable if not eligible
	if not bz_check.get("can_accept", false):
		_black_zone_button.disabled = true
	zone_row.add_child(_black_zone_button)

	parent.add_child(zone_row)

func _build_colony_world_buttons(parent: VBoxContainer) -> void:
	## Build Krag/Skulker Colony World travel buttons (Compendium pp.15, 17)
	## Only shown if crew has a Krag or Skulker and the DLC is owned
	var dlc: Node = get_node_or_null("/root/DLCManager")
	if not dlc or not dlc.has_method("is_feature_available"):
		return

	# Check if crew has Krag or Skulker members
	var has_krag := false
	var has_skulker := false
	for member in crew_data:
		var sid: String = str(member.get("species_id",
			member.get("species", ""))).to_lower()
		if sid == "krag":
			has_krag = true
		elif sid == "skulker":
			has_skulker = true

	# Only show if relevant species is in crew AND DLC is owned
	var show_krag: bool = has_krag and dlc.is_feature_available(
		dlc.ContentFlag.SPECIES_KRAG)
	var show_skulker: bool = has_skulker and dlc.is_feature_available(
		dlc.ContentFlag.SPECIES_SKULKER)
	if not show_krag and not show_skulker:
		return

	var colony_row := HBoxContainer.new()
	colony_row.name = "ColonyButtonRow"
	colony_row.add_theme_constant_override("separation", 16)
	colony_row.alignment = BoxContainer.ALIGNMENT_CENTER

	if show_krag:
		# Krag colony costs 1 Story Point (Compendium p.15)
		var krag_btn := Button.new()
		krag_btn.text = "Travel to Krag Colony (1 SP)"
		krag_btn.tooltip_text = (
			"Krag colonies always have Busy Markets + Vendetta System traits. "
			+ "Costs 1 Story Point to discover (Compendium p.15)")
		krag_btn.custom_minimum_size = Vector2(0, 48)
		var krag_style := StyleBoxFlat.new()
		krag_style.bg_color = Color(0.35, 0.25, 0.1, 0.9)
		krag_style.border_color = Color(0.6, 0.45, 0.15, 1)
		krag_style.set_border_width_all(1)
		krag_style.set_corner_radius_all(4)
		krag_style.set_content_margin_all(12)
		krag_btn.add_theme_stylebox_override("normal", krag_style)
		krag_btn.add_theme_color_override(
			"font_color", Color(0.95, 0.95, 0.95, 1))
		# Check SP availability
		var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
		var sp_balance: int = 0
		if cpm and cpm.story_point_system:
			sp_balance = cpm.story_point_system.get_balance()
		if sp_balance < 1:
			krag_btn.disabled = true
			krag_btn.tooltip_text += "\n(Requires 1 Story Point — none available)"
		krag_btn.pressed.connect(_on_colony_travel_pressed.bind("krag"))
		colony_row.add_child(krag_btn)

	if show_skulker:
		# Skulker colony is free (Compendium p.17)
		var skulker_btn := Button.new()
		skulker_btn.text = "Travel to Skulker Colony"
		skulker_btn.tooltip_text = (
			"Skulker colonies always have Adventurous trait + one random trait. "
			+ "'Alien species restricted' = no result (Compendium p.17)")
		skulker_btn.custom_minimum_size = Vector2(0, 48)
		var skulker_style := StyleBoxFlat.new()
		skulker_style.bg_color = Color(0.15, 0.3, 0.2, 0.9)
		skulker_style.border_color = Color(0.2, 0.5, 0.35, 1)
		skulker_style.set_border_width_all(1)
		skulker_style.set_corner_radius_all(4)
		skulker_style.set_content_margin_all(12)
		skulker_btn.add_theme_stylebox_override("normal", skulker_style)
		skulker_btn.add_theme_color_override(
			"font_color", Color(0.95, 0.95, 0.95, 1))
		skulker_btn.pressed.connect(_on_colony_travel_pressed.bind("skulker"))
		colony_row.add_child(skulker_btn)

	parent.add_child(colony_row)

func _on_colony_travel_pressed(species_id: String) -> void:
	## Handle colony world travel — deduct SP if Krag, generate colony, travel
	if species_id == "krag":
		# Deduct 1 Story Point (Compendium p.15)
		var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
		if cpm and cpm.story_point_system:
			if cpm.story_point_system.get_balance() < 1:
				return
			cpm.story_point_system.remove_points(1)

	# Generate colony world via PlanetDataManager
	var pdm: Node = get_node_or_null("/root/PlanetDataManager")
	if pdm and pdm.has_method("create_colony_world"):
		var campaign: Resource = _get_campaign_resource()
		var turn: int = 0
		if campaign and "progress_data" in campaign:
			turn = campaign.progress_data.get("turns_played", 0)
		var colony_planet = pdm.create_colony_world(species_id, turn)
		if colony_planet:
			pdm.current_planet_id = colony_planet.id

	# Mark travel decision
	selected_zone = 0
	travel_decision_made = true
	chose_to_travel = true
	_update_travel_ui_after_decision()
	var colony_label: String = "%s Colony" % species_id.capitalize()
	_travel_status_label.text = "✓ Traveling to %s" % colony_label
	_travel_status_label.add_theme_color_override(
		"font_color", UIColors.COLOR_EMERALD)
	_travel_status_label.visible = true
	_update_gating_state()

func _on_red_zone_travel_pressed() -> void:
	## Handle Red Zone travel — check license, purchase if needed
	var campaign: Resource = _get_campaign_resource()
	if not campaign:
		return

	if RedZoneSystem.is_licensed(campaign):
		# Already licensed — proceed with Red Zone travel
		_commit_zone_travel(1)
	else:
		# Check if eligible for license purchase
		var check: Dictionary = RedZoneSystem.can_obtain_license(
			campaign)
		if check.get("can_license", false):
			_show_license_purchase_dialog(check)
		else:
			# Show why they can't get a license
			var reasons: String = "\n".join(
				check.get("reasons", []))
			_show_help_dialog(
				"Red Zone License Requirements",
				"Cannot obtain license:\n" + reasons)

func _on_black_zone_accepted() -> void:
	## Handle Black Zone mission acceptance
	var campaign: Resource = _get_campaign_resource()
	if not campaign:
		return

	var check: Dictionary = BlackZoneSystem.can_accept_mission(
		campaign)
	if not check.get("can_accept", false):
		var reasons: String = "\n".join(
			check.get("reasons", []))
		_show_help_dialog(
			"Black Zone Requirements",
			"Cannot accept Black Zone mission:\n" + reasons)
		return

	_commit_zone_travel(2)

func _commit_zone_travel(zone: int) -> void:
	## Finalize zone travel decision and update state
	selected_zone = zone
	travel_decision_made = true
	chose_to_travel = true
	_update_travel_ui_after_decision()

	# Deduct travel cost (same as normal travel)
	var travel_cost: int
	if has_ship:
		travel_cost = SHIP_TRAVEL_COST
	else:
		travel_cost = (
			_get_crew_size_for_travel()
			* COMMERCIAL_TRAVEL_COST_PER_CREW)
	GameStateManager.modify_credits(-travel_cost)

	# Update status label
	var zone_name: String = "Red Zone" if zone == 1 else "Black Zone"
	_travel_status_label.text = (
		"Traveling to %s world (-%d cr)" % [zone_name, travel_cost])
	var zone_color: Color = (
		Color(0.86, 0.15, 0.15, 1) if zone == 1
		else Color(0.4, 0.1, 0.6, 1))
	_travel_status_label.add_theme_color_override(
		"font_color", zone_color)
	_travel_status_label.visible = true

	# Generate travel event for Red Zone (Black Zone skips travel)
	if zone == 1:
		_generate_travel_event()

	# Refresh upkeep display (credits changed + zone may waive upkeep)
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()
	_update_gating_state()

func _show_license_purchase_dialog(
		license_check: Dictionary) -> void:
	## Show confirmation dialog for Red Zone license purchase
	if _license_dialog and is_instance_valid(_license_dialog):
		_license_dialog.queue_free()

	_license_dialog = ConfirmationDialog.new()
	_license_dialog.title = "Red Zone License"
	var fee: int = license_check.get("fee", 15)
	var reqs: Dictionary = license_check.get("requirements", {})
	var turns_info: String = "Turns: %d/%d" % [
		reqs.get("turns", {}).get("current", 0),
		reqs.get("turns", {}).get("required", 10)]
	var crew_info: String = "Crew: %d/%d" % [
		reqs.get("crew", {}).get("current", 0),
		reqs.get("crew", {}).get("required", 7)]
	_license_dialog.dialog_text = (
		"Purchase Red Zone License?\n\n"
		+ "Cost: %d credits\n" % fee
		+ "%s\n%s\n\n" % [turns_info, crew_info]
		+ "Red Zone missions feature increased opposition, "
		+ "threat conditions, and improved rewards.\n\n"
		+ "WARNING: Red Zones are high-risk and intended for "
		+ "experienced crews. (Core Rules Appendix III)")
	_license_dialog.ok_button_text = "Purchase (%d cr)" % fee
	_license_dialog.confirmed.connect(
		_on_license_purchase_confirmed)
	add_child(_license_dialog)
	_license_dialog.popup_centered(Vector2i(450, 300))

func _on_license_purchase_confirmed() -> void:
	## Handle license purchase confirmation
	var campaign: Resource = _get_campaign_resource()
	if not campaign:
		return

	var success: bool = RedZoneSystem.purchase_license(campaign)
	if success:
		# Journal: milestone entry for license purchase
		var journal: Node = get_node_or_null(
			"/root/CampaignJournal")
		if journal and journal.has_method(
				"auto_create_milestone_entry"):
			var turns: int = 0
			if "progress_data" in campaign:
				turns = campaign.progress_data.get(
					"turns_played", 0)
			journal.auto_create_milestone_entry(
				"red_zone_license", {
					"turn": turns,
					"stats": {
						"license_fee": RedZoneSystem.can_obtain_license(campaign).get("fee", 15),
					},
				})
		_commit_zone_travel(1)
	else:
		_show_help_dialog(
			"License Purchase Failed",
			"Could not purchase Red Zone license. "
			+ "Check credits and requirements.")

func _update_zone_info_label() -> void:
	## Update the zone eligibility info text
	if not _zone_info_label:
		return

	var campaign: Resource = _get_campaign_resource()
	if not campaign:
		_zone_info_label.visible = false
		return

	var turns_played: int = 0
	if "progress_data" in campaign:
		turns_played = campaign.progress_data.get("turns_played", 0)
	if turns_played < 10:
		_zone_info_label.visible = false
		return

	var parts: Array[String] = []
	if RedZoneSystem.is_licensed(campaign):
		parts.append("Red Zone: Licensed")
		var rz_turns: int = (
			campaign.red_zone_turns_completed
			if "red_zone_turns_completed" in campaign else 0)
		if rz_turns < 10:
			parts.append(
				"Black Zone: %d/10 Red Zone turns" % rz_turns)
		else:
			parts.append("Black Zone: Eligible")
	else:
		var check: Dictionary = RedZoneSystem.can_obtain_license(
			campaign)
		if check.get("can_license", false):
			parts.append("Red Zone: License available")
		else:
			var reasons: Array = check.get("reasons", [])
			if not reasons.is_empty():
				parts.append(
					"Red Zone: " + str(reasons[0]))

	_zone_info_label.text = "  |  ".join(parts)
	_zone_info_label.visible = not parts.is_empty()

func _get_campaign_resource() -> Resource:
	## Helper to get the current campaign Resource
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		return gs.current_campaign
	return null

## Public API: Get selected zone for WorldPhaseController
func get_selected_zone() -> int:
	## Returns 0=normal, 1=red_zone, 2=black_zone
	return selected_zone

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
	_apply_travel_event(event)


func _apply_travel_event(event: Dictionary) -> void:
	## The table used to be text-only: TravelEventTable.gd states at line 10 that
	## its effect tags are "hint tags for the resolving UI (not mechanically
	## applied here)", and no resolving UI ever existed. Travel therefore carried
	## neither risk nor reward for the entire campaign.
	_travel_choices.clear()
	_travel_event_depth = 0
	_resolve_travel_event(event)


func _resolve_travel_event(event: Dictionary) -> void:
	## Events that ask the player something come back with a pending_choice; the
	## buttons below answer it and re-enter here. p.70's "then roll again on this
	## table" is followed for real, bounded so a chain cannot hang the turn.
	var campaign: Resource = _get_campaign_resource()
	if campaign == null:
		return
	_travel_event_depth += 1
	if _travel_event_depth > 6:
		_add_travel_event_note("Event chain stopped after 6 rolls.")
		return

	var report: Dictionary = TravelEventResolverClass.apply(
		campaign, event, _travel_choices)

	var choice: Dictionary = report.get("pending_choice", {})
	if not choice.is_empty():
		_build_travel_choice(event, choice)
		return

	_consume_travel_report(report)

	if bool(report.get("reroll", false)):
		var next_roll: int = randi_range(1, 100)
		var next_event: Dictionary = _process_travel_event_roll(next_roll)
		_display_travel_event(next_event, next_roll)
		_resolve_travel_event(next_event)


func _build_travel_choice(event: Dictionary, choice: Dictionary) -> void:
	## Inline buttons rather than a modal Window: this panel is already a
	## scrolling column and a popup would fight the portrait layout.
	_add_travel_event_note(str(choice.get("prompt", "Choose:")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for option: Dictionary in choice.get("options", []):
		var btn := Button.new()
		btn.text = str(option.get("label", "Choose"))
		btn.accessibility_name = btn.text
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_travel_choice_made.bind(
			event, choice, str(option.get("id", "")), row))
		row.add_child(btn)
	if _travel_event_container:
		_travel_event_container.add_child(row)


func _on_travel_choice_made(event: Dictionary, choice: Dictionary,
		option_id: String, row: Node) -> void:
	var key: String = str(choice.get("id", ""))
	# The three-world pick needs the generated worlds carried with the answer, or
	# the resolver would roll three DIFFERENT worlds when it re-runs.
	if choice.has("worlds"):
		_travel_choices[key] = {"id": option_id, "worlds": choice["worlds"]}
	else:
		_travel_choices[key] = option_id
	if is_instance_valid(row):
		row.queue_free()
	_resolve_travel_event(event)


func _consume_travel_report(report: Dictionary) -> void:
	for line: String in report.get("applied", []):
		_add_travel_event_note(line)

	# Hull damage goes through GameStateManager so ship traits (Armored,
	# Improved Shielding, Dodgy Drive) and the p.59 wreck check both apply.
	# in_space is TRUE here: these events happen in transit, which selects the
	# "being without a ship" outcome rather than the grounded scrap payout.
	var hull: int = int(report.get("hull_damage", 0))
	if hull > 0:
		var gsm: Node = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("apply_ship_damage"):
			var dealt: int = int(gsm.apply_ship_damage(hull, true))
			_add_travel_event_note("Ship took %d Hull Point damage" % dealt)

	var battle: Dictionary = report.get("forced_battle", {})
	if not battle.is_empty():
		_forced_travel_battle = battle
		_add_travel_event_note(
			"Pirates board — an out-of-sequence battle awaits (it does not"
			+ " consume this turn's Battle stage).")


func get_forced_travel_battle() -> Dictionary:
	## Non-empty when the p.70 Raided event failed its intimidation roll.
	## Mirrors get_forced_invasion_mission() so WorldPhaseController can consume
	## it the same way.
	return _forced_travel_battle


func _add_travel_event_note(text: String) -> void:
	if _travel_event_container == null:
		return
	var label := Label.new()
	label.text = "• " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	_travel_event_container.add_child(label)

func _arrive_at_new_world() -> Dictionary:
	## New World Arrival (Core Rules p.69). Generate a fresh world and write it
	## through campaign.initialize_world() — the SINGLE world_data writer — which
	## emits world_changed so the galaxy map + world log update. Returns the new
	## world dict (empty on failure). Also clears any satisfied quest-travel flag.
	var campaign: Resource = _get_campaign_resource()
	if not campaign or not campaign.has_method("initialize_world"):
		return {}

	var turn: int = 1
	if "progress_data" in campaign:
		turn = int(campaign.progress_data.get("turns_played", 1))

	var gen: Node = WorldGeneratorClass.new()
	var new_world: Dictionary = {}
	if gen and gen.has_method("generate_world"):
		new_world = gen.generate_world(turn)
	if gen:
		gen.free()

	if new_world.is_empty():
		return {}

	# New World Arrival steps 1-2 (Core Rules p.72) — who comes with you, not
	# where you land. Deliberately AFTER generation (so a failed generation
	# cannot strip Rivals for a journey that never happened) and BEFORE
	# initialize_world, so the departure is journalled against the world being
	# LEFT rather than the one being arrived at.
	var departures: Dictionary = NewWorldArrivalClass.apply(campaign)
	_report_arrival_departures(departures)

	# The single chokepoint: fires world_changed → PDM sync + world-arrival event.
	campaign.initialize_world(new_world)

	_roll_psionic_legality_for_world(campaign, new_world)
	_check_personal_trinkets(campaign)

	# Mission-required travel (Core Rules p.119): traveling to a NEW world
	# satisfies a Quest's "next step is on another world" requirement — clear it.
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_quest_requires_travel") \
			and gs.has_method("set_quest_requires_travel"):
		if gs.get_quest_requires_travel().get("required", false):
			gs.set_quest_requires_travel(false, false)

	# Surface the arrival: toast + refresh the current-world label.
	var world_name: String = str(new_world.get("name", "a new world"))
	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success("Arrived: %s — added to Galaxy Log" % world_name)
	if _travel_status_label:
		_travel_status_label.text = "✓ Arrived: %s" % world_name

	return new_world


func _entity_display_name(entity: Variant, fallback: String) -> String:
	return NewWorldArrivalClass.display_name(entity, fallback)


func _report_arrival_departures(departures: Dictionary) -> void:
	## Tell the player who stayed behind. Without this the p.72 steps would be
	## invisible bookkeeping and would read as a bug ("where did my Patron go?").
	var rivals_left: Array = departures.get("rivals_left", [])
	var patrons_left: Array = departures.get("patrons_left", [])
	if rivals_left.is_empty() and patrons_left.is_empty():
		return

	var parts: Array[String] = []
	if not rivals_left.is_empty():
		parts.append("%d Rival%s stayed behind" % [
			rivals_left.size(), "" if rivals_left.size() == 1 else "s"])
	if not patrons_left.is_empty():
		parts.append("%d Patron%s did not follow" % [
			patrons_left.size(), "" if patrons_left.size() == 1 else "s"])
	var summary: String = " · ".join(parts)

	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_info"):
		notif.show_info(summary)

	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		var detail: Array[String] = []
		if not rivals_left.is_empty():
			detail.append("Remained behind (Rivals): %s"
				% ", ".join(rivals_left))
		if not patrons_left.is_empty():
			detail.append("Patrons dismissed on departure: %s"
				% ", ".join(patrons_left))
		journal.create_entry({
			"type": "travel",
			"title": "Departure",
			"description": "\n".join(detail),
		})

func _check_personal_trinkets(campaign: Resource) -> void:
	## Core Rules p.121, Battlefield Finds 46-60, verbatim: "Personal trinket — On
	## each planet you visit in the future, roll 2D6. On a 9+ you find the owner
	## and receive a Loot roll (p.131) as payment."
	##
	## NO PER-PLANET CHECK EXISTED ANYWHERE. The find's own branch said "Resolved
	## per-planet later" and set amount 0, and a repo-wide search for a trinket /
	## 9+ resolver returned nothing outside a descriptive UI string. So the one
	## table entry whose whole value is a RECURRING payoff paid out exactly never.
	if campaign == null or not ("progress_data" in campaign):
		return
	var trinkets: int = int(campaign.progress_data.get("personal_trinkets", 0))
	if trinkets <= 0:
		return

	var found: int = 0
	var remaining: int = trinkets
	for _i in range(trinkets):
		if randi_range(1, 6) + randi_range(1, 6) >= 9:
			found += 1
			remaining -= 1
	if found <= 0:
		return

	# The owner is found once per trinket; that trinket is then spent.
	campaign.progress_data["personal_trinkets"] = remaining
	var owed: int = int(campaign.progress_data.get("pending_loot_rolls", 0))
	campaign.progress_data["pending_loot_rolls"] = owed + found

	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success(
			"Found the owner of a personal trinket — %d Loot roll(s) owed (p.121)."
			% found)
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "event",
			"auto_generated": true,
			"title": "Personal trinket returned",
			"description": ("Tracked down the owner of %d battlefield trinket(s)"
				% found) + " — %d Loot Table roll(s) as payment (Core Rules p.121)." % found,
			"tags": ["loot"],
		})


func _roll_psionic_legality_for_world(campaign: Resource, world: Dictionary) -> void:
	## The Legality of Psionics (Compendium p.20), verbatim: "When using Psionic
	## characters in a campaign, World Generation Steps gain an ADDITIONAL STEP
	## after Travel Step 4: New World Arrival" — D100, 01-25 Outlawed, 26-55
	## Highly unusual, 56-100 Who cares?
	##
	## THE ENTIRE RULE WAS ALREADY BUILT AND HAS NEVER RUN ONCE. The D100 bands
	## (PsionicSystem.roll_psionic_legality), the p.21 detection roll on post-game
	## step 1 (check_outlawed_detection: caught on a 1 after one use, 1-2 after
	## several), the D6 Psi-hunter table and its Seize-the-Initiative -2 / extra
	## Specialist / +1-to-hit adjustments, the badge on the world screen and the
	## journal entry — all correct, all waiting on this one number.
	##
	## The only writer lived in src/core/campaign/phases/WorldPhase.gd, a file
	## with zero instantiations. Travel actually happens here. So every consumer
	## read `psionic_legality` as -1, the OUTLAWED branch could never be taken,
	## and a Psionic could burn powers on a world that outlaws them with no
	## possibility of consequence.
	if campaign == null or not ("progress_data" in campaign):
		return
	var dlc: Node = get_node_or_null("/root/DLCManager")
	if dlc == null or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		return

	var legality: int = PsionicSystemRef.roll_psionic_legality()
	campaign.progress_data["psionic_legality"] = legality
	# Also on the world itself, so the world screen's badge and the Galaxy Log
	# describe the world they belong to rather than "the last roll".
	if not world.is_empty():
		world["psionic_legality"] = legality
		if campaign.has_method("initialize_world"):
			pass  # already written through; do not re-fire world_changed

	# A new world's status is news — the player has to know before deciding
	# whether to use a power, since that is the only thing that risks detection.
	var legality_name: String = PsionicSystemRef.get_legality_name(legality)
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "event",
			"auto_generated": true,
			"title": "Psionic legality: %s" % legality_name,
			"description": "%s — %s (Compendium p.20)" % [
				str(world.get("name", "This world")),
				PsionicSystemRef.get_legality_description(legality)],
			"tags": ["psionics", "world"],
		})
	if legality == PsionicSystemRef.PsionicLegality.OUTLAWED:
		var notif: Node = get_node_or_null("/root/NotificationManager")
		if notif and notif.has_method("show_warning"):
			notif.show_warning(
				"Psionics are OUTLAWED here — using a power in battle risks Psi-hunters")

func _process_travel_event_roll(roll: int) -> Dictionary:
	## Starship Travel Events Table (Core Rules pp.70-71).
	## Single source of truth lives in TravelEventTable so this never diverges
	## from the TravelPhaseUI travel roll. (Previously this site had a fabricated
	## 61-100 tail: Cargo Run / Rumor Mill / Smooth Sailing — none of which are in
	## the book. The book's 61-100 is Accident / Travel-time / Uneventful / Reflect
	## / Read / Library.)
	return TravelEventTable.get_event(roll)

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
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 16.0
	card_style.content_margin_top = 12.0
	card_style.content_margin_right = 16.0
	card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)

	var roll_label := Label.new()
	roll_label.text = "Travel Event Roll: %d" % roll
	roll_label.add_theme_font_size_override("font_size", _scaled_font(12))
	roll_label.add_theme_color_override(
		"font_color", Color(0.42, 0.451, 0.502, 1))
	card_vbox.add_child(roll_label)

	var title_label := Label.new()
	title_label.text = event.get("title", "Unknown Event")
	title_label.add_theme_font_size_override("font_size", _scaled_font(18))
	title_label.add_theme_color_override(
		"font_color", Color(0.953, 0.957, 0.965, 1))
	card_vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = event.get("desc", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", _scaled_font(14))
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

func _on_view_galaxy_map_pressed() -> void:
	## Open the Galaxy Log (read-only journey record) from the Travel step.
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("galaxy_log")

func _build_quest_travel_prompt(parent: VBoxContainer) -> void:
	## If a Quest's next step is on another world (Core Rules p.119), show a
	## non-blocking prompt encouraging travel. Traveling clears the flag (see
	## _arrive_at_new_world). Quests wait for you — this never forces the choice.
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("get_quest_requires_travel"):
		return
	var q: Dictionary = gs.get_quest_requires_travel()
	if not q.get("required", false) or not q.get("requires_new_world", false):
		return

	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.28, 0.85)
	style.border_color = Color(0.55, 0.35, 0.85, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = ("A Quest's next step is on another world — travel to progress it"
		+ " (Core Rules p.119). Quests will wait for you.")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0, 1))
	lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	banner.add_child(lbl)
	parent.add_child(banner)

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

func get_blocker_hint() -> String:
	## Human-readable reason this step can't advance yet ("" if it can).
	## Surfaced by WorldPhaseController next to a disabled "Next Step".
	if not travel_decision_made:
		return "Choose \"Stay\" or \"Travel\" first."
	if not upkeep_completed:
		return "Tap \"Calculate Costs\", then \"Pay Upkeep\" to continue."
	return ""

func get_upkeep_results() -> Dictionary:
	## Get the results of upkeep calculation
	var results: Dictionary = current_upkeep_data.duplicate()
	results["selected_zone"] = selected_zone
	return results

func reset_upkeep_phase() -> void:
	## Reset upkeep phase for new turn
	upkeep_completed = false
	costs_calculated = false
	travel_decision_made = false
	chose_to_travel = false
	_forced_invasion_mission = {}
	_fuel_offset_last_trip = 0
	selected_zone = 0
	current_upkeep_data.clear()
	ship_data.clear()
	crew_data.clear()
	_build_travel_section()
	_update_ui_display()

# ============================================================================
# DISMISS CREW (Core Rules p.76)
# "You can opt to kick out any crew member at this stage. If you do,
#  you may pick one item they carry and return it to your Stash,
#  but they take the rest of their equipment with them."
# ============================================================================

var _dismiss_dialog: Window
var _dismiss_crew_list: VBoxContainer
var _dismiss_equip_dialog: Window

func show_dismiss_crew_dialog() -> void:
	## PUBLIC API: Show crew dismissal dialog during upkeep phase
	if _dismiss_dialog:
		_dismiss_dialog.queue_free()

	_dismiss_dialog = Window.new()
	_dismiss_dialog.title = "Dismiss Crew Member"
	_dismiss_dialog.size = Vector2i(400, 350)
	_dismiss_dialog.exclusive = true
	_dismiss_dialog.close_requested.connect(
		func(): _dismiss_dialog.queue_free(); _dismiss_dialog = null)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_dismiss_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = (
		"Select a crew member to dismiss.\n"
		+ "You may keep 1 item they carry. (Core Rules p.76)")
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	_dismiss_crew_list = VBoxContainer.new()
	_dismiss_crew_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_dismiss_crew_list)

	for member in crew_data:
		var mname: String = member.get(
			"character_name", member.get("name", "Unknown"))
		var status: String = str(member.get("status", "ACTIVE"))
		if status in ["DEPARTED", "DEAD", "RETIRED"]:
			continue
		# Don't allow dismissing the captain
		if member.get("is_captain", false):
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_dismiss_crew_list.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = mname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "Dismiss"
		dismiss_btn.custom_minimum_size = Vector2(80, 36)
		dismiss_btn.pressed.connect(
			_on_dismiss_crew_pressed.bind(member))
		row.add_child(dismiss_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 44)
	cancel_btn.pressed.connect(func():
		_dismiss_dialog.queue_free(); _dismiss_dialog = null)
	vbox.add_child(cancel_btn)

	add_child(_dismiss_dialog)
	_dismiss_dialog.popup_centered()

func _on_dismiss_crew_pressed(member: Dictionary) -> void:
	## Player selected a crew member to dismiss — show equipment pick
	if _dismiss_dialog:
		_dismiss_dialog.queue_free()
		_dismiss_dialog = null

	var equipment: Array = member.get("equipment", [])
	if equipment.is_empty():
		# No equipment — just dismiss
		_execute_crew_dismissal(member, -1)
		return

	# Show equipment selection dialog (pick 1 to keep)
	_dismiss_equip_dialog = Window.new()
	_dismiss_equip_dialog.title = "Keep One Item"
	_dismiss_equip_dialog.size = Vector2i(400, 300)
	_dismiss_equip_dialog.exclusive = true
	_dismiss_equip_dialog.close_requested.connect(func():
		_dismiss_equip_dialog.queue_free()
		_dismiss_equip_dialog = null)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_dismiss_equip_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var mname: String = member.get(
		"character_name", member.get("name", "Unknown"))
	var header := Label.new()
	header.text = (
		"Dismissing %s. Pick 1 item to return to stash:"
	) % mname
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	for i in range(equipment.size()):
		var item = equipment[i]
		var item_name: String = ""
		if item is Dictionary:
			item_name = item.get("name", item.get("item_name", "Item"))
		else:
			item_name = str(item)

		var keep_btn := Button.new()
		keep_btn.text = "Keep: %s" % item_name
		keep_btn.custom_minimum_size = Vector2(0, 40)
		keep_btn.pressed.connect(
			_execute_crew_dismissal.bind(member, i))
		vbox.add_child(keep_btn)

	var none_btn := Button.new()
	none_btn.text = "Keep Nothing"
	none_btn.custom_minimum_size = Vector2(0, 40)
	none_btn.pressed.connect(
		_execute_crew_dismissal.bind(member, -1))
	vbox.add_child(none_btn)

	add_child(_dismiss_equip_dialog)
	_dismiss_equip_dialog.popup_centered()

func _execute_crew_dismissal(
	member: Dictionary, keep_item_index: int
) -> void:
	## Execute the dismissal: recover 1 item, remove crew member
	if _dismiss_equip_dialog:
		_dismiss_equip_dialog.queue_free()
		_dismiss_equip_dialog = null

	var mname: String = member.get(
		"character_name", member.get("name", "Unknown"))

	# Recover 1 item to stash (Core Rules p.76)
	if keep_item_index >= 0:
		var equipment: Array = member.get("equipment", [])
		if keep_item_index < equipment.size():
			var kept_item = equipment[keep_item_index]
			var eq_mgr = get_node_or_null("/root/EquipmentManager")
			if eq_mgr and eq_mgr.has_method("add_to_ship_stash"):
				eq_mgr.add_to_ship_stash(kept_item)

	# Remove crew member from campaign
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var member_id: String = member.get(
			"id", member.get("character_id", ""))
		# Route through the campaign's own mutator (Core Rules p.76 dismissal).
		#
		# This used to grab the live members Array (Arrays are reference types, so
		# that IS the owner) and call members.remove_at(i) directly. That bypassed
		# remove_crew_member(), which is the chokepoint that also rebuilds
		# _crew_id_index — so every member positioned AFTER the dismissed one was left
		# indexed one slot too high, and the dismissed member's own id stayed in the
		# index pointing at whoever moved into their place.
		#
		# get_crew_member_by_id() then resolved those stale entries as cache HITS (it
		# only range-checked), so World Phase crew-task XP was credited to the wrong
		# character sheet — silently, in the same turn, since Upkeep is where dismissal
		# is offered and crew tasks resolve later in that same World Phase.
		if not member_id.is_empty() and gs.current_campaign.has_method("remove_crew_member"):
			gs.current_campaign.remove_crew_member(member_id)

	# Remove from local crew_data too
	crew_data.erase(member)

	# Journal entry
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "crew_departure",
			"auto_generated": true,
			"title": "Crew Dismissed: %s" % mname,
			"description": (
				"%s was dismissed during upkeep (Core Rules p.76)"
			) % mname,
			"tags": ["crew_dismissed", "upkeep"],
		})

	# Recalculate upkeep with smaller crew
	current_upkeep_data = calculate_upkeep_costs()
	_update_ui_display()
	_show_help_dialog("Crew Dismissed",
		"%s has been dismissed from the crew." % mname)
