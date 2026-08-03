extends GdUnitTestSuite
## Elite-level Enemies — Compendium pp.48-65.
##
## THE DEFECT THIS PINS, in two layers.
##
## 1. data/elite_enemy_types.json was never even LOADED. DataManager declared the
##    path and the dictionary, cleared it twice, and its only getter was commented
##    out at DataManager.gd:745. Nothing else in the repo referenced the file.
##
## 2. The file was also badly incomplete, which made it a trap rather than merely
##    dead: it held THREE of the book's five tables, and two of those stopped
##    halfway — Elite Hired Muscle ended at roll 50 and Elite Unique Individuals
##    at 41, with Elite Interested Parties and Elite Roving Threats absent
##    entirely. Wiring it in that state would have produced a generator returning
##    nothing for most rolls: a silent default that reads as "implemented".
##
## So the data was completed from the PDF first. The invariant that proves the
## extraction did not drop a row is coverage — every table must span D100 1-100
## with no gap and no overlap — and it is asserted here, not just at extraction
## time, because a later hand-edit can reopen a hole just as easily.
##
## gdUnit4 v6.0.3 compatible.

const Elite = preload("res://src/data/compendium_elite_enemies.gd")

const ENEMY_GEN_SRC := "res://src/core/systems/EnemyGenerator.gd"

## p.48: the elite tables "contain the same types of enemies" as the core ones,
## so each elite table must have exactly as many rows as its Core Rules
## counterpart in enemy_types.json. That is an INDEPENDENT check on the
## extraction: a dropped or invented row breaks the match.
const CORE_CATEGORY_FOR := {
	"Elite Criminal Elements": "criminal_elements",
	"Elite Hired Muscle": "hired_muscle",
	"Elite Interested Parties": "interested_parties",
	"Elite Roving Threats": "roving_threats",
}

var _saved_flag: bool = false
var _saved_owned: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	_saved_owned = dlc.has_dlc("freelancers_handbook")
	_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("ELITE_ENEMIES"))


func after_test() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("ELITE_ENEMIES"), _saved_flag)
	dlc.set_dlc_owned("freelancers_handbook", _saved_owned)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("ELITE_ENEMIES"), true)
	return true


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


# --- The data ------------------------------------------------------------------

func test_all_five_book_tables_are_present() -> void:
	var names: Array = []
	for table in Elite.ENEMY_TABLES:
		names.append(str(table.get("table_name", "")))
	assert_array(names).override_failure_message(
		"pp.50-62 print five elite tables; the file has %s" % str(names)
	).contains_exactly_in_any_order([
		"Elite Criminal Elements", "Elite Hired Muscle", "Elite Interested Parties",
		"Elite Roving Threats", "Elite Unique Individuals",
	])


func test_every_table_spans_1_to_100_with_no_gap_or_overlap() -> void:
	# The invariant that catches a dropped row. Hired Muscle used to stop at 50
	# and Unique Individuals at 41.
	for table in Elite.ENEMY_TABLES:
		var spans: Array = []
		for enemy in table.get("enemies", []):
			var span: Array = enemy.get("roll_range", [])
			assert_int(span.size()).override_failure_message(
				"%s / %s has no roll_range" % [table.get("table_name"), enemy.get("name")]
			).is_greater_equal(2)
			spans.append([int(span[0]), int(span[1])])
		spans.sort_custom(func(a, b): return a[0] < b[0])
		var previous: int = 0
		for span in spans:
			assert_int(span[0]).override_failure_message(
				"%s: gap or overlap at %d (previous row ended %d)"
				% [table.get("table_name"), span[0], previous]).is_equal(previous + 1)
			previous = span[1]
		assert_int(previous).override_failure_message(
			"%s stops at %d, not 100" % [table.get("table_name"), previous]
		).is_equal(100)


func test_each_elite_table_has_the_same_row_count_as_its_core_table() -> void:
	# p.48: "They contain the same types of enemies." An independent check that
	# the extraction neither dropped nor invented a row.
	var f := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var json := JSON.new()
	var ok: bool = json.parse(f.get_as_text()) == OK
	f.close()
	assert_bool(ok).is_true()

	var core_counts := {}
	for category in json.data.get("enemy_categories", []):
		core_counts[str(category.get("id", ""))] = (category.get("enemies", []) as Array).size()

	for table_name in CORE_CATEGORY_FOR:
		var table: Dictionary = Elite.get_table(table_name)
		var elite_rows: int = (table.get("enemies", []) as Array).size()
		var core_rows: int = int(core_counts.get(CORE_CATEGORY_FOR[table_name], -1))
		assert_int(elite_rows).override_failure_message(
			"%s has %d rows but its Core Rules table has %d"
			% [table_name, elite_rows, core_rows]).is_equal(core_rows)


func test_every_enemy_carries_the_columns_the_book_prints() -> void:
	for table in Elite.ENEMY_TABLES:
		var is_unique: bool = str(table.get("table_name", "")).ends_with("Unique Individuals")
		for enemy in table.get("enemies", []):
			var label: String = "%s / %s" % [table.get("table_name"), enemy.get("name", "?")]
			for key in ["name", "speed", "combat_skill", "toughness", "ai", "weapons"]:
				assert_bool(enemy.has(key)).override_failure_message(
					"%s is missing %s" % [label, key]).is_true()
			# Unique Individuals print LUCK instead of NUM./PANIC (p.63).
			if is_unique:
				assert_bool(enemy.has("luck")).override_failure_message(
					"%s is missing luck" % label).is_true()
			else:
				assert_bool(enemy.has("num")).override_failure_message(
					"%s is missing num" % label).is_true()
				assert_bool(enemy.has("panic")).override_failure_message(
					"%s is missing panic" % label).is_true()


# --- The rule ------------------------------------------------------------------

func test_rolling_a_category_returns_an_elite_profile() -> void:
	if not _enable():
		return
	for category_id in Elite.CATEGORY_TO_TABLE:
		var seen := {}
		for _i in range(200):
			var out: Dictionary = Elite.roll_enemy_in_category(category_id)
			assert_bool(out.is_empty()).override_failure_message(
				"%s produced nothing — the loader is not reading the table"
				% category_id).is_false()
			assert_bool(bool(out.get("elite", false))).is_true()
			assert_int(int(out.get("roll", 0))).is_between(1, 100)
			seen[str(out.get("name", ""))] = true
		assert_int(seen.size()).override_failure_message(
			"%s only ever produced %s" % [category_id, str(seen.keys())]).is_greater(2)


func test_the_option_is_silent_when_switched_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("ELITE_ENEMIES"), false)
	assert_bool(Elite.roll_enemy_in_category("criminal_elements").is_empty()) \
		.override_failure_message(
			"an unowned/disabled option must fall through to the core tables"
		).is_true()


func test_an_unknown_category_falls_through() -> void:
	if not _enable():
		return
	assert_bool(Elite.roll_enemy_in_category("bug_hunt_swarm").is_empty()).is_true()


# --- p.49 composition ----------------------------------------------------------

func test_a_force_is_never_smaller_than_four() -> void:
	# "If the size would be less than 4 figures, increase it to 4."
	for size in [0, 1, 2, 3, 4]:
		assert_int(Elite.enforce_minimum_size(size)).is_equal(4)
	assert_int(Elite.enforce_minimum_size(7)).is_equal(7)


func test_the_composition_table_matches_the_book() -> void:
	# p.49: 4 -> 3 basic 1 spec; 5 -> 2/2/1 Lt; 6 -> 3/2/1 Lt; 7+ -> 3+/2/1/1.
	var four: Dictionary = Elite.get_composition(4)
	assert_int(int(four["basic"])).is_equal(3)
	assert_int(int(four["specialists"])).is_equal(1)
	assert_int(int(four["lieutenants"])).is_equal(0)
	assert_int(int(four["captain"])).is_equal(0)

	var five: Dictionary = Elite.get_composition(5)
	assert_int(int(five["basic"])).is_equal(2)
	assert_int(int(five["specialists"])).is_equal(2)
	assert_int(int(five["lieutenants"])).is_equal(1)

	var six: Dictionary = Elite.get_composition(6)
	assert_int(int(six["basic"])).is_equal(3)
	assert_int(int(six["lieutenants"])).is_equal(1)
	assert_int(int(six["captain"])).is_equal(0)

	var nine: Dictionary = Elite.get_composition(9)
	assert_int(int(nine["captain"])).override_failure_message(
		"a 7+ force gets a Captain").is_equal(1)
	assert_int(int(nine["specialists"])).is_equal(2)
	assert_int(int(nine["lieutenants"])).is_equal(1)
	# Every figure is accounted for — the basic count absorbs the remainder.
	assert_int(int(nine["basic"]) + 2 + 1 + 1).is_equal(9)


func test_unique_individual_threshold_drops_from_nine_to_seven() -> void:
	# "If you outnumber the enemy, they are AUTOMATICALLY accompanied by a Unique
	# Individual. If you do not outnumber them, roll normally, but a 7+ is
	# required instead of the usual 9+."
	assert_int(Elite.unique_individual_threshold(true)).override_failure_message(
		"outnumbering the enemy guarantees a Unique Individual").is_equal(0)
	assert_int(Elite.unique_individual_threshold(false)).is_equal(7)


func test_elite_rivals_follow_on_a_four_plus() -> void:
	var followed: int = 0
	for _i in range(600):
		if Elite.rival_follows_to_new_world():
			followed += 1
	# 4+ on 1D6 is 50%. Wide bounds — this asserts the threshold, not the RNG.
	assert_int(followed).override_failure_message(
		"p.49 says 4+ on 1D6; got %d/600" % followed).is_between(240, 360)


# --- p.49 leadership -----------------------------------------------------------

func test_leadership_shrinks_the_panic_range_it_never_grows_it() -> void:
	# The direction that CLAUDE.md quotes this table to settle: better morale
	# means a SMALLER Panic range.
	assert_str(Elite.modified_panic_range("1-3", "Lieutenant")).is_equal("1-2")
	assert_str(Elite.modified_panic_range("1-2", "Lieutenant")).is_equal("1")
	assert_str(Elite.modified_panic_range("1-3", "Captain")).is_equal("1")
	assert_str(Elite.modified_panic_range("1", "Captain")).override_failure_message(
		"p.49: a Captain takes a 1 down to 0, and 'a Panic range of 0 indicates "
		+ "the enemy is Fearless'").is_equal("0")


func test_an_unlisted_panic_range_is_left_alone() -> void:
	assert_str(Elite.modified_panic_range("1-4", "Lieutenant")).is_equal("1-4")
	assert_str(Elite.modified_panic_range("1-3", "Sergeant")).is_equal("1-3")


# --- The wiring ----------------------------------------------------------------

func test_the_generator_substitutes_at_the_category_roll() -> void:
	# p.48: the elite tables "take the place of the regular encounter tables", so
	# the substitution belongs at the one point every category roll passes.
	var src: String = _src(ENEMY_GEN_SRC)
	assert_str(src).override_failure_message(
		"EnemyGenerator no longer consults the elite tables"
	).contains("CompendiumEliteEnemiesRef.roll_enemy_in_category(category_id)")
