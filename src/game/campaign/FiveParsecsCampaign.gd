@tool
extends BaseCampaign
# This file should be referenced via preload
# Use explicit preloads instead of global class names
const Self = preload("res://src/game/campaign/FiveParsecsCampaign.gd")

const BaseCampaign = preload("res://src/base/campaign/BaseCampaign.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const FiveParsecsCrew = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")

# Five Parsecs specific properties
var crew
var galaxy_map: Dictionary = {
	"current_system": "",
	"visited_systems": [],
	"known_systems": [],
	"travel_routes": []
}
var battle_stats: Dictionary = {
	"battles_fought": 0,
	"battles_won": 0,
	"battles_lost": 0,
	"enemies_defeated": 0,
	"crew_injuries": 0,
	"crew_deaths": 0
}
var current_mission: Dictionary = {}
var completed_missions: Array = []
var patrons: Array = []
var rivals: Array = []

func _init(name: String = "New Five Parsecs Campaign") -> void:
	super(name)
	crew = FiveParsecsCrew.new()
	crew.name = name + " Crew"
	_initialize_galaxy_map()
	_initialize_five_parsecs_resources()

func _initialize_five_parsecs_resources() -> void:
	resources = {
		"credits": 1500, # Five Parsecs starts with 1500 credits
		"reputation": 0,
		"story_points": 3,
		"salvage": 0,
		"medical_supplies": 2,
		"spare_parts": 2
	}

func _initialize_galaxy_map() -> void:
	galaxy_map = {
		"current_system": "Nexus Prime",
		"visited_systems": ["Nexus Prime"],
		"known_systems": ["Nexus Prime", "Helios", "Cygnus", "Vega", "Altair"],
		"travel_routes": [
			{"from": "Nexus Prime", "to": "Helios", "distance": 2},
			{"from": "Nexus Prime", "to": "Cygnus", "distance": 3},
			{"from": "Helios", "to": "Vega", "distance": 1},
			{"from": "Cygnus", "to": "Altair", "distance": 2}
		]
	}

func start_campaign() -> void:
	super()
	# Five Parsecs specific initialization
	if crew.members.size() == 0:
		crew.generate_random_crew(5)

func travel_to_system(system_name: String) -> bool:
	# Check if system is known
	if not system_name in galaxy_map.known_systems:
		push_error("Cannot travel to unknown system: " + system_name)
		return false
	
	# Find route
	var route = null
	for r in galaxy_map.travel_routes:
		if (r.from == galaxy_map.current_system and r.to == system_name) or \
		   (r.to == galaxy_map.current_system and r.from == system_name):
			route = r
			break
	
	if route == null:
		push_error("No direct route to system: " + system_name)
		return false
	
	# Travel takes days equal to distance
	advance_time(route.distance)
	
	# Update current system
	galaxy_map.current_system = system_name
	
	# Add to visited systems if not already visited
	if not system_name in galaxy_map.visited_systems:
		galaxy_map.visited_systems.append(system_name)
	
	return true

func add_patron(patron_data: Dictionary) -> void:
	patrons.append(patron_data)

func remove_patron(patron_id: String) -> bool:
	for i in range(patrons.size()):
		if patrons[i].id == patron_id:
			patrons.remove_at(i)
			return true
	
	return false

func add_rival(rival_data: Dictionary) -> void:
	rivals.append(rival_data)

func remove_rival(rival_id: String) -> bool:
	for i in range(rivals.size()):
		if rivals[i].id == rival_id:
			rivals.remove_at(i)
			return true
	
	return false

func record_battle_result(victory: bool, enemies_defeated: int = 0, crew_injuries: int = 0, crew_deaths: int = 0) -> void:
	battle_stats.battles_fought += 1
	
	if victory:
		battle_stats.battles_won += 1
	else:
		battle_stats.battles_lost += 1
	
	battle_stats.enemies_defeated += enemies_defeated
	battle_stats.crew_injuries += crew_injuries
	battle_stats.crew_deaths += crew_deaths

func add_mission(mission_data: Dictionary) -> void:
	current_mission = mission_data

func complete_mission(success: bool = true) -> void:
	if current_mission.size() > 0:
		current_mission["completed"] = true
		current_mission["success"] = success
		completed_missions.append(current_mission)
		current_mission = {}

func use_story_point() -> bool:
	return remove_resource("story_points", 1)

func serialize() -> Dictionary:
	var data = super.serialize()
	
	# Add Five Parsecs specific data
	data["crew"] = crew.to_dict()
	data["galaxy_map"] = galaxy_map
	data["battle_stats"] = battle_stats
	data["current_mission"] = current_mission
	data["completed_missions"] = completed_missions
	data["patrons"] = patrons
	data["rivals"] = rivals
	
	return data

func deserialize(data: Dictionary) -> Dictionary:
	# Call parent deserialize first and check if it succeeded
	var result = super.deserialize(data)
	if not result.success:
		return result
	
	# Load Five Parsecs specific data
	if data.has("crew"):
		# Try to load crew data safely
		if crew.from_dict(data.crew) != true:
			return {"success": false, "message": "Failed to load crew data"}
	
	if data.has("galaxy_map"):
		galaxy_map = data.galaxy_map.duplicate()
	
	if data.has("battle_stats"):
		battle_stats = data.battle_stats.duplicate()
	
	if data.has("current_mission"):
		current_mission = data.current_mission.duplicate()
	
	if data.has("completed_missions"):
		completed_missions = data.completed_missions.duplicate()
	
	if data.has("patrons"):
		patrons = data.patrons.duplicate()
	
	if data.has("rivals"):
		rivals = data.rivals.duplicate()
	
	return {"success": true, "message": "Five Parsecs campaign data loaded successfully"}