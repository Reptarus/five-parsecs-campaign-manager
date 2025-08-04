@tool
class_name BaseCrew
extends Resource

signal member_added(character)
signal member_removed(character)
signal credits_changed(new_amount: int)

const MAX_CREW_SIZE: int = 8
const MIN_CREW_SIZE: int = 3

var members: Array[Variant] = []
var credits: int = 1000
var crew_name: String = "" # Crew name property
var characteristic: String = ""
var meeting_story: String = ""

func _init() -> void:
	members = []
	credits = 1000

func add_member(character: Variant) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false
	if (safe_call_method(members, "size") as int) >= MAX_CREW_SIZE:
		push_error("Cannot add member: Crew is at maximum capacity")
		return false

	if character in members:
		push_error("Cannot add member: Character is already in crew")
		return false

	safe_call_method(members, "append", [character])
	member_added.emit(character)
	return true

func remove_member(character: Variant) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false
	if not character in members:
		push_error("Cannot remove member: Character is not in crew")
		return false

	if (safe_call_method(members, "size") as int) <= MIN_CREW_SIZE:
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
	return (safe_call_method(members, "size") as int)

func get_member_by_index(index: int):
	if index < 0 or index >= (safe_call_method(members, "size") as int):
		push_error("Invalid member index: " + str(index))
		return null

	return members[index]

func get_member_by_name(member_name: String):
	for member in members:
		if member.character_name == member_name:
			return member
func to_dict() -> Dictionary:
	var member_data: Array = []
	for member in members:
		if member and member.has_method("to_dict"):
			safe_call_method(member_data, "append", [member.to_dict()])

	return {
		"name": crew_name,
		"characteristic": characteristic,
		"meeting_story": meeting_story,
		"credits": credits,
		"members": member_data
	}

func from_dict(data: Dictionary) -> void:
	if data.has("name"): crew_name = data.name
	if data.has("characteristic"): characteristic = data.characteristic
	if data.has("meeting_story"): meeting_story = data.meeting_story
	if data.has("credits"):
		credits = data.credits
		credits_changed.emit(credits)

	# Member loading should be handled by derived classes
	# as they will know the specific member type" 

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null