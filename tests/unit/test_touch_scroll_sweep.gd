extends GdUnitTestSuite
## §2 of the tablet checklist: "touch-scroll works in EVERY ScrollContainer".
##
## THE DEFECT SHAPE, measured on a Lenovo TB361FU across three QA passes (T4-01,
## T9-45, and deploy #26's Select Crew): a screen scrolls perfectly by dragging the
## thin scrollbar and does nothing at all when dragged in the middle. Every
## decorative surface — `PanelContainer`, `HSeparator`, `CheckBox`, `OptionButton`,
## `SpinBox`, `Button` — defaults to `MOUSE_FILTER_STOP`, and `Viewport::_gui_call_input`
## stops Mouse/ScreenDrag/ScreenTouch at the first STOP control. Only WHEEL events are
## excepted, which is exactly why the scrollbar worked, the desktop mouse wheel worked,
## and a finger did not.
##
## `TouchScrollOpener.open_subtree()` is the fix, and it was applied to **6** screens
## while `ScrollContainer` appears in **20 `.tscn` + 87 `.gd`** files. This sweep asks
## every screen the same question the device would.
##
## ⭐ **The measurement is `open_subtree()`'s RETURN VALUE, not a synthetic drag.** Its
## docblock states the contract: it "returns the number of controls opened, so a caller
## (or a test) can tell the difference between 'nothing needed opening' and 'the sweep
## never ran'." A non-zero count on a populated screen means a finger landing there
## would have died before reaching the scroll. That scales to every screen; driving 28
## real drags does not. `test_prebattle_responsive_layout.gd` keeps the real-gesture
## proof for the flagship screen.
##
## ⚠ **An EMPTY screen reports zero and looks clean** — the T11-01 false green, where
## the layout sweep was green for a month because it measured four empty panes. So this
## suite runs the same `ScreenPopulator` the layout sweep uses, and every report line
## carries the screen's node count: a screen that built nothing is visibly empty in the
## output rather than silently passing.

const OpenerCls = preload("res://src/ui/components/common/TouchScrollOpener.gd")
const PopulatorCls = preload("res://tests/tools/screen_populator.gd")

## ⚠ PIN THE CAMPAIGN CONTEXT, do not inherit it.
##
## This suite builds 27 REAL screens, most of them 5PFH-only, against whatever
## GameState.current_campaign holds — and GameState auto-loads `last_campaign` at
## boot (GameState.gd:112/:150), gating only on that key being non-empty. Any suite
## that saves a campaign sets it, so running the Tactics suites leaves a TACTICS
## core loaded for every process that starts afterwards, and 5PFH screens abort
## against it: `Nonexistent function 'get_crew_members' in base
## 'Resource (TacticsCampaignCore)'`, which unwinds the screen's _ready().
##
## ⭐ MEASURED: this suite passed standalone (4/4) and FAILED in two consecutive full
## runs, with a cause three suites away from anything it tests. The PASSING runs were
## the misleading ones. Same family as the documented `user://window.ini` bleed — a
## test that measures a real screen must pin its configuration, not inherit it.
##
## ⚠ IT CLEARS ONLY A NON-5PFH CORE, never unconditionally. This suite runs
## ScreenPopulator precisely so it does not repeat T11-01, where a layout sweep was
## green for a month because it measured four EMPTY panes. Dropping a legitimate
## 5PFH campaign would hand that false green straight back.
var _saved_campaign: Variant = null


func before_test() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	_saved_campaign = gs.current_campaign
	var c: Variant = gs.current_campaign
	# Only the three variant cores declare campaign_type; a 5PFH core has no such
	# field, which is the same discriminator MainMenu.gd:436-440 routes on.
	if c != null and "campaign_type" in c and str(c.campaign_type) != "five_parsecs":
		gs.current_campaign = null


func after_test() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign

## The tablet design space this project's device QA targets (2560x1600 physical).
const TABLET_DESIGN := Vector2i(2207, 1379)

## Drawn from `tests/tools/verify_layout.gd`'s SCREENS, which is the maintained list.
##
## ⚠ `PrintSheetScreen.tscn` is deliberately ABSENT. It builds a real `SheetRenderer`
## that loads and draws the sheet PNGs, so it needs a rendering device and crashes with
## signal 11 under `--headless` — the same reason `test_sheet_source_paths_resolve.gd`
## is the project's one NEEDS_DISPLAY suite. Including it would take the whole batch
## down and report as `cases=PARSE_FAIL` rather than a failure.
const SCREENS: Array[String] = [
	"res://src/ui/screens/mainmenu/MainMenu.tscn",
	"res://src/ui/screens/legal/EULAScreen.tscn",
	"res://src/ui/screens/legal/LegalTextViewer.tscn",
	"res://src/ui/screens/settings/SettingsScreen.tscn",
	"res://src/ui/help/HelpScreen.tscn",
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
	"res://src/ui/screens/world/PatronRivalManager.tscn",
	"res://src/ui/screens/battle/PreBattle.tscn",
	"res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"res://src/ui/screens/postbattle/PostBattleSequence.tscn",
	"res://src/ui/screens/utils/GameOverScreen.tscn",
	"res://src/ui/screens/battle_simulator/BattleSimulatorUI.tscn",
	"res://src/ui/screens/compendium/CompendiumScreen.tscn",
	"res://src/ui/screens/compendium/CompendiumCategoryView.tscn",
	"res://src/ui/screens/store/StoreScreen.tscn",
]


## Record `class @ path` for every STOP control the opener would rewrite, WITHOUT
## rewriting it. Mirrors TouchScrollOpener's own skip list so the two cannot disagree.
func _name_stops(root: Node, n: Node, out: Array[String]) -> void:
	for child in n.get_children():
		if child is Control:
			var c := child as Control
			var skip := false
			for cls: String in ["ScrollContainer", "Tree", "ItemList", "TextEdit",
					"RichTextLabel", "GraphEdit"]:
				if c.is_class(cls):
					skip = true
					break
			if not skip and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				out.append("%s @ %s" % [c.get_class(), str(root.get_path_to(c))])
		_name_stops(root, child, out)

func _count_nodes(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count_nodes(c)
	return total


func _collect_scrolls(n: Node, out: Array) -> void:
	if n is ScrollContainer:
		out.append(n)
	for c in n.get_children():
		_collect_scrolls(c, out)


## Build one screen the way its navigator would, then ask the opener how many STOP
## controls are sitting under its scrolls.
func _sweep(path: String) -> Dictionary:
	var row := {
		"path": path, "built": false, "nodes": 0,
		"scrolls": 0, "stop": 0, "note": "", "names": [] as Array[String],
	}
	if not ResourceLoader.exists(path):
		row["note"] = "scene missing"
		return row
	var packed := load(path) as PackedScene
	if packed == null:
		row["note"] = "not a PackedScene"
		return row

	var pop = PopulatorCls.new(self)
	pop.populate_pre(path)

	var sv := SubViewport.new()
	sv.size = TABLET_DESIGN
	add_child(sv)
	auto_free(sv)

	var inst := packed.instantiate()
	if inst == null:
		row["note"] = "instantiate returned null"
		return row
	sv.add_child(inst)
	pop.populate_post(inst, path)

	# Containers re-sort deferred and several screens open their touch chain one
	# frame late, so a count taken now would read a tree that is still settling.
	for _i in range(8):
		await get_tree().process_frame

	row["built"] = true
	row["nodes"] = _count_nodes(inst)
	var scrolls: Array = []
	_collect_scrolls(inst, scrolls)
	row["scrolls"] = scrolls.size()
	# NAME the offenders before opening them. A bare count says "6 controls are
	# closed" and leaves the next reader guessing which — three guesses were spent
	# that way. The paths point straight at the owner that needs the sweep.
	var names: Array[String] = []
	for s: ScrollContainer in scrolls:
		_name_stops(inst, s, names)
	var stop := 0
	for s: ScrollContainer in scrolls:
		# open_subtree FIXES as it counts, so this instance is mutated — which is
		# fine, it is thrown away, and each screen gets a fresh one.
		stop += OpenerCls.open_subtree(s)
	row["stop"] = stop
	row["names"] = names
	return row


func test_the_opener_can_actually_detect_a_swallowing_control() -> void:
	# The premise. Every "0 STOP controls" result below is meaningless unless the
	# opener is capable of returning non-zero, so build the defect deliberately.
	var scroll := ScrollContainer.new()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var check := CheckBox.new()
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(check)
	scroll.add_child(panel)
	add_child(scroll)
	auto_free(scroll)

	assert_int(OpenerCls.open_subtree(scroll)).override_failure_message(
		"the opener failed to detect two deliberately STOP-filtered controls, so every "
		+ "zero this suite reports would be meaningless").is_equal(2)
	# ...and it is idempotent, so a second pass over a fixed tree reports clean.
	assert_int(OpenerCls.open_subtree(scroll)).is_equal(0)


func test_no_screen_swallows_a_touch_drag_over_its_scrollable_content() -> void:
	var offenders: Array[String] = []
	var report: Array[String] = []
	var built := 0

	for path: String in SCREENS:
		var row: Dictionary = await _sweep(path)
		var name := str(row["path"]).get_file()
		if not row["built"]:
			report.append("  %-42s SKIP (%s)" % [name, row["note"]])
			continue
		built += 1
		report.append("  %-42s nodes=%-5d scrolls=%-2d STOP-under-scroll=%d" % [
			name, row["nodes"], row["scrolls"], row["stop"]])
		if int(row["stop"]) > 0:
			offenders.append("%s (%d)" % [name, row["stop"]])
			for nm: String in row["names"]:
				report.append("      ! " + nm)

	print("\n--- touch-scroll sweep @ %dx%d ---" % [TABLET_DESIGN.x, TABLET_DESIGN.y])
	for line: String in report:
		print(line)
	print("--- %d/%d screens built ---\n" % [built, SCREENS.size()])

	# A sweep that built almost nothing would report almost no offenders and read as
	# a clean bill of health — the same false green that kept T11-01 hidden.
	assert_int(built).override_failure_message(
		"only %d of %d screens instantiated, so this run cannot support any conclusion"
		% [built, SCREENS.size()]).is_greater(20)

	assert_array(offenders).override_failure_message(
		"these screens leave STOP-filtered controls under a ScrollContainer, so a finger "
		+ "drag over their content dies before reaching the scroll (the scrollbar and "
		+ "the desktop wheel would still work, which is why this survives desk QA): %s"
		% str(offenders)).is_empty()
