@tool
class_name Crew
extends Resource

signal crew_updated
signal resources_changed

@export var members: Array[Character] = []
@export var credits: int = 0
@export var reputation: int = 0
@export var has_red_zone_license: bool = false
@export var has_black_zone_access: bool = false
@export var equipment: Array[Equipment] = []

const MAX_CREW_SIZE = 8

func get_member_count() -> int:
	return members.size()

func can_add_member() -> bool:
	return members.size() < MAX_CREW_SIZE

func get_available_members_for_mission(mission: Mission) -> Array[Character]:
	var available_members: Array[Character] = []
	for member in members:
		if member.can_participate_in_mission(mission):
			available_members.append(member)
	return available_members

func has_required_crew_for_mission(mission: Mission) -> bool:
	var available_members = get_available_members_for_mission(mission)
	if available_members.size() < mission.required_crew_size:
		return false
		
	# Check required roles
	for role in mission.required_roles:
		var has_role = false
		for member in available_members:
			if member.role == role:
				has_role = true
				break
		if not has_role:
			return false
			
	return true

func has_broker() -> bool:
	for member in members:
		if member.role == GlobalEnums.CrewRole.BROKER:
			return true
	return false

func get_total_skill_level(skill_name: String) -> int:
	var total = 0
	for member in members:
		total += member.get_skill_level(skill_name)
	return total

func add_member(character: Character) -> void:
	if can_add_member():
		members.append(character)
		crew_updated.emit()

func remove_member(character: Character) -> void:
	members.erase(character)
	crew_updated.emit()

func add_equipment(item: Equipment) -> void:
	equipment.append(item)
	resources_changed.emit()

func remove_equipment(item: Equipment) -> void:
	equipment.erase(item)
	resources_changed.emit()

func apply_casualties() -> void:
	for member in members:
		if randf() < 0.2:  # 20% chance of injury
			member.set_status(GlobalEnums.CharacterStatus.INJURED)
