class_name CrewData
extends Resource

## Enterprise-grade Crew Data Model for Five Parsecs Campaign Manager
## Replaces Dictionary-based crew management with type-safe operations
## Implements validation, crew composition rules, and character relationship tracking

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

# Import required classes
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

@export var members: Array[Resource] = [] # Will be CrewMember when available
@export var captain: Resource # Will be CrewMember when available
@export var total_size: int = 4
@export var is_complete: bool = false
@export var formation_date: String = ""
@export var crew_name: String = ""
@export var specialization: String = "" # e.g., "Combat Specialists", "Traders", "Explorers"

## Crew composition constraints from Five Parsecs rules
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8
const VALID_SPECIALIZATIONS = ["Combat", "Exploration", "Trading", "Balanced"]

## Validation framework ensuring Five Parsecs rule compliance
func validate() -> ValidationResult:
	var result = ValidationResult.new()
	
	# Size validation
	if total_size < MIN_CREW_SIZE or total_size > MAX_CREW_SIZE:
		result.add_error("Crew size must be between %d and %d" % [MIN_CREW_SIZE, MAX_CREW_SIZE])
	
	if members.size() != total_size:
		result.add_error("Member count (%d) doesn't match specified size (%d)" % [members.size(), total_size])
	
	# Captain validation
	if not captain:
		result.add_error("Crew must have a designated captain")
	elif captain not in members:
		result.add_error("Captain must be a member of the crew")
	
	# Character validation
	for i in range(members.size()):
		var member = members[i]
		if not member:
			result.add_error("Crew member at index %d is null" % i)
			continue
			
		var member_validation = member.validate()
		if not member_validation.is_valid():
			result.add_error("Crew member '%s' is invalid: %s" % [member.member_name, member_validation.get_error_summary()])
	
	# Crew composition rules
	_validate_crew_composition(result)
	
	return result

## Five Parsecs crew composition validation
func _validate_crew_composition(result: ValidationResult) -> void:
	var role_counts = {}
	
	for member in members:
		if member and member.role:
			role_counts[member.role] = role_counts.get(member.role, 0) + 1
	
	# Ensure balanced crew composition
	if role_counts.size() == 1 and members.size() > 2:
		result.add_warning("Crew lacks role diversity - consider adding different specializations")
	
	# Check for required leadership
	var has_leader = false
	for member in members:
		if member and member.has_leadership_trait():
			has_leader = true
			break
	
	if not has_leader and members.size() > 1:
		result.add_warning("Large crew without leadership traits may suffer penalties")

## Crew management operations with business logic
func add_member(new_member: Resource) -> bool:
	if not new_member:
		push_error("Cannot add null crew member")
		return false
	
	if members.size() >= MAX_CREW_SIZE:
		push_warning("Crew at maximum capacity (%d)" % MAX_CREW_SIZE)
		return false
	
	if new_member in members:
		push_warning("Member '%s' is already in the crew" % new_member.member_name)
		return false
	
	members.append(new_member)
	total_size = members.size()
	_update_completion_status()
	return true

func remove_member(member: Resource) -> bool:
	if not member or member not in members:
		return false
	
	# Prevent removing the captain without replacement
	if member == captain and members.size() > 1:
		push_warning("Cannot remove captain without assigning a replacement")
		return false
	
	members.erase(member)
	total_size = members.size()
	
	# Clear captain if they were removed
	if member == captain:
		captain = null
	
	_update_completion_status()
	return true

func set_captain(new_captain: Resource) -> bool:
	if not new_captain:
		push_error("Cannot set null captain")
		return false
	
	if new_captain not in members:
		push_error("Captain must be a crew member")
		return false
	
	captain = new_captain
	_update_completion_status()
	return true

## Business intelligence methods for Five Parsecs mechanics
func get_total_combat_rating() -> int:
	var total = 0
	for member in members:
		if member and member.stats:
			total += member.stats.combat
	return total

func get_crew_morale() -> float:
	if members.is_empty():
		return 0.0
	
	var total_morale = 0.0
	for member in members:
		if member:
			total_morale += member.get_current_morale()
	
	return total_morale / members.size()

func has_specialization(specialization_type: String) -> bool:
	for member in members:
		if member and member.role == specialization_type:
			return true
	return false

## State management and persistence
func _update_completion_status() -> void:
	is_complete = (members.size() >= MIN_CREW_SIZE and
				  captain != null and
				  validate().is_valid())

func to_dictionary() -> Dictionary:
	var member_dicts = []
	for member in members:
		if member:
			member_dicts.append(member.to_dictionary())
	
	return {
		"members": member_dicts,
		"captain": captain.to_dictionary() if captain else null,
		"total_size": total_size,
		"is_complete": is_complete,
		"formation_date": formation_date,
		"crew_name": crew_name,
		"specialization": specialization
	}

## Factory methods for common crew configurations
static func create_starter_crew(size: int = 4) -> CrewData:
	var crew = CrewData.new()
	crew.total_size = size
	crew.formation_date = Time.get_datetime_string_from_system()
	crew.crew_name = "New Crew"
	crew.specialization = "Balanced"
	return crew

static func create_from_template(template_name: String) -> CrewData:
	# Load predefined crew templates for quick setup
	var crew = CrewData.new()
	
	match template_name:
		"combat_specialists":
			crew.specialization = "Combat"
			crew.crew_name = "Combat Specialists"
		"explorers":
			crew.specialization = "Exploration"
			crew.crew_name = "Deep Space Explorers"
		"traders":
			crew.specialization = "Trading"
			crew.crew_name = "Merchant Crew"
		_:
			crew.specialization = "Balanced"
			crew.crew_name = "Balanced Crew"
	
	crew.formation_date = Time.get_datetime_string_from_system()
	return crew
