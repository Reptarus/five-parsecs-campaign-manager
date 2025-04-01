@tool
extends Resource

signal campaign_started
signal campaign_ended(victory: bool)
signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
signal resources_changed(resources: Dictionary)

@export var campaign_name: String = "":
	set(value):
		if value.length() == 0:
			push_error("Campaign name cannot be empty")
			return
		campaign_name = value

@export var campaign_type: int = 0
@export var campaign_difficulty: int = 0
@export var current_phase: int = 0
@export var completed_phases: Array = []
@export var resources: Dictionary = {}
@export var start_date: Dictionary = {}
@export var current_date: Dictionary = {}
@export var total_days: int = 0

## Constructor with initialization
## @param name The name of the campaign
func _init(name: String = "New Campaign") -> void:
	campaign_name = name
	_initialize_resources()
	_initialize_dates()
	
	# Ensure resource has valid path for testing/serialization
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var random_suffix = randi() % 1000000
		resource_path = "res://tests/generated/campaign_%d_%d.tres" % [timestamp, random_suffix]

## Initialize default resources
func _initialize_resources() -> void:
	resources = {
		"credits": 0,
		"reputation": 0,
		"story_points": 0
	}

## Initialize dates for the campaign
func _initialize_dates() -> void:
	var current_time = Time.get_datetime_dict_from_system()
	start_date = {
		"year": current_time.year,
		"month": current_time.month,
		"day": current_time.day
	}
	current_date = start_date.duplicate()
	total_days = 0

## Start the campaign
func start_campaign() -> void:
	campaign_started.emit()
	start_phase(0)

## End the campaign
## @param victory Whether the campaign ended in victory
func end_campaign(victory: bool = false) -> void:
	campaign_ended.emit(victory)

## Start a specific campaign phase
## @param phase The phase to start
func start_phase(phase: int) -> void:
	var old_phase = current_phase
	current_phase = phase
	phase_changed.emit(old_phase, current_phase)
	phase_started.emit(current_phase)

## Complete the current phase
func complete_phase() -> void:
	if not current_phase in completed_phases:
		completed_phases.append(current_phase)
	phase_completed.emit(current_phase)

## Advance campaign time
## @param days Number of days to advance
func advance_time(days: int = 1) -> void:
	if days <= 0:
		push_warning("Attempted to advance time by non-positive days: " + str(days))
		return
		
	total_days += days
	
	# Simple calendar logic (assuming 30 days per month)
	var day = current_date.day + days
	var month = current_date.month
	var year = current_date.year
	
	while day > 30:
		day -= 30
		month += 1
		
		if month > 12:
			month = 1
			year += 1
	
	current_date.day = day
	current_date.month = month
	current_date.year = year

## Add a resource
## @param resource_type The type of resource to add
## @param amount The amount to add
func add_resource(resource_type: String, amount: int) -> void:
	if resource_type in resources:
		resources[resource_type] += amount
		resources_changed.emit(resources)
	else:
		push_error("Unknown resource type: " + resource_type)

## Remove a resource
## @param resource_type The type of resource to remove
## @param amount The amount to remove
## @return Whether the removal was successful
func remove_resource(resource_type: String, amount: int) -> bool:
	if not resource_type in resources:
		push_error("Unknown resource type: " + resource_type)
		return false
		
	if resources[resource_type] < amount:
		push_warning("Insufficient resources to remove: " + resource_type + " (" +
			str(resources[resource_type]) + " < " + str(amount) + ")")
		return false
		
	resources[resource_type] -= amount
	resources_changed.emit(resources)
	return true

## Get the amount of a resource
## @param resource_type The type of resource to get
## @return The amount of the resource
func get_resource(resource_type: String) -> int:
	if resource_type in resources:
		return resources[resource_type]
	return 0

## Serialize the campaign to a Dictionary
## @return The serialized campaign data
func serialize() -> Dictionary:
	# Ensure the resource has a valid path for serialization
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var random_suffix = randi() % 1000000
		resource_path = "res://tests/generated/campaign_%d_%d.tres" % [timestamp, random_suffix]
		
	var data = {
		"campaign_name": campaign_name,
		"campaign_type": campaign_type,
		"campaign_difficulty": campaign_difficulty,
		"current_phase": current_phase,
		"completed_phases": completed_phases.duplicate(),
		"resources": resources.duplicate(),
		"start_date": start_date.duplicate(),
		"current_date": current_date.duplicate(),
		"total_days": total_days
	}
	return data

## Deserialize campaign data
## @param data The data to deserialize
## @return Result Dictionary with success status and message
func deserialize(data: Dictionary) -> Dictionary:
	if data == null:
		return {"success": false, "message": "Data is null"}
		
	if typeof(data) != TYPE_DICTIONARY:
		return {"success": false, "message": "Invalid data format, expected Dictionary"}
	
	if not "campaign_name" in data:
		return {"success": false, "message": "Missing required campaign data: campaign_name"}
	
	# Use explicit set to handle validation in property setters
	if "campaign_name" in data:
		campaign_name = data.campaign_name
		
	if "campaign_type" in data:
		campaign_type = data.campaign_type
		
	if "campaign_difficulty" in data:
		campaign_difficulty = data.campaign_difficulty
		
	if "current_phase" in data:
		current_phase = data.current_phase
		
	if "completed_phases" in data:
		completed_phases = data.completed_phases.duplicate() # Use duplicate to avoid reference issues
		
	if "resources" in data:
		resources = data.resources.duplicate() # Use duplicate to avoid reference issues
		
	if "start_date" in data:
		start_date = data.start_date.duplicate() # Use duplicate to avoid reference issues
		
	if "current_date" in data:
		current_date = data.current_date.duplicate() # Use duplicate to avoid reference issues
		
	if "total_days" in data:
		total_days = data.total_days
	
	return {"success": true, "message": "Campaign data deserialized successfully"}