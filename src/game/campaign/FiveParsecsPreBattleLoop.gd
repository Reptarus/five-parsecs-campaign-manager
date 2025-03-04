@tool
class_name FiveParsecsPreBattleLoop
extends BasePreBattleLoop

const BasePreBattleLoop = preload("res://src/base/campaign/BasePreBattleLoop.gd")
const FiveParsecsMissionGenerator = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var mission_generator: FiveParsecsMissionGenerator
var terrain_types: Array = [
	"Urban", "Wilderness", "Derelict", "Industrial",
	"Space Station", "Starship", "Desert", "Jungle",
	"Ice World", "Volcanic"
]

func _init() -> void:
	super()
	mission_generator = FiveParsecsMissionGenerator.new()

func _initialize_available_missions() -> void:
	available_missions.clear()
	
	# Generate 3-5 missions of varying difficulty
	var mission_count = randi() % 3 + 3
	
	for i in range(mission_count):
		var difficulty = randi() % 4 + 1 # Difficulty 1-4
		var mission = mission_generator.generate_mission(difficulty)
		available_missions.append(mission)

func _initialize_available_locations() -> void:
	available_locations.clear()
	
	# Generate 3 locations with different terrain types
	for i in range(3):
		var terrain_index = randi() % terrain_types.size()
		var terrain_type = terrain_types[terrain_index]
		
		var location = {
			"id": str(randi()),
			"name": _generate_location_name(terrain_type),
			"terrain_type": terrain_type,
			"description": _generate_location_description(terrain_type),
			"size": randi() % 3 + 1, # 1=Small, 2=Medium, 3=Large
			"features": _generate_terrain_features(terrain_type),
			"hazards": _generate_terrain_hazards(terrain_type)
		}
		
		available_locations.append(location)

func _generate_location_name(terrain_type: String) -> String:
	var prefixes = [
		"Abandoned", "Ruined", "Desolate", "Ancient", "Contested",
		"Remote", "Forgotten", "Hidden", "Dangerous", "Mysterious"
	]
	
	var suffixes = {
		"Urban": ["District", "Sector", "Blocks", "Slums", "Marketplace"],
		"Wilderness": ["Outpost", "Valley", "Ridge", "Forest", "Plains"],
		"Derelict": ["Complex", "Facility", "Station", "Colony", "Base"],
		"Industrial": ["Factory", "Refinery", "Processing Plant", "Warehouse", "Foundry"],
		"Space Station": ["Docking Bay", "Habitat Ring", "Command Module", "Cargo Hold", "Maintenance Sector"],
		"Starship": ["Bridge", "Engine Room", "Cargo Bay", "Crew Quarters", "Hangar"],
		"Desert": ["Dunes", "Oasis", "Canyon", "Wasteland", "Settlement"],
		"Jungle": ["Clearing", "Ruins", "Canopy", "River Basin", "Temple"],
		"Ice World": ["Glacier", "Outpost", "Caverns", "Research Station", "Mining Camp"],
		"Volcanic": ["Caldera", "Lava Fields", "Ash Plains", "Thermal Vents", "Obsidian Fortress"]
	}
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = ""
	
	if suffixes.has(terrain_type):
		suffix = suffixes[terrain_type][randi() % suffixes[terrain_type].size()]
	else:
		suffix = "Location"
	
	return prefix + " " + suffix

func _generate_location_description(terrain_type: String) -> String:
	var descriptions = {
		"Urban": "A once-bustling urban area now fallen into disrepair and danger.",
		"Wilderness": "An untamed wilderness far from civilization and safety.",
		"Derelict": "An abandoned facility with unknown dangers lurking within.",
		"Industrial": "A massive industrial complex filled with machinery and hazards.",
		"Space Station": "A space station with multiple levels and confined spaces.",
		"Starship": "The interior of a starship with narrow corridors and vital systems.",
		"Desert": "A harsh desert environment with limited cover and extreme heat.",
		"Jungle": "A dense jungle with limited visibility and natural hazards.",
		"Ice World": "A frigid landscape with treacherous footing and deadly cold.",
		"Volcanic": "An active volcanic region with unstable ground and toxic gases."
	}
	
	if descriptions.has(terrain_type):
		return descriptions[terrain_type]
	
	return "A dangerous location suitable for combat operations."

func _generate_terrain_features(terrain_type: String) -> Array:
	var common_features = [
		"Cover", "Elevation", "Choke Point", "Open Area", "Defensible Position"
	]
	
	var terrain_specific_features = {
		"Urban": ["Buildings", "Streets", "Alleyways", "Rubble", "Barricades"],
		"Wilderness": ["Trees", "Rocks", "Hills", "Streams", "Clearings"],
		"Derelict": ["Collapsed Sections", "Debris", "Malfunctioning Equipment", "Sealed Rooms", "Emergency Lighting"],
		"Industrial": ["Machinery", "Catwalks", "Storage Containers", "Pipelines", "Control Rooms"],
		"Space Station": ["Airlocks", "Computer Terminals", "Life Support Systems", "Viewports", "Maintenance Tunnels"],
		"Starship": ["Bulkheads", "Control Panels", "Escape Pods", "Ventilation Ducts", "Power Conduits"],
		"Desert": ["Sand Dunes", "Rock Formations", "Dried Riverbeds", "Oases", "Ancient Ruins"],
		"Jungle": ["Dense Vegetation", "Fallen Trees", "Vines", "Mud Pits", "Ancient Structures"],
		"Ice World": ["Ice Formations", "Crevasses", "Frozen Lakes", "Snow Drifts", "Thermal Vents"],
		"Volcanic": ["Lava Flows", "Steam Vents", "Ash Clouds", "Rock Formations", "Unstable Ground"]
	}
	
	var features = []
	
	# Add 2-3 common features
	var common_count = randi() % 2 + 2
	for i in range(common_count):
		if common_features.size() > 0:
			var index = randi() % common_features.size()
			features.append(common_features[index])
			common_features.remove_at(index)
	
	# Add 2-3 terrain-specific features
	if terrain_specific_features.has(terrain_type):
		var specific_features = terrain_specific_features[terrain_type]
		var specific_count = randi() % 2 + 2
		
		for i in range(specific_count):
			if specific_features.size() > 0:
				var index = randi() % specific_features.size()
				features.append(specific_features[index])
				specific_features.remove_at(index)
	
	return features

func _generate_terrain_hazards(terrain_type: String) -> Array:
	var common_hazards = [
		"Difficult Terrain", "Poor Visibility", "Exposed Position"
	]
	
	var terrain_specific_hazards = {
		"Urban": ["Collapsing Structures", "Exposed Power Lines", "Toxic Waste", "Automated Security", "Unstable Floors"],
		"Wilderness": ["Quicksand", "Poisonous Plants", "Wild Animals", "Flash Floods", "Falling Trees"],
		"Derelict": ["Radiation Leaks", "Electrical Hazards", "Toxic Atmosphere", "Structural Collapse", "Automated Defenses"],
		"Industrial": ["Toxic Chemicals", "Extreme Heat", "Moving Machinery", "Electrical Hazards", "Explosive Materials"],
		"Space Station": ["Vacuum Exposure", "Radiation", "Zero Gravity", "Malfunctioning Systems", "Depressurization"],
		"Starship": ["System Failures", "Fire Hazards", "Gravity Fluctuations", "Radiation Leaks", "Airlock Malfunctions"],
		"Desert": ["Sandstorms", "Extreme Heat", "Dehydration", "Quicksand", "Venomous Creatures"],
		"Jungle": ["Poisonous Plants", "Dangerous Wildlife", "Disease", "Quicksand", "Flash Floods"],
		"Ice World": ["Extreme Cold", "Thin Ice", "Avalanches", "Blizzards", "Hypothermia"],
		"Volcanic": ["Lava", "Toxic Gases", "Extreme Heat", "Ash Clouds", "Earthquakes"]
	}
	
	var hazards = []
	
	# Add 1-2 common hazards
	var common_count = randi() % 2 + 1
	for i in range(common_count):
		if common_hazards.size() > 0:
			var index = randi() % common_hazards.size()
			hazards.append(common_hazards[index])
			common_hazards.remove_at(index)
	
	# Add 1-2 terrain-specific hazards
	if terrain_specific_hazards.has(terrain_type):
		var specific_hazards = terrain_specific_hazards[terrain_type]
		var specific_count = randi() % 2 + 1
		
		for i in range(specific_count):
			if specific_hazards.size() > 0:
				var index = randi() % specific_hazards.size()
				hazards.append(specific_hazards[index])
				specific_hazards.remove_at(index)
	
	return hazards

func get_deployment_zone_options(location: Dictionary) -> Array:
	var size_factor = location.get("size", 2)
	var options = []
	
	# Generate deployment zones based on location size
	for i in range(3): # Always provide 3 options
		var zone = {
			"id": str(i),
			"name": "Deployment Zone " + str(i + 1),
			"description": _generate_deployment_description(i),
			"positions": _generate_deployment_positions(size_factor),
			"advantages": _generate_deployment_advantages(i),
			"disadvantages": _generate_deployment_disadvantages(i)
		}
		
		options.append(zone)
	
	return options

func _generate_deployment_description(zone_index: int) -> String:
	var descriptions = [
		"A strategic position with good cover and visibility.",
		"A flanking position that allows for tactical movement.",
		"A defensive position with limited approaches."
	]
	
	if zone_index < descriptions.size():
		return descriptions[zone_index]
	
	return "A suitable deployment zone for your crew."

func _generate_deployment_positions(size_factor: int) -> Array:
	# This would normally generate actual grid positions
	# For this example, we'll just return placeholder data
	var positions = []
	var position_count = 5 + size_factor # 6-8 positions based on size
	
	for i in range(position_count):
		positions.append({
			"x": randi() % (10 * size_factor),
			"y": randi() % (10 * size_factor),
			"z": 0
		})
	
	return positions

func _generate_deployment_advantages(zone_index: int) -> Array:
	var all_advantages = [
		"Good Cover", "High Ground", "Multiple Approaches",
		"Defensive Position", "Good Visibility", "Close to Objectives",
		"Concealed Approach", "Tactical Flexibility", "Resource Access"
	]
	
	var advantages = []
	var advantage_count = randi() % 2 + 1 # 1-2 advantages
	
	for i in range(advantage_count):
		if all_advantages.size() > 0:
			var index = randi() % all_advantages.size()
			advantages.append(all_advantages[index])
			all_advantages.remove_at(index)
	
	return advantages

func _generate_deployment_disadvantages(zone_index: int) -> Array:
	var all_disadvantages = [
		"Limited Cover", "Exposed Position", "Restricted Movement",
		"Poor Visibility", "Far from Objectives", "Hazardous Terrain",
		"Limited Escape Routes", "Enemy Advantage", "Resource Scarcity"
	]
	
	var disadvantages = []
	var disadvantage_count = randi() % 2 + 1 # 1-2 disadvantages
	
	for i in range(disadvantage_count):
		if all_disadvantages.size() > 0:
			var index = randi() % all_disadvantages.size()
			disadvantages.append(all_disadvantages[index])
			all_disadvantages.remove_at(index)
	
	return disadvantages

func select_deployment_zone(zone_index: int, location: Dictionary) -> bool:
	var options = get_deployment_zone_options(location)
	
	if zone_index < 0 or zone_index >= options.size():
		push_error("Invalid deployment zone index: " + str(zone_index))
		return false
	
	set_deployment_positions(options[zone_index].positions)
	return true

func serialize() -> Dictionary:
	var data = super.serialize()
	
	# Add Five Parsecs specific data
	# (None needed at this time, but the function is here for future expansion)
	
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	
	# Process Five Parsecs specific data
	# (None needed at this time, but the function is here for future expansion) 