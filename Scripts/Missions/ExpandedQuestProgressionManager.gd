class_name ExpandedQuestProgressionManager
extends Node

const QUEST_STAGES_PATH = "res://data/expanded_quest_progressions.json"

var game_state: GameState
var quest_stages: Dictionary
var active_quests: Array[Quest] = []

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	load_quest_stages()

func load_quest_stages() -> void:
	var file = FileAccess.open(QUEST_STAGES_PATH, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		quest_stages = json.get_data()
	else:
		push_error("Failed to parse quest stages JSON")

func generate_new_quest() -> Quest:
	var quest_generator = QuestGenerator.new(game_state)
	var new_quest = quest_generator.generate_quest()
	new_quest.current_stage = 1
	new_quest.current_requirements = quest_stages["quest_stages"][0]["requirements"]
	active_quests.append(new_quest)
	return new_quest

func update_quests() -> void:
	for quest in active_quests:
		if _check_quest_requirements(quest):
			_advance_quest_stage(quest)

func _check_quest_requirements(quest: Quest) -> bool:
	for requirement in quest.current_requirements:
		if not _is_requirement_met(requirement, quest):
			return false
	return true

func _is_requirement_met(requirement: String, quest: Quest) -> bool:
	# This function would check if the requirement is met based on the game state
	# For now, we'll use a placeholder implementation
	return randf() > 0.5

func _advance_quest_stage(quest: Quest) -> void:
	quest.current_stage += 1
	if quest.current_stage > quest_stages["quest_stages"].size():
		_complete_quest(quest)
	else:
		var stage_data = quest_stages["quest_stages"][quest.current_stage - 1]
		quest.current_requirements = stage_data["requirements"]
		_apply_stage_rewards(quest, stage_data["rewards"])

func _complete_quest(quest: Quest) -> void:
	quest.complete()
	active_quests.erase(quest)
	game_state.completed_quests.append(quest)
	_apply_final_rewards(quest)

func _apply_stage_rewards(_quest: Quest, rewards: Dictionary) -> void:
	if "credits" in rewards:
		var credits = _roll_dice(rewards["credits"])
		game_state.credits += credits
	if "story_points" in rewards:
		game_state.story_points += rewards["story_points"]
	if "gear" in rewards:
		var new_gear = _generate_gear(rewards["gear"])
		game_state.add_item(new_gear)

func _apply_final_rewards(quest: Quest) -> void:
	game_state.credits += quest.reward["credits"]
	game_state.reputation += quest.reward["reputation"]
	if "item" in quest.reward:
		game_state.add_item(quest.reward["item"])

func _roll_dice(dice_string: String) -> int:
	var parts = dice_string.split("D")
	var num_dice = int(parts[0])
	var dice_size = int(parts[1].split(" x ")[0])
	var multiplier = int(parts[1].split(" x ")[1])
	var total = 0
	for i in range(num_dice):
		total += randi() % dice_size + 1
	return total * multiplier

func _generate_gear(gear_type: String) -> Equipment:
	# This function would generate gear based on the type
	# For now, we'll use a placeholder implementation
	return Equipment.new(gear_type, 0, randi_range(50, 500))

func get_active_quests() -> Array[Quest]:
	return active_quests

func get_quest_stage_description(quest: Quest) -> String:
	return quest_stages["quest_stages"][quest.current_stage - 1]["description"]

func fail_quest(quest: Quest) -> void:
	quest.fail()
	active_quests.erase(quest)

func add_psionic_quest() -> Quest:
	var psionic_quest = generate_new_quest()
	psionic_quest.quest_type = "PSIONIC"
	psionic_quest.objective = "Master a new psionic ability"
	return psionic_quest

func update_quest_for_new_location(new_location: Location) -> void:
	for quest in active_quests:
		if quest.location != new_location:
			quest.location = new_location
			quest.objective = _generate_new_objective_for_location(quest, new_location)

func _generate_new_objective_for_location(quest: Quest, location: Location) -> String:
	var quest_generator = QuestGenerator.new(game_state)
	var quest_type = QuestGenerator.QuestType[quest.quest_type]
	return quest_generator.generate_objective(quest_type, location)

func get_quest_summary(quest: Quest) -> String:
	var summary = "Quest: {type}\n".format({"type": quest.quest_type})
	summary += "Location: {location}\n".format({"location": quest.location.name})
	summary += "Objective: {objective}\n".format({"objective": quest.objective})
	summary += "Current Stage: {stage}\n".format({"stage": quest.current_stage})
	summary += "Stage Description: {description}\n".format({"description": get_quest_stage_description(quest)})
	summary += "Requirements:\n"
	for requirement in quest.current_requirements:
		summary += "- {req}\n".format({"req": requirement})
	return summary

func serialize_quests() -> Array:
	var serialized_quests = []
	for quest in active_quests:
		serialized_quests.append(quest.serialize())
	return serialized_quests

func deserialize_quests(data: Array) -> void:
	active_quests.clear()
	for quest_data in data:
		var quest = Quest.deserialize(quest_data)
		active_quests.append(quest)
