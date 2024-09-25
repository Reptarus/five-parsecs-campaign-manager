class_name Quest extends Resource

enum QuestType { EXPLORATION, RESCUE, RETRIEVAL, ELIMINATION, DIPLOMACY, PSIONIC }
enum RumorType { LOCATION, ITEM, CHARACTER, EVENT }

@export var quest_type: QuestType
@export var location: Location
@export var objective: String
@export var reward: Dictionary
@export var completed: bool = false
@export var failed: bool = false
@export var current_stage: int = 1
@export var current_requirements: Array[String] = []
@export var faction: Dictionary = {}
@export var loyalty_requirement: int = 0
@export var power_requirement: int = 0

# Rumor properties
@export var rumor_type: RumorType
@export var title: String
@export var description: String
@export var difficulty: int  # 1-5 scale
@export var reward_estimate: int
@export var expiration_turns: int
@export var discovered: bool = false

signal quest_completed
signal quest_failed
signal quest_stage_changed(new_stage: int)
signal rumor_discovered

func _init(p_quest_type: QuestType = QuestType.EXPLORATION, p_location: Location = null, p_objective: String = "", p_reward: Dictionary = {}):
    quest_type = p_quest_type
    location = p_location
    objective = p_objective
    reward = p_reward

func complete():
    completed = true
    emit_signal("quest_completed")

func fail():
    failed = true
    emit_signal("quest_failed")

func advance_stage():
    current_stage += 1
    emit_signal("quest_stage_changed", current_stage)

func is_active() -> bool:
    return not completed and not failed

func discover_rumor():
    discovered = true
    emit_signal("rumor_discovered")

func serialize() -> Dictionary:
    return {
        "quest_type": quest_type,
        "location": location.serialize() if location else null,
        "objective": objective,
        "reward": reward,
        "completed": completed,
        "failed": failed,
        "current_stage": current_stage,
        "current_requirements": current_requirements,
        "faction": faction,
        "loyalty_requirement": loyalty_requirement,
        "power_requirement": power_requirement,
        "rumor_type": rumor_type,
        "title": title,
        "description": description,
        "difficulty": difficulty,
        "reward_estimate": reward_estimate,
        "expiration_turns": expiration_turns,
        "discovered": discovered
    }

static func deserialize(data: Dictionary) -> Quest:
    var quest = Quest.new()
    quest.quest_type = data["quest_type"]
    quest.location = Location.deserialize(data["location"]) if data["location"] else null
    quest.objective = data["objective"]
    quest.reward = data["reward"]
    quest.completed = data["completed"]
    quest.failed = data["failed"]
    quest.current_stage = data["current_stage"]
    quest.current_requirements = data["current_requirements"]
    quest.faction = data["faction"]
    quest.loyalty_requirement = data["loyalty_requirement"]
    quest.power_requirement = data["power_requirement"]
    quest.rumor_type = data["rumor_type"]
    quest.title = data["title"]
    quest.description = data["description"]
    quest.difficulty = data["difficulty"]
    quest.reward_estimate = data["reward_estimate"]
    quest.expiration_turns = data["expiration_turns"]
    quest.discovered = data["discovered"]
    return quest