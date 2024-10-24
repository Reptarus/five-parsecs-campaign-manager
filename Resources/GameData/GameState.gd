class_name GameState
extends Resource

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal credits_changed(new_amount: int)
signal story_points_changed(new_amount: int)

const DEFAULT_CREDITS: int = 0
const DEFAULT_STORY_POINTS: int = 0
const Crew = preload("res://Resources/CrewAndCharacters/Crew.gd")
const GameWorld = preload("res://Resources/GameData/world.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const Ship = preload("res://Resources/Ships/Ship.gd")

var crew: Crew 

var current_state: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.MAIN_MENU:
	set(value):
		if current_state != value:
			current_state = value
			state_changed.emit(current_state)

var current_ship: Ship
var available_locations: Array[GameWorld] = []
var current_location: GameWorld
var current_mission: Mission
var credits: int = DEFAULT_CREDITS:
	set(value):
		if credits != value:
			credits = value
			credits_changed.emit(credits)

var story_points: int = DEFAULT_STORY_POINTS:
	set(value):
		if story_points != value:
			story_points = value
			story_points_changed.emit(story_points)

var campaign_turn: int = 0
var available_missions: Array[Mission] = []
var active_quests: Array[Quest] = []
var patrons: Array[Patron] = []
var rivals: Array[Rival] = []
var character_connections: Array[Dictionary] = []
var difficulty_settings: DifficultySettings
var victory_condition: Dictionary = {}

var reputation: int = 0
var last_mission_results: String = ""
var crew_size: int = 0
var completed_patron_job_this_turn: bool = false
var held_the_field_against_roving_threat: bool = false
var active_rivals: Array[Rival] = []
var is_tutorial_active: bool = false
var trade_actions_blocked: bool = false
var mission_payout_reduction: int = 0

# New properties based on GlobalEnums.gd
var current_game_state: GlobalEnums.GameState = GlobalEnums.GameState.SETUP
var current_battle_phase: GlobalEnums.BattlePhase = GlobalEnums.BattlePhase.REACTION_ROLL
var current_cover_type: GlobalEnums.CoverType = GlobalEnums.CoverType.NONE
var current_global_event: GlobalEnums.GlobalEvent = GlobalEnums.GlobalEvent.MARKET_CRASH
var current_victory_condition: GlobalEnums.VictoryConditionType = GlobalEnums.VictoryConditionType.TURNS

func serialize() -> Dictionary:
	var serialized_data = {
		"current_state": current_state,
		"credits": credits,
		"story_points": story_points,
		"campaign_turn": campaign_turn,
		"reputation": reputation,
		"last_mission_results": last_mission_results,
		"crew_size": crew_size,
		"completed_patron_job_this_turn": completed_patron_job_this_turn,
		"held_the_field_against_roving_threat": held_the_field_against_roving_threat,
		"is_tutorial_active": is_tutorial_active,
		"trade_actions_blocked": trade_actions_blocked,
		"mission_payout_reduction": mission_payout_reduction,
		"current_game_state": current_game_state,
		"current_battle_phase": current_battle_phase,
		"current_cover_type": current_cover_type,
		"current_global_event": current_global_event,
		"current_victory_condition": current_victory_condition,
	}
	
	serialized_data["crew"] = crew.serialize() if crew else {} as Dictionary
	serialized_data["current_ship"] = current_ship.serialize() if current_ship else {} as Dictionary
	serialized_data["current_location"] = current_location.serialize() if current_location else {} as Dictionary
	serialized_data["current_mission"] = current_mission.serialize() if current_mission else null
	
	serialized_data["available_locations"] = available_locations.map(func(loc): return loc.serialize())
	serialized_data["available_missions"] = available_missions.map(func(mission): return mission.serialize())
	serialized_data["active_quests"] = active_quests.map(func(quest): return quest.serialize())
	serialized_data["patrons"] = patrons.map(func(patron): return patron.serialize())
	serialized_data["rivals"] = rivals.map(func(rival): return rival.serialize())
	serialized_data["active_rivals"] = active_rivals.map(func(rival): return rival.serialize())
	
	serialized_data["difficulty_settings"] = difficulty_settings.serialize() if difficulty_settings else null
	serialized_data["victory_condition"] = victory_condition.duplicate()
	serialized_data["character_connections"] = character_connections.duplicate()
	
	return serialized_data

func check_victory_conditions() -> bool:
	# TODO: Implement victory condition checks
	return false

func deserialize(data: Dictionary) -> void:
	assert(data.has("current_state"), "Deserialized data must contain current_state")
	
	current_state = data.get("current_state", GlobalEnums.CampaignPhase.MAIN_MENU)
	credits = data.get("credits", DEFAULT_CREDITS)
	story_points = data.get("story_points", DEFAULT_STORY_POINTS)
	campaign_turn = data.get("campaign_turn", 0)
	reputation = data.get("reputation", 0)
	last_mission_results = data.get("last_mission_results", "")
	crew_size = data.get("crew_size", 0)
	completed_patron_job_this_turn = data.get("completed_patron_job_this_turn", false)
	held_the_field_against_roving_threat = data.get("held_the_field_against_roving_threat", false)
	is_tutorial_active = data.get("is_tutorial_active", false)
	trade_actions_blocked = data.get("trade_actions_blocked", false)
	mission_payout_reduction = data.get("mission_payout_reduction", 0)
	current_game_state = data.get("current_game_state", GlobalEnums.GameState.SETUP)
	current_battle_phase = data.get("current_battle_phase", GlobalEnums.BattlePhase.REACTION_ROLL)
	current_cover_type = data.get("current_cover_type", GlobalEnums.CoverType.NONE)
	current_global_event = data.get("current_global_event", GlobalEnums.GlobalEvent.MARKET_CRASH)
	current_victory_condition = data.get("current_victory_condition", GlobalEnums.VictoryConditionType.TURNS)
	
	crew = _deserialize_resource(data.get("crew"), "Crew") as Crew
	current_ship = _deserialize_resource(data.get("current_ship"), "Ship") as Ship
	
	if data.has("current_location"):
		current_location = GameWorld.deserialize(data["current_location"])
	
	available_locations = []
	for location_data in data.get("available_locations", []):
		var location = GameWorld.deserialize(location_data)
		available_locations.append(location)
	
	current_mission = _deserialize_resource(data.get("current_mission"), "Mission") as Mission
	available_missions = _deserialize_array(data.get("available_missions", []), "Mission")
	active_quests = _deserialize_array(data.get("active_quests", []), "Quest")
	patrons = _deserialize_array(data.get("patrons", []), "Patron")
	rivals = _deserialize_array(data.get("rivals", []), "Rival")
	active_rivals = _deserialize_array(data.get("active_rivals", []), "Rival")
	
	difficulty_settings = _deserialize_resource(data.get("difficulty_settings"), "DifficultySettings")
	
	victory_condition = data.get("victory_condition", {})
	character_connections = data.get("character_connections", [])

func _deserialize_resource(resource_data: Dictionary, resource_type: String) -> Resource:
	if resource_data:
		var ResourceClass = load("res://Scripts/" + resource_type + ".gd")
		if ResourceClass:
			var resource = ResourceClass.new()
			if resource.has_method("deserialize"):
				resource.deserialize(resource_data)
			return resource
	return null

func _deserialize_array(array_data: Array, object_type: String) -> Array:
	var deserialized_array = []
	var ResourceClass = load("res://Resources/" + object_type + ".gd")
	for item_data in array_data:
		var item = ResourceClass.new()
		item.deserialize(item_data)
		deserialized_array.append(item)
	return deserialized_array
