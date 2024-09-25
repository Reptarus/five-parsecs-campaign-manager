class_name QuestManager extends Node

signal quest_added(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)

@export var game_state: GameState
@export var quest_progression_manager: ExpandedQuestProgressionManager

var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

func _ready() -> void:
    quest_progression_manager.connect("quest_generated", Callable(self, "_on_quest_generated"))
    quest_progression_manager.connect("quest_stage_advanced", Callable(self, "_on_quest_stage_advanced"))

func generate_new_quest() -> Quest:
    return quest_progression_manager.generate_new_quest()

func add_quest(quest: Quest) -> void:
    active_quests.append(quest)
    quest.connect("quest_completed", Callable(self, "_on_quest_completed").bind(quest))
    quest.connect("quest_failed", Callable(self, "_on_quest_failed").bind(quest))
    emit_signal("quest_added", quest)

func update_quests() -> void:
    quest_progression_manager.update_quests()

func _on_quest_generated(quest: Quest) -> void:
    add_quest(quest)

func _on_quest_stage_advanced(quest: Quest, new_stage: int) -> void:
    # Handle quest stage advancement
    print("Quest stage advanced: ", quest.title, " - Stage: ", new_stage)

func _on_quest_completed(quest: Quest) -> void:
    active_quests.erase(quest)
    completed_quests.append(quest)
    emit_signal("quest_completed", quest)

func _on_quest_failed(quest: Quest) -> void:
    active_quests.erase(quest)
    failed_quests.append(quest)
    emit_signal("quest_failed", quest)

# Additional methods can be implemented here as needed