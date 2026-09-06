extends GdUnitTestSuite
## T11-24 — the Encounter Log's enemy stat columns.
##
## THE FINDING (device, deploy #19). The printed sheet has SEVEN columns in its enemy
## table and the manifest addressed only two of them, so Panic / Speed / Combat /
## Toughness / AI printed blank on every export. ⚠ This was filed as an ENHANCEMENT,
## not a defect: the manifest had no field entry for those columns at all, so blank
## was exactly what it asked for. Nearly filed as a null-resolution bug.
##
## COLUMN ORDER IS READ OFF THE ARTWORK. The captions on
## assets/sheets/core/encounter_log.png are:
##     Name/Type | Number | Panic | Speed | Combat | Toughness | AI
## The Appendix X PDF text layer interleaves this sheet with the crew log's weapon
## table and reads "...AI Number Speed / Shots Panic / Ramge Combat / Damage
## Toughness", i.e. it suggests a Number-Speed-Panic order the sheet does not have.
## That is the documented reason this project crops the PNG for anything positional.
##
## VALUES ARE BOOK-VERIFIED. Core Rules p.94, Criminal Elements table:
##     ROLL   ENEMY    NUMBERS  PANIC  SPEED  COMBAT SKILL  TOUGHNESS  AI
##     1-10   Gangers    +2      1-2    4"        +0            3       A
##     11-19  Punks      +3      1-3    4"        +0            3       A

const SheetDataContext := preload("res://src/core/export/SheetDataContext.gd")
const EnemyGeneratorScript := preload("res://src/core/systems/EnemyGenerator.gd")

const MANIFEST := "res://data/sheets/core/encounter_log_fields.json"


func _manifest() -> Dictionary:
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Dictionary


func _last_battle(enemy: String) -> Dictionary:
	return SheetDataContext._build_journal([
		{"type": "battle", "stats": {"enemy_type": enemy, "enemy_count": 5}},
	])["last_battle"]


func test_the_five_stat_columns_are_addressed_by_the_manifest() -> void:
	var ids: Array[String] = []
	for f_v in _manifest().get("fields", []):
		ids.append(str((f_v as Dictionary).get("id", "")))
	for wanted: String in [
		"enemy_panic_1", "enemy_speed_1", "enemy_combat_1",
		"enemy_toughness_1", "enemy_ai_1",
	]:
		assert_array(ids).override_failure_message(
			"%s is not in the manifest, so that printed column stays blank." % wanted
		).contains([wanted])


## The rects must sit between the artwork's own vertical separators, which were
## measured at x = 155, 541, 715, 889, 1063, 1237, 1411, 1763 across the enemy row.
## Asserting the boundaries rather than the exact rect keeps this a geometry test
## and not a transcription of the values it is checking.
func test_each_stat_column_sits_inside_its_printed_cell() -> void:
	var separators := [155, 541, 715, 889, 1063, 1237, 1411, 1763]
	var order := [
		"enemy_name_1", "enemy_number_1", "enemy_panic_1", "enemy_speed_1",
		"enemy_combat_1", "enemy_toughness_1", "enemy_ai_1",
	]
	var by_id: Dictionary = {}
	for f_v in _manifest().get("fields", []):
		by_id[str((f_v as Dictionary).get("id", ""))] = f_v

	for i in range(order.size()):
		var fid: String = order[i]
		assert_bool(by_id.has(fid)).is_true()
		var rect: Array = (by_id[fid] as Dictionary).get("rect", [])
		var x: int = int(rect[0])
		var right: int = x + int(rect[2])
		assert_int(x).override_failure_message(
			"%s starts at x=%d, left of its cell boundary %d." % [fid, x, separators[i]]
		).is_greater(separators[i])
		assert_int(right).override_failure_message(
			"%s ends at x=%d, past its cell boundary %d — it would print over the "
			% [fid, right, separators[i + 1]] + "neighbouring column."
		).is_less(separators[i + 1])


func test_a_known_enemy_prints_its_book_stat_line() -> void:
	var lb: Dictionary = _last_battle("Gangers")
	# Core Rules p.94: Gangers  +2  1-2  4"  +0  3  A
	assert_str(str(lb.get("enemy_panic", ""))).is_equal("1-2")
	assert_str(str(lb.get("enemy_speed", ""))).override_failure_message(
		"Speed must carry the inch mark the book prints."
	).is_equal("4\"")
	assert_str(str(lb.get("enemy_combat", ""))).override_failure_message(
		"Combat Skill is a SIGNED modifier in the book (+0), and 0 is a real value "
		+ "— a blank here would mean the emptiness test was run on the number."
	).is_equal("+0")
	assert_str(str(lb.get("enemy_toughness", ""))).is_equal("3")
	assert_str(str(lb.get("enemy_ai", ""))).is_equal("A")


func test_a_second_enemy_type_differs_from_the_first() -> void:
	# Enforcers: +0  1-2  4"  +1  4  T (p.94). Asserted so the lookup cannot be
	# passing by returning one hardcoded row.
	var lb: Dictionary = _last_battle("Enforcers")
	assert_str(str(lb.get("enemy_combat", ""))).is_equal("+1")
	assert_str(str(lb.get("enemy_toughness", ""))).is_equal("4")
	assert_str(str(lb.get("enemy_ai", ""))).is_equal("T")


## A Rival, a Unique Individual or a Bug Hunt swarm is not a row in that table.
## Blank is the correct output — a print form is meant to have empty boxes, and an
## invented stat line would be worse than nothing.
func test_an_enemy_outside_the_table_leaves_the_columns_blank() -> void:
	var lb: Dictionary = _last_battle("Some Rival Nobody Tabulated")
	for key: String in [
		"enemy_panic", "enemy_speed", "enemy_combat", "enemy_toughness", "enemy_ai",
	]:
		assert_str(str(lb.get(key, "x"))).override_failure_message(
			"%s was filled in for an enemy that has no row in enemy_types.json." % key
		).is_empty()


func test_no_battle_at_all_leaves_the_columns_blank() -> void:
	var lb: Dictionary = SheetDataContext._build_journal([])["last_battle"]
	assert_str(str(lb.get("enemy_ai", "x"))).is_empty()


## The lookup reads the file that OWNS these numbers, so a data correction reaches
## the sheet without a second edit.
func test_the_stat_block_comes_from_the_shipped_data_file() -> void:
	var block: Dictionary = EnemyGeneratorScript.get_enemy_stat_block("Gangers")
	assert_bool(block.is_empty()).is_false()
	assert_str(str(block.get("panic", ""))).is_equal("1-2")
	assert_bool(EnemyGeneratorScript.get_enemy_stat_block("Not An Enemy").is_empty()) \
		.is_true()
	assert_bool(EnemyGeneratorScript.get_enemy_stat_block("").is_empty()).is_true()
