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
const ReactionRollPoolClass = preload("res://src/core/battle/ReactionRollPool.gd")
const EscalatingBattlesManagerRef = preload("res://src/core/managers/EscalatingBattlesManager.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const CompendiumDeploymentVariablesRef = preload(
	"res://src/data/compendium_deployment_variables.gd")
const ProgressiveDifficultyTrackerRef = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
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
	"story_marker_panel": "res://src/ui/components/battle/StoryMarkerPanel.gd",
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

# Stars of the Story battle HUD (Core Rules p.67 — 3 mid-battle abilities)
var _stars_battle_button: Button = null

# Wave 3 battle-UX: single-level undo of the last player-recorded unit mutation,
# plus its ActionBar button (set up like _stars_battle_button).
var _undo_button: Button = null
var _consumable_button: Button = null
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
## Story Track Event 5 marker tracker (Core Rules p.157). Only instantiated when
## the mission carries story_event_id == "kidnap"; null on every other battle.
var story_marker_panel: Control = null
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
## Compendium p.22: "Reinforcements can arrive only once in each battle."
var _psionic_reinforcements_arrived: bool = false
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

## AI code -> the full type name used by data/RulesReference/EnemyAI.json.
## Codes are Core Rules p.92 ("The AI Type column indicates the type of AI to
## use: A Aggressive / C Cautious / D Defensive / G Guardian / R Rampage /
## T Tactical / B Beast").
const AI_CODE_TO_NAME: Dictionary = {
	"A": "Aggressive",
	"C": "Cautious",
	"D": "Defensive",
	"G": "Guardian",
	"R": "Rampage",
	"T": "Tactical",
	"B": "Beast",
}

## The Escalating Battles D100 table (Compendium p.46) has exactly SIX columns.
## Guardian is a real Core Rules AI type with no column in that table, so a
## Guardian enemy legitimately gets no Escalation check — this list is what the
## setup screen tests against so the omission is stated instead of silent.
const ESCALATION_AI_TYPES: PackedStringArray = [
	"aggressive", "cautious", "defensive", "rampage", "tactical", "beast",
]

const EnemyAIOracleRouterClass = preload("res://src/core/battle/EnemyAIOracleRouter.gd")
var _ai_reference_router: RefCounted = null

# SceneRouter-based battle delegation (Bug Hunt, Planetfall, Tactics)
# When loaded via SceneRouter (not embedded as child), these track the
# return route and temp_data key for storing results.
var _return_screen: String = ""
var _result_temp_key: String = ""

# Seed-once guard for the End-Phase Morale tracker. set_enemy_count() resets the
# per-round casualty count and the fled tally, so a second seed mid-battle would
# erase real progress.
var _morale_seeded: bool = false

## Always-visible battle-state chip strip (round / enemies + panic / objective /
## deployment condition), built into the phase banner.
var _glance_row: HFlowContainer = null

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

	# Keep content clear of the floating SettingsOverlay gear/bug buttons (drawn on
	# their own CanvasLayer above this screen). Pushes content DOWN -- a right-side
	# margin would raise the container's minimum WIDTH and propagate an overflow up
	# the tree (proven and reverted on HelpScreen).
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)

func _initialize_managers() -> void:
	## Initialize manager references
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null

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

	# Stars of the Story HUD — deferred so campaign data is loaded
	call_deferred("_setup_stars_battle_ui")
	# Wave 3: Undo button on the ActionBar (deferred so the bar exists).
	call_deferred("_setup_undo_button")
	# Consumable use — a Free Action from the Stash (Core Rules p.54).
	call_deferred("_setup_consumable_button")

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
	# p.118 is the BATTLE ROUND REFERENCE spread (verified against the PDF);
	# p.119 is where Post-Battle Activities starts.
	_make_drawer("reference", "Battle Round Reference (Core Rules p.118)",
		DrawerClass.Edge.RIGHT)
	_make_drawer("tracking", "Tracking", DrawerClass.Edge.RIGHT, true)
	# NO separate "oracle" drawer. One existed and NOTHING was ever added to its
	# body, so the FULL_ORACLE toolbar button opened a blank panel. The AI oracle
	# is deliberately an intent layer sitting above the per-figure enemy cards
	# (see _populate_unit_drawer), so it lives in the "enemies" drawer and a second
	# empty surface competing for the same content is worse than none.

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

func _is_standalone_battle() -> bool:
	## True when this battle has no owning 5PFH campaign to persist a table for.
	##
	## Two independent signals, either sufficient:
	##  - a non-empty _battle_mode_id (bug_hunt / planetfall / tactics run their own
	##    campaign cores and never use 5PFH's active_battlefield contract)
	##  - no current_campaign at all (Battle Simulator, MCP/demo, tier-select mode)
	##
	## Deliberately NOT using the PhaseContainer ancestor walk that
	## _check_standalone_mode does: this is called during persistence, long after
	## reparenting, so an ownership question must be answered from state, not layout.
	if not _battle_mode_id.is_empty():
		return true
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return true
	return gs.get("current_campaign") == null


func _check_standalone_mode() -> void:
	## If initialize_battle() was never called, check if battle context was
	## stored in temp_data by a gamemode turn controller (Bug Hunt, Planetfall,
	## Tactics). If so, auto-initialize from that context. Otherwise, show
	## tier selection for standalone/MCP/demo mode (BUG-B01, B06, B17, B18 fix).
	if _battle_initialized:
		return
	# Deferred from _ready(), so it runs a frame later and this screen may have
	# left the tree by then. Guarding HERE rather than at each symptom: the whole
	# chain below is tree-dependent, and a detached run produced three separate
	# errors from one deferred call — the /root/GameStateManager lookup in
	# _try_auto_init_from_temp_data(), the /root lookup in
	# _build_terrain_controls(), and get_viewport() coming back null in
	# _overlay_width(). One check at the entry point stops all of them.
	if not is_inside_tree():
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

	# Check each gamemode's battle context key. Tactics is intentionally absent:
	# no producer ever writes tactics_battle_context (the Tactics→TacticalBattleUI
	# delegation was never built — TacticsBattleSetupPanel is an info stub), so
	# this read was dead. Re-add when that delegation lands (feature backlog).
	var context_keys: Array = [
		{"context_key": "bug_hunt_battle_context", "result_key": "bug_hunt_battle_result", "return_screen": "bug_hunt_turn_controller"},
		{"context_key": "planetfall_battle_context", "result_key": "planetfall_battle_result", "return_screen": "planetfall_turn_controller"},
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
	# Reached from call_deferred() AND from a resize debounce timer, so it can
	# fire a frame or more after this screen left the tree — during a scene
	# transition, say. get_viewport() is null on a detached node, and the next
	# line called a method on it ("Cannot call method 'get_visible_rect' on a
	# null value"). Checked before the re-entrancy flag is set, so an early
	# return cannot leave the flag stuck true and permanently disable layout.
	if not is_inside_tree():
		return
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
func _refresh_glance_chips() -> void:
	## Repaint the always-visible battle-state strip. Cheap, so it is rebuilt on
	## every state change rather than diffed.
	if _glance_row == null or not is_instance_valid(_glance_row):
		return
	# remove_child BEFORE queue_free: queue_free is deferred, so the old chips are
	# still in the tree for the rest of the frame and the strip would briefly show
	# both the stale and the fresh set.
	for c in _glance_row.get_children():
		_glance_row.remove_child(c)
		c.queue_free()

	# The tracker is authoritative once the battle is running, but it reports 0
	# before it starts (setup/deployment), which would blank the chip. Take
	# whichever is further along.
	var round_num: int = current_turn
	if round_tracker and round_tracker.has_method("get_current_round"):
		round_num = maxi(round_num, int(round_tracker.get_current_round()))
	if round_num > 0:
		_add_glance_chip("Round %d" % round_num, UIColors.COLOR_CYAN,
			"Battle round %d" % round_num)

	# Enemies left + the Panic range they bail on — the two numbers that decide
	# whether to press the attack. Available now that the morale tracker is seeded.
	var standing: int = 0
	for unit in enemy_units:
		if not unit.is_dead and unit.health > 0:
			standing += 1
	var panic_txt: String = ""
	if morale_tracker and is_instance_valid(morale_tracker) \
			and "panic_range_max" in morale_tracker:
		var pr: int = int(morale_tracker.panic_range_max)
		panic_txt = " · Panic %s" % ("0" if pr <= 0 else "1-%d" % pr)
	if not enemy_units.is_empty():
		_add_glance_chip("%d enemy left%s" % [standing, panic_txt],
			UIColors.COLOR_RED,
			"%d enemy figures still standing%s" % [standing, panic_txt])

	if _objective_tracker != null and _objective_tracker.has_objective():
		var done: bool = _objective_tracker.is_complete()
		_add_glance_chip(
			"%s: %s" % [_objective_tracker.get_objective_name(),
				"DONE" if done else "open"],
			UIColors.COLOR_EMERALD if done else UIColors.COLOR_WARNING,
			"Objective %s %s" % [_objective_tracker.get_objective_name(),
				"complete" if done else "not yet met"])

	var deploy: Dictionary = _battle_context.get("deployment", {})
	var cond_title: String = str(deploy.get("condition_title",
		deploy.get("condition_id", "")))
	if cond_title != "" and cond_title != "NO_CONDITION":
		_add_glance_chip(cond_title.capitalize(), UIColors.COLOR_WARNING,
			"Deployment condition: %s" % cond_title)

	# Invasion hold clock (Core Rules p.92): "You must hold out for 6 rounds,
	# then you can flee or fight until you Hold the Field... Any figure that
	# leaves the table before Round 6 becomes a casualty." A 6-round obligation
	# the player has to count is exactly what a glance chip is for — and until
	# now BattleSetupRules computed hold_rounds and nothing displayed it.
	var setup_rules: Dictionary = _stored_mission_data.get("setup_rules", {}) \
		if _stored_mission_data is Dictionary else {}
	var hold_rounds: int = int(setup_rules.get("hold_rounds", 0))
	if hold_rounds > 0:
		var round_now: int = maxi(current_turn, 1)
		if round_now < hold_rounds:
			_add_glance_chip("Hold %d/%d" % [round_now, hold_rounds],
				UIColors.COLOR_RED,
				"Invasion: hold out for %d rounds. Leaving before round %d makes that figure a casualty (Core Rules p.92)."
					% [hold_rounds, hold_rounds])
		else:
			_add_glance_chip("Hold complete", UIColors.COLOR_EMERALD,
				"Invasion: the %d-round hold is done — you may now flee or fight on until you Hold the Field (p.92)."
					% hold_rounds)


func _add_glance_chip(text: String, color: Color, a11y: String) -> void:
	var chip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UIColors.COLOR_TERTIARY
	st.border_color = color
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = UIColors.SPACING_SM
	st.content_margin_right = UIColors.SPACING_SM
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	lbl.add_theme_color_override("font_color", color)
	# Godot 4.6 AccessKit reports nothing useful for unnamed code-built controls.
	lbl.accessibility_name = a11y
	chip.add_child(lbl)
	_glance_row.add_child(chip)


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
	# Glance strip: the handful of numbers a player at a physical table checks
	# constantly (round, enemies left + their Panic range, objective progress,
	# active deployment condition). All of it previously required opening a
	# drawer mid-turn with dice in one hand. HFlow so it wraps in portrait
	# instead of overflowing the 360dp floor.
	_glance_row = HFlowContainer.new()
	_glance_row.name = "GlanceChips"
	_glance_row.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
	_glance_row.add_theme_constant_override("v_separation", 4)
	vb.add_child(_glance_row)
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
	# The banner changes once per phase, which is exactly when the glance numbers
	# are worth repainting.
	_refresh_glance_chips()

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
	# UnifiedBattleLog — the canonical instance is built ONCE into the FeedStrip
	# (see the "Single canonical feed" block in the layout builder) and reused here.
	#
	# THE BUG THIS FIXES: this function used to unconditionally `.new()` a SECOND
	# UnifiedBattleLog and reassign `unified_log` to it. The first instance stayed
	# parented in %FeedHost — the visible bottom feed strip, which
	# _apply_stage_visibility shows for every stage except TIER_SELECT and
	# _apply_responsive_layout even sizes — but no longer had any reference pointing
	# at it, so it never received a single line. Every _log_message /
	# unified_log.log_* call went into the Tracking drawer copy instead, i.e. the
	# player's always-on battle feed was permanently blank and the whole running
	# account of the fight was hidden behind a drawer.
	if not (unified_log and is_instance_valid(unified_log)):
		unified_log = FPCM_UnifiedBattleLog.new()
		unified_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unified_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var log_host: Node = feed_host if feed_host else phase_content
		if log_host:
			log_host.add_child(unified_log)

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
	# EnemyIntentPanel is created in the STABLE tracking host and then moved to the
	# top of the enemy drawer by _populate_unit_drawer ("an AI-intent layer ON TOP
	# of the per-figure enemy tracker, not a replacement"). Do NOT create it in the
	# enemies body directly: that body is cleared and rebuilt on every repopulate,
	# so the panel would be queue_free()d out from under this reference.
	#
	# THE BUG THIS FIXES: activate_oracle() had ZERO callers repo-wide, so
	# _oracle_container.visible stayed false forever — EnemyAIOracleRouter, the
	# book's 1D6 behaviour tables and CardOracleSystem were all unreachable at
	# runtime, and the panel just read "No enemy intents detected / AI: Tactical"
	# with a hardcoded type no matter who you were fighting.
	enemy_intent_panel = _get_res("enemy_intent").new()
	enemy_intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_intent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if phase_content:
		phase_content.add_child(enemy_intent_panel)
	# activate_oracle() builds the router and reveals the mode selector. Deferred
	# so it runs after the panel's own _ready() has built _oracle_container.
	_activate_enemy_oracle.call_deferred()

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

	# InitiativeCalculator — initiative results + overlay dismiss
	if initiative_calculator:
		initiative_calculator.continue_requested.connect(_hide_overlay)
		# Record the outcome into _battle_context so the battle briefing's
		# INITIATIVE block (which reads seize_initiative_result, a key nothing
		# used to write) actually renders, and the p.112 "may Move or fire, hits
		# only on a natural 6" instruction reaches the player.
		if not initiative_calculator.initiative_calculated.is_connected(
				_on_initiative_calculated):
			initiative_calculator.initiative_calculated.connect(
				_on_initiative_calculated)
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
	_ensure_overlay_scroll()
	call_deferred("_fit_overlay_height")
	overlay_bg.visible = true
	overlay_center.visible = true


## Put the overlay content in a scroll so a tall modal cannot exceed the screen.
##
## Width was already handled; height was not. The tier picker needs 568px on a phone
## in landscape (338 available) and 770px on a small phone, and a CenterContainer
## sizes its child to that minimum whatever the screen — so the top and bottom of the
## overlay, including its buttons, were simply off the screen. Created once and reused.
func _ensure_overlay_scroll() -> ScrollContainer:
	if overlay_content == null or not is_instance_valid(overlay_content):
		return null
	var parent := overlay_content.get_parent()
	if parent is ScrollContainer:
		return parent as ScrollContainer
	if parent == null:
		return null
	var scroll := ScrollContainer.new()
	scroll.name = "OverlayScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var idx: int = overlay_content.get_index()
	parent.remove_child(overlay_content)
	parent.add_child(scroll)
	parent.move_child(scroll, idx)
	scroll.add_child(overlay_content)
	return scroll


## Cap the overlay at the viewport, but only when it is actually taller.
##
## Deferred because the content's minimum is not known until the frame after it is
## added; a short overlay keeps its natural height rather than stretching.
func _fit_overlay_height() -> void:
	var scroll := _ensure_overlay_scroll()
	if scroll == null or not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var available: float = maxf(160.0, vp.get_visible_rect().size.y - 32.0)
	var wanted: float = overlay_content.get_combined_minimum_size().y
	scroll.custom_minimum_size.x = _overlay_width()
	scroll.custom_minimum_size.y = minf(wanted, available)

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

## Compendium p.34 "Time is Running Out" runtime state.
## _paying_by_hour_limit is the 2D6-pick-highest+4 round count rolled once at
## setup (0 = the option is off); _movement_all_over_arrivals counts arrivals so
## the SECOND one is the specialist the book calls for; _fickle_scans_resolved
## keeps the end-of-Round-3 removal from firing twice.
var _paying_by_hour_limit: int = 0
var _paying_by_hour_expired: bool = false
var _movement_all_over_arrivals: int = 0
var _fickle_scans_resolved: bool = false

func _check_pending_battle_event() -> void:
	## Check if a battle event should trigger this round (Core Rules pp.116-117:
	## end of Round 2 and end of Round 4, and no more after that).
	## Called after overlay dismissal so overlays don't collide.
	## Guarded so it only fires once per round (not on every overlay dismiss).
	if not round_tracker or not round_tracker.has_method("check_battle_event"):
		return
	# Core Rules p.116 heads this table "BATTLE EVENTS (OPTIONAL)" and closes it
	# with "Use of this table is optional — you may choose to use it occasionally
	# during your campaign, or not at all." The app rolled them unconditionally,
	# so a player who had opted out at the table still got an event announced at
	# the end of rounds 2 and 4. Defaults on, so nothing changes unless asked.
	var settings := get_node_or_null("/root/SettingsManager")
	if settings and settings.has_method("are_battle_events_enabled") \
			and not settings.are_battle_events_enabled():
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

	# Same reason the cards are rebuilt above: initialize_battle() runs BEFORE the
	# player picks a tier, so these ASSISTED components did not exist yet and the
	# configuration calls there were no-ops. enemy_units, _stored_mission_data and
	# the crew are all populated by now.
	_seed_morale_tracker()
	if initiative_calculator and is_instance_valid(initiative_calculator) \
			and initiative_calculator.has_method("set_crew"):
		var crew_for_init: Array = []
		for unit in crew_units:
			if unit.original_character:
				crew_for_init.append(unit.original_character)
		if not crew_for_init.is_empty():
			initiative_calculator.set_crew(crew_for_init)
	_apply_initiative_context()

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

	# Objective + win condition (p.89-90).
	#
	# THE BUG THIS FIXES: this read mission_data["objective"] — the JOB's name
	# from the world phase — while the glance chip, the battle log and the
	# results form all read the objective the tracker actually resolved from the
	# p.89 D10 table. A desktop run showed "◆ Objective: Fight Off" on the card
	# while the chip read "Deliver: open" and the log was tracking "all enemies
	# with package undamaged". The card's whole purpose is to state the WIN
	# CONDITION, so naming a different objective than the one being tracked told
	# the player to satisfy the wrong one. The tracker is authoritative; the
	# mission keys are the fallback for paths that never built a tracker.
	var obj_txt: String = ""
	var obj_key: String = ""
	if _objective_tracker != null and _objective_tracker.has_objective():
		obj_txt = _objective_tracker.get_objective_name()
		# The win-text table is keyed by the snake_case objective ID, so look up
		# by ID and display by name. Passing the display name matched nothing for
		# the two multi-word objectives ("Fight Off" != "fight_off",
		# "Move Through" != "move_through") and printed a BLANK win condition —
		# on the one card row whose entire job is to state how you win.
		obj_key = _objective_tracker.get_objective_id()
	if obj_txt == "":
		obj_txt = str(md.get("mission_objective",
			md.get("objective", md.get("type", ""))))
	if obj_key == "":
		obj_key = obj_txt
	if obj_txt != "":
		var win: String = BattleFlowGuideClass.objective_win_text(obj_key)
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
	## Seed the results form from what the player already recorded during the
	## battle, so Record Result opens pre-filled and they only correct it.
	##
	## THE BUG THIS FIXES: this read ONLY the objective tracker. A player who spent
	## the whole fight marking figures down on the crew and enemy cards opened the
	## form to every casualty box unchecked, zero enemies defeated and round 1 — and
	## for a battle with no trackable objective _objective_tracker is null, so the
	## prefill was completely empty. The one screen that decides what the campaign
	## records ignored every input the companion had collected.
	##
	## The player still owns every value: this is a starting point, not an answer.
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

	# Live table state. Only fills what the objective tracker did not already
	# provide, so the tracker stays authoritative where it has an opinion.
	# defeated_enemies was hardcoded [] on this path, so RivalPatronResolver's
	# per-enemy rival stamp had nothing to walk after a manually recorded battle.
	var defeated: Array = _defeated_enemy_records()
	var enemies_down: int = defeated.size()
	prefill["defeated_enemies"] = defeated
	if not prefill.has("enemies_defeated"):
		prefill["enemies_defeated"] = enemies_down

	# Downed crew, by index into the SAME array _ensure_results_form_drawer
	# passes to setup() (built from crew_units in order).
	#
	# These pre-check the INJURIES boxes, never the casualties boxes: Core Rules
	# p.122 — a figure that went Out of Action always rolls the post-battle Injury
	# Table, and the ROLL decides dead / injured / recovered. Being downed
	# mid-battle must not pre-classify anyone as killed. Same rule the played path
	# already applies when it routes downed crew into injuries_data.
	var downed: Array = []
	var crew_standing: int = 0
	for i in range(crew_units.size()):
		var unit = crew_units[i]
		if unit.is_dead or unit.health <= 0:
			downed.append(i)
		else:
			crew_standing += 1
	prefill["downed_crew_indices"] = downed

	if not prefill.has("rounds"):
		prefill["rounds"] = maxi(1, current_turn)
	if not prefill.has("victory"):
		prefill["victory"] = enemies_down >= enemy_units.size() \
			and crew_standing > 0
	if not prefill.has("held_field"):
		prefill["held_field"] = bool(prefill["victory"])
	return prefill

func _defeated_enemy_records() -> Array:
	## The single builder for the `defeated_enemies` contract, shared by all four
	## result paths (played, manual Record Result prefill, in-battle auto-resolve,
	## "It's Time To Go").
	##
	## THE GAP THIS CLOSES: each path built its own version and they disagreed.
	## The in-battle auto-resolve path hardcoded [], so RivalPatronResolver could
	## never chase a Rival off after an auto-resolved battle; two others omitted
	## was_specialist / was_unique_individual, which the post-battle XP reads.
	## Consolidated on the richest shape so no consumer is starved by which
	## button the player happened to press.
	var records: Array = []
	for unit in enemy_units:
		if unit.is_dead or unit.health <= 0:
			records.append({
				"name": unit.node_name,
				"type": unit.enemy_type if "enemy_type" in unit else "",
				"was_lieutenant": unit.is_lieutenant \
					if "is_lieutenant" in unit else false,
				"was_specialist": unit.is_specialist \
					if "is_specialist" in unit else false,
				"was_unique_individual": unit.is_unique_individual \
					if "is_unique_individual" in unit else false,
			})
	return records

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
	# BattleRoundHUD gates its End-Phase auto-prompt (the "morale check needed /
	# roll d100 for a Battle Event" reminder) on its OWN _display_tier, which
	# defaults to 0 and was never set from here — set_display_tier() had zero
	# callers repo-wide. So _update_auto_prompt() hit `if _display_tier < 1:` and
	# hid the prompt at EVERY tier, including FULL_ORACLE. This is the single
	# place a tier change is applied, so it is the correct hook.
	if battle_round_hud and is_instance_valid(battle_round_hud) \
			and battle_round_hud.has_method("set_display_tier"):
		battle_round_hud.set_display_tier(tier)
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
	# No "oracle" button at tier 2: its drawer body was never populated, so it
	# opened blank. The AI oracle is an intent layer on top of the per-figure
	# enemy cards and lives in the "enemies" drawer (see _instance_oracle_components
	# and the reparent in _populate_unit_drawer).
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
	# The HUD counts casualties PER ROUND to size its End-Phase morale prompt
	# (Core Rules p.114: roll 1D6 per figure lost THIS round). reset_round_tracking()
	# had zero callers, so _casualties_this_round accumulated across the whole
	# battle and round 4 would claim every casualty since round 1.
	if battle_round_hud and is_instance_valid(battle_round_hud) \
			and battle_round_hud.has_method("reset_round_tracking"):
		battle_round_hud.reset_round_tracking()
	_reset_all_unit_reactions()
	# Tick down battle event overlay durations (fog/hazard/reinforcement markers expire)
	if battlefield_grid_panel and battlefield_grid_panel.has_method("tick_overlay_durations"):
		battlefield_grid_panel.tick_overlay_durations()
	# Advance objective progress (auto-derives rounds_survived + turn countdown)
	if _objective_tracker != null:
		_objective_tracker.on_round_advanced(round_number)
	# Story Event 5 marker decay (Core Rules p.157: "At the end of Round 3 and
	# each round thereafter, roll 1D6 for every remaining marker").
	if story_marker_panel != null and is_instance_valid(story_marker_panel):
		story_marker_panel.on_round_advanced(round_number)
		_refresh_objective_panel()

func _on_round_ended(round_number: int) -> void:
	## Handle round end
	_log_message("=== ROUND %d COMPLETE ===" % round_number, UIColors.COLOR_AMBER)

	# DLC: Escalating Battles check (Compendium pp.46-48)
	_check_escalating_battles(round_number)

	# Compendium p.34 "Time is Running Out" — the three options that resolve at
	# the end of a round.
	_check_movement_all_over(round_number)
	_check_fickle_scans(round_number)
	_check_paying_by_the_hour(round_number)


func _check_movement_all_over(round_number: int) -> void:
	## Compendium p.34, verbatim: "At the end of each round, including the first,
	## roll 1D6. If the roll is equal to or below the round number that just
	## elapsed, one additional enemy figure shows up. This means that from Round 6
	## onwards a new enemy will arrive every round.
	##
	## Place the arriving enemy at the center of a random battlefield edge (roll
	## 1D6: 1-2 left edge, 3-4 enemy edge, 5-6 right edge). The first enemy that
	## arrives is a basic enemy, the second is a specialist, with all remaining
	## reinforcements being basic enemies."
	if not CompendiumDifficultyTogglesRef.is_toggle_active("movement_all_over"):
		return
	var roll: int = randi_range(1, 6)
	if roll > round_number:
		_log_message(
			"Movement all over the Place: 1D6 = %d vs round %d — no arrival."
			% [roll, round_number], UIColors.COLOR_TEXT_SECONDARY)
		return

	_movement_all_over_arrivals += 1
	# "The first enemy that arrives is a basic enemy, the second is a specialist,
	# with all remaining reinforcements being basic enemies." Second only.
	var arrival_role: String = "specialist" if _movement_all_over_arrivals == 2 else "basic"
	var edge_roll: int = randi_range(1, 6)
	var edge: String = "left edge"
	if edge_roll >= 5:
		edge = "right edge"
	elif edge_roll >= 3:
		edge = "enemy edge"
	_log_message(
		"Movement all over the Place: 1D6 = %d vs round %d — a %s enemy arrives at the centre of the %s (1D6 = %d)."
		% [roll, round_number, arrival_role, edge, edge_roll], UIColors.COLOR_AMBER)


func _check_fickle_scans(round_number: int) -> void:
	## Compendium p.34: "Any Notable Sight that has not been investigated by the
	## end of Round 3 is removed from play."
	if round_number != 3 or _fickle_scans_resolved:
		return
	if not CompendiumDifficultyTogglesRef.is_toggle_active("fickle_scans"):
		return
	_fickle_scans_resolved = true
	# The mission dict on this screen is _stored_mission_data — a Variant, so it
	# is shape-checked before use like every other read of it in this file.
	if not (_stored_mission_data is Dictionary):
		return
	var md: Dictionary = _stored_mission_data
	var sight: Dictionary = md.get("notable_sight", {})
	if sight.is_empty():
		return
	md["notable_sight_removed"] = true
	_log_message(
		"Fickle Scans: the Notable Sight (%s) was not investigated by the end of Round 3 and is removed from play."
		% str(sight.get("name", "unknown")), UIColors.COLOR_AMBER)
	_refresh_objective_panel()


func _check_paying_by_the_hour(round_number: int) -> void:
	## Compendium p.34: "When setting up, roll two D6, pick the highest die and
	## add 4 (for a final total of 5-10). After the conclusion of this round, the
	## only objectives that can still be achieved are Defend and Fight Off."
	##
	## The limit itself is rolled once at setup (_roll_paying_by_the_hour_limit);
	## this only announces the moment it expires. The book does NOT end the
	## battle here — play continues, but every other objective is off the table.
	if _paying_by_hour_limit <= 0 or _paying_by_hour_expired:
		return
	if round_number < _paying_by_hour_limit:
		return
	_paying_by_hour_expired = true
	if _stored_mission_data is Dictionary:
		(_stored_mission_data as Dictionary)["time_limit_expired"] = true
	_log_message(
		"They are Paying us by the Hour: the clock ran out at the end of Round %d."
		% round_number + " Only Defend and Fight Off objectives can still be achieved.",
		UIColors.COLOR_AMBER)
	_refresh_objective_panel()


func _roll_paying_by_the_hour_limit() -> void:
	## Compendium p.34: "When setting up, roll two D6, pick the highest die and
	## add 4 (for a final total of 5-10)."
	if not CompendiumDifficultyTogglesRef.is_toggle_active("paying_by_hour"):
		return
	var a: int = randi_range(1, 6)
	var b: int = randi_range(1, 6)
	_paying_by_hour_limit = maxi(a, b) + 4
	_paying_by_hour_expired = false
	if _stored_mission_data is Dictionary:
		(_stored_mission_data as Dictionary)["round_limit"] = _paying_by_hour_limit
	_log_message(
		"They are Paying us by the Hour: 2D6 = %d/%d, highest + 4 — the job runs for %d rounds."
		% [a, b, _paying_by_hour_limit], UIColors.COLOR_AMBER)

func _on_battle_event_triggered(round_num: int, _event_type: String) -> void:
	## Handle battle event trigger (end of Rounds 2 and 4, Core Rules pp.116-117)
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
	# Second seeding attempt: on the pre-selected-tier fast path the tier can be
	# applied before _battle_context exists. Guarded internally, so whichever call
	# gets there first wins and the other is a no-op.
	_seed_morale_tracker()
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

func _round_one_condition_note() -> String:
	## Core Rules p.88 deployment conditions whose effect lands ONLY in round 1.
	## BattleSetupRules computes these into setup_rules.round_one; before this
	## they were computed and read by nothing, so a Caught Off Guard crew acted
	## normally and a Delayed crew all started on the table.
	if current_turn > 1:
		return ""
	var setup_rules: Dictionary = _stored_mission_data.get("setup_rules", {}) \
		if _stored_mission_data is Dictionary else {}
	var r1: Dictionary = setup_rules.get("round_one", {})
	if r1.is_empty():
		return ""
	var notes: Array[String] = []
	if bool(r1.get("crew_all_slow", false)):
		notes.append("Caught Off Guard — your ENTIRE crew acts in Slow Actions this round, whatever they rolled.")
	if bool(r1.get("enemy_skips", false)):
		notes.append("Surprise Encounter — the enemy does not act at all this round.")
	var delayed: int = int(r1.get("delayed_crew", 0))
	if delayed > 0:
		notes.append("Delayed — %d crew start OFF the table. At the end of each round roll 1D6 per absent figure; they arrive on a roll at or under the round number." % delayed)
	if notes.is_empty():
		return ""
	return "\n⚠ Round 1: " + "  ".join(notes)

func _show_quick_actions_ui() -> void:
	## QUICK ACTIONS — surface ActivationTrackerPanel for crew checklist
	_clear_action_buttons()
	_set_phase_instruction(1, "Quick Actions",
		"Crew who passed their reaction roll act now. Move and act each on the table, then mark them done."
			+ _round_one_condition_note())
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
	# The book's AI instructions (base condition + 1D6 table + activation order)
	# go to EVERY tier — the tier gates AUTOMATION, not INSTRUCTIONS. Previously
	# this card was built only in the `elif` below, so a LOG_ONLY player running
	# the enemy entirely by hand got no AI guidance at all.
	if not _battle_context.is_empty():
		_surface_custom_phase_content(_build_enemy_action_content())
		if right_tabs: right_tabs.current_tab = 2

	# At FULL_ORACLE tier the interactive oracle lives in its own drawer, reachable
	# from the toolbar's Oracle button. It is NOT surfaced as phase content: the
	# phase content is the book reference card above, which every tier needs.
	if tier_controller and tier_controller.current_tier >= 2:
		# F8 fix (kept): enemy_intent_panel can be invalid by combat — it is the
		# one phase component freed during the SETUP->COMBAT rebuild. Recreate if
		# invalid, mirroring the recreate-if-null pattern used elsewhere.
		if not is_instance_valid(enemy_intent_panel):
			enemy_intent_panel = _get_res("enemy_intent").new()
			enemy_intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enemy_intent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if phase_content:
				phase_content.add_child(enemy_intent_panel)
			_activate_enemy_oracle.call_deferred()
		if right_tabs: right_tabs.current_tab = 2
	elif _battle_context.is_empty():
		_surface_phase_component(null)
		if right_tabs: right_tabs.current_tab = 1
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	var enemy_name: String = ef.get("type", "enemies")
	# Snap Fire holders. The card already flags each holder individually, but the
	# player is looking at the ENEMY half of the table during this phase and has
	# no reason to scroll the crew cards — so whoever is holding was invisible at
	# exactly the moment their hold matters. Errata v1.06 also clarifies that a
	# snap shot may be taken at ANY point of the enemy's move, not only at its
	# end, which is the part that decides where to interrupt.
	var snap_holders: Array[String] = []
	for unit in crew_units:
		if "is_holding_snap" in unit and unit.is_holding_snap \
				and not unit.is_dead and unit.health > 0:
			snap_holders.append(str(unit.node_name))
	var snap_line: String = ""
	if not snap_holders.is_empty():
		snap_line = "\n⚡ Holding Snap Fire: %s — may shoot at ANY point of an enemy's move (errata v1.06), not only when it stops." \
			% ", ".join(snap_holders)
	_set_phase_instruction(2, "Enemy Actions",
		"Resolve %s actions on the table — move each toward its target per its AI, and fire if in range.%s%s"
			% [enemy_name, snap_line, _round_one_condition_note()])
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

func _add_psionic_legality_section(vbox: VBoxContainer) -> void:
	## The world's psionic legality changes what using a power costs you
	## (Compendium pp.20-22), and the action card never mentioned it.
	##
	## The "Highly unusual" band is 26-55 on the D100 — roughly a THIRD of all
	## worlds — and its entire consequence was unreachable: p.22 says "Every time
	## you use a psionic power, if two or more of the Projection roll dice show
	## 6s... the enemy is going to call for reinforcements", and
	## PsionicSystem.check_highly_unusual_reinforcements() implemented it
	## correctly with ZERO callers. The player was never told to look at their
	## dice, so the reinforcements never came.
	var PsiRef = load("res://src/core/systems/PsionicSystem.gd")
	if PsiRef == null:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return
	var campaign = gs.current_campaign
	if not ("progress_data" in campaign):
		return
	var legality: int = int(campaign.progress_data.get("psionic_legality", -1))
	if legality < 0:
		return

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "THIS WORLD: Psionics are %s." % PsiRef.get_legality_name(legality)
	status.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(status)

	if legality == PsiRef.PsionicLegality.OUTLAWED:
		var outlawed := Label.new()
		outlawed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outlawed.text = ("OUTLAWED: using a power risks detection. A D6 is rolled after "
			+ "the battle — caught on a 1 if you used a power once, on a 1-2 if more "
			+ "than once. Psi-hunters become a Rival (Compendium p.21).")
		outlawed.add_theme_font_size_override("font_size", 12)
		outlawed.add_theme_color_override("font_color", UIColors.COLOR_DANGER)
		vbox.add_child(outlawed)
		return

	if legality != PsiRef.PsionicLegality.HIGHLY_UNUSUAL:
		return

	var attention := Label.new()
	attention.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attention.text = ("DRAWS ATTENTION: if TWO OR MORE of your Projection dice "
		+ "showed a 6, the enemy calls for reinforcements (Compendium p.22).")
	attention.add_theme_font_size_override("font_size", 12)
	attention.add_theme_color_override("font_color", UIColors.COLOR_WARNING)
	vbox.add_child(attention)

	if _psionic_reinforcements_arrived:
		var spent := Label.new()
		spent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spent.text = "Reinforcements have already arrived this battle — they come only once."
		spent.add_theme_font_size_override("font_size", 12)
		spent.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		vbox.add_child(spent)
		return

	var roll_btn := Button.new()
	roll_btn.text = "Two or more 6s — roll reinforcements"
	roll_btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	roll_btn.pressed.connect(_on_psionic_reinforcements_pressed)
	vbox.add_child(roll_btn)

func _on_psionic_reinforcements_pressed() -> void:
	## Compendium p.22: "Roll three D6 and check each die" — 1 none, 2-5 a basic
	## enemy, 6 an enemy Specialist. "Reinforcements will arrive at the end of the
	## next round unless you have cleared the table of opponents by then...
	## Reinforcements can arrive only once in each battle, and arrive at the
	## center of the enemy table edge."
	if _psionic_reinforcements_arrived:
		return
	_psionic_reinforcements_arrived = true
	var PsiRef = load("res://src/core/systems/PsionicSystem.gd")
	if PsiRef == null:
		return
	var rolled: Array[String] = PsiRef._roll_highly_unusual_reinforcements()
	var text: String = PsiRef.get_reinforcement_text(rolled)
	_log_message("PSIONIC ATTENTION — %s Arriving at the END OF THE NEXT ROUND." % text,
		UIColors.COLOR_WARNING)
	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_warning"):
		notif.show_warning(text)

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

	_add_psionic_legality_section(vbox)

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

		# Activation ORDER — Core Rules p.113, verbatim: "enemy figures begin with
		# those closest to the player's battlefield edge, then progress away
		# towards the opposing battlefield edge. If two figures are equally close,
		# start on their left side." The player has to get this right on the table
		# and it was surfaced nowhere in the app.
		lines.append("")
		lines.append("[b]Order:[/b] nearest YOUR edge first, working away. "
			+ "Ties: start on their left.")

		# The book's actual AI instructions for this type (base condition + 1D6).
		lines.append_array(_ai_reference_lines(ai_code))
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
		# "Enemy Morale is +1" (p.88) is ambiguous where morale IS the Panic
		# range. Compendium p.49 settles it: improved Morale = a SMALLER Panic
		# range. Stating the effect beats quoting the ambiguous phrase.
		lines.append(
			"[color=#D97706]Bitter Struggle: enemy Morale improved — their Panic range is 1 narrower, so they are harder to break (p.88).[/color]")

	rtl.text = "\n".join(lines)
	vbox.add_child(rtl)
	return vbox

func _ai_type_name(ai_code: String) -> String:
	## "A" -> "Aggressive". Tolerates a full name already being passed in.
	var code: String = ai_code.strip_edges()
	if AI_CODE_TO_NAME.has(code.to_upper()):
		return AI_CODE_TO_NAME[code.to_upper()]
	return code if code != "" else "Aggressive"


func _ai_reference_lines(ai_code: String) -> Array:
	## The BOOK's AI instructions for this enemy: base condition, then the 1D6
	## behaviour table (Core Rules pp.113-115, data/RulesReference/EnemyAI.json).
	##
	## Shown at EVERY tier. The tier gates AUTOMATION, never INSTRUCTIONS — a
	## LOG_ONLY player is running the enemy by hand off this text and needs it MORE
	## than a FULL_ORACLE player does, not less. Before this, the only AI guidance
	## anywhere in the battle was a one-line AI_DESCRIPTIONS summary.
	var lines: Array = []
	if _ai_reference_router == null:
		_ai_reference_router = EnemyAIOracleRouterClass.new()
	if _ai_reference_router == null:
		return lines

	var type_name: String = _ai_type_name(ai_code)
	var data: Dictionary = {}
	if _ai_reference_router.has_method("_find_ai_type"):
		data = _ai_reference_router._find_ai_type(type_name)
	if data.is_empty():
		return lines

	var base: String = str(data.get("base_condition", ""))
	if base != "":
		lines.append("")
		lines.append("[b]Base condition[/b] — check this FIRST:")
		lines.append("  [color=#4FC3F7]%s[/color]" % base)

	var note: String = str(data.get("note", ""))
	if note != "":
		lines.append("  [color=#808080]%s[/color]" % note)

	var table: Array = data.get("behavior_table", [])
	if not table.is_empty():
		lines.append("")
		lines.append("[b]Otherwise roll 1D6:[/b]")
		for entry in table:
			if entry is Dictionary:
				lines.append("  [b]%s[/b]  %s" % [
					str(entry.get("roll", "?")), str(entry.get("action", ""))])

	lines.append_array(_ai_errata_lines(type_name))
	return lines


func _ai_errata_lines(type_name: String) -> Array:
	## Official errata v1.06 clarifications to the AI rules. These change how the
	## player runs the enemy turn and appear in NEITHER rulebook, so a player
	## working off the printed page would get them wrong — which makes the oracle
	## reference card the only place they can be surfaced.
	var out: Array = []
	var name_lc: String = type_name.to_lower()

	# Applies to every AI type: "Unless constrained by a special rule, the AI is
	# assumed to always be aware of your characters and should act accordingly,
	# even if they are behind a terrain feature."
	out.append("")
	out.append("[color=#808080][i]Errata: the AI always knows where your crew are — even behind terrain — unless a special rule says otherwise.[/i][/color]")

	if name_lc.begins_with("defensive"):
		# "Defensive AI considers any terrain within one move to be 'Adjacent'
		# for the purpose of its AI instructions."
		out.append("[color=#D97706][i]Errata: for Defensive AI, any terrain within ONE MOVE counts as \"Adjacent\".[/i][/color]")

	if name_lc.begins_with("guardian"):
		# "If the figure a Guardian AI protects is slain, the Guardian will adopt
		# the AI mode used by the main enemy force."
		out.append("[color=#D97706][i]Errata: if the figure this Guardian protects is slain, it switches to the main force's AI for the rest of the battle.[/i][/color]")

	return out


func _apply_initiative_context() -> void:
	## Hand the campaign-computed Seize the Initiative modifiers to the calculator
	## that actually rolls (Core Rules p.112).
	##
	## THE BUG THIS FIXES: mission_data["initiative_context"] had exactly two
	## references in the whole repo — written by CampaignTurnController, read by
	## PreBattleUI to draw a probability. It never reached the roll. The calculator
	## sourced every modifier from checkboxes the player had to tick by hand, so
	## the app told you "you need 9+ on 2D6" and then rolled against an unmodified
	## target: Hardcore -2, Insanity -3 and the outnumbered +1 were all displayed
	## and then silently dropped.
	if not (initiative_calculator and is_instance_valid(initiative_calculator)):
		return
	if not initiative_calculator.has_method("apply_initiative_context"):
		return
	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}
	var ctx: Dictionary = md.get("initiative_context", {})
	if ctx is Dictionary and not ctx.is_empty():
		initiative_calculator.apply_initiative_context(ctx)


func _on_initiative_calculated(result) -> void:
	## Record the seize outcome where the battle briefing already looks for it.
	##
	## _build_battlefield_intel renders an "INITIATIVE: SEIZED / not seized" block
	## from _battle_context["seize_initiative_result"] — a key NOTHING in the repo
	## ever wrote, so that block was dead. The calculator's result only ever
	## reached the log feed.
	if result == null:
		return
	var seized: bool = false
	var total: int = 0
	if "success" in result:
		seized = bool(result.success)
	if "roll_total" in result:
		total = int(result.roll_total)
	elif "total" in result:
		total = int(result.total)
	_battle_context["seize_initiative_result"] = {
		"success": seized,
		"roll_total": total,
	}
	# Core Rules p.112: on 10+ every crew figure may either Move or fire before
	# round 1, and those shots only Hit on a natural 6.
	if seized:
		_log_message(
			"INITIATIVE SEIZED (%d) — each crew figure may Move OR fire now. "
			% total + "Shots Hit only on a natural 6.",
			UIColors.COLOR_EMERALD)
	else:
		_log_message("Initiative not seized (%d) — begin Round 1 normally."
			% total, UIColors.COLOR_TEXT_SECONDARY)

	_apply_enemy_deployment_variable(seized)


## Compendium pp.44-45 Enemy Deployment Variables. p.44 keys the whole rule off
## this exact moment: "Set up both sides normally and roll to Seize the
## Initiative. If you fail, roll D100 on the table below, using the AI type to
## calculate which deployment type the enemy will use. If you successfully Seize
## the Initiative, the enemy will always use the Line (i.e. standard) deployment
## option."
##
## deployment_variables.json held all six AI columns, byte-correct, with ZERO
## loaders — so a player who owned the Freelancer's Handbook and switched this on
## got standard deployment in every battle of every campaign.
func _apply_enemy_deployment_variable(seized: bool) -> void:
	var force: Dictionary = _battle_context.get("enemy_force", {})
	if force.is_empty() and _stored_mission_data is Dictionary:
		force = _stored_mission_data.get("enemy_force", {})
	var deployment: Dictionary = CompendiumDeploymentVariablesRef.roll_deployment(
		str(force.get("ai", "")), seized)
	if deployment.is_empty():
		return

	_battle_context["enemy_deployment_variable"] = deployment
	_log_message("ENEMY DEPLOYMENT — %s. %s" % [
		str(deployment.get("name", "Line")), str(deployment.get("reason", ""))],
		Color("#D97706"))
	_log_message(str(deployment.get("instruction", "")), Color("#4FC3F7"))
	# Infiltration and Concealed put figures on the table mid-battle, so the
	# placement clarification only matters for those two.
	if str(deployment.get("id", "")) in ["infiltration", "concealed"]:
		_log_message(
			CompendiumDeploymentVariablesRef.get_arrival_placement_note(),
			UIColors.COLOR_TEXT_SECONDARY)
	if unified_log:
		unified_log.add_entry("event", "Enemy deployment: %s"
			% str(deployment.get("name", "Line")))


func _activate_enemy_oracle() -> void:
	## Turn the oracle on and seed it with the force we already know about, so the
	## player is not asked to hand-enter an enemy group and its AI type that the
	## app generated itself. Core Rules pp.91-94: one enemy type per battle.
	if not (enemy_intent_panel and is_instance_valid(enemy_intent_panel)):
		return
	if enemy_intent_panel.has_method("activate_oracle"):
		enemy_intent_panel.activate_oracle()
	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}
	var ef: Dictionary = _battle_context.get("enemy_force", md.get("enemy_force", {}))
	var type_name: String = _ai_type_name(str(ef.get("ai", "A")))
	if enemy_intent_panel.has_method("set_ai_behavior_type"):
		enemy_intent_panel.set_ai_behavior_type(type_name)


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

	# Step: Morale check. Core Rules p.114 — the enemy tests ONLY if it lost
	# figures this round, one die per figure lost. Say which it is, and when there
	# is nothing to roll say so instead of leaving a box the player must reason about.
	step_num += 1
	var enemy_losses: int = 0
	if morale_tracker and is_instance_valid(morale_tracker) \
			and "casualties_this_round" in morale_tracker:
		enemy_losses = int(morale_tracker.casualties_this_round)
	if enemy_losses > 0:
		vbox.add_child(_make_checklist_step(
			step_num, "Morale: roll %dD6 (enemy lost %d). Each die in the Bail range removes one, closest to their edge first."
				% [enemy_losses, enemy_losses],
			_resolve_end_phase_morale, "Roll morale"))
	else:
		vbox.add_child(_make_checklist_step(
			step_num, "Morale: no enemy figures lost this round — no check.",
			Callable(), "", true))

	# Step: the enemy may give up once your objective is met (Core Rules
	# pp.114-115). This prompt did not exist anywhere in the app, so a player who
	# completed their objective had no way to learn the battle could end here.
	var giveup: Dictionary = _giveup_check_info()
	if not giveup.is_empty():
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num, giveup["text"],
			_on_giveup_roll_pressed if giveup["rollable"] else Callable(),
			"Roll", not giveup["rollable"]))

	# Step: Deployment condition round checks. Each opens the Dice drawer with the
	# roll named, rather than telling the player to go find it.
	var open_dice: Callable = func() -> void: _open_drawer("dice")

	if cond_id == "BRIEF_ENGAGEMENT":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Brief Engagement: Roll 2D6 — on %d or less, battle ends" % round_num,
			open_dice, "2D6"))

	if cond_id == "DELAYED" and round_num >= 2:
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Delayed crew: Roll 1D6 — on %d or less, they arrive at your edge" % round_num,
			open_dice, "1D6"))

	if cond_id == "TOXIC_ENVIRONMENT":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Toxic Environment: Stunned units roll 1D6+Savvy, below 4 = casualty",
			open_dice, "1D6"))

	if cond_id == "POOR_VISIBILITY":
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Reroll visibility: 1D6+8\" maximum range for next round",
			open_dice, "1D6"))

	# Step: Battle Event — end of Round 2 and Round 4 only (Core Rules pp.116-117).
	if round_num == 2 or round_num == 4:
		step_num += 1
		vbox.add_child(_make_checklist_step(
			step_num,
			"Battle Event: Roll D100 (Core Rules p.116)",
			func() -> void: _on_battle_event_triggered(round_num, "end_phase"),
			"Roll D100"))

	# Step: objective / battle end (always). Reads the live tracker so it states
	# where the battle actually stands instead of asking an open question.
	step_num += 1
	var enemies_up: int = 0
	for unit in enemy_units:
		if not unit.is_dead and unit.health > 0:
			enemies_up += 1
	if enemies_up == 0:
		vbox.add_child(_make_checklist_step(
			step_num,
			"No enemies left standing — you Hold the Field. Record the result.",
			_on_record_result_pressed, "Record"))
	else:
		var obj_line: String = "%d enemy figure%s still standing." % [
			enemies_up, "" if enemies_up == 1 else "s"]
		if _objective_tracker != null and _objective_tracker.has_objective():
			obj_line += "  Objective: %s" % (
				"COMPLETE" if _objective_tracker.is_complete() else "not yet met")
		vbox.add_child(_make_checklist_step(step_num, obj_line, Callable(), "", true))

	return vbox

func _make_checklist_step(number: int, text: String,
		action: Callable = Callable(), action_label: String = "",
		resolved: bool = false) -> HBoxContainer:
	## One end-of-round step. When the step has something to roll it carries a
	## button that DOES it; steps that do not apply this round arrive already
	## ticked with an explanation.
	##
	## These rows used to be bare CheckBoxes with no signal and no state — purely
	## decorative. The player read "Morale check" and then had to go find the
	## morale panel themselves, which is the opposite of what a companion is for.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var check := CheckBox.new()
	check.custom_minimum_size = Vector2(
		UIColors.TOUCH_TARGET_MIN, UIColors.TOUCH_TARGET_MIN)
	check.button_pressed = resolved
	check.accessibility_name = "Step %d done" % number
	hbox.add_child(check)

	var lbl := Label.new()
	lbl.text = "%d. %s" % [number, text]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY if resolved
			else UIColors.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)

	if action.is_valid() and not resolved:
		# A Button (not a CheckBox) so it gets keyboard/controller focus and a
		# focus ring for free, per the Godot 4 GUI navigation defaults.
		var btn := Button.new()
		btn.text = action_label if action_label != "" else "Roll"
		btn.custom_minimum_size = Vector2(96, UIColors.TOUCH_TARGET_MIN)
		btn.accessibility_name = "%s: %s" % [btn.text, text]
		btn.pressed.connect(func() -> void:
			action.call()
			check.button_pressed = true)
		hbox.add_child(btn)

	return hbox


func _giveup_check_info() -> Dictionary:
	## Core Rules pp.114-115: once you have achieved your objective's Win
	## condition, at the end of the current and EVERY subsequent round roll to see
	## if the enemy gives up — 2D6 for Cautious / Defensive / Tactical opponents,
	## 1D6 for Aggressive. "If either die is a natural 1, the enemy withdraws and
	## the battle ends immediately, with you Holding the Field." Rampaging and
	## Beast opponents never give up: they "fight until either side has completely
	## left the table."
	##
	## Returns {} when the check does not apply this round.
	if _objective_tracker == null or not _objective_tracker.has_objective():
		return {}
	if not _objective_tracker.is_complete():
		return {}
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	var ai: String = str(ef.get("ai", "A")).to_upper()
	var name: String = str(ef.get("type", "The enemy"))
	if ai in ["R", "B"]:
		return {
			"text": "%s will NOT give up (%s) — they fight until one side leaves the table."
				% [name, _ai_type_name(ai)],
			"rollable": false,
		}
	var dice: int = 1 if ai == "A" else 2
	return {
		"text": "Objective complete — roll %dD6 for %s to give up. A natural 1 on either die ends the battle; you Hold the Field."
			% [dice, name],
		"rollable": true,
	}


func _on_giveup_roll_pressed() -> void:
	## Roll the enemy give-up check and, on a natural 1, end the battle with the
	## field held (Core Rules p.115). Routed to the Record Result form pre-filled
	## as a win rather than resolving it silently — the player still confirms what
	## happened on their table.
	var ef: Dictionary = _battle_context.get("enemy_force", {})
	var ai: String = str(ef.get("ai", "A")).to_upper()
	var dice: int = 1 if ai == "A" else 2
	var rolls: Array[int] = []
	var withdrew: bool = false
	for _i in range(dice):
		var r: int = randi_range(1, 6)
		rolls.append(r)
		if r == 1:
			withdrew = true
	var roll_text: String = ", ".join(
		PackedStringArray(rolls.map(func(r): return str(r))))
	if withdrew:
		_log_message("Give up: rolled %s — the enemy WITHDRAWS. You Hold the Field."
			% roll_text, UIColors.COLOR_EMERALD)
		if unified_log:
			unified_log.log_victory("Enemy withdrew (give-up roll %s)" % roll_text)
		_on_record_result_pressed()
	else:
		_log_message("Give up: rolled %s — they stay. Roll again next round."
			% roll_text, UIColors.COLOR_TEXT_SECONDARY)

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
	## The Reaction Roll (Core Rules p.113) — now the ONLY roll.
	##
	## THE BUG THIS FIXES: there were TWO. _assign_crew_reaction_slots() rolled a
	## die per figure and set react_slot, which drives the Quick/Slow rails.
	## This function — the button the player actually presses — rolled AGAIN,
	## wrote initiative_roll, logged that second result and never touched
	## react_slot. The numbers shown to the player were not the numbers the app
	## acted on, and pressing the button twice produced a third answer.
	##
	## Also implements the pool semantics the book describes ("Roll a number of D6
	## equal to the number of your characters. Assign each of the dice results to
	## one of your characters") and the Feral Impetuous Actions constraint, which
	## existed nowhere.
	_assign_crew_reaction_slots(true)
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

func _setup_story_marker_panel(mission_dict: Dictionary) -> void:
	## Story Track Event 5 "Kidnap" (Core Rules p.157): six markers, investigated
	## by approach, yielding the Evidence that unlocks Event 6. Nothing else in
	## the game produces Evidence, so without this panel the p.157 search could
	## only ever crawl forward on its automatic +1 per failed roll.
	if story_marker_panel != null:
		return
	if str(mission_dict.get("story_event_id", "")) != "kidnap":
		return

	var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
	var event: Variant = null
	if cpm != null and "story_track" in cpm and cpm.story_track != null:
		if cpm.story_track.has_method("get_current_event"):
			event = cpm.story_track.get_current_event()

	story_marker_panel = _get_res("story_marker_panel").new()
	story_marker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom_content: VBoxContainer = bottom_bar.get_child(0) \
		if bottom_bar and bottom_bar.get_child_count() > 0 else null
	if bottom_content and bottom_content is VBoxContainer:
		bottom_content.add_child(story_marker_panel)
		bottom_content.move_child(story_marker_panel, 0)
	else:
		# No bottom bar on this layout — drop the panel rather than leaking it.
		story_marker_panel.queue_free()
		story_marker_panel = null
		push_warning("TacticalBattleUI: no bottom_content for StoryMarkerPanel")
		return

	story_marker_panel.setup(event, dice_manager)
	story_marker_panel.evidence_changed.connect(_on_story_evidence_changed)
	story_marker_panel.markers_resolved.connect(_on_story_markers_resolved)
	_log_message(
		"Story Event 5: place 6 markers, crew no closer than 8\" to any of them.",
		UIColors.COLOR_AMBER)

func _on_story_evidence_changed(total: int) -> void:
	_log_message("Evidence uncovered — %d piece(s) so far." % total,
		UIColors.COLOR_EMERALD)
	# Park the tally on mission_data rather than on one result dict. There are
	# FOUR tactical_battle_completed.emit() sites (played, evacuation, in-battle
	# auto-resolve, map auto-resolve) and mission_data is what every one of them
	# carries into BattleResultNormalizer — the single chokepoint. Stamping here
	# means no emission path can silently drop the Evidence.
	if _stored_mission_data is Dictionary:
		_stored_mission_data["story_evidence_found"] = total

func _on_story_markers_resolved() -> void:
	## p.157: "The mission ends once all markers have been revealed or removed."
	_log_message(
		"All markers resolved — the mission ends. Record your result.",
		UIColors.COLOR_AMBER)

func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void:
	## Initialize the tactical battle
	_battle_initialized = true
	_log_message("Initializing tactical battle...", UIColors.COLOR_CYAN)

	# Compendium p.34: "When setting up, roll two D6, pick the highest die and
	# add 4." Rolled here, once, so the limit is fixed for the whole battle.
	_movement_all_over_arrivals = 0
	_fickle_scans_resolved = false
	_roll_paying_by_the_hour_limit()

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
	_apply_initiative_context()

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

	# Story Track Event 5 marker tracker (Core Rules p.157). MUST be set up above
	# the pre-selected-tier early return below — that branch is the normal
	# campaign path, so anything wired after it never runs in a real campaign.
	_setup_story_marker_panel(mission_dict)

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

	# Core Rules p.88 Deployment Conditions — show the condition that was ROLLED.
	#
	# THE BUG THIS FIXES: DeploymentConditionsPanel has roll_condition() and
	# display_condition() and NOTHING called either, so the panel rendered blank
	# for every battle while its Acknowledge/Details buttons sat wired to an
	# empty panel. The condition itself was never missing — CampaignTurnController
	# rolls it and stamps mission_data["deployment_condition"] — it simply never
	# reached the one screen built to present it.
	#
	# The panel takes a DeploymentCondition OBJECT and the mission carries the
	# flattened Dictionary, so it is rehydrated by id rather than re-rolled: a
	# second roll here would show the player a different condition from the one
	# the battle is actually being fought under.
	_populate_deployment_conditions(mission_dict)

	# DLC: Wire mission-type-specific panels (Fixer's Guidebook).
	#
	# The panels need the GENERATOR's shape, where `objective` is a Dictionary
	# carrying the roll range, instruction text and has_individual flag. The
	# campaign hand-off (WorldPhaseController) flattens a job to a Patron-shaped
	# literal in which `objective` is a plain String, so it carries the generator
	# payload alongside under `compendium_mission` rather than merging the two
	# incompatible shapes. Fall back to mission_dict for the standalone/battle-
	# simulator paths, which build the generator shape directly.
	var mission_type: String = mission_dict.get("type", "")
	var compendium_payload: Dictionary = mission_dict.get("compendium_mission", mission_dict)
	if mission_type == "stealth":
		_setup_stealth_panel(compendium_payload)
	elif mission_type == "street_fight":
		_setup_street_fight_panel(compendium_payload)
	elif mission_type == "salvage":
		_setup_salvage_panel(compendium_payload)

func _populate_deployment_conditions(mission_dict: Dictionary) -> void:
	## Show the p.88 condition the battle funnel already rolled for THIS battle.
	if deployment_conditions == null or not is_instance_valid(deployment_conditions):
		return

	var stamped: Dictionary = mission_dict.get("deployment_condition", {})
	var condition_id: String = str(stamped.get("condition_id", ""))
	if condition_id.is_empty():
		# p.88's table is ignored during an Invasion, and a Rival ambush can
		# suppress it too, so "no condition stamped" is a legitimate state — hide
		# the panel rather than show an empty one.
		deployment_conditions.hide()
		return

	var DeploySysClass = load("res://src/core/battle/DeploymentConditionsSystem.gd")
	var deploy_sys = DeploySysClass.new()
	var condition = deploy_sys.get_condition_by_id(condition_id)
	if condition == null:
		push_warning(
			"TacticalBattleUI: unknown deployment condition id '%s'" % condition_id)
		deployment_conditions.hide()
		return

	deployment_conditions.display_condition(condition, int(stamped.get("roll", 0)))
	if unified_log:
		unified_log.log_action("Deployment", str(stamped.get("title", condition_id)))


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
		# Core Rules p.118, verbatim: "Stunned figures may Move OR make a Combat
		# Action. Remove one Stun marker after acting." Nothing removed markers
		# anywhere — they were only cleared by a full round reset, so a figure
		# Stunned once stayed Stunned for the rest of the battle and the player
		# had to remember to clear it by hand.
		if unit.stun_markers > 0:
			unit.stun_markers -= 1
			if unified_log:
				unified_log.log_action(char_name,
					"acted while Stunned — remove 1 Stun marker (%d left)"
						% unit.stun_markers)
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
	if feed_morale and not is_crew:
		if morale_tracker and is_instance_valid(morale_tracker):
			# casualties_this_round drives perform_morale_check() at End Phase.
			if morale_tracker.has_method("add_casualty"):
				morale_tracker.add_casualty()
			elif "casualties_this_round" in morale_tracker:
				morale_tracker.casualties_this_round += 1
			# Keep the survivor count honest — it caps how many figures CAN bail.
			# Only on the feed_morale path: perform_morale_check() already
			# subtracts the bails itself, and the bail removal re-enters here
			# with feed_morale=false, so decrementing there would double-count.
			if "enemies_remaining" in morale_tracker:
				morale_tracker.enemies_remaining = maxi(
					0, morale_tracker.enemies_remaining - 1)
		# The HUD keeps its own per-round count for the End-Phase prompt text.
		# Its report_casualty() was only ever called from one legacy "mark unit
		# dead" branch, never from this chokepoint, so the prompt under-reported
		# (usually reading zero) even once the tier gate was fixed.
		if battle_round_hud and is_instance_valid(battle_round_hud) \
				and battle_round_hud.has_method("report_casualty"):
			battle_round_hud.report_casualty()
	_refresh_unit_rails()
	_refresh_glance_chips()
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


func _setup_consumable_button() -> void:
	## "Use Consumable" on the ActionBar. Consumables are a Free Action used from the
	## Stash in battle (Core Rules p.54); this companion shows the effect + tracks depletion.
	if not is_inside_tree() or _consumable_button != null:
		return
	var action_bar: Container = end_turn_button.get_parent() if end_turn_button else null
	if not action_bar:
		return
	_consumable_button = Button.new()
	_consumable_button.text = "💊 Consumable"
	_consumable_button.tooltip_text = "Use a consumable from the Stash (a Free Action in battle)"
	_consumable_button.custom_minimum_size = Vector2(128, _touch_h())
	_consumable_button.pressed.connect(_on_consumable_button_pressed)
	action_bar.add_child(_consumable_button)


func _on_consumable_button_pressed() -> void:
	var eqm = get_node_or_null("/root/EquipmentManager")
	if not eqm or not eqm.has_method("get_stash_consumables"):
		return
	var consumables: Array = eqm.get_stash_consumables()
	if consumables.is_empty():
		_log_message("No consumables in the Stash.", UIColors.COLOR_AMBER)
		return
	var labels: Array = []
	var label_to_id := {}
	for c in consumables:
		var nm: String = str(c.get("name", "Consumable"))
		labels.append(nm)
		label_to_id[nm] = str(c.get("id", ""))
	var PopupScript = load("res://src/ui/components/dialogs/ItemChoicePopup.gd")
	var popup: Window = PopupScript.new()
	popup.item_chosen.connect(func(chosen: String) -> void:
		var cid: String = str(label_to_id.get(chosen, ""))
		if cid != "" and eqm.has_method("use_stash_consumable"):
			var r: Dictionary = eqm.use_stash_consumable(cid)
			if bool(r.get("used", false)):
				_log_message("%s used — %s" % [str(r.get("name", "")), str(r.get("effect", ""))],
					UIColors.COLOR_EMERALD)
		popup.queue_free()
	)
	add_child(popup)
	popup.show_choices("Use a Consumable (Free Action)", labels)


func _on_undo_button_pressed() -> void:
	_undo_last_mutation()


func _refresh_undo_button() -> void:
	if _undo_button == null:
		return
	var has_snap: bool = not _undo_snapshot.is_empty()
	_undo_button.disabled = not has_snap
	_undo_button.text = "↶ Undo %s" % str(_undo_snapshot.get("label", "")) if has_snap else "↶ Undo"


func _assign_crew_reaction_slots(verbose: bool = false) -> void:
	## The Reaction Roll, Core Rules p.113. THE single roll for the round.
	##
	## The book rolls a POOL — "Roll a number of D6 equal to the number of your
	## characters" — and then the player "assign[s] each of the dice results to
	## one of your characters". Rolling one die per figure and pinning it there
	## removes the round's main tactical decision, so this rolls the pool and
	## applies FPCM_ReactionRollPool's best-fit default, which the player can
	## then re-read off the per-figure lines below.
	##
	## Enemies never roll (always the Enemy Actions phase).
	var living: Array = []
	for unit in crew_units:
		if unit.is_dead:
			unit.react_slot = 0
			continue
		living.append(unit)
	if living.is_empty():
		_refresh_unit_rails()
		return

	var dm = get_node_or_null("/root/DiceManager")
	var roller: Callable = Callable()
	if dm and dm.has_method("roll_d6"):
		roller = func() -> int: return dm.roll_d6("Reaction Roll")

	var figures: Array = []
	for i in range(living.size()):
		figures.append({
			"id": str(i),
			"name": str(living[i].node_name),
			"reactions": int(living[i].reactions),
			"is_feral": _unit_is_feral(living[i]),
		})

	var dice: Array[int] = ReactionRollPoolClass.roll_pool(living.size(), roller)
	var assignment: Dictionary = ReactionRollPoolClass.auto_assign(dice, figures)

	var q: int = 0
	var s: int = 0
	for i in range(living.size()):
		var unit = living[i]
		var die: int = int(assignment.get(str(i), 6))
		unit.initiative_roll = die
		unit.react_slot = ReactionRollPoolClass.slot_for(die, unit.reactions)
		if unit.react_slot == ReactionRollPoolClass.SLOT_QUICK:
			q += 1
		else:
			s += 1
		if verbose and unified_log:
			unified_log.log_action("Reaction Roll", "  %s: %d vs Reactions %d — %s" % [
				unit.node_name, die, unit.reactions,
				"QUICK" if unit.react_slot == ReactionRollPoolClass.SLOT_QUICK else "SLOW"])

	if unified_log:
		var pool_txt: String = ", ".join(dice.map(func(d): return str(d)))
		unified_log.log_action("Reaction Roll",
			"Pool [%s] → %d Quick · %d Slow" % [pool_txt, q, s])
		# p.113 Feral Impetuous Actions. Surfaced because it CONSTRAINS the
		# player's assignment, and a player who does not know the rule cannot
		# tell why the app placed the 1 where it did.
		if ReactionRollPoolClass.feral_die_required(dice, figures):
			unified_log.log_action("Reaction Roll",
				"Feral: exactly one 1 was rolled, so it must go to a Feral character (p.113).")
	_refresh_unit_rails()


func _unit_is_feral(unit) -> bool:
	## Feral is a species, so it can arrive as species_id or the legacy origin.
	for key in ["species_id", "origin"]:
		if key in unit and str(unit.get(key)).to_lower() == "feral":
			return true
	var oc = unit.original_character if "original_character" in unit else null
	if oc == null:
		return false
	for key in ["species_id", "origin"]:
		if key in oc and str(oc.get(key)).to_lower() == "feral":
			return true
	return false


func _seed_morale_tracker() -> void:
	## Feed MoralePanicTracker the REAL enemy force (Core Rules p.114).
	##
	## THE BUG THIS FIXES: set_enemy_count() and setup_from_enemy_data() had ZERO
	## callers anywhere in the repo. So total_enemies / enemies_remaining stayed 0,
	## and perform_morale_check() capped its result with
	##   bailable    = maxi(0, enemies_remaining - fearless) -> 0
	##   actual_bails = mini(bails, bailable)                -> 0
	## which made _resolve_end_phase_morale() return at `if bails <= 0` every single
	## time. The End-Phase Morale check — the mechanic that ends most Five Parsecs
	## battles — could never remove a figure. The panel also showed the hardcoded
	## default "Panic: 1-2" with a blank enemy name regardless of who you fought,
	## and Stubborn / Fearless / Dogged were never detected because the special
	## rules were never handed over.
	##
	## Seeded once per battle: set_enemy_count() resets casualties_this_round and
	## fled_enemies, so re-seeding mid-battle would silently erase progress.
	if _morale_seeded:
		return
	if not (morale_tracker and is_instance_valid(morale_tracker)):
		return

	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}
	var ef: Dictionary = _battle_context.get("enemy_force", md.get("enemy_force", {}))
	if ef.is_empty():
		return

	# enemy_force names the type under "type"; setup_from_enemy_data reads "name"
	# (it was written against a raw enemy_types.json entry).
	if morale_tracker.has_method("setup_from_enemy_data"):
		morale_tracker.setup_from_enemy_data({
			"name": ef.get("type", "Unknown"),
			"panic": ef.get("panic", "1-2"),
			"special_rules": ef.get("special_rules", []),
		})

	# Figures actually on the table beats the generator's count — a Unique
	# Individual is added "in addition to those normally encountered" (p.94).
	var figure_count: int = enemy_units.size()
	if figure_count <= 0:
		figure_count = int(ef.get("count", 0))
	if morale_tracker.has_method("set_enemy_count"):
		morale_tracker.set_enemy_count(figure_count)

	# Fearless figures are skipped by the Morale dice and must not be counted as
	# bailable (Core Rules p.114 Fearless, p.105 Unique Individuals).
	var lieutenants: int = 0
	var has_unique: bool = bool(ef.get("has_unique_individual", false))
	for unit in enemy_units:
		if unit.is_lieutenant:
			lieutenants += 1
		if unit.is_unique_individual:
			has_unique = true
	if "lieutenant_count" in morale_tracker:
		morale_tracker.lieutenant_count = lieutenants
	if "unique_individual_present" in morale_tracker:
		morale_tracker.unique_individual_present = has_unique

	# Bitter Struggle (Core Rules p.88): "Enemy Morale is +1". Compendium p.49
	# fixes the direction — its Leadership table is headed "enemy Morale is
	# IMPROVED according to the table below" and every row moves the Panic range
	# DOWN, so improved Morale means a SMALLER Panic range and a harder enemy to
	# break. BattleSetupRules computes the delta; this is the only place that can
	# apply it, because the panic range is not known until the tracker is seeded.
	# Floored at 1: on that same table only Captain-grade leadership reaches 0
	# (Fearless), and a deployment condition is not that.
	var setup_rules: Dictionary = _stored_mission_data.get("setup_rules", {}) \
		if _stored_mission_data is Dictionary else {}
	var panic_delta: int = int(setup_rules.get("panic_range_delta", 0))
	if panic_delta != 0 and "panic_range_max" in morale_tracker:
		var before: int = int(morale_tracker.panic_range_max)
		morale_tracker.panic_range_max = maxi(1, before + panic_delta)
		if unified_log and morale_tracker.panic_range_max != before:
			unified_log.log_action("Morale",
				"Bitter Struggle — enemy Panic range %d → %d (Core Rules p.88)"
					% [before, int(morale_tracker.panic_range_max)])

	_morale_seeded = true
	if unified_log:
		unified_log.log_action("Morale", "%s — Panic %s, %d figures" % [
			ef.get("type", "Enemy"), str(ef.get("panic", "?")), figure_count])


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
	var defeated_enemies: Array = _defeated_enemy_records()

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

	# Convert TacticalUnits to dictionaries for BattleResolver.
	# `_auto_resolve_deployed_units` keeps the TacticalUnit for each entry we
	# push into crew_deployed, IN THE SAME ORDER. Without it the result mapping
	# below indexed crew_units_final (which mirrors the FILTERED crew_deployed)
	# using an index from the UNFILTERED crew_units — see the comment there.
	var crew_deployed: Array = []
	var deployed_units: Array = []
	for unit in crew_units:
		if unit.health > 0:
			deployed_units.append(unit)
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

	# Determine crew casualties from resolver's final state.
	#
	# THE BUG: this walked `crew_units` (ALL crew) but indexed `crew_units_final`
	# (which mirrors `crew_deployed`, FILTERED to health > 0) with the same `i`.
	# Any crew member already down when auto-resolve is triggered — the normal
	# case, since you auto-resolve after taking losses — shifted every later
	# index by one, so THE WRONG CREW MEMBERS TOOK THE CASUALTIES:
	#   crew_units      = [A(down), B, C]
	#   crew_deployed   = [B, C]        -> crew_units_final = [B', C']
	#   i=0: unit A read B' and was reported ALIVE despite being down
	#   i=1: unit B read C' and inherited C's fate
	#   i=2: unit C fell past the end and was judged on its pre-resolve health
	# Now indexed through `deployed_units`, built in lockstep with crew_deployed,
	# and the not-deployed crew are handled explicitly as the casualties they are.
	var crew_units_final: Array = resolver_result.get("crew_units_final", [])
	var fates: Dictionary = {}  # TacticalUnit -> is_alive
	for i in range(deployed_units.size()):
		var alive: bool = true
		if i < crew_units_final.size():
			alive = crew_units_final[i].get("is_alive", true)
		fates[deployed_units[i]] = alive
	for unit_pre in crew_units:
		if not fates.has(unit_pre):
			# Not deployed => already at 0 health when auto-resolve started.
			fates[unit_pre] = false

	for unit in crew_units:
		var is_alive: bool = fates.get(unit, true)

		if not is_alive and unit.original_character:
			var oc = unit.original_character
			# Compendium pp.99-100 Casualty Tables, when the option is on.
			#
			# These rows are IN-BATTLE outcomes, not a death check. Only "Goner"
			# removes the figure from play; Dazed / Wounded / Knock down /
			# Temporary shutdown / Damaged / Bleeding all leave it standing, and
			# p.100 states those conditions are "removed at the end of the battle
			# and [have] no long-term effects" — so those crew take NO post-battle
			# roll at all. That is the whole point of the option: it "tends to keep
			# combatants in the fight longer than normal" (p.99).
			#
			# The old code read casualty_check["id"] and compared it to
			# "instant_kill"/"dead". These rows carry `outcome`, never `id`, and
			# no row has ever been named either of those — so even once the reader
			# was fixed, every result would have fallen to the injuries branch.
			var is_mech: bool = bool(_oc_field(oc, "is_bot", false)) \
				or bool(_oc_field(oc, "is_soulless", false))
			var casualty_check: Dictionary = _roll_compendium_casualty(
				CompendiumDifficultyTogglesRef.casualty_category_for(is_mech, false),
				bool(_oc_field(oc, "is_captain", false)))
			if not casualty_check.is_empty():
				var outcome: String = str(casualty_check.get("outcome", ""))
				_log_message("%s — %s (D6 %d, %s column): %s" % [
					str(_oc_field(oc, "character_name", _oc_field(oc, "name", "Crew"))),
					outcome, int(casualty_check.get("roll", 0)),
					str(casualty_check.get("column", "regular")),
					str(casualty_check.get("effect", "")),
				], Color("#DC2626") if outcome == "Goner" else Color("#D97706"))
				if outcome != "Goner":
					# Still on their feet. Not a casualty, no post-battle roll.
					continue
				# Removed from play. The post-battle Injury Table decides whether
				# that is death — the casualty table never kills outright.
				result.crew_injuries.append(oc)
			else:
				var death_roll: int = _roll_dice("Death Check", "D6")
				if death_roll <= 2:
					result.crew_casualties.append(oc)
				else:
					result.crew_injuries.append(oc)

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
		# THE GAP THIS FIXES: this path hardcoded []. BattleResultNormalizer walks
		# defeated_enemies to stamp rival kills, and RivalPatronResolver reads
		# those stamps to decide whether a Rival is chased off — so on the
		# in-battle auto-resolve path a Rival could never be removed no matter
		# how comprehensively you beat it. Built the same way as the played path.
		"defeated_enemies": _defeated_enemy_records(),
		"enemies_defeated_count": enemies_defeated_count,
		"enemies_remaining": enemies_deployed.size() \
			- enemies_defeated_count,
		# Core Rules p.123: "Any character that flees the battlefield in the first
		# 2 rounds of the battle receives no XP." That is the ONLY rule this key
		# feeds — ExperienceTrainingProcessor._calculate_crew_xp returns 0 on it.
		# Do NOT widen it to the p.91 Rival threshold ("flee before 4 rounds are
		# up" costs an item); that is a separate rule with a separate window, and
		# carried on setup_rules.flee_before_round.
		# Only the manual Record Result form and the "It's Time To Go" star wrote
		# this key, so an auto-resolved 1-round rout still paid full XP.
		"fled_early": (not held_field) and result.rounds_fought <= 2,
		# The round count the p.91 item-loss check needs, which the XP threshold
		# above cannot express.
		"rounds": result.rounds_fought,
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

# The legacy reaction-dice assignment UI was DELETED here (~90 lines).
# dice_pool_display, character_assignment_list and confirm_assignments_button
# were declared `= null` and NEVER assigned — no @onready, no .new() — so every
# function below them returned at its first `if not <node>` guard and the whole
# feature was unreachable. Its state (reaction_dice_pool, dice_assignments) was
# likewise written by nothing that ran.
#
# Superseded by FPCM_ReactionRollPool + _assign_crew_reaction_slots(), which
# implement the Core Rules p.113 pool properly: one roll, a best-fit default
# assignment, and the Feral Impetuous Actions constraint this version never had.

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

	# Section 5: Compendium GAME OPTIONS the player switched on.
	#
	# These blocks used to read three mission_dict keys — "dlc_difficulty_instructions",
	# "dlc_ai_type" and "dramatic_combat_effects" — that NO producer anywhere ever
	# wrote (proved by the producer/consumer census, scripts/lint_handoff_contracts.py).
	# Every value is derivable right here from the DLC flags, the campaign, and the
	# enemy force the app already generated, so they are built locally now instead of
	# waiting on a stamp that was never going to come.
	var dlc_instructions: Array[String] = _build_compendium_option_instructions()
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
		_add_setup_separator()

	# Escalating Battles (Compendium pp.46-48) keys its D100 column off the enemy's
	# main AI type. This assignment used to live INSIDE the guard above, so even a
	# correct dlc_ai_type producer would have been swallowed by a DIFFERENT missing
	# key: _check_escalating_battles() returns early while _dlc_ai_type is empty, so
	# the D100 was never rolled once in any battle of any campaign.
	var esc_force: Dictionary = _battle_context.get(
		"enemy_force", mission_dict.get("enemy_force", {}))
	_dlc_ai_type = _ai_type_name(str(esc_force.get("ai", "A"))).to_lower()
	if EscalatingBattlesManagerRef.is_enabled():
		_add_setup_section_header("ESCALATING BATTLES")
		if _dlc_ai_type in ESCALATION_AI_TYPES:
			var esc_text: String = EscalatingBattlesManagerRef.generate_setup_text(_dlc_ai_type)
			_add_setup_text(esc_text, Color("#D97706"))
		else:
			# The p.46 table has exactly six columns (Aggressive / Cautious /
			# Defensive / Rampage / Tactical / Beast). Guardian has none, so the
			# book grants these enemies no Escalation — say so rather than
			# silently skipping the check and leaving the player guessing.
			_add_setup_text(
				"No Escalation table for %s AI — the Compendium p.46 table covers "
				% _ai_type_name(str(esc_force.get("ai", "A")))
				+ "Aggressive, Cautious, Defensive, Rampage, Tactical and Beast only.",
				Color("#808080"))
		_add_setup_separator()

	# Section 5b: Dramatic Combat (Compendium p.87). Adjusted Shooting is already
	# applied by the resolvers (BattleResolver / NoMinis / Stealth / Salvage), but
	# Duck Back and Lunge are executed by the player at the table, so the rule TEXT
	# is the implementation for a companion app — and it was never being shown.
	var dramatic_effects: Array[String] = \
		CompendiumDifficultyTogglesRef.get_dramatic_combat_rule_instructions()
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
	# A STANDALONE battle must not write the campaign's saved table.
	#
	# active_battlefield is shared state written by four entry points but cleared by
	# ONE (CampaignTurnController's post-battle handler). Battle Simulator and the
	# other standalone modes generate their own map and persisted it through the same
	# chokepoint, which writes through to campaign.progress_data — so playing a
	# standalone battle while a campaign was loaded OVERWROTE the physical table the
	# player had already built for their next campaign mission, and it survived the
	# save. Standalone battles have no campaign to persist to; keep them in memory.
	if _is_standalone_battle():
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

## Build the Compendium GAME OPTIONS instruction lines for the battle-setup tab.
##
## Progressive Difficulty (Compendium pp.30-31) is a campaign-creation choice that
## reached campaign.progress_data and was then read by NOBODY: a player who ticked
## Basic or Advanced got no extra enemies, no respawns, and not one line of text
## for the entire campaign. The milestone tables in data/progressive_difficulty.json
## are book-exact — only the call was missing.
##
## Milestones are cumulative: the book says "apply both the highest Respawn and the
## highest Strength entry that applies to you" (p.30), and get_active_milestones()
## already returns every entry at or below the current turn.
func _build_compendium_option_instructions() -> Array[String]:
	var out: Array[String] = []
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return out
	var campaign = gs.current_campaign
	if not ("progress_data" in campaign):
		return out
	var progress: Dictionary = campaign.progress_data
	var turn_number: int = int(progress.get("turns_played", 0))
	var options: Array = progress.get("progressive_difficulty_options", [])
	for option: Variant in options:
		var milestones: Array[Dictionary] = \
			ProgressiveDifficultyTrackerRef.get_active_milestones(
				turn_number, int(option))
		for milestone: Dictionary in milestones:
			var instruction: String = str(milestone.get("instruction", "")).strip_edges()
			if not instruction.is_empty():
				out.append("MILESTONE: " + instruction)
	return out


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


## ── DLC: Compendium Casualty Tables (Compendium pp.99-100) ────────

## Read a field off a crew member that may be a Character Resource OR a minimal
## Dictionary (TacticalUnit accepts both — Battle Simulator builds dicts).
## `in` works for both; 2-arg .get() would ABORT on a Resource.
func _oc_field(oc: Variant, key: String, fallback: Variant = null) -> Variant:
	if oc is Dictionary:
		return oc.get(key, fallback)
	if oc is Object and key in oc:
		return oc.get(key)
	return fallback


func _roll_compendium_casualty(category: String = "humanoid",
		is_boss: bool = false) -> Dictionary:
	## Roll on the Compendium casualty table if CASUALTY_TABLES is on, else {}.
	return CompendiumDifficultyTogglesRef.roll_casualty(category, is_boss)

# _roll_compendium_injury() was DELETED here. The Detailed Post-Battle Injury
# table is a POST-BATTLE table — p.101: "can be used in place of the one in the
# core rules" — so rolling it mid-battle-resolution was the wrong stage, and it
# would have double-rolled against the post-battle step once that step was
# wired. It now lives at its proper site, InjuryProcessor.process_single_injury.


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

	# Enemy identity carried over from the generated force. These did not exist,
	# so every `"is_lieutenant" in unit` / `"enemy_type" in unit` guard in this file
	# was permanently FALSE: the post-battle `defeated_enemies` list recorded every
	# kill as type "" with was_lieutenant false, and the End-Phase Morale seeding
	# could not tell how many figures are Fearless (Core Rules p.114 — a Lieutenant
	# is skipped by the Morale dice unless Cowardly).
	var enemy_type: String = ""
	var is_lieutenant: bool = false
	var is_specialist: bool = false
	var is_unique_individual: bool = false

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
			# Carry the generator's role flags onto the figure — without these the
			# post-battle defeated-enemy list and the Morale seeding were blind.
			#
			# EnemyGenerator's vocabulary is `role` ("standard"/"lieutenant"/
			# "specialist") plus `is_leader`; it does NOT emit is_lieutenant. Read the
			# producer's real keys here rather than renaming them at the source —
			# those keys are pinned by the battle-result contract.
			enemy_type = str(enemy.get("type", ""))
			var _role: String = str(enemy.get("role", "")).to_lower()
			is_lieutenant = _role == "lieutenant" \
				or bool(enemy.get("is_leader", false)) \
				or bool(enemy.get("is_lieutenant", false))
			is_specialist = _role == "specialist" \
				or bool(enemy.get("is_specialist", false))
			is_unique_individual = _role == "unique" \
				or bool(enemy.get("is_unique_individual", false))
		else:
			var _name_val = enemy.get("name") if enemy else null
			node_name = str(_name_val) if _name_val else "Enemy"
			combat_skill = enemy.get("combat_skill") if enemy and enemy.get("combat_skill") != null else 0
			toughness = enemy.get("toughness") if enemy and enemy.get("toughness") != null else 0
			reactions = enemy.get("reactions") if enemy and enemy.get("reactions") != null else 0
			if enemy:
				if enemy.get("type") != null:
					enemy_type = str(enemy.get("type"))
				is_lieutenant = bool(enemy.get("is_lieutenant")) \
					if enemy.get("is_lieutenant") != null else false
				is_specialist = bool(enemy.get("is_specialist")) \
					if enemy.get("is_specialist") != null else false
				is_unique_individual = bool(enemy.get("is_unique_individual")) \
					if enemy.get("is_unique_individual") != null else false

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
	tactical_battle_completed.emit(_build_evacuation_result_dict(true))


func _build_evacuation_result_dict(via_star: bool) -> Dictionary:
	## Standard battle-result contract for a battle the crew LEAVES rather than
	## fights to a finish — currently the "It's time to go!" star (Core Rules p.67).
	##
	## THE BUG THIS FIXES: the evacuation path emitted its own ad-hoc 8-key dict.
	## It sent crew_casualties / crew_injuries as ARRAYS where every other producer
	## sends ints, used an "objectives_met" key no consumer reads, and omitted
	## success, crew_participants, crew_casualties_data, crew_injuries_data,
	## mission_source and the zone flags. Downstream, BattleResultNormalizer steps 7
	## and 8 build injuries_sustained / casualties FROM crew_*_data, so both came out
	## empty, and PostBattlePhase reads a missing "success" as false. Invoking the
	## once-per-campaign escape therefore cost the player every injury roll, all XP,
	## and any objective they had already completed.
	##
	## Core Rules p.115: leaving the battlefield means you do NOT Hold the Field, but
	## objectives achieved BEFORE exiting still stand ("having achieved your
	## objectives before exiting the battle").
	var crew_alive: int = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive: int = enemy_units.filter(func(u): return u.health > 0).size()

	# current_turn is the round in progress (set by _on_round_started), so the round
	# the crew bails in IS a round they fought.
	var rounds: int = maxi(0, current_turn)

	# Downed crew route to injuries_data, never casualties_data — Core Rules p.122:
	# a figure that went Out of Action ALWAYS rolls the post-battle Injury Table, and
	# the roll decides dead / injured / recovered. Same rule the played path applies.
	var injuries_data: Array = []
	for unit in crew_units:
		if unit.health <= 0:
			injuries_data.append(unit.original_character)

	var defeated_enemies: Array = _defeated_enemy_records()

	var crew_participants: Array = []
	for unit in crew_units:
		if unit.original_character:
			crew_participants.append(unit.original_character)

	var obj_id: String = ""
	var obj_met: bool = false
	var obj_progress: Array = []
	if _objective_tracker != null and _objective_tracker.has_objective():
		obj_id = _objective_tracker.get_objective_id()
		obj_met = _objective_tracker.is_complete()
		obj_progress = _objective_tracker.get_panel_conditions()

	var md: Dictionary = _stored_mission_data \
		if _stored_mission_data is Dictionary else {}

	return {
		"victory": false,
		"won": false,
		# The objective still decides the mission (Core Rules p.90); leaving the
		# table only forfeits Holding the Field.
		"success": obj_met,
		"held_field": false,
		"evacuated": true,
		"evacuated_via_star": via_star,
		# Core Rules p.123, verbatim: "Any character that flees the battlefield in
		# the first 2 rounds of the battle receives no XP."
		"fled_early": rounds <= 2,
		"objective_id": obj_id,
		"objective_met": obj_met,
		"objective_progress": obj_progress,
		"rounds_fought": rounds,
		"crew_casualties": 0,
		"crew_injuries": injuries_data.size(),
		"crew_casualties_data": [],
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
	# Start below the floating gear/bug buttons, which live on their own CanvasLayer in
	# the same top-right corner. reserve_band_on() cannot help here: this widget is on
	# a CanvasLayer of its own, so it is not a descendant of anything the reservation
	# can push down. Ask the overlay where it actually is instead of hardcoding a gap.
	panel.offset_top = 16.0
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("get_reserved_bottom"):
		panel.offset_top = maxf(16.0, float(_so.get_reserved_bottom()) + 8.0)
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
