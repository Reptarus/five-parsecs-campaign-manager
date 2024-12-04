class_name QuestManager
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal quest_started(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal quest_updated(quest: Quest)
signal quest_stage_advanced(quest: Quest, stage: int)

var game_state: GameState
var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

# Quest tracking metrics
var quest_metrics: Dictionary = {
    "total_started": 0,
    "total_completed": 0,
    "total_failed": 0,
    "story_quests_completed": 0,
    "faction_quests_completed": 0,
    "side_quests_completed": 0
}

func _init() -> void:
    pass

func setup(state: GameState) -> void:
    game_state = state

func start_quest(quest: Quest) -> void:
    if not active_quests.has(quest):
        active_quests.append(quest)
        quest_metrics.total_started += 1
        quest_started.emit(quest)

func complete_quest(quest: Quest) -> void:
    if active_quests.has(quest):
        active_quests.erase(quest)
        completed_quests.append(quest)
        quest_metrics.total_completed += 1
        
        match quest.quest_type:
            GlobalEnums.QuestType.STORY:
                quest_metrics.story_quests_completed += 1
            GlobalEnums.QuestType.FACTION:
                quest_metrics.faction_quests_completed += 1
            GlobalEnums.QuestType.SIDE:
                quest_metrics.side_quests_completed += 1
        
        quest_completed.emit(quest)

func fail_quest(quest: Quest) -> void:
    if active_quests.has(quest):
        active_quests.erase(quest)
        failed_quests.append(quest)
        quest_metrics.total_failed += 1
        quest_failed.emit(quest)

func advance_quest_stage(quest: Quest) -> void:
    if active_quests.has(quest):
        quest.advance_stage()
        quest_stage_advanced.emit(quest, quest.current_stage)
        quest_updated.emit(quest)
        
        if quest.current_stage >= quest.total_stages:
            complete_quest(quest)

func get_active_quests_by_type(quest_type: int) -> Array[Quest]:
    return active_quests.filter(func(q): return q.quest_type == quest_type)

func get_quest_completion_rate() -> float:
    var total = quest_metrics.total_completed + quest_metrics.total_failed
    if total == 0:
        return 0.0
    return float(quest_metrics.total_completed) / float(total)

func get_story_progress() -> float:
    # Calculate story progress based on completed story quests
    # This is a simplified calculation - you might want to weight different quests differently
    var total_story_quests = completed_quests.filter(
        func(q): return q.quest_type == GlobalEnums.QuestType.STORY
    ).size()
    
    return float(total_story_quests) / max(1.0, float(game_state.total_story_quests))

func update_quests() -> void:
    # Update quest states, check for time-based failures, etc.
    for quest in active_quests:
        if _should_fail_quest(quest):
            fail_quest(quest)
        elif _should_advance_quest(quest):
            advance_quest_stage(quest)

func _should_fail_quest(quest: Quest) -> bool:
    # Implement quest failure conditions
    # For example, time limits, prerequisite failures, etc.
    return false

func _should_advance_quest(quest: Quest) -> bool:
    # Implement quest advancement conditions
    # For example, objectives completed, time passed, etc.
    return false

func get_quest_metrics() -> Dictionary:
    return quest_metrics.duplicate()
