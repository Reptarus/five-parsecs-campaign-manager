## PreBattleUI manages the pre-battle setup interface
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control


## Dependencies
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
## Grid geometry SSOT (table sizes p.108) — preloaded per this file's
## stale-class_name-cache convention.
const BattlefieldGridClass = preload("res://src/core/battle/BattlefieldGrid.gd")
const BattleFlowGuideClass = preload("res://src/core/battle/BattleFlowGuide.gd")
## Tier copy comes from ONE place. This screen used to keep its own parallel
## list of tier names and descriptions that disagreed with the picker shown
## inside the battle, and with the code.
const BattleTierControllerRef = preload(
	"res://src/core/battle/BattleTierController.gd")
# KeywordLinker preload — bypasses the global class_name cache which can be
# stale until editor reopens (CLAUDE.md "Preload Pattern for UI Class
# References").
const KeywordLinker = preload("res://src/ui/components/tooltips/KeywordLinker.gd")
## DLCUpsellBanner preloaded by path (same stale-class_name-cache reason as above).
const DLCUpsellBanner = preload("res://src/ui/components/dlc/DLCUpsellBanner.gd")
## AdaptivePanelGroup preloaded by path — the 3 content panels collapse to a tab
## strip in portrait via this (master-detail). Same stale-class_name avoidance.
const AdaptivePanelGroupClass = preload("res://src/ui/components/base/AdaptivePanelGroup.gd")
## PortraitChrome preloaded by path (stale-class_name avoidance) — trims the root
## MarginContainer L/R margins in portrait to reclaim width on the 360dp floor.
const PortraitChromeClass = preload("res://src/ui/components/base/PortraitChrome.gd")
## The shared STOP -> PASS sweep that lets a touch-drag reach ContentScroll. Same
## preload-by-path form as WorldPhaseController.gd:43-44, the screen this is copied from.
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")
## Referenced only for SCROLL_NAME — the name ShortScreenScroll gives the scroll it
## builds. Naming it through the component keeps _content_scroll() from drifting off it.
const ShortScreenScrollRef = preload(
	"res://src/ui/components/base/ShortScreenScroll.gd")

## Signals
signal crew_selected(crew: Array)
signal deployment_confirmed
signal preview_updated
signal back_pressed

## Tracking tier selection (moved here from TacticalBattleUI overlay)
## 0 = LOG_ONLY, 1 = ASSISTED, 2 = FULL_ORACLE
var selected_tier: int = 0

## Combat representation mode (Wave 3 per-battle picker) — orthogonal to the
## tracking tier. Sprint Roadmap "representation axis": HOW the battle is fought.
##   "play_on_table" = interactive full-minis companion (default)
##   "no_minis"      = interactive No-Minis abstract panel (Freelancer's Handbook DLC)
##   "auto_resolve"  = "play it out for me" — resolver + NarrativeScreen, no tabletop
var selected_representation_mode: String = "play_on_table"

## Tier radios, tracked so picking auto-resolve can grey them out (tracking level
## is moot when the app resolves the whole battle for you).
var _tier_radios: Array[CheckBox] = []

## AI letter codes → human-readable names (Core Rules p.99, EnemyAI.json).
## Used to decode the AI cell in the enemy stat table so testers don't need
## the rulebook open to know what "T" means.
const AI_TYPE_NAMES: Dictionary = {
	"A": "Aggressive",
	"C": "Cautious",
	"T": "Tactical",
	"D": "Defensive",
	"R": "Rampage",
	"B": "Beast",
	"G": "Guardian",
}

## Node references
# %-relative so they survive the LeftPanel/CenterPanel/RightPanel reparent into
# AdaptivePanelGroup (panel-internal structure is intact; only the parent moves).
@onready var mission_info_panel = %LeftPanel/MissionInfo/VBoxContainer/Content
@onready var enemy_info_panel = %LeftPanel/EnemyInfo/VBoxContainer/Content
@onready var battlefield_preview = %PreviewContent
@onready var crew_selection_panel = %RightPanel/CrewSelection/VBoxContainer/ScrollContainer/Content
@onready var confirm_button = %ConfirmButton
@onready var back_button = %BackButton

## State
var current_mission: StoryQuestData
var selected_crew: Array = []
var _max_deploy: int = 6  # Campaign crew size deployment limit (Core Rules p.63/85)
var _deploy_label: Label  # "Deploying X / Y max" display
var _keyword_tooltip: KeywordTooltip = null  # Lazy-instantiated for inline rules popovers
var _portrait_chrome: Node = null  # PortraitChrome margin-trim helper
var _panel_group: Control = null  # AdaptivePanelGroup holding the 4 panes
var _summary_label: Label = null  # Live "Mode · Tracking" choice summary

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

## Device-keyed touch-target height: 56 on the mobile bucket, 48 otherwise
## (ResponsiveManager.get_touch_target_size). Fallback 48 in editor/headless.
func _touch_target() -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_touch_target_size"):
		return rm.get_touch_target_size()
	return 48

## Seed the two per-battle choices from what the player picked last time.
## Called before the selectors are built so the radios come up preselected.
func _restore_remembered_choices() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm == null:
		return
	if sm.has_method("get_last_tracking_tier"):
		selected_tier = clampi(int(sm.get_last_tracking_tier()), 0, 2)
	if sm.has_method("get_last_combat_mode"):
		var mode: String = str(sm.get_last_combat_mode())
		if mode in ["play_on_table", "no_minis", "auto_resolve"]:
			selected_representation_mode = mode

func _ready() -> void:
	_restore_remembered_choices()
	_apply_base_background()
	_connect_signals()
	confirm_button.disabled = true
	_setup_adaptive_panels()
	_setup_portrait_chrome()
	# Push content below the floating gear/bug buttons. Belt-and-braces: pre-battle is
	# also instantiated as a child by CampaignTurnController, where it never becomes
	# current_scene and so is never reached by the autoload's scene_changed net.
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)

	# Let the content scroll whenever it does not FIT, and pin the footer below it.
	#
	# ⚠ T11-01 (fixed 2026-09-04) was TWO defects stacked here, either fatal alone.
	# (1) This used to read "a phone in landscape has 338, let it scroll there, and
	# lay out exactly as before on anything taller" — and ShortScreenScroll gated on
	# viewport height < 620. A tablet in landscape has 689 design px, so the gate
	# never fired, the scroll stayed DISABLED, and a DISABLED ScrollContainer
	# propagates its child's minimum: the populated 4-pane group pushed the root
	# MarginContainer 196.7 px past the viewport, and because it is anchored
	# full-rect with grow_vertical = BOTH it grew in both directions. The page could
	# not be swiped because the scroll was disabled, not because it was exhausted.
	# (2) The trailing 0 meant EVERY child moved into the scroll — including
	# FooterPanel. _setup_adaptive_panels() above still says the footer "stays put —
	# always visible below the group", which was true when that comment was written
	# and was undone eight lines later by this call. Confirm/Back now sit OUTSIDE
	# the scroll, which is what a footer is for.
	var _column := get_node_or_null("MarginContainer/VBoxContainer")
	if _column is BoxContainer:
		var _sss = load("res://src/ui/components/base/ShortScreenScroll.gd").new()
		add_child(_sss)
		_sss.setup(_column as BoxContainer, 0, 620.0, 1)

	# Debug-only: name what is under the finger when a drag goes nowhere. attach()
	# returns null in a release build, so a player can never reach any of it. Its
	# scroll_started line is the discriminator the device walk reads — per the Godot
	# 4.6 docs that signal fires ONLY for a touch drag on the scrollable area (never
	# the scrollbar, the wheel or the keyboard), on Android/iOS or wherever
	# emulate_touch_from_mouse is set, which this project sets (project.godot:109).
	var _probe := TouchChainProbe.attach(self, "PreBattle")
	if _probe:
		var _cs := _content_scroll()
		if _cs != null:
			_probe.watch_scroll(_cs, ShortScreenScrollRef.SCROLL_NAME)
			# The staleness verdict has to compare like with like: this is the same
			# subtree _open_touch_chain() sweeps, not the whole screen (which would
			# count the __phase_bg ColorRect production deliberately leaves alone).
			_probe.set_sweep_root(_cs)


## Reparent the 3 content panels (Mission / Battlefield / Crew) into an
## AdaptivePanelGroup so they sit side-by-side in landscape and collapse to a tab
## strip in portrait (master-detail). The FooterPanel (Confirm/Back) is a sibling
## of MainContent, so it stays put — always visible below the group. @onready vars
## above already cached their (now %-relative, reparent-proof) node references.
##
## ⚠ "It stays put" is only true because _ready() now pins it: the ShortScreenScroll
## call below used to move every child of the VBox — footer included — into the
## scroll, silently undoing this. See the T11-01 note at that call site.
func _setup_adaptive_panels() -> void:
	var left: Control = get_node_or_null("%LeftPanel")
	var center: Control = get_node_or_null("%CenterPanel")
	var right: Control = get_node_or_null("%RightPanel")
	if not (left and center and right):
		return
	# Promote EnemyInfo (currently stacked under MissionInfo inside LeftPanel) to
	# its OWN "Forces" pane: the Mission pane becomes "what's happening + my two
	# choices", Forces becomes "who I'm fighting" — clearer read order on desktop,
	# and in portrait the enemy table gets its own tab instead of burying the
	# decisions. add_pane reparents it out of LeftPanel automatically; the
	# enemy_info_panel @onready ref already cached the inner Content node, so it
	# stays valid after the move.
	var enemy: Control = get_node_or_null("%LeftPanel/EnemyInfo")
	var main_content: Node = left.get_parent()          # the MainContent HBox
	var vbox: Node = main_content.get_parent() if main_content else null
	if not vbox:
		return
	var idx: int = main_content.get_index()
	var group := AdaptivePanelGroupClass.new()
	group.name = "AdaptiveContent"
	group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	# FOUR panes, FOUR columns: a ceiling, not a demand.
	#
	# AdaptivePanelGroup still drops columns below its own MIN_COLUMN_DESIGN_PX (320) via
	# _columns_that_fit(), so a narrow viewport gets fewer columns on its own — this only
	# stops the grid WRAPPING a pane onto a second row on a screen wide enough for four.
	# Same fix, same component, same reasoning as ShipManager.gd:104-108, which hit this
	# with its own fourth pane.
	#
	# ⭐ THE GRID RULE, verified against the engine source rather than inferred
	# (scene/gui/grid_container.cpp, NOTIFICATION_SORT_CHILDREN): a column's minimum is the
	# MAX of its children's minimums; expanded columns share the leftover width EQUALLY
	# (`remaining_space.width / col_expanded.size()`); a column whose own minimum exceeds
	# that equal share is dropped from the expanded set and receives EXACTLY its minimum.
	# `size_flags_stretch_ratio` is never read in that file. So a wrapped orphan row cannot
	# be shaped, and ONE oversize child sizes the whole row. Measured on the tablet design
	# space (2207x1379) with a mission pulled off the device: at max_columns = 4 with the
	# description NOT wrapping, the columns come out 1136 / 328 / 328 / 327; with it
	# wrapping, 528 / 528 / 528 / 527. Four columns is the shape; the autowrap at
	# _setup_mission_info() is what makes them even.
	#
	# ⚠ DESKTOP CHANGES SHAPE, DELIBERATELY. 1920x1080 is WIDE, so it also goes to four
	# ~390 px columns instead of today's 3 + Crew below the fold, and the Mission pane
	# becomes tall and scrolls. That was the owner's call (2026-09-07) over the
	# alternatives of a per-screen column floor or a supporting-pane rail.
	#
	# ⚠ CORRECTED 2026-09-06. This comment used to say the wide 8-col FORCES table is
	# what wraps to row 2. It is not, and never was: the add_pane order below is
	# Mission(0) / Forces(1) / Battlefield(2) / Crew(3), so a 3-column GridContainer
	# puts 0-2 on row 1 and leaves **Crew** alone on row 2. The comment described an
	# intent the ordering does not produce, which is part of why nobody looked at the
	# pane that actually landed there.
	#
	# ⚠ AND THAT PANE ASKED FOR NOTHING. AdaptivePanelGroup holds a plain GridContainer
	# with no row-height logic — _show_grid() sets `columns` and visibility only — so a
	# row gets its own minimum plus an EQUAL share of any surplus. Now that ShortScreenScroll
	# enables correctly (T11-01), the inner column settles at its COMBINED MINIMUM, so
	# the surplus is ZERO and row 2 receives exactly the Crew pane's own minimum. That
	# minimum was header-sized, because the crew list lives in a ScrollContainer and a
	# ScrollContainer contributes ZERO minimum on its scroll axis — while row 1 is tall
	# because PreBattle.tscn gives PreviewContent a hard custom_minimum_size of (0, 300).
	# The pane was visible and correctly laid out; it simply requested nothing, so
	# "Select Crew" rendered as a header with no list under it.
	#
	# FIX: PreBattle.tscn now gives that ScrollContainer `custom_minimum_size =
	# Vector2(0, 144)`, mirroring what PreviewContent already does one pane over.
	# 144 = 3 x UIColors.TOUCH_TARGET_MIN (48), the touch floor this very screen already
	# asserts in test_prebattle_responsive_layout.gd — three crew rows visible, the rest
	# scrolling. The number is derived from an existing constant, not invented; how many
	# rows should be visible is a product call.
	# ✅ No footer risk: ShortScreenScroll pins the footer OUTSIDE the scroll (see
	# _sss.setup(..., 1) above), so a taller scroll child lengthens the scroll range
	# instead of pushing Confirm/Back off the bottom.
	#
	# ⚠ HARDWARE VERDICT (deploy #26, TB361FU, 2026-09-07) — HALF CONFIRMED.
	#   PORTRAIT 1600x2560: PASS, and it is not this floor that saves it — the group
	#     drops to TABS (Mission | Forces | Battlefield | Crew), so Crew gets a whole
	#     tab. All 6 crew render as buttons AND "Deploying 6 / 6 max" is legible — the
	#     counter CLAUDE.md records as unreadable at 2560x1600.
	#     ⚠ That also corrects the plan's claim that TABS is "structurally unreachable":
	#     it is unreachable in LANDSCAPE, where _columns_that_fit() returns 6. Rotate and
	#     it is the normal presentation.
	#   LANDSCAPE 2560x1600: STILL BROKEN, and worse than "header-only" — the pane gets
	#     ~30 px, so the words "Select Crew" are themselves CLIPPED MID-GLYPH against the
	#     pinned footer, and the page WILL NOT SCROLL to reveal the list (swipes at five
	#     x-positions left the frame byte-identical, md5 56241bbef25b426c5a99db38cdf338a0).
	#     So a 144 px minimum on the pane is not sufficient: in landscape the row-2 pane
	#     is not merely short, it has no room AND the outer scroll is not taking the
	#     gesture. Do NOT record the Select Crew row as closed on the strength of the
	#     portrait pass — landscape is the configuration the finding was filed in.
	#
	# ⭐ ROOT-CAUSED AT THE DESK 2026-09-07 (tests/tools/probe_prebattle_landscape.gd),
	# and it was TWO defects, either fatal alone:
	#   A. the orphan row above, whose row-1 height is the MISSION pane's content — ~1042
	#      to 1120 design px for a real rival-attack mission, against a ~1222 px budget the
	#      device shrinks further (this screen is embedded under CampaignTurnController's
	#      header, so content starts ~143 px down, not 68). Fixed by the four columns here.
	#   B. the page not scrolling: every surface under a finger is MOUSE_FILTER_STOP by
	#      construction (PanelContainer's own constructor sets it — "Has visible stylebox,
	#      so stop by default"), and viewport.cpp stops Mouse/ScreenDrag/ScreenTouch there
	#      unless it is a WHEEL event. Fixed by _open_touch_chain() below.
	#
	# ✅ DEPLOY #27 (versionCode 11, TB361FU, 2026-09-07) — BOTH HALVES CONFIRMED ON
	# HARDWARE, in the orientation the finding was filed in.
	#   LANDSCAPE 2560x1600: FOUR panes in ONE ROW — Mission Info | Enemy Forces |
	#     Battlefield Preview | Select Crew — with all SIX crew buttons rendered and
	#     "Deploying 5 / 5 max" legible at the top of the pane. The briefing wrapped to
	#     three lines inside its own column instead of sizing every column.
	#   THE SWIPE: a finger drag over the Mission body SCROLLED THE PAGE (the frame
	#     changed — md5 03169a7a -> 0d0300ac — revealing the rest of the Before You
	#     Deploy checklist and the Deployment Condition block, footer still pinned). On
	#     #26 five swipe positions left the frame byte-identical. The log carries
	#     `[TouchChainProbe:PreBattle] scroll_started on ContentScroll — THE GESTURE
	#     ARRIVED` on every swipe, which per the 4.6 docs fires ONLY for a touch drag on
	#     the scrollable area — the gesture reached the container, it was not merely a
	#     frame that happened to differ.
	#   PORTRAIT 1600x2560: unchanged — still TABS, Crew tab shows all six and the
	#     counter. No regression from the four-column change.
	# ⭐ INCIDENTAL, and it closes a row this file recorded as unreadable: the p.91
	# Ambush cap is VISIBLY BOUND here — "Deploying 5 / 5 max" with Nyx Ward
	# deselected, on a six-crew roster. T11-48 was verified on #24 from the SAVE
	# because the counter could not be read at 2560x1600; it can now.
	# ⚠ THE SWEEP FIXTURE COULD NOT SEE (A): screen_populator's generated mission gave the
	# Mission pane 679 px and the 3+1 layout FIT. The pane only overflows once the mission
	# carries what CampaignTurnController actually stamps — initiative_context, setup_rules,
	# terrain_guide, objective_details, a deployment condition. A populated screen can still
	# be under-populated.
	group.max_columns = 4
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(group)
	vbox.move_child(group, idx)
	# add_pane reparents each panel out of MainContent into the group's grid.
	# Order = tab/focus index: Mission / Forces / Battlefield / Crew.
	group.add_pane(left, "Mission")
	if enemy:
		group.add_pane(enemy, "Forces")
	group.add_pane(center, "Battlefield")
	group.add_pane(right, "Crew")
	_panel_group = group
	main_content.queue_free()  # now empty; footer untouched

## The outer page scroll ShortScreenScroll builds in _ready(), or null before it has.
func _content_scroll() -> ScrollContainer:
	var n := get_node_or_null(
		"MarginContainer/VBoxContainer/" + ShortScreenScrollRef.SCROLL_NAME)
	return n as ScrollContainer


## Let a touch-drag over this page reach ContentScroll.
##
## WHY IT IS NEEDED AT ALL: every surface under a finger here is MOUSE_FILTER_STOP by
## CONSTRUCTION — PanelContainer's constructor sets it ("Has visible stylebox, so stop
## by default", scene/gui/panel_container.cpp) and so do HSeparator, CheckBox,
## OptionButton and Button — and Viewport::_gui_call_input stops Mouse, ScreenDrag and
## ScreenTouch at the first STOP control it reaches. Only WHEEL events are excepted
## (Control.mouse_force_pass_scroll_events), which is exactly why the desktop mouse
## wheel scrolled this page while a finger on the tablet did nothing.
## Measured 2026-09-07 on the populated screen: 31 controls opened; before the sweep a
## synthetic drag over the Mission body left scroll_vertical at 0 with no
## scroll_started, after it the page moved and the signal fired.
##
## WHY IT RUNS AFTER EACH SETUP CALL, not once: CampaignTurnController populates in
## three steps (setup_preview -> setup_crew_selection -> set_deployment_condition) and
## every one of them ADDS STOP controls. A sweep that runs before its children exist is
## a fix that silently does nothing — the exact way the World Phase step area stayed
## dead through two rebuild paths. open_subtree() is idempotent and STOP -> PASS only,
## so re-running it is free.
##
## ⚠ Deferred one frame: several panes finish building deferred themselves, and a
## sweep that runs first would walk a tree its own stimulus has not populated yet.
func _open_touch_chain() -> void:
	call_deferred("_open_touch_chain_now")


func _open_touch_chain_now() -> void:
	var scroll := _content_scroll()
	if scroll == null:
		return
	TouchScrollOpenerRef.open_subtree(scroll)


## Trim the root MarginContainer's L/R margins in portrait (reclaims ~32px on the
## 360dp floor) and restore them in landscape. PortraitChrome self-wires to
## ResponsiveManager.layout_class_changed; zero desktop/landscape impact.
func _setup_portrait_chrome() -> void:
	var mc := get_node_or_null("MarginContainer")
	if mc == null:
		return
	_portrait_chrome = PortraitChromeClass.new()
	add_child(_portrait_chrome)
	_portrait_chrome.setup(mc)

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

## Lazy-instantiate the shared keyword tooltip used by inline rules popovers.
## Called only when a clickable keyword surface is built, so PreBattleUI without
## special_rules / weapon traits avoids the AcceptDialog allocation entirely.
func _ensure_keyword_tooltip() -> KeywordTooltip:
	if _keyword_tooltip == null:
		_keyword_tooltip = KeywordTooltip.new()
		add_child(_keyword_tooltip)
	return _keyword_tooltip

## Connect UI signals
func _connect_signals() -> void:
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_pressed.emit()

## Accept deployment condition data and display in mission panel
func set_deployment_condition(condition: Dictionary) -> void:
	if not condition or condition.is_empty():
		return
	if not mission_info_panel:
		return

	var separator := HSeparator.new()
	mission_info_panel.add_child(separator)

	var header := Label.new()
	header.text = "Deployment Condition"
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	mission_info_panel.add_child(header)

	var title := Label.new()
	title.text = condition.get("title", "Unknown")
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	title.add_theme_color_override(
		"font_color", Color("#D97706"))
	mission_info_panel.add_child(title)

	# Show canonical rule text from Core Rules p.88
	var desc := Label.new()
	desc.text = condition.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	mission_info_panel.add_child(desc)
	_open_touch_chain()

## Setup the UI with mission data
func setup_preview(data: Dictionary) -> void:
	if not data:
		push_error("PreBattleUI: Invalid preview data")
		return

	_setup_mission_info(data)
	_setup_enemy_info(data)
	_setup_battlefield_preview(data)
	_setup_scenario_rules(data)
	_open_touch_chain()
	preview_updated.emit()

func _setup_scenario_rules(data: Dictionary) -> void:
	## The physical-setup instructions this scenario imposes before the first
	## die: Rival attack type (Core Rules pp.91-92), Invasion structure (p.92)
	## and the deployment condition's setup half (p.88).
	##
	## THE GAP THIS FILLS: these were rolled and stored, and the player was never
	## told. An Assault silently required the whole crew to set up in a building;
	## an Ambush silently cost a deployment slot; an Invasion silently ran on a
	## 6-round clock. All of it now arrives as a checklist the player can read
	## while laying out the table.
	if not mission_info_panel:
		return
	var rules: Dictionary = data.get("setup_rules", {})
	var notes: Array = rules.get("setup_notes", [])

	# HOW YOU WIN, first and in its own colour (Core Rules p.90).
	#
	# THE GAP THIS FILLS: "victory_condition" had ZERO references in this file.
	# CampaignTurnController rolls the p.89 objective and writes its win text into
	# mission_data, and the pre-battle screen — the one the player reads while
	# building the table — never showed it. The single most important fact about
	# the battle was the one fact missing.
	var win_text: String = _win_condition_text(data)

	# Terrain guidance (p.109 Standard Terrain Set). Produced by
	# CampaignTurnController._generate_terrain_setup_guide() and, like the win
	# condition, read by nothing.
	var terrain_lines: Array = []
	var tg: Dictionary = data.get("terrain", {}).get("terrain_guide", {})
	if tg.is_empty():
		tg = data.get("terrain_guide", {})
	for s in tg.get("suggestions", []):
		terrain_lines.append(str(s))

	if notes.is_empty() and win_text.is_empty() and terrain_lines.is_empty():
		return

	# Rebuilt on every preview, so clear any prior copy rather than stacking.
	for child in mission_info_panel.get_children():
		if child.name.begins_with("__scenario_rule"):
			mission_info_panel.remove_child(child)
			child.queue_free()

	var sep := HSeparator.new()
	sep.name = "__scenario_rule_sep"
	mission_info_panel.add_child(sep)

	var header := Label.new()
	header.name = "__scenario_rule_header"
	header.text = "Before You Deploy"
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	header.add_theme_color_override("font_color", Color("#4FC3F7"))
	mission_info_panel.add_child(header)

	if win_text != "":
		var win_lbl := Label.new()
		win_lbl.name = "__scenario_rule_win"
		win_lbl.text = "◆ HOW YOU WIN: %s" % win_text
		win_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		win_lbl.add_theme_font_size_override("font_size", _scaled_font(14))
		win_lbl.add_theme_color_override("font_color", Color("#10B981"))
		mission_info_panel.add_child(win_lbl)

	for i in range(terrain_lines.size()):
		var trow := Label.new()
		trow.name = "__scenario_rule_terrain_%d" % i
		trow.text = "▦  %s" % terrain_lines[i]
		trow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trow.add_theme_font_size_override("font_size", _scaled_font(14))
		trow.add_theme_color_override("font_color", Color("#808080"))
		mission_info_panel.add_child(trow)

	for i in range(notes.size()):
		var row := Label.new()
		row.name = "__scenario_rule_%d" % i
		row.text = "•  %s" % str(notes[i])
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", _scaled_font(14))
		mission_info_panel.add_child(row)

## Setup mission information
func _win_condition_text(data: Dictionary) -> String:
	## The p.90 win condition for this scenario, in the book's own words.
	##
	## Prefers the objective's own victory_condition (rolled from the p.89 D10
	## table and carried on objective_details), and falls back to
	## BattleFlowGuide's condensed summary keyed by the objective id or name.
	## Rival battles and Invasions have NO win condition at all (pp.91-92) and
	## say so, rather than showing a blank row.
	var rules: Dictionary = data.get("setup_rules", {})
	if bool(rules.get("no_win_condition", false)):
		if int(rules.get("hold_rounds", 0)) > 0:
			return "There is no Win condition — hold out for %d rounds, then flee or fight until you Hold the Field (p.92)." \
				% int(rules["hold_rounds"])
		return "There is no Win condition against Rivals — Hold the Field to improve your chance of chasing them off (p.91)."

	var details: Dictionary = data.get("objective_details", {})
	var vc: String = str(data.get("victory_condition",
		details.get("victory_condition", ""))).strip_edges()
	if vc != "":
		return vc

	var key: String = str(details.get("id", details.get("name",
		data.get("mission_objective", data.get("objective", "")))))
	return BattleFlowGuideClass.objective_win_text(key)


func _setup_mission_info(data: Dictionary) -> void:
	if not mission_info_panel:
		return

	# Rebuild, do not append. Every phase that maps to a battle launch —
	# MISSION, BATTLE_SETUP and BATTLE_RESOLUTION all share the one
	# _show_phase_ui branch that calls _initiate_battle_sequence() — lands
	# here again, and this panel owns the mission header, the Seize summary
	# AND both decision cards. Without a clear, a second pass showed the
	# player TWO Combat Mode cards and TWO Tracking Level cards, six live
	# radios in three button groups, of which only the last pair was read.
	# Observed during the 2026-09-03 desktop MCP walk (6 tier radios).
	for _old in mission_info_panel.get_children():
		mission_info_panel.remove_child(_old)
		_old.queue_free()
	_tier_radios.clear()
	_summary_label = null

	var mission_title := Label.new()
	mission_title.text = data.get("title", "Unknown Mission")

	var mission_desc := Label.new()
	mission_desc.text = data.get("description", "No description available")
	# A non-wrapping Label reports its FULL TEXT WIDTH as its minimum, and this is the
	# widest child in the pane: measured 1134 px for a 124-character rival-attack briefing
	# (765 for an 82-character one) against a title of 297 and headers under 215. Because
	# GridContainer gives an oversize column exactly its minimum and splits only the rest
	# equally, that one Label sized every column — and below the WIDE bucket it pushed the
	# whole page off BOTH edges (grow-both re-centres the overflow): measured 23 px at
	# desktop 1080p, 299 px at 1103x689, 96 px at phone landscape, all pre-existing and all
	# invisible to the sweep because its fixture's description is short. Wrapped, every
	# configuration measures 0.0 overflow. Same family as T11-42 and T11-18.
	# ⚠ Safe here, unlike the T11 "Corporate Label" trap: this Label sits in a plain VBox,
	# where children are stretched to the container width, NOT in an HBox with
	# SIZE_SHRINK_BEGIN where a 1 px minimum would make the text vanish.
	mission_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var battle_type := Label.new()
	battle_type.text = "Battle Type: " + GlobalEnums.BattleType.keys()[data.get("battle_type", 0)]

	mission_info_panel.add_child(mission_title)
	mission_info_panel.add_child(mission_desc)
	mission_info_panel.add_child(battle_type)

	# Initiative context summary (pre-computed by CampaignTurnController)
	var init_ctx: Dictionary = data.get("initiative_context", {})
	if not init_ctx.is_empty():
		var sep := HSeparator.new()
		mission_info_panel.add_child(sep)
		var init_header := Label.new()
		init_header.text = "Seize the Initiative"
		init_header.add_theme_font_size_override("font_size", _scaled_font(16))
		mission_info_panel.add_child(init_header)
		var init_info := Label.new()
		# Core Rules p.91, verbatim: a Rival "Ambush" means "you can deploy one
		# crew member less than standard ... and cannot roll to Seize the
		# Initiative". A PROHIBITION, not a modifier.
		#
		# ⚠ This block already received the answer and threw it away. The rule is
		# computed in BattleSetupRules (`can_seize_initiative = false`, :288) and
		# carried into this very dict by CampaignTurnController alongside a
		# ready-made reason string (:1371-1373) — and `InitiativeCalculator`
		# honours it (`_set_seize_forbidden`, :218-236). This surface read only
		# required_roll / highest_savvy / success_probability from the same
		# dictionary, so it advertised a roll the scenario forbids.
		#
		# MEASURED on the tablet Aug 13 2026: an Ambush whose own briefing line
		# said "cannot roll to Seize the Initiative (p.91)" was rendered two
		# blocks above as "Need 8+ on 2D6 (Savvy +2) — 42% chance". The 8+ is the
		# normal 7+ with the Rival -1 applied, so it read as a harder roll rather
		# than no roll — the most convincing possible wrong answer.
		#
		# Same mechanic, second surface: whenever two views show one rule, BOTH
		# have to read the flag that gates it.
		if init_ctx.has("can_seize") and not bool(init_ctx["can_seize"]):
			init_info.text = str(init_ctx.get("cannot_seize_reason",
				"This scenario does not allow a Seize the Initiative roll."))
			init_info.add_theme_color_override("font_color", Color("#D97706"))
		else:
			# success_probability from SeizeInitiativeSystem is ALREADY a percentage
			# (success_count / 36.0 * 100.0), matching InitiativeCalculator's usage.
			# The old `prob * 100.0` double-scaled it (e.g. 41.67 -> "4167%").
			var prob: float = init_ctx.get("success_probability", 0.0)
			init_info.text = "Need %d+ on 2D6 (Savvy +%d) — %.0f%% chance" % [
				init_ctx.get("required_roll", 10),
				init_ctx.get("highest_savvy", 0),
				prob]
			init_info.add_theme_color_override("font_color", Color("#4FC3F7"))
		init_info.add_theme_font_size_override("font_size", _scaled_font(14))
		init_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_info_panel.add_child(init_info)

	# ── Battle Setup ── the two coupled decisions (how to fight / how much to
	# track), grouped into distinct cards under one header so they read as choices
	# and don't get buried under the mission text. Combat Mode comes first because
	# it decides whether the app tracks at all (auto-resolve needs no tracking).
	var setup_sep := HSeparator.new()
	mission_info_panel.add_child(setup_sep)
	var setup_header := Label.new()
	setup_header.text = "Battle Setup"
	setup_header.add_theme_font_size_override("font_size", _scaled_font(18))
	mission_info_panel.add_child(setup_header)
	# Live glanceable summary of the current two choices (updated on each pick).
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_summary_label.add_theme_color_override("font_color", Color("#4FC3F7"))
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_info_panel.add_child(_summary_label)
	_build_representation_selector()
	_build_tier_selector()
	_update_choice_summary()

## Setup enemy information — Core Rules table format (pp.91-94)
func _setup_enemy_info(data: Dictionary) -> void:
	if not enemy_info_panel:
		return

	var enemy_force: Dictionary = data.get("enemy_force", {})
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# ── Table header: "Enemy Forces" ──
	var title := Label.new()
	title.text = "Enemy Forces"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	container.add_child(title)

	# ── Stat table (GridContainer, 8 columns) ──
	var table_panel := PanelContainer.new()
	var table_style := StyleBoxFlat.new()
	table_style.bg_color = Color("#252542")  # COLOR_ELEVATED
	table_style.border_color = Color("#3A3A5C")  # COLOR_BORDER
	table_style.set_border_width_all(1)
	table_style.set_corner_radius_all(4)
	table_style.set_content_margin_all(4)
	table_panel.add_theme_stylebox_override("panel", table_style)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header row
	var headers := ["ENEMY", "NUMBERS", "PANIC", "SPEED",
		"CMB", "TGH", "AI", "WEAPONS"]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(10))
		lbl.add_theme_color_override("font_color", Color("#808080"))
		grid.add_child(lbl)

	# Data row
	var type_name: String = enemy_force.get("type", "")
	if type_name.is_empty():
		type_name = data.get("enemy_type",
			data.get("enemy_faction", "Unknown"))

	var spd: int = enemy_force.get("speed", 0)
	var cmb: int = enemy_force.get("combat_skill", 0)
	var tgh: int = enemy_force.get("toughness", 0)
	var numbers_str: String = str(enemy_force.get("numbers", ""))
	var panic_str: String = str(enemy_force.get("panic", ""))
	var ai_raw: String = str(enemy_force.get("ai", ""))
	# Decode AI letter to letter+name (e.g. "T → Tactical") for readability.
	# Falls back to raw letter if unrecognized.
	var ai_str: String = ai_raw
	if AI_TYPE_NAMES.has(ai_raw):
		ai_str = "%s (%s)" % [ai_raw, AI_TYPE_NAMES[ai_raw]]
	var weapons_val = enemy_force.get("weapons", "")
	var weapons_str: String = ""
	if weapons_val is Array:
		weapons_str = ", ".join(
			weapons_val.map(func(w): return str(w)))
	else:
		weapons_str = str(weapons_val)

	var cmb_str := "+%d" % cmb if cmb >= 0 else str(cmb)
	var values := [type_name, numbers_str, panic_str,
		'%d"' % spd, cmb_str, str(tgh), ai_str, weapons_str]

	for i in range(values.size()):
		var raw_value: String = str(values[i])
		# Col 7 = weapons. Wrap recognized trait/weapon keywords as clickable
		# popovers (Pistol, Heavy, etc. are all in KeywordDB).
		if i == 7 and not raw_value.is_empty():
			var weapons_rtl := RichTextLabel.new()
			weapons_rtl.bbcode_enabled = true
			weapons_rtl.fit_content = true
			weapons_rtl.scroll_active = false
			weapons_rtl.text = KeywordLinker.wrap_known_keywords(raw_value)
			weapons_rtl.add_theme_font_size_override(
				"normal_font_size", _scaled_font(13))
			weapons_rtl.add_theme_color_override(
				"default_color", Color("#4FC3F7"))
			KeywordLinker.attach(weapons_rtl, _ensure_keyword_tooltip())
			grid.add_child(weapons_rtl)
			continue

		var lbl := Label.new()
		lbl.text = raw_value
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		if i == 0:
			# Enemy name in red
			lbl.add_theme_color_override(
				"font_color", Color("#DC2626"))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			lbl.add_theme_color_override(
				"font_color", Color("#4FC3F7"))
		grid.add_child(lbl)

	# Horizontal-scroll wrapper (Godot 4.6 ScrollContainer): the 8-col table
	# exceeds a ~321px portrait pane. h=AUTO / v=DISABLED means the grid keeps
	# its full min width on the scroll axis and SWIPES in portrait; in landscape
	# the grid min < pane width so — because the grid still has SIZE_EXPAND_FILL —
	# the ScrollContainer stretches it to fill and shows NO scrollbar
	# (pixel-identical to before). Pattern mirrors CompendiumCategoryView.
	var table_scroll := ScrollContainer.new()
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	table_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(grid)
	table_panel.add_child(table_scroll)
	container.add_child(table_panel)

	# ── Count ──
	var total: int = enemy_force.get("count",
		data.get("enemy_count", 0))
	if total > 0:
		var count_lbl := Label.new()
		count_lbl.text = "Count: %d" % total
		count_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		container.add_child(count_lbl)

	# ── Category rules (Core Rules pp.95-96) ──
	# Surfaces the parent enemy-category's rules block (Criminal Elements,
	# Hired Muscle, Interested Parties, Roving Threats). Players need this to
	# understand category-wide modifiers like "Hired Muscle: -1 to Seize the
	# Initiative" before they decide on tier.
	var category_name: String = str(enemy_force.get("category_name", ""))
	var category_rules: String = str(enemy_force.get("category_rules", ""))
	var seize_init_mod: int = int(enemy_force.get("seize_initiative_modifier", 0))
	if not category_name.is_empty() or not category_rules.is_empty():
		var cat_header := Label.new()
		var header_text: String = "Category: %s" % category_name if not category_name.is_empty() else "Category"
		if seize_init_mod != 0:
			header_text += "  (Seize Init %+d)" % seize_init_mod
		cat_header.text = header_text
		cat_header.add_theme_font_size_override("font_size", _scaled_font(12))
		cat_header.add_theme_color_override("font_color", Color("#10B981"))  # COLOR_SUCCESS
		container.add_child(cat_header)

		if not category_rules.is_empty():
			var cat_rules_rtl := RichTextLabel.new()
			cat_rules_rtl.bbcode_enabled = true
			cat_rules_rtl.fit_content = true
			cat_rules_rtl.scroll_active = false
			cat_rules_rtl.text = KeywordLinker.wrap_known_keywords(category_rules)
			cat_rules_rtl.add_theme_font_size_override(
				"normal_font_size", _scaled_font(11))
			cat_rules_rtl.add_theme_color_override(
				"default_color", Color("#808080"))  # COLOR_TEXT_SECONDARY
			cat_rules_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			KeywordLinker.attach(cat_rules_rtl, _ensure_keyword_tooltip())
			container.add_child(cat_rules_rtl)

	# ── Special rules ──
	# RichTextLabels with KeywordLinker so terms like "Heavy", "Area", "Stun" pop
	# the rules tooltip on click (Core Rules trait names live in KeywordDB).
	var rules: Array = enemy_force.get("special_rules", [])
	for rule in rules:
		var rule_rtl := RichTextLabel.new()
		rule_rtl.bbcode_enabled = true
		rule_rtl.fit_content = true
		rule_rtl.scroll_active = false
		rule_rtl.text = KeywordLinker.wrap_known_keywords(str(rule))
		rule_rtl.add_theme_font_size_override(
			"normal_font_size", _scaled_font(12))
		rule_rtl.add_theme_color_override(
			"default_color", Color("#D97706"))
		rule_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		KeywordLinker.attach(rule_rtl, _ensure_keyword_tooltip())
		container.add_child(rule_rtl)

	enemy_info_panel.add_child(container)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
	if not battlefield_preview:
		return

	# Gather terrain data from preview data or GameState. The stored
	# active_battlefield contract is FLAT (sectors at top level), so
	# bf_data.get("terrain", bf_data) resolves to the contract itself.
	var terrain_data: Dictionary = data.get("terrain", {})
	if terrain_data.is_empty():
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("get_battlefield_data"):
			var bf_data: Dictionary = game_state.get_battlefield_data()
			terrain_data = bf_data.get("terrain", bf_data)

	if terrain_data.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Terrain suggestions not available.\nSet up terrain on your physical table as desired."
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placeholder.add_theme_color_override("font_color", Color("#9ca3af"))
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		battlefield_preview.add_child(placeholder)
		return

	# Prefer the display name; fall back to the theme key
	var theme_name: String = terrain_data.get("theme_name",
		terrain_data.get("theme", ""))

	# Try to extract sector data for the visual map view
	var sector_array: Array = _extract_sector_array(terrain_data)
	if not sector_array.is_empty():
		# Stack: table-size override row above the map (PreviewContent is a
		# bare anchoring Control, so stacking needs a VBox)
		var preview_vbox := VBoxContainer.new()
		preview_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview_vbox.add_theme_constant_override("separation", 4)
		battlefield_preview.add_child(preview_vbox)

		var table_ft: float = float(terrain_data.get("table_size_ft", 3.0))
		preview_vbox.add_child(_build_table_size_override(table_ft))

		# Use BattlefieldMapView for visual overhead grid
		var map_view := BattlefieldMapView.new()
		map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Size the grid to the persisted table size (Core Rules p.108)
		if map_view.has_method("configure_grid"):
			map_view.configure_grid(BattlefieldGridClass.dims_for_table(table_ft))
		var world_traits: Array = terrain_data.get("world_traits", [])
		map_view.populate_from_sectors(sector_array, theme_name, world_traits)
		# Show the persisted objective markers on the preview too
		var stored_obj: Variant = terrain_data.get("objective_positions", [])
		if stored_obj is Array and not stored_obj.is_empty() \
				and map_view.has_method("set_objective_positions"):
			var rehydrated: Array = []
			for obj in stored_obj:
				if obj is Dictionary:
					var o: Dictionary = obj.duplicate()
					o["grid_pos"] = BattlefieldGridClass.json_to_grid_pos(
						o.get("grid_pos"))
					rehydrated.append(o)
			map_view.set_objective_positions(rehydrated)
		preview_vbox.add_child(map_view)

		# Store terrain data for passthrough to post-battle
		# NO terrain passthrough. This used to write a "battlefield_terrain"
		# temp-data blob whose ONLY consumer was
		# PostBattleSummarySheet._setup_battlefield_recap. That component was
		# deleted 2026-09-04 (unreachable from product and tests), so the write
		# had no reader left. The battlefield itself already survives the battle
		# through GameState.set_battlefield_data() / active_battlefield, which is
		# the persisted contract every other consumer reads.
		return

	# Fallback: render terrain suggestions as text
	_setup_text_terrain_fallback(terrain_data, theme_name)

## Extract sector data into the Array format BattlefieldMapView expects.
## Handles the generator/contract Array format, dict-keyed sectors, and
## pre-formatted sector arrays.
func _extract_sector_array(terrain_data: Dictionary) -> Array:
	# Format A: sectors as Array of {label, features} — the shape both the
	# generator and the persisted active_battlefield contract emit.
	# (Pre-2026-07-02 this format was NOT handled, so the visual preview
	# could never render generator output.)
	var sectors: Variant = terrain_data.get("sectors",
		terrain_data.get("sector_list", []))
	if sectors is Array and not sectors.is_empty():
		return sectors

	# Format B: sectors as Dictionary {label: features_or_description}
	if sectors is Dictionary and not sectors.is_empty():
		var result: Array = []
		for sector_key: String in sectors:
			var sector_info = sectors[sector_key]
			var features: Array = []
			if sector_info is Array:
				features = sector_info
			elif sector_info is String:
				# Single description string — split on comma or use as-is
				if ", " in sector_info:
					features = sector_info.split(", ")
				else:
					features = [sector_info]
			elif sector_info is Dictionary:
				features = sector_info.get("features", [])
			result.append({"label": sector_key, "features": features})
		return result

	return []

## Per-battle table-size override row (Core Rules p.108). Changing it does
## NOT re-roll terrain dice (the 5-step process is size-independent,
## Compendium p.94) — it re-derives grid geometry + marker positions from
## the SAME seeds and persists the choice.
func _build_table_size_override(current_ft: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Table:"
	lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	lbl.add_theme_color_override("font_color", Color("#E0E0E0"))
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.add_item("2x2 ft", 20)
	opt.add_item("2.5x2.5 ft", 25)
	opt.add_item("3x3 ft", 30)
	var cur_id: int = int(roundf(current_ft * 10.0))
	for i in range(opt.item_count):
		if opt.get_item_id(i) == cur_id:
			opt.select(i)
			break
	opt.custom_minimum_size = Vector2(140, _touch_target())
	opt.accessibility_name = "Battle table size override"
	opt.item_selected.connect(func(idx: int) -> void:
		_on_table_size_override(opt.get_item_id(idx) / 10.0))
	row.add_child(opt)
	var hint := Label.new()
	hint.text = "(p.108 — dice unchanged)"
	hint.add_theme_font_size_override("font_size", _scaled_font(11))
	hint.add_theme_color_override("font_color", Color("#808080"))
	row.add_child(hint)
	return row

## Re-derive grid geometry + marker positions for the new size and persist.
func _on_table_size_override(new_ft: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("get_battlefield_data"):
		return
	var contract: Dictionary = gs.get_battlefield_data()
	if contract.get("sectors", []) is Array \
			and contract.get("sectors", []).is_empty():
		return
	contract["table_size_ft"] = new_ft
	var dims: Dictionary = BattlefieldGridClass.dims_for_table(new_ft)

	# Objective + enemy markers derive from grid dims — recompute
	# deterministically from the SAME seeds (terrain dice untouched).
	var GenClass = load("res://src/core/battle/BattlefieldGenerator.gd")
	var gen = GenClass.new()
	var base_seed: int = int(contract.get("seed", 0))
	var obj_rng := RandomNumberGenerator.new()
	obj_rng.seed = hash("%d|objectives" % base_seed)
	var runtime_obj: Array = gen.compute_objective_positions(
		str(contract.get("mission_objective", "")),
		contract.get("sectors", []), obj_rng, dims)
	runtime_obj = GenClass.append_notable_sight_marker(
		runtime_obj, contract.get("notable_sight", {}), dims)
	var obj_json: Array = []
	for obj in runtime_obj:
		var oj: Dictionary = obj.duplicate()
		oj["grid_pos"] = BattlefieldGridClass.grid_pos_to_json(
			oj.get("grid_pos", Vector2.ZERO))
		obj_json.append(oj)
	contract["objective_positions"] = obj_json
	var marker_rng := RandomNumberGenerator.new()
	marker_rng.seed = hash("%d|enemy_markers" % base_seed)
	contract["enemy_markers"] = GenClass.compute_enemy_deploy_markers(
		str(contract.get("enemy_ai", "")),
		int(contract.get("enemy_count", 0)), marker_rng, dims)
	gs.set_battlefield_data(contract)

	# Rebuild the preview with the new geometry (re-reads from GameState)
	for child in battlefield_preview.get_children():
		child.queue_free()
	_setup_battlefield_preview({})

## Text fallback for terrain data without structured sectors
func _setup_text_terrain_fallback(terrain_data: Dictionary, theme_name: String) -> void:
	var terrain_log := RichTextLabel.new()
	terrain_log.bbcode_enabled = true
	terrain_log.fit_content = true
	terrain_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_log.add_theme_color_override("default_color", Color("#f3f4f6"))
	terrain_log.add_theme_font_size_override("normal_font_size", _scaled_font(14))

	var bbcode: String = "[b]Terrain Setup Guide[/b]\n\n"
	if theme_name != "":
		bbcode += "[color=#f59e0b]Theme:[/color] %s\n\n" % theme_name

	if terrain_data.has("suggestions"):
		var suggestions: Array = terrain_data.get("suggestions", [])
		for suggestion in suggestions:
			bbcode += "- %s\n" % str(suggestion)
	elif terrain_data.has("description"):
		bbcode += str(terrain_data["description"])

	terrain_log.text = bbcode
	battlefield_preview.add_child(terrain_log)

## Setup crew selection — accepts both Character objects and Dictionaries
## max_deploy: deployment cap from campaign crew size setting (Core Rules p.63/85)
func setup_crew_selection(
	available_crew: Array, max_deploy: int = 6
) -> void:
	if not crew_selection_panel:
		return
	# T11-48. IDEMPOTENT. This used to clear neither the panel nor the selection,
	# so a second call (Back then forward, or any re-entry) stacked a duplicate
	# button list on top of the first AND inherited the previous picks: the
	# pre-select loop below only fills while `selected_crew.size() < _max_deploy`,
	# so an already-full selection left every NEW button rendering unpressed while
	# the stale picks stayed live. That was cosmetic for as long as nothing
	# consumed get_selected_crew(); now that the battle actually deploys it, a
	# stale selection is the wrong crew on the table.
	for stale in crew_selection_panel.get_children():
		crew_selection_panel.remove_child(stale)
		stale.queue_free()
	selected_crew.clear()
	_max_deploy = max_deploy

	var crew_list := VBoxContainer.new()

	# Deployment counter label
	_deploy_label = Label.new()
	_deploy_label.add_theme_font_size_override("font_size", 14)
	_deploy_label.add_theme_color_override(
		"font_color", Color("#4FC3F7"))
	crew_list.add_child(_deploy_label)

	for item in available_crew:
		var char_button := Button.new()
		if item is Character:
			char_button.text = item.name
		elif item is Dictionary:
			char_button.text = item.get(
				"name", item.get("character_name", "Unknown"))
		else:
			char_button.text = str(item)
		char_button.toggle_mode = true
		# Touch target + long-name wrap: wrap within the (expanding) button so a
		# long crew name never widens the column / clips in the narrow Crew tab.
		char_button.custom_minimum_size.y = _touch_target()
		char_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Style the pressed/selected state
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color("#2D5A7B")
		pressed_style.border_color = Color("#4FC3F7")
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(8)
		char_button.add_theme_stylebox_override("pressed", pressed_style)
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color("#1E1E36")
		normal_style.border_color = Color("#3A3A5C")
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(8)
		char_button.pressed.connect(
			_on_character_selected.bind(item, char_button))
		crew_list.add_child(char_button)
		# Pre-select up to max_deploy crew members
		if selected_crew.size() < _max_deploy:
			char_button.button_pressed = true
			selected_crew.append(item)

	crew_selection_panel.add_child(crew_list)
	_update_deploy_label()
	_open_touch_chain()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

## Handle character selection with deployment limit enforcement
func _on_character_selected(character, button: Button = null) -> void:
	if selected_crew.has(character):
		selected_crew.erase(character)
	else:
		# Enforce deployment cap (Core Rules p.63/85)
		if selected_crew.size() >= _max_deploy:
			# Revert toggle — at deployment limit
			if button:
				button.button_pressed = false
			return
		selected_crew.append(character)

	_update_deploy_label()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

func _update_deploy_label() -> void:
	if not _deploy_label:
		return
	_deploy_label.text = "Deploying %d / %d max" % [
		selected_crew.size(), _max_deploy]
	# Red at empty (can't confirm), amber at the cap (no room left), cyan between.
	var col := Color("#4FC3F7")
	if selected_crew.is_empty():
		col = Color("#DC2626")
	elif selected_crew.size() >= _max_deploy:
		col = Color("#D97706")
	_deploy_label.add_theme_color_override("font_color", col)

## Handle confirm button press
func _on_confirm_pressed() -> void:
	deployment_confirmed.emit()

## Update confirm button state
func _update_confirm_button() -> void:
	if not confirm_button:
		return

	# Require crew selection (terrain always renders — map or text fallback)
	confirm_button.disabled = selected_crew.is_empty()
	# Tell the player WHY Confirm is disabled (the common case is no crew picked).
	confirm_button.tooltip_text = "Select at least one crew member to deploy" \
		if selected_crew.is_empty() else ""

## Build a styled "decision card" (PanelContainer + inner VBox) appended to the
## Mission pane, returning the inner VBox for the caller to fill. Bounds each
## battle-setup choice so it reads as a distinct, self-contained decision.
func _make_decision_card(title_text: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1E1E36")      # COLOR_INPUT
	style.border_color = Color("#3A3A5C")  # COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	vb.add_child(title)
	mission_info_panel.add_child(card)
	return vb

## Build the tracking tier radio buttons (LOG_ONLY / ASSISTED / FULL_ORACLE)
func _build_tier_selector() -> void:
	if not mission_info_panel:
		return

	var card := _make_decision_card("Tracking Level")

	var desc := Label.new()
	desc.text = "How much should the app track for you?"
	desc.add_theme_font_size_override("font_size", _scaled_font(12))
	desc.add_theme_color_override("font_color", Color("#808080"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)

	# Read the copy from the controller rather than keeping a second list here.
	# The two used to disagree: this screen promised "Full Oracle — AI runs enemy
	# turns" while the tier picker inside the battle promised it would "manage
	# everything", and the code does neither — it adds an oracle panel to the
	# enemy tracker and the player still moves every figure.
	var tier_names: Array[String] = []
	for t in [0, 1, 2]:
		var info: Dictionary = BattleTierControllerRef.TIER_INFO.get(t, {})
		tier_names.append("%s — %s" % [str(info.get("name", "?")),
			str(info.get("description", ""))])
	var button_group := ButtonGroup.new()
	_tier_radios.clear()
	for i in range(tier_names.size()):
		var radio := CheckBox.new()
		radio.text = tier_names[i]
		radio.button_group = button_group
		radio.add_theme_font_size_override("font_size", _scaled_font(14))
		radio.custom_minimum_size.y = _touch_target()  # Touch-friendly
		radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long labels wrap at 360dp
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Tracking level is meaningless when the app resolves the whole battle.
		# _on_representation_radio_pressed() applies this rule when the player
		# PRESSES auto-resolve, but the mode can also arrive from
		# _restore_remembered_choices() — which sets the field and runs no side
		# effect, and could not disable these anyway because _tier_radios is
		# still empty at _ready(). Without this line a remembered auto-resolve
		# rendered three live radios that persisted a tier nothing would read.
		radio.disabled = (selected_representation_mode == "auto_resolve")
		if i == selected_tier:
			radio.button_pressed = true
		radio.pressed.connect(_on_tier_radio_pressed.bind(i))
		_tier_radios.append(radio)
		card.add_child(radio)

func _on_tier_radio_pressed(tier: int) -> void:
	selected_tier = tier
	# Remembered for the next battle. Stored in SettingsManager, the single
	# owner of options.cfg, not in the campaign — it is a preference about how
	# this player likes to run a fight, not a fact about the campaign.
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("set_last_tracking_tier"):
		sm.set_last_tracking_tier(tier)
	_update_choice_summary()

## Live "Mode · Tracking" summary so the current two choices are glanceable
## without scrolling the cards. Auto-resolve reads differently (no tracking).
func _update_choice_summary() -> void:
	if not _summary_label:
		return
	var mode_names := {
		"play_on_table": "Play on table",
		"no_minis": "No-minis",
		"auto_resolve": "Auto-resolve",
	}
	var tier_names := ["Log Only", "Assisted", "Full Oracle"]
	var mode_txt: String = mode_names.get(
		selected_representation_mode, selected_representation_mode)
	if selected_representation_mode == "auto_resolve":
		_summary_label.text = "Mode: %s — the app resolves the whole battle" % mode_txt
	else:
		var tier_txt: String = tier_names[selected_tier] \
			if selected_tier >= 0 and selected_tier < tier_names.size() else "?"
		_summary_label.text = "Mode: %s · Tracking: %s" % [mode_txt, tier_txt]

## Build the per-battle combat representation picker (Wave 3, Sprint Roadmap
## "representation axis"). Three options; No-Minis is gated on Freelancer's
## Handbook DLC OWNERSHIP (not the global toggle — this picker IS the per-battle
## toggle). Auto-resolve is a base feature (the "digital version" value prop) and
## is never gated. Writes selected_representation_mode, read by
## CampaignTurnController._on_deployment_confirmed().
func _build_representation_selector() -> void:
	if not mission_info_panel:
		return

	var card := _make_decision_card("Combat Mode")

	var desc := Label.new()
	desc.text = "How do you want to fight this battle?"
	desc.add_theme_font_size_override("font_size", _scaled_font(12))
	desc.add_theme_color_override("font_color", Color("#808080"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)

	# DLC OWNERSHIP gate (is_feature_available ignores the global toggle — the
	# picker itself is the per-battle toggle). Null-safe for editor/headless.
	var dlc := get_node_or_null("/root/DLCManager")
	var no_minis_owned: bool = false
	if dlc and dlc.has_method("is_feature_available"):
		no_minis_owned = dlc.is_feature_available(dlc.ContentFlag.NO_MINIS_COMBAT)

	# Each row: [mode_id, label, enabled, locked_flag_name_for_upsell]
	var options: Array = [
		["play_on_table",
			"Play on my table — track my physical game", true, ""],
		["no_minis",
			"No-minis abstract — resolve by zones, no miniatures",
			no_minis_owned, "NO_MINIS_COMBAT"],
		["auto_resolve",
			"Play it out for me — auto-resolve as a story", true, ""],
	]

	var group := ButtonGroup.new()
	for opt in options:
		var mode_id: String = opt[0]
		var enabled: bool = opt[2]
		var locked_flag: String = opt[3]

		var radio := CheckBox.new()
		radio.text = opt[1]
		radio.button_group = group
		radio.add_theme_font_size_override("font_size", _scaled_font(14))
		radio.custom_minimum_size.y = _touch_target()  # Touch-friendly
		radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radio.disabled = not enabled
		if mode_id == selected_representation_mode and enabled:
			radio.button_pressed = true
		radio.pressed.connect(_on_representation_radio_pressed.bind(mode_id))
		card.add_child(radio)

		# Locked option → subtle, non-aggressive contextual upsell beneath it.
		if not enabled and not locked_flag.is_empty():
			var banner := DLCUpsellBanner.create_for_flag(locked_flag)
			card.add_child(banner)

func _on_representation_radio_pressed(mode: String) -> void:
	selected_representation_mode = mode
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("set_last_combat_mode"):
		sm.set_last_combat_mode(mode)
	# Tracking level is meaningless when the app resolves the whole battle.
	var is_auto: bool = (mode == "auto_resolve")
	for r in _tier_radios:
		if is_instance_valid(r):
			r.disabled = is_auto
	_update_choice_summary()

## Get selected crew
func get_selected_crew() -> Array:
	return selected_crew

## Cleanup
func cleanup() -> void:
	selected_crew.clear()
	current_mission = null

	# Clear UI panels
	for child in mission_info_panel.get_children():
		child.queue_free()
	for child in enemy_info_panel.get_children():
		child.queue_free()
	for child in battlefield_preview.get_children():
		child.queue_free()
	for child in crew_selection_panel.get_children():
		child.queue_free()
