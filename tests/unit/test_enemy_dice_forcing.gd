extends GdUnitTestSuite
## Every book table EnemyGenerator rolls can be forced from a debug build.
##
## The p.63 enemy count, the p.94 encounter column, the per-category enemy table,
## the p.104 weapon tables and the pp.105-107 Unique Individuals all rolled with a
## raw randi(), so DiceManager.queue_forced_result() could not reach them and a rare
## row (a Unique Individual, a Roving Threat) could only be walked on a device by
## luck. Each case forces two values that land in DIFFERENT rows, so an unrouted
## random roll passes only by matching both by chance.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const NORMAL := 2

var _gen: EnemyGenerator
var _dm: Node
var _prev_campaign = null


func before_test() -> void:
	_dm = get_node("/root/DiceManager")
	_dm.clear_forced_results()
	# A campaign with no difficulty toggles, so Strength-adjusted Enemies (which
	# replaces the count roll) cannot be on from whatever an earlier suite loaded.
	_prev_campaign = get_node("/root/GameState").current_campaign
	get_node("/root/GameState").current_campaign = CampaignCore.new()
	_gen = auto_free(EnemyGenerator.new())


func after_test() -> void:
	_dm.clear_forced_results()
	get_node("/root/GameState").current_campaign = _prev_campaign


func _force(key: String, value: int) -> void:
	_dm.queue_forced_result(key, value)


func test_the_enemy_count_dice_can_be_forced() -> void:
	# p.63: crew 6 rolls 2D6 and picks the higher, crew 4 picks the lower.
	_force("Enemy Count", 2)
	_force("Enemy Count", 5)
	assert_int(_gen._calculate_enemy_count(NORMAL, 6)).is_equal(5)
	_force("Enemy Count", 6)
	_force("Enemy Count", 3)
	assert_int(_gen._calculate_enemy_count(NORMAL, 4)).is_equal(3)


func test_the_encounter_column_can_be_forced() -> void:
	# p.94 Opportunity column: 01-30 Criminal Elements, 81-00 Roving Threats.
	_force("Encounter Category", 5)
	assert_str(_gen._roll_encounter_category("opportunity")).is_equal("criminal_elements")
	_force("Encounter Category", 95)
	assert_str(_gen._roll_encounter_category("opportunity")).is_equal("roving_threats")


func test_the_enemy_type_can_be_forced() -> void:
	# Criminal Elements: 01-10 Gangers, 11-19 Punks.
	_force("Encounter Enemy Type", 3)
	assert_str(str(_gen._roll_core_enemy_in_category("criminal_elements").get("name"))) \
		.is_equal("Gangers")
	_force("Encounter Enemy Type", 15)
	assert_str(str(_gen._roll_core_enemy_in_category("criminal_elements").get("name"))) \
		.is_equal("Punks")


func test_the_enemy_weapon_table_can_be_forced() -> void:
	# p.104 basic table, column 1: a 1 is a Scrap Pistol, a 3 a Colony Rifle.
	_force("Enemy Weapon", 1)
	assert_array(_gen._roll_on_weapon_table("basic", "weapon_1")).contains(["Scrap Pistol"])
	_force("Enemy Weapon", 3)
	assert_array(_gen._roll_on_weapon_table("basic", "weapon_1")).contains(["Colony Rifle"])


func test_the_unique_individual_type_can_be_forced() -> void:
	# pp.105-107: 01-06 Enemy Bruiser, 07-12 Enemy Heavy.
	var table: Array = _gen.enemy_data.get("unique_individuals", [])
	assert_bool(table.is_empty()).is_false()
	_force("Unique Individual Type", 2)
	assert_str(str(_gen._roll_unique_individual_entry(table).get("id"))).is_equal("enemy_bruiser")
	_force("Unique Individual Type", 9)
	assert_str(str(_gen._roll_unique_individual_entry(table).get("id"))).is_equal("enemy_heavy")


func test_the_unique_individual_roll_can_be_forced() -> void:
	# p.93: 2D6 9+ (Hired Muscle) brings a Unique Individual. 6+6 always passes;
	# 1+1 never does, so the two arms disagree.
	_force("Unique Individual: die 1", 6)
	_force("Unique Individual: die 2", 6)
	var hit: Array = _gen.roll_unique_individuals({}, "hired_muscle", NORMAL)
	assert_int(hit.size()).is_greater(0)
	_force("Unique Individual: die 1", 1)
	_force("Unique Individual: die 2", 1)
	var miss: Array = _gen.roll_unique_individuals({}, "hired_muscle", NORMAL)
	assert_int(miss.size()).is_equal(0)
