extends SceneTree
## WINDOWED layout-geometry sweep. Instantiates each in-scope screen and MEASURES
## it at real device sizes.
##
## Run (NOTE: no --headless — this needs a real window to resize):
##   godot --path <root> --script res://tests/tools/verify_layout.gd
##
## ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
## The three existing "responsive" suites (test_postbattle_responsive.gd,
## test_prebattle_responsive_layout.gd, test_tactical_battle_responsive.gd) assert
## CONFIGURATION — autowrap flags, whether a panel resolved, column counts — and
## never resize the viewport or measure a rect. All three were green while the
## MainMenu title rendered clipped 67px off BOTH edges and sat 103px underneath
## the button column. Configuration is the input to layout; this measures the
## OUTPUT.
##
## ── THE MEASUREMENT THAT MAKES IT POSSIBLE ───────────────────────────────────
## On Windows DisplayServer.screen_get_scale() is 1.0, and
## SettingsManager._apply_ui_scale() cancels the square-1080 base stretch
## (stretch_cancel = 1080 / short_axis). The result is that on BOTH desktop and
## device the design space is (window_dp / EFFECTIVE_SCALE). So a desktop window
## sized to a device's dp reproduces that device's layout arithmetic exactly:
## 393x851 gives MOBILE / portrait / 1 column / 56px touch target and a design
## space of 338.79 x 733.42, and 338.79 * 1.16 == 393.0.
## The ratio is DERIVED per-measurement below, never hardcoded, so a change to
## SettingsManager.TARGET_EFFECTIVE cannot silently invalidate the dp checks.
##
## ── HARNESS CONSTRAINTS (inherited from verify_post_battle.gd; do not relax) ──
##  1. All work runs in _process() on frame >= 2, NEVER _initialize(): under
##     --script the autoloads exist but root.is_inside_tree() is false during
##     _initialize(), so every "/root/X" lookup errors.
##  2. NOTHING is preload()ed. Several production scripts reference bare autoload
##     identifiers, which are not registered as GDScript globals when a --script
##     main loop is compiled. Runtime load() from inside _process() works.
##
## Exit 1 on any FAIL. A screen that cannot be instantiated is SKIPped WITH ITS
## REASON and counted separately — a skip is never folded into the pass count.

## Device sizes in dp. Chosen to cover every branch in ResponsiveManager:
## MOBILE/portrait, DESKTOP-bucket-but-portrait (a tablet), the phone-in-landscape
## case that lands in the DESKTOP bucket with only ~339 design px of height, and
## the desktop/wide ladder.
const SIZES: Array = [
	[393, 851, "phone portrait"],
	[851, 393, "phone landscape"],
	[800, 1280, "tablet portrait"],
	[1280, 800, "tablet landscape"],
	[1920, 1080, "desktop 1080p"],
	[360, 640, "small phone"],
]

## Core Rules-independent UX floor: Material/Android minimum touch target.
const TOUCH_FLOOR_DP := 48.0
## Sub-pixel slack so a 0.0001 rounding artefact is not a failure.
const EPS := 0.5

## A1 alpha surface. Bug Hunt / Planetfall / Tactics are hidden by
## MainMenu.gd A1_BUILD and are deliberately out of scope.
const SCREENS: Array = [
	"res://src/ui/screens/mainmenu/MainMenu.tscn",
	"res://src/ui/screens/legal/EULAScreen.tscn",
	"res://src/ui/screens/legal/LegalTextViewer.tscn",
	"res://src/ui/screens/settings/SettingsScreen.tscn",
	"res://src/ui/help/HelpScreen.tscn",
	"res://src/ui/screens/tutorial/TutorialSelection.tscn",
	"res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"res://src/ui/screens/campaign/CampaignEditorScreen.tscn",
	"res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"res://src/ui/screens/campaign/CampaignTurnController.tscn",
	"res://src/ui/screens/campaign/CampaignJournalScreen.tscn",
	"res://src/ui/screens/galaxy_log/GalaxyLogScreen.tscn",
	"res://src/ui/screens/character/SimpleCharacterCreator.tscn",
	"res://src/ui/screens/character/CharacterDetailsScreen.tscn",
	"res://src/ui/screens/crew/CrewManagementScreen.tscn",
	"res://src/ui/screens/equipment/EquipmentManager.tscn",
	"res://src/ui/screens/equipment/EquipmentGenerationScene.tscn",
	"res://src/ui/screens/ships/ShipManager.tscn",
	"res://src/ui/screens/world/WorldPhaseController.tscn",
	# MissionSelectionUI.tscn is deliberately NOT in scope. Every one of its controls
	# lives under a PopupPanel, which is a Window: it lays out against its OWN rect,
	# not root.get_visible_rect(), so measuring it here compares two different
	# coordinate spaces and reports overflow that cannot exist on screen. It needs
	# Window-aware measurement (deferred, see docs/QA_STATUS_DASHBOARD.md), not a
	# skip line that pretends the screen was checked.
	"res://src/ui/screens/world/PatronRivalManager.tscn",
	"res://src/ui/screens/battle/PreBattle.tscn",
	"res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"res://src/ui/screens/postbattle/PostBattleSequence.tscn",
	"res://src/ui/screens/utils/GameOverScreen.tscn",
	"res://src/ui/screens/battle_simulator/BattleSimulatorUI.tscn",
	"res://src/ui/screens/compendium/CompendiumScreen.tscn",
	"res://src/ui/screens/compendium/CompendiumCategoryView.tscn",
	"res://src/ui/screens/print/PrintSheetScreen.tscn",
	"res://src/ui/screens/store/StoreScreen.tscn",
]

var _frame := 0
var _started := false
var _pass := 0
var _fail := 0
var _skip := 0
var _findings: Array = []


## NOTE: _process must NOT return true to end the run. This sweep is a coroutine —
## it awaits frames so containers can actually lay out — and returning true would
## quit the main loop at the first await, before any measurement happened. So the
## loop is kept alive and _run() calls quit() itself when it is finished.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()  # fire-and-forget coroutine; quits when done
	return false


func _run() -> void:
	_load_requested_campaign()
	print("=== LAYOUT SWEEP: %d screens x %d sizes ===" % [SCREENS.size(), SIZES.size()])
	# STATE MATTERS AND IS NOT ALWAYS THE SAME. Several screens build from the current
	# campaign, so a machine that has one auto-loaded measures far more content than an
	# empty one — CampaignDashboard's landscape overflow went 30.6 -> 154.8 px purely
	# from a campaign being present. Both readings are legitimate; a run whose header
	# says NO CAMPAIGN is a FLOOR, not a clean bill of health. Print it so two runs are
	# never silently compared across that boundary.
	print("campaign state: %s" % _campaign_state())
	for path in SCREENS:
		await _sweep_screen(path)
	print("\n================ RESULT ================")
	print("passed=%d failed=%d skipped=%d" % [_pass, _fail, _skip])
	if not _findings.is_empty():
		print("\n---- FINDINGS ----")
		for f in _findings:
			print("  " + f)
	print("LAYOUT SWEEP: %s" % ("PASS" if _fail == 0 else "FAIL"))
	quit(1 if _fail > 0 else 0)


## Load a campaign on request, so "with content" is a DELIBERATE input.
##
##   godot ... --script res://tests/tools/verify_layout.gd -- campaign=user://saves/x.save
##
## Without this the state is whatever the machine happened to have: a campaign left
## loaded by a previous session made the sweep measure real content (finding real
## defects an empty screen hides), and then quietly unloaded again, so two runs an
## hour apart were not measuring the same thing. Both readings are worth having —
## just never by accident.
func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty():
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("load_campaign"):
		print("campaign load requested but GameState is unavailable: %s" % wanted)
		return
	if not FileAccess.file_exists(wanted):
		print("campaign load requested but file does not exist: %s" % wanted)
		return
	gs.load_campaign(wanted)


## Which campaign, if any, the screens will build from. See the note in _run().
func _campaign_state() -> String:
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null:
		return "GameState autoload missing"
	var campaign = null
	if gs.has_method("get_current_campaign"):
		campaign = gs.get_current_campaign()
	if campaign == null:
		return "NO CAMPAIGN loaded (screens that build from campaign data render empty)"
	var id := ""
	if "campaign_id" in campaign:
		id = str(campaign.campaign_id)
	elif "campaign_name" in campaign:
		id = str(campaign.campaign_name)
	return "campaign loaded: %s" % (id if not id.is_empty() else "<unnamed>")


func _sweep_screen(path: String) -> void:
	var short := path.get_file()
	if not ResourceLoader.exists(path):
		_skip += 1
		_findings.append("SKIP %s — scene file does not exist" % short)
		return
	var ps: PackedScene = load(path)
	if ps == null:
		_skip += 1
		_findings.append("SKIP %s — scene failed to load" % short)
		return
	for size_spec in SIZES:
		var w: int = size_spec[0]
		var h: int = size_spec[1]
		var label: String = size_spec[2]
		DisplayServer.window_set_size(Vector2i(w, h))
		# Two frames for the resize + one for the screen's own deferred layout.
		for _i in range(3):
			await process_frame
		var inst: Node = ps.instantiate()
		if inst == null:
			_skip += 1
			_findings.append("SKIP %s @ %s — instantiate() returned null" % [short, label])
			continue
		root.add_child(inst)
		# Modal screens ship hidden and are shown by whoever opens them —
		# SimpleCharacterCreator.gd:60 sets visible = false in _ready(). A hidden root
		# measures as zero visible Controls, which the anti-false-pass guard below was
		# reporting as "likely needs campaign state": a misdiagnosis that quietly took
		# six configs out of the sweep. Showing it is exactly what its caller does.
		if inst is CanvasItem and not (inst as CanvasItem).visible:
			(inst as CanvasItem).show()
		await _settle(inst)
		_apply_runtime_overlay_net(inst)
		await _settle(inst)
		_measure(inst, short, label)
		inst.queue_free()
		await process_frame


## Reproduce what the RUNNING APP does to every screen it navigates to.
##
## SceneRouter emits scene_changed, SettingsOverlay updates which buttons are visible
## and then reserves the band on the incoming scene (SettingsOverlay.gd:213-250). A
## sweep that add_child()es a screen never emits that signal, so every screen here was
## being measured WITHOUT a reservation the user always gets — reporting collisions
## that do not happen in the app, and hiding which screens are genuinely unreachable
## by the net.
##
## This is reproduction, NOT suppression: it calls the same two functions, in the same
## order, on the same node. reserve_band_on() only succeeds where the screen's own
## structure allows it (a root MarginContainer or a vertical root BoxContainer), so a
## screen it cannot act on still collides and still fails — which is the finding worth
## having.
func _apply_runtime_overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


## Wait until the screen's geometry STOPS CHANGING before measuring.
##
## A fixed 3-frame wait was measuring screens mid-build. Panels populate from
## call_deferred, ScrollContainers re-sort after their content arrives, and
## AdaptivePanelGroup re-parents whole panes — so an early read catches transient
## rects and reports overflow that does not exist once the screen settles.
## CampaignCreationUI was reported as "StepLabel off-screen by 86.7 px" at desktop
## while the running app had ZERO overflow there; the finding was the harness, not
## the screen.
##
## Signature is the sum of every visible Control's rect, which changes whenever
## anything moves or resizes. Three identical consecutive frames means settled.
## The cap keeps a screen that never settles (an animation, a spinner) from
## hanging the sweep — it just gets measured at the cap, as before.
func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(30):
		await process_frame
		var sig := _geometry_signature(inst)
		if sig == last:
			stable += 1
			if stable >= 3:
				return
		else:
			stable = 0
			last = sig


func _geometry_signature(inst: Node) -> String:
	var acc := 0.0
	var n := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is Control and (node as Control).is_visible_in_tree():
			var r: Rect2 = (node as Control).get_global_rect()
			acc += r.position.x + r.position.y * 3.0 + r.size.x * 7.0 + r.size.y * 11.0
			n += 1
	return "%d:%.2f" % [n, acc]


## Design-space -> dp ratio, derived live. Never hardcode 1.16: it is
## SettingsManager.TARGET_EFFECTIVE and a change there must not silently
## invalidate every touch-target check in this file.
func _dp_ratio() -> float:
	var ds: Vector2 = root.get_visible_rect().size
	if ds.x <= 0.0:
		return 1.0
	return float(DisplayServer.window_get_size().x) / ds.x


## True when the node sits inside a ScrollContainer somewhere below `stop`.
## Content inside a scroll view is ALLOWED to exceed the viewport — that is what
## scrolling means, and counting it as overflow is a false positive that will
## bury the real findings.
func _inside_scroll(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## Rect the global SettingsOverlay is occupying right now. Asked live rather than
## hardcoded because WHICH buttons are visible varies per screen (the gear hides
## on MainMenu and SettingsScreen, the bug button only on SettingsScreen).
## Content a user reads or touches — the only kind of node that can meaningfully be
## "hidden under" the floating overlay. Layout containers, separators and
## backgrounds merely span the region.
func _is_content(ctl: Control) -> bool:
	return ctl is Label or ctl is Button or ctl is LineEdit or ctl is TextEdit \
		or ctl is RichTextLabel or ctl is TextureRect or ctl is ProgressBar \
		or ctl is Slider or ctl is SpinBox or ctl is ItemList or ctl is Tree


## The rect a control's PIXELS actually occupy, which for a Label is usually much
## narrower than its box. A full-width header Label with left-aligned text has a rect
## spanning the whole screen — including the top-right overlay corner — while its
## glyphs are nowhere near it. Testing the box instead of the text reported dozens of
## "collisions" that are invisible on screen. Interactive controls are NOT narrowed:
## their whole rect is the hit area, so any part of it under the overlay is a real
## conflict even where nothing is drawn.
func _drawn_rect(ctl: Control, r: Rect2) -> Rect2:
	if not (ctl is Label):
		return r
	var lbl := ctl as Label
	if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return r  # wrapped text fills the box width
	var fnt: Font = lbl.get_theme_font("font")
	if fnt == null:
		return r
	var w: float = minf(
		fnt.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			lbl.get_theme_font_size("font_size")).x,
		r.size.x)
	var x: float = r.position.x
	match lbl.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = r.position.x + (r.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_FILL:
			x = r.position.x + r.size.x - w
	return Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y))


## A near-full-screen element is a backdrop, not content that got covered.
func _is_backdrop(r: Rect2, ds: Vector2) -> bool:
	if ds.x <= 0.0 or ds.y <= 0.0:
		return false
	return (r.size.x * r.size.y) >= (ds.x * ds.y) * 0.8


## True when an ancestor (below `stop`) already overflows by at least as much, so
## this node's overflow is a consequence rather than the cause.
func _parent_already_overflows(ctl: Control, stop: Node, off: float) -> bool:
	var ds: Vector2 = root.get_visible_rect().size
	var p := ctl.get_parent()
	while p != null and p != stop:
		if p is Control and (p as Control).is_visible_in_tree():
			var pr: Rect2 = (p as Control).get_global_rect()
			if pr.size.x > 0.0 and pr.size.y > 0.0:
				var poff: float = maxf(
					maxf(-pr.position.x, pr.end.x - ds.x),
					maxf(-pr.position.y, pr.end.y - ds.y))
				if poff >= off - EPS:
					return true
		p = p.get_parent()
	return false


## Catch CONTENT DRAWN ON TOP OF OTHER CONTENT.
##
## The MainMenu showcase card is anchored top-to-bottom with an 80px bottom offset
## reserving the social footer, and grow_vertical = GROW_DIRECTION_END. When its
## minimum exceeded that slot it expanded DOWNWARD, putting its call-to-action button
## on top of the footer links. Nothing clipped, nothing went off-screen, and no
## minimum-size check could see it — the two controls simply occupied the same pixels.
##
## Restricted to ANCHOR-POSITIONED siblings: children of a Container are laid out by
## the parent and cannot overlap each other, so testing those would be pure noise.
## Backdrops are skipped (a full-bleed background legitimately sits under everything)
## and Labels are compared on their DRAWN text, not their full box.
##
## An earlier version of this check compared each control against the slot its anchors
## allocated. It fired 23 times across screens that look perfectly fine, because
## growing past the anchor box is normal minimum-size behaviour — the parent usually
## has room. A check that cries wolf is worse than no check, so it was replaced with
## this one, which tests the thing that actually goes wrong.
func _check_sibling_overlap(ctl: Control, problems: Array) -> void:
	var parent := ctl.get_parent()
	if parent == null or parent is Container or not (parent is Control):
		return
	if not _is_content(ctl):
		return
	var ds: Vector2 = root.get_visible_rect().size
	var r: Rect2 = _drawn_rect(ctl, ctl.get_global_rect())
	if r.size.x <= 0.0 or r.size.y <= 0.0 or _is_backdrop(r, ds):
		return
	for sibling in parent.get_children():
		if sibling == ctl or not (sibling is Control):
			continue
		var sib := sibling as Control
		if not sib.is_visible_in_tree() or not _is_content(sib):
			continue
		# Only report each pair once — the later sibling (drawn on top) is the one
		# doing the covering, so it is the one worth naming.
		if sib.get_index() > ctl.get_index():
			continue
		var sr: Rect2 = _drawn_rect(sib, sib.get_global_rect())
		if sr.size.x <= 0.0 or sr.size.y <= 0.0 or _is_backdrop(sr, ds):
			continue
		var hit: Rect2 = r.intersection(sr)
		# A few pixels of touching is kerning slop, not a covered control.
		if hit.size.x > 4.0 and hit.size.y > 4.0:
			problems.append("%s is drawn ON TOP OF %s (%.0fx%.0f px of overlap) — "
				% [String(ctl.name), String(sib.name), hit.size.x, hit.size.y]
				+ "anchored siblings, so one of them grew past what its offsets reserved")


## Catch the autowrap-collapse trap: a wrapping control whose minimum WIDTH fell to its
## longest word, so its minimum HEIGHT became the whole string's line count.
##
## This project has walked into it three times — an AdvancementManager title that turned
## a header 900px tall, a HelpScreen title that rendered one letter per line, and the
## World Phase travel buttons that became 32px-wide, 486px-tall slabs with no readable
## text. Each time it was caught by a screenshot, never by measurement, because nothing
## overflows: the control is politely tiny in one axis and enormous in the other.
##
## Measured signature (tests/tools/probe_control_caps.gd, verbatim numbers):
##   autowrapping Button in a horizontal BoxContainer, default FILL flags → min 32x486
##   the same Button with SIZE_EXPAND_FILL                                → min 32x45
##   autowrapping Button in an HFlowContainer                             → min 32x486
##   the same Button with autowrap OFF                                    → min 254x45
##
## So the test is: the control wraps, its minimum width is a fraction of the width the
## text would need unwrapped, and its minimum height is several lines. That holds in any
## container, which is why this checks the geometry rather than the parent's class — the
## parent's class only goes in the message, to point at the fix.
func _check_autowrap_collapse(ctl: Control, problems: Array) -> void:
	var text := ""
	var wraps := false
	if ctl is Label:
		text = (ctl as Label).text
		wraps = (ctl as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	elif ctl is Button:
		text = (ctl as Button).text
		wraps = (ctl as Button).autowrap_mode != TextServer.AUTOWRAP_OFF
	if not wraps or text.strip_edges().is_empty():
		return
	var fnt: Font = ctl.get_theme_font("font")
	if fnt == null:
		return
	var one_line: Vector2 = fnt.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, ctl.get_theme_font_size("font_size"))
	if one_line.x <= 0.0 or one_line.y <= 0.0:
		return
	var m: Vector2 = ctl.get_combined_minimum_size()
	# Half the unwrapped width is generous: a legitimately wrapped two-line control sits
	# near 50%. The slab sits near 12%.
	var collapsed_width: bool = m.x < one_line.x * 0.5
	# Three lines of text as a MINIMUM means the container is going to hand it that
	# height forever, not that the text happens to be long.
	var stacked_height: bool = m.y > one_line.y * 3.0
	# AND the container actually handed it that collapsed width. A collapsed minimum on
	# its own is harmless: a child of a VERTICAL container gets the full column width
	# under the default FILL flag and wraps normally, which is why the EULA consent
	# checkbox (min 64 wide, actually ~300) renders correctly and must not be flagged.
	# The pathology is the container giving the child its MINIMUM — a FlowContainer, or
	# a horizontal BoxContainer where the child does not expand.
	var got_the_minimum: bool = ctl.size.x <= m.x + 2.0
	if collapsed_width and stacked_height and got_the_minimum:
		var parent_class := "no parent"
		var p := ctl.get_parent()
		if p != null:
			parent_class = p.get_class()
			if p is BoxContainer:
				parent_class += (" (vertical)" if (p as BoxContainer).vertical
					else " (horizontal)")
		# The PATH, not just the name: these are code-built nodes with autogenerated
		# names like @Label@2497, which locate nothing.
		var where := String(ctl.name)
		var screen_root := ctl.get_parent()
		while screen_root != null and screen_root.get_parent() != root:
			screen_root = screen_root.get_parent()
		if screen_root != null:
			where = "%s [\"%s\"]" % [str(screen_root.get_path_to(ctl)), text.substr(0, 32)]
		problems.append(
			"%s autowraps but collapsed to %.0fx%.0f (unwrapped one line is %.0fx%.0f) "
			% [where, m.x, m.y, one_line.x, one_line.y]
			+ "inside a %s — it will render as a tall thin slab. " % parent_class
			+ "Give it SIZE_EXPAND_FILL, put it in a vertical container, or drop autowrap "
			+ "for clip_text + ellipsis.")


## Name the DEEPEST descendant whose own minimum accounts for this overflow.
##
## The finding above reports the OUTERMOST node, which is the right thing to report —
## but it is never the thing to fix. A minimum propagates all the way up, so a screen
## that hangs 127px off the edge is usually one label or one button row deep inside it
## refusing to shrink. Without this you fix by guesswork, one sweep run per guess.
##
## "Accounts for" is generous by 8px so panel padding between the driver and the
## reported node does not hide it, and the DEEPEST match wins because every ancestor
## of the real driver reports the same inflated minimum.
func _driver_hint(ctl: Control, ds: Vector2) -> String:
	var minimum: Vector2 = ctl.get_combined_minimum_size()
	# Pick the axis that is actually overflowing, not the one whose minimum happens to
	# exceed the viewport. A grow-both container that overflows re-centres itself, so
	# it can hang off both edges while its minimum still fits — those findings got no
	# hint at all until this used the RECT to choose the axis.
	var r: Rect2 = ctl.get_global_rect()
	var h_off: float = maxf(-r.position.x, r.end.x - ds.x)
	var v_off: float = maxf(-r.position.y, r.end.y - ds.y)
	var horiz: bool = h_off >= v_off
	var target: float = minimum.x if horiz else minimum.y
	if target <= 0.0:
		return ""
	var best: Control = null
	var best_depth := -1
	var stack: Array = [[ctl, 0]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var depth: int = entry[1]
		for c in node.get_children():
			stack.append([c, depth + 1])
		if node == ctl or not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var m: Vector2 = (node as Control).get_combined_minimum_size()
		var mv: float = m.x if horiz else m.y
		if mv >= target - 24.0 and depth > best_depth:
			best = node as Control
			best_depth = depth
	if best == null:
		return ""
	return "  [%s driver: %s %s min=%.0fx%.0f]" % [
		"width" if horiz else "height", best.get_class(), str(ctl.get_path_to(best)),
		best.get_combined_minimum_size().x, best.get_combined_minimum_size().y]


func _overlay_rect() -> Rect2:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so != null and so.has_method("get_reserved_rect"):
		return so.get_reserved_rect()
	return Rect2()


func _measure(inst: Node, short: String, label: String) -> void:
	var ds: Vector2 = root.get_visible_rect().size
	var ratio := _dp_ratio()
	var overlay := _overlay_rect()
	var problems: Array = []

	var visible_controls := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var ctl := n as Control
		visible_controls += 1
		var r: Rect2 = ctl.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var nm := String(ctl.name)

		if not _inside_scroll(ctl, inst):
			var off: float = maxf(
				maxf(-r.position.x, r.end.x - ds.x),
				maxf(-r.position.y, r.end.y - ds.y))
			# Report the OUTERMOST cause only. A container that overflows drags every
			# descendant with it, and listing all of them buries the one node worth
			# fixing under dozens of consequences.
			if off > EPS and not _parent_already_overflows(ctl, inst, off):
				problems.append("%s off-screen by %.1f px%s"
					% [nm, off, _driver_hint(ctl, ds)])
			# Only content a user actually reads or taps can be "hidden under" the
			# overlay. A full-screen Background or a layout container merely SPANS
			# that corner — MainMenu reported 50 failures whose sole cause was its
			# background TextureRect, and 822 of the sweep's first 1129 findings were
			# this same noise. Verified against a screen already proven clean.
			if overlay.size.y > 0.0 and _is_content(ctl) and not _is_backdrop(r, ds) \
					and _drawn_rect(ctl, r).intersects(overlay):
				problems.append("%s collides with the SettingsOverlay band" % nm)

		# Interactive controls must clear the touch floor. Measured in dp, not
		# design px — those differ by the effective UI scale.
		if (ctl is Button or ctl is CheckBox or ctl is OptionButton or ctl is LineEdit) \
				and r.size.y * ratio < TOUCH_FLOOR_DP - EPS:
			problems.append("%s is %.1fdp tall (floor %ddp)"
				% [nm, r.size.y * ratio, int(TOUCH_FLOOR_DP)])

		_check_autowrap_collapse(ctl, problems)
		_check_sibling_overlap(ctl, problems)

		# The exact shape of the MainMenu title bug: a Label with autowrap OFF
		# demands its full unwrapped width as a minimum, which drags its whole
		# parent container past the screen edge.
		if ctl is Label:
			var lbl := ctl as Label
			if lbl.autowrap_mode == TextServer.AUTOWRAP_OFF and not lbl.clip_text:
				var need: float = lbl.get_combined_minimum_size().x
				if need > ds.x + EPS:
					problems.append("%s needs %.0fpx unwrapped in a %.0fpx space (no autowrap, no clip)"
						% [nm, need, ds.x])

	# ANTI-FALSE-PASS. A screen whose _ready() aborted (Godot 4.6 unwinds the
	# function and keeps running) renders almost nothing, and an empty screen
	# trivially satisfies every geometry check above. Counting that as a pass is
	# exactly the failure mode that let ~33 defects through 1884 green tests, so a
	# near-empty screen is reported as a SKIP with its reason instead.
	if visible_controls < 3:
		_skip += 1
		_findings.append("SKIP %s @ %s — only %d visible Controls, so its geometry was "
			% [short, label, visible_controls]
			+ "NOT verified (a modal needing an explicit show entrypoint, a _ready() "
			+ "that aborted, or a screen that builds from campaign state)")
		return

	if problems.is_empty():
		_pass += 1
	else:
		_fail += 1
		for p in problems:
			_findings.append("FAIL %s @ %s (%dx%d): %s" % [short, label, int(ds.x), int(ds.y), p])
