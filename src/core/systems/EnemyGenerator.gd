class_name EnemyGenerator
extends Resource

## Enemy Generation System for Five Parsecs Campaign Manager
## Generates appropriate enemies based on mission type, difficulty, and world conditions

signal enemies_generated(enemies: Array[Resource])

# Enemy types from Five Parsecs rules
var enemy_categories = {
	"criminal": ["Thug", "Gang Leader", "Crime Boss", "Hired Gun", "Smuggler"],
	"alien": ["K'Erin Warrior", "Swift Scout", "Engineer Tech", "Precursor", "Soulless"],
	"hostile": ["Converted", "Swarm Warrior", "Pirate", "Raider", "Mercenary"],
	"security": ["Unity Guard", "Corporate Security", "Local Militia", "Police Officer"],
	"wildlife": ["Predator", "Pack Hunter", "Giant Insect", "Toxic Creature"]
}

var enemy_stats_base = {
	"Thug": {"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Blade", "Handgun"]},
	"Gang Leader": {"combat_skill": 2, "toughness": 4, "speed": 4, "weapons": ["Auto Pistol", "Blade"]},
	"K'Erin Warrior": {"combat_skill": 3, "toughness": 4, "speed": 5, "weapons": ["Blade", "Handgun"]},
	"Unity Guard": {"combat_skill": 2, "toughness": 4, "speed": 4, "weapons": ["Military Rifle", "Armor"]},
	"Pirate": {"combat_skill": 2, "toughness": 3, "speed": 4, "weapons": ["Shotgun", "Blade"]},
	"Converted": {"combat_skill": 2, "toughness": 5, "speed": 3, "weapons": ["Bio Weapon", "Armor"]},
	"Predator": {"combat_skill": 2, "toughness": 4, "speed": 6, "weapons": ["Natural Weapons"]}
}

func generate_enemies_for_mission(mission: Resource, crew_size: int = 4) -> Array[Resource]:
	"""Generate appropriate enemies for a mission based on Five Parsecs rules"""
	var enemies: Array[Resource] = []
	
	var mission_type = mission.get_meta("mission_type") if mission.has_method("get_meta") else "Patrol"
	var difficulty = mission.get_meta("difficulty") if mission.has_method("get_meta") else 1
	
	var enemy_category = _determine_enemy_category(mission_type)
	var enemy_count = _calculate_enemy_count(difficulty, crew_size)
	
	for i in range(enemy_count):
		var enemy = _create_enemy(enemy_category, difficulty)
		enemies.append(enemy)
	
	enemies_generated.emit(enemies)
	return enemies

func _determine_enemy_category(mission_type: String) -> String:
	"""Determine enemy category based on mission type"""
	match mission_type:
		"Patrol", "Investigate":
			return ["criminal", "hostile"].pick_random()
		"Hunt", "Bounty":
			return ["criminal", "alien"].pick_random()
		"Guard", "Defend":
			return ["hostile", "criminal"].pick_random()
		"Deliver", "Trade":
			return ["criminal", "security"].pick_random()
		"Explore":
			return ["wildlife", "alien", "hostile"].pick_random()
		"Salvage":
			return ["criminal", "wildlife"].pick_random()
		_:
			return "criminal"

func _calculate_enemy_count(difficulty: int, crew_size: int) -> int:
	"""Calculate enemy count based on difficulty and crew size"""
	var base_count = crew_size
	
	match difficulty:
		1: # Easy
			return max(1, base_count - 1)
		2: # Medium
			return base_count
		3: # Hard
			return base_count + 1
		_:
			return base_count

func _create_enemy(category: String, difficulty: int) -> Resource:
	"""Create a single enemy of specified category and difficulty"""
	var enemy = Resource.new()
	
	# Select enemy type from category
	var enemy_types = enemy_categories.get(category, ["Thug"])
	var enemy_type = enemy_types.pick_random()
	
	# Get base stats
	var base_stats = enemy_stats_base.get(enemy_type, {
		"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Handgun"]
	})
	
	# Apply difficulty modifiers
	var modified_stats = _apply_difficulty_modifiers(base_stats, difficulty)
	
	# Set enemy properties
	enemy.set_meta("name", enemy_type)
	enemy.set_meta("category", category)
	enemy.set_meta("combat_skill", modified_stats.combat_skill)
	enemy.set_meta("toughness", modified_stats.toughness)
	enemy.set_meta("speed", modified_stats.speed)
	enemy.set_meta("weapons", modified_stats.weapons)
	enemy.set_meta("difficulty", difficulty)
	
	return enemy

func _apply_difficulty_modifiers(base_stats: Dictionary, difficulty: int) -> Dictionary:
	"""Apply difficulty modifiers to enemy stats"""
	var modified = base_stats.duplicate()
	
	match difficulty:
		1: # Easy - reduce stats slightly
			modified.combat_skill = max(0, modified.combat_skill - 1)
			modified.toughness = max(1, modified.toughness - 1)
		3: # Hard - increase stats
			modified.combat_skill += 1
			modified.toughness += 1
			# Add better weapons for hard enemies
			if modified.weapons.size() == 1:
				modified.weapons.append("Armor")
	
	return modified

func generate_random_encounter() -> Array[Resource]:
	"""Generate a random encounter for unexpected battles"""
	var encounter_types = ["criminal", "wildlife", "hostile"]
	var category = encounter_types.pick_random()
	var count = randi_range(1, 3)
	var difficulty = randi_range(1, 2) # Random encounters are usually easier
	
	var enemies: Array[Resource] = []
	for i in range(count):
		var enemy = _create_enemy(category, difficulty)
		enemies.append(enemy)
	
	return enemies

func get_enemy_description(enemy: Resource) -> String:
	"""Get a description of an enemy for UI display"""
	var name = enemy.get_meta("name") if enemy.has_method("get_meta") else "Unknown"
	var combat = enemy.get_meta("combat_skill") if enemy.has_method("get_meta") else 1
	var toughness = enemy.get_meta("toughness") if enemy.has_method("get_meta") else 3
	var weapons = enemy.get_meta("weapons") if enemy.has_method("get_meta") else []
	
	var weapon_text = weapons[0] if weapons.size() > 0 else "Unarmed"
	
	return "%s (Combat: %d, Toughness: %d) - Armed with %s" % [name, combat, toughness, weapon_text]

func get_enemy_threat_level(enemies: Array[Resource]) -> String:
	"""Calculate overall threat level of enemy group"""
	var total_threat = 0
	
	for enemy in enemies:
		var combat = enemy.get_meta("combat_skill") if enemy.has_method("get_meta") else 1
		var toughness = enemy.get_meta("toughness") if enemy.has_method("get_meta") else 3
		total_threat += combat + (toughness / 2)
	
	if total_threat <= 6:
		return "Low"
	elif total_threat <= 12:
		return "Medium"
	else:
		return "High"