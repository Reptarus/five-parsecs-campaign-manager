@warning_ignore("return_value_discarded")
# UNSAFE_METHOD_ACCESS and UNTYPED_DECLARATION warnings fixed with type safety patterns
extends Node
## FactionSystem — registered as autoload (no class_name per Godot 4.6 gotcha)

## Consolidated Faction System for Five Parsecs Campaign Manager
##
## Unified system combining:
	## - RivalManager: Individual rival tracking, reputation, negotiations
## - FactionManager: Basic faction standings and relationships
## - ExpandedFactionManager: Complex faction generation, activities, conflicts
##
## Implements IGameSystem interface for standardized integration

# Proper dependency imports - compile-time validation
# GlobalEnums available as autoload singleton

# Use preload pattern for dependencies
const GameState = preload("res://src/core/state/GameState.gd")

# Rival Management Signals
signal rival_encountered(rival: Dictionary)
signal rival_reputation_changed(rival: Dictionary, change: int)
signal rival_status_changed(rival: Dictionary, new_status: String)
signal rival_negotiation_attempted(rival: Dictionary, success: bool)

# Faction Management Signals
signal faction_relation_changed(faction_id: String, new_standing: float)
signal faction_event_occurred(event: Dictionary)
signal faction_created(faction: Dictionary)
signal faction_conflict_resolved(attacker: Dictionary, defender: Dictionary, result: String)

# System state
var _initialized: bool = false
var _game_state: Node = null # Type-safe managed by system
var _errors: Array[String] = []
var _last_update: int = 0

# Rival Management Data with strong typing
var active_rivals: Array[Dictionary] = []
var rival_reputations: Dictionary = {} # rival_id:String -> reputation:int (-100 to 100)
var rival_statuses: Dictionary = {} # rival_id:String -> status:String

# Faction Management Data with strong typing
var faction_standings: Dictionary = {} # faction_id:String -> standing:float (-100.0 to 100.0)
var active_factions: Dictionary = {} # faction_id:String -> faction_data:Dictionary
var faction_relations: Dictionary = {} # faction_id:String -> Dictionary[other_faction_id:String -> relation:float]

# Faction System Data
var faction_data: Dictionary = {} # Loaded from JSON
var faction_categories: Dictionary = {
	"government": [],
	"corporate": [],
	"criminal": [],
	"military": [],
	"religious": [],
	"mercenary": [],
	"pirate": [],
	"alien": []
}

# Configuration
var max_active_rivals: int = 8
var max_factions_per_category: int = 5
var faction_update_chance: float = 0.3 # Chance per turn for faction activity

# Constants
const MIN_FACTION_STRENGTH: int = 1
const MAX_FACTION_STRENGTH: int = 10
const MIN_FACTION_INFLUENCE: int = 1
const MAX_FACTION_INFLUENCE: int = 5
const MIN_FACTION_POWER: int = 3
const MAX_FACTION_POWER: int = 5
const MAX_TECH_LEVEL: int = 5
const MIN_TECH_LEVEL: int = 1

# Rival status mapping
const RIVAL_STATUS_HOSTILE = "HOSTILE"
const RIVAL_STATUS_UNFRIENDLY = "UNFRIENDLY"
const RIVAL_STATUS_NEUTRAL = "NEUTRAL"
const RIVAL_STATUS_FRIENDLY = "FRIENDLY"
const RIVAL_STATUS_ALLIED = "ALLIED"
const RIVAL_STATUS_DEFEATED = "DEFEATED"

func _init() -> void:
	name = "FactionSystem"
	# Dependencies are now preloaded at compile time

# =====================================================
# IGameSystem Interface Implementation
# =====================================================

func initialize() -> bool:
	## Initialize the faction system with all dependencies
	if _initialized:
		return true

	_errors.clear()

	# Validate dependencies
	if not GlobalEnums:
		_errors.append("GlobalEnums not available")

	if not GameState:
		_errors.append("GameState not available")

	# Try to get game state through GameStateManager
	if GameStateManager and GameStateManager.has_method("get_game_state"):
		_game_state = GameStateManager.get_game_state()
	elif GameStateManager:
		_game_state = GameStateManager

	if not _game_state:
		_errors.append("Game state not accessible")

	# Load faction data
	_load_faction_data()

	# Initialize default data
	_initialize_default_data()

	_initialized = _errors.is_empty()
	_last_update = Time.get_unix_time_from_system()

	if _initialized:
		pass
	else:
		push_error("FactionSystem: Failed to initialize - errors: " + str(_errors))

	return _initialized

func get_data() -> Dictionary:
	## Get all faction system data in serializable format
	return {
		"active_rivals": active_rivals.duplicate(),
		"rival_reputations": rival_reputations.duplicate(),
		"rival_statuses": rival_statuses.duplicate(),
		"faction_standings": faction_standings.duplicate(),
		"active_factions": active_factions.duplicate(),
		"faction_relations": faction_relations.duplicate(),
		"faction_categories": faction_categories.duplicate(),
		"last_update": _last_update
	}

func update_data(data: Dictionary) -> bool:
	## Update system state with provided data
	if not _initialized:
		_errors.append("System not initialized")
		return false

	# Update rival data with type safety
	if data.has("active_rivals") and data["active_rivals"] is Array:
		var rivals_data: Array = data["active_rivals"] as Array
		active_rivals = []
		for rival_variant in rivals_data:
			if rival_variant is Dictionary:
				active_rivals.append(rival_variant as Dictionary)

	if data.has("rival_reputations") and data["rival_reputations"] is Dictionary:
		var reputation_data: Dictionary = data["rival_reputations"] as Dictionary
		rival_reputations = reputation_data.duplicate()

	if data.has("rival_statuses") and data["rival_statuses"] is Dictionary:
		var status_data: Dictionary = data["rival_statuses"] as Dictionary
		rival_statuses = status_data.duplicate()

	# Update faction data with type safety
	if data.has("faction_standings") and data["faction_standings"] is Dictionary:
		var standings_data: Dictionary = data["faction_standings"] as Dictionary
		faction_standings = standings_data.duplicate()

	if data.has("active_factions") and data["active_factions"] is Dictionary:
		var factions_data: Dictionary = data["active_factions"] as Dictionary
		active_factions = factions_data.duplicate()

	if data.has("faction_relations") and data["faction_relations"] is Dictionary:
		var relations_data: Dictionary = data["faction_relations"] as Dictionary
		faction_relations = relations_data.duplicate()

	if data.has("faction_categories") and data["faction_categories"] is Dictionary:
		var categories_data: Dictionary = data["faction_categories"] as Dictionary
		faction_categories = categories_data.duplicate()

	_last_update = Time.get_unix_time_from_system()
	return true

func cleanup() -> void:
	## Clean up system resources and connections
	active_rivals.clear()
	rival_reputations.clear()
	rival_statuses.clear()
	faction_standings.clear()
	active_factions.clear()
	faction_relations.clear()
	faction_categories.clear()
	faction_data.clear()
	_errors.clear()
	_initialized = false

func get_status() -> Dictionary:
	## Get system status information
	return {
		"initialized": _initialized,
		"active": _initialized,
		"errors": _errors.duplicate(),
		"last_update": _last_update,
		"rival_count": active_rivals.size(),
		"faction_count": active_factions.size(),
		"total_category_factions": _get_total_category_factions()
	}

func validate_state() -> Dictionary:
	## Validate system state integrity
	var result: Dictionary = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate rival consistency
	for rival in active_rivals:
		if not rival.has("id"):
			result.errors.append("Rival missing required 'id' field")
			result.valid = false
		elif not rival_reputations.has(rival.id):
			result.warnings.append("Rival '" + rival.id + "' missing reputation entry")
		elif not rival_statuses.has(rival.id):
			result.warnings.append("Rival '" + rival.id + "' missing status entry")

	# Validate faction consistency
	for faction_id in active_factions.keys():
		var faction = active_factions[faction_id]
		if not faction.has("name"):
			result.errors.append("Faction '" + faction_id + "' missing required 'name' field")
			result.valid = false

		if not faction_standings.has(faction_id):
			result.warnings.append("Faction '" + faction_id + "' missing standing entry")

	return result

# =====================================================
# RIVAL MANAGEMENT (formerly RivalManager)
# =====================================================

func generate_rival() -> Dictionary:
	## Generate a new rival with complete profile
	var rival = {
		"id": "rival_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"name": _generate_rival_name(),
		"type": _select_rival_type(),
		"strength": randi_range(1, 5),
		"resources": {
			"credits": randi_range(1000, 5000),
			"ships": randi_range(1, 3),
			"equipment": randi_range(3, 7)
		},
		"characteristics": _generate_rival_characteristics(),
		"created_at": Time.get_unix_time_from_system()
	}

	# Add to system if not at capacity
	if active_rivals.size() < max_active_rivals:
		active_rivals.append(rival)
		rival_reputations[rival.id] = 0
		rival_statuses[rival.id] = RIVAL_STATUS_NEUTRAL
		rival_encountered.emit(rival)
	else:
		pass

	return rival

func update_rival_reputation(rival_id: String, change: int) -> void:
	## Update rival reputation and check for status changes
	if not rival_reputations.has(rival_id):
		_errors.append("Rival reputation not found: " + rival_id)
		return

	var old_reputation = rival_reputations[rival_id]
	rival_reputations[rival_id] = clamp(old_reputation + change, -100, 100)

	var rival = _get_rival_by_id(rival_id)
	if rival:
		rival_reputation_changed.emit(rival, change)
		_check_rival_reputation_thresholds(rival)

func attempt_rival_negotiation(rival_id: String) -> bool:
	## Attempt to negotiate with rival
	var rival = _get_rival_by_id(rival_id)
	if not rival:
		return false

	if not _can_interact_with_rival(rival_id):
		return false

	var success_chance = _calculate_negotiation_chance(rival)
	var success = randf() <= success_chance

	if success:
		_improve_rival_relations(rival)
	else:
		_worsen_rival_relations(rival)

	rival_negotiation_attempted.emit(rival, success)
	return success

func get_rival_reputation(rival_id: String) -> int:
	## Get current reputation with specific rival
	return rival_reputations.get(rival_id, 0)

func get_rival_status(rival_id: String) -> String:
	## Get current status with specific rival
	return rival_statuses.get(rival_id, RIVAL_STATUS_NEUTRAL)

func get_active_rivals() -> Array[Dictionary]:
	## Get all active rivals
	return active_rivals.duplicate()

# =====================================================
# FACTION MANAGEMENT (formerly FactionManager + ExpandedFactionManager)
# =====================================================

func create_faction(faction_type: String, custom_name: String = "") -> Dictionary:
	## Create a new faction with specified type
	var faction = _generate_faction_data(faction_type)

	if custom_name != "":
		faction.name = custom_name

	var faction_id = faction.name.replace(" ", "_").to_lower()
	active_factions[faction_id] = faction
	faction_standings[faction_id] = 0.0
	faction_relations[faction_id] = {}

	# Add to appropriate category
	if faction_type in faction_categories:
		if faction_categories[faction_type].size() < max_factions_per_category:
			faction_categories[faction_type].append(faction)

	faction_created.emit(faction)
	return faction

func get_faction_standing(faction_id: String) -> float:
	## Get current standing with faction
	return faction_standings.get(faction_id, 0.0)

func modify_faction_standing(faction_id: String, amount: float) -> void:
	## Modify faction standing by amount
	var current = get_faction_standing(faction_id)
	faction_standings[faction_id] = clamp(current + amount, -100.0, 100.0)
	faction_relation_changed.emit(faction_id, faction_standings[faction_id])

func process_faction_activities() -> void:
	## Process faction activities for all active factions
	for faction_id in active_factions.keys():
		if randf() < faction_update_chance:
			var faction = active_factions[faction_id]
			_perform_faction_activity(faction)

func resolve_faction_conflict(attacker_id: String, defender_id: String) -> Dictionary:
	## Resolve conflict between two factions
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_mgr and not dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.EXPANDED_FACTIONS):
		return {"success": false, "reason": "Expanded Factions DLC not enabled"}
	var attacker = active_factions.get(attacker_id)
	var defender = active_factions.get(defender_id)

	if not attacker or not defender:
		return {"success": false, "reason": "Invalid faction IDs"}

	var attacker_roll = randi_range(1, 6) + attacker.get("power", 3)
	var defender_roll = randi_range(1, 6) + defender.get("power", 3)

	if defender.get("temporary_defense", false):
		defender_roll += 2
		defender.temporary_defense = false

	var result: Dictionary = {}
	if attacker_roll > defender_roll:
		defender.strength = max(MIN_FACTION_STRENGTH, defender.strength - 1)
		attacker.influence = min(MAX_FACTION_INFLUENCE, attacker.influence + 1)
		result = {"winner": attacker_id, "loser": defender_id, "type": "attacker_victory"}
	elif defender_roll > attacker_roll:
		attacker.strength = max(MIN_FACTION_STRENGTH, attacker.strength - 1)
		defender.influence = min(MAX_FACTION_INFLUENCE, defender.influence + 1)
		result = {"winner": defender_id, "loser": attacker_id, "type": "defender_victory"}
	else:
		result = {"winner": "none", "loser": "none", "type": "stalemate"}

	faction_conflict_resolved.emit(attacker, defender, result.type)
	return result

func generate_faction_mission(faction_id: String) -> Dictionary:
	## Generate a mission for specific faction
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_mgr and not dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.EXPANDED_FACTIONS):
		return {}
	var faction = active_factions.get(faction_id)
	if not faction:
		return {}

	var mission = {
		"id": "faction_mission_" + str(Time.get_unix_time_from_system()),
		"faction_id": faction_id,
		"type": _get_faction_mission_type(faction),
		"name": _generate_faction_mission_name(faction),
		"description": _generate_faction_mission_description(faction),
		"difficulty": _calculate_faction_mission_difficulty(faction),
		"rewards": _generate_faction_mission_rewards(faction),
		"faction_bonus": _generate_faction_mission_bonus(faction)
	}

	return mission

# =====================================================
# PRIVATE HELPER METHODS
# =====================================================

func _load_faction_data() -> void:
	## Load faction data from JSON file with type safety
	var file_path := "res://data/RulesReference/Factions.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_initialize_default_faction_data()
		return
		
	var json_text: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error: int = json.parse(json_text)
	if error != OK:
		_errors.append("Failed to parse faction data: " + json.get_error_message())
		_initialize_default_faction_data()
		return
		
	var data = json.get_data()
	if not data is Dictionary:
		_errors.append("Invalid faction data format: expected Dictionary")
		_initialize_default_faction_data()
		return
		
	var data_dict: Dictionary = data as Dictionary
	if data_dict.has("factions") and data_dict["factions"] is Dictionary:
		faction_data = data_dict["factions"] as Dictionary
	else:
		_errors.append("Faction data missing 'factions' key or invalid format")
		_initialize_default_faction_data()

func _initialize_default_faction_data() -> void:
	## Initialize default faction data
	faction_data = {
		"government": {"base_influence": 4, "mission_types": ["security", "diplomacy"]},
		"corporate": {"base_influence": 3, "mission_types": ["transport", "trade"]},
		"criminal": {"base_influence": 2, "mission_types": ["smuggling", "heist"]},
		"military": {"base_influence": 4, "mission_types": ["combat", "escort"]},
		"religious": {"base_influence": 3, "mission_types": ["pilgrimage", "protection"]},
		"mercenary": {"base_influence": 2, "mission_types": ["combat", "security"]},
		"pirate": {"base_influence": 1, "mission_types": ["raid", "smuggling"]},
		"alien": {"base_influence": 3, "mission_types": ["exploration", "research"]}
	}

func _initialize_default_data() -> void:
	## Initialize system with default empty state
	for category in faction_categories.keys():
		if faction_categories[category].is_empty():
			# Generate 1-2 default factions per category
			for i: int in range(randi_range(1, 2)):
				create_faction(category)

func _generate_faction_data(faction_type: String) -> Dictionary:
	## Generate faction data based on type
	var base_data = faction_data.get(faction_type, {})

	return {
		"name": _generate_faction_name(faction_type),
		"type": faction_type,
		"strength": randi_range(MIN_FACTION_STRENGTH, MAX_FACTION_STRENGTH),
		"power": randi_range(MIN_FACTION_POWER, MAX_FACTION_POWER),
		"influence": base_data.get("base_influence", randi_range(MIN_FACTION_INFLUENCE, MAX_FACTION_INFLUENCE)),
		"tech_level": randi_range(MIN_TECH_LEVEL, MAX_TECH_LEVEL),
		"loyalty": {},
		"temporary_defense": false,
		"mission_types": base_data.get("mission_types", ["generic"]),
		"created_at": Time.get_unix_time_from_system()
	}

func _generate_rival_name() -> String:
	## Generate random rival name
	var prefixes: Array[String] = ["Captain", "Commander", "Boss", "Chief", "Leader", "Admiral", "Colonel"]
	var first_names: Array[String] = ["Alex", "Morgan", "Casey", "Jordan", "Riley", "Avery", "Blake", "Quinn"]
	var last_names: Array[String] = ["Smith", "Jones", "Blake", "Zhang", "Singh", "Rodriguez", "Volkov", "Chen"]

	return prefixes.pick_random() + " " + first_names.pick_random() + " " + last_names.pick_random()

func _select_rival_type() -> String:
	## Select random rival type
	var types: Array[String] = ["MERCENARY", "PIRATE", "TRADER", "BOUNTY_HUNTER", "SMUGGLER", "CORPORATE_AGENT", "ROGUE_MILITARY"]
	return types.pick_random()

func _generate_rival_characteristics() -> Array[String]:
	## Generate rival characteristics
	var all_characteristics: Array[String] = ["AGGRESSIVE", "CAUTIOUS", "DIPLOMATIC", "TREACHEROUS", "HONORABLE", "RESOURCEFUL", "VENGEFUL"]
	var num_characteristics: int = randi_range(2, 3)
	var characteristics: Array[String] = []

	for i: int in range(num_characteristics):
		var char = all_characteristics.pick_random()
		if not char in characteristics:
			characteristics.append(char)

	return characteristics

func _generate_faction_name(faction_type: String) -> String:
	## Generate faction name based on type
	var prefixes = {
		"government": ["United", "Federal", "Imperial", "Republic of", "Commonwealth of"],
		"corporate": ["Mega", "Stellar", "Galactic", "Universal", "Prime"],
		"criminal": ["Black", "Shadow", "Dark", "Blood", "Iron"],
		"military": ["Elite", "Special", "Advanced", "Strategic", "Tactical"],
		"religious": ["Sacred", "Holy", "Divine", "Blessed", "Righteous"],
		"mercenary": ["Free", "Independent", "Elite", "Professional", "Veteran"],
		"pirate": ["Red", "Crimson", "Skull", "Void", "Savage"],
		"alien": ["Star", "Void", "Crystal", "Plasma", "Quantum"]
	}

	var suffixes = {
		"government": ["Coalition", "Alliance", "Federation", "Union", "Empire"],
		"corporate": ["Corporation", "Industries", "Enterprises", "Syndicate", "Group"],
		"criminal": ["Syndicate", "Cartel", "Brotherhood", "Family", "Order"],
		"military": ["Command", "Division", "Regiment", "Corps", "Battalion"],
		"religious": ["Order", "Sect", "Faith", "Brotherhood", "Covenant"],
		"mercenary": ["Company", "Battalion", "Corps", "Legion", "Guard"],
		"pirate": ["Fleet", "Armada", "Raiders", "Corsairs", "Buccaneers"],
		"alien": ["Collective", "Hive", "Confederation", "Assembly", "Consortium"]
	}

	var prefix_list = prefixes.get(faction_type, ["Generic"])
	var suffix_list = suffixes.get(faction_type, ["Organization"])

	return prefix_list.pick_random() + " " + suffix_list.pick_random()

func _get_rival_by_id(rival_id: String) -> Dictionary:
	## Find rival by ID
	for rival in active_rivals:
		if rival.has("id") and rival.id == rival_id:
			return rival
	return {}

func _can_interact_with_rival(rival_id: String) -> bool:
	## Check if can interact with rival
	var status = get_rival_status(rival_id)
	return status != RIVAL_STATUS_HOSTILE and status != RIVAL_STATUS_DEFEATED

func _check_rival_reputation_thresholds(rival: Dictionary) -> void:
	## Check rival reputation thresholds and update status
	var reputation = get_rival_reputation(rival.id)
	var old_status = get_rival_status(rival.id)
	var new_status = old_status

	if reputation <= -75:
		new_status = RIVAL_STATUS_HOSTILE
	elif reputation <= -25:
		new_status = RIVAL_STATUS_UNFRIENDLY
	elif reputation <= 25:
		new_status = RIVAL_STATUS_NEUTRAL
	elif reputation <= 75:
		new_status = RIVAL_STATUS_FRIENDLY
	else:
		new_status = RIVAL_STATUS_ALLIED

	if new_status != old_status:
		rival_statuses[rival.id] = new_status
		rival_status_changed.emit(rival, new_status)

func _calculate_negotiation_chance(rival: Dictionary) -> float:
	## Calculate chance of successful negotiation
	var base_chance: float = 0.5
	var reputation = get_rival_reputation(rival.id)

	# Modify based on reputation
	base_chance += reputation / 20.0 # -0.5 to +0.5

	# Modify based on rival characteristics
	for characteristic in rival.characteristics:
		match characteristic:
			"DIPLOMATIC":
				base_chance += 0.2
			"TREACHEROUS":
				base_chance -= 0.2
			"HONORABLE":
				base_chance += 0.1
			"AGGRESSIVE":
				base_chance -= 0.1
			"CAUTIOUS":
				base_chance += 0.05

	return clamp(base_chance, 0.1, 0.9)

func _improve_rival_relations(rival: Dictionary) -> void:
	## Improve relations with rival
	var reputation_gain = randi_range(5, 15)
	update_rival_reputation(rival.id, reputation_gain)

func _worsen_rival_relations(rival: Dictionary) -> void:
	## Worsen relations with rival
	var reputation_loss = randi_range(5, 15)
	update_rival_reputation(rival.id, -reputation_loss)

func _perform_faction_activity(faction: Dictionary) -> void:
	## Perform random faction activity
	var activity_roll = randi_range(1, 100)

	match activity_roll:
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10:
			_consolidate_power(faction)
		11, 12, 13, 14, 15:
			_undermine_faction(faction)
		16, 17, 18, 19, 20:
			_hostile_takeover(faction)
		21, 22, 23, 24, 25, 26, 27, 28, 29, 30:
			_public_relations_campaign(faction)
		31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45:
			_capitalize_on_events(faction)
		46, 47, 48, 49, 50, 51, 52, 53, 54, 55:
			_lay_low(faction)
		56, 57, 58, 59, 60:
			_defensive_posture(faction)
		61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75:
			_faction_struggle(faction)
		76, 77, 78, 79, 80:
			_office_party(faction)
		81, 82, 83, 84, 85, 86, 87, 88, 89, 90:
			_plans_within_plans(faction)
		_:
			_day_to_day_operations(faction)

func _consolidate_power(faction: Dictionary) -> void:
	## Faction consolidates power
	if randi_range(1, 6) > faction.get("power", 3):
		faction.power = min(MAX_FACTION_POWER, faction.power + 1)

func _undermine_faction(faction: Dictionary) -> void:
	## Faction undermines another faction
	var targets = _get_other_factions(faction)
	if targets.is_empty():
		return

	var target = targets.pick_random()
	if randi_range(1, 6) >= 5:
		var stat_to_decrease = "power" if randi() % 2 == 0 else "influence"
		target[stat_to_decrease] = max(1, target[stat_to_decrease] - 1)

func _hostile_takeover(faction: Dictionary) -> void:
	## Faction attempts hostile takeover
	if faction.get("influence", 0) >= 3:
		var targets = _get_other_factions(faction)
		if targets.is_empty():
			return

		var target = targets.pick_random()
		if randi_range(1, 6) > target.get("influence", 0):
			target.influence = max(MIN_FACTION_INFLUENCE, target.influence - 1)
			faction.influence = min(MAX_FACTION_INFLUENCE, faction.influence + 1)

func _public_relations_campaign(faction: Dictionary) -> void:
	## Faction runs PR campaign
	if randi_range(1, 6) > faction.get("influence", 0):
		faction.influence = min(MAX_FACTION_INFLUENCE, faction.influence + 1)

func _capitalize_on_events(faction: Dictionary) -> void:
	## Faction capitalizes on events
	var stat_to_increase = "influence" if faction.get("influence", 0) <= faction.get("power", 0) else "power"
	faction[stat_to_increase] = min(MAX_FACTION_POWER, faction[stat_to_increase] + 1)

func _lay_low(faction: Dictionary) -> void:
	## Faction lays low
	# No effect - faction is inactive this turn
	pass

func _defensive_posture(faction: Dictionary) -> void:
	## Faction takes defensive posture
	if faction.get("power", 0) >= 3:
		faction.temporary_defense = true

func _faction_struggle(faction: Dictionary) -> void:
	## Faction engages in struggle
	if faction.get("power", 0) >= 3:
		var targets = _get_other_factions(faction)
		if not targets.is_empty():
			var target = targets.pick_random()
			resolve_faction_conflict(faction.get("name", ""), target.get("name", ""))

func _office_party(faction: Dictionary) -> void:
	## Faction throws office party
	# Benefits crew members with loyalty to this faction
	if _game_state and _game_state and _game_state.has_method("get_crew"):
		var crew = _game_state.get_crew()
		for character in crew:
			if character and character.has_method("get_faction_loyalty"):
				var loyalty = character.get_faction_loyalty(faction.get("name", ""))
				if loyalty > 0:
					if _game_state and _game_state.has_method("add_credits"):
						_game_state.add_credits(loyalty)

func _plans_within_plans(faction: Dictionary) -> void:
	## Faction makes complex plans
	if faction.get("influence", 0) >= 3:
		# Generate a quest/mission from this faction
		var mission = generate_faction_mission(faction.get("name", ""))
		if not mission.is_empty() and _game_state:
			if _game_state and _game_state.has_method("add_mission_opportunity"):
				_game_state.add_mission_opportunity(mission)

func _day_to_day_operations(faction: Dictionary) -> void:
	## Faction performs normal operations
	# Generate routine mission opportunity
	var mission = generate_faction_mission(faction.get("name", ""))
	if not mission.is_empty() and _game_state:
		if _game_state and _game_state.has_method("add_mission_opportunity"):
			_game_state.add_mission_opportunity(mission)

func _get_other_factions(faction: Dictionary) -> Array[Dictionary]:
	## Get other factions for interaction
	var others: Array[Dictionary] = []
	var faction_name = faction.get("name", "")

	for other_faction in active_factions.values():
		if other_faction.get("name", "") != faction_name:
			others.append(other_faction)

	return others

func _get_total_category_factions() -> int:
	## Get total number of factions across all categories
	var total: int = 0
	for category in faction_categories.values():
		total += category.size()
	return total

func _get_faction_mission_type(faction: Dictionary) -> String:
	## Get mission type for faction
	var mission_types = faction.get("mission_types", ["generic"])
	return mission_types.pick_random()

func _generate_faction_mission_name(faction: Dictionary) -> String:
	## Generate mission name for faction
	var faction_name = faction.get("name", "Unknown Faction")
	var mission_type = _get_faction_mission_type(faction)

	var templates = {
		"security": "Security Operation for %s",
		"diplomacy": "Diplomatic Mission with %s",
		"transport": "Transport Contract from %s",
		"trade": "Trade Agreement with %s",
		"combat": "Combat Mission for %s",
		"escort": "Escort Duty for %s",
		"smuggling": "Smuggling Run for %s",
		"heist": "Heist Operation for %s",
		"generic": "Mission for %s"
	}

	var template = templates.get(mission_type, "Mission for %s")
	return template % faction_name

func _generate_faction_mission_description(faction: Dictionary) -> String:
	## Generate mission description for faction
	var mission_type = _get_faction_mission_type(faction)
	var descriptions = {
		"security": "Provide security services for faction operations.",
		"diplomacy": "Conduct diplomatic negotiations on behalf of the faction.",
		"transport": "Transport valuable cargo for the faction.",
		"trade": "Facilitate trade agreements and deals.",
		"combat": "Engage in combat operations for the faction.",
		"escort": "Provide escort services for faction personnel.",
		"smuggling": "Conduct discrete smuggling operations.",
		"heist": "Execute high-risk acquisition missions.",
		"generic": "Complete important tasks for the faction."
	}

	return descriptions.get(mission_type, "Complete the assigned mission objectives.")

func _calculate_faction_mission_difficulty(faction: Dictionary) -> int:
	## Calculate mission difficulty based on faction power
	var base_difficulty = faction.get("power", 3)
	return clamp(base_difficulty + randi_range(-1, 1), 1, 5)

func _generate_faction_mission_rewards(faction: Dictionary) -> Dictionary:
	## Generate mission rewards based on faction resources
	var influence = faction.get("influence", 3)
	var base_credits = influence * 500

	return {
		"credits": base_credits + randi_range(-100, 200),
		"reputation": randi_range(5, 15),
		"faction_standing": randi_range(5, 10)
	}

func _generate_faction_mission_bonus(faction: Dictionary) -> Dictionary:
	## Generate faction-specific mission bonuses with type safety
	var faction_type_value = faction.get("type", "generic")
	var faction_type: String = faction_type_value as String if faction_type_value is String else "generic"

	var bonuses = {
		"government": {"security_clearance": true},
		"corporate": {"trade_discount": 0.1},
		"criminal": {"black_market_access": true},
		"military": {"weapon_upgrade": true},
		"religious": {"medical_support": true},
		"mercenary": {"combat_bonus": 1},
		"pirate": {"salvage_rights": true},
		"alien": {"tech_knowledge": true}
	}

	return bonuses.get(faction_type, {})

# Public API methods
func get_all_factions() -> Dictionary:
	## Get all active factions
	return active_factions.duplicate()

func get_faction_by_name(name: String) -> Dictionary:
	## Get faction by name with type safety
	for faction_variant: Variant in active_factions.values():
		if not faction_variant is Dictionary:
			continue
			
		var faction: Dictionary = faction_variant as Dictionary
		var faction_name = faction.get("name", "")
		
		if faction_name is String and (faction_name as String) == name:
			return faction
	return {}

func get_factions_by_type(faction_type: String) -> Array[Dictionary]:
	## Get all factions of specific type
	return faction_categories.get(faction_type, []).duplicate()

func has_rival(rival_id: String) -> bool:
	## Check if rival exists
	return _get_rival_by_id(rival_id) != {}

func has_faction(faction_id: String) -> bool:
	## Check if faction exists
	return active_factions.has(faction_id)

func get_faction_mission_opportunities() -> Array[Dictionary]:
	## Get available faction missions
	var opportunities: Array[Dictionary] = []

	for faction in active_factions.values():
		if randf() < 0.3: # 30% chance per faction
			var mission = generate_faction_mission(faction.get("name", ""))
			if not mission.is_empty():
				opportunities.append(mission)

	return opportunities
