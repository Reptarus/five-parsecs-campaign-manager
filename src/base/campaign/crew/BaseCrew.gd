@tool
extends Resource

signal member_added(character)
signal member_removed(character)
signal credits_changed(new_amount: int)

const MAX_CREW_SIZE: int = 8
const MIN_CREW_SIZE: int = 3

var members: Array = []
var credits: int = 0  # Set during campaign creation (Core Rules p.28: 1/crew + background rolls)
var name: String = ""
var characteristic: String = ""
var meeting_story: String = ""

func _init() -> void:
	members = []
	credits = 0
	
	# Ensure resource has a unique path for serialization
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var random_suffix = randi() % 1000000
		resource_path = "res://tests/generated/base_crew_%d_%d.tres" % [timestamp, random_suffix]

func add_member(character) -> bool:
	if members.size() >= MAX_CREW_SIZE:
		push_error("Cannot add member: Crew is at maximum capacity")
		return false
	
	if character in members:
		push_error("Cannot add member: Character is already in crew")
		return false
	
	members.append(character)
	member_added.emit(character)
	return true

func remove_member(character) -> bool:
	if not character in members:
		push_error("Cannot remove member: Character is not in crew")
		return false
	
	if members.size() <= MIN_CREW_SIZE:
		push_error("Cannot remove member: Crew is at minimum size")
		return false
	
	members.erase(character)
	member_removed.emit(character)
	return true

func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)

func remove_credits(amount: int) -> bool:
	if amount > credits:
		push_error("Cannot remove credits: Not enough credits available")
		return false
	
	credits -= amount
	credits_changed.emit(credits)
	return true

func get_member_count() -> int:
	return members.size()

func get_member_by_index(index: int):
	if index < 0 or index >= members.size():
		push_error("Invalid member index: " + str(index))
		return null
	
	return members[index]

func get_member_by_name(member_name: String):
	for member in members:
		if member.character_name == member_name:
			return member
	
	return null

func to_dict() -> Dictionary:
	var member_data = []
	for member in members:
		if member.has_method("to_dict"):
			member_data.append(member.to_dict())
	
	return {
		"name": name,
		"characteristic": characteristic,
		"meeting_story": meeting_story,
		"credits": credits,
		"members": member_data
	}

func from_dict(data: Dictionary) -> bool:
	if not data is Dictionary or data.is_empty():
		return false
		
	if data.has("name"): name = data.name
	if data.has("characteristic"): characteristic = data.characteristic
	if data.has("meeting_story"): meeting_story = data.meeting_story
	if data.has("credits"):
		credits = data.credits
		credits_changed.emit(credits)
	
	# Member loading should be handled by derived classes
	# as they will know the specific member type
	return true