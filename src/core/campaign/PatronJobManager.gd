class_name PatronJobManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

## Signals
signal patrons_updated
signal job_added(patron_id: String, job_data: Dictionary)
signal job_completed(patron_id: String, job_id: String, success: bool)
signal patron_relationship_changed(patron_id: String, new_relationship: int)

## Properties
var patrons: Dictionary = {} # Patron ID to patron data
var active_jobs: Dictionary = {} # Job ID to job data
var game_state: FiveParsecsGameState

## Initialize the patron job manager
func _init() -> void:
	pass

## Setup with game state
func setup(state: FiveParsecsGameState) -> void:
	game_state = state

## Generate available patrons based on current location and reputation
func generate_available_patrons() -> void:
	var patron_count = randi() % 3 + 1 # 1-3 patrons
	var location_data = game_state.get_current_location()
	var player_reputation = game_state.get_reputation()
	
	# Clear previous patrons
	patrons.clear()
	
	# Generate new patrons
	for i in range(patron_count):
		var patron_id = str(randi())
		var patron_type = randi() % 5 # Assuming 5 patron types
		var reputation_requirement = randi() % 3 + 1 # 1-3 reputation
		
		# Skip if player doesn't meet reputation requirement
		if player_reputation < reputation_requirement:
			continue
		
		var patron_data = {
			"id": patron_id,
			"name": _generate_patron_name(),
			"type": patron_type,
			"reputation_requirement": reputation_requirement,
			"relationship": 0, # Neutral by default
			"jobs": []
		}
		
		# Generate jobs for this patron
		var job_count = randi() % 2 + 1 # 1-2 jobs per patron
		for j in range(job_count):
			var job_id = str(randi())
			var job_data = _generate_job(patron_id, job_id, location_data)
			patron_data.jobs.append(job_id)
			active_jobs[job_id] = job_data
		
		patrons[patron_id] = patron_data
	
	patrons_updated.emit()

## Get a specific patron by ID
func get_patron(patron_id: String) -> Dictionary:
	if patrons.has(patron_id):
		return patrons[patron_id]
	return {}

## Get all available patrons
func get_available_patrons() -> Array:
	var result = []
	for patron_id in patrons:
		result.append(patrons[patron_id])
	return result

## Get a specific job by ID
func get_job(job_id: String) -> Dictionary:
	if active_jobs.has(job_id):
		return active_jobs[job_id]
	return {}

## Get all jobs for a specific patron
func get_patron_jobs(patron_id: String) -> Array:
	var result = []
	if patrons.has(patron_id):
		for job_id in patrons[patron_id].jobs:
			if active_jobs.has(job_id):
				result.append(active_jobs[job_id])
	return result

## Accept a job
func accept_job(job_id: String) -> bool:
	if active_jobs.has(job_id):
		active_jobs[job_id].status = "accepted"
		return true
	return false

## Complete a job
func complete_job(job_id: String, success: bool = true) -> void:
	if active_jobs.has(job_id):
		var job_data = active_jobs[job_id]
		var patron_id = job_data.patron_id
		
		# Update job status
		job_data.status = "completed" if success else "failed"
		
		# Update patron relationship
		if patrons.has(patron_id):
			var relationship_change = 1 if success else -1
			patrons[patron_id].relationship += relationship_change
			patron_relationship_changed.emit(patron_id, patrons[patron_id].relationship)
		
		# Award rewards if successful
		if success and game_state:
			game_state.add_resource(GameEnums.ResourceType.CREDITS, job_data.reward_credits)
			if job_data.has("reward_items"):
				for item in job_data.reward_items:
					game_state.add_item(item)
		
		job_completed.emit(patron_id, job_id, success)

## Generate a random job
func _generate_job(patron_id: String, job_id: String, location_data: Dictionary) -> Dictionary:
	var job_types = ["retrieval", "elimination", "defense", "escort", "sabotage"]
	var job_type = job_types[randi() % job_types.size()]
	
	var difficulty = randi() % 5 + 1 # 1-5 difficulty
	var reward_credits = difficulty * (randi() % 100 + 200) # 200-700 credits per difficulty level
	
	var job_data = {
		"id": job_id,
		"patron_id": patron_id,
		"type": job_type,
		"title": _generate_job_title(job_type),
		"description": _generate_job_description(job_type),
		"difficulty": difficulty,
		"reward_credits": reward_credits,
		"status": "available",
		"location": location_data.id if location_data.has("id") else "",
		"expiration_turn": game_state.get_turn() + (randi() % 3 + 3) # Expires in 3-5 turns
	}
	
	# Add bonus rewards for higher difficulties
	if difficulty > 3:
		job_data.reward_items = _generate_bonus_rewards(difficulty)
	
	return job_data

## Generate a patron name
func _generate_patron_name() -> String:
	var first_names = [
		"Zara", "Jax", "Nova", "Kai", "Luna", "Orion", "Vega", "Cade",
		"Lyra", "Rook", "Echo", "Mace", "Piper", "Flint", "Ember", "Slate"
	]
	
	var last_names = [
		"Voss", "Reeve", "Stark", "Frost", "Drake", "Steel", "Marsh", "Blaze",
		"Storm", "Pike", "Wolfe", "Ryder", "Shaw", "Cross", "Vale", "Thorne"
	]
	
	var titles = ["Captain", "Doctor", "Commander", "Agent", "Director", "Broker", "Marshal", "Chancellor"]
	
	var name = ""
	if randf() < 0.3: # 30% chance to add a title
		name += titles[randi() % titles.size()] + " "
	
	name += first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	return name

## Generate a job title based on type
func _generate_job_title(job_type: String) -> String:
	match job_type:
		"retrieval":
			var items = ["Data", "Artifact", "Technology", "Package", "Supplies", "Specimen", "Prototype"]
			return "Retrieve the " + items[randi() % items.size()]
		"elimination":
			var targets = ["Target", "Rogue Agent", "Criminal", "Alien Creature", "Renegade", "Hostile AI", "Pirate Leader"]
			return "Eliminate the " + targets[randi() % targets.size()]
		"defense":
			var locations = ["Outpost", "Settlement", "Research Facility", "Mining Operation", "Space Station", "Convoy", "Colony"]
			return "Defend the " + locations[randi() % locations.size()]
		"escort":
			var vips = ["VIP", "Scientist", "Diplomat", "Defector", "Informant", "Witness", "Corporate Executive"]
			return "Escort the " + vips[randi() % vips.size()]
		"sabotage":
			var targets = ["Facility", "Production Line", "Communications Array", "Power Source", "Weapon System", "Security Grid"]
			return "Sabotage the " + targets[randi() % targets.size()]
		_:
			return "Mysterious Assignment"

## Generate a job description based on type
func _generate_job_description(job_type: String) -> String:
	match job_type:
		"retrieval":
			var descriptions = [
				"A valuable item needs to be recovered from a hostile location.",
				"Critical data has been stolen and needs to be retrieved urgently.",
				"A rare artifact of immense value has been located and requires extraction.",
				"Sensitive materials need to be recovered from a crash site before others find it."
			]
			return descriptions[randi() % descriptions.size()]
		"elimination":
			var descriptions = [
				"A dangerous individual has been causing trouble and needs to be dealt with permanently.",
				"A hostile creature is threatening a nearby settlement and must be eliminated.",
				"A rogue agent has gone AWOL with sensitive information and must be neutralized.",
				"A criminal leader has been located and a substantial bounty is offered for their elimination."
			]
			return descriptions[randi() % descriptions.size()]
		"defense":
			var descriptions = [
				"A settlement is under threat of attack and requires immediate protection.",
				"Valuable cargo needs to be defended from pirates during transit.",
				"A research facility is expecting an attack and requires additional security.",
				"A VIP location needs protection during a critical event."
			]
			return descriptions[randi() % descriptions.size()]
		"escort":
			var descriptions = [
				"A high-profile individual needs safe passage through dangerous territory.",
				"A defector with valuable intelligence requires escort to a safe location.",
				"A scientist with crucial research must be protected during their journey.",
				"A witness to a major crime needs to be safely transported to testify."
			]
			return descriptions[randi() % descriptions.size()]
		"sabotage":
			var descriptions = [
				"A rival corporation's facility needs to be disabled discretely.",
				"A hostile production line manufacturing dangerous weapons must be shut down.",
				"An enemy communications array must be destroyed to prevent reinforcements.",
				"A security system needs to be compromised to allow for a future operation."
			]
			return descriptions[randi() % descriptions.size()]
		_:
			return "A job shrouded in mystery but promising good pay for the right crew."

## Generate bonus rewards based on difficulty
func _generate_bonus_rewards(difficulty: int) -> Array:
	var rewards = []
	var reward_count = difficulty - 2 # 1-3 bonus rewards for difficulty 3-5
	
	var potential_rewards = [
		{"type": "item", "item_id": "medkit_advanced", "name": "Advanced Medkit"},
		{"type": "item", "item_id": "weapon_upgrade", "name": "Weapon Upgrade Kit"},
		{"type": "item", "item_id": "armor_plating", "name": "Advanced Armor Plating"},
		{"type": "item", "item_id": "stim_pack", "name": "Combat Stim Pack"},
		{"type": "item", "item_id": "shield_generator", "name": "Portable Shield Generator"},
		{"type": "item", "item_id": "rare_tech", "name": "Rare Technology Fragment"},
		{"type": "item", "item_id": "ancient_artifact", "name": "Ancient Artifact"}
	]
	
	# Select random rewards
	for i in range(reward_count):
		var reward = potential_rewards[randi() % potential_rewards.size()].duplicate()
		if not rewards.has(reward): # Avoid duplicates
			rewards.append(reward)
	
	return rewards

## Get a description of the patron
func get_description() -> String:
	var result = ""
	for patron_id in patrons:
		var patron = patrons[patron_id]
		result += patron.name + "\n"
		
		# Add relationship status
		var relationship_text = "Neutral"
		if patron.relationship > 2:
			relationship_text = "Friendly"
		elif patron.relationship > 4:
			relationship_text = "Allied"
		elif patron.relationship < -2:
			relationship_text = "Unfriendly"
		elif patron.relationship < -4:
			relationship_text = "Hostile"
		
		result += "Relationship: " + relationship_text + "\n"
		
		# Add job listings
		var jobs = get_patron_jobs(patron_id)
		if jobs.size() > 0:
			result += "Available Jobs:\n"
			for job in jobs:
				result += "- " + job.title + " (Difficulty: " + str(job.difficulty) + ", Reward: " + str(job.reward_credits) + " credits)\n"
		else:
			result += "No jobs available\n"
		
		result += "\n"
	
	return result