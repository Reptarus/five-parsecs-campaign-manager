@tool
extends Node
class_name TestFixtures

## TestFixtures
## A utility class that provides ready-to-use test fixtures for the Five Parsecs game
## This helps create consistent test objects and avoids resource loading errors

# Common script references
const GameEnumsPath = "res://src/core/systems/GlobalEnums.gd"
const FiveParsecsCampaignPath = "res://src/game/campaign/FiveParsecsCampaign.gd"
const CharacterBody2DPath = "res://src/core/characters/CharacterBody2D.gd"

# Cache for created resources
static var _cached_resources = {}
static var _instance_id_counter = 0

## Creates a mock GameState that can be used for testing when the real one isn't accessible
## This avoids "File not found" errors for FiveParsecsGameState.gd
static func create_mock_game_state() -> Node:
	var game_state = Node.new()
	game_state.name = "MockGameState"
	
	# Add minimal script to make it function like a GameState
	var script = GDScript.new()
	script.source_code = """
@tool
extends Node

signal state_changed
signal campaign_loaded(campaign)
signal campaign_saved
signal save_started
signal save_completed(success, message)
signal load_started
signal load_completed(success, message)

var current_campaign = null
var game_settings = {
	"last_campaign": "",
	"recently_used_campaigns": [],
	"auto_load_last_campaign": false,
	"backup_save_count": 3,
	"created_campaigns_count": 0
}
var game_options = {
	"tutorials_enabled": true,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false
}

func set_current_campaign(campaign) -> void:
	current_campaign = campaign
	if campaign != null:
		campaign_loaded.emit(campaign)
	state_changed.emit()

func get_current_campaign():
	return current_campaign

func new_campaign(campaign_data: Dictionary):
	if campaign_data == null:
		push_error("Campaign data is null")
		return null
		
	var campaign = Resource.new()
	
	# Create a script for the campaign
	var script = GDScript.new()
	script.source_code = '''
extends Resource

var campaign_id = "test_campaign_" + str(randi())
var campaign_name = "Test Campaign"
var difficulty = 1
var credits = 1000
var supplies = 5
var turn = 1
var phase = 0

func initialize_from_data(data = {}):
	if data.has("campaign_id"):
		campaign_id = data.campaign_id
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("credits"):
		credits = data.credits
	if data.has("supplies"):
		supplies = data.supplies
	return true
	
func serialize():
	return {
		"campaign_id": campaign_id,
		"campaign_name": campaign_name,
		"difficulty": difficulty,
		"credits": credits,
		"supplies": supplies,
		"turn": turn,
		"phase": phase
	}
	
func deserialize(data):
	return initialize_from_data(data)
'''
	script.reload()
	campaign.set_script(script)
	
	# Initialize campaign with data
	if campaign.has_method("initialize_from_data"):
		campaign.initialize_from_data(campaign_data)
	
	return campaign

func save_campaign():
	if current_campaign and current_campaign.has_method("serialize"):
		return current_campaign.serialize()
	return {}

func load_campaign(save_data):
	var campaign = new_campaign({})
	if campaign.has_method("deserialize"):
		campaign.deserialize(save_data)
	set_current_campaign(campaign)
	return true

func set_resource(resource_type, amount):
	if current_campaign:
		if current_campaign.has_method("set_resource"):
			current_campaign.set_resource(resource_type, amount)
		elif "resources" in current_campaign:
			if not current_campaign.resources:
				current_campaign.resources = {}
			current_campaign.resources[resource_type] = amount

func get_resource(resource_type):
	if current_campaign:
		if current_campaign.has_method("get_resource"):
			return current_campaign.get_resource(resource_type)
		elif "resources" in current_campaign:
			if current_campaign.resources and current_campaign.resources.has(resource_type):
				return current_campaign.resources[resource_type]
	return 0

func has_resource(resource_type):
	return get_resource(resource_type) > 0

func get_crew_size():
	if current_campaign and "crew" in current_campaign:
		if current_campaign.crew:
			if current_campaign.crew.has_method("get_size"):
				return current_campaign.crew.get_size()
			elif "members" in current_campaign.crew:
				return current_campaign.crew.members.size()
	return 0
"""
	script.reload()
	game_state.set_script(script)
	
	return game_state

## Creates a mock FiveParsecsCampaign for testing that doesn't require loading the actual class
static func create_mock_campaign(campaign_name: String = "Test Campaign") -> Resource:
	var campaign = Resource.new()
	campaign.resource_path = "res://tests/generated/test_campaign_%d.tres" % (_instance_id_counter)
	_instance_id_counter += 1
	
	# Add minimal script
	var script = GDScript.new()
	script.source_code = """
extends Resource

var campaign_id = "test_campaign_" + str(randi())
var campaign_name = "Test Campaign"
var difficulty = 1
var campaign_difficulty = 1
var credits = 1000
var supplies = 5
var turn = 1
var phase = 0
var resources = {
	"credits": 1000,
	"supplies": 5,
	"story_points": 3,
	"salvage": 0,
	"medical_supplies": 2,
	"spare_parts": 2
}
var crew = null
var patrons = []
var rivals = []
var current_mission = {}
var completed_missions = []
var battle_stats = {
	"battles_fought": 0,
	"battles_won": 0,
	"battles_lost": 0,
	"enemies_defeated": 0,
	"crew_injuries": 0,
	"crew_deaths": 0
}
var galaxy_map = {
	"current_system": "Nexus Prime",
	"visited_systems": ["Nexus Prime"],
	"known_systems": ["Nexus Prime", "Helios", "Cygnus", "Vega", "Altair"],
	"travel_routes": []
}

signal campaign_state_changed(property)

func _init(name: String = "Test Campaign"):
	campaign_name = name

func get_campaign_id():
	return campaign_id
	
func get_campaign_name():
	return campaign_name
	
func get_resource(resource_name):
	if resources.has(resource_name):
		return resources[resource_name]
	return 0
	
func set_resource(resource_name, value):
	resources[resource_name] = value
	campaign_state_changed.emit(resource_name)
	
func add_resource(resource_name, amount):
	if resources.has(resource_name):
		resources[resource_name] += amount
	else:
		resources[resource_name] = amount
	campaign_state_changed.emit(resource_name)
	
func remove_resource(resource_name, amount):
	if resources.has(resource_name):
		resources[resource_name] = max(0, resources[resource_name] - amount)
	campaign_state_changed.emit(resource_name)
	return true
	
func initialize_from_data(data = {}):
	if data.has("campaign_id"):
		campaign_id = data.campaign_id
	if data.has("campaign_name"):
		campaign_name = data.campaign_name
	if data.has("difficulty"):
		difficulty = data.difficulty
		campaign_difficulty = data.difficulty
	if data.has("resources") and data.resources is Dictionary:
		for key in data.resources:
			resources[key] = data.resources[key]
	if data.has("crew"):
		# Create mock crew
		crew = create_mock_crew()
	return true
	
func serialize():
	return {
		"campaign_id": campaign_id,
		"campaign_name": campaign_name,
		"difficulty": difficulty,
		"resources": resources,
		"battle_stats": battle_stats,
		"galaxy_map": galaxy_map,
		"current_mission": current_mission,
		"completed_missions": completed_missions,
		"patrons": patrons,
		"rivals": rivals
	}
	
func deserialize(data):
	var result = initialize_from_data(data)
	return {"success": result, "message": "Campaign loaded"}
	
func start_campaign():
	phase = 1
	campaign_state_changed.emit("phase")
	return true
	
func end_campaign(victory = false):
	phase = 99
	battle_stats["victory"] = victory
	campaign_state_changed.emit("phase")
	return true
	
func add_patron(patron_data):
	patrons.append(patron_data)
	campaign_state_changed.emit("patrons")
	
func add_rival(rival_data):
	rivals.append(rival_data)
	campaign_state_changed.emit("rivals")
	
func complete_mission(success = true):
	if current_mission:
		completed_missions.append(current_mission)
		current_mission = {}
		battle_stats["battles_fought"] += 1
		if success:
			battle_stats["battles_won"] += 1
		else:
			battle_stats["battles_lost"] += 1
		campaign_state_changed.emit("missions")
	
func create_mock_crew():
	# Changed from Object.new() to Node.new() for better script compatibility
	var crew_obj = Node.new()
	crew_obj.name = campaign_name + " Crew"
	crew_obj.members = []
	
	# Create a script for the crew
	var script = GDScript.new()
	script.source_code = '''
extends Node

var name = "Test Crew"
var members = []

func get_size():
	return members.size()
	
func generate_random_crew(size = 5):
	members.clear()
	for i in range(size):
		members.append({
			"id": "member_" + str(i),
			"name": "Crew Member " + str(i),
			"health": 100,
			"skills": ["combat", "pilot", "tech"][i % 3],
			"equipment": []
		})
	return true
'''
	script.reload()
	crew_obj.set_script(script)
	
	if crew_obj.has_method("generate_random_crew"):
		crew_obj.generate_random_crew(5)
	
	return crew_obj
"""
	script.reload()
	campaign.set_script(script)
	
	# Set campaign name
	if campaign and "campaign_name" in campaign:
		campaign.campaign_name = campaign_name
	
	return campaign

## Creates a mock enemy with properly initialized enemy_data to avoid missing data errors
static func create_mock_enemy(enemy_id: String = "", include_data: bool = true) -> Node:
	# Create base node
	var enemy = Node.new()
	
	if enemy_id.is_empty():
		_instance_id_counter += 1
		enemy_id = "enemy_%d" % _instance_id_counter
	
	enemy.name = "Enemy_" + enemy_id
	
	# Create a script for the enemy that includes CharacterBody2D functionality
	var script = GDScript.new()
	script.source_code = """
extends Node

var enemy_data = null
@export var character_id = "%s"

func _ready():
	# Ensure enemy_data is always set
	if enemy_data == null:
		enemy_data = {
			"id": character_id,
			"health": 100,
			"max_health": 100,
			"damage": 10,
			"armor": 5,
			"speed": 3,
			"type": "basic",
			"skills": ["melee", "ranged"],
			"inventory": []
		}

func set_enemy_data(data):
	enemy_data = data.duplicate() if data else {}
	
	# If not all required fields are present, add defaults
	if not enemy_data.has("id"):
		enemy_data["id"] = character_id
	if not enemy_data.has("health"):
		enemy_data["health"] = 100
	if not enemy_data.has("max_health"):
		enemy_data["max_health"] = 100
	if not enemy_data.has("damage"):
		enemy_data["damage"] = 10
		
func get_enemy_data():
	return enemy_data
	
func move_to(position):
	# Mock movement function
	return true
	
func attack(target):
	# Mock attack function
	return true
""" % enemy_id
	script.reload()
	enemy.set_script(script)
	
	# Initialize enemy_data
	if include_data and enemy.has_method("set_enemy_data"):
		enemy.set_enemy_data({
			"id": enemy_id,
			"health": 100,
			"max_health": 100,
			"damage": 10,
			"armor": 5,
			"speed": 3,
			"type": "basic",
			"skills": ["melee", "ranged"],
			"inventory": []
		})
	
	return enemy

## Creates a mock mission for testing
static func create_mock_mission(mission_id: String = "") -> Resource:
	if mission_id.is_empty():
		_instance_id_counter += 1
		mission_id = "mission_%d" % _instance_id_counter
	
	var mission = Resource.new()
	mission.resource_path = "res://tests/generated/test_mission_%s.tres" % mission_id
	
	# Create script for mission
	var script = GDScript.new()
	script.source_code = """
extends Resource

var mission_id = "%s"
var mission_name = "Test Mission"
var mission_description = "A test mission"
var mission_type = 0 # Use an enum value from GameEnums
var difficulty = 2
var required_crew_size = 3
var required_equipment = []
var required_resources = {}
var reward_credits = 500
var reward_reputation = 2
var reward_items = []
var is_active = false
var is_completed = false
var is_failed = false
var objectives = []

func add_objective(objective_type, description, required = true):
	objectives.append({
		"type": objective_type,
		"description": description,
		"required": required,
		"completed": false
	})
	
func configure(mission_type):
	self.mission_type = mission_type
	# Set up configuration based on type
	match mission_type:
		0: # Patrol
			mission_name = "Patrol Mission"
			required_crew_size = 3
		1: # Rescue
			mission_name = "Rescue Mission"
			required_crew_size = 4
		2: # Sabotage
			mission_name = "Sabotage Mission"
			required_crew_size = 5
	return true
	
func validate():
	return {
		"is_valid": true,
		"errors": []
	}
	
func get_objective_count():
	return objectives.size()
	
func get_required_objective_count():
	var count = 0
	for obj in objectives:
		if obj.required:
			count += 1
	return count
""" % mission_id
	script.reload()
	mission.set_script(script)
	
	return mission

## Clean up cached resources to prevent memory leaks
static func cleanup():
	for resource in _cached_resources.values():
		if resource is Resource and resource.resource_path.begins_with("res://tests/generated/"):
			resource.take_over_path("")
	
	_cached_resources.clear()
	_instance_id_counter = 0