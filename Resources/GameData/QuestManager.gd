class_name QuestManager
extends Resource

signal quest_added(quest: Dictionary)
signal quest_updated(quest: Dictionary)
signal quest_completed(quest: Dictionary)
signal quest_failed(quest: Dictionary)
signal objective_completed(quest: Dictionary, objective: Dictionary)

var game_state: GameState
var active_quests: Dictionary = {}  # quest_id -> quest
var completed_quests: Array = []
var failed_quests: Array = []
var quest_progress: Dictionary = {}  # quest_id -> progress

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func add_quest(quest: Dictionary) -> bool:
	if not _validate_quest(quest):
		return false
	
	if quest.id in active_quests:
		return false
	
	active_quests[quest.id] = quest
	quest_progress[quest.id] = _initialize_quest_progress(quest)
	
	quest_added.emit(quest)
	return true

func update_quest_progress(quest_id: String, progress_data: Dictionary) -> void:
	if not quest_id in active_quests:
		return
	
	var quest = active_quests[quest_id]
	_update_progress(quest, progress_data)
	
	if _is_quest_complete(quest):
		complete_quest(quest_id)
	elif _is_quest_failed(quest):
		fail_quest(quest_id)
	else:
		quest_updated.emit(quest)

func complete_quest(quest_id: String) -> void:
	if not quest_id in active_quests:
		return
	
	var quest = active_quests[quest_id]
	active_quests.erase(quest_id)
	completed_quests.append(quest)
	
	_apply_quest_rewards(quest)
	quest_completed.emit(quest)

func fail_quest(quest_id: String) -> void:
	if not quest_id in active_quests:
		return
	
	var quest = active_quests[quest_id]
	active_quests.erase(quest_id)
	failed_quests.append(quest)
	
	_apply_quest_penalties(quest)
	quest_failed.emit(quest)

func get_quest(quest_id: String) -> Dictionary:
	return active_quests.get(quest_id, {})

func get_active_quests() -> Array:
	return active_quests.values()

func get_completed_quests() -> Array:
	return completed_quests

func get_failed_quests() -> Array:
	return failed_quests

func get_quest_progress(quest_id: String) -> Dictionary:
	return quest_progress.get(quest_id, {})

func can_accept_quest(quest: Dictionary) -> bool:
	# Check if we have room for another quest
	if active_quests.size() >= game_state.max_active_quests:
		return false
	
	# Check requirements
	if not _meet_quest_requirements(quest):
		return false
	
	# Check prerequisites
	if not _meet_quest_prerequisites(quest):
		return false
	
	return true

func abandon_quest(quest_id: String) -> void:
	if not quest_id in active_quests:
		return
	
	var quest = active_quests[quest_id]
	active_quests.erase(quest_id)
	failed_quests.append(quest)
	
	_apply_abandonment_penalties(quest)
	quest_failed.emit(quest)

# Helper Functions
func _validate_quest(quest: Dictionary) -> bool:
	# Check required fields
	var required_fields = ["id", "type", "name", "description", "objectives", "rewards", "requirements"]
	for field in required_fields:
		if not field in quest:
			return false
	
	# Validate objectives
	if quest.objectives.is_empty():
		return false
	
	# Validate rewards
	if not "credits" in quest.rewards or quest.rewards.credits <= 0:
		return false
	
	return true

func _initialize_quest_progress(quest: Dictionary) -> Dictionary:
	var progress = {
		"completed_objectives": [],
		"current_objective": 0,
		"progress_values": {},
		"time_started": Time.get_unix_time_from_system(),
		"last_updated": Time.get_unix_time_from_system()
	}
	
	# Initialize progress values for each objective
	for objective in quest.objectives:
		if "target_value" in objective:
			progress.progress_values[objective.id] = 0
	
	return progress

func _update_progress(quest: Dictionary, progress_data: Dictionary) -> void:
	var quest_id = quest.id
	if not quest_id in quest_progress:
		return
	
	var progress = quest_progress[quest_id]
	
	# Update progress values
	if "values" in progress_data:
		for objective_id in progress_data.values:
			if objective_id in progress.progress_values:
				progress.progress_values[objective_id] = progress_data.values[objective_id]
	
	# Check for completed objectives
	for objective in quest.objectives:
		if not objective.id in progress.completed_objectives:
			if _is_objective_complete(objective, progress):
				progress.completed_objectives.append(objective.id)
				objective_completed.emit(quest, objective)
	
	# Update current objective if needed
	while progress.current_objective < quest.objectives.size():
		var current = quest.objectives[progress.current_objective]
		if not _is_objective_complete(current, progress):
			break
		progress.current_objective += 1
	
	progress.last_updated = Time.get_unix_time_from_system()
	quest_progress[quest_id] = progress

func _is_quest_complete(quest: Dictionary) -> bool:
	var progress = quest_progress[quest.id]
	
	# Check if all required objectives are complete
	for objective in quest.objectives:
		if objective.get("required", true) and not objective.id in progress.completed_objectives:
			return false
	
	# Check time limit if any
	if "time_limit" in quest:
		var elapsed_time = Time.get_unix_time_from_system() - progress.time_started
		if elapsed_time > quest.time_limit:
			return false
	
	return true

func _is_quest_failed(quest: Dictionary) -> bool:
	var progress = quest_progress[quest.id]
	
	# Check time limit
	if "time_limit" in quest:
		var elapsed_time = Time.get_unix_time_from_system() - progress.time_started
		if elapsed_time > quest.time_limit:
			return true
	
	# Check fail conditions
	if "fail_conditions" in quest:
		for condition in quest.fail_conditions:
			if _check_fail_condition(condition, quest):
				return true
	
	return false

func _is_objective_complete(objective: Dictionary, progress: Dictionary) -> bool:
	# Check progress value if target exists
	if "target_value" in objective:
		var current_value = progress.progress_values.get(objective.id, 0)
		return current_value >= objective.target_value
	
	# Check completion flag
	return objective.id in progress.completed_objectives

func _meet_quest_requirements(quest: Dictionary) -> bool:
	var requirements = quest.requirements
	
	# Check crew size
	if "min_crew" in requirements:
		if game_state.crew.size() < requirements.min_crew:
			return false
	
	# Check skills
	if "required_skills" in requirements:
		for skill in requirements.required_skills:
			if not game_state.crew.has_skill_level(skill, requirements.required_skills[skill]):
				return false
	
	# Check equipment
	if "required_equipment" in requirements:
		for equipment in requirements.required_equipment:
			if not game_state.has_equipment(equipment):
				return false
	
	return true

func _meet_quest_prerequisites(quest: Dictionary) -> bool:
	if not "prerequisites" in quest:
		return true
	
	for prereq in quest.prerequisites:
		match prereq.type:
			"QUEST_COMPLETED":
				if not _is_quest_completed(prereq.quest_id):
					return false
			"REPUTATION":
				if not _meet_reputation_requirement(prereq):
					return false
			"LEVEL":
				if not _meet_level_requirement(prereq):
					return false
	
	return true

func _is_quest_completed(quest_id: String) -> bool:
	for quest in completed_quests:
		if quest.id == quest_id:
			return true
	return false

func _meet_reputation_requirement(requirement: Dictionary) -> bool:
	var current_rep = game_state.get_faction_reputation(requirement.faction)
	return current_rep >= requirement.value

func _meet_level_requirement(requirement: Dictionary) -> bool:
	return game_state.crew.get_average_level() >= requirement.value

func _check_fail_condition(condition: Dictionary, quest: Dictionary) -> bool:
	match condition.type:
		"TIME_LIMIT":
			var progress = quest_progress[quest.id]
			var elapsed_time = Time.get_unix_time_from_system() - progress.time_started
			return elapsed_time > condition.value
		"CREW_CASUALTIES":
			return game_state.crew.get_casualties() > condition.value
		"REPUTATION_LOSS":
			return game_state.reputation < condition.value
		_:
			return false

func _apply_quest_rewards(quest: Dictionary) -> void:
	var rewards = quest.rewards
	
	# Apply base rewards
	if "credits" in rewards:
		game_state.add_credits(rewards.credits)
	
	if "experience" in rewards:
		game_state.add_crew_experience(rewards.experience)
	
	if "reputation" in rewards:
		game_state.add_reputation(rewards.reputation)
	
	# Apply bonus rewards for optional objectives
	var progress = quest_progress[quest.id]
	for objective in quest.objectives:
		if not objective.get("required", true) and objective.id in progress.completed_objectives:
			if "bonus_rewards" in objective:
				_apply_bonus_rewards(objective.bonus_rewards)

func _apply_quest_penalties(quest: Dictionary) -> void:
	var penalties = quest.get("penalties", {})
	
	# Apply reputation penalty
	if "reputation" in penalties:
		game_state.add_reputation(-penalties.reputation)
	
	# Apply credit penalty
	if "credits" in penalties:
		game_state.remove_credits(penalties.credits)
	
	# Apply faction penalties
	if "faction_reputation" in penalties:
		for faction in penalties.faction_reputation:
			game_state.add_faction_reputation(faction, -penalties.faction_reputation[faction])

func _apply_abandonment_penalties(quest: Dictionary) -> void:
	var penalties = quest.get("abandonment_penalties", {})
	
	# Apply reputation penalty
	if "reputation" in penalties:
		game_state.add_reputation(-penalties.reputation)
	
	# Apply faction penalties
	if "faction_reputation" in penalties:
		for faction in penalties.faction_reputation:
			game_state.add_faction_reputation(faction, -penalties.faction_reputation[faction])

func _apply_bonus_rewards(rewards: Dictionary) -> void:
	if "credits" in rewards:
		game_state.add_credits(rewards.credits)
	
	if "items" in rewards:
		for item in rewards.items:
			game_state.add_item(item)
	
	if "faction_reputation" in rewards:
		for faction in rewards.faction_reputation:
			game_state.add_faction_reputation(faction, rewards.faction_reputation[faction])
