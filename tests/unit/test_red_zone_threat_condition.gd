extends GdUnitTestSuite
## Core Rules p.149 Red Job Threat Condition — a producer with no caller and a
## consumer with no producer, on opposite ends of the same key.
##
## "You must roll for a Threat Condition. This is an additional factor that is
## applied to the mission, regardless of its type."
##
## `RedZoneSystem.roll_threat_condition()` was written and correct, and its only
## mention anywhere in the tree was the usage example in its own docblock — ZERO
## callers. Meanwhile `PostBattleCompletion.gd:149` reads `red_zone_threat` off
## the battle result to journal it, so the consumer was live and waiting on a
## producer that never ran. Every Red Job in every campaign was fought with no
## Threat Condition at all.
##
## gdUnit4 v6.0.3 compatible.

const RedZoneSystemClass = preload("res://src/core/mission/RedZoneSystem.gd")
const EnemyGeneratorClass = preload("res://src/core/systems/EnemyGenerator.gd")

## p.149, verbatim.
const BOOK_CONDITIONS := {
	1: "Comms Interference",
	2: "Elite Opposition",
	3: "Pitch Black",
	4: "Heavy Opposition",
	5: "Armored Opponents",
	6: "Enemy Captain",
}


# ── The table ───────────────────────────────────────────────────────────────

func test_the_six_threat_conditions_match_the_book() -> void:
	var file := FileAccess.open("res://data/red_zone_jobs.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()
	var conditions: Array = (json.data as Dictionary).get("threat_conditions", [])
	assert_int(conditions.size()).override_failure_message(
		"p.149 is a D6 table with six rows").is_equal(6)
	for entry in conditions:
		var roll: int = int(entry.get("roll", 0))
		assert_bool(BOOK_CONDITIONS.has(roll)).is_true()
		assert_str(str(entry.get("name", ""))).override_failure_message(
			"p.149 roll %d" % roll).is_equal(BOOK_CONDITIONS[roll])


## Every roll must resolve — a D6 with a hole in it silently returns {} and the
## mission gets no Threat Condition, which is the state this row is about.
func test_every_roll_resolves_to_a_condition() -> void:
	var seen := {}
	for attempt in 60:
		var threat: Dictionary = RedZoneSystemClass.roll_threat_condition()
		assert_bool(threat.is_empty()).override_failure_message(
			"roll_threat_condition() returned nothing").is_false()
		var roll: int = int(threat.get("roll", 0))
		assert_bool(BOOK_CONDITIONS.has(roll)).is_true()
		seen[roll] = true
	assert_int(seen.size()).override_failure_message(
		"only saw rolls %s over 60 draws — the D6 is not covering its table"
		% str(seen.keys())).is_equal(6)


# ── The mechanical effects, at their consumers ──────────────────────────────

func _generate(mission: Dictionary) -> Array:
	## Red Jobs take the p.150 flat base of 7 figures, so the count is
	## deterministic apart from the Threat Condition under test — which is what
	## makes the +2 comparison below meaningful rather than dice noise.
	var gen = EnemyGeneratorClass.new()
	mission["is_red_zone"] = true
	mission["enemy_type"] = mission.get("enemy_type", "Gangers")
	return gen.generate_enemies_as_dicts(mission, 6)


## Roll 4 Heavy Opposition: "Increase the opposing force by +2 enemy."
## DOCUMENTED READING: p.150's "No other modifiers are applied up or down"
## governs the number-DETERMINATION step it sits in. Threat Conditions occur ONLY
## on Red Jobs, so if p.150 suppressed them, roll 4 would be permanently dead
## text on the only mission type that can produce it.
func _rank_and_file(mission: Dictionary) -> int:
	## Count only the figures the p.150 base of 7 governs. A Unique Individual is
	## "always in addition to those normally encountered" (p.94) and arrives on a
	## random 9+ — and Red Zone adds +1 to that roll — so a raw .size() compares
	## dice noise, not the Threat Condition. This test passed in isolation and
	## failed in a full run for exactly that reason before the filter.
	var n: int = 0
	for f in _generate(mission):
		if str(f.get("role", "")) == "unique":
			continue
		if bool(f.get("is_red_zone_captain", false)):
			continue
		n += 1
	return n


func test_heavy_opposition_adds_two_enemies() -> void:
	# The p.150 base is flat (7 + type modifier, "no other modifiers"), so with
	# uniques excluded both sides are deterministic and the delta is exactly the
	# Threat Condition. Repeated so a single lucky pair cannot carry it.
	for attempt in 10:
		var plain: int = _rank_and_file({})
		var heavy: int = _rank_and_file({"red_zone_enemy_delta": 2})
		assert_int(heavy - plain).override_failure_message(
			"p.149 roll 4 adds +2 enemy; got %d vs %d" % [heavy, plain]).is_equal(2)


## Roll 2 Elite Opposition: "All opponents with +0 Combat Skill are upgraded to
## +1." A FLOOR — "Not all of these Threat Conditions may be applicable ... If
## so, the result is simply ignored", so a profile already above it is untouched.
func test_elite_opposition_floors_combat_skill() -> void:
	for figure in _generate({"enemy_combat_skill_floor": 1}):
		if str(figure.get("role", "")) == "unique":
			continue
		assert_int(int(figure.get("combat_skill", -9))).override_failure_message(
			"p.149 roll 2: %s kept Combat Skill below +1" % figure.get("name", "?")
		).is_greater_equal(1)


## Roll 5 Armored Opponents: "All opponents with 3 Toughness are upgraded to 4."
func test_armored_opponents_floors_toughness() -> void:
	for figure in _generate({"enemy_toughness_floor": 4}):
		if str(figure.get("role", "")) == "unique":
			continue
		assert_int(int(figure.get("toughness", -9))).override_failure_message(
			"p.149 roll 5: %s kept Toughness below 4" % figure.get("name", "?")
		).is_greater_equal(4)


## A floor must never REDUCE a profile that is already better.
func test_the_floors_never_reduce_a_better_profile() -> void:
	var floored: Array = _generate({"enemy_toughness_floor": 1})
	for figure in floored:
		assert_int(int(figure.get("toughness", 0))).override_failure_message(
			"a Toughness floor of 1 pushed a figure DOWN").is_greater_equal(3)


## Roll 6 Enemy Captain: "Add an ADDITIONAL Lieutenant with Combat Skill +2 and
## Toughness 5, regardless of the normal profile used." Additional, so the force
## grows; and the scores are SET, not floored.
func test_enemy_captain_is_an_additional_lieutenant() -> void:
	var with_captain: Array = _generate({
		"extra_lieutenant": {"combat_skill": 2, "toughness": 5}})
	# "ADDITIONAL" — the captain is on top of the rank and file, so the base
	# count is unchanged and exactly one extra figure carries the flag. Compared
	# through the unique-filtered count for the same reason as Heavy Opposition.
	var with_cap_count: int = _rank_and_file(
		{"extra_lieutenant": {"combat_skill": 2, "toughness": 5}})
	assert_int(with_cap_count).override_failure_message(
		"p.149 roll 6 is ADDITIONAL — it must not shrink the rank and file"
	).is_equal(_rank_and_file({}))

	var captains: Array = []
	for f in with_captain:
		if bool(f.get("is_red_zone_captain", false)):
			captains.append(f)
	assert_int(captains.size()).is_equal(1)
	assert_str(str(captains[0].get("role", ""))).is_equal("lieutenant")
	assert_int(int(captains[0].get("combat_skill", -9))).override_failure_message(
		"'regardless of the normal profile used' — Combat Skill is SET to +2"
	).is_equal(2)
	assert_int(int(captains[0].get("toughness", -9))).override_failure_message(
		"'regardless of the normal profile used' — Toughness is SET to 5"
	).is_equal(5)


## Without the Threat Condition keys nothing changes — the half that proves the
## rows above are not passing for free.
func test_a_mission_without_a_threat_condition_is_unmodified() -> void:
	for figure in _generate({}):
		assert_bool(figure.get("is_red_zone_captain", false)).is_false()
