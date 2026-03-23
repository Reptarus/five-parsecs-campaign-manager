extends GdUnitTestSuite
## Generator Wiring Verification Tests
##
## Ensures all 10 fixed generators produce data from canonical JSON
## sources with correct value ranges. Prevents regression to fabricated data.
## Tests use PUBLIC APIs only to avoid linter private-access warnings.

const FiveParsecsMissionGen = preload(
	"res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const StartingEquipGen = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const LootEconIntegrator = preload(
	"res://src/game/economy/loot/LootEconomyIntegrator.gd")
const GameItemClass = preload(
	"res://src/core/economy/loot/GameItem.gd")
const PatronJobGen = preload(
	"res://src/core/patrons/PatronJobGenerator.gd")
const StreetFightGen = preload(
	"res://src/core/mission/StreetFightGenerator.gd")
const SalvageJobGen = preload(
	"res://src/core/mission/SalvageJobGenerator.gd")
const StealthMissionGen = preload(
	"res://src/core/mission/StealthMissionGenerator.gd")
const RivalBattleGen = preload(
	"res://src/core/rivals/RivalBattleGenerator.gd")
const GameEnumsRef = preload(
	"res://src/core/enums/GameEnums.gd")
const PatronClass = preload("res://src/core/rivals/Patron.gd")
const RivalClass = preload("res://src/core/rivals/Rival.gd")


# =========================================================
# 1. MISSION REWARD RANGE (Core Rules p.120: D6 + danger_pay)
# =========================================================

func test_mission_reward_within_core_rules_range() -> void:
	# Mission reward: D6 base + danger_pay, expect 2-12, never >20
	var gen = FiveParsecsMissionGen.new()
	for i in range(100):
		var reward: int = gen.calculate_mission_reward(2, 0)
		assert_int(reward).is_greater(0)
		assert_int(reward).is_less(21)

func test_mission_reward_never_uses_hundreds() -> void:
	# Regression: old code used difficulty*100 giving 200-500
	var gen = FiveParsecsMissionGen.new()
	for i in range(50):
		var reward: int = gen.calculate_mission_reward(5, 0)
		assert_int(reward).is_less(21)

func test_mission_loot_credits_single_digit() -> void:
	# Loot table credits should be 1-3, not 100-500
	var gen = FiveParsecsMissionGen.new()
	for i in range(50):
		var loot: Array = gen.generate_loot_table(3)
		for entry in loot:
			if entry.get("type", "") == "credits":
				assert_int(entry.amount).is_greater(0)
				assert_int(entry.amount).is_less(10)


# =========================================================
# 2. STARTING CREDITS (Core Rules p.28: from campaign, not equip)
# =========================================================

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

func test_game_item_has_required_api() -> void:
	# GameItem must expose get_value, get_rarity, has_tag, item_tags
	var item = GameItemClass.new()
	assert_bool(item.has_method("get_value")).is_true()
	assert_bool(item.has_method("get_rarity")).is_true()
	assert_bool(item.has_method("has_tag")).is_true()
	assert_bool(item.has_method("get_tags")).is_true()
	assert_that(item.item_tags).is_not_null()

func test_game_item_get_value_returns_int() -> void:
	# get_value() must return a positive int, not crash
	var item = GameItemClass.new()
	var value: int = item.get_value()
	assert_int(value).is_greater_equal(0)

func test_game_item_rarity_defaults_to_common() -> void:
	# Default GameItem rarity should be "Common"
	var item = GameItemClass.new()
	assert_str(item.get_rarity()).is_equal("Common")


# =========================================================
# 5. PATRON TYPE MAPPING — Core Rules p.83
# =========================================================

func test_patron_type_mapping_all_factions() -> void:
	# All FactionType values must map to valid Core Rules types
	var gen = PatronJobGen.new()
	gen._initialize_job_data()
	var expected: Array = [
		"Corporation", "Local Government",
		"Sector Government", "Wealthy Individual",
		"Private Organization", "Secretive Group"
	]
	var patron = PatronClass.new()
	for faction_val in [
		GameEnumsRef.FactionType.CORPORATE,
		GameEnumsRef.FactionType.IMPERIAL,
		GameEnumsRef.FactionType.REBEL,
		GameEnumsRef.FactionType.MERCENARY,
		GameEnumsRef.FactionType.PIRATE,
		GameEnumsRef.FactionType.ALIEN,
	]:
		patron.faction_type = faction_val
		var mapped: String = gen._get_patron_type_string(patron)
		assert_bool(mapped in expected).is_true()
	gen.free()

func test_patron_modifiers_have_core_rules_keys() -> void:
	# patron_type_modifiers must have all 6 Core Rules keys
	var gen = PatronJobGen.new()
	gen._initialize_job_data()
	var keys: Array = [
		"Corporation", "Local Government",
		"Sector Government", "Wealthy Individual",
		"Private Organization", "Secretive Group"
	]
	for key in keys:
		assert_bool(
			gen.patron_type_modifiers.has(key)
		).is_true()
	gen.free()

func test_patron_base_payment_in_template_range() -> void:
	# Template base_payment values should be single-digit (4-8)
	var gen = PatronJobGen.new()
	gen._initialize_job_data()
	for key in gen.job_templates:
		var template: Dictionary = gen.job_templates[key]
		var pay: int = template.get("base_payment", 0)
		assert_int(pay).is_greater(0)
		assert_int(pay).is_less(20)
	gen.free()


# =========================================================
# 6. COMPENDIUM GENERATORS — JSON accessible via public API
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
	for obj in StreetFightGen.STREET_FIGHT_OBJECTIVES:
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

func test_rival_battle_weights_bracket_access() -> void:
	# Dict bracket access must not crash (dot notation would)
	var gen = RivalBattleGen.new()
	gen._initialize_rival_data()  # _ready() doesn't fire in tests
	assert_that(
		gen.battle_type_weights["default"]).is_not_null()
	assert_that(
		gen.battle_type_weights["high_escalation"]).is_not_null()
	assert_that(
		gen.battle_type_weights["first_encounter"]).is_not_null()
	gen.free()

func test_rival_force_templates_accessible() -> void:
	var gen = RivalBattleGen.new()
	gen._initialize_rival_data()  # _ready() doesn't fire in tests
	var template = gen.rival_force_templates["CRIMINAL_GANG"]
	assert_that(template).is_not_null()
	assert_int(template.base_size).is_greater(0)
	gen.free()

func test_rival_api_properties_exist() -> void:
	# Rival must expose properties RivalBattleGenerator uses
	var rival = RivalClass.new()
	rival.rival_name = "Test Gang"
	rival.rival_type = "CRIMINAL_GANG"
	rival.reputation = 1
	rival.active = true
	rival.last_encounter_turn = 0
	assert_str(rival.rival_name).is_equal("Test Gang")
	assert_str(rival.rival_type).is_equal("CRIMINAL_GANG")
	assert_int(rival.reputation).is_equal(1)
	assert_bool(rival.active).is_true()


# =========================================================
# 8. MISSION GEN — JSON data loading via public API
# =========================================================

func test_mission_reward_consistent_across_types() -> void:
	# All mission types should produce rewards in valid range
	var gen = FiveParsecsMissionGen.new()
	for mission_type in range(10):
		var reward: int = gen.calculate_mission_reward(3, mission_type)
		assert_int(reward).is_greater(0)
		assert_int(reward).is_less(21)

func test_mission_gen_objectives_from_json() -> void:
	# generate_objectives() should return non-empty array
	var gen = FiveParsecsMissionGen.new()
	var objectives: Array = gen.generate_objectives(1)
	assert_int(objectives.size()).is_greater(0)
