extends "res://src/ui/screens/planetfall/PlanetfallScreenBase.gd"

## Planetfall Campaign Turn Controller — 18-step campaign turn.
## Manages the phase flow from Recovery (Step 1) through Update Tracking (Step 18).
## Each step has a panel displayed in the main area (placeholder panels for Sprint 1).
## Follows the same architecture as BugHuntTurnController.
## Source: Planetfall pp.58-70

const PlanetfallPhaseManagerScript := preload(
	"res://src/core/campaign/PlanetfallPhaseManager.gd")
const BattleGuideScript := preload("res://src/core/battle/PlanetfallBattleGuide.gd")
const ItemChoicePopupScript := preload("res://src/ui/components/dialogs/ItemChoicePopup.gd")
const PlaceholderPanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallPlaceholderPanel.gd")
const AutoResolveScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallAutoResolveDialog.gd")
const SimpleDialogScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const ScoutReportsScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallScoutReportsPanel.gd")
const ColonyEventsScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallColonyEventsPanel.gd")
const PostBattleScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const MissionPanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallMissionPanel.gd")
const LockAndLoadScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const ResearchPanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallResearchPanel.gd")
const BuildingPanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallBuildingPanel.gd")
const EndGamePanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEndGamePanel.gd")
const MilestoneSystemScript := preload(
	"res://src/core/systems/PlanetfallMilestoneSystem.gd")
const CalamitySystemScript := preload(
	"res://src/core/systems/PlanetfallCalamitySystem.gd")
const MissionDataSystemScript := preload(
	"res://src/core/systems/PlanetfallMissionDataSystem.gd")
const ConditionSystemScript := preload(
	"res://src/core/systems/PlanetfallConditionSystem.gd")
const LifeformGenScript := preload(
	"res://src/core/systems/PlanetfallLifeformGenerator.gd")
const TacticalEnemyGenScript := preload(
	"res://src/core/systems/PlanetfallTacticalEnemyGenerator.gd")
const ArmoryScript := preload("res://src/core/systems/PlanetfallArmorySystem.gd")

var phase_manager: PlanetfallPhaseManagerScript
var campaign: Resource  # PlanetfallCampaignCore
var panels: Array[Control] = []
## Untyped: its signals are declared on the panel script, not on Control.
var _endgame_panel = null
var current_panel: Control
var _mission_context: Dictionary = {}  # Cached from Step 6+7 for battle launch
var _deployed_data: Dictionary = {}    # Cached from Step 7 for battle launch

## Progression systems (instantiated once per turn controller lifetime)
var _milestone_sys: MilestoneSystemScript
var _calamity_sys: CalamitySystemScript
var _md_sys: MissionDataSystemScript
var _condition_sys: ConditionSystemScript
var _lifeform_gen: LifeformGenScript
var _enemy_gen: TacticalEnemyGenScript

var _turn_label: Label
var _phase_label: Label
## A flow container, so the colony's resources wrap onto a second line on a phone
## instead of being hidden there (it used to drop RM, Grunts and Milestones in portrait).
var _stat_strip: HFlowContainer
var _advance_button: Button
## Why the footer button is disabled, shown above it (a phone has no hover).
var _footer_reason: Label
var _save_button: Button
var _dashboard_button: Button
var _top_row: BoxContainer
## Save + Dashboard, kept side by side when the header stacks on a phone.
var _top_buttons: HBoxContainer
var _panel_container: Control
var _phase_scroll: ScrollContainer
var _phase_indicator_box: HBoxContainer
var _phase_indicators: Array[Label] = []
## The page margin. Its left/right are recomputed on every resize so the turn reads as
## one centred column on a tablet in landscape instead of a 2,000-px-wide strip with
## its prose on the far left and its buttons in the middle (Sprint U captures).
var _page_margin: MarginContainer

## The widest the turn's column grows, in design px.
const MAX_TURN_WIDTH := 1200
## Tracks whether _apply_topbar_responsive() last applied the portrait shape, so a
## layout_class_changed that does not flip orientation is a cheap no-op.
var _topbar_is_portrait_applied: bool = false
## False until the first _apply_topbar_responsive() runs, so the initial pass is
## never skipped by the orientation-unchanged dedupe (default-false could match).
var _last_topbar_state_initialized: bool = false

## Stat labels for the colony stat bar
var _stat_labels: Dictionary = {}
var _post_battle_panel: Control


## ============================================================================
## LIFECYCLE
## ============================================================================

func _setup_screen() -> void:
	# Defer initialization — scene may not be fully in tree when
	# instantiated via TransitionManager.fade_to_scene()
	call_deferred("_initialize")


## Disconnect the dedicated top-bar responsive signal. CampaignScreenBase._exit_tree()
## handles its own breakpoint_changed / layout_class_changed disconnects; this adds
## the top-bar-specific connection on top of that.
func _exit_tree() -> void:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed") \
			and rm.layout_class_changed.is_connected(_on_topbar_layout_class_changed):
		rm.layout_class_changed.disconnect(_on_topbar_layout_class_changed)
	var vp := get_viewport()
	if vp and vp.size_changed.is_connected(_apply_turn_column_width):
		vp.size_changed.disconnect(_apply_turn_column_width)
	super._exit_tree()


func _initialize() -> void:
	# Deferred from _ready(), so it lands a frame later and this controller may
	# already have left the tree. The /root campaign lookups below ERROR from a
	# detached node rather than returning null, and the turn would initialise
	# against no campaign at all. Same guard as the other deferred entry points.
	if not is_inside_tree():
		return
	_load_campaign()
	if not campaign:
		return
	_init_progression_systems()
	_build_layout()
	_create_phase_manager()
	_create_panels()
	_connect_signals()
	_start_or_resume_turn()


func _init_progression_systems() -> void:
	_milestone_sys = MilestoneSystemScript.new()
	_calamity_sys = CalamitySystemScript.new()
	_md_sys = MissionDataSystemScript.new()
	_condition_sys = ConditionSystemScript.new()
	_lifeform_gen = LifeformGenScript.new()
	_enemy_gen = TacticalEnemyGenScript.new()


func _start_or_resume_turn() -> void:
	# A finished campaign opens on its conclusion. An End Game in progress does NOT stop
	# here: Colony Security needs a destroyed Strongpoint and the final milestone needs
	# BP and RP (pp.160-161), both earned in campaign turns, so a battle return or a turn
	# under way resumes as normal and the End Game panel opens between turns
	# (_on_turn_completed). This branch used to catch "endgame" too, which dropped the
	# returning battle and left no way back to a turn.
	var gp: String = campaign.game_phase if "game_phase" in campaign else ""
	if gp == "completed" or gp == "failed":
		_show_endgame_panel()
		return

	# Check if returning from battle
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	var battle_result = null
	if gs_mgr and gs_mgr.has_method("get_temp_data"):
		battle_result = gs_mgr.get_temp_data("planetfall_battle_result")

	if battle_result is Dictionary and not battle_result.is_empty():
		_resume_after_battle(battle_result)
		if gs_mgr.has_method("set_temp_data"):
			gs_mgr.set_temp_data("planetfall_battle_result", null)
	elif campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 0
		if turn <= 0:
			phase_manager.start_new_turn()
		else:
			_resume_turn(turn)
	# A Breakthrough award left unassigned when the app closed is asked for again.
	_offer_character_awards.call_deferred()


## Resume a turn already under way, on the step the campaign recorded (T1). This used
## to jump to RECOVERY every time, replaying steps whose effects were already applied.
## campaign_turn_started is deliberately NOT emitted: its handler runs the turn-start
## Calamity effects, which roll and ADD progress, so re-emitting it advanced an active
## Calamity once more on every relaunch.
func _resume_turn(turn: int) -> void:
	var ph := PlanetfallPhaseManagerScript.Phase
	phase_manager.turn_number = turn
	_turn_label.text = "TURN %d" % turn
	_refresh_stat_strip()
	var phase: int = phase_manager.restore_from_campaign()
	if phase == ph.NONE:
		# The last turn ended and was saved; the next one starts on the player's word.
		_on_turn_completed(turn)
		return
	var result: Dictionary = phase_manager.get_battle_result()
	if not result.is_empty() and phase >= ph.INJURIES and phase <= ph.TRACK_ENEMY_INFO:
		for panel in panels:
			if panel.has_method("set_battle_results"):
				panel.set_battle_results(result)
	phase_manager.go_to_phase(phase)


func _load_campaign() -> void:
	campaign = _get_planetfall_campaign()

	# Validate this is a PlanetfallCampaignCore (has roster property)
	if campaign and not "roster" in campaign:
		push_warning("PlanetfallTurnController: Campaign missing 'roster'. Routing to main menu.")
		campaign = null
		_navigate("main_menu")


## ============================================================================
## LAYOUT
## ============================================================================

func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SPACING_MD)
	margin.add_theme_constant_override("margin_top", SPACING_SM)
	margin.add_theme_constant_override("margin_right", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_SM)
	add_child(margin)
	_page_margin = margin

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	margin.add_child(vbox)

	# Top row: Turn label + the two buttons. A BoxContainer so portrait can stack it --
	# see _apply_topbar_responsive(). It was built as an HBoxContainer under this same
	# comment, so `vertical = true` raised "Can't change orientation of HBoxContainer"
	# and the phone header never stacked.
	_top_row = BoxContainer.new()
	_top_row.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_top_row)

	_turn_label = Label.new()
	_turn_label.text = "TURN 1"
	_turn_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(_turn_label)

	_top_buttons = HBoxContainer.new()
	_top_buttons.add_theme_constant_override("separation", SPACING_MD)
	_top_row.add_child(_top_buttons)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(80, 36)
	_save_button.pressed.connect(_on_save_pressed)
	_top_buttons.add_child(_save_button)

	_dashboard_button = Button.new()
	_dashboard_button.text = "Dashboard"
	_dashboard_button.custom_minimum_size = Vector2(100, 36)
	_dashboard_button.pressed.connect(func(): _navigate("planetfall_dashboard"))
	_top_buttons.add_child(_dashboard_button)

	# Colony stat strip
	_stat_strip = HFlowContainer.new()
	_stat_strip.add_theme_constant_override("h_separation", SPACING_MD)
	_stat_strip.add_theme_constant_override("v_separation", SPACING_XS)
	vbox.add_child(_stat_strip)
	_build_stat_strip()

	# Phase indicator strip (scrollable for 18 items)
	_phase_scroll = ScrollContainer.new()
	_phase_scroll.custom_minimum_size.y = 32
	_phase_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_phase_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_phase_scroll)

	_phase_indicator_box = HBoxContainer.new()
	_phase_indicator_box.add_theme_constant_override("separation", SPACING_XS)
	_phase_scroll.add_child(_phase_indicator_box)
	_build_phase_indicators()

	# Where the turn stands: the p.58 group and the step count. The step's NAME is the
	# panel's own title ("STEP 3: SCOUT REPORTS"); this label used to repeat it as
	# "PRE-BATTLE — SCOUT REPORTS", so every step opened with its name printed twice.
	_phase_label = Label.new()
	_phase_label.text = "PRE-BATTLE · STEP 1 OF 18"
	_phase_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_SM))
	_phase_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	# Panel container — holds all 18 panels, only one visible
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Bottom navigation
	_footer_reason = Label.new()
	_footer_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer_reason.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_SM))
	_footer_reason.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	_footer_reason.visible = false
	vbox.add_child(_footer_reason)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", SPACING_MD)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_advance_button = Button.new()
	_advance_button.text = "Complete Phase"
	_advance_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_advance_button.pressed.connect(_on_advance_pressed)
	nav.add_child(_advance_button)

	# Apply the initial portrait/landscape shape to the top bar now that it exists,
	# and listen for orientation/breakpoint changes. The base CampaignScreenBase
	# already connects layout_class_changed -> _on_layout_class_changed for its own
	# column relayout; this is a SEPARATE, dedicated connection so the top-bar
	# reshape fires on every rotation regardless of column-count dedupe.
	_connect_topbar_responsive()
	_apply_topbar_responsive()
	_apply_turn_column_width()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply_turn_column_width):
		vp.size_changed.connect(_apply_turn_column_width)


## Centre the turn in a column no wider than MAX_TURN_WIDTH. Width arithmetic in the
## design space the layout itself uses, so get_visible_rect() is the right reading
## here; orientation questions still go to ResponsiveManager.
func _apply_turn_column_width() -> void:
	if not is_instance_valid(_page_margin) or not is_inside_tree():
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var side: int = maxi(SPACING_MD, int((width - MAX_TURN_WIDTH) / 2.0))
	_page_margin.add_theme_constant_override("margin_left", side)
	_page_margin.add_theme_constant_override("margin_right", side)


## ============================================================================
## TOP-BAR RESPONSIVE LAYOUT (portrait phones)
## ============================================================================

## Wire the dedicated top-bar reshape to ResponsiveManager.layout_class_changed.
## Guarded so a re-entrant _build_layout() can never double-connect.
func _connect_topbar_responsive() -> void:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed") \
			and not rm.layout_class_changed.is_connected(_on_topbar_layout_class_changed):
		rm.layout_class_changed.connect(_on_topbar_layout_class_changed)


func _on_topbar_layout_class_changed(_effective_columns: int) -> void:
	_apply_topbar_responsive()


## Reshape ONLY the top row for the current orientation. Portrait stacks it
## vertically (so Turn/Save/Dashboard are not crushed) and bumps both buttons to
## >= TOUCH_TARGET_MIN (48) high. The stat strip needs nothing here: it wraps.
func _apply_topbar_responsive() -> void:
	if not is_instance_valid(_top_row):
		return

	var portrait: bool = _topbar_is_portrait()
	if portrait == _topbar_is_portrait_applied and _last_topbar_state_initialized:
		return
	_topbar_is_portrait_applied = portrait
	_last_topbar_state_initialized = true

	if portrait:
		# Stack the top row so the expanding Turn label does not crush the two
		# buttons onto one cramped line.
		_top_row.vertical = true
		_top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_top_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_turn_label):
			_turn_label.size_flags_horizontal = Control.SIZE_FILL
		# Touch-friendly buttons, full-width so they are easy to hit on a phone.
		if is_instance_valid(_save_button):
			_save_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
			_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_dashboard_button):
			_dashboard_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
			_dashboard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The stat strip wraps (HFlowContainer), so no colony stat is hidden here.
	else:
		# Restore the original landscape shape exactly.
		_top_row.vertical = false
		_top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_top_buttons.size_flags_horizontal = Control.SIZE_FILL
		if is_instance_valid(_turn_label):
			_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_save_button):
			_save_button.custom_minimum_size = Vector2(80, 36)
			_save_button.size_flags_horizontal = Control.SIZE_FILL
		if is_instance_valid(_dashboard_button):
			_dashboard_button.custom_minimum_size = Vector2(100, 36)
			_dashboard_button.size_flags_horizontal = Control.SIZE_FILL


## True when the current layout should collapse the top bar to its portrait shape.
## Prefers ResponsiveManager (DPI-aware, single source of truth); falls back to a
## raw viewport aspect check so it still works if the autoload is absent.
func _topbar_is_portrait() -> bool:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm:
		var portrait: bool = rm.is_portrait() if rm.has_method("is_portrait") else false
		var collapse: bool = rm.should_collapse_to_single_column() \
			if rm.has_method("should_collapse_to_single_column") else false
		return portrait and collapse
	var vp := get_viewport()
	if not vp:
		return false
	var sz := vp.get_visible_rect().size
	return sz.y > sz.x


func _build_stat_strip() -> void:
	for key in COLONY_STAT_ORDER:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_CYAN)
		_stat_strip.add_child(lbl)
		_stat_labels[key] = lbl
	_refresh_stat_strip()


## Build and Research Points are the pools Steps 14-15 spend (p.69); the turn used to
## show neither, so a player reached Research without seeing what they could afford.
## The values come from colony_stats(), which the dashboard reads too.
func _refresh_stat_strip() -> void:
	if not campaign:
		return
	var stats: Dictionary = colony_stats(campaign)
	for key in _stat_labels:
		if stats.has(key):
			_stat_labels[key].text = "%s: %s" % [stats[key][0], str(stats[key][2])]


## The 18 steps, grouped the way p.58 prints them (Pre-Battle 1-6, Battle 7-8,
## Post-Battle 9-18), with each group named. It used to be eighteen bare numbers.
func _build_phase_indicators() -> void:
	_phase_indicators.clear()
	var last_group := ""
	for i in range(PlanetfallPhaseManagerScript.PHASE_COUNT):
		var group: String = str(PlanetfallPhaseManagerScript.PHASE_CATEGORIES.get(i, ""))
		if group != last_group:
			if last_group != "":
				_phase_indicator_box.add_child(VSeparator.new())
			var caption := Label.new()
			caption.text = group
			caption.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XS))
			caption.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_phase_indicator_box.add_child(caption)
			last_group = group
		var indicator := Label.new()
		var short_name: String = PlanetfallPhaseManagerScript.PHASE_NAMES.get(i, "?")
		indicator.text = "%d" % (i + 1)
		indicator.tooltip_text = "%d. %s" % [i + 1, short_name]
		indicator.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XS))
		indicator.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		indicator.custom_minimum_size = Vector2(24, 24)
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_phase_indicator_box.add_child(indicator)
		_phase_indicators.append(indicator)


## ============================================================================
## PHASE MANAGER SETUP
## ============================================================================

func _create_phase_manager() -> void:
	phase_manager = PlanetfallPhaseManagerScript.new()
	phase_manager.name = "PlanetfallPhaseManager"
	add_child(phase_manager)
	phase_manager.setup(campaign)


func _create_panels() -> void:
	panels.clear()
	var ph := PlanetfallPhaseManagerScript.Phase

	for i in range(PlanetfallPhaseManagerScript.PHASE_COUNT):
		var panel: Control = _create_panel_for_phase(i)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_child(panel)
		panel.hide()

		if panel.has_method("set_campaign"):
			panel.set_campaign(campaign)
		if panel.has_method("set_phase_manager"):
			panel.set_phase_manager(phase_manager)

		panels.append(panel)

	# Store reference for post-battle data injection
	_post_battle_panel = panels[ph.INJURIES] if ph.INJURIES < panels.size() else null


func _create_panel_for_phase(phase: int) -> Control:
	## Create the appropriate panel type for each phase.
	## Auto-resolve steps use PlanetfallAutoResolveDialog.
	## Simple input steps use PlanetfallSimpleDialog.
	## Complex steps use dedicated panels.
	## Unimplemented steps (Sprint 2) use PlaceholderPanel.
	var ph := PlanetfallPhaseManagerScript.Phase
	var phase_name: String = PlanetfallPhaseManagerScript.PHASE_NAMES.get(
		phase, "Step %d" % (phase + 1))

	match phase:
		# Auto-resolve steps (Sprint 3)
		ph.RECOVERY:
			var p := AutoResolveScript.new()
			p.configure("recovery", phase)
			return p
		ph.ENEMY_ACTIVITY:
			var p := AutoResolveScript.new()
			p.configure("enemy_activity", phase)
			return p
		ph.COLONY_INTEGRITY:
			var p := AutoResolveScript.new()
			p.configure("colony_integrity", phase)
			return p
		ph.UPDATE_TRACKING:
			var p := AutoResolveScript.new()
			p.configure("update_tracking", phase)
			return p

		# Simple dialog steps (Sprint 3)
		ph.REPAIRS:
			var p := SimpleDialogScript.new()
			p.configure("repairs", phase)
			return p
		ph.TRACK_ENEMY_INFO:
			var p := SimpleDialogScript.new()
			p.configure("track_enemy_info", phase)
			return p
		ph.REPLACEMENTS:
			var p := SimpleDialogScript.new()
			p.configure("replacements", phase)
			return p
		ph.CHARACTER_EVENT:
			var p := SimpleDialogScript.new()
			p.configure("character_event", phase)
			return p

		# Full panels (Sprint 3)
		ph.SCOUT_REPORTS:
			return ScoutReportsScript.new()
		ph.COLONY_EVENTS:
			return ColonyEventsScript.new()

		# Post-battle combined panel — steps 9-12
		ph.INJURIES, ph.EXPERIENCE, ph.MORALE_ADJUSTMENTS:
			return PostBattleScript.new()

		# Core system panels
		ph.MISSION_DETERMINATION:
			return MissionPanelScript.new()
		ph.LOCK_AND_LOAD:
			return LockAndLoadScript.new()
		ph.RESEARCH:
			return ResearchPanelScript.new()
		ph.BUILDING:
			return BuildingPanelScript.new()

		# Battle delegation — intercepted in _on_phase_changed
		ph.PLAY_OUT_MISSION:
			var p := PlaceholderPanelScript.new()
			p.configure("Play Out Mission", phase)
			return p

	# Fallback
	var p := PlaceholderPanelScript.new()
	p.configure(phase_name, phase)
	return p


func _connect_signals() -> void:
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_completed.connect(_on_phase_completed)
	phase_manager.campaign_turn_started.connect(_on_turn_started)
	phase_manager.campaign_turn_completed.connect(_on_turn_completed)
	# p.90 Campaign Failure ends the turn mid-way; the end screen says why.
	phase_manager.campaign_ended.connect(func(_reason: String): _show_endgame_panel())
	phase_manager.navigation_updated.connect(_on_navigation_updated)

	# Panel completion signals
	for panel in panels:
		if panel.has_signal("phase_completed"):
			panel.phase_completed.connect(_on_panel_phase_completed)


## ============================================================================
## SIGNAL HANDLERS
## ============================================================================

func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	var ph := PlanetfallPhaseManagerScript.Phase

	# Intercept Step 8 (PLAY_OUT_MISSION) — delegate to TacticalBattleUI
	if new_phase == ph.PLAY_OUT_MISSION:
		_launch_planetfall_battle()
		return

	# Auto-skip TRACK_ENEMY_INFO (phase 11) — PostBattlePanel at phase 10
	# already handles POST_MISSION_FINDS and ENEMY_INFO internally. Mission Data is not
	# checked here: p.68 notes it and a Milestone checks it (PlanetfallMissionDataSystem).
	if new_phase == ph.TRACK_ENEMY_INFO:
		phase_manager.complete_current_phase({})
		return

	_show_panel(new_phase)
	_update_phase_display(new_phase)
	_refresh_stat_strip()

	# Refresh the new panel
	if new_phase >= 0 and new_phase < panels.size():
		var panel: Control = panels[new_phase]
		if panel.has_method("refresh"):
			panel.refresh()
	_refresh_footer()

	# Scroll phase indicator into view
	_scroll_indicator_into_view(new_phase)


func _on_phase_completed(_phase: int) -> void:
	_update_phase_indicators()
	_refresh_stat_strip()


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "TURN %d" % turn
	_refresh_stat_strip()

	# Calamities roll "at the end of each campaign turn" (pp.165-168): Step 18, through
	# the phase manager, never here. This handler used to roll them at turn START and
	# report them only as push_warning.


func _on_turn_completed(_turn: int) -> void:
	# p.160: "The summit takes place at the end of the current campaign turn and cannot
	# be delayed." The 7th Milestone marks the End Game; the turn that earned it finishes.
	if campaign and "game_phase" in campaign and str(campaign.game_phase) == "endgame":
		_show_endgame_panel()
		return
	_advance_button.text = "Start Next Turn"
	_advance_button.disabled = false
	_advance_button.visible = true
	_footer_reason.visible = false
	_phase_label.text = "TURN COMPLETE"
	_refresh_stat_strip()


func _on_panel_phase_completed(result_data: Dictionary) -> void:
	var current: int = phase_manager.current_phase

	# Cache mission selection from Step 6 for battle launch
	if current == PlanetfallPhaseManagerScript.Phase.MISSION_DETERMINATION:
		_mission_context = result_data.get("selected_mission", {})
		# pp.110-113: the Battlefield Condition rolled for this mission rides on it to the
		# battle card. It reached only Lock and Load until 2026-10-28.
		_mission_context["active_condition"] = result_data.get("active_condition", {})
		# Pass force limits + mission context to LockAndLoadPanel
		var lock_phase: int = PlanetfallPhaseManagerScript.Phase.LOCK_AND_LOAD
		if lock_phase >= 0 and lock_phase < panels.size():
			var lock_panel: Control = panels[lock_phase]
			var force_limits: Dictionary = result_data.get("force_limits", {})
			if lock_panel.has_method("set_force_limits") and not force_limits.is_empty():
				lock_panel.set_force_limits(force_limits)
			if lock_panel.has_method("set_mission_context"):
				lock_panel.set_mission_context(result_data)

	# Cache deployment data from Step 7 for battle launch
	if current == PlanetfallPhaseManagerScript.Phase.LOCK_AND_LOAD:
		_deployed_data = result_data.duplicate(true)

	phase_manager.complete_current_phase(result_data)

	# Steps 14-15: the phase manager delivers any Milestone on completion (pp.156-158);
	# this screen only shows what happened.
	_show_milestone_receipt(phase_manager.take_milestone_receipt())


func _on_advance_pressed() -> void:
	if phase_manager.current_phase == PlanetfallPhaseManagerScript.Phase.NONE:
		# Between turns — start new turn. start_new_turn() reaches _on_phase_changed and
		# _refresh_footer() synchronously, so Step 1 has already set the footer; a
		# "Complete Phase" written here overwrote it on every new turn.
		phase_manager.start_new_turn()
		return

	# Let the panel handle its own completion
	var panel_idx: int = phase_manager.current_phase
	if panel_idx >= 0 and panel_idx < panels.size():
		var panel: Control = panels[panel_idx]
		if panel.has_method("complete"):
			panel.complete()
		else:
			phase_manager.complete_current_phase({})


## The phase manager marks a phase complete only as it advances past it, so its
## can_forward was false on every step and the footer read "Complete Phase", disabled,
## everywhere. The footer now follows the step itself (_refresh_footer).
func _on_navigation_updated(_can_back: bool, _can_forward: bool) -> void:
	_refresh_footer()


func _on_save_pressed() -> void:
	if not campaign:
		return
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		var result: Dictionary = gs.save_campaign(campaign)
		if result.get("success", false):
			_save_button.text = "Saved!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_save_button):
					_save_button.text = "Save"
			)
	elif campaign.has_method("save_to_file") and campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		var err: int = campaign.save_to_file(path)
		if err == OK:
			_save_button.text = "Saved!"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(_save_button):
					_save_button.text = "Save"
			)


## ============================================================================
## PANEL DISPLAY
## ============================================================================

func _show_panel(phase_idx: int) -> void:
	if current_panel:
		current_panel.hide()
		if current_panel.has_signal("step_status_changed") \
				and current_panel.step_status_changed.is_connected(_refresh_footer):
			current_panel.step_status_changed.disconnect(_refresh_footer)
	if phase_idx >= 0 and phase_idx < panels.size():
		current_panel = panels[phase_idx]
		current_panel.show()
		if current_panel.has_signal("step_status_changed"):
			current_panel.step_status_changed.connect(_refresh_footer)


## The pinned footer is a step's one completion control. A step that reports
## step_status() -> {ready, reason} (and an optional "label") drives it: enabled when ready, otherwise
## disabled with the reason shown above it, and pressing it calls the step's
## complete(). A step that does not report one finishes from its own panel, so the
## footer is hidden rather than shown disabled. Between turns the footer is "Start
## Next Turn" (_on_turn_completed) and this leaves it alone.
func _refresh_footer() -> void:
	if not is_instance_valid(_advance_button) or phase_manager == null:
		return
	if phase_manager.current_phase == PlanetfallPhaseManagerScript.Phase.NONE:
		return
	var status: Dictionary = {}
	if is_instance_valid(current_panel) and current_panel.has_method("step_status"):
		status = current_panel.step_status()
	if status.is_empty():
		_advance_button.visible = false
		_footer_reason.visible = false
		return
	var ready: bool = bool(status.get("ready", false))
	_advance_button.visible = true
	_advance_button.text = str(status.get("label",
			_next_step_label(phase_manager.current_phase)))
	_advance_button.disabled = not ready
	_footer_reason.text = "" if ready else str(status.get("reason", ""))
	_footer_reason.visible = _footer_reason.text != ""


## "Continue to Step N" for the step after `phase`, or "End Turn N" on the last one.
## Step 12 (Track Enemy Info) is folded into the post-battle panel and skipped, so the
## label names the step the player will actually see.
func _next_step_label(phase: int) -> String:
	var next: int = phase + 1
	if next == PlanetfallPhaseManagerScript.Phase.TRACK_ENEMY_INFO:
		next += 1
	if next >= PlanetfallPhaseManagerScript.PHASE_COUNT:
		return "End Turn %d" % phase_manager.turn_number
	return "Continue to Step %d" % (next + 1)


func _update_phase_display(phase: int) -> void:
	var category: String = phase_manager.get_phase_category(phase)
	_phase_label.text = "%s · STEP %d OF %d" % [
			category, phase + 1, PlanetfallPhaseManagerScript.PHASE_COUNT]
	_refresh_footer()
	_update_phase_indicators()


func _update_phase_indicators() -> void:
	for i in range(_phase_indicators.size()):
		var indicator: Label = _phase_indicators[i]
		indicator.remove_theme_stylebox_override("normal")
		if i < phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif i == phase_manager.current_phase:
			# The current step sits on a chip, so it can be found at a glance.
			indicator.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			var chip := StyleBoxFlat.new()
			chip.bg_color = COLOR_ACCENT
			chip.set_corner_radius_all(4)
			indicator.add_theme_stylebox_override("normal", chip)
		else:
			indicator.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)


func _scroll_indicator_into_view(phase_idx: int) -> void:
	## Scroll the phase indicator strip so the current phase is visible.
	if phase_idx < 0 or phase_idx >= _phase_indicators.size():
		return
	var indicator: Label = _phase_indicators[phase_idx]
	# Ensure the indicator is in view within the scroll container
	var target_x: float = indicator.position.x - _phase_scroll.size.x / 2.0 + indicator.size.x / 2.0
	_phase_scroll.scroll_horizontal = int(max(0.0, target_x))


## ============================================================================
## BATTLE DELEGATION
## ============================================================================

func _resume_after_battle(result: Dictionary) -> void:
	## Fast-forward to INJURIES phase after returning from TacticalBattleUI.
	if campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 1
		phase_manager.turn_number = turn
		_turn_label.text = "TURN %d" % turn

	_refresh_stat_strip()

	# This controller and its phase manager were REBUILT for the return, so the turn's
	# casualties, colony damage and Story Point block start at zero unless restored.
	# They used to be lost on every battle, and Morale (p.68) then read no colony damage.
	phase_manager.restore_from_campaign()
	phase_manager.set_battle_result(result)

	# Pass battle results to ALL PostBattlePanel instances BEFORE triggering
	# phase change, because go_to_phase() synchronously fires phase_changed
	# → refresh(). Phases 8-10 are separate PostBattlePanel instances. They get the
	# phase manager's NORMALIZED dictionary, never the raw temp_data: the raw one has
	# none of the keys pp.66-68 read, and sharing one dictionary is what lets the
	# Step 9 debrief reach the Step 10 and Step 12 instances.
	var normalized: Dictionary = phase_manager.get_battle_result()
	for panel in panels:
		if panel.has_method("set_battle_results"):
			panel.set_battle_results(normalized)

	# Jump directly to INJURIES phase
	phase_manager.go_to_phase(PlanetfallPhaseManagerScript.Phase.INJURIES)


func _show_endgame_panel() -> void:
	## Lay the EndGamePanel over the turn flow. The step panels are HIDDEN, not freed:
	## an End Game that still needs Colony Security or BP/RP hands back to a campaign
	## turn (_on_endgame_continue), which needs them.
	if not _panel_container:
		return
	if is_instance_valid(_endgame_panel):
		_endgame_panel.queue_free()
	for panel in panels:
		if is_instance_valid(panel):
			panel.hide()

	_endgame_panel = EndGamePanelScript.new()
	_endgame_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_endgame_panel.set_campaign(campaign)
	_panel_container.add_child(_endgame_panel)

	_endgame_panel.phase_completed.connect(func(_data: Dictionary):
		# Return to dashboard after endgame completion
		_navigate("planetfall_dashboard")
	)
	_endgame_panel.continue_campaign_requested.connect(_on_endgame_continue)

	_endgame_panel.refresh()

	# Update header. The panel carries its own buttons; the step button would advance a
	# turn that is not running.
	var failed: bool = campaign != null and campaign.has_method("is_failed") \
			and campaign.is_failed()
	if _turn_label:
		_turn_label.text = "CAMPAIGN OVER" if failed else "END GAME"
	if _phase_label:
		_phase_label.text = "Unity forces have taken control" if failed \
				else "Decide the fate of your colony"
	if _advance_button:
		_advance_button.visible = false


## pp.160-161: Colony Security or the final milestone is not met yet, so the colony plays
## another campaign turn. The End Game panel reopens when that turn ends.
func _on_endgame_continue() -> void:
	if is_instance_valid(_endgame_panel):
		_endgame_panel.queue_free()
	_endgame_panel = null
	# The new turn's Step 1 sets the footer (_refresh_footer) as start_new_turn() runs.
	phase_manager.start_new_turn()


func _launch_planetfall_battle() -> void:
	## Step 8: Delegate to TacticalBattleUI via SceneRouter.
	## Stores battle context in temp_data for TacticalBattleUI to auto-initialize.
	## On completion, TacticalBattleUI stores results and navigates back here.
	if not campaign:
		push_warning("PlanetfallTurnController: No campaign for battle launch")
		phase_manager.complete_current_phase({})
		return
	var payload: Dictionary = build_battle_payload()

	# Stamp what this mission IS before leaving. This controller is rebuilt on the
	# battle return, so _mission_context does not survive it; the phase manager
	# persists the stamp with the turn and normalizes the result against it (T9a).
	phase_manager.stamp_mission(payload.stamp)
	var battle_context: Dictionary = payload.context

	# Store in temp_data for TacticalBattleUI to pick up
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if gs_mgr and gs_mgr.has_method("set_temp_data"):
		gs_mgr.set_temp_data("planetfall_battle_context", battle_context)

	# Save campaign before leaving (in case of crash during battle)
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("save_campaign"):
		game_state.save_campaign()

	# Navigate to TacticalBattleUI — do NOT complete the phase here.
	# TacticalBattleUI will auto-init from temp_data, and on completion
	# store results in "planetfall_battle_result" and navigate back.
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("tactical_battle")
	else:
		push_warning("PlanetfallTurnController: SceneRouter not available, skipping battle")
		phase_manager.complete_current_phase({"skipped": true})


## A mission's printed table size ("2x2" / "3x3" feet, pp.115-130) as the battle
## screen's `table_size_ft`. It used to go out as `table_size`, which nothing read, so
## every Planetfall battle was laid out on the player's default table.
static func table_size_ft(size: String) -> float:
	var ft: float = float(size.to_lower().split("x")[0])
	return ft if ft > 0.0 else 3.0


## What Step 8 hands the battle and what it stamps on the turn: {context, stamp}. It
## ROLLS (the Slyn check and the force), so call it once per launch. Split from the
## launch so a test reads it without leaving the screen.
func build_battle_payload() -> Dictionary:
	# Build crew array from deployed characters
	var crew: Array = []
	var deployed_chars: Dictionary = _deployed_data.get("deployed_characters", {})
	var armory := ArmoryScript.new()
	if "roster" in campaign:
		for char_dict in campaign.roster:
			if char_dict is Dictionary:
				var cid: String = char_dict.get("id", "")
				if deployed_chars.has(cid):
					var deployed_entry: Dictionary = deployed_chars[cid]
					var crew_entry: Dictionary = char_dict.duplicate(true)
					# Attach weapon assignment from Lock and Load
					var wid: String = str(deployed_entry.get("weapon_id", ""))
					# The battle screen's quick roll reads a figure's `weapons` ROWS (range,
					# shots, damage, traits); the bare id reached nothing, so every Planetfall
					# shot fell back to a rifle.
					var weapon: Dictionary = armory.get_weapon(wid) if wid != "" else {}
					if not weapon.is_empty():
						crew_entry["weapons"] = [weapon]
					crew.append(crew_entry)

	# The opposition, rolled now that Lock and Load is done (pp.117/121/125: "After
	# deploying, roll 2D6"), and the force it fields (pp.148-153). The battle screen
	# reads the rows; the figures are stat references for the minis on the table.
	var mission_id: String = _mission_context.get("id", "")
	var opposition: Dictionary = _mission_context.get("opposition", {})
	# p.167 Slyn assault: two Slyn checks while it lasts.
	var calamities := CalamitySystemScript.new()
	var resolved: Dictionary = BattleGuideScript.resolve_opposition(_mission_context,
			campaign != null and not campaign.is_slyn_active(),
			campaign != null and calamities.is_active(campaign, "slyn_assault"))
	var opp_type: String = str(resolved.get("type", "lifeforms"))
	var te_index: int = _battle_tactical_enemy_index() if opp_type == "tactical" else -1
	var force: Dictionary = BattleGuideScript.build_force(campaign, opp_type, opposition,
			te_index, bool(resolved.get("slyn_eight", false)))
	var enemies: Array = force.get("enemies", [])
	var force_rows: Array = []
	if str(resolved.get("line", "")) != "":
		force_rows.append({"head": str(resolved.line), "detail": ""})
	force_rows.append_array(force.get("rows", []))
	# The rules each active Calamity adds to this battle (pp.165-168).
	if campaign != null:
		force_rows.append_array(calamities.battle_rows(campaign, mission_id,
				str(_mission_context.get("sector", "")), opp_type))

	# p.123: the Skirmish objectives are a table-setup roll, made once here; p.115's
	# Discovery table is printed beside them.
	var skirmish: Array = BattleGuideScript.roll_skirmish_objectives(_mission_context)

	# Build mission_data dict for TacticalBattleUI
	var mission_data: Dictionary = {
		"battle_mode": "planetfall",
		"type": mission_id,
		"title": _mission_context.get("name", "Planetfall Mission"),
		"objective": _mission_context.get("description", ""),
		"table_size_ft": table_size_ft(str(_mission_context.get("table_size", "3x3"))),
		"battlefield_conditions": _mission_context.get("battlefield_conditions", false),
		"grunts_deployed": _deployed_data.get("grunts_deployed", 0),
		# p.30: one Reaction die per fireteam, read by TacticalBattleUI.
		"grunt_fireteams": _deployed_data.get("grunt_fireteams", 0),
		"opposition_type": opp_type,
		"slyn_attacking": bool(resolved.get("slyn_attacking", false)),
		"opposition": opposition.duplicate(true),
		"opposition_force_rows": force_rows,
		"objective_rows": BattleGuideScript.objective_rows(_mission_context, skirmish),
		"skirmish_objectives": skirmish,
		"active_condition": _mission_context.get("active_condition", {}),
		"uncertain_features": _mission_context.get("uncertain_features", false),
		"enemy_type": str(force.get("enemy_type", "")),
	}

	var deployed_ids: Array = []
	for c in crew:
		deployed_ids.append(str(c.get("id", "")))
	var stamp: Dictionary = {
		"id": mission_id,
		"mission_name": _mission_context.get("name", ""),
		"opposition_type": opp_type,
		"enemy_type": str(force.get("enemy_type", "")),
		"tactical_enemy_index": te_index,
		"grunts_deployed": int(_deployed_data.get("grunts_deployed", 0)),
		"deployed_ids": deployed_ids,
		# The Map Location sector picked at Step 6 (pp.115-130); Step 12's
		# PlanetfallMap.apply_mission_factors() applies the mission's Campaign Factors to it.
		"sector": str(_mission_context.get("sector", "")),
		# p.165: a won Strike on the super weapon site ends the Calamity.
		"weapon_site": bool(_mission_context.get("weapon_site", false)),
	}
	var battle_context: Dictionary = {
		"crew": crew,
		"enemies": enemies,
		"mission_data": mission_data,
		"mission_context": _mission_context.duplicate(true),
		"deployed_data": _deployed_data.duplicate(true)
	}
	return {"context": battle_context, "stamp": stamp}


## The Tactical Enemy a tactical mission fights: the first one not yet defeated at its
## Strongpoint (p.51), or -1. One reader for the opposition and the stamp.
func _battle_tactical_enemy_index() -> int:
	if not campaign or not "tactical_enemies" in campaign:
		return -1
	# A Skirmish, Strike, Assault or Pitched Battle is fought against the enemy its
	# sector names (pp.123-128), not whichever enemy happens to be listed first.
	# p.165: with no builder on the map, the weapon site's scouting force is "rolled on the
	# Tactical Enemies table" and "not connected to any other group".
	if bool(_mission_context.get("weapon_site", false)):
		return -1
	var site_idx: int = int(_mission_context.get("site_enemy_index", -1))
	if site_idx >= 0 and site_idx < campaign.tactical_enemies.size():
		return site_idx
	for i in range(campaign.tactical_enemies.size()):
		var te: Variant = campaign.tactical_enemies[i]
		if te is Dictionary and not te.get("defeated", false):
			return i
	return -1


## ============================================================================
## PROGRESSION SYSTEM WIRING
## ============================================================================

## Show the Milestones a step delivered (pp.156-158), once, in plain text.
func _show_milestone_receipt(receipt: Dictionary) -> void:
	var lines: Array = receipt.get("lines", []) if receipt is Dictionary else []
	if lines.is_empty():
		return
	_refresh_stat_strip()
	var dialog: AcknowledgeDialog = AcknowledgeDialog.show_message(
			self, "\n".join(PackedStringArray(lines)))
	if dialog:
		dialog.acknowledged.connect(_offer_character_awards, CONNECT_ONE_SHOT)


## p.169 Final Breakthrough awards to "characters of your choice", queued on the campaign
## by PlanetfallMissionDataSystem: one pick at a time until the queue is empty.
func _offer_character_awards() -> void:
	if not campaign or not "pending_character_awards" in campaign \
			or campaign.pending_character_awards.is_empty():
		return
	var award: Dictionary = campaign.pending_character_awards[0]
	var chosen: Array = award.get("chosen", []) if award.get("chosen") is Array else []
	var label_to_id: Dictionary = {}
	for c in campaign.roster:
		if not c is Dictionary or chosen.has(str(c.get("id", ""))):
			continue
		var label: String = str(c.get("name", "Character"))
		if label_to_id.has(label):
			label = "%s (%d)" % [label, label_to_id.size() + 1]
		label_to_id[label] = str(c.get("id", ""))
	if label_to_id.is_empty():
		# Fewer characters than the award names: the rest of its picks lapse.
		campaign.discard_character_award()
		_offer_character_awards()
		return
	var amount: int = int(award.get("amount", 0))
	var what: String = ("+%d XP" % amount) if str(award.get("stat", "")) == "xp" \
			else ("+%d Reactions" % amount)
	var popup: Window = ItemChoicePopupScript.new()
	popup.title = str(award.get("source", "Breakthrough"))
	popup.item_chosen.connect(func(picked: String) -> void:
		if campaign.grant_character_award(str(label_to_id.get(picked, ""))) != "":
			_refresh_stat_strip()
		_offer_character_awards.call_deferred())
	add_child(popup)
	popup.show_choices("%s: %s" % [str(award.get("source", "")), what], label_to_id.keys(),
			"Choose a character (%d left, p.169)" % int(award.get("picks", 1)))


## Accessors for progression systems (used by panels)

func get_milestone_system() -> RefCounted:
	return _milestone_sys

func get_calamity_system() -> RefCounted:
	return _calamity_sys

func get_mission_data_system() -> RefCounted:
	return _md_sys

func get_condition_system() -> RefCounted:
	return _condition_sys

func get_lifeform_generator() -> RefCounted:
	return _lifeform_gen

func get_enemy_generator() -> RefCounted:
	return _enemy_gen
