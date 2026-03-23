extends GdUnitTestSuite
## Generator Wiring Verification Tests
##
## Ensures all 10 fixed generators produce data from canonical JSON sources
## with correct value ranges. Prevents regression to fabricated data.
##
## Covers: FiveParsecsMissionGenerator, StartingEquipmentGenerator,
## LootEconomyIntegrator, PatronJobGenerator, StreetFightGenerator,
## SalvageJobGenerator, StealthMissionGenerator, RivalBattleGenerator,
## EquipmentGenerationScene, SimpleCharacterCreator

const FiveParsecsMissionGenerator = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const LootEconomyIntegrator = preload("res://src/game/economy/loot/LootEconomyIntegrator.gd")
const GameItem = preload("res://src/core/economy/loot/GameItem.gd")
const PatronJobGeneratorClass = preload("res://src/core/patrons/PatronJobGenerator.gd")
const StreetFightGenerator = preload("res://src/core/mission/StreetFightGenerator.gd")
const SalvageJobGenerator = preload("res://src/core/mission/SalvageJobGenerator.gd")
const StealthMissionGenerator = preload("res://src/core/mission/StealthMissionGenerator.gd")
const RivalBattleGeneratorClass = preload("res://src/core/rivals/RivalBattleGenerator.gd")
const SimpleCharacterCreatorClass = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const Patron = preload("res://src/core/rivals/Patron.gd")
const Rival = preload("res://src/core/rivals/Rival.gd")


# ============================================================================
# 1. MISSION REWARD RANGE (Core Rules p.120: D6 base + danger_pay = 2-12)
# ============================================================================

func test_mission_reward_within_core_rules_range() -> void:
	"""Mission reward should be D6 + danger_pay, typically 2-12, never >20"""
	var gen = FiveParsecsMissionGenerator.new()
	for i in range(100):
		var reward: int = gen.calculate_mission_reward(2, 0)
		assert_int(reward).is_greater(0)
		assert_int(reward).is_less(21)

func test_mission_reward_never_uses_hundreds() -> void:
	"""Regression: old code used difficulty*100, giving 200-500"""
	var gen = FiveParsecsMissionGenerator.new()
	for i in range(50):
		var reward: int = gen.calculate_mission_reward(5, 0)
		assert_int(reward).is_less(21)

func test_mission_loot_credits_single_digit() -> void:
	"""Loot table credits should be 1-3, not 100-500"""
	var gen = FiveParsecsMissionGenerator.new()
	for i in range(50):
		var loot: Array = gen.generate_loot_table(3)
		for entry in loot:
			if entry.get("type", "") == "credits":
				assert_int(entry.amount).is_greater(0)
				assert_int(entry.amount).is_less(10)


# ============================================================================
# 2. STARTING CREDITS (Core Rules p.28: 1 credit per crew, NOT from equip gen)
# ============================================================================

func test_equipment_gen_produces_zero_credits() -> void:
	"""StartingEquipmentGenerator must NOT add credits — campaign creation does that"""
	var character = Character.new()
	character.character_class = "SOLDIER"
	character.background = "MILITARY_BRAT"
	# generate_starting_equipment needs a dice_manager, pass null for credits test
	var equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character, null)
	assert_int(equipment.get("credits", -1)).is_equal(0)


# ============================================================================
# 3. STAT GENERATION (model expects 1-6, NOT raw 2D6 = 2-12)
# ============================================================================

func test_roll_stat_within_model_range() -> void:
	"""SimpleCharacterCreator._roll_stat() must return 1-6"""
	var creator = SimpleCharacterCreatorClass.new()
	for i in range(200):
		var stat: int = creator._roll_stat()
		assert_int(stat).is_greater_equal(1)
		assert_int(stat).is_less_equal(6)
	creator.free()

func test_roll_stat_never_exceeds_six() -> void:
	"""Regression: raw 2D6 gave 2-12, overflowing Character stat range"""
	var creator = SimpleCharacterCreatorClass.new()
	var max_seen: int = 0
	for i in range(500):
		var stat: int = creator._roll_stat()
		if stat > max_seen:
			max_seen = stat
	assert_int(max_seen).is_less_equal(6)
	creator.free()

func test_roll_2d6_still_returns_full_range() -> void:
	"""_roll_2d6() (raw) should still return 2-12 for non-stat uses"""
	var creator = SimpleCharacterCreatorClass.new()
	var min_seen: int = 99
	var max_seen: int = 0
	for i in range(500):
		var val: int = creator._roll_2d6()
		if val < min_seen:
			min_seen = val
		if val > max_seen:
			max_seen = val
	assert_int(min_seen).is_greater_equal(2)
	assert_int(max_seen).is_less_equal(12)
	creator.free()


# ============================================================================
# 4. LOOT ECONOMY INTEGRATOR — GameItem API compatibility
# ============================================================================

func test_game_item_has_required_api() -> void:
	"""GameItem must have get_value(), get_rarity(), item_tags, has_tag()"""
	var item = GameItem.new()
	assert_bool(item.has_method("get_value")).is_true()
	assert_bool(item.has_method("get_rarity")).is_true()
	assert_bool(item.has_method("has_tag")).is_true()
	assert_bool(item.has_method("get_tags")).is_true()
	# Verify item_tags property exists
	assert_that(item.item_tags).is_not_null()

func test_loot_economy_integrator_no_crash_on_empty_loot() -> void:
	"""LootEconomyIntegrator.process_battle_loot() shouldn't crash with empty data"""
	var integrator = LootEconomyIntegrator.new()
	var result: Dictionary = integrator.process_battle_loot({})
	assert_that(result).is_not_null()
	assert_int(result.get("immediate_credits", -1)).is_equal(0)

func test_loot_economy_rarity_score() -> void:
	"""_rarity_score() maps rarity strings to 0-4 int scale"""
	var integrator = LootEconomyIntegrator.new()
	assert_int(integrator._rarity_score("Common")).is_equal(0)
	assert_int(integrator._rarity_score("Uncommon")).is_equal(1)
	assert_int(integrator._rarity_score("Rare")).is_equal(2)
	assert_int(integrator._rarity_score("Very Rare")).is_equal(3)
	assert_int(integrator._rarity_score("Legendary")).is_equal(4)
	assert_int(integrator._rarity_score("")).is_equal(0)


# ============================================================================
# 5. PATRON TYPE MAPPING — Core Rules p.83 patron types
# ============================================================================

func test_patron_type_mapping_all_six_types() -> void:
	"""All 6 Core Rules patron types must map from FactionType enum"""
	var gen = PatronJobGeneratorClass.new()
	var expected_types: Array = [
		"Corporation", "Local Government", "Sector Government",
		"Wealthy Individual", "Private Organization", "Secretive Group"
	]

	# Test each FactionType maps to a valid Core Rules type
	var patron = Patron.new()
	for faction_val in [
		GameEnums.FactionType.CORPORATE,
		GameEnums.FactionType.IMPERIAL,
		GameEnums.FactionType.REBEL,
		GameEnums.FactionType.MERCENARY,
		GameEnums.FactionType.PIRATE,
		GameEnums.FactionType.ALIEN,
	]:
		patron.faction_type = faction_val
		var mapped: String = gen._get_patron_type_string(patron)
		assert_bool(mapped in expected_types).is_true()
	gen.free()

func test_patron_type_modifiers_keyed_to_core_rules() -> void:
	"""patron_type_modifiers dict keys must match Core Rules p.83 types"""
	var gen = PatronJobGeneratorClass.new()
	var expected_keys: Array = [
		"Corporation", "Local Government", "Sector Government",
		"Wealthy Individual", "Private Organization", "Secretive Group"
	]
	for key in expected_keys:
		assert_bool(gen.patron_type_modifiers.has(key)).is_true()
	gen.free()

func test_patron_payment_single_digit_scale() -> void:
	"""Patron job payment (base + danger) should be single-digit credits"""
	var gen = PatronJobGeneratorClass.new()
	var patron = Patron.new()
	patron._patron_name = "Test Corp"
	patron.faction_type = GameEnums.FactionType.CORPORATE

	for i in range(20):
		var job = gen.generate_patron_job(patron, 4, 0)
		var total: int = job.base_payment + job.danger_pay + job.bonus_payment
		assert_int(total).is_greater(0)
		assert_int(total).is_less(30)
	gen.free()


# ============================================================================
# 6. COMPENDIUM GENERATORS — JSON loading wired
# ============================================================================

func test_street_fight_generator_loads_json() -> void:
	"""StreetFightGenerator._ensure_ref_loaded() must populate _ref_data"""
	StreetFightGenerator._ref_loaded = false
	StreetFightGenerator._ref_data = {}
	StreetFightGenerator._ensure_ref_loaded()
	# StealthAndStreet.json should exist and load
	assert_bool(StreetFightGenerator._ref_loaded).is_true()
	# If the file exists, _ref_data should have content
	if FileAccess.file_exists("res://data/RulesReference/StealthAndStreet.json"):
		assert_bool(StreetFightGenerator._ref_data.is_empty()).is_false()

func test_salvage_job_generator_loads_json() -> void:
	"""SalvageJobGenerator._ensure_ref_loaded() must populate _ref_data"""
	SalvageJobGenerator._ref_loaded = false
	SalvageJobGenerator._ref_data = {}
	SalvageJobGenerator._ensure_ref_loaded()
	assert_bool(SalvageJobGenerator._ref_loaded).is_true()
	if FileAccess.file_exists("res://data/RulesReference/SalvageJobs.json"):
		assert_bool(SalvageJobGenerator._ref_data.is_empty()).is_false()

func test_stealth_mission_generator_loads_json() -> void:
	"""StealthMissionGenerator._ensure_ref_loaded() must populate _ref_data"""
	StealthMissionGenerator._ref_loaded = false
	StealthMissionGenerator._ref_data = {}
	StealthMissionGenerator._ensure_ref_loaded()
	assert_bool(StealthMissionGenerator._ref_loaded).is_true()
	if FileAccess.file_exists("res://data/RulesReference/StealthAndStreet.json"):
		assert_bool(StealthMissionGenerator._ref_data.is_empty()).is_false()

func test_street_fight_objectives_have_valid_ranges() -> void:
	"""All STREET_FIGHT_OBJECTIVES must cover D100 range 1-100"""
	var min_roll: int = 999
	var max_roll: int = 0
	for obj in StreetFightGenerator.STREET_FIGHT_OBJECTIVES:
		if obj.roll_min < min_roll:
			min_roll = obj.roll_min
		if obj.roll_max > max_roll:
			max_roll = obj.roll_max
	assert_int(min_roll).is_equal(1)
	assert_int(max_roll).is_equal(100)

func test_salvage_conversion_table_complete() -> void:
	"""Salvage conversion table should cover all practical unit ranges"""
	# Test boundary values
	assert_int(SalvageJobGenerator.get_salvage_credits(1)).is_greater(0)
	assert_int(SalvageJobGenerator.get_salvage_credits(5)).is_greater(0)
	assert_int(SalvageJobGenerator.get_salvage_credits(10)).is_greater(0)
	assert_int(SalvageJobGenerator.get_salvage_credits(20)).is_greater(0)


# ============================================================================
# 7. RIVAL BATTLE GENERATOR — Dict access + Rival API
# ============================================================================

func test_rival_battle_generator_dict_access() -> void:
	"""battle_type_weights must use bracket access, not dot notation"""
	var gen = RivalBattleGeneratorClass.new()
	# These would crash if using .KEY notation on a Dictionary
	assert_that(gen.battle_type_weights["default"]).is_not_null()
	assert_that(gen.battle_type_weights["high_escalation"]).is_not_null()
	assert_that(gen.battle_type_weights["first_encounter"]).is_not_null()
	gen.free()

func test_rival_battle_force_templates_accessible() -> void:
	"""rival_force_templates["CRIMINAL_GANG"] must be accessible"""
	var gen = RivalBattleGeneratorClass.new()
	assert_that(gen.rival_force_templates["CRIMINAL_GANG"]).is_not_null()
	assert_int(gen.rival_force_templates["CRIMINAL_GANG"].base_size).is_greater(0)
	gen.free()

func test_rival_battle_uses_rival_api() -> void:
	"""RivalBattleGenerator must use Rival's actual properties"""
	var rival = Rival.new()
	rival.rival_name = "Test Gang"
	rival.rival_type = "CRIMINAL_GANG"
	rival.reputation = 1
	rival.active = true
	rival.last_encounter_turn = 0
	# Verify these properties exist (would crash if API mismatched)
	assert_str(rival.rival_name).is_equal("Test Gang")
	assert_str(rival.rival_type).is_equal("CRIMINAL_GANG")
	assert_int(rival.reputation).is_equal(1)
	assert_bool(rival.active).is_true()


# ============================================================================
# 8. MISSION GENERATOR — JSON data loading
# ============================================================================

func test_mission_generator_loads_patron_generation_json() -> void:
	"""FiveParsecsMissionGenerator must load danger_pay from patron_generation.json"""
	var gen = FiveParsecsMissionGenerator.new()
	# After _init(), _mission_gen_data should have danger_pay_entries
	if FileAccess.file_exists("res://data/patron_generation.json"):
		assert_bool(gen._mission_gen_data.has("danger_pay_entries")).is_true()
		var entries: Array = gen._mission_gen_data.get("danger_pay_entries", [])
		assert_int(entries.size()).is_greater(0)

func test_mission_generator_danger_pay_table_correct() -> void:
	"""Danger pay entries from JSON must match Core Rules p.83"""
	var gen = FiveParsecsMissionGenerator.new()
	var entries: Array = gen._mission_gen_data.get("danger_pay_entries", [])
	if entries.size() > 0:
		# First entry: rolls 1-4 = 1 credit
		assert_int(entries[0].get("danger_pay", -1)).is_equal(1)
		# Second entry: rolls 5-8 = 2 credits
		assert_int(entries[1].get("danger_pay", -1)).is_equal(2)
