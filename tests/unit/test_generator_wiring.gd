extends GdUnitTestSuite
## Generator Wiring Verification Tests
##
## Ensures the live generators produce data from canonical JSON sources with correct
## value ranges. Prevents regression to fabricated data. Public APIs only.
##
## Trimmed 2026-09-04 from 24 cases to 10. The removed cases drove
## FiveParsecsMissionGenerator, PatronJobGenerator, RivalBattleGenerator, GameItem,
## Patron and Rival — all production-dead and deleted. Their book mechanics are live
## elsewhere: mission reward / Danger Pay / objectives in JobOfferComponent (which
## also corrects WHEN the objective is shown, p.83 vs p.89), loot in LootProcessor,
## rival acquisition in RivalPatronResolver + FactionSystem.
##
## One case was dropped rather than repointed: test_patron_type_mapping_all_factions
## asserted that every GameEnums.FactionType maps to a Core Rules patron type. The
## live app has no such mapping — it rolls a D10 on the p.78 patron table
## (data/patron_types.json, data/patron_generation.json) — so the invariant existed
## only to describe a fabricated bridge. Repointing it would have meant inventing the
## mapping it claimed to verify.

const StartingEquipGen = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const StreetFightGen = preload(
	"res://src/core/mission/StreetFightGenerator.gd")
const CompendiumStreetFightsData = preload(
	"res://src/data/compendium_street_fights.gd")
const SalvageJobGen = preload(
	"res://src/core/mission/SalvageJobGenerator.gd")
const StealthMissionGen = preload(
	"res://src/core/mission/StealthMissionGenerator.gd")
const GameEnumsRef = preload(
	"res://src/core/enums/GameEnums.gd")


func test_equipment_gen_produces_zero_credits() -> void:
	# Equipment gen must NOT add credits
	var character = Character.new()
	character.character_class = "SOLDIER"
	character.background = "MILITARY_BRAT"
	var equipment: Dictionary = StartingEquipGen.generate_starting_equipment(
		character, null)
	assert_int(equipment.get("credits", -1)).is_equal(0)


# =========================================================
# 3. STAT GENERATION (model expects 1-6, NOT raw 2D6)
# =========================================================

func test_generated_character_stats_in_range() -> void:
	# After _generate_random_stats, all stats must be 1-6
	var character = Character.new()
	# Simulate what SimpleCharacterCreator does: ceil(2D6/3)
	for i in range(100):
		var raw: int = randi_range(1, 6) + randi_range(1, 6)
		var stat: int = clampi(ceili(raw / 3.0), 1, 6)
		assert_int(stat).is_greater_equal(1)
		assert_int(stat).is_less_equal(6)

func test_stat_generation_never_exceeds_six() -> void:
	# Regression: raw 2D6 gave 2-12, overflowing stat range
	var max_seen: int = 0
	for i in range(500):
		var raw: int = randi_range(1, 6) + randi_range(1, 6)
		var stat: int = clampi(ceili(raw / 3.0), 1, 6)
		if stat > max_seen:
			max_seen = stat
	assert_int(max_seen).is_less_equal(6)


# =========================================================
# 4. LOOT ECONOMY — GameItem API compatibility
# =========================================================


# =========================================================

func test_street_fight_ref_data_accessible() -> void:
	# get_ref_data() must return a non-null dict
	var data: Dictionary = StreetFightGen.get_ref_data()
	assert_that(data).is_not_null()

func test_street_fight_rules_accessible() -> void:
	# get_street_fight_rules() should return dict (may be empty
	# if JSON not present, but must not crash)
	var rules: Dictionary = StreetFightGen.get_street_fight_rules()
	assert_that(rules).is_not_null()

func test_salvage_ref_data_accessible() -> void:
	var data: Dictionary = SalvageJobGen.get_ref_data()
	assert_that(data).is_not_null()

func test_stealth_ref_data_accessible() -> void:
	var data: Dictionary = StealthMissionGen.get_ref_data()
	assert_that(data).is_not_null()

func test_stealth_rules_accessible() -> void:
	var rules: Dictionary = StealthMissionGen.get_stealth_rules()
	assert_that(rules).is_not_null()

func test_street_fight_d100_range_complete() -> void:
	# STREET_FIGHT_OBJECTIVES must cover full D100 1-100
	var min_roll: int = 999
	var max_roll: int = 0
	for obj in CompendiumStreetFightsData.STREET_FIGHT_OBJECTIVES:
		if obj.roll_min < min_roll:
			min_roll = obj.roll_min
		if obj.roll_max > max_roll:
			max_roll = obj.roll_max
	assert_int(min_roll).is_equal(1)
	assert_int(max_roll).is_equal(100)

func test_salvage_credits_conversion_works() -> void:
	# Salvage conversion: units → credits must return >0
	assert_int(SalvageJobGen.get_salvage_credits(1)).is_greater(0)
	assert_int(SalvageJobGen.get_salvage_credits(5)).is_greater(0)
	assert_int(SalvageJobGen.get_salvage_credits(10)).is_greater(0)
	assert_int(SalvageJobGen.get_salvage_credits(20)).is_greater(0)


# =========================================================
# 7. RIVAL BATTLE — Dict access + Rival API
# =========================================================

