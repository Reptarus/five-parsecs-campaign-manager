class_name FPCM_TacticalBattleUI
extends Control

## Tactical Battle UI - Five Parsecs Positioning and Movement
##
## Provides tactical turn-based combat with:
	## - Grid-based positioning system
## - Line of sight calculation
## - Cover and elevation mechanics
## - Five Parsecs combat rules
## - Dice integration for all rolls

signal tactical_battle_completed(battle_result: BattleResult)
signal return_to_battle_resolution()

const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")
const TierSelectionPanelClass = preload("res://src/ui/components/battle/TierSelectionPanel.gd")
const PreBattleChecklistClass = preload("res://src/ui/components/battle/PreBattleChecklist.gd")
# LOG_ONLY tier component scenes (Sprint 3)
const BattleJournalScene = preload("res://src/ui/components/battle/BattleJournal.tscn")
const DiceDashboardScene = preload("res://src/ui/components/battle/DiceDashboard.tscn")
const CombatCalculatorScene = preload("res://src/ui/components/battle/CombatCalculator.tscn")
const CharacterStatusCardScene = preload("res://src/ui/components/battle/CharacterStatusCard.tscn")
const BattleRoundHUDClass = preload("res://src/ui/components/battle/BattleRoundHUD.gd")
# ASSISTED tier component scenes/scripts (Sprint 4)
const MoralePanicTrackerScene = preload("res://src/ui/components/battle/MoralePanicTracker.tscn")
const ActivationTrackerScene = preload("res://src/ui/components/battle/ActivationTrackerPanel.tscn")
const DeploymentConditionsScene = preload("res://src/ui/components/battle/DeploymentConditionsPanel.tscn")
const InitiativeCalculatorScene = preload("res://src/ui/components/battle/InitiativeCalculator.tscn")
const ObjectiveDisplayScene = preload("res://src/ui/components/battle/ObjectiveDisplay.tscn")
const ReactionDicePanelScene = preload("res://src/ui/components/battle/ReactionDicePanel.tscn")
const EventResolutionPanelClass = preload("res://src/ui/components/battle/EventResolutionPanel.gd")
const VictoryProgressPanelClass = preload("res://src/ui/components/battle/VictoryProgressPanel.gd")
# FULL_ORACLE tier component scenes/scripts (Sprint 5)
const EnemyIntentPanelClass = preload("res://src/ui/components/battle/EnemyIntentPanel.gd")
const EnemyGenerationWizardScene = preload("res://src/ui/components/battle/EnemyGenerationWizard.tscn")
# Always-visible components (Sprint 6)
const CheatSheetPanelClass = preload("res://src/ui/components/battle/CheatSheetPanel.gd")
const WeaponTableDisplayScene = preload("res://src/ui/components/battle/WeaponTableDisplay.tscn")
const CombatSituationPanelScene = preload("res://src/ui/components/battle/CombatSituationPanel.tscn")
const DualInputRollClass = preload("res://src/ui/components/battle/DualInputRoll.gd")
const BattlefieldGeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")
# Compendium DLC preloads
const EscalatingBattlesManagerRef = preload("res://src/core/managers/EscalatingBattlesManager.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const NoMinisCombatPanelClass = preload("res://src/ui/components/battle/NoMinisCombatPanel.gd")
const StealthMissionPanelClass = preload("res://src/ui/components/battle/StealthMissionPanel.gd")
# GlobalEnums available as autoload singleton

# UI Nodes — three-zone tabbed companion layout
@onready var return_button: Button = %ReturnButton
@onready var auto_resolve_button: Button = %AutoResolveButton
@onready var title_label: Label = %TitleLabel
@onready var tier_badge: Label = %TierBadge

# Zone containers (components instanced in Sprints 3-6)
@onready var left_tabs: TabContainer = %LeftTabs
@onready var crew_content: VBoxContainer = %CrewContent
@onready var units_content: VBoxContainer = %UnitsContent
@onready var enemies_content: VBoxContainer = %EnemiesContent
@onready var battlefield_grid_panel: PanelContainer = %BattlefieldGridPanel
@onready var center_tabs: TabContainer = %CenterTabs
@onready var battle_log_content: VBoxContainer = %BattleLogContent
@onready var tracking_content: VBoxContainer = %TrackingContent
@onready var events_content: VBoxContainer = %EventsContent
@onready var right_tabs: TabContainer = %RightTabs
@onready var tools_content: VBoxContainer = %ToolsContent
@onready var reference_content: VBoxContainer = %ReferenceContent
@onready var setup_content: VBoxContainer = %SetupContent

# Bottom bar
@onready var turn_indicator: Label = %TurnIndicator
@onready var action_buttons: HBoxContainer = %PhaseButtonsContainer
@onready var end_turn_button: Button = %EndTurnButton

# Fallback log (replaced by BattleJournal component in Sprint 3)
@onready var battle_log: RichTextLabel = %FallbackLog

# Overlay nodes (for tier selection, checklists, popups)
@onready var overlay_bg: ColorRect = $OverlayLayer/OverlayBackground
@onready var overlay_center: CenterContainer = $OverlayLayer/OverlayCenter
@onready var overlay_content: VBoxContainer = $OverlayLayer/OverlayCenter/OverlayContent

# Reaction Dice UI (handled by ReactionDicePanel component in Sprint 4)
var dice_pool_display: HBoxContainer = null
var character_assignment_list: VBoxContainer = null
var confirm_assignments_button: Button = null

# Core Systems
var battlefield_manager: BattlefieldManager
var dice_manager: Node = null
var alpha_manager: Node = null
var battle_tracker: Node = null  # For reaction economy tracking

## Sprint 11.4: BattleRoundTracker integration for phase-based combat
var round_tracker: Node = null  # BattleRoundTracker instance for Five Parsecs combat rounds
var _round_tracker_connected: bool = false

# Tier controller for component visibility (wired in Sprint 2)
var tier_controller: Resource = null  # FPCM_BattleTierController instance

# LOG_ONLY component instances (Sprint 3)
var battle_journal: PanelContainer = null
var dice_dashboard: Control = null
var combat_calculator: Control = null
var battle_round_hud: Control = null
var character_cards: Array = []  # Array of CharacterStatusCard instances

# ASSISTED component instances (Sprint 4)
var morale_tracker: PanelContainer = null
var activation_tracker: PanelContainer = null
var deployment_conditions: PanelContainer = null
var initiative_calculator: PanelContainer = null
var objective_display: PanelContainer = null
var reaction_dice_panel: PanelContainer = null
var event_resolution: PanelContainer = null
var victory_progress: PanelContainer = null

# FULL_ORACLE component instances (Sprint 5)
var enemy_intent_panel: PanelContainer = null
var enemy_generation_wizard: PanelContainer = null

# Always-visible component instances (Sprint 6)
var cheat_sheet_panel: PanelContainer = null
var weapon_table_display: PanelContainer = null
var combat_situation_panel: PanelContainer = null
var dual_input_roll: HBoxContainer = null

# Compendium DLC panel instances
var no_minis_combat_panel: PanelContainer = null
var stealth_mission_panel: PanelContainer = null

# Battlefield Setup tab state
var _battlefield_generator: FPCM_BattlefieldGenerator = null
var _current_terrain_theme: String = ""
var _stored_mission_data: Variant = null
var _terrain_section_start_index: int = -1
var _terrain_section_end_index: int = -1

# Battle State
var crew_units: Array[TacticalUnit] = []
var enemy_units: Array[TacticalUnit] = []
var all_units: Array[TacticalUnit] = []
var current_turn: int = 0
var current_unit_index: int = 0
var selected_unit: TacticalUnit = null
var battle_phase: String = "deployment" # deployment, combat, resolution
var turn_phase: String = "movement" # movement, action, resolution

# DLC Escalating Battles tracking (Compendium pp.46-48)
var _dlc_ai_type: String = ""
var _dlc_escalation_count: int = 0
var _dlc_escalation_history: Array[String] = []  # Track for variation mode

# Grid and positioning
var grid_size: Vector2i = Vector2i(20, 20)
var _cell_size: int = 32
var deployment_zones: Dictionary = {}

# Battle Result
class BattleResult:
	var victory: bool = false
	var crew_casualties: Array = []
	var crew_injuries: Array = []
	var rounds_fought: int = 0

func _ready() -> void:
	_initialize_managers()
	_setup_battlefield()
	_connect_signals()
	_setup_ui()

func _initialize_managers() -> void:
	## Initialize manager references
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null
	battle_tracker = get_node("/root/BattleTracker") if has_node("/root/BattleTracker") else null

	# Create battlefield systems
	battlefield_manager = BattlefieldManager.new()
	add_child(battlefield_manager)

func _setup_battlefield() -> void:
	## Setup the tactical battlefield
	battlefield_manager.battlefield_width = grid_size.x
	battlefield_manager.battlefield_height = grid_size.y
	battlefield_manager._setup_battlefield()

	# Generate terrain and cover
	_generate_battlefield_terrain()
	_setup_deployment_zones()

func _generate_battlefield_terrain() -> void:
	## Generate terrain using Five Parsecs rules
	# Use dice to determine terrain features
	var terrain_roll = _roll_dice("Terrain Generation", "D6")
	var num_features = terrain_roll + 2 # 3-8 terrain features

	_log_message("Generating battlefield with %d terrain features..." % num_features, UIColors.COLOR_CYAN)

	for i: int in range(num_features):
		var x = randi_range(2, grid_size.x - 3)
		var y = randi_range(2, grid_size.y - 3)
		var feature_type = _roll_dice("Terrain Type", "D6")

		match feature_type:
			1, 2: # Cover (walls, rocks)
				_place_cover_feature(x, y)
			3, 4: # Elevation (hills, platforms)
				_place_elevation_feature(x, y)
			5: # Difficult terrain (debris, mud)
				_place_difficult_terrain(x, y)
			6: # Special feature (determined by mission)
				_place_special_feature(x, y)

func _place_cover_feature(x: int, y: int) -> void:
	## Place a cover feature on the battlefield
	# Create L-shaped or straight cover
	var cover_pattern = _roll_dice("Cover Pattern", "D6")
	var positions: Array = []

	match cover_pattern:
		1, 2, 3: # Straight line (horizontal)
			for i: int in range(3):
				if x + i < grid_size.x:
					positions.append(Vector2i(x + i, y))
		4, 5: # Straight line (vertical)
			for i: int in range(3):
				if y + i < grid_size.y:
					positions.append(Vector2i(x, y + i))
		6: # L-shape
			positions.append(Vector2i(x, y))
			positions.append(Vector2i(x + 1, y))
			positions.append(Vector2i(x, y + 1))

	for pos in positions:
		if _is_valid_position(pos):
			battlefield_manager.cover_map[pos.x][pos.y] = 2 # Full cover

func _place_elevation_feature(x: int, y: int) -> void:
	## Place an elevation feature
	var size = _roll_dice("Elevation Size", "D6")
	var elevation_value: int = 1 if size <= 3 else 2

	# Create small elevated area
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var pos = Vector2i(x + dx, y + dy)
			if _is_valid_position(pos):
				battlefield_manager.elevation_map[pos.x][pos.y] = elevation_value

func _place_difficult_terrain(x: int, y: int) -> void:
	## Place difficult terrain
	# Mark area as difficult terrain (movement cost x2)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var pos = Vector2i(x + dx, y + dy)
			if _is_valid_position(pos):
				battlefield_manager.terrain_map[pos.x][pos.y] = TerrainTypes.Type.DIFFICULT

func _place_special_feature(x: int, y: int) -> void:
	## Place mission-specific special feature
	# Could be objectives, spawn points, etc.
	var pos = Vector2i(x, y)
	if _is_valid_position(pos):
		battlefield_manager.terrain_map[pos.x][pos.y] = TerrainTypes.Type.HAZARD # Use HAZARD for special features
		_log_message("Special feature placed at (%d, %d)" % [x, y], UIColors.COLOR_AMBER)

func _setup_deployment_zones() -> void:
	## Setup deployment zones for crew and enemies
	# Crew deploys on left side
	deployment_zones["crew"] = []
	for x: int in range(0, 4):
		for y: int in range(grid_size.y):
			deployment_zones["crew"].append(Vector2i(x, y))

	# Enemies deploy on right side
	deployment_zones["enemies"] = []
	for x: int in range(grid_size.x - 4, grid_size.x):
		for y: int in range(grid_size.y):
			deployment_zones["enemies"].append(Vector2i(x, y))

func _connect_signals() -> void:
	## Connect UI and system signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn)
	if return_button:
		return_button.pressed.connect(_on_return_to_battle_resolution)
	if auto_resolve_button:
		auto_resolve_button.pressed.connect(_on_auto_resolve_battle)

	# Battlefield signals (handlers removed as dead code in Sprint 26.16)
	# TODO: Implement terrain/cover UI updates when needed
	# if battlefield_manager:
	# 	battlefield_manager.terrain_updated.connect(_on_terrain_updated)
	# 	battlefield_manager.cover_updated.connect(_on_cover_updated)

	# Reaction Dice signals
	if confirm_assignments_button:
		confirm_assignments_button.pressed.connect(_on_confirm_dice_assignments)

	# Connect to combat system for reaction dice events
	var combat_system = get_node_or_null("/root/FiveParsecsCombatSystem")
	if combat_system:
		if combat_system.has_signal("reaction_dice_rolled"):
			combat_system.reaction_dice_rolled.connect(_on_reaction_dice_rolled)
		if combat_system.has_signal("reaction_dice_assigned"):
			combat_system.reaction_dice_assigned.connect(_on_reaction_dice_assigned)

func _setup_ui() -> void:
	## Setup the tactical UI and show tier selection overlay
	if turn_indicator:
		turn_indicator.text = "Deployment Phase"
	if battle_log:
		battle_log.clear()
	_log_message("Tactical battle mode activated", UIColors.COLOR_EMERALD)

	# Instance LOG_ONLY components into their zones
	_instance_log_only_components()

	# Default to LOG_ONLY visibility until tier is selected
	_apply_tier_visibility(0)

	# Tier selection is deferred to initialize_battle() so it doesn't
	# appear during World Phase (TacticalBattleUI is a persistent scene child)

func _instance_log_only_components() -> void:
	## Instance and add LOG_ONLY tier components to zones
	# BattleJournal → Center / "Battle Log" tab
	battle_journal = BattleJournalScene.instantiate()
	battle_journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if battle_log_content:
		battle_log_content.add_child(battle_journal)

	# DiceDashboard → Right / "Tools" tab
	dice_dashboard = DiceDashboardScene.instantiate()
	dice_dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dice_manager:
		dice_dashboard.set_dice_system(dice_manager)
	if tools_content:
		tools_content.add_child(dice_dashboard)

	# CombatCalculator → Right / "Tools" tab
	combat_calculator = CombatCalculatorScene.instantiate()
	combat_calculator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tools_content:
		tools_content.add_child(combat_calculator)

	# BattleRoundHUD → Bottom bar (before action buttons)
	battle_round_hud = BattleRoundHUDClass.new()
	battle_round_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if action_buttons and action_buttons.get_parent():
		action_buttons.get_parent().add_child(battle_round_hud)
		action_buttons.get_parent().move_child(battle_round_hud, 0)

	# CombatSituationPanel → Right / "Tools" tab
	combat_situation_panel = CombatSituationPanelScene.instantiate()
	combat_situation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tools_content:
		tools_content.add_child(combat_situation_panel)

	# DualInputRoll → Right / "Tools" tab (standalone quick roller)
	dual_input_roll = DualInputRollClass.new()
	dual_input_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tools_content:
		tools_content.add_child(dual_input_roll)

	# CheatSheetPanel → Right / "Reference" tab
	cheat_sheet_panel = CheatSheetPanelClass.new()
	cheat_sheet_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_sheet_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if reference_content:
		reference_content.add_child(cheat_sheet_panel)

	# WeaponTableDisplay → Right / "Reference" tab
	weapon_table_display = WeaponTableDisplayScene.instantiate()
	weapon_table_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_table_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if reference_content:
		reference_content.add_child(weapon_table_display)

	# Connect component signals to journal logging
	_connect_component_signals()

	# Instance ASSISTED tier components (hidden by tab visibility)
	_instance_assisted_components()

	# Instance FULL_ORACLE tier components (hidden by tab visibility)
	_instance_oracle_components()

func _instance_assisted_components() -> void:
	## Instance ASSISTED tier components into their zones
	# MoralePanicTracker → Center / "Tracking" tab
	morale_tracker = MoralePanicTrackerScene.instantiate()
	morale_tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tracking_content:
		tracking_content.add_child(morale_tracker)

	# VictoryProgressPanel → Center / "Tracking" tab
	victory_progress = VictoryProgressPanelClass.new()
	victory_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tracking_content:
		tracking_content.add_child(victory_progress)

	# ReactionDicePanel → Center / "Tracking" tab
	reaction_dice_panel = ReactionDicePanelScene.instantiate()
	reaction_dice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tracking_content:
		tracking_content.add_child(reaction_dice_panel)

	# ActivationTrackerPanel → Left / "Units" tab
	activation_tracker = ActivationTrackerScene.instantiate()
	activation_tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activation_tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if units_content:
		units_content.add_child(activation_tracker)

	# DeploymentConditionsPanel → Center / "Events" tab
	deployment_conditions = DeploymentConditionsScene.instantiate()
	deployment_conditions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if events_content:
		events_content.add_child(deployment_conditions)

	# ObjectiveDisplay → Center / "Events" tab
	objective_display = ObjectiveDisplayScene.instantiate()
	objective_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if events_content:
		events_content.add_child(objective_display)

	# InitiativeCalculator → stored for overlay popup
	initiative_calculator = InitiativeCalculatorScene.instantiate()

	# EventResolutionPanel → stored for overlay popup
	event_resolution = EventResolutionPanelClass.new()

	# Connect ASSISTED component signals
	_connect_assisted_signals()

func _instance_oracle_components() -> void:
	## Instance FULL_ORACLE tier components into their zones
	# EnemyIntentPanel → Left / "Enemies" tab
	enemy_intent_panel = EnemyIntentPanelClass.new()
	enemy_intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_intent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if enemies_content:
		enemies_content.add_child(enemy_intent_panel)

	# EnemyGenerationWizard → Left / "Enemies" tab
	enemy_generation_wizard = EnemyGenerationWizardScene.instantiate()
	enemy_generation_wizard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if enemies_content:
		enemies_content.add_child(enemy_generation_wizard)

	# Connect FULL_ORACLE component signals
	if enemy_intent_panel and battle_journal:
		enemy_intent_panel.intent_revealed.connect(
			func(enemy_id: String, intent: Dictionary) -> void:
				var action: String = intent.get("action", "unknown")
				battle_journal.log_action("Enemy AI", "%s: %s" % [enemy_id, action])
		)
		enemy_intent_panel.oracle_instruction_ready.connect(
			func(group_name: String, instruction: String) -> void:
				_log_message("[Oracle] %s: %s" % [group_name, instruction], UIColors.COLOR_WARNING)
		)

	if enemy_generation_wizard:
		enemy_generation_wizard.enemies_generated.connect(
			func(enemies: Array) -> void:
				if battle_journal:
					battle_journal.log_event("Enemies", "%d enemies generated" % enemies.size())
		)

func _connect_assisted_signals() -> void:
	## Connect ASSISTED component signals to journal/hub
	if morale_tracker and battle_journal:
		morale_tracker.morale_check_triggered.connect(
			func(enemies: int, casualties: int) -> void:
				battle_journal.log_morale(
					"Check: %d enemies, %d casualties" % [
						enemies, casualties
					]
				)
		)
		morale_tracker.enemy_fled.connect(
			func(fled: int) -> void:
				battle_journal.log_morale("Fled", fled)
		)

	if event_resolution and battle_journal:
		event_resolution.event_resolved.connect(
			func(event: Dictionary, outcome: Dictionary) -> void:
				var name: String = event.get("name", "Unknown")
				battle_journal.log_event(
					name, outcome.get("description", "")
				)
		)

	# VictoryProgressPanel — win/loss detection
	if victory_progress and battle_journal:
		victory_progress.victory_condition_met.connect(
			func(condition_type: String) -> void:
				battle_journal.log_event("VICTORY", condition_type)
				_log_message("Victory condition met: %s" % condition_type, UIColors.COLOR_EMERALD)
		)
		victory_progress.defeat_condition_triggered.connect(
			func(reason: String) -> void:
				battle_journal.log_event("DEFEAT", reason)
				_log_message("Defeat: %s" % reason, UIColors.COLOR_DANGER)
		)
		victory_progress.objective_status_changed.connect(
			func(objective_id: String, status: String) -> void:
				battle_journal.log_action("Objective", "%s: %s" % [objective_id, status])
		)

	# ActivationTrackerPanel — unit turn tracking
	if activation_tracker and battle_journal:
		activation_tracker.unit_activation_requested.connect(
			func(unit_id: String) -> void:
				battle_journal.log_action("Activation", unit_id)
		)
		activation_tracker.reset_all_requested.connect(
			func() -> void:
				battle_journal.log_action("Activation", "All units reset for new round")
		)

	# ObjectiveDisplay — mission objective tracking
	if objective_display and battle_journal:
		objective_display.objective_rolled.connect(
			func(objective) -> void:
				var obj_name: String = objective.name if objective and "name" in objective else "Mission Objective"
				battle_journal.log_event("Objective", obj_name)
		)
		objective_display.objective_acknowledged.connect(
			func() -> void:
				battle_journal.log_action("Objective", "Acknowledged by player")
		)

	# ReactionDicePanel — dice spend tracking
	if reaction_dice_panel and battle_journal:
		reaction_dice_panel.dice_spent.connect(
			func(character_name: String, remaining: int) -> void:
				battle_journal.log_action(character_name, "Reaction die spent (%d remaining)" % remaining)
		)
		reaction_dice_panel.all_dice_reset.connect(
			func() -> void:
				battle_journal.log_action("Dice", "All reaction dice reset")
		)

	# DeploymentConditionsPanel — terrain/deployment info
	if deployment_conditions and battle_journal:
		deployment_conditions.condition_acknowledged.connect(
			func() -> void:
				battle_journal.log_action("Deployment", "Conditions acknowledged")
		)
		deployment_conditions.reroll_requested.connect(
			func() -> void:
				battle_journal.log_action("Deployment", "Reroll requested")
		)

	# InitiativeCalculator — initiative results
	if initiative_calculator and battle_journal:
		initiative_calculator.initiative_calculated.connect(
			func(result) -> void:
				var seized: String = "Seized!" if result and result.seized else "Normal"
				battle_journal.log_action("Initiative", seized)
		)

func _connect_component_signals() -> void:
	## Connect component signals so actions log to BattleJournal
	if dice_dashboard and battle_journal:
		dice_dashboard.dice_rolled.connect(
			func(dice_type: String, result: int, context: String) -> void:
				battle_journal.log_action("Dice", "%s: %d (%s)" % [
					dice_type, result, context
				])
		)

	if combat_calculator and battle_journal:
		combat_calculator.calculation_completed.connect(
			func(calc_type: String, result: Dictionary) -> void:
				var explanation: String = result.get(
					"explanation", calc_type
				)
				battle_journal.log_action("Calculator", explanation)
		)

	# Wire CombatSituationPanel modifier changes to CombatCalculator
	if combat_situation_panel and combat_calculator:
		if combat_situation_panel.has_signal("modifiers_changed"):
			combat_situation_panel.modifiers_changed.connect(
				func(total_mod: int) -> void:
					if combat_calculator.has_method("set_situation_modifier"):
						combat_calculator.set_situation_modifier(total_mod)
			)

	# Wire DualInputRoll results to journal
	if dual_input_roll and battle_journal:
		if dual_input_roll.has_signal("roll_completed"):
			dual_input_roll.roll_completed.connect(
				func(result: int, was_manual: bool) -> void:
					var mode: String = "manual" if was_manual else "auto"
					battle_journal.log_action(
						"Roll", "%d (%s)" % [result, mode]
					)
			)

	if battle_round_hud:
		battle_round_hud.next_phase_requested.connect(
			_on_advance_phase_pressed
		)

	# WeaponTableDisplay — weapon reference selection
	if weapon_table_display and battle_journal:
		if weapon_table_display.has_signal("weapon_selected"):
			weapon_table_display.weapon_selected.connect(
				func(weapon_data) -> void:
					var wname: String = weapon_data.name if weapon_data and "name" in weapon_data else "Weapon"
					battle_journal.log_action("Reference", "Viewed: %s" % wname)
			)

## Overlay Management

func _show_overlay(content_node: Control) -> void:
	## Show a modal overlay with the given content
	# Clear previous overlay content
	for child in overlay_content.get_children():
		child.queue_free()
	overlay_content.add_child(content_node)
	overlay_bg.visible = true
	overlay_center.visible = true

func _hide_overlay() -> void:
	## Hide the modal overlay
	overlay_bg.visible = false
	overlay_center.visible = false
	for child in overlay_content.get_children():
		child.queue_free()

## Tier Selection + Pre-Battle Checklist Flow

func _show_tier_selection() -> void:
	## Show the tier selection overlay so the player picks their tracking level
	var panel := TierSelectionPanelClass.new()
	panel.tier_selected.connect(_on_tier_selected)
	_show_overlay(panel)

func _on_tier_selected(tier: int) -> void:
	## Handle tier selection — store tier, apply visibility, show checklist
	# Create tier controller
	tier_controller = BattleTierControllerClass.new()
	tier_controller.set_tier(tier, true)  # force = true at battle start

	_apply_tier_visibility(tier)
	_hide_overlay()

	# Show pre-battle checklist
	_show_pre_battle_checklist(tier)

func _show_pre_battle_checklist(tier: int) -> void:
	## Show the pre-battle setup checklist overlay
	var checklist := PreBattleChecklistClass.new()
	checklist.checklist_completed.connect(
		_on_checklist_completed
	)

	# Wrap checklist with a "Begin Battle" button
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 16)
	wrapper.add_child(checklist)
	# Set tier AFTER adding to tree so _ready() has built the UI
	checklist.set_tier(tier)

	var begin_btn := Button.new()
	begin_btn.text = "Begin Battle"
	begin_btn.custom_minimum_size = Vector2(0, 56)
	begin_btn.add_theme_font_size_override("font_size", 18)
	begin_btn.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY
	)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIColors.COLOR_ACCENT
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(12)
	begin_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = UIColors.COLOR_ACCENT_HOVER
	begin_btn.add_theme_stylebox_override("hover", btn_hover)
	begin_btn.pressed.connect(_on_checklist_dismissed)
	wrapper.add_child(begin_btn)

	_show_overlay(wrapper)

func _on_checklist_completed() -> void:
	## All checklist items checked — log it (player can still click Begin)
	_log_message(
		"Pre-battle checklist complete!", UIColors.COLOR_EMERALD
	)

func _on_checklist_dismissed() -> void:
	## Player clicked Begin Battle — hide overlay and start
	_hide_overlay()
	_log_message(
		"Deploy your crew in the western deployment zone",
		UIColors.COLOR_CYAN
	)

## Tier Visibility

func _apply_tier_visibility(tier: int) -> void:
	## Show/hide tabs and components based on tracking tier.
	## Called after tier selection and on mid-battle tier upgrade.
	## Tier 0 (LOG_ONLY): Crew tab, Battle Log tab, Tools tab, Reference tab
	## Tier 1 (ASSISTED): + Units tab, Tracking tab, Events tab
	## Tier 2 (FULL_ORACLE): + Enemies tab
	var show_assisted := tier >= 1
	var show_oracle := tier >= 2

	# Left sidebar tabs: Crew always visible, Units at ASSISTED+, Enemies at FULL_ORACLE
	if left_tabs:
		# Tab indices: 0=Crew, 1=Units, 2=Enemies
		left_tabs.set_tab_hidden(1, not show_assisted)
		left_tabs.set_tab_hidden(2, not show_oracle)

	# Center tabs: Battle Log always visible, Tracking + Events at ASSISTED+
	if center_tabs:
		# Tab indices: 0=Battle Log, 1=Tracking, 2=Events
		center_tabs.set_tab_hidden(1, not show_assisted)
		center_tabs.set_tab_hidden(2, not show_assisted)

	# Right sidebar tabs: always visible (0=Tools, 1=Reference, 2=Setup)
	# No changes needed — all three tabs shown at all tiers

	# Update tier badge text
	if tier_badge:
		match tier:
			0: tier_badge.text = "[LOG ONLY]"
			1: tier_badge.text = "[ASSISTED]"
			2: tier_badge.text = "[FULL ORACLE]"

## Sprint 11.4: BattleRoundTracker Integration Methods

func set_round_tracker(tracker: Node) -> void:
	## Set the BattleRoundTracker and connect to its signals for phase-based combat
	if round_tracker and _round_tracker_connected:
		_disconnect_round_tracker_signals()

	round_tracker = tracker

	if round_tracker:
		_connect_round_tracker_signals()
		_round_tracker_connected = true
		_log_message(
			"Round tracker connected - combat phases active",
			UIColors.COLOR_CYAN
		)
		# Connect BattleRoundHUD to tracker
		if battle_round_hud and battle_round_hud.has_method("connect_to_tracker"):
			battle_round_hud.connect_to_tracker(round_tracker)

func _connect_round_tracker_signals() -> void:
	## Connect to BattleRoundTracker signals for phase and round updates
	if not round_tracker:
		return

	# Phase changes within a round
	if round_tracker.has_signal("phase_changed") and not round_tracker.phase_changed.is_connected(_on_round_phase_changed):
		round_tracker.phase_changed.connect(_on_round_phase_changed)

	# Round start/end
	if round_tracker.has_signal("round_started") and not round_tracker.round_started.is_connected(_on_round_started):
		round_tracker.round_started.connect(_on_round_started)

	if round_tracker.has_signal("round_ended") and not round_tracker.round_ended.is_connected(_on_round_ended):
		round_tracker.round_ended.connect(_on_round_ended)

	# Battle events (rounds 2 and 4)
	if round_tracker.has_signal("battle_event_triggered") and not round_tracker.battle_event_triggered.is_connected(_on_battle_event_triggered):
		round_tracker.battle_event_triggered.connect(_on_battle_event_triggered)

	# Battle start/end
	if round_tracker.has_signal("battle_started") and not round_tracker.battle_started.is_connected(_on_tracker_battle_started):
		round_tracker.battle_started.connect(_on_tracker_battle_started)

	if round_tracker.has_signal("battle_ended") and not round_tracker.battle_ended.is_connected(_on_tracker_battle_ended):
		round_tracker.battle_ended.connect(_on_tracker_battle_ended)

func _disconnect_round_tracker_signals() -> void:
	## Disconnect from BattleRoundTracker signals
	if not round_tracker:
		return

	if round_tracker.has_signal("phase_changed") and round_tracker.phase_changed.is_connected(_on_round_phase_changed):
		round_tracker.phase_changed.disconnect(_on_round_phase_changed)

	if round_tracker.has_signal("round_started") and round_tracker.round_started.is_connected(_on_round_started):
		round_tracker.round_started.disconnect(_on_round_started)

	if round_tracker.has_signal("round_ended") and round_tracker.round_ended.is_connected(_on_round_ended):
		round_tracker.round_ended.disconnect(_on_round_ended)

	if round_tracker.has_signal("battle_event_triggered") and round_tracker.battle_event_triggered.is_connected(_on_battle_event_triggered):
		round_tracker.battle_event_triggered.disconnect(_on_battle_event_triggered)

	if round_tracker.has_signal("battle_started") and round_tracker.battle_started.is_connected(_on_tracker_battle_started):
		round_tracker.battle_started.disconnect(_on_tracker_battle_started)

	if round_tracker.has_signal("battle_ended") and round_tracker.battle_ended.is_connected(_on_tracker_battle_ended):
		round_tracker.battle_ended.disconnect(_on_tracker_battle_ended)

	_round_tracker_connected = false

## BattleRoundTracker Signal Handlers

func _on_round_phase_changed(phase: int, phase_name: String) -> void:
	## Handle phase change from round tracker - update UI
	var round_num: int = current_turn
	if round_tracker and round_tracker.has_method("get_current_round"):
		round_num = round_tracker.get_current_round()
	if turn_indicator:
		turn_indicator.text = "Round %d - %s" % [round_num, phase_name]
	_log_message("Phase: %s" % phase_name, UIColors.COLOR_AMBER)
	_update_action_buttons_for_phase(phase)

	# Show InitiativeCalculator overlay at REACTION_ROLL phase
	if phase == 0 and initiative_calculator and tier_controller:
		if tier_controller.current_tier >= 1:
			_show_overlay(initiative_calculator)

func _on_round_started(round_number: int) -> void:
	## Handle round start - reset reactions and update UI
	current_turn = round_number
	_log_message("=== ROUND %d BEGINS ===" % round_number, UIColors.COLOR_CYAN)
	_reset_all_unit_reactions()

func _on_round_ended(round_number: int) -> void:
	## Handle round end
	_log_message("=== ROUND %d COMPLETE ===" % round_number, UIColors.COLOR_AMBER)

	# DLC: Escalating Battles check (Compendium pp.46-48)
	_check_escalating_battles(round_number)

func _on_battle_event_triggered(round_num: int, _event_type: String) -> void:
	## Handle battle event trigger (rounds 2 and 4 per Five Parsecs p.118)
	_log_message(
		"BATTLE EVENT! (Round %d) - Rolling on event table..." % round_num,
		UIColors.COLOR_AMBER
	)
	# Show EventResolutionPanel overlay at ASSISTED+ tier
	if event_resolution and tier_controller:
		if tier_controller.current_tier >= 1:
			_show_overlay(event_resolution)

func _on_tracker_battle_started() -> void:
	## Handle battle start from tracker
	_log_message("Tactical combat initiated via round tracker", UIColors.COLOR_EMERALD)
	battle_phase = "combat"

func _on_tracker_battle_ended() -> void:
	## Handle battle end from tracker
	_log_message("Battle concluded via round tracker", UIColors.COLOR_AMBER)
	battle_phase = "resolution"

func _update_action_buttons_for_phase(phase: int) -> void:
	## Update action buttons based on current combat phase from round tracker
	if not action_buttons:
		return
	# Map BattleRoundTracker phases to appropriate UI states
	# 0: REACTION_ROLL, 1: QUICK_ACTIONS, 2: ENEMY_ACTIONS, 3: SLOW_ACTIONS, 4: END_PHASE
	match phase:
		0:  # REACTION_ROLL
			_show_reaction_roll_ui()
		1:  # QUICK_ACTIONS
			_show_quick_actions_ui()
		2:  # ENEMY_ACTIONS
			_show_enemy_actions_ui()
		3:  # SLOW_ACTIONS
			_show_slow_actions_ui()
		4:  # END_PHASE
			_show_end_phase_ui()

func _show_reaction_roll_ui() -> void:
	## Show UI for reaction roll phase
	_clear_action_buttons()
	var roll_button := Button.new()
	roll_button.text = "Roll Reactions"
	roll_button.pressed.connect(_on_roll_reactions_pressed)
	action_buttons.add_child(roll_button)

func _show_quick_actions_ui() -> void:
	## Show UI for quick actions phase - crew with successful reactions act first
	_log_message("Quick Actions - Crew with reactions act first", UIColors.COLOR_CYAN)
	_update_action_buttons_for_combat()

func _show_enemy_actions_ui() -> void:
	## Show UI for enemy actions phase
	_clear_action_buttons()
	_log_message("Enemy Actions - AI controlling enemy units", UIColors.COLOR_RED)
	var skip_button := Button.new()
	skip_button.text = "Process Enemy Actions"
	skip_button.pressed.connect(_on_process_enemy_actions_pressed)
	action_buttons.add_child(skip_button)

func _show_slow_actions_ui() -> void:
	## Show UI for slow actions phase - remaining crew act
	_log_message("Slow Actions - Remaining crew members act", UIColors.COLOR_CYAN)
	_update_action_buttons_for_combat()

func _show_end_phase_ui() -> void:
	## Show UI for end phase
	_clear_action_buttons()
	var advance_button := Button.new()
	advance_button.text = "End Round / Morale Check"
	advance_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(advance_button)

func _on_roll_reactions_pressed() -> void:
	## Handle reaction roll button press
	_log_message("Rolling reactions for crew...", UIColors.COLOR_CYAN)
	# Roll for each crew member
	for unit in crew_units:
		if unit.health > 0:
			var roll = _roll_dice("Reaction: " + unit.node_name, "D6")
			unit.initiative_roll = roll
			var success = roll <= unit.reactions
			_log_message("  %s: Rolled %d vs Reactions %d - %s" % [
				unit.node_name, roll, unit.reactions,
				"QUICK" if success else "SLOW"
			], UIColors.COLOR_EMERALD if success else UIColors.COLOR_TEXT_SECONDARY)

	# Advance phase via round tracker
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()

func _on_process_enemy_actions_pressed() -> void:
	## Process AI enemy actions
	_log_message("Processing enemy actions...", UIColors.COLOR_RED)
	for unit in enemy_units:
		if unit.health > 0:
			# Simple AI: Move toward nearest crew and shoot if in range
			var target = _find_nearest_enemy(unit)
			if target:
				var distance = unit.node_position.distance_to(target.node_position)
				if distance <= 12:  # In shooting range
					_log_message("  %s shoots at %s" % [unit.node_name, target.node_name], UIColors.COLOR_RED)
					# Simplified shot resolution
					var hit_roll = _roll_dice("Enemy Shot", "D6")
					if hit_roll <= 4:
						var damage = _roll_dice("Damage", "D6")
						target.take_damage(damage)
						_log_message("    HIT! %d damage to %s" % [damage, target.node_name], UIColors.COLOR_AMBER)
				else:
					_log_message("  %s moves toward crew" % unit.node_name, UIColors.COLOR_RED)

	# Advance phase via round tracker
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()

func _on_advance_phase_pressed() -> void:
	## Advance to next phase via round tracker
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()
	else:
		# Fallback if no round tracker
		_end_combat_round()

## Initialize tactical battle with crew and enemies

func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void:
	## Initialize the tactical battle
	_log_message("Initializing tactical battle...", UIColors.COLOR_CYAN)

	# Show tier selection now that battle is actually starting
	_show_tier_selection()

	# Create tactical units from crew
	for crew_member in crew_members:
		var unit := TacticalUnit.new()
		unit.initialize_from_crew_member(crew_member)
		unit.team = "crew"
		crew_units.append(unit)
		all_units.append(unit)

	# Create tactical units from enemies
	for enemy in enemies:
		var unit := TacticalUnit.new()
		unit.initialize_from_enemy(enemy)
		unit.team = "enemy"
		enemy_units.append(unit)
		all_units.append(unit)

	_log_message(
		"Battle initialized: %d crew vs %d enemies" % [
			crew_units.size(), enemy_units.size()
		], Color.WHITE
	)

	# Create CharacterStatusCards for crew
	_create_character_cards(crew_members)

	# Log to journal if available
	if battle_journal:
		battle_journal.start_battle()

	# Start deployment phase
	_start_deployment_phase()

	# Populate battlefield setup tab
	_stored_mission_data = mission_data
	_populate_setup_tab(mission_data)

	# DLC: Wire No-Minis Combat panel if enabled
	_setup_no_minis_panel(crew_members.size(), enemies.size())

	# DLC: Wire Stealth Mission panel if this is a stealth mission
	var mission_dict: Dictionary = mission_data if mission_data is Dictionary else {}
	if mission_dict.get("type", "") == "stealth":
		_setup_stealth_panel(mission_dict)

func _create_character_cards(crew_members: Array) -> void:
	## Create a CharacterStatusCard for each crew member
	# Clear existing cards
	for card in character_cards:
		if is_instance_valid(card):
			card.queue_free()
	character_cards.clear()

	if not crew_content:
		return

	for crew_member in crew_members:
		var card: PanelContainer = CharacterStatusCardScene.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crew_content.add_child(card)

		# Set character data (accepts Resource or Dictionary)
		card.set_character_data(crew_member)

		# Set tier display level
		if tier_controller:
			card.set_display_tier(tier_controller.current_tier)

		# Connect signals to journal
		if battle_journal:
			card.action_used.connect(
				func(char_name: String, action_type: String) -> void:
					battle_journal.log_action(
						char_name, action_type
					)
			)
			card.damage_taken.connect(
				func(char_name: String, amount: int) -> void:
					battle_journal.log_action(
						char_name,
						"took %d damage" % amount
					)
			)

		character_cards.append(card)

func _start_deployment_phase() -> void:
	## Start the deployment phase
	battle_phase = "deployment"
	if turn_indicator:
		turn_indicator.text = "Deployment Phase - Place your crew"
	_log_message("Place your crew members in the deployment zone", UIColors.COLOR_CYAN)

	# Enable deployment UI
	_update_action_buttons_for_deployment()

func _start_combat_phase() -> void:
	## Start the main combat phase
	battle_phase = "combat"
	current_turn = 1
	current_unit_index = 0

	# Roll for initiative order
	_determine_initiative_order()

	if turn_indicator:
		turn_indicator.text = "Combat Round %d" % current_turn
	_log_message("Combat begins! Round %d" % current_turn, UIColors.COLOR_RED)

	_start_unit_turn()

func _determine_initiative_order() -> void:
	## Determine turn order using Five Parsecs initiative rules
	_log_message("Rolling for initiative...", UIColors.COLOR_AMBER)

	# Each unit rolls for initiative
	for unit in all_units:
		unit.initiative_roll = _roll_dice("Initiative: " + unit.name, "D6") + unit.get_initiative_bonus()
		_log_message("%s initiative: %d" % [unit.name, unit.initiative_roll], Color.WHITE)

	# Sort by initiative (highest first)
	all_units.sort_custom(func(a, b): return a.initiative_roll > b.initiative_roll)

func _start_unit_turn() -> void:
	## Start a unit's turn
	if current_unit_index >= all_units.size():
		_end_combat_round()
		return

	selected_unit = all_units[current_unit_index]
	selected_unit.actions_remaining = selected_unit.max_actions
	selected_unit.movement_remaining = selected_unit.movement_points

	turn_phase = "movement"
	if turn_indicator:
		turn_indicator.text = "Round %d - %s's Turn" % [current_turn, selected_unit.name]
	_log_message("%s's turn begins" % selected_unit.name, UIColors.COLOR_CYAN)

	_update_action_buttons_for_combat()
	_update_unit_info_display()

func _update_action_buttons_for_deployment() -> void:
	## Update action buttons for deployment phase
	if not action_buttons:
		return
	_clear_action_buttons()

	# Add deployment-specific buttons
	var place_unit_button := Button.new()
	place_unit_button.text = "Place Unit"
	place_unit_button.pressed.connect(_on_place_unit_clicked)
	action_buttons.add_child(place_unit_button)

	var auto_deploy_button := Button.new()
	auto_deploy_button.text = "Auto Deploy"
	auto_deploy_button.pressed.connect(_on_auto_deploy_clicked)
	action_buttons.add_child(auto_deploy_button)

func _update_action_buttons_for_combat() -> void:
	## Update action buttons for combat phase
	if not action_buttons:
		return
	_clear_action_buttons()

	if not selected_unit or selected_unit.team != "crew":
		return # Only show actions for crew units

	# Check reaction availability (reaction economy system)
	var has_reactions := selected_unit.can_use_reaction()

	# Movement - requires reaction
	if selected_unit.movement_remaining > 0:
		var move_button := Button.new()
		move_button.text = "Move (%d left)" % selected_unit.movement_remaining
		move_button.pressed.connect(_on_move_clicked)
		if not has_reactions:
			move_button.disabled = true
			move_button.tooltip_text = "No reactions remaining"
		action_buttons.add_child(move_button)

	# Shooting - requires reaction
	if selected_unit.actions_remaining > 0:
		var shoot_button := Button.new()
		shoot_button.text = "Shoot"
		shoot_button.pressed.connect(_on_shoot_clicked)
		if not has_reactions:
			shoot_button.disabled = true
			shoot_button.tooltip_text = "No reactions remaining"
		action_buttons.add_child(shoot_button)

	# Dash (extra movement) - requires reaction
	if selected_unit.actions_remaining > 0:
		var dash_button := Button.new()
		dash_button.text = "Dash"
		dash_button.pressed.connect(_on_dash_clicked)
		if not has_reactions:
			dash_button.disabled = true
			dash_button.tooltip_text = "No reactions remaining"
		action_buttons.add_child(dash_button)

	# Skip turn - always available
	var skip_button := Button.new()
	skip_button.text = "End Turn"
	skip_button.pressed.connect(_on_skip_turn_clicked)
	action_buttons.add_child(skip_button)

	# Show exhaustion warning
	if not has_reactions:
		_log_message("⚠ %s has no reactions remaining this round!" % selected_unit.node_name, UIColors.COLOR_AMBER)

func _clear_action_buttons() -> void:
	## Clear all action buttons
	if not action_buttons:
		return
	for child in action_buttons.get_children():
		child.queue_free()

func _update_unit_info_display() -> void:
	## Update the selected unit info display
	if not selected_unit:
		return

	# Update unit info panel
	# Show stats, health, reactions, equipment
	var reactions_remaining := selected_unit.get_reactions_remaining()
	var max_reactions := selected_unit.max_reactions_per_round
	var reaction_color := UIColors.COLOR_EMERALD if reactions_remaining > 0 else UIColors.COLOR_RED

	_log_message("Selected: %s (Team: %s)" % [selected_unit.node_name, selected_unit.team], UIColors.COLOR_AMBER)
	_log_message("  HP: %d/%d | Actions: %d | Movement: %d" % [
		selected_unit.health, selected_unit.max_health,
		selected_unit.actions_remaining, selected_unit.movement_remaining
	], Color.WHITE)
	_log_message("  Reactions: %d/%d %s" % [
		reactions_remaining, max_reactions,
		"(EXHAUSTED)" if reactions_remaining == 0 else ""
	], reaction_color)

# Action handlers
func _on_move_clicked() -> void:
	## Handle move action
	if not selected_unit or not selected_unit.can_move():
		_log_message("Cannot move - no movement remaining!", UIColors.COLOR_RED)
		return

	# Check and spend reaction (reaction economy system)
	if not selected_unit.can_use_reaction():
		_log_message("Cannot move - no reactions remaining!", UIColors.COLOR_RED)
		return
	selected_unit.spend_reaction()

	_log_message("%s is moving... (Movement: %d remaining, Reactions: %d/%d)" % [
		selected_unit.node_name, selected_unit.movement_remaining,
		selected_unit.get_reactions_remaining(), selected_unit.max_reactions_per_round
	], UIColors.COLOR_CYAN)
	
	# For now, auto-move toward nearest enemy (will be replaced with UI selection)
	var nearest_enemy = _find_nearest_enemy(selected_unit)
	if nearest_enemy:
		var move_vector = (nearest_enemy.node_position - selected_unit.node_position).sign()
		var new_pos = selected_unit.node_position + Vector2i(move_vector.x, move_vector.y)
		
		if _is_valid_position(new_pos):
			selected_unit.node_position = new_pos
			selected_unit.movement_remaining = max(0, selected_unit.movement_remaining - 1)
			_log_message("%s moved to (%d, %d)" % [selected_unit.node_name, new_pos.x, new_pos.y], UIColors.COLOR_CYAN)
		else:
			_log_message("Invalid move position!", UIColors.COLOR_RED)
	
	_update_action_buttons_for_combat()

func _on_shoot_clicked() -> void:
	## Handle shoot action
	if not selected_unit or not selected_unit.can_act():
		_log_message("Cannot shoot - no actions remaining!", UIColors.COLOR_RED)
		return

	# Check and spend reaction (reaction economy system)
	if not selected_unit.can_use_reaction():
		_log_message("Cannot shoot - no reactions remaining!", UIColors.COLOR_RED)
		return
	selected_unit.spend_reaction()

	# Find nearest enemy to shoot (will be replaced with UI targeting)
	var target = _find_nearest_enemy(selected_unit)
	if not target:
		_log_message("No valid targets!", UIColors.COLOR_RED)
		return
	
	var distance = selected_unit.node_position.distance_to(target.node_position)
	
	# Check range (24 inches = 24 grid squares)
	if distance > 24:
		_log_message("Target out of range! (Distance: %.0f)" % distance, UIColors.COLOR_RED)
		return
	
	_log_message("%s shooting at %s (Range: %.0f)" % [selected_unit.node_name, target.node_name, distance], UIColors.COLOR_AMBER)
	
	# Calculate to-hit (Five Parsecs rules)
	var base_skill = selected_unit.combat_skill
	var cover_mod = _get_cover_modifier(target)
	var to_hit_bonus = base_skill + cover_mod
	
	# Roll to hit (D6, need <= modified skill + 3)
	var hit_roll = _roll_dice("To Hit", "D6")
	var hit_threshold = 3 + to_hit_bonus
	var hit = hit_roll <= hit_threshold
	
	if hit:
		# Roll damage
		var damage = _roll_dice("Damage", "D6")
		var actual_damage = max(1, damage - (target.toughness / 2))
		
		target.take_damage(actual_damage)
		_log_message("HIT! Rolled %d (needed <=%d) - %d damage dealt!" % [hit_roll, hit_threshold, actual_damage], UIColors.COLOR_EMERALD)
		_log_message("%s: %d/%d HP remaining" % [target.node_name, target.health, target.max_health], UIColors.COLOR_AMBER)
		
		if target.is_dead:
			_log_message("%s is DOWN!" % target.node_name, UIColors.COLOR_RED)
	else:
		_log_message("MISS! Rolled %d (needed <=%d)" % [hit_roll, hit_threshold], UIColors.COLOR_TEXT_SECONDARY)
	
	# Consume action
	selected_unit.actions_remaining -= 1
	_update_action_buttons_for_combat()

func _on_dash_clicked() -> void:
	## Handle dash action (extra movement)
	# Check and spend reaction (reaction economy system)
	if not selected_unit.can_use_reaction():
		_log_message("Cannot dash - no reactions remaining!", UIColors.COLOR_RED)
		return
	selected_unit.spend_reaction()

	selected_unit.movement_remaining += selected_unit.movement_points
	selected_unit.actions_remaining -= 1
	_log_message("%s dashes forward! (Reactions: %d/%d)" % [
		selected_unit.node_name,
		selected_unit.get_reactions_remaining(), selected_unit.max_reactions_per_round
	], UIColors.COLOR_AMBER)
	_update_action_buttons_for_combat()

func _on_skip_turn_clicked() -> void:
	## Skip the current unit's turn
	_log_message("%s ends their turn" % selected_unit.name, UIColors.COLOR_TEXT_SECONDARY)
	_end_unit_turn()

func _on_place_unit_clicked() -> void:
	## Handle unit placement in deployment
	_log_message("Click on the deployment zone to place units", UIColors.COLOR_CYAN)

func _on_auto_deploy_clicked() -> void:
	## Auto-deploy all crew units
	_log_message("Auto-deploying crew members...", UIColors.COLOR_CYAN)

	var crew_positions = deployment_zones["crew"].duplicate()
	crew_positions.shuffle()

	for i: int in range(min(crew_units.size(), crew_positions.size())):
		crew_units[i].position = crew_positions[i]
		_log_message("%s deployed at (%d, %d)" % [crew_units[i].name, crew_positions[i].x, crew_positions[i].y], Color.WHITE)

	# Auto-deploy enemies too
	_auto_deploy_enemies()

	# Start combat
	_start_combat_phase()

func _auto_deploy_enemies() -> void:
	## Auto-deploy enemy units
	var enemy_positions: Array[Vector2] = deployment_zones["enemies"].duplicate()
	enemy_positions.shuffle()

	for i: int in range(min(enemy_units.size(), enemy_positions.size())):
		enemy_units[i].position = enemy_positions[i]
		_log_message("%s deployed at (%d, %d)" % [enemy_units[i].name, enemy_positions[i].x, enemy_positions[i].y], Color.WHITE)

func _end_unit_turn() -> void:
	## End the current unit's turn
	current_unit_index += 1
	_start_unit_turn()

func _end_combat_round() -> void:
	## End the current combat round
	current_turn += 1
	current_unit_index = 0

	_log_message("Round %d complete" % (current_turn - 1), UIColors.COLOR_AMBER)

	# Reset reactions for all units at start of new round (reaction economy system)
	_reset_all_unit_reactions()

	# Check victory conditions
	if _check_victory_conditions():
		_resolve_battle()
	else:
		_start_unit_turn()

func _reset_all_unit_reactions() -> void:
	## Reset reactions for all units at the start of a new round
	for unit in all_units:
		if unit.health > 0:
			unit.reset_reactions()
	_log_message("All units' reactions reset for Round %d" % current_turn, UIColors.COLOR_CYAN)

func _check_victory_conditions() -> bool:
	## Check if battle should end
	var crew_alive = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive = enemy_units.filter(func(u): return u.health > 0).size()

	return crew_alive == 0 or enemies_alive == 0 or current_turn > 20 # Max 20 rounds

func _resolve_battle() -> void:
	## Resolve the tactical battle
	battle_phase = "resolution"

	var crew_alive = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive = enemy_units.filter(func(u): return u.health > 0).size()

	var result := BattleResult.new()
	result.rounds_fought = current_turn - 1

	if crew_alive > 0 and enemies_alive == 0:
		result.victory = true
		_log_message("Victory! All enemies defeated!", UIColors.COLOR_EMERALD)
	elif crew_alive == 0:
		result.victory = false
		_log_message("Defeat! All crew members down!", UIColors.COLOR_RED)
	else:
		# Stalemate or time limit
		result.victory = crew_alive > enemies_alive
		_log_message("Battle concluded after %d rounds" % result.rounds_fought, UIColors.COLOR_AMBER)

	# Calculate casualties and injuries
	for unit in crew_units:
		if unit.health <= 0:
			if unit.is_dead:
				result.crew_casualties.append(unit.original_character)
			else:
				result.crew_injuries.append(unit.original_character)

	tactical_battle_completed.emit(result)

func _on_end_turn() -> void:
	## Handle end turn button
	if battle_phase == "combat":
		_end_unit_turn()

func _on_return_to_battle_resolution() -> void:
	## Return to battle resolution UI
	return_to_battle_resolution.emit() # warning: return value discarded (intentional)

func _on_auto_resolve_battle() -> void:
	## Auto-resolve the remaining battle using Five Parsecs combat system
	_log_message("Auto-resolving battle...", UIColors.COLOR_AMBER)
	
	# Calculate crew power
	var crew_power = 0
	for unit in crew_units:
		if unit.health > 0:
			crew_power += unit.combat_skill + unit.toughness
	
	# Calculate enemy power  
	var enemy_power = 0
	for unit in enemy_units:
		if unit.health > 0:
			enemy_power += unit.combat_skill + unit.toughness
	
	# Roll 2D6 for each side
	var crew_roll = _roll_dice("Crew Combat", "D6") + _roll_dice("Crew Combat 2", "D6")
	var enemy_roll = _roll_dice("Enemy Combat", "D6") + _roll_dice("Enemy Combat 2", "D6")
	
	var crew_total = crew_power + crew_roll
	var enemy_total = enemy_power + enemy_roll
	
	_log_message("Crew: %d power + %d roll = %d" % [crew_power, crew_roll, crew_total], UIColors.COLOR_CYAN)
	_log_message("Enemy: %d power + %d roll = %d" % [enemy_power, enemy_roll, enemy_total], UIColors.COLOR_RED)
	
	var result := BattleResult.new()
	result.rounds_fought = current_turn
	result.victory = crew_total > enemy_total
	
	# Calculate casualties — use Compendium tables when DLC enabled, else simplified
	for unit in crew_units:
		if unit.health <= 0:
			# Try Compendium casualty table first (D6, Compendium p.86)
			var casualty_result: Dictionary = _roll_compendium_casualty()
			if not casualty_result.is_empty():
				var cas_instruction: String = casualty_result.get("instruction", "")
				var cas_id: String = casualty_result.get("id", "")
				_log_message(cas_instruction, Color("#DC2626"))
				if cas_id == "instant_kill" or cas_id == "dead":
					result.crew_casualties.append(unit.original_character)
				else:
					result.crew_injuries.append(unit.original_character)
					# Try detailed injury table (2D6, Compendium p.87)
					var injury_result: Dictionary = _roll_compendium_injury()
					if not injury_result.is_empty():
						_log_message(injury_result.get("instruction", ""), Color("#D97706"))
			else:
				# Fallback: simplified casualty (core rules)
				if not result.victory:
					var casualty_roll: int = _roll_dice("Casualty", "D6")
					if casualty_roll <= 3:
						result.crew_casualties.append(unit.original_character)
				else:
					var death_roll: int = _roll_dice("Death Check", "D6")
					if death_roll <= 2:
						result.crew_casualties.append(unit.original_character)
					else:
						result.crew_injuries.append(unit.original_character)

	_log_message("Battle %s!" % ("WON" if result.victory else "LOST"), UIColors.COLOR_EMERALD if result.victory else UIColors.COLOR_RED)
	tactical_battle_completed.emit(result)

## Utility functions

func _is_valid_position(pos: Vector2i) -> bool:
	## Check if position is valid on battlefield
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func _roll_dice(context: String, pattern: String) -> int:
	## Roll dice using the dice system
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		match pattern:
			"D6": return randi_range(1, 6)
			"D10": return randi_range(1, 10)
			_: return randi_range(1, 6)

func _log_message(message: String, color: Color = Color.WHITE) -> void:
	## Log a message to the battle log
	if not battle_log:
		return
	var timestamp: String = "[%02d:%02d] " % [current_turn, current_unit_index]
	battle_log.append_text("[color=%s]%s%s[/color]\n" % [color.to_html(), timestamp, message])
	battle_log.scroll_to_line(battle_log.get_line_count())

func _find_nearest_enemy(unit: TacticalUnit) -> TacticalUnit:
	## Find the nearest enemy unit to the given unit
	var enemies = enemy_units if unit.team == "crew" else crew_units
	var nearest: TacticalUnit = null
	var min_distance = INF
	
	for enemy in enemies:
		if enemy.health > 0:
			var dist = unit.node_position.distance_to(enemy.node_position)
			if dist < min_distance:
				min_distance = dist
				nearest = enemy
	
	return nearest

func _get_cover_modifier(unit: TacticalUnit) -> int:
	## Get cover modifier for a unit at their position
	# Check terrain at unit position
	var terrain_data = battlefield_manager.get_terrain_data(unit.node_position)
	if terrain_data and terrain_data.has("cover"):
		return -terrain_data["cover"]  # Cover makes them harder to hit (negative modifier)
	return 0

## Reaction Dice System

var reaction_dice_pool: Array[int] = []
var dice_assignments: Dictionary = {} # character_id -> dice_value

func _on_reaction_dice_rolled(dice_values: Array) -> void:
	## Handle reaction dice rolled at start of round
	reaction_dice_pool = dice_values
	dice_assignments.clear()
	_display_dice_pool()
	_display_character_assignments()
	_log_message("Reaction dice rolled: %s" % str(dice_values), UIColors.COLOR_CYAN)

func _on_reaction_dice_assigned(character_id: String, dice_value: int) -> void:
	## Handle dice assignment update
	dice_assignments[character_id] = dice_value
	_display_character_assignments()

func _on_confirm_dice_assignments() -> void:
	## Confirm all dice assignments and proceed
	var combat_system = get_node_or_null("/root/FiveParsecsCombatSystem")
	if combat_system and combat_system.has_method("confirm_reaction_assignments"):
		combat_system.confirm_reaction_assignments(dice_assignments)
	_log_message("Reaction dice assignments confirmed", UIColors.COLOR_EMERALD)

func _display_dice_pool() -> void:
	## Display available reaction dice
	if not dice_pool_display:
		return

	# Clear existing dice
	for child in dice_pool_display.get_children():
		child.queue_free()

	# Create visual for each die
	for die_value in reaction_dice_pool:
		var die_label := Label.new()
		die_label.text = "[%d]" % die_value
		die_label.add_theme_font_size_override("font_size", 20)

		# Color code by value (higher = better)
		if die_value >= 5:
			die_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
		elif die_value >= 3:
			die_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
		else:
			die_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)

		dice_pool_display.add_child(die_label)

func _display_character_assignments() -> void:
	## Display character assignment options
	if not character_assignment_list:
		return

	# Clear existing assignments
	for child in character_assignment_list.get_children():
		child.queue_free()

	# Create assignment row for each crew member
	for unit in crew_units:
		if unit.health <= 0:
			continue

		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = unit.node_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var assigned_value: int = dice_assignments.get(unit.node_name, 0)
		var value_label := Label.new()
		value_label.text = str(assigned_value) if assigned_value > 0 else "-"
		row.add_child(value_label)

		# Add assign button
		var assign_button := Button.new()
		assign_button.text = "Assign"
		assign_button.pressed.connect(_on_assign_dice_to_character.bind(unit.node_name))
		row.add_child(assign_button)

		character_assignment_list.add_child(row)

func _on_assign_dice_to_character(character_name: String) -> void:
	## Assign next available die to character
	# Find first unassigned die
	var assigned_values = dice_assignments.values()
	for die_value in reaction_dice_pool:
		if die_value not in assigned_values:
			dice_assignments[character_name] = die_value
			_display_character_assignments()
			_log_message("%s assigned reaction die: %d" % [character_name, die_value], UIColors.COLOR_CYAN)
			return

	_log_message("No dice available to assign!", UIColors.COLOR_RED)

## ── Battlefield Setup Tab ──────────────────────────────────────────

func _populate_setup_tab(mission_data) -> void:
	## Populate the Setup tab with terrain, deployment, and objective info
	if not setup_content:
		return

	# Clear previous content
	for child in setup_content.get_children():
		child.queue_free()

	# Initialize battlefield generator
	if not _battlefield_generator:
		_battlefield_generator = BattlefieldGeneratorClass.new()

	# Read battlefield data from GameState
	var game_state = get_node_or_null("/root/GameState")
	var bf_data: Dictionary = {}
	if game_state and game_state.has_method("get_battlefield_data"):
		bf_data = game_state.get_battlefield_data()

	var terrain_data: Dictionary = bf_data.get("terrain", {})
	var deployment_condition: Dictionary = bf_data.get("deployment_condition", {})

	# Determine terrain theme key for BattlefieldGenerator
	var theme_name: String = terrain_data.get("theme", "Standard Battlefield")
	_current_terrain_theme = _map_theme_name_to_key(theme_name)

	# Generate rich per-sector terrain suggestions
	var sector_data: Dictionary = _battlefield_generator.generate_terrain_suggestions(
		_current_terrain_theme)

	# Populate the visual battlefield grid in center area
	if battlefield_grid_panel and battlefield_grid_panel.has_method("populate"):
		var sectors_arr: Array = sector_data.get("sectors", [])
		var theme_display_name: String = sector_data.get("theme_name", theme_name)
		battlefield_grid_panel.populate(sectors_arr, theme_display_name)
		if not battlefield_grid_panel.regenerate_requested.is_connected(
				_on_regenerate_terrain_pressed):
			battlefield_grid_panel.regenerate_requested.connect(
				_on_regenerate_terrain_pressed)

	# Section 1: Terrain Theme
	_add_setup_section_header("TERRAIN SETUP")
	var theme_display: String = sector_data.get("theme_name", theme_name)
	_add_setup_text(theme_display, Color("#f59e0b"), 16)
	var description: String = terrain_data.get("description", "")
	if description.is_empty():
		# Fallback to compendium description from sector_data summary
		var summary: String = sector_data.get("summary", "")
		var lines: PackedStringArray = summary.split("\n")
		if lines.size() >= 2:
			description = lines[1]
	if not description.is_empty():
		_add_setup_text(description, Color("#9ca3af"))

	var notable_count: int = sector_data.get("notable_count", 0)
	_add_setup_text(
		"Notable features: %d | Grid: 4x4 sectors" % notable_count,
		Color("#808080"))

	_add_setup_separator()

	# Section 2: Sector-by-Sector Breakdown
	_terrain_section_start_index = setup_content.get_child_count()
	_add_setup_section_header("SECTOR LAYOUT")
	_build_sector_labels(sector_data)
	_terrain_section_end_index = setup_content.get_child_count()

	_add_setup_separator()

	# Section 3: Deployment Condition
	var condition_id: String = deployment_condition.get("condition_id", "NO_CONDITION")
	if condition_id != "NO_CONDITION" and not deployment_condition.is_empty():
		_add_setup_section_header("DEPLOYMENT CONDITION")
		var dep_title: String = deployment_condition.get("title", "Unknown")
		_add_setup_text(dep_title, Color("#D97706"), 16)
		var dep_desc: String = deployment_condition.get("description", "")
		if not dep_desc.is_empty():
			_add_setup_text(dep_desc, Color("#9ca3af"))
		var effects_summary: String = deployment_condition.get("effects_summary", "")
		if not effects_summary.is_empty():
			_add_setup_text("Effects: %s" % effects_summary, Color("#DC2626"))
		_add_setup_separator()

	# Section 4: Mission Objective
	var mission_dict: Dictionary = mission_data if mission_data is Dictionary else {}
	var objective_name: String = mission_dict.get("objective", mission_dict.get("type", ""))
	if not objective_name.is_empty():
		_add_setup_section_header("MISSION OBJECTIVE")
		_add_setup_text(objective_name, Color("#10B981"), 16)
		var obj_desc: String = mission_dict.get("description", "")
		if not obj_desc.is_empty():
			_add_setup_text(obj_desc, Color("#9ca3af"))
		_add_setup_separator()

	# Section 5: DLC Compendium Difficulty Instructions
	var dlc_instructions: Array = mission_dict.get("dlc_difficulty_instructions", [])
	if not dlc_instructions.is_empty():
		_add_setup_section_header("COMPENDIUM DIFFICULTY RULES")
		for instruction: String in dlc_instructions:
			if instruction.is_empty():
				continue
			# Color code by instruction type
			var color := Color("#4FC3F7")  # Default cyan
			if instruction.begins_with("AI:"):
				color = Color("#D97706")  # Orange for AI behavior
			elif instruction.begins_with("TOGGLE:"):
				color = Color("#DC2626")  # Red for difficulty toggles
			elif instruction.begins_with("MILESTONE:"):
				color = Color("#10B981")  # Green for milestones
			_add_setup_text(instruction, color)
		# Store AI type for escalation checks
		_dlc_ai_type = mission_dict.get("dlc_ai_type", "")
		_add_setup_separator()

		# Add escalation setup text if enabled
		if EscalatingBattlesManagerRef.is_enabled():
			_add_setup_section_header("ESCALATING BATTLES")
			var esc_text: String = EscalatingBattlesManagerRef.generate_setup_text(_dlc_ai_type)
			_add_setup_text(esc_text, Color("#D97706"))
			_add_setup_separator()

	# Section 6: Regenerate button
	var regen_button := Button.new()
	regen_button.text = "Regenerate Terrain Layout"
	regen_button.custom_minimum_size = Vector2(0, 44)
	regen_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.216, 0.255, 0.318, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.content_margin_left = 16.0
	btn_style.content_margin_top = 8.0
	btn_style.content_margin_right = 16.0
	btn_style.content_margin_bottom = 8.0
	regen_button.add_theme_stylebox_override("normal", btn_style)
	regen_button.add_theme_color_override("font_color", Color("#E0E0E0"))
	regen_button.pressed.connect(_on_regenerate_terrain_pressed)
	setup_content.add_child(regen_button)

var _regen_in_progress: bool = false

func _on_regenerate_terrain_pressed() -> void:
	## Re-roll the terrain sector layout
	if not _battlefield_generator or not setup_content or _regen_in_progress:
		return
	_regen_in_progress = true

	# Remove old terrain section nodes
	if _terrain_section_start_index >= 0 and _terrain_section_end_index > _terrain_section_start_index:
		var nodes_to_remove: Array[Node] = []
		var children: Array[Node] = []
		for child in setup_content.get_children():
			children.append(child)
		for i in range(_terrain_section_start_index, mini(_terrain_section_end_index, children.size())):
			nodes_to_remove.append(children[i])
		for node in nodes_to_remove:
			node.queue_free()

	# Wait one frame for nodes to be freed
	await get_tree().process_frame

	# Generate new sector data
	var new_sector_data: Dictionary = _battlefield_generator.generate_terrain_suggestions(
		_current_terrain_theme)

	# Also refresh the visual battlefield grid
	if battlefield_grid_panel and battlefield_grid_panel.has_method("populate"):
		var new_sectors: Array = new_sector_data.get("sectors", [])
		var theme_display: String = new_sector_data.get("theme_name", _current_terrain_theme)
		battlefield_grid_panel.populate(new_sectors, theme_display)

	# Re-insert terrain section at the same position
	var insert_idx: int = _terrain_section_start_index

	# Header — same style as _add_setup_section_header
	var header := Label.new()
	header.text = "SECTOR LAYOUT"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color("#808080"))
	header.uppercase = true
	setup_content.add_child(header)
	setup_content.move_child(header, insert_idx)
	insert_idx += 1

	var sectors: Array = new_sector_data.get("sectors", [])
	for sector: Dictionary in sectors:
		var features: Array = sector.get("features", [])
		if features.is_empty():
			continue
		var sector_label: String = sector.get("label", "??")
		var slabel := _create_setup_label("Sector %s" % sector_label, Color("#E0E0E0"), 14)
		setup_content.add_child(slabel)
		setup_content.move_child(slabel, insert_idx)
		insert_idx += 1
		for feat: String in features:
			var color := Color("#10B981") if feat.begins_with("NOTABLE:") else (
				Color("#6b7280") if feat.begins_with("Scatter:") else Color("#9ca3af"))
			var flabel := _create_setup_label("  %s" % feat, color, 13)
			setup_content.add_child(flabel)
			setup_content.move_child(flabel, insert_idx)
			insert_idx += 1

	# Ensure end index is at least start+1 (header always present)
	_terrain_section_end_index = max(insert_idx, _terrain_section_start_index + 1)

	# Log regeneration
	if battle_journal and battle_journal.has_method("add_entry"):
		battle_journal.add_entry("setup", "Terrain layout regenerated (%s)" % _current_terrain_theme)
	_log_message("Terrain layout regenerated", Color("#f59e0b"))
	_regen_in_progress = false

func _build_sector_labels(sector_data: Dictionary) -> void:
	## Build per-sector feature labels from BattlefieldGenerator output
	var sectors: Array = sector_data.get("sectors", [])
	for sector: Dictionary in sectors:
		var features: Array = sector.get("features", [])
		if features.is_empty():
			continue
		var sector_label: String = sector.get("label", "??")
		_add_setup_text("Sector %s" % sector_label, Color("#E0E0E0"), 14)
		for feat: String in features:
			var color := Color("#10B981") if feat.begins_with("NOTABLE:") else (
				Color("#6b7280") if feat.begins_with("Scatter:") else Color("#9ca3af"))
			_add_setup_text("  %s" % feat, color, 13)

func _map_theme_name_to_key(theme_name: String) -> String:
	## Map display name → BattlefieldGenerator theme key
	var lower: String = theme_name.to_lower()
	if "industrial" in lower:
		return "industrial_zone"
	elif "wilderness" in lower or "wild" in lower:
		return "wilderness"
	elif "alien" in lower or "ruin" in lower:
		return "alien_ruin"
	elif "crash" in lower:
		return "crash_site"
	# Fallback
	return "wilderness"

func _add_setup_section_header(text: String) -> void:
	## Add a section header label to the Setup tab
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#808080"))
	label.uppercase = true
	setup_content.add_child(label)

func _add_setup_text(text: String, color: Color = Color("#9ca3af"), font_size: int = 14) -> void:
	## Add a styled text label to the Setup tab
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_content.add_child(label)

func _add_setup_separator() -> void:
	## Add a thin separator to the Setup tab
	var sep := HSeparator.new()
	sep.modulate = Color(0.216, 0.255, 0.318, 0.5)
	setup_content.add_child(sep)

func _create_setup_label(text: String, color: Color, font_size: int = 14) -> Label:
	## Create a styled label without adding it (for manual positioning)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## ── DLC: Escalating Battles (Compendium pp.46-48) ────────────────

func _check_escalating_battles(round_number: int) -> void:
	## Check and resolve escalating battles at end of round
	if not EscalatingBattlesManagerRef.is_enabled():
		return
	if _dlc_ai_type.is_empty():
		return

	# Determine trigger conditions
	var enemies_removed: bool = enemy_units.any(func(u): return u.health <= 0)
	var objective_reached: bool = false  # Set by objective system if wired
	var crew_count: int = crew_units.filter(func(u): return u.health > 0).size()
	var enemy_count: int = enemy_units.filter(func(u): return u.health > 0).size()
	var outnumber_by: int = crew_count - enemy_count

	if not EscalatingBattlesManagerRef.should_check_escalation(
			enemies_removed, objective_reached, round_number,
			outnumber_by, _dlc_escalation_count):
		return

	# Roll escalation
	var result: Dictionary = EscalatingBattlesManagerRef.roll_escalation(_dlc_ai_type)
	if result.is_empty():
		return

	_dlc_escalation_count += 1
	var effect_id: String = result.get("id", "")

	# Variation mode: duplicate results have no effect but don't count toward limit
	if effect_id in _dlc_escalation_history:
		var variation_text: String = EscalatingBattlesManagerRef.generate_variation_text(
			result.get("name", ""))
		_log_message(variation_text, Color("#D97706"))
		_dlc_escalation_count -= 1  # Doesn't count toward the 3-roll limit
		if battle_journal:
			battle_journal.add_entry(variation_text)
		return

	_dlc_escalation_history.append(effect_id)

	# Log the escalation result
	var esc_text: String = EscalatingBattlesManagerRef.generate_escalation_check_text(
		round_number, _dlc_escalation_count, result)
	_log_message(esc_text, Color("#DC2626"))

	# Also log the instruction
	var instruction: String = result.get("instruction", "")
	if not instruction.is_empty():
		_log_message(instruction, Color("#D97706"))

	if battle_journal:
		battle_journal.add_entry(esc_text)
		if not instruction.is_empty():
			battle_journal.add_entry(instruction)


## ── DLC: Compendium Casualty/Injury Tables (Compendium p.86) ────

func _roll_compendium_casualty() -> Dictionary:
	## Roll on compendium casualty table if CASUALTY_TABLES enabled, else empty
	return CompendiumDifficultyTogglesRef.roll_casualty()

func _roll_compendium_injury() -> Dictionary:
	## Roll on compendium detailed injury table if DETAILED_INJURIES enabled, else empty
	return CompendiumDifficultyTogglesRef.roll_detailed_injury()


## ── DLC: No-Minis Combat Panel (Compendium pp.64-67) ────────────

func _setup_no_minis_panel(crew_size: int, enemy_count: int) -> void:
	## Create and wire No-Minis Combat panel when DLC enabled
	var dlc_mgr = get_node_or_null("/root/DLCManager")
	if not dlc_mgr:
		return
	if not dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.NO_MINIS_COMBAT):
		return

	no_minis_combat_panel = NoMinisCombatPanelClass.new()
	no_minis_combat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_minis_combat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Battle Log" tab alongside the journal
	if battle_log_content:
		battle_log_content.add_child(no_minis_combat_panel)

	# Initialize the abstract battle
	no_minis_combat_panel.setup_battle(crew_size, enemy_count)

	# Connect signals to journal
	if battle_journal:
		no_minis_combat_panel.round_advanced.connect(
			func(round_num: int) -> void:
				battle_journal.add_entry("[b]NO-MINIS:[/b] Round %d" % round_num)
		)
		no_minis_combat_panel.action_resolved.connect(
			func(action_text: String) -> void:
				battle_journal.add_entry("[b]NO-MINIS ACTION:[/b] %s" % action_text)
		)
		no_minis_combat_panel.battle_completed.connect(
			func(result: Dictionary) -> void:
				var rounds: int = result.get("rounds_played", 0)
				battle_journal.add_entry(
					"[b]NO-MINIS BATTLE ENDED[/b] after %d rounds" % rounds)
		)

	_log_message("No-Minis Combat mode active (Compendium pp.64-67)", UIColors.COLOR_EMERALD)


## ── DLC: Stealth Mission Panel (Compendium) ─────────────────────

func _setup_stealth_panel(mission_dict: Dictionary) -> void:
	## Create and wire Stealth Mission panel for stealth mission type
	stealth_mission_panel = StealthMissionPanelClass.new()
	stealth_mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stealth_mission_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Events" tab
	if events_content:
		events_content.add_child(stealth_mission_panel)

	# Initialize with mission data
	stealth_mission_panel.setup_mission(mission_dict)

	# Connect signals to journal
	if battle_journal:
		stealth_mission_panel.round_advanced.connect(
			func(round_num: int) -> void:
				battle_journal.add_entry("[b]STEALTH:[/b] Round %d" % round_num)
		)
		stealth_mission_panel.detection_triggered.connect(
			func() -> void:
				battle_journal.add_entry(
					"[color=#DC2626][b]STEALTH: DETECTED![/b] Combat begins.[/color]")
		)
		stealth_mission_panel.mission_completed.connect(
			func() -> void:
				battle_journal.add_entry(
					"[color=#10B981][b]STEALTH MISSION COMPLETE[/b][/color]")
		)

	_log_message("Stealth Mission mode active", UIColors.COLOR_EMERALD)

	# Switch to Events tab to show stealth panel
	if center_tabs:
		for i in center_tabs.get_tab_count():
			if center_tabs.get_tab_title(i) == "Events":
				center_tabs.current_tab = i
				break


## Tactical Unit Class

class TacticalUnit:
	var node_name: String = ""
	var team: String = "" # "crew" or "enemy"
	var node_position: Vector2i = Vector2i(-1, -1)
	var health: int = 3
	var max_health: int = 3
	var is_dead: bool = false
	var movement_points: int = 6
	var movement_remaining: int = 6
	var max_actions: int = 2
	var actions_remaining: int = 2
	var initiative_roll: int = 0
	var original_character = null

	# Combat stats
	var combat_skill: int = 0
	var toughness: int = 0
	var savvy: int = 0
	var reactions: int = 0

	# Reaction economy (Five Parsecs Swift species = 1 max, others = 3)
	var max_reactions_per_round: int = 3
	var reactions_used_this_round: int = 0

	# Equipment
	var _weapon_range: int = 12
	var _weapon_shots: int = 1
	var _weapon_damage: int = 1
	var _armor_save: int = 0

	func initialize_from_crew_member(crew_member) -> void:
		## Initialize unit from crew member data (Resource or Dictionary)
		original_character = crew_member
		if crew_member is Dictionary:
			node_name = crew_member.get("name", crew_member.get("character_name", "Crew Member"))
			combat_skill = crew_member.get("combat", crew_member.get("combat_skill", 0))
			toughness = crew_member.get("toughness", 0)
			savvy = crew_member.get("savvy", 0)
			reactions = crew_member.get("reaction", crew_member.get("reactions", 0))
		else:
			# Resource/Object — use .get() which works on Objects too
			var _name_val = crew_member.get("character_name") if crew_member else null
			node_name = str(_name_val) if _name_val else "Crew Member"
			combat_skill = crew_member.get("combat_skill") if crew_member and crew_member.get("combat_skill") != null else 0
			toughness = crew_member.get("toughness") if crew_member and crew_member.get("toughness") != null else 0
			savvy = crew_member.get("savvy") if crew_member and crew_member.get("savvy") != null else 0
			reactions = crew_member.get("reactions") if crew_member and crew_member.get("reactions") != null else 0

		# Set health based on toughness
		max_health = max(1, toughness)
		health = max_health

		# Initialize reaction economy from character (Swift = 1 max)
		initialize_reactions_from_character()

	func initialize_from_enemy(enemy) -> void:
		## Initialize unit from enemy data (Resource or Dictionary)
		original_character = enemy
		if enemy is Dictionary:
			node_name = enemy.get("name", "Enemy")
			combat_skill = enemy.get("combat", enemy.get("combat_skill", 0))
			toughness = enemy.get("toughness", 0)
			reactions = enemy.get("reaction", enemy.get("reactions", 0))
		else:
			var _name_val = enemy.get("name") if enemy else null
			node_name = str(_name_val) if _name_val else "Enemy"
			combat_skill = enemy.get("combat_skill") if enemy and enemy.get("combat_skill") != null else 0
			toughness = enemy.get("toughness") if enemy and enemy.get("toughness") != null else 0
			reactions = enemy.get("reactions") if enemy and enemy.get("reactions") != null else 0

		max_health = max(1, toughness)
		health = max_health

		# Initialize reaction economy from enemy character
		initialize_reactions_from_character()

	func get_initiative_bonus() -> int:
		## Get initiative bonus based on reactions
		return reactions

	func take_damage(amount: int) -> void:
		## Apply damage to the unit
		health = max(0, health - amount)
		if health <= 0:
			is_dead = true

	func can_act() -> bool:
		## Check if unit can take actions
		return health > 0 and actions_remaining > 0

	func can_move() -> bool:
		## Check if unit can move
		return health > 0 and movement_remaining > 0

	func get_reactions_remaining() -> int:
		## Get remaining reactions this round
		return max(0, max_reactions_per_round - reactions_used_this_round)

	func can_use_reaction() -> bool:
		## Check if unit has reactions available
		return health > 0 and get_reactions_remaining() > 0

	func spend_reaction() -> bool:
		## Spend one reaction. Returns true if successful.
		if not can_use_reaction():
			return false
		reactions_used_this_round += 1
		return true

	func reset_reactions() -> void:
		## Reset reactions at start of new round
		reactions_used_this_round = 0

	func initialize_reactions_from_character() -> void:
		## Initialize reaction cap from original character (Swift = 1)
		if original_character and original_character is Object and original_character.has_method("get_max_reactions"):
			max_reactions_per_round = original_character.get_max_reactions()
		elif original_character and "max_reactions_per_round" in original_character:
			if original_character is Dictionary:
				max_reactions_per_round = original_character.get("max_reactions_per_round", 3)
			else:
				max_reactions_per_round = original_character.max_reactions_per_round
		# Check for Swift species via origin field (save data uses "origin", not "_origin")
		elif original_character:
			var origin_str: String = ""
			if original_character is Dictionary:
				origin_str = str(original_character.get("origin", original_character.get("_origin", ""))).to_lower()
			elif "_origin" in original_character:
				origin_str = str(original_character._origin).to_lower()
			if "swift" in origin_str:
				max_reactions_per_round = 1  # Swift limited to 1 reaction
