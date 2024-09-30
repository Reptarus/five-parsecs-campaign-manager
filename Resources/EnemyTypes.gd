class_name EnemyTypes
extends Resource

const ENEMY_TYPES: Dictionary = {
	"Gangers": {
		"numbers": 2,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Leg it: When a ganger is hit by a shot, they will retreat 3\" away from the shooter."]
	},
	"Punks": {
		"numbers": 3,
		"panic": "1-3",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative.",
			"Bad shots: Their shooting only Hits on a natural 6."
		]
	},
	"Raiders": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Scavengers: Roll twice on the Battlefield Finds Table."]
	},
	"Cultists": {
		"numbers": 2,
		"panic": "1",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Intrigue: Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."]
	},
	"Psychos": {
		"numbers": 2,
		"panic": "1",
		"speed": 6,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.AIType.RAMPAGE,
		"weapons": "1 B",
		"special_rules": ["Bad shots: Their shooting only Hits on a natural 6."]
	},
	"Brat Gang": {
		"numbers": 2,
		"panic": "1-3",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 C",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative.",
			"6+ Saving Throw."
		]
	},
	"Gene Renegades": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.AIType.CAUTIOUS,
		"weapons": "1 B",
		"special_rules": ["Alert: You are -1 to Seize the Initiative."]
	},
	"Anarchists": {
		"numbers": 2,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Stubborn: They ignore the first casualty of the battle when making a Morale check."]
	},
	"Pirates": {
		"numbers": 2,
		"panic": "1-3",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Loot: Gain an extra Loot roll if Holding the Field."]
	},
	"K'Erin Outlaws": {
		"numbers": 1,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 A",
		"special_rules": ["Stubborn: They ignore the first casualty when making a Morale check."]
	},
	"Skulker Brigands": {
		"numbers": 3,
		"panic": "1-2",
		"speed": 6,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.CAUTIOUS,
		"weapons": "1 B",
		"special_rules": [
			"Alert: You are -1 to Seize the Initiative.",
			"Scavengers: Roll twice on the Battlefield Finds Table."
		]
	},
	"Tech Gangers": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "3 C",
		"special_rules": [
			"Loot: Gain an extra Loot roll if Holding the Field.",
			"6+ Saving Throw."
		]
	},
	"Starport Scum": {
		"numbers": 3,
		"panic": "1-3",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.DEFENSIVE,
		"weapons": "1 A",
		"special_rules": ["Friday Night Warriors: When a scum is slain, all allies within 6\" will retreat a standard move at their base speed directly back towards their own battlefield edge."]
	},
	"Hulker Gang": {
		"numbers": 0,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 5,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": [
			"Ferocious: +1 to Brawling rolls when initiating combat.",
			"Aggro: If Hit by a shot and surviving, immediately move 1\" towards the shooter."
		]
	},
	"Gun Slingers": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "1 B",
		"special_rules": ["Trick shot: Any natural 6 when they shoot allows an additional shot against the same target or another target within 2\"."]
	},
	"Unknown Mercs": {
		"numbers": 0,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "2 B",
		"special_rules": ["Lets just call it a day: If they are down to 1 or 2 figures remaining, they will accept ending the fight at the end of any round. Neither side Holds the Field in this case."]
	},
	"Enforcers": {
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "2 A",
		"special_rules": ["Cop killer: If you ever fight Enforcers as Rivals, add +2 to their numbers."]
	},
	"Guild Troops": {
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["Intrigue: Roll 2D6, and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."]
	},
	"Roid-gangers": {
		"numbers": 1,
		"panic": "1",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 A",
		"special_rules": ["Careless: You are +1 to Seize the Initiative (for a final modifier of 0)."]
	},
	"Black Ops Team": {
		"numbers": 0,
		"panic": "1",
		"speed": 6,
		"combat_skill": 2,
		"toughness": 5,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "3 A",
		"special_rules": ["Tough fight: A random survivor gains +1 XP."]
	},
	"War Bots": {
		"numbers": 0,
		"panic": "0",
		"speed": 3,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "3 C",
		"special_rules": [
			"Fearless: Never affected by Morale.",
			"5+ Saving Throw."
		]
	},
	"Secret Agents": {
		"numbers": 0,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.CAUTIOUS,
		"weapons": "2 C",
		"special_rules": [
			"Loot: Gain an extra Loot roll if Holding the Field.",
			"Intrigue: Roll 2D6, and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor."
		]
	},
	"Assassins": {
		"numbers": 0,
		"panic": "1",
		"speed": 6,
		"combat_skill": 2,
		"toughness": 3,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "1 B",
		"special_rules": [
			"Gruesome: Characters rolling for post-battle Injuries must apply a -5 to the roll.",
			"Tough fight: A random survivor gains +1 XP."
		]
	},
	"Feral Mercenaries": {
		"numbers": 2,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 0,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Quick feet: They add +1\" to the distance for any Dash move."]
	},
	"Skulker Mercenaries": {
		"numbers": 3,
		"panic": "1-2",
		"speed": 7,
		"combat_skill": 0,
		"toughness": 3,
		"ai": GlobalEnums.AIType.CAUTIOUS,
		"weapons": "2 C",
		"special_rules": [
			"Alert: You are -1 to Seize the Initiative (for a total of -2).",
			"Scavengers: Roll twice on the Battlefield Finds Table."
		]
	},
	"Corporate Security": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.DEFENSIVE,
		"weapons": "2 B",
		"special_rules": ["6+ Saving Throw."]
	},
	"Unity Grunts": {
		"numbers": 1,
		"panic": "1",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["6+ Saving Throw."]
	},
	"Security Bots": {
		"numbers": 1,
		"panic": "0",
		"speed": 3,
		"combat_skill": 0,
		"toughness": 5,
		"ai": GlobalEnums.AIType.DEFENSIVE,
		"weapons": "2 A",
		"special_rules": [
			"Careless: You are +1 to Seize the Initiative (for a total of 0).",
			"Fearless: Never affected by Morale.",
			"6+ Saving Throw."
		]
	},
	"Black Dragon Mercs": {
		"numbers": 1,
		"panic": "1-2",
		"speed": 5,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "2 C",
		"special_rules": ["Stubborn: They ignore the first casualty of the battle when making a Morale check."]
	},
	"Rage Lizard Mercs": {
		"numbers": 0,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 5,
		"ai": GlobalEnums.AIType.TACTICAL,
		"weapons": "3 B",
		"special_rules": ["Up close: If a Rage Lizard is within 1\" of terrain, they may add +1 to Brawling rolls."]
	},
	"Blood Storm Mercs": {
		"numbers": 0,
		"panic": "1",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": GlobalEnums.AIType.AGGRESSIVE,
		"weapons": "2 B",
		"special_rules": ["Ferocious: +1 to Brawling rolls when initiating combat."]
	}
}

static func get_enemy_type(type_name: String) -> Dictionary:
	assert(type_name in ENEMY_TYPES, "Invalid enemy type: " + type_name)
	return ENEMY_TYPES[type_name].duplicate(true)

static func get_all_enemy_types() -> PackedStringArray:
	return PackedStringArray(ENEMY_TYPES.keys())

static func get_random_enemy_type() -> String:
	var types := get_all_enemy_types()
	return types[randi() % types.size()]

static func get_enemy_types_by_category(category: String) -> PackedStringArray:
	var category_types: Array[String] = []
	match category:
		"Criminal Elements":
			category_types = [
				"Gangers", "Punks", "Raiders", "Cultists", "Psychos", "Brat Gang",
				"Gene Renegades", "Anarchists", "Pirates", "K'Erin Outlaws",
				"Skulker Brigands", "Tech Gangers", "Starport Scum", "Hulker Gang",
				"Gun Slingers"
			]
		"Hired Muscle":
			category_types = [
				"Unknown Mercs", "Enforcers", "Guild Troops", "Roid-gangers",
				"Black Ops Team", "War Bots", "Secret Agents", "Assassins",
				"Feral Mercenaries", "Skulker Mercenaries", "Corporate Security",
				"Unity Grunts", "Security Bots", "Black Dragon Mercs",
				"Rage Lizard Mercs", "Blood Storm Mercs"
			]
	return PackedStringArray(category_types)

static func get_random_enemy_type_by_category(category: String) -> String:
	var category_types := get_enemy_types_by_category(category)
	assert(category_types.size() > 0, "Invalid category or empty category: " + category)
	return category_types[randi() % category_types.size()]
