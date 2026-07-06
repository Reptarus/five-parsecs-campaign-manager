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

signal tactical_battle_completed(battle_result)
signal return_to_battle_resolution()

## Keep-as-preload: used externally for enum/static access, always needed
const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")
# Path preload: BattlefieldGrid is new (2026-07-02); global class
# cache is stale until the editor reopens (project gotcha).
const BattlefieldGridClass = preload("res://src/core/battle/BattlefieldGrid.gd")
# Battle-journey guidance text source (deployment steps, round-end
# prompts, objective win text — Core Rules pp.88-90, 110). Path preload:
# new class, same stale-cache gotcha.
const BattleFlowGuideClass = preload("res://src/core/battle/BattleFlowGuide.gd")
const EscalatingBattlesManagerRef = preload("res://src/core/managers/EscalatingBattlesManager.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const BattleResolverClass = preload("res://src/core/battle/BattleResolver.gd")
const NoMinisResolverClass = preload("res://src/core/battle/NoMinisResolver.gd")
const BattleResolverRouterClass = preload("res://src/core/battle/BattleResolverRouter.gd")
const BattleObjectiveTrackerClass = preload("res://src/core/battle/BattleObjectiveTracker.gd")

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

# --- Map-Primary + Drawers frame (redesign) -------------------------------
# Real .tscn nodes of the new glance frame.
@onready var crew_rail_panel: PanelContainer = %CrewRailPanel
@onready var crew_rail: VBoxContainer = %CrewRail
@onready var map_host: PanelContainer = %MapHost
@onready var info_rail_panel: PanelContainer = %InfoRailPanel
@onready var info_rail: VBoxContainer = %InfoRail
@onready var feed_strip: PanelContainer = %FeedStrip
@onready var feed_host: VBoxContainer = %FeedHost
@onready var drawer_layer: CanvasLayer = $DrawerLayer

## Compatibility shims (Phase-1 port). The legacy layout funneled ~165 call
## sites into phase_content / tools_content / reference_content / right_tabs /
## etc. Rather than rewrite every site on this 4-game-mode shared file, those
## vars are REPOINTED in _setup_ui at the new structure's drawer-body VBoxes
## (Tracking / Dice / Reference) and rails, so existing component-funneling
## logic lands in the right drawer with the layout fully restructured.
var left_panel: PanelContainer = null            # → %CrewRailPanel
var crew_content: VBoxContainer = null           # → %CrewRail
var center_panel: Control = null                 # → %MapHost
var battlefield_grid_panel: Control = null       # → code-built BattlefieldMapView
var phase_content_panel: PanelContainer = null   # → null (guarded everywhere)
var phase_content: VBoxContainer = null          # → Tracking drawer body
var right_panel: PanelContainer = null           # → %InfoRailPanel
var right_tabs: TabContainer = null              # → null (all uses guarded)
var tools_content: VBoxContainer = null          # → Dice drawer body
var reference_content: VBoxContainer = null      # → Reference drawer body
var setup_content: VBoxContainer = null          # → Tracking drawer body
var battle_log: RichTextLabel = null             # → detached sink; real feed = unified_log

# Keeper drawer instances (SlideOverDrawer), one per toolbar surface.
const DrawerClass = preload("res://src/ui/components/common/SlideOverDrawer.gd")
## Portrait top app bar (hosts the ≡ Panels drawer menu); path-preloaded.
const MobileAppBarClass = preload("res://src/ui/components/common/MobileAppBar.gd")
var _drawers: Dictionary = {}            # id -> SlideOverDrawer
var _drawer_bodies: Dictionary = {}      # id -> VBoxContainer (content host)
var _toolbar_built: bool = false

# Portrait rail mask: the per-stage match decides the rails' INTENT; the actual
# visibility is intent AND (not collapsed). Captured after each stage change and
# re-applied on every rotation so landscape restores the stage-correct rails.
var _rail_intent_crew: bool = false
var _rail_intent_info: bool = false

# Bottom bar (two rows: PhaseHUD + ActionBar) — UNCHANGED nodes
@onready var bottom_bar: PanelContainer = $EdgeMargin/MainContainer/BottomBar
@onready var phase_hud: HBoxContainer = %PhaseHUD
@onready var turn_indicator: Label = %TurnIndicator
@onready var action_buttons: Container = %PhaseButtonsContainer  # HFlowContainer (wraps in portrait)
@onready var end_turn_button: Button = %EndTurnButton

# Overlay nodes (for tier selection, checklists, popups)
@onready var overlay_bg: ColorRect = $OverlayLayer/OverlayBackground
@onready var overlay_center: CenterContainer = $OverlayLayer/OverlayCenter
@onready var overlay_content: VBoxContainer = $OverlayLayer/OverlayCenter/OverlayContent

# Reaction Dice UI (handled by ReactionDicePanel component in Sprint 4)
var dice_pool_display: HBoxContainer = null
var character_assignment_list: VBoxContainer = null
var confirm_assignments_button: Button = null

# Stars of the Story battle HUD (Core Rules p.67 — 3 mid-battle abilities)
var _stars_battle_button: Button = null

# Wave 3 battle-UX: single-level undo of the last player-recorded unit mutation,
# plus its ActionBar button (set up like _stars_battle_button).
var _undo_button: Button = null
var _undo_snapshot: Dictionary = {}
var _stars_battle_popup: PopupPanel = null

# Phase-instruction banner — the companion "what do I do now THIS phase" surface.
# A persistent panel above the action row stating the PHYSICAL action to perform,
# with intra-round 5-phase progress. Reuses the existing per-phase copy verbatim
# (no invented game data); the feed keeps the scrolling history.
var _phase_banner: PanelContainer = null
var _phase_banner_chip: Label = null
var _phase_banner_label: Label = null

# Portrait top app bar: replaces the cramped TopBar on phones and hosts the
# "≡ Panels" drawer MenuButton + Auto-Resolve, so the bottom action row carries
# only phase buttons. Self-hides in landscape (zero desktop impact). The 7-button
# DrawerBar and this menu COEXIST (visibility-toggled by orientation), never
# reparented. _drawer_tier is remembered so a rotation can rebuild the menu.
var _mobile_app_bar: PanelContainer = null
var _panels_menu: MenuButton = null
var _drawer_tier: int = 0
var _top_bar: HBoxContainer = null  # cached TopBar (hidden in portrait)
const _StarsSysClassRef = preload(
	"res://src/core/systems/StarsOfTheStorySystem.gd")

# Core Systems
## battlefield_manager removed — terrain handled by BattlefieldGenerator + GridPanel
var dice_manager: Node = null
var alpha_manager: Node = null
var battle_tracker: Node = null # For reaction economy tracking

## Sprint 11.4: BattleRoundTracker integration for phase-based combat
var round_tracker: Node = null # BattleRoundTracker instance for Five Parsecs combat rounds
var _round_tracker_connected: bool = false
var _battle_events_system: Resource = null # FPCM_BattleEventsSystem (lazy-loaded data Resource)
var _objective_tracker = null # BattleObjectiveTracker — single owner of battle end-state
var _objective_refreshing: bool = false # re-entrancy guard for _refresh_objective_panel

# Tier controller for component visibility (wired in Sprint 2)
var tier_controller: Resource = null # FPCM_BattleTierController instance

# LOG_ONLY component instances (Sprint 3)
var unified_log: FPCM_UnifiedBattleLog = null  # Replaces BattleJournal + FallbackLog
var dice_dashboard: Control = null
var combat_calculator: Control = null
var battle_round_hud: Control = null
var character_cards: Array = [] # Array of CharacterStatusCard instances (crew + enemy drawer cards)
var _unit_card_by_id: Dictionary = {}   # _unit_id(unit) -> CharacterStatusCard (live drawer card)
var _drawer_repopulate_queued: bool = false  # re-entrancy guard for deferred drawer rebuilds

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

# Battle Notes carryback (Sprint 1 QOL Item 5) — player jots observations
# that get folded into the post-battle CampaignJournal entry via the
# GameStateManager.set_temp_data("battle_player_notes", ...) channel.
var _battle_note_layer: CanvasLayer = null
var _battle_note_edit: TextEdit = null

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
## Last BattlefieldGenerator result (sectors/combat_notes/visibility_limit) —
## drives the redesign's info-rail BATTLEFIELD card + TERRAIN KEY legend.
var _battlefield_data: Dictionary = {}

# Battle State
var crew_units: Array[TacticalUnit] = []
var enemy_units: Array[TacticalUnit] = []
var all_units: Array[TacticalUnit] = []
var current_turn: int = 0
var _is_bug_hunt_mode: bool = false
var _is_planetfall_mode: bool = false
var _battle_mode_id: String = ""  # "" = standard 5PFH; gates No-Minis auto-resolve routing
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

# Session 48: Battle context for phase-driven content (enemy force, deployment, objective, etc.)
var _battle_context: Dictionary = {}

# Tap-a-sector rules popover — the ONE on-map interaction (map-primary
# journey rule). Lazily built; lives as a map_host child.
var _sector_popover: Control = null

# Psionics tracking (Compendium pp.19-22) — counts uses for post-battle legality detection
var _psionic_uses: int = 0
var _psionic_powers_json: Dictionary = {}  # Cached psionic_powers.json data

## AI type descriptions for enemy action phase guidance (Core Rules pp.94-103)
const AI_DESCRIPTIONS: Dictionary = {
	"A": "Aggressive — move toward closest crew, attack if able",
	"C": "Cautious — stay in cover, fire at closest visible target",
	"D": "Defensive — hold position, fire only if crew approach",
	"G": "Guardian — stay near assigned unit, protect them",
	"R": "Rampage — rush nearest target, always melee if possible",
	"T": "Tactical — advance to cover, fire at best target",
	"B": "Beast — move toward nearest figure, attack on contact",
}

# SceneRouter-based battle delegation (Bug Hunt, Planetfall, Tactics)
# When loaded via SceneRouter (not embedded as child), these track the
# return route and temp_data key for storing results.
var _return_screen: String = ""
var _result_temp_key: String = ""

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
## and displayed via BattlefieldMapView using text-based sector descriptions.

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

	# Stars of the Story HUD — deferred so campaign data is loaded
	call_deferred("_setup_stars_battle_ui")
	# Wave 3: Undo button on the ActionBar (deferred so the bar exists).
	call_deferred("_setup_undo_button")

func _setup_ui() -> void:
	## Setup the tactical UI — Map-Primary + Drawers frame (redesign port).
	# Build the new glance frame + keeper drawers, then repoint the legacy
	# layout vars (shims) so existing component-funneling logic lands in the
	# right drawer/rail with the layout fully restructured.
	_build_redesign_frame()

	if turn_indicator:
		turn_indicator.text = "Setting Up"
	if battle_log:
		battle_log.clear()
	_log_message("Tactical battle mode activated", UIColors.COLOR_EMERALD)

	# Instance LOG_ONLY components — now funnel into drawer bodies via shims
	_instance_log_only_components()

	# Default to LOG_ONLY visibility until tier is selected
	_apply_tier_visibility(0)

	# Build breadcrumb navigation
	_build_phase_breadcrumb()

	# Start with everything hidden — tier selection deferred to initialize_battle()
	_apply_stage_visibility(BattleStage.TIER_SELECT)

	# Battle Notes carryback widget — small floating textbox for player notes.
	_setup_battle_notes_widget()

	# Initial responsive layout pass
	call_deferred("_apply_responsive_layout")


# ============================================================================
# MAP-PRIMARY + DRAWERS FRAME (Phase-1 port of the approved Phase-0 prototype)
# ============================================================================

func _build_redesign_frame() -> void:
	## Build the new frame's runtime pieces and repoint legacy shims.
	# Detached log sink so battle_log.clear()/_log_message stay harmless;
	# the real feed is the UnifiedBattleLog placed in FeedHost.
	battle_log = RichTextLabel.new()
	battle_log.bbcode_enabled = true

	# Simple structural shims (valid same-type nodes).
	left_panel = crew_rail_panel
	crew_content = crew_rail
	center_panel = map_host
	right_panel = info_rail_panel
	right_tabs = null
	phase_content_panel = null

	# Bare BattlefieldMapView in MapHost (requirement iter-2: real rules-
	# accurate map, no GridPanel chrome). Built in code like the prototype.
	if map_host and map_host.get_child_count() == 0:
		var mv := BattlefieldMapView.new()
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map_host.add_child(mv)
		battlefield_grid_panel = mv
		# NOTE: do NOT call set_show_scatter() here — the MapView builds its
		# _terrain_container in _ready(), which has not run on the same frame
		# it is added. Scatter defaults TRUE; the real map is populated later
		# by the generator (populate_from_sectors), where toggles are safe.

	# Keeper drawers (one per surface). Bodies always exist so the ~165
	# legacy add_child(phase_content/tools_content/...) sites never null-
	# deref; tier gating controls which toolbar buttons appear, not whether
	# the body exists.
	# "wide" drawers hold full component panels (unit-tracker cards with a
	# 5-button action row, DiceDashboard, MoralePanicTracker, EnemyIntentPanel)
	# whose natural width exceeds the tight reading column — they opt into a
	# wider panel so content fits instead of horizontally clipping/scrolling.
	# Reference stays the tight column (text/cheat-sheet; WeaponTableDisplay
	# scrolls inside it by the Phase-1 keeper contract).
	_make_drawer("crew", "Crew", DrawerClass.Edge.LEFT, true)
	_make_drawer("enemies", "Enemy Tracker", DrawerClass.Edge.RIGHT, true)
	# Portrait twin of the info rail's battlefield-intel block (objective +
	# visibility + terrain key). Mirrored in _rebuild_info_rail so this content
	# survives when the rail is suppressed on a narrow screen.
	_make_drawer("intel", "Battlefield Intel", DrawerClass.Edge.RIGHT, true)
	_make_drawer("dice", "Dice Roller", DrawerClass.Edge.RIGHT, true)
	_make_drawer("reference", "Battle Round Reference (Core Rules p.119)",
		DrawerClass.Edge.RIGHT)
	_make_drawer("tracking", "Tracking", DrawerClass.Edge.RIGHT, true)
	_make_drawer("oracle", "Enemy AI Oracle", DrawerClass.Edge.RIGHT, true)

	# Repoint the funnel shims at drawer bodies. setup_content stays a valid
	# host for any legacy funnel, but the pre-battle checklist itself is a
	# CENTERED MODAL (approved plan: "ModalLayer (existing OverlayLayer):
	# tier select, pre-battle checklist, enemy-gen wizard"), not a drawer.
	phase_content = _drawer_bodies["tracking"]
	setup_content = _drawer_bodies["tracking"]
	tools_content = _drawer_bodies["dice"]
	reference_content = _drawer_bodies["reference"]

	# Single canonical feed.
	if feed_host and feed_host.get_child_count() == 0:
		unified_log = FPCM_UnifiedBattleLog.new()
		unified_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unified_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		feed_host.add_child(unified_log)

	# Persistent "what do I do now THIS phase" companion banner.
	_build_phase_instruction_banner()

	# Portrait top app bar (self-hides in landscape).
	_build_mobile_app_bar()


func _make_drawer(id: String, title: String, edge: int,
		wide: bool = false) -> void:
	## Create one keeper SlideOverDrawer with an empty VBox body. `wide`
	## drawers fit full component panels (≈480px min) instead of the tight
	## reading column, so a 5-button card row never clips/scrolls sideways.
	if _drawers.has(id):
		return
	var d = DrawerClass.new()
	d.edge = edge
	d.drawer_title = title
	if wide:
		d.min_panel_width = 480.0
	drawer_layer.add_child(d)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIColors.SPACING_SM)
	d.set_content(body)
	_drawers[id] = d
	_drawer_bodies[id] = body


func _open_drawer(id: String) -> void:
	## Exclusive open: tapping a drawer toggles it; others close.
	for key in _drawers:
		var d = _drawers[key]
		if key == id:
			if d.is_open(): d.close()
			else: d.open()
		else:
			d.close()


func _sync_redesign_for_stage(stage: int) -> void:
	## Feed strip + rails follow the battle stage (rails/feed are NEW nodes
	## the legacy match never touches, so order vs the match is irrelevant).
	var combatish: bool = stage in [
		BattleStage.DEPLOYMENT, BattleStage.COMBAT]
	if feed_strip:
		feed_strip.visible = stage != BattleStage.TIER_SELECT
	if crew_rail_panel:
		crew_rail_panel.visible = combatish or stage == BattleStage.SETUP
	if info_rail_panel:
		info_rail_panel.visible = combatish or stage == BattleStage.SETUP
	if map_host:
		map_host.visible = stage != BattleStage.TIER_SELECT \
			and stage != BattleStage.RESOLUTION
	_rebuild_crew_rail()
	_rebuild_info_rail()


func _rebuild_crew_rail() -> void:
	if not crew_rail:
		return
	for c in crew_rail.get_children():
		c.queue_free()
	if crew_units.is_empty():
		return
	var alive: int = 0
	var acted: int = 0
	var q_pending: int = 0
	var s_pending: int = 0
	for u in crew_units:
		if not u.is_dead:
			alive += 1
			if u.is_activated:
				acted += 1
			elif u.react_slot == 1:
				q_pending += 1
			elif u.react_slot == 2:
				s_pending += 1
	_rail_header(crew_rail, "CREW  %d / %d" % [alive, crew_units.size()])
	# Live activation bookkeeping (Core Rules p.114) — who has acted, and how
	# many still owe a Quick / Slow activation this round.
	_rail_header(crew_rail, "ACTIVATED %d/%d · Q %d · S %d" % [
		acted, alive, q_pending, s_pending])
	var reset_btn := Button.new()
	reset_btn.text = "↺ Round"
	reset_btn.tooltip_text = "Manually reset all crew activation for a new round"
	reset_btn.add_theme_font_size_override("font_size", 11)
	reset_btn.pressed.connect(_on_manual_round_reset)
	crew_rail.add_child(reset_btn)
	for u in crew_units:
		crew_rail.add_child(_unit_minicard(
			u.node_name, u.health, u.max_health, u.is_dead,
			"C%d T%d Sv%d R%d" % [u.combat_skill, u.toughness,
				u.savvy, u.reactions],
			"Acts %d" % u.actions_remaining,
			func() -> void: _open_drawer("crew"), u))


func _rebuild_info_rail() -> void:
	if not info_rail:
		return
	for c in info_rail.get_children():
		c.queue_free()

	# Objective + battlefield modifiers (the rail-exclusive content with no other
	# drawer twin). Mirrored into the "intel" drawer below so it survives when the
	# rail is hidden in portrait. The enemy summary that follows is rail-only —
	# it is fully covered by the "enemies" drawer when the rail collapses.
	_build_battlefield_intel(info_rail)
	info_rail.add_child(HSeparator.new())

	var n_active: int = 0
	for e in enemy_units:
		if not e.is_dead:
			n_active += 1
	_rail_header(info_rail, "ENEMIES  %d / %d active" % [
		n_active, enemy_units.size()])
	# This-round casualties feed the End Phase Morale check (Core Rules
	# pp.114-115) — surfaced so the trigger is glanceable, not hidden.
	var cas: int = 0
	if morale_tracker and is_instance_valid(morale_tracker) \
			and "casualties_this_round" in morale_tracker:
		cas = morale_tracker.casualties_this_round
	if cas > 0:
		_info_modifier_line(info_rail,
			"☠ Casualties this round: %d (→ End Phase Morale)" % cas,
			UIColors.COLOR_DANGER)
	for e in enemy_units:
		info_rail.add_child(_unit_minicard(
			e.node_name, e.health, e.max_health, e.is_dead,
			"C%d T%d R%d" % [e.combat_skill, e.toughness, e.reactions],
			"", func() -> void: _open_drawer("enemies"), e))

	# Mirror the battlefield intel into the portrait "intel" drawer so the
	# objective / visibility / terrain notes survive when the rail is hidden.
	# The drawer copy ALSO carries the terrain controls (legend / scatter /
	# regenerate / table size) — drawer-only per the map-primary journey
	# rule: nothing docked on the map surface.
	var intel_body = _drawer_bodies.get("intel")
	if intel_body:
		for c in intel_body.get_children():
			c.queue_free()
		_build_battlefield_intel(intel_body, true)


func _build_battlefield_intel(target: Node,
		include_terrain_controls: bool = false) -> void:
	## Objective + battlefield modifiers, built into `target` (the info rail in
	## landscape, the "intel" drawer in portrait). No invented data — only the
	## mission objective and the generator's real visibility / combat_notes.
	## include_terrain_controls: drawer copy only — legend, scatter toggle,
	## Regenerate (SETUP-gated), table size.
	var md: Dictionary = (_stored_mission_data
		if _stored_mission_data is Dictionary else {})
	var obj_txt: String = str(md.get("objective", md.get("type", "")))
	if obj_txt != "":
		_rail_header(target, "OBJECTIVE")
		var ol := Label.new()
		ol.text = "◆ %s (marked on map)" % obj_txt.capitalize()
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.add_theme_font_size_override("font_size", 12)
		ol.add_theme_color_override("font_color", UIColors.COLOR_SUCCESS)
		target.add_child(ol)

	# BATTLEFIELD — real modifiers from the generator result (visibility +
	# world-trait combat_notes). No invented data: only what it returned.
	var notes: Array = _battlefield_data.get("combat_notes", [])
	var vis: String = str(_battlefield_data.get("visibility_limit", ""))
	if vis != "" or not notes.is_empty():
		target.add_child(HSeparator.new())
		_rail_header(target, "BATTLEFIELD")
		if vis != "":
			_info_modifier_line(target, "👁 Visibility: " + vis,
				UIColors.COLOR_WARNING)
		for note in notes:
			_info_modifier_line(target, "• " + str(note),
				UIColors.COLOR_TEXT_PRIMARY)
		# TERRAIN KEY — decodes hazardous vs difficult (Core Rules p.117/p.119).
		_info_modifier_line(target,
			"■ Hazardous: Dmg +1, ignores Armor (p.117)",
			UIColors.COLOR_DANGER)
		_info_modifier_line(target,
			"■ Difficult: Move +1\" per 2\" (p.119)",
			UIColors.COLOR_WARNING)

	if include_terrain_controls:
		_build_terrain_controls(target)


func _build_terrain_controls(target: Node) -> void:
	## Terrain controls for the intel DRAWER only (map-primary journey rule:
	## nothing docked on the map). Legend + scatter toggle + table size, and
	## a Regenerate button gated to SETUP — once the physical table is
	## built, editing the map would desync it.
	target.add_child(HSeparator.new())
	_rail_header(target, "TERRAIN")

	# Table size (Core Rules p.108)
	var table_ft: float = 3.0
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_battlefield_data"):
		table_ft = float(gs.get_battlefield_data().get("table_size_ft", 3.0))
	_info_modifier_line(target,
		"Table: %s (Core Rules p.108)"
			% BattlefieldGridClass.table_size_label(table_ft),
		UIColors.COLOR_TEXT_PRIMARY)

	# Data-driven legend (only categories actually rendered this mission)
	var LegendClass = load(
		"res://src/ui/components/battle/TerrainLegendStrip.gd")
	var legend = LegendClass.new()
	if battlefield_grid_panel \
			and battlefield_grid_panel.has_method("get_rendered_legend_keys"):
		legend.rebuild(battlefield_grid_panel.get_rendered_legend_keys())
	target.add_child(legend)

	# Terrain EDITING controls (scatter visibility, whole-map Regenerate,
	# per-sector re-roll) are available ONLY before the battle starts —
	# SETUP/DEPLOYMENT. Once COMBAT begins the map is locked to what the
	# player physically built; the drawer then shows info only (table size
	# + legend above), and the map itself still supports tap-for-rules /
	# zoom / pan. Changing the map mid-battle would desync the table.
	if current_stage not in [BattleStage.SETUP, BattleStage.DEPLOYMENT]:
		var locked := Label.new()
		locked.text = "Terrain locked for battle — tap a sector for its rules; pinch/scroll to zoom, drag to pan."
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.add_theme_font_size_override("font_size", 11)
		locked.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		target.add_child(locked)
		return

	# Scatter toggle — off while placing main features, on for dressing
	var scatter_toggle := CheckButton.new()
	scatter_toggle.text = "Show scatter terrain"
	scatter_toggle.add_theme_font_size_override("font_size", 12)
	scatter_toggle.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	scatter_toggle.button_pressed = battlefield_grid_panel.show_scatter \
		if battlefield_grid_panel and "show_scatter" in battlefield_grid_panel \
		else true
	scatter_toggle.toggled.connect(func(on: bool) -> void:
		if battlefield_grid_panel \
				and battlefield_grid_panel.has_method("set_show_scatter"):
			battlefield_grid_panel.set_show_scatter(on)
			if is_instance_valid(legend) and battlefield_grid_panel.has_method(
					"get_rendered_legend_keys"):
				legend.rebuild(battlefield_grid_panel.get_rendered_legend_keys()))
	target.add_child(scatter_toggle)

	# Whole-map Regenerate
	var regen_btn := Button.new()
	regen_btn.text = "🎲 Regenerate Terrain"
	regen_btn.tooltip_text = \
		"Roll a whole new battlefield (Compendium 5-step, pp.94-95)"
	regen_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	regen_btn.add_theme_font_size_override("font_size", 12)
	regen_btn.pressed.connect(_on_regenerate_terrain_pressed)
	target.add_child(regen_btn)
	var hint := Label.new()
	hint.text = "Tap any map sector for its rules — or to re-roll just that sector."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	target.add_child(hint)


func _rail_header(parent: Node, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	parent.add_child(l)


func _info_modifier_line(parent: Node, txt: String, col: Color) -> void:
	var l := Label.new()
	l.text = txt
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)


func _unit_minicard(nm: String, hp: int, mx: int, dead: bool,
		stats: String, badge: String, on_press: Callable,
		unit = null) -> Control:
	## Rail mini-card = the glance bookkeeping layer (plan iters 3/7). When a
	## TacticalUnit is passed it renders per-figure state: a Q/S reaction-slot
	## chip (Core Rules p.114), amber stun pips (stackable, p.116-118), and an
	## "activated recede" (acted figures dim + lose the accent border so the
	## eye lands on who still has to act this round).
	var stun: int = unit.stun_markers if unit else 0
	var activated: bool = unit.is_activated if unit else false
	var slot: int = unit.react_slot if unit else 0
	# A still-to-act crew figure gets the accent border (draws the eye);
	# activated / dead figures recede.
	var pending: bool = (not dead) and (not activated)
	# Highlight only a crew figure that still has to act AND has a real
	# reaction slot (1 QUICK / 2 SLOW). Enemies (slot 3) never highlight.
	var highlight: bool = pending and (slot == 1 or slot == 2)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UIColors.COLOR_BASE if dead else UIColors.COLOR_INPUT
	st.border_color = UIColors.COLOR_FOCUS if highlight else UIColors.COLOR_BORDER
	st.set_border_width_all(2 if highlight else 1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(UIColors.SPACING_SM)
	card.add_theme_stylebox_override("panel", st)
	if dead or activated:
		card.modulate = Color(1, 1, 1, 0.55)  # recede; eye lands on pending
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UIColors.SPACING_XS)
	card.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	# Q/S reaction-slot chip (crew only — slot 1=QUICK, 2=SLOW; enemies are
	# slot 3=ENEMY phase and need no chip). Empty until the Reaction Roll.
	if slot == 1 or slot == 2:
		var chip := Label.new()
		chip.text = " Q " if slot == 1 else " S "
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		var cs := StyleBoxFlat.new()
		cs.bg_color = UIColors.COLOR_ACCENT if slot == 1 else UIColors.COLOR_WARNING
		cs.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("normal", cs)
		top.add_child(chip)
	var nl := Label.new()
	nl.text = ("☠ " if dead else ("✓ " if activated else "")) + nm
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color",
		UIColors.COLOR_TEXT_DISABLED if dead else UIColors.COLOR_TEXT_PRIMARY)
	top.add_child(nl)
	# Stun pips — one amber ● per marker (Core Rules: Stunned figures may Move
	# OR Combat Action; a marker is removed only after the figure acts).
	if stun > 0 and not dead:
		var pips := Label.new()
		pips.text = "●".repeat(stun)
		pips.tooltip_text = "%d Stun marker(s) — Move OR Combat, not both" % stun
		pips.add_theme_font_size_override("font_size", 11)
		pips.add_theme_color_override("font_color", UIColors.COLOR_WARNING)
		top.add_child(pips)
	if badge != "":
		var bl := Label.new()
		bl.text = badge
		bl.add_theme_font_size_override("font_size", 11)
		bl.add_theme_color_override("font_color", UIColors.COLOR_ACCENT)
		top.add_child(bl)
	vb.add_child(_rail_hp_bar(hp, mx))
	var sl := Label.new()
	sl.text = stats
	sl.add_theme_font_size_override("font_size", 11)
	sl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	vb.add_child(sl)
	return card


func _rail_hp_bar(hp: int, mx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, float(mx))
	bar.value = float(hp)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frac: float = float(hp) / maxf(1.0, float(mx))
	var fill := StyleBoxFlat.new()
	fill.bg_color = (UIColors.COLOR_DANGER if frac <= 0.3
		else (UIColors.COLOR_WARNING if frac <= 0.6 else UIColors.COLOR_SUCCESS))
	fill.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.COLOR_INPUT
	bg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	var lbl := Label.new()
	lbl.text = "%d/%d" % [hp, mx]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	row.add_child(lbl)
	return row

func _check_standalone_mode() -> void:
	## If initialize_battle() was never called, check if battle context was
	## stored in temp_data by a gamemode turn controller (Bug Hunt, Planetfall,
	## Tactics). If so, auto-initialize from that context. Otherwise, show
	## tier selection for standalone/MCP/demo mode (BUG-B01, B06, B17, B18 fix).
	if _battle_initialized:
		return
	# QA-FIX: Only show tier selection if actually visible and not embedded in campaign flow.
	if not visible:
		return
	var ancestor := get_parent()
	while ancestor:
		if ancestor.name == "PhaseContainer":
			return # Embedded in campaign turn flow — not standalone
		ancestor = ancestor.get_parent()

	# Check for SceneRouter-delegated battle context in temp_data
	if _try_auto_init_from_temp_data():
		return

	_log_message("Standalone mode — no campaign data. Set up your table manually.", UIColors.COLOR_WARNING)
	_show_tier_selection()


func _try_auto_init_from_temp_data() -> bool:
	## Check if a gamemode turn controller stored battle context in temp_data.
	## Supports Bug Hunt, Planetfall, and Tactics delegation patterns.
	## Returns true if auto-initialized from temp_data.
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if not gs_mgr or not gs_mgr.has_method("get_temp_data"):
		return false

	# Check each gamemode's battle context key
	var context_keys: Array = [
		{"context_key": "bug_hunt_battle_context", "result_key": "bug_hunt_battle_result", "return_screen": "bug_hunt_turn_controller"},
		{"context_key": "planetfall_battle_context", "result_key": "planetfall_battle_result", "return_screen": "planetfall_turn_controller"},
		{"context_key": "tactics_battle_context", "result_key": "tactics_battle_result", "return_screen": "tactics_turn_controller"},
	]

	for key_set in context_keys:
		var context = gs_mgr.get_temp_data(key_set["context_key"])
		if context is Dictionary and not context.is_empty():
			_return_screen = key_set["return_screen"]
			_result_temp_key = key_set["result_key"]

			# Extract crew and enemies from context
			var crew: Array = context.get("crew", [])
			var enemies: Array = context.get("enemies", [])
			var mission_data: Dictionary = context.get("mission_data", {})

			# Ensure battle_mode is set in mission_data
			if not mission_data.has("battle_mode"):
				if "bug_hunt" in key_set["context_key"]:
					mission_data["battle_mode"] = "bug_hunt"
				elif "planetfall" in key_set["context_key"]:
					mission_data["battle_mode"] = "planetfall"
				elif "tactics" in key_set["context_key"]:
					mission_data["battle_mode"] = "tactics"

			_log_message("Auto-initializing from %s context..." % _return_screen.replace("_", " "),
				UIColors.COLOR_CYAN)

			# Connect our own signal to handle result storage + return
			if not tactical_battle_completed.is_connected(_on_delegated_battle_completed):
				tactical_battle_completed.connect(_on_delegated_battle_completed)

			initialize_battle(crew, enemies, mission_data)

			# Clear the context key (consumed)
			gs_mgr.set_temp_data(key_set["context_key"], null)
			return true

	return false


func _on_delegated_battle_completed(result: Dictionary) -> void:
	## When battle was launched via SceneRouter delegation, store results
	## in temp_data and navigate back to the calling turn controller.
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if gs_mgr and gs_mgr.has_method("set_temp_data") and not _result_temp_key.is_empty():
		gs_mgr.set_temp_data(_result_temp_key, result)

	if not _return_screen.is_empty():
		var router = get_node_or_null("/root/SceneRouter")
		if router and router.has_method("navigate_to"):
			router.navigate_to(_return_screen)
			return

	# Fallback: just log if no router available
	push_warning("TacticalBattleUI: Battle completed but no return route configured.")

# ============================================================================
# RESPONSIVE LAYOUT
# ============================================================================

func _get_ui_scale() -> float:
	## Scale factor relative to ResponsiveManager's shared design base.
	var vp_width := get_viewport().get_visible_rect().size.x
	return clampf(vp_width / ResponsiveManager.DESIGN_BASE_WIDTH, 0.75, 2.0)

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

var _responsive_layout_in_progress: bool = false

func _apply_responsive_layout() -> void:
	## Scale panel sizes proportionally to viewport
	if _responsive_layout_in_progress:
		return  # Guard against re-entrant calls from resize feedback
	_responsive_layout_in_progress = true

	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0 or vp.y <= 0:
		_responsive_layout_in_progress = false
		return

	# Proportional column widths (percentage-based with min/max clamps)
	if left_panel:
		var new_w := clampf(vp.x * 0.15, 200, 400)
		if absf(left_panel.custom_minimum_size.x - new_w) > 1.0:
			left_panel.custom_minimum_size.x = new_w
	if right_panel:
		var new_w := clampf(vp.x * 0.20, 260, 500)
		if absf(right_panel.custom_minimum_size.x - new_w) > 1.0:
			right_panel.custom_minimum_size.x = new_w

	# Phase content panel minimum height scales
	if phase_content_panel:
		var new_h := clampf(vp.y * 0.15, 140, 300)
		if absf(phase_content_panel.custom_minimum_size.y - new_h) > 1.0:
			phase_content_panel.custom_minimum_size.y = new_h

	# Feed strip height: shorter on a short portrait viewport (the map + the new
	# phase-instruction banner are the priority; the feed is glance/history),
	# taller on desktop for readability. Same proportional-clamp idiom as the rails.
	if feed_strip:
		var feed_h := clampf(vp.y * 0.18, 96, 200)
		if absf(feed_strip.custom_minimum_size.y - feed_h) > 1.0:
			feed_strip.custom_minimum_size.y = feed_h

	_responsive_layout_in_progress = false
	# Re-apply the portrait rail mask on resize/rotation (viewport_resized →
	# debounce → here). This is what makes a constant-stage rotation collapse or
	# restore the rails without a stage change.
	_reconcile_portrait_layout()
	_reconcile_bars_portrait()

func _apply_stage_visibility(stage: int) -> void:
	## Control which panels are visible based on current battle stage
	current_stage = stage

	# Update breadcrumb
	_update_breadcrumb(stage)

	# EDIT 17: enable map drag-drop only during DEPLOYMENT (positions are
	# player-managed on the physical table during COMBAT).
	# battlefield_grid_panel IS the bare MapView (property, not the old
	# GridPanel forwarder method — the has_method guard never matched,
	# so drag never enabled; fixed 2026-07-03).
	if battlefield_grid_panel and "allow_unit_drag" in battlefield_grid_panel:
		battlefield_grid_panel.allow_unit_drag = (stage == BattleStage.DEPLOYMENT)

	# Journey staging: the sector popover's Re-roll is SETUP-only, and a
	# stage change invalidates any open popover.
	if _sector_popover and is_instance_valid(_sector_popover):
		_sector_popover.hide_popover()

	# Redesign frame: feed strip + rails follow the stage (non-conflicting
	# with the legacy match below, which only touches the shimmed panels).
	_sync_redesign_for_stage(stage)

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
			if battle_round_hud: battle_round_hud.visible = false  # Not relevant until combat
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
			if battle_round_hud: battle_round_hud.visible = false  # Not relevant until combat
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

	# Capture the stage's rail INTENT (after the match has had the final say),
	# then apply the portrait mask. Capturing here lets a later rotation restore
	# the stage-correct rails without re-deriving the match.
	_rail_intent_crew = crew_rail_panel.visible if crew_rail_panel else false
	_rail_intent_info = info_rail_panel.visible if info_rail_panel else false
	_reconcile_portrait_layout()
	_reconcile_bars_portrait()


## Portrait/phone → collapse the battle rails so the map fills the row. Crew +
## enemies stay reachable via the persistent drawer toolbar; the battlefield
## intel is mirrored into the "intel" drawer.
func _should_collapse_battle_rails() -> bool:
	if _responsive_manager and _responsive_manager.has_method(
			"should_collapse_to_single_column"):
		return _responsive_manager.should_collapse_to_single_column()
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2.ZERO
	return vp.x > 0 and vp.y > vp.x


## Apply the portrait mask: each rail is visible only when its stage wants it AND
## we are not collapsed to a single column. Idempotent — safe to call after a
## stage change AND on every viewport resize/rotation.
func _reconcile_portrait_layout() -> void:
	var collapse := _should_collapse_battle_rails()
	if crew_rail_panel:
		crew_rail_panel.visible = _rail_intent_crew and not collapse
	if info_rail_panel:
		info_rail_panel.visible = _rail_intent_info and not collapse


## Portrait reflow of the bottom action row + top bar. In portrait: drop the
## PhaseButtonsContainer's main-axis expand so the ActionBar HFlow can WRAP its
## buttons (an expanding child suppresses FlowContainer wrapping); ellipsize the
## TopBar title (its full text is the widest TopBar item and would clip the badge
## at 360dp). Landscape restores every value → desktop stays pixel-stable.
## Idempotent — safe to call from the stage match AND every resize/rotation.
func _reconcile_bars_portrait() -> void:
	var portrait := _should_collapse_battle_rails()
	if action_buttons:
		action_buttons.size_flags_horizontal = \
			Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_EXPAND_FILL
	# In portrait the MobileAppBar replaces the cramped TopBar and hosts the
	# ≡ Panels drawer menu; hide the TopBar + the bottom 7-button DrawerBar (the
	# app-bar menu covers it). Restore both in landscape (the app bar self-hides).
	if _top_bar:
		_top_bar.visible = not portrait
	var drawer_bar := action_buttons.get_node_or_null("DrawerBar") if action_buttons else null
	if drawer_bar:
		(drawer_bar as CanvasItem).visible = not portrait
	if _mobile_app_bar and _mobile_app_bar.has_method("set_subtitle") and tier_badge:
		_mobile_app_bar.set_subtitle(tier_badge.text)
	# Battle-notes visibility is owned by _sync_battle_notes_visibility (M4) — it
	# combines on-screen state with the portrait gate.
	_sync_battle_notes_visibility()


## Build the persistent phase-instruction banner at the TOP of BottomContent
## (adjacent to the phase buttons that advance it), so the player always sees the
## PHYSICAL action to perform this phase. Hidden until the first instruction is set.
func _build_phase_instruction_banner() -> void:
	if _phase_banner != null or phase_hud == null:
		return
	var bottom_content: Node = phase_hud.get_parent()  # BottomContent VBox
	if bottom_content == null:
		return
	_phase_banner = PanelContainer.new()
	_phase_banner.name = "PhaseInstructionBanner"
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_SECONDARY
	style.border_color = UIColors.COLOR_CYAN
	style.border_width_left = 4  # accent stripe
	style.set_corner_radius_all(6)
	style.set_content_margin_all(UIColors.SPACING_SM)
	_phase_banner.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_phase_banner.add_child(vb)
	_phase_banner_chip = Label.new()
	_phase_banner_chip.add_theme_font_size_override("font_size", _scaled_font(12))
	_phase_banner_chip.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	vb.add_child(_phase_banner_chip)
	_phase_banner_label = Label.new()
	_phase_banner_label.add_theme_font_size_override("font_size", _scaled_font(16))
	_phase_banner_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
	_phase_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_phase_banner_label)
	bottom_content.add_child(_phase_banner)
	bottom_content.move_child(_phase_banner, 0)
	_phase_banner.visible = false


## Build the portrait top app bar as the first child of MainContainer. It hosts
## the ≡ Panels drawer menu and shows the tier as subtitle; self-hides in
## landscape (so desktop keeps the full TopBar untouched).
func _build_mobile_app_bar() -> void:
	if _mobile_app_bar != null:
		return
	_top_bar = title_label.get_parent() if title_label else null
	var main_container := get_node_or_null("EdgeMargin/MainContainer")
	if main_container == null:
		return
	_mobile_app_bar = MobileAppBarClass.new()
	main_container.add_child(_mobile_app_bar)
	main_container.move_child(_mobile_app_bar, 0)
	_mobile_app_bar.setup("Tactical Companion",
		tier_badge.text if tier_badge else "", true)
	if _mobile_app_bar.has_method("set_back_handler"):
		_mobile_app_bar.set_back_handler(_on_return_to_battle_resolution)


## (Re)build the portrait "≡ Panels" drawer menu in the app-bar actions slot.
## Mirrors the landscape 7-button DrawerBar's ids; both coexist (orientation
## toggles which is visible). Frees the previous menu to avoid a leak.
func _rebuild_panels_menu(ids: Array) -> void:
	if _mobile_app_bar == null:
		return
	if _panels_menu and is_instance_valid(_panels_menu):
		_panels_menu.queue_free()
	_panels_menu = MenuButton.new()
	_panels_menu.text = "≡ Panels"
	_panels_menu.custom_minimum_size = Vector2(0, _touch_h())
	_panels_menu.flat = false
	var pm := _panels_menu.get_popup()
	for i in range(ids.size()):
		pm.add_item(str(ids[i]).capitalize(), i)
	# Portrait twin of the Record Result button (id == ids.size(), the one slot
	# past the drawer ids). Same reachable end-a-played-battle path.
	var record_idx: int = ids.size()
	pm.add_separator()
	pm.add_item("✔ Record Result", record_idx)
	pm.id_pressed.connect(func(idx: int) -> void:
		if idx == record_idx:
			_on_record_result_pressed()
		elif idx >= 0 and idx < ids.size():
			_open_drawer(str(ids[idx])))
	if _mobile_app_bar.has_method("add_action"):
		_mobile_app_bar.add_action(_panels_menu)


## Set the persistent companion instruction: the PHYSICAL action to perform this
## phase + intra-round 5-phase progress. `instruction` reuses the existing
## per-phase copy verbatim (no invented game data). Empty text hides the banner.
func _set_phase_instruction(phase_idx: int, phase_name: String, instruction: String) -> void:
	if _phase_banner == null:
		return
	if instruction.is_empty():
		_phase_banner.visible = false
		return
	if _phase_banner_chip:
		_phase_banner_chip.text = "PHASE %d/5 · %s" % [phase_idx + 1, phase_name.to_upper()]
	if _phase_banner_label:
		_phase_banner_label.text = instruction
	_phase_banner.visible = true

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
			var action_bar: Container = end_turn_button.get_parent() if end_turn_button else null
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
		# BUG-104: hint so the collapsed accordion is discoverable.
		var tools_hint := Label.new()
		tools_hint.text = "Tap a section to expand (one open at a time)."
		tools_hint.add_theme_font_size_override("font_size", 12)
		tools_hint.add_theme_color_override(
			"font_color", Color(0.61, 0.64, 0.69))
		tools_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tools_content.add_child(tools_hint)

		var tools_accordion := FPCM_AccordionToolContainer.new()
		tools_accordion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools_accordion.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# BUG-104: one-line description per section so each says what it does.
		tools_accordion.add_section("Quick Dice Rolls", dice_dashboard,
			"Roll dice for any check (d6, 2d6, d100)")
		tools_accordion.add_section("Combat Calculator", combat_calculator,
			"Compute hit chance and damage for an attack")
		tools_accordion.add_section("Combat Situation", combat_situation_panel,
			"Track cover, range and modifiers for the current shot")
		tools_accordion.add_section("Character Quick Roll", character_quick_roll,
			"Roll a stat check for a specific crew member")
		tools_accordion.add_section("Brawl Resolver", brawl_resolver,
			"Resolve a melee brawl between two fighters")
		tools_content.add_child(tools_accordion)
		# BUG-104: default-expand the most-used section so the panel is not
		# all-collapsed on entry (reuses existing open_section()).
		tools_accordion.open_section(0)
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

	# Tier-conditional component instantiation (Phase 58 fix)
	# Only instantiate higher-tier components if the tier warrants it.
	# Previously all tiers got all components, making LOG_ONLY identical to ASSISTED.
	if tier_controller and tier_controller.current_tier >= 1:
		_instance_assisted_components()
	if tier_controller and tier_controller.current_tier >= 2:
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

func _on_unit_right_clicked(unit_idx: int, screen_pos: Vector2) -> void:
	## Right-click on a unit token → context menu for marking casualty.
	## Increments BattleRoundHUD's casualty counter so morale prompt fires correctly.
	var menu := PopupMenu.new()
	menu.add_item("Mark Wounded", 0)
	menu.add_item("Mark Dead", 1)
	menu.add_separator()
	menu.add_item("Show Details", 2)
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0:
				if unified_log and unified_log.has_method("add_entry"):
					unified_log.add_entry("INJURY", "Unit %d marked Wounded" % unit_idx)
			1:
				if battle_round_hud and battle_round_hud.has_method("report_casualty"):
					battle_round_hud.report_casualty()
				if unified_log and unified_log.has_method("add_entry"):
					unified_log.add_entry("INJURY", "Unit %d marked Dead" % unit_idx)
			2:
				if unified_log and unified_log.has_method("add_entry"):
					unified_log.add_entry("INFO", "Unit %d details" % unit_idx)
		menu.queue_free()
	)
	add_child(menu)
	menu.position = Vector2i(screen_pos)
	menu.popup()

func _on_round_hud_roll_dice() -> void:
	## Player clicked the "Roll Dice" button on the auto-prompt.
	## Pick a sensible phase-appropriate dice pattern and run it through
	## the existing _on_quick_dice_pressed handler so it logs identically.
	if not round_tracker:
		return
	var current_round_num: int = round_tracker.get_current_round() if round_tracker.has_method("get_current_round") else 1
	var current_phase_idx: int = round_tracker.get_current_phase() if round_tracker.has_method("get_current_phase") else 0
	match current_phase_idx:
		0:  # REACTION_ROLL
			_on_quick_dice_pressed(1, 6, "Reaction roll")
		2:  # ENEMY_ACTIONS — no inherent roll, but allow 1D6 for enemy targeting
			_on_quick_dice_pressed(1, 6, "Enemy roll")
		4:  # END_PHASE
			if current_round_num == 2 or current_round_num == 4:
				_on_quick_dice_pressed(1, 100, "Battle event (Core Rules p.116)")
			elif current_round_num > 4:
				_on_quick_dice_pressed(1, 6, "Escalation check")
			else:
				_on_quick_dice_pressed(1, 6, "Morale check")
		_:
			_on_quick_dice_pressed(1, 6, "Quick roll")

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
		# Player override of objective progress (companion app — player owns
		# the physical table). Routes through the tracker, then refreshes.
		if victory_progress.has_signal("objective_progress_input") \
				and not victory_progress.objective_progress_input.is_connected(
					_on_objective_progress_input):
			victory_progress.objective_progress_input.connect(
				_on_objective_progress_input)

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

	# BUG-104 wiring check / BUG-106: CharacterQuickRollPanel and
	# BrawlResolverPanel were shown in the Tools accordion but their results
	# were never echoed to the log like the other tools. Wire them to match.
	if character_quick_roll and unified_log:
		if character_quick_roll.has_signal("roll_completed"):
			character_quick_roll.roll_completed.connect(
				func(char_name: String, roll_type: String,
						result: Dictionary) -> void:
					var detail: String = str(result.get("summary",
						result.get("explanation", roll_type)))
					unified_log.log_action(
						"Quick Roll", "%s: %s" % [char_name, detail]
					)
			)

	if brawl_resolver and unified_log:
		if brawl_resolver.has_signal("brawl_resolved"):
			brawl_resolver.brawl_resolved.connect(
				func(result: Dictionary) -> void:
					var detail: String = str(result.get("summary",
						result.get("explanation", "resolved")))
					unified_log.log_action("Brawl", detail)
			)

	if battle_round_hud:
		battle_round_hud.next_phase_requested.connect(
			_on_advance_phase_pressed
		)
		if battle_round_hud.has_signal("roll_dice_requested") \
				and not battle_round_hud.roll_dice_requested.is_connected(_on_round_hud_roll_dice):
			battle_round_hud.roll_dice_requested.connect(_on_round_hud_roll_dice)

	# WeaponTableDisplay — weapon reference selection
	if weapon_table_display and unified_log:
		if weapon_table_display.has_signal("weapon_selected"):
			weapon_table_display.weapon_selected.connect(
				func(weapon_data) -> void:
					var wname: String = weapon_data.name if weapon_data and "name" in weapon_data else "Weapon"
					unified_log.log_action("Reference", "Viewed: %s" % wname)
			)

## Overlay Management

## Responsive max width for a modal overlay: fills a phone (minus scrim gutters)
## up to a comfortable desktop cap. Prevents the fixed 500/560px OverlayContent
## from overflowing the ~321px portrait floor.
func _overlay_width(desktop_cap: float = 560.0) -> float:
	var vp_x: float = float(get_viewport().get_visible_rect().size.x)
	return clampf(vp_x - 32.0, 280.0, desktop_cap)

## Device-keyed touch-target height (56 mobile / 48 else). Fallback 48.
func _touch_h() -> int:
	if _responsive_manager and _responsive_manager.has_method("get_touch_target_size"):
		return _responsive_manager.get_touch_target_size()
	return 48

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
	# Drive the overlay width responsively so portrait phones don't overflow.
	overlay_content.custom_minimum_size.x = _overlay_width()
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
	# Responsive width (clamp to viewport, up to a 700px desktop cap) so the
	# wizard never overflows the ~321px portrait floor.
	enemy_generation_wizard.custom_minimum_size.x = _overlay_width(700.0)
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

	# Instance tier-gated components NOW that the tier is known. _setup_ui()
	# ran _instance_log_only_components() before tier selection (tier_controller
	# was null → the >=1 / >=2 gates were skipped), so without this the
	# assisted/oracle components (VictoryProgressPanel, ObjectiveDisplay,
	# MoralePanicTracker, ActivationTrackerPanel, ReactionDicePanel,
	# EnemyIntentPanel) would never instantiate. Guarded against double-instance.
	if tier >= 1 and victory_progress == null:
		_instance_assisted_components()
	if tier >= 2 and enemy_intent_panel == null:
		_instance_oracle_components()

	# initialize_battle() ran _create_character_cards() BEFORE the player
	# picked a tier, so the per-figure drawers were built while
	# activation_tracker was still null (its units were never registered).
	# Now that the ASSISTED rules engines exist, rebuild the drawers so the
	# Tracking drawer's ActivationTrackerPanel is populated and in lock-step.
	if tier >= 1 and (not crew_units.is_empty() or not enemy_units.is_empty()):
		_create_character_cards([])

	_apply_tier_visibility(tier)
	_hide_overlay()
	_apply_stage_visibility(BattleStage.SETUP)

	# Pre-battle checklist: a CENTERED MODAL on the existing OverlayLayer
	# (approved plan ModalLayer role), not the deleted Setup tab.
	_show_pre_battle_checklist(tier)

func _show_pre_battle_checklist(tier: int) -> void:
	## Show the pre-battle checklist as a centered modal. The dense per-step
	## rows (label + Roll/I-rolled controls) need the wide OverlayContent
	## (>=500px), not a tight 380px keeper drawer. Scrollable so a tall
	## checklist never overflows the viewport.
	# modal_root = [ scroller(checklist) | fixed Begin-Battle footer ].
	# The button MUST live OUTSIDE the scroller: a tall checklist scrolls
	# its rows below the clip fold, and a clipped button is not clickable
	# (verified at runtime). A fixed footer keeps the primary action
	# always reachable regardless of scroll position.
	var modal_root := VBoxContainer.new()
	# Responsive width: 560 on desktop, shrinks to fit the portrait floor.
	modal_root.custom_minimum_size = Vector2(_overlay_width(), 0)
	modal_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_root.add_theme_constant_override("separation", UIColors.SPACING_MD)

	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Cap scroller height (leave room for the fixed footer button).
	var vp_h: float = float(get_viewport().get_visible_rect().size.y)
	scroller.custom_minimum_size.y = clampf(vp_h * 0.70, 280, vp_h - 180.0)
	modal_root.add_child(scroller)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", UIColors.SPACING_MD)
	scroller.add_child(col)

	# Battle Card (journey Moment 0): the brief the book spreads across
	# pp.88-90 — objective + win condition, deployment condition, notable
	# sight, enemy summary, theme + table — consolidated ABOVE the checklist.
	var battle_card: Control = _build_battle_card()
	if battle_card:
		col.add_child(battle_card)

	# Create checklist and add to the scrolled column
	var checklist: Control = _get_res("pre_battle_checklist").new()
	checklist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checklist.checklist_completed.connect(_on_checklist_completed)
	col.add_child(checklist)
	# Set tier AFTER adding to tree so _ready() has built the UI
	checklist.set_tier(tier)

	# "Begin Battle" fixed footer (sibling of scroller, never clipped)
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
	modal_root.add_child(begin_btn)

	# Surface it immediately as the modal (scrim + centered).
	_show_overlay(modal_root)

func _on_checklist_completed() -> void:
	## All checklist items checked — log it (player can still click Begin)
	_log_message(
		"Pre-battle checklist complete!", UIColors.COLOR_EMERALD
	)

## Read the active deployment condition id from the persisted contract
## (both key spellings — see the C-phase id-mismatch fix).
func _active_condition_id() -> String:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_battlefield_data"):
		var dc: Dictionary = gs.get_battlefield_data().get(
			"deployment_condition", {})
		return str(dc.get("condition_id", dc.get("id", "")))
	return ""

## Battle Card (journey Moment 0). Only real rolled data — every line that
## has no data is simply omitted. Returns null when nothing is known.
func _build_battle_card() -> Control:
	var gs = get_node_or_null("/root/GameState")
	var contract: Dictionary = gs.get_battlefield_data() \
		if gs and gs.has_method("get_battlefield_data") else {}
	var md: Dictionary = (_stored_mission_data
		if _stored_mission_data is Dictionary else {})
	var ef: Dictionary = _battle_context.get("enemy_force",
		md.get("enemy_force", {}))

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#252542")
	style.border_color = Color("#3A3A5C")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	var rows: int = 0

	var title := Label.new()
	title.text = "BATTLE CARD"
	title.add_theme_font_size_override("font_size", _scaled_font(12))
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(title)

	# Objective + win condition (p.89-90)
	var obj_txt: String = str(md.get("objective", md.get("type", "")))
	if obj_txt != "":
		var win: String = BattleFlowGuideClass.objective_win_text(obj_txt)
		rows += 1
		_battle_card_row(vbox, "◆ Objective: %s" % obj_txt.capitalize(),
			win + (" (Core Rules p.90)" if win != "" else ""),
			UIColors.COLOR_SUCCESS)

	# Deployment condition (p.88)
	var dc: Dictionary = contract.get("deployment_condition", {})
	var dc_title: String = str(dc.get("title", ""))
	if dc_title != "" and dc_title.to_lower() != "no condition":
		rows += 1
		_battle_card_row(vbox, "⚠ Condition: %s" % dc_title,
			str(dc.get("description", "")) + " (Core Rules p.88)",
			UIColors.COLOR_WARNING)

	# Notable Sight (p.89)
	var sight: Dictionary = contract.get("notable_sight", {})
	if not sight.is_empty() \
			and str(sight.get("type", "")).to_upper() != "NOTHING":
		rows += 1
		_battle_card_row(vbox, "★ Notable Sight: %s"
			% str(sight.get("name", "")),
			"%s %s" % [str(sight.get("effect", "")),
				str(sight.get("rule", ""))],
			UIColors.COLOR_AMBER)

	# Enemy summary
	var e_count: int = int(ef.get("count", contract.get("enemy_count", 0)))
	var e_type: String = str(ef.get("type", ""))
	if e_count > 0:
		rows += 1
		var ai_code: String = str(ef.get("ai", contract.get("enemy_ai", "")))
		var ai_line: String = str(AI_DESCRIPTIONS.get(ai_code.to_upper(), ""))
		_battle_card_row(vbox, "☠ Enemy: %d x %s" % [e_count,
			e_type if e_type != "" else "opponents"], ai_line,
			UIColors.COLOR_RED)

	# Theme + table size (pp.94-98 / p.108)
	var theme_line: String = str(contract.get("theme_name", ""))
	if theme_line != "":
		rows += 1
		_battle_card_row(vbox, "▦ Battlefield: %s — %s" % [theme_line,
			BattlefieldGridClass.table_size_label(
				float(contract.get("table_size_ft", 3.0)))],
			"Build it from the map (tap any sector for details).",
			UIColors.COLOR_TEXT_PRIMARY)

	if rows == 0:
		card.queue_free()
		return null
	return card

func _battle_card_row(parent: Node, head: String, detail: String,
		color: Color) -> void:
	var head_lbl := Label.new()
	head_lbl.text = head
	head_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
	head_lbl.add_theme_color_override("font_color", color)
	parent.add_child(head_lbl)
	if detail.strip_edges() != "":
		var detail_lbl := Label.new()
		detail_lbl.text = detail.strip_edges()
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
		detail_lbl.add_theme_color_override("font_color",
			UIColors.COLOR_TEXT_SECONDARY)
		parent.add_child(detail_lbl)

func _on_checklist_dismissed() -> void:
	## Player clicked Begin Battle — close the modal, proceed to deployment.
	## ALL tiers (incl. LOG_ONLY) now get the full companion: map, enemy tracker,
	## 5-phase round HUD. LOG_ONLY no longer short-circuits to a bare results
	## form — the reachable "Record Result" button (see _rebuild_drawer_toolbar)
	## is how a played battle at any tier is recorded, so the companion's
	## table-tracking value is never thrown away (choice-B design, 2026-07-05).
	_hide_overlay()
	_apply_stage_visibility(BattleStage.DEPLOYMENT)
	_update_action_buttons_for_deployment()
	_log_message(
		"Deploy your crew in the deployment zone",
		UIColors.COLOR_CYAN
	)

## LOG_ONLY Results Form (Phase 58)

var _log_only_results_form: Control = null

func _show_log_only_results_form() -> void:
	## Results-only view (TIER_SELECT / Battle Simulator path only). The campaign
	## fast-path keeps the FULL companion + the Record Result button instead —
	## this stays for callers that want the bare form with no combat screen.
	_ensure_results_form_drawer()
	current_stage = BattleStage.COMBAT
	if return_button: return_button.visible = true
	if auto_resolve_button: auto_resolve_button.visible = false
	if turn_indicator:
		turn_indicator.text = "Enter your battle results"
	_open_drawer("results")

func _ensure_results_form_drawer() -> void:
	## Build the BattleResultsInputForm + its "results" drawer once (idempotent).
	## This is the reachable "record what happened on my table" path for a PLAYED
	## battle at ANY tier — the companion never simulates the fight for the player
	## (that is what the top-bar Auto Resolve is for). Seeded from the live
	## objective tracker so the player starts from the objective-accurate guess.
	if _drawers.has("results") and _log_only_results_form \
			and is_instance_valid(_log_only_results_form):
		return
	var FormClass = load(
		"res://src/ui/components/battle/BattleResultsInputForm.gd")
	_log_only_results_form = FormClass.new()

	var crew_data: Array = []
	for unit in crew_units:
		if unit.original_character:
			crew_data.append(unit.original_character)
		else:
			crew_data.append({
				"character_name": unit.node_name,
				"combat": unit.combat_skill,
				"reactions": unit.reactions,
				"toughness": unit.toughness,
				"speed": unit.speed,
			})
	if crew_data.is_empty():
		crew_data = [{"character_name": "Crew", "combat": 1, "reactions": 1,
			"toughness": 3, "speed": 4}]

	var enemy_count: int = enemy_units.size()
	if enemy_count == 0:
		enemy_count = 8

	_log_only_results_form.setup(
		crew_data, enemy_count,
		_stored_mission_data if _stored_mission_data is Dictionary else {},
		_build_results_prefill())
	_log_only_results_form.results_submitted.connect(
		_on_log_only_results_submitted)

	_make_drawer("results", "Record Battle Result", DrawerClass.Edge.RIGHT, true)
	var rbody: VBoxContainer = _drawer_bodies["results"]
	for c in rbody.get_children():
		c.queue_free()
	_log_only_results_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rbody.add_child(_log_only_results_form)

func _build_results_prefill() -> Dictionary:
	## Seed the results form from the live objective tracker so the player starts
	## from the objective-accurate guess (they still confirm/edit on the table).
	var prefill: Dictionary = {}
	if _objective_tracker != null and _objective_tracker.has_objective():
		prefill = _objective_tracker.get_result_prefill()
		prefill["objective_id"] = _objective_tracker.get_objective_id()
		prefill["objective_name"] = _objective_tracker.get_objective_name()
		prefill["objective_met"] = _objective_tracker.is_complete()
		var os = _objective_tracker._system  # resolved Objective lives here
		if os and os.current_objective \
				and "victory_condition" in os.current_objective:
			prefill["objective_condition"] = str(
				os.current_objective.victory_condition)
	return prefill

func _on_record_result_pressed() -> void:
	## Reachable end-a-played-battle control (Record Result button). Opens the
	## results form so the player declares their table outcome + objective, then
	## submit → _on_log_only_results_submitted → tactical_battle_completed.
	_ensure_results_form_drawer()
	_open_drawer("results")

func _on_log_only_results_submitted(result: Dictionary) -> void:
	## Handle LOG_ONLY form submission — transition to resolution.
	## Close the results drawer FIRST so the form doesn't linger over the
	## PostBattle sequence that tactical_battle_completed hands off to
	## (on-device F10 walk, Test21: drawer stayed open atop PostBattle).
	if _drawers.has("results") and is_instance_valid(_drawers["results"]):
		_drawers["results"].close()
	_log_message("Battle results recorded", UIColors.COLOR_EMERALD)
	_apply_stage_visibility(BattleStage.RESOLUTION)
	tactical_battle_completed.emit(result)

## Tier Visibility

func _apply_tier_visibility(tier: int) -> void:
	## REAL per-tier gating (was inert pre-redesign): build the drawer
	## toolbar for this tier. LOG_ONLY = crew/enemies/dice/reference;
	## ASSISTED = + tracking; FULL_ORACLE = + oracle. (Plan §Tier scaling.)
	if tier_badge:
		match tier:
			0: tier_badge.text = "[LOG ONLY]"
			1: tier_badge.text = "[ASSISTED]"
			2: tier_badge.text = "[FULL ORACLE]"
	_rebuild_drawer_toolbar(tier)


func _rebuild_drawer_toolbar(tier: int) -> void:
	## (Re)build the drawer-button bar in a dedicated child of the action
	## row so it never clobbers phase buttons added by other code.
	if not action_buttons:
		return
	# HFlowContainer (not HBox) so the 5-7 drawer buttons WRAP across rows in a
	# narrow portrait bar instead of one ~700px row that overflows the 360dp floor.
	# Single-line on desktop (it fits). FlowContainer uses h_separation/v_separation.
	var bar: Container = action_buttons.get_node_or_null("DrawerBar")
	if bar == null:
		bar = HFlowContainer.new()
		bar.name = "DrawerBar"
		bar.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
		bar.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
		# EXPAND on the flow line: without it a nested HFlow only ever gets
		# its MINIMUM width (one 92px button) and wraps the 6-7 drawer
		# buttons into a ~330px COLUMN, inflating the whole bottom bar and
		# starving the map row (found in the 2026-07-03 map-primary audit).
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_buttons.add_child(bar)
		action_buttons.move_child(bar, 0)
	for c in bar.get_children():
		c.queue_free()
	var ids: Array = ["crew", "enemies", "intel", "dice", "reference"]
	if tier >= 1:
		ids.append("tracking")
	if tier >= 2:
		ids.append("oracle")
	for id: String in ids:
		var b := Button.new()
		b.text = id.capitalize()
		b.custom_minimum_size = Vector2(92, _touch_h())
		b.focus_mode = Control.FOCUS_NONE
		var cap_id: String = id
		b.pressed.connect(func() -> void: _open_drawer(cap_id))
		bar.add_child(b)
	# Record Result — the reachable "I finished playing, here's the outcome"
	# control for a PLAYED battle at ANY tier. Without this a played battle had
	# no way to reach the results form / PostBattle except Auto Resolve (which
	# simulates the fight you played by hand) or Return (abandon). Emerald-styled
	# so it reads as the primary end-of-battle action, not just another drawer.
	var record_btn := Button.new()
	record_btn.text = "✔ Record Result"
	record_btn.custom_minimum_size = Vector2(140, _touch_h())
	record_btn.focus_mode = Control.FOCUS_NONE
	var rec_style := StyleBoxFlat.new()
	rec_style.bg_color = UIColors.COLOR_EMERALD
	rec_style.set_corner_radius_all(8)
	rec_style.set_content_margin_all(8)
	record_btn.add_theme_stylebox_override("normal", rec_style)
	var rec_hover := rec_style.duplicate()
	rec_hover.bg_color = Color(UIColors.COLOR_EMERALD, 0.85)
	record_btn.add_theme_stylebox_override("hover", rec_hover)
	record_btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	record_btn.pressed.connect(_on_record_result_pressed)
	bar.add_child(record_btn)
	# Portrait twin: a single ≡ Panels menu in the app bar (same drawer ids).
	_drawer_tier = tier
	_rebuild_panels_menu(ids)
	_toolbar_built = true

func _on_right_tabs_tab_changed(_idx: int) -> void:
	## Re-apply process_mode whenever the active tab changes.
	_apply_inactive_tab_processing()

func _apply_inactive_tab_processing() -> void:
	## Set PROCESS_MODE_DISABLED on inactive tab children, INHERIT on the active one.
	## Per Godot 4.6 docs, this stops _process and _input on hidden tab content.
	if not right_tabs:
		return
	var active: int = right_tabs.current_tab
	for i in range(right_tabs.get_tab_count()):
		var tab_node: Control = right_tabs.get_tab_control(i)
		if tab_node == null:
			continue
		tab_node.process_mode = Node.PROCESS_MODE_INHERIT if i == active else Node.PROCESS_MODE_DISABLED

# EDIT 8: F1 keyboard shortcut to toggle CheatSheetPanel
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F1:
			_toggle_cheat_sheet()
			accept_event()

func _toggle_cheat_sheet() -> void:
	## F1 now opens the Reference drawer (CheatSheetPanel lives inside it).
	if cheat_sheet_panel and cheat_sheet_panel.visible == false:
		cheat_sheet_panel.visible = true
	if cheat_sheet_panel and round_tracker \
			and cheat_sheet_panel.has_method("expand_section_for_phase"):
		var phase_idx: int = round_tracker.get_current_phase() if round_tracker.has_method("get_current_phase") else 0
		cheat_sheet_panel.expand_section_for_phase(phase_idx)
	if _drawers.has("reference"):
		_open_drawer("reference")

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
	# M4: the battle-notes CanvasLayer is a child of this node but renders on its
	# own layer — free it explicitly so it never lingers/floats after the scene
	# leaves the tree.
	if _battle_note_layer and is_instance_valid(_battle_note_layer):
		_battle_note_layer.queue_free()
		_battle_note_layer = null
	# Clean up BattleEventsSystem (RefCounted Resource — nulling frees it)
	_battle_events_system = null
	# Objective tracker is RefCounted held by one var — null frees it. The
	# objective_progress_input connection drops automatically when the
	# victory_progress child frees with this parent (see note below).
	_objective_tracker = null
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

	# Redesign: keep rails fresh as the round advances (HP/active counts).
	_rebuild_crew_rail()
	_rebuild_info_rail()

	# Phase-spine auto-surface (plan §Core Rules phase alignment): at
	# ASSISTED+ the phase-relevant deep surface opens (player can close).
	# round_tracker phase enum: 0=REACTION, 2=ENEMY, 4=END_PHASE.
	if tier_controller and tier_controller.current_tier >= 1:
		if phase == 0:
			# Reaction Roll (Core Rules p.114): D6 per crew figure vs its
			# Reactions populates the rail's Q/S slots. The rail is downstream
			# of the roll (plan iter 9) — static no longer.
			_assign_crew_reaction_slots()
		if phase == 4 and _drawers.has("tracking"):
			_open_drawer("tracking")        # morale/victory at End Phase
			# End Phase Morale (Core Rules pp.114-115): ONLY if the enemy
			# lost figures this round; the player never tests morale.
			_resolve_end_phase_morale()

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
	# Tick down battle event overlay durations (fog/hazard/reinforcement markers expire)
	if battlefield_grid_panel and battlefield_grid_panel.has_method("tick_overlay_durations"):
		battlefield_grid_panel.tick_overlay_durations()
	# Advance objective progress (auto-derives rounds_survived + turn countdown)
	if _objective_tracker != null:
		_objective_tracker.on_round_advanced(round_number)
		_refresh_objective_panel()

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
	if not event_resolution or not tier_controller:
		return
	if tier_controller.current_tier < 1:
		return

	# Generate actual event data from BattleEventsSystem (d100 roll)
	var event_dict: Dictionary = {}
	if _battle_events_system and _battle_events_system.has_method("trigger_battle_event"):
		_battle_events_system.trigger_battle_event()
		var triggered: Array = _battle_events_system.events_triggered
		if not triggered.is_empty():
			var battle_event = triggered.back()
			event_dict = {
				"title": battle_event.title,
				"description": battle_event.description,
				"type": battle_event.target_type,
				"effects": battle_event.effects,
				"duration": battle_event.duration,
			}

	# Fallback: tabletop-companion instruction if no system or no event rolled
	if event_dict.is_empty():
		event_dict = {
			"title": "Battle Event (Round %d)" % round_num,
			"description": "Roll on the Battle Events table (Core Rules p.116) and apply the result.",
			"type": "battlefield",
		}

	_show_overlay(event_resolution)
	event_resolution.display_event(event_dict)

func _on_battle_terrain_effect(effect: Dictionary) -> void:
	## Render battle event visual on the map (fog cloud, hazard zone, reinforcement marker).
	if battlefield_grid_panel and battlefield_grid_panel.has_method("add_terrain_overlay"):
		battlefield_grid_panel.add_terrain_overlay(effect)
	if unified_log and unified_log.has_method("add_entry"):
		unified_log.add_entry(
			"ENVIRONMENT_CHANGE",
			"%s appeared on battlefield" % str(effect.get("label", "Effect")))

func _on_battle_hazard_activated(hazard) -> void:
	## Render environmental hazard activation on the map.
	if not hazard:
		return
	var radius_val: float = 1.0
	if "affects_radius" in hazard:
		radius_val = float(hazard.affects_radius)
	var is_perm: bool = false
	if "is_permanent" in hazard:
		is_perm = bool(hazard.is_permanent)
	var effect_payload: Dictionary = {
		"id": str(hazard.hazard_id) if "hazard_id" in hazard else "hazard",
		"type": "hazard",
		"center": Vector2(12, 8),
		"radius": radius_val,
		"label": str(hazard.hazard_name) if "hazard_name" in hazard else "Hazard",
		"duration_rounds": 0 if is_perm else 2,
	}
	if battlefield_grid_panel and battlefield_grid_panel.has_method("add_terrain_overlay"):
		battlefield_grid_panel.add_terrain_overlay(effect_payload)

func _on_tracker_battle_started() -> void:
	## Handle battle start from tracker — transition to COMBAT stage
	_log_message("Tactical combat initiated", UIColors.COLOR_EMERALD)
	battle_phase = "combat"
	_apply_stage_visibility(BattleStage.COMBAT)

	# Session 48: Pass battle context to HUD and cheat sheet
	_battle_context = _stored_mission_data if _stored_mission_data is Dictionary else {}
	if battle_round_hud and battle_round_hud.has_method("set_battle_context"):
		battle_round_hud.set_battle_context(_battle_context)
	if cheat_sheet_panel and cheat_sheet_panel.has_method("set_battle_context"):
		cheat_sheet_panel.set_battle_context(_battle_context)
	# Show briefing as initial PhaseContent before Reaction Roll
	_show_battle_briefing()
	# Battle end-state tracker — wires the (previously dead) VictoryProgressPanel
	# + ObjectiveDisplay to live progress. Gated on mission_objective presence;
	# rival attacks / non-objective battles fall through harmlessly.
	_init_objective_tracker()

## Build the objective tracker from battle context and feed the UI panels.
func _init_objective_tracker() -> void:
	var mission_obj: Dictionary = {}
	if _battle_context is Dictionary:
		# mission_objective may be a rich Dict {name, victory_condition, type}
		# OR a bare String objective id (the campaign context stores a
		# String). Prefer the richer objective_details Dict when present;
		# otherwise wrap the String so the tracker degrades gracefully
		# instead of crashing on a String→Dict assignment (2026-07-03 walk).
		var raw: Variant = _battle_context.get("mission_objective", {})
		if raw is Dictionary and not raw.is_empty():
			mission_obj = raw
		else:
			var details: Variant = _battle_context.get("objective_details", {})
			if details is Dictionary and not details.is_empty():
				mission_obj = details
			elif raw is String and raw != "":
				mission_obj = {"name": raw, "type": raw}
	if mission_obj == null or mission_obj.is_empty():
		_objective_tracker = null
		return
	var enemy_count: int = enemy_units.size()
	_objective_tracker = BattleObjectiveTrackerClass.new()
	_objective_tracker.init_from_context(mission_obj, enemy_count)
	if not _objective_tracker.has_objective():
		_objective_tracker = null
		return
	if victory_progress and victory_progress.has_method("set_conditions"):
		victory_progress.set_conditions(
			_objective_tracker.get_panel_conditions())
		victory_progress.set_turns_remaining(
			_objective_tracker.get_turns_remaining())
	if objective_display and objective_display.has_method("display_objective"):
		var os = _objective_tracker._system  # resolved Objective lives here
		if os and os.current_objective:
			objective_display.display_objective(os.current_objective, 0)
	# Announce the objective in the battle log at start. display_objective()
	# (unlike roll_objective()) does not emit objective_rolled, so without this
	# the player's log would never record what they were fighting for.
	if unified_log and unified_log.has_method("log_event"):
		var _mo: Dictionary = mission_obj
		unified_log.log_event(
			"Objective: %s" % str(_mo.get("name", _objective_tracker.get_objective_id())),
			str(_mo.get("victory_condition", _mo.get("description", ""))))

## Push current tracker state into VictoryProgressPanel + flag complete/failed.
func _refresh_objective_panel() -> void:
	if _objective_tracker == null or victory_progress == null:
		return
	# Re-entrancy guard: update_condition_progress() rebuilds rows, recreating
	# the StepperControl whose deferred setup() re-emits value_changed. Without
	# this + the no-op guard in _on_objective_progress_input, that forms an
	# infinite refresh→rebuild→setup→signal→refresh loop (found in runtime QA).
	if _objective_refreshing:
		return
	_objective_refreshing = true
	for cond in _objective_tracker.get_panel_conditions():
		if victory_progress.has_method("update_condition_progress"):
			victory_progress.update_condition_progress(
				cond.get("id", ""),
				cond.get("progress", 0.0),
				cond.get("status", ""))
	if victory_progress.has_method("set_turns_remaining"):
		victory_progress.set_turns_remaining(
			_objective_tracker.get_turns_remaining())
	_objective_refreshing = false

## Player override from VictoryProgressPanel — route through the tracker.
## A programmatic StepperControl.setup() re-emits value_changed; that echo
## carries the value the tracker already holds, so it is a no-op. Only refresh
## when the tracker state actually changed — this breaks the cross-frame
## setup→signal→refresh→rebuild loop at its semantic root.
func _on_objective_progress_input(_condition_id: String, value) -> void:
	if _objective_tracker == null:
		return
	var before: String = JSON.stringify(_objective_tracker.get_panel_conditions())
	_objective_tracker.apply_panel_input(value)
	var after: String = JSON.stringify(_objective_tracker.get_panel_conditions())
	if before == after:
		return  # echo from programmatic setup — no real change, do not rebuild
	_refresh_objective_panel()

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
	_set_phase_instruction(0, "Reaction Roll",
		"Roll 1D6 for each crew figure. A figure that rolls ≤ its Reactions acts in Quick Actions; the rest act in Slow Actions.")
	_surface_phase_component(reaction_dice_panel)
	if right_tabs: right_tabs.current_tab = 1 # Tools tab — dice needed
	var roll_button := Button.new()
	roll_button.text = "Roll Reactions"
	roll_button.pressed.connect(_on_roll_reactions_pressed)
	action_buttons.add_child(roll_button)

func _show_quick_actions_ui() -> void:
	## QUICK ACTIONS — surface ActivationTrackerPanel for crew checklist
	_clear_action_buttons()
	_set_phase_instruction(1, "Quick Actions",
		"Crew who passed their reaction roll act now. Move and act each on the table, then mark them done.")
	_surface_phase_component(activation_tracker)
	_log_message(
		"Quick Actions — crew who passed reactions act now.",
		UIColors.COLOR_CYAN)
	_inject_psionic_action_button()
	var done_button := Button.new()
	done_button.text = "All Quick Actions Done"
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

func _show_enemy_actions_ui() -> void:
	## ENEMY ACTIONS — tier-aware display with contextual enemy info
	_clear_action_buttons()
	# At FULL_ORACLE tier, surface EnemyIntentPanel with AI oracle.
	if tier_controller and tier_controller.current_tier >= 2:
		# F8 fix: enemy_intent_panel can be invalid by combat — it is the one
		# phase component freed during the SETUP->COMBAT rebuild (the others
		# survive). Passing a freed ref to the TYPED _surface_phase_component(
		# component: Control) param fails the call-boundary type check and ABORTS
		# this method, so the "Enemy Actions Done" button below never builds ->
		# the Enemy Actions phase soft-locks (and the FULL_ORACLE oracle, the
		# whole point of the tier, silently vanishes). Recreate if invalid,
		# mirroring the line ~2009 recreate-if-null pattern.
		if not is_instance_valid(enemy_intent_panel):
			enemy_intent_panel = _get_res("enemy_intent").new()
			enemy_intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enemy_intent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if phase_content:
				phase_content.add_child(enemy_intent_panel)
		if is_instance_valid(enemy_intent_panel):
			_surface_phase_component(enemy_intent_panel)
		if right_tabs: right_tabs.current_tab = 2
	elif not _battle_context.is_empty():
		# ASSISTED tier: show structured enemy action card
		var enemy_card: Control = _build_enemy_action_content()
		_surface_custom_phase_content(enemy_card)
		if right_tabs: right_tabs.current_tab = 2
	else:
		_surface_phase_component(null)
		if right_tabs: right_tabs.current_tab = 1
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	var enemy_name: String = ef.get("type", "enemies")
	_set_phase_instruction(2, "Enemy Actions",
		"Resolve %s actions on the table — move each toward its target per its AI, and fire if in range." % enemy_name)
	_log_message(
		"Enemy Actions — resolve %s actions on the table." % enemy_name,
		UIColors.COLOR_RED)
	var done_button := Button.new()
	done_button.text = "Enemy Actions Done"
	done_button.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

func _show_slow_actions_ui() -> void:
	## SLOW ACTIONS — surface ActivationTrackerPanel for remaining crew
	_clear_action_buttons()
	_set_phase_instruction(3, "Slow Actions",
		"Your remaining crew act now. Move and act each on the table, then mark them done.")
	_surface_phase_component(activation_tracker)
	_log_message(
		"Slow Actions — remaining crew act now.",
		UIColors.COLOR_CYAN)
	_inject_psionic_action_button()
	var done_button := Button.new()
	done_button.text = "All Slow Actions Done"
	done_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(done_button)

## ── Psionic Action Helpers (Compendium pp.19-22) ────────────────────────

func _inject_psionic_action_button() -> void:
	## Add a "Psionic Action" button if DLC enabled and crew has a psionic member.
	var dlc = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		return
	var psi_char: Dictionary = _find_psionic_crew_member()
	if psi_char.is_empty():
		return
	var psi_btn := Button.new()
	psi_btn.text = "Psionic Action (%s)" % psi_char.get("character_name",
		psi_char.get("name", "Psionic"))
	psi_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	psi_btn.add_theme_color_override("font_color", UIColors.COLOR_FOCUS)
	psi_btn.pressed.connect(_on_psionic_action_pressed.bind(psi_char))
	if action_buttons:
		action_buttons.add_child(psi_btn)

func _find_psionic_crew_member() -> Dictionary:
	## Scan battle context crew for a character with psionic powers.
	var crew: Array = _battle_context.get("crew_participants", [])
	if crew.is_empty():
		# Fallback: try crew_units
		for unit in crew_units:
			var orig = unit.original_data if "original_data" in unit else {}
			if orig is Dictionary and not orig.get("psionic_powers", []).is_empty():
				return orig
		return {}
	for member in crew:
		var powers: Array = []
		if member is Dictionary:
			powers = member.get("psionic_powers", [])
			if powers.is_empty():
				var pp: String = member.get("psionic_power", "")
				if pp != "":
					powers = [pp]
		elif "psionic_powers" in member:
			powers = member.psionic_powers
		if not powers.is_empty():
			var result: Dictionary = {}
			if member is Dictionary:
				result = member
			else:
				result = {"character_name": member.character_name if "character_name" in member else "Psionic",
					"psionic_powers": powers,
					"psionic_power_enhanced": member.psionic_power_enhanced if "psionic_power_enhanced" in member else false,
					"species_id": member.species_id if "species_id" in member else ""}
			return result
	return {}

func _on_psionic_action_pressed(psi_char: Dictionary) -> void:
	## Show psionic action instructions and increment usage counter.
	_psionic_uses += 1
	var card: Control = _build_psionic_action_card(psi_char)
	_surface_custom_phase_content(card)
	var char_name: String = psi_char.get("character_name",
		psi_char.get("name", "Psionic"))
	_log_message(
		"PSIONIC ACTION — %s uses psionic power (use #%d this battle)" % [
			char_name, _psionic_uses],
		UIColors.COLOR_FOCUS)

func _build_psionic_action_card(psi_char: Dictionary) -> Control:
	## Build companion text instructions for a psionic action (Compendium pp.20-22).
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var char_name: String = psi_char.get("character_name",
		psi_char.get("name", "Psionic"))
	var powers: Array = psi_char.get("psionic_powers", [])
	var enhanced: bool = psi_char.get("psionic_power_enhanced", false)
	var species_id: String = psi_char.get("species_id", "")

	# Title
	var title := Label.new()
	title.text = "PSIONIC ACTION — %s" % char_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UIColors.COLOR_FOCUS)
	vbox.add_child(title)

	# Load power data
	if _psionic_powers_json.is_empty():
		var file := FileAccess.open("res://data/psionic_powers.json", FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_psionic_powers_json = json.data

	# Power descriptions
	for power_id in powers:
		var pdata: Dictionary = _psionic_powers_json.get(power_id, {})
		var pname: String = pdata.get("name", power_id.capitalize())
		var pdesc: String = pdata.get("description", "")

		var power_lbl := RichTextLabel.new()
		power_lbl.bbcode_enabled = true
		power_lbl.fit_content = true
		power_lbl.scroll_active = false
		var tags: Array[String] = []
		if pdata.get("affects_robotic_targets", false):
			tags.append("[color=#808080]Robotic OK[/color]")
		if pdata.get("target_self", false):
			tags.append("[color=#808080]Self OK[/color]")
		if pdata.get("persists", false):
			tags.append("[color=#D97706]Persists[/color]")
		var tag_str: String = (" — " + " | ".join(tags)) if not tags.is_empty() else ""
		power_lbl.text = "[color=#4FC3F7][b]%s[/b][/color]%s\n%s" % [pname, tag_str, pdesc]
		vbox.add_child(power_lbl)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Projection roll instructions
	var proj := Label.new()
	proj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var proj_text := "PROJECTION: Roll 2D6 for range (inches)."
	if enhanced:
		proj_text += " +1D6 Enhanced bonus."
	proj.text = proj_text
	proj.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(proj)

	# Strain reminder
	var strain := Label.new()
	strain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if species_id.to_lower() == "swift":
		strain.text = "STRAIN (Swift): Roll extra 1D6. Stunned on 5-6, power always succeeds."
	else:
		strain.text = "STRAIN: If out of range, roll extra 1D6. 4-5: Stunned + power works. 6: Stunned + power FAILS."
	strain.add_theme_color_override("font_color", UIColors.COLOR_WARNING)
	vbox.add_child(strain)

	# Targeting rules (Compendium p.22)
	var target_note := Label.new()
	target_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_note.text = "TARGETING: Psionics see through friendly/hostile figures. Darkness, fog, and smoke still block targeting."
	target_note.add_theme_font_size_override("font_size", 12)
	target_note.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(target_note)

	# Weapon restriction note
	var weapon_note := Label.new()
	weapon_note.text = "WEAPONS: Psionics can only use Pistol or Melee weapons."
	weapon_note.add_theme_font_size_override("font_size", 12)
	weapon_note.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(weapon_note)

	# Dismiss button
	var dismiss := Button.new()
	dismiss.text = "Done with Psionic Action"
	dismiss.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	dismiss.pressed.connect(func():
		_surface_phase_component(activation_tracker))
	vbox.add_child(dismiss)

	return vbox

func _show_end_phase_ui() -> void:
	## END PHASE — show end-of-round checklist with condition-specific steps
	_clear_action_buttons()
	if not _battle_context.is_empty() and not _is_bug_hunt_mode:
		# ASSISTED+: structured end-of-round checklist
		var checklist: Control = _build_end_phase_checklist()
		_surface_custom_phase_content(checklist)
	elif not _is_bug_hunt_mode and tier_controller and tier_controller.current_tier >= 1:
		# Fallback: morale tracker only
		_surface_phase_component(morale_tracker)
	else:
		_surface_phase_component(
			victory_progress if is_instance_valid(victory_progress) else null)
	# Deployment-condition end-of-round prompts (Core Rules p.88) — the
	# rolls players forget most (Brief Engagement / Delayed / Poor
	# Visibility). Their DESCRIPTION goes on the full-width phase banner,
	# NOT the action row: a wrapping Label in the HFlowContainer button row
	# collapses to ~1px and char-wraps vertically (the autowrap-in-HFlow
	# trap, caught in the 2026-07-03 portrait pass). Only the Roll chip
	# (a Button, which sizes fine in the HFlow) goes in the action row.
	var round_prompts: Array = BattleFlowGuideClass.build_round_end_prompts(
		_active_condition_id())
	var banner_lines: Array[String] = [
		"Run the end-of-round checklist on the table: morale, any battle event, then the victory check."]
	for prompt in round_prompts:
		banner_lines.append("⚠ %s" % str(prompt.get("text", "")))
	_set_phase_instruction(4, "End Phase", "\n".join(banner_lines))
	for prompt in round_prompts:
		var roll_chip := Button.new()
		roll_chip.text = "Roll %s (Dice drawer)" % str(prompt.get("roll", ""))
		roll_chip.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		roll_chip.add_theme_font_size_override("font_size", _scaled_font(12))
		roll_chip.pressed.connect(func() -> void: _open_drawer("dice"))
		action_buttons.add_child(roll_chip)

	var advance_button := Button.new()
	advance_button.text = "Next Round"
	advance_button.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	advance_button.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(advance_button)

# ============================================================================
# SESSION 48: PHASE-DRIVEN CONTEXTUAL CONTENT
# ============================================================================

func _show_battle_briefing() -> void:
	## Show battle briefing card as initial PhaseContent at combat start.
	## Replaced by Reaction Roll UI when player taps "Next Phase".
	_clear_action_buttons()
	var briefing: Control = _build_battle_briefing_content()
	_surface_custom_phase_content(briefing)
	_log_message("Battle briefing — review and press Next Phase",
		UIColors.COLOR_AMBER)
	var proceed_btn := Button.new()
	proceed_btn.text = "Begin Round 1"
	proceed_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	proceed_btn.pressed.connect(_on_advance_phase_pressed)
	action_buttons.add_child(proceed_btn)

func _build_battle_briefing_content() -> Control:
	## Build a compact briefing card from _battle_context data.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_color_override(
		"default_color", UIColors.COLOR_TEXT_PRIMARY)

	var lines: Array[String] = []

	# Objective — tolerate both a Dict {name, victory_condition} and a bare
	# String objective id (the campaign context stores a String; assigning
	# it to a Dict-typed var crashed combat start — 2026-07-03 walk).
	var obj_raw: Variant = _battle_context.get("mission_objective", {})
	var obj_name: String = ""
	var obj_vc: String = ""
	if obj_raw is Dictionary:
		obj_name = str(obj_raw.get("name", ""))
		obj_vc = str(obj_raw.get("victory_condition", ""))
	elif obj_raw is String:
		obj_name = obj_raw
	if obj_name != "":
		lines.append("[b]OBJECTIVE:[/b] %s" % obj_name)
		if obj_vc != "":
			lines.append("  %s" % obj_vc)

	# Rival attack type (instead of objective for rival battles) — same
	# String-or-Dict tolerance (mission_data["rival_attack_type"] is a String).
	var rival_raw: Variant = _battle_context.get("rival_attack_type", {})
	if rival_raw is Dictionary and rival_raw.get("type", "") != "":
		lines.append(
			"[b]RIVAL ATTACK:[/b] %s — %s" % [
				rival_raw.get("type", ""), rival_raw.get("description", "")])
	elif rival_raw is String and rival_raw != "":
		lines.append("[b]RIVAL ATTACK:[/b] %s" % rival_raw)

	# Deployment condition
	var deploy: Dictionary = _battle_context.get("deployment", {})
	var cond_id: String = deploy.get("condition_id", "NO_CONDITION")
	if cond_id != "NO_CONDITION" and cond_id != "":
		lines.append(
			"[b]CONDITION:[/b] %s" % deploy.get(
				"condition_title", cond_id))
		var desc: String = deploy.get("condition_description", "")
		if not desc.is_empty():
			lines.append("  %s" % desc)

	# Enemy force
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	if not ef.is_empty() and ef.get("type", "") != "":
		var ai_code: String = str(ef.get("ai", "A"))
		var ai_desc: String = AI_DESCRIPTIONS.get(
			ai_code, "Unknown AI")
		lines.append(
			"[b]ENEMY:[/b] %s x%d | AI: %s" % [
				ef.get("type", "Unknown"),
				ef.get("count", 0), ai_desc])
		lines.append(
			"  Speed: %s | Combat: +%s | Tough: %s | Panic: %s" % [
				str(ef.get("speed", "?")),
				str(ef.get("combat_skill", "?")),
				str(ef.get("toughness", "?")),
				str(ef.get("panic", "?"))])
		# Special rules in amber
		var rules: Array = ef.get("special_rules", [])
		for rule in rules:
			var rule_str: String = str(rule)
			if not rule_str.is_empty():
				lines.append(
					"  [color=#D97706]%s[/color]" % rule_str)

	# Seize Initiative result
	var seize: Dictionary = _battle_context.get(
		"seize_initiative_result", {})
	if not seize.is_empty():
		var seized: bool = seize.get("success", false)
		var total: int = seize.get("roll_total", 0)
		if seized:
			lines.append(
				"[b]INITIATIVE:[/b] [color=#10B981]SEIZED[/color]"
				+ " (rolled %d) — crew may Move or Fire (natural 6 only)" % total)
		else:
			if seize.get("cannot_seize", false):
				lines.append(
					"[b]INITIATIVE:[/b] Cannot seize (enemy rule)")
			else:
				lines.append(
					"[b]INITIATIVE:[/b] Not seized (rolled %d, needed 10+)" % total)

	# Notable sight
	var sight: Dictionary = _battle_context.get("notable_sight", {})
	if not sight.is_empty() and sight.get("type", "NOTHING") != "NOTHING":
		lines.append(
			"[b]NOTABLE SIGHT:[/b] %s" % sight.get("effect",
				sight.get("description", "")))

	if lines.is_empty():
		lines.append("[i]No battle data available — set up your table manually.[/i]")

	rtl.text = "\n".join(lines)
	vbox.add_child(rtl)
	return vbox

func _build_enemy_action_content() -> Control:
	## Build structured enemy action card for ENEMY_ACTIONS phase.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_color_override(
		"default_color", UIColors.COLOR_TEXT_PRIMARY)

	var lines: Array[String] = []
	var ef: Dictionary = _battle_context.get("enemy_force", {})

	if not ef.is_empty() and ef.get("type", "") != "":
		var ai_code: String = str(ef.get("ai", "A"))
		var ai_desc: String = AI_DESCRIPTIONS.get(
			ai_code, "Unknown AI type")

		lines.append("[b]%s[/b] — %s" % [
			ef.get("type", "Unknown"), ai_desc])
		lines.append(
			"Speed: %s\" | Combat: +%s | Tough: %s | Panic: %s" % [
				str(ef.get("speed", "?")),
				str(ef.get("combat_skill", "?")),
				str(ef.get("toughness", "?")),
				str(ef.get("panic", "?"))])

		# Special rules in amber
		var rules: Array = ef.get("special_rules", [])
		if not rules.is_empty():
			lines.append("")
			lines.append("[b]Special Rules:[/b]")
			for rule in rules:
				var rule_str: String = str(rule)
				if not rule_str.is_empty():
					lines.append(
						"  [color=#D97706]%s[/color]" % rule_str)
	else:
		lines.append(
			"Move each enemy toward closest crew, shoot if in range.")

	# Check deployment condition effects on enemy actions
	var deploy: Dictionary = _battle_context.get("deployment", {})
	var cond_id: String = deploy.get("condition_id", "")
	var round_num: int = round_tracker.get_current_round() if round_tracker and round_tracker.has_method("get_current_round") else 1
	if cond_id == "SURPRISE_ENCOUNTER" and round_num == 1:
		lines.append("")
		lines.append(
			"[color=#10B981][b]SURPRISE:[/b] Enemies cannot act this round![/color]")
	elif cond_id == "BITTER_STRUGGLE":
		lines.append("")
		lines.append(
			"[color=#D97706]Bitter Struggle: Enemy Morale +1[/color]")

	rtl.text = "\n".join(lines)
	vbox.add_child(rtl)
	return vbox

func _build_end_phase_checklist() -> Control:
	## Build a numbered end-of-round checklist with condition-specific steps.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var round_num: int = round_tracker.get_current_round() if round_tracker and round_tracker.has_method("get_current_round") else 1
	var deploy: Dictionary = _battle_context.get("deployment", {})
	var cond_id: String = deploy.get("condition_id", "")

	# Title
	var title := Label.new()
	title.text = "END OF ROUND %d" % round_num
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(title)

	var step_num: int = 0

	# Step: Morale check (always)
	step_num += 1
	vbox.add_child(_make_checklist_step(
		step_num, "Morale check — roll 1D6 per casualty this round, "
		+ "Bail Range removes enemies"))

	# Step: Deployment condition round checks
	if cond_id == "BRIEF_ENGAGEMENT":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Brief Engagement: Roll 2D6 — on %d or less, battle ends" % round_num))

	if cond_id == "DELAYED" and round_num >= 2:
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Delayed crew: Roll 1D6 — on %d or less, they arrive at your edge" % round_num))

	if cond_id == "TOXIC_ENVIRONMENT":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Toxic Environment: Stunned units roll 1D6+Savvy, below 4 = casualty"))

	if cond_id == "POOR_VISIBILITY":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Reroll visibility: 1D6+8\" maximum range for next round"))

	# Step: Battle Event (rounds 2 and 4 only)
	if round_num == 2 or round_num == 4:
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Battle Event: Roll D100 (Core Rules p.116)"))

	# Step: Victory check (always)
	step_num += 1
	vbox.add_child(_make_checklist_step(
		step_num,
		"Victory check — all enemies eliminated or bailed?"))

	return vbox

func _make_checklist_step(number: int, text: String) -> HBoxContainer:
	## Create a single checklist step with checkbox + label.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var check := CheckBox.new()
	check.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN)
	hbox.add_child(check)

	var lbl := Label.new()
	lbl.text = "%d. %s" % [number, text]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)

	return hbox

func _surface_custom_phase_content(content: Control) -> void:
	## Surface a dynamically-built Control in the phase content area.
	## Hides standard phase components, adds custom content as child.
	_surface_phase_component(null) # Hide all standard components
	# Remove any previous custom content
	for child in phase_content.get_children():
		if child.name.begins_with("_custom_"):
			child.queue_free()
	# Add new custom content
	content.name = "_custom_phase_content"
	phase_content.add_child(content)

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
	## Advance to next phase via round tracker (only valid during COMBAT stage)
	if current_stage != BattleStage.COMBAT:
		return  # Ignore phase advance clicks during setup/deployment
	if round_tracker and round_tracker.has_method("advance_phase"):
		round_tracker.advance_phase()
	else:
		push_warning("TacticalBattleUI: No round tracker — cannot advance phase")

## Initialize tactical battle with crew and enemies

func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void:
	## Initialize the tactical battle
	_battle_initialized = true
	_log_message("Initializing tactical battle...", UIColors.COLOR_CYAN)

	# Update title header with mission name. The objective fallback tolerates
	# both a String id and a Dict {name,...} (Bug Hunt stores a Dict, and
	# has no title, so the old String-typed fallback crashed here — same
	# String-or-Dict family as the combat-start fixes, 2026-07-03).
	var md: Dictionary = mission_data if mission_data is Dictionary else {}
	if title_label:
		var mission_title: String = str(md.get("title", ""))
		if mission_title == "":
			var obj_val: Variant = md.get("objective", "")
			if obj_val is Dictionary:
				mission_title = str(obj_val.get("name", "Tactical Companion"))
			elif obj_val is String and obj_val != "":
				mission_title = obj_val
			else:
				mission_title = "Tactical Companion"
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

	# Ensure BattleEventsSystem exists for event generation (rounds 2 & 4)
	if not _battle_events_system:
		var BES = load("res://src/core/battle/BattleEventsSystem.gd")
		if BES:
			_battle_events_system = BES.new()
			_battle_events_system.initialize_battle()
			# WIRING FIX: connect terrain visual + hazard signals to map overlay
			if _battle_events_system.has_signal("terrain_effect_triggered") \
					and not _battle_events_system.terrain_effect_triggered.is_connected(_on_battle_terrain_effect):
				_battle_events_system.terrain_effect_triggered.connect(_on_battle_terrain_effect)
			if _battle_events_system.has_signal("environmental_hazard_activated") \
					and not _battle_events_system.environmental_hazard_activated.is_connected(_on_battle_hazard_activated):
				_battle_events_system.environmental_hazard_activated.connect(_on_battle_hazard_activated)

	# Populate battlefield setup tab (data only, no stage change)
	_stored_mission_data = mission_data
	_populate_setup_tab(mission_data)

	# Detect Bug Hunt mode from mission context
	var mission_dict: Dictionary = mission_data if mission_data is Dictionary else {}

	# UX streamline: If tier was pre-selected in PreBattleUI, skip the
	# TIER_SELECT overlay and go straight to COMBAT stage.
	if mission_dict.has("selected_tier"):
		var pre_tier: int = mission_dict.get("selected_tier", 0)
		_on_tier_selected(pre_tier)
		# Skip SETUP/DEPLOYMENT — player already reviewed everything in PreBattleUI
		_on_auto_deploy_clicked()
		_apply_stage_visibility(BattleStage.COMBAT)
		return

	# NOTE: Deployment phase starts AFTER tier selection completes
	# (see _on_tier_selected → _apply_stage_visibility(SETUP) → checklist → DEPLOYMENT)
	var battle_mode: String = mission_dict.get("battle_mode", "")
	_battle_mode_id = battle_mode
	_is_bug_hunt_mode = battle_mode == "bug_hunt"
	_is_planetfall_mode = battle_mode == "planetfall"
	if _is_bug_hunt_mode:
		_log_message("Bug Hunt mode — morale hidden, contact markers active", UIColors.COLOR_AMBER)
	elif _is_planetfall_mode:
		_log_message("Planetfall mode — colony mission, contacts system active", UIColors.COLOR_CYAN)

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

func _create_character_cards(_crew_members: Array) -> void:
	## Phase 2: the Crew and Enemy SlideOverDrawers ARE the per-figure battle
	## tracker (plan iters 1/2). One CharacterStatusCard per TacticalUnit goes
	## into each drawer body; the TacticalUnit is the single source of truth
	## (CLAUDE.md SSOT) and the card is a view that signals mutations back up.
	## The legacy `crew_content` (= crew_rail) parenting is gone — the rail is
	## the glance summary, the drawer is the detail (built from `crew_units`/
	## `enemy_units`, the normalized model, NOT the raw `crew_members` source).
	for card in character_cards:
		if is_instance_valid(card):
			card.queue_free()
	character_cards.clear()
	_unit_card_by_id.clear()

	_populate_unit_drawer(_drawer_bodies.get("crew"), crew_units, true)
	_populate_unit_drawer(_drawer_bodies.get("enemies"), enemy_units, false)


func _unit_id(unit) -> String:
	## Stable per-battle key. TacticalUnit is RefCounted (no `extends`), so
	## get_instance_id() is unique and stable for the object's lifetime —
	## no new model field, no name-collision risk for identical enemy types.
	return str(unit.get_instance_id()) if unit else ""


func _unit_card_dict(unit) -> Dictionary:
	## Build the card/activation-tracker dict from the live TacticalUnit so
	## the view always reflects current model state (health/stun/activation),
	## never stale source data. Keys match CharacterStatusCard.set_character_data
	## and ActivationTrackerPanel.add_unit (which requires a non-empty "id").
	return {
		"id": _unit_id(unit),
		"character_name": unit.node_name,
		"name": unit.node_name,
		"combat": unit.combat_skill,
		"toughness": unit.toughness,
		"speed": unit.movement_points,
		"savvy": unit.savvy,
		"reactions": unit.reactions,
		"max_health": unit.max_health,
		"health": unit.health,
		"actions_remaining": unit.actions_remaining,
		"stun_markers": unit.stun_markers,
		"is_activated": unit.is_activated,
	}


func _populate_unit_drawer(body, units: Array, is_crew: bool) -> void:
	## Rebuild one drawer body: a CharacterStatusCard + a "Mark Down" eliminate
	## button per TacticalUnit, signals wired card -> model -> log/trackers.
	if body == null or not is_instance_valid(body):
		return
	for c in body.get_children():
		c.queue_free()

	var tier: int = tier_controller.current_tier if tier_controller else 0

	# FULL_ORACLE: EnemyIntentPanel is an AI-intent layer ON TOP of the
	# per-figure enemy tracker (plan iter 1), not a replacement. Reparent it
	# to the top of the enemy drawer body.
	if not is_crew and tier >= 2 and enemy_intent_panel \
			and is_instance_valid(enemy_intent_panel):
		var prev := enemy_intent_panel.get_parent()
		if prev and prev != body:
			prev.remove_child(enemy_intent_panel)
		if enemy_intent_panel.get_parent() == null:
			body.add_child(enemy_intent_panel)
			body.move_child(enemy_intent_panel, 0)

	# ActivationTrackerPanel mirrors the same figures (Tracking drawer). Clear
	# then re-add so a rebuild never double-registers (add_unit warns on dup).
	if activation_tracker and is_instance_valid(activation_tracker) \
			and activation_tracker.has_method("clear_all_units") and is_crew:
		activation_tracker.clear_all_units()

	for unit in units:
		var data: Dictionary = _unit_card_dict(unit)

		# Register with the Tracking drawer's ActivationTrackerPanel so its
		# crew/enemy sections stay in lock-step with these figures (alive OR
		# down — a down figure still reads as defeated in the tracker).
		if activation_tracker and is_instance_valid(activation_tracker) \
				and activation_tracker.has_method("add_unit"):
			activation_tracker.add_unit(data, is_crew)

		# DOWN figures collapse to a compact one-line ledger row (F9). A defeated
		# figure needs no stat block or Stun/Dmg/Aim/Snap/Mark-Down controls, and
		# keeping FULL-height cards for the dead inflated the drawer past the
		# viewport — the last LIVE enemy's Mark-Down button fell off the bottom
		# with no way to touch-scroll to it (found on-device, 2026-07-05).
		if unit.is_dead:
			var down_row := _build_downed_unit_row(unit)
			body.add_child(down_row)
			_unit_card_by_id[_unit_id(unit)] = down_row
			continue

		var card: PanelContainer = _get_res("character_status_card").instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(card)
		card.set_character_data(data)
		card.set_display_tier(tier)
		if card.has_method("set_activated"):
			card.set_activated(unit.is_activated)
		# Host-side overflow guard (CharacterStatusCard reused unchanged):
		# autowrap its status/stats labels so a long status line
		# ("Stunned x1 (Move OR Combat, not both) | Actions: 2") wraps inside
		# the drawer column instead of forcing a horizontal scrollbar.
		for lbl_name in ["status_label", "stats_label"]:
			if lbl_name in card and card.get(lbl_name) is Label:
				var lbl: Label = card.get(lbl_name)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.custom_minimum_size.x = 0.0

		# Card (view) -> model + log + trackers. bind() appends the unit so
		# each card mutates exactly its own TacticalUnit (SSOT).
		card.damage_taken.connect(_on_card_damage.bind(unit, is_crew))
		card.stun_marked.connect(_on_card_stun.bind(unit))
		card.action_used.connect(_on_card_action.bind(unit))

		# Explicit eliminate path (instant kill: die = 6 or score >= Toughness,
		# Core Rules pp.116-118) — no damage ticking required.
		var down_btn := Button.new()
		down_btn.text = "✖ Mark Down"
		down_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
		var down_style := StyleBoxFlat.new()
		down_style.bg_color = UIColors.COLOR_DANGER
		down_style.set_corner_radius_all(6)
		down_btn.add_theme_stylebox_override("normal", down_style)
		down_btn.add_theme_stylebox_override("hover", down_style)
		down_btn.add_theme_stylebox_override("pressed", down_style)
		down_btn.pressed.connect(_confirm_mark_casualty.bind(unit, is_crew))
		body.add_child(down_btn)

		character_cards.append(card)
		_unit_card_by_id[_unit_id(unit)] = card


func _build_downed_unit_row(unit) -> PanelContainer:
	## Compact one-line ledger entry for a DOWN figure (F9). Keeps the casualty
	## visible for the post-battle reckoning without the full card's height, so
	## a full roster + several casualties still fits the drawer viewport.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_INPUT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(UIColors.SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	panel.add_child(row)
	var skull := Label.new()
	skull.text = "☠"
	skull.add_theme_color_override("font_color", UIColors.COLOR_DANGER)
	row.add_child(skull)
	var name_lbl := Label.new()
	name_lbl.text = unit.node_name
	name_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var down_lbl := Label.new()
	down_lbl.text = "DOWN  0/%d" % unit.max_health
	down_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_DISABLED)
	down_lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	row.add_child(down_lbl)
	return panel


func _on_card_damage(char_name: String, amount: int, unit, is_crew: bool) -> void:
	## CharacterStatusCard "Damage" -> model. Health 0 = casualty (the card
	## already updated its own display; we only sync model/log/trackers/rail).
	_capture_undo_snapshot(unit, "Damage", is_crew)
	unit.health = max(0, unit.health - amount)
	if unified_log:
		unified_log.log_action(char_name, "took %d damage" % amount)
	if unit.health <= 0 and not unit.is_dead:
		_mark_casualty(unit, is_crew)
	else:
		_refresh_unit_rails()


func _on_card_stun(char_name: String, unit) -> void:
	## CharacterStatusCard "Stun" -> model. Stackable; persists across rounds
	## (Core Rules: removed only after the stunned figure acts).
	_capture_undo_snapshot(unit, "Stun")
	unit.stun_markers += 1
	if unified_log:
		unified_log.log_action(char_name, "Stunned (x%d)" % unit.stun_markers)
	_refresh_unit_rails()


func _on_card_action(char_name: String, action_type: String, unit) -> void:
	## Only the generic Use-Action consumes the once-per-round activation
	## (Core Rules p.114). Aim/Snap toggles are tactical state, not activation.
	if action_type == "generic_action":
		_capture_undo_snapshot(unit, "Action")
		unit.is_activated = true
		if activation_tracker and is_instance_valid(activation_tracker) \
				and activation_tracker.has_method("set_unit_activated"):
			activation_tracker.set_unit_activated(_unit_id(unit), true)
	if unified_log:
		unified_log.log_action(char_name, action_type)
	_refresh_unit_rails()


func _mark_casualty(unit, is_crew: bool, feed_morale: bool = true) -> void:
	## Single casualty chokepoint (idempotent). Model -> trackers -> the
	## iter-3 morale bridge (enemy casualties this round feed End Phase
	## Morale, Core Rules pp.114-115). Player figures never feed enemy morale.
	## feed_morale=false when REMOVING a Bailed enemy (a bail is not a kill,
	## so it must not re-inflate casualties_this_round).
	if unit == null or unit.is_dead:
		return
	unit.is_dead = true
	unit.health = 0
	if unified_log:
		unified_log.log_action(unit.node_name, "is DOWN")
	if activation_tracker and is_instance_valid(activation_tracker) \
			and activation_tracker.has_method("set_unit_defeated"):
		activation_tracker.set_unit_defeated(_unit_id(unit), true)
	if feed_morale and not is_crew and morale_tracker \
			and is_instance_valid(morale_tracker):
		# casualties_this_round drives perform_morale_check() at End Phase.
		if morale_tracker.has_method("add_casualty"):
			morale_tracker.add_casualty()
		elif "casualties_this_round" in morale_tracker:
			morale_tracker.casualties_this_round += 1
	_refresh_unit_rails()
	_queue_drawer_repopulate()


## ── Wave 3 battle-UX: casualty confirm + single-level undo ───────────────

func _confirm_mark_casualty(unit, is_crew: bool) -> void:
	## Guard the irreversible EXPLICIT elimination ("Mark Down" button) with a
	## confirmation. Damage-driven casualties (_on_card_damage) and automatic
	## Bail removals stay un-prompted — those already follow a recorded action.
	if unit == null or unit.is_dead:
		return
	_capture_undo_snapshot(unit, "Mark Down", is_crew)
	var dlg := ConfirmationDialog.new()
	dlg.title = "Confirm Casualty"
	dlg.dialog_text = "Mark %s as DOWN?\n\nThis removes the figure from the battle." % unit.node_name
	dlg.ok_button_text = "Mark Down"
	add_child(dlg)
	dlg.confirmed.connect(func() -> void: _mark_casualty(unit, is_crew))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()


## Snapshot one unit's mutable battle state so the NEXT action can be undone.
## Single-level: a new capture overwrites the previous. is_crew lets undo also
## reverse the End-Phase-Morale casualty count when an enemy kill is undone.
func _capture_undo_snapshot(unit, label: String, is_crew: bool = false) -> void:
	if unit == null:
		return
	_undo_snapshot = {
		"unit": unit,
		"is_crew": is_crew,
		"health": unit.health,
		"stun_markers": unit.stun_markers,
		"is_activated": unit.is_activated,
		"is_dead": unit.is_dead,
		"actions_remaining": unit.actions_remaining,
		"label": label,
	}
	_refresh_undo_button()


func _undo_last_mutation() -> void:
	if _undo_snapshot.is_empty():
		return
	var unit = _undo_snapshot.get("unit")
	if unit == null:
		_undo_snapshot = {}
		_refresh_undo_button()
		return
	var was_dead: bool = bool(_undo_snapshot.get("is_dead", unit.is_dead))
	unit.health = int(_undo_snapshot.get("health", unit.health))
	unit.stun_markers = int(_undo_snapshot.get("stun_markers", unit.stun_markers))
	unit.is_activated = bool(_undo_snapshot.get("is_activated", unit.is_activated))
	unit.actions_remaining = int(_undo_snapshot.get("actions_remaining", unit.actions_remaining))
	# Reviving from a just-applied casualty: un-count it for End Phase Morale.
	# (unit.is_dead here is still the POST-mutation value; restored just below.)
	if unit.is_dead and not was_dead and not bool(_undo_snapshot.get("is_crew", false)) \
			and morale_tracker and is_instance_valid(morale_tracker) \
			and "casualties_this_round" in morale_tracker:
		morale_tracker.casualties_this_round = max(0, morale_tracker.casualties_this_round - 1)
	unit.is_dead = was_dead
	if activation_tracker and is_instance_valid(activation_tracker):
		if activation_tracker.has_method("set_unit_defeated"):
			activation_tracker.set_unit_defeated(_unit_id(unit), unit.is_dead)
		if activation_tracker.has_method("set_unit_activated"):
			activation_tracker.set_unit_activated(_unit_id(unit), unit.is_activated)
	if unified_log:
		unified_log.log_action(unit.node_name,
			"Undo: %s" % str(_undo_snapshot.get("label", "last action")))
	_undo_snapshot = {}
	_refresh_unit_rails()
	_queue_drawer_repopulate()
	_refresh_undo_button()


func _setup_undo_button() -> void:
	## Add the Undo button to the ActionBar (sibling of EndTurnButton), mirroring
	## the Stars button. Disabled until a mutation is captured.
	if not is_inside_tree() or _undo_button != null:
		return
	var action_bar: Container = end_turn_button.get_parent() if end_turn_button else null
	if not action_bar:
		return
	_undo_button = Button.new()
	_undo_button.text = "↶ Undo"
	_undo_button.tooltip_text = "Undo the last damage / stun / action / casualty you recorded"
	_undo_button.custom_minimum_size = Vector2(96, _touch_h())
	_undo_button.disabled = true
	_undo_button.pressed.connect(_on_undo_button_pressed)
	action_bar.add_child(_undo_button)
	action_bar.move_child(_undo_button, 0)  # Leftmost in the bar


func _on_undo_button_pressed() -> void:
	_undo_last_mutation()


func _refresh_undo_button() -> void:
	if _undo_button == null:
		return
	var has_snap: bool = not _undo_snapshot.is_empty()
	_undo_button.disabled = not has_snap
	_undo_button.text = "↶ Undo %s" % str(_undo_snapshot.get("label", "")) if has_snap else "↶ Undo"


func _assign_crew_reaction_slots() -> void:
	## Core Rules p.114 Reaction Roll: roll 1D6 per crew figure. Roll <= that
	## figure's Reactions => it acts in the QUICK phase (slot 1); otherwise
	## SLOW (slot 2). Enemies never roll (always ENEMY phase, slot 3).
	var dm = get_node_or_null("/root/DiceManager")
	var q: int = 0
	var s: int = 0
	for unit in crew_units:
		if unit.is_dead:
			unit.react_slot = 0
			continue
		var d6: int = 0
		if dm and dm.has_method("roll_d6"):
			d6 = dm.roll_d6("Reaction Roll: %s" % unit.node_name)
		else:
			d6 = (randi() % 6) + 1
		if d6 <= unit.reactions:
			unit.react_slot = 1
			q += 1
		else:
			unit.react_slot = 2
			s += 1
	if unified_log:
		unified_log.log_action("Reaction Roll", "%d Quick · %d Slow" % [q, s])
	_refresh_unit_rails()


func _resolve_end_phase_morale() -> void:
	## Core Rules pp.114-115: at End Phase, if the enemy lost figures this
	## round, roll 1D6 per casualty; each within the Bail Range = 1 enemy
	## Bails (removed from play). The player never tests morale.
	## casualties_this_round is fed by _mark_casualty (the iter-3 bridge).
	if not (morale_tracker and is_instance_valid(morale_tracker)):
		return
	var cas: int = 0
	if "casualties_this_round" in morale_tracker:
		cas = morale_tracker.casualties_this_round
	if cas <= 0 or not morale_tracker.has_method("perform_morale_check"):
		return
	var result: Dictionary = morale_tracker.perform_morale_check()
	var bails: int = int(result.get("bails", 0))
	if bails <= 0:
		return
	# A Bailed enemy leaves play — remove it WITHOUT re-feeding morale.
	var removed: int = 0
	for e in enemy_units:
		if removed >= bails:
			break
		if not e.is_dead:
			_mark_casualty(e, false, false)
			removed += 1
	if unified_log and removed > 0:
		unified_log.log_morale("Bailed", removed)


func _refresh_unit_rails() -> void:
	## Rails are the glance layer — cheap to rebuild every mutation. Drawer
	## cards self-update (CharacterStatusCard._update_display), so we do NOT
	## rebuild the drawer here (would free a card mid-signal-emit).
	_rebuild_crew_rail()
	_rebuild_info_rail()


func _queue_drawer_repopulate() -> void:
	## Deferred so a card is never freed while it is mid-signal-emit
	## (e.g. damage -> casualty -> rebuild). Coalesced via a re-entrancy flag.
	if _drawer_repopulate_queued:
		return
	_drawer_repopulate_queued = true
	call_deferred("_do_drawer_repopulate")


func _do_drawer_repopulate() -> void:
	_drawer_repopulate_queued = false
	_create_character_cards([])

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

	# Journey Moment 2: the p.110 deployment procedure as three steps on
	# the EXISTING phase-instruction banner (always visible above the
	# action row — phase_content is not shown during DEPLOYMENT).
	_set_deployment_banner()

	# Add deployment-specific buttons
	var place_unit_button := Button.new()
	place_unit_button.text = "Place Unit"
	place_unit_button.pressed.connect(_on_place_unit_clicked)
	action_buttons.add_child(place_unit_button)

	var auto_deploy_button := Button.new()
	auto_deploy_button.text = "Auto Deploy"
	auto_deploy_button.pressed.connect(_on_auto_deploy_clicked)
	action_buttons.add_child(auto_deploy_button)

func _set_deployment_banner() -> void:
	## The Core Rules p.110 setup procedure, with the active deployment
	## condition's crew modifiers folded in (BattleFlowGuide, PDF-verified),
	## written onto the phase-instruction banner (the per-stage guidance
	## line the player already reads).
	if _phase_banner == null:
		_build_phase_instruction_banner()
	if _phase_banner == null:
		return
	var gs = get_node_or_null("/root/GameState")
	var contract: Dictionary = gs.get_battlefield_data() \
		if gs and gs.has_method("get_battlefield_data") else {}
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	var enemy_ai: String = str(ef.get("ai", contract.get("enemy_ai", "")))
	var steps: Array = BattleFlowGuideClass.deployment_steps(
		_active_condition_id(), enemy_ai)
	var lines: Array[String] = []
	for i in range(steps.size()):
		lines.append("%d. %s" % [i + 1, str(steps[i].get("text", ""))])
	if _phase_banner_chip:
		_phase_banner_chip.text = "DEPLOYMENT · Core Rules p.110"
	if _phase_banner_label:
		_phase_banner_label.text = "\n".join(lines)
	_phase_banner.visible = true

## Legacy _update_action_buttons_for_combat() removed — phase-specific buttons
## are now created by _show_reaction_roll_ui(), _show_quick_actions_ui(), etc.

func _clear_action_buttons() -> void:
	## Clear all per-stage action buttons. The DrawerBar (Crew/Enemies/Dice/
	## Reference/...) is a PERSISTENT toolbar (approved plan: drawer buttons
	## are always-visible glanceable affordances across every stage), so it
	## must survive the per-stage rebuilds that recreate the spine buttons.
	if not action_buttons:
		return
	for child in action_buttons.get_children():
		if child.name == "DrawerBar":
			continue
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

	# Ensure round tracker exists (may not if standalone/demo mode skipped initialize_battle)
	if not round_tracker:
		var BattleRoundTrackerClass = preload("res://src/core/battle/BattleRoundTracker.gd")
		var tracker := BattleRoundTrackerClass.new()
		tracker.name = "BattleRoundTracker"
		add_child(tracker)
		set_round_tracker(tracker)

	# Start combat via round tracker (Five Parsecs 5-phase combat)
	battle_phase = "combat"
	if round_tracker and round_tracker.has_method("start_battle"):
		round_tracker.start_battle()
	else:
		push_warning("TacticalBattleUI: Round tracker unavailable after creation attempt")

## Legacy _end_unit_turn() and _end_combat_round() removed
## Round progression now driven by BattleRoundTracker.advance_phase()

func _reset_all_unit_reactions() -> void:
	## Round reset (Core Rules p.114): each surviving figure acts once per
	## round, so activation + the reaction economy clear every round. Stun
	## markers deliberately do NOT reset — a Stun marker is removed only
	## after the stunned figure acts. ASSISTED+ also resyncs the rules
	## engines in the Tracking drawer so they stay in lock-step.
	for unit in all_units:
		if unit.health > 0:
			unit.reset_for_new_round()
	if tier_controller and tier_controller.current_tier >= 1:
		if activation_tracker and is_instance_valid(activation_tracker) \
				and activation_tracker.has_method("reset_all_activations"):
			activation_tracker.reset_all_activations()
		if reaction_dice_panel and is_instance_valid(reaction_dice_panel) \
				and reaction_dice_panel.has_method("reset_all_dice"):
			reaction_dice_panel.reset_all_dice()
		if morale_tracker and is_instance_valid(morale_tracker) \
				and morale_tracker.has_method("new_round"):
			morale_tracker.new_round()
	_log_message("All units reset for Round %d (activation + reactions)"
		% current_turn, UIColors.COLOR_CYAN)
	_refresh_unit_rails()
	_queue_drawer_repopulate()


func _on_manual_round_reset() -> void:
	## Rail "↺ Round" affordance — a tabletop player who advances their own
	## physical round just wants the digital tracker cleared to match.
	_reset_all_unit_reactions()
	if unified_log:
		unified_log.log_action("Round", "Activation manually reset")

## Legacy _check_victory_conditions() removed — VictoryProgressPanel handles this in END_PHASE

func _resolve_battle() -> void:
	## Resolve the tactical battle — transition to RESOLUTION stage.
	## Emits a rich Dictionary (not BattleResult class) so PostBattlePhase
	## has all the data it needs for loot, injuries, XP, and journal entries.
	battle_phase = "resolution"
	_apply_stage_visibility(BattleStage.RESOLUTION)

	var crew_alive_units: Array = crew_units.filter(
		func(u): return u.health > 0)
	var enemies_alive_units: Array = enemy_units.filter(
		func(u): return u.health > 0)
	var crew_alive: int = crew_alive_units.size()
	var enemies_alive: int = enemies_alive_units.size()
	var rounds: int = current_turn - 1

	var victory: bool = false
	if crew_alive > 0 and enemies_alive == 0:
		victory = true
		_log_message("Victory! All enemies defeated!",
			UIColors.COLOR_EMERALD)
		if unified_log:
			unified_log.log_victory("All enemies defeated")
	elif crew_alive == 0:
		victory = false
		_log_message("Defeat! All crew members down!",
			UIColors.COLOR_RED)
		if unified_log:
			unified_log.log_defeat("All crew members down")
	else:
		victory = crew_alive > enemies_alive
		_log_message(
			"Battle concluded after %d rounds" % rounds,
			UIColors.COLOR_AMBER)
		if unified_log:
			if victory:
				unified_log.log_victory(
					"Outnumbered enemies %d to %d" % [
						crew_alive, enemies_alive])
			else:
				unified_log.log_defeat(
					"Outnumbered by enemies %d to %d" % [
						enemies_alive, crew_alive])

	# Build casualties and injuries lists.
	# Core Rules p.122 (user-confirmed, rules-faithful): a crew figure that
	# went Out of Action ALWAYS rolls the standard post-battle Injury Table —
	# the roll itself determines dead / injured / recovered. Being downed
	# mid-battle does NOT pre-classify the figure as a confirmed casualty
	# (that forced the harsher "Roll Severity" sub-path with no "no effect"
	# outcome). So every downed crew member routes to injuries_data → the
	# Injury Table decides, not the in-battle Mark-Down button. Enemies are
	# not in this loop; they die outright in battle (they feed End-Phase
	# Morale, they do not roll the crew Injury Table).
	var casualties_data: Array = []
	var injuries_data: Array = []
	for unit in crew_units:
		if unit.health <= 0:
			injuries_data.append(unit.original_character)

	# Build defeated enemy list for loot/XP
	var defeated_enemies: Array = []
	for unit in enemy_units:
		if unit.health <= 0:
			defeated_enemies.append({
				"name": unit.node_name,
				"type": unit.enemy_type if "enemy_type" in unit \
					else "",
				"was_lieutenant": unit.is_lieutenant \
					if "is_lieutenant" in unit else false,
			})

	# Crew who participated (for XP distribution)
	var crew_participants: Array = []
	for unit in crew_units:
		if unit.original_character:
			crew_participants.append(unit.original_character)

	# Held field = victory + at least 1 crew alive at end
	var held_field: bool = victory and crew_alive > 0

	# Extract mission type flags from stored mission data
	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}

	# Objective-accurate mission success. Fixes a pre-existing latent bug:
	# PostBattlePhase reads battle_data.get("success", false) but this path
	# never set "success", so won battles cascaded as failures into pay/quests.
	# Falls back to won/held_field when there is no trackable objective.
	var obj_success: bool = victory
	var obj_id: String = ""
	var obj_met: bool = victory
	var obj_progress: Array = []
	if _objective_tracker != null and _objective_tracker.has_objective():
		obj_success = _objective_tracker.get_mission_success(
			victory, held_field)
		obj_id = _objective_tracker.get_objective_id()
		obj_met = _objective_tracker.is_complete()
		obj_progress = _objective_tracker.get_panel_conditions()

	var result_dict: Dictionary = {
		"victory": victory,
		"won": victory,  # Alias for CampaignTurnController
		"success": obj_success,  # consumed by PostBattlePhase.mission_successful
		"held_field": held_field,
		"objective_id": obj_id,
		"objective_met": obj_met,
		"objective_progress": obj_progress,
		"rounds_fought": rounds,
		"crew_casualties": casualties_data.size(),
		"crew_injuries": injuries_data.size(),
		"crew_casualties_data": casualties_data,
		"crew_injuries_data": injuries_data,
		"crew_participants": crew_participants,
		"defeated_enemies": defeated_enemies,
		"enemies_defeated_count": defeated_enemies.size(),
		"enemies_remaining": enemies_alive,
		"crew_alive": crew_alive,
		"is_red_zone": md.get("is_red_zone", false),
		"is_black_zone": md.get("is_black_zone", false),
		"is_quest_finale": md.get("is_quest_finale", false),
		"mission_source": md.get("mission_source", "opportunity"),
		"mission_type": md.get("type", ""),
		"auto_resolved": false,
		"psionic_uses": _psionic_uses,
	}

	tactical_battle_completed.emit(result_dict)

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

	# Resolver selection routed through BattleResolverRouter so No-Minis / Standard /
	# Salvage-fallback (Compendium p.116) matches the campaign auto-resolve path.
	# Previously this site lacked the Salvage fallback. _battle_mode_id keeps the
	# shared UI's Bug Hunt / Planetfall / Tactics battles on the generic resolver.
	var dlc_mgr = get_node_or_null("/root/DLCManager")
	var _md_auto: Dictionary = _stored_mission_data if _stored_mission_data is Dictionary else {}
	var _mission_type_auto: String = str(_md_auto.get("type", ""))
	var resolver_result: Dictionary = BattleResolverRouterClass.resolve(
		crew_deployed, enemies_deployed, battlefield_data,
		deployment_condition, dice_roller, dlc_mgr, _battle_mode_id, _mission_type_auto)

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

	_log_message("Battle %s!" % ("WON" if result.victory else "LOST"),
		UIColors.COLOR_EMERALD if result.victory else UIColors.COLOR_RED)

	# Objective-accurate success for the auto-resolve path. Auto-resolve is an
	# abstract sim with no per-round play, so only trust the tracker for
	# objectives derivable from rounds + enemy counts (FIGHT_OFF / survival);
	# everything else falls back to the sim outcome (no regression).
	var obj_success: bool = result.victory
	var obj_id: String = ""
	var obj_met: bool = result.victory
	var obj_progress: Array = []
	if _objective_tracker != null and _objective_tracker.has_objective():
		_objective_tracker.on_round_advanced(result.rounds_fought)
		var er: int = maxi(
			enemies_deployed.size() - enemies_defeated_count, 0)
		_objective_tracker.set_manual("enemies_remaining", er)
		obj_id = _objective_tracker.get_objective_id()
		obj_progress = _objective_tracker.get_panel_conditions()
		if _objective_tracker.is_auto_derivable():
			obj_success = _objective_tracker.is_complete()
			obj_met = obj_success
		else:
			obj_success = result.victory or held_field
			obj_met = _objective_tracker.is_complete()

	# Emit rich Dictionary (same contract as _resolve_battle)
	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}
	var auto_result_dict: Dictionary = {
		"victory": result.victory,
		"won": result.victory,
		"success": obj_success,  # consumed by PostBattlePhase.mission_successful
		"held_field": held_field,
		"objective_id": obj_id,
		"objective_met": obj_met,
		"objective_progress": obj_progress,
		"rounds_fought": result.rounds_fought,
		"crew_casualties": result.crew_casualties.size(),
		"crew_injuries": result.crew_injuries.size(),
		"crew_casualties_data": result.crew_casualties,
		"crew_injuries_data": result.crew_injuries,
		"crew_participants": crew_units.map(
			func(u): return u.original_character).filter(
			func(c): return c != null),
		"defeated_enemies": [],
		"enemies_defeated_count": enemies_defeated_count,
		"enemies_remaining": enemies_deployed.size() \
			- enemies_defeated_count,
		"crew_alive": crew_units.filter(
			func(u): return u.health > 0).size(),
		"is_red_zone": md.get("is_red_zone", false),
		"is_black_zone": md.get("is_black_zone", false),
		"is_quest_finale": md.get("is_quest_finale", false),
		"mission_source": md.get("mission_source", "opportunity"),
		"mission_type": md.get("type", ""),
		"auto_resolved": true,
		"psionic_uses": _psionic_uses,
	}
	tactical_battle_completed.emit(auto_result_dict)

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
	## Toggle deployment zone highlighting. battlefield_grid_panel IS the
	## bare BattlefieldMapView since the map-primary redesign — the old
	## GridPanel child/property lookups never matched it, so the highlight
	## silently no-opped until 2026-07-03.
	if battlefield_grid_panel \
			and battlefield_grid_panel.has_method("set_deployment_highlight"):
		battlefield_grid_panel.set_deployment_highlight(enabled)

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

	# Read the persisted active battlefield (single-generation contract,
	# stored by CampaignTurnController at the MISSION phase). If it holds
	# sectors, CONSUME it verbatim — the map the player saw in the preview
	# IS the battle map, and it survives save/quit/reload.
	var game_state = get_node_or_null("/root/GameState")
	var bf_data: Dictionary = {}
	if game_state and game_state.has_method("get_battlefield_data"):
		bf_data = game_state.get_battlefield_data()

	var deployment_condition: Dictionary = bf_data.get("deployment_condition", {})

	# Read world traits and planet type for terrain modification
	var world_traits: Array = []
	var planet_type_id: int = 0  # GlobalEnums.PlanetType.NONE
	if game_state and game_state.current_campaign:
		var campaign_res = game_state.current_campaign
		if "current_planet" in campaign_res:
			var planet = campaign_res.current_planet
			if planet is Dictionary:
				world_traits = planet.get("world_traits", [])
				planet_type_id = planet.get("type",
					planet.get("planet_type", 0))

	# Table size: stored contract wins, else the player's setting (p.108)
	var table_size_ft: float = float(bf_data.get("table_size_ft", 0.0))
	if table_size_ft <= 0.0:
		var settings_mgr = get_node_or_null("/root/SettingsManager")
		table_size_ft = settings_mgr.get_table_size_ft() \
			if settings_mgr and settings_mgr.has_method("get_table_size_ft") \
			else 3.0
	var bf_dims: Dictionary = BattlefieldGridClass.dims_for_table(table_size_ft)

	var stored_sectors: Array = []
	if bf_data.get("sectors", []) is Array:
		stored_sectors = bf_data.get("sectors", [])
	var sector_data: Dictionary
	if not stored_sectors.is_empty():
		# CONSUME-FIRST: the persisted contract is the SSOT.
		sector_data = bf_data
		_current_terrain_theme = str(bf_data.get("theme", "wilderness"))
		var stored_traits: Variant = bf_data.get("world_traits", [])
		if stored_traits is Array and not stored_traits.is_empty():
			world_traits = stored_traits
	else:
		# FALLBACK (Battle Simulator / Bug Hunt / Planetfall / standalone):
		# no campaign-side generation ran. Generate locally with a fresh
		# seed and WRITE BACK below so recap/reload/preview agree.
		var mission_dict_hint: Dictionary = (
			mission_data if mission_data is Dictionary else {})
		if deployment_condition.is_empty():
			var md_condition: Variant = mission_dict_hint.get(
				"deployment_condition", mission_dict_hint.get("deployment", {}))
			if md_condition is Dictionary:
				deployment_condition = md_condition
		# Theme priority: explicit theme in terrain data → planet type → fallback
		var terrain_data: Dictionary = bf_data.get("terrain", {})
		var theme_name: String = terrain_data.get("theme",
			bf_data.get("terrain_type", ""))
		if not theme_name.is_empty():
			_current_terrain_theme = _map_theme_name_to_key(theme_name)
		elif planet_type_id > 0:
			_current_terrain_theme = _planet_type_to_theme(planet_type_id)
		else:
			_current_terrain_theme = "wilderness"

		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		sector_data = _battlefield_generator.generate_terrain_suggestions(
			_current_terrain_theme, world_traits,
			deployment_condition, seed_rng.randi(), table_size_ft)

	# Store the generator result so the info-rail BATTLEFIELD card +
	# TERRAIN KEY (redesign) can read real combat_notes/objective data.
	_battlefield_data = sector_data

	# Populate the visual battlefield (bare BattlefieldMapView per the
	# map-primary redesign; the old chromed GridPanel was deleted
	# 2026-07-03 — its legend/popover live on as TerrainLegendStrip +
	# SectorRulesPopover in the intel drawer / overlay).
	if battlefield_grid_panel:
		# Square-grid sizing per the chosen table size (Core Rules p.108)
		if battlefield_grid_panel.has_method("configure_grid"):
			battlefield_grid_panel.configure_grid(bf_dims)
		var sectors_arr: Array = sector_data.get("sectors", [])
		var theme_display_name: String = sector_data.get(
			"theme_name", _current_terrain_theme)
		if battlefield_grid_panel.has_method("populate_from_sectors"):
			battlefield_grid_panel.populate_from_sectors(
				sectors_arr, theme_display_name, world_traits)
		# EDIT 13: right-click unit → mark casualty PopupMenu
		if battlefield_grid_panel.has_signal("unit_right_clicked") \
				and not battlefield_grid_panel.unit_right_clicked.is_connected(_on_unit_right_clicked):
			battlefield_grid_panel.unit_right_clicked.connect(_on_unit_right_clicked)
		# Tap a sector → rules popover ("what do I physically put here?")
		if battlefield_grid_panel.has_signal("cell_clicked") \
				and not battlefield_grid_panel.cell_clicked.is_connected(_on_map_sector_clicked):
			battlefield_grid_panel.cell_clicked.connect(_on_map_sector_clicked)

	# Objective positions (Core Rules pp.89-91): consume the stored ones —
	# they were computed once at generation — else compute deterministically
	# from the battlefield seed and write back below.
	var mission_dict_obj: Dictionary = (
		mission_data if mission_data is Dictionary else {})
	# objective may be a String id/type (campaign / battle-sim) OR a Dict
	# {name, type, ...} (Bug Hunt). Reduce to the type string the generator
	# matches on (Core Rules pp.89-91). String-or-Dict, 2026-07-03.
	var obj_raw: Variant = mission_dict_obj.get(
		"objective", mission_dict_obj.get("type", ""))
	var objective_str: String = ""
	if obj_raw is String:
		objective_str = obj_raw
	elif obj_raw is Dictionary:
		objective_str = str(obj_raw.get("type", obj_raw.get("name", "")))
	var base_seed: int = int(sector_data.get("seed", 0))
	var obj_positions: Array = []
	var stored_obj: Variant = bf_data.get("objective_positions", [])
	if not stored_sectors.is_empty() and stored_obj is Array \
			and not stored_obj.is_empty():
		for obj in stored_obj:
			if obj is Dictionary:
				var o: Dictionary = obj.duplicate()
				o["grid_pos"] = BattlefieldGridClass.json_to_grid_pos(
					o.get("grid_pos"))
				obj_positions.append(o)
	else:
		var obj_rng := RandomNumberGenerator.new()
		obj_rng.seed = hash("%d|objectives" % base_seed)
		obj_positions = _battlefield_generator.compute_objective_positions(
			objective_str, sector_data.get("sectors", []), obj_rng, bf_dims)
	if battlefield_grid_panel and battlefield_grid_panel.has_method(
			"set_objective_positions"):
		battlefield_grid_panel.set_objective_positions(obj_positions)

	# Enemy deployment markers by AI type (Core Rules p.110): consume
	# stored, else compute deterministically from the battlefield seed.
	var ef_for_deploy: Dictionary = (
		mission_dict_obj.get("enemy_force", {}))
	var ai_type: String = ef_for_deploy.get("ai", "")
	var enemy_count: int = ef_for_deploy.get("count", 0)
	var unit_markers: Array = []
	var stored_markers: Variant = bf_data.get("enemy_markers", [])
	if not stored_sectors.is_empty() and stored_markers is Array \
			and not stored_markers.is_empty():
		unit_markers = _rehydrate_markers(stored_markers)
	elif enemy_count > 0:
		var marker_rng := RandomNumberGenerator.new()
		marker_rng.seed = hash("%d|enemy_markers" % base_seed)
		unit_markers = _rehydrate_markers(
			FPCM_BattlefieldGenerator.compute_enemy_deploy_markers(
				ai_type, enemy_count, marker_rng, bf_dims))
	if not unit_markers.is_empty() and battlefield_grid_panel \
			and battlefield_grid_panel.has_method("set_unit_positions"):
		battlefield_grid_panel.set_unit_positions(unit_markers)

	# WRITE-BACK (fallback path only): persist the locally-generated
	# battlefield in the contract shape (JSON-safe positions) so the
	# recap, a reload, and any re-entry render this exact map.
	if stored_sectors.is_empty():
		_persist_battlefield_contract(sector_data, obj_positions,
			unit_markers, deployment_condition, world_traits,
			table_size_ft, objective_str, ai_type, enemy_count)

	# (The old GridPanel context header line was chrome the bare MapView
	# never had — objective/condition/enemy context lives in the setup
	# sections below and the pre-battle Battle Card.)

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
	var theme_display: String = sector_data.get(
		"theme_name", _current_terrain_theme)
	_add_setup_text(theme_display, Color("#f59e0b"), 16)
	# Compendium theme description = line 2 of the generator summary
	var description: String = ""
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

	# Section 1b: World Trait Combat Notes (from BattlefieldGenerator)
	var combat_notes: Array = sector_data.get("combat_notes", [])
	if not combat_notes.is_empty():
		_add_setup_section_header("WORLD TRAIT EFFECTS")
		for note: String in combat_notes:
			_add_setup_text(note, Color("#E879F9"))
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

	# Section 4: Mission Objective (mission_dict declared in Section 0a).
	# objective is String (campaign / battle-sim) or Dict (Bug Hunt) — take
	# the display name from either. (2026-07-03, String-or-Dict family.)
	var obj_field: Variant = mission_dict.get(
		"objective", mission_dict.get("type", ""))
	var objective_name: String = ""
	if obj_field is String:
		objective_name = obj_field
	elif obj_field is Dictionary:
		objective_name = str(obj_field.get("name", obj_field.get("type", "")))
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

	# Regenerate = roll a whole NEW battlefield (fresh explicit seed) with
	# the SAME world traits + deployment condition as the original, then
	# persist the new contract so preview/recap/reload agree.
	var regen_world_traits: Array = []
	var regen_condition: Dictionary = {}
	var regen_table_ft: float = 0.0
	var regen_objective: String = ""
	var regen_ai: String = ""
	var regen_count: int = 0
	var regen_game_state = get_node_or_null("/root/GameState")
	if regen_game_state and regen_game_state.has_method("get_battlefield_data"):
		var prev_contract: Dictionary = regen_game_state.get_battlefield_data()
		regen_condition = prev_contract.get("deployment_condition", {})
		regen_table_ft = float(prev_contract.get("table_size_ft", 0.0))
		regen_objective = str(prev_contract.get("mission_objective", ""))
		regen_ai = str(prev_contract.get("enemy_ai", ""))
		regen_count = int(prev_contract.get("enemy_count", 0))
		var prev_traits: Variant = prev_contract.get("world_traits", [])
		if prev_traits is Array:
			regen_world_traits = prev_traits
	if regen_world_traits.is_empty() and regen_game_state \
			and regen_game_state.current_campaign:
		var regen_campaign = regen_game_state.current_campaign
		if "current_planet" in regen_campaign:
			var regen_planet = regen_campaign.current_planet
			if regen_planet is Dictionary:
				regen_world_traits = regen_planet.get("world_traits", [])
	if regen_table_ft <= 0.0:
		var regen_settings = get_node_or_null("/root/SettingsManager")
		regen_table_ft = regen_settings.get_table_size_ft() \
			if regen_settings and regen_settings.has_method("get_table_size_ft") \
			else 3.0

	var regen_seed_rng := RandomNumberGenerator.new()
	regen_seed_rng.randomize()
	var new_sector_data: Dictionary = (
		_battlefield_generator.generate_terrain_suggestions(
			_current_terrain_theme, regen_world_traits, regen_condition,
			regen_seed_rng.randi(), regen_table_ft))
	_battlefield_data = new_sector_data

	# Refresh the visual battlefield. (Pre-2026-07-02 this guarded on
	# has_method("populate") — the bare MapView only has
	# populate_from_sectors, so Regenerate silently skipped the visual.)
	var regen_dims: Dictionary = BattlefieldGridClass.dims_for_table(regen_table_ft)
	var regen_seed: int = int(new_sector_data.get("seed", 0))
	if battlefield_grid_panel:
		if battlefield_grid_panel.has_method("configure_grid"):
			battlefield_grid_panel.configure_grid(regen_dims)
		if battlefield_grid_panel.has_method("populate_from_sectors"):
			battlefield_grid_panel.populate_from_sectors(
				new_sector_data.get("sectors", []),
				new_sector_data.get("theme_name", _current_terrain_theme),
				regen_world_traits)

	# Recompute objectives + markers deterministically from the new seed.
	# The Notable Sight is mission-level (p.89), not terrain — it survives
	# a terrain regenerate.
	var regen_obj_rng := RandomNumberGenerator.new()
	regen_obj_rng.seed = hash("%d|objectives" % regen_seed)
	var regen_obj: Array = _battlefield_generator.compute_objective_positions(
		regen_objective, new_sector_data.get("sectors", []),
		regen_obj_rng, regen_dims)
	var regen_prev: Dictionary = regen_game_state.get_battlefield_data() \
		if regen_game_state \
		and regen_game_state.has_method("get_battlefield_data") else {}
	regen_obj = FPCM_BattlefieldGenerator.append_notable_sight_marker(
		regen_obj, regen_prev.get("notable_sight", {}), regen_dims)
	if battlefield_grid_panel and battlefield_grid_panel.has_method(
			"set_objective_positions"):
		battlefield_grid_panel.set_objective_positions(regen_obj)
	var regen_markers: Array = []
	if regen_count > 0:
		var regen_marker_rng := RandomNumberGenerator.new()
		regen_marker_rng.seed = hash("%d|enemy_markers" % regen_seed)
		regen_markers = _rehydrate_markers(
			FPCM_BattlefieldGenerator.compute_enemy_deploy_markers(
				regen_ai, regen_count, regen_marker_rng, regen_dims))
		if battlefield_grid_panel and battlefield_grid_panel.has_method(
				"set_unit_positions"):
			battlefield_grid_panel.set_unit_positions(regen_markers)

	# Persist the new battlefield (fresh sector_rerolls — new table)
	_persist_battlefield_contract(new_sector_data, regen_obj,
		regen_markers, regen_condition, regen_world_traits,
		regen_table_ft, regen_objective, regen_ai, regen_count)

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

## Map GlobalEnums.PlanetType ordinal → BattlefieldGenerator theme key.
## Based on thematic fit — no Core Rules mapping exists, these are UX choices.
## Only the 4 Compendium themes (pp.96-98) are valid targets; the 3 synthesized
## themes (urban_settlement/wasteland/ship_interior) were removed 2026-07-02.
func _planet_type_to_theme(planet_type: int) -> String:
	# GlobalEnums.PlanetType: NONE=0, DESERT=1, ICE=2, JUNGLE=3,
	# OCEAN=4, ROCKY=5, TEMPERATE=6, VOLCANIC=7
	match planet_type:
		1:  # DESERT
			return "wilderness"
		2:  # ICE
			return "wilderness"
		3:  # JUNGLE
			return "wilderness"
		4:  # OCEAN
			return "crash_site"
		5:  # ROCKY
			return "alien_ruin"
		6:  # TEMPERATE
			return "industrial_zone"
		7:  # VOLCANIC
			return "alien_ruin"
		_:
			return "wilderness"

func _map_theme_name_to_key(theme_name: String) -> String:
	## Map display name → BattlefieldGenerator theme key (4 Compendium themes only)
	var lower: String = theme_name.to_lower()
	if "industrial" in lower or "urban" in lower or "settlement" in lower or "city" in lower:
		return "industrial_zone"
	elif "wilderness" in lower or "wild" in lower:
		return "wilderness"
	elif "alien" in lower or "ruin" in lower:
		return "alien_ruin"
	elif "crash" in lower or "waste" in lower or "blasted" in lower \
			or "ship" in lower or "interior" in lower or "corridor" in lower:
		return "crash_site"
	# Fallback
	return "wilderness"

## Rehydrate contract markers for the MapView: positions persist as
## JSON-safe [x, y] Arrays; the MapView consumes Vector2i.
## (Enemy layout math lives in FPCM_BattlefieldGenerator
## .compute_enemy_deploy_markers — Core Rules p.110, moved 2026-07-02.)
func _rehydrate_markers(markers: Array) -> Array:
	var out: Array = []
	for m in markers:
		if m is Dictionary:
			var mm: Dictionary = m.duplicate()
			var p: Vector2 = BattlefieldGridClass.json_to_grid_pos(
				mm.get("position"))
			mm["position"] = Vector2i(p)
			out.append(mm)
	return out

## Persist the current battlefield in the active_battlefield contract shape
## (JSON-safe positions) via GameState.set_battlefield_data — the single
## chokepoint that also writes through to campaign.progress_data.
func _persist_battlefield_contract(sector_data: Dictionary,
		obj_positions: Array, unit_markers: Array,
		deployment_condition: Dictionary, world_traits: Array,
		table_size_ft: float, mission_objective: String,
		enemy_ai: String, enemy_count: int,
		sector_rerolls: Dictionary = {}) -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("set_battlefield_data"):
		return
	# Carry over campaign-path context a re-persist shouldn't lose
	var prev: Dictionary = gs.get_battlefield_data() \
		if gs.has_method("get_battlefield_data") else {}
	var obj_json: Array = []
	for obj in obj_positions:
		if obj is Dictionary:
			var oj: Dictionary = obj.duplicate()
			oj["grid_pos"] = BattlefieldGridClass.grid_pos_to_json(
				BattlefieldGridClass.json_to_grid_pos(oj.get("grid_pos")))
			obj_json.append(oj)
	var marker_json: Array = []
	for m in unit_markers:
		if m is Dictionary:
			var mj: Dictionary = m.duplicate()
			mj["position"] = BattlefieldGridClass.grid_pos_to_json(
				BattlefieldGridClass.json_to_grid_pos(mj.get("position")))
			marker_json.append(mj)
	gs.set_battlefield_data({
		"schema_version": 1,
		"seed": int(sector_data.get("seed", 0)),
		"theme": _current_terrain_theme,
		"theme_name": str(sector_data.get("theme_name", "")),
		"table_size_ft": table_size_ft,
		"world_traits": world_traits,
		"deployment_condition": deployment_condition,
		"sectors": sector_data.get("sectors", []),
		"combat_notes": sector_data.get("combat_notes", []),
		"visibility_limit": str(sector_data.get("visibility_limit", "")),
		"summary": str(sector_data.get("summary", "")),
		"objective_positions": obj_json,
		"enemy_markers": marker_json,
		"mission_objective": mission_objective,
		"enemy_ai": enemy_ai,
		"enemy_count": enemy_count,
		"sector_rerolls": sector_rerolls,
		"generated_at_turn": int(prev.get("generated_at_turn", 0)),
		"terrain_guide": prev.get("terrain_guide", {}),
		"notable_sight": prev.get("notable_sight", {}),
	})

## Tap a sector → SectorRulesPopover (the one on-map interaction).
## Re-roll offered only during SETUP — once the physical table is built,
## editing the map would desync it.
func _on_map_sector_clicked(sector_label: String, features: Array) -> void:
	# The MapView emits rendered DISPLAY labels (prefix-stripped, includes
	# visible scatter pieces); the popover needs the RAW generator features
	# — the LARGE:/SMALL:/Scatter: prefixes drive its Scatter-skip and
	# terrain-rules classification. Resolve from our stored battlefield
	# data (the SSOT); fall back to the display list.
	var raw_features: Array = features
	for sector in _battlefield_data.get("sectors", []):
		if sector is Dictionary \
				and str(sector.get("label", "")) == sector_label:
			raw_features = sector.get("features", features)
			break
	if _sector_popover == null or not is_instance_valid(_sector_popover):
		var PopoverClass = load(
			"res://src/ui/components/battle/SectorRulesPopover.gd")
		_sector_popover = PopoverClass.new()
		_sector_popover.re_roll_requested.connect(_on_sector_reroll_requested)
		# Parent to the MapView (plain Control) — a PanelContainer parent
		# (map_host) force-fills its children, which stretched the popover
		# across the whole host (found in the 2026-07-03 runtime pass).
		var popover_parent: Control = battlefield_grid_panel \
			if battlefield_grid_panel is Control else self
		popover_parent.add_child(_sector_popover)
		_sector_popover.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_sector_popover.position.y = 12.0
	# Re-roll allowed until COMBAT: SETUP is covered by the checklist
	# modal, so the player actually builds the physical table during
	# DEPLOYMENT — the hard edit-lock is Confirm Deployment -> COMBAT.
	_sector_popover.show_sector(sector_label, raw_features,
		current_stage in [BattleStage.SETUP, BattleStage.DEPLOYMENT])

## Per-sector re-roll (Compendium Step 5, p.95): deterministic derived seed
## hash(base_seed | label | count) — the engine RNG has no avalanche effect,
## so derived seeds must be hashed (Godot 4.6 docs).
func _on_sector_reroll_requested(sector_label: String) -> void:
	if not _battlefield_generator:
		return
	var gs = get_node_or_null("/root/GameState")
	var contract: Dictionary = gs.get_battlefield_data() \
		if gs and gs.has_method("get_battlefield_data") else {}
	var base_seed: int = int(contract.get(
		"seed", _battlefield_data.get("seed", 0)))
	var rerolls: Dictionary = contract.get("sector_rerolls", {}).duplicate()
	var count: int = int(rerolls.get(sector_label, 0)) + 1
	var derived_seed: int = hash("%d|%s|%d" % [base_seed, sector_label, count])
	var new_sector: Dictionary = _battlefield_generator.regenerate_sector(
		_current_terrain_theme, sector_label, derived_seed)
	if new_sector.is_empty():
		return
	rerolls[sector_label] = count

	# Replace ONLY that sector in the current battlefield data
	var sectors: Array = _battlefield_data.get("sectors", [])
	for i in range(sectors.size()):
		if sectors[i] is Dictionary \
				and str(sectors[i].get("label", "")) == sector_label:
			sectors[i] = new_sector
			break

	var world_traits: Array = contract.get("world_traits", [])
	if battlefield_grid_panel \
			and battlefield_grid_panel.has_method("populate_from_sectors"):
		battlefield_grid_panel.populate_from_sectors(sectors,
			str(_battlefield_data.get("theme_name", _current_terrain_theme)),
			world_traits)

	# Patrol/Search markers depend on sector contents — recompute
	# deterministically from the same objective seed (p.90).
	var table_ft: float = float(contract.get("table_size_ft", 3.0))
	var dims: Dictionary = BattlefieldGridClass.dims_for_table(table_ft)
	var obj_rng := RandomNumberGenerator.new()
	obj_rng.seed = hash("%d|objectives" % base_seed)
	var obj_positions: Array = _battlefield_generator.compute_objective_positions(
		str(contract.get("mission_objective", "")), sectors, obj_rng, dims)
	obj_positions = FPCM_BattlefieldGenerator.append_notable_sight_marker(
		obj_positions, contract.get("notable_sight", {}), dims)
	if battlefield_grid_panel \
			and battlefield_grid_panel.has_method("set_objective_positions"):
		battlefield_grid_panel.set_objective_positions(obj_positions)

	var markers: Array = _rehydrate_markers(contract.get("enemy_markers", []))
	_persist_battlefield_contract(_battlefield_data, obj_positions, markers,
		contract.get("deployment_condition", {}), world_traits, table_ft,
		str(contract.get("mission_objective", "")),
		str(contract.get("enemy_ai", "")),
		int(contract.get("enemy_count", 0)), rerolls)

	# Refresh the open popover with the new features + the intel drawer
	if _sector_popover and is_instance_valid(_sector_popover):
		_sector_popover.show_sector(sector_label,
			new_sector.get("features", []), true)
	_rebuild_info_rail()
	if unified_log and unified_log.has_method("add_entry"):
		unified_log.add_entry("setup",
			"Sector %s re-rolled (Compendium Step 5, p.95)" % sector_label)

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


## ── DLC: No-Minis Combat Panel (Compendium pp.66-73) ────────────

func _setup_no_minis_panel(crew_size: int, enemy_count: int) -> void:
	## Create and wire the No-Minis Combat panel. Wave 3: the per-battle
	## representation picker is authoritative when present in mission_data
	## (representation_mode == "no_minis" shows it; anything else hides it);
	## absent (standalone sim / non-picker paths) we fall back to the global
	## feature toggle. Ownership of the Freelancer's Handbook DLC is required
	## either way (No-Minis is Compendium content).
	var dlc_mgr = get_node_or_null("/root/DLCManager")
	if not dlc_mgr:
		return
	if not dlc_mgr.is_feature_available(dlc_mgr.ContentFlag.NO_MINIS_COMBAT):
		return
	var md: Dictionary = _stored_mission_data if _stored_mission_data is Dictionary else {}
	var rep_mode: String = str(md.get("representation_mode", ""))
	var want_no_minis: bool = (rep_mode == "no_minis") if rep_mode != "" \
		else dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.NO_MINIS_COMBAT)
	if not want_no_minis:
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

	_log_message("No-Minis Combat mode active (Compendium pp.66-73)", UIColors.COLOR_EMERALD)


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

	# Per-figure battle bookkeeping (Core Rules Battle Round Ref pp.116-118).
	# stun_markers: stackable; gained surviving a Hit ("pushed 1\" back and
	#   Stunned"). NOT reset at round start (Core Rules: removed after acting).
	# is_activated: each figure acts once per round; reset every round.
	# react_slot: Reaction Roll outcome — 0 none / 1 QUICK / 2 SLOW / 3 ENEMY.
	var stun_markers: int = 0
	var is_activated: bool = false
	var react_slot: int = 0

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

		# Enemies always act in the ENEMY phase (Core Rules p.114) — they do
		# not make a Reaction Roll. react_slot = 3 from creation so the rail
		# reads correctly even before the first round reset.
		react_slot = 3

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

	func reset_for_new_round() -> void:
		## Core Rules p.114: each figure acts once per round; activation and
		## the reaction economy reset every round. Stun markers do NOT reset
		## here (Core Rules: a Stun marker is removed only after the stunned
		## figure acts). Enemies keep react_slot = 3 (always ENEMY phase);
		## crew react_slot is repopulated by the Reaction Roll each round.
		is_activated = false
		reactions_used_this_round = 0
		if team == "enemy":
			react_slot = 3
		else:
			react_slot = 0

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


## ============================================================================
## Stars of the Story — Mid-Battle HUD (Core Rules p.67)
## ============================================================================
##
## Three abilities are available DURING battle:
##   - "It's time to go!"          — end battle, all crew escape (no hold field)
##   - "Did you ever meet my mate?" — add new crew member at battlefield edge
##   - "Lucky shot!"               — turn a missed shot into a hit
##
## Disabled in non-5PFH battle modes (Bug Hunt / Planetfall / Tactics) and in
## Insanity difficulty. Per Compendium p.214, stars don't carry to Bug Hunt.

func _setup_stars_battle_ui() -> void:
	if not is_inside_tree():
		return

	# Only standard 5PFH battles offer stars
	if _is_bug_hunt_mode or _is_planetfall_mode:
		return

	# Need a campaign with stars data
	var campaign = _get_campaign_for_stars()
	if not campaign or campaign.stars_of_the_story.is_empty():
		return

	# Verify any battle-only star is usable
	var stars = _build_stars_system_from_campaign(campaign)
	if not stars or not stars.is_active():
		return
	if not (stars.can_use(_StarsSysClassRef.StarAbility.ITS_TIME_TO_GO)
			or stars.can_use(_StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET)
			or stars.can_use(_StarsSysClassRef.StarAbility.LUCKY_SHOT)):
		return

	# Add Stars button to ActionBar (sibling of EndTurnButton)
	var action_bar: Container = end_turn_button.get_parent() if end_turn_button else null
	if not action_bar:
		return
	_stars_battle_button = Button.new()
	_stars_battle_button.text = "⭐ Stars"
	_stars_battle_button.tooltip_text = "Use a Stars of the Story emergency ability (Core Rules p.67)"
	_stars_battle_button.custom_minimum_size = Vector2(96, _touch_h())
	_stars_battle_button.pressed.connect(_on_stars_battle_button_pressed)
	# Insert before EndTurnButton so it's left of "End Turn"
	action_bar.add_child(_stars_battle_button)
	var end_idx: int = end_turn_button.get_index()
	action_bar.move_child(_stars_battle_button, end_idx)


func _get_campaign_for_stars():
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		return gs.get_current_campaign()
	return null


func _build_stars_system_from_campaign(campaign):
	if not campaign or campaign.stars_of_the_story.is_empty():
		return null
	var s = _StarsSysClassRef.new()
	s.deserialize(campaign.stars_of_the_story)
	return s


func _on_stars_battle_button_pressed() -> void:
	_show_stars_battle_popup()


func _show_stars_battle_popup() -> void:
	# Lazy-build popup
	if _stars_battle_popup == null or not is_instance_valid(_stars_battle_popup):
		_stars_battle_popup = PopupPanel.new()
		_stars_battle_popup.size = Vector2i(360, 0)
		add_child(_stars_battle_popup)
		_build_stars_battle_popup_content()
	# Refresh ability state before showing
	_refresh_stars_battle_popup()
	# Anchor below the button
	if _stars_battle_button:
		var rect: Rect2 = _stars_battle_button.get_global_rect()
		_stars_battle_popup.popup(Rect2i(
			Vector2i(int(rect.position.x), int(rect.end.y + 4)),
			_stars_battle_popup.size))
	else:
		_stars_battle_popup.popup_centered()


func _build_stars_battle_popup_content() -> void:
	if not _stars_battle_popup:
		return
	for child in _stars_battle_popup.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_stars_battle_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "STARS OF THE STORY (Battle)"
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	var help := Label.new()
	help.text = "Each ability usable ONCE per campaign (Core Rules p.67)."
	help.add_theme_font_size_override("font_size", 11)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(help)

	vbox.add_child(HSeparator.new())

	# 3 mid-battle ability rows (each named for later refresh by node name)
	_build_stars_battle_row(vbox,
		_StarsSysClassRef.StarAbility.ITS_TIME_TO_GO,
		"It's time to go!", "ItsTimeToGoBtn")
	_build_stars_battle_row(vbox,
		_StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET,
		"Did you ever meet my mate?", "MetMyMateBtn")
	_build_stars_battle_row(vbox,
		_StarsSysClassRef.StarAbility.LUCKY_SHOT,
		"Lucky shot!", "LuckyShotBtn")


func _build_stars_battle_row(parent: VBoxContainer, ability: int,
		label_text: String, btn_node_name: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.name = btn_node_name + "Label"
	hbox.add_child(name_lbl)

	var uses_lbl := Label.new()
	uses_lbl.text = "1/1"
	uses_lbl.add_theme_font_size_override("font_size", 12)
	uses_lbl.name = btn_node_name + "Uses"
	hbox.add_child(uses_lbl)

	var use_btn := Button.new()
	use_btn.text = "Use"
	use_btn.name = btn_node_name
	use_btn.custom_minimum_size = Vector2(60, 32)
	use_btn.pressed.connect(_on_battle_star_use_pressed.bind(ability))
	hbox.add_child(use_btn)


func _refresh_stars_battle_popup() -> void:
	if not _stars_battle_popup:
		return
	var campaign = _get_campaign_for_stars()
	var stars = _build_stars_system_from_campaign(campaign)
	if not stars:
		return
	_refresh_star_row(stars, _StarsSysClassRef.StarAbility.ITS_TIME_TO_GO, "ItsTimeToGoBtn")
	_refresh_star_row(stars, _StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET, "MetMyMateBtn")
	_refresh_star_row(stars, _StarsSysClassRef.StarAbility.LUCKY_SHOT, "LuckyShotBtn")


func _refresh_star_row(stars, ability: int, btn_node_name: String) -> void:
	var btn := _stars_battle_popup.find_child(btn_node_name, true, false) as Button
	var uses_lbl := _stars_battle_popup.find_child(btn_node_name + "Uses",
		true, false) as Label
	if not btn or not uses_lbl:
		return
	var remaining: int = stars.get_uses_remaining(ability)
	var maximum: int = stars.get_max_uses(ability)
	uses_lbl.text = "%d/%d" % [remaining, maximum]
	btn.disabled = not stars.can_use(ability)


func _on_battle_star_use_pressed(ability: int) -> void:
	var campaign = _get_campaign_for_stars()
	var stars = _build_stars_system_from_campaign(campaign)
	if not stars or not stars.can_use(ability):
		return

	# Route by ability
	match ability:
		_StarsSysClassRef.StarAbility.ITS_TIME_TO_GO:
			_use_battle_star_its_time_to_go(campaign, stars)
		_StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET:
			_use_battle_star_met_my_mate(campaign, stars)
		_StarsSysClassRef.StarAbility.LUCKY_SHOT:
			_use_battle_star_lucky_shot(campaign, stars)


func _use_battle_star_its_time_to_go(campaign, stars) -> void:
	# Confirm via simple ConfirmationDialog (tabletop companion style)
	var dlg := ConfirmationDialog.new()
	dlg.title = "It's time to go!"
	dlg.dialog_text = ("All crew immediately escape the battle.\n\n"
		+ "You do NOT hold the field. Any objectives are abandoned.\n\n"
		+ "Once per campaign — confirm?")
	add_child(dlg)
	dlg.confirmed.connect(func():
		_apply_its_time_to_go(campaign, stars)
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


func _apply_its_time_to_go(campaign, stars) -> void:
	var result: Dictionary = stars.use_ability(
		_StarsSysClassRef.StarAbility.ITS_TIME_TO_GO, {})
	if not result.get("success", false):
		return
	# Persist + log
	campaign.stars_of_the_story = stars.serialize()
	_log_battle_star_use(_StarsSysClassRef.StarAbility.ITS_TIME_TO_GO,
		{}, result, campaign)
	# Hide popup + Stars button (one-shot used; popup also reflects 0/1 anyway)
	if _stars_battle_popup:
		_stars_battle_popup.hide()
	# Build battle_result and emit completion
	var battle_result := {
		"victory": false,
		"held_field": false,
		"evacuated": true,
		"evacuated_via_star": true,
		"crew_casualties": [],
		"crew_injuries": [],
		"rounds_fought": 0,
		"objectives_met": []
	}
	tactical_battle_completed.emit(battle_result)


func _use_battle_star_met_my_mate(campaign, stars) -> void:
	# Tabletop companion: instruct the player to add a new model.
	# Spawn a random character via CharacterGenerator if available, else generic note.
	var new_char_name: String = _roll_random_recruit_name()

	var dlg := AcceptDialog.new()
	dlg.title = "Did you ever meet my mate?"
	dlg.dialog_text = ("A new crew member joins immediately!\n\n"
		+ "Name (suggested): %s\n\n" % new_char_name
		+ "Place the model within 6\" of any battlefield edge.\n"
		+ "They can act this round.\n\n"
		+ "(Roll up full stats post-battle and add them to your crew.)")
	add_child(dlg)
	dlg.confirmed.connect(func():
		_apply_met_my_mate(campaign, stars, new_char_name)
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


func _apply_met_my_mate(campaign, stars, new_char_name: String) -> void:
	var ctx := {
		"new_character": {
			"character_name": new_char_name,
			"name": new_char_name,
			"character_id": "",
			"id": ""
		},
		"placement_tile": Vector2i.ZERO
	}
	var result: Dictionary = stars.use_ability(
		_StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET, ctx)
	if not result.get("success", false):
		return
	campaign.stars_of_the_story = stars.serialize()
	_log_battle_star_use(_StarsSysClassRef.StarAbility.DID_YOU_EVER_MEET,
		ctx, result, campaign)
	_refresh_stars_battle_popup()


func _roll_random_recruit_name() -> String:
	# Light random name — full creation happens post-battle via CharacterCreator
	var firsts: Array = ["Kai", "Vex", "Jax", "Nyx", "Rho", "Mira", "Zane",
		"Lir", "Ash", "Quill"]
	var lasts: Array = ["Cross", "Vane", "Stark", "Rook", "Hale", "Drift",
		"Pyre", "Vance", "Mox", "Reaper"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s %s" % [firsts[rng.randi() % firsts.size()],
		lasts[rng.randi() % lasts.size()]]


func _use_battle_star_lucky_shot(campaign, stars) -> void:
	# Tabletop companion: instruct the player to apply the hit.
	var dlg := AcceptDialog.new()
	dlg.title = "Lucky shot!"
	dlg.dialog_text = ("Your most recent missed shot is now a hit.\n\n"
		+ "Apply the shot's damage as if it had hit (single shot only,\n"
		+ "even if the weapon rolls multiple attack dice).\n\n"
		+ "Once per campaign — confirm to use this star.")
	add_child(dlg)
	dlg.confirmed.connect(func():
		_apply_lucky_shot(campaign, stars)
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


func _apply_lucky_shot(campaign, stars) -> void:
	# Synthesize a minimal shot_result dict — tabletop player applies damage manually
	var ctx := {"shot_result": {"hit": false, "shooter_name": "Crew", "target_name": "target"}}
	var result: Dictionary = stars.use_ability(
		_StarsSysClassRef.StarAbility.LUCKY_SHOT, ctx)
	if not result.get("success", false):
		return
	campaign.stars_of_the_story = stars.serialize()
	_log_battle_star_use(_StarsSysClassRef.StarAbility.LUCKY_SHOT,
		ctx, result, campaign)
	_refresh_stars_battle_popup()


func _log_battle_star_use(ability: int, context: Dictionary,
		result: Dictionary, campaign) -> void:
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if not journal:
		return
	var turn_num: int = 0
	if campaign and "progress_data" in campaign:
		turn_num = campaign.progress_data.get("turns_played", 0)
	_StarsSysClassRef.log_use_to_journal(
		ability, context, result, journal, turn_num, "battle")

## Build the small floating "Battle Notes" textbox in the top-right corner.
## Player jots quick observations during battle; the text is written via
## GameStateManager.set_temp_data("battle_player_notes", ...) on every change
## and consumed by CampaignJournal.auto_create_battle_entry() when the
## post-battle entry is constructed.
## M4: single authority for the battle-notes layer visibility — shown only when
## the battle screen is actually on-screen (is_visible_in_tree) AND not in a
## portrait phone layout (where the -260px-anchored box overlaps the top bar).
func _sync_battle_notes_visibility() -> void:
	if _battle_note_layer and is_instance_valid(_battle_note_layer):
		_battle_note_layer.visible = is_visible_in_tree() and not _should_collapse_battle_rails()

func _setup_battle_notes_widget() -> void:
	if _battle_note_layer != null:
		return
	_battle_note_layer = CanvasLayer.new()
	_battle_note_layer.layer = 30  # Above main UI, below modals
	_battle_note_layer.name = "__battle_notes_layer"
	add_child(_battle_note_layer)
	# M4: a CanvasLayer renders independent of its parent Control's visibility, so
	# hiding TacticalBattleUI does NOT hide this widget — it would float over the
	# world phase / dashboard. Gate it on the screen's actual visibility-in-tree.
	if not visibility_changed.is_connected(_sync_battle_notes_visibility):
		visibility_changed.connect(_sync_battle_notes_visibility)
	_sync_battle_notes_visibility()

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_note_layer.add_child(anchor)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -260
	panel.offset_top = 16
	panel.offset_right = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	anchor.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "Battle Notes"
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	label.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	vbox.add_child(label)

	_battle_note_edit = TextEdit.new()
	_battle_note_edit.placeholder_text = "Jot what happened. Carries to the journal."
	_battle_note_edit.custom_minimum_size = Vector2(228, 70)
	_battle_note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_battle_note_edit.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_SM)
	_battle_note_edit.text_changed.connect(_on_battle_note_changed)
	vbox.add_child(_battle_note_edit)

func _on_battle_note_changed() -> void:
	if _battle_note_edit == null:
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("set_temp_data"):
		return
	gsm.set_temp_data("battle_player_notes", _battle_note_edit.text)
