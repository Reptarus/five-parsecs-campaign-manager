# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends PanelContainer

const Self = preload("res://src/scenes/campaign/world_phase/JobOffersPanel.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

signal job_selected(job: Node)

var job_generator: Node
var special_mission_generator: Node
var game_state_manager: Node

func _ready() -> void:
    if not is_inside_tree():
        return
        
    game_state_manager = get_node_or_null("/root/GameStateManager")
    if not game_state_manager:
        push_error("GameStateManager instance not found")
        queue_free()
        return
        
    job_generator = Node.new()
    if not job_generator:
        push_error("Failed to create job_generator node")
        queue_free()
        return
        
    special_mission_generator = Node.new()
    if not special_mission_generator:
        push_error("Failed to create special_mission_generator node")
        queue_free()
        return
    
    # Connect to necessary signals
    if game_state_manager.has("game_state") and game_state_manager.game_state:
        if game_state_manager.game_state.has_signal("state_changed") and not game_state_manager.game_state.state_changed.is_connected(_on_game_state_changed):
            game_state_manager.game_state.connect("state_changed", _on_game_state_changed)

func _on_game_state_changed() -> void:
    # Handle state changes here
    pass

func populate_jobs(available_missions: Array) -> void:
    if not is_inside_tree():
        return
        
    if not job_generator or not special_mission_generator:
        push_error("Job generators not initialized")
        return
        
    # Clear existing children
    for child in get_children():
        remove_child(child)
        child.queue_free()
    
    # Generate standard jobs
    if job_generator.has_method("generate_jobs"):
        var standard_jobs = job_generator.generate_jobs(3)
        _add_jobs_to_list(standard_jobs, "Standard Jobs")
    else:
        push_warning("job_generator missing generate_jobs method")
    
    # Generate patron jobs if available
    if game_state_manager and game_state_manager.has("game_state") and game_state_manager.game_state:
        if game_state_manager.game_state.has_method("has_active_patrons") and game_state_manager.game_state.has_active_patrons():
            var patron_job_manager = Node.new()
            if not patron_job_manager:
                push_warning("Failed to create patron_job_manager")
            else:
                if game_state_manager.game_state.has_method("get_active_patrons"):
                    var active_patrons = game_state_manager.game_state.get_active_patrons()
                    var patron_jobs = []
                    
                    if patron_job_manager.has_method("generate_benefits_hazards_conditions"):
                        for patron in active_patrons:
                            var benefits_hazards_conditions = patron_job_manager.generate_benefits_hazards_conditions(patron)
                            for job in benefits_hazards_conditions.values():
                                patron_jobs.append(job)
                        _add_jobs_to_list(patron_jobs, "Patron Jobs")
                    else:
                        push_warning("patron_job_manager missing generate_benefits_hazards_conditions method")
    
    # Generate red zone jobs if eligible
    if job_generator.has_method("check_red_zone_eligibility") and job_generator.check_red_zone_eligibility():
        if special_mission_generator.has_method("generate_mission"):
            var red_zone_job = special_mission_generator.generate_mission({
                "type": GameEnums.MissionType.RED_ZONE,
                "difficulty": 4,
                "rewards": {"credits": 2000}
            })
            if red_zone_job:
                _add_jobs_to_list([red_zone_job], "Red Zone Jobs")
        else:
            push_warning("special_mission_generator missing generate_mission method")
    
    # Add existing available missions
    if available_missions and available_missions.size() > 0:
        _add_jobs_to_list(available_missions, "Current Offers")

func _add_jobs_to_list(jobs: Array, category: String) -> void:
    if not is_inside_tree():
        return
        
    if jobs.is_empty():
        return
        
    var category_label = Label.new()
    if not category_label:
        push_warning("Failed to create category label")
        return
        
    category_label.text = category
    add_child(category_label)
    
    for job in jobs:
        var job_button = _create_job_button(job)
        if job_button:
            add_child(job_button)

func _create_job_button(job: Node) -> Button:
    if not job:
        push_warning("Cannot create job button: job is null")
        return null
        
    var button = Button.new()
    if not button:
        push_warning("Failed to create button for job")
        return null
        
    button.text = _format_job_info(job)
    # Use safer signal connection syntax
    if not button.pressed.is_connected(func(): job_selected.emit(job)):
        button.pressed.connect(func(): job_selected.emit(job))
    return button

func _format_job_info(job: Node) -> String:
    if not job or not job.has("title") or not job.has("description") or not job.has("rewards") or not job.has("difficulty"):
        return "Invalid Job"
        
    return "%s - %s\nReward: %d credits\nDifficulty: %d" % [
        job.title,
        job.description,
        job.rewards.get("credits", 0),
        job.difficulty
    ]