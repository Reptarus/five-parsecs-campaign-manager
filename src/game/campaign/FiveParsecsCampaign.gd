@tool
extends BaseCampaign
# This file should be referenced via preload
# Use explicit preloads instead of global class names
const Self = preload("res://src/game/campaign/FiveParsecsCampaign.gd")

const BaseCampaign = preload("res://src/base/campaign/BaseCampaign.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const FiveParsecsCrew = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")

# Five Parsecs specific properties
var campaign_id: String = "":
	get:
		# Return campaign_id if it exists, otherwise generate one from the name
		if campaign_id.is_empty() and not campaign_name.is_empty():
			# Create a reproducible ID based on name and creation time
			var timestamp = Time.get_unix_time_from_system()
			campaign_id = campaign_name.to_lower().replace(" ", "_") + "_" + str(timestamp)
		return campaign_id

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
	super (name)
	crew = FiveParsecsCrew.new()
	crew.name = name + " Crew"
	_initialize_galaxy_map()
	_initialize_five_parsecs_resources()
	
	# Generate a campaign ID from the name if needed
	if campaign_id.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		campaign_id = name.to_lower().replace(" ", "_") + "_" + str(timestamp)

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
	super ()
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
	data["campaign_id"] = campaign_id
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
	
	# Load campaign_id if available
	if data.has("campaign_id"):
		campaign_id = data.campaign_id
	
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

func initialize_from_data(campaign_data: Dictionary) -> void:
	# Initialize basic campaign properties from parent class first
	if campaign_data.has("name"):
		campaign_name = campaign_data.name
	else:
		campaign_name = "New Five Parsecs Campaign"
	
	# Initialize campaign_id if provided
	if campaign_data.has("id") or campaign_data.has("campaign_id"):
		campaign_id = campaign_data.get("id", campaign_data.get("campaign_id", ""))
	# Otherwise generate a new one
	else:
		var timestamp = Time.get_unix_time_from_system()
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_" + str(timestamp)
	
	# Set difficulty if provided
	if campaign_data.has("difficulty"):
		campaign_difficulty = campaign_data.difficulty
	
	# Initialize resources from provided data or use defaults
	if campaign_data.has("resources") and campaign_data.resources is Dictionary:
		# Start with default resources to ensure all fields exist
		_initialize_five_parsecs_resources()
		
		# Then override with provided values
		for key in campaign_data.resources:
			resources[key] = campaign_data.resources[key]
	else:
		# Fall back to default resources
		_initialize_five_parsecs_resources()
	
	# Initialize crew
	if crew == null:
		crew = FiveParsecsCrew.new()
		crew.name = campaign_name + " Crew"
	
	# Initialize crew data if provided
	if campaign_data.has("crew"):
		if campaign_data.crew is Dictionary:
			crew.initialize_from_data(campaign_data.crew)
		elif campaign_data.has("crew_size") and campaign_data.crew_size is int:
			# Generate random crew if only size specified
			crew.generate_random_crew(campaign_data.crew_size)
	
	# Initialize galaxy map with defaults first
	_initialize_galaxy_map()
	
	# Override with provided galaxy data if available
	if campaign_data.has("galaxy_map") and campaign_data.galaxy_map is Dictionary:
		for key in campaign_data.galaxy_map:
			galaxy_map[key] = campaign_data.galaxy_map[key]
	
	# Initialize battle stats
	if campaign_data.has("battle_stats") and campaign_data.battle_stats is Dictionary:
		battle_stats = campaign_data.battle_stats.duplicate()
	
	# Set patrons and rivals
	if campaign_data.has("patrons") and campaign_data.patrons is Array:
		patrons = campaign_data.patrons.duplicate()
		
	if campaign_data.has("rivals") and campaign_data.rivals is Array:
		rivals = campaign_data.rivals.duplicate()
	
	# Set missions
	if campaign_data.has("current_mission") and campaign_data.current_mission is Dictionary:
		current_mission = campaign_data.current_mission.duplicate()
		
	if campaign_data.has("completed_missions") and campaign_data.completed_missions is Array:
		completed_missions = campaign_data.completed_missions.duplicate()
	
	# Equivalent to start_campaign but without generating crew if specified
	if not campaign_data.get("skip_initialization", false):
		start_campaign()

## Override the built-in get method to provide safe access to campaign properties
func get(property_name) -> Variant:
	# Convert to string just in case it's a StringName
	var prop_name = str(property_name)
	
	match prop_name:
		"resources":
			return resources
		"campaign_id", "id":
			return campaign_id
		"campaign_name", "name":
			return campaign_name
		"campaign_difficulty", "difficulty":
			return campaign_difficulty
		"crew":
			return crew
		"galaxy_map":
			return galaxy_map
		"battle_stats":
			return battle_stats
		"current_mission":
			return current_mission
		"completed_missions":
			return completed_missions
		"patrons":
			return patrons
		"rivals":
			return rivals
		_:
			# Check if it's a resource first
			if resources != null and resources.has(prop_name):
				return resources[prop_name]
			
			# Call parent implementation which handles the default case
			return super.get(property_name)

## Set a resource value in the campaign
func set_resource(resource_key, value) -> bool:
	if resources == null:
		resources = {}
	
	# Convert the key to string in case it's an enum
	var key_str = str(resource_key)
	resources[key_str] = value
	
	# Emit the resources_changed signal if we have it
	if has_signal("resources_changed"):
		emit_signal("resources_changed", resources)
	
	return true

## Helper method to check if a resource exists
func has_resource(resource_key) -> bool:
	var key_str = str(resource_key)
	return resources != null and resources.has(key_str)

## Override get_resource from parent to handle resources properly
## @param resource_key: The resource identifier (can be int, string, or any type convertible to string)
## @return: The resource value as an integer
func get_resource(resource_key: Variant) -> int:
	var key_str = str(resource_key)
	if resources != null and resources.has(key_str):
		var value = resources[key_str]
		# Ensure we return an integer as the parent expects
		if value is int:
			return value
		elif value is float:
			return int(value)
		elif value is String and value.is_valid_int():
			return value.to_int()
		elif value is bool:
			return 1 if value else 0
	
	# Default to parent implementation - convert parameter to string
	return super.get_resource(key_str)

## Helper method for crew access
func get_crew():
	return crew

## Helper method for crew member access
func get_crew_member(index: int):
	if crew == null or crew.members == null or index < 0 or index >= crew.members.size():
		return null
	return crew.members[index]

## Helper to get the size of the crew
func get_crew_size() -> int:
	if crew == null or crew.members == null:
		return 0
	return crew.members.size()

## Get the current system name
func get_current_system() -> String:
	if galaxy_map == null or not galaxy_map.has("current_system"):
		return ""
	return galaxy_map.current_system

## This is a helper method to ensure BaseCampaign resources are properly handled
func has_method(method_name) -> bool:
	# Convert to string just in case it's a StringName
	var method_str = str(method_name)
	return super.has_method(method_name) or has_signal(method_str)

## This overrides the empty dict check in case empty dicts are valid in some contexts
func is_empty() -> bool:
	return campaign_name.is_empty() and resources.is_empty() and campaign_id.is_empty()

## Helper to check for crew existence
func has_crew() -> bool:
	return crew != null

## Helper for campaign id access
func get_campaign_id() -> String:
	return campaign_id

## Additional method to check for equipment
func has_equipment(equipment_id) -> bool:
	# Convert to int if it's a string that can be converted
	var equip_id = equipment_id
	if equip_id is String and equip_id.is_valid_int():
		equip_id = equip_id.to_int()
	
	# Check if any crew member has this equipment
	if has_crew():
		for member in crew.members:
			if member and member.has_method("has_equipment") and member.has_equipment(equip_id):
				return true
	
	return false
