class_name JobOffersPanel
extends PanelContainer

signal job_selected(job: Node)

enum MissionType {
    STANDARD,
    PATRON,
    RED_ZONE,
    BLACK_ZONE,
    SPECIAL
}

var job_generator: Node
var special_mission_generator: Node
var game_state_manager: Node

func _ready() -> void:
    game_state_manager = get_node("/root/GameStateManager")
    if not game_state_manager:
        push_error("GameStateManager instance not found")
        queue_free()
        return
        
    job_generator = Node.new()
    special_mission_generator = Node.new()
    
    # Connect to necessary signals
    if game_state_manager.game_state:
        game_state_manager.game_state.connect("state_changed", _on_game_state_changed)

func _on_game_state_changed() -> void:
    # Handle state changes here
    pass

func populate_jobs(available_missions: Array) -> void:
    # Generate standard jobs
    var standard_jobs = job_generator.generate_jobs(3)
    _add_jobs_to_list(standard_jobs, "Standard Jobs")
    
    # Generate patron jobs if available
    if game_state_manager.game_state.has_active_patrons():
        var patron_job_manager = Node.new()
        var active_patrons = game_state_manager.game_state.get_active_patrons()
        var patron_jobs = []
        for patron in active_patrons:
            var benefits_hazards_conditions = patron_job_manager.generate_benefits_hazards_conditions(patron)
            for job in benefits_hazards_conditions.values():
                patron_jobs.append(job)
        _add_jobs_to_list(patron_jobs, "Patron Jobs")
    
    # Generate red zone jobs if eligible
    if job_generator.check_red_zone_eligibility():
        var red_zone_job = special_mission_generator.generate_mission({
            "type": MissionType.RED_ZONE,
            "difficulty": 4,
            "rewards": {"credits": 2000}
        })
        if red_zone_job:
            _add_jobs_to_list([red_zone_job], "Red Zone Jobs")
    
    # Add existing available missions
    _add_jobs_to_list(available_missions, "Current Offers")

func _add_jobs_to_list(jobs: Array, category: String) -> void:
    var category_label = Label.new()
    category_label.text = category
    add_child(category_label)
    
    for job in jobs:
        var job_button = _create_job_button(job)
        add_child(job_button)

func _create_job_button(job: Node) -> Button:
    var button = Button.new()
    button.text = _format_job_info(job)
    button.pressed.connect(func(): job_selected.emit(job))
    return button

func _format_job_info(job: Node) -> String:
    return "%s - %s\nReward: %d credits\nDifficulty: %d" % [
        job.title,
        job.description,
        job.rewards.get("credits", 0),
        job.difficulty
    ] 