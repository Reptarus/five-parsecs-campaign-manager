class_name CrewSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal crew_updated
signal member_added(character: Character)
signal member_removed(character: Character)
signal task_assigned(character: Character, task: int)
signal task_completed(character: Character, task: int)
signal relationships_updated

const MAX_CREW_SIZE := 8
const MIN_CREW_SIZE := 3

var state_manager  # Reference to GameStateManager
var active_tasks: Dictionary = {} # Character: int (task)
var members: Array[Character] = []
var relationship_manager: CrewRelationshipManager

func _init(_state_manager = null) -> void:
	if _state_manager:
		state_manager = _state_manager
	relationship_manager = CrewRelationshipManager.new()
	add_child(relationship_manager)

func initialize(config: Dictionary = {}) -> void:
	if config.has("max_crew_size"):
		set_max_crew_size(config.max_crew_size)
	if config.has("relationships"):
		relationship_manager.deserialize(config.relationships)

func set_max_crew_size(size: int) -> void:
	# Implementation remains the same
	pass

func add_member(character: Character) -> bool:
	if members.size() >= MAX_CREW_SIZE:
		return false
	members.append(character)
	member_added.emit(character)
	crew_updated.emit()
	if members.size() > 1:
		relationship_manager.generate_initial_relationships(members)
		relationships_updated.emit()
	return true

func remove_member(character: Character) -> bool:
	if members.size() <= MIN_CREW_SIZE:
		return false
	var index = members.find(character)
	if index != -1:
		members.remove_at(index)
		if active_tasks.has(character):
			active_tasks.erase(character)
		member_removed.emit(character)
		crew_updated.emit()
		# Remove all relationships involving this character
		for other_member in members:
			if other_member != character:
				relationship_manager.remove_relationship(character, other_member)
		relationships_updated.emit()
		return true
	return false

func assign_task(character: Character, task: int) -> bool:
	if not character in members or active_tasks.has(character):
		return false
	active_tasks[character] = task
	task_assigned.emit(character, task)
	return true

func complete_task(character: Character) -> void:
	if not active_tasks.has(character):
		return
	var completed_task = active_tasks[character]
	active_tasks.erase(character)
	task_completed.emit(character, completed_task)

func get_available_members() -> Array[Character]:
	return members.filter(func(member: Character) -> bool: 
		return not active_tasks.has(member))

func get_task_description(task: int) -> String:
	match task:
		GlobalEnums.ResourceType.NONE: 
			return "Take a break and rest"
		GlobalEnums.ResourceType.MINERALS: 
			return "Mine valuable minerals"
		GlobalEnums.ResourceType.FUEL: 
			return "Gather and process fuel"
		GlobalEnums.ResourceType.TECHNOLOGY: 
			return "Research and develop technology"
		GlobalEnums.ResourceType.MEDICAL_SUPPLIES: 
			return "Produce medical supplies"
		GlobalEnums.ResourceType.WEAPONS: 
			return "Manufacture weapons"
		GlobalEnums.ResourceType.RARE_MATERIALS: 
			return "Search for rare materials"
		GlobalEnums.ResourceType.LUXURY_GOODS: 
			return "Trade in luxury goods"
		GlobalEnums.ResourceType.CREDITS: 
			return "Earn credits through trade"
		GlobalEnums.ResourceType.SUPPLIES: 
			return "Gather general supplies"
		GlobalEnums.ResourceType.STORY_POINT: 
			return "Investigate story leads"
		GlobalEnums.ResourceType.PATRON: 
			return "Network with potential patrons"
		GlobalEnums.ResourceType.RIVAL: 
			return "Gather intel on rivals"
		GlobalEnums.ResourceType.QUEST_RUMOR: 
			return "Search for quest opportunities"
		GlobalEnums.ResourceType.XP: 
			return "Train and gain experience"
		_: 
			return "Unknown task"

func process_task_results() -> void:
	for character in active_tasks:
		var task = active_tasks[character]
		var result = _generate_task_result(character, task)
		_apply_task_result(character, task, result)

func _generate_task_result(character: Character, task: int) -> Dictionary:
	var success = randf() < _calculate_success_chance(character, task)
	var rewards = {}
	var consequences = {}

	if success:
		rewards = _generate_task_rewards(task)
	else:
		consequences = _generate_task_consequences(task)

	return {
		"success": success,
		"rewards": rewards,
		"consequences": consequences
	}

func _calculate_success_chance(character: Character, task: int) -> float:
	var base_chance = 0.5
	
	match task:
		GlobalEnums.ResourceType.NONE:
			base_chance = 0.9
		GlobalEnums.ResourceType.CREDITS:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.MINERALS:
			base_chance += character.toughness * 0.1
		GlobalEnums.ResourceType.FUEL:
			base_chance += character.speed * 0.1
		GlobalEnums.ResourceType.TECHNOLOGY:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.MEDICAL_SUPPLIES:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.WEAPONS:
			base_chance += character.combat_skill * 0.1
		GlobalEnums.ResourceType.RARE_MATERIALS:
			base_chance += character.luck * 0.1
		GlobalEnums.ResourceType.LUXURY_GOODS:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.SUPPLIES:
			base_chance += character.speed * 0.1
		GlobalEnums.ResourceType.STORY_POINT:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.PATRON:
			base_chance += character.savvy * 0.1
		GlobalEnums.ResourceType.RIVAL:
			base_chance += character.combat_skill * 0.1
		GlobalEnums.ResourceType.QUEST_RUMOR:
			base_chance += character.luck * 0.1
		GlobalEnums.ResourceType.XP:
			base_chance += character.savvy * 0.1
			
	return clampf(base_chance, 0.1, 0.9)

func _generate_task_rewards(task: int) -> Dictionary:
	var rewards = {}
	match task:
		GlobalEnums.ResourceType.NONE:
			rewards["morale"] = 1
		GlobalEnums.ResourceType.CREDITS:
			rewards["credits"] = randi_range(50, 200)
		GlobalEnums.ResourceType.MINERALS:
			rewards["minerals"] = randi_range(1, 3)
		GlobalEnums.ResourceType.FUEL:
			rewards["fuel"] = randi_range(1, 3)
		GlobalEnums.ResourceType.TECHNOLOGY:
			rewards["technology"] = randi_range(1, 2)
		GlobalEnums.ResourceType.MEDICAL_SUPPLIES:
			rewards["medical_supplies"] = randi_range(1, 2)
		GlobalEnums.ResourceType.WEAPONS:
			rewards["weapons"] = randi_range(1, 2)
		GlobalEnums.ResourceType.RARE_MATERIALS:
			rewards["rare_materials"] = randi_range(1, 2)
		GlobalEnums.ResourceType.LUXURY_GOODS:
			rewards["luxury_goods"] = randi_range(1, 2)
		GlobalEnums.ResourceType.SUPPLIES:
			rewards["supplies"] = randi_range(2, 4)
		GlobalEnums.ResourceType.STORY_POINT:
			rewards["story_points"] = 1
		GlobalEnums.ResourceType.PATRON:
			rewards["reputation"] = randi_range(1, 2)
		GlobalEnums.ResourceType.RIVAL:
			rewards["intel"] = randi_range(1, 3)
		GlobalEnums.ResourceType.QUEST_RUMOR:
			rewards["quest_rumors"] = 1
		GlobalEnums.ResourceType.XP:
			rewards["experience"] = randi_range(10, 30)
	return rewards

func _generate_task_consequences(task: int) -> Dictionary:
	var consequences = {}
	match task:
		GlobalEnums.ResourceType.NONE:
			consequences["morale_loss"] = 1
		GlobalEnums.ResourceType.CREDITS:
			consequences["credits_lost"] = randi_range(10, 50)
		GlobalEnums.ResourceType.MINERALS:
			consequences["injury_chance"] = 0.2
		GlobalEnums.ResourceType.FUEL:
			consequences["supplies_lost"] = randi_range(1, 2)
		GlobalEnums.ResourceType.TECHNOLOGY:
			consequences["credits_lost"] = randi_range(20, 60)
		GlobalEnums.ResourceType.MEDICAL_SUPPLIES:
			consequences["supplies_lost"] = randi_range(1, 2)
		GlobalEnums.ResourceType.WEAPONS:
			consequences["credits_lost"] = randi_range(30, 70)
		GlobalEnums.ResourceType.RARE_MATERIALS:
			consequences["injury_chance"] = 0.15
		GlobalEnums.ResourceType.LUXURY_GOODS:
			consequences["credits_lost"] = randi_range(40, 80)
		GlobalEnums.ResourceType.SUPPLIES:
			consequences["credits_lost"] = randi_range(15, 45)
		GlobalEnums.ResourceType.STORY_POINT:
			consequences["morale_loss"] = 2
		GlobalEnums.ResourceType.PATRON:
			consequences["reputation_loss"] = 1
		GlobalEnums.ResourceType.RIVAL:
			consequences["injury_chance"] = 0.25
		GlobalEnums.ResourceType.QUEST_RUMOR:
			consequences["morale_loss"] = 1
		GlobalEnums.ResourceType.XP:
			consequences["fatigue"] = 2
	return consequences

func _apply_task_result(character: Character, task: int, result: Dictionary) -> void:
	if result.success:
		for reward_type in result.rewards:
			match reward_type:
				"credits":
					state_manager.campaign_manager.add_credits(result.rewards[reward_type])
				"story_points":
					state_manager.campaign_manager.add_story_points(result.rewards[reward_type])
				"experience":
					character.add_experience(result.rewards[reward_type])
				"potential_recruit":
					state_manager.campaign_manager.trigger_recruitment_event()
				"heal_amount":
					character.heal(result.rewards[reward_type])
				"repaired_items":
					state_manager.campaign_manager.repair_items(result.rewards[reward_type])
	else:
		for consequence_type in result.consequences:
			match consequence_type:
				"credits_lost":
					state_manager.campaign_manager.remove_credits(result.consequences[consequence_type])
				"injury_chance":
					if randf() < result.consequences[consequence_type]:
						character.status = GlobalEnums.CharacterStatus.INJURED
				"fatigue":
					character.add_fatigue(result.consequences[consequence_type])
				"reputation_loss":
					state_manager.campaign_manager.modify_reputation(-result.consequences[consequence_type]) 

func get_crew_characteristic() -> String:
	return relationship_manager.crew_characteristic

func get_meeting_story() -> String:
	return relationship_manager.crew_meeting_story

func get_relationship(char1: Character, char2: Character) -> String:
	return relationship_manager.get_relationship(char1, char2)

func get_all_relationships(character: Character) -> Array:
	return relationship_manager.get_all_relationships(character)

func add_relationship(char1: Character, char2: Character, relationship_type: String) -> void:
	relationship_manager.add_relationship(char1, char2, relationship_type)
	relationships_updated.emit()

func remove_relationship(char1: Character, char2: Character) -> void:
	relationship_manager.remove_relationship(char1, char2)
	relationships_updated.emit()

func serialize_relationships() -> Dictionary:
	return relationship_manager.serialize()

func deserialize_relationships(data: Dictionary) -> void:
	relationship_manager.deserialize(data)
	relationships_updated.emit()

func get_active_crew_count() -> int:
	var count := 0
	for crew_member in members:
		if crew_member.status == GlobalEnums.CharacterStatus.HEALTHY:
			count += 1
	return count
