extends "res://src/ui/screens/planetfall/PlanetfallScreenBase.gd"

## Planetfall Campaign Turn Controller — 18-step campaign turn.
## Manages the phase flow from Recovery (Step 1) through Update Tracking (Step 18).
## Each step has a panel displayed in the main area (placeholder panels for Sprint 1).
## Follows the same architecture as BugHuntTurnController.
## Source: Planetfall pp.58-70

const PlanetfallPhaseManagerScript := preload(
	"res://src/core/campaign/PlanetfallPhaseManager.gd")
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

var phase_manager: PlanetfallPhaseManagerScript
var campaign: Resource  # PlanetfallCampaignCore
var panels: Array[Control] = []
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
var _stat_strip: HBoxContainer
var _advance_button: Button
var _save_button: Button
var _dashboard_button: Button
var _top_row: HBoxContainer
var _panel_container: Control
var _phase_scroll: ScrollContainer
var _phase_indicator_box: HBoxContainer
var _phase_indicators: Array[Label] = []

## Lower-priority stat keys collapsed away in portrait so the high-priority
## colony stats (MORALE/INTEGRITY/SP) keep room and are not crushed.
const _TOPBAR_PORTRAIT_HIDDEN_STATS: Array[String] = ["RM", "GRUNTS", "MILESTONES"]
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
	super._exit_tree()


func _initialize() -> void:
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
	# Check for endgame/completed — show EndGamePanel instead of turn flow
	var gp: String = campaign.game_phase if "game_phase" in campaign else ""
	if gp == "endgame" or gp == "completed":
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
			gs_mgr.set_temp_data("planetfall_mission", null)
	elif campaign:
		var turn: int = campaign.campaign_turn if "campaign_turn" in campaign else 0
		if turn <= 0:
			phase_manager.start_new_turn()
		else:
			phase_manager.turn_number = turn
			phase_manager.campaign_turn_started.emit(turn)
			phase_manager.go_to_phase(PlanetfallPhaseManagerScript.Phase.RECOVERY)


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

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	margin.add_child(vbox)

	# Top row: Turn label + Save button (BoxContainer so portrait can stack it
	# vertically — see _apply_topbar_responsive()).
	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_top_row)

	_turn_label = Label.new()
	_turn_label.text = "TURN 1"
	_turn_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	_turn_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(_turn_label)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(80, 36)
	_save_button.pressed.connect(_on_save_pressed)
	_top_row.add_child(_save_button)

	_dashboard_button = Button.new()
	_dashboard_button.text = "Dashboard"
	_dashboard_button.custom_minimum_size = Vector2(100, 36)
	_dashboard_button.pressed.connect(func(): _navigate("planetfall_dashboard"))
	_top_row.add_child(_dashboard_button)

	# Colony stat strip
	_stat_strip = HBoxContainer.new()
	_stat_strip.add_theme_constant_override("separation", SPACING_MD)
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

	# Current phase title
	_phase_label = Label.new()
	_phase_label.text = "RECOVERY"
	_phase_label.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL))
	_phase_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	# Panel container — holds all 18 panels, only one visible
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Bottom navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", SPACING_MD)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_advance_button = Button.new()
	_advance_button.text = "Complete Phase"
	_advance_button.custom_minimum_size = Vector2(200, TOUCH_TARGET_MIN)
	_advance_button.pressed.connect(_on_advance_pressed)
	nav.add_child(_advance_button)

	# Apply the initial portrait/landscape shape to the top bar now that it exists,
	# and listen for orientation/breakpoint changes. The base CampaignScreenBase
	# already connects layout_class_changed -> _on_layout_class_changed for its own
	# column relayout; this is a SEPARATE, dedicated connection so the top-bar
	# reshape fires on every rotation regardless of column-count dedupe.
	_connect_topbar_responsive()
	_apply_topbar_responsive()


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


## Reshape ONLY the top bar (top row + 6-label stat strip) for the current
## orientation. Landscape is left byte-for-byte identical to the original layout;
## portrait stacks the top row vertically (so Turn/Save/Dashboard are not crushed),
## hides the three lower-priority colony stats so MORALE/INTEGRITY/SP keep room,
## and bumps both buttons to >= TOUCH_TARGET_MIN (48) high.
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
		if is_instance_valid(_turn_label):
			_turn_label.size_flags_horizontal = Control.SIZE_FILL
		# Touch-friendly buttons, full-width so they are easy to hit on a phone.
		if is_instance_valid(_save_button):
			_save_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
			_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_dashboard_button):
			_dashboard_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
			_dashboard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Drop the low-priority stats so the kept three are not squeezed.
		for key in _TOPBAR_PORTRAIT_HIDDEN_STATS:
			if _stat_labels.has(key) and is_instance_valid(_stat_labels[key]):
				_stat_labels[key].visible = false
	else:
		# Restore the original landscape shape exactly.
		_top_row.vertical = false
		_top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		if is_instance_valid(_turn_label):
			_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_save_button):
			_save_button.custom_minimum_size = Vector2(80, 36)
			_save_button.size_flags_horizontal = Control.SIZE_FILL
		if is_instance_valid(_dashboard_button):
			_dashboard_button.custom_minimum_size = Vector2(100, 36)
			_dashboard_button.size_flags_horizontal = Control.SIZE_FILL
		for key in _TOPBAR_PORTRAIT_HIDDEN_STATS:
			if _stat_labels.has(key) and is_instance_valid(_stat_labels[key]):
				_stat_labels[key].visible = true


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
	var stat_keys: Array[String] = ["MORALE", "INTEGRITY", "SP", "RM", "GRUNTS", "MILESTONES"]
	for key in stat_keys:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_CYAN)
		_stat_strip.add_child(lbl)
		_stat_labels[key] = lbl
	_refresh_stat_strip()


func _refresh_stat_strip() -> void:
	if not campaign:
		return
	var morale: int = campaign.colony_morale if "colony_morale" in campaign else 0
	var integrity: int = campaign.colony_integrity if "colony_integrity" in campaign else 0
	var sp: int = campaign.story_points if "story_points" in campaign else 0
	var rm: int = campaign.raw_materials if "raw_materials" in campaign else 0
	var grunts: int = campaign.grunts if "grunts" in campaign else 0
	var milestones: int = campaign.milestones_completed if "milestones_completed" in campaign else 0

	if _stat_labels.has("MORALE"):
		_stat_labels["MORALE"].text = "Morale: %d" % morale
	if _stat_labels.has("INTEGRITY"):
		_stat_labels["INTEGRITY"].text = "Integrity: %d" % integrity
	if _stat_labels.has("SP"):
		_stat_labels["SP"].text = "SP: %d" % sp
	if _stat_labels.has("RM"):
		_stat_labels["RM"].text = "RM: %d" % rm
	if _stat_labels.has("GRUNTS"):
		_stat_labels["GRUNTS"].text = "Grunts: %d" % grunts
	if _stat_labels.has("MILESTONES"):
		_stat_labels["MILESTONES"].text = "Milestones: %d/7" % milestones


func _build_phase_indicators() -> void:
	_phase_indicators.clear()
	for i in range(PlanetfallPhaseManagerScript.PHASE_COUNT):
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
	# already handles POST_MISSION_FINDS and ENEMY_INFO internally.
	if new_phase == ph.TRACK_ENEMY_INFO:
		_process_mission_data_check()
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

	# Scroll phase indicator into view
	_scroll_indicator_into_view(new_phase)


func _on_phase_completed(_phase: int) -> void:
	_update_phase_indicators()
	_refresh_stat_strip()


func _on_turn_started(turn: int) -> void:
	_turn_label.text = "TURN %d" % turn
	_refresh_stat_strip()

	# Process active calamity ongoing effects at turn start
	if _calamity_sys and campaign:
		var cal_effects: Dictionary = _calamity_sys.process_turn_effects(campaign)
		for event in cal_effects.get("events", []):
			if event is Dictionary:
				var desc: String = event.get("description", "")
				if not desc.is_empty():
					push_warning("Calamity effect: %s" % desc)


func _on_turn_completed(_turn: int) -> void:
	_advance_button.text = "Start Next Turn"
	_advance_button.disabled = false
	_phase_label.text = "TURN COMPLETE"
	_refresh_stat_strip()


func _on_panel_phase_completed(result_data: Dictionary) -> void:
	var current: int = phase_manager.current_phase

	# Cache mission selection from Step 6 for battle launch
	if current == PlanetfallPhaseManagerScript.Phase.MISSION_DETERMINATION:
		_mission_context = result_data.get("selected_mission", {})
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

	# Step 14 (Research) / Step 15 (Building): Check for milestone grants
	if current == PlanetfallPhaseManagerScript.Phase.RESEARCH:
		_check_for_milestone_grants()
	if current == PlanetfallPhaseManagerScript.Phase.BUILDING:
		_check_for_milestone_grants()

	phase_manager.complete_current_phase(result_data)


func _on_advance_pressed() -> void:
	if phase_manager.current_phase == PlanetfallPhaseManagerScript.Phase.NONE:
		# Between turns — start new turn
		phase_manager.start_new_turn()
		_advance_button.text = "Complete Phase"
		return

	# Let the panel handle its own completion
	var panel_idx: int = phase_manager.current_phase
	if panel_idx >= 0 and panel_idx < panels.size():
		var panel: Control = panels[panel_idx]
		if panel.has_method("complete"):
			panel.complete()
		else:
			phase_manager.complete_current_phase({})


func _on_navigation_updated(_can_back: bool, can_forward: bool) -> void:
	_advance_button.disabled = not can_forward


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
	if phase_idx >= 0 and phase_idx < panels.size():
		current_panel = panels[phase_idx]
		current_panel.show()


func _update_phase_display(phase: int) -> void:
	var phase_name: String = phase_manager.get_phase_name(phase)
	var category: String = phase_manager.get_phase_category(phase)
	_phase_label.text = "%s — %s" % [category, phase_name.to_upper()]
	_advance_button.text = "Complete Phase"
	_update_phase_indicators()


func _update_phase_indicators() -> void:
	for i in range(_phase_indicators.size()):
		var indicator: Label = _phase_indicators[i]
		if i < phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif i == phase_manager.current_phase:
			indicator.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
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

	# Pass battle results to ALL PostBattlePanel instances BEFORE triggering
	# phase change, because go_to_phase() synchronously fires phase_changed
	# → refresh(). Phases 8-10 are separate PostBattlePanel instances.
	for panel in panels:
		if panel.has_method("set_battle_results"):
			panel.set_battle_results(result)

	# Jump directly to INJURIES phase
	phase_manager.go_to_phase(PlanetfallPhaseManagerScript.Phase.INJURIES)


func _show_endgame_panel() -> void:
	## Replace the normal turn flow with the EndGamePanel.
	if not _panel_container:
		return
	for child in _panel_container.get_children():
		child.queue_free()

	var endgame_panel := EndGamePanelScript.new()
	endgame_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	endgame_panel.set_campaign(campaign)
	_panel_container.add_child(endgame_panel)

	endgame_panel.phase_completed.connect(func(data: Dictionary):
		# Return to dashboard after endgame completion
		_navigate("planetfall_dashboard")
	)

	endgame_panel.refresh()

	# Update header
	if _turn_label:
		_turn_label.text = "END GAME"
	if _phase_label:
		_phase_label.text = "Decide the fate of your colony"


func _launch_planetfall_battle() -> void:
	## Step 8: Delegate to TacticalBattleUI via SceneRouter.
	## Stores battle context in temp_data for TacticalBattleUI to auto-initialize.
	## On completion, TacticalBattleUI stores results and navigates back here.
	if not campaign:
		push_warning("PlanetfallTurnController: No campaign for battle launch")
		phase_manager.complete_current_phase({})
		return

	# Build crew array from deployed characters
	var crew: Array = []
	var deployed_chars: Dictionary = _deployed_data.get("deployed_characters", {})
	if "roster" in campaign:
		for char_dict in campaign.roster:
			if char_dict is Dictionary:
				var cid: String = char_dict.get("id", "")
				if deployed_chars.has(cid):
					var deployed_entry: Dictionary = deployed_chars[cid]
					var crew_entry: Dictionary = char_dict.duplicate(true)
					# Attach weapon assignment from Lock and Load
					crew_entry["assigned_weapon"] = deployed_entry.get("weapon_id", "")
					crew.append(crew_entry)

	# Build enemies array (placeholder — actual enemy generation depends on
	# mission type: Lifeforms, Tactical Enemies, Slyn, or Delve Hazards)
	var enemies: Array = []
	var mission_id: String = _mission_context.get("id", "")
	var opposition: Dictionary = _mission_context.get("opposition", {})
	var opp_type: String = opposition.get("type", "lifeforms")

	# For now, generate a basic enemy group. Full generation would use
	# PlanetfallLifeformGenerator / PlanetfallTacticalEnemyGenerator / Slyn profile
	# based on the opposition type. The tabletop player handles the actual minis.
	enemies = _generate_opposition_for_battle(opp_type)

	# Build mission_data dict for TacticalBattleUI
	var mission_data: Dictionary = {
		"battle_mode": "planetfall",
		"type": mission_id,
		"title": _mission_context.get("name", "Planetfall Mission"),
		"objective": _mission_context.get("description", ""),
		"table_size": _mission_context.get("table_size", "3x3"),
		"battlefield_conditions": _mission_context.get("battlefield_conditions", false),
		"grunts_deployed": _deployed_data.get("grunts_deployed", 0),
		"opposition_type": opp_type,
	}

	# Build battle context for temp_data storage
	var battle_context: Dictionary = {
		"crew": crew,
		"enemies": enemies,
		"mission_data": mission_data,
		"mission_context": _mission_context.duplicate(true),
		"deployed_data": _deployed_data.duplicate(true)
	}

	# Store in temp_data for TacticalBattleUI to pick up
	var gs_mgr = get_node_or_null("/root/GameStateManager")
	if gs_mgr and gs_mgr.has_method("set_temp_data"):
		gs_mgr.set_temp_data("planetfall_battle_context", battle_context)
		gs_mgr.set_temp_data("planetfall_mission", _mission_context)

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


func _generate_opposition_for_battle(opp_type: String) -> Array:
	## Generate a basic enemy roster for the TacticalBattleUI.
	## This is a tabletop companion — the actual minis are on the physical table.
	## The enemies here provide stat references for the battle UI.
	var enemies: Array = []

	match opp_type:
		"lifeforms":
			# Use campaign lifeform table if available
			if campaign and "lifeform_table" in campaign:
				for slot in campaign.lifeform_table:
					if slot is Dictionary and not slot.is_empty():
						enemies.append({
							"name": "Lifeform",
							"speed": slot.get("speed", 6),
							"combat_skill": slot.get("combat_skill", 1),
							"toughness": slot.get("toughness", 4),
							"type": "lifeform"
						})
						break  # Use first filled slot as representative
			if enemies.is_empty():
				enemies.append({"name": "Unknown Lifeform", "speed": 6,
					"combat_skill": 1, "toughness": 4, "type": "lifeform"})

		"tactical":
			# Use campaign tactical enemies if available
			if campaign and "tactical_enemies" in campaign:
				for te in campaign.tactical_enemies:
					if te is Dictionary and not te.get("defeated", false):
						var te_type: Dictionary = te.get("type", {})
						var cs = te_type.get("combat_skill", 0)
						var tg = te_type.get("toughness", 3)
						enemies.append({
							"name": te_type.get("name", "Tactical Enemy"),
							"speed": te_type.get("speed", 4),
							"combat_skill": cs[0] if cs is Array else cs,
							"toughness": tg[0] if tg is Array else tg,
							"type": "tactical_enemy"
						})
						break
			if enemies.is_empty():
				enemies.append({"name": "Unknown Enemy", "speed": 4,
					"combat_skill": 0, "toughness": 3, "type": "tactical_enemy"})

		"slyn_check", "slyn":
			var slyn: Dictionary = {"name": "Slyn", "speed": 5,
				"combat_skill": 1, "toughness": 4, "type": "slyn"}
			enemies.append(slyn)

		"delve_hazards":
			# Delve missions don't have conventional enemies at start
			enemies.append({"name": "Sleeper", "speed": 5,
				"combat_skill": 1, "toughness": 4, "type": "sleeper"})

		_:
			enemies.append({"name": "Unknown", "speed": 4,
				"combat_skill": 0, "toughness": 3, "type": "unknown"})

	return enemies


## ============================================================================
## PROGRESSION SYSTEM WIRING
## ============================================================================

func _check_for_milestone_grants() -> void:
	## Check if any recently completed building/research/augmentation/artifact
	## grants a milestone. Called after Research (Step 14) and Building (Step 15).
	if not _milestone_sys or not campaign:
		return

	# Check buildings
	if "buildings_data" in campaign:
		for building_id in campaign.buildings_data.get("constructed", []):
			if _milestone_sys.check_tech_grants_milestone("buildings", str(building_id)):
				_trigger_milestone()
				return

	# Check research applications
	if "research_data" in campaign:
		for app_id in campaign.research_data.get("unlocked_applications", []):
			if _milestone_sys.check_tech_grants_milestone("research_applications", str(app_id)):
				_trigger_milestone()
				return

	# Check augmentations
	if "research_data" in campaign:
		for aug_id in campaign.research_data.get("augmentations_owned", []):
			if _milestone_sys.check_tech_grants_milestone("augmentations", str(aug_id)):
				_trigger_milestone()
				return

	# Check artifacts
	if "artifacts_found" in campaign:
		for artifact in campaign.artifacts_found:
			if artifact is Dictionary:
				var aid: String = artifact.get("id", "")
				if _milestone_sys.check_tech_grants_milestone("alien_artifacts", aid):
					_trigger_milestone()
					return


func _trigger_milestone() -> void:
	## Apply milestone effects and process all cascading actions.
	if not _milestone_sys or not campaign:
		return
	var current_milestones: int = campaign.milestones_completed \
		if "milestones_completed" in campaign else 0
	var next_index: int = current_milestones + 1
	if next_index > 7:
		return  # Already completed all milestones

	var result: Dictionary = _milestone_sys.apply_milestone(campaign, next_index)

	# Process actions_needed from milestone
	for action in result.get("actions_needed", []):
		if action is not Dictionary:
			continue
		var action_type: String = action.get("action", "")

		match action_type:
			"create_tactical_enemy":
				if _enemy_gen:
					_enemy_gen.create_full_enemy(campaign)

			"roll_lifeform_evolution":
				if _lifeform_gen and campaign and "lifeform_table" in campaign:
					var slot: int = randi_range(0, 9)
					var evo_roll: int = randi_range(1, 100)
					_lifeform_gen.apply_evolution(campaign, slot, evo_roll)

			"add_mission_data":
				var amount: int = action.get("amount", 0)
				_process_mission_data_addition(amount)

			"check_calamity":
				if _milestone_sys.check_calamity_trigger(campaign):
					if _calamity_sys:
						var cal_roll: int = randi_range(1, 100)
						_calamity_sys.trigger_calamity(campaign, cal_roll)

	_refresh_stat_strip()


func _process_mission_data_check() -> void:
	## After Step 12 (Track Enemy Info), check if any accumulated mission data
	## triggers a breakthrough.
	if not _md_sys or not campaign:
		return
	var md_total: int = campaign.mission_data if "mission_data" in campaign else 0
	if md_total <= 0:
		return
	# The check happens inside add_and_check — but we only check here,
	# we don't add more data. The PostBattlePanel already added the MD.
	# We just need to roll the D6 check.
	var roll: int = randi_range(1, 6)
	if roll <= md_total:
		# Breakthrough!
		if "mission_data" in campaign:
			campaign.mission_data -= roll
		if "mission_data_breakthroughs" in campaign:
			campaign.mission_data_breakthroughs += 1
		var bt_index: int = campaign.mission_data_breakthroughs
		var bt_result: Dictionary = _md_sys.process_breakthrough(campaign, bt_index)
		push_warning("Mission Data Breakthrough #%d: %s" % [
			bt_index, bt_result.get("name", "Unknown")])

		# Handle 4th breakthrough (Final D100 table)
		for needed in bt_result.get("actions_needed", []):
			if needed is Dictionary and needed.get("action", "") == "roll_final_breakthrough":
				var final_roll: int = randi_range(1, 100)
				_md_sys.roll_final_breakthrough(campaign, final_roll)


func _process_mission_data_addition(amount: int) -> void:
	## Add mission data and check for breakthrough via MissionDataSystem.
	if not _md_sys or not campaign:
		return
	var result: Dictionary = _md_sys.add_and_check(campaign, amount)
	if result.get("breakthrough", false):
		var bt_result: Dictionary = result.get("result", {})
		push_warning("Mission Data Breakthrough: %s" % bt_result.get("name", "Unknown"))
		for needed in bt_result.get("actions_needed", []):
			if needed is Dictionary and needed.get("action", "") == "roll_final_breakthrough":
				var final_roll: int = randi_range(1, 100)
				_md_sys.roll_final_breakthrough(campaign, final_roll)


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
