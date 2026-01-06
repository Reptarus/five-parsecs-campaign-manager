@tool
extends RefCounted
class_name WorldPhaseResources

## World Phase Resources - Feature 4 Implementation
## Resource-based data structures for crew tasks, patrons, and equipment
## Follows SerializableResource patterns with Universal Safety Framework

# GlobalEnums available as autoload singleton

## Crew Task Result Resource
class CrewTaskResult extends Resource:
	@export var crew_id: String = ""
	@export var crew_name: String = ""
	@export var task_type: String = ""
	@export var task_assigned_turn: int = 0
	@export var success: bool = false
	@export var dice_rolls: Array[int] = []
	@export var final_result: int = 0
	@export var modifiers_applied: Dictionary = {}
	@export var rewards: Dictionary = {}
	@export var narrative: String = ""
	@export var timestamp: String = ""
	@export var world_modifiers: Dictionary = {}
	@export var skill_bonuses: Dictionary = {}
	
	func _init(crew_member_id: String = "", task_name: String = ""):
		if not crew_member_id.is_empty():
			crew_id = crew_member_id
		if not task_name.is_empty():
			task_type = task_name
		timestamp = Time.get_datetime_string_from_system()
	
	func serialize() -> Dictionary:
		return {
			"crew_id": crew_id,
			"crew_name": crew_name,
			"task_type": task_type,
			"task_assigned_turn": task_assigned_turn,
			"success": success,
			"dice_rolls": dice_rolls,
			"final_result": final_result,
			"modifiers_applied": modifiers_applied,
			"rewards": rewards,
			"narrative": narrative,
			"timestamp": timestamp,
			"world_modifiers": world_modifiers,
			"skill_bonuses": skill_bonuses
		}
	
	func deserialize(data: Dictionary) -> void:
		crew_id = data.get("crew_id", "")
		crew_name = data.get("crew_name", "")
		task_type = data.get("task_type", "")
		task_assigned_turn = data.get("task_assigned_turn", 0)
		success = data.get("success", false)
		dice_rolls = data.get("dice_rolls", [])
		final_result = data.get("final_result", 0)
		modifiers_applied = data.get("modifiers_applied", {})
		rewards = data.get("rewards", {})
		narrative = data.get("narrative", "")
		timestamp = data.get("timestamp", "")
		world_modifiers = data.get("world_modifiers", {})
		skill_bonuses = data.get("skill_bonuses", {})
	
	func validate() -> bool:
		return not crew_id.is_empty() and not task_type.is_empty()
	
	func get_reward_summary() -> String:
		var summary_parts: Array[String] = []
		
		if rewards.has("credits"):
			var credits = rewards["credits"]
			if credits > 0:
				summary_parts.append("+%d credits" % credits)
			elif credits < 0:
				summary_parts.append("%d credits" % credits)
		
		if rewards.has("equipment"):
			summary_parts.append("Equipment found")
		
		if rewards.has("story_points"):
			var points = rewards["story_points"]
			if points > 0:
				summary_parts.append("+%d story points" % points)
		
		if rewards.has("patron_contact"):
			summary_parts.append("Patron contact")
		
		return ", ".join(summary_parts) if not summary_parts.is_empty() else "No rewards"

## Patron Data Resource
class PatronData extends Resource:
	@export var patron_id: String = ""
	@export var patron_name: String = ""
	@export var patron_type: String = ""
	@export var relationship_level: int = 0
	@export var discovered_turn: int = 0
	@export var contact_method: String = ""
	@export var available_jobs: Array[Dictionary] = []
	@export var completed_jobs: Array[Dictionary] = []
	@export var reputation_modifier: int = 0
	@export var payment_modifier: float = 1.0
	@export var special_rules: Array[String] = []
	@export var contact_frequency: int = 1  # How often they provide jobs
	@export var last_contact_turn: int = 0
	@export var patron_notes: String = ""
	@export var faction_affiliation: String = ""
	@export var world_of_origin: String = ""
	
	func _init(id: String = "", name: String = "", type: String = ""):
		if not id.is_empty():
			patron_id = id
		if not name.is_empty():
			patron_name = name
		if not type.is_empty():
			patron_type = type
		discovered_turn = 0  # Will be set when discovered
	
	func serialize() -> Dictionary:
		return {
			"patron_id": patron_id,
			"patron_name": patron_name,
			"patron_type": patron_type,
			"relationship_level": relationship_level,
			"discovered_turn": discovered_turn,
			"contact_method": contact_method,
			"available_jobs": available_jobs,
			"completed_jobs": completed_jobs,
			"reputation_modifier": reputation_modifier,
			"payment_modifier": payment_modifier,
			"special_rules": special_rules,
			"contact_frequency": contact_frequency,
			"last_contact_turn": last_contact_turn,
			"patron_notes": patron_notes,
			"faction_affiliation": faction_affiliation,
			"world_of_origin": world_of_origin
		}
	
	func deserialize(data: Dictionary) -> void:
		patron_id = data.get("patron_id", "")
		patron_name = data.get("patron_name", "")
		patron_type = data.get("patron_type", "")
		relationship_level = data.get("relationship_level", 0)
		discovered_turn = data.get("discovered_turn", 0)
		contact_method = data.get("contact_method", "")
		available_jobs = data.get("available_jobs", [])
		completed_jobs = data.get("completed_jobs", [])
		reputation_modifier = data.get("reputation_modifier", 0)
		payment_modifier = data.get("payment_modifier", 1.0)
		special_rules = data.get("special_rules", [])
		contact_frequency = data.get("contact_frequency", 1)
		last_contact_turn = data.get("last_contact_turn", 0)
		patron_notes = data.get("patron_notes", "")
		faction_affiliation = data.get("faction_affiliation", "")
		world_of_origin = data.get("world_of_origin", "")
	
	func validate() -> bool:
		return not patron_id.is_empty() and not patron_name.is_empty() and not patron_type.is_empty()
	
	func add_job(job_data: Dictionary) -> void:
		available_jobs.append(job_data)
	
	func complete_job(job_id: String, success: bool, payment: int) -> void:
		# Move from available to completed
		for i in range(available_jobs.size()):
			var job = available_jobs[i]
			if job.get("job_id", "") == job_id:
				job["completed"] = true
				job["success"] = success
				job["payment_received"] = payment
				completed_jobs.append(job)
				available_jobs.remove_at(i)
				
				# Update relationship based on success
				if success:
					relationship_level += 1
				else:
					relationship_level -= 1
				break
	
	func get_relationship_status() -> String:
		if relationship_level >= 10:
			return "Trusted"
		elif relationship_level >= 5:
			return "Favorable"
		elif relationship_level >= 0:
			return "Neutral"
		elif relationship_level >= -5:
			return "Unfavorable"
		else:
			return "Hostile"

## Equipment Discovery Resource
class EquipmentDiscovery extends Resource:
	@export var equipment_id: String = ""
	@export var equipment_name: String = ""
	@export var equipment_type: String = ""
	@export var equipment_category: String = ""
	@export var discovery_method: String = ""  # "exploration", "trade", "loot", etc.
	@export var discovery_turn: int = 0
	@export var discovery_location: String = ""
	@export var discovery_roll: int = 0
	@export var market_value: int = 0
	@export var rarity: String = "common"
	@export var condition: String = "good"
	@export var special_properties: Array[String] = []
	@export var assigned_to_crew: String = ""
	@export var in_stash: bool = true
	@export var discovery_narrative: String = ""
	
	func _init(id: String = "", name: String = "", type: String = ""):
		if not id.is_empty():
			equipment_id = id
		if not name.is_empty():
			equipment_name = name
		if not type.is_empty():
			equipment_type = type
		discovery_turn = 0  # Will be set when discovered
	
	func serialize() -> Dictionary:
		return {
			"equipment_id": equipment_id,
			"equipment_name": equipment_name,
			"equipment_type": equipment_type,
			"equipment_category": equipment_category,
			"discovery_method": discovery_method,
			"discovery_turn": discovery_turn,
			"discovery_location": discovery_location,
			"discovery_roll": discovery_roll,
			"market_value": market_value,
			"rarity": rarity,
			"condition": condition,
			"special_properties": special_properties,
			"assigned_to_crew": assigned_to_crew,
			"in_stash": in_stash,
			"discovery_narrative": discovery_narrative
		}
	
	func deserialize(data: Dictionary) -> void:
		equipment_id = data.get("equipment_id", "")
		equipment_name = data.get("equipment_name", "")
		equipment_type = data.get("equipment_type", "")
		equipment_category = data.get("equipment_category", "")
		discovery_method = data.get("discovery_method", "")
		discovery_turn = data.get("discovery_turn", 0)
		discovery_location = data.get("discovery_location", "")
		discovery_roll = data.get("discovery_roll", 0)
		market_value = data.get("market_value", 0)
		rarity = data.get("rarity", "common")
		condition = data.get("condition", "good")
		special_properties = data.get("special_properties", [])
		assigned_to_crew = data.get("assigned_to_crew", "")
		in_stash = data.get("in_stash", true)
		discovery_narrative = data.get("discovery_narrative", "")
	
	func validate() -> bool:
		return not equipment_id.is_empty() and not equipment_name.is_empty()
	
	func assign_to_crew(crew_id: String) -> void:
		assigned_to_crew = crew_id
		in_stash = false
	
	func return_to_stash() -> void:
		assigned_to_crew = ""
		in_stash = true
	
	func get_rarity_color() -> Color:
		match rarity:
			"legendary":
				return Color.GOLD
			"rare":
				return Color.PURPLE
			"uncommon":
				return Color.BLUE
			"common":
				return Color.WHITE
			_:
				return Color.GRAY

## World Phase State Resource
class WorldPhaseState extends Resource:
	@export var current_turn: int = 0
	@export var current_substep: int = 0
	@export var substep_name: String = ""
	@export var phase_started: bool = false
	@export var phase_completed: bool = false
	@export var crew_tasks_assigned: Dictionary = {}  # crew_id -> task_type
	@export var crew_tasks_completed: Dictionary = {}  # crew_id -> CrewTaskResult
	@export var automation_enabled: bool = false
	@export var automation_progress: int = 0
	@export var automation_total: int = 0
	@export var world_name: String = ""
	@export var world_traits: Array[String] = []
	@export var discovered_patrons: Array[Dictionary] = []
	@export var equipment_stash: Array[Dictionary] = []
	@export var phase_start_time: String = ""
	@export var phase_end_time: String = ""
	
	func _init():
		current_turn = 0
		current_substep = 0
		phase_started = false
		phase_completed = false
		automation_enabled = false
	
	func serialize() -> Dictionary:
		return {
			"current_turn": current_turn,
			"current_substep": current_substep,
			"substep_name": substep_name,
			"phase_started": phase_started,
			"phase_completed": phase_completed,
			"crew_tasks_assigned": crew_tasks_assigned,
			"crew_tasks_completed": crew_tasks_completed,
			"automation_enabled": automation_enabled,
			"automation_progress": automation_progress,
			"automation_total": automation_total,
			"world_name": world_name,
			"world_traits": world_traits,
			"discovered_patrons": discovered_patrons,
			"equipment_stash": equipment_stash,
			"phase_start_time": phase_start_time,
			"phase_end_time": phase_end_time
		}
	
	func deserialize(data: Dictionary) -> void:
		current_turn = data.get("current_turn", 0)
		current_substep = data.get("current_substep", 0)
		substep_name = data.get("substep_name", "")
		phase_started = data.get("phase_started", false)
		phase_completed = data.get("phase_completed", false)
		crew_tasks_assigned = data.get("crew_tasks_assigned", {})
		crew_tasks_completed = data.get("crew_tasks_completed", {})
		automation_enabled = data.get("automation_enabled", false)
		automation_progress = data.get("automation_progress", 0)
		automation_total = data.get("automation_total", 0)
		world_name = data.get("world_name", "")
		world_traits = data.get("world_traits", [])
		discovered_patrons = data.get("discovered_patrons", [])
		equipment_stash = data.get("equipment_stash", [])
		phase_start_time = data.get("phase_start_time", "")
		phase_end_time = data.get("phase_end_time", "")
	
	func validate() -> bool:
		return current_turn >= 0 and current_substep >= 0
	
	func start_phase() -> void:
		phase_started = true
		phase_completed = false
		phase_start_time = Time.get_datetime_string_from_system()
		current_substep = 0
	
	func complete_phase() -> void:
		phase_completed = true
		phase_end_time = Time.get_datetime_string_from_system()
	
	func assign_crew_task(crew_id: String, task_type: String) -> void:
		crew_tasks_assigned[crew_id] = task_type
	
	func complete_crew_task(crew_id: String, result: CrewTaskResult) -> void:
		crew_tasks_completed[crew_id] = result.serialize()
	
	func get_phase_progress() -> float:
		if automation_total <= 0:
			return 0.0
		return float(automation_progress) / float(automation_total)
	
	func get_completed_tasks_count() -> int:
		return crew_tasks_completed.size()
	
	func get_assigned_tasks_count() -> int:
		return crew_tasks_assigned.size()

## Job Opportunity Resource
class JobOpportunity extends Resource:
	@export var job_id: String = ""
	@export var job_title: String = ""
	@export var job_type: String = ""
	@export var patron_id: String = ""
	@export var patron_name: String = ""
	@export var base_payment: int = 0
	@export var danger_level: int = 1
	@export var requirements: Array[String] = []
	@export var description: String = ""
	@export var time_limit: int = 0  # 0 = no limit, >0 = turns until expires
	@export var special_conditions: Array[String] = []
	@export var potential_rewards: Array[String] = []
	@export var generation_turn: int = 0
	@export var expiration_turn: int = 0
	@export var accepted: bool = false
	@export var completed: bool = false
	@export var job_location: String = ""
	
	func _init(id: String = "", title: String = "", type: String = ""):
		if not id.is_empty():
			job_id = id
		if not title.is_empty():
			job_title = title
		if not type.is_empty():
			job_type = type
		generation_turn = 0  # Will be set when generated
	
	func serialize() -> Dictionary:
		return {
			"job_id": job_id,
			"job_title": job_title,
			"job_type": job_type,
			"patron_id": patron_id,
			"patron_name": patron_name,
			"base_payment": base_payment,
			"danger_level": danger_level,
			"requirements": requirements,
			"description": description,
			"time_limit": time_limit,
			"special_conditions": special_conditions,
			"potential_rewards": potential_rewards,
			"generation_turn": generation_turn,
			"expiration_turn": expiration_turn,
			"accepted": accepted,
			"completed": completed,
			"job_location": job_location
		}
	
	func deserialize(data: Dictionary) -> void:
		job_id = data.get("job_id", "")
		job_title = data.get("job_title", "")
		job_type = data.get("job_type", "")
		patron_id = data.get("patron_id", "")
		patron_name = data.get("patron_name", "")
		base_payment = data.get("base_payment", 0)
		danger_level = data.get("danger_level", 1)
		requirements = data.get("requirements", [])
		description = data.get("description", "")
		time_limit = data.get("time_limit", 0)
		special_conditions = data.get("special_conditions", [])
		potential_rewards = data.get("potential_rewards", [])
		generation_turn = data.get("generation_turn", 0)
		expiration_turn = data.get("expiration_turn", 0)
		accepted = data.get("accepted", false)
		completed = data.get("completed", false)
		job_location = data.get("job_location", "")
	
	func validate() -> bool:
		return not job_id.is_empty() and not job_title.is_empty() and base_payment > 0
	
	func calculate_final_payment(reputation_modifier: int = 0) -> int:
		var final_payment = base_payment
		final_payment += reputation_modifier
		final_payment += danger_level  # Danger bonus
		return max(1, final_payment)  # Minimum 1 credit
	
	func is_expired(current_turn: int) -> bool:
		return time_limit > 0 and current_turn > expiration_turn
	
	func get_danger_description() -> String:
		match danger_level:
			1:
				return "Low Risk"
			2:
				return "Moderate Risk"
			3:
				return "High Risk"
			4:
				return "Extreme Risk"
			5:
				return "Suicidal Risk"
			_:
				return "Unknown Risk"

## Static factory methods for creating resources
static func create_crew_task_result(crew_id: String, task_type: String) -> CrewTaskResult:
	return CrewTaskResult.new(crew_id, task_type)

static func create_patron_data(patron_id: String, patron_name: String, patron_type: String) -> PatronData:
	return PatronData.new(patron_id, patron_name, patron_type)

static func create_equipment_discovery(equipment_id: String, equipment_name: String, equipment_type: String) -> EquipmentDiscovery:
	return EquipmentDiscovery.new(equipment_id, equipment_name, equipment_type)

static func create_world_phase_state() -> WorldPhaseState:
	return WorldPhaseState.new()

static func create_job_opportunity(job_id: String, job_title: String, job_type: String) -> JobOpportunity:
	return JobOpportunity.new(job_id, job_title, job_type)

## Utility methods for batch operations
static func serialize_crew_task_results(results: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for result in results:
		if result and result.validate():
			serialized.append(result.serialize())
	return serialized

static func deserialize_crew_task_results(data: Array) -> Array[CrewTaskResult]:
	var results: Array[CrewTaskResult] = []
	for result_data in data:
		var result = CrewTaskResult.new()
		result.deserialize(result_data)
		if result.validate():
			results.append(result)
	return results