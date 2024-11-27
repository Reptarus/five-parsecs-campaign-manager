class_name CampaignManager
extends Node  # Add this line at the top of your script

signal phase_changed(new_phase: GlobalEnums.CampaignPhase)
signal turn_completed
signal campaign_victory_achieved(victory_type: GlobalEnums.CampaignVictoryType)

var game_state: GameState
var current_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.UPKEEP
var use_expanded_missions: bool = false
var story_track: StoryTrack
var save_manager: SaveManager
var save_load_ui: Control

# Add new variables for deferred loading
var _save_load_ui_scene: PackedScene
var _is_initialized: bool = false

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    story_track = StoryTrack.new()
    save_manager = SaveManager.new()
    # Defer scene loading
    _save_load_ui_scene = load("res://Resources/Utilities/SaveLoadUI.tscn")
    
    # Remove immediate instantiation
    save_load_ui = null

# Add initialization method to be called after engine is ready
func initialize() -> void:
    if _is_initialized:
        return
        
    if _save_load_ui_scene:
        save_load_ui = _save_load_ui_scene.instantiate()
        save_load_ui.hide()
        add_child(save_load_ui)
    else:
        push_error("Failed to load SaveLoadUI scene")
    
    _is_initialized = true

func start_new_turn(main_scene: Node) -> void:
    # Add validation
    if not is_instance_valid(main_scene):
        push_error("Invalid main scene provided")
        return
        
    game_state.current_turn += 1
    game_state.reset_turn_specific_data()
    
    var turn_summary = create_campaign_turn_summary()
    game_state.logbook.add_entry(turn_summary)
    
    # Add validation before showing UI
    if _is_initialized and is_instance_valid(save_load_ui):
        show_save_load_ui()
    else:
        push_warning("SaveLoadUI not initialized, skipping autosave")
    
    if game_state.is_tutorial_active:
        start_tutorial_phase(main_scene)
    else:
        start_world_phase(main_scene)

func start_tutorial_phase(main_scene: Node) -> void:
    var tutorial_phase_scene = load("res://Scenes/campaign/TutorialPhase.tscn").instantiate()
    tutorial_phase_scene.initialize(game_state, story_track)
    main_scene.add_child(tutorial_phase_scene)

func start_world_phase(main_scene: Node) -> void:
    var world_phase_scene = load("res://Scenes/campaign/WorldPhase.tscn").instantiate()
    world_phase_scene.initialize(game_state)
    main_scene.add_child(world_phase_scene)

func advance_phase() -> void:
    if game_state.is_tutorial_active:
        progress_story(current_phase)
    else:
        current_phase = GlobalEnums.CampaignPhase.values()[(current_phase + 1) % GlobalEnums.CampaignPhase.size()]
    phase_changed.emit(current_phase)

func perform_upkeep() -> bool:
    var upkeep_cost: int = game_state.current_crew.calculate_upkeep_cost()
    if game_state.remove_credits(upkeep_cost):
        for crew_member in game_state.current_crew.members:
            crew_member.recover_time = maxi(0, crew_member.recover_time - 1)
        return true
    else:
        game_state.current_crew.decrease_morale()
        return false

func handle_story_point() -> bool:
    if game_state.story_points > 0:
        game_state.remove_story_points(1)
        return true
    return false

func move_to_new_location(location_index: int) -> bool:
    var locations: Array = game_state.available_locations
    if location_index >= 0 and location_index < locations.size():
        game_state.current_location = locations[location_index]
        return true
    return false

func generate_events() -> Dictionary:
    return game_state.event_system.generate_random_event()

func update_quests() -> Array:
    return game_state.quest_system.update_quests()

func recruit_crew(recruit_index: int) -> bool:
    var potential_recruits: Array = game_state.character_generator.generate_recruits()
    if recruit_index >= 0 and recruit_index < potential_recruits.size():
        return game_state.current_crew.add_member(potential_recruits[recruit_index])
    return false

func train_and_study(crew_index: int, skill: String, skill_type: GlobalEnums.SkillType) -> bool:
    if crew_index >= 0 and crew_index < game_state.current_crew.members.size():
        var crew_member = game_state.current_crew.members[crew_index]
        
        if crew_member.has_skill(skill):
            crew_member.increase_skill_level(skill)
        else:
            crew_member.add_skill(skill, skill_type)
        
        return true
    
    return false

func trade_items(buy: bool, item_index: int) -> bool:
    if buy:
        var available_items = game_state.equipment_manager.get_available_items()
        if item_index >= 0 and item_index < available_items.size():
            return game_state.equipment_manager.buy_item(available_items[item_index])
    else:
        var crew_items = game_state.current_crew.get_all_items()
        if item_index >= 0 and item_index < crew_items.size():
            return game_state.equipment_manager.sell_item(crew_items[item_index])
    return false

func check_patron_jobs() -> Array:
    return game_state.patron_job_manager.get_available_jobs()

func start_mission(mission_index: int) -> bool:
    var available_missions: Array = game_state.mission_generator.generate_available_missions()
    if mission_index >= 0 and mission_index < available_missions.size():
        game_state.current_mission = available_missions[mission_index]
        return true
    return false

func handle_post_mission() -> Dictionary:
    if game_state.current_mission:
        var results = {
            "loot": game_state.current_mission.get_reward(),
            "injuries": [],
            "xp_gained": game_state.current_mission.get_reward().xp
        }
        game_state.add_credits(results.loot.credits)
        for item in results.loot.items:
            game_state.current_crew.add_equipment(item)

        for crew_member in game_state.current_crew.members:
            if crew_member.status == GlobalEnums.CharacterStatus.INJURED:
                var injury = crew_member.roll_injury()
                results.injuries.append({"crew_member": crew_member.name, "injury": injury})

        game_state.current_crew.gain_experience(results.xp_gained)
        game_state.current_mission = null
        return results
    return {}

func end_turn() -> void:
    game_state.advance_turn()
    check_victory_conditions()
    turn_completed.emit()
    var current_scene = get_tree().current_scene
    if current_scene:
        start_new_turn(current_scene)
    else:
        push_error("Current scene not found")

func create_campaign_turn_summary() -> String:
    return "Turn %d: %s" % [game_state.current_turn, game_state.current_location.name]

func start_story_track_tutorial() -> void:
    game_state.is_tutorial_active = true
    story_track.start_tutorial()

func end_tutorial(main_scene: Node) -> void:
    game_state.is_tutorial_active = false
    start_world_phase(main_scene)

func start_tutorial() -> void:
    game_state.is_tutorial_active = true
    var character_creation_logic = load("res://Resources/CharacterCreationLogic.gd").new()
    var tutorial_character = character_creation_logic.create_tutorial_character()
    game_state.current_crew.add_member(tutorial_character)

func show_save_load_ui() -> void:
    save_load_ui.show()
    save_load_ui.save_requested.connect(_on_save_requested)
    save_load_ui.load_requested.connect(_on_load_requested)

func _on_save_requested(save_name: String) -> void:
    var result = SaveGame.save_game(game_state, save_name)
    if result != OK:
        push_error("Failed to save game. Error code: " + str(result))
    else:
        print("Game saved successfully as: " + save_name)

func _on_load_requested(save_name: String) -> void:
    var loaded_game_state = SaveGame.load_game(save_name)
    if loaded_game_state:
        game_state = loaded_game_state
        print("Game loaded successfully: " + save_name)
    else:
        push_error("Failed to load game: " + save_name)

func progress_story(phase: GlobalEnums.CampaignPhase) -> void:
    if story_track:
        story_track.progress_story(phase)
    else:
        push_warning("Story track not initialized.")

func check_victory_conditions() -> void:
    var game_state_manager = GameStateManager.get_instance()
    if game_state_manager.check_campaign_victory_condition():
        campaign_victory_achieved.emit(game_state_manager.campaign_victory_condition)

# Add cleanup method for Android lifecycle management
func cleanup() -> void:
    if is_instance_valid(save_load_ui):
        save_load_ui.queue_free()
        save_load_ui = null
    _is_initialized = false
