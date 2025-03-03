@tool
class_name FiveParsecsCrewSystem
extends BaseCrewSystem

const FiveParsecsCrew = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")
const FiveParsecsCrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const FiveParsecsStrangeCharacters = preload("res://src/game/campaign/crew/FiveParsecsStrangeCharacters.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")

signal battle_completed(battle_data: Dictionary)
signal campaign_event_triggered(event_data: Dictionary)
signal patron_job_completed(job_data: Dictionary)

# Five Parsecs specific properties
var current_campaign: Dictionary = {
	"type": FiveParsecsGameEnums.CampaignType.STANDARD,
	"progress": 0,
	"battles_fought": 0,
	"battles_won": 0,
	"battles_lost": 0,
	"current_mission": null,
	"completed_missions": []
}

var galaxy_map: Dictionary = {
	"current_system": "",
	"visited_systems": [],
	"known_systems": [],
	"travel_routes": []
}

var game_time: Dictionary = {
	"year": 3200,
	"month": 1,
	"day": 1,
	"total_days": 0
}

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_initialize_five_parsecs_campaign()

func _initialize_five_parsecs_campaign() -> void:
	# Initialize with Five Parsecs specific data
	current_campaign = {
		"type": FiveParsecsGameEnums.CampaignType.STANDARD,
		"progress": 0,
		"battles_fought": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"current_mission": null,
		"completed_missions": []
	}
	
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
	
	game_time = {
		"year": 3200,
		"month": 1,
		"day": 1,
		"total_days": 0
	}

func create_new_crew(crew_name: String = "New Crew") -> FiveParsecsCrew:
	var crew = FiveParsecsCrew.new()
	crew.name = crew_name
	
	# Generate random crew members
	crew.generate_random_crew(5)
	
	# Set current crew
	current_crew = {
		"captain": crew.members[0],
		"crew_members": crew.members.slice(1),
		"connections": [],
		"ship": {
			"name": crew.ship_name,
			"type": crew.ship_type
		},
		"resources": crew.credits
	}
	
	crew_changed.emit(current_crew)
	return crew

func add_strange_character(character_type: int = -1) -> FiveParsecsCrewMember:
	# Create a new crew member
	var member = FiveParsecsCrewMember.new()
	
	# Randomize class
	member.character_class = randi() % GameEnums.CharacterClass.size()
	
	# Generate random name
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
	member.character_name = first + " " + last
	
	# Apply strange character abilities
	if character_type < 0:
		character_type = randi() % 6 # Random type
	
	var strange_character = FiveParsecsStrangeCharacters.new(character_type)
	strange_character.apply_special_abilities(member)
	
	# Add to crew
	add_crew_member(member)
	
	return member

func start_new_campaign(campaign_type: int = FiveParsecsGameEnums.CampaignType.STANDARD) -> void:
	current_campaign.type = campaign_type
	current_campaign.progress = 0
	current_campaign.battles_fought = 0
	current_campaign.battles_won = 0
	current_campaign.battles_lost = 0
	current_campaign.current_mission = null
	current_campaign.completed_missions = []
	
	# Reset galaxy map
	galaxy_map.current_system = "Nexus Prime"
	galaxy_map.visited_systems = ["Nexus Prime"]
	
	# Reset game time
	game_time.year = 3200
	game_time.month = 1
	game_time.day = 1
	game_time.total_days = 0
	
	# Emit signal
	crew_changed.emit(current_crew)

func advance_time(days: int = 1) -> void:
	game_time.total_days += days
	
	# Update calendar
	var day = game_time.day + days
	var month = game_time.month
	var year = game_time.year
	
	# Simple calendar logic (assuming 30 days per month)
	while day > 30:
		day -= 30
		month += 1
		
		if month > 12:
			month = 1
			year += 1
	
	game_time.day = day
	game_time.month = month
	game_time.year = year
	
	# Check for random events based on time passing
	_check_for_time_based_events(days)

func _check_for_time_based_events(days_passed: int) -> void:
	# Chance for random events increases with more days passed
	var event_chance = days_passed * 5 # 5% per day
	
	if randi() % 100 < event_chance:
		_trigger_random_campaign_event()

func _trigger_random_campaign_event() -> void:
	var events = [
		{"type": "news", "title": "Local Conflict", "description": "A conflict has broken out in a nearby system."},
		{"type": "opportunity", "title": "Salvage Operation", "description": "A derelict ship has been spotted nearby."},
		{"type": "threat", "title": "Rival Activity", "description": "Your rivals have been spotted in the area."},
		{"type": "resource", "title": "Market Fluctuation", "description": "Prices for common goods have changed."},
		{"type": "character", "title": "Potential Recruit", "description": "You've heard of someone looking for work."}
	]
	
	var event = events[randi() % events.size()]
	campaign_event_triggered.emit(event)

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

func complete_battle(battle_data: Dictionary) -> void:
	current_campaign.battles_fought += 1
	
	if battle_data.get("victory", false):
		current_campaign.battles_won += 1
	else:
		current_campaign.battles_lost += 1
	
	# Add to completed missions if this was a mission
	if current_campaign.current_mission != null:
		current_campaign.completed_missions.append(current_campaign.current_mission)
		current_campaign.current_mission = null
	
	# Advance campaign progress
	current_campaign.progress += 1
	
	# Emit signal
	battle_completed.emit(battle_data)
	crew_changed.emit(current_crew)

func complete_patron_job(job_data: Dictionary) -> void:
	# Add rewards
	if job_data.has("credits"):
		current_crew.resources += job_data.credits
	
	# Add reputation
	if job_data.has("reputation"):
		# This would be handled by the FiveParsecsCrew instance
		if current_crew.captain and current_crew.captain.has_method("add_reputation"):
			current_crew.captain.add_reputation(job_data.reputation)
	
	# Emit signal
	patron_job_completed.emit(job_data)
	crew_changed.emit(current_crew)

func save_crew() -> Dictionary:
	var data = super.save_crew()
	
	# Add Five Parsecs specific data
	data["current_campaign"] = current_campaign
	data["galaxy_map"] = galaxy_map
	data["game_time"] = game_time
	
	return data

func load_crew(data: Dictionary) -> bool:
	var success = super.load_crew(data)
	
	if not success:
		return false
	
	# Load Five Parsecs specific data
	if data.has("current_campaign"):
		current_campaign = data.current_campaign
	
	if data.has("galaxy_map"):
		galaxy_map = data.galaxy_map
	
	if data.has("game_time"):
		game_time = data.game_time
	
	return true