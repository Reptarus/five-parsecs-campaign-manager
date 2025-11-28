class_name FPCM_BattleCompanionUI
extends Control

## Battlefield Companion User Interface
##
## Clean, production-ready UI for the battlefield companion system.
## Replaces complex tactical battle interfaces with focused assistance tools.
## Designed for tablet and desktop use during tabletop gaming sessions.
##
## Architecture: Phase-based UI with responsive design
## Performance: Optimized for smooth transitions and minimal input latency

# Dependencies - Enhanced with modernized battle system
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const BattlefieldCompanion = preload("res://src/core/battle/BattlefieldCompanion.gd")
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const FPCM_BattlefieldSetupAssistant = preload("res://src/core/battle/BattlefieldSetupAssistant.gd")
const FPCM_SetupSuggestions = preload("res://src/core/battle/SetupSuggestions.gd")
const FPCM_BattlefieldIO = preload("res://src/core/battle/BattlefieldIO.gd")

# Battle assistance component scenes
const InitiativeCalculatorScene = preload("res://src/ui/components/battle/InitiativeCalculator.tscn")
const DeploymentConditionsPanelScene = preload("res://src/ui/components/battle/DeploymentConditionsPanel.tscn")
const EnemyGenerationWizardScene = preload("res://src/ui/components/battle/EnemyGenerationWizard.tscn")
const WeaponTableDisplayScene = preload("res://src/ui/components/battle/WeaponTableDisplay.tscn")
const ObjectiveDisplayScene = preload("res://src/ui/components/battle/ObjectiveDisplay.tscn")
const ReactionDicePanelScene = preload("res://src/ui/components/battle/ReactionDicePanel.tscn")
const MoralePanicTrackerScene = preload("res://src/ui/components/battle/MoralePanicTracker.tscn")
const CombatSituationPanelScene = preload("res://src/ui/components/battle/CombatSituationPanel.tscn")
const BattleJournalScene = preload("res://src/ui/components/battle/BattleJournal.tscn")


# UI state signals - Enhanced with battle manager integration
signal phase_navigation_requested(phase: BattlefieldTypes.BattlePhase)
signal battle_action_triggered(action: String, data: Dictionary)
signal ui_error_occurred(error: String, context: Dictionary)
signal phase_completed() # For battle manager integration
signal dice_roll_requested(pattern: FPCM_DiceSystem.DicePattern, context: String)
signal battle_manager_action(action: String, data: Dictionary)

# Phase-specific UI containers
@onready var main_container: Control = %MainContainer
@onready var phase_indicator: Label = %PhaseIndicator
@onready var phase_progress: ProgressBar = %PhaseProgress

# Phase-specific panels
@onready var setup_panel: Control = %SetupPhasePanel
@onready var deployment_panel: Control = %DeploymentPhasePanel
@onready var tracking_panel: Control = %TrackingPhasePanel
@onready var results_panel: Control = %ResultsPhasePanel

# Navigation and controls
@onready var navigation_container: HBoxContainer = %NavigationContainer
@onready var quick_actions: VBoxContainer = %QuickActions
@onready var status_bar: Control = %StatusBar

# Responsive design elements
@onready var responsive_container: Control = %ResponsiveContainer
@onready var mobile_layout: Control = %MobileLayout
@onready var desktop_layout: Control = %DesktopLayout

# Core system references - Enhanced with modern battle management
var battlefield_companion: BattlefieldCompanion = null
var battle_manager: FPCM_BattleManager = null
var dice_system: FPCM_DiceSystem = null
var battle_state: FPCM_BattleState = null
var current_phase: BattlefieldTypes.BattlePhase = BattlefieldTypes.BattlePhase.SETUP_TERRAIN
var battlefield_setup_assistant: FPCM_BattlefieldSetupAssistant

# Battle assistance component instances
var initiative_calculator: Control
var deployment_conditions_panel: Control
var enemy_generation_wizard: Control
var weapon_table_display: Control
var objective_display: Control
var reaction_dice_panel: Control
var morale_panic_tracker: Control
var combat_situation_panel: Control
var battle_journal: Control


# UI state management
var ui_locked: bool = false
var last_update_time: float = 0.0
var update_frequency: float = 0.1 # 10 FPS for UI updates
var performance_mode: bool = false

func _ready() -> void:
	"""Initialize companion UI with enhanced modern systems"""
	_initialize_core_systems()
	_initialize_battlefield_companion()
	_setup_responsive_design()
	_connect_ui_signals()
	_initialize_phase_ui()
	_setup_dice_integration()
	
	# Setup the assistant and renderer
	battlefield_setup_assistant = FPCM_BattlefieldSetupAssistant.new()
	add_child(battlefield_setup_assistant)

	# This path needs to be correct for your scene structure
	var battlefield_main = get_tree().get_root().get_node_or_null("Root/BattlefieldMain") 
	if battlefield_main:
		var renderer = battlefield_main.get_node_or_null("MarginContainer/VBoxContainer/BattlefieldView/SubViewport/Battlefield/BattlefieldRenderer")
		if renderer:
			battlefield_setup_assistant.set_renderer(renderer)
		else:
			push_error("BattlefieldRenderer node not found.")
	else:
		push_error("BattlefieldMain node not found.")


func _initialize_core_systems() -> void:
	"""Initialize modern battle management systems"""
	# Initialize dice system for battle companion
	dice_system = FPCM_DiceSystem.new()
	dice_system.dice_rolled.connect(_on_dice_rolled)
	
	# Initialize battle manager
	battle_manager = FPCM_BattleManager.new()
	battle_manager.phase_changed.connect(_on_battle_phase_changed)
	battle_manager.ui_transition_requested.connect(_on_ui_transition_requested)
	battle_manager.battle_error.connect(_on_battle_manager_error)
	
	# Register this UI component with battle manager
	battle_manager.register_ui_component("BattleCompanionUI", self)

func _initialize_battlefield_companion() -> void:
	"""Initialize or connect to battlefield companion system"""
	# Check if companion already exists in scene tree
	battlefield_companion = _find_existing_companion()

	if not battlefield_companion:
		# Create new companion instance
		battlefield_companion = BattlefieldCompanion.new()
		add_child(battlefield_companion)

	# Connect companion signals
	_connect_companion_signals()

func _find_existing_companion() -> BattlefieldCompanion:
	"""Find existing battlefield companion in scene tree"""
	var potential_companions := get_tree().get_nodes_in_group("battlefield_companions")

	for companion in potential_companions:
		if companion is BattlefieldCompanion:
			return companion

	return null

func _connect_companion_signals() -> void:
	"""Connect battlefield companion signals to UI handlers"""
	if not battlefield_companion:
		return

	battlefield_companion.phase_changed.connect(_on_phase_changed)
	battlefield_companion.battlefield_ready.connect(_on_battlefield_ready)
	battlefield_companion.battle_started.connect(_on_battle_started)
	battlefield_companion.battle_completed.connect(_on_battle_completed)
	battlefield_companion.companion_error.connect(_on_companion_error)

func _setup_responsive_design() -> void:
	"""Setup responsive design based on screen size"""
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_layout_for_screen_size()

func _on_viewport_resized() -> void:
	"""Handle viewport resize for responsive design"""
	await get_tree().process_frame # Wait for resize to complete
	_update_layout_for_screen_size()

func _update_layout_for_screen_size() -> void:
	"""Update layout based on current screen size"""
	var viewport_size := get_viewport().get_visible_rect().size
	var is_mobile := viewport_size.x < 768 or viewport_size.y < 600

	if is_mobile:
		_apply_mobile_layout()
	else:
		_apply_desktop_layout()

func _apply_mobile_layout() -> void:
	"""Apply mobile-optimized layout"""
	if mobile_layout and desktop_layout:
		mobile_layout.visible = true
		desktop_layout.visible = false

	# Adjust touch targets for mobile
	_adjust_touch_targets(44) # Minimum 44pt touch targets

func _apply_desktop_layout() -> void:
	"""Apply desktop-optimized layout"""
	if mobile_layout and desktop_layout:
		mobile_layout.visible = false
		desktop_layout.visible = true

	# Standard button sizes for desktop
	_adjust_touch_targets(32)

func _adjust_touch_targets(min_size: int) -> void:
	"""Adjust button sizes for accessibility"""
	var buttons := _get_all_buttons()

	for button in buttons:
		var current_size := button.custom_minimum_size
		button.custom_minimum_size = Vector2(
			max(current_size.x, min_size),
			max(current_size.y, min_size)
		)

func _get_all_buttons() -> Array[Button]:
	"""Get all buttons in the UI for accessibility adjustment"""
	var buttons: Array[Button] = []
	_collect_buttons_recursive(self, buttons)
	return buttons

func _collect_buttons_recursive(node: Node, buttons: Array[Button]) -> void:
	"""Recursively collect all buttons in the UI tree"""
	if node is Button:
		buttons.append(node)

	for child in node.get_children():
		_collect_buttons_recursive(child, buttons)

# =====================================================
# PHASE UI MANAGEMENT
# =====================================================

func _initialize_phase_ui() -> void:
	"""Initialize UI for all phases"""
	_setup_terrain_phase_ui()
	_setup_deployment_phase_ui()
	_setup_tracking_phase_ui()
	_setup_results_phase_ui()
	_setup_navigation_ui()

	# Show initial phase
	_show_phase_ui(BattlefieldTypes.BattlePhase.SETUP_TERRAIN)

func _show_phase_ui(phase: BattlefieldTypes.BattlePhase) -> void:
	"""Show UI for specific phase"""
	current_phase = phase

	# Hide all phase panels
	setup_panel.visible = false
	deployment_panel.visible = false
	tracking_panel.visible = false
	results_panel.visible = false

	# Show current phase panel
	match phase:
		BattlefieldTypes.BattlePhase.SETUP_TERRAIN:
			setup_panel.visible = true
			phase_indicator.text = "Battlefield Setup"
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT:
			deployment_panel.visible = true
			phase_indicator.text = "Unit Deployment"
		BattlefieldTypes.BattlePhase.TRACK_BATTLE:
			tracking_panel.visible = true
			phase_indicator.text = "Battle Tracking"
		BattlefieldTypes.BattlePhase.PREPARE_RESULTS:
			results_panel.visible = true
			phase_indicator.text = "Battle Results"

	# Update phase progress
	_update_phase_progress()

	# Update navigation availability
	_update_navigation_ui()

func _update_phase_progress() -> void:
	"""Update phase progress indicator"""
	var phase_values := {
		BattlefieldTypes.BattlePhase.SETUP_TERRAIN: 25,
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT: 50,
		BattlefieldTypes.BattlePhase.TRACK_BATTLE: 75,
		BattlefieldTypes.BattlePhase.PREPARE_RESULTS: 100
	}

	var progress_value_raw = phase_values.get(current_phase)
	var progress_value: int = progress_value_raw if progress_value_raw != null else 0
	if phase_progress:
		phase_progress.value = progress_value

# =====================================================
# TERRAIN SETUP PHASE UI
# =====================================================

func _setup_terrain_phase_ui() -> void:
	"""Setup UI elements for terrain phase"""
	var generate_button := setup_panel.get_node_or_null("GenerateButton")
	var regenerate_button := setup_panel.get_node_or_null("RegenerateButton")
	var confirm_button := setup_panel.get_node_or_null("ConfirmButton")
	var import_button := setup_panel.get_node_or_null("ImportButton")
	var export_button := setup_panel.get_node_or_null("ExportButton")

	if generate_button:
		generate_button.pressed.connect(_on_generate_terrain_pressed)
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_terrain_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_setup_pressed)
	if import_button:
		import_button.pressed.connect(_on_import_pressed)
	if export_button:
		export_button.pressed.connect(_on_export_pressed)

	# Add battle assistance components to setup phase
	var setup_container := setup_panel.get_node_or_null("VBoxContainer")
	if not setup_container:
		setup_container = setup_panel

	# Initiative Calculator
	initiative_calculator = InitiativeCalculatorScene.instantiate()
	setup_container.add_child(initiative_calculator)

	# Deployment Conditions Panel
	deployment_conditions_panel = DeploymentConditionsPanelScene.instantiate()
	setup_container.add_child(deployment_conditions_panel)

	# Enemy Generation Wizard
	enemy_generation_wizard = EnemyGenerationWizardScene.instantiate()
	setup_container.add_child(enemy_generation_wizard)

	# Connect component signals
	if initiative_calculator.has_signal("initiative_calculated"):
		initiative_calculator.initiative_calculated.connect(_on_initiative_calculated)
	if deployment_conditions_panel.has_signal("conditions_rolled"):
		deployment_conditions_panel.conditions_rolled.connect(_on_deployment_conditions_rolled)
	if enemy_generation_wizard.has_signal("enemy_generated"):
		enemy_generation_wizard.enemy_generated.connect(_on_enemy_generated)


func _on_initiative_calculated(seized: bool, roll: int, modifiers: int) -> void:
	"""Handle initiative calculation result"""
	if battle_journal:
		battle_journal.log_initiative(seized, roll + modifiers)


func _on_deployment_conditions_rolled(condition: Dictionary) -> void:
	"""Handle deployment condition roll"""
	if battle_journal:
		battle_journal.log_event("Deployment: %s" % condition.get("name", "Unknown"), condition.get("effect", ""))


func _on_enemy_generated(enemy_data: Dictionary) -> void:
	"""Handle enemy generation"""
	if battle_journal:
		battle_journal.log_event("Enemy Generated", "%s - %d enemies" % [enemy_data.get("type", "Unknown"), enemy_data.get("count", 0)])


func _on_generate_terrain_pressed() -> void:
	"""Handle terrain generation request"""
	if ui_locked:
		return

	_lock_ui("Generating battlefield...")

	# Get current mission data and options
	var options := _get_terrain_generation_options()
	battlefield_companion.generate_battlefield_suggestions(null, options)

func _on_regenerate_terrain_pressed() -> void:
	"""Handle terrain regeneration request"""
	if ui_locked:
		return

	_lock_ui("Regenerating terrain...")
	battlefield_companion.regenerate_terrain_only()

func _on_confirm_setup_pressed() -> void:
	"""Handle setup confirmation"""
	var setup_data := _gather_setup_data()
	var success := battlefield_companion.confirm_battlefield_setup(setup_data)

	if success:
		_advance_to_next_phase()
	else:
		_show_error("Failed to confirm battlefield setup")

func _get_terrain_generation_options() -> Dictionary:
	"""Get terrain generation options from UI"""
	var options := {
		"terrain_density": "standard",
		"complexity": "standard",
		"mission_type": "patrol"
	}

	# Read options from UI controls if they exist
	var density_option := setup_panel.get_node_or_null("TerrainDensity")
	if density_option and density_option and density_option.has_method("get_selected_id"):
		var density_values := ["light", "standard", "heavy"]
		options.terrain_density = density_values[density_option.get_selected_id()]

	return options

func _gather_setup_data() -> Dictionary:
	"""Gather setup data from UI"""
	return {
		"terrain_confirmed": true,
		"setup_time": Time.get_unix_time_from_system(),
		"user_modifications": []
	}

func _display_terrain_suggestions(suggestions: FPCM_SetupSuggestions) -> void:
	"""Display terrain suggestions in UI"""
	var suggestions_container := setup_panel.get_node_or_null("SuggestionsList")
	if not suggestions_container:
		return

	# Clear existing suggestions
	_clear_container(suggestions_container)

	# Add terrain features from SetupSuggestions
	for feature in suggestions.get_terrain_features():
		var suggestion_item := _create_terrain_suggestion_item(feature)
		suggestions_container.add_child(suggestion_item)

	# Show setup summary
	var summary_label := setup_panel.get_node_or_null("SetupSummary")
	if summary_label:
		summary_label.text = suggestions.get_setup_summary()

func _create_terrain_suggestion_item(feature: FPCM_BattlefieldTypes.TerrainFeature) -> Control:
	"""Create UI item for terrain feature"""
	var item := VBoxContainer.new()

	# Title
	var title_label := Label.new()
	title_label.text = feature.title
	title_label.add_theme_stylebox_override("normal", _get_title_style())
	item.add_child(title_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = feature.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_child(desc_label)

	# Properties
	if feature.cover_value > 0:
		var cover_label := Label.new()
		cover_label.text = "Cover Value: +%d" % feature.cover_value
		cover_label.modulate = Color.GREEN
		item.add_child(cover_label)

	if feature.movement_modifier != 1.0:
		var movement_label := Label.new()
		movement_label.text = "Movement: %s" % ("Difficult" if feature.movement_modifier < 1.0 else "Enhanced")
		movement_label.modulate = Color.YELLOW if feature.movement_modifier < 1.0 else Color.CYAN
		item.add_child(movement_label)

	# Special rules
	if feature.special_rules.size() > 0:
		var rules_label := Label.new()
		rules_label.text = "Special: " + ", ".join(feature.special_rules)
		rules_label.modulate = Color.ORANGE
		item.add_child(rules_label)

	return item

# =====================================================
# DEPLOYMENT PHASE UI
# =====================================================

func _setup_deployment_phase_ui() -> void:
	"""Setup UI elements for deployment phase"""
	var start_tracking_button := deployment_panel.get_node_or_null("StartTrackingButton")
	var deployment_guide_button := deployment_panel.get_node_or_null("DeploymentGuideButton")

	if start_tracking_button:
		start_tracking_button.pressed.connect(_on_start_tracking_pressed)
	if deployment_guide_button:
		deployment_guide_button.pressed.connect(_on_show_deployment_guide)

func _on_start_tracking_pressed() -> void:
	"""Handle start tracking request"""
	if ui_locked:
		return

	_lock_ui("Setting up battle tracking...")

	# Get crew and enemy data
	var crew_members := _get_crew_members()
	var enemies := _get_enemy_units()

	var success := battlefield_companion.setup_unit_deployment(crew_members, enemies)

	if success:
		_advance_to_next_phase()
	else:
		_show_error("Failed to setup unit deployment")

func _on_show_deployment_guide() -> void:
	"""Show deployment guidance"""
	var guidance := battlefield_companion.get_deployment_guidance()
	_show_deployment_popup(guidance)

func _show_deployment_popup(guidance: Dictionary) -> void:
	"""Show deployment guidance popup"""
	var popup := AcceptDialog.new()
	popup.title = "Deployment Guidance"

	var content := VBoxContainer.new()

	# Crew zone
	var crew_label := Label.new()
	crew_label.text = "Crew Deployment: " + guidance.crew_zone
	content.add_child(crew_label)

	# Enemy zone
	var enemy_label := Label.new()
	enemy_label.text = "Enemy Deployment: " + guidance.enemy_zone
	content.add_child(enemy_label)

	# Restrictions
	if guidance.restrictions.size() > 0:
		var restrictions_label := Label.new()
		restrictions_label.text = "Restrictions: " + ", ".join(guidance.restrictions)
		content.add_child(restrictions_label)

	popup.add_child(content)
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)

# =====================================================
# BATTLE TRACKING PHASE UI
# =====================================================

func _setup_tracking_phase_ui() -> void:
	"""Setup UI elements for tracking phase"""
	var end_round_button := tracking_panel.get_node_or_null("EndRoundButton")
	var random_event_button := tracking_panel.get_node_or_null("RandomEventButton")
	var end_battle_button := tracking_panel.get_node_or_null("EndBattleButton")

	if end_round_button:
		end_round_button.pressed.connect(_on_end_round_pressed)
	if random_event_button:
		random_event_button.pressed.connect(_on_random_event_pressed)
	if end_battle_button:
		end_battle_button.pressed.connect(_on_end_battle_pressed)

	# Add battle assistance components to tracking phase
	var tracking_container := tracking_panel.get_node_or_null("VBoxContainer")
	if not tracking_container:
		tracking_container = tracking_panel

	# Weapon Table Display (reference)
	weapon_table_display = WeaponTableDisplayScene.instantiate()
	tracking_container.add_child(weapon_table_display)

	# Objective Display
	objective_display = ObjectiveDisplayScene.instantiate()
	tracking_container.add_child(objective_display)

	# Reaction Dice Panel
	reaction_dice_panel = ReactionDicePanelScene.instantiate()
	tracking_container.add_child(reaction_dice_panel)

	# Morale Panic Tracker
	morale_panic_tracker = MoralePanicTrackerScene.instantiate()
	tracking_container.add_child(morale_panic_tracker)

	# Combat Situation Panel
	combat_situation_panel = CombatSituationPanelScene.instantiate()
	tracking_container.add_child(combat_situation_panel)

	# Connect tracking phase component signals
	if reaction_dice_panel.has_signal("reaction_spent"):
		reaction_dice_panel.reaction_spent.connect(_on_reaction_spent)
	if morale_panic_tracker.has_signal("morale_checked"):
		morale_panic_tracker.morale_checked.connect(_on_morale_checked)
	if morale_panic_tracker.has_signal("enemies_fled"):
		morale_panic_tracker.enemies_fled.connect(_on_enemies_fled)
	if combat_situation_panel.has_signal("modifiers_changed"):
		combat_situation_panel.modifiers_changed.connect(_on_combat_modifiers_changed)


func _on_reaction_spent(character_name: String, success: bool) -> void:
	"""Handle reaction dice spent"""
	if battle_journal:
		var result := "success" if success else "failed"
		battle_journal.log_action(character_name, "Reaction (%s)" % result)


func _on_morale_checked(result: String, roll: int) -> void:
	"""Handle morale check result"""
	if battle_journal:
		battle_journal.log_morale(result)


func _on_enemies_fled(count: int) -> void:
	"""Handle enemies fleeing from morale"""
	if battle_journal:
		battle_journal.log_morale("Panic", count)


func _on_combat_modifiers_changed(total: int) -> void:
	"""Handle combat modifier changes - for UI updates only"""
	pass  # Modifier display handled by component itself


func _on_end_round_pressed() -> void:
	"""Handle end round request"""
	if battlefield_companion and battlefield_companion.battle_tracker:
		battlefield_companion.battle_tracker.end_round()

	# Log new round to journal
	if battle_journal:
		battle_journal.new_round()

func _on_random_event_pressed() -> void:
	"""Handle manual random event trigger"""
	if battlefield_companion and battlefield_companion.battle_tracker:
		battlefield_companion.battle_tracker.trigger_manual_event(0, "Manually triggered event")

func _on_end_battle_pressed() -> void:
	"""Handle end battle request"""
	var victory_team: String = await _determine_victory_team()
	var success := battlefield_companion.end_battle_tracking(victory_team)

	if success:
		_advance_to_next_phase()

func _determine_victory_team() -> String:
	"""Determine victory team through UI"""
	var victory_dialog := _create_victory_dialog()
	add_child(victory_dialog)
	victory_dialog.popup_centered()

	var result: String = await victory_dialog.custom_action
	victory_dialog.queue_free()

	return result

func _create_victory_dialog() -> AcceptDialog:
	"""Create victory determination dialog"""
	var dialog := AcceptDialog.new()
	dialog.title = "Battle Outcome"

	var content := VBoxContainer.new()
	var label := Label.new()
	label.text = "Who achieved victory?"
	content.add_child(label)

	var crew_button := Button.new()
	crew_button.text = "Crew Victory"
	crew_button.pressed.connect(func(): dialog.custom_action.emit("crew"))
	content.add_child(crew_button)

	var enemy_button := Button.new()
	enemy_button.text = "Enemy Victory"
	enemy_button.pressed.connect(func(): dialog.custom_action.emit("enemy"))
	content.add_child(enemy_button)

	var draw_button := Button.new()
	draw_button.text = "Draw"
	draw_button.pressed.connect(func(): dialog.custom_action.emit("draw"))
	content.add_child(draw_button)

	dialog.add_child(content)
	dialog.add_user_signal("custom_action", [ {"name": "result", "type": TYPE_STRING}])

	return dialog

# =====================================================
# RESULTS PHASE UI
# =====================================================

func _setup_results_phase_ui() -> void:
	"""Setup UI elements for results phase"""
	var process_results_button := results_panel.get_node_or_null("ProcessResultsButton")
	var continue_campaign_button := results_panel.get_node_or_null("ContinueCampaignButton")

	if process_results_button:
		process_results_button.pressed.connect(_on_process_results_pressed)
	if continue_campaign_button:
		continue_campaign_button.pressed.connect(_on_continue_campaign_pressed)

	# Add battle assistance components to results phase
	var results_container := results_panel.get_node_or_null("VBoxContainer")
	if not results_container:
		results_container = results_panel

	# Battle Journal (narrative review of battle)
	battle_journal = BattleJournalScene.instantiate()
	results_container.add_child(battle_journal)

func _on_process_results_pressed() -> void:
	"""Handle results processing request"""
	if ui_locked:
		return

	_lock_ui("Processing battle results...")
	var results := battlefield_companion.process_battle_results()
	_display_battle_results(results)

func _on_continue_campaign_pressed() -> void:
	"""Handle continue to campaign request"""
	var completion_data := battlefield_companion.complete_battle_companion()

	# Add battle assistance data to completion
	if battle_journal:
		completion_data["journal_summary"] = battle_journal.get_summary()
		completion_data["journal_entries"] = battle_journal.get_entries()

	if morale_panic_tracker and morale_panic_tracker.has_method("get_fled_count"):
		completion_data["enemies_fled"] = morale_panic_tracker.get_fled_count()

	if reaction_dice_panel and reaction_dice_panel.has_method("get_spent_reactions"):
		completion_data["reactions_spent"] = reaction_dice_panel.get_spent_reactions()

	battle_action_triggered.emit("continue_campaign", completion_data)

func _display_battle_results(results: BattlefieldTypes.BattleResults) -> void:
	"""Display battle results in UI"""
	var results_container := results_panel.get_node_or_null("ResultsDisplay")
	if not results_container:
		return

	# Clear existing results
	_clear_container(results_container)

	# Victory status
	var victory_label := Label.new()
	victory_label.text = "Victory: %s" % ("Yes" if results.victory else "No")
	victory_label.add_theme_color_override("font_color", Color.GREEN if results.victory else Color.RED)
	results_container.add_child(victory_label)

	# Rounds fought
	var rounds_label := Label.new()
	rounds_label.text = "Rounds Fought: %d" % results.rounds_fought
	results_container.add_child(rounds_label)

	# Casualties
	if results.casualties.size() > 0:
		var casualties_header := Label.new()
		casualties_header.text = "Casualties:"
		casualties_header.add_theme_color_override("font_color", Color.RED)
		results_container.add_child(casualties_header)

		for casualty in results.casualties:
			var casualty_label := Label.new()
			casualty_label.text = "- %s (%s)" % [casualty.name, casualty.type]
			results_container.add_child(casualty_label)

	# Injuries
	if results.injuries.size() > 0:
		var injuries_header := Label.new()
		injuries_header.text = "Injuries:"
		injuries_header.add_theme_color_override("font_color", Color.YELLOW)
		results_container.add_child(injuries_header)

		for injury in results.injuries:
			var injury_label := Label.new()
			injury_label.text = "- %s: %s (%d rounds recovery)" % [injury.name, injury.injury, injury.recovery_rounds]
			results_container.add_child(injury_label)

	# Experience
	if results.experience_gained.size() > 0:
		var exp_header := Label.new()
		exp_header.text = "Experience Gained:"
		exp_header.add_theme_color_override("font_color", Color.CYAN)
		results_container.add_child(exp_header)

		for crew_member in results.experience_gained.keys():
			var exp_label := Label.new()
			exp_label.text = "- %s: %d XP" % [crew_member, results.experience_gained[crew_member]]
			results_container.add_child(exp_label)

	# Loot opportunities
	if results.loot_opportunities.size() > 0:
		var loot_header := Label.new()
		loot_header.text = "Loot Opportunities:"
		loot_header.add_theme_color_override("font_color", Color.GREEN)
		results_container.add_child(loot_header)

		for loot in results.loot_opportunities:
			var loot_label := Label.new()
			loot_label.text = "- %s" % loot
			results_container.add_child(loot_label)

# =====================================================
# NAVIGATION AND CONTROLS
# =====================================================

func _setup_navigation_ui() -> void:
	"""Setup navigation controls"""
	var prev_button := navigation_container.get_node_or_null("PreviousPhaseButton")
	var next_button := navigation_container.get_node_or_null("NextPhaseButton")

	if prev_button:
		prev_button.pressed.connect(_on_previous_phase_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_phase_pressed)

func _update_navigation_ui() -> void:
	"""Update navigation button availability"""
	var prev_button := navigation_container.get_node_or_null("PreviousPhaseButton")
	var next_button := navigation_container.get_node_or_null("NextPhaseButton")

	if prev_button:
		prev_button.disabled = current_phase == BattlefieldTypes.BattlePhase.SETUP_TERRAIN

	if next_button:
		var can_advance := battlefield_companion._can_advance_phase() if battlefield_companion else false
		next_button.disabled = not can_advance

func _on_previous_phase_pressed() -> void:
	"""Handle previous phase navigation"""
	var prev_phase_map := {
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT: BattlefieldTypes.BattlePhase.SETUP_TERRAIN,
		BattlefieldTypes.BattlePhase.TRACK_BATTLE: BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT,
		BattlefieldTypes.BattlePhase.PREPARE_RESULTS: BattlefieldTypes.BattlePhase.TRACK_BATTLE
	}

	var prev_phase_raw = prev_phase_map.get(current_phase)
	if prev_phase_raw != null:
		var prev_phase: BattlefieldTypes.BattlePhase = prev_phase_raw
		phase_navigation_requested.emit(prev_phase)

func _on_next_phase_pressed() -> void:
	"""Handle next phase navigation"""
	_advance_to_next_phase()

func _advance_to_next_phase() -> void:
	"""Advance to next phase in workflow"""
	if battlefield_companion:
		battlefield_companion.force_phase_advance()

# =====================================================
# EVENT HANDLERS
# =====================================================

func _on_phase_changed(old_phase: BattlefieldTypes.BattlePhase, new_phase: BattlefieldTypes.BattlePhase) -> void:
	"""Handle phase change from companion"""
	_unlock_ui()
	_show_phase_ui(new_phase)

func _on_battlefield_ready(battlefield_data: BattlefieldTypes.BattlefieldData) -> void:
	"""Handle battlefield generation completion"""
	_unlock_ui()
	# Could update UI with battlefield visualization

func _on_battle_started(initial_state: Dictionary) -> void:
	"""Handle battle start"""
	_unlock_ui()
	# Update tracking UI with initial battle state

	# Initialize journal with battle objective
	if battle_journal:
		var objective_name: String = initial_state.get("objective", "")
		battle_journal.start_battle(objective_name)


func _on_battle_completed(results: BattlefieldTypes.BattleResults) -> void:
	"""Handle battle completion"""
	_unlock_ui()
	_display_battle_results(results)

	# Log battle outcome to journal
	if battle_journal:
		var reason: String = results.get("reason") if results.get("reason") else ""
		if results.victory:
			battle_journal.log_victory(reason)
		else:
			battle_journal.log_defeat(reason)

func _on_companion_error(error_code: String, context: Dictionary) -> void:
	"""Handle companion errors"""
	_unlock_ui()
	_show_error("Companion Error: %s" % error_code)

func _connect_ui_signals() -> void:
	"""Connect UI-specific signals"""
	if has_signal("visibility_changed"):
		visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	"""Handle visibility changes for resource management"""
	if visible:
		# Resume any paused operations
		pass
	else:
		# Pause non-essential operations
		pass

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _lock_ui(message: String = "Processing...") -> void:
	"""Lock UI during processing"""
	ui_locked = true
	_update_status_bar(message)

func _unlock_ui() -> void:
	"""Unlock UI after processing"""
	ui_locked = false
	_update_status_bar("Ready")

func _update_status_bar(message: String) -> void:
	"""Update status bar message"""
	var status_label := status_bar.get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = message

func _show_error(message: String) -> void:
	"""Show error message to user"""
	var error_dialog := AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Error"
	add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(error_dialog.queue_free)

	ui_error_occurred.emit(message, {})

func _clear_container(container: Node) -> void:
	"""Clear all children from container"""
	for child in container.get_children():
		child.queue_free()

func _get_title_style() -> StyleBox:
	"""Get title style for suggestion items"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 3
	style.border_color = Color.CYAN
	return style

func _get_crew_members() -> Array:
	"""Get crew members for deployment"""
	# This would integrate with your campaign manager
	return []

func _get_enemy_units() -> Array:
	"""Get enemy units for deployment"""
	# This would integrate with your mission system
	return []

# =====================================================
# ACCESSIBILITY AND PERFORMANCE
# =====================================================

func _input(event: InputEvent) -> void:
	"""Handle input events for accessibility"""
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			match key_event.keycode:
				KEY_TAB:
					_handle_tab_navigation(key_event.shift_pressed)
				KEY_ESCAPE:
					_handle_escape()
				KEY_ENTER:
					_handle_enter()

func _handle_tab_navigation(reverse: bool) -> void:
	"""Handle tab navigation for accessibility"""
	var focusable_nodes := _get_focusable_nodes()
	if focusable_nodes.is_empty():
		return

	var current_focus := get_viewport().gui_get_focus_owner()
	var current_index := focusable_nodes.find(current_focus)

	if reverse:
		current_index = (current_index - 1) % focusable_nodes.size()
	else:
		current_index = (current_index + 1) % focusable_nodes.size()

	focusable_nodes[current_index].grab_focus()

func _get_focusable_nodes() -> Array[Control]:
	"""Get all focusable nodes for keyboard navigation"""
	var focusable: Array[Control] = []
	_collect_focusable_recursive(self, focusable)
	return focusable

func _collect_focusable_recursive(node: Node, focusable: Array[Control]) -> void:
	"""Recursively collect focusable controls"""
	if node is Control and node.visible and node.focus_mode != Control.FOCUS_NONE:
		focusable.append(node)

	for child in node.get_children():
		_collect_focusable_recursive(child, focusable)

func _handle_escape() -> void:
	"""Handle escape key for navigation"""
	# Could implement cancel/back functionality
	pass

func _handle_enter() -> void:
	"""Handle enter key for activation"""
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button:
		focused.pressed.emit()

func set_performance_mode(enabled: bool) -> void:
	"""Enable/disable performance mode for lower-end devices"""
	performance_mode = enabled

	if enabled:
		update_frequency = 0.2 # 5 FPS for performance mode
		# Disable non-essential visual effects
	else:
		update_frequency = 0.1 # 10 FPS for normal mode
		# Enable full visual effects

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

# =====================================================
# ENHANCED BATTLE SYSTEM INTEGRATION
# =====================================================

func _setup_dice_integration() -> void:
	"""Setup dice system integration with quick action buttons"""
	if not quick_actions:
		return
	
	# Add dice roll quick action buttons
	var dice_section := VBoxContainer.new()
	dice_section.name = "DiceSection"
	
	var dice_label := Label.new()
	dice_label.text = "Quick Dice Rolls"
	dice_label.add_theme_font_size_override("font_size", 14)
	dice_section.add_child(dice_label)
	
	# Common battle dice rolls
	var dice_buttons: Array[Dictionary] = [
		{"text": "D6", "pattern": FPCM_DiceSystem.DicePattern.D6, "context": "Quick D6 Roll"},
		{"text": "D10", "pattern": FPCM_DiceSystem.DicePattern.D10, "context": "Quick D10 Roll"},
		{"text": "2D6", "pattern": FPCM_DiceSystem.DicePattern.COMBAT, "context": "Combat Roll"},
		{"text": "Reaction", "pattern": FPCM_DiceSystem.DicePattern.REACTION, "context": "Reaction Test"}
	]
	
	for button_data: Dictionary in dice_buttons:
		var button := Button.new()
		button.text = button_data.text
		button.custom_minimum_size = Vector2(60, 32)
		button.pressed.connect(_on_quick_dice_roll.bind(button_data.pattern, button_data.context))
		dice_section.add_child(button)
	
	quick_actions.add_child(dice_section)

func _on_quick_dice_roll(pattern: FPCM_DiceSystem.DicePattern, context: String) -> void:
	"""Handle quick dice roll requests"""
	if dice_system:
		var result: FPCM_DiceSystem.DiceRoll = dice_system.roll_dice(pattern, context)
		_display_dice_result(result)
	
	# Emit signal for other systems
	dice_roll_requested.emit(pattern, context)

func _display_dice_result(result: FPCM_DiceSystem.DiceRoll) -> void:
	"""Display dice roll result in status bar or dedicated area"""
	if status_bar and status_bar.has_method("show_message"):
		var message: String = "%s: %s" % [result.context, result.get_simple_text()]
		status_bar.show_message(message, 3.0)
	else:
		print("Dice Roll - %s: %s" % [result.context, result.get_display_text()])

func _on_dice_rolled(result: FPCM_DiceSystem.DiceRoll) -> void:
	"""Handle dice roll completion from dice system"""
	_display_dice_result(result)

func _on_battle_phase_changed(old_phase: FPCM_BattleManager.BattleManagerPhase, new_phase: FPCM_BattleManager.BattleManagerPhase) -> void:
	"""Handle battle manager phase changes"""
	# Map battle manager phases to companion UI phases
	var ui_phase: BattlefieldTypes.BattlePhase
	
	match new_phase:
		FPCM_BattleManager.BattleManagerPhase.PRE_BATTLE:
			ui_phase = BattlefieldTypes.BattlePhase.SETUP_TERRAIN
		FPCM_BattleManager.BattleManagerPhase.TACTICAL_BATTLE:
			ui_phase = BattlefieldTypes.BattlePhase.TRACK_BATTLE
		FPCM_BattleManager.BattleManagerPhase.BATTLE_RESOLUTION:
			ui_phase = BattlefieldTypes.BattlePhase.TRACK_BATTLE
		FPCM_BattleManager.BattleManagerPhase.POST_BATTLE:
			ui_phase = BattlefieldTypes.BattlePhase.PREPARE_RESULTS
		_:
			ui_phase = BattlefieldTypes.BattlePhase.SETUP_TERRAIN
	
	_show_phase_ui(ui_phase)

func _on_ui_transition_requested(target_ui: String, data: Dictionary) -> void:
	"""Handle UI transition requests from battle manager"""
	if target_ui == "BattleCompanionUI":
		# Update battle state if provided
		if "battle_state" in data:
			battle_state = data.battle_state
		
		# Show appropriate phase
		if "phase" in data:
			var manager_phase: FPCM_BattleManager.BattleManagerPhase = data.phase
			_on_battle_phase_changed(FPCM_BattleManager.BattleManagerPhase.NONE, manager_phase)

func _on_battle_manager_error(error_code: String, context: Dictionary) -> void:
	"""Handle battle manager errors"""
	var error_message: String = "Battle Manager Error: %s" % error_code
	ui_error_occurred.emit(error_message, context)
	
	if status_bar and status_bar.has_method("show_error"):
		status_bar.show_error(error_message, 5.0)
	else:
		print("ERROR: %s - %s" % [error_code, str(context)])

func setup_battle(mission_data: Resource, crew_members: Array[Resource], enemy_forces: Array[Resource]) -> bool:
	"""Setup companion UI for a new battle using modern battle manager"""
	if not battle_manager:
		ui_error_occurred.emit("BATTLE_MANAGER_MISSING", {})
		return false
	
	# Initialize battle through battle manager
	var success: bool = battle_manager.initialize_battle(mission_data, crew_members, enemy_forces)
	
	if success:
		battle_state = battle_manager.battle_state
		# UI will be updated through battle manager signals
	
	return success

func complete_current_phase() -> void:
	"""Complete current phase and advance battle"""
	if battle_manager:
		battle_manager.advance_phase()
	
	# Emit completion signal for any direct listeners
	phase_completed.emit()

func get_battle_status() -> Dictionary:
	"""Get current battle status from modern systems"""
	var status: Dictionary = {}
	
	if battle_manager:
		status = battle_manager.get_battle_status()
	
	# Add companion UI specific status
	status["ui_phase"] = current_phase
	status["ui_locked"] = ui_locked
	status["performance_mode"] = performance_mode
	
	return status

func set_battle_state(new_state: FPCM_BattleState) -> void:
	"""Set battle state and update UI accordingly"""
	battle_state = new_state
	
	if battle_state:
		# Update UI based on battle state
		_update_ui_from_battle_state()

func _update_ui_from_battle_state() -> void:
	"""Update UI elements based on current battle state"""
	if not battle_state:
		return
	
	# Update phase progress
	var status: Dictionary = battle_state.get_battlefield_status()
	if phase_progress:
		# Calculate progress based on round number (rough estimate)
		var progress_value: float = min(float(status.get("round", 0)) / 6.0, 1.0)
		phase_progress.value = progress_value
	
	# Update phase indicator with battle info
	if phase_indicator:
		var round_text: String = "Round %d" % status.get("round", 0)
		phase_indicator.text = "%s - %s" % [phase_indicator.text, round_text]

## Emergency cleanup for battle manager integration
func _exit_tree() -> void:
	"""Cleanup when UI is removed from scene"""
	if battle_manager:
		battle_manager.unregister_ui_component("BattleCompanionUI")
	
	# Disconnect dice system signals
	if dice_system and dice_system.dice_rolled.is_connected(_on_dice_rolled):
		dice_system.dice_rolled.disconnect(_on_dice_rolled)

func _on_import_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.5pbf", "Five Parsecs Battlefield")
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_file_imported)
	file_dialog.popup_centered()

func _on_file_imported(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		_show_error("Failed to open imported file.")
		return
	var content = file.get_as_text()
	file.close()
	var context = FPCM_BattlefieldIO.import_battlefield(content)
	if context.is_empty():
		_show_error("Invalid battlefield blueprint file.")
		return
	
	# Use the imported context to generate the battlefield
	battlefield_setup_assistant.generate_and_render_battlefield(context)

func _on_export_pressed() -> void:
	var grid_data = battlefield_setup_assistant.get_last_generated_grid()
	if grid_data.is_empty():
		_show_error("No battlefield has been generated to export.")
		return

	var context = battlefield_setup_assistant.get_last_generation_context()
	var blueprint_string = FPCM_BattlefieldIO.export_battlefield(context, grid_data.grid)

	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.5pbf", "Five Parsecs Battlefield")
	add_child(file_dialog)
	file_dialog.file_selected.connect(func(path):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(blueprint_string)
	)
	file_dialog.popup_centered()
