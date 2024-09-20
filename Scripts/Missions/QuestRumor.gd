class_name QuestRumor
extends Resource

enum RumorType {
    LOCATION,
    ITEM,
    CHARACTER,
    EVENT
}

@export var type: RumorType
@export var title: String
@export var description: String
@export var difficulty: int  # 1-5 scale
@export var reward_estimate: int
@export var expiration_turns: int
@export var associated_quest: Quest

var discovered: bool = false

func _init(p_type: RumorType = RumorType.LOCATION, p_title: String = "", p_description: String = "", 
           p_difficulty: int = 1, p_reward_estimate: int = 0, p_expiration_turns: int = 3):
    type = p_type
    title = p_title
    description = p_description
    difficulty = clamp(p_difficulty, 1, 5)
    reward_estimate = p_reward_estimate
    expiration_turns = p_expiration_turns

func discover():
    discovered = true

func is_expired(current_turn: int) -> bool:
    return current_turn >= expiration_turns

func generate_quest(game_state: GameState) -> Quest:
    if associated_quest == null:
        var quest_generator = QuestGenerator.new(game_state)
        associated_quest = quest_generator.generate_quest()
    return associated_quest

func serialize() -> Dictionary:
    return {
        "type": type,
        "title": title,
        "description": description,
        "difficulty": difficulty,
        "reward_estimate": reward_estimate,
        "expiration_turns": expiration_turns,
        "discovered": discovered,
        "associated_quest": associated_quest.serialize() if associated_quest else {}
    }

static func deserialize(data: Dictionary) -> QuestRumor:
    var rumor = QuestRumor.new(
        data["type"],
        data["title"],
        data["description"],
        data["difficulty"],
        data["reward_estimate"],
        data["expiration_turns"]
    )
    rumor.discovered = data["discovered"]
    if data["associated_quest"]:
        rumor.associated_quest = Quest.deserialize(data["associated_quest"])
    return rumor
