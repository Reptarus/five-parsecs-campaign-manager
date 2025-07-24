@tool
extends Node
class_name JobValidator

## Job Validator - Feature 8 Implementation
## Validates job requirements and constraints for Five Parsecs from Home
## Integrated with Universal Safety Framework patterns

const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")

## Validation rules configuration
var validation_rules = {
	"min_payment": 50,
	"max_payment": 10000,
	"min_difficulty": 1,
	"max_difficulty": 5,
	"required_fields": ["job_id", "job_type", "reward_credits"],
	"valid_job_types": ["patron", "opportunity", "quest", "trade"]
}

## Main job validation method
func validate_job_requirements(job: Resource) -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not job:
		result.is_valid = false
		result.errors.append("Job resource is null")
		return result
	
	# Validate required fields
	for field in validation_rules.required_fields:
		if not job.has_meta(field):
			result.is_valid = false
			result.errors.append("Missing required field: %s" % field)
	
	# Validate job type
	var job_type = job.get_meta("job_type", "")
	if not job_type in validation_rules.valid_job_types:
		result.is_valid = false
		result.errors.append("Invalid job type: %s" % job_type)
	
	# Validate payment range
	var payment = job.get_meta("reward_credits", 0)
	if payment < validation_rules.min_payment:
		result.is_valid = false
		result.errors.append("Payment too low: %d (minimum: %d)" % [payment, validation_rules.min_payment])
	elif payment > validation_rules.max_payment:
		result.warnings.append("Payment very high: %d (maximum recommended: %d)" % [payment, validation_rules.max_payment])
	
	# Validate difficulty
	var difficulty = job.get_meta("difficulty", 1)
	if difficulty < validation_rules.min_difficulty or difficulty > validation_rules.max_difficulty:
		result.warnings.append("Difficulty outside normal range: %d (range: %d-%d)" % [difficulty, validation_rules.min_difficulty, validation_rules.max_difficulty])
	
	return result

## Validate job against crew capabilities
func validate_crew_requirements(job: Resource, crew_data: Array) -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	var requirements = job.get_meta("requirements", [])
	if requirements.is_empty():
		return result
	
	# Check crew availability
	if crew_data.is_empty():
		result.warnings.append("No crew data available for validation")
		return result
	
	# Validate specific requirements
	for requirement in requirements:
		var req_text = str(requirement).to_lower()
		
		if "combat" in req_text:
			if not _has_combat_capable_crew(crew_data):
				result.warnings.append("No combat-capable crew members found")
		
		if "medical" in req_text:
			if not _has_medical_crew(crew_data):
				result.warnings.append("No medical specialist available")
		
		if "tech" in req_text:
			if not _has_tech_crew(crew_data):
				result.warnings.append("No technical specialist available")
	
	return result

## Check if crew has combat capabilities
func _has_combat_capable_crew(crew_data: Array) -> bool:
	for crew_member in crew_data:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var combat_skill = crew_member.get("combat", 0)
			if combat_skill >= 2:
				return true
	return false

## Check if crew has medical capabilities
func _has_medical_crew(crew_data: Array) -> bool:
	for crew_member in crew_data:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var background = crew_member.get("background", "")
			if "medic" in str(background).to_lower():
				return true
			# Check skills array if present
			var skills = crew_member.get("skills", [])
			for skill in skills:
				if "medical" in str(skill).to_lower():
					return true
	return false

## Check if crew has technical capabilities
func _has_tech_crew(crew_data: Array) -> bool:
	for crew_member in crew_data:
		if typeof(crew_member) == TYPE_DICTIONARY:
			var tech_skill = crew_member.get("tech", 0)
			if tech_skill >= 2:
				return true
	return false

## Update validation rules (for configuration)
func set_validation_rules(new_rules: Dictionary) -> void:
	for key in new_rules.keys():
		if validation_rules.has(key):
			validation_rules[key] = new_rules[key]

## Get current validation rules
func get_validation_rules() -> Dictionary:
	return validation_rules.duplicate()