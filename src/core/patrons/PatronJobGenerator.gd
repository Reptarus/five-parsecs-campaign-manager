@tool
extends Node
class_name PatronJobGenerator

## Patron Job Generator for Five Parsecs Campaign Manager
## Handles patron mission creation, relationship progression, and job variety

# Safe imports
# GlobalEnums available as autoload singleton
const Patron = preload("res://src/core/rivals/Patron.gd")

## Patron Job Data Structure
class PatronJob:
	var job_id: String
	var patron_id: String
	var patron_name: String
	var job_type: String
	var mission_title: String
	var mission_description: String
	var base_payment: int = 6
	var danger_pay: int = 0
	var bonus_payment: int = 0
	var difficulty_level: int = 2
	var required_crew_size: int = 3
	var time_limit: int = 0  # 0 = no limit, >0 = turns to complete
	var special_requirements: Array[String] = []
	var success_rewards: Dictionary = {}
	var failure_consequences: Dictionary = {}
	var patron_relationship_change: int = 0
	
	func _init(id: String = ""):
		job_id = id if id != "" else "job_" + str(Time.get_unix_time_from_system())
	
	func serialize() -> Dictionary:
		return {
			"job_id": job_id,
			"patron_id": patron_id,
			"patron_name": patron_name,
			"job_type": job_type,
			"mission_title": mission_title,
			"mission_description": mission_description,
			"base_payment": base_payment,
			"danger_pay": danger_pay,
			"bonus_payment": bonus_payment,
			"difficulty_level": difficulty_level,
			"required_crew_size": required_crew_size,
			"time_limit": time_limit,
			"special_requirements": special_requirements,
			"success_rewards": success_rewards,
			"failure_consequences": failure_consequences,
			"patron_relationship_change": patron_relationship_change
		}

## Patron Job Generator Signals
signal patron_job_generated(job: PatronJob)
signal patron_relationship_updated(patron_id: String, relationship_level: int)
signal patron_mission_completed(patron_id: String, success: bool)

## Job generation data
var job_templates: Dictionary = {}
var patron_type_modifiers: Dictionary = {}
var relationship_benefits: Dictionary = {}

func _ready() -> void:
	_initialize_job_data()
	print("PatronJobGenerator: Initialized successfully")

## Initialize patron job data
func _initialize_job_data() -> void:
	_load_job_templates()
	_load_patron_modifiers()
	_load_relationship_benefits()

## Load job templates for different mission types
func _load_job_templates() -> void:
	job_templates = {
		"ESCORT": {
			"titles": ["Safe Passage", "VIP Transport", "Diplomatic Escort", "Merchant Guard"],
			"descriptions": [
				"Escort %s safely to their destination",
				"Provide protection during transit to %s",
				"Guard valuable cargo during transport",
				"Ensure safe arrival of important passenger"
			],
			"base_payment": 6,
			"danger_range": [1, 3],
			"difficulty_range": [1, 3],
			"special_rules": ["protect_target", "time_sensitive"],
			"success_bonus": {"reputation": 1, "contacts": 0}
		},
		"SALVAGE": {
			"titles": ["Recovery Operation", "Salvage Rights", "Archaeological Dig", "Wreck Retrieval"],
			"descriptions": [
				"Recover valuable items from %s",
				"Salvage technology from abandoned site",
				"Investigate and retrieve artifacts",
				"Secure valuable materials before competitors"
			],
			"base_payment": 5,
			"danger_range": [2, 4],
			"difficulty_range": [2, 4],
			"special_rules": ["exploration", "competition"],
			"success_bonus": {"equipment": 1, "story_points": 1}
		},
		"DELIVERY": {
			"titles": ["Courier Service", "Urgent Delivery", "Package Run", "Data Transfer"],
			"descriptions": [
				"Deliver important package to %s",
				"Transport sensitive materials discreetly",
				"Courier classified information",
				"Rush delivery of critical supplies"
			],
			"base_payment": 4,
			"danger_range": [0, 2],
			"difficulty_range": [1, 2],
			"special_rules": ["stealth", "time_critical"],
			"success_bonus": {"credits": 2}
		},
		"PATROL": {
			"titles": ["Security Patrol", "Area Sweep", "Border Watch", "Perimeter Check"],
			"descriptions": [
				"Patrol %s and eliminate threats",
				"Sweep area for hostile activity",
				"Maintain security in designated zone",
				"Monitor for unauthorized intrusions"
			],
			"base_payment": 5,
			"danger_range": [1, 3],
			"difficulty_range": [1, 3],
			"special_rules": ["search_destroy", "area_control"],
			"success_bonus": {"reputation": 1}
		},
		"INVESTIGATION": {
			"titles": ["Corporate Espionage", "Missing Person", "Intelligence Gathering", "Surveillance Op"],
			"descriptions": [
				"Investigate suspicious activity at %s",
				"Gather intelligence on target organization",
				"Locate missing person last seen at %s",
				"Conduct covert surveillance operation"
			],
			"base_payment": 7,
			"danger_range": [2, 3],
			"difficulty_range": [2, 4],
			"special_rules": ["stealth", "information_gathering"],
			"success_bonus": {"story_points": 2, "contacts": 1}
		},
		"ASSAULT": {
			"titles": ["Direct Strike", "Facility Raid", "Hostile Takeover", "Elimination Mission"],
			"descriptions": [
				"Assault enemy position at %s",
				"Raid hostile facility and secure objectives",
				"Eliminate specific targets",
				"Capture or destroy enemy assets"
			],
			"base_payment": 8,
			"danger_range": [3, 5],
			"difficulty_range": [3, 5],
			"special_rules": ["combat_heavy", "high_risk"],
			"success_bonus": {"equipment": 2, "reputation": 2}
		}
	}

## Load patron type modifiers
func _load_patron_modifiers() -> void:
	patron_type_modifiers = {
		"CORPORATION": {
			"payment_modifier": 1.2,
			"preferred_jobs": ["ESCORT", "DELIVERY", "INVESTIGATION"],
			"bonus_equipment": true,
			"reputation_value": 2
		},
		"MILITARY": {
			"payment_modifier": 1.0,
			"preferred_jobs": ["PATROL", "ASSAULT", "ESCORT"],
			"danger_bonus": 1,
			"reputation_value": 2
		},
		"CRIMINAL": {
			"payment_modifier": 1.3,
			"preferred_jobs": ["DELIVERY", "ASSAULT", "INVESTIGATION"],
			"risk_bonus": true,
			"reputation_value": -1
		},
		"TRADER": {
			"payment_modifier": 0.9,
			"preferred_jobs": ["ESCORT", "DELIVERY", "SALVAGE"],
			"equipment_discount": true,
			"reputation_value": 1
		},
		"SCIENTIST": {
			"payment_modifier": 1.1,
			"preferred_jobs": ["SALVAGE", "INVESTIGATION", "ESCORT"],
			"story_bonus": true,
			"reputation_value": 1
		},
		"GOVERNMENT": {
			"payment_modifier": 1.0,
			"preferred_jobs": ["PATROL", "INVESTIGATION", "ESCORT"],
			"authority_bonus": true,
			"reputation_value": 3
		}
	}

## Load relationship progression benefits
func _load_relationship_benefits() -> void:
	relationship_benefits = {
		-2: {"payment_mod": 0.7, "job_frequency": 0.3, "description": "Hostile - rare jobs, poor pay"},
		-1: {"payment_mod": 0.8, "job_frequency": 0.5, "description": "Unfriendly - reduced opportunities"},
		0: {"payment_mod": 1.0, "job_frequency": 1.0, "description": "Neutral - standard terms"},
		1: {"payment_mod": 1.1, "job_frequency": 1.2, "description": "Friendly - better opportunities"},
		2: {"payment_mod": 1.2, "job_frequency": 1.5, "description": "Trusted - preferred contractor"},
		3: {"payment_mod": 1.4, "job_frequency": 2.0, "description": "Allied - exclusive contracts"}
	}

## Generate patron job
func generate_patron_job(patron_data: Patron, crew_size: int = 4, relationship_level: int = 0) -> PatronJob:
	var job = PatronJob.new()
	
	# Basic job info
	job.patron_id = patron_data.patron_name  # Using name as ID for simplicity
	job.patron_name = patron_data.patron_name
	
	# Select job type based on patron preferences
	job.job_type = _select_job_type(patron_data)
	var template = job_templates[job.job_type]
	
	# Generate mission details
	_generate_mission_details(job, template)
	
	# Calculate payment based on patron type and relationship
	_calculate_payment(job, patron_data, relationship_level)
	
	# Set difficulty and requirements
	_set_job_difficulty(job, template, crew_size)
	
	# Add special requirements and rewards
	_add_special_elements(job, patron_data, template)
	
	print("PatronJobGenerator: Generated %s job '%s' for %s" % [job.job_type, job.mission_title, job.patron_name])
	self.patron_job_generated.emit(job)
	
	return job

## Select job type based on patron preferences
func _select_job_type(patron_data: Patron) -> String:
	var patron_type = patron_data.patron_type if patron_data.patron_type != "" else "TRADER"
	var modifiers = patron_type_modifiers.get(patron_type, patron_type_modifiers.TRADER)
	var preferred_jobs = modifiers.preferred_jobs
	
	# 70% chance for preferred job type, 30% for any job type
	if randi_range(1, 100) <= 70 and preferred_jobs.size() > 0:
		return preferred_jobs[randi() % preferred_jobs.size()]
	else:
		var all_job_types = job_templates.keys()
		return all_job_types[randi() % all_job_types.size()]

## Generate mission title and description
func _generate_mission_details(job: PatronJob, template: Dictionary) -> void:
	var titles = template.titles
	var descriptions = template.descriptions
	
	job.mission_title = titles[randi() % titles.size()]
	
	# Generate description with location placeholder
	var description_template = descriptions[randi() % descriptions.size()]
	var locations = ["the industrial district", "the old ruins", "sector 7", "the mining facility", "the research station"]
	var location = locations[randi() % locations.size()]
	job.mission_description = description_template % location

## Calculate payment based on various factors
func _calculate_payment(job: PatronJob, patron_data: Patron, relationship_level: int) -> void:
	var template = job_templates[job.job_type]
	var base_payment = template.base_payment
	
	# Apply patron type modifier
	var patron_type = patron_data.patron_type if patron_data.patron_type != "" else "TRADER"
	var patron_mod = patron_type_modifiers.get(patron_type, patron_type_modifiers.TRADER)
	var payment_modifier = patron_mod.payment_modifier
	
	# Apply relationship modifier
	var relationship_mod = relationship_benefits.get(relationship_level, relationship_benefits[0])
	payment_modifier *= relationship_mod.payment_mod
	
	# Calculate final payment
	job.base_payment = int(base_payment * payment_modifier)
	
	# Generate danger pay
	var danger_range = template.danger_range
	job.danger_pay = randi_range(danger_range[0], danger_range[1])
	
	# Add bonus payment for high-reputation patrons
	if patron_data.reputation >= 2:
		job.bonus_payment = randi_range(1, 3)

## Set job difficulty and requirements
func _set_job_difficulty(job: PatronJob, template: Dictionary, crew_size: int) -> void:
	var difficulty_range = template.difficulty_range
	job.difficulty_level = randi_range(difficulty_range[0], difficulty_range[1])
	
	# Adjust required crew size based on difficulty
	job.required_crew_size = max(2, job.difficulty_level + randi_range(-1, 1))
	
	# Scale with actual crew size (don't require more than they have)
	job.required_crew_size = min(job.required_crew_size, crew_size + 1)
	
	# Set time limit for urgent jobs
	if "time_critical" in template.get("special_rules", []):
		job.time_limit = randi_range(2, 4)  # 2-4 turns to complete

## Add special requirements and rewards
func _add_special_elements(job: PatronJob, patron_data: Patron, template: Dictionary) -> void:
	# Add special requirements based on job type
	var special_rules = template.get("special_rules", [])
	for rule in special_rules:
		match rule:
			"stealth":
				job.special_requirements.append("Avoid detection")
			"time_critical":
				job.special_requirements.append("Complete within time limit")
			"protect_target":
				job.special_requirements.append("Target must survive")
			"high_risk":
				job.special_requirements.append("Extremely dangerous mission")
	
	# Set success rewards
	var success_bonus = template.get("success_bonus", {})
	job.success_rewards = success_bonus.duplicate()
	
	# Add patron-specific bonuses
	var patron_type = patron_data.patron_type if patron_data.patron_type != "" else "TRADER"
	var patron_mod = patron_type_modifiers.get(patron_type, patron_type_modifiers.TRADER)
	
	if patron_mod.get("bonus_equipment", false):
		job.success_rewards["equipment_bonus"] = true
	if patron_mod.get("story_bonus", false):
		job.success_rewards["story_points"] = job.success_rewards.get("story_points", 0) + 1
	
	# Set failure consequences
	job.failure_consequences = {
		"reputation_loss": 1,
		"payment_penalty": 0.5
	}
	
	if job.difficulty_level >= 4:
		job.failure_consequences["equipment_risk"] = true

## Process job completion
func process_job_completion(job: PatronJob, success: bool, performance_rating: int = 3) -> Dictionary:
	var result = {
		"success": success,
		"payment_received": 0,
		"relationship_change": 0,
		"rewards_earned": {},
		"consequences": {}
	}
	
	if success:
		# Calculate payment
		result.payment_received = job.base_payment + job.danger_pay
		
		# Performance bonuses
		if performance_rating >= 4:  # Excellent performance
			result.payment_received += job.bonus_payment
			result.relationship_change = 1
		elif performance_rating >= 3:  # Good performance
			result.relationship_change = 1
		# Standard performance = no change
		
		# Apply success rewards
		result.rewards_earned = job.success_rewards.duplicate()
		
		print("PatronJobGenerator: Job completed successfully for %s (+%d relationship)" % [job.patron_name, result.relationship_change])
	else:
		# Failure consequences
		result.relationship_change = -1
		result.consequences = job.failure_consequences.duplicate()
		
		# Partial payment for attempted completion
		if performance_rating >= 2:
			result.payment_received = int(job.base_payment * 0.3)
		
		print("PatronJobGenerator: Job failed for %s (-1 relationship)" % job.patron_name)
	
	self.patron_mission_completed.emit(job.patron_id, success)
	return result

## Update patron relationship
func update_patron_relationship(patron_data: Patron, relationship_change: int) -> int:
	var old_level = patron_data.reputation
	patron_data.reputation = clamp(patron_data.reputation + relationship_change, -3, 3)
	
	if patron_data.reputation != old_level:
		print("PatronJobGenerator: %s relationship: %d -> %d" % [patron_data.patron_name, old_level, patron_data.reputation])
		self.patron_relationship_updated.emit(patron_data.patron_name, patron_data.reputation)
	
	return patron_data.reputation

## Check if patron has jobs available
func has_jobs_available(patron_data: Patron, relationship_level: int) -> bool:
	var relationship_info = relationship_benefits.get(relationship_level, relationship_benefits[0])
	var job_frequency = relationship_info.job_frequency
	
	# Roll against job frequency (higher relationship = more jobs)
	var availability_roll = randf()
	return availability_roll <= (job_frequency * 0.5)  # 50% base chance modified by relationship

## Generate multiple job offers from patron
func generate_job_offers(patron_data: Patron, count: int = 2, crew_size: int = 4, relationship_level: int = 0) -> Array[PatronJob]:
	var jobs: Array[PatronJob] = []
	
	for i in range(count):
		var job = generate_patron_job(patron_data, crew_size, relationship_level)
		jobs.append(job)
	
	return jobs

## Get patron job difficulty assessment
func get_job_difficulty_assessment(job: PatronJob, crew_size: int) -> Dictionary:
	var assessment = {
		"difficulty_name": "",
		"crew_requirement": "",
		"risk_level": "",
		"recommended": true
	}
	
	# Difficulty names
	match job.difficulty_level:
		1: assessment.difficulty_name = "Routine"
		2: assessment.difficulty_name = "Standard"
		3: assessment.difficulty_name = "Challenging"
		4: assessment.difficulty_name = "Dangerous"
		5: assessment.difficulty_name = "Extremely Dangerous"
	
	# Crew requirement assessment
	if job.required_crew_size > crew_size:
		assessment.crew_requirement = "Understaffed - need %d more crew" % (job.required_crew_size - crew_size)
		assessment.recommended = false
	elif job.required_crew_size == crew_size:
		assessment.crew_requirement = "Adequate crew size"
	else:
		assessment.crew_requirement = "Overstaffed - %d extra crew" % (crew_size - job.required_crew_size)
	
	# Risk assessment
	var total_payment = job.base_payment + job.danger_pay + job.bonus_payment
	var risk_ratio = float(job.difficulty_level) / float(total_payment)
	
	if risk_ratio > 0.4:
		assessment.risk_level = "High risk, low reward"
		assessment.recommended = false
	elif risk_ratio < 0.2:
		assessment.risk_level = "Low risk, good reward"
	else:
		assessment.risk_level = "Balanced risk/reward"
	
	return assessment

## Generate mock job completion result for testing
func generate_mock_job_result(job: PatronJob, force_success: bool = true) -> Dictionary:
	var performance_rating = randi_range(2, 5) if force_success else randi_range(1, 3)
	return process_job_completion(job, force_success, performance_rating)

## Get relationship description
func get_relationship_description(relationship_level: int) -> String:
	var relationship_info = relationship_benefits.get(relationship_level, relationship_benefits[0])
	return relationship_info.description

## Safe method call helper
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null