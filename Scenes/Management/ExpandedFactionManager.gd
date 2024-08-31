class_name ExpandedFactionManager
extends Node

enum FactionType {
	CORPORATE,
	CRIMINAL,
	POLITICAL,
	RELIGIOUS
}

var game_state: GameState
var factions: Array[Dictionary] = []

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_factions(num_factions: int) -> void:
	assert(num_factions > 0, "Number of factions must be greater than 0")
	for i in range(num_factions):
		factions.append(generate_faction())

func generate_faction() -> Dictionary:
	var faction_type: FactionType = FactionType.values()[randi_range(0, FactionType.size() - 1)]

	return {
		"name": generate_faction_name(),
		"type": faction_type,
		"influence": randi_range(1, 5),
		"attitude": randf_range(-1.0, 1.0)
	}

func generate_faction_name() -> String:
	var prefixes: Array[String] = ["New", "United", "Free", "Imperial", "Republic of"]
	var suffixes: Array[String] = ["Corp", "Syndicate", "Alliance", "Federation", "Collective"]
	return prefixes[randi_range(0, prefixes.size() - 1)] + " " + suffixes[randi_range(0, suffixes.size() - 1)]

func update_faction_relations(faction: Dictionary, change: float) -> void:
	assert("attitude" in faction, "Invalid faction dictionary: missing 'attitude' key")
	faction["attitude"] = clamp(faction["attitude"] + change, -1.0, 1.0)

func get_faction_mission(faction: Dictionary) -> Mission:
	assert("type" in faction and "attitude" in faction, "Invalid faction dictionary: missing required keys")
	# Generate a mission based on the faction's type and attitude
	return game_state.mission_generator.generate_mission_for_faction(faction)

func resolve_faction_conflict() -> void:
	# TODO: Implement logic for resolving conflicts between factions
	pass
