extends Control
class_name WorldPhaseController

## Core Rules p.149 Red Job Threat Condition. Path-loaded rather than
## `class_name`-referenced to match this file's other data-layer imports.
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")

## WorldPhaseController - Orchestrator for Campaign Turn Workflow
## Replaces 3,910-line WorldPhaseUI monolith with focused component coordination
## Implements Mediator pattern for component interactions

# Signals for phase transition integration
signal phase_completed(results: Dictionary)
signal return_to_dashboard
signal return_to_travel  # Sprint 10.2: Signal for bidirectional navigation
signal proceed_to_battle
## Errata v1.06 (Campaign rules, Update), verbatim: "Normally you have to
## undertake a new mission every campaign turn. If you wish to lay low and rest
## up, check for Rival attacks normally. If you are not attacked, you can pay
## 1D6+1 Credits to stay in town. Simply skip the battle sequence and all reward
## sections (loot, pay, injuries, XP)." Emitted WITHOUT completing the phase —
## the Rival check has to happen first and may force a battle anyway.
signal lay_low_requested

# Event bus integration - single source of truth for events
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
## Core Rules p.85 "Check for Rivals" — used here only for its crew-task readers
## (decoy count / tracked Rivals). Path preload: no class_name on that script.
const RivalEncounterCheckClass = preload("res://src/core/campaign/RivalEncounterCheck.gd")
var event_bus: CampaignTurnEventBus = null
## Event-bus subscriptions made by THIS controller, so _exit_tree() can undo them.
## The bus is parented to /root and outlives every scene change.
var _event_subscriptions: Array[Dictionary] = []

# Component dependencies
const UpkeepPhaseComponent = preload("res://src/ui/screens/world/components/UpkeepPhaseComponent.gd")
const CrewTaskComponent = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const JobOfferComponent = preload("res://src/ui/screens/world/components/JobOfferComponent.gd")
const MissionPrepComponent = preload("res://src/ui/screens/world/components/MissionPrepComponent.gd")
const CompendiumWorldOptionsRef = preload("res://src/data/compendium_world_options.gd")
const FringeWorldStrifeRef = preload("res://src/core/world/FringeWorldStrife.gd")
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")
const AssignEquipmentComponent = preload("res://src/ui/screens/world/components/AssignEquipmentComponent.gd")
const ResolveRumorsComponent = preload("res://src/ui/screens/world/components/ResolveRumorsComponent.gd")
# Note: PurchaseItems, CampaignEvent, CharacterEvent components moved to PostBattleSequence

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const PsionicLegalityBadgeClass = preload("res://src/ui/components/world/PsionicLegalityBadge.gd")

# UI Components (replaced monolith references)
const WorldBriefingBuilderScript = preload("res://src/core/world/WorldBriefingBuilder.gd")

@onready var phase_container: Control = %PhaseContainer

# PhaseContainer's and PhaseScroll's mouse_filter as the SCENE defines them, captured
# before compaction first overrides them so the relaxed layout can be restored to those
# rather than to a hard-coded guess. Negative means "not captured yet".
# See _apply_vertical_compaction().
var _phase_container_mouse_filter: int = -1
var _phase_scroll_mouse_filter: int = -1

# The layout currently ON SCREEN, as last decided by _apply_vertical_compaction().
#
# Everything that runs later reads this instead of re-deriving it. Re-asking _is_tight()
# from a content-rebuild hook is not the same question: the briefing has just queue_free()d
# its children at that point, so the column's minimums are momentarily tiny, the budget
# reads huge, and the answer comes back "not tight" for a screen that is plainly tight.
# Measured on the tablet — the sweep opened 33 controls and a later re-measure closed all
# 33 again, leaving touch-drag exactly as dead as before the fix.
var _is_tight_layout: bool = false

@onready var step_navigation: Container = %StepNavigation  # HFlowContainer (wraps in portrait)
@onready var current_step_label: Label = %CurrentStepLabel
@onready var progress_bar: ProgressBar = %PhaseProgressBar
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var automation_toggle: CheckBox = %AutomationToggle
@onready var back_to_dashboard_button: Button = %BackToDashboardButton
@onready var proceed_to_battle_button: Button = %ProceedToBattleButton
@onready var lay_low_button: Button = %LayLowButton

# Component containers - properly structured scene hierarchy
@onready var upkeep_container: Control = %UpkeepContainer
@onready var crew_task_container: Control = %CrewTaskContainer
@onready var job_offer_container: Control = %JobOfferContainer
@onready var assign_equipment_container: Control = %AssignEquipmentContainer
@onready var resolve_rumors_container: Control = %ResolveRumorsContainer
@onready var mission_prep_container: Control = %MissionPrepContainer
# Note: Post-battle containers (PurchaseItems, CampaignEvent, CharacterEvent) moved to PostBattleSequence

# Phase management - Core Rules STEP 2 (World Phase)
# Note: Purchase Items, Campaign Event, Character Event are in Post-Battle (STEP 4)
enum WorldPhaseStep {
	UPKEEP = 0,
	CREW_TASKS = 1,
	JOB_OFFERS = 2,
	ASSIGN_EQUIPMENT = 3,
	RESOLVE_RUMORS = 4,
	MISSION_PREP = 5  # Final step - Choose Your Battle
}

var current_step: WorldPhaseStep = WorldPhaseStep.UPKEEP
var step_names: Array[String] = [
	"Travel & Upkeep", "Crew Tasks", "Job Offers", "Assign Equipment",
	"Resolve Rumors", "Mission Prep"
]
var step_completed: Dictionary = {} # WorldPhaseStep -> bool
var automation_enabled: bool = false
var _blocker_label: Label = null # readout shown when "Next Step" is disabled

# Component instances - directly reference scene-instanced components
@onready var upkeep_component = %UpkeepContainer/UpkeepPhaseComponent
@onready var crew_task_component = %CrewTaskContainer/CrewTaskComponent
@onready var job_offer_component = %JobOfferContainer/JobOfferComponent
@onready var assign_equipment_component = %AssignEquipmentContainer/AssignEquipmentComponent
@onready var resolve_rumors_component = %ResolveRumorsContainer/ResolveRumorsComponent
@onready var mission_prep_component = %MissionPrepContainer/MissionPrepComponent
# Note: Post-battle component refs removed - now in PostBattleSequence
var _psionic_badge: PsionicLegalityBadgeClass = null

# Campaign data
var world_phase_data: Dictionary = {}

# Persistent "World Briefing" panel (fills the space short steps leave empty).
var _world_briefing_vbox: VBoxContainer = null
var ship_data: Dictionary = {}
var crew_data: Array = []

# Sprint 26.4: Checkpoint system for World Phase state persistence
var _checkpoint_data: Dictionary = {}

# Sprint C: Step completion indicators
var step_indicators: Array = []

# Below this much DESIGN height the fixed chrome has to give space back — a phone in
# landscape has ~338 (see _apply_vertical_compaction), a 360x640 phone in portrait 551.
const SHORT_VIEWPORT_DESIGN_PX := 620.0

# The smallest step viewport that can actually be used: a list plus the buttons that
# act on it. Below this the step is a caption with its controls off-screen.
#
# This exists because viewport HEIGHT alone is the wrong question. A 1280x800 tablet
# in landscape measures 689 design px — comfortably over SHORT_VIEWPORT_DESIGN_PX, so
# it was classed "tall" — but the fixed chrome costs 449 of those (margins 64, header
# 75, the 134px Controls block, the 48px footer, two separators, four 24px gaps),
# leaving 240. PhaseScroll then took 117px for 1130px of content, so World Phase Step 2
# rendered as the "Crew Tasks" heading and nothing else: the crew list, the task list
# and "Resolve All Tasks" were all below the fold. Verified on device Aug 8 2026 and
# reproduced on desktop at the same geometry.
#
# A ScrollContainer reports ~0 minimum height, so PhaseContainer contributes 2px to the
# column's minimum and absorbs the entire squeeze silently — nothing overflows and no
# warning is printed, which is why a viewport-height rule could never catch it.
const MIN_PHASE_VIEWPORT_DESIGN_PX := 320.0

# The relaxed (non-compacted) spacing. Named because _phase_viewport_budget() has to
# measure in these units even while the screen is already compacted — see its comment.
const RELAXED_SEPARATION_PX := 24.0
const TIGHT_SEPARATION_PX := 8.0
const RELAXED_MARGIN_BOTTOM_PX := 32.0
const TIGHT_MARGIN_BOTTOM_PX := 8.0

# Name of the code-inserted scroll that holds everything below the Header.
const CONTENT_SCROLL_NAME := "ContentScroll"

# Design System Constants (matching BaseCampaignPanel)
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_ACCENT := UIColors.COLOR_CYAN
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	name = "WorldPhaseController"
	
	_initialize_event_bus()
	_initialize_components()
	_connect_ui_signals()
	_setup_initial_state()
	_setup_world_briefing()

	# Keep content clear of the floating SettingsOverlay gear/bug buttons, which
	# are drawn on their own CanvasLayer ABOVE this screen. Pushes content DOWN --
	# a right-side margin would raise the container's minimum WIDTH and propagate
	# an overflow up the tree (proven and reverted on HelpScreen).
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)

	# Portrait de-clip. The root margins are what push this screen past a phone's
	# ~339 design px: the content itself needs ~341 and the 20+20 margins take it to
	# 381. PortraitChrome trims LEFT/RIGHT only (never the top, so it does not fight
	# the SettingsOverlay band reservation above) and restores them in landscape.
	var _pc_mc := get_node_or_null("MarginContainer")
	if _pc_mc is MarginContainer:
		var _pc = load("res://src/ui/components/base/PortraitChrome.gd").new()
		add_child(_pc)
		_pc.setup(_pc_mc as MarginContainer)

	_ensure_content_scroll()
	_apply_vertical_compaction()

	# T10-09: a drag over the step content moves nothing while a drag on the
	# scrollbar moves 1.4M pixels. Every desk-side diagnosis of that has been
	# wrong, and a headless probe of THIS screen is impossible (a --script
	# SceneTree does not register autoloads, so :1345's bare `TweenFX` reference
	# fails to compile and _ready() never runs). So it is measured on the device.
	# attach() returns null in a release build — a player cannot reach any of it.
	var _probe := TouchChainProbe.attach(self, "WorldPhase")
	if _probe:
		var _cs := get_node_or_null(
			"MarginContainer/VBoxContainer/" + CONTENT_SCROLL_NAME)
		if _cs is ScrollContainer:
			_probe.watch_scroll(_cs as ScrollContainer, CONTENT_SCROLL_NAME)
			# Same subtree _open_content_to_scroll_gesture() sweeps, so the
			# probe's staleness verdict is comparable. Given the whole screen it
			# counted `Background` — a ColorRect sibling production never sweeps
			# and which blocks nothing — and reported a stale sweep that was not.
			_probe.set_sweep_root(_cs)
		# Watched even though _apply_layout_for() sets it DISABLED + IGNORE: if
		# PhaseScroll ever reports scroll_started it is still claiming gestures,
		# which is the failure that IGNORE was added to stop.
		var _ps: Node = null
		if phase_container and is_instance_valid(phase_container):
			_ps = phase_container.get_node_or_null("PhaseScroll")
		if _ps is ScrollContainer:
			_probe.watch_scroll(_ps as ScrollContainer, "PhaseScroll")

	var _rm := get_node_or_null("/root/ResponsiveManager")
	if _rm and _rm.has_signal("layout_class_changed"):
		# A METHOD callable, not a lambda. Godot cleans up connections whose target
		# object is freed, but a lambda's captures are not tracked that way — after
		# this screen is freed the autoload kept calling it, printing "Lambda capture
		# at index 0 was freed" on every rotation for the rest of the session.
		_rm.layout_class_changed.connect(_on_layout_class_changed)
	get_viewport().size_changed.connect(_apply_vertical_compaction)

## Wrap everything below the Header in one scroll view, so a short screen can reach
## the parts of the chrome that do not fit.
##
## Measured at 733x338 (a phone on its side): the fixed chrome alone — header 66,
## two separators, the 131px controls block, the 48px footer — needs 295px, the band
## reservation takes 68 more, and there are 338 to spend. Nothing was reachable past
## the fold and the step content area was squeezed to TWO pixels.
##
## This moves EVERYTHING below the Header in, including the nav row and footer.
## That is right for the 338px case above and wrong everywhere else — see
## _apply_nav_pinning(), which lifts Controls / HSeparator2 / Footer back out on
## any screen that is not `tight`, because leaving them in here put Next Step and
## Proceed to Battle permanently below the fold on the tablet (T10-11 / T5-03).
##
## The scroll is created once and always present, so the two layouts differ by a
## single flag plus that one re-parent rather than by rebuilding the tree:
## _apply_vertical_compaction() turns its vertical scrolling ON for short screens and
## OFF everywhere else, and a disabled ScrollContainer propagates its child's minimum
## exactly like the plain container this used to be — so tall screens lay out as they
## always did.
func _ensure_content_scroll() -> void:
	var vbox := get_node_or_null("MarginContainer/VBoxContainer")
	if not (vbox is VBoxContainer) or vbox.get_node_or_null(CONTENT_SCROLL_NAME):
		return
	var header := vbox.get_node_or_null("Header")
	var movable: Array[Node] = []
	for child in vbox.get_children():
		if child != header and child is Control:
			movable.append(child)
	if movable.is_empty():
		return

	var scroll := ScrollContainer.new()
	scroll.name = CONTENT_SCROLL_NAME
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.name = "ContentColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", vbox.get_theme_constant("separation"))

	vbox.add_child(scroll)
	scroll.add_child(column)
	for child in movable:
		vbox.remove_child(child)
		column.add_child(child)


## Reclaim vertical space on short viewports so the screen stops overflowing.
##
## A phone on its side has ~338 design px of HEIGHT. This screen's fixed chrome —
## header, two separators, the step navigation row and the footer — is laid out with
## 24px between six children (120px of pure gap) plus 32px margins top and bottom,
## and that alone pushed the whole MarginContainer 68px off the bottom. Because the
## root grows both ways, that overflow re-centres the screen to a NEGATIVE y, which
## is what put the title back underneath the SettingsOverlay band the reservation had
## just cleared it from: fixing the overflow is what fixes the collision.
##
## Gaps and the bottom margin only. margin_top belongs to the band reservation and
## left/right to PortraitChrome — writing those here would fight them.
##
## Height comes from get_visible_rect(), which is the DESIGN space. That is correct
## here and is NOT the orientation-detection trap from
## docs/sop/responsive-adaptive-ui.md: the design-space height IS the layout budget
## being spent, whereas deciding "is this device portrait" needs physical pixels.
## Design px left for the step area once the fixed chrome has been paid for.
##
## Deliberately built from get_combined_minimum_size(), NOT from live sizes: the live
## height of PhaseScroll is an OUTPUT of the tight/not-tight decision, so feeding it
## back in oscillates (going tight makes the step area tall, which then reads as
## "plenty of room", which flips it back). Minimums are stable across both branches.
##
## PhaseContainer is excluded because it is the thing being budgeted for.
##
## MEASURED IN RELAXED UNITS ON PURPOSE. Compaction itself edits four of the inputs
## this sum would otherwise read — both separations, margin_bottom, and the Title's
## visibility — so reading them live makes the answer depend on the answer: the same
## 1280x800 tablet measures 240 while relaxed and 384 while tight, which straddles the
## threshold and flip-flops the layout between resizes. Asking the question in fixed
## relaxed units keeps it monotonic, and it is also the question worth asking: "with
## nothing given back yet, is the step area usable?"
func _phase_viewport_budget() -> float:
	var vp := get_viewport()
	if vp == null:
		return INF
	var budget: float = vp.get_visible_rect().size.y
	var mc := get_node_or_null("MarginContainer")
	if mc is MarginContainer:
		# margin_top belongs to the SettingsOverlay band reservation, not to
		# compaction, so it is read live. margin_bottom is compaction's, so it is not.
		budget -= float(mc.get_theme_constant("margin_top"))
		budget -= RELAXED_MARGIN_BOTTOM_PX
	var vbox := get_node_or_null("MarginContainer/VBoxContainer")
	if not (vbox is VBoxContainer):
		return budget
	var header := vbox.get_node_or_null("Header")
	if header is Control:
		budget -= (header as Control).get_combined_minimum_size().y + RELAXED_SEPARATION_PX
		# The Title is chrome compaction is allowed to reclaim, so it must not count in
		# EITHER state — otherwise the tight reading sits permanently below the relaxed
		# one and the first evaluation latches the layout for good. The header's minimum
		# already excludes the Title once hidden, so add it back only while visible.
		var title := header.get_node_or_null("Title")
		if title is Control and (title as Control).visible:
			budget += (title as Control).get_combined_minimum_size().y
	var scroll := vbox.get_node_or_null(CONTENT_SCROLL_NAME)
	var column: Node = scroll.get_node_or_null("ContentColumn") if scroll else null
	if column is VBoxContainer:
		for child in column.get_children():
			# _PINNED_NAV_NAMES are handled below, wherever they currently live, so
			# they must NOT also be counted here or they land in the sum twice.
			if child is Control and (child as Control).visible \
					and str(child.name) != "PhaseContainer" \
					and not _PINNED_NAV_NAMES.has(str(child.name)):
				budget -= (child as Control).get_combined_minimum_size().y \
					+ RELAXED_SEPARATION_PX

	# T11-40. Subtract the nav ALWAYS, wherever it is parented.
	#
	# This used to be part of the loop above, which meant the answer depended on the
	# arrangement the answer produces: _apply_nav_pinning() MOVES Controls /
	# HSeparator2 / Footer out of ContentColumn whenever the layout is relaxed, so
	# they were subtracted while tight and not subtracted while relaxed. MEASURED on
	# a 1280x800 viewport (689.7 design px): 244.7 with the nav inside, 502.7 with it
	# pinned, against MIN_PHASE_VIEWPORT_DESIGN_PX = 320 - so BOTH states are stable
	# fixed points and the layout latched to whichever it reached first. The delta is
	# exactly the nav's own minimum plus its separations.
	#
	# Subtracting it unconditionally is not merely consistent, it is CORRECT: the nav
	# occupies its height in both arrangements - inside the column it is scrolled
	# content, pinned outside it sits between the scroll and the screen edge. Either
	# way the step area does not get that space.
	#
	# The docblock above keeps the UNITS monotonic on purpose. Node LOCATION was a
	# second input, and it moved with the answer.
	for nav_name: String in _PINNED_NAV_NAMES:
		var nav: Node = column.get_node_or_null(nav_name) if column else null
		if nav == null:
			nav = vbox.get_node_or_null(nav_name)
		if nav is Control and (nav as Control).visible:
			budget -= (nav as Control).get_combined_minimum_size().y \
				+ RELAXED_SEPARATION_PX
	return budget


## Two independent ways to be short on height, and BOTH have to hand space back. The
## first is a small screen. The second is a screen that is tall enough overall but whose
## chrome has eaten the step area anyway — a landscape tablet, which the height test
## alone waves through. See MIN_PHASE_VIEWPORT_DESIGN_PX.
##
## Its own function because the content sweep re-runs on rebuilds, long after compaction
## last ran, and the two must never disagree about which layout is on screen.
func _is_tight() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.get_visible_rect().size.y < SHORT_VIEWPORT_DESIGN_PX \
		or _phase_viewport_budget() < MIN_PHASE_VIEWPORT_DESIGN_PX


func _apply_vertical_compaction() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_apply_layout_for(_is_tight())


## Apply a layout, without deciding which one.
##
## Split from the decision so both branches can be driven directly. Asking the question
## and acting on it in one function made the regression tests depend on the harness
## landing in the branch they wanted to check: they were green run alone and failed in a
## multi-suite run, because an earlier suite left the window in a state where BOTH sizes
## measured relaxed. An order-dependent test is worse than a failing one — it goes green
## on the run that matters and hides the bug.
func _apply_layout_for(tight: bool) -> void:
	_is_tight_layout = tight
	var vbox := get_node_or_null("MarginContainer/VBoxContainer")
	if vbox is VBoxContainer:
		(vbox as VBoxContainer).add_theme_constant_override("separation",
			int(TIGHT_SEPARATION_PX if tight else RELAXED_SEPARATION_PX))
	var mc := get_node_or_null("MarginContainer")
	if mc is MarginContainer:
		(mc as MarginContainer).add_theme_constant_override("margin_bottom",
			int(TIGHT_MARGIN_BOTTOM_PX if tight else RELAXED_MARGIN_BOTTOM_PX))

	# The screen title repeats what the step label underneath it already says
	# ("Step 2 of 6: Crew Tasks"), so it is the first thing to go when 35px matters.
	var title := get_node_or_null("MarginContainer/VBoxContainer/Header/Title")
	if title is Control:
		(title as Control).visible = not tight

	# Exactly ONE scrollbar, always. On a short screen the outer scroll owns the
	# gesture and the step area stops scrolling independently (nested vertical
	# scrolling is unusable on touch); everywhere else the outer one is inert and the
	# step area scrolls as it always has.
	var scroll := get_node_or_null("MarginContainer/VBoxContainer/" + CONTENT_SCROLL_NAME)
	if scroll is ScrollContainer:
		# AUTO in BOTH layouts, never DISABLED.
		#
		# The comment above wants the outer scroll "inert" when relaxed, and AUTO already
		# means exactly that: a ScrollContainer set to AUTO shows no bar and consumes no
		# gesture while its content fits. DISABLED means something stronger and wrong —
		# it cannot scroll EVEN WHEN THE CONTENT OVERFLOWS.
		#
		# StepNavigation and the footer live inside this container, so DISABLED made them
		# permanently unreachable whenever the page was taller than the viewport.
		# Measured at the tablet's portrait geometry (800x1280 design px) on World Phase
		# step 1: NextButton at y=1609 and BackToDashboardButton at y=1685, i.e. the
		# primary navigation 329px below the fold with no way to bring it up.
		(scroll as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var column := scroll.get_node_or_null("ContentColumn")
		if column is VBoxContainer:
			(column as VBoxContainer).add_theme_constant_override("separation",
				int(TIGHT_SEPARATION_PX if tight else RELAXED_SEPARATION_PX))
	# Resolve through the cached node, NOT "%PhaseContainer/PhaseScroll": a %-unique
	# name only resolves as the FIRST element of a path, so that lookup returned null
	# and the step area silently stayed scrollable — which is exactly the two-pixel
	# content strip the first landscape screenshot showed.
	var phase_scroll: Node = null
	if phase_container and is_instance_valid(phase_container):
		phase_scroll = phase_container.get_node_or_null("PhaseScroll")
	if phase_scroll is ScrollContainer:
		# ONE gesture model, in every layout: the OUTER scroll owns scrolling and the
		# step area never scrolls independently.
		#
		# This used to hand ownership back and forth (outer when tight, inner when
		# relaxed), and the relaxed half was broken in two ways measured on the tablet:
		#
		#   1. The chrome inside PhaseScroll (cards, separators) is MOUSE_FILTER_STOP and
		#      is DEEPER than PhaseScroll, so it was offered the drag first and marked it
		#      handled. PhaseScroll — the container that supposedly owned scrolling —
		#      never saw a single touch-drag. The source comment argued the opposite
		#      ("PhaseScroll is a child and so is offered the drag first"), which is true
		#      of PhaseContainer ABOVE it and false of everything INSIDE it.
		#   2. StepNavigation and the footer live in the OUTER scroll, so disabling that
		#      one put Next Step permanently out of reach on any page taller than the
		#      viewport (measured: y=1609 in a 1280 viewport).
		#
		# Unifying keeps every invariant the two-mode design existed to protect — exactly
		# one scrollbar, never zero, and the gesture always reaching the owner — while
		# removing the branch where the owner could not receive it.
		(phase_scroll as ScrollContainer).vertical_scroll_mode = \
			ScrollContainer.SCROLL_MODE_DISABLED
		# Turning the scrolling off does NOT stop it CLAIMING the gesture. A
		# ScrollContainer starts a drag the moment it sees the touch-press, and an event
		# a child has claimed never reaches an ancestor — so while tight, PhaseScroll ate
		# every touch-drag over the step area and the outer scroll, which owns scrolling
		# there, saw nothing. Measured on the tablet: swipes inside the card left
		# pixel-identical screenshots, while one on the strip above it (the only place
		# outside PhaseScroll) scrolled correctly. IGNORE is what actually stops it — its
		# mouse_filter is already PASS by default, so relaxing the filter changes nothing.
		# Per the Godot 4.6 Control.MouseFilter docs IGNORE does not block other controls,
		# so the step's own buttons and lists stay live.
		if _phase_scroll_mouse_filter < 0:
			_phase_scroll_mouse_filter = (phase_scroll as Control).mouse_filter
		# IGNORE in every layout, for the same reason: PhaseScroll must never CLAIM a
		# drag it no longer acts on. Per the Godot 4.6 Control.MouseFilter docs IGNORE
		# does not block other controls, so the step's own buttons and lists stay live.
		(phase_scroll as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ...and clear the panel above it as well.
	# PhaseContainer is a PanelContainer, and PanelContainer defaults to
	# MOUSE_FILTER_STOP, which per the Godot 4.6 Control.MouseFilter docs marks the
	# event handled and stops it propagating. So while tight, a touch-drag anywhere over
	# the step area died at PhaseContainer and the outer scroll — the container that now
	# owns scrolling — never saw it. Observed on the tablet: every swipe inside the card
	# left a pixel-identical screenshot, while a swipe on the thin strip just above it
	# (outside PhaseContainer) scrolled the screen correctly.
	#
	# PhaseScroll itself needs nothing here: ScrollContainer already defaults to PASS.
	# Confirm a filter before "fixing" it — the obvious suspect was not the STOP one.
	#
	# Restores the scene's own value rather than a hard-coded STOP, and only while
	# relaxed, where the default is right: PhaseScroll is a child and so is offered the
	# drag first, accepts it, and PhaseContainer never comes up.
	if phase_container and is_instance_valid(phase_container):
		if _phase_container_mouse_filter < 0:
			_phase_container_mouse_filter = phase_container.mouse_filter
		# PASS in every layout. PhaseContainer is a PanelContainer (default STOP) sitting
		# between the step area and the outer scroll that now always owns the gesture, so
		# it must always let the drag past.
		phase_container.mouse_filter = Control.MOUSE_FILTER_PASS

	_apply_nav_pinning(tight)
	_open_content_to_scroll_gesture(tight)


## Node names of the navigation chrome that must stay reachable without scrolling.
const _PINNED_NAV_NAMES: Array[String] = ["Controls", "HSeparator2", "Footer"]


## Keep Next Step / the step pips / Proceed to Battle on screen at all times.
##
## T10-11, measured on the tablet 2026-09-04: the World Phase rendered its step
## content and then simply ended, with no Next Step, no pips and no Back to
## Dashboard anywhere on the page — in BOTH orientations, on every entry after
## the first. The campaign could not be advanced at all.
##
## They were never missing. _ensure_content_scroll() moves EVERY non-Header child
## into ContentScroll, and PhaseScroll is deliberately SCROLL_MODE_DISABLED just
## above, so PhaseContainer's minimum height becomes the whole step's content
## height and pushes the nav off the bottom of the column. The numbers are already
## recorded in _apply_layout_for(): NextButton y=1609, BackToDashboardButton
## y=1685, in a 1280-tall viewport. The only way to reach them was to drag the
## outer scroll — and a touch-drag over the step area does not reach it (T10-09),
## so on a touch device there was no way at all. Same defect as T5-03.
##
## Fixing the geometry rather than the gesture: on a normal screen the nav is a
## pinned sibling BELOW the scroll, exactly as Header is pinned above it, so it
## cannot go off-screen however tall the step content grows.
##
## ⚠ NOT unconditional, and this is the reason the nav was in the scroll to begin
## with: _ensure_content_scroll()'s docblock records a 733x338 phone-on-its-side
## where the pinned chrome alone (header 66 + separators + 131 controls + 48
## footer = 295) leaves 43px of a 338px screen for the step itself. On that screen
## scrolling to the nav is strictly better than pinning it, so `tight` keeps the
## original single-column behaviour untouched.
##
## Idempotent: re-parents only when a node is not already where this layout wants
## it, so the repeated calls from size_changed / layout_class_changed are free.
func _apply_nav_pinning(tight: bool) -> void:
	var vbox := get_node_or_null("MarginContainer/VBoxContainer")
	if not (vbox is VBoxContainer):
		return
	var scroll := vbox.get_node_or_null(CONTENT_SCROLL_NAME)
	if scroll == null:
		return
	var column := scroll.get_node_or_null("ContentColumn")
	if column == null:
		return

	var want_parent: Node = column if tight else vbox
	for nav_name in _PINNED_NAV_NAMES:
		var node: Node = column.get_node_or_null(nav_name)
		if node == null:
			node = vbox.get_node_or_null(nav_name)
		if node == null:
			continue
		if node.get_parent() == want_parent:
			continue
		node.get_parent().remove_child(node)
		want_parent.add_child(node)

	# Header stays at 0; the scroll takes the space between it and the pinned nav.
	# add_child() appends, so the loop above already lands the nav in
	# Controls / HSeparator2 / Footer order after whatever is in the parent — this
	# only has to put the scroll back above them.
	if not tight:
		vbox.move_child(scroll, 1)


## Let a touch-drag over the content reach whichever scroll owns it.
##
## Clearing the two containers above is not enough, because the finger does not land on
## them — it lands on whatever decorative chrome is drawn under it, and PanelContainer
## and HSeparator both default to MOUSE_FILTER_STOP, which Godot 4.6 marks handled and
## does not propagate. The chain measured on the tablet, deepest first, was:
##
##     @HSeparator@1533   HSeparator      STOP    <- finger here
##     WorldBriefingCard  PanelContainer  STOP
##     PhaseContentVBox   VBoxContainer   PASS
##     PhaseScroll        ScrollContainer IGNORE  <- already cleared, never reached
##     PhaseContainer     PanelContainer  PASS    <- already cleared, never reached
##     ContentScroll      ScrollContainer PASS    <- the one that needed the drag
##
## So this is a whole CLASS of blocker, not two nodes: every card and rule the briefing
## draws is another one, and the briefing rebuilds them on each refresh. Hence a sweep
## rather than a fix at any one creation site.
##
## Only NON-FOCUSABLE controls are opened. That is the line between chrome and controls:
## panels, separators and layout boxes take no focus, while buttons, lists and text
## fields do and must keep claiming their own gestures — dragging over a list should
## still scroll THAT list. STOP -> PASS, never IGNORE, so the chrome still receives its
## own mouse_entered/exited and only stops SWALLOWING what it does not handle.
func _open_content_to_scroll_gesture(tight: bool) -> void:
	var scroll := get_node_or_null("MarginContainer/VBoxContainer/" + CONTENT_SCROLL_NAME)
	if not (scroll is ScrollContainer):
		return
	_open_subtree(scroll, tight)


## T9-45: this now delegates to the shared opener, which relaxes EVERY STOP
## descendant rather than only the non-focusable ones.
##
## The `focus_mode == FOCUS_NONE` rule below was too strict and that is why the
## World Phase step area still would not drag-scroll on the tablet after the
## T4-01 fix: the Travel and Upkeep panels are built from CheckBox, SpinBox and
## OptionButton, all of which take focus, so the sweep walked straight past the
## exact controls under the player's finger.
##
## Relaxing them is safe because PASS still offers the event to the control
## FIRST — a widget that genuinely handles a drag keeps handling it, and only
## unhandled events travel on. Containers with their own inner scroll are still
## skipped outright by TouchScrollOpener._SKIP.
func _open_subtree(node: Node, _tight: bool) -> void:
	TouchScrollOpenerRef.open_subtree(node)


## Fill the World-Phase empty space with a persistent "World Briefing" of the
## current planet (flavor + the law/rules meaning of each world trait). The 6 step
## containers are wrapped in a VBox so the ScrollContainer (which takes a single
## child) stacks the visible step ABOVE the briefing, letting it fill the space
## that short steps otherwise leave empty. Idempotent.
func _setup_world_briefing() -> void:
	if not phase_container:
		return
	var scroll := phase_container.get_node_or_null("PhaseScroll")
	if not (scroll is ScrollContainer):
		return
	if scroll.get_node_or_null("PhaseContentVBox"):
		return  # already wrapped
	var content := VBoxContainer.new()
	content.name = "PhaseContentVBox"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	# Reparent the step containers (unique_name_in_owner refs survive reparenting).
	for c in [upkeep_container, crew_task_container, job_offer_container,
			mission_prep_container, assign_equipment_container, resolve_rumors_container]:
		if c and c.get_parent() == scroll:
			scroll.remove_child(c)
			content.add_child(c)
	scroll.add_child(content)

	var card := PanelContainer.new()
	card.name = "WorldBriefingCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_TERTIARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	_world_briefing_vbox = VBoxContainer.new()
	_world_briefing_vbox.add_theme_constant_override("separation", 6)
	card.add_child(_world_briefing_vbox)
	content.add_child(card)
	_refresh_world_briefing.call_deferred()


## Repaint the briefing the moment the campaign's world actually changes.
##
## T8-03 (tablet QA, Aug 8 2026). The aggregate rebuild above is guarded on the
## TURN number, which is right for the bug it was added for (the screen is SHOWN
## each turn rather than re-created, so it went stale between turns) — but travel
## changes the world DURING a turn, so the guard blocks the refresh and the
## briefing keeps describing the world you just left.
##
## Observed on device: after "Travel to New World" the dashboard and the persisted
## save both read high_cost / danger 3 / Research Station + Mining Facility, while
## this screen still showed Imminent Invasion / danger 2 / Military Base + Ruins.
## The travel card itself rebuilt correctly (the Pay buttons re-costed), which is
## what made it look fine at a glance.
##
## The fix is NOT to drop the turn guard: _fetch_campaign_data() ends in
## _initialize_components_with_data(), which has side effects — JobOfferComponent
## ._fail_expired_job() writes journal entries — so an unguarded call double-fires
## them. `world_changed` is the campaign's own arrival chokepoint (emitted by
## initialize_world(), the single world_data writer), and _refresh_world_briefing()
## re-reads PlanetDataManager live, so repainting on that signal is both targeted
## and side-effect free.
func _ensure_world_changed_subscription() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return
	var c: Resource = gs.current_campaign
	if not c.has_signal("world_changed"):
		return
	# Idempotent: initialize_world_phase() runs every turn, and the autoloaded
	# campaign outlives this screen, so a plain connect() would stack duplicates.
	if c.is_connected("world_changed", _on_campaign_world_arrived):
		return
	c.connect("world_changed", _on_campaign_world_arrived)


func _on_campaign_world_arrived(_world_data: Dictionary) -> void:
	if not is_inside_tree():
		return
	_refresh_world_briefing()


## Repopulate the briefing from the current planet. Safe to call anytime.
func _refresh_world_briefing() -> void:
	if not is_instance_valid(_world_briefing_vbox):
		return
	# Reached via call_deferred(), so it can land a frame after this screen left
	# the tree. The /root/PlanetDataManager lookup below ERRORS from a detached
	# node instead of returning null, and the briefing then silently stays empty.
	if not is_inside_tree():
		return
	for child in _world_briefing_vbox.get_children():
		child.queue_free()
	var pdm := get_node_or_null("/root/PlanetDataManager")
	if not pdm or not pdm.has_method("get_current_planet"):
		return
	var planet = pdm.get_current_planet()
	if not planet:
		return
	WorldBriefingBuilderScript.build_into(_world_briefing_vbox, planet)
	# The builder makes fresh PanelContainers and HSeparators every refresh, and every
	# one of them defaults to MOUSE_FILTER_STOP — so without re-sweeping here the newly
	# built chrome starts swallowing touch-drags again. See
	# _open_content_to_scroll_gesture().
	_open_content_to_scroll_gesture(_is_tight_layout)


func _initialize_event_bus() -> void:
	## Initialize centralized event bus - eliminates signal hell
	# Find or create event bus
	event_bus = get_node("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"
	
	# Enable debug mode for development
	event_bus.enable_debug_mode(true)
	
	# Subscribe to component events - centralized event handling.
	# Tracked so _exit_tree() can unsubscribe: the bus is parented to /root above, so
	# it OUTLIVES this scene. SceneRouter frees the controller on every navigation
	# (2-3x per campaign turn), and without cleanup each freed controller left 6 dead
	# Callables registered forever — ~300 by turn 100.
	_subscribe_tracked(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, _on_crew_task_resolved)
	_subscribe_tracked(CampaignTurnEventBus.TurnEvent.CREW_TASK_ASSIGNED, _on_crew_task_assigned)
	_subscribe_tracked(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, _on_job_accepted)
	_subscribe_tracked(CampaignTurnEventBus.TurnEvent.MISSION_PREPARED, _on_mission_prepared)
	_subscribe_tracked(
		CampaignTurnEventBus.TurnEvent.PHASE_TRANSITION_REQUESTED,
		_on_phase_transition_requested)
	_subscribe_tracked(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, _on_phase_completed)


func _subscribe_tracked(event_type, handler: Callable) -> void:
	## Subscribe and remember it, mirroring WorldPhaseComponent's pattern
	## (WorldPhaseComponent.gd:53-55). The controller was the one subscriber that
	## never adopted it.
	if not event_bus:
		return
	event_bus.subscribe_to_event(event_type, handler)
	_event_subscriptions.append({"event": event_type, "handler": handler})


func _exit_tree() -> void:
	## Auto-cleanup event bus subscriptions — the bus lives on /root and outlives us.
	if event_bus and is_instance_valid(event_bus):
		for sub in _event_subscriptions:
			event_bus.unsubscribe_from_event(sub.event, sub.handler)
	_event_subscriptions.clear()


func _initialize_components() -> void:
	## Verify scene-instanced components and propagate event bus.
	## Child _ready() runs BEFORE parent _ready() in Godot, so components
	## couldn't find CampaignTurnEventBus (dynamically created here).
	## Assign it now and re-subscribe to events.
	var components: Array = [
		upkeep_component, crew_task_component, job_offer_component,
		assign_equipment_component, resolve_rumors_component, mission_prep_component
	]
	for component in components:
		if component and "event_bus" in component and not component.event_bus:
			component.event_bus = event_bus
			if component.has_method("_subscribe_to_events"):
				component._subscribe_to_events()

	# Initialize mission selection UI for Job Offers/Mission Prep phases


func _connect_ui_signals() -> void:
	## Connect UI navigation signals
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if automation_toggle:
		automation_toggle.toggled.connect(_on_automation_toggled)
	if back_to_dashboard_button:
		back_to_dashboard_button.pressed.connect(_on_back_to_dashboard_pressed)
	if proceed_to_battle_button:
		proceed_to_battle_button.pressed.connect(_on_proceed_to_battle_pressed)
	if lay_low_button:
		lay_low_button.pressed.connect(_on_lay_low_pressed)
	# B1: the upkeep step (unlike crew-task/job/mission-prep) has no event-bus
	# completion notification, so "Next Step" never re-evaluated after upkeep was
	# paid → turn soft-lock. Refresh the nav on every upkeep state change.
	if upkeep_component and upkeep_component.has_signal("step_state_changed"):
		if not upkeep_component.step_state_changed.is_connected(_update_ui_display):
			upkeep_component.step_state_changed.connect(_update_ui_display)

func _setup_initial_state() -> void:
	## Setup initial UI state and fetch campaign data from GameStateManager

	# BUG-030 fix: Load checkpoint from campaign storage if local _checkpoint_data
	# is empty (scene was destroyed and re-instantiated by SceneRouter)
	if _checkpoint_data.is_empty():
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign:
			var campaign = gs.current_campaign
			if campaign is Dictionary and "world_phase_checkpoint" in campaign:
				_checkpoint_data = campaign["world_phase_checkpoint"].duplicate()
			elif campaign is Resource and "progress_data" in campaign:
				var cp = campaign.progress_data.get("world_phase_checkpoint", {})
				if not cp.is_empty():
					_checkpoint_data = cp.duplicate()

	# QA-FIX BUG-12: Validate checkpoint staleness by checking turn number.
	# Previously only "all steps complete" was detected as stale, but partially
	# complete checkpoints from a PREVIOUS turn leaked step_completed state
	# (e.g., step 5 checkmark appearing on Turn 2's Upkeep).
	if is_checkpoint_stale(_checkpoint_data, _current_campaign_turn()):
		_checkpoint_data = {}
		clear_checkpoint()

	# Check for existing checkpoint (BUG-030: preserve progress on Back to Dashboard)
	if has_checkpoint():
		restore_from_checkpoint()
		# Sprint C: Create step indicators (needed even on restore)
		_create_step_indicators()
		if proceed_to_battle_button:
			proceed_to_battle_button.visible = false
		if lay_low_button:
			lay_low_button.visible = false
		_fetch_campaign_data()
		# ⚠ ORDER IS LOAD-BEARING. This MUST run after _fetch_campaign_data(),
		# which reaches _initialize_components_with_data() ->
		# `job_offer_component.initialize_job_offers(world_phase_data)` and
		# rebuilds that component from scratch. Restoring the accepted job inside
		# restore_from_checkpoint() (two lines earlier) is silently undone by that
		# call, and the symptom is identical to having no fix at all: the resumed
		# Mission Prep briefing reads "Objective: Unknown / Pay: 0", because
		# _refresh_mission_prep() sources the mission from get_accepted_job().
		# MEASURED on the tablet Aug 13 2026 — the job WAS in the checkpoint on
		# disk and the briefing was still blank.
		_restore_job_offers_from_checkpoint()
		_update_ui_display()
		_show_current_step()
		return

	current_step = WorldPhaseStep.UPKEEP
	# A new world phase can complete again (see _complete_world_phase).
	_world_phase_completed = false
	step_completed = {
		WorldPhaseStep.UPKEEP: false,
		WorldPhaseStep.CREW_TASKS: false,
		WorldPhaseStep.JOB_OFFERS: false,
		WorldPhaseStep.ASSIGN_EQUIPMENT: false,
		WorldPhaseStep.RESOLVE_RUMORS: false,
		WorldPhaseStep.MISSION_PREP: false
	}

	# Sprint C: Create step indicators
	_create_step_indicators()

	# Hide battle button until all steps are complete
	if proceed_to_battle_button:
		proceed_to_battle_button.visible = false
	if lay_low_button:
		lay_low_button.visible = false

	# Auto-fetch campaign data from GameStateManager
	_fetch_campaign_data()

	_update_ui_display()
	_show_current_step()

	# Check for deferred events at start of turn
	check_deferred_events("NEXT_TURN")

## The campaign turn `world_phase_data` was last built for. -1 = never built.
## Used by initialize_world_phase() to re-fetch exactly once per turn; see the
## comment there for what a stale aggregate costs.
##
## Public (no leading underscore) on purpose: tests/unit/test_world_phase_data_merge.gd
## forces a stale value to prove the per-turn rebuild actually happens. A guard nobody
## can drive from a test is a guard nobody knows is working.
var aggregate_built_for_turn: int = -1


func _current_campaign_turn() -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
		return int(gs.current_campaign.progress_data.get("turns_played", 0))
	return -1


func _fetch_campaign_data() -> void:
	## Fetch crew and ship data from GameState autoload for self-initialization
	var game_state_node = get_node_or_null("/root/GameState")
	if not game_state_node:
		return
	aggregate_built_for_turn = _current_campaign_turn()

	# Get crew data via GameState.get_active_crew()
	crew_data = game_state_node.get_active_crew() if game_state_node.has_method("get_active_crew") else []

	# Log equipment data availability and populate initial stash
	if game_state_node.current_campaign:
		var _camp = game_state_node.current_campaign
		if "equipment_data" in _camp:
			pass

	# Get ship data from campaign
	ship_data = {"name": "Unknown Ship", "condition": "good"}
	if game_state_node.current_campaign:
		var campaign = game_state_node.current_campaign
		if "ship_data" in campaign and campaign.ship_data is Dictionary:
			ship_data = campaign.ship_data
		elif campaign is Dictionary and campaign.has("ship_data"):
			ship_data = campaign.get("ship_data", ship_data)

	# Build world phase data from campaign
	var gsm = get_node_or_null("/root/GameStateManager")
	world_phase_data = {
		"credits": gsm.get_credits() if gsm else 0,
		"stash": [],
		"rumors": [],
		"quest": {},
		"available_items": [],
		"patrons": [],
		"location": "Unknown Location"
	}

	# Get additional campaign data from current_campaign
	if game_state_node.current_campaign:
		var campaign = game_state_node.current_campaign
		# Access properties directly for Resource, with fallback for Dictionary
		if campaign is Dictionary:
			world_phase_data["stash"] = campaign.get("stash", [])
			world_phase_data["rumors"] = campaign.get("rumors", [])
			world_phase_data["patrons"] = campaign.get("patrons", [])
			var current_world = campaign.get("current_world", {})
			if current_world is Dictionary:
				world_phase_data["location"] = current_world.get("name", "Unknown Location")
		else:
			# Resource access — FiveParsecsCampaignCore properties
			if campaign.has_method("get_all_equipment"):
				world_phase_data["stash"] = campaign.get_all_equipment()
			elif "equipment_data" in campaign:
				world_phase_data["stash"] = campaign.equipment_data.get("equipment", [])
			if "quest_rumors" in campaign:
				# quest_rumors is an int count; convert to Array for ResolveRumorsComponent
				var rumor_count: int = campaign.quest_rumors
				var rumor_array: Array = []
				for i in range(rumor_count):
					rumor_array.append({"id": i, "name": "Rumor %d" % (i + 1), "resolved": false})
				world_phase_data["rumors"] = rumor_array
			if "patrons" in campaign:
				world_phase_data["patrons"] = campaign.patrons
			if "world_data" in campaign and campaign.world_data is Dictionary:
				world_phase_data["location"] = campaign.world_data.get(
					"name", "Unknown Location")
	else:
		pass

	# The active Quest (Core Rules p.85 step 5). This key was declared above and
	# never written, so ResolveRumorsComponent always believed no Quest was
	# running — and the book's "If you are not currently on a Quest" gate could
	# not hold. A crew already on a Quest could roll again and silently replace
	# it. Quest state is Resource-unsafe on the campaign, so GameState owns it.
	if game_state_node.has_method("get_active_quest"):
		world_phase_data["quest"] = game_state_node.get_active_quest()

	# Track location visit in NPCTracker
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("visit_location"):
		var location_name: String = world_phase_data.get("location", "")
		if not location_name.is_empty() and location_name != "Unknown Location":
			var turn: int = 0
			var gs = get_node_or_null("/root/GameState")
			if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
				turn = gs.current_campaign.progress_data.get("turns_played", 0)
			npc_tracker.visit_location(location_name, turn)

	# Display psionic legality badge (DLC-gated)
	_setup_psionic_legality_badge()

	# Initialize components with fetched data
	_initialize_components_with_data()

## Public API: Initialize world phase with campaign data
func initialize_world_phase(ship: Dictionary, crew: Array, world_data: Dictionary) -> void:
	## Initialize world phase with campaign data - orchestrator entry point
	ship_data = ship.duplicate()
	crew_data = crew.duplicate()

	# REBUILD the aggregate first, once per campaign turn.
	#
	# _fetch_campaign_data() is otherwise called only from _setup_initial_state()
	# (a _ready() hook) and the checkpoint-restore branch. CampaignTurnController
	# SHOWS this controller each turn rather than re-creating it
	# (CampaignTurnController.gd:700-714), so _ready() fires once per app session —
	# and world_phase_data (rumors, quest, patrons, stash, location) stayed frozen
	# at whatever the campaign looked like on the turn the screen was first built.
	#
	# Measured on device Aug 8 2026, turn 2, same screen either side of a process
	# restart: briefing "Foch II" vs Gamma Prime, traits Corporate State vs Imminent
	# Invasion, danger 4 vs 2, Rumors 5 vs 6, roll target D6<=5 vs D6<=6. The
	# dashboard (which reads live state) agreed with the post-restart values, so the
	# campaign was right and only this screen was wrong. Worst of it: the briefing
	# advertised the departed world's "+2 to find a Patron" while the roll correctly
	# applied none, and the accepted job read "LOCATION: Foch II".
	#
	# Guarded on the turn number rather than called unconditionally because
	# _fetch_campaign_data() ends in _initialize_components_with_data(), which has
	# side effects (JobOfferComponent._fail_expired_job writes journal entries). On
	# turn 1 this function runs moments after _ready() already fetched, so an
	# unguarded call would double-fire them.
	if _current_campaign_turn() != aggregate_built_for_turn:
		_fetch_campaign_data()

	_ensure_world_changed_subscription()

	# MERGE the planet data in; do NOT replace the dictionary.
	#
	# world_phase_data carries two different things under one name: the PLANET (name,
	# government, traits, locations...) and the PHASE's own aggregate (rumors, quest,
	# patrons, stash). _fetch_campaign_data() builds the second during _ready(); the
	# turn controller then calls this immediately afterwards, and a plain assignment
	# threw all of it away — leaving only planet keys.
	#
	# What that cost: Step 5 reads world_phase_data["rumors"], so it always saw an empty
	# array and reported "Rumors: 0" against a campaign holding 5. The Core Rules p.85
	# roll is "D6, if equal or below the number of rumors, convert to a Quest" — at zero
	# it can never succeed, so Quests were unreachable through the World Phase.
	# Confirmed on device Aug 8 2026: screen said 0, resources.quest_rumors said 5, and
	# the persisted checkpoint's world_phase_data was a pure planet dict with no rumors
	# or quest key at all.
	#
	# Merging keeps both producers' work. The planet still wins on its own keys, which
	# is the existing behaviour for everything this function was actually meant to set.
	for _k in world_data:
		world_phase_data[_k] = world_data[_k]

	# Generate world event for current planet
	_generate_turn_world_event()

	# DLC: Check Fringe World Strife (Compendium pp.148-151)
	_check_compendium_world_strife()

	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "world_phase",
			"ship_data": ship_data,
			"crew_data": crew_data,
			"world_data": world_phase_data
		})
	
	# Initialize components with data
	_initialize_components_with_data()
	
	# No valid checkpoint = fresh turn entry (either first time or auto turn advance).
	# Call the full reset so component state (step_completed, all_tasks_resolved,
	# prep_completed, etc.) from the previous turn is cleared. In-place reuse by
	# CampaignTurnController does NOT fire _ready()/_setup_initial_state() on
	# Turn 2+, so this is the only place the reset can happen on auto advance.
	if not has_checkpoint():
		reset_world_phase()
		_show_current_step()
		return

	# ⚠ A VALID CHECKPOINT MEANS THE LINE ABOVE JUST DESTROYED THE RESTORE.
	#
	# This function is the orchestrator entry point and CampaignTurnController calls
	# it AFTER _ready() has already run _setup_initial_state() -> the checkpoint
	# branch -> _restore_job_offers_from_checkpoint(). `_initialize_components_with_data()`
	# then re-runs UNCONDITIONALLY and undoes it twice over:
	#   - `initialize_job_offers()` sets job_accepted = false (JobOfferComponent:200)
	#   - `initialize_mission_prep(world_phase_data.get("mission", {}))` passes {},
	#     because the mission lives in job_offer_component.get_accepted_job() and was
	#     never a world_phase_data key
	# and the `if not has_checkpoint()` guard above means _show_current_step() does
	# NOT run, so nothing re-renders and the blanked briefing is what the player sees.
	#
	# MEASURED on the tablet Aug 14 2026: a checkpoint holding "Reputable Contractor"
	# / Protect / Isolationists / 7cr resumed to "Objective: Unknown / Pay: 0". The
	# giveaway was the world's Current Event changing across the resume ("A supply
	# glut drops market prices by 20%" -> "Nothing notable happens this turn"), which
	# only _generate_turn_world_event() (:946) does — proving THIS function ran after
	# the restore.
	#
	# Two earlier fixes ordered the restore against the other two callers of
	# `initialize_job_offers()` and both still failed on device, because this third
	# one is on a path _ready() cannot see.
	_restore_job_offers_from_checkpoint()
	_show_current_step()

## The turn a world event was last rolled for, keyed by planet. -1 = never.
var _world_event_rolled: Dictionary = {}


func _generate_turn_world_event() -> void:
	## Roll a world event for the current planet — ONCE per turn, per planet.
	##
	## T4-02: this used to re-roll on every call, and `PlanetDataManager
	## .generate_world_event()` is not a pure query — it rolls a D6 and calls
	## `add_world_event()`, MUTATING the planet's persistent state. The caller then
	## discarded the return value (`if not event.is_empty(): pass`), which is what
	## made it look harmless.
	##
	## So the world's Current Event changed every time this ran: four different
	## values were observed inside one campaign turn on device. That is not
	## cosmetic — the rolled row carries a live modifier the rules use (Civil Unrest
	## is -1 to ALL crew tasks, Labor Shortage is +1 to recruitment, Market Surge is
	## a 20% price change), so the penalty a player planned their turn around could
	## be a different one by the time they resolved it.
	##
	## Keyed by planet as well as turn: travelling mid-turn arrives at a DIFFERENT
	## world, and that world is entitled to its own event on the same turn.
	##
	## T10-10, measured on the tablet 2026-09-04: the guard below used to be
	## `_world_event_rolled` ALONE — a plain instance Dictionary. That holds within
	## one process and is empty in the next, so after a restart the guard failed
	## open and this rolled a second event for the same turn on the same world.
	## Observed: the save on disk held "Worker shortages make recruitment easier
	## (+1)" while the screen showed "Pirate raids increase local danger level", and
	## `grep 'Pirate raids' <save>` found nothing. Same family as the battle
	## checkpoint (T10-06): state that has to outlive the process, kept only in RAM.
	##
	## The authority is now the PERSISTED world_events array, which serializes with
	## the campaign. `_world_event_rolled` stays as a same-frame fast path only, and
	## must never be the only thing consulted.
	var pdm = get_node_or_null("/root/PlanetDataManager")
	if not pdm or not pdm.has_method("generate_world_event"):
		return
	var planet_id: String = ""
	if pdm.has_method("get") and "current_planet_id" in pdm:
		planet_id = pdm.current_planet_id
	elif world_phase_data.has("planet_id"):
		planet_id = world_phase_data.get("planet_id", "")
	if planet_id.is_empty():
		return

	var turn := _current_campaign_turn()
	if int(_world_event_rolled.get(planet_id, -1)) == turn:
		return
	if pdm.has_method("has_world_event_for_turn") \
			and pdm.has_world_event_for_turn(planet_id, turn):
		# Already rolled for this world this turn, in this session or a previous one.
		_world_event_rolled[planet_id] = turn
		return
	_world_event_rolled[planet_id] = turn
	pdm.generate_world_event(planet_id, turn)

func _check_compendium_world_strife() -> void:
	## Compendium p.148 arrival roll: "when arriving on a new world, roll 1D6.
	## A roll of 4+ indicates the world is Unstable."
	##
	## WHAT THIS REPLACED, because all four faults were independent and each one
	## alone was fatal:
	##   1. it gated on `world_phase_data["is_fringe_world"]` — a key NO producer
	##      anywhere in the repo writes, so the guard was permanently false;
	##   2. `should_check_strife()` re-rolled the ARRIVAL die every campaign turn,
	##      and the book rolls it once, on arrival;
	##   3. it fired the D100 immediately, and the book fires it only when
	##      Instability reaches or exceeds 10 — the score did not exist;
	##   4. it read `strife_event["instability_mod"]`; the rows carry
	##      `instability_reduction`, and the local was never used regardless.
	##   ...and then logged through `journal.add_entry()`, which has zero
	##   definitions on CampaignJournal — another permanently-false has_method
	##   guard.
	##
	## The accumulator itself runs in the Invasion step (Compendium p.148,
	## "During the Invasion step of every campaign turn"), which lives in
	## PostBattlePhase step 6 — NOT here.
	if not FringeWorldStrifeRef.is_enabled():
		return
	var pdm = get_node_or_null("/root/PlanetDataManager")
	var gs = get_node_or_null("/root/GameState")
	if pdm == null or gs == null:
		return
	var planet_id: String = str(pdm.current_planet_id)
	var campaign = gs.get_current_campaign() if gs.has_method("get_current_campaign") else null
	if planet_id.is_empty() or campaign == null:
		return

	# "You may opt to use a 5+ roll if you prefer a less chaotic environment."
	# Stored in progress_data, which is where this codebase keeps per-campaign
	# option state (progressive_difficulty_options sets the precedent) — there is
	# no `campaign_config` dictionary on FiveParsecsCampaignCore.
	var calmer: bool = false
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		calmer = bool(campaign.progress_data.get("fringe_strife_calmer", false))

	# Idempotent per world: a world already rolled for keeps its verdict, so
	# re-entering the World Phase or reloading a save cannot re-roll a quiet
	# world into an unstable one.
	var state: Dictionary = FringeWorldStrifeRef.roll_arrival(campaign, planet_id, calmer)
	if state.is_empty():
		return
	world_phase_data["fringe_strife"] = state
	world_phase_data["world_unstable"] = bool(state.get("unstable", false))
	world_phase_data["world_instability"] = int(state.get("instability", 0))

func _initialize_components_with_data() -> void:
	## Initialize all components with campaign data
	# Initialize upkeep component
	if upkeep_component and upkeep_component.has_method("initialize_upkeep_phase"):
		upkeep_component.initialize_upkeep_phase(ship_data, crew_data)

	# Initialize crew task component
	if crew_task_component and crew_task_component.has_method("initialize_crew_tasks"):
		crew_task_component.initialize_crew_tasks(crew_data)

	# Initialize job offer component
	if job_offer_component and job_offer_component.has_method("initialize_job_offers"):
		job_offer_component.initialize_job_offers(world_phase_data)

	# Initialize assign equipment component
	if assign_equipment_component and assign_equipment_component.has_method("initialize_equipment_phase"):
		var stash = world_phase_data.get("stash", [])
		assign_equipment_component.initialize_equipment_phase(crew_data, stash)

	# Initialize resolve rumors component
	if resolve_rumors_component and resolve_rumors_component.has_method("initialize_rumors_phase"):
		var rumors = world_phase_data.get("rumors", [])
		var quest = world_phase_data.get("quest", {})
		resolve_rumors_component.initialize_rumors_phase(rumors, quest)

	# Initialize mission prep component
	if mission_prep_component and mission_prep_component.has_method("initialize_mission_prep"):
		var mission = world_phase_data.get("mission", {})
		var equipment = world_phase_data.get("stash", [])
		# Sprint 26.3: Character-Everywhere - convert Character objects to Dictionary for component
		var typed_crew: Array[Dictionary] = []
		for member in crew_data:
			if member is Character:
				# Serialize Character to Dictionary for component compatibility
				if member.has_method("to_dictionary"):
					typed_crew.append(member.to_dictionary())
				else:
					# Manual conversion — include both key aliases for all consumers
					var _cid: String = member.character_id if "character_id" in member else ""
					var _cname: String = member.name if member.name else ""
					typed_crew.append({
						"id": _cid,
						"character_id": _cid,
						"name": _cname,
						"character_name": _cname,
						"combat": member.combat if "combat" in member else 0,
						"reactions": member.reactions if "reactions" in member else 0,
						"toughness": member.toughness if "toughness" in member else 0,
						"savvy": member.savvy if "savvy" in member else 0,
						"speed": member.speed if "speed" in member else 4,
						"is_captain": member.is_captain if "is_captain" in member else false,
						"equipment": member.equipment.duplicate() if "equipment" in member else []
					})
					push_warning("WorldPhaseController: Character missing to_dictionary()")
			elif member is Dictionary:
				typed_crew.append(member)
			else:
				push_warning("WorldPhaseController: Unexpected crew member type: %s" % typeof(member))
		var typed_equipment: Array[Dictionary] = []
		for item in equipment:
			if item is Dictionary:
				typed_equipment.append(item)
		# BUG-035 FIX: Enrich crew dicts with equipment from EquipmentManager
		_enrich_crew_equipment(typed_crew)
		mission_prep_component.initialize_mission_prep(mission, typed_crew, typed_equipment)

	# Note: Post-battle components (PurchaseItems, CampaignEvent, CharacterEvent) now initialized in PostBattleSequence

## Step Navigation - coordinated component management
## The step the content scroll was last rewound for. -1 so the first step also
## rewinds (a checkpoint restore can land on a step other than UPKEEP).
var _scroll_reset_for_step: int = -1


## Rewind the page to the top when the step actually CHANGES (W2-05).
##
## The scroll offset used to survive a step change, so arriving at a short step
## from a long one landed you partway down a page whose content ended above the
## fold — the new step's heading was scrolled off and the visible remainder was
## blank. On the tablet this read as "Crew Tasks shows only 1 of 6 crew", and it
## cost real time chasing a data bug through _get_eligible_crew() and
## _populate_crew_list() before scrolling the page revealed all six were there.
##
## Guarded on a step stamp rather than reset unconditionally: _show_current_step()
## has seven call sites and none is a mid-interaction refresh TODAY, but an
## unconditional rewind would yank a player to the top the first time someone adds
## one. Same shape as the W2-01 turn stamp.
func _reset_scroll_on_step_change() -> void:
	if current_step == _scroll_reset_for_step:
		return
	_scroll_reset_for_step = current_step
	# Only the outer ContentScroll needs rewinding: PhaseScroll is SCROLL_MODE_DISABLED
	# in every layout since the W2-03 fix, so it cannot hold a non-zero offset.
	var scroll := get_node_or_null("MarginContainer/VBoxContainer/" + CONTENT_SCROLL_NAME)
	if scroll is ScrollContainer:
		(scroll as ScrollContainer).scroll_vertical = 0


func _show_current_step() -> void:
	## Show current step component and hide others

	# §2: re-open the touch chain for the step being shown.
	#
	# ⚠ The existing sweep runs from the LAYOUT paths (:534, :753), not from here —
	# and this function has FOUR callers that change which step is on screen. Each
	# step component refreshes its own content when it becomes visible (see the
	# "World phase components need refresh" note in CLAUDE.md), so a sweep that ran
	# at layout time never saw the cards the NEXT step builds.
	#
	# This is the resolution of the deploy #24 row that recorded two candidates
	# ("(a) ORDER ... (b) _SKIP ... needs desk introspection to separate") and was
	# never settled: it is ORDER. Measured by tests/unit/test_touch_scroll_sweep.gd,
	# which reports 0 for this screen at the default step and 6 once an earlier
	# suite has left the campaign on a different one — the same 6 then surface
	# through CampaignTurnController, which embeds this screen.
	#
	# ⚠ It sweeps the WHOLE screen, not _open_content_to_scroll_gesture()'s single
	# ContentScroll: this screen has THREE ScrollContainers and the step cards do not
	# all live under that one. Scoping the sweep to one scroll is why re-running the
	# existing helper here still left 6 controls closed.
	#
	# Sweeping self does NOT disturb the deliberate PhaseScroll design
	# (vertical_scroll_mode=DISABLED + mouse_filter=IGNORE so the outer scroll owns
	# the gesture) — TouchScrollOpener._SKIP passes over every ScrollContainer, and
	# IGNORE is not STOP so it is never rewritten.
	#
	# call_deferred so it lands after the step components have rebuilt.
	call_deferred("_open_whole_screen_to_scroll_gesture")

	# Show/hide all 6 World Phase containers based on current step
	if upkeep_container:
		upkeep_container.visible = (current_step == WorldPhaseStep.UPKEEP)
	if crew_task_container:
		crew_task_container.visible = (current_step == WorldPhaseStep.CREW_TASKS)
	if job_offer_container:
		job_offer_container.visible = (current_step == WorldPhaseStep.JOB_OFFERS)
	if assign_equipment_container:
		assign_equipment_container.visible = (current_step == WorldPhaseStep.ASSIGN_EQUIPMENT)
	if resolve_rumors_container:
		resolve_rumors_container.visible = (current_step == WorldPhaseStep.RESOLVE_RUMORS)
	if mission_prep_container:
		mission_prep_container.visible = (current_step == WorldPhaseStep.MISSION_PREP)

	# Re-initialize components that depend on data from prior steps
	if current_step == WorldPhaseStep.JOB_OFFERS:
		_refresh_job_offers()
	if current_step == WorldPhaseStep.ASSIGN_EQUIPMENT:
		_refresh_assign_equipment()
	if current_step == WorldPhaseStep.MISSION_PREP:
		_refresh_mission_prep()
	# Early steps also refresh on (re-)entry so a crew change in a later step (e.g. a
	# recruit) isn't shown stale — but NEVER re-initialize a COMPLETED step: re-running
	# initialize_upkeep_phase() resets the paid flag and would re-charge upkeep on
	# back-navigation (Core Rules p.76: upkeep is paid once per turn). The same guard
	# protects completed crew-task assignments and rumor resolution. See the helpers.
	if current_step == WorldPhaseStep.UPKEEP:
		_refresh_upkeep()
	if current_step == WorldPhaseStep.CREW_TASKS:
		_refresh_crew_tasks()
	if current_step == WorldPhaseStep.RESOLVE_RUMORS:
		_refresh_resolve_rumors()

	# Update UI
	_update_ui_display()

	# Each step's own chrome is built by its component, so a step that has just become
	# visible brings in a fresh crop of MOUSE_FILTER_STOP panels that would swallow
	# touch-drags. See _open_content_to_scroll_gesture().
	_open_content_to_scroll_gesture(_is_tight_layout)

	_reset_scroll_on_step_change()

	# Fade-in on step transition
	var _containers := [
		upkeep_container, crew_task_container,
		job_offer_container, assign_equipment_container,
		resolve_rumors_container, mission_prep_container]
	var tm := get_node_or_null("/root/ThemeManager")
	var skip_anim: bool = tm != null and tm.is_reduced_animation_enabled()
	if not skip_anim and current_step < _containers.size():
		var active: Control = _containers[current_step]
		if active and is_instance_valid(active) and active.visible:
			TweenFX.fade_in(active, 0.2)

	# Publish step change event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": step_names[current_step].to_lower(),
			"step_index": current_step,
			"total_steps": step_names.size()
		})

	# Black Zone: auto-advance past skipped steps (Core Rules p.150)
	var _bz_sel: int = 0
	if upkeep_component and upkeep_component.has_method("get_selected_zone"):
		_bz_sel = upkeep_component.get_selected_zone()
	if _bz_sel == 2 and (
			current_step == WorldPhaseStep.JOB_OFFERS
			or current_step == WorldPhaseStep.RESOLVE_RUMORS):
		call_deferred("_on_next_button_pressed")
		return

	# Introductory Campaign: skip steps not yet unlocked
	# (Compendium pp.105-109 — phases progressively enabled)
	if _should_skip_intro_step(current_step):
		call_deferred("_on_next_button_pressed")
		return

	# AUTO-ADVANCE: If automation enabled and step already complete, advance
	if automation_enabled and _can_advance_to_next_step():
		# Use call_deferred to avoid recursion issues
		call_deferred("_on_next_button_pressed")

## Sprint C: Create step completion indicators
func _create_step_indicators() -> void:
	## Create visual step indicators showing completion status
	if not step_navigation:
		push_warning("WorldPhaseController: step_navigation not found - skipping indicators")
		return

	# Clear existing indicators
	for indicator in step_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	step_indicators.clear()

	# Create indicator container
	var indicator_container := HBoxContainer.new()
	indicator_container.name = "StepIndicators"
	indicator_container.add_theme_constant_override("separation", 8)
	indicator_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create an indicator for each step
	for i in range(step_names.size()):
		var indicator := _create_step_indicator_badge(i)
		step_indicators.append(indicator)
		indicator_container.add_child(indicator)

	# Insert at beginning of step_navigation (before Back/Next buttons)
	step_navigation.add_child(indicator_container)
	step_navigation.move_child(indicator_container, 0)


func _create_step_indicator_badge(step_index: int) -> PanelContainer:
	## Create a single step indicator badge
	var badge := PanelContainer.new()
	badge.name = "StepIndicator_%d" % step_index
	badge.custom_minimum_size = Vector2(32, 32)

	# Style the badge
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.set_corner_radius_all(16)  # Circular
	style.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", style)

	# Create centered label
	var label := Label.new()
	label.name = "StepLabel"
	label.text = str(step_index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _scaled_font(12))
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	badge.add_child(label)

	# Add tooltip
	badge.tooltip_text = step_names[step_index]

	return badge

func _update_step_indicators() -> void:
	## Update step indicator visuals based on completion status
	for i in range(step_indicators.size()):
		if i >= step_indicators.size():
			break

		var indicator = step_indicators[i]
		if not is_instance_valid(indicator):
			continue

		var label = indicator.get_node_or_null("StepLabel")
		if not label:
			continue

		var step_key = i as WorldPhaseStep
		var is_completed = step_completed.get(step_key, false)
		var is_current = (i == current_step)

		# Update label and color based on state
		if is_completed:
			label.text = "✓"
			label.add_theme_color_override("font_color", COLOR_SUCCESS)
		elif is_current:
			label.text = str(i + 1)
			label.add_theme_color_override("font_color", COLOR_ACCENT)
		else:
			label.text = str(i + 1)
			label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

func _update_ui_display() -> void:
	## Update navigation UI display
	if current_step_label:
		var zone_suffix := ""
		var _ui_zone: int = 0
		if upkeep_component and upkeep_component.has_method("get_selected_zone"):
			_ui_zone = upkeep_component.get_selected_zone()
		match _ui_zone:
			1: zone_suffix = "  •  RED ZONE"
			2: zone_suffix = "  •  BLACK ZONE"
		current_step_label.text = "Step %d of %d: %s%s" % [
			current_step + 1,
			step_names.size(),
			step_names[current_step],
			zone_suffix
		]
		# Tint label color for active zones
		match _ui_zone:
			1:
				current_step_label.add_theme_color_override(
					"font_color", Color(0.86, 0.3, 0.3, 1))
			2:
				current_step_label.add_theme_color_override(
					"font_color", Color(0.6, 0.3, 0.8, 1))
			_:
				current_step_label.add_theme_color_override(
					"font_color", Color(0.502, 0.502, 0.502, 1))

	if progress_bar:
		var progress = float(current_step) / float(step_names.size() - 1)
		progress_bar.value = progress * 100.0

	if back_button:
		back_button.disabled = (current_step == WorldPhaseStep.UPKEEP)

	if next_button:
		if current_step == WorldPhaseStep.MISSION_PREP:
			# Hide step nav button on final step — proceed_to_battle_button handles it
			next_button.visible = false
			if _blocker_label:
				_blocker_label.visible = false
		else:
			next_button.visible = true
			var can_advance = _can_advance_to_next_step()
			next_button.disabled = not can_advance
			next_button.text = "Next Step"
			# Progress-blocker readout: when Next Step is disabled, tell the player
			# exactly what this step still needs (mirrors the same gating checks).
			_ensure_blocker_label()
			if _blocker_label:
				var hint: String = _get_current_step_blocker() if not can_advance else ""
				_blocker_label.text = "⚠  " + hint
				_blocker_label.visible = hint != ""

	# Sprint C: Update step indicators
	_update_step_indicators()

	# Show battle button when all steps are complete, OR when user has reached
	# the final step and Mission Prep is done (guards against event bus timing
	# issues where earlier steps weren't tracked via step_completed)
	if proceed_to_battle_button:
		var all_complete: bool = true
		for step_key in step_completed:
			if not step_completed[step_key]:
				all_complete = false
				break
		var mission_prep_done: bool = (
			current_step == WorldPhaseStep.MISSION_PREP
			and mission_prep_component
			and mission_prep_component.has_method("is_mission_prepared")
			and mission_prep_component.is_mission_prepared()
		)
		proceed_to_battle_button.visible = all_complete or mission_prep_done
		# Lay Low is the alternative to that same button, so it appears with it.
		if lay_low_button:
			lay_low_button.visible = proceed_to_battle_button.visible

func _should_skip_intro_step(step: int) -> bool:
	## Check if the Introductory Campaign restricts this step.
	## During early intro turns, some World Phase steps are locked.
	var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if not cpm or not cpm.has_method("get_intro_turn_restrictions"):
		return false
	var restrictions: Dictionary = cpm.get_intro_turn_restrictions()
	if restrictions.is_empty():
		return false

	var enabled_steps: Array = restrictions.get(
		"pre_battle_enabled", [])
	# "all" means everything is unlocked (turn 5)
	if enabled_steps.has("all"):
		return false
	# Empty enabled list = skip everything pre-battle (turn 0-1)
	if enabled_steps.is_empty():
		# But never skip MISSION_PREP — that's the battle launcher
		return step != WorldPhaseStep.MISSION_PREP

	# Check specific steps against the enabled list
	match step:
		WorldPhaseStep.UPKEEP:
			return not (enabled_steps.has("upkeep")
				or enabled_steps.has("medical"))
		WorldPhaseStep.CREW_TASKS:
			return not (enabled_steps.has("crew_tasks_limited")
				or enabled_steps.has("crew_tasks_full"))
		WorldPhaseStep.JOB_OFFERS:
			return not (enabled_steps.has("job_offers")
				or enabled_steps.has("find_patron"))
		WorldPhaseStep.ASSIGN_EQUIPMENT:
			return not enabled_steps.has("assign_equipment")
		WorldPhaseStep.RESOLVE_RUMORS:
			return not enabled_steps.has("resolve_rumors")
		WorldPhaseStep.MISSION_PREP:
			return false  # Always allow mission prep
	return false


func _can_advance_to_next_step() -> bool:
	## Check if current step is completed and can advance

	# Introductory Campaign: auto-complete skipped steps
	# (Compendium pp.105-109 — phases progressively enabled)
	if _should_skip_intro_step(current_step):
		step_completed[current_step] = true
		return true

	# Black Zone: auto-skip patron/rival search and rumors
	# (Core Rules Appendix III p.150)
	var _bz_zone: int = 0
	if upkeep_component and upkeep_component.has_method("get_selected_zone"):
		_bz_zone = upkeep_component.get_selected_zone()
	if _bz_zone == 2:
		if (current_step == WorldPhaseStep.JOB_OFFERS
				or current_step == WorldPhaseStep.RESOLVE_RUMORS):
			step_completed[current_step] = true
			return true

	var result = false
	match current_step:
		WorldPhaseStep.UPKEEP:
			var travel_ok := true
			var upkeep_ok := false
			if upkeep_component:
				if upkeep_component.has_method("is_travel_completed"):
					travel_ok = upkeep_component.is_travel_completed()
				if upkeep_component.has_method("is_upkeep_completed"):
					upkeep_ok = upkeep_component.is_upkeep_completed()
			else:
				upkeep_ok = step_completed.get(WorldPhaseStep.UPKEEP, false)
			result = travel_ok and upkeep_ok
		WorldPhaseStep.CREW_TASKS:
			if crew_task_component and crew_task_component.has_method("is_tasks_completed"):
				result = crew_task_component.is_tasks_completed()
			else:
				result = step_completed.get(WorldPhaseStep.CREW_TASKS, false)
		WorldPhaseStep.JOB_OFFERS:
			if job_offer_component and job_offer_component.has_method("is_job_accepted"):
				result = job_offer_component.is_job_accepted()
			else:
				result = step_completed.get(WorldPhaseStep.JOB_OFFERS, false)
		WorldPhaseStep.ASSIGN_EQUIPMENT:
			if assign_equipment_component and assign_equipment_component.has_method("is_equipment_assigned"):
				result = assign_equipment_component.is_equipment_assigned()
			else:
				result = step_completed.get(WorldPhaseStep.ASSIGN_EQUIPMENT, false)
		WorldPhaseStep.RESOLVE_RUMORS:
			if resolve_rumors_component and resolve_rumors_component.has_method("is_rumors_resolved"):
				result = resolve_rumors_component.is_rumors_resolved()
			else:
				result = step_completed.get(WorldPhaseStep.RESOLVE_RUMORS, false)
		WorldPhaseStep.MISSION_PREP:
			if mission_prep_component and mission_prep_component.has_method("is_mission_prepared"):
				result = mission_prep_component.is_mission_prepared()
			else:
				result = step_completed.get(WorldPhaseStep.MISSION_PREP, false)
		_:
			result = false

	return result

func _ensure_blocker_label() -> void:
	## Lazily create the progress-blocker readout label at the top of the Controls
	## box (above the Automation row + Back/Next). Amber warning text, wraps.
	if _blocker_label and is_instance_valid(_blocker_label):
		return
	var nav := get_node_or_null("%StepNavigation")
	if not nav:
		return
	var controls: Node = nav.get_parent()
	if not controls:
		return
	_blocker_label = Label.new()
	_blocker_label.name = "BlockerHint"
	_blocker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blocker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blocker_label.add_theme_color_override("font_color", Color(0.851, 0.467, 0.024, 1))
	_blocker_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(15))
	_blocker_label.visible = false
	controls.add_child(_blocker_label)
	controls.move_child(_blocker_label, 0)

func _get_current_step_blocker() -> String:
	## Human-readable reason the CURRENT step can't advance ("" if it can).
	## Delegates to the active component's get_blocker_hint() (each owns its state).
	var comp: Node = null
	match current_step:
		WorldPhaseStep.UPKEEP:
			comp = upkeep_component
		WorldPhaseStep.CREW_TASKS:
			comp = crew_task_component
		WorldPhaseStep.JOB_OFFERS:
			comp = job_offer_component
		WorldPhaseStep.ASSIGN_EQUIPMENT:
			comp = assign_equipment_component
		WorldPhaseStep.RESOLVE_RUMORS:
			comp = resolve_rumors_component
	if comp and comp.has_method("get_blocker_hint"):
		var h: String = comp.get_blocker_hint()
		if h != "":
			return h
	return "Complete this step to continue."

## UI Event Handlers - orchestrator navigation
func _on_back_button_pressed() -> void:
	## Handle back button navigation - Sprint 10.2: Uses phase rollback for bidirectional navigation
	if current_step == WorldPhaseStep.UPKEEP:
		_confirm_rollback_to_travel()
	elif current_step > WorldPhaseStep.UPKEEP:
		current_step = current_step - 1
		_show_current_step()


## Back-at-step-1 means rollback_to_phase(TRAVEL), and that is NOT navigation — it
## calls campaign.from_dictionary() on the snapshot taken when TRAVEL was entered,
## replacing the ENTIRE campaign. Everything done since is gone: upkeep paid, crew
## tasks resolved, the job taken, and any Quest generated at step 5.
##
## W2-02 is that loss observed from the outside. The device generated a Quest on
## Turn 1 and the end-of-turn save had NO `active_quest` key at all and
## quest_rumors back at 5(+1). A snapshot predating step 5 explains both exactly —
## and the key being ABSENT rather than `{}` is what rules out the p.120 post-battle
## clear_active_quest(), which assigns an empty dict and leaves the key in place.
## (The generation step itself is correct and round-trips; pinned by
## tests/unit/test_quest_generation_persistence.gd.)
##
## The rollback is kept — deliberately re-doing Travel is a legitimate thing to
## want — but it now announces itself. Same defect class as W2-04: a single tap
## irreversibly destroying a turn's work with no confirm.
func _confirm_rollback_to_travel() -> void:
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	var enums = load("res://src/core/systems/GlobalEnums.gd")
	var travel_phase: int = enums.FiveParsecsCampaignPhase.TRAVEL if enums else -1

	var destructive: bool = (
		cpm != null
		and travel_phase >= 0
		and cpm.has_method("has_phase_checkpoint")
		and cpm.has_phase_checkpoint(travel_phase)
		and cpm.has_method("rollback_to_phase")
	)
	if not destructive:
		# No snapshot to restore, so nothing can be lost — plain navigation.
		return_to_dashboard.emit()
		SceneRouter.navigate_to("campaign_turn_controller")
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Go back to Travel?"
	dialog.ok_button_text = "Discard and go back"
	dialog.cancel_button_text = "Stay here"
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = ("Going back to Travel REWINDS the campaign to how it was before this"
		+ " World Phase began.\n\n" + _describe_world_phase_progress()
		+ "\n\nThis cannot be undone.")
	dialog.add_child(note)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if cpm.rollback_to_phase(travel_phase):
			return_to_travel.emit()
		else:
			return_to_dashboard.emit()
			SceneRouter.navigate_to("campaign_turn_controller")
	)
	dialog.close_requested.connect(dialog.queue_free)
	# No fixed size: a hard-coded Vector2i clipped both controls off a portrait
	# tablet the last time this codebase used one.
	dialog.popup_centered()


## Name what the rollback would actually throw away, so the confirm is a decision
## rather than a speed bump. A confirm that says only "are you sure?" trains people
## to tap through it.
func _describe_world_phase_progress() -> String:
	var done: Array[String] = []
	for step_key in step_completed:
		if bool(step_completed[step_key]) and int(step_key) < step_names.size():
			done.append(str(step_names[int(step_key)]))
	if done.is_empty():
		return "Nothing has been completed this World Phase yet."
	return "You will lose: " + ", ".join(done) + "."

func _on_next_button_pressed() -> void:
	## Handle next button navigation
	if _can_advance_to_next_step():
		if current_step < WorldPhaseStep.MISSION_PREP:
			current_step = current_step + 1
			_show_current_step()
			# Checkpoint save after each step advance
			_save_world_phase_checkpoint()
		else:
			# Complete world phase - proceed to battle
			_complete_world_phase()
	else:
		pass

func _on_automation_toggled(enabled: bool) -> void:
	## Handle automation toggle
	automation_enabled = enabled

	# Publish automation event for components
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, {
			"enabled": enabled
		})

## Navigation Button Handlers - Clear user actions
func _on_lay_low_pressed() -> void:
	## Errata v1.06: pay 1D6+1 Credits to skip this turn's battle.
	##
	## Deliberately does NOT complete the world phase here. The errata's first
	## clause is "check for Rival attacks NORMALLY" — a Rival that tracks the crew
	## down forces the fight regardless (Core Rules p.85: "this will prevent you
	## from doing whatever you had wanted to do this campaign turn"), and the crew
	## may not be able to afford the stay. CampaignTurnController owns both
	## answers, so it decides and completes the phase itself.
	lay_low_requested.emit()


func _on_proceed_to_battle_pressed() -> void:
	## Handle Proceed to Battle button - primary action

	# Sprint 26.4: Save checkpoint before transitioning to battle
	save_checkpoint()

	# Complete world phase and transition to battle
	_complete_world_phase()

	# Emit signal for external listeners
	proceed_to_battle.emit()

	# Standalone mode: if no CampaignTurnController is listening to phase_completed,
	# navigate to battle flow directly via SceneRouter
	if phase_completed.get_connections().is_empty():
		var router = get_node_or_null("/root/SceneRouter")
		if router:
			router.navigate_to("campaign_turn_controller")
		else:
			push_error("WorldPhaseController: No SceneRouter and no CampaignTurnController — cannot proceed to battle")

func _on_back_to_dashboard_pressed() -> void:
	## Handle Back to Dashboard button - return navigation

	# Save checkpoint so progress is preserved on re-entry
	save_checkpoint()

	# Emit signal for external listeners
	return_to_dashboard.emit()

	# Navigate back to dashboard
	SceneRouter.navigate_to("campaign_dashboard")

## Component Event Handlers - centralized coordination
func _on_crew_task_resolved(data: Dictionary) -> void:
	## Handle crew task resolution from CrewTaskComponent
	step_completed[WorldPhaseStep.CREW_TASKS] = true
	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_crew_task_assigned(_data: Dictionary) -> void:
	## A crew task was assigned (not yet resolved). Refresh the nav/readout so the
	## progress-blocker hint advances immediately (e.g. "Assign at least one crew
	## task" -> "Tap Resolve All Tasks") instead of lagging until the next pass.
	_update_ui_display()

func _on_job_accepted(data: Dictionary) -> void:
	## Handle job acceptance from JobOfferComponent
	step_completed[WorldPhaseStep.JOB_OFFERS] = true

	# Track patron interaction in NPCTracker
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
		var patron_id: String = data.get("patron_id", data.get("patron", ""))
		if not patron_id.is_empty():
			var turn: int = 0
			var gs = get_node_or_null("/root/GameState")
			if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
				turn = gs.current_campaign.progress_data.get("turns_played", 0)
			npc_tracker.track_patron_interaction(patron_id, "job_offered", {"turn": turn})

	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_mission_prepared(data: Dictionary) -> void:
	## Handle mission preparation from MissionPrepComponent
	step_completed[WorldPhaseStep.MISSION_PREP] = true
	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

func _on_phase_transition_requested(data: Dictionary) -> void:
	## Handle phase transition requests from components
	pass

func _on_phase_completed(data: Dictionary) -> void:
	## Handle phase completion events from all components via PHASE_COMPLETED
	var phase_name = data.get("phase_name", "")

	# Route completion to correct step based on phase_name
	match phase_name:
		"upkeep":
			step_completed[WorldPhaseStep.UPKEEP] = true
		"assign_equipment":
			step_completed[WorldPhaseStep.ASSIGN_EQUIPMENT] = true
		"resolve_rumors":
			step_completed[WorldPhaseStep.RESOLVE_RUMORS] = true
		"mission_prep":
			step_completed[WorldPhaseStep.MISSION_PREP] = true
		"crew_tasks":
			step_completed[WorldPhaseStep.CREW_TASKS] = true
		"job_offers":
			step_completed[WorldPhaseStep.JOB_OFFERS] = true
		# Note: purchase_items, campaign_event, character_event are now in PostBattleSequence

	_update_ui_display()

	if automation_enabled:
		await get_tree().create_timer(1.0).timeout
		_on_next_button_pressed()

## World Phase Completion
##
## Guards re-entry. With auto-processing enabled on the final step, every
## component that finishes publishes a completion which _on_phase_completed
## turns into another _on_next_button_pressed() — and at MISSION_PREP that is
## another _complete_world_phase(). A desktop run of one turn produced TWENTY
## calls, each re-gathering results, re-emitting world_phase_completed and
## asking CampaignTurnController to enter MISSION again.
##
## Nothing broke only because CampaignPhaseManager refuses the duplicate
## transition — the "Failed to transition to MISSION" warning WAS the guard.
## That is accidental protection: it sits one behaviour change away from
## re-running _initiate_battle_sequence, which would re-roll the enemies, the
## deployment condition and the battlefield after the player had already seen
## them in PreBattleUI. The world phase completes once.
var _world_phase_completed: bool = false

func _complete_world_phase() -> void:
	## Complete the entire world phase and transition to battle
	if _world_phase_completed:
		return
	_world_phase_completed = true

	# Clear checkpoint — world phase is done, next turn should start fresh
	clear_checkpoint()

	# Gather results from all 9 components
	var upkeep_results = {}
	if upkeep_component and upkeep_component.has_method("get_upkeep_results"):
		upkeep_results = upkeep_component.get_upkeep_results()

	var crew_task_results = []
	if crew_task_component and crew_task_component.has_method("get_task_results"):
		crew_task_results = crew_task_component.get_task_results()

	var job_results = {}
	if job_offer_component and job_offer_component.has_method("get_accepted_job"):
		job_results = job_offer_component.get_accepted_job()
		# Errata v1.06: the crew fights ONE of its accepted jobs this turn, and
		# that one is no longer outstanding — so its commitment is discharged here,
		# at the hand-off, rather than left to lapse into a false failure later.
		# Without this call `discharge_commitment()` would be a zero-caller
		# producer, which is the exact defect shape this sprint exists to close.
		if job_offer_component.has_method("discharge_commitment"):
			job_offer_component.discharge_commitment(str(job_results.get("id", "")))

	# `get_step_results()` is the real method — `get_equipment_assignments()` has
	# ZERO definitions repo-wide, so this guard was permanently false and
	# equipment_results was always {}. (The assignments themselves now persist
	# immediately through EquipmentTransferService inside the component; this dict
	# is the step's summary, not the mechanism.)
	var equipment_results = {}
	if assign_equipment_component and assign_equipment_component.has_method("get_step_results"):
		equipment_results = assign_equipment_component.get_step_results()

	var rumors_results = {}
	if resolve_rumors_component and resolve_rumors_component.has_method("get_step_results"):
		rumors_results = resolve_rumors_component.get_step_results()

	var mission_data = {}
	if mission_prep_component and mission_prep_component.has_method("get_mission_data"):
		mission_data = mission_prep_component.get_mission_data()

	# Note: purchase_results, campaign_event_results, character_event_results now gathered in PostBattleSequence

	var world_phase_results = {
		"upkeep_results": upkeep_results,
		"crew_task_results": crew_task_results,
		"job_results": job_results,
		"equipment_results": equipment_results,
		"rumors_results": rumors_results,
		"mission_data": mission_data
	}

	# PERSIST DATA TO GAMESTATE for battle phase
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign

		# Persist to progress_data (Resource doesn't support bracket assignment)
		if "progress_data" in campaign:
			# Save accepted job as current_mission (required by battle system)
			if not job_results.is_empty():
				# Derive mission source for Compendium battle type selection (p.118)
				var mission_source: String = job_results.get("mission_source",
					job_results.get("source", "opportunity"))
				var mission_dict: Dictionary = {
					"objective": job_results.get("objective", "patrol"),
					"objective_description": job_results.get("objective_description", ""),
					"enemy_type": job_results.get("enemy_type", "Unknown Hostiles"),
					"pay": job_results.get("pay", job_results.get("danger_pay", 0)),
					# Pure Danger Pay component (Core Rules p.78) carried through to
					# Get Paid, where it is added on top of the 1D6 base for a Patron
					# job (p.120). Merged into battle_results by _on_battle_completed.
					"danger_pay": job_results.get("danger_pay", 0),
					# Danger Pay 10+ (Core Rules p.83): "roll twice, picking the
					# higher die when rolling for mission pay after the battle".
					# The job has always carried this flag and the offer summary
					# advertised it; it stopped here, so the promise was never kept.
					"double_roll_bonus": job_results.get("double_roll_bonus", false),
					"danger_level": job_results.get("danger_level", 1),
					"time_frame": job_results.get("time_frame", ""),
					# Patron Conditions (Core Rules pp.79-80). The job rolls these
					# and TacticalBattleUI renders a "PATRON CONDITIONS" section
					# from them — but this hand-off copied `benefits` and `hazards`
					# and simply omitted `conditions`, so that section was always
					# empty and half of the Benefits/Hazards/Conditions rule never
					# reached the table.
					"conditions": job_results.get("conditions", []),
					# NOTE: `deployment_condition` and `notable_sights` are NOT read
					# from the job. Nothing writes them job-side, and both are rolled
					# later by the battle funnel (CampaignTurnController rolls the
					# p.88 deployment condition and the p.89 Notable Sight itself).
					# The reads that used to sit here were permanently "" — copying a
					# value the job never had, which would have shadowed the real
					# roll if a job ever did start supplying one.
					"patron": job_results.get("patron_name", job_results.get("patron", "")),
					"patron_type": job_results.get("patron_type", ""),
					# The Patron's IDENTITY, not just their display name. Post-battle
					# Step 2 (Core Rules p.119) adds them as a contact on success and
					# — per errata v1.06 — drops them from your known Patrons on a
					# failed accepted job. Both branches are gated on this key, so
					# without it the entire step was inert in both directions.
					"patron_id": str(job_results.get("patron_id",
						job_results.get("patron_name", ""))),
					"benefits": job_results.get("benefits", []),
					"hazards": job_results.get("hazards", []),
					"location": job_results.get("location", ""),
					# THE FACTION'S IDENTITY. Same shape as `patron_id` above, and
					# it was missing for exactly as long: FactionSystem stamps
					# `faction_id` on every generated faction job, this literal
					# copied ~20 named keys and that was not one of them, so the
					# id died here. RivalPatronResolver reads
					# `battle_result["faction_id"]` to run the p.112 Loyalty gain,
					# and it was permanently "" — so Loyalty NEVER rose above 0 in
					# any campaign, which in turn made every downstream rule inert:
					# Faction Favors (D6 <= Loyalty), the p.113 Office party payout
					# (Credits equal to Loyalty), the p.115 "Befriending the
					# leadership" story point, and the 3+ Loyalty gate on "We
					# thought we would do you a favor".
					"faction_id": str(job_results.get("faction_id", "")),
					# Compendium p.113, verbatim: "If you did a job DIRECTLY for a
					# Faction, always perform the Faction Struggle event. THIS DOES
					# NOT OCCUR FOR AFFILIATED JOBS." So this is deliberately NOT
					# the same as `faction_id` — an affiliated Patron job carries a
					# faction_id (for Loyalty) and must leave this empty.
					# PostBattlePhase:554 has read it since the decomposition and
					# no producer ever wrote it, so the mandatory Struggle has
					# never fired.
					"faction_job_id": str(job_results.get("faction_id", "")) \
						if mission_source == "faction" else "",
					# p.112: an affiliated job "is less likely to increase your
					# Loyalty" — a roll of 6 rather than D6 >= Loyalty.
					"is_affiliated_patron_job": bool(
						job_results.get("is_affiliated_patron_job", false)),
					# Mission source for Compendium battle type selection
					"source": mission_source,
					"mission_source": mission_source,
					# PreBattleUI-compatible alias keys
					# Named for the PATRON, not the objective. "%s Mission" %
					# objective produced "Secure Mission" on the pre-battle screen
					# for a battle whose objective the p.89 roll then made Protect
					# (T10-03). A job is not entitled to an objective until battle
					# setup (Core Rules p.83 vs p.89 step 5), so the title cannot be
					# built from one.
					"title": ("%s Job" % str(job_results.get("patron_name",
						job_results.get("patron", "")))).strip_edges() \
						if not str(job_results.get("patron_name",
							job_results.get("patron", ""))).strip_edges().is_empty() \
						else "Patron Job",
					"description": job_results.get("objective_description", "Complete the mission objective."),
					"battle_type": _get_battle_type_for_objective(job_results.get("objective", "patrol")),
				}

				# Fixer's Guidebook mission types (Stealth / Street Fight /
				# Salvage). TWO keys, and both are load-bearing:
				#
				# `type` is the exact string TacticalBattleUI branches on to open
				# the matching battle panel. The literal above copies ~20 named
				# keys off the job and `type` was not one of them, so even once
				# JobOfferComponent started offering these missions the dispatch
				# would never have matched — the same omission this hand-off
				# already made for `conditions`.
				#
				# `compendium_mission` carries the generator's payload verbatim.
				# It cannot be merged into mission_dict: the panels read
				# `objective` as a DICTIONARY (roll range, instruction text,
				# has_individual) while the flattened literal sets it to a plain
				# String, so a merge would either break the panels or break
				# everything downstream that expects the String. Keeping both
				# shapes side by side is the only lossless option.
				var compendium_type: String = str(job_results.get("type", ""))
				if compendium_type in ["stealth", "street_fight", "salvage"]:
					mission_dict["type"] = compendium_type
					mission_dict["compendium_mission"] = job_results.duplicate(true)
					mission_dict["title"] = str(job_results.get("name", "Mission"))

				# Inject Red/Black Zone flags (Core Rules Appendix III)
				var selected_zone: int = 0
				if upkeep_component and upkeep_component.has_method("get_selected_zone"):
					selected_zone = upkeep_component.get_selected_zone()
				if selected_zone == 1:
					mission_dict["is_red_zone"] = true
					_stamp_red_zone_threat(mission_dict)
				elif selected_zone == 2:
					mission_dict["is_black_zone"] = true
					_stamp_black_zone_mission(mission_dict)

				campaign.progress_data["current_mission"] = mission_dict

			# A FAILED Flee Invasion roll OVERRIDES whatever job was accepted.
			# Core Rules p.69: on a failed roll "there's no time during your World
			# step to do anything except Assign Equipment (p.85) before proceeding
			# to the 'Battle' section of the rules, where you MUST fight an
			# Invasion Battle (p.92)". Deliberately written after the job block so
			# the invasion wins. The battle funnel needs no special case — it keys
			# off mission_source, which BattleSetupRules.is_invasion() already
			# reads and the p.120/121 payment/finds/loot gates all follow.
			if upkeep_component and upkeep_component.has_method("get_forced_invasion_mission"):
				var forced_invasion: Dictionary = upkeep_component.get_forced_invasion_mission()
				if not forced_invasion.is_empty():
					campaign.progress_data["current_mission"] = forced_invasion

			# Raided (Core Rules p.70): the travel-event pirate boarding, set when
			# the intimidation roll fails. Written BEFORE the invasion block would
			# be wrong — an invasion outranks a raid — so it goes after, but only
			# when no invasion claimed the slot. The book calls this an "out of
			# sequence" encounter that "does not count as the main Battle stage",
			# which the flag on the mission carries forward.
			if upkeep_component and upkeep_component.has_method("get_forced_travel_battle"):
				var raid: Dictionary = upkeep_component.get_forced_travel_battle()
				if not raid.is_empty() \
						and campaign.progress_data.get("current_mission", {}).is_empty():
					campaign.progress_data["current_mission"] = raid

			# Crew-task outcomes that the RIVAL check reads (Core Rules p.85).
			# Both were pure flavour text before this: the Decoy task printed
			# "Crew unavailable for battle" and the roll it was supposed to modify
			# never ran at all, because CampaignTurnController keyed the check off
			# progress_data["rival_count"] — a key nothing has ever written.
			# data/crew_tasks.json, decoy (p.78): "+1 to the roll when checking if
			# Rivals track you down, per crew sent as Decoy".
			campaign.progress_data["decoy_crew_count"] = \
				RivalEncounterCheckClass.decoy_count_from_tasks(crew_task_results)
			# p.119 removal modifier: "+1 if you Tracked them down during Assign and
			# Resolve Crew Tasks". Populated from Track results that name a Rival;
			# see the Track task note in docs/sop/README.md — the task resolves but
			# does not yet let the player pick WHICH Rival ("a Rival of your
			# choice", p.78), so this stays empty until that picker exists rather
			# than guessing a choice the book gives to the player.
			campaign.progress_data["tracked_rivals"] = \
				RivalEncounterCheckClass.tracked_rival_ids_from_tasks(crew_task_results)

			# Increment Red Zone turn counter (both RZ and BZ turns count)
			var zone_sel: int = 0
			if upkeep_component and upkeep_component.has_method("get_selected_zone"):
				zone_sel = upkeep_component.get_selected_zone()
			if zone_sel >= 1 and "red_zone_turns_completed" in campaign:
				campaign.red_zone_turns_completed += 1

			# NO progress_data["equipment_assignments"] mirror. Per-character gear
			# is owned by Character.equipment and the ship stash by
			# equipment_data["equipment"] (data-ownership table); a third copy in
			# progress_data was a second home for the same items — the exact thing
			# the "one item, one home" invariant forbids — and nothing ever read
			# it back. The assignments reach the campaign through
			# EquipmentTransferService as the player makes them.

			# NO progress_data["world_phase_results"] copy. It was labelled "for
			# summary display" and had zero readers repo-wide, so it only ever
			# grew the save file. The turn's world step is now summarised into the
			# campaign journal by CampaignTurnController._journal_world_phase(),
			# which receives the same dict through the phase_completed signal —
			# the journal being the campaign's actual record.

	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "world_phase",
			"results": world_phase_results,
			"next_phase": "battle_phase"
		})


	# Emit signal for CampaignTurnController integration.
	# CampaignTurnController handles the phase transition to MISSION internally —
	# do NOT also navigate via SceneRouter (dual-navigation causes scene reload
	# which resets to UPKEEP).
	phase_completed.emit(world_phase_results)

func _progress_data_of(campaign: Variant) -> Dictionary:
	## The campaign's progress_data, for BOTH campaign shapes.
	##
	## Returned BY REFERENCE, deliberately: callers mutate it in place (consuming
	## a deferred event, for instance) and expect that to reach the campaign.
	## Returns an empty throwaway when there is no progress_data to speak of, so
	## callers can `.get()` safely — check `.is_empty()` before writing.
	if campaign == null:
		return {}
	if campaign is Dictionary:
		var d: Dictionary = campaign
		if not d.has("progress_data") or not (d["progress_data"] is Dictionary):
			d["progress_data"] = {}
		return d["progress_data"]
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		return campaign.progress_data
	return {}

func _refresh_upkeep() -> void:
	## Re-pull crew on (re-)entry so an outdated crew (e.g. a recruit added in a later
	## step) doesn't show a stale Upkeep cost. GUARDED: never re-initialize a COMPLETED
	## upkeep — initialize_upkeep_phase() resets upkeep_completed and recalculates, which
	## would RE-CHARGE the player on back-navigation (Core Rules p.76: upkeep is paid once
	## per turn). A completed upkeep is left exactly as the player paid it.
	if not upkeep_component:
		return
	if upkeep_component.has_method("is_upkeep_completed") and upkeep_component.is_upkeep_completed():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_active_crew"):
		crew_data = gs.get_active_crew()
	if upkeep_component.has_method("initialize_upkeep_phase"):
		upkeep_component.initialize_upkeep_phase(ship_data, crew_data)

func _refresh_crew_tasks() -> void:
	## Re-pull crew on (re-)entry. GUARDED: don't re-initialize completed tasks — that
	## would wipe the player's task assignments on back-navigation.
	if not crew_task_component:
		return
	if crew_task_component.has_method("is_tasks_completed") and crew_task_component.is_tasks_completed():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_active_crew"):
		crew_data = gs.get_active_crew()
	if crew_task_component.has_method("initialize_crew_tasks"):
		crew_task_component.initialize_crew_tasks(crew_data)

func _refresh_resolve_rumors() -> void:
	## Re-pull rumors/quest on (re-)entry. GUARDED: don't re-initialize resolved rumors —
	## that would wipe the player's rumor resolution on back-navigation.
	if not resolve_rumors_component:
		return
	if resolve_rumors_component.has_method("is_rumors_resolved") and resolve_rumors_component.is_rumors_resolved():
		return
	if resolve_rumors_component.has_method("initialize_rumors_phase"):
		var rumors = world_phase_data.get("rumors", [])
		var quest = world_phase_data.get("quest", {})
		resolve_rumors_component.initialize_rumors_phase(rumors, quest)

func _refresh_job_offers() -> void:
	## Re-fetch patron data from campaign and re-initialize job offer component
	## Called when advancing to JOB_OFFERS step, since crew tasks may have found new patrons
	##
	## ⚠ NOT ONCE THE PLAYER HAS TAKEN A JOB. `initialize_job_offers()` re-rolls the
	## board and resets `job_accepted = false` (JobOfferComponent.gd:200), so running
	## it again DISCARDS the player's choice. Same guard, same reason, as
	## `_refresh_rumors()` directly above.
	##
	## MEASURED on the tablet Aug 14 2026. `_show_current_step()` calls this on every
	## arrival at JOB_OFFERS (:1177), which makes it a SECOND producer after the one
	## in `_initialize_components_with_data()`, and it runs AFTER
	## `_restore_job_offers_from_checkpoint()` in `_setup_initial_state()`. Resuming a
	## checkpoint whose accepted job was verifiably on disk ("Reputable Contractor" /
	## Protect / Isolationists / 7cr) re-rolled it into two unrelated offers with the
	## step's checkmark cleared. Ordering the restore against ONE producer was not
	## enough; this guard is what makes it hold against both.
	##
	## It also fixes a plain back-navigation bug needing no restart: accept a job,
	## step forward, press Back, and the acceptance was silently re-rolled away.
	if job_offer_component and job_offer_component.has_method("get_accepted_job") \
			and not job_offer_component.get_accepted_job().is_empty():
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var campaign = gs.current_campaign
		if "patrons" in campaign:
			world_phase_data["patrons"] = campaign.patrons
		elif campaign is Dictionary:
			world_phase_data["patrons"] = campaign.get("patrons", [])
	if job_offer_component and job_offer_component.has_method("initialize_job_offers"):
		job_offer_component.initialize_job_offers(world_phase_data)

func _refresh_mission_prep() -> void:
	## Re-initialize mission prep with accepted job data and current crew/equipment
	## Called when advancing to MISSION_PREP step, since job offers and equipment assignment
	## happen in prior steps and MissionPrepComponent needs that data
	var accepted_job: Dictionary = {}
	if job_offer_component and job_offer_component.has_method("get_accepted_job"):
		accepted_job = job_offer_component.get_accepted_job()

	# Inject zone flags so MissionPrepComponent can display zone info
	var _mp_zone: int = 0
	if upkeep_component and upkeep_component.has_method("get_selected_zone"):
		_mp_zone = upkeep_component.get_selected_zone()
	if _mp_zone == 1:
		accepted_job["is_red_zone"] = true
		_stamp_red_zone_threat(accepted_job)
	elif _mp_zone == 2:
		accepted_job["is_black_zone"] = true
		_stamp_black_zone_mission(accepted_job)

	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var campaign = gs.current_campaign
		# Refresh equipment from campaign
		if campaign.has_method("get_all_equipment"):
			world_phase_data["stash"] = campaign.get_all_equipment()
		elif "equipment_data" in campaign:
			world_phase_data["stash"] = campaign.equipment_data.get("equipment", [])

	if mission_prep_component and mission_prep_component.has_method("initialize_mission_prep"):
		var equipment: Array = world_phase_data.get("stash", [])
		var typed_crew: Array[Dictionary] = []
		var typed_equipment: Array[Dictionary] = []

		# Prefer Step 4 (AssignEquipment) results if available — they have equipment assignments applied
		var use_step4_data := false
		if assign_equipment_component and assign_equipment_component.has_method("get_step_results"):
			var eq_results: Dictionary = assign_equipment_component.get_step_results()
			# Use Step 4 data if crew_data is non-empty (user may not click Confirm button)
			var crew_from_step4: Array = eq_results.get("crew_data", [])
			var stash_from_step4: Array = eq_results.get("stash_data", [])
			if not crew_from_step4.is_empty():
				for member in crew_from_step4:
					if member is Dictionary:
						typed_crew.append(member)
					elif member is Object and member.has_method("to_dictionary"):
						typed_crew.append(member.to_dictionary())
				for item in stash_from_step4:
					if item is Dictionary:
						typed_equipment.append(item)
					elif item is Object and item.has_method("to_dictionary"):
						typed_equipment.append(item.to_dictionary())
				use_step4_data = true

		# Fallback to campaign data if Step 4 results not available
		if not use_step4_data:
			for member in crew_data:
				if member is Character:
					if member.has_method("to_dictionary"):
						typed_crew.append(member.to_dictionary())
					else:
						var _cid: String = member.character_id if "character_id" in member else ""
						var _cname: String = member.name if member.name else ""
						typed_crew.append({
							"id": _cid,
							"character_id": _cid,
							"name": _cname,
							"character_name": _cname,
							"equipment": member.equipment.duplicate() if "equipment" in member else []
						})
				elif member is Dictionary:
					typed_crew.append(member)
			for item in equipment:
				if item is Dictionary:
					typed_equipment.append(item)

		# BUG-035 FIX: Enrich crew dicts with equipment from EquipmentManager
		_enrich_crew_equipment(typed_crew)
		mission_prep_component.initialize_mission_prep(accepted_job, typed_crew, typed_equipment)

func _refresh_assign_equipment() -> void:
	## Re-initialize assign equipment with current crew and equipment data
	## Called when advancing to ASSIGN_EQUIPMENT step
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		return

	var campaign = gs.current_campaign

	# Refresh crew data from campaign
	crew_data = gs.get_active_crew() if gs.has_method("get_active_crew") else []

	# Refresh equipment data from campaign
	var all_equipment: Array = []
	if campaign.has_method("get_all_equipment"):
		all_equipment = campaign.get_all_equipment()
	elif "equipment_data" in campaign:
		all_equipment = campaign.equipment_data.get(
			"equipment", [])

	# Filter stash: exclude items already assigned to crew
	var crew_item_names: Array = []
	for member in crew_data:
		if "equipment" in member:
			crew_item_names.append_array(member.equipment)
	var stash: Array = []
	for item in all_equipment:
		var item_name: String = ""
		if item is Dictionary:
			item_name = item.get("name", "")
		else:
			item_name = str(item)
		if item_name not in crew_item_names:
			stash.append(item)

	# Also update world_phase_data for consistency
	world_phase_data["stash"] = stash

	if assign_equipment_component and assign_equipment_component.has_method("initialize_equipment_phase"):
		assign_equipment_component.initialize_equipment_phase(
			crew_data, stash)

## Public API for external integration
func get_current_step() -> WorldPhaseStep:
	## Get current world phase step
	return current_step

func is_world_phase_complete() -> bool:
	## Check if entire world phase is completed
	for step in step_completed.values():
		if not step:
			return false
	return true

func get_world_phase_results() -> Dictionary:
	## Get complete world phase results
	return {
		"upkeep_results": upkeep_component.get_upkeep_results() if upkeep_component else {},
		"step_completed": step_completed.duplicate(),
		"automation_used": automation_enabled
	}

func reset_world_phase() -> void:
	## Reset world phase for new turn
	current_step = WorldPhaseStep.UPKEEP
	# A new world phase can complete again (see _complete_world_phase).
	_world_phase_completed = false
	step_completed = {
		WorldPhaseStep.UPKEEP: false,
		WorldPhaseStep.CREW_TASKS: false,
		WorldPhaseStep.JOB_OFFERS: false,
		WorldPhaseStep.ASSIGN_EQUIPMENT: false,
		WorldPhaseStep.RESOLVE_RUMORS: false,
		WorldPhaseStep.MISSION_PREP: false
	}

	# Reset all components
	if upkeep_component and upkeep_component.has_method("reset_upkeep_phase"):
		upkeep_component.reset_upkeep_phase()
	if crew_task_component and crew_task_component.has_method("reset_crew_tasks"):
		crew_task_component.reset_crew_tasks()
	# `reset_job_phase` is the real name — `reset_job_offers` has zero definitions,
	# so this guard was permanently false and the component was NEVER reset at
	# turn rollover: `job_accepted` stayed true and last turn's offers stayed on
	# the list. (The integration test calls reset_job_phase() directly on the
	# component, which is why it passed while production never invoked it.)
	if job_offer_component and job_offer_component.has_method("reset_job_phase"):
		job_offer_component.reset_job_phase()
	if assign_equipment_component and assign_equipment_component.has_method("reset_equipment_phase"):
		assign_equipment_component.reset_equipment_phase()
	if resolve_rumors_component and resolve_rumors_component.has_method("reset_rumors_phase"):
		resolve_rumors_component.reset_rumors_phase()
	if mission_prep_component and mission_prep_component.has_method("reset_mission_prep"):
		mission_prep_component.reset_mission_prep()
	# Note: Post-battle components (PurchaseItems, CampaignEvent, CharacterEvent) reset in PostBattleSequence

func _get_battle_type_for_objective(objective: String) -> int:
	## Map mission objective to GlobalEnums.BattleType int value
	## NONE=0, STANDARD=1, BOSS=2, STORY=3, EVENT=4
	match objective.to_lower():
		"patrol", "security", "delivery", "escort", "exploration", "retrieval":
			return 1  # STANDARD
		"elimination", "sabotage":
			return 1  # STANDARD
		"rescue", "investigation":
			return 1  # STANDARD
		"special":
			return 3  # STORY
		_:
			return 1  # Default to STANDARD — most missions are combat

## Deferred Event System - Check and resolve pending events

# Popup for resolving deferred events
var deferred_event_popup: AcceptDialog = null
var pending_deferred_events: Array = []
var current_deferred_event_index: int = 0

func check_deferred_events(trigger_type: String) -> void:
	## Check for and display pending deferred events matching trigger type.
	##
	## Trigger types:
	## - NEW_PLANET: When arriving at new planet
	## - NEXT_TURN: At start of campaign turn (called from _setup_initial_state)
	## - THIS_BATTLE: Before battle starts
	## - ON_QUEST: When undertaking a quest
	## - ON_RECRUIT: When recruiting crew
	## - PERSISTENT: Check each planet for trade goods, spare parts
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		return

	var campaign = game_state.current_campaign
	if not campaign:
		return

	# Deferred events live in progress_data["pending_events"] — that is where the
	# producer puts them (CrewTaskComponent, when a crew task defers an effect).
	# This read looked for a top-level `pending_events` PROPERTY, which
	# FiveParsecsCampaignCore does not declare, so `"pending_events" in campaign`
	# was permanently false and the Dictionary branch never applied to a Resource
	# campaign. Deferred events therefore accumulated in the save forever and no
	# trigger ever fired one.
	var all_pending: Array = _progress_data_of(campaign).get("pending_events", [])

	if all_pending.is_empty():
		return

	# Filter events by trigger type
	pending_deferred_events = []
	# `campaign_turn` is likewise not a property on the core; turns_played is the
	# SSOT (see the data-ownership table).
	var current_turn: int = int(_progress_data_of(campaign).get("turns_played", 0))
	for event in all_pending:
		if event.get("trigger_type", "") == trigger_type and not event.get("consumed", false):
			# Check expiration
			var expires = event.get("expires_turn", null)
			if expires == null or current_turn <= expires:
				pending_deferred_events.append(event)

	if pending_deferred_events.is_empty():
		return

	# Show first event
	current_deferred_event_index = 0
	_show_deferred_event_popup()

func _show_deferred_event_popup() -> void:
	## Show popup for current deferred event
	if current_deferred_event_index >= pending_deferred_events.size():
		# All events processed
		pending_deferred_events = []
		return

	var event = pending_deferred_events[current_deferred_event_index]

	# Create popup if needed
	if not deferred_event_popup:
		deferred_event_popup = AcceptDialog.new()
		deferred_event_popup.title = "Deferred Event"
		deferred_event_popup.confirmed.connect(_on_deferred_event_confirmed)
		deferred_event_popup.canceled.connect(_on_deferred_event_confirmed)  # Same behavior
		add_child(deferred_event_popup)

	# Build popup content
	var effect = event.get("effect", {})
	var event_name = event.get("event_name", "Unknown Event")
	var crew_id = event.get("crew_id", "Unknown")

	var content = "%s\n\n" % event_name
	content += "Crew: %s\n" % crew_id
	content += "Trigger: %s\n\n" % event.get("trigger_type", "")

	# Show effect details
	if effect is Dictionary:
		content += "Effect: %s\n" % effect.get("effect", "No description")

		var rewards: Array = []
		if effect.get("credits", 0) > 0:
			rewards.append("+%d credits" % effect.credits)
		if effect.get("xp", 0) > 0:
			rewards.append("+%d XP" % effect.xp)
		if effect.get("story_points", 0) > 0:
			rewards.append("+%d story point" % effect.story_points)
		if effect.get("items", []).size() > 0:
			for item in effect.items:
				rewards.append(item)

		if rewards.size() > 0:
			content += "\nRewards: %s" % ", ".join(rewards)

	deferred_event_popup.dialog_text = content
	deferred_event_popup.popup_centered()

func _on_deferred_event_confirmed() -> void:
	## Handle deferred event confirmation - apply effects and mark consumed
	if current_deferred_event_index >= pending_deferred_events.size():
		return

	var event = pending_deferred_events[current_deferred_event_index]

	# Apply effects
	_apply_deferred_event_effects(event)

	# Mark event as consumed
	event["consumed"] = true

	# Check for single_use items to remove from pending
	var effect = event.get("effect", {})
	if effect is Dictionary and effect.get("single_use", false):
		_remove_consumed_event(event)

	# Move to next event
	current_deferred_event_index += 1
	_show_deferred_event_popup()

func _apply_deferred_event_effects(event: Dictionary) -> void:
	## Apply the effects of a deferred event to campaign state
	var effect = event.get("effect", {})
	if not effect is Dictionary:
		return

	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return

	# Apply credits
	var credits = effect.get("credits", 0)
	if credits != 0 and GameStateManager:
		GameStateManager.add_credits(credits)

	# Apply story points
	var story_points = effect.get("story_points", 0)
	if story_points > 0:
		var campaign = game_state.current_campaign
		if campaign is Resource and "story_points" in campaign:
			campaign.story_points += story_points
		elif campaign is Dictionary:
			campaign["story_points"] = campaign.get("story_points", 0) + story_points

	# Apply XP to crew member
	var xp = effect.get("xp", 0)
	if xp > 0:
		var crew_id = event.get("crew_id", "")
		var campaign = game_state.current_campaign
		if campaign:
			var crew = campaign.get("crew", []) if campaign is Dictionary else []
			for character in crew:
				var char_id = character.get("id", character.get("character_id", "")) if character is Dictionary else ""
				if char_id == crew_id:
					if character is Dictionary:
						character["experience"] = character.get("experience", 0) + xp
					break

	# Handle rival generation
	if effect.get("rival", false):
		var campaign = game_state.current_campaign
		if campaign:
			# Generate new rival
			var new_rival = {
				"id": "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"name": "Rival %d" % (randi() % 100 + 1),
				"type": ["Criminal", "Corporate", "Military", "Pirate", "Cult"][randi() % 5],
				"hostility": randi() % 3 + 3,  # 3-5 hostility
				"resources": randi() % 3 + 1,  # 1-3 resources
				"source": "deferred_event",
				"created_turn": campaign.get("campaign_turn", 1) if campaign is Dictionary else 1
			}
			var rivals = campaign.get("rivals", []) if campaign is Dictionary else []
			rivals.append(new_rival)
			if campaign is Dictionary:
				campaign["rivals"] = rivals

	# Handle rumor generation
	if effect.get("rumor", false):
		var campaign = game_state.current_campaign
		if campaign:
			# Generate rumor per Core Rules p.3098-3110 (D10 for flavor)
			var rumor_types = [
				"An extracted data file",
				"An extracted data file",
				"Notebook with secret information",
				"Notebook with secret information",
				"Old map showing a location",
				"Old map showing a location",
				"A tip from a contact",
				"A tip from a contact",
				"An intercepted transmission",
				"An intercepted transmission"
			]
			var rumor_roll = randi() % 10
			var new_rumor = {
				"id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"type": rumor_roll + 1,
				"description": rumor_types[rumor_roll],
				"source": "deferred_event",
				"created_turn": campaign.get("campaign_turn", 1) if campaign is Dictionary else 1
			}
			var rumors = campaign.get("rumors", []) if campaign is Dictionary else []
			rumors.append(new_rumor)
			if campaign is Dictionary:
				campaign["rumors"] = rumors

func _remove_consumed_event(event: Dictionary) -> void:
	## Remove consumed single-use event from campaign pending events
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		return

	var campaign = game_state.current_campaign
	if not campaign:
		return

	var event_id = event.get("id", "")
	if event_id == "":
		return

	# Same wrong location as the reader above: the list lives in
	# progress_data["pending_events"], so consuming an event has to remove it
	# from THERE or the event would fire again on the next matching trigger.
	var pd: Dictionary = _progress_data_of(campaign)
	if pd.is_empty():
		return
	var remaining: Array = (pd.get("pending_events", []) as Array).filter(
		func(e): return e.get("id", "") != event_id)
	pd["pending_events"] = remaining


# The MissionSelectionUI integration was DELETED here. All of it was dead:
# _initialize_mission_selection() was a `pass` documented as deprecated in
# favour of JobOfferComponent, `mission_selection_ui` was declared and NEVER
# assigned, and _on_mission_selected() / _on_mission_selection_cancelled()
# were therefore connected to nothing and unreachable. The screen itself and
# its "mission_selection" SceneRouter route went with it — the route had ZERO
# navigate_to callers.

func _advance_to_next_step() -> void:
	## Advance to the next step in the world phase workflow

	if current_step < WorldPhaseStep.MISSION_PREP:
		current_step = current_step + 1
		_show_current_step()
	else:
		_complete_world_phase()

func _update_phase_display() -> void:
	## Update the UI to reflect current phase step
	_update_ui_display()

## Debug Mode - Developer Testing Shortcuts
func _input(event: InputEvent) -> void:
	## Handle debug hotkeys for fast iteration during development
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				# Skip directly to battle with synthetic mission data
				_debug_skip_to_battle()
			KEY_F6:
				# Auto-complete current step (for testing)
				_debug_complete_current_step()

func _debug_skip_to_battle() -> void:
	## [DEBUG] Skip directly to battle phase with generated test data

	# Load test helper for mock data
	var HelperClass = load("res://tests/helpers/CampaignTurnTestHelper.gd")
	var helper = HelperClass.new()

	# Generate mock battle context
	var mock_battle_data = helper.create_mock_battle_phase_data()

	# Add crew data from current state
	mock_battle_data["crew"] = crew_data.duplicate()
	mock_battle_data["ship"] = ship_data.duplicate()

	# Create full mission context for battle transition
	var mission_context = {
		"mission_type": mock_battle_data.get("mission_type", "OPPORTUNITY"),
		"enemy_count": mock_battle_data.get("enemy_count", 5),
		"enemy_type": mock_battle_data.get("enemy_type", "RAIDERS"),
		"deployment_zones": ["north", "south"],
		"terrain_type": "urban",
		"objective": "eliminate_hostiles",
		"crew": crew_data,
		"equipment": world_phase_data.get("stash", [])
	}

	# Publish event to trigger battle transition
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "world_phase",
			"results": {"debug_skip": true},
			"next_phase": "battle_phase",
			"mission_context": mission_context
		})


func _debug_complete_current_step() -> void:
	## [DEBUG] Auto-complete current step for testing
	step_completed[current_step] = true
	_update_ui_display()

	# Auto-advance if enabled
	if automation_enabled:
		_on_next_button_pressed()

# =====================================================
# CHECKPOINT SAVES (Sprint 26.4: Enhanced for World Phase state persistence)
# =====================================================

func save_checkpoint() -> void:
	## Sprint 26.4: Save World Phase checkpoint before transitioning away.
	## Saves to local _checkpoint_data for quick restore and to campaign for persistence.
	# QA-FIX BUG-12: Include turn_number so stale checkpoints from previous
	# turns can be detected and discarded on restore.
	var current_turn: int = 0
	var gs_ref = get_node_or_null("/root/GameState")
	if gs_ref and gs_ref.current_campaign and "progress_data" in gs_ref.current_campaign:
		current_turn = gs_ref.current_campaign.progress_data.get(
			"turns_played", 0)
	# ⚠ THIS IS A FIXED KEY LITERAL, so anything not named here is simply not in
	# the checkpoint. The accepted job was not: it lives in JobOfferComponent's
	# memory, and `_refresh_mission_prep()` (:2104-2106) reads the mission from
	# `job_offer_component.get_accepted_job()` and nowhere else. A resumed
	# checkpoint therefore rebuilt that component empty and rendered the Mission
	# Prep briefing as "Objective: Unknown / Enemy: Unknown / Pay: 0" — measured on
	# the tablet Aug 13 2026, on a save whose accepted job was intact everywhere
	# else. The player had accepted a job and the resume lost it.
	#
	# `get_step_results()` is the component's own serialization and
	# `restore_step_results()` its inverse; keep using the pair rather than
	# re-listing its fields here, or this literal will drift the same way again.
	var job_offers_state: Dictionary = {}
	if job_offer_component and job_offer_component.has_method("get_step_results"):
		job_offers_state = job_offer_component.get_step_results()

	_checkpoint_data = {
		"current_step": current_step,
		"step_completed": step_completed.duplicate(),
		"world_phase_data": world_phase_data.duplicate(),
		"automation_enabled": automation_enabled,
		"job_offers": job_offers_state,
		"turn_number": current_turn,
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Also save to campaign for crash recovery
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var campaign = gs.current_campaign
		if campaign is Dictionary:
			campaign["world_phase_checkpoint"] = _checkpoint_data.duplicate()
		elif campaign is Resource and "progress_data" in campaign:
			campaign.progress_data["world_phase_checkpoint"] = _checkpoint_data.duplicate()

	# Trigger a game save. GameStateManager has no quick_save/save_game (those
	# guards never passed → checkpoint saves were silent no-ops); the real API is
	# GameState.save_campaign() (gs fetched above).
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign()


func _restore_job_offers_from_checkpoint() -> void:
	## Re-adopt the accepted job saved by save_checkpoint().
	##
	## Split out of restore_from_checkpoint() ON PURPOSE: it has to run AFTER
	## `_fetch_campaign_data()`, which rebuilds JobOfferComponent via
	## `initialize_job_offers()`. Called earlier, the restore is overwritten and
	## the resumed Mission Prep briefing is blank exactly as if nothing had been
	## saved at all.
	##
	## Pre-fix checkpoints carry no "job_offers" key, restore to {}, and behave
	## as they do today.
	if job_offer_component and job_offer_component.has_method("restore_step_results"):
		job_offer_component.restore_step_results(
			_checkpoint_data.get("job_offers", {}))


func restore_from_checkpoint() -> void:
	if _checkpoint_data.is_empty():
		return

	current_step = _checkpoint_data.get("current_step", WorldPhaseStep.UPKEEP)
	step_completed = _checkpoint_data.get("step_completed", {}).duplicate()
	world_phase_data = _checkpoint_data.get("world_phase_data", {}).duplicate()
	automation_enabled = _checkpoint_data.get("automation_enabled", false)

	# NOTE the accepted job is deliberately NOT restored here — see
	# `_restore_job_offers_from_checkpoint()`, which the caller invokes AFTER
	# component initialization. Restoring it at this point is silently undone.

	# RE-DERIVE the stash instead of trusting the checkpoint's copy.
	#
	# world_phase_data["stash"] is populated from campaign.get_all_equipment()
	# (:378, :1287) and then PERSISTED inside progress_data.world_phase_checkpoint.
	# That makes it a second, independently-stale copy of the ship stash, and it is
	# what every World Phase surface reads (:496, :508, :1292).
	#
	# It is already known to diverge: a real save inspected on 2026-07-27 carried 16
	# checkpoint items against 8 canonical ones — every item doubled, because the
	# checkpoint was taken while get_all_equipment() was still unioning the
	# split-format keys (fixed in 87c06567). The load-time heal in GameState repairs
	# equipment_data but does NOT reach inside this checkpoint, so a pre-fix
	# checkpoint would restore the doubled list straight back into the UI.
	#
	# Re-deriving on restore fixes existing saves without a migration and removes the
	# divergence permanently: the stash is derivable, so it should never have been a
	# persisted copy in the first place.
	var gs_for_stash = get_node_or_null("/root/GameState")
	var live_campaign = gs_for_stash.current_campaign if gs_for_stash else null
	if live_campaign != null:
		if live_campaign is Dictionary:
			if live_campaign.has("stash"):
				world_phase_data["stash"] = live_campaign.get("stash", [])
		elif live_campaign.has_method("get_all_equipment"):
			world_phase_data["stash"] = live_campaign.get_all_equipment()
		elif "equipment_data" in live_campaign:
			world_phase_data["stash"] = live_campaign.equipment_data.get("equipment", [])

	# Ensure all step keys exist with defaults (guards against incomplete checkpoint data)
	for step_key in [WorldPhaseStep.UPKEEP, WorldPhaseStep.CREW_TASKS,
			WorldPhaseStep.JOB_OFFERS, WorldPhaseStep.ASSIGN_EQUIPMENT,
			WorldPhaseStep.RESOLVE_RUMORS, WorldPhaseStep.MISSION_PREP]:
		if step_key not in step_completed:
			step_completed[step_key] = false

	# Restore UI state
	_show_current_step()
	_update_ui_display()

	if automation_toggle:
		automation_toggle.button_pressed = automation_enabled


## Whether a checkpoint belongs to a turn other than `current_turn`, or is already
## finished. Pure and static so the staleness rule is testable and, more
## importantly, so it has exactly ONE definition.
##
## T2-06: this logic already existed — inline in _setup_initial_state(), with a
## comment naming the precise symptom it was written to stop ("step 5 checkmark
## appearing on Turn 2's Upkeep"). It was correct. It just sat on a path the live
## flow does not take: CampaignTurnController REUSES this controller in place on
## Turn 2+, which fires neither _ready() nor _setup_initial_state(), so on every
## auto-advanced turn the only consulted gate was has_checkpoint() — and that asked
## nothing but `is_empty()`. Last turn's `step_completed` therefore survived into
## the new turn and the strip rendered `1 2 3 4 ✓ 6` on a fresh Step 1.
##
## Same shape as W2-01: a correct guard, on a path the real flow skips. Producers
## wrote `turn_number` for this exact purpose (see save_checkpoint) and no consumer
## ever read it.
static func is_checkpoint_stale(cp: Dictionary, current_turn: int) -> bool:
	if cp.is_empty():
		return false          # nothing to be stale
	var cp_turn: int = int(cp.get("turn_number", -1))
	if cp_turn >= 0 and current_turn >= 0 and cp_turn != current_turn:
		return true
	# A checkpoint whose every step is done describes a FINISHED world phase;
	# restoring it would drop the player into a turn with nothing left to do.
	var cp_steps: Dictionary = cp.get("step_completed", {})
	if cp_steps.is_empty():
		return false
	for step_key: Variant in cp_steps:
		if not cp_steps[step_key]:
			return false
	return true


func has_checkpoint() -> bool:
	## True only for a checkpoint belonging to the CURRENT turn and not already
	## finished. A stale one is discarded here rather than reported, so the single
	## caller that matters — initialize_world_phase(), which skips
	## reset_world_phase() when this returns true — cannot restore last turn's
	## completion flags on an in-place turn advance.
	if _checkpoint_data.is_empty():
		return false
	if is_checkpoint_stale(_checkpoint_data, _current_campaign_turn()):
		_checkpoint_data = {}
		clear_checkpoint()
		return false
	return true

func clear_checkpoint() -> void:
	## Sprint 26.4: Clear saved checkpoint data (both local and campaign storage)
	_checkpoint_data = {}
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign:
		var campaign = gs.current_campaign
		if campaign is Dictionary and "world_phase_checkpoint" in campaign:
			campaign.erase("world_phase_checkpoint")
		elif campaign is Resource and "progress_data" in campaign:
			campaign.progress_data.erase("world_phase_checkpoint")

func _save_world_phase_checkpoint() -> void:
	## Deprecated: Use save_checkpoint() instead. Kept for backward compatibility.
	save_checkpoint()

# =====================================================
# BATTLE PHASE TRANSITION
# =====================================================

func _navigate_to_battle_phase(world_phase_results: Dictionary) -> void:
	## Navigate to battle phase using SceneRouter with fallbacks

	# Try SceneRouter first (preferred method)
	if SceneRouter and SceneRouter.has_method("navigate_to"):
		SceneRouter.navigate_to("pre_battle")
		return

	# Fallback to GameStateManager navigation
	if GameStateManager and GameStateManager.has_method("navigate_to_screen"):
		GameStateManager.navigate_to_screen("pre_battle")
		return

	# Final fallback: navigate via SceneRouter
	SceneRouter.call_deferred("navigate_to", "pre_battle")

func _show_battle_scene_missing_error() -> void:
	## Show error dialog when battle scene is missing
	# Use NotificationManager if available
	if has_node("/root/NotificationManager"):
		var notif_manager = get_node("/root/NotificationManager")
		if notif_manager.has_method("show_error"):
			notif_manager.show_error(
				"Battle Screen Not Found",
				"The battle interface could not be loaded. Returning to Campaign Dashboard.\n\nPlease report this issue if it persists."
			)
			return

	# Fallback: Create a simple error dialog
	var error_dialog = AcceptDialog.new()
	error_dialog.title = "Battle Screen Error"
	error_dialog.dialog_text = "The battle interface could not be loaded.\n\nReturning to Campaign Dashboard."
	error_dialog.get_ok_button().text = "Continue"
	add_child(error_dialog)
	error_dialog.popup_centered()
	# Dialog will be freed when user acknowledges it
	error_dialog.confirmed.connect(error_dialog.queue_free)

## BUG-035 FIX: Enrich crew member dicts with equipment from EquipmentManager
func _enrich_crew_equipment(typed_crew: Array[Dictionary]) -> void:
	## Attach the EquipmentManager view of each member's kit WITHOUT clobbering the
	## canonical one.
	##
	## `Character.equipment` is an Array[String] of item NAMES (Character.gd:129).
	## `EquipmentManager.get_character_equipment()` returns stash item IDs. This used
	## to assign the IDs straight over `typed_crew[i]["equipment"]`, and typed_crew
	## holds the LIVE campaign member dictionaries — WorldPhaseController.gd:417 and
	## CrewTaskComponent.gd:123 only SHALLOW-duplicate the array, so the elements are
	## shared references into campaign.crew_data["members"]. One Mission Prep visit
	## therefore rewrote every crew member's canonical equipment as internal ids like
	## "rattle_gun_5168_92512", and the next save persisted that. GameState.gd:880-927
	## is a legacy heal that converts exactly those id-strings back to names, i.e.
	## this has bitten before.
	##
	## The ids ARE wanted downstream (MissionPrepComponent's assignment map), so they
	## are exposed under a SEPARATE key. MissionPrepComponent.gd:87-95 already accepts
	## either shape, and `equipment` keeps meaning names for every card and DB lookup.
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	if not eq_mgr or not eq_mgr.has_method("get_character_equipment"):
		return
	for i in range(typed_crew.size()):
		var member_id: String = typed_crew[i].get(
			"id", typed_crew[i].get("character_id", ""))
		if member_id.is_empty():
			continue
		var member_equip: Array = eq_mgr.get_character_equipment(member_id)
		if member_equip.is_empty():
			continue
		typed_crew[i]["equipment_ids"] = member_equip
		# Only fill `equipment` when the member has none — never overwrite names.
		var existing = typed_crew[i].get("equipment", [])
		if existing is Array and existing.is_empty() and eq_mgr.has_method("get_equipment"):
			var resolved: Array = []
			for eq_id in member_equip:
				var item = eq_mgr.get_equipment(str(eq_id))
				var item_name: String = ""
				if item is Dictionary:
					item_name = str(item.get("name", ""))
				resolved.append(item_name if not item_name.is_empty() else str(eq_id))
			typed_crew[i]["equipment"] = resolved


func _setup_psionic_legality_badge() -> void:
	## Display PsionicLegalityBadge in upkeep container (DLC-gated)
	if _psionic_badge:
		_psionic_badge.queue_free()
		_psionic_badge = null
	var dlc = get_node_or_null("/root/DLCManager")
	if not dlc or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		return
	# Read legality from campaign progress_data (set by WorldPhase)
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		return
	if not "progress_data" in gs.current_campaign:
		return
	var pd: Dictionary = gs.current_campaign.progress_data
	var legality: int = pd.get("psionic_legality", -1)
	if legality < 0:
		return
	_psionic_badge = PsionicLegalityBadgeClass.new()
	_psionic_badge.set_legality(legality)
	if upkeep_container:
		upkeep_container.add_child(_psionic_badge)


func _on_layout_class_changed(_cols: int = 0) -> void:
	_apply_vertical_compaction()


func _stamp_black_zone_mission(mission: Dictionary) -> void:
	## Core Rules pp.150-151 "The Mission": "Roll to determine what you are here to
	## do" — the D10 'Your Day in Hell' table. ONE roll, for this Black Job.
	##
	## THE GAP THIS FILLS, and it is two defects meeting in the middle:
	##
	## `BlackZoneSystem.roll_mission_type()`'s only caller was inside
	## `MissionPrepComponent`'s card BUILDER, so it re-rolled on every panel
	## rebuild — the briefing could say "Destroy strong point" one moment and
	## "Penetrate the lines" the next, and the crew could not know which mission
	## they were actually playing.
	##
	## Meanwhile `PostBattleCompletion.gd:161` reads
	## `battle_result["black_zone_mission"]` to journal which Black Job was
	## attempted, and `CampaignJournal.gd:204` renders it. Two live consumers on a
	## key NO producer anywhere ever wrote.
	##
	## Rolled here, at the same point and in the same shape as the Red Job Threat
	## Condition above, and PERSISTED on the campaign so it survives a panel
	## rebuild, a save and a reload. `CampaignPhaseManager._clear_black_zone_mission()`
	## drops it at turn rollover so the next Black Job rolls fresh.
	var gs: Node = get_node_or_null("/root/GameState")
	var campaign = gs.current_campaign if (gs and "current_campaign" in gs) else null
	var has_pd: bool = campaign != null and "progress_data" in campaign

	var stored: Variant = {}
	if has_pd:
		stored = campaign.progress_data.get("black_zone_mission", {})
	if not (stored is Dictionary) or (stored as Dictionary).is_empty():
		stored = BlackZoneSystemRef.roll_mission_type()
		if has_pd:
			campaign.progress_data["black_zone_mission"] = stored
	if stored is Dictionary and not (stored as Dictionary).is_empty():
		mission["black_zone_mission"] = stored


func _stamp_red_zone_threat(mission: Dictionary) -> void:
	## Core Rules p.149, verbatim: "You must roll for a Threat Condition. This is
	## an additional factor that is applied to the mission, regardless of its
	## type." One D6, rolled once when the Red Job is accepted.
	##
	## THE GAP THIS FILLS: `RedZoneSystem.roll_threat_condition()` was written,
	## correct and had ZERO callers — its only mention anywhere was the usage
	## example in its own docblock. Meanwhile `PostBattleCompletion.gd:149` reads
	## `red_zone_threat` off the battle result to journal it, so the consumer was
	## live and waiting on a producer that never ran. Every Red Job in every
	## campaign was fought with no Threat Condition at all.
	##
	## Three of the six are mechanical and are applied through keys that already
	## have consumers; the other three are table instructions the player applies,
	## so they ride along as text. "Not all of these Threat Conditions may be
	## applicable ... If so, the result is simply ignored" — so nothing here
	## forces a profile change that the enemy type does not qualify for.
	var threat: Dictionary = RedZoneSystemRef.roll_threat_condition()
	if threat.is_empty():
		return
	mission["red_zone_threat"] = threat

	match int(threat.get("roll", 0)):
		2:
			# "All opponents with +0 Combat Skill are upgraded to +1."
			mission["enemy_combat_skill_floor"] = 1
		4:
			# "Increase the opposing force by +2 enemy." enemy_delta is the
			# established bundle key with real readers in the battle funnel.
			mission["red_zone_enemy_delta"] = 2
		5:
			# "All opponents with 3 Toughness are upgraded to 4."
			mission["enemy_toughness_floor"] = 4
		6:
			# "Add an additional Lieutenant with Combat Skill +2 and Toughness 5,
			# regardless of the normal profile used."
			mission["extra_lieutenant"] = {"combat_skill": 2, "toughness": 5}


## Whole-screen touch sweep, used by _show_current_step().
##
## Separate from _open_content_to_scroll_gesture(), which is deliberately scoped to
## ContentScroll for the layout paths. This one exists because a STEP CHANGE rebuilds
## cards under any of the screen's three scrolls.
func _open_whole_screen_to_scroll_gesture() -> void:
	TouchScrollOpenerRef.open_subtree(self)
