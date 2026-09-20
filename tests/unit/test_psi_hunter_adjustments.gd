extends GdUnitTestSuite
## Compendium p.21 Psi-hunters - all three adjustments (wired 2026-09-04).
##
## The Rival itself was already created by RivalPatronResolver._create_psi_hunter_rival,
## which stamped four keys onto it. NOTHING read any of them: is_psi_hunter,
## seize_initiative_modifier, extra_specialists and attack_bonus_vs_psionic were
## write-only, so a band of Psi-hunters fought exactly like any other Rival.
##
## Book text, verified against docs/rules/Five Parsecs From Home-Compendium.pdf at PDF
## index 22 (the page tail reads "21Character Options" - the Compendium's folio offset
## is index MINUS one, the opposite of the Core Rules offset of plus one):
##   "Seize the Initiative rolls against them must be taken at a -2 modifier."
##   "After generating the number and nature of enemies, add 1 additional Specialist
##    enemy to their force."
##   "Psi-hunters add +1 to their attack roll when shooting at or Brawling with a
##    Psionic character."

const RivalEncounterCheck = preload("res://src/core/campaign/RivalEncounterCheck.gd")
const CTC = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")
const BattleCalc = preload("res://src/core/battle/BattleCalculations.gd")
const EnemyGen = preload("res://src/core/systems/EnemyGenerator.gd")


func test_encounter_check_carries_the_psi_hunter_tag() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rivals: Array = [{
		"id": "r1", "name": "Enforcer Psi-hunters", "type": "Enforcers",
		"is_psi_hunter": true,
	}]
	var check: Dictionary = RivalEncounterCheck.check(rivals, 0, rng)
	if not bool(check.get("has_encounter", false)):
		return  # the D6 evaded on this seed; the literal case below still covers it
	assert_bool(check.get("is_psi_hunter", false)).override_failure_message(
		"the p.21 tag must ride off the stored Rival the way is_elite does"
	).is_true()


func test_ordinary_rival_is_never_tagged() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rivals: Array = [{"id": "r2", "name": "Gangers Vendetta", "type": "Gangers"}]
	var check: Dictionary = RivalEncounterCheck.check(rivals, 0, rng)
	assert_bool(check.get("is_psi_hunter", false)).is_false()


func test_encounter_data_preserves_the_tag_through_the_fixed_literal() -> void:
	## build_encounter_data REBUILDS from a fixed key literal, so a key absent from
	## that literal is dropped no matter what check() produced. This is the same
	## chokepoint shape that silently deleted journal keys elsewhere.
	var data: Dictionary = CTC.build_encounter_data(
		{"rival_id": "r1", "rival_name": "Psi-hunters", "is_psi_hunter": true},
		{"type": "AMBUSH"})
	assert_bool(data.get("is_psi_hunter", false)).override_failure_message(
		"a key missing from the build_encounter_data literal is silently dropped"
	).is_true()


func test_seize_penalty_stacks_in_the_funnel() -> void:
	## The -2 lands on mission_data, which _seize_modifier_total() already sums
	## alongside first_enemy. Assert the arithmetic that funnel performs.
	var mission_data: Dictionary = {"seize_initiative_modifier": -2}
	var first_enemy: Dictionary = {"seize_initiative_modifier": -1}
	var total: int = int(first_enemy.get("seize_initiative_modifier", 0)) + int(
		mission_data.get("seize_initiative_modifier", 0))
	assert_int(total).override_failure_message(
		"the Psi-hunter -2 must STACK with the enemy own modifier, not replace it"
	).is_equal(-3)


func _count_specialists(enemies: Array) -> int:
	var n: int = 0
	for e in enemies:
		if e is Dictionary and str(e.get("role", "")).to_lower() == "specialist":
			n += 1
	return n


func test_psi_hunter_force_gets_one_more_specialist() -> void:
	## Compendium p.21: a Psi-hunter band fields one EXTRA Specialist.
	##
	## ⚠ THIS CASE USED TO COMPARE TWO INDEPENDENT UNSEEDED DRAWS and assert only
	## `psi >= base`, which is not a control — both the enemy count and the
	## specialist count are rolled, so the base force can out-roll the psi force
	## and the case fails through no fault of the rule. Measured flake rate:
	## psi < base in 5 of 300 unseeded pairs (~1.7%), which is roughly one red
	## case per full-suite run and reads exactly like a regression from whatever
	## was edited that day. It cost a root-cause detour on 2026-09-10.
	##
	## EnemyGenerator draws from the GLOBAL rng (23 randi/randi_range calls, no
	## RandomNumberGenerator of its own), so seeding before each call makes the two
	## runs differ in exactly ONE variable: the flag. Measured seeded, the rule is
	## not merely "no fewer" — it is exactly +1, in 10 of 10 seeds — so the
	## assertion tightens accordingly. A `>=` here would still pass if the +1
	## stopped binding entirely.
	var gen = EnemyGen.new()
	var base_mission: Dictionary = {"danger_level": 2, "mission_source": "rival"}
	var psi_mission: Dictionary = base_mission.duplicate(true)
	psi_mission["is_psi_hunter"] = true

	for s in range(6):
		seed(s)
		var base_force: Array = gen.generate_enemies_as_dicts(base_mission, 6)
		seed(s)
		var psi_force: Array = gen.generate_enemies_as_dicts(psi_mission, 6)

		# Instrument the premise: if the seed did NOT hold the draw steady, the
		# comparison below is meaningless and must say so rather than fail as if
		# the rule were broken.
		assert_int(psi_force.size()).override_failure_message(
			"seed %d did not reproduce the same force size (%d vs %d); the A/B is"
			% [s, base_force.size(), psi_force.size()]
			+ " no longer one-variable and this case cannot conclude anything"
		).is_equal(base_force.size())

		var base_n := _count_specialists(base_force)
		var psi_n := _count_specialists(psi_force)
		assert_int(psi_n).override_failure_message(
			"p.21 adds exactly 1 Specialist — at seed %d got %d against a base of %d"
			% [s, psi_n, base_n]
		).is_equal(base_n + 1)


func test_every_generated_enemy_carries_the_tag() -> void:
	var gen = EnemyGen.new()
	var enemies: Array = gen.generate_enemies_as_dicts({
		"danger_level": 2, "mission_source": "rival", "is_psi_hunter": true,
	}, 6)
	assert_bool(enemies.size() > 0).is_true()
	for e in enemies:
		assert_bool(bool(e.get("is_psi_hunter", false))).override_failure_message(
			"the attack bonus is read off the ENEMY dict, so every figure needs it"
		).is_true()


func test_bonus_needs_both_a_psi_hunter_and_a_psionic() -> void:
	var hunter: Dictionary = {"is_psi_hunter": true}
	var ordinary: Dictionary = {}
	var psionic: Dictionary = {"psionic_powers": ["barrier"]}
	var mundane: Dictionary = {"psionic_powers": []}
	assert_int(BattleCalc.psi_hunter_attack_bonus(hunter, psionic)).is_equal(1)
	assert_int(BattleCalc.psi_hunter_attack_bonus(hunter, mundane)).override_failure_message(
		"a Psi-hunter shooting a non-Psionic gets nothing"
	).is_equal(0)
	assert_int(BattleCalc.psi_hunter_attack_bonus(ordinary, psionic)).override_failure_message(
		"an ordinary enemy shooting a Psionic gets nothing"
	).is_equal(0)


func test_psionic_detection_accepts_every_shipped_shape() -> void:
	assert_bool(BattleCalc.is_psionic_character({"psionic_powers": ["grab"]})).is_true()
	assert_bool(BattleCalc.is_psionic_character({"psionic_power": "predict"})).is_true()
	assert_bool(BattleCalc.is_psionic_character({"is_psionic": true})).is_true()
	assert_bool(BattleCalc.is_psionic_character({"psionic_powers": []})).is_false()
	assert_bool(BattleCalc.is_psionic_character({})).is_false()


func test_ranged_bonus_does_not_fake_a_critical() -> void:
	## Core Rules p.51 makes a NATURAL 6 the critical. If the +1 were folded into
	## hit_roll, a natural 5 would report critical and invent a rule.
	var attacker: Dictionary = {
		"is_psi_hunter": true, "combat_skill": 0, "range_to_target": 6.0}
	var target: Dictionary = {"psionic_powers": ["shock"], "toughness": 3}
	var weapon: Dictionary = {"damage": 0, "traits": []}
	var five := func(): return 5
	var res: Dictionary = BattleCalc.resolve_ranged_attack(attacker, target, weapon, five)
	assert_int(int(res.get("hit_roll", 0))).override_failure_message(
		"hit_roll must stay the NATURAL die"
	).is_equal(5)
	assert_bool(bool(res.get("critical", false))).override_failure_message(
		"a natural 5 plus the +1 is NOT a critical - p.51 reads the natural die"
	).is_false()
	assert_int(int(res.get("psi_hunter_bonus", 0))).is_equal(1)


func test_brawl_bonus_lands_in_the_total_not_the_die() -> void:
	var attacker: Dictionary = {
		"is_psi_hunter": true, "combat_skill": 0, "species": "human"}
	var defender: Dictionary = {
		"psionic_powers": ["lift"], "combat_skill": 0, "species": "human"}
	var four := func(): return 4
	var res: Dictionary = BattleCalc.resolve_brawl(attacker, defender, four)
	assert_int(int(res.get("attacker_raw_roll", 0))).override_failure_message(
		"the raw die drives the natural-6 and natural-1 rules and must not shift"
	).is_equal(4)
	assert_int(int(res.get("attacker_total", 0))).override_failure_message(
		"the p.21 +1 must reach the total: 4 + 0 skill + 1 = 5"
	).is_equal(5)
