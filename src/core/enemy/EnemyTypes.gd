class_name EnemyTypes
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# AI Behavior Patterns from EnemyAI.json
static var AI_BEHAVIOR_PATTERNS: Dictionary = {
	GlobalEnums.EnemyBehavior.AGGRESSIVE: {
		"base_condition": "If able to engage an opponent in brawling combat this round, advance to do so.",
		"behavior_table": [
			{"roll": 1, "action": "Maneuver within current Cover to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Advance to the next forward position in Cover. Fire if eligible."},
			{"roll": 4, "action": "Advance and fire on the nearest enemy. Use Cover."},
			{"roll": 5, "action": "Advance and fire on the nearest enemy. Fastest route."},
			{"roll": 6, "action": "Dash towards the nearest enemy. Fastest route."}
		]
	},
	GlobalEnums.EnemyBehavior.CAUTIOUS: {
		"base_condition": "If in Cover and visible opponents are within 12\", move away to the most distant position that remains in Cover and in range and retains Line of Sight to an opponent, then fire.",
		"behavior_table": [
			{"roll": 1, "action": "Retreat a full move, remaining in Cover. Maintain Line of Sight if possible."},
			{"roll": 2, "action": "Remain in place or maneuver within current Cover to fire."},
			{"roll": 3, "action": "Remain in place or maneuver within current Cover to fire."},
			{"roll": 4, "action": "Advance to within 12\" of the nearest enemy and fire. Remain in Cover."},
			{"roll": 5, "action": "Advance to within 12\" of the nearest enemy and fire. Remain in Cover."},
			{"roll": 6, "action": "Advance on the nearest enemy and fire, ending in Cover if possible."}
		]
	},
	GlobalEnums.EnemyBehavior.TACTICAL: {
		"base_condition": "If in Cover and within 12\" of visible opponents, remain in position and fire.",
		"behavior_table": [
			{"roll": 1, "action": "Remain in place to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Advance to the next forward position in Cover or move to flank."},
			{"roll": 4, "action": "Advance to the next forward position in Cover or move to flank."},
			{"roll": 5, "action": "Advance and fire on the nearest enemy. Use Cover."},
			{"roll": 6, "action": "Advance and fire on the nearest enemy. Use Cover."}
		]
	},
	GlobalEnums.EnemyBehavior.DEFENSIVE: {
		"base_condition": "If in Cover and opponents in the open are visible, remain in position and fire.",
		"behavior_table": [
			{"roll": 1, "action": "Remain in place to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Maneuver within current Cover to fire."},
			{"roll": 4, "action": "Maneuver within current Cover to fire."},
			{"roll": 5, "action": "Advance to the next forward position in Cover."},
			{"roll": 6, "action": "Advance and fire on the nearest enemy. Use Cover."}
		]
	},
	GlobalEnums.EnemyBehavior.BEAST: {
		"base_condition": "Always move towards the nearest visible opponent by the most direct route possible.",
		"behavior_table": []
	},
	GlobalEnums.EnemyBehavior.RAMPAGE: {
		"base_condition": "Always move towards the nearest opponent by the most direct route possible, attempting to enter brawling combat.",
		"behavior_table": []
	},
	GlobalEnums.EnemyBehavior.GUARDIAN: {
		"base_condition": "Remain in place unless an opponent comes within 12\", then move to engage.",
		"behavior_table": []
	}
}

static var ENEMY_CATEGORIES: Dictionary = {
	GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS: [
		"Gangers", "Punks", "Raiders", "Cultists", "Psychos", "Brat Gang",
		"Gene Renegades", "Anarchists", "Pirates", "K'Erin Outlaws", "Skulker Brigands",
		"Tech Gangers", "Starport Scum", "Hulker Gang"
	],
	GlobalEnums.EnemyCategory.HIRED_MUSCLE: [
		"Unknown Mercs", "Enforcers", "Guild Troops", "Roid-gangers", "Black Ops Team",
		"War Bots", "Secret Agents", "Assassins", "Corporate Security", "Gun Slingers"
	],
	GlobalEnums.EnemyCategory.MILITARY_FORCES: [
		"Unity Grunts", "Security Bots", "Black Dragon Mercs"
	],
	GlobalEnums.EnemyCategory.ALIEN_THREATS: [
		"Rage Lizard Mercs", "Blood Storm Mercs", "Feral Mercenaries", "Skulker Mercenaries"
	]
}

static var ENEMY_TYPES: Dictionary = {
	"Gangers": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.GANGERS,
		"numbers": 2,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Leg it: When a ganger is hit by a shot, they will retreat 3\" away from the shooter."]
	},
	"Punks": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.PUNKS,
		"numbers": 3,
		"panic": "1-3",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative.",
			"Bad shots: Their shooting only Hits on a natural 6."
		]
	},
	"Raiders": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.RAIDERS,
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Scavengers: Roll twice on the Battlefield Finds Table."]
	},
	"Cultists": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.CULTISTS,
		"numbers": 2,
		"panic": "1",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Intrigue: Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."]
	},
	"Psychos": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.PSYCHOS,
		"numbers": 2,
		"panic": "1",
		"speed": 6,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 B",
		"special_rules": ["Bad shots: Their shooting only Hits on a natural 6."]
	},
	"Brat Gang": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.BRAT_GANG,
		"numbers": 2,
		"panic": "1-3",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 C",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative.",
			"6+ Saving Throw."
		]
	},
	"Gene Renegades": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.GENE_RENEGADES,
		"numbers": 1,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.CAUTIOUS,
		"weapons": "1 B",
		"special_rules": ["Alert: You are -1 to Seize the Initiative."]
	},
	"Anarchists": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.ANARCHISTS,
		"numbers": 2,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Stubborn: They ignore the first casualty of the battle when making a Morale check."]
	},
	"Pirates": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.PIRATES,
		"numbers": 2,
		"panic": "1-3",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Loot: Gain an extra Loot roll if Holding the Field."]
	},
	"K'Erin Outlaws": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.K_ERIN_OUTLAWS,
		"numbers": 1,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Stubborn: They ignore the first casualty when making a Morale check."]
	},
	"Skulker Brigands": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.SKULKER_BRIGANDS,
		"numbers": 3,
		"panic": "1-2",
		"speed": 6,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.CAUTIOUS,
		"weapons": "1 B",
		"special_rules": [
			"Alert: You are -1 to Seize the Initiative.",
			"Scavengers: Roll twice on the Battlefield Finds Table."
		]
	},
	"Tech Gangers": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.TECH_GANGERS,
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "3 C",
		"special_rules": [
			"Loot: Gain an extra Loot roll if Holding the Field.",
			"6+ Saving Throw."
		]
	},
	"Starport Scum": {
		"category": GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"type": GlobalEnums.EnemyType.STARPORT_SCUM,
		"numbers": 3,
		"panic": "1-3",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.DEFENSIVE,
		"weapons": "1 A",
		"special_rules": ["Friday Night Warriors: When a scum is slain, all allies within 6\" will retreat a standard move at their base speed directly back towards their own battlefield edge."]
	},
	"Hulker Gang": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.HULKER_GANG,
		"numbers": 0,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": [
			"Ferocious: +1 to Brawling rolls when initiating combat.",
			"Aggro: If Hit by a shot and surviving, immediately move 1\" towards the shooter."
		]
	},
	"Gun Slingers": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.GUN_SLINGERS,
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "1 B",
		"special_rules": ["Trick shot: Any natural 6 when they shoot allows an additional shot against the same target or another target within 2\"."]
	},
	"Unknown Mercs": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.UNKNOWN_MERCS,
		"numbers": 0,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "2 B",
		"special_rules": ["Lets just call it a day: If they are down to 1 or 2 figures remaining, they will accept ending the fight at the end of any round. Neither side Holds the Field in this case."]
	},
	"Enforcers": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.ENFORCERS,
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "2 A",
		"special_rules": ["Cop killer: If you ever fight Enforcers as Rivals, add +2 to their numbers."]
	},
	"Guild Troops": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.GUILD_TROOPS,
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["Intrigue: Roll 2D6, and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."]
	},
	"Roid-gangers": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.ROID_GANGERS,
		"numbers": 1,
		"panic": "1",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Careless: You are +1 to Seize the Initiative (for a final modifier of 0)."]
	},
	"Black Ops Team": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.BLACK_OPS_TEAM,
		"numbers": 0,
		"panic": "1",
		"speed": 6,
		"combat_skill": 2,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "3 A",
		"special_rules": ["Tough fight: A random survivor gains +1 XP."]
	},
	"War Bots": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.WAR_BOTS,
		"numbers": 0,
		"panic": "0",
		"speed": 3,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "3 C",
		"special_rules": [
			"Fearless: Never affected by Morale.",
			"5+ Saving Throw."
		]
	},
	"Secret Agents": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.SECRET_AGENTS,
		"numbers": 0,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.CAUTIOUS,
		"weapons": "2 C",
		"special_rules": [
			"Loot: Gain an extra Loot roll if Holding the Field.",
			"Intrigue: Roll 2D6, and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."
		]
	},
	"Assassins": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.ASSASSINS,
		"numbers": 0,
		"panic": "1",
		"speed": 6,
		"combat_skill": 2,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "1 B",
		"special_rules": [
			"Gruesome: Characters rolling for post-battle Injuries must apply a -5 to the roll.",
			"Tough fight: A random survivor gains +1 XP."
		]
	},
	"Feral Mercenaries": {
		"category": GlobalEnums.EnemyCategory.ALIEN_THREATS,
		"type": GlobalEnums.EnemyType.FERAL_MERCENARIES,
		"numbers": 2,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Quick feet: They add +1\" to the distance for any Dash move."]
	},
	"Skulker Mercenaries": {
		"category": GlobalEnums.EnemyCategory.ALIEN_THREATS,
		"type": GlobalEnums.EnemyType.SKULKER_MERCENARIES,
		"numbers": 3,
		"panic": "1-2",
		"speed": 7,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.EnemyBehavior.CAUTIOUS,
		"weapons": "2 C",
		"special_rules": [
			"Alert: You are -1 to Seize the Initiative (for a total of -2).",
			"Scavengers: Roll twice on the Battlefield Finds Table."
		]
	},
	"Corporate Security": {
		"category": GlobalEnums.EnemyCategory.HIRED_MUSCLE,
		"type": GlobalEnums.EnemyType.CORPORATE_SECURITY,
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.DEFENSIVE,
		"weapons": "2 B",
		"special_rules": ["6+ Saving Throw."]
	},
	"Unity Grunts": {
		"category": GlobalEnums.EnemyCategory.MILITARY_FORCES,
		"type": GlobalEnums.EnemyType.UNITY_GRUNTS,
		"numbers": 1,
		"panic": "1",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["6+ Saving Throw."]
	},
	"Security Bots": {
		"category": GlobalEnums.EnemyCategory.MILITARY_FORCES,
		"type": GlobalEnums.EnemyType.SECURITY_BOTS,
		"numbers": 1,
		"panic": "0",
		"speed": 3,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.DEFENSIVE,
		"weapons": "2 A",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative (for a total of 0).",
			"Fearless: Never affected by Morale.",
			"6+ Saving Throw."
		]
	},
	"Black Dragon Mercs": {
		"category": GlobalEnums.EnemyCategory.MILITARY_FORCES,
		"type": GlobalEnums.EnemyType.BLACK_DRAGON_MERCS,
		"numbers": 1,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["Stubborn: They ignore the first casualty of the battle when making a Morale check."]
	},
	"Rage Lizard Mercs": {
		"category": GlobalEnums.EnemyCategory.ALIEN_THREATS,
		"type": GlobalEnums.EnemyType.RAGE_LIZARD_MERCS,
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 5,
		"ai": GlobalEnums.EnemyBehavior.TACTICAL,
		"weapons": "3 B",
		"special_rules": ["Up close: If a Rage Lizard is within 1\" of terrain, they may add +1 to Brawling rolls."]
	},
	"Blood Storm Mercs": {
		"category": GlobalEnums.EnemyCategory.ALIEN_THREATS,
		"type": GlobalEnums.EnemyType.BLOOD_STORM_MERCS,
		"numbers": 0,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.EnemyBehavior.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Ferocious: +1 to Brawling rolls when initiating combat."]
	}
}

static func get_enemy_type(type_name: String) -> Dictionary:
	assert(type_name in ENEMY_TYPES, "Invalid enemy type: " + type_name)
	var enemy = ENEMY_TYPES[type_name].duplicate(true)
	_validate_enemy_data(enemy)
	return enemy

static func _validate_enemy_data(enemy: Dictionary) -> void:
	assert(enemy.has("category") and enemy.category in GlobalEnums.EnemyCategory.values(), "Invalid enemy category")
	assert(enemy.has("type") and enemy.type in GlobalEnums.EnemyType.values(), "Invalid enemy type")
	assert(enemy.has("ai") and enemy.ai in GlobalEnums.EnemyBehavior.values(), "Invalid AI behavior")
	assert(enemy.has("numbers") and enemy.numbers >= 0, "Invalid numbers value")
	assert(enemy.has("combat_skill") and enemy.combat_skill >= 0, "Invalid combat skill")
	assert(enemy.has("toughness") and enemy.toughness >= 0, "Invalid toughness")
	assert(enemy.has("speed") and enemy.speed >= 0, "Invalid speed")
	assert(enemy.has("weapons"), "Missing weapons")
	assert(enemy.has("special_rules"), "Missing special rules")
	assert(enemy.has("panic"), "Missing panic value")

static func get_ai_behavior_pattern(behavior: GlobalEnums.EnemyBehavior) -> Dictionary:
	assert(behavior in AI_BEHAVIOR_PATTERNS, "Invalid AI behavior type")
	return AI_BEHAVIOR_PATTERNS[behavior]

static func get_all_enemy_types() -> PackedStringArray:
	return PackedStringArray(ENEMY_TYPES.keys())

static func get_random_enemy_type() -> String:
	var types := get_all_enemy_types()
	return types[randi() % types.size()]

static func get_enemy_types_by_category(category: GlobalEnums.EnemyCategory) -> PackedStringArray:
	return PackedStringArray(ENEMY_CATEGORIES.get(category, []))

static func get_random_enemy_type_by_category(category: GlobalEnums.EnemyCategory) -> String:
	var category_types := get_enemy_types_by_category(category)
	assert(category_types.size() > 0, "Invalid category or empty category")
	return category_types[randi() % category_types.size()]
