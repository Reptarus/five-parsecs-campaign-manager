@tool
# REMOVED: class_name FPCM_Crew
# The authoritative version should be referenced via preload. Use explicit preloads instead of global class name.
extends BaseCrew

# Self-reference constant for external scripts
const Self = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")
const BaseCrew = preload("res://src/base/campaign/crew/BaseCrew.gd")
const FPCM_CrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")

# Five Parsecs specific properties
var ship_name: String = ""
var ship_type: int = 0 # Will use FiveParsecsGameEnums.ShipType
var reputation: int = 0
var patrons: Array = []
var rivals: Array = []
var campaign_progress: int = 0
var campaign_type: int = 0 # Will use FiveParsecsGameEnums.CampaignType
var current_system: String = ""
var visited_systems: Array = []
var story_points: int = 0

func _init() -> void:
	super ()
	name = "New Five Parsecs Crew"
	credits = 1500 # Five Parsecs starts with more credits
	
	# Ensure resource has valid path for testing/serialization
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var random_suffix = randi() % 1000000
		resource_path = "res://tests/generated/five_parsecs_crew_%d_%d.tres" % [timestamp, random_suffix]

func add_member(character) -> bool:
	# Override to ensure we're adding FiveParsecsCrewMember instances
	if not character is FPCM_CrewMember:
		push_error("Can only add FPCM_CrewMember instances to a FPCM_Crew")
		return false
	
	return super.add_member(character)

func generate_random_crew(size: int = 5) -> void:
	# Clear existing members
	members.clear()
	
	# Generate new members
	for i in range(size):
		var member = FPCM_CrewMember.new()
		
		# Randomize class
		member.character_class = randi() % FiveParsecsGameEnums.CharacterClass.size()
		
		# Generate random name
		member.character_name = _generate_random_name()
		
		# Add to crew
		add_member(member)
	
	# Generate crew characteristic and meeting story
	characteristic = _generate_crew_characteristic()
	meeting_story = _generate_meeting_story()
	
	# Generate ship
	ship_name = _generate_ship_name()
	ship_type = randi() % FiveParsecsGameEnums.ShipType.size()

func _generate_random_name() -> String:
	var first_names = [
		"Zara", "Jax", "Nova", "Kai", "Luna", "Orion", "Vega", "Cade",
		"Lyra", "Rook", "Echo", "Mace", "Piper", "Flint", "Ember", "Slate"
	]
	
	var last_names = [
		"Voss", "Reeve", "Stark", "Frost", "Drake", "Steel", "Marsh", "Blaze",
		"Storm", "Pike", "Wolfe", "Ryder", "Shaw", "Cross", "Vale", "Thorne"
	]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	
	return first + " " + last

func _generate_crew_characteristic() -> String:
	var characteristics = [
		"Mercenary", "Explorers", "Traders", "Salvagers", "Bounty Hunters",
		"Rebels", "Smugglers", "Researchers", "Privateers", "Colonists"
	]
	
	return characteristics[randi() % characteristics.size()]

func _generate_meeting_story() -> String:
	var stories = [
		"Met during a bar fight on Nexus Prime",
		"Survivors of a colony attack",
		"Former military unit gone rogue",
		"Assembled by a mysterious patron",
		"Escaped prisoners from a labor camp",
		"Crew of a salvage operation gone wrong",
		"Graduates from the same academy",
		"Brought together by a shared enemy",
		"Survivors of a ship crash",
		"Former rivals who joined forces"
	]
	
	return stories[randi() % stories.size()]

func _generate_ship_name() -> String:
	var prefixes = [
		"Star", "Void", "Nova", "Stellar", "Cosmic", "Astral", "Solar", "Lunar",
		"Galactic", "Nebula", "Quantum", "Radiant", "Phantom", "Shadow", "Rogue"
	]
	
	var suffixes = [
		"Runner", "Hawk", "Voyager", "Nomad", "Seeker", "Venture", "Horizon", "Drift",
		"Wanderer", "Marauder", "Corsair", "Raider", "Ghost", "Specter", "Wraith"
	]
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + " " + suffix

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

func add_story_points(amount: int) -> void:
	story_points += amount

func use_story_point() -> bool:
	if story_points <= 0:
		return false
	
	story_points -= 1
	return true

func add_visited_system(system_name: String) -> void:
	if not system_name in visited_systems:
		visited_systems.append(system_name)

func set_current_system(system_name: String) -> void:
	current_system = system_name
	add_visited_system(system_name)

func advance_campaign() -> void:
	campaign_progress += 1

func to_dict() -> Dictionary:
	var data = super.to_dict()
	
	# Add Five Parsecs specific data
	data["ship_name"] = ship_name
	data["ship_type"] = ship_type
	data["reputation"] = reputation
	data["patrons"] = patrons
	data["rivals"] = rivals
	data["campaign_progress"] = campaign_progress
	data["campaign_type"] = campaign_type
	data["current_system"] = current_system
	data["visited_systems"] = visited_systems
	data["story_points"] = story_points
	
	return data

func from_dict(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false
		
	if not super.from_dict(data):
		return false
	
	# Load Five Parsecs specific data
	if data.has("ship_name"): ship_name = data.ship_name
	if data.has("ship_type"): ship_type = data.ship_type
	if data.has("reputation"): reputation = data.reputation
	if data.has("patrons"): patrons = data.patrons.duplicate()
	if data.has("rivals"): rivals = data.rivals.duplicate()
	if data.has("campaign_progress"): campaign_progress = data.campaign_progress
	if data.has("campaign_type"): campaign_type = data.campaign_type
	if data.has("current_system"): current_system = data.current_system
	if data.has("visited_systems"): visited_systems = data.visited_systems.duplicate()
	if data.has("story_points"): story_points = data.story_points
	
	# Load crew members
	if data.has("members"):
		members.clear()
		for member_data in data.members:
			var member = FPCM_CrewMember.new()
			if not member.from_dict(member_data):
				push_error("Failed to load crew member data")
				return false
			if not add_member(member):
				push_error("Failed to add crew member")
				return false
	
	return true

func initialize_from_data(crew_data: Dictionary) -> void:
	# Set basic crew properties
	if crew_data.has("name"):
		name = crew_data.name
	
	if crew_data.has("credits"):
		credits = crew_data.credits
	
	if crew_data.has("ship_name"):
		ship_name = crew_data.ship_name
	
	if crew_data.has("ship_type"):
		ship_type = crew_data.ship_type
	
	if crew_data.has("reputation"):
		reputation = crew_data.reputation
	
	if crew_data.has("campaign_progress"):
		campaign_progress = crew_data.campaign_progress
	
	if crew_data.has("campaign_type"):
		campaign_type = crew_data.campaign_type
	
	if crew_data.has("current_system"):
		current_system = crew_data.current_system
	
	if crew_data.has("visited_systems"):
		visited_systems = crew_data.visited_systems.duplicate()
	
	if crew_data.has("story_points"):
		story_points = crew_data.story_points
	
	if crew_data.has("patrons"):
		patrons = crew_data.patrons.duplicate()
	
	if crew_data.has("rivals"):
		rivals = crew_data.rivals.duplicate()
	
	# Initialize crew members if provided
	if crew_data.has("members") and crew_data.members is Array:
		members.clear()
		for member_data in crew_data.members:
			var member = FPCM_CrewMember.new()
			if member.has_method("initialize_from_data"):
				member.initialize_from_data(member_data)
			members.append(member)