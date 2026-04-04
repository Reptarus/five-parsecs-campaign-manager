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

## Keep-as-preload: used externally for enum/static access, always needed
const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")
const EscalatingBattlesManagerRef = preload("res://src/core/managers/EscalatingBattlesManager.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const BattleResolverClass = preload("res://src/core/battle/BattleResolver.gd")

# Design system spacing (UIColors canonical source)
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL

## Lazy-load registry: scenes/scripts loaded on first access per tier (Phase 33 optimization)
const _SCENE_REGISTRY: Dictionary = {
	# Core (always needed)
	"tier_selection": "res://src/ui/components/battle/TierSelectionPanel.gd",
	"pre_battle_checklist": "res://src/ui/components/battle/PreBattleChecklist.gd",
	"battlefield_generator": "res://src/core/battle/BattlefieldGenerator.gd",
	"character_status_card": "res://src/ui/components/battle/CharacterStatusCard.tscn",
	# LOG_ONLY tier
	"battle_journal": "res://src/ui/components/battle/BattleJournal.tscn",
	"dice_dashboard": "res://src/ui/components/battle/DiceDashboard.tscn",
	"combat_calculator": "res://src/ui/components/battle/CombatCalculator.tscn",
	"battle_round_hud": "res://src/ui/components/battle/BattleRoundHUD.gd",
	"cheat_sheet": "res://src/ui/components/battle/CheatSheetPanel.gd",
	"weapon_table": "res://src/ui/components/battle/WeaponTableDisplay.tscn",
	"combat_situation": "res://src/ui/components/battle/CombatSituationPanel.tscn",
	"dual_input_roll": "res://src/ui/components/battle/DualInputRoll.gd",
	"character_quick_roll": "res://src/ui/components/battle/CharacterQuickRollPanel.gd",
	"brawl_resolver": "res://src/ui/components/battle/BrawlResolverPanel.gd",
	# ASSISTED tier
	"morale_tracker": "res://src/ui/components/battle/MoralePanicTracker.tscn",
	"reaction_dice": "res://src/ui/components/battle/ReactionDicePanel.tscn",
	"reaction_assignment": "res://src/ui/components/battle/ReactionRollAssignment.gd",
	"activation_tracker": "res://src/ui/components/battle/ActivationTrackerPanel.tscn",
	"deployment_conditions": "res://src/ui/components/battle/DeploymentConditionsPanel.tscn",
	"objective_display": "res://src/ui/components/battle/ObjectiveDisplay.tscn",
	"initiative_calculator": "res://src/ui/components/battle/InitiativeCalculator.tscn",
	"event_resolution": "res://src/ui/components/battle/EventResolutionPanel.gd",
	"victory_progress": "res://src/ui/components/battle/VictoryProgressPanel.gd",
	# FULL_ORACLE tier
	"enemy_intent": "res://src/ui/components/battle/EnemyIntentPanel.gd",
	"enemy_generation": "res://src/ui/components/battle/EnemyGenerationWizard.tscn",
	# Compendium DLC
	"no_minis_combat": "res://src/ui/components/battle/NoMinisCombatPanel.gd",
	"stealth_mission": "res://src/ui/components/battle/StealthMissionPanel.gd",
	"street_fight_mission": "res://src/ui/components/battle/StreetFightPanel.gd",
	"salvage_mission": "res://src/ui/components/battle/SalvageMissionPanel.gd",
}
var _scene_cache: Dictionary = {}

## Lazy-load a scene/script from the registry (loads on first access, cached)
func _get_res(key: String) -> Resource:
	if key not in _scene_cache:
		_scene_cache[key] = load(_SCENE_REGISTRY[key])
	return _scene_cache[key]
# GlobalEnums available as autoload singleton

# UI Nodes — progressive disclosure layout
@onready var return_button: Button = %ReturnButton
@onready var auto_resolve_button: Button = %AutoResolveButton
@onready var title_label: Label = %TitleLabel
@onready var tier_badge: Label = %TierBadge
@onready var phase_breadcrumb: HBoxContainer = %PhaseBreadcrumb

# Panel containers (visibility controlled by _apply_stage_visibility)
@onready var left_panel: PanelContainer = %LeftPanel
@onready var crew_content: VBoxContainer = %CrewContent
@onready var center_panel: VBoxContainer = %CenterPanel
@onready var battlefield_grid_panel: PanelContainer = %BattlefieldGridPanel
@onready var phase_content_panel: PanelContainer = %PhaseContentPanel
@onready var phase_content: VBoxContainer = %PhaseContent
@onready var right_panel: PanelContainer = %RightPanel
@onready var right_tabs: TabContainer = %RightTabs
@onready var tools_content: VBoxContainer = %ToolsContent
@onready var reference_content: VBoxContainer = %ReferenceContent
@onready var setup_content: VBoxContainer = %SetupContent

# Bottom bar (two rows: PhaseHUD + ActionBar)
@onready var bottom_bar: PanelContainer = $EdgeMargin/MainContainer/BottomBar
@onready var phase_hud: HBoxContainer = %PhaseHUD
@onready var turn_indicator: Label = %TurnIndicator
@onready var action_buttons: HBoxContainer = %PhaseButtonsContainer
@onready var end_turn_button: Button = %EndTurnButton

# Battle log (inside PhaseContentPanel)
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
## battlefield_manager removed — terrain handled by BattlefieldGenerator + GridPanel
var dice_manager: Node = null
var alpha_manager: Node = null
var battle_tracker: Node = null # For reaction economy tracking

## Sprint 11.4: BattleRoundTracker integration for phase-based combat
var round_tracker: Node = null # BattleRoundTracker instance for Five Parsecs combat rounds
var _round_tracker_connected: bool = false

# Tier controller for component visibility (wired in Sprint 2)
var tier_controller: Resource = null # FPCM_BattleTierController instance

# LOG_ONLY component instances (Sprint 3)
var unified_log: FPCM_UnifiedBattleLog = null  # Replaces BattleJournal + FallbackLog
var dice_dashboard: Control = null
var combat_calculator: Control = null
var battle_round_hud: Control = null
var character_cards: Array = [] # Array of CharacterStatusCard instances

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

# Battle Parity components (Phase 34 — Core Rules combat companion)
var character_quick_roll: PanelContainer = null
var brawl_resolver: PanelContainer = null
var reaction_assignment: PanelContainer = null

# Quick Dice Bar (always visible in right panel)
var _quick_dice_label: Label = null

# Compendium DLC panel instances
var no_minis_combat_panel: PanelContainer = null
var stealth_mission_panel: PanelContainer = null
var street_fight_panel: PanelContainer = null
var salvage_mission_panel: PanelContainer = null

# Responsive layout
var _responsive_manager: Node = null
var _resize_debounce_timer: Timer = null

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
var _is_bug_hunt_mode: bool = false
## Battle stage enum — controls progressive disclosure UI
enum BattleStage {
	TIER_SELECT,
	SETUP,
	DEPLOYMENT,
	COMBAT,
	RESOLUTION
}
var current_stage: int = BattleStage.TIER_SELECT
var battle_phase: String = "deployment" # legacy compat — will migrate fully to BattleStage
var _battle_initialized: bool = false # Tracks whether initialize_battle() was called

# DLC Escalating Battles tracking (Compendium pp.46-48)
var _dlc_ai_type: String = ""
var _dlc_escalation_count: int = 0
var _dlc_escalation_history: Array[String] = [] # Track for variation mode

## Grid/positioning/deployment_zones removed — handled by BattlefieldGenerator

# Battle Result
class BattleResult:
	var victory: bool = false
	var crew_casualties: Array = []
	var crew_injuries: Array = []
	var rounds_fought: int = 0

func _ready() -> void:
	_initialize_managers()
	_connect_signals()
	_setup_ui()
	# Deferred check: if initialize_battle() wasn't called by the campaign flow,
	# show tier selection anyway so standalone/MCP/demo mode works (BUG-B01 fix)
	call_deferred("_check_standalone_mode")

func _initialize_managers() -> void:
	## Initialize manager references
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null
	battle_tracker = get_node("/root/BattleTracker") if has_node("/root/BattleTracker") else null

	# Responsive layout manager
	_responsive_manager = get_node_or_null("/root/ResponsiveManager")
	if _responsive_manager:
		_responsive_manager.viewport_resized.connect(_on_viewport_resized)

	# Debounce timer for resize events (prevents frame drops from rapid redraws)
	_resize_debounce_timer = Timer.new()
	_resize_debounce_timer.one_shot = true
	_resize_debounce_timer.wait_time = 0.15
	_resize_debounce_timer.timeout.connect(_apply_responsive_layout)
	add_child(_resize_debounce_timer)

## Legacy _setup_battlefield(), _generate_battlefield_terrain(), terrain placement methods,
## and _setup_deployment_zones() removed. Terrain is now generated by FPCM_BattlefieldGenerator
## and displayed via BattlefieldGridPanel/BattlefieldMapView using text-based sector descriptions.

func _connect_signals() -> void:
	## Connect UI and system signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn)
	if return_button:
		return_button.pressed.connect(_on_return_to_battle_resolution)
	if auto_resolve_button:
		auto_resolve_button.pressed.connect(_on_auto_resolve_battle)

	# Battlefield signals removed — terrain is text-based via BattlefieldGenerator

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
	## Setup the tactical UI with progressive disclosure
	if turn_indicator:
		turn_indicator.text = "Setting Up"
	if battle_log:
		battle_log.clear()
	_log_message("Tactical battle mode activated", UIColors.COLOR_EMERALD)

	# Instance LOG_ONLY components into their zones
	_instance_log_only_components()

	# Default to LOG_ONLY visibility until tier is selected
	_apply_tier_visibility(0)

	# Build breadcrumb navigation
	_build_phase_breadcrumb()

	# Start with everything hidden — tier selection deferred to initialize_battle()
	_apply_stage_visibility(BattleStage.TIER_SELECT)

	# Initial responsive layout pass
	call_deferred("_apply_responsive_layout")

func _check_standalone_mode() -> void:
	## If initialize_battle() was never called (standalone/MCP/demo load),
	## show tier selection overlay so the UI is usable (BUG-B01, B06, B17, B18 fix)
	if _battle_initialized:
		return
	# QA-FIX: Only show tier selection if actually visible and not embedded in campaign flow.
	# When loaded as a child of CampaignTurnController's PhaseContainer, this node starts
	# hidden — tier selection should only appear when initialize_battle() is called explicitly.
	if not visible:
		return
	var ancestor := get_parent()
	while ancestor:
		if ancestor.name == "PhaseContainer":
			return # Embedded in campaign turn flow — not standalone
		ancestor = ancestor.get_parent()
	_log_message("Standalone mode — no campaign data. Set up your table manually.", UIColors.COLOR_WARNING)
	_show_tier_selection()

# ============================================================================
# RESPONSIVE LAYOUT
# ============================================================================

func _get_ui_scale() -> float:
	## Scale factor relative to design base (1920px width)
	var vp_width := get_viewport().get_visible_rect().size.x
	return clampf(vp_width / 1920.0, 0.75, 2.0)

func _scaled_font(base: int) -> int:
	## Scale font size using ResponsiveManager or viewport-based fallback
	if _responsive_manager and _responsive_manager.has_method("get_responsive_font_size"):
		return _responsive_manager.get_responsive_font_size(base)
	# Fallback: scale by viewport ratio (more noticeable than RM's 1.1x at WIDE)
	return int(float(base) * _get_ui_scale())

func _scaled_spacing(base: int) -> int:
	## Scale spacing using ResponsiveManager
	if _responsive_manager and _responsive_manager.has_method("get_responsive_spacing"):
		return _responsive_manager.get_responsive_spacing(base)
	return base

func _on_viewport_resized(_new_size: Vector2) -> void:
	## Debounce resize events to avoid frame drops from rapid redraws
	if _resize_debounce_timer:
		_resize_debounce_timer.start()

func _apply_responsive_layout() -> void:
	## Scale panel sizes proportionally to viewport
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return

	# Proportional column widths (percentage-based with min/max clamps)
	if left_panel:
		left_panel.custom_minimum_size.x = clampf(vp.x * 0.15, 200, 400)
	if right_panel:
		right_panel.custom_minimum_size.x = clampf(vp.x * 0.20, 260, 500)

	# Map minimum scales with viewport
	if battlefield_grid_panel:
		var map_view: BattlefieldMapView = null
		for child in battlefield_grid_panel.get_children():
			if child is VBoxContainer:
				for subchild in child.get_children():
					if subchild is BattlefieldMapView:
						map_view = subchild
						break
		if map_view:
			map_view.custom_minimum_size = Vector2(
				clampf(vp.x * 0.35, 480, 1200),
				clampf(vp.y * 0.30, 280, 600)
			)

	# Phase content panel minimum height scales
	if phase_content_panel:
		phase_content_panel.custom_minimum_size.y = clampf(vp.y * 0.15, 140, 300)

func _apply_stage_visibility(stage: int) -> void:
	## Control which panels are visible based on current battle stage
	current_stage = stage

	# Update breadcrumb
	_update_breadcrumb(stage)

	match stage:
		BattleStage.TIER_SELECT:
			# Only overlay visible — everything else hidden
			if left_panel: left_panel.visible = false
			if center_panel: center_panel.visible = false
			if right_panel: right_panel.visible = false
			if phase_content_panel: phase_content_panel.visible = false
			if return_button: return_button.visible = false
			if auto_resolve_button: auto_resolve_button.visible = false
			if end_turn_button: end_turn_button.visible = false
			if bottom_bar: bottom_bar.visible = false
			if phase_breadcrumb: phase_breadcrumb.visible = false

		BattleStage.SETUP:
			# Map + setup checklist only
			if left_panel: left_panel.visible = false
			if center_panel: center_panel.visible = true
			if battlefield_grid_panel: battlefield_grid_panel.visible = true
			if phase_content_panel: phase_content_panel.visible = false
			if right_panel: right_panel.visible = true
			if right_tabs: right_tabs.current_tab = 0 # Setup tab
			if return_button: return_button.visible = false
			if auto_resolve_button: auto_resolve_button.visible = false
			if end_turn_button:
				end_turn_button.visible = true
				end_turn_button.text = "Begin Battle"
			if turn_indicator:
				turn_indicator.text = "Set Up Your Battlefield"
			if bottom_bar: bottom_bar.visible = true
			if phase_breadcrumb: phase_breadcrumb.visible = true
			if battle_round_hud: battle_round_hud.visible = true
			if action_buttons: action_buttons.visible = true

		BattleStage.DEPLOYMENT:
			# Map with zones + crew cards + deployment info
			if left_panel: left_panel.visible = true
			if center_panel: center_panel.visible = true
			if battlefield_grid_panel: battlefield_grid_panel.visible = true
			if phase_content_panel: phase_content_panel.visible = false
			if right_panel: right_panel.visible = true
			if right_tabs: right_tabs.current_tab = 0 # Setup tab
			if return_button: return_button.visible = false
			if auto_resolve_button: auto_resolve_button.visible = false
			if end_turn_button:
				end_turn_button.visible = true
				end_turn_button.text = "Confirm Deployment"
			if turn_indicator:
				turn_indicator.text = "Deploy Your Crew"
			if bottom_bar: bottom_bar.visible = true
			if phase_breadcrumb: phase_breadcrumb.visible = true
			if battle_round_hud: battle_round_hud.visible = true
			if action_buttons: action_buttons.visible = true
			# Highlight deployment zones on the map
			_set_map_deployment_highlight(true)

		BattleStage.COMBAT:
			# Full companion layout
			if left_panel: left_panel.visible = true
			if center_panel: center_panel.visible = true
			if battlefield_grid_panel: battlefield_grid_panel.visible = true
			if phase_content_panel: phase_content_panel.visible = true
			if right_panel: right_panel.visible = true
			if right_tabs: right_tabs.current_tab = 1 # Tools tab
			if return_button: return_button.visible = true
			if auto_resolve_button: auto_resolve_button.visible = true
			if end_turn_button:
				end_turn_button.visible = true
				end_turn_button.text = "End Turn"
			if bottom_bar: bottom_bar.visible = true
			if phase_breadcrumb: phase_breadcrumb.visible = true
			if battle_round_hud: battle_round_hud.visible = true
			if action_buttons: action_buttons.visible = true
			if turn_indicator:
				if round_tracker and round_tracker.has_method("get_current_round"):
					turn_indicator.text = "Round %d - Combat" % round_tracker.get_current_round()
				else:
					turn_indicator.text = "Round 1 - Combat"
			# Subtle deployment zones during combat
			_set_map_deployment_highlight(false)

		BattleStage.RESOLUTION:
			# Results only
			if left_panel: left_panel.visible = false
			if center_panel: center_panel.visible = true
			if battlefield_grid_panel: battlefield_grid_panel.visible = false
			if phase_content_panel: phase_content_panel.visible = true
			if right_panel: right_panel.visible = false
			if return_button: return_button.visible = true
			if auto_resolve_button: auto_resolve_button.visible = false
			if end_turn_button:
				end_turn_button.visible = true
				end_turn_button.text = "Return to Campaign"
			if battle_round_hud: battle_round_hud.visible = false
			if phase_breadcrumb: phase_breadcrumb.visible = false
			if action_buttons: action_buttons.visible = false
			if turn_indicator:
				turn_indicator.text = "Battle Complete"

func _build_phase_breadcrumb() -> void:
	## Build the stage breadcrumb in TopBar
	if not phase_breadcrumb:
		return
	# Clear existing
	for child in phase_breadcrumb.get_children():
		child.queue_free()

	var stages := ["Setup", "Deploy", "Combat"]
	for i: int in range(stages.size()):
		if i > 0:
			var sep := Label.new()
			sep.text = " > "
			sep.add_theme_color_override(
				"font_color", Color(0.4, 0.4, 0.5))
			sep.add_theme_font_size_override("font_size", _scaled_font(12))
			phase_breadcrumb.add_child(sep)
		var lbl := Label.new()
		lbl.text = stages[i]
		lbl.add_theme_font_size_override("font_size", _scaled_font(12))
		lbl.add_theme_color_override(
			"font_color", Color(0.4, 0.4, 0.5))
		lbl.name = "Breadcrumb_%d" % i
		phase_breadcrumb.add_child(lbl)

func _update_breadcrumb(stage: int) -> void:
	## Highlight the active stage in the breadcrumb
	if not phase_breadcrumb:
		return
	# Map BattleStage to breadcrumb index (TIER_SELECT=none, SETUP=0, DEPLOY=1, COMBAT=2)
	var active_idx: int = -1
	match stage:
		BattleStage.SETUP: active_idx = 0
		BattleStage.DEPLOYMENT: active_idx = 1
		BattleStage.COMBAT, BattleStage.RESOLUTION: active_idx = 2

	for i: int in range(3):
		var lbl: Label = phase_breadcrumb.get_node_or_null(
			"Breadcrumb_%d" % i)
		if lbl:
			if i == active_idx:
				lbl.add_theme_color_override(
					"font_color", Color(0.878, 0.878, 0.878))
			elif i < active_idx:
				lbl.add_theme_color_override(
					"font_color", Color(0.063, 0.725, 0.506))
			else:
				lbl.add_theme_color_override(
					"font_color", Color(0.4, 0.4, 0.5))

func _instance_log_only_components() -> void:
	## Instance and add LOG_ONLY tier components to zones
	# UnifiedBattleLog → Center / replaces BattleJournal + FallbackLog
	unified_log = FPCM_UnifiedBattleLog.new()
	unified_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unified_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(unified_log)

	# DiceDashboard
	dice_dashboard = _get_res("dice_dashboard").instantiate()
	dice_dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dice_manager:
		dice_dashboard.set_dice_system(dice_manager)

	# CombatCalculator
	combat_calculator = _get_res("combat_calculator").instantiate()
	combat_calculator.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# BattleRoundHUD → Bottom bar's VBoxContainer (before PhaseHUD and ActionBar)
	battle_round_hud = _get_res("battle_round_hud").new()
	battle_round_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom_content: VBoxContainer = bottom_bar.get_child(0) if bottom_bar and bottom_bar.get_child_count() > 0 else null
	if bottom_content and bottom_content is VBoxContainer:
		bottom_content.add_child(battle_round_hud)
		bottom_content.move_child(battle_round_hud, 0)
		# Hide PhaseHUD container (redundant) but reparent TurnIndicator
		# to ActionBar so stage context text ("Set Up Your Battlefield") stays visible
		if phase_hud:
			phase_hud.visible = false
		if turn_indicator and turn_indicator.get_parent() == phase_hud:
			phase_hud.remove_child(turn_indicator)
			turn_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			turn_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var action_bar: HBoxContainer = end_turn_button.get_parent() if end_turn_button else null
			if action_bar:
				action_bar.add_child(turn_indicator)
				action_bar.move_child(turn_indicator, 0)

	# CombatSituationPanel
	combat_situation_panel = _get_res("combat_situation").instantiate()
	combat_situation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# DualInputRoll (compact, always visible outside accordion)
	dual_input_roll = _get_res("dual_input_roll").new()
	dual_input_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# CharacterQuickRollPanel
	character_quick_roll = _get_res("character_quick_roll").new()
	character_quick_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# BrawlResolverPanel
	brawl_resolver = _get_res("brawl_resolver").new()
	brawl_resolver.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Wrap tools in accordion (exclusive mode — one open at a time)
	if tools_content:
		var tools_accordion := FPCM_AccordionToolContainer.new()
		tools_accordion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools_accordion.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tools_accordion.add_section("Quick Dice Rolls", dice_dashboard)
		tools_accordion.add_section("Combat Calculator", combat_calculator)
		tools_accordion.add_section("Combat Situation", combat_situation_panel)
		tools_accordion.add_section("Character Quick Roll", character_quick_roll)
		tools_accordion.add_section("Brawl Resolver", brawl_resolver)
		tools_content.add_child(tools_accordion)
		# DualInputRoll stays always-visible (compact single row)
		tools_content.add_child(dual_input_roll)

	# CheatSheetPanel → Right / "Reference" tab
	cheat_sheet_panel = _get_res("cheat_sheet").new()
	cheat_sheet_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_sheet_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if reference_content:
		reference_content.add_child(cheat_sheet_panel)

	# WeaponTableDisplay → Right / "Reference" tab
	weapon_table_display = _get_res("weapon_table").instantiate()
	weapon_table_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_table_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if reference_content:
		reference_content.add_child(weapon_table_display)

	# Quick Dice Bar — always visible below the right panel tabs
	_build_quick_dice_bar()

	# Connect component signals to journal logging
	_connect_component_signals()

	# Instance ASSISTED tier components (hidden by tab visibility)
	_instance_assisted_components()

	# Instance FULL_ORACLE tier components (hidden by tab visibility)
	_instance_oracle_components()

func _build_quick_dice_bar() -> void:
	## Build a persistent quick dice bar at the bottom of the right panel.
	## Always visible regardless of active tab — 1d6, 2d6, d100 + last result.
	if not right_panel:
		return

	# The right panel is a PanelContainer with RightTabs as its child.
	# We need to wrap the content in a VBox so the dice bar sits below the tabs.
	var existing_tabs: TabContainer = right_tabs
	if not existing_tabs:
		return

	# Reparent: remove TabContainer from right_panel, add VBox, add both
	right_panel.remove_child(existing_tabs)
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)

	# Re-add tabs (takes most space)
	existing_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(existing_tabs)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = Color(0.216, 0.255, 0.318, 0.5)
	right_vbox.add_child(sep)

	# Quick Dice Bar
	var dice_bar := HBoxContainer.new()
	dice_bar.name = "QuickDiceBar"
	dice_bar.add_theme_constant_override("separation", SPACING_SM)
	dice_bar.custom_minimum_size = Vector2(0, 40)
	right_vbox.add_child(dice_bar)

	var bar_label := Label.new()
	bar_label.text = "Quick:"
	bar_label.add_theme_font_size_override("font_size", _scaled_font(11))
	bar_label.add_theme_color_override("font_color", Color(0.502, 0.502, 0.502))
	dice_bar.add_child(bar_label)

	# Dice buttons
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.122, 0.137, 0.216, 0.8)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.216, 0.255, 0.318, 1)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.content_margin_left = float(SPACING_SM)
	btn_style.content_margin_right = float(SPACING_SM)
	btn_style.content_margin_top = float(SPACING_XS)
	btn_style.content_margin_bottom = float(SPACING_XS)

	for dice_config: Array in [["1d6", 1, 6], ["2d6", 2, 6], ["d100", 1, 100]]:
		var btn := Button.new()
		btn.text = dice_config[0]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", _scaled_font(12))
		btn.add_theme_color_override("font_color", Color(0.878, 0.878, 0.878))
		btn.add_theme_stylebox_override("normal", btn_style.duplicate())
		var count: int = dice_config[1]
		var sides: int = dice_config[2]
		btn.pressed.connect(_on_quick_dice_pressed.bind(count, sides, dice_config[0]))
		dice_bar.add_child(btn)

	# Result label
	_quick_dice_label = Label.new()
	_quick_dice_label.text = "—"
	_quick_dice_label.add_theme_font_size_override("font_size", _scaled_font(14))
	_quick_dice_label.add_theme_color_override("font_color", Color(0.961, 0.62, 0.043))
	_quick_dice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dice_bar.add_child(_quick_dice_label)

func _on_quick_dice_pressed(count: int, sides: int, label: String) -> void:
	## Roll dice from the quick dice bar
	var dice_mgr = get_node_or_null("/root/DiceManager")
	var total: int = 0
	var results: Array[int] = []
	for i: int in range(count):
		var roll: int = 0
		if dice_mgr and dice_mgr.has_method("roll_dice"):
			roll = dice_mgr.roll_dice(1, sides)
		else:
			roll = randi_range(1, sides)
		results.append(roll)
		total += roll

	# Update result label
	if _quick_dice_label:
		if count == 1:
			_quick_dice_label.text = "%s: %d" % [label, total]
		else:
			_quick_dice_label.text = "%s: %d (%s)" % [label, total, "+".join(results.map(func(r): return str(r)))]

	# Log to battle journal
	var log_text: String
	if count > 1:
		log_text = "Quick %s: %d (%s)" % [label, total, "+".join(results.map(func(r): return str(r)))]
	else:
		log_text = "Quick %s: %d" % [label, total]
	if unified_log and unified_log.has_method("add_entry"):
		unified_log.add_entry("dice", log_text)
	_log_message(log_text, Color(0.961, 0.62, 0.043))

func _instance_assisted_components() -> void:
	## Instance ASSISTED tier components into their zones
	# MoralePanicTracker → Center / "Tracking" tab
	morale_tracker = _get_res("morale_tracker").instantiate()
	morale_tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(morale_tracker)

	# VictoryProgressPanel → Center / "Tracking" tab
	victory_progress = _get_res("victory_progress").new()
	victory_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(victory_progress)

	# ReactionDicePanel → Center / "Tracking" tab
	reaction_dice_panel = _get_res("reaction_dice").instantiate()
	reaction_dice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(reaction_dice_panel)

	# ActivationTrackerPanel → Left / "Units" tab
	activation_tracker = _get_res("activation_tracker").instantiate()
	activation_tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activation_tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(activation_tracker)

	# DeploymentConditionsPanel → Center / "Events" tab
	deployment_conditions = _get_res("deployment_conditions").instantiate()
	deployment_conditions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(deployment_conditions)

	# ObjectiveDisplay → Center / "Events" tab
	objective_display = _get_res("objective_display").instantiate()
	objective_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(objective_display)

	# InitiativeCalculator → stored for overlay popup
	initiative_calculator = _get_res("initiative_calculator").instantiate()

	# EventResolutionPanel → stored for overlay popup
	event_resolution = _get_res("event_resolution").new()

	# ReactionRollAssignment → Right / "Tools" tab (interactive dice assignment)
	reaction_assignment = _get_res("reaction_assignment").new()
	reaction_assignment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tools_content:
		tools_content.add_child(reaction_assignment)

	# Connect ASSISTED component signals
	_connect_assisted_signals()

func _instance_oracle_components() -> void:
	## Instance FULL_ORACLE tier components into their zones
	# EnemyIntentPanel → Left / "Enemies" tab
	enemy_intent_panel = _get_res("enemy_intent").new()
	enemy_intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_intent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(enemy_intent_panel)

	# EnemyGenerationWizard → shown as modal overlay (not stacked in PhaseContent)
	enemy_generation_wizard = _get_res("enemy_generation").instantiate()
	enemy_generation_wizard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# NOT added to phase_content — will be shown via _show_overlay()

	# Connect FULL_ORACLE component signals
	if enemy_intent_panel and unified_log:
		enemy_intent_panel.intent_revealed.connect(
			func(enemy_id: String, intent: Dictionary) -> void:
				var action: String = intent.get("action", "unknown")
				unified_log.log_action("Enemy AI", "%s: %s" % [enemy_id, action])
		)
		enemy_intent_panel.oracle_instruction_ready.connect(
			func(group_name: String, instruction: String) -> void:
				_log_message("[Oracle] %s: %s" % [group_name, instruction], UIColors.COLOR_WARNING)
		)

	if enemy_generation_wizard:
		enemy_generation_wizard.enemies_generated.connect(
			func(enemies: Array) -> void:
				_hide_overlay()
				if unified_log:
					unified_log.log_event("Enemies", "%d enemies generated" % enemies.size())
		)
		if enemy_generation_wizard.has_signal("generation_cancelled"):
			enemy_generation_wizard.generation_cancelled.connect(_hide_overlay)

func _connect_assisted_signals() -> void:
	## Connect ASSISTED component signals to journal/hub
	if morale_tracker and unified_log:
		morale_tracker.morale_check_performed.connect(
			func(result: Dictionary) -> void:
				unified_log.log_morale(
					"Panic Check: %d kills, %d bailed (%s)" % [
						result.get("kills", 0),
						result.get("bails", 0),
						result.get("enemy_type", "")
					]
				)
		)
		morale_tracker.enemies_bailed.connect(
			func(bail_count: int) -> void:
				unified_log.log_morale("Bailed", bail_count)
		)

	if event_resolution and unified_log:
		event_resolution.event_resolved.connect(
			func(event: Dictionary, outcome: Dictionary) -> void:
				var name: String = event.get("name", "Unknown")
				unified_log.log_event(
					name, outcome.get("description", "")
				)
		)

	# VictoryProgressPanel — win/loss detection
	if victory_progress and unified_log:
		victory_progress.victory_condition_met.connect(
			func(condition_type: String) -> void:
				unified_log.log_event("VICTORY", condition_type)
				_log_message("Victory condition met: %s" % condition_type, UIColors.COLOR_EMERALD)
		)
		victory_progress.defeat_condition_triggered.connect(
			func(reason: String) -> void:
				unified_log.log_event("DEFEAT", reason)
				_log_message("Defeat: %s" % reason, UIColors.COLOR_DANGER)
		)
		victory_progress.objective_status_changed.connect(
			func(objective_id: String, status: String) -> void:
				unified_log.log_action("Objective", "%s: %s" % [objective_id, status])
		)

	# ActivationTrackerPanel — unit turn tracking
	if activation_tracker and unified_log:
		activation_tracker.unit_activation_requested.connect(
			func(unit_id: String) -> void:
				unified_log.log_action("Activation", unit_id)
		)
		activation_tracker.reset_all_requested.connect(
			func() -> void:
				unified_log.log_action("Activation", "All units reset for new round")
		)

	# ObjectiveDisplay — mission objective tracking
	if objective_display and unified_log:
		objective_display.objective_rolled.connect(
			func(objective) -> void:
				var obj_name: String = objective.name if objective and "name" in objective else "Mission Objective"
				unified_log.log_event("Objective", obj_name)
		)
		objective_display.objective_acknowledged.connect(
			func() -> void:
				unified_log.log_action("Objective", "Acknowledged by player")
		)

	# ReactionDicePanel — dice spend tracking
	if reaction_dice_panel and unified_log:
		reaction_dice_panel.dice_spent.connect(
			func(character_name: String, remaining: int) -> void:
				unified_log.log_action(character_name, "Reaction die spent (%d remaining)" % remaining)
		)
		reaction_dice_panel.all_dice_reset.connect(
			func() -> void:
				unified_log.log_action("Dice", "All reaction dice reset")
		)

	# DeploymentConditionsPanel — terrain/deployment info
	if deployment_conditions and unified_log:
		deployment_conditions.condition_acknowledged.connect(
			func() -> void:
				unified_log.log_action("Deployment", "Conditions acknowledged")
		)
		deployment_conditions.reroll_requested.connect(
			func() -> void:
				unified_log.log_action("Deployment", "Reroll requested")
		)

	# InitiativeCalculator — initiative results + overlay dismiss
	if initiative_calculator:
		initiative_calculator.continue_requested.connect(_hide_overlay)
		if unified_log:
			initiative_calculator.initiative_calculated.connect(
				func(result) -> void:
					var seized: String = "Seized!" if result and result.success else "Normal"
					unified_log.log_action("Initiative", seized)
			)

	# EventResolutionPanel — overlay dismiss on resolve/cancel
	if event_resolution:
		event_resolution.event_resolved.connect(
			func(_event: Dictionary, _outcome: Dictionary) -> void:
				_hide_overlay()
		)
		event_resolution.resolution_cancelled.connect(_hide_overlay)
		event_resolution.escalation_resolved.connect(
			func(_instruction: String) -> void:
				_hide_overlay()
		)

func _connect_component_signals() -> void:
	## Connect component signals so actions log to BattleJournal
	if dice_dashboard and unified_log:
		dice_dashboard.dice_rolled.connect(
			func(dice_type: String, result: int, context: String) -> void:
				unified_log.log_action("Dice", "%s: %d (%s)" % [
					dice_type, result, context
				])
		)

	if combat_calculator and unified_log:
		combat_calculator.calculation_completed.connect(
			func(calc_type: String, result: Dictionary) -> void:
				var explanation: String = result.get(
					"explanation", calc_type
				)
				unified_log.log_action("Calculator", explanation)
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
	if dual_input_roll and unified_log:
		if dual_input_roll.has_signal("roll_completed"):
			dual_input_roll.roll_completed.connect(
				func(result: int, was_manual: bool) -> void:
					var mode: String = "manual" if was_manual else "auto"
					unified_log.log_action(
						"Roll", "%d (%s)" % [result, mode]
					)
			)

	if battle_round_hud:
		battle_round_hud.next_phase_requested.connect(
			_on_advance_phase_pressed
		)

	# WeaponTableDisplay — weapon reference selection
	if weapon_table_display and unified_log:
		if weapon_table_display.has_signal("weapon_selected"):
			weapon_table_display.weapon_selected.connect(
				func(weapon_data) -> void:
					var wname: String = weapon_data.name if weapon_data and "name" in weapon_data else "Weapon"
					unified_log.log_action("Reference", "Viewed: %s" % wname)
			)

## Overlay Management

func _show_overlay(content_node: Control) -> void:
	## Show a modal overlay with the given content.
	## Uses remove_child() for reusable nodes and queue_free() for disposable ones.
	var reusable_nodes := [initiative_calculator, event_resolution, enemy_generation_wizard]
	for child in overlay_content.get_children():
		if child in reusable_nodes:
			overlay_content.remove_child(child)
		else:
			child.queue_free()
	overlay_content.add_child(content_node)
	overlay_bg.visible = true
	overlay_center.visible = true

func _hide_overlay() -> void:
	## Hide the modal overlay. Uses remove_child for reusable nodes.
	overlay_bg.visible = false
	overlay_center.visible = false
	var reusable_nodes := [initiative_calculator, event_resolution, enemy_generation_wizard]
	for child in overlay_content.get_children():
		if child in reusable_nodes:
			overlay_content.remove_child(child)
		else:
			child.queue_free()
	# After overlay dismissed, check for pending battle events this round
	# (events fire here instead of BattleRoundTracker to avoid overlay collision)
	_check_pending_battle_event()

func show_enemy_generation_overlay() -> void:
	## Show the enemy generation wizard as a modal overlay (FULL_ORACLE tier)
	if not enemy_generation_wizard:
		return
	var vp_width := get_viewport().get_visible_rect().size.x
	enemy_generation_wizard.custom_minimum_size.x = clampf(vp_width * 0.5, 400, 700)
	_show_overlay(enemy_generation_wizard)

var _battle_event_fired_this_round: int = 0  # Track which round we already fired event for

func _check_pending_battle_event() -> void:
	## Check if a battle event should trigger this round (Core Rules p.118:
	## rounds 2 and 4). Called after overlay dismissal so overlays don't collide.
	## Guarded so it only fires once per round (not on every overlay dismiss).
	if not round_tracker or not round_tracker.has_method("check_battle_event"):
		return
	var current_round: int = round_tracker.get_current_round()
	if _battle_event_fired_this_round == current_round:
		return  # Already fired this round
	var event_data: Dictionary = round_tracker.check_battle_event()
	if event_data.get("should_trigger", false):
		_battle_event_fired_this_round = current_round
		_on_battle_event_triggered(current_round, event_data.get("event_type", ""))

## Tier Selection + Pre-Battle Checklist Flow

func _show_tier_selection() -> void:
	## Show the tier selection overlay so the player picks their tracking level
	_apply_stage_visibility(BattleStage.TIER_SELECT)
	var panel: Control = _get_res("tier_selection").new()
	panel.tier_selected.connect(_on_tier_selected)
	_show_overlay(panel)

func _on_tier_selected(tier: int) -> void:
	## Handle tier selection — store tier, transition to SETUP stage
	# Create tier controller
	tier_controller = BattleTierControllerClass.new()
	tier_controller.set_tier(tier, true) # force = true at battle start

	_apply_tier_visibility(tier)
	_hide_overlay()
	_apply_stage_visibility(BattleStage.SETUP)

	# Embed checklist in Setup tab (non-blocking, grid stays visible)
	_embed_checklist_in_setup_tab(tier)

func _embed_checklist_in_setup_tab(tier: int) -> void:
	## Embed the pre-battle checklist in the Setup tab so the battlefield grid
	## remains visible while the player sets up their physical table.
	# Clear existing setup tab content
	for child in setup_content.get_children():
		child.queue_free()

	# Create checklist and add to Setup tab
	var checklist: Control = _get_res("pre_battle_checklist").new()
	checklist.checklist_completed.connect(_on_checklist_completed)
	setup_content.add_child(checklist)
	# Set tier AFTER adding to tree so _ready() has built the UI
	checklist.set_tier(tier)

	# Add "Begin Battle" button at bottom of Setup tab
	var begin_btn := Button.new()
	begin_btn.text = "Begin Battle"
	begin_btn.custom_minimum_size = Vector2(0, 56)
	begin_btn.add_theme_font_size_override("font_size", _scaled_font(18))
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
	setup_content.add_child(begin_btn)

	# Switch to Setup tab so checklist is immediately visible (tab 0 = Setup)
	right_tabs.current_tab = 0

func _on_checklist_completed() -> void:
	## All checklist items checked — log it (player can still click Begin)
	_log_message(
		"Pre-battle checklist complete!", UIColors.COLOR_EMERALD
	)

func _on_checklist_dismissed() -> void:
	## Player clicked Begin Battle — transition to deployment
	_apply_stage_visibility(BattleStage.DEPLOYMENT)
	_update_action_buttons_for_deployment()
	_log_message(
		"Deploy your crew in the deployment zone",
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

	# Left panel: crew cards (no tabs — single scroll)
	# PhaseContentPanel: phase-specific components shown/hidden per phase
	# No tab-hiding needed — visibility controlled by _apply_stage_visibility()

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

func _exit_tree() -> void:
	# Disconnect round tracker signals (autoload-child, persists across scenes)
	_disconnect_round_tracker_signals()
	# Disconnect FiveParsecsCombatSystem autoload signals
	var combat_system = get_node_or_null("/root/FiveParsecsCombatSystem")
	if combat_system:
		if combat_system.has_signal("reaction_dice_rolled") and combat_system.reaction_dice_rolled.is_connected(_on_reaction_dice_rolled):
			combat_system.reaction_dice_rolled.disconnect(_on_reaction_dice_rolled)
		if combat_system.has_signal("reaction_dice_assigned") and combat_system.reaction_dice_assigned.is_connected(_on_reaction_dice_assigned):
			combat_system.reaction_dice_assigned.disconnect(_on_reaction_dice_assigned)
	# Note: Lambda connections to local child components (unified_log, morale_tracker,
	# enemy_intent_panel, etc.) are automatically cleaned up when children are freed
	# with this parent Control node. No explicit disconnect needed.

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
			initiative_calculator.reset()
			_show_overlay(initiative_calculator)

func _on_round_started(round_number: int) -> void:
	## Handle round start - reset reactions and update UI
	current_turn = round_number
	_log_message("=== ROUND %d BEGINS ===" % round_number, UIColors.COLOR_CYAN)
	if unified_log:
		unified_log.new_round()
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
	## Handle battle start from tracker — transition to COMBAT stage
	_log_message("Tactical combat initiated", UIColors.COLOR_EMERALD)
	battle_phase = "combat"
	_apply_stage_visibility(BattleStage.COMBAT)

func _on_tracker_battle_ended() -> void:
	## Handle battle end from tracker — transition to RESOLUTION stage
	_log_message("Battle concluded", UIColors.COLOR_AMBER)
	battle_phase = "resolution"
	_resolve_battle()

func _update_action_buttons_for_phase(phase: int) -> void:
	## Update action buttons based on current combat phase from round tracker
	if not action_buttons:
		return
	# Map BattleRoundTracker phases to appropriate UI states
	# 0: REACTION_ROLL, 1: QUICK_ACTIONS, 2: ENEMY_ACTIONS, 3: SLOW_ACTIONS, 4: END_PHASE
	match phase:
		0: # REACTION_ROLL
			_show_reaction_roll_ui()
		1: # QUICK_ACTIONS
			_show_quick_actions_ui()
		2: # ENEMY_ACTIONS
			_show_enemy_actions_ui()
		3: # SLOW_ACTIONS
			_show_slow_actions_ui()
		4: # END_PHASE
			_show_end_phase_ui()

func _show_reaction_roll_ui() -> void:
	## REACTION ROLL — surface ReactionDicePanel if available
	_clear_action_buttons()
	_surface_phase_component(reaction_dice_panel)
	if right_tabs: right_tabs.current_tab = 1 # Tools tab — dice needed
	var roll_button := Button.new()
	roll_button.text = "Roll Reactions"
	roll_button.pressed.connect(_on_roll_reactions_pressed)
	action_buttons.add_child(roll_button)

func _show_quick_actions_ui() -> void:
	## QUICK ACTIONS — surface ActivationTrackerPanel for crew checklist
	_clear_action_buttons()
	_surface_phase_component(activation_tracker)
	_log_message(
		"Quick Actions — crew who passed reactions act now.",
		UIColors.COLOR_CYAN)
	var done_button := Button.new()
	done_button.text = "All Quick Actions Done"
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

func _show_enemy_actions_ui() -> void:
	## ENEMY ACTIONS — tier-aware display
	_clear_action_buttons()
	# At FULL_ORACLE tier, surface EnemyIntentPanel with AI oracle
	if tier_controller and tier_controller.current_tier >= 2:
		_surface_phase_component(enemy_intent_panel)
		if right_tabs: right_tabs.current_tab = 2 # Reference tab — enemy AI info
	else:
		_surface_phase_component(null) # Clear phase content
		if right_tabs: right_tabs.current_tab = 1 # Tools tab
	_log_message(
		"Enemy Actions — move each enemy toward closest, shoot if in range.",
		UIColors.COLOR_RED)
	var done_button := Button.new()
	done_button.text = "Enemy Actions Done"
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

func _show_slow_actions_ui() -> void:
	## SLOW ACTIONS — surface ActivationTrackerPanel for remaining crew
	_clear_action_buttons()
	_surface_phase_component(activation_tracker)
	_log_message(
		"Slow Actions — remaining crew act now.",
		UIColors.COLOR_CYAN)
	var done_button := Button.new()
	done_button.text = "All Slow Actions Done"
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

func _show_end_phase_ui() -> void:
	## END PHASE — surface morale/events/victory components
	_clear_action_buttons()
	# Show morale tracker at ASSISTED+ tier (hidden in Bug Hunt mode)
	if not _is_bug_hunt_mode and tier_controller and tier_controller.current_tier >= 1:
		_surface_phase_component(morale_tracker)
	else:
		_surface_phase_component(victory_progress if is_instance_valid(victory_progress) else null)
	var advance_button := Button.new()
	advance_button.text = "End Round / Morale Check"
	advance_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(advance_button)

func _surface_phase_component(component: Control) -> void:
	## Bring a component to the front of the phase content area.
	## Hides other phase-specific components, shows this one.
	if not phase_content:
		return
	# Hide all phase-swappable components
	var phase_components: Array = [
		reaction_dice_panel, activation_tracker,
		morale_tracker, event_resolution, victory_progress,
		enemy_intent_panel,
	]
	for comp in phase_components:
		if is_instance_valid(comp):
			comp.visible = false
	# Show the requested one
	if is_instance_valid(component):
		component.visible = true

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
	## Enemy actions — companion tells player what enemies do, no simulation
	_log_message("All enemies act now. Move each toward closest crew, shoot if in range.", UIColors.COLOR_RED)

	# Advance phase via round tracker
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()

func _on_advance_phase_pressed() -> void:
	## Advance to next phase via round tracker
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()
	else:
		push_warning("TacticalBattleUI: No round tracker — cannot advance phase")

## Initialize tactical battle with crew and enemies

func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void:
	## Initialize the tactical battle
	_battle_initialized = true
	_log_message("Initializing tactical battle...", UIColors.COLOR_CYAN)

	# Update title header with mission name
	var md: Dictionary = mission_data if mission_data is Dictionary else {}
	if title_label:
		var mission_title: String = md.get("title",
			md.get("objective", "Tactical Companion"))
		title_label.text = mission_title

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

	# BUG-042 FIX: Pass crew data to initiative calculator for equipment auto-detection
	if initiative_calculator and initiative_calculator.has_method("set_crew"):
		initiative_calculator.set_crew(crew_members)

	# Pass crew data to CharacterQuickRollPanel for dice rolling with stats
	if character_quick_roll and character_quick_roll.has_method("set_crew"):
		character_quick_roll.set_crew(crew_members)

	# Log to journal if available
	if unified_log:
		unified_log.start_battle()

	# Ensure BattleRoundTracker exists (canonical Five Parsecs 5-phase combat)
	if not round_tracker:
		var BattleRoundTrackerClass = preload("res://src/core/battle/BattleRoundTracker.gd")
		var tracker := BattleRoundTrackerClass.new()
		tracker.name = "BattleRoundTracker"
		add_child(tracker)
		set_round_tracker(tracker)

	# Populate battlefield setup tab (data only, no stage change)
	_stored_mission_data = mission_data
	_populate_setup_tab(mission_data)

	# NOTE: Deployment phase starts AFTER tier selection completes
	# (see _on_tier_selected → _apply_stage_visibility(SETUP) → checklist → DEPLOYMENT)

	# Detect Bug Hunt mode from mission context
	var mission_dict: Dictionary = mission_data if mission_data is Dictionary else {}
	_is_bug_hunt_mode = mission_dict.get("battle_mode", "") == "bug_hunt"
	if _is_bug_hunt_mode:
		_log_message("Bug Hunt mode — morale hidden, contact markers active", UIColors.COLOR_AMBER)

	# DLC: Wire No-Minis Combat panel if enabled
	_setup_no_minis_panel(crew_members.size(), enemies.size())

	# DLC: Wire mission-type-specific panels
	var mission_type: String = mission_dict.get("type", "")
	if mission_type == "stealth":
		_setup_stealth_panel(mission_dict)
	elif mission_type == "street_fight":
		_setup_street_fight_panel(mission_dict)
	elif mission_type == "salvage":
		_setup_salvage_panel(mission_dict)

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
		var card: PanelContainer = _get_res("character_status_card").instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crew_content.add_child(card)

		# Set character data (accepts Resource or Dictionary)
		card.set_character_data(crew_member)

		# Set tier display level
		if tier_controller:
			card.set_display_tier(tier_controller.current_tier)

		# Connect signals to journal
		if unified_log:
			card.action_used.connect(
				func(char_name: String, action_type: String) -> void:
					unified_log.log_action(
						char_name, action_type
					)
			)
			card.damage_taken.connect(
				func(char_name: String, amount: int) -> void:
					unified_log.log_action(
						char_name,
						"took %d damage" % amount
					)
			)

		character_cards.append(card)

func _start_deployment_phase() -> void:
	## Start the deployment phase
	battle_phase = "deployment"
	_apply_stage_visibility(BattleStage.DEPLOYMENT)
	_log_message("Place your crew members in the deployment zone", UIColors.COLOR_CYAN)

	# Enable deployment UI
	_update_action_buttons_for_deployment()

## Legacy _start_combat_phase() removed — combat now starts via round_tracker.start_battle()
## Legacy _determine_initiative_order() removed — Five Parsecs uses Reaction Roll, not initiative
## Legacy _start_unit_turn() removed — round tracker drives phase progression

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

## Legacy _update_action_buttons_for_combat() removed — phase-specific buttons
## are now created by _show_reaction_roll_ui(), _show_quick_actions_ui(), etc.

func _clear_action_buttons() -> void:
	## Clear all action buttons
	if not action_buttons:
		return
	for child in action_buttons.get_children():
		child.queue_free()

## Legacy _update_unit_info_display() removed — CharacterStatusCards show unit info

## Legacy per-unit action handlers removed (_on_move/shoot/dash/skip_turn_clicked)
## The companion now tells the player what to do; it doesn't simulate combat

func _on_place_unit_clicked() -> void:
	## Handle unit placement in deployment
	_log_message("Click on the deployment zone to place units", UIColors.COLOR_CYAN)

func _on_auto_deploy_clicked() -> void:
	## Mark all units as deployed and start combat
	## (Tabletop companion — player places figures physically, app just confirms)
	_log_message("All crew and enemies marked as deployed.", UIColors.COLOR_CYAN)
	for unit in crew_units:
		_log_message("  %s — deployed" % unit.node_name, Color.WHITE)

	# Start combat via round tracker (Five Parsecs 5-phase combat)
	if round_tracker and round_tracker.has_method("start_battle"):
		battle_phase = "combat"
		round_tracker.start_battle()
	else:
		push_error("TacticalBattleUI: No round tracker available")
		battle_phase = "combat"

## Legacy _end_unit_turn() and _end_combat_round() removed
## Round progression now driven by BattleRoundTracker.advance_phase()

func _reset_all_unit_reactions() -> void:
	## Reset reactions for all units at the start of a new round
	for unit in all_units:
		if unit.health > 0:
			unit.reset_reactions()
	_log_message("All units' reactions reset for Round %d" % current_turn, UIColors.COLOR_CYAN)

## Legacy _check_victory_conditions() removed — VictoryProgressPanel handles this in END_PHASE

func _resolve_battle() -> void:
	## Resolve the tactical battle — transition to RESOLUTION stage
	battle_phase = "resolution"
	_apply_stage_visibility(BattleStage.RESOLUTION)

	var crew_alive = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive = enemy_units.filter(func(u): return u.health > 0).size()

	var result := BattleResult.new()
	result.rounds_fought = current_turn - 1

	if crew_alive > 0 and enemies_alive == 0:
		result.victory = true
		_log_message("Victory! All enemies defeated!", UIColors.COLOR_EMERALD)
		if unified_log:
			unified_log.log_victory("All enemies defeated")
	elif crew_alive == 0:
		result.victory = false
		_log_message("Defeat! All crew members down!", UIColors.COLOR_RED)
		if unified_log:
			unified_log.log_defeat("All crew members down")
	else:
		# Stalemate or time limit
		result.victory = crew_alive > enemies_alive
		_log_message("Battle concluded after %d rounds" % result.rounds_fought, UIColors.COLOR_AMBER)
		if unified_log:
			if result.victory:
				unified_log.log_victory("Outnumbered enemies %d to %d" % [crew_alive, enemies_alive])
			else:
				unified_log.log_defeat("Outnumbered by enemies %d to %d" % [enemies_alive, crew_alive])

	# Calculate casualties and injuries
	for unit in crew_units:
		if unit.health <= 0:
			if unit.is_dead:
				result.crew_casualties.append(unit.original_character)
			else:
				result.crew_injuries.append(unit.original_character)

	tactical_battle_completed.emit(result)

func _on_end_turn() -> void:
	## Context-sensitive end turn button — behavior depends on current stage
	match current_stage:
		BattleStage.SETUP:
			_on_checklist_dismissed()
		BattleStage.DEPLOYMENT:
			_on_auto_deploy_clicked()
		BattleStage.COMBAT:
			if round_tracker and round_tracker.has_method("advance_phase"):
				round_tracker.advance_phase()
		BattleStage.RESOLUTION:
			_on_return_to_battle_resolution()

func _on_return_to_battle_resolution() -> void:
	## Return to battle resolution UI
	return_to_battle_resolution.emit() # warning: return value discarded (intentional)

func _on_auto_resolve_battle() -> void:
	## Auto-resolve the remaining battle using BattleResolver for rules-accurate combat
	_log_message("Auto-resolving battle with Five Parsecs combat rules...", UIColors.COLOR_AMBER)

	# Convert TacticalUnits to dictionaries for BattleResolver
	var crew_deployed: Array = []
	for unit in crew_units:
		if unit.health > 0:
			var unit_dict: Dictionary = {
				"name": unit.node_name,
				"character_name": unit.node_name,
				"combat_skill": unit.combat_skill,
				"combat": unit.combat_skill,
				"toughness": unit.toughness,
				"savvy": unit.savvy,
				"reactions": unit.reactions,
				"health": unit.health,
				"is_alive": true
			}
			if unit.original_character:
				if unit.original_character is Dictionary:
					unit_dict.merge(unit.original_character, false)
				elif unit.original_character.has_method("to_dictionary"):
					unit_dict.merge(unit.original_character.to_dictionary(), false)
			crew_deployed.append(unit_dict)

	var enemies_deployed: Array = []
	for unit in enemy_units:
		if unit.health > 0:
			enemies_deployed.append({
				"name": unit.node_name,
				"combat_skill": unit.combat_skill,
				"combat": unit.combat_skill,
				"toughness": unit.toughness,
				"savvy": unit.savvy,
				"reactions": unit.reactions,
				"health": unit.health,
				"is_alive": true
			})

	_log_message("Crew strength: %d units | Enemy strength: %d units" % [
		crew_deployed.size(), enemies_deployed.size()
	], UIColors.COLOR_CYAN)

	# Use BattleResolver for rules-accurate combat resolution
	var battlefield_data: Dictionary = {}
	var deployment_condition: Dictionary = {}
	var dice_roller: Callable = func(): return randi_range(1, 6)

	var resolver_result: Dictionary = BattleResolverClass.resolve_battle(
		crew_deployed, enemies_deployed, battlefield_data,
		deployment_condition, dice_roller
	)

	# Map resolver results to BattleResult
	var result := BattleResult.new()
	result.victory = resolver_result.get("success", false)
	result.rounds_fought = resolver_result.get("rounds_fought", current_turn)

	var crew_casualties_count: int = resolver_result.get("crew_casualties", 0)
	var enemies_defeated_count: int = resolver_result.get("enemies_defeated", 0)

	_log_message("Combat resolved: %d rounds fought" % result.rounds_fought, UIColors.COLOR_CYAN)
	_log_message("Enemies defeated: %d / %d" % [enemies_defeated_count, enemies_deployed.size()], UIColors.COLOR_CYAN)

	# Determine crew casualties from resolver's final state
	var crew_units_final: Array = resolver_result.get("crew_units_final", [])
	for i in range(crew_units.size()):
		var unit: TacticalUnit = crew_units[i]
		var is_alive: bool = true
		if i < crew_units_final.size():
			is_alive = crew_units_final[i].get("is_alive", true)
		elif unit.health <= 0:
			is_alive = false

		if not is_alive and unit.original_character:
			# Use Compendium casualty table if available, else core rules
			var casualty_check: Dictionary = _roll_compendium_casualty()
			if not casualty_check.is_empty():
				var cas_id: String = casualty_check.get("id", "")
				_log_message(casualty_check.get("instruction", ""), Color("#DC2626"))
				if cas_id == "instant_kill" or cas_id == "dead":
					result.crew_casualties.append(unit.original_character)
				else:
					result.crew_injuries.append(unit.original_character)
					var injury_check: Dictionary = _roll_compendium_injury()
					if not injury_check.is_empty():
						_log_message(injury_check.get("instruction", ""), Color("#D97706"))
			else:
				var death_roll: int = _roll_dice("Death Check", "D6")
				if death_roll <= 2:
					result.crew_casualties.append(unit.original_character)
				else:
					result.crew_injuries.append(unit.original_character)

	if crew_casualties_count > 0:
		_log_message("Crew casualties: %d" % crew_casualties_count, UIColors.COLOR_RED)

	var held_field: bool = resolver_result.get("held_field", result.victory)
	if held_field:
		_log_message("Crew holds the field — battlefield salvage available", UIColors.COLOR_EMERALD)

	# Log auto-resolve summary to BattleJournal
	if unified_log:
		unified_log.add_entry("event", "Auto-resolved: %d rounds of combat" % result.rounds_fought)
		if crew_casualties_count > 0:
			unified_log.add_entry("casualty_crew", "%d crew members went down" % crew_casualties_count)
		if enemies_defeated_count > 0:
			unified_log.add_entry("casualty_enemy", "%d enemies eliminated" % enemies_defeated_count)
		if result.victory:
			unified_log.log_victory("Auto-resolve: Crew victorious")
		else:
			unified_log.log_defeat("Auto-resolve: Crew defeated")

	_log_message("Battle %s!" % ("WON" if result.victory else "LOST"), UIColors.COLOR_EMERALD if result.victory else UIColors.COLOR_RED)
	tactical_battle_completed.emit(result)

## Utility functions

## Legacy _is_valid_position() removed — no grid-based positioning in companion

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
	## Log a message to the unified battle log (live feed)
	if unified_log:
		unified_log.add_live_message(message, color, current_turn)
	elif battle_log:
		# Fallback to raw RichTextLabel if unified_log not yet created
		var timestamp: String = "[R%d] " % current_turn
		battle_log.append_text("[color=%s]%s%s[/color]\n" % [color.to_html(), timestamp, message])
		battle_log.scroll_to_line(battle_log.get_line_count())

## Legacy _find_nearest_enemy() and _get_cover_modifier() removed
## The companion doesn't simulate combat — it guides the player

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
		die_label.add_theme_font_size_override("font_size", _scaled_font(20))

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

## ── Battlefield View Helpers ───────────────────────────────────────

func _set_map_deployment_highlight(enabled: bool) -> void:
	## Toggle deployment zone highlighting on the BattlefieldMapView
	if not battlefield_grid_panel:
		return
	var map_view = battlefield_grid_panel.get_node_or_null("BattlefieldMapView")
	if not map_view:
		# MapView is built dynamically — try the internal reference
		if battlefield_grid_panel.has_method("get") and battlefield_grid_panel.get("_map_view"):
			battlefield_grid_panel._map_view.set_deployment_highlight(enabled)
		return
	if map_view.has_method("set_deployment_highlight"):
		map_view.set_deployment_highlight(enabled)

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
		_battlefield_generator = _get_res("battlefield_generator").new()

	# Read battlefield data from GameState
	var game_state = get_node_or_null("/root/GameState")
	var bf_data: Dictionary = {}
	if game_state and game_state.has_method("get_battlefield_data"):
		bf_data = game_state.get_battlefield_data()

	var terrain_data: Dictionary = bf_data.get("terrain", {})
	var deployment_condition: Dictionary = bf_data.get("deployment_condition", {})

	# Determine terrain theme key for BattlefieldGenerator
	# BUG-038 FIX: Check terrain sub-dict first, then fall back to top-level
	var theme_name: String = terrain_data.get("theme",
		bf_data.get("terrain_type", "Standard Battlefield"))
	_current_terrain_theme = _map_theme_name_to_key(theme_name)

	# Read world traits for terrain modification (Core Rules pp.72-75)
	var world_traits: Array = []
	if game_state and game_state.current_campaign:
		var campaign_res = game_state.current_campaign
		if "current_planet" in campaign_res:
			var planet = campaign_res.current_planet
			if planet is Dictionary:
				world_traits = planet.get("world_traits", [])

	# Generate Compendium-compliant terrain (5-step process)
	var sector_data: Dictionary = (
		_battlefield_generator.generate_terrain_suggestions(
			_current_terrain_theme, world_traits,
			deployment_condition))

	# Populate the visual battlefield grid in center area
	if battlefield_grid_panel and battlefield_grid_panel.has_method("populate"):
		var sectors_arr: Array = sector_data.get("sectors", [])
		var theme_display_name: String = sector_data.get(
			"theme_name", theme_name)
		battlefield_grid_panel.populate(sectors_arr, theme_display_name)
		if not battlefield_grid_panel.regenerate_requested.is_connected(
				_on_regenerate_terrain_pressed):
			battlefield_grid_panel.regenerate_requested.connect(
				_on_regenerate_terrain_pressed)

	# Compute mission-aware objective positions (Core Rules pp.89-91)
	var mission_dict_obj: Dictionary = (
		mission_data if mission_data is Dictionary else {})
	var objective_str: String = mission_dict_obj.get(
		"objective", mission_dict_obj.get("type", ""))
	var obj_rng := RandomNumberGenerator.new()
	obj_rng.seed = Time.get_unix_time_from_system()
	var obj_positions: Array = (
		_battlefield_generator.compute_objective_positions(
			objective_str, sector_data.get("sectors", []), obj_rng))
	if battlefield_grid_panel and battlefield_grid_panel.has_method(
			"set_objective_positions"):
		battlefield_grid_panel.set_objective_positions(obj_positions)

	# Section 0a: Mission Overview (pay, location, danger)
	var mission_dict: Dictionary = mission_data if mission_data is Dictionary else {}
	var m_location: String = mission_dict.get("location", "")
	var m_pay: int = mission_dict.get("pay",
		mission_dict.get("danger_pay", 0))
	var m_danger: int = mission_dict.get("danger_level", 0)
	if not m_location.is_empty() or m_pay > 0 or m_danger > 0:
		_add_setup_section_header("MISSION DETAILS")
		if not m_location.is_empty():
			_add_setup_text(
				"Location: %s" % m_location, Color("#E0E0E0"))
		if m_pay > 0:
			_add_setup_text(
				"Pay: %d credits" % m_pay, Color("#10B981"))
		if m_danger > 0:
			var danger_color := Color("#10B981")
			if m_danger >= 3:
				danger_color = Color("#DC2626")
			elif m_danger >= 2:
				danger_color = Color("#D97706")
			_add_setup_text(
				"Danger Level: %d" % m_danger, danger_color)
		var m_patron: String = mission_dict.get("patron", "")
		if not m_patron.is_empty():
			_add_setup_text(
				"Patron: %s" % m_patron, Color("#4FC3F7"))
		_add_setup_separator()

	# Section 0b: Enemy Forces — single type per battle (Core Rules pp.91-94)
	var enemy_force: Dictionary = mission_dict.get("enemy_force", {})
	var enemy_type_str: String = enemy_force.get(
		"type",
		mission_dict.get("enemy_type",
			mission_dict.get("enemy_faction", "")))
	var enemy_unit_count: int = enemy_force.get(
		"count", mission_dict.get("enemy_count", 0))

	if not enemy_type_str.is_empty() or enemy_unit_count > 0:
		_add_setup_section_header("ENEMY FORCES")

		# Primary type name + category
		var ef_category: String = enemy_force.get("category", "")
		var type_display: String = enemy_type_str
		if not ef_category.is_empty():
			type_display += " (%s)" % ef_category.replace(
				"_", " ").capitalize()
		_add_setup_text(type_display, Color("#DC2626"), 16)

		# Stat line from enemy_force dict or JSON lookup
		var ef_stats: Dictionary = enemy_force
		if ef_stats.get("speed", 0) == 0:
			# Fallback: look up from enemy_types.json
			var enemy_db: Dictionary = _load_enemy_types_db()
			ef_stats = _lookup_enemy_stats(enemy_db, enemy_type_str)
		if not ef_stats.is_empty():
			_add_enemy_stat_line(ef_stats)

		# Count + role breakdown
		var units: Array = enemy_force.get("units", [])
		var std_count: int = 0
		var spec_count: int = 0
		var lt_count: int = 0
		for u in units:
			if u is Dictionary:
				match u.get("role", "standard"):
					"lieutenant":
						lt_count += 1
					"specialist":
						spec_count += 1
					_:
						std_count += 1

		var count_parts: Array[String] = []
		if std_count > 0:
			count_parts.append("%d standard" % std_count)
		if spec_count > 0:
			count_parts.append("%d specialist" % spec_count)
		if lt_count > 0:
			count_parts.append("%d lieutenant" % lt_count)

		if enemy_unit_count > 0:
			var breakdown: String = ""
			if count_parts.size() > 0:
				breakdown = " (%s)" % ", ".join(count_parts)
			_add_setup_text(
				"Total: %d%s" % [enemy_unit_count, breakdown],
				Color("#E0E0E0"))

		# Special rules
		var rules: Array = enemy_force.get(
			"special_rules", ef_stats.get("special_rules", []))
		for rule in rules:
			var rule_str: String = str(rule)
			if not rule_str.is_empty():
				_add_setup_text(
					"  %s" % rule_str, Color("#D97706"), 12)

		_add_setup_separator()

	# Section 0c: Patron Conditions (benefits, hazards, conditions)
	var benefits: Array = mission_dict.get("benefits", [])
	var hazards: Array = mission_dict.get("hazards", [])
	var conditions: Array = mission_dict.get("conditions", [])
	if benefits.size() > 0 or hazards.size() > 0 \
			or conditions.size() > 0:
		_add_setup_section_header("PATRON CONDITIONS")
		for benefit in benefits:
			var b_text: String = str(benefit)
			if not b_text.is_empty():
				_add_setup_text(
					"+ %s" % b_text, Color("#10B981"))
		for hazard in hazards:
			var h_text: String = str(hazard)
			if not h_text.is_empty():
				_add_setup_text(
					"! %s" % h_text, Color("#D97706"))
		for cond in conditions:
			var c_text: String = str(cond)
			if not c_text.is_empty():
				_add_setup_text(
					"? %s" % c_text, Color("#4FC3F7"))
		_add_setup_separator()

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

	# Section 4: Mission Objective (mission_dict declared in Section 0a)
	var objective_name: String = mission_dict.get(
		"objective", mission_dict.get("type", ""))
	if not objective_name.is_empty():
		_add_setup_section_header("MISSION OBJECTIVE")
		_add_setup_text(objective_name, Color("#10B981"), 16)
		var obj_desc: String = mission_dict.get("description", "")
		if not obj_desc.is_empty():
			_add_setup_text(obj_desc, Color("#9ca3af"))
		# Core Rules objective details (pp.89-91)
		var obj_details: Dictionary = mission_dict.get(
			"objective_details", {})
		var victory_cond: String = obj_details.get(
			"victory_condition",
			mission_dict.get("victory_condition", ""))
		if not victory_cond.is_empty():
			_add_setup_text(
				"Victory: %s" % victory_cond, Color("#f59e0b"))
		var placement: String = obj_details.get(
			"placement_rules",
			mission_dict.get("placement_rules", ""))
		if not placement.is_empty():
			_add_setup_text(
				"Setup: %s" % placement, Color("#9ca3af"))
		_add_setup_separator()

	# Section 4b: Notable Sight (Core Rules p.88)
	var notable_sight: Dictionary = mission_dict.get(
		"notable_sight", {})
	var sight_type: String = notable_sight.get("type", "")
	if not sight_type.is_empty() and sight_type != "NOTHING":
		_add_setup_section_header("NOTABLE SIGHT")
		_add_setup_text(
			sight_type.replace("_", " ").capitalize(),
			Color("#E879F9"), 16)
		var sight_effect: String = notable_sight.get("effect", "")
		if not sight_effect.is_empty():
			_add_setup_text(sight_effect, Color("#9ca3af"))
		_add_setup_text(
			"Placed 2D6+2\" from center in random direction.",
			Color("#808080"))
		_add_setup_separator()

	# Section 5: DLC Compendium Difficulty Instructions
	var dlc_instructions: Array = mission_dict.get("dlc_difficulty_instructions", [])
	if not dlc_instructions.is_empty():
		_add_setup_section_header("COMPENDIUM DIFFICULTY RULES")
		for instruction: String in dlc_instructions:
			if instruction.is_empty():
				continue
			# Color code by instruction type
			var color := Color("#4FC3F7") # Default cyan
			if instruction.begins_with("AI:"):
				color = Color("#D97706") # Orange for AI behavior
			elif instruction.begins_with("TOGGLE:"):
				color = Color("#DC2626") # Red for difficulty toggles
			elif instruction.begins_with("MILESTONE:"):
				color = Color("#10B981") # Green for milestones
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

	# Section 5b: Dramatic Combat effects (Compendium DLC)
	var dramatic_effects: Array = mission_dict.get("dramatic_combat_effects", [])
	if not dramatic_effects.is_empty():
		_add_setup_section_header("DRAMATIC COMBAT")
		for effect in dramatic_effects:
			var effect_str: String = str(effect)
			if not effect_str.is_empty():
				_add_setup_text(effect_str, Color("#E879F9")) # Purple for dramatic
		_add_setup_separator()

	# Section 5c: Grid Movement instructions (Compendium DLC)
	var grid_instructions: Array = mission_dict.get("grid_movement_instructions", [])
	if not grid_instructions.is_empty():
		_add_setup_section_header("GRID-BASED MOVEMENT")
		for grid_inst in grid_instructions:
			var inst_str: String = str(grid_inst)
			if not inst_str.is_empty():
				_add_setup_text(inst_str, Color("#38BDF8")) # Sky blue for grid
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

	# Generate new sector data (with world traits + deployment condition)
	var regen_world_traits: Array = []
	var regen_game_state = get_node_or_null("/root/GameState")
	if regen_game_state and regen_game_state.current_campaign:
		var regen_campaign = regen_game_state.current_campaign
		if "current_planet" in regen_campaign:
			var regen_planet = regen_campaign.current_planet
			if regen_planet is Dictionary:
				regen_world_traits = regen_planet.get("world_traits", [])
	var new_sector_data: Dictionary = (
		_battlefield_generator.generate_terrain_suggestions(
			_current_terrain_theme, regen_world_traits))

	# Also refresh the visual battlefield grid
	if battlefield_grid_panel and battlefield_grid_panel.has_method("populate"):
		var new_sectors: Array = new_sector_data.get("sectors", [])
		var theme_display: String = new_sector_data.get("theme_name", _current_terrain_theme)
		battlefield_grid_panel.populate(new_sectors, theme_display)

	# Re-insert terrain section — clamp index to actual child count
	# (queue_free'd nodes are now gone after await, child count is lower)
	_terrain_section_start_index = mini(
		_terrain_section_start_index, setup_content.get_child_count())
	var insert_idx: int = _terrain_section_start_index

	# Header — same style as _add_setup_section_header
	var header := Label.new()
	header.text = "SECTOR LAYOUT"
	header.add_theme_font_size_override("font_size", _scaled_font(12))
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
	if unified_log and unified_log.has_method("add_entry"):
		unified_log.add_entry("setup", "Terrain layout regenerated (%s)" % _current_terrain_theme)
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
	elif "urban" in lower or "settlement" in lower or "city" in lower:
		return "urban_settlement"
	elif "waste" in lower or "blasted" in lower:
		return "wasteland"
	elif "ship" in lower or "interior" in lower or "corridor" in lower:
		return "ship_interior"
	# Fallback
	return "wilderness"

func _add_setup_section_header(text: String) -> void:
	## Add a section header label to the Setup tab
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _scaled_font(12))
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

func _add_enemy_stat_line(stats: Dictionary) -> void:
	## Add a compact stat line for an enemy type: SPD/CMB/TGH/AI/Panic/Weapons
	var spd: int = stats.get("speed", 0)
	var cmb: int = stats.get("combat_skill", 0)
	var tgh: int = stats.get("toughness", 0)
	var ai_type: String = str(stats.get("ai", ""))
	var panic_str: String = str(stats.get("panic", ""))
	var weapons: String = str(stats.get("weapons", ""))
	var numbers: String = str(stats.get("numbers", ""))

	var line: String = "    SPD:%d  CMB:+%d  TGH:%d  AI:%s" \
		% [spd, cmb, tgh, ai_type]
	if not panic_str.is_empty():
		line += "  Panic:%s" % panic_str
	if not weapons.is_empty():
		line += "  Wpns:%s" % weapons
	if not numbers.is_empty():
		line += "  Numbers:%s" % numbers

	_add_setup_text(line, Color("#4FC3F7"), 12)

var _enemy_types_cache: Dictionary = {}

func _load_enemy_types_db() -> Dictionary:
	## Load and cache enemy_types.json
	if not _enemy_types_cache.is_empty():
		return _enemy_types_cache
	var file := FileAccess.open(
		"res://data/enemy_types.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	file.close()
	if json.data is Dictionary:
		_enemy_types_cache = json.data
	return _enemy_types_cache

func _lookup_enemy_stats(db: Dictionary, enemy_name: String) -> Dictionary:
	## Find an enemy entry by name across all categories
	var name_lower: String = enemy_name.to_lower().strip_edges()
	for cat in db.get("enemy_categories", []):
		if cat is Dictionary:
			for entry in cat.get("enemies", []):
				if entry is Dictionary:
					var entry_name: String = entry.get(
						"name", "").to_lower()
					if entry_name == name_lower:
						return entry
	return {}

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
	var objective_reached: bool = false # Set by objective system if wired
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
		_dlc_escalation_count -= 1 # Doesn't count toward the 3-roll limit
		if unified_log:
			unified_log.add_entry("event", variation_text)
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

	if unified_log:
		unified_log.add_entry("event", esc_text)
		if not instruction.is_empty():
			unified_log.add_entry("event", instruction)


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

	no_minis_combat_panel = _get_res("no_minis_combat").new()
	no_minis_combat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_minis_combat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Battle Log" tab alongside the journal
	if phase_content:
		phase_content.add_child(no_minis_combat_panel)

	# Initialize the abstract battle
	no_minis_combat_panel.setup_battle(crew_size, enemy_count)

	# Connect signals to journal
	if unified_log:
		no_minis_combat_panel.round_advanced.connect(
			func(round_num: int) -> void:
				unified_log.add_entry("round", "[b]NO-MINIS:[/b] Round %d" % round_num)
		)
		no_minis_combat_panel.action_resolved.connect(
			func(action_text: String) -> void:
				unified_log.add_entry("action", "[b]NO-MINIS ACTION:[/b] %s" % action_text)
		)
		no_minis_combat_panel.battle_completed.connect(
			func(result: Dictionary) -> void:
				var rounds: int = result.get("rounds_played", 0)
				unified_log.add_entry("event",
					"[b]NO-MINIS BATTLE ENDED[/b] after %d rounds" % rounds)
		)

	_log_message("No-Minis Combat mode active (Compendium pp.64-67)", UIColors.COLOR_EMERALD)


## ── DLC: Stealth Mission Panel (Compendium) ─────────────────────

func _setup_stealth_panel(mission_dict: Dictionary) -> void:
	## Create and wire Stealth Mission panel for stealth mission type
	stealth_mission_panel = _get_res("stealth_mission").new()
	stealth_mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stealth_mission_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Events" tab
	if phase_content:
		phase_content.add_child(stealth_mission_panel)

	# Initialize with mission data
	stealth_mission_panel.setup_mission(mission_dict)

	# Connect signals to journal
	if unified_log:
		stealth_mission_panel.round_advanced.connect(
			func(round_num: int) -> void:
				unified_log.add_entry("round", "[b]STEALTH:[/b] Round %d" % round_num)
		)
		stealth_mission_panel.detection_triggered.connect(
			func() -> void:
				unified_log.add_entry("event",
					"[color=#DC2626][b]STEALTH: DETECTED![/b] Combat begins.[/color]")
		)
		stealth_mission_panel.mission_completed.connect(
			func() -> void:
				unified_log.add_entry("victory",
					"[color=#10B981][b]STEALTH MISSION COMPLETE[/b][/color]")
		)

	_log_message("Stealth Mission mode active", UIColors.COLOR_EMERALD)

	# Stealth panel is in phase_content — visible during combat stages


## ── DLC: Street Fight Panel (Compendium pp.123-138) ─────────────

func _setup_street_fight_panel(mission_dict: Dictionary) -> void:
	## Create and wire Street Fight panel for street fight mission type
	street_fight_panel = _get_res("street_fight_mission").new()
	street_fight_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	street_fight_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Events" tab
	if phase_content:
		phase_content.add_child(street_fight_panel)

	# Initialize with mission data
	street_fight_panel.setup_mission(mission_dict)

	# Connect signals to journal
	if unified_log:
		street_fight_panel.round_advanced.connect(
			func(round_num: int) -> void:
				unified_log.add_entry("round", "[b]STREET FIGHT:[/b] Round %d" % round_num)
		)
		street_fight_panel.suspect_revealed.connect(
			func() -> void:
				unified_log.add_entry("event",
					"[color=#D97706][b]SUSPECT IDENTIFIED[/b][/color]")
		)
		street_fight_panel.mission_completed.connect(
			func() -> void:
				unified_log.add_entry("victory",
					"[color=#10B981][b]STREET FIGHT COMPLETE[/b][/color]")
		)

	_log_message("Street Fight mode active", UIColors.COLOR_AMBER)


## ── DLC: Salvage Mission Panel (Compendium pp.137-147) ──────────

func _setup_salvage_panel(mission_dict: Dictionary) -> void:
	## Create and wire Salvage Mission panel for salvage mission type
	salvage_mission_panel = _get_res("salvage_mission").new()
	salvage_mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salvage_mission_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to center "Events" tab
	if phase_content:
		phase_content.add_child(salvage_mission_panel)

	# Initialize with mission data
	salvage_mission_panel.setup_mission(mission_dict)

	# Connect signals to journal
	if unified_log:
		salvage_mission_panel.round_advanced.connect(
			func(round_num: int) -> void:
				unified_log.add_entry("round", "[b]SALVAGE:[/b] Round %d" % round_num)
		)
		salvage_mission_panel.contact_revealed.connect(
			func() -> void:
				unified_log.add_entry("event",
					"[color=#D97706][b]CONTACT RESOLVED[/b][/color]")
		)
		salvage_mission_panel.mission_completed.connect(
			func() -> void:
				unified_log.add_entry("victory",
					"[color=#10B981][b]SALVAGE JOB COMPLETE[/b][/color]")
		)

	_log_message("Salvage Job mode active", UIColors.COLOR_CYAN)


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
				max_reactions_per_round = 1 # Swift limited to 1 reaction
