extends SceneTree

## Deploy #21 desk pass — assert the data-present findings against the REAL device
## save, before spending hardware time on them.
##
## ── WHY A PULLED SAVE AND NOT A FIXTURE ─────────────────────────────────────
## T11-22/24/30/32/33/34 are FORMATTER fixes. Their inputs already exist on the
## tablet in exactly the shape that broke, produced by real play:
##
##   ship.hull_points        35.0  (float)               -> T11-30
##   characters_involved     ["char_498964_9495", ...]   -> T11-32
##   casualties              0 (turn 9) AND 0.0 (turn 1) -> T11-33, BOTH arms
##   enemy_category          "interested_parties"        -> T11-34
##   notable_sight           "DOCUMENTATION"             -> T11-34
##   enemy_type              "Salvage Team", count 6     -> T11-24
##
## A hand-authored journal entry would be WORSE than useless. `create_entry()` passes
## `stats` through wholesale (CampaignJournal.gd:88), so a fabricated entry survives
## the chokepoint intact and prints perfectly — proving the renderer works while
## bypassing `auto_create_battle_entry()` (:234-296), the producer T11-24 exists to
## test. This project has already validated a shape the app cannot produce three
## times over. Load the save the device wrote.
##
## ── WHY IT GOES THROUGH THE SCREEN'S OWN FETCHES ────────────────────────────
## Mirrors PrintSheetScreen._build_data_context() (:279-307) line for line. BOTH
## device-only sheet defects lived in those three fetch lines and not in build(),
## because every existing test passes a/b/c straight in
## (reference_test_the_screen_not_just_the_builder).
##
## ── AND WHY IT ASSERTS CALL SITES, NOT JUST THE HELPER ──────────────────────
## T11-33/34 are one class fixed by ONE shared helper, which is exactly the shape
## where "the helper was never the missing piece — the CALL was" (T11-05). A probe
## that only exercises DisplayText.number() would pass with every screen still
## printing raw. So each surface is asserted through the transform IT actually
## applies, read out of its own source.
##
##   Godot_console.exe --headless --path <project> \
##       --script tests/tools/probe_deploy21_data.gd
##
## Headless is correct: nothing renders. The PNG geometry row (T11-22) needs a
## framebuffer and is a separate windowed probe.

const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")
const DisplayTextScript = preload("res://src/ui/components/common/DisplayText.gd")
const JournalScreenScript = preload("res://src/ui/screens/campaign/CampaignJournalScreen.gd")

const SAVE_PATH := "user://saves/tablet_qa_run_1786210201.save"

## Book-sourced expectations: data/enemy_types.json, category "Interested Parties",
## enemy "Salvage Team" — the row the device's last battle actually fought.
## Core Rules p.94 prints Speed with the inch mark and Combat Skill as a SIGNED
## modifier, so "+0" is a real value and emptiness is tested on the RECORD, never
## on the number.
const EXPECT_ENEMY := {
	"enemy_type": "Salvage Team",
	"enemy_panic": "1-3",
	"enemy_speed": '4"',
	"enemy_combat": "+0",
	"enemy_toughness": "4",
	"enemy_ai": "C",
}

var _pass: int = 0
var _fail: int = 0


func _initialize() -> void:
	_run()


func _eq(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		_pass += 1
		print("  PASS  %-38s = %s" % [label, str(got)])
	else:
		_fail += 1
		print("  FAIL  %-38s = %s   (expected %s)" % [label, str(got), str(want)])


func _true(label: String, good: bool, detail: String) -> void:
	if good:
		_pass += 1
		print("  PASS  %-38s %s" % [label, detail])
	else:
		_fail += 1
		print("  FAIL  %-38s %s" % [label, detail])


func _run() -> void:
	await process_frame

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		print("ABORT: no /root/GameState — autoloads absent in this run mode")
		quit(2)
		return

	print("=== load the pulled device save through GameState ===")
	var res: Dictionary = gs.load_campaign(SAVE_PATH)
	if not bool(res.get("success", false)) or gs.get("current_campaign") == null:
		print("ABORT: %s" % str(res.get("message", "load produced nothing")))
		quit(2)
		return
	await process_frame

	# The screen's three fetches, verbatim (PrintSheetScreen.gd:286-305).
	var campaign: Object = gs.get("current_campaign")
	var world: Variant = null
	var pdm: Node = root.get_node_or_null("/root/PlanetDataManager")
	if pdm and pdm.has_method("get_current_planet"):
		world = pdm.get_current_planet()
	var entries: Array = []
	var journal: Node = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("get_all_entries"):
		entries = journal.get_all_entries()

	print("  campaign : %s" % str(campaign.get("campaign_name")))
	print("  world    : %s" % ("<null>" if world == null else str(world)))
	_true("journal reached the builder", entries.size() > 0,
		"%d entries (0 = the get_all_entries fetch regressed)" % entries.size())

	var ctx: Dictionary = SheetDataContextScript.build(campaign, world, entries)
	var lb: Dictionary = ctx.get("journal", {}).get("last_battle", {})

	print("")
	print("=== T11-24  Encounter Log enemy row (data/enemy_types.json) ===")
	for key: String in EXPECT_ENEMY:
		_eq("sheet last_battle.%s" % key, lb.get(key, "<missing>"), EXPECT_ENEMY[key])
	_eq("sheet last_battle.enemy_count", lb.get("enemy_count", "<missing>"), 6)

	print("")
	print("=== T11-23 / T11-34  the SHEET's transforms ===")
	_eq("sheet encounter_type", lb.get("encounter_type", "<missing>"),
		"Interested Parties")
	_true("sheet notable_sight is prettified",
		str(lb.get("notable_sight", "")).begins_with("Documentation"),
		"-> '%s'" % str(lb.get("notable_sight", "")))

	print("")
	print("=== T11-34  the JOURNAL SCREEN's transform, on the same two values ===")
	# CampaignJournalScreen.gd:904-909 renders EVERY stat value through
	# DisplayText.number(). That fixes the numbers and does nothing to a String,
	# so this is where the journal half of T11-34 either holds or does not.
	var raw_stats: Dictionary = _last_battle_stats(entries)
	print("  raw stats in the save: enemy_category=%s  notable_sight=%s" % [
		str(raw_stats.get("enemy_category", "<absent>")),
		str(raw_stats.get("notable_sight", "<absent>"))])
	var j_cat: String = DisplayTextScript.stat_value(raw_stats.get("enemy_category", ""))
	var j_sight: String = DisplayTextScript.stat_value(raw_stats.get("notable_sight", ""))
	_eq("journal renders Enemy category", j_cat, "Interested Parties")
	_eq("journal renders Notable sight", j_sight, "Documentation")
	# Values that OWN their spelling must survive the same generic pass.
	for keep: String in ["enemy_type", "objective", "deployment_condition",
			"notable_sight_effect"]:
		if raw_stats.has(keep):
			_eq("journal leaves %s alone" % keep,
				DisplayTextScript.stat_value(raw_stats[keep]), str(raw_stats[keep]))
	# ⚠ Everything above exercises the HELPER. The helper was never the missing
	# piece on this class of defect — the CALL was (T11-05), and the pre-fix code
	# called number() here, which is why the numbers were right and the strings
	# were not. So assert the WIRING too, or a revert of the call site leaves this
	# probe green and proves nothing.
	#
	# The preload of JournalScreenScript already proves the file still PARSES (a
	# text scan alone cannot — CheatSheetPanel, PatronRivalManager); this adds the
	# one thing a load cannot tell us, which is where the stats block routes.
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignJournalScreen.gd")
	_true("journal stats block calls stat_value",
		src.contains("DisplayTextRef.stat_value(stats[k])"),
		"(pre-fix this line read DisplayTextRef.number(stats[k]))")
	_true("sheet sight label shares the transform",
		FileAccess.get_file_as_string("res://src/core/export/SheetDataContext.gd") \
			.contains("DisplayTextRef.sentence_case(raw)"),
		"(so the two surfaces cannot drift apart again)")

	print("")
	print("=== T11-33  whole floats must not print .0 (both arms present in save) ===")
	for probe: Variant in [0, 0.0, 6, 6.0, 12.0, 1.5, 2.5]:
		var out: String = DisplayTextScript.number(probe)
		_true("DisplayText.number(%s)" % str(probe), not out.ends_with(".0"),
			"-> '%s'" % out)
	for e: Variant in entries:
		if e is Dictionary and str((e as Dictionary).get("type", "")) == "battle":
			var st: Dictionary = (e as Dictionary).get("stats", {})
			for k: String in ["casualties", "enemy_count", "xp_gained", "loot_earned"]:
				if st.has(k):
					var s: String = DisplayTextScript.number(st[k])
					_true("turn %s stats.%s" % [str(e.get("turn_number")), k],
						not s.ends_with(".0"), "-> '%s'" % s)

	print("")
	print("=== T11-32  journal crew identity: names, never char_ ids ===")
	# The finding is on the JOURNAL, whose ids live in characters_involved — not
	# on the sheet's crew array, which is a different surface with a different
	# producer. _crew_name_for_id() routes through Engine.get_main_loop().root
	# precisely so it can be exercised detached (its own docblock says so).
	var journal_screen: Object = JournalScreenScript.new()
	var ids: Array = _last_battle_ids(entries)
	print("  characters_involved in the save: %d ids" % ids.size())
	var unresolved: int = 0
	for cid: Variant in ids:
		var shown: String = journal_screen.call("_crew_name_for_id", str(cid))
		if shown == str(cid) or shown.begins_with("char_"):
			unresolved += 1
			print("      %s -> %s   UNRESOLVED" % [str(cid), shown])
		else:
			print("      %s -> %s" % [str(cid), shown])
	_true("every journal id resolves to a name", unresolved == 0 and ids.size() > 0,
		"%d of %d unresolved" % [unresolved, ids.size()])
	journal_screen.free()

	print("")
	print("=== T11-30  ship: the raw float, and the two display sites ===")
	var sd: Variant = campaign.get("ship_data")
	var raw_hull: Variant = (sd as Dictionary).get("max_hull") if sd is Dictionary else null
	print("  raw max_hull in the save: %s (%s)" % [str(raw_hull), type_string(typeof(raw_hull))])
	_true("DisplayText.number(max_hull) is clean",
		not DisplayTextScript.number(raw_hull).ends_with(".0"),
		"-> '%s'" % DisplayTextScript.number(raw_hull))
	_eq("pluralize(1, credit)", DisplayTextScript.pluralize(1, "credit"), "1 credit")
	_eq("pluralize(6, credit)", DisplayTextScript.pluralize(6, "credit"), "6 credits")

	print("")
	print("======================================================")
	print("  deploy #21 desk data probe:  %d pass, %d FAIL" % [_pass, _fail])
	print("======================================================")
	quit(0 if _fail == 0 else 1)


func _last_battle_ids(entries: Array) -> Array:
	for i in range(entries.size() - 1, -1, -1):
		var e: Variant = entries[i]
		if e is Dictionary and str((e as Dictionary).get("type", "")) == "battle":
			var ci: Variant = (e as Dictionary).get("characters_involved", [])
			return ci if ci is Array else []
	return []


func _last_battle_stats(entries: Array) -> Dictionary:
	for i in range(entries.size() - 1, -1, -1):
		var e: Variant = entries[i]
		if e is Dictionary and str((e as Dictionary).get("type", "")) == "battle":
			var st: Variant = (e as Dictionary).get("stats", {})
			return st if st is Dictionary else {}
	return {}
