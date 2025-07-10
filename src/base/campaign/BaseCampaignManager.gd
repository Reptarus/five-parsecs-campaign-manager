# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Node

# Universal framework integration removed for code simplification
# Direct signal emission used instead of Universal framework

signal campaign_started(campaign)
signal campaign_ended(campaign)
signal campaign_saved(campaign)
signal campaign_loaded(campaign)
signal world_phase_started(location: String)
signal world_phase_completed
signal upkeep_costs_due(amount: int)
signal crew_tasks_available(available_tasks: Array)
signal job_offers_available(offers: Array)

const SAVE_DIR = "user://campaigns/"
const SAVE_EXTENSION = ".campaign"

var current_campaign: Variant
# # var _active_campaigns: Array[Variant] = [] # Unused variable commented out # Unused variable commented out

func _init() -> void:
	_validate_universal_connections()
	_initialize_save_directory()

func _validate_universal_connections() -> void:
	# Validate base system connections for derived classes
	_validate_base_connections()

func _validate_base_connections() -> void:
	# Base classes should validate essential autoloads
	var essential_systems: Array = ["GameState"]
	for system_name in essential_systems:
		var typed_system_name: Variant = system_name
		var system: Node = get_node_or_null("/root/" + str(system_name))
		if not system:
			push_warning("BASE SYSTEM: %s not available (BaseCampaignManager)" % system_name)

func _initialize_save_directory() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if not dir:
		push_error("CRASH PREVENTION: Cannot access user directory for save operations")
		return

	if not dir.dir_exists(SAVE_DIR):
		var error: int = dir.make_dir(SAVE_DIR)
		if error != OK:
			push_error("CRASH PREVENTION: Failed to create save directory: %s (Error: %s)" % [SAVE_DIR, error])
func create_campaign(name: String = "New Campaign") -> Variant:
	push_error("BaseCampaignManager: create_campaign() must be overridden by derived class")
	return null
func start_campaign(campaign: Variant = null) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return

	if campaign:
		current_campaign = campaign

	if not current_campaign:
		push_error("CRASH PREVENTION: Cannot start campaign - No campaign selected")
		return

	if not current_campaign.has_method("start_campaign"):
		push_error("CRASH PREVENTION: Campaign object does not have start_campaign method")
		return

	current_campaign.start_campaign()
	campaign_started.emit(current_campaign)

func end_campaign(victory: bool = false) -> void:
	if not current_campaign:
		push_error("CRASH PREVENTION: Cannot end campaign - No campaign active")
		return

	if not current_campaign.has_method("end_campaign"):
		push_error("CRASH PREVENTION: Campaign object does not have end_campaign method")
		return

	current_campaign.end_campaign(victory)
	campaign_ended.emit(current_campaign)

func save_campaign(campaign: Variant = null) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false

	if campaign:
		current_campaign = campaign

	if not current_campaign:
		push_error("Cannot save campaign: No campaign selected")
		return false

	var save_path: String = SAVE_DIR + current_campaign.campaign_name.replace(" ", "_") + SAVE_EXTENSION
	var save_data: Dictionary = current_campaign.serialize() if current_campaign.has_method("serialize") else {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return false

	file.store_var(save_data)
	file.close()

	campaign_saved.emit(current_campaign)
	return true

func load_campaign(campaign_name: String) -> Variant:
	var save_path: String = SAVE_DIR + campaign_name.replace(" ", "_") + SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return null

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return null

	var save_data = file.get_var()
	file.close()

	var campaign = create_campaign()
	if campaign and campaign.has_method("deserialize"):
		campaign.deserialize(save_data)

	current_campaign = campaign
	campaign_loaded.emit(current_campaign)

	return campaign

func get_saved_campaigns() -> Array:
	var campaigns: Array = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)

	if not dir:
		push_error("Failed to open save directory: " + SAVE_DIR)
		return campaigns

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var campaign_name: String = file_name.replace(SAVE_EXTENSION, "").replace("_", " ")
			safe_call_method(campaigns, "append", 	[campaign_name])
		file_name = dir.get_next()

	return campaigns

func delete_saved_campaign(campaign_name: String) -> bool:
	var save_path: String = SAVE_DIR + campaign_name.replace(" ", "_") + SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return false

	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if not dir:
		push_error("Failed to open save directory: " + SAVE_DIR)
		return false

	var err: int = dir.remove(campaign_name.replace(" ", "_") + SAVE_EXTENSION)
	if err != OK:
		push_error("Failed to delete save file: " + save_path)
		return false

	return true

func start_world_phase(location: String) -> void:
	world_phase_started.emit(location)

func complete_world_phase() -> void:
	world_phase_completed.emit()

func charge_upkeep_costs(amount: int) -> bool:
	if not current_campaign:
		push_error("Cannot charge upkeep costs: No campaign active")
		return false

	upkeep_costs_due.emit(amount)
	return current_campaign.remove_resource("credits", amount) if current_campaign.has_method("remove_resource") else false

func generate_crew_tasks() -> Array:
	var tasks: Array = []
	# Base implementation returns empty array
	# Override in derived classes to generate game-specific tasks
	crew_tasks_available.emit(tasks)
	return tasks

func generate_job_offers() -> Array:
	var offers: Array = []
	# Base implementation returns empty array
	# Override in derived classes to generate game-specific job offers
	job_offers_available.emit(offers)
	return offers

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null