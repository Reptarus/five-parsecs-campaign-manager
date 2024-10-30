class_name CrewTaskManager
extends Node

signal task_completed(character: Character, result: Dictionary)
signal task_failed(character: Character, reason: String)

enum TaskResult {
    CRITICAL_SUCCESS,
    SUCCESS,
    PARTIAL_SUCCESS,
    FAILURE,
    CRITICAL_FAILURE
}

enum TaskType {
    TRADE,
    EXPLORE,
    TRAIN,
    RECRUIT,
    FIND_PATRON,
    REPAIR_KIT,
    DECOY,
    REST,
    GATHER_INTEL,
    MAINTENANCE
}

var game_state: GameState
var task_descriptions := {
    TaskType.TRADE: "Engage in local trading for profit",
    TaskType.EXPLORE: "Scout the local area",
    TaskType.TRAIN: "Train crew skills",
    TaskType.RECRUIT: "Search for new crew members",
    TaskType.FIND_PATRON: "Network with potential patrons",
    TaskType.REPAIR_KIT: "Craft repair supplies",
    TaskType.DECOY: "Create diversions",
    TaskType.REST: "Rest and recover",
    TaskType.GATHER_INTEL: "Gather local intelligence",
    TaskType.MAINTENANCE: "Perform ship maintenance"
}

func _init(state: GameState) -> void:
    game_state = state

func get_task_description(task: TaskType) -> String:
    return task_descriptions[task]

func _get_relevant_skill(character: Character, task: TaskType) -> int:
    match task:
        TaskType.TRADE:
            return character.get_skill_level("negotiation")
        TaskType.EXPLORE:
            return character.get_skill_level("survival")
        TaskType.TRAIN:
            return character.get_skill_level("leadership")
        TaskType.RECRUIT:
            return character.get_skill_level("diplomacy")
        TaskType.FIND_PATRON:
            return character.get_skill_level("negotiation")
        TaskType.REPAIR_KIT:
            return character.get_skill_level("technical")
        TaskType.GATHER_INTEL:
            return character.get_skill_level("stealth")
        TaskType.MAINTENANCE:
            return character.get_skill_level("technical")
        _:
            return 0

func _calculate_rewards(result: Dictionary) -> void:
    var task = result["task"] as TaskType
    var rewards = {}
    
    match result["outcome"]:
        TaskResult.CRITICAL_SUCCESS:
            rewards = _get_critical_success_rewards(task)
        TaskResult.SUCCESS:
            rewards = _get_success_rewards(task)
        TaskResult.PARTIAL_SUCCESS:
            rewards = _get_partial_success_rewards(task)
        TaskResult.CRITICAL_FAILURE:
            rewards = _get_critical_failure_penalties(task)
        _:
            rewards = {}
    
    result["rewards"] = rewards

func _get_critical_success_rewards(task: TaskType) -> Dictionary:
    match task:
        TaskType.TRADE:
            return {"credits": randi() % 300 + 200, "experience": 100, "item": "rare_trade_good"}
        TaskType.EXPLORE:
            return {"credits": randi() % 100 + 50, "experience": 150, "rumor": true}
        TaskType.TRAIN:
            return {"experience": 200, "skill_increase": true}
        TaskType.RECRUIT:
            return {"experience": 100, "new_recruit": true}
        TaskType.FIND_PATRON:
            return {"credits": randi() % 200 + 100, "patron_reputation": 2}
        TaskType.REPAIR_KIT:
            return {"repair_kits": 3, "experience": 100}
        TaskType.GATHER_INTEL:
            return {"intel_value": 3, "experience": 150, "story_points": 1}
        TaskType.MAINTENANCE:
            return {"ship_repair": 20, "experience": 100}
        _:
            return {"experience": 50}

func _get_success_rewards(task: TaskType) -> Dictionary:
    match task:
        TaskType.TRADE:
            return {"credits": randi() % 150 + 100, "experience": 50}
        TaskType.EXPLORE:
            return {"credits": randi() % 50 + 25, "experience": 75}
        # Add other task rewards...
        _:
            return {"experience": 25}

func _get_partial_success_rewards(task: TaskType) -> Dictionary:
    match task:
        TaskType.TRADE:
            return {"credits": randi() % 50 + 25, "experience": 25}
        # Add other task rewards...
        _:
            return {"experience": 10}

func _get_critical_failure_penalties(task: TaskType) -> Dictionary:
    match task:
        TaskType.TRADE:
            return {"credits_loss": randi() % 100 + 50, "morale_loss": true}
        TaskType.EXPLORE:
            return {"injury": true, "morale_loss": true}
        # Add other task penalties...
        _:
            return {"morale_loss": true}
