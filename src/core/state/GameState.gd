class_name GameState
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParcsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
const SaveManager = preload("res://src/core/managers/SaveManager.gd")

signal state_changed
signal campaign_loaded(campaign: FiveParcsecsCampaign)
signal campaign_saved
signal save_started
signal save_completed(success: bool, message: String)
signal load_started
signal load_completed(success: bool, message: String)
signal resources_changed
signal turn_advanced
signal quest_added(quest: Dictionary)
signal quest_completed(quest_id: String)

# Core state
var current_phase: GameEnums.FiveParcsecsCampaignPhase = GameEnums.FiveParcsecsCampaignPhase.NONE
var turn_number: int = 0
var story_points: int = 0
var reputation: int = 0
var resources: Dictionary = {}
var active_quests: Array[Dictionary] = []
var completed_quests: Array[Dictionary] = []
var current_location = null
var player_ship = null

# Limits and settings
var max_turns: int = 100
var max_story_points: int = 5
var max_reputation: int = 100
var difficulty_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
var enable_permadeath: bool = true
var use_story_track: bool = true
var auto_save_enabled: bool = true
var auto_save_frequency: int = 15

# Campaign state
var current_campaign: FiveParcsecsCampaign
var visited_locations: Array[String] = []

# Save system
var save_manager: SaveManager
var last_save_time: int = 0

func _init() -> void:
	pass

func set_phase(phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	current_phase = phase
	state_changed.emit()

func can_transition_to(phase: GameEnums.FiveParcsecsCampaignPhase) -> bool:
	match current_phase:
		GameEnums.FiveParcsecsCampaignPhase.NONE:
			return phase == GameEnums.FiveParcsecsCampaignPhase.SETUP
		GameEnums.FiveParcsecsCampaignPhase.SETUP:
			return phase == GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN
		GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN:
			return phase in [GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
						   GameEnums.FiveParcsecsCampaignPhase.TRADE,
						   GameEnums.FiveParcsecsCampaignPhase.STORY]
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return phase == GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
		_:
			return false

func complete_phase() -> void:
	match current_phase:
		GameEnums.FiveParcsecsCampaignPhase.SETUP:
			set_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
		GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN:
			set_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP)
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP:
			set_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION)
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			set_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)

func advance_turn() -> void:
	if turn_number < max_turns:
		turn_number += 1
		turn_advanced.emit()
		state_changed.emit()
		
		if auto_save_enabled:
			_auto_save()

func get_turn_events() -> Array:
	# Generate events based on current state
	var events = []
	if current_location:
		events.append({
			"type": "location",
			"data": current_location
		})
	return events

# Resource Management
func add_resource(resource_type: GameEnums.ResourceType, amount: int) -> bool:
	if amount < 0:
		return false
	var current = get_resource(resource_type)
	resources[resource_type] = current + amount
	resources_changed.emit()
	return true

func remove_resource(resource_type: GameEnums.ResourceType, amount: int) -> bool:
	var current = get_resource(resource_type)
	if current < amount:
		return false
	resources[resource_type] = current - amount
	resources_changed.emit()
	return true

func get_resource(resource_type: GameEnums.ResourceType) -> int:
	return resources.get(resource_type, 0)

# Quest Management
func add_quest(quest: Dictionary) -> bool:
	if active_quests.size() >= 10:
		return false
	active_quests.append(quest)
	quest_added.emit(quest)
	return true

func complete_quest(quest_id: String) -> bool:
	for quest in active_quests:
		if quest.id == quest_id:
			active_quests.erase(quest)
			completed_quests.append(quest)
			quest_completed.emit(quest_id)
			return true
	return false

# Location Management
func set_location(location: Dictionary) -> void:
	current_location = location
	if not (location.id in visited_locations):
		visited_locations.append(location.id)
	state_changed.emit()

func apply_location_effects() -> void:
	if current_location and current_location.has("fuel_cost"):
		remove_resource(GameEnums.ResourceType.FUEL, current_location.fuel_cost)

# Ship Management
func set_player_ship(ship) -> void:
	player_ship = ship
	state_changed.emit()

func apply_ship_damage(amount: int) -> void:
	if player_ship:
		var hull = player_ship.get_component("hull")
		if hull:
			hull.durability = maxi(0, hull.durability - amount)
			if hull.durability == 0:
				hull.is_active = false

func repair_ship() -> void:
	if player_ship:
		var hull = player_ship.get_component("hull")
		if hull:
			hull.durability = 100
			hull.is_active = true

# Reputation System
func add_reputation(amount: int) -> void:
	reputation = mini(reputation + amount, max_reputation)
	state_changed.emit()

func remove_reputation(amount: int) -> void:
	reputation = maxi(0, reputation - amount)
	state_changed.emit()

# Story Point Management
func add_story_points(amount: int) -> void:
	story_points = mini(story_points + amount, max_story_points)
	state_changed.emit()

func use_story_point() -> bool:
	if story_points > 0:
		story_points -= 1
		state_changed.emit()
		return true
	return false

# Save System
func quick_save() -> void:
	if not current_campaign or not save_manager:
		return
		
	var save_name = "quicksave_%d" % turn_number
	var save_data = serialize()
	save_manager.save_game(save_data, save_name)

func _auto_save() -> void:
	if not current_campaign or not auto_save_enabled or not save_manager:
		return
		
	var save_name = "autosave_%d" % turn_number
	var save_data = serialize()
	save_manager.save_game(save_data, save_name)

func _on_save_manager_save_completed(success: bool, message: String) -> void:
	if success:
		last_save_time = Time.get_unix_time_from_system()
	save_completed.emit(success, message)

func _on_save_manager_load_completed(success: bool, message: String) -> void:
	load_completed.emit(success, message)

# Settings Management
func set_difficulty(new_difficulty: GameEnums.DifficultyLevel) -> void:
	difficulty_level = new_difficulty
	state_changed.emit()

func set_permadeath(enabled: bool) -> void:
	enable_permadeath = enabled
	state_changed.emit()

func set_story_track(enabled: bool) -> void:
	use_story_track = enabled
	state_changed.emit()

func set_auto_save(enabled: bool) -> void:
	auto_save_enabled = enabled
	state_changed.emit()

# Serialization
func serialize() -> Dictionary:
	var data := {
		"current_phase": current_phase,
		"turn_number": turn_number,
		"story_points": story_points,
		"reputation": reputation,
		"resources": resources.duplicate(),
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"visited_locations": visited_locations.duplicate(),
		"difficulty_level": difficulty_level,
		"enable_permadeath": enable_permadeath,
		"use_story_track": use_story_track,
		"auto_save_enabled": auto_save_enabled,
		"auto_save_frequency": auto_save_frequency
	}
	
	if current_location:
		data["current_location"] = current_location.duplicate()
	
	if player_ship:
		data["player_ship"] = player_ship.serialize()
		
	if current_campaign:
		data["campaign"] = current_campaign.serialize()
	
	return data

func deserialize(data: Dictionary) -> void:
	current_phase = data.get("current_phase", GameEnums.FiveParcsecsCampaignPhase.NONE)
	turn_number = data.get("turn_number", 0)
	story_points = data.get("story_points", 0)
	reputation = data.get("reputation", 0)
	resources = data.get("resources", {}).duplicate()
	active_quests = data.get("active_quests", []).duplicate()
	completed_quests = data.get("completed_quests", []).duplicate()
	visited_locations = data.get("visited_locations", []).duplicate()
	difficulty_level = data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	enable_permadeath = data.get("enable_permadeath", true)
	use_story_track = data.get("use_story_track", true)
	auto_save_enabled = data.get("auto_save_enabled", true)
	auto_save_frequency = data.get("auto_save_frequency", 15)
	
	if data.has("current_location"):
		current_location = data.current_location.duplicate()
	
	if data.has("player_ship"):
		player_ship = Ship.new()
		player_ship.deserialize(data.player_ship)
		
	if data.has("campaign"):
		current_campaign = FiveParcsecsCampaign.new()
		current_campaign.deserialize(data.campaign)

static func deserialize_new(data: Dictionary) -> GameState:
	var state = GameState.new()
	state.deserialize(data)
	return state

func _ready() -> void:
	save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.save_completed.connect(_on_save_manager_save_completed)
		save_manager.load_completed.connect(_on_save_manager_load_completed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	if save_manager:
		if save_manager.save_completed.is_connected(_on_save_manager_save_completed):
			save_manager.save_completed.disconnect(_on_save_manager_save_completed)
		if save_manager.load_completed.is_connected(_on_save_manager_load_completed):
			save_manager.load_completed.disconnect(_on_save_manager_load_completed)
	save_manager = null
	
	if current_campaign:
		current_campaign = null

func start_new_campaign(campaign: FiveParcsecsCampaign) -> void:
	current_campaign = campaign
	turn_number = 1
	reputation = campaign.starting_reputation
	state_changed.emit()
	
	if auto_save_enabled:
		_auto_save()

func load_campaign(save_data: Dictionary) -> void:
	load_started.emit()
	
	if not save_data.has("campaign"):
		push_error("No campaign data in save file")
		load_completed.emit(false, "No campaign data in save file")
		return
	
	var campaign_data = save_data.campaign
	current_campaign = FiveParcsecsCampaign.new()
	current_campaign.from_dictionary(campaign_data)
	
	# Load game state
	turn_number = save_data.get("turn_number", 1)
	reputation = save_data.get("reputation", 0)
	last_save_time = save_data.get("last_save_time", 0)
	
	# Load game settings
	difficulty_level = save_data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	enable_permadeath = save_data.get("enable_permadeath", true)
	use_story_track = save_data.get("use_story_track", true)
	auto_save_enabled = save_data.get("auto_save_enabled", true)
	
	campaign_loaded.emit(current_campaign)
	state_changed.emit()
	load_completed.emit(true, "Campaign loaded successfully")

func save_campaign() -> Dictionary:
	save_started.emit()
	
	if not current_campaign:
		push_error("No campaign to save")
		save_completed.emit(false, "No campaign to save")
		return {}
	
	var save_data := {
		"campaign": current_campaign.to_dictionary(),
		"turn_number": turn_number,
		"reputation": reputation,
		"last_save_time": Time.get_unix_time_from_system(),
		"difficulty_level": difficulty_level,
		"enable_permadeath": enable_permadeath,
		"use_story_track": use_story_track,
		"auto_save_enabled": auto_save_enabled
	}
	
	campaign_saved.emit()
	return save_data

func has_active_campaign() -> bool:
	return current_campaign != null

func end_campaign() -> void:
	if current_campaign and auto_save_enabled:
		_auto_save()
	
	current_campaign = null
	turn_number = 0
	reputation = 0
	state_changed.emit()

func get_campaign() -> FiveParcsecsCampaign:
	return current_campaign

func modify_reputation(amount: int) -> void:
	reputation += amount
	state_changed.emit()

# Resource Management
func has_resource(resource_type: int) -> bool:
	return resource_type in resources

func set_resource(resource_type: int, amount: int) -> void:
	resources[resource_type] = amount
	resources_changed.emit()
	state_changed.emit()

func modify_resource(resource_type: int, amount: int) -> void:
	var current = get_resource(resource_type)
	set_resource(resource_type, current + amount)

# Crew Management
func get_crew_size() -> int:
	if not current_campaign:
		return 0
	return current_campaign.get_crew_size()

# Equipment Management
func has_equipment(equipment_type: Variant) -> bool:
	if not current_campaign:
		return false
	
	# Convert string to int if needed
	var equipment_id: int
	if equipment_type is String:
		equipment_id = GameEnums.WeaponType.get(equipment_type, -1)
		if equipment_id == -1:
			push_warning("Invalid equipment type string: " + str(equipment_type))
			return false
	else:
		equipment_id = equipment_type
	
	return current_campaign.has_equipment(equipment_id)
