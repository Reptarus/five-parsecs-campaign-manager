class_name JobOffersPanel
extends PanelContainer

signal job_selected(job: Mission)

var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator

func _ready() -> void:
    job_generator = JobGenerator.new(GameStateManager.get_state())
    special_mission_generator = SpecialMissionGenerator.new(GameStateManager.get_state())

func populate_jobs(available_missions: Array) -> void:
    # Generate standard jobs
    var standard_jobs = job_generator.generate_jobs(3)
    _add_jobs_to_list(standard_jobs, "Standard Jobs")
    
    # Generate patron jobs if available
    if GameStateManager.get_state().has_active_patrons():
        var patron_jobs = job_generator.generate_jobs(2, JobGenerator.JobType.PATRON)
        _add_jobs_to_list(patron_jobs, "Patron Jobs")
    
    # Generate red zone jobs if eligible
    if job_generator._check_red_zone_eligibility():
        var red_zone_job = special_mission_generator.generate_special_mission(
            SpecialMissionGenerator.MissionTier.RED_ZONE
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
