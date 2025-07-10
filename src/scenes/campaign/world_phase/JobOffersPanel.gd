class_name FPCM_JobOffersPanel
extends PanelContainer

signal job_selected(job: Node)

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var job_generator: Node
var special_mission_generator: Node
var game_state_manager: Node

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManagerAutoload")
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
		var patron_job_manager := Node.new()
		var active_patrons = game_state_manager.game_state.get_active_patrons()
		var patron_jobs: Array = []
		for patron in active_patrons:
			var benefits_hazards_conditions = patron_job_manager.generate_benefits_hazards_conditions(patron)
			for job in benefits_hazards_conditions.values():
				patron_jobs.append(job)
		_add_jobs_to_list(patron_jobs, "Patron Jobs")

	# Generate red zone jobs if eligible
	if job_generator.check_red_zone_eligibility():
		var red_zone_job = special_mission_generator.generate_mission({
			"type": GlobalEnums.MissionType.RED_ZONE,
			"difficulty": 4,
			"rewards": {"credits": 2000}
		})
		if red_zone_job:
			_add_jobs_to_list([red_zone_job], "Red Zone Jobs")

	# Add existing available _missions
	_add_jobs_to_list(available_missions, "Current Offers")

func _add_jobs_to_list(jobs: Array, category: String) -> void:
	var category_label := Label.new()
	category_label.text = category
	add_child(category_label)

	for job in jobs:
		var job_button: Button = _create_job_button(job)
		add_child(job_button)
func _create_job_button(job: Node) -> Button:
	var button := Button.new()
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

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null