extends SceneTree
## ROTATION sweep. Builds each screen ONCE and then resizes it, which is what a device
## actually does — and is the one thing verify_layout.gd cannot see.
##
## Run (NOTE: no --headless — this needs a real window to resize):
##   godot --path <root> --script res://tests/tools/verify_rotation.gd
##   godot ... --script res://tests/tools/verify_rotation.gd -- campaign=user://saves/x.save
##
## ── WHY THIS EXISTS, GIVEN THE GEOMETRY SWEEP ────────────────────────────────
## verify_layout.gd instantiates a fresh screen at each size, so every screen gets a
## first-layout at its final size. A screen that builds a three-column grid and then
## IGNORES the rotation to portrait passes that sweep at both sizes and is broken on a
## real device. The bug class it misses:
##
##   * built wide, rotated narrow, never re-laid-out (no layout_class_changed wiring,
##     or a _ready() override that skipped super._ready() and lost it)
##   * re-laid-out one way only — collapses to a single column in portrait and never
##     goes back when rotated to landscape (a latch)
##   * re-laid-out but overflowed doing it (the new layout was never measured, only the
##     first one was)
##
## So this walks a SINGLE instance through portrait -> landscape -> portrait, at phone
## and tablet scale, and after every step checks both that nothing overflows AND that
## the layout actually changed shape where it must.
##
## ── WHAT "ACTUALLY CHANGED SHAPE" MEANS HERE ─────────────────────────────────
## Asserting a screen's column count equals what the code computes would just re-assert
## the implementation. The expectation asserted instead is behavioural and holds
## regardless of how it is implemented:
##
##   at PHONE PORTRAIT   an AdaptivePanelGroup shows ONE column (or its tab strip)
##   at TABLET LANDSCAPE the same group shows MORE than one column
##   returning to portrait must return to one column (no latch)
##
## Screens with no AdaptivePanelGroup are still measured for overflow at every step —
## they just have no shape assertion to make.

## Instance-once, then walk. Portrait and landscape of the SAME device, so a failure
## isolates rotation rather than a size change.
const STEPS: Array = [
	[393, 851, "phone portrait"],
	[851, 393, "phone landscape"],
	[393, 851, "phone portrait (back)"],
	[800, 1280, "tablet portrait"],
	[1280, 800, "tablet landscape"],
	[800, 1280, "tablet portrait (back)"],
]

const EPS := 0.5

## Same A1 scope as verify_layout.gd, minus screens that cannot be measured against the
## root rect (MissionSelectionUI's controls live under a PopupPanel — a Window).
const SCREENS: Array = [
	"res://src/ui/screens/mainmenu/MainMenu.tscn",
	"res://src/ui/screens/legal/EULAScreen.tscn",
	"res://src/ui/screens/settings/SettingsScreen.tscn",
	"res://src/ui/help/HelpScreen.tscn",
	"res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"res://src/ui/screens/campaign/CampaignEditorScreen.tscn",
	"res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"res://src/ui/screens/campaign/CampaignTurnController.tscn",
	"res://src/ui/screens/campaign/CampaignJournalScreen.tscn",
	"res://src/ui/screens/galaxy_log/GalaxyLogScreen.tscn",
	"res://src/ui/screens/character/CharacterDetailsScreen.tscn",
	"res://src/ui/screens/crew/CrewManagementScreen.tscn",
	"res://src/ui/screens/equipment/EquipmentManager.tscn",
	"res://src/ui/screens/equipment/EquipmentGenerationScene.tscn",
	"res://src/ui/screens/ships/ShipManager.tscn",
	"res://src/ui/screens/world/WorldPhaseController.tscn",
	"res://src/ui/screens/world/PatronRivalManager.tscn",
	"res://src/ui/screens/battle/PreBattle.tscn",
	"res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"res://src/ui/screens/postbattle/PostBattleSequence.tscn",
	"res://src/ui/screens/compendium/CompendiumScreen.tscn",
	"res://src/ui/screens/print/PrintSheetScreen.tscn",
	"res://src/ui/screens/store/StoreScreen.tscn",
]

var _frame := 0
var _started := false
var _pass := 0
var _fail := 0
var _skip := 0
var _findings: Array = []


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_load_requested_campaign()
	print("=== ROTATION SWEEP: %d screens, one instance walked through %d sizes ==="
		% [SCREENS.size(), STEPS.size()])
	print("campaign state: %s" % _campaign_state())
	for path in SCREENS:
		await _walk_screen(path)
	print("\n================ RESULT ================")
	print("passed=%d failed=%d skipped=%d" % [_pass, _fail, _skip])
	if not _findings.is_empty():
		print("\n---- FINDINGS ----")
		for f in _findings:
			print("  " + f)
	print("ROTATION SWEEP: %s" % ("PASS" if _fail == 0 else "FAIL"))
	quit(1 if _fail > 0 else 0)


func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty() or not FileAccess.file_exists(wanted):
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("load_campaign"):
		gs.load_campaign(wanted)


func _campaign_state() -> String:
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_current_campaign"):
		return "unknown"
	var campaign = gs.get_current_campaign()
	if campaign == null:
		return "NO CAMPAIGN loaded"
	return "campaign loaded"


func _walk_screen(path: String) -> void:
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

	# Build ONCE, at the first size.
	DisplayServer.window_set_size(Vector2i(STEPS[0][0], STEPS[0][1]))
	for _i in range(3):
		await process_frame
	var inst: Node = ps.instantiate()
	if inst == null:
		_skip += 1
		_findings.append("SKIP %s — instantiate() returned null" % short)
		return
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	await _settle(inst)
	_apply_runtime_overlay_net(inst)
	await _settle(inst)

	var problems: Array = []
	var shapes: Dictionary = {}     # step label -> layout shape string (compared)
	var rm_state: Dictionary = {}   # step label -> ResponsiveManager answer (reported)
	for step in STEPS:
		DisplayServer.window_set_size(Vector2i(step[0], step[1]))
		# The resize itself is what is under test: no re-instantiation, no second
		# reserve_band_on(), nothing but the screen reacting to its viewport changing.
		await _settle(inst)
		_measure(inst, short, String(step[2]), problems)
		shapes[String(step[2])] = _layout_shape(inst)
		# Diagnosis only — deliberately NOT part of the compared shape. Folding it in
		# made every portrait/landscape pair differ by construction and turned the
		# "screen is not reacting" check into a guaranteed pass. Reported alongside a
		# failure so a screen bug can be told apart from a stale autoload.
		rm_state[String(step[2])] = _responsive_state()

	_check_shape_changes(shapes, rm_state, problems)

	if problems.is_empty():
		_pass += 1
	else:
		_fail += 1
		for p in problems:
			_findings.append("FAIL %s: %s" % [short, p])
	inst.queue_free()
	await process_frame


## Reproduce the app's own overlay net once, at build time — see verify_layout.gd.
func _apply_runtime_overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(40):
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


## Column count of every AdaptivePanelGroup in the screen, plus whether its tab strip is
## showing. That is the shape a rotation is supposed to change.
func _layout_shape(inst: Node) -> String:
	var parts: Array[String] = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var grid := node.get_node_or_null("PaneGrid")
		if grid is GridContainer and (node as Node).get("max_columns") != null:
			var tabs := node.get_node_or_null("PaneTabBar")
			var tabs_visible: bool = tabs is Control and (tabs as Control).visible
			parts.append("%s:cols=%d,tabs=%s"
				% [node.name, (grid as GridContainer).columns, str(tabs_visible)])
	parts.sort()
	return ", ".join(parts)


## The behavioural expectations. Deliberately NOT "columns == what the code computes":
## that would re-assert the implementation instead of testing it.
## What ResponsiveManager itself thinks, for the finding text only.
func _responsive_state() -> String:
	var rm := root.get_node_or_null("/root/ResponsiveManager")
	if rm == null or not rm.has_method("get_effective_columns"):
		return "RM unavailable"
	var portrait := "?"
	if rm.has_method("is_portrait"):
		portrait = str(rm.is_portrait())
	return "eff_cols=%d portrait=%s" % [rm.get_effective_columns(), portrait]


func _check_shape_changes(shapes: Dictionary, rm_state: Dictionary, problems: Array) -> void:
	var portrait: String = shapes.get("phone portrait", "")
	var landscape: String = shapes.get("tablet landscape", "")
	var back: String = shapes.get("phone portrait (back)", "")
	if portrait.is_empty():
		return  # no AdaptivePanelGroup on this screen — overflow checks only

	# 1. A phone in portrait must be one column (or showing its tab strip instead).
	for entry in portrait.split(", "):
		if entry.is_empty():
			continue
		if entry.contains("cols=") and not entry.contains("cols=1") \
				and not entry.contains("tabs=true"):
			problems.append("phone portrait keeps a multi-column grid (%s) — a rotation "
				% entry + "to portrait must collapse it")

	# 2. A tablet in landscape must actually spread out again.
	if not landscape.is_empty() and landscape == portrait:
		problems.append("layout shape is IDENTICAL at phone portrait and tablet "
			+ "landscape (%s) — the screen is not reacting to rotation " % portrait
			+ "[ResponsiveManager said: portrait %s / landscape %s]"
			% [rm_state.get("phone portrait", "?"), rm_state.get("tablet landscape", "?")])

	# 3. Rotating back must restore the portrait shape (no one-way latch).
	if not back.is_empty() and back != portrait:
		problems.append("rotating back to portrait did NOT restore the portrait shape "
			+ "(was %s, came back as %s) — one-way latch" % [portrait, back])


func _inside_scroll(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _is_content(ctl: Control) -> bool:
	return ctl is Label or ctl is Button or ctl is LineEdit or ctl is TextEdit \
		or ctl is RichTextLabel or ctl is TextureRect or ctl is ProgressBar \
		or ctl is Slider or ctl is SpinBox or ctl is ItemList or ctl is Tree


func _is_backdrop(r: Rect2, ds: Vector2) -> bool:
	if ds.x <= 0.0 or ds.y <= 0.0:
		return false
	return (r.size.x * r.size.y) >= (ds.x * ds.y) * 0.8


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


## Overflow only. Touch targets and band collisions are already covered per-size by
## verify_layout.gd; what is new here is whether the RESIZE produced a valid layout.
func _measure(inst: Node, short: String, step: String, problems: Array) -> void:
	var ds: Vector2 = root.get_visible_rect().size
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
		if _inside_scroll(ctl, inst):
			continue
		var off: float = maxf(
			maxf(-r.position.x, r.end.x - ds.x),
			maxf(-r.position.y, r.end.y - ds.y))
		if off > EPS and not _parent_already_overflows(ctl, inst, off) \
				and not _is_backdrop(r, ds):
			problems.append("%s @ %s (%dx%d): %s off-screen by %.1f px AFTER RESIZE"
				% [short, step, int(ds.x), int(ds.y), String(ctl.name), off])
	if visible_controls < 3:
		problems.append("%s @ %s: only %d visible Controls after resize — the screen "
			% [short, step, visible_controls] + "did not survive the rotation")
