class_name ExpandedQuestProgressionManager
extends Node

class QuestData:
    var current_stage: int = 0
    var current_requirements: Array[String] = []
    var location: Vector2
    var objective: String
    var reward: Dictionary = {}
    
    func advance_stage() -> void:
        current_stage += 1
    
    func complete() -> void:
        pass
    func generate_quest(_game_state: GameStateManager) -> Quest:
        var quest = Quest.new()
        quest.current_stage = 0
        quest.current_requirements = []
        quest.location = Vector2()
        quest.objective = ""
        quest.reward = {}
        return quest

class QuestTemplate extends Resource:
    var template_id: String
    var requirements: Array[String] = []
    var rewards: Dictionary

signal quest_generated(quest: Quest)
signal quest_stage_advanced(quest: Quest, new_stage: int)
signal quest_completed(quest: Quest)

const GameStateManager = preload("res://StateMachines/GameStateManager.gd")

@export var game_state: GameStateManager
var active_quests: Array[Quest] = []
var quest_stages: Dictionary = {}
var quest_templates: Array[QuestTemplate] = []

func _init(_game_state: GameStateManager) -> void:
    if not _game_state:
        push_error("GameStateManager is required for ExpandedQuestProgressionManager")
        return
    game_state = _game_state
    load_quest_stages()
    load_quest_templates()

func load_quest_stages() -> void:
    var file_path = "res://Data/quest_stages.json"
    if not FileAccess.file_exists(file_path):
        push_error("Quest stages file not found: %s" % file_path)
        return

    var file := FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json_string := file.get_as_text()
        var json := JSON.new()
        var error := json.parse(json_string)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                quest_stages = data
            else:
                push_error("Invalid quest stages data format")
        else:
            push_error("Failed to parse quest stages JSON: %s" % json.get_error_message())
        file.close()

func load_quest_templates() -> void:
    var file_path = "res://Data/quest_templates.json"
    if not FileAccess.file_exists(file_path):
        push_error("Quest templates file not found")
        return

    var file := FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json_string := file.get_as_text()
        var json := JSON.new()
        var error := json.parse(json_string)
        if error == OK:
            var data = json.get_data()
            if data is Array:
                quest_templates = data
            else:
                push_error("Invalid quest templates data format")
        else:
            push_error("Failed to parse quest templates JSON: %s" % json.get_error_message())
        file.close()

func generate_new_quest() -> Quest:
    var quest_generator = Quest.new()
    var new_quest = quest_generator.generate_quest(game_state)
    new_quest.current_stage = 1
    new_quest.current_requirements = quest_stages["quest_stages"][0]["requirements"]
    active_quests.append(new_quest)
    quest_generated.emit(new_quest)
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
    match requirement:
        "location_reached":
            return game_state.current_location == quest.location
        "item_collected":
            return game_state.current_crew.has_item(quest.objective)
        "enemy_defeated":
            return game_state.defeated_enemies.has(quest.objective)
        _:
            push_warning("Unknown requirement: " + requirement)
            return false

func _advance_quest_stage(quest: Quest) -> void:
    quest.advance_stage()
    if quest.current_stage > quest_stages["quest_stages"].size():
        _complete_quest(quest)
    else:
        var stage_data = quest_stages["quest_stages"][quest.current_stage - 1]
        quest.current_requirements = stage_data["requirements"]
        _apply_stage_rewards(quest, stage_data["rewards"])
    quest_stage_advanced.emit(quest, quest.current_stage)

func _complete_quest(quest: Quest) -> void:
    quest.complete()
    active_quests.erase(quest)
    game_state.completed_quests.append(quest)
    _apply_final_rewards(quest)

func _apply_stage_rewards(_quest: Quest, rewards: Dictionary) -> void:
    for reward_type in rewards:
        match reward_type:
            "experience":
                game_state.current_crew.gain_experience(rewards[reward_type])
            "credits":
                game_state.add_credits(rewards[reward_type])
            "item":
                game_state.current_crew.add_equipment(rewards[reward_type])
            _:
                push_warning("Unknown reward type: " + reward_type)

func _apply_final_rewards(quest: Quest) -> void:
    var reward = quest.reward
    if reward is Dictionary:
        _apply_stage_rewards(quest, reward)
        
        if reward.get("story_points"):
            game_state.add_story_point(reward.get("story_points"))
    else:
        push_error("Invalid reward type: " + str(reward))
    if reward.get("loyalty"):
        game_state.add_faction_loyalty(reward.get("loyalty"))
    
    if reward.get("influence"):
        game_state.add_faction_influence(reward.get("influence"))
    
    if reward.get("power"):
        game_state.add_faction_power(reward.get("power"))
    
    if reward.get("rival"):
        game_state.add_rival(reward.get("rival"))
    
    if reward.get("faction_destruction"):
        _handle_faction_destruction(reward.get("faction_destruction") as int)
    
    if reward.get("new_character"):
        game_state.current_crew.add_member(reward.get("new_character"))
    
    if reward.get("quest_rumors"):
        game_state.add_quest_rumors(reward.get("quest_rumors"))
    
    if reward.get("patron"):
        game_state.add_patron(reward.get("patron"))
    
    if reward.get("tick_clock"):
        game_state.advance_turn(reward.get("tick_clock") as int)

func _handle_faction_destruction(faction_id: int) -> void:
    var destroyed_faction = game_state.get_faction(faction_id)
    if destroyed_faction:
        destroyed_faction.destroy()
        game_state.remove_faction_loyalty(faction_id)
        game_state.remove_faction_influence(faction_id)
        game_state.remove_faction_power(faction_id)
        game_state.remove_faction(faction_id)
        game_state.remove_faction_power(faction_id)
        game_state.remove_faction(faction_id)