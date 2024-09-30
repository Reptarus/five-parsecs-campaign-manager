class_name ExpandedQuestProgressionManager
extends Node

signal quest_generated(quest: Quest)
signal quest_stage_advanced(quest: Quest, new_stage: int)

var game_state: GameState
var active_quests: Array[Quest] = []
var quest_stages: Dictionary

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    load_quest_stages()

func load_quest_stages() -> void:
    var file := FileAccess.open("res://Data/quest_stages.json", FileAccess.READ)
    var json := JSON.new()
    var error := json.parse(file.get_as_text())
    if error == OK:
        quest_stages = json.get_data()
    else:
        push_error("Failed to parse quest stages JSON")
    file.close()

func generate_new_quest() -> Quest:
    var quest_generator := preload("res://Scripts/Missions/Quest.gd").new()
    var new_quest := quest_generator.generate_quest(game_state)
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
        var stage_data := quest_stages["quest_stages"][quest.current_stage - 1]
        quest.current_requirements = stage_data["requirements"]
        _apply_stage_rewards(quest, stage_data["rewards"])
    quest_stage_advanced.emit(quest, quest.current_stage)

func _complete_quest(quest: Quest) -> void:
    quest.complete()
    active_quests.erase(quest)
    game_state.completed_quests.append(quest)
    _apply_final_rewards(quest)

func _apply_stage_rewards(quest: Quest, rewards: Dictionary) -> void:
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
    _apply_stage_rewards(quest, quest.reward)
    
    if quest.reward.has("story_points"):
        game_state.add_story_point(quest.reward["story_points"])
    
    if quest.reward.has("loyalty"):
        game_state.add_faction_loyalty(quest.reward["loyalty"])
    
    if quest.reward.has("influence"):
        game_state.add_faction_influence(quest.reward["influence"])
    
    if quest.reward.has("power"):
        game_state.add_faction_power(quest.reward["power"])
    
    if quest.reward.has("rival"):
        game_state.add_rival(quest.reward["rival"])
    
    if quest.reward.has("faction_destruction"):
        _handle_faction_destruction(quest.reward["faction_destruction"])
    
    if quest.reward.has("new_character"):
        game_state.current_crew.add_member(quest.reward["new_character"])
    
    if quest.reward.has("quest_rumors"):
        game_state.add_quest_rumors(quest.reward["quest_rumors"])
    
    if quest.reward.has("patron"):
        game_state.add_patron(quest.reward["patron"])
    
    if quest.reward.has("tick_clock"):
        game_state.advance_turn(quest.reward["tick_clock"])

func _handle_faction_destruction(faction: GlobalEnums.Faction) -> void:
    var destroyed_faction := game_state.get_faction(faction)
    if destroyed_faction:
        destroyed_faction.destroy()
        game_state.remove_faction_loyalty(destroyed_faction)
        game_state.remove_faction_influence(destroyed_faction)
        game_state.remove_faction_power(destroyed_faction)
        game_state.remove_faction(destroyed_faction)