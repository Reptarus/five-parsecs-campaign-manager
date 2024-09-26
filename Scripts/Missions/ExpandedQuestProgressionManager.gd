class_name ExpandedQuestProgressionManager extends Node

signal quest_generated(quest: Quest)
signal quest_stage_advanced(quest: Quest, new_stage: int)

@export var game_state: GameState
var active_quests: Array[Quest] = []
var quest_stages: Dictionary

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    load_quest_stages()

func load_quest_stages() -> void:
    # Load quest stages from JSON file
    var file = FileAccess.open("res://Data/quest_stages.json", FileAccess.READ)
    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    if error == OK:
        quest_stages = json.get_data()
    else:
        push_error("Failed to parse quest stages JSON")
    file.close()

func generate_new_quest() -> Quest:
    var quest_generator = preload("res://Scripts/Missions/Quest.gd").new()
    var new_quest = quest_generator.generate_quest(game_state)
    new_quest.current_stage = 1
    new_quest.current_requirements = quest_stages["quest_stages"][0]["requirements"]
    active_quests.append(new_quest)
    emit_signal("quest_generated", new_quest)
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
    # Implement requirement checking logic
    match requirement:
        "location_reached":
            return game_state.player_location == quest.location
        "item_collected":
            return game_state.inventory.has_item(quest.objective)
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
    emit_signal("quest_stage_advanced", quest, quest.current_stage)

func _complete_quest(quest: Quest) -> void:
    quest.complete()
    active_quests.erase(quest)
    game_state.completed_quests.append(quest)
    _apply_final_rewards(quest)

func _apply_stage_rewards(quest: Quest, rewards: Dictionary) -> void:
    # Implement stage reward application logic
    for reward_type in rewards:
        match reward_type:
            "experience":
                game_state.add_experience(rewards[reward_type])
            "credits":
                game_state.add_credits(rewards[reward_type])
            "item":
                game_state.inventory.add_item(rewards[reward_type])
            _:
                push_warning("Unknown reward type: " + reward_type)

func _apply_final_rewards(quest: Quest) -> void:
    # Implement final reward application logic
    _apply_stage_rewards(quest, quest.reward)
    
    # Additional final reward logic based on Core Rules and Compendium
    if quest.reward.has("story_points"):
        game_state.add_story_points(quest.reward["story_points"])
    
    if quest.reward.has("loyalty"):
        game_state.add_loyalty(quest.reward["loyalty"])
    
    if quest.reward.has("influence"):
        game_state.add_influence(quest.reward["influence"])
    
    if quest.reward.has("power"):
        game_state.add_power(quest.reward["power"])
    
    if quest.reward.has("rival"):
        game_state.add_rival(quest.reward["rival"])
    
    if quest.reward.has("faction_destruction"):
        _handle_faction_destruction(quest.reward["faction_destruction"])
    
    if quest.reward.has("new_character"):
        game_state.add_new_character(quest.reward["new_character"])
    
    if quest.reward.has("quest_rumors"):
        game_state.add_quest_rumors(quest.reward["quest_rumors"])
    
    if quest.reward.has("credits"):
        game_state.add_credits(quest.reward["credits"])
    
    if quest.reward.has("experience"):
        game_state.add_experience(quest.reward["experience"])
    
    if quest.reward.has("item"):
        game_state.inventory.add_item(quest.reward["item"])
    
    if quest.reward.has("patron"):
        game_state.add_patron(quest.reward["patron"])
    
    if quest.reward.has("tick_clock"):
        game_state.tick_clock(quest.reward["tick_clock"])

func _handle_faction_destruction(faction: String) -> void:
    # Implement faction destruction logic
    var destroyed_faction = game_state.get_faction(faction)
    if destroyed_faction:
        destroyed_faction.destroy()
        game_state.remove_loyalty(destroyed_faction)
        game_state.remove_influence(destroyed_faction)
        game_state.remove_power(destroyed_faction)
        game_state.remove_faction(destroyed_faction)
        # Handle any additional logic for faction destruction