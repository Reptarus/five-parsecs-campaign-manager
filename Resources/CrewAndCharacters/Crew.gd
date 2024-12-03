@tool
class_name Crew
extends SerializableResource

signal crew_changed
signal morale_changed(new_morale: int)
signal upkeep_failed

const MAX_SIZE := 8
const MIN_SIZE := 3
const BASE_UPKEEP := 10

@export var members: Array[Character] = []
@export var captain: Character
@export var crew_morale: int = 10
@export var credits: int = 0

# Core Rules crew tracking
var total_battles: int = 0
var battles_won: int = 0
var crew_level: int = 1
var story_points: int = 0

func _init() -> void:
	pass

func add_member(character: Character) -> bool:
	if members.size() >= MAX_SIZE:
		return false
		
	members.append(character)
	
	# If this is the first member and no captain, make them captain
	if members.size() == 1 and not captain:
		set_captain(character)
		
	character.stats_changed.connect(_on_member_stats_changed)
	character.status_changed.connect(_on_member_status_changed)
	
	crew_changed.emit()
	return true

func remove_member(character: Character) -> bool:
	if members.size() <= MIN_SIZE:
		return false
		
	var index = members.find(character)
	if index != -1:
		members.remove_at(index)
		
		if character == captain:
			captain = null
			# Try to assign new captain from remaining crew
			for member in members:
				if member.stats.leadership > 0:
					set_captain(member)
					break
		
		character.stats_changed.disconnect(_on_member_stats_changed)
		character.status_changed.disconnect(_on_member_status_changed)
		
		crew_changed.emit()
		return true
	return false

func set_captain(character: Character) -> void:
	if character in members:
		if captain:
			captain.is_captain = false
		captain = character
		captain.is_captain = true
		crew_changed.emit()

func calculate_upkeep() -> int:
	# Core Rules upkeep calculation
	var total = BASE_UPKEEP
	for member in members:
		if member.character_class == GlobalEnums.Class.SPECIALIST:
			total += 5
		elif member.character_class == GlobalEnums.Class.LEADER:
			total += 3
	return total

func handle_failed_upkeep() -> void:
	# Core Rules failed upkeep consequences
	modify_morale(-2)
	for member in members:
		if randf() < 0.2:  # 20% chance per member
			member.status = GlobalEnums.CharacterStatus.STRESSED
	upkeep_failed.emit()

func modify_morale(amount: int) -> void:
	crew_morale = clamp(crew_morale + amount, 0, 10)
	morale_changed.emit(crew_morale)

func get_active_members() -> Array[Character]:
	return members.filter(func(m): return m.can_act())

func get_injured_members() -> Array[Character]:
	return members.filter(func(m): return m.status == GlobalEnums.CharacterStatus.INJURED)

func get_member_count() -> int:
	return members.size()

func has_skill(skill_name: String, minimum_level: int = 1) -> bool:
	for member in members:
		if member.stats.get_skill_level(skill_name) >= minimum_level:
			return true
	return false

func _on_member_stats_changed() -> void:
	crew_changed.emit()

func _on_member_status_changed(_new_status: int) -> void:
	crew_changed.emit()

func serialize() -> Dictionary:
	return {
		"members": members.map(func(m): return m.serialize()),
		"captain": captain.serialize() if captain else null,
		"crew_morale": crew_morale,
		"credits": credits,
		"total_battles": total_battles,
		"battles_won": battles_won,
		"crew_level": crew_level,
		"story_points": story_points
	}

func deserialize(data: Dictionary) -> void:
	members.clear()
	for member_data in data.get("members", []):
		var character = Character.new()
		character.deserialize(member_data)
		add_member(character)
	
	if data.has("captain") and data.captain != null:
		for member in members:
			if member.serialize() == data.captain:
				set_captain(member)
				break
	
	crew_morale = data.get("crew_morale", 10)
	credits = data.get("credits", 0)
	total_battles = data.get("total_battles", 0)
	battles_won = data.get("battles_won", 0)
	crew_level = data.get("crew_level", 1)
	story_points = data.get("story_points", 0)
