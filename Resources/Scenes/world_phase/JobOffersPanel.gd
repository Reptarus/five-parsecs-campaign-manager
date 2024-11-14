class_name JobOffersPanel
extends PanelContainer

signal job_selected(job: Mission)

var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator
var game_state_manager: GameStateManager

func _ready() -> void:
    game_state_manager = GameStateManager.get_instance.call()
    if not game_state_manager:
        push_error("GameStateManager instance not found")
        queue_free()
        return
        
    job_generator = JobGenerator.new(game_state_manager.game_state)
    special_mission_generator = SpecialMissionGenerator.new(game_state_manager.game_state)
    
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
        var patron_job_manager = PatronJobManager.new(game_state_manager.game_state)
        var active_patrons = game_state_manager.game_state.get_active_patrons()
        var patron_jobs = []
        for patron in active_patrons:
            var benefits_hazards_conditions = patron_job_manager.generate_benefits_hazards_conditions(patron)
            for job in benefits_hazards_conditions.values():
                patron_jobs.append(job)
        _add_jobs_to_list(patron_jobs, "Patron Jobs")
    
    # Generate red zone jobs if eligible
    if job_generator.check_red_zone_eligibility():
        var red_zone_job = special_mission_generator.generate_special_mission(
            GlobalEnums.MissionType.RED_ZONE
        )
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

func _create_job_button(job: Mission) -> Button:
    var button = Button.new()
    button.text = _format_job_info(job)
    button.pressed.connect(func(): job_selected.emit(job))
    return button

func _format_job_info(job: Mission) -> String:
    return "%s - %s\nReward: %d credits\nDifficulty: %d" % [
        job.title,
        job.description,
        job.rewards.get("credits", 0),
        job.difficulty
    ]
