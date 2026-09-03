extends GdUnitTestSuite
## The battle Cheat Sheet must print the BOOK, not a paraphrase of it.
## Sep 2026 page walk.
##
## THE DEFECT THIS PINS. Every Compendium section of `CheatSheetPanel` was a
## hand-written string literal, and four of them printed rules that appear in
## NEITHER rulebook. Diffed against the PDFs:
##
##   Casualty tables   a D6 "1 Instantly Killed / 2 Dead / 3 Permanent Injury /
##                     4 Serious Wound / 5 Minor Wound / 6 Lucky Escape" table
##                     and a 2D6 "Lost Limb / Head Trauma / Nerve Damage ..."
##                     injury table. Neither exists. The real pp.99-100 tables
##                     are three D6 tables with regular/boss COLUMNS; p.102 is a
##                     D100 of twelve rows. Both were cited to "p.86" and "p.87",
##                     which hold neither.
##   Salvage           a "1-3 units = 2 cr | 4-6 = 5 cr | 7-10 = 8 cr" conversion
##                     scale that does not exist — p.147's Scrapper is three Loot
##                     rolls at 1D6 units each, "treat a roll of a 1 as a 2" —
##                     plus a literal `pass` line in the player-facing text.
##   Street fights     "1-2 Civilian / 3-4 Armed thug / 5 Target! / 6 Trap!" at
##                     4 inches. p.125 is "1 Nothing / 2 Possible enemy / 3-5
##                     Enemy / 6 Ambush" at 4+Savvy inches.
##   Stealth           "+D6 reinforcements Round 2". p.122 is 2D6 EVERY round,
##                     one basic enemy per 6 rolled.
##
## This is the fourth failure mode recorded in
## docs/COMPENDIUM_CHAPTER_TRACE_2026-08.md: the chapter is WIRED, and WRONG. A
## flag census, a caller census and a producer/consumer census all pass it,
## because the surface renders. And it is the worst place in the app to be wrong
## — a player consults this panel mid-battle.
##
## The fix is structural: every section renders from the same JSON the MECHANIC
## reads. These cases assert that structure, so a future literal fails here.
##
## gdUnit4 v6.0.3 compatible.

const Sections = preload("res://src/ui/components/battle/CheatSheetSections.gd")
const Toggles = preload("res://src/data/compendium_difficulty_toggles.gd")

const PANEL_SRC := "res://src/ui/components/battle/CheatSheetPanel.gd"

## Strings that were on the panel and are in NEITHER book. None may return.
const FABRICATIONS := [
	"Instantly Killed", "Lucky Escape", "Lost Limb", "Head Trauma",
	"Nerve Damage", "Torn Muscle", "Deep Laceration", "Cracked Ribs",
	"Adrenaline Rush", "1-3 units = 2 cr", "Armed thug",
	"D6 reinforcements Round 2", "1 square = 2",
]

## Compendium p.102, all twelve rows.
const INJURY_ROWS := [
	"Death", "Critical Strike", "Extensive Injury", "Item Hit",
	"Lingering Injury", "Injured Arm", "Injured Leg", "Injured Torso",
	"Serious Injury", "Minor Injury", "Knocked Out", "School of Hard Knocks",
]

var _saved_flags: Dictionary = {}
var _saved_owned: Dictionary = {}

const FLAGS := [
	"CASUALTY_TABLES", "DETAILED_INJURIES", "STEALTH_MISSIONS",
	"STREET_FIGHTS", "SALVAGE_JOBS", "NO_MINIS_COMBAT", "AI_VARIATIONS",
	"DIFFICULTY_TOGGLES",
]
const PACKS := ["freelancers_handbook", "fixers_guidebook"]


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_flags.clear()
	_saved_owned.clear()
	for pack in PACKS:
		_saved_owned[pack] = dlc.has_dlc(pack)
	for flag_name in FLAGS:
		_saved_flags[flag_name] = dlc.is_feature_enabled(dlc.ContentFlag.get(flag_name))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	for flag_name in _saved_flags:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), bool(_saved_flags[flag_name]))
	for pack in _saved_owned:
		dlc.set_dlc_owned(pack, bool(_saved_owned[pack]))


func _enable_all() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	for pack in PACKS:
		dlc.set_dlc_owned(pack, true)
	for flag_name in FLAGS:
		dlc.set_feature_enabled(dlc.ContentFlag.get(flag_name), true)
	return true


func _read_panel() -> String:
	var f := FileAccess.open(PANEL_SRC, FileAccess.READ)
	assert_object(f).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# ── No fabricated rule may survive anywhere on the panel ─────────────────

func test_no_fabricated_rule_remains_in_the_panel_source() -> void:
	var src: String = _read_panel()
	for phrase in FABRICATIONS:
		assert_bool(src.contains(phrase)).override_failure_message(
			"'%s' is back in CheatSheetPanel — that text is in NEITHER rulebook"
			% phrase).is_false()


func test_the_literal_builders_are_gone() -> void:
	# Structural, not textual: while a section is a literal it can drift from the
	# mechanic again, which is exactly how these four survived a chapter audit
	# that checked call sites.
	var src: String = _read_panel()
	for fn in ["_casualty_tables_text", "_salvage_rules_text",
			"_street_fight_rules_text", "_stealth_rules_text",
			"_difficulty_toggles_text", "_no_minis_text"]:
		assert_bool(src.contains("func %s(" % fn)).override_failure_message(
			"%s() is back as a hand-written literal; add a builder to"
			% fn + " CheatSheetSections instead"
		).is_false()
	assert_str(src).contains("CheatSheetSectionsRef")


# ── Casualties and injuries, pp.99-102 ───────────────────────────────────

func test_the_casualty_section_prints_the_real_three_tables() -> void:
	if not _enable_all():
		return
	var text: String = Sections.casualty_tables()
	assert_str(text).is_not_empty()
	for outcome in ["Dazed", "Wounded", "Goner", "Temporary Shutdown",
			"Damaged", "Knock down / Drive off", "Bleeding"]:
		assert_str(text).override_failure_message(
			"'%s' is missing; the section is not rendering the real p.99-100"
			% outcome + " tables").contains(outcome)


func test_the_casualty_section_states_the_boss_column() -> void:
	# The single clearest proof it is reading the DATA: the boss column is what
	# makes a captain harder to kill, and the fabricated table had no columns at
	# all.
	if not _enable_all():
		return
	var text: String = Sections.casualty_tables()
	assert_str(text).contains("BOSS")
	# p.99: "ONLY the single highest result from the casualty rolls is applied."
	assert_str(text).override_failure_message(
		"the multiple-hits rule is missing, and it changes every burst weapon"
	).contains("highest result")


func test_the_injury_section_prints_all_twelve_book_rows() -> void:
	if not _enable_all():
		return
	var text: String = Sections.detailed_injuries()
	assert_str(text).is_not_empty()
	for row_name in INJURY_ROWS:
		assert_str(text).override_failure_message(
			"p.102 row '%s' is missing from the reference" % row_name
		).contains(row_name)


func test_the_injury_section_says_the_table_replaces_the_core_one() -> void:
	# p.101: the table "can be used IN PLACE of the one in the core rules", and
	# bots stay on the p.122 Bot table. A player rolling both would double-injure
	# every casualty.
	if not _enable_all():
		return
	var text: String = Sections.detailed_injuries()
	assert_str(text).contains("IN PLACE")
	assert_str(text).contains("Bot")


# ── Stealth, street fights, salvage ──────────────────────────────────────

func test_the_stealth_section_states_the_real_reinforcement_rate() -> void:
	# p.122: "At the beginning of each battle round, roll 2D6. For each die
	# showing a 6, a basic enemy arrives." The literal said "+D6 reinforcements
	# Round 2", which is neither the rate nor the timing.
	if not _enable_all():
		return
	var text: String = Sections.stealth_missions()
	assert_str(text).is_not_empty()
	assert_str(text).override_failure_message(
		"the stealth reinforcement rate is not the book's 2D6-per-round"
	).contains("2D6")


func test_the_street_fight_suspect_table_is_the_book_one() -> void:
	# p.125: 1 Nothing / 2 Possible enemy / 3-5 Enemy / 6 Ambush, identified at
	# 4+Savvy inches. The literal had a different table at a fixed 4 inches.
	if not _enable_all():
		return
	var text: String = Sections.street_fights()
	assert_str(text).is_not_empty()
	assert_str(text).contains("Ambush")
	assert_str(text).override_failure_message(
		"identification range must be 4+Savvy inches, not a flat 4"
	).contains("4+Savvy")


func test_the_salvage_section_describes_the_scrapper_not_a_price_list() -> void:
	# p.147: three Loot rolls, 1D6 units each, "treat a roll of a 1 as a 2", and
	# 1 unit = 1 Credit for ship repairs, ship modules and bot upgrades ONLY.
	if not _enable_all():
		return
	var text: String = Sections.salvage_jobs()
	assert_str(text).is_not_empty()
	assert_str(text).contains("SCRAPPERS")
	assert_str(text).override_failure_message(
		"the three purchases Salvage may pay for are the whole point of the"
		+ " currency and must be stated"
	).contains("ship repairs")
	assert_bool(text.contains("1-3 units = 2 cr")).override_failure_message(
		"the invented conversion scale is back"
	).is_false()


# ── The toggle and AI sections are complete and honest ───────────────────

func test_all_twelve_difficulty_toggles_are_listed() -> void:
	# The literal listed eight and dropped Better Leadership's second bullet, so
	# a player could not tell which switches they had on.
	if not _enable_all():
		return
	var text: String = Sections.difficulty_toggles()
	assert_str(text).is_not_empty()
	var listed: int = 0
	for toggle in Toggles.DIFFICULTY_TOGGLES:
		if toggle is Dictionary and text.contains(str(toggle.get("name", ""))):
			listed += 1
	assert_int(listed).override_failure_message(
		"only %d of %d toggles reach the reference" % [
			listed, Toggles.DIFFICULTY_TOGGLES.size()]
	).is_equal(Toggles.DIFFICULTY_TOGGLES.size())


func test_the_ai_section_is_silent_without_the_option() -> void:
	# The core AI is DICELESS (Core Rules p.42). Printing the Compendium tables to
	# a player who does not own them is the original defect of this sweep.
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("AI_VARIATIONS"), false)
	assert_str(Sections.ai_variations()).override_failure_message(
		"the AI Variations tables were offered with the option OFF"
	).is_empty()


func test_the_ai_section_prints_the_tables_when_enabled() -> void:
	if not _enable_all():
		return
	var text: String = Sections.ai_variations()
	assert_str(text).is_not_empty()
	# The dice are the whole content of the option.
	assert_str(text).contains("1D6")
	# One real action row, so the section renders the TABLE and not just a header.
	assert_str(text).override_failure_message(
		"no action rows reached the reference: %s" % text.substr(0, 300)
	).contains("Dash towards the nearest enemy")
	# p.42: Beast, Rampage and Guardian are explicitly unchanged, and saying so is
	# what stops a player looking for a table that does not exist.
	assert_str(text).contains("Beast")


# ── An empty section is never rendered ───────────────────────────────────

func test_a_section_with_no_data_is_omitted_rather_than_blank() -> void:
	# An empty box reads as a feature that failed. The panel drops it instead.
	assert_str(_read_panel()).contains("func _add_built_section(")
	assert_str(_read_panel()).contains("if content.strip_edges().is_empty():")


# ── Core page cites ──────────────────────────────────────────────────────

func test_the_core_sections_cite_the_right_pages() -> void:
	# The turn sequence was cited to "p.38" (it is pp.112-113), Hit Rules to
	# "p.40-43" (p.44), Damage to "p.43-44" (p.46), Status Effects to "p.44"
	# (p.40) and the weapon table to "p.45-47" (p.50). A wrong cite sends a
	# player to the wrong page mid-game.
	var src: String = _read_panel()
	for wrong in ['Turn Sequence (p.38)', 'Hit Rules (p.40-43)',
			'Damage & Armor (p.43-44)', 'Status Effects (p.44)',
			'Common Weapons (p.45-47)']:
		assert_bool(src.contains(wrong)).override_failure_message(
			"stale page cite '%s' is back" % wrong).is_false()
	assert_str(src).contains("Turn Sequence (pp.112-113)")
	assert_str(src).contains("Common Weapons (p.50)")


# ── The panel must COMPILE, not merely contain the right words ───────────

func test_the_panel_script_actually_compiles_and_can_be_instantiated() -> void:
	# ⚠ EVERY OTHER CASE IN THIS SUITE READS THE PANEL AS TEXT (`_read_panel()`
	# via FileAccess). Text is blind to whether the file PARSES — and on Sep 3
	# 2026 it did not. A `const ... = preload(...)` line was inserted into the
	# middle of an existing two-line `preload(` continuation:
	#
	#     const CompendiumGridMovementRef = preload(
	#     const CheatSheetSectionsRef = preload(".../CheatSheetSections.gd")
	#         "res://src/data/compendium_grid_movement.gd")
	#
	# Every content case above still passed — the strings were all present, just
	# in a file the engine could not load. The real cost was upstream:
	# `TacticalBattleUI._instance_log_only_components()` calls
	# `_get_res("cheat_sheet").new()`, which failed with "Nonexistent function
	# 'new' in base 'GDScript'" and ABORTED `_setup_ui()` — so the live battle
	# screen stopped building partway through. Only
	# `tests/unit/test_tactical_battle_responsive.gd`, which instantiates the real
	# scene, noticed.
	#
	# ⚠ A PLAIN `load()` NULL-CHECK DOES NOT DETECT THIS, and that is the whole
	# trap. It serves the resource CACHE, and a parse-broken GDScript still comes
	# back as a NON-NULL object anyway — which is exactly why the original failure
	# read "Nonexistent function 'new'" instead of a null dereference.
	# CACHE_MODE_IGNORE forces a real parse from disk and returns null on failure.
	var scr: Resource = ResourceLoader.load(
		PANEL_SRC, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	assert_that(scr).override_failure_message(
		"CheatSheetPanel.gd does not PARSE. Every text-scan case above can still"
		+ " pass in this state while the battle screen fails to build."
	).is_not_null()

	var gd := scr as GDScript
	assert_that(gd).is_not_null()
	assert_bool(gd.can_instantiate()).override_failure_message(
		"CheatSheetPanel.gd parses but cannot be instantiated;"
		+ " TacticalBattleUI._instance_log_only_components() calls .new() on it"
	).is_true()
	# Mirror the real call site rather than trusting the flag above.
	var panel: Object = auto_free(gd.new())
	assert_that(panel).is_not_null()
