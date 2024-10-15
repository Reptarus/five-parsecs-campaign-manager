class_name GameState
extends Resource

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal credits_changed(new_amount: int)
signal story_points_changed(new_amount: int)

const DEFAULT_CREDITS: int = 0
const DEFAULT_STORY_POINTS: int = 0

@export var current_state: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.MAIN_MENU
@export var credits: int = DEFAULT_CREDITS
@export var story_points: int = DEFAULT_STORY_POINTS
@export var crew: Crew
@export var current_ship: Ship
@export var current_location: Resource
@export var available_locations: Array[Resource] = []
@export var current_mission: Resource
@export var available_missions: Array[Resource] = []
@export var active_quests: Array[Resource] = []
@export var patrons: Array[Resource] = []
@export var rivals: Array[Resource] = []
@export var active_rivals: Array[Resource] = []
@export var campaign_turn: int = 0
@export var character_connections: Array[Dictionary] = []
@export var difficulty_settings: Resource
@export var victory_condition: Dictionary = {}
@export var reputation: int = 0
@export var last_mission_results: String = ""
@export var crew_size: int = 0
@export var completed_patron_job_this_turn: bool = false
@export var held_the_field_against_roving_threat: bool = false
@export var is_tutorial_active: bool = false
@export var trade_actions_blocked: bool = false
@export var mission_payout_reduction: int = 0
@export var current_game_state: GlobalEnums.GameState = GlobalEnums.GameState.SETUP
@export var current_battle_phase: GlobalEnums.BattlePhase = GlobalEnums.BattlePhase.REACTION_ROLL
@export var current_cover_type: GlobalEnums.CoverType = GlobalEnums.CoverType.NONE
@export var current_global_event: GlobalEnums.GlobalEvent = GlobalEnums.GlobalEvent.MARKET_CRASH
@export var current_victory_condition: GlobalEnums.VictoryConditionType = GlobalEnums.VictoryConditionType.TURNS

func serialize() -> Dictionary:
	var serialized_data = {}
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(property.name)
			if value is Resource:
				serialized_data[property.name] = value.serialize() if value.has_method("serialize") else null
			elif value is Array and value.size() > 0 and value[0] is Resource:
				serialized_data[property.name] = value.map(func(item): return item.serialize() if item.has_method("serialize") else null)
			else:
				serialized_data[property.name] = value
	return serialized_data

func deserialize(data: Dictionary) -> void:
	for key in data.keys():
		if key in self:
			var value = data[key]
			if get(key) is Resource and value is Dictionary:
				get(key).deserialize(value)
			elif get(key) is Array and value is Array:
				set(key, _deserialize_array(value, key))
			else:
				set(key, value)

func _deserialize_array(array_data: Array, property_name: String) -> Array:
	var deserialized_array = []
	var property_class = get_property_class(property_name)
	if property_class:
		for item_data in array_data:
			var item = property_class.new()
			if item.has_method("deserialize"):
				item.deserialize(item_data)
			deserialized_array.append(item)
	return deserialized_array

func get_property_class(property_name: String) -> GDScript:
	match property_name:
		"available_locations", "current_location":
			return load("res://Resources/Location.gd")
		"available_missions", "current_mission":
			return load("res://Resources/Mission.gd")
		"active_quests":
			return load("res://Resources/Quest.gd")
		"patrons":
			return load("res://Resources/Patron.gd")
		"rivals", "active_rivals":
			return load("res://Resources/Rival.gd")
	return null
