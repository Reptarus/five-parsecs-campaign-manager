class_name TravelPhaseUI
extends Control

## Travel Phase UI for Five Parsecs Campaign Manager
## Handles Step 1: Travel decision for the campaign turn (Core Rules p.69)
## Travel comes BEFORE World Phase in the campaign turn sequence

const RulesHelpText = preload("res://src/data/rules_help_text.gd")

signal phase_completed()
signal travel_completed()

# ============================================================================
# DESIGN SYSTEM CONSTANTS (from BaseCampaignPanel)
# ============================================================================

const COLOR_PRIMARY := Color("#0a0d14")
const COLOR_SECONDARY := Color("#111827")
const COLOR_TERTIARY := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_BLUE := Color("#3b82f6")
const COLOR_AMBER := Color("#f59e0b")
const COLOR_EMERALD := Color("#10b981")
const COLOR_RED := Color("#ef4444")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

# Travel costs per Five Parsecs rules (p.69)
const SHIP_TRAVEL_COST := 5
const COMMERCIAL_TRAVEL_COST_PER_CREW := 1

# ============================================================================
# UI REFERENCES
# ============================================================================

# Header elements
@onready var step_label: Label = %StepLabel
@onready var progress_bar: ProgressBar = %PhaseProgressBar
@onready var help_button: Button = %HelpButton

# Status display
@onready var credits_value: Label = %CreditsValue
@onready var crew_value: Label = %CrewValue
@onready var ship_value: Label = %ShipValue
@onready var world_value: Label = %WorldValue
@onready var commercial_cost_value: Label = %CommercialCostValue

# Travel options
@onready var stay_button: Button = %StayButton
@onready var travel_button: Button = %TravelButton
@onready var travel_event_details: VBoxContainer = %TravelEventDetails
@onready var travel_help_button: Button = %TravelHelpButton

# Log book
@onready var log_book: RichTextLabel = %LogBook

# Navigation buttons
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton

# ============================================================================
# STATE TRACKING
# ============================================================================

var campaign_data: Variant = null
var travel_decision_made: bool = false
var chose_to_travel: bool = false
var has_ship: bool = true # Default to having a ship

# Tooltip reference
var _help_dialog: AcceptDialog = null

# Sprint 10.4: Checkpoint data for bidirectional navigation
var _checkpoint_data: Dictionary = {}
var _log_entries: Array[String] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_apply_base_background()
	_fetch_campaign_data()
	_setup_ui()
	_setup_tooltips()
	_add_log_entry("[color=#4FC3F7]Travel Phase started (Step 1 of Campaign Turn)[/color]")

## Apply the Deep Space COLOR_BASE background behind this panel
func _apply_base_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__phase_bg"
	bg.color = Color("#1A1A2E")  # COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)

func _fetch_campaign_data() -> void:
	## Fetch campaign data from GameStateManager (self-initialization)
	# Try GameStateManager first (primary source)
	if GameStateManager:
		_update_status_from_game_state()
		return
	
	# Fallback: Try GameState autoload
	var game_state := get_node_or_null("/root/GameState")
	if game_state and game_state.get("current_campaign"):
		campaign_data = game_state.current_campaign
		_update_status_display()
		return
	
	# No data available - use defaults
	push_warning("TravelPhaseUI: No campaign data available, using defaults")
	_update_status_display()

func _update_status_from_game_state() -> void:
	## Update status display from GameStateManager
	if not GameStateManager:
		return
	
	# Get current credits
	var credits: int = GameStateManager.get_credits()
	if credits_value:
		credits_value.text = "%d cr" % credits
		credits_value.add_theme_color_override("font_color",
			COLOR_EMERALD if credits >= SHIP_TRAVEL_COST else COLOR_RED)
	
	# Get crew size
	var crew_size: int = GameStateManager.get_crew_size()
	if crew_value:
		crew_value.text = str(crew_size)
	
	# Calculate commercial travel cost
	var commercial_cost: int = crew_size * COMMERCIAL_TRAVEL_COST_PER_CREW
	if commercial_cost_value:
		commercial_cost_value.text = "%d cr (%d crew)" % [commercial_cost, crew_size]
	
	# Get ship status
	has_ship = _check_has_ship()
	if ship_value:
		if has_ship:
			ship_value.text = "Available"
			ship_value.add_theme_color_override("font_color", COLOR_EMERALD)
		else:
			ship_value.text = "No Ship"
			ship_value.add_theme_color_override("font_color", COLOR_AMBER)
	
	# Get current world
	var current_world: String = _get_current_world_name()
	if world_value:
		world_value.text = current_world if current_world else "Unknown World"
	
	# Update travel button states
	_update_travel_buttons(credits, crew_size)

func _update_status_display() -> void:
	## Update status display from campaign_data (fallback)
	var credits := 0
	var crew_size := 4
	
	if campaign_data:
		if campaign_data is Resource:
			credits = campaign_data.get_meta("credits", 0)
			if campaign_data.has_method("get_crew"):
				var crew: Array = campaign_data.get_crew()
				crew_size = crew.size()
		elif campaign_data is Dictionary:
			credits = campaign_data.get("credits", 0)
			var crew: Array = campaign_data.get("crew", [])
			crew_size = crew.size()
	
	if credits_value:
		credits_value.text = "%d cr" % credits
		credits_value.add_theme_color_override("font_color",
			COLOR_EMERALD if credits >= SHIP_TRAVEL_COST else COLOR_RED)
	
	if crew_value:
		crew_value.text = str(crew_size)
	
	var commercial_cost: int = crew_size * COMMERCIAL_TRAVEL_COST_PER_CREW
	if commercial_cost_value:
		commercial_cost_value.text = "%d cr (%d crew)" % [commercial_cost, crew_size]
	
	_update_travel_buttons(credits, crew_size)

func _check_has_ship() -> bool:
	## Check if the crew has a ship
	if GameStateManager and GameStateManager.has_method("get_ship"):
		var ship: Variant = GameStateManager.get_ship()
		return ship != null
	return true # Default to having a ship

func _get_current_world_name() -> String:
	## Get the current world name
	if GameStateManager and GameStateManager.has_method("get_current_world"):
		var world: Variant = GameStateManager.get_current_world()
		if world and world is Object and world.has_method("get_name"):
			return world.get_name()
		elif world is Dictionary:
			return world.get("name", "Unknown")
	return "Fringe World"

func _update_travel_buttons(credits: int, crew_size: int) -> void:
	## Update travel button states based on available credits
	var ship_travel_affordable: bool = credits >= SHIP_TRAVEL_COST
	var commercial_cost: int = crew_size * COMMERCIAL_TRAVEL_COST_PER_CREW
	var commercial_affordable: bool = credits >= commercial_cost
	
	if stay_button:
		stay_button.disabled = false # Stay is always free
	
	if travel_button:
		if has_ship:
			# Ship travel
			if ship_travel_affordable:
				travel_button.text = "Travel to New World (%d credits)" % SHIP_TRAVEL_COST
				travel_button.disabled = false
			else:
				travel_button.text = "Travel (Need %d credits)" % SHIP_TRAVEL_COST
				travel_button.disabled = true
		else:
			# Commercial travel (no ship)
			if commercial_affordable:
				travel_button.text = "Commercial Passage (%d credits)" % commercial_cost
				travel_button.disabled = false
			else:
				travel_button.text = "Passage (Need %d credits)" % commercial_cost
				travel_button.disabled = true

func _setup_ui() -> void:
	## Setup initial UI state
	if next_button:
		next_button.disabled = true
	_update_progress_bar()

func _setup_tooltips() -> void:
	## Setup tooltips for buttons using the existing Tooltip system
	# The built-in tooltip_text property handles basic tooltips
	# For rich tooltips, we use the help button dialogs
	pass

# ============================================================================
# PROGRESS BAR
# ============================================================================

func _update_progress_bar() -> void:
	## Update progress bar based on current phase completion
	if not progress_bar:
		return
	
	# 4 steps: Flee Invasion, Travel Decision, Travel Event, New World Arrival
	var progress := 1.0 # Start at step 1 (flee invasion skipped if not applicable)
	if travel_decision_made:
		progress = 2.0
		if chose_to_travel:
			progress = 3.0 # After travel event
	
	progress_bar.value = progress

# ============================================================================
# HELP SYSTEM
# ============================================================================

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
	rich_text.custom_minimum_size = Vector2(450, 250)
	rich_text.text = content
	rich_text.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_help_dialog.add_child(rich_text)
	
	_help_dialog.popup_centered()

func _on_help_button_pressed() -> void:
	## Show main travel phase help
	_show_help_dialog("Travel Phase (Step 1)", RulesHelpText.get_tooltip("travel_phase"))

func _on_travel_help_pressed() -> void:
	## Show travel decision help
	_show_help_dialog("Travel Decision", RulesHelpText.get_tooltip("travel_decision"))

# ============================================================================
# PHASE MANAGEMENT
# ============================================================================

func setup_phase(data: Variant) -> void:
	## Setup the travel phase with campaign data (legacy support)
	campaign_data = data
	_reset_phase_state()
	_update_status_display()
	_add_log_entry("[color=#4FC3F7]Travel Phase initialized[/color]")

func _reset_phase_state() -> void:
	## Reset phase state for new campaign turn
	travel_decision_made = false
	chose_to_travel = false
	if next_button:
		next_button.disabled = true
	_update_progress_bar()
	
	# Clear travel event details
	if travel_event_details:
		for child in travel_event_details.get_children():
			child.queue_free()

func get_phase_status() -> Dictionary:
	## Get the current phase status
	return {
		"travel_decision_made": travel_decision_made,
		"chose_to_travel": chose_to_travel,
		"can_advance": travel_decision_made
	}

func load_campaign_data(data: Variant) -> void:
	## Load campaign data for this phase (legacy support)
	campaign_data = data
	_update_status_display()

# ============================================================================
# LOG BOOK
# ============================================================================

func _add_log_entry(text: String) -> void:
	## Add an entry to the log book with timestamp
	if not log_book:
		return
	var time_dict := Time.get_time_dict_from_system()
	var timestamp := "%02d:%02d" % [time_dict.hour, time_dict.minute]
	var entry := "[color=#6b7280][%s][/color] %s\n" % [timestamp, text]
	log_book.append_text(entry)
	# Sprint 10.4: Track entries for checkpoint restoration
	_log_entries.append(entry)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_stay_button_pressed() -> void:
	## Handle stay in current location - proceed to World Phase
	travel_decision_made = true
	chose_to_travel = false
	
	_add_log_entry("[color=#4FC3F7]Decided to stay in current location[/color]")
	_add_log_entry("No travel costs incurred. Proceeding to World Phase...")
	
	# Disable travel options after decision
	if stay_button:
		stay_button.disabled = true
		stay_button.text = "✓ Staying in Current Location"
	if travel_button:
		travel_button.disabled = true
	
	_complete_travel_phase()

func _on_travel_button_pressed() -> void:
	## Handle travel to new location with Five Parsecs mechanics
	# Deduct travel cost
	var travel_cost: int = SHIP_TRAVEL_COST if has_ship else _get_commercial_cost()
	
	if GameStateManager and GameStateManager.has_method("modify_credits"):
		GameStateManager.modify_credits(-travel_cost)
		_add_log_entry("[color=#f59e0b]Paid %d credits for travel[/color]" % travel_cost)
	
	travel_decision_made = true
	chose_to_travel = true
	
	_add_log_entry("[color=#f59e0b]Decided to travel to new location[/color]")
	
	# Disable travel options after decision
	if stay_button:
		stay_button.disabled = true
	if travel_button:
		travel_button.disabled = true
		travel_button.text = "✓ Traveling to New World"
	
	# Generate travel event (Core Rules p.70-71)
	_generate_travel_event()
	
	_update_progress_bar()
	
	# Enable next button after travel event is shown
	if next_button:
		next_button.disabled = false

func _get_commercial_cost() -> int:
	## Get commercial travel cost based on crew size
	var crew_size := 4
	if GameStateManager and GameStateManager.has_method("get_crew_size"):
		crew_size = GameStateManager.get_crew_size()
	return crew_size * COMMERCIAL_TRAVEL_COST_PER_CREW

func _complete_travel_phase() -> void:
	## Complete the travel phase and navigate to World Phase
	if next_button:
		next_button.disabled = false
	_update_progress_bar()
	travel_completed.emit()
	_add_log_entry("[color=#10b981]Travel phase complete - ready for World Phase[/color]")

func _on_back_button_pressed() -> void:
	## Handle back button - return to dashboard
	SceneRouter.navigate_to("campaign_turn_controller")

func _on_next_button_pressed() -> void:
	## Handle next button - proceed to World Phase
	if not travel_decision_made:
		_add_log_entry("[color=#ef4444]Please make a travel decision first[/color]")
		return

	# Sprint 10.4: Save checkpoint before leaving Travel Phase
	save_checkpoint()

	phase_completed.emit()
	_add_log_entry("[color=#10b981]Advancing to World Phase (Step 2)[/color]")

	# Navigate to World Phase
	SceneRouter.navigate_to("world_phase")

# ============================================================================
# TRAVEL EVENT GENERATION
# ============================================================================

func _generate_travel_event() -> void:
	## Generate travel event using Five Parsecs tables (p.70-71)
	var dice_manager := get_node_or_null("/root/DiceManager")
	var travel_roll: int = 0
	
	if dice_manager and dice_manager.has_method("roll_dice"):
		travel_roll = dice_manager.roll_dice("Travel Event", "D100")
	else:
		travel_roll = randi_range(1, 100)
	
	_add_log_entry("Starship Travel Event roll: [color=#4FC3F7]%d[/color]" % travel_roll)
	
	var event_result := _process_travel_event_roll(travel_roll)
	_display_travel_event(event_result)

func _process_travel_event_roll(roll: int) -> Dictionary:
	## Process travel event roll using Five Parsecs tables (p.70-71)
	var event := {
		"type": "none",
		"title": "Uneventful Trip",
		"description": "A lot of time playing cards and cleaning guns. You can Repair one damaged item.",
		"effects": []
	}
	
	# Five Parsecs Starship Travel Events Table (D100)
	if roll <= 7: # Asteroids
		event.type = "danger"
		event.title = "Asteroids"
		event.description = "Rocky debris everywhere! Roll to navigate safely or take Hull damage."
		event.effects = ["asteroids"]
	elif roll <= 12: # Navigation trouble
		event.type = "setback"
		event.title = "Navigation Trouble"
		event.description = "Is this place even on the star maps? Lose 1 story point."
		event.effects = ["lose_story_point"]
	elif roll <= 17: # Raided
		event.type = "hostile"
		event.title = "Raided"
		event.description = "Pirates have spotted your vessel! Prepare for potential combat."
		event.effects = ["combat_encounter"]
	elif roll <= 25: # Deep space wreckage
		event.type = "opportunity"
		event.title = "Deep Space Wreckage"
		event.description = "Found an old wreck drifting through space. Roll twice on the Gear Table."
		event.effects = ["gear_rolls"]
	elif roll <= 29: # Drive trouble
		event.type = "setback"
		event.title = "Drive Trouble"
		event.description = "It's not supposed to make that sound. May be grounded next turn."
		event.effects = ["drive_trouble"]
	elif roll <= 38: # Down-time
		event.type = "beneficial"
		event.title = "Down-time"
		event.description = "Select a crew member to earn +1 XP. Repair 1 damaged item for free."
		event.effects = ["xp_bonus", "free_repair"]
	elif roll <= 44: # Distress call
		event.type = "choice"
		event.title = "Distress Call"
		event.description = "'This is Licensed Trader Cyberwolf.' Do you respond?"
		event.effects = ["distress_call"]
	elif roll <= 50: # Patrol ship
		event.type = "neutral"
		event.title = "Patrol Ship"
		event.description = "A Unity patrol vessel hails you. They may confiscate contraband."
		event.effects = ["patrol_inspection"]
	elif roll <= 53: # Cosmic phenomenon
		event.type = "rare"
		event.title = "Cosmic Phenomenon"
		event.description = "A crew member sees something strange... and gains +1 Luck!"
		event.effects = ["luck_bonus"]
	elif roll <= 60: # Escape pod
		event.type = "choice"
		event.title = "Escape Pod"
		event.description = "You find an escape pod drifting through space. Rescue them?"
		event.effects = ["rescue_choice"]
	elif roll <= 66: # Accident
		event.type = "setback"
		event.title = "Accident"
		event.description = "A crew member is injured during maintenance. One item is damaged."
		event.effects = ["injury", "damaged_item"]
	elif roll <= 75: # Travel-time
		event.type = "neutral"
		event.title = "Travel-time"
		event.description = "Long journey under standard drives. Injured crew may rest."
		event.effects = ["rest_time"]
	elif roll <= 85: # Uneventful trip
		event.type = "neutral"
		event.title = "Uneventful Trip"
		event.description = "A lot of time playing cards and cleaning guns. Repair 1 damaged item."
		event.effects = ["free_repair"]
	elif roll <= 91: # Time to reflect
		event.type = "beneficial"
		event.title = "Time to Reflect"
		event.description = "How is the story unfolding? What did it all mean? +1 story point."
		event.effects = ["story_point"]
	elif roll <= 95: # Time to read
		event.type = "beneficial"
		event.title = "Time to Read a Book"
		event.description = "Time for education. Random crew members earn XP."
		event.effects = ["random_xp"]
	else: # Library data
		event.type = "beneficial"
		event.title = "Locked in the Library Data"
		event.description = "You've found information about multiple worlds. Choose your destination!"
		event.effects = ["world_choice"]
	
	return event

func _display_travel_event(event: Dictionary) -> void:
	## Display travel event details in the UI
	if not travel_event_details:
		return
	
	# Clear existing event details
	for child in travel_event_details.get_children():
		child.queue_free()
	
	# Event type color
	var type_color := COLOR_TEXT_SECONDARY
	match event.type:
		"beneficial": type_color = COLOR_EMERALD
		"hostile", "danger": type_color = COLOR_RED
		"setback": type_color = COLOR_AMBER
		"opportunity": type_color = COLOR_BLUE
		"choice": type_color = Color("#8b5cf6") # Purple
	
	# Create event display panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_TERTIARY.r, COLOR_TERTIARY.g, COLOR_TERTIARY.b, 0.8)
	style.border_color = type_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Title
	var title_label := Label.new()
	title_label.text = "🎲 " + event.title
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", type_color)
	vbox.add_child(title_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = event.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(desc_label)
	
	panel.add_child(vbox)
	travel_event_details.add_child(panel)
	
	# Log the event
	_add_log_entry("[color=%s]%s[/color]: %s" % [type_color.to_html(), event.title, event.description])
	
	# Process event effects
	_process_travel_event_effects(event.effects)
	
	# Add resolution button for interactive events
	if event.type in ["hostile", "choice", "danger"]:
		var resolve_button := Button.new()
		resolve_button.text = "Resolve Event"
		resolve_button.custom_minimum_size.y = 40
		resolve_button.pressed.connect(_on_resolve_travel_event.bind(event))
		travel_event_details.add_child(resolve_button)

func _process_travel_event_effects(effects: Array) -> void:
	## Process the effects of a travel event
	for effect in effects:
		match effect:
			"combat_encounter":
				_schedule_combat_encounter()
			"story_point":
				_add_story_point()
			"lose_story_point":
				_remove_story_point()
			"free_repair":
				_add_log_entry("You may repair 1 damaged item for free.")
			"xp_bonus":
				_add_log_entry("Select a crew member to earn +1 XP.")
			"luck_bonus":
				_add_log_entry("A crew member gains +1 Luck!")
			"gear_rolls":
				_add_log_entry("Roll twice on the Gear Table (items may be damaged).")

func _schedule_combat_encounter() -> void:
	## Schedule a combat encounter
	if GameStateManager and GameStateManager.has_method("set_pending_combat"):
		GameStateManager.set_pending_combat({"enabled": true, "source": "travel_encounter"})
	_add_log_entry("[color=#ef4444]Combat encounter scheduled![/color]")

func _add_story_point() -> void:
	## Add a story point
	if GameStateManager and GameStateManager.has_method("modify_story_progress"):
		GameStateManager.modify_story_progress(1)
	_add_log_entry("[color=#8b5cf6]+1 Story Point[/color]")

func _remove_story_point() -> void:
	## Remove a story point
	if GameStateManager and GameStateManager.has_method("modify_story_progress"):
		GameStateManager.modify_story_progress(-1)
	_add_log_entry("[color=#ef4444]-1 Story Point[/color]")

func _on_resolve_travel_event(event: Dictionary) -> void:
	## Resolve a travel event
	match event.type:
		"hostile":
			_resolve_hostile_encounter()
		"choice":
			_resolve_choice_event(event)
		"danger":
			_resolve_danger_event(event)
	
	_add_log_entry("Event resolved: %s" % event.title)

func _resolve_hostile_encounter() -> void:
	## Resolve hostile encounter during travel
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Hostile forces approach! Choose your action:"
	dialog.title = "Hostile Encounter"
	
	dialog.add_button("Fight", false, "fight")
	dialog.add_button("Evade (Roll 5+)", false, "evade")
	dialog.add_button("Negotiate", false, "negotiate")
	
	dialog.custom_action.connect(_on_hostile_encounter_choice)
	add_child(dialog)
	dialog.popup_centered()

func _resolve_choice_event(event: Dictionary) -> void:
	## Resolve choice-based event
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = event.description + "\n\nDo you want to investigate?"
	dialog.title = event.title
	dialog.ok_button_text = "Yes"
	dialog.cancel_button_text = "No"
	
	dialog.confirmed.connect(func(): _add_log_entry("Chose to investigate - roll for results."))
	dialog.canceled.connect(func(): _add_log_entry("Decided to pass - continuing journey."))
	
	add_child(dialog)
	dialog.popup_centered()

func _resolve_danger_event(_event: Dictionary) -> void:
	## Resolve danger event
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "Roll 1D6+Savvy to navigate safely. Need 4+ to succeed."
	dialog.title = "Navigation Check"
	
	add_child(dialog)
	dialog.popup_centered()

func _on_hostile_encounter_choice(action: String) -> void:
	## Handle hostile encounter choice
	match action:
		"fight":
			_schedule_combat_encounter()
			_add_log_entry("Chose to fight - combat encounter scheduled")
		"evade":
			var roll: int = randi_range(1, 6)
			if roll >= 5:
				_add_log_entry("[color=#10b981]Successfully evaded! (Rolled %d)[/color]" % roll)
			else:
				_schedule_combat_encounter()
				_add_log_entry("[color=#ef4444]Evasion failed (Rolled %d) - combat scheduled[/color]" % roll)
		"negotiate":
			var roll: int = randi_range(1, 6)
			if roll >= 5:
				_add_log_entry("[color=#10b981]Negotiation successful! (Rolled %d)[/color]" % roll)
			else:
				_schedule_combat_encounter()
				_add_log_entry("[color=#ef4444]Negotiation failed (Rolled %d) - combat scheduled[/color]" % roll)

# ============================================================================
# SPRINT 10.4: CHECKPOINT STORAGE FOR BIDIRECTIONAL NAVIGATION
# ============================================================================

func save_checkpoint() -> void:
	## Save current Travel Phase state for potential rollback from World Phase
	_checkpoint_data = {
		"travel_decision_made": travel_decision_made,
		"chose_to_travel": chose_to_travel,
		"has_ship": has_ship,
		"log_entries": _log_entries.duplicate(),
		"timestamp": Time.get_unix_time_from_system()
	}

func restore_from_checkpoint() -> void:
	## Restore Travel Phase state from checkpoint (called when rolling back from World Phase)
	if _checkpoint_data.is_empty():
		return

	# Restore state
	travel_decision_made = _checkpoint_data.get("travel_decision_made", false)
	chose_to_travel = _checkpoint_data.get("chose_to_travel", false)
	has_ship = _checkpoint_data.get("has_ship", true)

	# Restore log entries
	_log_entries = _checkpoint_data.get("log_entries", [])
	if log_book:
		log_book.clear()
		for entry in _log_entries:
			log_book.append_text(entry)

	# Update UI state
	_update_ui_after_restore()

func _update_ui_after_restore() -> void:
	## Update UI elements after restoring from checkpoint
	# Update button states based on restored state
	if travel_decision_made:
		if stay_button:
			stay_button.disabled = true
			if not chose_to_travel:
				stay_button.text = "✓ Staying in Current Location"
		if travel_button:
			travel_button.disabled = true
			if chose_to_travel:
				travel_button.text = "✓ Traveling to New World"
		if next_button:
			next_button.disabled = false
	else:
		# Reset to decision-pending state
		_update_status_from_game_state()
		if next_button:
			next_button.disabled = true

	_update_progress_bar()

func has_checkpoint() -> bool:
	## Check if a checkpoint exists
	return not _checkpoint_data.is_empty()

func clear_checkpoint() -> void:
	## Clear saved checkpoint data
	_checkpoint_data = {}
