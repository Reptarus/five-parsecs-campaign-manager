@tool
class_name FiveParsecsCampaignManager
extends BaseCampaignManager

const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

# Five Parsecs specific properties
var available_patrons: Array = []
var available_rivals: Array = []
var available_missions: Array = []
var galaxy_systems: Array = []

func _init() -> void:
	super()
	_initialize_galaxy_systems()

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

func start_campaign(campaign = null) -> void:
	super(campaign)
	
	if current_campaign:
		# Generate initial patrons, rivals, and missions
		generate_patrons()
		generate_rivals()
		generate_missions()

func generate_patrons() -> void:
	available_patrons.clear()
	
	# Generate 1-3 patrons
	var patron_count = randi() % 3 + 1
	
	for i in range(patron_count):
		var patron = {
			"id": str(randi()),
			"name": _generate_random_name(),
			"type": randi() % GameEnums.PatronType.size(),
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
			current_campaign.add_patron(patron)

func generate_rivals() -> void:
	available_rivals.clear()
	
	# Generate 1-2 rivals
	var rival_count = randi() % 2 + 1
	
	for i in range(rival_count):
		var rival = {
			"id": str(randi()),
			"name": _generate_random_name(),
			"type": randi() % GameEnums.RivalType.size(),
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
	
	return current_campaign.travel_to_system(system_name)

func complete_mission(mission_id: String, success: bool = true) -> void:
	if not current_campaign:
		push_error("Cannot complete mission: No campaign active")
		return
	
	for mission in available_missions:
		if mission.id == mission_id:
			if success:
				current_campaign.add_resource("credits", mission.reward)
				current_campaign.add_resource("reputation", 1)
			
			current_campaign.complete_mission(success)
			available_missions.erase(mission)
			break