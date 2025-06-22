@tool
extends Node

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
var _active_campaigns: Array = []

func _init() -> void:
	_initialize_save_directory()
func _initialize_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)
func create_campaign(name: String = "New Campaign") -> Variant:
	push_error("BaseCampaignManager.create_campaign() must be overridden by derived class")
	return null
func start_campaign(campaign = null) -> void:
	if campaign:
		current_campaign = campaign
	
	if not current_campaign:
		push_error("Cannot start campaign: No campaign selected")
		return
	
	current_campaign.start_campaign()
	campaign_started.emit(current_campaign)

func end_campaign(victory: bool = false) -> void:
	if not current_campaign:
		push_error("Cannot end campaign: No campaign active")
		return
	
	current_campaign.end_campaign(victory)
	campaign_ended.emit(current_campaign)

func save_campaign(campaign = null) -> bool:
	if campaign:
		current_campaign = campaign
	
	if not current_campaign:
		push_error("Cannot save campaign: No campaign selected")
		return false
	
	var save_path = SAVE_DIR + current_campaign.campaign_name.replace(" ", "_") + SAVE_EXTENSION
	var save_data = current_campaign.serialize()
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return false
	
	file.store_var(save_data)
	file.close()
	
	campaign_saved.emit(current_campaign)
	return true

func load_campaign(campaign_name: String) -> Variant:
	var save_path = SAVE_DIR + campaign_name.replace(" ", "_") + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return null
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: " + save_path)
		return null
	
	var save_data = file.get_var()
	file.close()
	
	var campaign = create_campaign()
	campaign.deserialize(save_data)
	
	current_campaign = campaign
	campaign_loaded.emit(current_campaign)
	
	return campaign

func get_saved_campaigns() -> Array:
	var campaigns: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if not dir:
		push_error("Failed to open save directory: " + SAVE_DIR)
		return campaigns
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var campaign_name = file_name.replace(SAVE_EXTENSION, "").replace("_", " ")

			campaigns.append(campaign_name)
		file_name = dir.get_next()
	
	return campaigns

func delete_saved_campaign(campaign_name: String) -> bool:
	var save_path = SAVE_DIR + campaign_name.replace(" ", "_") + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		push_error("Failed to open save directory: " + SAVE_DIR)
		return false
	
	var err = dir.remove(campaign_name.replace(" ", "_") + SAVE_EXTENSION)
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
	return current_campaign.remove_resource("credits", amount)

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
