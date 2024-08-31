class_name QuestGenerator
extends Node

enum QuestType { EXPLORATION, RESCUE, RETRIEVAL, ELIMINATION, DIPLOMACY }

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_quest() -> Quest:
	var quest_type: QuestType = choose_quest_type()
	var location: Location = choose_location()
	var objective: String = generate_objective(quest_type)
	var reward: Dictionary = generate_reward()
	
	return Quest.new(QuestType.keys()[quest_type], location, objective, reward)

func choose_quest_type() -> QuestType:
	return QuestType.values()[randi() % QuestType.size()]

func choose_location() -> Location:
	return game_state.get_random_location()

func generate_objective(quest_type: QuestType) -> String:
	match quest_type:
		QuestType.EXPLORATION:
			return "Explore the uncharted region of " + generate_region_name()
		QuestType.RESCUE:
			return "Rescue " + generate_npc_name() + " from " + generate_enemy_group()
		QuestType.RETRIEVAL:
			return "Retrieve " + generate_item_name() + " from " + generate_location_name()
		QuestType.ELIMINATION:
			return "Eliminate " + generate_enemy_leader() + " and their followers"
		QuestType.DIPLOMACY:
			return "Negotiate a peace treaty between " + generate_faction_name() + " and " + generate_faction_name()
		_:
			push_error("Invalid quest type")
			return "Error: Invalid quest type"

func generate_reward() -> Dictionary:
	return {
		"credits": randi_range(100, 1000),
		"reputation": randi_range(1, 5),
		"item": generate_reward_item()
	}

func generate_region_name() -> String:
	var prefixes = ["Nebula", "Asteroid Field", "Gas Cloud", "Star Cluster"]
	var suffixes = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"]
	return prefixes[randi() % prefixes.size()] + " " + suffixes[randi() % suffixes.size()]

func generate_npc_name() -> String:
	var first_names = ["John", "Jane", "Zorg", "Xyla", "Krath"]
	var last_names = ["Smith", "Doe", "X'tor", "Vex", "Blorp"]
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func generate_enemy_group() -> String:
	var groups = ["Space Pirates", "Rogue AI", "Alien Hive", "Rebel Faction", "Criminal Syndicate"]
	return groups[randi() % groups.size()]

func generate_item_name() -> String:
	var adjectives = ["Ancient", "Mysterious", "Powerful", "Alien", "Prototype"]
	var nouns = ["Artifact", "Weapon", "Technology", "Relic", "Data Core"]
	return adjectives[randi() % adjectives.size()] + " " + nouns[randi() % nouns.size()]

func generate_location_name() -> String:
	var types = ["Planet", "Moon", "Space Station", "Asteroid", "Derelict Ship"]
	var names = ["Xanadu", "Nova Prime", "Epsilon Eridani", "Kepler-186f", "Trappist-1e"]
	return names[randi() % names.size()] + " " + types[randi() % types.size()]

func generate_enemy_leader() -> String:
	var titles = ["Warlord", "Pirate King", "Hive Queen", "Rebel Commander", "Crime Lord"]
	return titles[randi() % titles.size()] + " " + generate_npc_name()

func generate_faction_name() -> String:
	var adjectives = ["United", "Free", "Imperial", "Federated", "Collective"]
	var nouns = ["Systems", "Worlds", "Colonies", "Territories", "Alliance"]
	return adjectives[randi() % adjectives.size()] + " " + nouns[randi() % nouns.size()]

func generate_reward_item() -> Equipment:
	# Generate a random piece of equipment as a reward
	# This would use the Equipment system we created earlier
	return Equipment.new("Reward Item", 0, randi_range(50, 500))
