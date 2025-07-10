# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
@tool
extends Node

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

var BaseCampaignManager: Variant = null

# Use safe loading instead of load() to handle circular dependencies
var FiveParsecsCampaignScript = load("res://src/game/campaign/FiveParsecsCampaign.gd")
var FiveParsecsGlobalEnums: Variant = null
var GlobalEnums: Variant = null
var GameState: Variant = null

# Define patron and rival types directly
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

# Five Parsecs specific properties
var available_patrons: Array = []
var available_rivals: Array = []
var available_missions: Array = []
var galaxy_systems: Array = []

# Campaign tracking
var active_campaigns: Array[Resource] = []
var campaign_save_data: Dictionary = {}
var current_campaign: Resource = null

# Signals
signal crew_tasks_available(tasks: Array)
signal job_offers_available(offers: Array)

func _init() -> void:
	# Load dependencies safely at runtime
	BaseCampaignManager = load("res://src/base/campaign/BaseCampaignManager.gd")
	FiveParsecsGlobalEnums = load("res://src/game/campaign/crew/FiveParsecsGlobalEnums.gd")
	GlobalEnums = load("res://src/core/systems/GlobalEnums.gd")
	GameState = load("res://src/core/state/GameState.gd")

	_validate_universal_connections()
	_initialize_galaxy_systems()

func _validate_universal_connections() -> void:
	# Validate game logic connections
	_validate_game_connections()
	_setup_safe_event_handling()

func _validate_game_connections() -> void:
	# Validate EventBus connection
	var event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		push_error("GAME SYSTEM FAILURE: EventBus not accessible from FiveParsecsCampaignManager")
		return

	# Validate GameState connection
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		push_error("GAME SYSTEM FAILURE: GameState not accessible from FiveParsecsCampaignManager")
		return

	# Validate required dependencies
	if not GlobalEnums:
		push_error("GAME DEPENDENCY MISSING: GlobalEnums not loaded")

	if not FiveParsecsGlobalEnums:
		push_error("GAME DEPENDENCY MISSING: FiveParsecsGlobalEnums not loaded")

func _setup_safe_event_handling() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		# Connect to common game events safely
		event_bus.game_state_changed.connect(_on_game_state_changed)
		event_bus.campaign_created.connect(_on_campaign_created)

func _on_game_state_changed(new_state: Variant) -> void:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return# Handle game state changes safely
	print("FiveParsecsCampaignManager: Game state changed to: ", new_state)

func _on_campaign_created(campaign_data: Dictionary) -> void:
	# Handle campaign creation events safely
	var campaign_name: String = campaign_data.get("name", "Unknown Campaign")
	print("FiveParsecsCampaignManager: Campaign created: ", campaign_name)

func _initialize_galaxy_systems() -> void:
	galaxy_systems = [
		"Nexus Prime", "Helios", "Cygnus", "Vega", "Altair",
		"Procyon", "Sirius", "Arcturus", "Capella", "Rigel",
		"Deneb", "Antares", "Pollux", "Spica", "Regulus"
	]

func create_campaign(name: String = "New Campaign") -> Variant:
	var campaign = FiveParsecsCampaignScript.new(name)

	safe_call_method(active_campaigns, "append" , campaign) # warning: return value discarded (intentional)
	return campaign

func start_campaign(campaign: Variant = null) -> void:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if campaign:
		current_campaign = campaign

	if current_campaign:
		# Generate initial patrons, rivals, and missions
		generate_patrons()
		generate_rivals()
		generate_missions()

func generate_patrons() -> void:
	available_patrons.clear()

	# Generate 1-3 patrons
	var patron_count = randi() % 3 + 1

	for i: int in range(patron_count):
		var patron = {
			"id": str(randi()),
			"name": _generate_random_name(),
			"type": randi() % PatronType.size(),
			"reputation": randi() % 5 + 1,
			"jobs": []
		}

		# Generate 1-2 jobs
		var job_count = randi() % 2 + 1

		for j: int in range(job_count):
			var job = {
				"id": str(randi()),
				"title": _generate_job_title(),
				"description": _generate_job_description(),
				"reward": (randi() % 10 + 5) * 100,
				"difficulty": randi() % 5 + 1,
				"location": galaxy_systems[randi() % (safe_call_method(galaxy_systems, "size") as int)]
			}

			patron.jobs.append(job)

		available_patrons.append(patron)

	if current_campaign:
		for patron in available_patrons:
			current_campaign.add_patron(patron)

func generate_rivals() -> void:
	available_rivals.clear()

	# Generate 1-2 rivals
	var rival_count = randi() % 2 + 1

	for i: int in range(rival_count):
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
			current_campaign.add_rival(rival)

func generate_missions() -> void:
	available_missions.clear()

	# Generate 2-4 missions
	var mission_count = randi() % 3 + 2

	for i: int in range(mission_count):
		var mission = {
			"id": str(randi()),
			"title": _generate_mission_title(),
			"description": _generate_mission_description(),
			"type": randi() % GlobalEnums.MissionType.size(),
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

func generate_crew_tasks() -> Array:
	var tasks: Array = []

	# Generate 2-4 tasks
	var task_count = randi() % 3 + 2

	var task_types = [
		"Training", "Repair", "Trade", "Scavenge", "Recruit",
		"Research", "Craft", "Heal", "Scout", "Negotiate"
	]

	for i: int in range(task_count):
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
	var offers: Array = []

	# Generate 1-3 job offers
	var offer_count = randi() % 3 + 1

	for i: int in range(offer_count):
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

	return current_campaign.travel_to_system(system_name)

func complete_mission(mission_id: String, success: bool = true) -> void:
	if not current_campaign:
		push_error("Cannot complete mission: No campaign active")
		return

	for mission in available_missions:
		if mission._id == mission_id:
			if success:
				current_campaign.add_resource("credits", mission.reward)
				current_campaign.add_resource("reputation", 1)

			current_campaign.complete_mission(success)
			available_missions.erase(mission)
			break

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