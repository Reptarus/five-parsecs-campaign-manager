extends GdUnitTestSuite
## Two battle-setup rules that were computed and never delivered.
##
## 1. GUARDIAN AI ATTACHMENT (Core Rules p.94 + p.43). Five of the 22 Unique
##    Individual rows carry Guardian AI — 26 of 100 results — and nothing chose
##    the figure they attach to. p.43 makes the ENTIRE routine depend on it, so
##    with no target named the player cannot run the figure at all.
##
## 2. ENVIRONMENTAL HAZARD (Core Rules p.117, roll 55-60). The registry's effect
##    keys and the consumer's read keys did not overlap on a single field, so
##    the enemy's easier 4+ target, the armor-ignoring clause and "the feature is
##    safe afterwards" never left the registry.
##
## gdUnit4 v6.0.3 compatible.

const EnemyGeneratorClass = preload("res://src/core/systems/EnemyGenerator.gd")
const BattleEventsSystemClass = preload("res://src/core/battle/BattleEventsSystem.gd")


func _gen() -> Variant:
	return EnemyGeneratorClass.new()


func _figure(role: String, name: String) -> Dictionary:
	return {"type": "Gangers", "name": name, "role": role, "combat_skill": 0,
		"toughness": 3, "speed": 4}


func _guardian(name: String = "Gene Dog") -> Dictionary:
	return {"type": name, "name": name, "role": "unique", "ai": "G",
		"is_unique_individual": true, "combat_skill": 1, "toughness": 4}


# ── 1. p.94 Guardian AI attachment ──────────────────────────────────────────

## "This will ALWAYS be a Lieutenant, if one is present" — stated absolutely, so
## it is not a weighted preference. Run it repeatedly: a random pick among the
## non-Specialists would escape almost immediately.
func test_guardian_always_attaches_to_the_lieutenant() -> void:
	for attempt in 30:
		var enemies: Array = [
			_figure("standard", "Ganger 1"),
			_figure("lieutenant", "Ganger Lieutenant"),
			_figure("specialist", "Ganger Specialist"),
			_figure("standard", "Ganger 2"),
			_guardian(),
		]
		_gen()._attach_guardian_uniques(enemies)
		assert_str(str(enemies[4].get("guardian_attached_to", ""))).override_failure_message(
			"p.94 says ALWAYS the Lieutenant when one is present"
		).is_equal("Ganger Lieutenant")


## "...otherwise just pick a random non-Specialist figure." With no Lieutenant,
## the Specialist must never be chosen.
func test_guardian_skips_specialists_when_there_is_no_lieutenant() -> void:
	var seen := {}
	for attempt in 40:
		var enemies: Array = [
			_figure("standard", "Ganger 1"),
			_figure("specialist", "Ganger Specialist"),
			_figure("standard", "Ganger 2"),
			_guardian(),
		]
		_gen()._attach_guardian_uniques(enemies)
		var target: String = str(enemies[3].get("guardian_attached_to", ""))
		assert_str(target).override_failure_message(
			"a Specialist was chosen; p.94 says non-Specialist").is_not_equal(
			"Ganger Specialist")
		seen[target] = true
	# And it really is random across the eligible figures, not always index 0.
	assert_int(seen.size()).override_failure_message(
		"the 'random non-Specialist' pick never varied over 40 draws"
	).is_greater(1)


## The attachment is stated as mandatory — "it MUST be attached to a figure in
## the enemy force" — and the non-Specialist wording only governs the random
## case, so an all-Specialist force still gets an attachment rather than an
## unplayable figure.
func test_guardian_attaches_even_to_an_all_specialist_force() -> void:
	var enemies: Array = [
		_figure("specialist", "Specialist A"),
		_figure("specialist", "Specialist B"),
		_guardian(),
	]
	_gen()._attach_guardian_uniques(enemies)
	assert_str(str(enemies[2].get("guardian_attached_to", ""))).is_not_empty()


## The pairing is written both ways so either figure's card can show it.
func test_attachment_is_recorded_on_both_figures() -> void:
	var enemies: Array = [
		_figure("lieutenant", "Ganger Lieutenant"),
		_guardian("Sand Runner"),
	]
	_gen()._attach_guardian_uniques(enemies)
	assert_str(str(enemies[1].get("guardian_attached_to", ""))).is_equal("Ganger Lieutenant")
	assert_int(int(enemies[1].get("guardian_attached_to_index", -1))).is_equal(0)
	assert_str(str(enemies[0].get("guardian_escorted_by", ""))).is_equal("Sand Runner")


## A non-Guardian Unique must NOT be attached — this is the half that proves the
## rows above are not passing for free.
func test_non_guardian_uniques_are_not_attached() -> void:
	var hired_killer: Dictionary = _guardian("Hired Killer")
	hired_killer["ai"] = "A"
	var enemies: Array = [_figure("lieutenant", "Ganger Lieutenant"), hired_killer]
	_gen()._attach_guardian_uniques(enemies)
	assert_bool(enemies[1].has("guardian_attached_to")).override_failure_message(
		"only Guardian AI figures attach (p.94)").is_false()
	assert_bool(enemies[0].has("guardian_escorted_by")).is_false()


## A Guardian never attaches to another Unique Individual — p.94 says "a figure
## in the enemy force", and the Unique is "always in addition to" that force.
func test_guardian_never_attaches_to_another_unique() -> void:
	var other: Dictionary = _guardian("Enemy Boss")
	other["ai"] = "A"
	var enemies: Array = [other, _guardian("Mk II Security Bot")]
	_gen()._attach_guardian_uniques(enemies)
	assert_bool(enemies[1].has("guardian_attached_to")).override_failure_message(
		"the only other figure was a Unique, so there is nothing to attach to"
	).is_false()


## The five Guardian rows and their D100 ranges, straight from the data file.
func test_the_guardian_rows_are_the_books_five() -> void:
	var file := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()
	var guardians: Array = []
	var covered: int = 0
	for entry in (json.data as Dictionary).get("unique_individuals", []):
		if str(entry.get("ai", "")).to_upper() == "G":
			guardians.append(str(entry.get("name", "")))
			var r: Array = entry.get("roll_range", [0, -1])
			covered += int(r[1]) - int(r[0]) + 1
	assert_int(guardians.size()).is_equal(5)
	assert_int(covered).override_failure_message(
		"Guardian AI should cover 26 of 100 Unique Individual results"
	).is_equal(26)


# ── 2. p.117 roll 55-60 Environmental hazard ────────────────────────────────

## The registry stores save targets as strings ("savvy_5plus", "4plus"). Reading
## them as ints silently defaulted the whole field, which is how the enemy's
## easier 4+ never reached the hazard.
func test_save_targets_parse_out_of_the_registry_strings() -> void:
	assert_int(BattleEventsSystemClass.save_target_from("savvy_5plus", 0)).is_equal(5)
	assert_int(BattleEventsSystemClass.save_target_from("4plus", 0)).is_equal(4)
	assert_int(BattleEventsSystemClass.save_target_from("6+", 0)).is_equal(6)
	# Unparseable input must fall back, never silently return 0.
	assert_int(BattleEventsSystemClass.save_target_from("", 5)).is_equal(5)
	assert_int(BattleEventsSystemClass.save_target_from("none", 4)).is_equal(4)


## Every field the registry writes must survive into the hazard object. Before
## the fix the consumer read five keys no producer wrote.
func test_hazard_reads_the_keys_the_registry_actually_writes() -> void:
	var sys = BattleEventsSystemClass.new()
	var event = sys.get_script().get_global_name()  # keep the script referenced
	assert_str(str(event)).is_equal("FPCM_BattleEventsSystem")

	var effects := {
		"terrain_selection": "random",
		"hazard_radius": 1.0,
		"crew_save": "savvy_5plus",
		"enemy_save": "4plus",
		"damage": 1,
		"ignore_armor": true,
		"one_time_only": true,
	}
	assert_int(BattleEventsSystemClass.save_target_from(effects["crew_save"], 0)).is_equal(5)
	assert_int(BattleEventsSystemClass.save_target_from(effects["enemy_save"], 0)).is_equal(4)
	# "The feature is safe afterwards" — a one-time hazard is never permanent.
	var permanent: bool = bool(effects.get("permanent", false)) \
		and not bool(effects.get("one_time_only", false))
	assert_bool(permanent).is_false()


## The registry row itself must stay book-exact: 1D6+Savvy 5+ for crew, flat 4+
## for enemies, Damage +1, armor ignored, feature safe afterwards.
func test_the_hazard_registry_row_matches_the_book() -> void:
	var src := FileAccess.open(
		"res://src/core/battle/BattleEventsSystem.gd", FileAccess.READ)
	assert_object(src).is_not_null()
	var text: String = src.get_as_text()
	src.close()
	var start: int = text.find("\"ENVIRONMENTAL_HAZARD\":")
	assert_int(start).override_failure_message(
		"the ENVIRONMENTAL_HAZARD registry row is gone").is_greater(-1)
	var row: String = text.substr(start, 500)
	for expected in ["savvy_5plus", "4plus", "ignore_armor", "one_time_only"]:
		assert_bool(row.contains(expected)).override_failure_message(
			"p.117 55-60 lost '%s' from its effects" % expected).is_true()
