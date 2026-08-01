extends SceneTree
## WINDOWED screen-capture harness. Instantiates each in-scope screen and saves a
## PNG of it at a device size, so a VISUAL consistency review can be done on real
## renders instead of on impressions.
##
## Run (NOTE: no --headless — headless has no renderer, every capture comes out blank):
##   godot --path <root> --script res://tests/tools/capture_screens.gd -- \
##       size=393x851 out=user://shots campaign=user://saves/x.save
##
## Optional: screens=CompendiumScreen,WorldPhaseController   (substring match on the
## scene file name) to capture a subset instead of the whole list.
##
## ── WHY A SEPARATE TOOL FROM verify_layout.gd ────────────────────────────────
## verify_layout measures GEOMETRY: does anything fall off the edge, does anything
## collide. It cannot see that two screens which both fit are drawn in two entirely
## different colour palettes. Consistency is a rendering property, so it needs a
## render. Same instantiation contract as the sweep (same screen list, same overlay
## net, same settle-until-stable) so the two tools agree about what a screen IS.
##
## Constraints inherited from verify_layout.gd — do not relax:
##  1. All work runs in _process() on frame >= 2, never _initialize(): under --script
##     the autoloads exist but root.is_inside_tree() is false during _initialize().
##  2. Nothing is preload()ed — production scripts reference bare autoload identifiers
##     which are not registered as globals when a --script main loop is compiled.

const SCREENS: Array = [
	"res://src/ui/screens/mainmenu/MainMenu.tscn",
	"res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"res://src/ui/screens/campaign/CampaignTurnController.tscn",
	"res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"res://src/ui/screens/campaign/CampaignEditorScreen.tscn",
	"res://src/ui/screens/campaign/CampaignJournalScreen.tscn",
	"res://src/ui/screens/world/WorldPhaseController.tscn",
	"res://src/ui/screens/world/PatronRivalManager.tscn",
	"res://src/ui/screens/crew/CrewManagementScreen.tscn",
	"res://src/ui/screens/character/CharacterDetailsScreen.tscn",
	"res://src/ui/screens/equipment/EquipmentManager.tscn",
	"res://src/ui/screens/equipment/EquipmentGenerationScene.tscn",
	"res://src/ui/screens/ships/ShipManager.tscn",
	"res://src/ui/screens/postbattle/PostBattleSequence.tscn",
	"res://src/ui/screens/galaxy_log/GalaxyLogScreen.tscn",
	"res://src/ui/screens/compendium/CompendiumScreen.tscn",
	"res://src/ui/screens/compendium/CompendiumCategoryView.tscn",
	"res://src/ui/screens/print/PrintSheetScreen.tscn",
	"res://src/ui/screens/settings/SettingsScreen.tscn",
	"res://src/ui/screens/store/StoreScreen.tscn",
	"res://src/ui/help/HelpScreen.tscn",
]

var _frame := 0
var _started := false
var _out_dir := "user://shots"
var _size := Vector2i(393, 851)
var _filter: Array = []
var _saved := 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_load_requested_campaign()
	DisplayServer.window_set_size(_size)
	for _i in range(4):
		await process_frame
	print("=== CAPTURE %dx%d -> %s ===" % [_size.x, _size.y, _out_dir])
	for path in SCREENS:
		if not _wanted(path):
			continue
		await _capture(path)
	print("saved %d screenshots to %s" % [_saved, ProjectSettings.globalize_path(_out_dir)])
	quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a.begins_with("out="):
			_out_dir = a.substr(4)
		elif a.begins_with("size="):
			var parts := a.substr(5).split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
		elif a.begins_with("screens="):
			for s in a.substr(8).split(","):
				if not String(s).strip_edges().is_empty():
					_filter.append(String(s).strip_edges())


func _wanted(path: String) -> bool:
	if _filter.is_empty():
		return true
	for f in _filter:
		if path.get_file().findn(String(f)) >= 0:
			return true
	return false


func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty():
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("load_campaign"):
		print("campaign requested but GameState unavailable: %s" % wanted)
		return
	if not FileAccess.file_exists(wanted):
		print("campaign requested but file missing: %s" % wanted)
		return
	gs.load_campaign(wanted)


func _capture(path: String) -> void:
	var short := path.get_file().get_basename()
	if not ResourceLoader.exists(path):
		print("  SKIP %s — missing" % short)
		return
	var ps: PackedScene = load(path)
	if ps == null:
		print("  SKIP %s — failed to load" % short)
		return
	# Re-assert the size for EVERY screen, not once at startup. Some screens touch
	# SettingsManager, which re-applies the stored window/UI-scale settings and resizes
	# the window out from under the run — a whole-list capture came back at 800x1280
	# after starting at 393x851, silently measuring a different device than requested.
	if DisplayServer.window_get_size() != _size:
		DisplayServer.window_set_size(_size)
		for _i in range(3):
			await process_frame
	var inst: Node = ps.instantiate()
	if inst == null:
		print("  SKIP %s — instantiate() returned null" % short)
		return
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	await _settle(inst)
	_apply_runtime_overlay_net(inst)
	await _settle(inst)

	# One more full draw so the frame on the GPU matches the settled tree, then read
	# the backbuffer. frame_post_draw is the documented point at which the viewport
	# texture holds the rendered frame.
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var file := "%s/%s.png" % [_out_dir, short]
	if img != null:
		img.save_png(file)
		_saved += 1
		print("  %s  (%dx%d)" % [short, img.get_width(), img.get_height()])
	else:
		print("  SKIP %s — viewport image was null" % short)
	inst.queue_free()
	await process_frame


## Same runtime net verify_layout applies: SceneRouter's scene_changed makes
## SettingsOverlay refresh and reserve its band on the incoming screen. Capturing
## without it would show a chrome band overlapping content that the app does not.
func _apply_runtime_overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


## Wait until geometry stops changing — panels populate from call_deferred and
## ScrollContainers re-sort after their content arrives, so an early capture shows a
## half-built screen.
func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(30):
		await process_frame
		var sig := _geometry_signature(inst)
		if sig == last:
			stable += 1
			if stable >= 3:
				break
		else:
			stable = 0
			last = sig
	await _settle_opacity(inst)


## Wait out an entrance fade before reading the backbuffer.
##
## _settle above watches GEOMETRY, and a fade-in changes only `modulate` — so a
## screen that animates its opacity settles instantly while still being invisible.
## MainMenu does exactly that (add_fade_in_animation: modulate.a 0 -> 1 over 0.5s),
## and the contact sheet showed its buttons as ghosts you could read the hero photo
## through. That is a capture artifact, and it very nearly got "fixed" in the app.
func _settle_opacity(inst: Node) -> void:
	var ctl := inst as CanvasItem
	if ctl == null:
		return
	# 0.5s of fade at 60fps is 30 frames; 45 leaves headroom without stalling a
	# 24-screen sweep on screens that do not animate at all (they exit on frame 1).
	for _i in range(45):
		if ctl.modulate.a >= 0.999 and ctl.self_modulate.a >= 0.999:
			return
		await process_frame


func _geometry_signature(inst: Node) -> String:
	var acc := 0.0
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).visible:
			var r: Rect2 = (n as Control).get_global_rect()
			acc += r.position.x + r.position.y + r.size.x * 3.0 + r.size.y * 7.0
		for c in n.get_children():
			stack.append(c)
	return "%.2f" % acc
