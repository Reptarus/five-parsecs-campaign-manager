extends GdUnitTestSuite
## The two Bug Hunt co-op D100 tables -- Compendium p.210 (sector Factors) and p.211
## (Enemy Moves) -- pinned against data/bug_hunt/bug_hunt_coop_campaign.json.
##
## WHAT THIS PROVES. Every value 1-100 lands on exactly one row of each table (no gap, no
## overlap), the row count and ids are the book's, and a sample of rows carries the book's
## own sentences -- quoted from the PyPDF2 extraction of pages[211] and pages[212], whose
## page tails read "210Appendices" and "211Appendices". The lookups are asserted through
## BugHuntCoopCampaign, the module the rules run through, not only through the raw JSON.
##
## WHY BOTH. A coverage check alone passes on a table whose rows are all mislabelled; a
## quote check alone passes on a table with a hole in it. A D100 with a hole is a roll the
## app cannot answer, and nothing errors -- the lookup returns {} and the result is
## silently "no effect".
##
## gdUnit4 v6.0.3.

const Coop = preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const DATA_PATH := "res://data/bug_hunt/bug_hunt_coop_campaign.json"
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"

## p.210, in book order.
const FACTOR_IDS := [
	"ambush_zone", "infiltration_point", "sheltered", "swarming",
	"obstructed", "inaccessible", "hot_zone",
]
## p.211, in book order.
const MOVE_IDS := [
	"enemy_assault", "enemy_digs_in", "enemy_establishes_control", "enemy_gathers_forces",
	"enemy_sabotage", "enemy_patrols", "enemy_swarms", "enemy_elites", "wastage",
	"suspicious_activity",
]


func _data() -> Dictionary:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert_object(f).override_failure_message("could not open %s" % DATA_PATH).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).override_failure_message(
		"%s did not parse as a JSON object" % DATA_PATH).is_true()
	return parsed if parsed is Dictionary else {}


func _entries(section: String) -> Array:
	return (_data().get(section, {}) as Dictionary).get("entries", [])


## Every 1-100 value hits exactly one row. Returns the per-value hit counts.
func _coverage(rows: Array) -> Array:
	var hits: Array = []
	hits.resize(101)
	hits.fill(0)
	for row in rows:
		var r: Array = row.get("d100_range", [])
		assert_int(r.size()).is_equal(2)
		for v in range(int(r[0]), int(r[1]) + 1):
			if v >= 1 and v <= 100:
				hits[v] += 1
	return hits


func _assert_full_coverage(rows: Array, table: String) -> void:
	var hits: Array = _coverage(rows)
	var gaps: Array = []
	var overlaps: Array = []
	for v in range(1, 101):
		if int(hits[v]) == 0:
			gaps.append(v)
		elif int(hits[v]) > 1:
			overlaps.append(v)
	assert_array(gaps).override_failure_message(
		"%s: these D100 results reach no row: %s" % [table, str(gaps)]).is_empty()
	assert_array(overlaps).override_failure_message(
		"%s: these D100 results reach more than one row: %s" % [table, str(overlaps)]).is_empty()
	# Ranges stay inside 1-100 -- a row reaching 0 or 101 would hide behind the loop above.
	for row in rows:
		var r: Array = row.get("d100_range", [])
		assert_int(int(r[0])).is_greater_equal(1)
		assert_int(int(r[1])).is_less_equal(100)
		assert_int(int(r[0])).is_less_equal(int(r[1]))


# ──────────────────────────────────────────────────────────────────── provenance
func test_the_data_file_names_its_pages() -> void:
	var data := _data()
	var source: String = str(data.get("_source", ""))
	assert_str(source).contains("pp.209-211")
	assert_str(source).contains("PyPDF2")
	# The two contradictions/gaps the book leaves are recorded, not silently resolved.
	var notes: Dictionary = data.get("_book_notes", {})
	assert_bool(notes.has("stash_size_contradiction")).is_true()
	assert_bool(notes.has("lairs_undefined")).is_true()


# ──────────────────────────────────────────────────────── p.210 the Factor table
func test_the_factor_table_covers_one_to_one_hundred_exactly_once() -> void:
	var rows := _entries("sector_factors")
	assert_int(rows.size()).is_equal(7)
	_assert_full_coverage(rows, "sector_factors")
	var ids: Array = rows.map(func(r: Variant) -> String: return str(r.get("id", "")))
	assert_array(ids).is_equal(FACTOR_IDS)


func test_factor_rows_carry_the_book_text() -> void:
	## Quoted from p.210. Boundary rolls are the ones an off-by-one moves.
	var cases := {
		1: ["ambush_zone", "Ambush zone", "No visibility is possible beyond 8”."],
		15: ["ambush_zone", "Ambush zone", "No visibility is possible beyond 8”."],
		16: ["infiltration_point", "Infiltration point",
			"select a random adjacent sector and increase the Priority level by +1 (to a maximum of 6)"],
		31: ["sheltered", "Sheltered",
			"The sector cannot be attacked until at least one adjacent sector has been cleared."],
		50: ["sheltered", "Sheltered", "adjacent sector has been cleared"],
		51: ["swarming", "Swarming",
			"When revealing any Contact marker, the number of enemies is increased by +1."],
		80: ["obstructed", "Obstructed", "Evac ships cannot provide covering fire."],
		81: ["inaccessible", "Inaccessible", "Only a single support roll can be made."],
		91: ["hot_zone", "Hot zone", "The evac ship cannot loiter."],
		100: ["hot_zone", "Hot zone", "The ship must be called again, if needed."],
	}
	for roll: int in cases:
		var row: Dictionary = Coop.factor_for_roll(roll)
		var want: Array = cases[roll]
		assert_str(str(row.get("id", ""))).override_failure_message(
			"Factor D100 %d should be %s" % [roll, want[0]]).is_equal(want[0])
		assert_str(str(row.get("name", ""))).is_equal(want[1])
		assert_str(str(row.get("effect", ""))).contains(want[2])


func test_factor_battle_values_match_the_book_numbers() -> void:
	assert_int(int(Coop.factor_row("ambush_zone").battle.max_visibility_inches)).is_equal(8)
	assert_int(int(Coop.factor_row("infiltration_point").adjacent_priority_increase)).is_equal(1)
	assert_bool(bool(Coop.factor_row("sheltered").requires_adjacent_cleared)).is_true()
	assert_int(int(Coop.factor_row("swarming").battle.enemies_per_contact_bonus)).is_equal(1)
	assert_bool(bool(Coop.factor_row("obstructed").battle.evac_covering_fire)).is_false()
	assert_int(int(Coop.factor_row("inaccessible").battle.max_support_rolls)).is_equal(1)
	assert_bool(bool(Coop.factor_row("hot_zone").battle.evac_can_loiter)).is_false()


# ───────────────────────────────────────────────────── p.211 the Enemy Moves table
func test_the_enemy_moves_table_covers_one_to_one_hundred_exactly_once() -> void:
	var rows := _entries("enemy_moves")
	assert_int(rows.size()).is_equal(10)
	_assert_full_coverage(rows, "enemy_moves")
	var ids: Array = rows.map(func(r: Variant) -> String: return str(r.get("id", "")))
	assert_array(ids).is_equal(MOVE_IDS)


func test_enemy_move_rows_carry_the_book_text() -> void:
	var cases := {
		1: ["enemy_assault", "A cleared sector falls to the enemy. Priority level 3."],
		10: ["enemy_assault", "Priority level 3."],
		11: ["enemy_digs_in", "One enemy sector becomes an Ambush zone."],
		21: ["enemy_digs_in", "Ambush zone"],
		22: ["enemy_establishes_control", "One enemy sector becomes Obstructed."],
		39: ["enemy_gathers_forces", "One enemy sector becomes an Infiltration point."],
		40: ["enemy_sabotage", "During the next operational turn, all battles are fought with -1 Support point."],
		48: ["enemy_patrols", "add +1 to the Aggression die"],
		57: ["enemy_swarms", "Place 1 additional Contact marker at the beginning of the battle."],
		66: ["enemy_elites", "If Combat Skill is +0, raise it to +1. If Toughness is 3, raise it to 4."],
		74: ["wastage", "Reduce Support reserves by -1D3 points."],
		85: ["wastage", "-1D3"],
		86: ["suspicious_activity", "One enemy sector increases Priority by +1."],
		100: ["suspicious_activity", "increases Priority by +1"],
	}
	for roll: int in cases:
		var row: Dictionary = Coop.enemy_move_for_roll(roll)
		var want: Array = cases[roll]
		assert_str(str(row.get("id", ""))).override_failure_message(
			"Enemy Moves D100 %d should be %s" % [roll, want[0]]).is_equal(want[0])
		assert_str(str(row.get("effect", ""))).contains(want[1])


func test_enemy_move_values_match_the_book_numbers() -> void:
	assert_int(int(Coop.enemy_move_for_roll(5).set_priority)).is_equal(3)
	assert_str(str(Coop.enemy_move_for_roll(5).target)).is_equal("cleared")
	assert_str(str(Coop.enemy_move_for_roll(15).add_factor)).is_equal("ambush_zone")
	assert_str(str(Coop.enemy_move_for_roll(25).add_factor)).is_equal("obstructed")
	assert_str(str(Coop.enemy_move_for_roll(35).add_factor)).is_equal("infiltration_point")
	assert_int(int(Coop.enemy_move_for_roll(45).next_turn_support_penalty)).is_equal(1)
	assert_int(int(Coop.enemy_move_for_roll(50).battle.aggression_die_bonus)).is_equal(1)
	assert_int(int(Coop.enemy_move_for_roll(60).battle.extra_contact_markers)).is_equal(1)
	var elites: Dictionary = Coop.enemy_move_for_roll(70).battle
	assert_int(int(elites.elite_combat_skill_if)).is_equal(0)
	assert_int(int(elites.elite_combat_skill_to)).is_equal(1)
	assert_int(int(elites.elite_toughness_if)).is_equal(3)
	assert_int(int(elites.elite_toughness_to)).is_equal(4)
	assert_int(int(elites.elite_speed_bonus_inches)).is_equal(1)
	assert_str(str(Coop.enemy_move_for_roll(80).support_reserve_loss)).is_equal("1D3")
	assert_int(int(Coop.enemy_move_for_roll(90).priority_increase)).is_equal(1)


func test_every_move_that_adds_a_factor_names_a_real_factor() -> void:
	## "becomes an Ambush zone" must reach the p.210 row, or the sector gains an id no
	## lookup can resolve and the battle modifier silently reads nothing.
	for row in _entries("enemy_moves"):
		if row.has("add_factor"):
			assert_array(FACTOR_IDS).contains([str(row.add_factor)])
		var target: String = str(row.get("target", "missing"))
		assert_array(["enemy", "cleared", ""]).contains([target])


# ─────────────────────────────────────────────────────────── p.210 setup constants
func test_setup_constants_are_the_book_values() -> void:
	var data := _data()
	assert_int(int(data.sectors_per_player.shorter)).is_equal(3)
	assert_int(int(data.sectors_per_player.longer)).is_equal(5)
	assert_str(str(data.sector_priority.dice)).is_equal("2D6")
	assert_str(str(data.sector_priority.keep)).is_equal("lower")
	assert_bool(bool(data.unique_factors_before_duplicates)).is_true()
	var ends: Array = (data.stash.d100_ends_in as Array).map(func(v: Variant) -> int: return int(v))
	ends.sort()
	assert_array(ends).is_equal([0, 5])
	assert_str(str(data.stash.support_points)).is_equal("1D6")
	assert_int(int(data.victory_support_points)).is_equal(1)


func test_the_shared_rules_come_from_the_missions_file_not_a_copy() -> void:
	## p.211 "2+ Objectives completed" and p.210 "(to a maximum of 6)" are the p.201
	## threshold and the p.187 clamp. They are read from bug_hunt_missions.json, so the co-op
	## file must NOT carry a second copy of either.
	var data := _data()
	assert_bool(data.has("success_threshold")).is_false()
	assert_bool(data.has("priority_max")).is_false()
	var f := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	var missions: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	assert_int(int(missions.objectives.scoring.success_threshold)).is_equal(2)
	assert_int(int(missions.priority.min)).is_equal(1)
	assert_int(int(missions.priority.max)).is_equal(6)
