@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")
const BaseCampaignManager = preload("res://src/base/campaign/BaseCampaignManager.gd")
const BattleCoordinator = preload("res://src/core/battle/BattleCoordinator.gd")

signal event_occurred(event_data: Dictionary)
signal phase_changed(phase: int)
signal campaign_started(campaign)
signal campaign_ended(victory: bool)
signal crew_tasks_available(tasks: Array)
signal job_offers_available(offers: Array)
signal patron_added(patron_data: Dictionary)
signal rival_added(rival_data: Dictionary)
signal mission_available(mission_data: Dictionary)
signal battle_completed(battle_results: Dictionary)
signal resources_updated(resources: Dictionary)

var gamestate: GameState = null
var current_phase: int = GameEnums.CampaignPhase.SETUP
var current_campaign = null
var battle_coordinator = null

# Campaign management data
var available_patrons: Array = []
var available_rivals: Array = []
var available_missions: Array = []
var galaxy_systems: Array = []
var active_campaigns: Array = []

# Five Parsecs specific definitions 
enum PatronType {
	CORPORATE,
	GOVERNMENT,
	OUTLAW,
	MERCENARY,
	INDEPENDENT
}

enum RivalType {
	GANG,
	MERCENARY,
	BOUNTY_HUNTER,
	CORPORATE,
	MILITARY
}

func _init() -> void:
	gamestate = GameState.new()
	if gamestate:
		add_child(gamestate)
	else:
		push_error("Failed to initialize GameState")
	
	# Create battle coordinator for handling battles
	battle_coordinator = BattleCoordinator.new()
	if battle_coordinator:
		battle_coordinator.name = "BattleCoordinator"
		add_child(battle_coordinator)
		battle_coordinator.connect("battle_completed", Callable(self, "_on_battle_completed"))
	else:
		push_error("Failed to initialize BattleCoordinator")
		
	_initialize_galaxy_systems()

# Method to set the game state for testing purposes
func set_game_state(state) -> bool:
	if state != null and is_instance_valid(state):
		if gamestate and is_instance_valid(gamestate):
			gamestate.queue_free()
		gamestate = state
		if gamestate.get_parent() == null:
			add_child(gamestate)
		return true
	return false

# Method for clean initialization after gamestate has been set
func initialize() -> bool:
	if not gamestate or not is_instance_valid(gamestate):
		push_error("GameCampaignManager: Cannot initialize - gamestate is null or invalid")
		return false
	
	_initialize_galaxy_systems()
	return true

# Initialize game systems
func _initialize_galaxy_systems() -> void:
	galaxy_systems = [
		"Nexus Prime", "Helios", "Cygnus", "Vega", "Altair",
		"Procyon", "Sirius", "Arcturus", "Capella", "Rigel",
		"Deneb", "Antares", "Pollux", "Spica", "Regulus"
	]

func create_campaign(name: String = "New Campaign") -> Variant:
	var campaign = FiveParsecsCampaign.new(name)
	active_campaigns.append(campaign)
	return campaign

func start_campaign(config) -> void:
	if not config:
		push_error("Invalid campaign configuration provided")
		return
	
	current_campaign = config
	current_phase = GameEnums.CampaignPhase.SETUP
	gamestate.start_new_campaign(config)
	
	# Generate initial patrons, rivals, and missions
	generate_patrons()
	generate_rivals()
	generate_missions()
	
	campaign_started.emit(config)

func end_campaign(victory: bool = false) -> void:
	if current_campaign:
		current_campaign.end_campaign(victory)
		campaign_ended.emit(victory)
	current_phase = GameEnums.CampaignPhase.END

func save_campaign() -> Dictionary:
	return gamestate.save_campaign()

func load_campaign(save_data: Dictionary) -> void:
	# Create campaign from data directly instead of using the file loading path
	var campaign = FiveParsecsCampaign.new()
	var load_result = campaign.deserialize(save_data)
	
	if not load_result or (load_result is Dictionary and not load_result.get("success", false)):
		var error_message = "Failed to load campaign"
		if load_result is Dictionary and load_result.has("message"):
			error_message += ": " + load_result.message
		push_error(error_message)
		return
	
	# Set as current campaign in gamestate
	gamestate.set_current_campaign(campaign)
	current_phase = save_data.get("current_phase", GameEnums.CampaignPhase.SETUP)

func update_resource(resource_type: int, amount: int) -> void:
	gamestate.update_resource(resource_type, amount)

func trigger_event(event_data: Dictionary) -> void:
	event_occurred.emit(event_data)

func get_game_state() -> GameState:
	return gamestate

# Method to ensure compatibility with test system
func start_new_campaign(config) -> bool:
	if not config:
		push_error("Invalid campaign configuration provided")
		return false
	
	current_campaign = config
	current_phase = GameEnums.CampaignPhase.SETUP
	
	if gamestate:
		gamestate.set_current_campaign(config)
	
	# Generate initial patrons, rivals, and missions
	generate_patrons()
	generate_rivals()
	generate_missions()
	
	campaign_started.emit(config)
	return true

# Five Parsecs specific methods integrated from FiveParsecsCampaignManager
func generate_patrons() -> void:
	available_patrons.clear()
	
	# Generate 1-3 patrons
	var patron_count = randi() % 3 + 1
	
	for i in range(patron_count):
		var patron = {
			"id": str(randi()),
			"name": _generate_random_name(),
			"type": randi() % PatronType.size(),
			"reputation": randi() % 5 + 1,
			"jobs": []
		}
		
		# Generate 1-2 jobs
		var job_count = randi() % 2 + 1
		
		for j in range(job_count):
			var job = {
				"id": str(randi()),
				"title": _generate_job_title(),
				"description": _generate_job_description(),
				"reward": (randi() % 10 + 5) * 100,
				"difficulty": randi() % 5 + 1,
				"location": galaxy_systems[randi() % galaxy_systems.size()]
			}
			
			patron.jobs.append(job)
		
		available_patrons.append(patron)
	
	if current_campaign:
		for patron in available_patrons:
			if current_campaign.has_method("add_patron"):
				current_campaign.add_patron(patron)
			patron_added.emit(patron)

func generate_rivals() -> void:
	available_rivals.clear()
	
	# Generate 1-2 rivals
	var rival_count = randi() % 2 + 1
	
	for i in range(rival_count):
		var rival = {
			"id": str(randi()),
			"name": _generate_random_name(),
			"type": randi() % RivalType.size(),
			"threat_level": randi() % 5 + 1,
			"location": galaxy_systems[randi() % galaxy_systems.size()],
			"crew_size": randi() % 5 + 3
		}
		
		available_rivals.append(rival)
	
	if current_campaign:
		for rival in available_rivals:
			if current_campaign.has_method("add_rival"):
				current_campaign.add_rival(rival)
			rival_added.emit(rival)

func generate_missions() -> void:
	available_missions.clear()
	
	# Generate 2-4 missions
	var mission_count = randi() % 3 + 2
	
	for i in range(mission_count):
		var mission = {
			"id": str(randi()),
			"title": _generate_mission_title(),
			"description": _generate_mission_description(),
			"type": randi() % GameEnums.MissionType.size(),
			"difficulty": randi() % 5 + 1,
			"reward": (randi() % 15 + 10) * 100,
			"location": galaxy_systems[randi() % galaxy_systems.size()],
			"patron_id": "",
			"rival_id": ""
		}
		
		# 50% chance to be associated with a patron
		if randf() < 0.5 and available_patrons.size() > 0:
			var patron = available_patrons[randi() % available_patrons.size()]
			mission.patron_id = patron.id
		
		# 30% chance to be associated with a rival
		if randf() < 0.3 and available_rivals.size() > 0:
			var rival = available_rivals[randi() % available_rivals.size()]
			mission.rival_id = rival.id
		
		available_missions.append(mission)
		mission_available.emit(mission)

func generate_crew_tasks() -> Array:
	var tasks = []
	
	# Generate 2-4 tasks
	var task_count = randi() % 3 + 2
	
	var task_types = [
		"Training", "Repair", "Trade", "Scavenge", "Recruit",
		"Research", "Craft", "Heal", "Scout", "Negotiate"
	]
	
	for i in range(task_count):
		var task_type = task_types[randi() % task_types.size()]
		
		var task = {
			"id": str(randi()),
			"type": task_type,
			"title": task_type + " Task",
			"description": "A " + task_type.to_lower() + " task for crew members.",
			"difficulty": randi() % 3 + 1,
			"duration": randi() % 3 + 1,
			"reward": {
				"credits": randi() % 200 + 100,
				"experience": randi() % 10 + 5
			},
			"required_skills": []
		}
		
		tasks.append(task)
	
	crew_tasks_available.emit(tasks)
	return tasks

func generate_job_offers() -> Array:
	var offers = []
	
	# Generate 1-3 job offers
	var offer_count = randi() % 3 + 1
	
	for i in range(offer_count):
		var offer = {
			"id": str(randi()),
			"title": _generate_job_title(),
			"description": _generate_job_description(),
			"reward": (randi() % 10 + 5) * 100,
			"difficulty": randi() % 5 + 1,
			"location": galaxy_systems[randi() % galaxy_systems.size()],
			"duration": randi() % 5 + 1,
			"patron": _generate_random_name()
		}
		
		offers.append(offer)
	
	job_offers_available.emit(offers)
	return offers

func travel_to_system(system_name: String) -> bool:
	if not current_campaign:
		push_error("Cannot travel: No campaign active")
		return false
	
	if current_campaign.has_method("travel_to_system"):
		return current_campaign.travel_to_system(system_name)
	
	return false

func complete_mission(mission_id: String, success: bool = true) -> void:
	if not current_campaign:
		push_error("Cannot complete mission: No campaign active")
		return
	
	for mission in available_missions:
		if mission.id == mission_id:
			if success:
				if current_campaign.has_method("add_resource"):
					current_campaign.add_resource("credits", mission.reward)
					current_campaign.add_resource("reputation", 1)
			
			if current_campaign.has_method("complete_mission"):
				current_campaign.complete_mission(success)
			available_missions.erase(mission)
			break

# Helper methods for name generation
func _generate_random_name() -> String:
	var first_names = [
		"Zara", "Jax", "Nova", "Kai", "Luna", "Orion", "Vega", "Cade",
		"Lyra", "Rook", "Echo", "Mace", "Piper", "Flint", "Ember", "Slate"
	]
	
	var last_names = [
		"Voss", "Reeve", "Stark", "Frost", "Drake", "Steel", "Marsh", "Blaze",
		"Storm", "Pike", "Wolfe", "Ryder", "Shaw", "Cross", "Vale", "Thorne"
	]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	
	return first + " " + last

func _generate_job_title() -> String:
	var actions = ["Retrieve", "Escort", "Eliminate", "Protect", "Investigate", "Sabotage", "Recover", "Deliver"]
	var targets = ["Data", "Cargo", "VIP", "Artifact", "Fugitive", "Evidence", "Supplies", "Intelligence"]
	
	var action = actions[randi() % actions.size()]
	var target = targets[randi() % targets.size()]
	
	return action + " " + target

func _generate_job_description() -> String:
	var descriptions = [
		"A sensitive operation requiring discretion and skill.",
		"A high-risk mission with substantial rewards.",
		"A straightforward job with unexpected complications.",
		"A time-sensitive task that cannot afford delays.",
		"A dangerous assignment in hostile territory.",
		"A complex operation requiring careful planning.",
		"A covert mission with minimal support.",
		"A lucrative opportunity with potential long-term benefits."
	]
	
	return descriptions[randi() % descriptions.size()]

func _generate_mission_title() -> String:
	var adjectives = ["Hidden", "Lost", "Stolen", "Ancient", "Dangerous", "Mysterious", "Valuable", "Secret"]
	var nouns = ["Treasure", "Technology", "Weapon", "Artifact", "Intelligence", "Outpost", "Facility", "Shipment"]
	
	var adjective = adjectives[randi() % adjectives.size()]
	var noun = nouns[randi() % nouns.size()]
	
	return "The " + adjective + " " + noun

func _generate_mission_description() -> String:
	var descriptions = [
		"A mission of opportunity with significant risk and reward.",
		"A dangerous expedition into uncharted territory.",
		"A recovery operation in a contested zone.",
		"A high-stakes infiltration mission.",
		"A defensive operation against overwhelming odds.",
		"A time-critical extraction under fire.",
		"A salvage operation with unexpected complications.",
		"A reconnaissance mission in enemy territory."
	]
	
	return descriptions[randi() % descriptions.size()]

# Handle battle results from the BattleCoordinator
func _on_battle_completed(results: Dictionary) -> void:
	# Extract relevant information from battle results
	var mission_id = results.get("mission_id", "")
	var victory = results.get("victory", false)
	var battle_data = results
	
	# Process mission results in campaign
	process_mission_results(mission_id, victory, battle_data)
	
	# Update resources based on battle outcome
	if victory:
		var reward = results.get("rewards", {})
		for resource_type in reward:
			update_resource(resource_type, reward[resource_type])
	
	# Update patrons and rivals based on battle outcome
	_update_patrons_after_battle(results)
	_update_rivals_after_battle(results)
	
	# Update campaign state
	if current_campaign:
		current_campaign.increment_campaign_turn()
		
	# Emit battle completed signal for UI updates
	battle_completed.emit(results)
	
	# Update resource display
	if gamestate:
		resources_updated.emit(gamestate.get_resources())

# Update patron relationships after battle
func _update_patrons_after_battle(battle_results: Dictionary) -> void:
	if not battle_results.has("mission_id"):
		return
		
	var mission_id = battle_results.mission_id
	var mission_patron_id = ""
	
	# Find the mission's patron
	for mission in available_missions:
		if mission.id == mission_id and mission.has("patron_id"):
			mission_patron_id = mission.patron_id
			break
	
	if not mission_patron_id:
		return
		
	# Update patron reputation based on mission outcome
	var reputation_change = 1 if battle_results.get("victory", false) else -1
	_update_patron_reputation(mission_patron_id, reputation_change)

# Update rival relationships after battle
func _update_rivals_after_battle(battle_results: Dictionary) -> void:
	if not battle_results.has("mission_id"):
		return
		
	var mission_id = battle_results.mission_id
	var mission_rival_id = ""
	
	# Find the mission's rival
	for mission in available_missions:
		if mission.id == mission_id and mission.has("rival_id"):
			mission_rival_id = mission.rival_id
			break
	
	if not mission_rival_id:
		return
		
	# Update rival threat level based on mission outcome
	var threat_change = -1 if battle_results.get("victory", false) else 1
	_update_rival_threat_level(mission_rival_id, threat_change)

# Helper function to update patron reputation
func _update_patron_reputation(patron_id: String, change: int) -> void:
	for patron in available_patrons:
		if patron.id == patron_id and patron.has("reputation"):
			patron.reputation = clamp(patron.reputation + change, 1, 10)
			break

# Helper function to update rival threat level
func _update_rival_threat_level(rival_id: String, change: int) -> void:
	for rival in available_rivals:
		if rival.id == rival_id and rival.has("threat_level"):
			rival.threat_level = clamp(rival.threat_level + change, 1, 10)
			break

# Process battle casualties
func _process_battle_casualties(battle_data: Dictionary) -> void:
	# Process character injuries or deaths
	if battle_data.has("casualties"):
		for casualty in battle_data.casualties:
			if casualty.has("character_id") and casualty.has("status"):
				# Update character status in gamestate
				if gamestate.has_method("update_character_status"):
					gamestate.update_character_status(casualty.character_id, casualty.status)

# Process special mission effects
func _process_special_mission_effects(mission: Dictionary, battle_data: Dictionary) -> void:
	# Handle specific mission types or special conditions
	if mission.has("type"):
		match mission.type:
			GameEnums.MissionType.RESCUE:
				# Handle rescue mission success - might add new crew members
				if battle_data.has("rescued_characters"):
					for character_data in battle_data.rescued_characters:
						if gamestate.has_method("add_character"):
							gamestate.add_character(character_data)
			
			GameEnums.MissionType.SABOTAGE:
				# Sabotage might affect rival threat level
				if mission.has("rival_id") and mission.rival_id:
					_update_rival_threat_level(mission.rival_id, -2)
	
	# Process any special conditions
	if mission.has("special_conditions"):
		for condition in mission.special_conditions:
			_process_special_condition(condition, battle_data)

func process_mission_results(mission_id: String, success: bool, battle_data: Dictionary) -> void:
	if not mission_id or not current_campaign:
		push_error("Invalid mission ID or campaign")
		return
	
	# Find mission in available missions
	var mission_index = -1
	for i in range(available_missions.size()):
		if available_missions[i].id == mission_id:
			mission_index = i
			break
	
	if mission_index == -1:
		push_error("Mission with ID %s not found" % mission_id)
		return
	
	var mission = available_missions[mission_index]
	
	# Process mission results
	if success:
		# Award credits and resources
		if mission.has("reward"):
			update_resource(GameEnums.ResourceType.CREDITS, mission.reward)
		
		# Update patron reputation if applicable
		if mission.has("patron_id") and mission.patron_id:
			_update_patron_reputation(mission.patron_id, 1)
		
		# Process special mission effects
		_process_special_mission_effects(mission, battle_data)
	else:
		# Handle mission failure
		# Potentially reduce reputation with patron
		if mission.has("patron_id") and mission.patron_id:
			_update_patron_reputation(mission.patron_id, -1)
		
		# Check for casualties and equipment loss in battle data
		_process_battle_casualties(battle_data)
	
	# Remove completed mission
	available_missions.remove_at(mission_index)
	
	# Generate new missions to replace completed ones
	var new_mission_count = 1 + randi() % 2 # 1-2 new missions
	for i in range(new_mission_count):
		generate_missions()

# Process a specific special condition
func _process_special_condition(condition: Dictionary, battle_data: Dictionary) -> void:
	# Get condition type
	var condition_type = condition.get("type", "")
	
	match condition_type:
		"item_reward":
			# Award special items
			if condition.has("item_data") and gamestate.has_method("add_item"):
				gamestate.add_item(condition.item_data)
		
		"character_effect":
			# Apply effects to characters
			if condition.has("character_id") and condition.has("effect"):
				if gamestate.has_method("apply_character_effect"):
					gamestate.apply_character_effect(condition.character_id, condition.effect)
		
		"campaign_event":
			# Trigger a campaign event
			if condition.has("event_data"):
				trigger_event(condition.event_data)
		
		"patron_job":
			# Add a job from a patron
			if condition.has("patron_id") and condition.has("job_data"):
				for patron in available_patrons:
					if patron.id == condition.patron_id and patron.has("jobs"):
						patron.jobs.append(condition.job_data)
						break
		
		"rival_encounter":
			# Trigger a rival encounter
			if condition.has("rival_id") and condition.has("encounter_data"):
				for rival in available_rivals:
					if rival.id == condition.rival_id:
						trigger_event({
							"type": "rival_encounter",
							"rival": rival,
							"encounter_data": condition.encounter_data
						})
						break
		
		_:
			# Unknown condition type
			push_warning("Unknown special condition type: %s" % condition_type)

func _exit_tree() -> void:
	if gamestate:
		gamestate.queue_free()
	if current_campaign:
		current_campaign.queue_free()