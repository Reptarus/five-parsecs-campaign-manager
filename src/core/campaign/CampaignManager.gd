extends Node

signal campaign_started(campaign: Campaign)
signal campaign_ended(campaign: Campaign)
signal campaign_saved(campaign: Campaign)
signal campaign_loaded(campaign: Campaign)
signal world_phase_started(location: String)
signal world_phase_completed
signal upkeep_costs_due(amount: int)
signal crew_tasks_available(available_tasks: Array)
signal job_offers_available(offers: Array)

const Campaign = preload("res://src/core/campaign/Campaign.gd")
const SAVE_DIR = "user://campaigns/"
const SAVE_EXTENSION = ".campaign"

var current_campaign: Campaign
var active_campaigns: Array[Campaign] = []

func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func start_new_campaign(campaign_name: String, starting_credits: int = 1000) -> Campaign:
	current_campaign = Campaign.new()
	current_campaign.start_new_campaign(campaign_name, starting_credits)
	active_campaigns.append(current_campaign)
	
	campaign_started.emit(current_campaign)
	return current_campaign

func end_campaign() -> void:
	if current_campaign:
		current_campaign.is_active = false
		campaign_ended.emit(current_campaign)
		current_campaign = null

func save_campaign(campaign: Campaign = null) -> void:
	if not campaign:
		campaign = current_campaign
	if not campaign:
		push_error("No campaign to save")
		return
	
	var save_path = SAVE_DIR.path_join(campaign.campaign_id + SAVE_EXTENSION)
	var save_data = campaign.serialize()
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		campaign_saved.emit(campaign)
	else:
		push_error("Failed to save campaign: " + campaign.campaign_name)

func load_campaign(campaign_id: String) -> Campaign:
	var save_path = SAVE_DIR.path_join(campaign_id + SAVE_EXTENSION)
	
	if not FileAccess.file_exists(save_path):
		push_error("Campaign save file not found: " + campaign_id)
		return null
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open campaign save file: " + campaign_id)
		return null
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse campaign save file: " + campaign_id)
		return null
	
	var save_data = json.get_data()
	current_campaign = Campaign.deserialize(save_data)
	
	if not active_campaigns.has(current_campaign):
		active_campaigns.append(current_campaign)
	
	campaign_loaded.emit(current_campaign)
	return current_campaign

func get_all_campaigns() -> Array[Campaign]:
	var campaigns: Array[Campaign] = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
				var campaign_id = file_name.trim_suffix(SAVE_EXTENSION)
				var campaign = load_campaign(campaign_id)
				if campaign:
					campaigns.append(campaign)
			file_name = dir.get_next()
	
	return campaigns

func delete_campaign(campaign_id: String) -> void:
	var save_path = SAVE_DIR.path_join(campaign_id + SAVE_EXTENSION)
	
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(save_path)
			
			# Remove from active campaigns if present
			for i in range(active_campaigns.size() - 1, -1, -1):
				if active_campaigns[i].campaign_id == campaign_id:
					active_campaigns.remove_at(i)
					break
			
			# Clear current campaign if it was deleted
			if current_campaign and current_campaign.campaign_id == campaign_id:
				current_campaign = null

func get_campaign_by_id(campaign_id: String) -> Campaign:
	for campaign in active_campaigns:
		if campaign.campaign_id == campaign_id:
			return campaign
	
	# Try to load from file if not in memory
	return load_campaign(campaign_id)

func is_campaign_active(campaign_id: String) -> bool:
	var campaign = get_campaign_by_id(campaign_id)
	return campaign != null and campaign.is_active

func get_current_campaign() -> Campaign:
	return current_campaign

func set_current_campaign(campaign: Campaign) -> void:
	if campaign and not active_campaigns.has(campaign):
		active_campaigns.append(campaign)
	current_campaign = campaign 

func start_world_phase() -> void:
	if not current_campaign:
		push_error("Cannot start world phase without active campaign")
		return
	
	world_phase_started.emit(current_campaign.current_location)
	
	# 1. Handle upkeep and ship repairs
	_process_upkeep_phase()
	
	# 2. Make crew tasks available
	_process_crew_tasks()
	
	# 3. Generate job offers
	_process_job_offers()

func _process_upkeep_phase() -> void:
	var crew_size = _get_active_crew_size()
	var upkeep_cost = 1  # Base cost for 4-6 crew
	
	if crew_size > 6:
		upkeep_cost += crew_size - 6  # +1 credit per crew over 6
		
	upkeep_costs_due.emit(upkeep_cost)

func _process_crew_tasks() -> void:
	var available_tasks = [
		{"name": "Find a Patron", "type": GameEnums.CrewTask.FIND_PATRON as int},
		{"name": "Train", "type": GameEnums.CrewTask.TRAIN as int},
		{"name": "Trade", "type": GameEnums.CrewTask.TRADE as int},
		{"name": "Recruit", "type": GameEnums.CrewTask.RECRUIT as int},
		{"name": "Explore", "type": GameEnums.CrewTask.EXPLORE as int},
		{"name": "Track", "type": GameEnums.CrewTask.TRACK as int},
		{"name": "Repair Kit", "type": GameEnums.CrewTask.REPAIR as int},
		{"name": "Decoy", "type": GameEnums.CrewTask.DECOY as int}
	]
	
	crew_tasks_available.emit(available_tasks)

func _process_job_offers() -> void:
	var patron_roll = _roll_for_patrons()
	var job_offers = []
	
	if patron_roll >= 5:
		job_offers.append(_generate_job_offer())
		if patron_roll >= 6:
			job_offers.append(_generate_job_offer())
	
	job_offers_available.emit(job_offers)

func _roll_for_patrons() -> int:
	var base_roll = randi() % 6 + 1
	var looking_crew = _get_crew_searching_patrons()
	var old_patrons = current_campaign.get_patron_count()
	
	return base_roll + looking_crew + old_patrons

func _generate_job_offer() -> Dictionary:
	# Generate a job offer based on core rules
	return {
		"type": randi() % GameEnums.JobType.size() as int,
		"payment": (randi() % 6 + 1) * 2,
		"difficulty": randi() % GameEnums.DifficultyMode.size() as int,
		"patron": _generate_patron()
	}

func _get_active_crew_size() -> int:
	# Return number of active crew members
	return current_campaign.get_active_crew_count() if current_campaign else 0

func _get_crew_searching_patrons() -> int:
	# Return number of crew members looking for patrons
	return current_campaign.get_crew_on_task(GameEnums.CrewTask.FIND_PATRON as int) if current_campaign else 0

func _generate_patron() -> Dictionary:
	return {
		"name": _generate_patron_name(),
		"type": randi() % GameEnums.PatronType.size() as int,
		"relationship": 0,
		"persistent": randf() < 0.2  # 20% chance for persistent patron
	}

func _generate_patron_name() -> String:
	# Generate a random patron name - implement based on your naming system
	return "Patron-" + str(randi() % 1000)