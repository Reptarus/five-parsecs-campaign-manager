class_name CrewSystem
extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")

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

func _init(_state_manager) -> void:
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
		GameEnums.CrewTask.IDLE: 
			return "Take a break and rest"
		GameEnums.CrewTask.TRADE: 
			return "Search for profitable trade opportunities"
		GameEnums.CrewTask.SCOUT: 
			return "Scout the local area for opportunities"
		GameEnums.CrewTask.TRAIN: 
			return "Improve skills through training"
		GameEnums.CrewTask.HEAL: 
			return "Recover from injuries or provide medical aid"
		GameEnums.CrewTask.REPAIR: 
			return "Repair and maintain equipment"
		GameEnums.CrewTask.RESEARCH: 
			return "Study and gather information"
		GameEnums.CrewTask.GUARD: 
			return "Protect the crew and assets"
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
		GameEnums.CrewTask.IDLE:
			base_chance = 0.9
		GameEnums.CrewTask.TRADE:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.SAVVY) * 0.1
		GameEnums.CrewTask.SCOUT:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.REACTIONS) * 0.1
		GameEnums.CrewTask.TRAIN:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.SAVVY) * 0.1
		GameEnums.CrewTask.HEAL:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.SAVVY) * 0.1
		GameEnums.CrewTask.REPAIR:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.SAVVY) * 0.1
		GameEnums.CrewTask.RESEARCH:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.SAVVY) * 0.1
		GameEnums.CrewTask.GUARD:
			base_chance += character.stats.get_stat(GameEnums.CharacterStats.COMBAT_SKILL) * 0.1
			
	return clampf(base_chance, 0.1, 0.9)

func _generate_task_rewards(task: int) -> Dictionary:
	var rewards = {}
	match task:
		GameEnums.CrewTask.IDLE:
			rewards["morale"] = 1
		GameEnums.CrewTask.TRADE:
			rewards["credits"] = randi_range(50, 200)
		GameEnums.CrewTask.SCOUT:
			rewards["story_points"] = 1
			rewards["intel"] = randi_range(1, 3)
		GameEnums.CrewTask.TRAIN:
			rewards["experience"] = randi_range(10, 30)
		GameEnums.CrewTask.HEAL:
			rewards["heal_amount"] = randi_range(1, 3)
		GameEnums.CrewTask.REPAIR:
			rewards["repaired_items"] = randi_range(1, 3)
		GameEnums.CrewTask.RESEARCH:
			rewards["research_points"] = randi_range(1, 3)
			rewards["experience"] = randi_range(5, 15)
		GameEnums.CrewTask.GUARD:
			rewards["security_level"] = 1
			rewards["morale"] = 1
	return rewards

func _generate_task_consequences(task: int) -> Dictionary:
	var consequences = {}
	match task:
		GameEnums.CrewTask.IDLE:
			consequences["morale_loss"] = 1
		GameEnums.CrewTask.TRADE:
			consequences["credits_lost"] = randi_range(10, 50)
		GameEnums.CrewTask.SCOUT:
			consequences["injury_chance"] = 0.2
		GameEnums.CrewTask.TRAIN:
			consequences["fatigue"] = 1
		GameEnums.CrewTask.HEAL:
			consequences["supplies_lost"] = randi_range(1, 2)
		GameEnums.CrewTask.REPAIR:
			consequences["credits_lost"] = randi_range(15, 45)
			consequences["equipment_damage"] = 1
		GameEnums.CrewTask.RESEARCH:
			consequences["fatigue"] = 2
			consequences["supplies_lost"] = 1
		GameEnums.CrewTask.GUARD:
			consequences["injury_chance"] = 0.15
			consequences["fatigue"] = 1
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
						character.status = GameEnums.CharacterStatus.INJURED
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
