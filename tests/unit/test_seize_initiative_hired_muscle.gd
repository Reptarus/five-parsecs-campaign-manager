extends GdUnitTestSuite
## Seize the Initiative — the Hired Muscle -1 must REACH the roll (Core Rules p.112)
##
## p.112 verbatim: "Roll 2D6. Add the highest Savvy score of any crew member.
##   - Add +1 if you are outnumbered.
##   - When fighting opponents from the Hired Muscle encounter tables, modify by -1.
##   - If the campaign's difficulty mode is Hardcore, modify by -2.
##   - If the campaign's difficulty mode is Insanity, modify by -3.
##  ... On a total of 10+, any character in your crew may either take a normal Move or may
##  fire before the battle begins."
##
## WRITTEN AFTER A NEAR-MISS — READ THIS BEFORE "FIXING" ANYTHING HERE.
##
## On the tablet 2026-08-08, a campaign battle vs Blood Storm Mercs (Hired Muscle) with a
## crew of 6 whose highest Savvy was 2 showed, in PreBattleUI's Mission Info:
##     "Need 8+ on 2D6 (Savvy +2) — 42% chance"
## while the Enemy Forces panel one column over showed:
##     "Category: Hired Muscle (Seize Init -1)"
## 8 = 10 - 2 - 0, so the penalty the same screen advertised was plainly not in the number,
## and this codebase's most common defect by far is a modifier that is displayed and never
## applied. Most of a bug report was written before the crew roster got checked.
##
## THE APP WAS RIGHT. Finn Mendez is FERAL, and p.112 ends with: "If your crew includes any
## Feral, you may ignore any penalties the opponents would have imposed on you." The -1 is
## correctly cancelled, 8+ is the correct target, and 41.7% is the correct probability.
##
## The lesson is about evidence, not about Seize the Initiative: a modifier that appears in
## one panel and not in another panel's arithmetic is a LEAD. Before calling it a wiring
## break, check the campaign state that could legitimately cancel it — here, one crew
## member's species. Reading only the code could not have settled it.
##
## So this suite pins BOTH readings, and the Feral case exists specifically so that nobody
## later "fixes" the non-Feral expectation into the live path:
##   enemy_types.json  ->  _category_info()  ->  the generated enemy dict
##       ->  SeizeInitiativeSystem.calculate_required_roll()   [no Feral: 9]
##       ->  ...with a Feral in the crew                        [penalty ignored: 8]
##
## Must run as a gdUnit4 test, NOT a bare `--script` probe: EnemyGenerator._load_enemy_data()
## resolves /root/DataManager, and a detached Resource cannot, so the null call aborts _init
## and every category lookup silently returns 0. A probe run that way measures the trap
## rather than the code.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const EnemyGen := preload("res://src/core/systems/EnemyGenerator.gd")
const SeizeSys := preload("res://src/core/battle/SeizeInitiativeSystem.gd")

const CREW_SAVVY_2 := [
	{"savvy": 2, "name": "Bryn"}, {"savvy": 2, "name": "Dex"},
	{"savvy": 0, "name": "Yuri"}, {"savvy": 1, "name": "Mars"},
	{"savvy": 0, "name": "Finn"}, {"savvy": 0, "name": "Nyx"},
]


func test_hired_muscle_category_carries_the_book_penalty() -> void:
	## Link 1: the data file itself.
	var f := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	assert_object(f).override_failure_message("data/enemy_types.json unreadable").is_not_null()
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()

	var seize_by_id := {}
	for cat in (parsed as Dictionary).get("enemy_categories", []):
		seize_by_id[str(cat.get("id", ""))] = int(cat.get("seize_initiative_modifier", 0))

	assert_int(int(seize_by_id.get("hired_muscle", 0))) \
		.override_failure_message(
			"enemy_types.json lost the Hired Muscle Seize penalty. Core Rules p.112: "
			+ "\"When fighting opponents from the Hired Muscle encounter tables, modify by "
			+ "-1.\" Categories found: %s" % str(seize_by_id)) \
		.is_equal(-1)


func test_generated_hired_muscle_enemy_carries_the_penalty() -> void:
	## Link 2: the generated enemy dict, which is what the campaign layer reads via
	## `first_enemy.get("seize_initiative_modifier", 0)` — a 2-arg get whose default
	## silently hides a missing key.
	var gen = EnemyGen.new()

	var found: Dictionary = {}
	for attempt in range(60):
		var enemies: Array = gen.generate_enemies_as_dicts({
			"objective": "Patrol",
			"mission_source": "opportunity",
			"crew_in_field": 6,
		}, 6)
		if enemies.is_empty():
			continue
		var e: Dictionary = enemies[0]
		if str(e.get("category", "")) == "hired_muscle":
			found = e
			break

	assert_bool(found.is_empty()) \
		.override_failure_message(
			"never drew the Hired Muscle category in 60 opportunity encounters — p.94 gives "
			+ "it 31-60 on the Opportunity column, so this should hit in a handful of rolls. "
			+ "The encounter table or its roll is broken.") \
		.is_false()

	assert_bool(found.has("seize_initiative_modifier")) \
		.override_failure_message(
			"the generated enemy has NO seize_initiative_modifier key at all. "
			+ "CampaignTurnController reads it with a 2-arg .get(..., 0), so a missing key "
			+ "is a silent 0 and the p.112 penalty vanishes without any error.") \
		.is_true()

	# Blood Storm Mercs et al. carry no Careless (+1) / Alert (-1) trait, but some Hired
	# Muscle entries do, so assert the CATEGORY half is present rather than an exact total.
	var trait_mod: int = _trait_seize_modifier(str(found.get("type", "")))
	assert_int(int(found.get("seize_initiative_modifier", 0))) \
		.override_failure_message(
			"generated %s carries seize_initiative_modifier=%s; expected the category -1 "
			% [str(found.get("type", "?")), str(found.get("seize_initiative_modifier"))]
			+ "plus its own trait modifier (%d). Core Rules p.112." % trait_mod) \
		.is_equal(-1 + trait_mod)


func _trait_seize_modifier(enemy_name: String) -> int:
	var rules = load("res://src/core/systems/EnemyTraitRules.gd")
	return int(rules.seize_modifier(enemy_name))


func test_hired_muscle_penalty_applies_when_no_feral_in_crew() -> void:
	## Link 3, ordinary crew: the -1 is real and must move the target.
	var sys = SeizeSys.new()
	sys.set_crew_data(CREW_SAVVY_2)
	sys.set_outnumbered(false)          # 5 enemies vs 6 crew — not outnumbered
	sys.set_enemy_modifier(-1, "Blood Storm Mercs")

	assert_int(sys.highest_savvy) \
		.override_failure_message("highest Savvy across the crew should be 2") \
		.is_equal(2)
	assert_bool(sys.has_feral) \
		.override_failure_message("CREW_SAVVY_2 must contain NO Feral for this case") \
		.is_false()
	assert_int(sys.calculate_required_roll()) \
		.override_failure_message(
			"Core Rules p.112: total must reach 10. With Savvy +2 and Hired Muscle -1 and "
			+ "no Feral aboard, the raw 2D6 must be 9+.") \
		.is_equal(9)

	# P(2D6 >= 9) = 10/36 = 27.78%.
	assert_float(sys.get_success_probability()).is_equal_approx(27.78, 0.2)


func test_a_feral_in_the_crew_cancels_the_hired_muscle_penalty() -> void:
	## Link 3, THE TABLET'S ACTUAL CREW. p.112: "If your crew includes any Feral, you may
	## ignore any penalties the opponents would have imposed on you."
	##
	## This is the case that made "Need 8+ ... 42%" correct on device despite the Enemy
	## Forces panel advertising a -1. Do not "fix" the app to produce 9 here.
	var crew := CREW_SAVVY_2.duplicate(true)
	crew.append({"savvy": 0, "name": "Finn Mendez", "origin": "FERAL"})

	var sys = SeizeSys.new()
	sys.set_crew_data(crew)
	sys.set_outnumbered(false)
	sys.set_enemy_modifier(-1, "Blood Storm Mercs")

	assert_bool(sys.has_feral) \
		.override_failure_message(
			"Feral not detected. set_crew_data() matches origin case-insensitively; the "
			+ "device save stores it as the STRING \"FERAL\".") \
		.is_true()
	assert_int(sys.calculate_required_roll()) \
		.override_failure_message(
			"a Feral crew member must cancel the enemy's Seize penalty (p.112), leaving "
			+ "10 - 2 - 0 = 8. Measured on the tablet as \"Need 8+ ... 42%\".") \
		.is_equal(8)
	assert_float(sys.get_success_probability()).is_equal_approx(41.67, 0.2)


func test_feral_cancels_penalties_only_never_bonuses() -> void:
	## p.112 says "ignore any PENALTIES". A Careless opponent's +1 is a gift and must
	## survive — the guard is `modifier.value < 0`, not `key == "enemy_type"`.
	var crew := CREW_SAVVY_2.duplicate(true)
	crew.append({"savvy": 0, "name": "Finn Mendez", "origin": "FERAL"})

	var sys = SeizeSys.new()
	sys.set_crew_data(crew)
	sys.set_outnumbered(false)
	sys.set_enemy_modifier(1, "Punks")   # "Careless: You are +1 to Seize the Initiative"

	assert_int(sys.calculate_required_roll()) \
		.override_failure_message(
			"Feral must not discard a FAVOURABLE enemy modifier — p.112 exempts penalties "
			+ "only. 10 - 2 - 1 = 7.") \
		.is_equal(7)


func test_no_penalty_case_still_needs_8_with_savvy_2() -> void:
	## Control: without a category penalty the 8+/42% reading IS correct, so the tests
	## above pin the modifier and not merely the arithmetic.
	var sys = SeizeSys.new()
	sys.set_crew_data(CREW_SAVVY_2)
	sys.set_outnumbered(false)
	sys.set_enemy_modifier(0, "Gangers")

	assert_int(sys.calculate_required_roll()).is_equal(8)
	assert_float(sys.get_success_probability()).is_equal_approx(41.67, 0.2)
