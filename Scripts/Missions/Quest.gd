class_name Quest
extends Mission

enum QuestType { EXPLORATION, RESCUE, RETRIEVAL, ELIMINATION, DIPLOMACY, PSIONIC }
enum RumorType { LOCATION, ITEM, CHARACTER, EVENT }

@export var quest_type: QuestType
@export var current_stage: int = 1
@export var current_requirements: Array[String] = []

# Rumor properties
@export var rumor_type: RumorType
@export var reward_estimate: int
@export var expiration_turns: int
@export var discovered: bool = false

signal quest_stage_changed(new_stage: int)
signal rumor_discovered

func _init(p_title: String = "", p_description: String = "", p_type: GlobalEnums.Type = GlobalEnums.Type.QUEST, 
           p_objective: GlobalEnums.MissionObjective = GlobalEnums.MissionObjective.EXPLORE, p_location: Location = null, 
           p_difficulty: int = 1, p_rewards: Dictionary = {}, p_time_limit: int = 3,
           p_is_expanded: bool = false, p_faction: Dictionary = {}):
    super(p_title, p_description, p_type, p_objective, p_location, p_difficulty, p_rewards, p_time_limit, p_is_expanded, p_faction)
    quest_type = QuestType.EXPLORATION  # Default quest type

func advance_stage():
    current_stage += 1
    quest_stage_changed.emit(current_stage)

func is_active() -> bool:
    return status == GlobalEnums.MissionStatus.ACTIVE

func discover_rumor():
    discovered = true
    rumor_discovered.emit()

func serialize() -> Dictionary:
    var data = super.serialize()
    data["quest_type"] = QuestType.keys()[quest_type]
    data["current_stage"] = current_stage
    data["current_requirements"] = current_requirements
    data["rumor_type"] = RumorType.keys()[rumor_type]
    data["reward_estimate"] = reward_estimate
    data["expiration_turns"] = expiration_turns
    data["discovered"] = discovered
    return data

static func deserialize(data: Dictionary) -> Quest:
    var quest = Quest.new(
        data["title"],
        data["description"],
        GlobalEnums.Type[data["type"]],
        GlobalEnums.MissionObjective[data["objective"]],
        Location.deserialize(data["location"]) if "location" in data else null,
        data["difficulty"],
        data["rewards"],
        data["time_limit"],
        data["is_expanded"],
        data["faction"] if "faction" in data else {}
    )
    quest.status = GlobalEnums.MissionStatus[data["status"]]
    quest.quest_type = QuestType[data["quest_type"]]
    quest.current_stage = data["current_stage"]
    quest.current_requirements = data["current_requirements"]
    quest.rumor_type = RumorType[data["rumor_type"]]
    quest.reward_estimate = data["reward_estimate"]
    quest.expiration_turns = data["expiration_turns"]
    quest.discovered = data["discovered"]
    return quest