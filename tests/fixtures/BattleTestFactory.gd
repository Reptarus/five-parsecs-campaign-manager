class_name BattleTestFactory
extends RefCounted

## Factory for creating test data for battle system tests
## Provides consistent mock data without requiring actual game resources
## UPDATED: Uses correct stat names matching Character.gd (combat, not combat_skill)

#region Character Creation

## Create a test character with specified stats
## NOTE: Uses correct stat names matching Character.gd
static func create_character(
	name: String = "Test Character",
	combat: int = 2,           # CORRECT: matches Character.gd (NOT combat_skill)
	toughness: int = 3,
	savvy: int = 1
) -> Dictionary:
	return {
		"character_id": "char_%d_%d" % [Time.get_ticks_msec(), randi() % 10000],
		"id": "char_" + str(randi()),  # Legacy compatibility
		"name": name,
		"character_name": name,  # Compatibility alias

		# Character Properties - matching Character.gd
		"background": "COLONIST",
		"motivation": "SURVIVAL",
		"origin": "HUMAN",
		"character_class": "BASELINE",

		# Core Stats - CORRECT names matching Character.gd
		"combat": combat,          # CORRECT: NOT combat_skill
		"toughness": toughness,
		"savvy": savvy,
		"reactions": 1,
		"tech": 1,                 # ADDED: missing stat
		"move": 4,                 # ADDED: missing stat
		"speed": 4,
		"luck": 0,

		# Health
		"health": toughness + 2,
		"max_health": toughness + 2,

		# Equipment & State
		"armor": "none",
		"equipment": [] as Array[String],
		"is_captain": false,
		"status": "ACTIVE",
		"experience": 0,

		# Combat state
		"in_cover": false,
		"elevated": false,
		"is_stunned": false,
		"is_suppressed": false
	}

## Create a standard crew for testing
static func create_test_crew(count: int = 4) -> Array[Dictionary]:
	var crew: Array[Dictionary] = []
	var names := ["Captain", "Soldier", "Medic", "Engineer", "Scout", "Heavy"]
	var backgrounds := ["MILITARY", "MILITARY", "MEDIC", "ENGINEER", "EXPLORER", "MILITARY"]

	for i in range(mini(count, names.size())):
		var char_data := create_character(
			names[i],
			2 + (i % 3),  # Varying combat 2-4
			3,
			1 + (i % 2)  # Varying savvy 1-2
		)
		char_data["character_id"] = "crew_%d" % i
		char_data["id"] = "crew_" + str(i)
		char_data["background"] = backgrounds[i]
		if i == 0:
			char_data["is_captain"] = true
		crew.append(char_data)

	return crew

## Create test enemy
## NOTE: Uses correct stat names matching Character.gd
static func create_enemy(
	enemy_type: String = "Raider",
	combat: int = 1,           # CORRECT: matches Character.gd (NOT combat_skill)
	toughness: int = 3,
	count: int = 1
) -> Dictionary:
	return {
		"id": "enemy_" + str(randi()),
		"enemy_type": enemy_type,
		"name": enemy_type,

		# Stats - CORRECT names matching Character.gd
		"combat": combat,          # CORRECT: NOT combat_skill
		"toughness": toughness,
		"reactions": 1,
		"speed": 4,
		"savvy": 1,
		"tech": 1,
		"move": 4,

		# Health
		"health": toughness,
		"max_health": toughness,

		# State
		"armor": "none",
		"count": count,
		"in_cover": false,
		"elevated": false,
		"ai_type": "AGGRESSIVE"
	}

## Create a standard enemy force
static func create_test_enemies(count: int = 3) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	var types := ["Raider", "Thug", "Pirate", "Mercenary", "Cultist"]

	for i in range(count):
		var enemy := create_enemy(
			types[i % types.size()],
			1,  # Low combat skill
			3 + (i % 2)  # Toughness 3-4
		)
		enemy["id"] = "enemy_" + str(i)
		enemies.append(enemy)

	return enemies

#endregion

#region Weapon Creation

## Create test weapon
static func create_weapon(
	name: String = "Rifle",
	damage: int = 1,
	weapon_range: int = 24,
	penetration: int = 0,
	traits: Array = []
) -> Dictionary:
	return {
		"name": name,
		"damage": damage,
		"range": weapon_range,
		"penetration": penetration,
		"traits": traits
	}

## Create standard weapons
static func create_rifle() -> Dictionary:
	return create_weapon("Rifle", 1, 24)

static func create_pistol() -> Dictionary:
	return create_weapon("Pistol", 1, 8, 0, ["snap_shot"])

static func create_shotgun() -> Dictionary:
	return create_weapon("Shotgun", 2, 6, 0, ["devastating"])

static func create_heavy_weapon() -> Dictionary:
	return create_weapon("Heavy Bolter", 2, 36, 1, ["heavy"])

static func create_melee_weapon() -> Dictionary:
	return create_weapon("Combat Blade", 1, 0, 0, ["melee"])

#endregion

#region Mission Creation

## Create test mission
static func create_mission(
	mission_type: String = "patrol",
	difficulty: int = 2,
	base_payment: int = 10
) -> Dictionary:
	return {
		"id": "mission_" + str(randi()),
		"title": "Test Mission - " + mission_type.capitalize(),
		"description": "A test mission for unit testing",
		"mission_type": mission_type,
		"difficulty": difficulty,
		"battle_type": 0,  # Standard
		"base_payment": base_payment,
		"danger_pay": difficulty * 2,
		"is_rival_battle": false,
		"rival_id": "",
		"is_patron_mission": false,
		"patron_id": "",
		"victory_conditions": [{"type": "eliminate_enemies"}],
		"special_conditions": []
	}

#endregion

#region Battle Setup Creation

## Create complete BattleSetupData
static func create_battle_setup(
	crew_count: int = 4,
	enemy_count: int = 3
) -> Dictionary:
	return {
		"crew": create_test_crew(crew_count),
		"enemies": create_test_enemies(enemy_count),
		"mission": create_mission(),
		"deployment_condition": "standard",
		"deployment_condition_effect": "Standard deployment rules apply",
		"notable_sights": [],
		"initiative_seized": false,
		"initiative_roll": 7,
		"initiative_savvy_bonus": 2,
		"terrain_pieces": [],
		"terrain_layout_type": 0
	}

#endregion

#region Battle Results Creation

## Create test battle results
static func create_battle_results(
	outcome: String = "victory",
	enemies_defeated: int = 3,
	crew_count: int = 4
) -> Dictionary:
	var crew_ids: Array[String] = []
	for i in range(crew_count):
		crew_ids.append("crew_" + str(i))

	return {
		"outcome": outcome,
		"battle_id": "battle_test_" + str(randi()),
		"mission_id": "mission_test",
		"rounds_fought": 4,
		"turns_elapsed": 16,
		"enemies_defeated": enemies_defeated,
		"enemies_fled": 0,
		"hold_field": outcome == "victory",
		"crew_participants": crew_ids,
		"casualties": [],
		"injuries": [],
		"base_payment": 10,
		"danger_pay": 4,
		"bonus_credits": 0,
		"loot_rolls": 2,
		"loot_items": [],
		"xp_earned": {},
		"story_points": 1
	}

## Create results with casualties
static func create_results_with_casualties() -> Dictionary:
	var results := create_battle_results("victory", 3, 4)
	results["casualties"] = [
		{"crew_id": "crew_3", "type": "critically_wounded", "round": 3, "cause": "enemy_fire"}
	]
	results["injuries"] = [
		{"crew_id": "crew_1", "injury_type": "light_wound", "damage": 1, "recovery_turns": 1}
	]
	return results

## Create defeat results
static func create_defeat_results() -> Dictionary:
	var results := create_battle_results("defeat", 1, 4)
	results["hold_field"] = false
	results["casualties"] = [
		{"crew_id": "crew_2", "type": "killed", "round": 2, "cause": "enemy_fire"},
		{"crew_id": "crew_3", "type": "missing", "round": 3, "cause": "fled"}
	]
	return results

#endregion

#region Dice Roller Mocks

## Create a deterministic dice roller for testing
## Returns the same values in sequence
static func create_fixed_roller(values: Array) -> Callable:
	var index := 0
	return func() -> int:
		var result: int = values[index % values.size()]
		index += 1
		return result

## Create roller that always returns same value
static func create_constant_roller(value: int) -> Callable:
	return func() -> int:
		return value

## Create roller that returns random d6 values
static func create_random_roller() -> Callable:
	return func() -> int:
		return randi_range(1, 6)

#endregion

#region Combat Scenario Creation

## Create attacker data for combat resolution
static func create_attacker(
	combat: int = 2,           # CORRECT: matches Character.gd (NOT combat_skill)
	range_to_target: float = 12.0,
	elevated: bool = false
) -> Dictionary:
	var char_data := create_character("Attacker", combat)
	char_data["range_to_target"] = range_to_target
	char_data["elevated"] = elevated
	return char_data

## Create target data for combat resolution
static func create_target(
	toughness: int = 3,
	armor: String = "none",
	in_cover: bool = false,
	elevated: bool = false
) -> Dictionary:
	var char_data := create_character("Target", 1, toughness)
	char_data["armor"] = armor
	char_data["in_cover"] = in_cover
	char_data["elevated"] = elevated
	return char_data

#endregion

#region Post-Battle Data

## Create crew results for XP calculation
static func create_crew_xp_data(crew_count: int = 4) -> Array:
	var results: Array = []
	for i in range(crew_count):
		results.append({
			"id": "crew_" + str(i),
			"participated": true,
			"kills": i % 2,  # Alternating 0 and 1 kills
			"injured": i == crew_count - 1,  # Last crew member injured
			"achievements": []
		})
	return results

#endregion

#region Validation Helpers

## Check if character data has required fields
## Uses CORRECT stat names matching Character.gd
static func is_valid_character(char_data: Dictionary) -> bool:
	var required := ["combat", "toughness", "savvy", "reactions", "tech", "move"]  # CORRECT names
	for field in required:
		if not char_data.has(field):
			return false
	return true

## Check if weapon data has required fields
static func is_valid_weapon(weapon_data: Dictionary) -> bool:
	var required := ["damage", "range"]
	for field in required:
		if not weapon_data.has(field):
			return false
	return true

#endregion
