class_name QuestManager
extends Node

signal quest_added(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal quest_stage_advanced(quest: Quest, new_stage: int)

var game_state: GameStateManager
var quest_progression_manager: ExpandedQuestProgressionManager

var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

func _ready() -> void:
	quest_progression_manager.quest_generated.connect(_on_quest_generated)
	quest_progression_manager.quest_stage_advanced.connect(_on_quest_stage_advanced)

func generate_new_quest() -> Quest:
	return quest_progression_manager.generate_new_quest()

func add_quest(quest: Quest) -> void:
	active_quests.append(quest)
	quest.quest_completed.connect(_on_quest_completed.bind(quest))
	quest.quest_failed.connect(_on_quest_failed.bind(quest))
	quest_added.emit(quest)

func update_quests() -> void:
	quest_progression_manager.update_quests()

func _on_quest_generated(quest: Quest) -> void:
	add_quest(quest)

func _on_quest_stage_advanced(quest: Quest, new_stage: int) -> void:
	print("Quest stage advanced: %s - Stage: %d" % [quest.title, new_stage])
	quest_stage_advanced.emit(quest, new_stage)

func _on_quest_completed(quest: Quest) -> void:
	active_quests.erase(quest)
	completed_quests.append(quest)
	quest_completed.emit(quest)

func _on_quest_failed(quest: Quest) -> void:
	active_quests.erase(quest)
	failed_quests.append(quest)
	quest_failed.emit(quest)

func get_active_quests() -> Array[Quest]:
	return active_quests

func get_completed_quests() -> Array[Quest]:
	return completed_quests

func get_failed_quests() -> Array[Quest]:
	return failed_quests

func initialize(p_game_state: GameStateManager, p_quest_progression_manager: ExpandedQuestProgressionManager) -> void:
	game_state = p_game_state
	quest_progression_manager = p_quest_progression_manager