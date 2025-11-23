extends Control
class_name BaseCrewComponent

## Base component for crew management functionality
## Provides shared crew data management and utility methods

# Core crew data
var crew_members: Array[Character] = []
var captain: Character = null

# Crew management signals
signal crew_member_added(member: Character)
signal crew_member_removed(member: Character)
signal captain_changed(new_captain: Character)
signal crew_changed()

func _ready() -> void:
	pass

## Add a crew member to the crew
func add_crew_member(member: Character) -> void:
	if not member or not member.is_valid():
		push_error("BaseCrewComponent: Attempted to add invalid crew member")
		return
	
	if not crew_members.has(member):
		crew_members.append(member)
		crew_member_added.emit(member)
		crew_changed.emit()
		
		# Set as captain if first member
		if crew_members.size() == 1:
			set_captain(member)
		
		print("BaseCrewComponent: Added crew member: ", member.character_name)

## Remove a crew member from the crew
func remove_crew_member(member: Character) -> void:
	if crew_members.has(member):
		crew_members.erase(member)
		crew_member_removed.emit(member)
		crew_changed.emit()
		
		# Reassign captain if necessary
		if captain == member:
			captain = null
			if crew_members.size() > 0:
				set_captain(crew_members[0])
		
		print("BaseCrewComponent: Removed crew member: ", member.character_name)

## Set the crew captain
func set_captain(member: Character) -> void:
	if not crew_members.has(member):
		push_error("BaseCrewComponent: Cannot set captain - member not in crew")
		return
	
	captain = member
	captain_changed.emit(captain)
	print("BaseCrewComponent: Captain set to: ", captain.character_name)

## Get the crew captain
func get_captain() -> Character:
	return captain

## Get all crew members
func get_crew_members() -> Array[Character]:
	return crew_members

## Get the current crew size
func get_crew_size() -> int:
	return crew_members.size()

## Clear all crew members
func clear_crew() -> void:
	crew_members.clear()
	captain = null
	crew_changed.emit()
	print("BaseCrewComponent: Crew cleared")

## Calculate crew statistics
func calculate_crew_statistics() -> Dictionary:
	var stats := {
		"total_members": crew_members.size(),
		"average_combat": 0.0,
		"average_toughness": 0.0,
		"average_savvy": 0.0,
		"average_reaction": 0.0,
		"average_speed": 0.0,
		"total_xp": 0,
		"captain": captain.character_name if captain else "None"
	}
	
	if crew_members.is_empty():
		return stats
	
	var total_combat := 0
	var total_toughness := 0
	var total_savvy := 0
	var total_reaction := 0
	var total_speed := 0
	var total_xp := 0
	
	for member in crew_members:
		total_combat += member.combat
		total_toughness += member.toughness
		total_savvy += member.savvy
		total_reaction += member.reaction
		total_speed += member.speed
		total_xp += member.xp if "xp" in member else 0
	
	var member_count := float(crew_members.size())
	stats.average_combat = total_combat / member_count
	stats.average_toughness = total_toughness / member_count
	stats.average_savvy = total_savvy / member_count
	stats.average_reaction = total_reaction / member_count
	stats.average_speed = total_speed / member_count
	stats.total_xp = total_xp
	
	return stats

## Export crew data to dictionary format
func export_crew_data() -> Dictionary:
	var export_data := {
		"crew_size": crew_members.size(),
		"captain_name": captain.character_name if captain else "",
		"members": [],
		"statistics": calculate_crew_statistics()
	}
	
	for member in crew_members:
		var member_data := {
			"name": member.character_name,
			"class": member.character_class,
			"background": member.background,
			"origin": member.origin,
			"reaction": member.reaction,
			"speed": member.speed,
			"combat": member.combat,
			"toughness": member.toughness,
			"savvy": member.savvy,
			"is_captain": member == captain
		}
		export_data.members.append(member_data)
	
	return export_data

## Import crew data from dictionary format
func import_crew_data(data: Dictionary) -> void:
	clear_crew()
	
	if not data.has("members"):
		return
	
	for member_data in data.members:
		# Create character from data
		var member := Character.new()
		member.character_name = member_data.get("name", "Unknown")
		member.character_class = member_data.get("class", 0)
		member.background = member_data.get("background", 0)
		member.origin = member_data.get("origin", 0)
		member.reaction = member_data.get("reaction", 1)
		member.speed = member_data.get("speed", 4)
		member.combat = member_data.get("combat", 0)
		member.toughness = member_data.get("toughness", 3)
		member.savvy = member_data.get("savvy", 0)
		
		add_crew_member(member)
		
		if member_data.get("is_captain", false):
			set_captain(member)
	
	print("BaseCrewComponent: Imported crew with %d members" % crew_members.size())

## Validate crew completeness
func is_crew_valid() -> bool:
	if crew_members.is_empty():
		return false
	
	for member in crew_members:
		if not member or not member.is_valid():
			return false
	
	return captain != null

## Get crew member by name
func get_crew_member_by_name(member_name: String) -> Character:
	for member in crew_members:
		if member.character_name == member_name:
			return member
	return null

## Check if character is in crew
func has_crew_member(member: Character) -> bool:
	return crew_members.has(member)
