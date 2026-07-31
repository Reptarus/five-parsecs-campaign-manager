extends GdUnitTestSuite
## Battle-phase sprint, P1.9 — Unique Individuals (Core Rules pp.93-94, table
## pp.105-107).
##
## The roll was never made anywhere. It lived in BattlePhase.gd, deleted in
## 99fad30b2 and never re-homed, leaving only post-battle consumers reading a
## "unique_kills" key nothing wrote — while the complete 22-entry table sat unused
## in enemy_types.json.
##
## The book's EXCEPTIONS are the subtle part, so they are what these cases pin:
## Invasion and Roving Threats are skipped entirely, Interested Parties and
## Hardcore add +1, and Insanity overrides all of it.

const GEN = preload("res://src/core/systems/EnemyGenerator.gd")

const DIFF_NORMAL := 2
const DIFF_HARDCORE := 6   # GlobalEnums.DifficultyLevel.HARDCORE
const DIFF_INSANITY := 8   # GlobalEnums.DifficultyLevel.INSANITY

const TRIALS := 200

func _gen() -> Object:
	return auto_free(GEN.new())

# ── The exceptions (deterministic, no RNG dependence) ─────────────────────

func test_roving_threats_are_never_accompanied() -> void:
	# Core Rules p.93: "Unless fighting ... an enemy from the Roving Threats
	# Subtable, roll 2D6". p.101 restates it: "never accompanied by Unique
	# Individuals unless difficulty is Insanity".
	var g = _gen()
	for _i in range(TRIALS):
		assert_int(g.roll_unique_individuals({}, "roving_threats", DIFF_NORMAL).size()) \
			.is_equal(0)

func test_invasion_battles_are_never_accompanied() -> void:
	# Core Rules p.93: "Unless fighting an Invasion battle ... roll 2D6".
	var g = _gen()
	for _i in range(TRIALS):
		assert_int(g.roll_unique_individuals(
			{"is_invasion": true}, "criminal_elements", DIFF_NORMAL).size()).is_equal(0)

func test_insanity_always_produces_at_least_one_even_vs_roving_threats() -> void:
	# Core Rules p.94: "If the campaign's difficulty mode is Insanity, a Unique
	# Individual is present, even if fighting a Roving Threat."
	var g = _gen()
	for _i in range(TRIALS):
		var out: Array = g.roll_unique_individuals({}, "roving_threats", DIFF_INSANITY)
		assert_int(out.size()).is_between(1, 2)

func test_insanity_can_produce_two() -> void:
	# Core Rules p.94: "A result of 11-12 means you have to fight 2 Unique
	# Individuals." 11+ on 2D6 is 3/36, so across many trials it must appear.
	var g = _gen()
	var saw_two: bool = false
	for _i in range(TRIALS):
		if g.roll_unique_individuals({}, "criminal_elements", DIFF_INSANITY).size() == 2:
			saw_two = true
			break
	assert_bool(saw_two).is_true()

# ── The modifiers shift the odds in the right direction ───────────────────

func _rate(g: Object, category: String, difficulty: int) -> float:
	var hits: int = 0
	for _i in range(TRIALS):
		if not g.roll_unique_individuals({}, category, difficulty).is_empty():
			hits += 1
	return float(hits) / float(TRIALS)

func test_interested_parties_and_hardcore_make_a_unique_more_likely() -> void:
	# p.93: "+1 if fighting opponents from the Interested Parties Subtable" and
	# "+1 if the campaign's difficulty mode is Hardcore". Base 9+ on 2D6 is
	# 10/36 (~0.28); +1 makes it 8+, 15/36 (~0.42). Wide margins so the
	# assertion is about direction, not a flaky exact rate.
	var g = _gen()
	var base: float = _rate(g, "criminal_elements", DIFF_NORMAL)
	var parties: float = _rate(g, "interested_parties", DIFF_NORMAL)
	var hardcore: float = _rate(g, "criminal_elements", DIFF_HARDCORE)
	assert_float(base).is_between(0.15, 0.42)
	assert_float(parties).is_greater(base - 0.10)
	assert_float(hardcore).is_greater(base - 0.10)

# ── The produced figure is usable ─────────────────────────────────────────

func test_a_unique_is_flagged_fearless_and_additional() -> void:
	# p.105: "Unique Individuals are Fearless and will not be affected by Morale
	# checks." p.94: the figure "is always in addition to those normally
	# encountered", so it must be marked as its own role and never as a
	# Specialist or Lieutenant (which would consume a slot in the rolled count).
	var g = _gen()
	var out: Array = g.roll_unique_individuals({}, "criminal_elements", DIFF_INSANITY)
	assert_int(out.size()).is_greater(0)
	var u: Dictionary = out[0]
	assert_bool(u["is_unique_individual"]).is_true()
	assert_bool(u["is_fearless"]).is_true()
	assert_str(u["role"]).is_equal("unique")
	assert_str(u["name"]).is_not_empty()

func test_a_unique_carries_usable_stats_and_weapons() -> void:
	var g = _gen()
	var out: Array = g.roll_unique_individuals({}, "criminal_elements", DIFF_INSANITY)
	var u: Dictionary = out[0]
	# "-" in the table means "keep the base enemy's value" and must not become 0.
	assert_int(u["toughness"]).is_greater(0)
	assert_int(u["speed"]).is_greater(0)
	assert_array(u["weapons"]).is_not_empty()

# ── Designer FAQ: the first three entries scale off the enemy you fight ───
#
# modiphius.net/en-us/pages/five-parsecs-faq, verbatim: "The first three Unique
# Individuals on the table (Enemy Bruiser, Enemy Heavy, Enemy Boss) use the base
# profile of the enemy type you are fighting with a boost." Their table rows are
# "-" and "+1" rather than absolute scores, so without the base profile they are
# meaningless — and treating "+1" as no-data hands an Enemy Bruiser the same
# Toughness as the mooks it leads.

const TOUGH_BASE := 5
const COMBAT_BASE := 2
const SPEED_BASE := 6

func _base() -> Dictionary:
	return {"toughness": TOUGH_BASE, "combat_skill": COMBAT_BASE, "speed": SPEED_BASE}

func _find(exact_name: String) -> Dictionary:
	# EXACT match: the table also contains a "Mutant Bruiser" with absolute
	# scores, so a substring search for "Bruiser" picks up the wrong entry and
	# the test fails against correct code.
	var g = _gen()
	for _i in range(400):
		for u in g.roll_unique_individuals({}, "criminal_elements", DIFF_INSANITY, _base()):
			if str(u["name"]) == exact_name:
				return u
	return {}

func test_enemy_heavy_inherits_the_base_profile_unchanged() -> void:
	# Enemy Heavy's row is "-" for Speed, Combat Skill and Toughness.
	var u: Dictionary = _find("Enemy Heavy")
	assert_dict(u).is_not_empty()
	assert_int(u["toughness"]).is_equal(TOUGH_BASE)
	assert_int(u["combat_skill"]).is_equal(COMBAT_BASE)
	assert_int(u["speed"]).is_equal(SPEED_BASE)

func test_enemy_bruiser_takes_the_base_toughness_plus_one() -> void:
	# Enemy Bruiser's row is Toughness "+1" off the base enemy.
	var u: Dictionary = _find("Enemy Bruiser")
	assert_dict(u).is_not_empty()
	assert_int(u["toughness"]).is_equal(TOUGH_BASE + 1)

func test_enemy_boss_takes_base_combat_and_toughness_plus_one() -> void:
	var u: Dictionary = _find("Enemy Boss")
	assert_dict(u).is_not_empty()
	assert_int(u["combat_skill"]).is_equal(COMBAT_BASE + 1)
	assert_int(u["toughness"]).is_equal(TOUGH_BASE + 1)

func test_later_entries_keep_their_absolute_scores() -> void:
	# Everything after the first three carries real numbers and must NOT be
	# rebased onto the enemy being fought (Hired Killer is 5" / +1 / 5).
	var u: Dictionary = _find("Hired Killer")
	assert_dict(u).is_not_empty()
	assert_int(u["toughness"]).is_equal(5)
	assert_int(u["speed"]).is_equal(5)

func test_the_full_book_table_is_reachable() -> void:
	# The pp.105-107 table has 22 entries covering D100 1-100 with no gaps. Roll
	# enough times that a hole in the ranges would surface as a repeat-only set.
	var g = _gen()
	var names := {}
	for _i in range(TRIALS):
		var out: Array = g.roll_unique_individuals({}, "criminal_elements", DIFF_INSANITY)
		for u in out:
			names[u["name"]] = true
	assert_int(names.size()).is_greater(8)
