@tool
class_name FiveParsecsMissionGenerator
extends BaseMissionGenerator

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific mission types
enum FiveParsecsMissionType {
	BATTLE = 0,
	PATRON_JOB = 1,
	STORY_MISSION = 2,
	RIVAL_ENCOUNTER = 3,
	SALVAGE_RUN = 4,
	RESCUE_OPERATION = 5,
	BOUNTY_HUNT = 6,
	EXPLORATION = 7,
	CONVOY_ESCORT = 8,
	DEFENSE = 9
}

# Five Parsecs specific mission properties
var mission_locations: Array = [
	"Abandoned Outpost",
	"Derelict Ship",
	"Urban Ruins",
	"Mining Facility",
	"Research Station",
	"Jungle Wilderness",
	"Desert Wasteland",
	"Space Station",
	"Underground Complex",
	"Orbital Platform"
]

var enemy_factions: Array = [
	"Marauders",
	"Corporate Security",
	"Alien Horde",
	"Rogue AI",
	"Rival Crew",
	"Government Forces",
	"Cultists",
	"Mercenaries",
	"Rebels",
	"Pirates"
]

func _init() -> void:
	# Override mission types with Five Parsecs specific types
	mission_types = {
		FiveParsecsMissionType.BATTLE: "Battle",
		FiveParsecsMissionType.PATRON_JOB: "Patron Job",
		FiveParsecsMissionType.STORY_MISSION: "Story Mission",
		FiveParsecsMissionType.RIVAL_ENCOUNTER: "Rival Encounter",
		FiveParsecsMissionType.SALVAGE_RUN: "Salvage Run",
		FiveParsecsMissionType.RESCUE_OPERATION: "Rescue Operation",
		FiveParsecsMissionType.BOUNTY_HUNT: "Bounty Hunt",
		FiveParsecsMissionType.EXPLORATION: "Exploration",
		FiveParsecsMissionType.CONVOY_ESCORT: "Convoy Escort",
		FiveParsecsMissionType.DEFENSE: "Defense"
	}

func generate_mission(difficulty: int = 2, type: int = -1) -> Dictionary:
	if type < 0:
		type = randi() % FiveParsecsMissionType.size()
	
	var mission = {
		"id": str(randi()),
		"type": type,
		"difficulty": difficulty,
		"title": generate_mission_title(type),
		"description": generate_mission_description(type, difficulty),
		"reward": calculate_mission_reward(difficulty, type),
		"location": mission_locations[randi() % mission_locations.size()],
		"enemy_faction": enemy_factions[randi() % enemy_factions.size()],
		"enemy_count": calculate_enemy_count(difficulty, type),
		"special_rules": generate_special_rules(type),
		"objectives": generate_objectives(type),
		"loot_table": generate_loot_table(difficulty),
		"completed": false,
		"success": false
	}
	
	mission_generated.emit(mission)
	return mission

func generate_mission_title(type: int) -> String:
	var titles = {
		FiveParsecsMissionType.BATTLE: [
			"Desperate Stand", "Firefight", "Skirmish", "Ambush", "Raid"
		],
		FiveParsecsMissionType.PATRON_JOB: [
			"Special Contract", "Lucrative Offer", "Patron's Request", "High-Stakes Job", "Covert Operation"
		],
		FiveParsecsMissionType.STORY_MISSION: [
			"Critical Moment", "Turning Point", "Revelation", "Confrontation", "Discovery"
		],
		FiveParsecsMissionType.RIVAL_ENCOUNTER: [
			"Old Enemies", "Showdown", "Rivalry", "Contested Ground", "Face-Off"
		],
		FiveParsecsMissionType.SALVAGE_RUN: [
			"Valuable Salvage", "Wreckage Recovery", "Scavenging Operation", "Derelict Exploration", "Abandoned Tech"
		],
		FiveParsecsMissionType.RESCUE_OPERATION: [
			"Desperate Rescue", "Extraction Mission", "Hostage Situation", "Prisoner Recovery", "Emergency Evacuation"
		],
		FiveParsecsMissionType.BOUNTY_HUNT: [
			"High-Value Target", "Wanted Dead or Alive", "Dangerous Quarry", "Fugitive Hunt", "Bounty Collection"
		],
		FiveParsecsMissionType.EXPLORATION: [
			"Uncharted Territory", "Strange Discovery", "Ancient Ruins", "Mysterious Signal", "Frontier Expedition"
		],
		FiveParsecsMissionType.CONVOY_ESCORT: [
			"Valuable Cargo", "Dangerous Transit", "Escort Duty", "Supply Run", "VIP Transport"
		],
		FiveParsecsMissionType.DEFENSE: [
			"Last Stand", "Hold the Line", "Defensive Position", "Protect the Asset", "Fortified Defense"
		]
	}
	
	if titles.has(type) and titles[type].size() > 0:
		return titles[type][randi() % titles[type].size()]
	
	return "Five Parsecs Mission"

func generate_mission_description(type: int, difficulty: int) -> String:
	var difficulty_desc = ""
	match difficulty:
		1: difficulty_desc = "This should be a straightforward mission."
		2: difficulty_desc = "A standard operation with moderate risk."
		3: difficulty_desc = "This mission presents significant challenges."
		4: difficulty_desc = "A high-risk operation with serious dangers."
		5: difficulty_desc = "An extremely dangerous mission with overwhelming odds."
	
	var type_desc = ""
	match type:
		FiveParsecsMissionType.BATTLE:
			type_desc = "Engage and defeat enemy forces in direct combat."
		FiveParsecsMissionType.PATRON_JOB:
			type_desc = "Complete a specialized task for an influential patron."
		FiveParsecsMissionType.STORY_MISSION:
			type_desc = "A pivotal mission that will advance your crew's story."
		FiveParsecsMissionType.RIVAL_ENCOUNTER:
			type_desc = "Face off against a rival crew competing for the same objective."
		FiveParsecsMissionType.SALVAGE_RUN:
			type_desc = "Recover valuable salvage from a dangerous location."
		FiveParsecsMissionType.RESCUE_OPERATION:
			type_desc = "Extract hostages or stranded personnel from enemy territory."
		FiveParsecsMissionType.BOUNTY_HUNT:
			type_desc = "Track down and capture or eliminate a high-value target."
		FiveParsecsMissionType.EXPLORATION:
			type_desc = "Explore an uncharted area and document your findings."
		FiveParsecsMissionType.CONVOY_ESCORT:
			type_desc = "Protect a convoy of vehicles from enemy attacks."
		FiveParsecsMissionType.DEFENSE:
			type_desc = "Hold a strategic position against waves of enemies."
	
	return type_desc + " " + difficulty_desc

func calculate_mission_reward(difficulty: int, type: int) -> int:
	# Base calculation from parent class
	var base_reward = super.calculate_mission_reward(difficulty, type)
	
	# Five Parsecs specific adjustments
	match type:
		FiveParsecsMissionType.PATRON_JOB:
			base_reward *= 1.5 # Patron jobs pay more
		FiveParsecsMissionType.STORY_MISSION:
			base_reward *= 2.0 # Story missions have the highest rewards
		FiveParsecsMissionType.RIVAL_ENCOUNTER:
			base_reward *= 1.3 # Rival encounters have good rewards
		FiveParsecsMissionType.SALVAGE_RUN:
			base_reward *= 1.2 # Salvage runs have decent rewards
	
	# Random variation (±10%)
	var variation = randf_range(0.9, 1.1)
	base_reward = int(base_reward * variation)
	
	# Round to nearest 50
	base_reward = int(round(base_reward / 50.0) * 50)
	
	return base_reward

func calculate_enemy_count(difficulty: int, type: int) -> int:
	var base_count = difficulty + 2
	
	# Adjust based on mission type
	match type:
		FiveParsecsMissionType.BATTLE:
			base_count += 2
		FiveParsecsMissionType.RIVAL_ENCOUNTER:
			base_count = 5 # Rival crews are typically 5 members
		FiveParsecsMissionType.DEFENSE:
			base_count += 3 # Defense missions have more enemies
	
	# Add some randomness
	base_count += randi() % 3 - 1
	
	# Ensure minimum of 2 enemies
	return max(2, base_count)

func generate_special_rules(type: int) -> Array:
	var special_rules = []
	
	# 50% chance to have a special rule
	if randf() < 0.5:
		var possible_rules = [
			"Limited Visibility",
			"Hazardous Environment",
			"Reinforcements",
			"Time Limit",
			"Restricted Equipment",
			"Unstable Ground",
			"Extreme Weather",
			"Radiation Zone",
			"Automated Defenses",
			"Civilian Presence"
		]
		
		# Add 1-2 special rules
		var rule_count = randi() % 2 + 1
		for i in range(rule_count):
			if possible_rules.size() > 0:
				var rule_index = randi() % possible_rules.size()
				special_rules.append(possible_rules[rule_index])
				possible_rules.remove_at(rule_index)
	
	return special_rules

func generate_objectives(type: int) -> Array:
	var objectives = []
	
	match type:
		FiveParsecsMissionType.BATTLE:
			objectives.append("Defeat all enemies")
		FiveParsecsMissionType.PATRON_JOB:
			objectives.append("Complete the patron's task")
			objectives.append("Return to the extraction point")
		FiveParsecsMissionType.STORY_MISSION:
			objectives.append("Achieve the primary objective")
			objectives.append("Survive the encounter")
		FiveParsecsMissionType.RIVAL_ENCOUNTER:
			objectives.append("Defeat the rival crew")
			objectives.append("Secure the contested resource")
		FiveParsecsMissionType.SALVAGE_RUN:
			objectives.append("Collect at least 3 salvage tokens")
			objectives.append("Extract safely")
		FiveParsecsMissionType.RESCUE_OPERATION:
			objectives.append("Locate and secure all hostages")
			objectives.append("Escort hostages to extraction point")
		FiveParsecsMissionType.BOUNTY_HUNT:
			objectives.append("Capture or eliminate the target")
			objectives.append("Collect proof of completion")
		FiveParsecsMissionType.EXPLORATION:
			objectives.append("Explore at least 3 points of interest")
			objectives.append("Document findings")
		FiveParsecsMissionType.CONVOY_ESCORT:
			objectives.append("Protect the convoy vehicles")
			objectives.append("Reach the destination")
		FiveParsecsMissionType.DEFENSE:
			objectives.append("Hold the position for 5 turns")
			objectives.append("Prevent enemy access to the objective")
	
	# 30% chance to add a bonus objective
	if randf() < 0.3:
		var bonus_objectives = [
			"Recover the hidden data cache",
			"Eliminate the enemy leader",
			"Avoid triggering alarms",
			"Complete the mission without casualties",
			"Find and secure the secret weapon"
		]
		
		objectives.append("BONUS: " + bonus_objectives[randi() % bonus_objectives.size()])
	
	return objectives

func generate_loot_table(difficulty: int) -> Array:
	var loot_table = []
	
	# Base number of loot rolls based on difficulty
	var loot_rolls = difficulty + 1
	
	# Generate loot entries
	for i in range(loot_rolls):
		var loot_type = randi() % 5
		var loot_entry = {}
		
		match loot_type:
			0: # Credits
				loot_entry = {
					"type": "credits",
					"amount": (randi() % 5 + 1) * 100
				}
			1: # Item
				loot_entry = {
					"type": "item",
					"rarity": min(randi() % (difficulty + 1), 4) # 0-4 rarity based on difficulty
				}
			2: # Weapon
				loot_entry = {
					"type": "weapon",
					"rarity": min(randi() % (difficulty + 1), 4)
				}
			3: # Armor
				loot_entry = {
					"type": "armor",
					"rarity": min(randi() % (difficulty + 1), 4)
				}
			4: # Resource
				var resources = ["medical_supplies", "spare_parts", "salvage", "ammunition"]
				loot_entry = {
					"type": "resource",
					"resource": resources[randi() % resources.size()],
					"amount": randi() % 3 + 1
				}
		
		loot_table.append(loot_entry)
	
	return loot_table

func serialize_mission(mission_data: Dictionary) -> Dictionary:
	var data = super.serialize_mission(mission_data)
	
	# Add any Five Parsecs specific serialization logic here
	
	return data

func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	var mission = super.deserialize_mission(serialized_data)
	
	# Add any Five Parsecs specific deserialization logic here
	
	return mission