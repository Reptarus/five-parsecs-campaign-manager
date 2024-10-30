extends Node
class_name MockGameState

const World = preload("res://Resources/GameData/world.gd")

# Explicitly define all properties
@onready var game_state: MockGameState = self
@onready var mission_generator: MissionGenerator
@onready var equipment_manager: EquipmentManager
@onready var patron_job_manager: PatronJobManager
@onready var current_battle: Battle
@onready var fringe_world_strife_manager: FringeWorldStrifeManager
@onready var psionic_manager: PsionicManager
@onready var story_track: StoryTrack
@onready var world_generator: WorldGenerator
@onready var expanded_faction_manager: ExpandedFactionManager
@onready var combat_manager: CombatManager
@onready var crew: Crew

var settings: Dictionary = {
	"disable_tutorial_popup": false
}
var current_state: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.MISSION
var credits: int = 0
var story_points: int = 0
var campaign_turn: int = 0
var victory_condition: Dictionary
var visited_worlds: Array[Dictionary] = []
var current_location_data: Dictionary

@export var current_ship: Ship
@export var available_missions: Array[Mission] = []
@export var current_mission: Mission
@export var patrons: Array[Patron] = []
@export var rivals: Array[Rival] = []

func _ready() -> void:
	initialize_game_state()

func initialize_game_state() -> void:
	crew = Crew.new()
	crew.initialize()
	_setup_crew()
	_setup_ship()
	_setup_missions()
	_setup_patrons_and_rivals()
	_setup_worlds()
	
	current_state = GlobalEnums.CampaignPhase.MISSION
	credits = 5000
	story_points = 3
	campaign_turn = 8
	victory_condition = {
		"type": GlobalEnums.VictoryConditionType.TURNS,
		"target": 10,
		"progress": 8
	}
	
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new()
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	psionic_manager = PsionicManager.new()
	story_track = StoryTrack.new()
	world_generator = WorldGenerator.new()
	expanded_faction_manager = ExpandedFactionManager.new(self)
	combat_manager = CombatManager.new()

func _setup_crew() -> void:
	var crew_members = [
		{
			"name": "Zara Vex",
			"combat": 3,
			"technical": 1,
			"social": 2,
			"survival": 2,
			"health": 10,
			"max_health": 10,
			"class_type": GlobalEnums.Class.SOLDIER
		},
		{
			"name": "Krix",
			"combat": 1,
			"technical": 4,
			"social": 2,
			"survival": 1,
			"health": 8,
			"max_health": 8,
			"class_type": GlobalEnums.Class.HACKER
		},
		{
			"name": "Dorn-7",
			"combat": 2,
			"technical": 3,
			"social": 1,
			"survival": 2,
			"health": 12,
			"max_health": 12,
			"class_type": GlobalEnums.Class.TECHNICIAN
		},
		{
			"name": "Luna Eclipse",
			"combat": 2,
			"technical": 2,
			"social": 4,
			"survival": 2,
			"health": 9,
			"max_health": 9,
			"class_type": GlobalEnums.Class.MERCENARY
		},
		{
			"name": "Rex Steele",
			"combat": 4,
			"technical": 1,
			"social": 1,
			"survival": 3,
			"health": 15,
			"max_health": 15,
			"class_type": GlobalEnums.Class.MERCENARY
		},
		{
			"name": "Nova Blake",
			"combat": 2,
			"technical": 3,
			"social": 2,
			"survival": 3,
			"health": 11,
			"max_health": 11,
			"class_type": GlobalEnums.Class.TECHNICIAN
		},
		{
			"name": "Cipher",
			"combat": 1,
			"technical": 5,
			"social": 1,
			"survival": 1,
			"health": 7,
			"max_health": 7,
			"class_type": GlobalEnums.Class.HACKER
		},
		{
			"name": "Echo",
			"combat": 3,
			"technical": 2,
			"social": 3,
			"survival": 2,
			"health": 10,
			"max_health": 10,
			"class_type": GlobalEnums.Class.SCIENTIST
		}
	]
	
	for member_data in crew_members:
		var crew_member = CrewMember.new()
		crew_member.set_stats(member_data)
		crew.add_character(crew_member)

func _setup_ship() -> void:
	var ship_creation = ShipCreation.new()
	
	var engine = ship_creation.create_component_from_data({
		"id": "engine_basic",
		"name": "Basic Engine",
		"description": "A standard spacecraft engine",
		"power_usage": 20,
		"health": 100,
		"weight": 500,
		"speed": 1,
		"fuel_efficiency": 1
	})
	
	var hull = ship_creation.create_component_from_data({
		"id": "hull_light",
		"name": "Light Hull",
		"description": "A basic hull for small ships",
		"power_usage": 0,
		"health": 100,
		"weight": 1000,
		"armor": 100
	})
	
	var components: Array[ShipComponent] = [engine, hull]
	
	var new_ship = ship_creation.create_ship("Stellar Nomad", components)
	new_ship.fuel = 80
	new_ship.current_hull = 75
	
	new_ship.set_initial_traits(PackedStringArray(["Light Freighter"]))
	
	for crew_member in crew.get_characters():
		new_ship.add_crew_member(crew_member)
	
	var medbay = ship_creation.create_component_from_data({
		"id": "medical_bay_advanced",
		"name": "Advanced Medbay",
		"description": "A state-of-the-art medical facility",
		"power_usage": 10,
		"health": 100,
		"weight": 200,
		"healing_capacity": 2
	})
	new_ship.add_component(medbay)
	
	current_ship = new_ship

func _setup_missions() -> void:
	var missions = [
		{
			"title": "Corporate Espionage",
			"mission_type": GlobalEnums.MissionType.SABOTAGE,
			"objective": GlobalEnums.MissionObjective.ACQUIRE,
			"difficulty": 3,
			"rewards": {"credits": 2000},
			"status": GlobalEnums.MissionStatus.ACTIVE
		},
		{
			"title": "Alien Artifact Retrieval",
			"mission_type": GlobalEnums.MissionType.RETRIEVAL,
			"objective": GlobalEnums.MissionObjective.ACQUIRE,
			"difficulty": 4,
			"rewards": {"credits": 3000},
			"status": GlobalEnums.MissionStatus.ACTIVE
		},
		{
			"title": "Fringe World Rebellion",
			"mission_type": GlobalEnums.MissionType.FRINGE_WORLD_STRIFE,
			"objective": GlobalEnums.MissionObjective.DEFEND,
			"difficulty": 5,
			"rewards": {"credits": 4000},
			"status": GlobalEnums.MissionStatus.ACTIVE
		}
	]
	
	for mission_data in missions:
		var mission = Mission.new(
			mission_data["title"],
			mission_data["title"],
			mission_data["mission_type"],
			mission_data["objective"]
		)
		mission.difficulty = mission_data["difficulty"]
		mission.rewards = mission_data["rewards"]
		mission.status = mission_data["status"]
		available_missions.append(mission)
	
	current_mission = available_missions[0]

func _setup_patrons_and_rivals() -> void:
	var patrons = [
		{
			"name": "Elara Voss",
			"faction": GlobalEnums.FactionType.NEUTRAL,
			"relationship": 7,
			"background": "A cunning corporate executive with a hidden agenda."
		},
		{
			"name": "Zhen-Tau Collective",
			"faction": GlobalEnums.FactionType.NEUTRAL,
			"relationship": 5,
			"background": "An enigmatic alien hive-mind seeking to understand human culture."
		}
	]
	
	for patron_data in patrons:
		var patron = Patron.new()
		for key in patron_data:
			patron.set(key, patron_data[key])
		self.patrons.append(patron)
	
	var rivals = [
		{
			"name": "Black Nova Syndicate",
			"faction": GlobalEnums.FactionType.HOSTILE,
			"hostility": 6,
			"strength": 4,
			"background": "A ruthless criminal organization with a grudge against the crew."
		},
		{
			"name": "Captain Mara Sov",
			"faction": GlobalEnums.FactionType.HOSTILE,
			"hostility": 3,
			"strength": 5,
			"background": "A decorated Unity captain who believes the crew is involved in illegal activities."
		}
	]
	
	for rival_data in rivals:
		var rival = Rival.new()
		for key in rival_data:
			rival.set(key, rival_data[key])
		self.rivals.append(rival)

func _setup_worlds() -> void:
	var worlds = [
		{
			"name": "New Terra",
			"type": GlobalEnums.TerrainType.CITY,
			"faction": GlobalEnums.FactionType.NEUTRAL,
			"instability": GlobalEnums.StrifeType.RESOURCE_CONFLICT
		},
		{
			"name": "Zephyr Station",
			"type": GlobalEnums.TerrainType.SPACE_STATION,
			"faction": GlobalEnums.FactionType.NEUTRAL,
			"instability": GlobalEnums.StrifeType.POLITICAL_UPRISING
		},
		{
			"name": "Crimson Nebula",
			"type": GlobalEnums.TerrainType.ALIEN_LANDSCAPE,
			"faction": GlobalEnums.FactionType.HOSTILE,
			"instability": GlobalEnums.StrifeType.ALIEN_INCURSION
		}
	]
	for world_data in worlds:
		add_visited_world(world_data)
	
	if visited_worlds.size() >= 2:
		set_current_location(visited_worlds[1])
	else:
		push_warning("Not enough visited worlds to set the second as current location.")
	
	# Remove this line as we no longer store World objects directly
	# game_state.game_world = World.new(worlds[0])

# Add this method to add a visited world
func add_visited_world(world_data: Dictionary) -> void:
	visited_worlds.append(world_data)

# Add this method to get visited worlds
func get_visited_worlds() -> Array[Dictionary]:
	return visited_worlds

# Update the set_current_location method
func set_current_location(world_data: Dictionary) -> void:
	current_location_data = world_data.duplicate()

# Update the get_current_location method
func get_current_location() -> Dictionary:
	return current_location_data

func get_game_state() -> GlobalEnums.CampaignPhase:
	return current_state

func get_current_campaign_phase() -> GlobalEnums.CampaignPhase:
	return current_state

func get_current_ship() -> Ship:
	return current_ship

func get_crew() -> Array[CrewMember]:
	return crew.get_characters()

func get_internal_game_state() -> MockGameState:
	return game_state

func set_internal_game_state(new_state: MockGameState) -> void:
	game_state = new_state

# If you need a World object, add this method
func create_current_world() -> World:
	return World.new(current_location_data) if current_location_data else null
