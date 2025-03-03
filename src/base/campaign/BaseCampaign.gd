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

func _init(name: String = "New Campaign") -> void:
	campaign_name = name
	_initialize_resources()
	_initialize_dates()

func _initialize_resources() -> void:
	resources = {
		"credits": 0,
		"reputation": 0,
		"story_points": 0
	}

func _initialize_dates() -> void:
	var current_time = Time.get_datetime_dict_from_system()
	start_date = {
		"year": current_time.year,
		"month": current_time.month,
		"day": current_time.day
	}
	current_date = start_date.duplicate()
	total_days = 0

func start_campaign() -> void:
	campaign_started.emit()
	start_phase(0)

func end_campaign(victory: bool = false) -> void:
	campaign_ended.emit(victory)

func start_phase(phase: int) -> void:
	var old_phase = current_phase
	current_phase = phase
	phase_changed.emit(old_phase, current_phase)
	phase_started.emit(current_phase)

func complete_phase() -> void:
	if not current_phase in completed_phases:
		completed_phases.append(current_phase)
	phase_completed.emit(current_phase)

func advance_time(days: int = 1) -> void:
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

func add_resource(resource_type: String, amount: int) -> void:
	if resources.has(resource_type):
		resources[resource_type] += amount
		resources_changed.emit(resources)
	else:
		push_error("Unknown resource type: " + resource_type)

func remove_resource(resource_type: String, amount: int) -> bool:
	if not resources.has(resource_type):
		push_error("Unknown resource type: " + resource_type)
		return false
		
	if resources[resource_type] < amount:
		return false
		
	resources[resource_type] -= amount
	resources_changed.emit(resources)
	return true

func get_resource(resource_type: String) -> int:
	if resources.has(resource_type):
		return resources[resource_type]
	return 0

func serialize() -> Dictionary:
	var data = {
		"campaign_name": campaign_name,
		"campaign_type": campaign_type,
		"campaign_difficulty": campaign_difficulty,
		"current_phase": current_phase,
		"completed_phases": completed_phases,
		"resources": resources,
		"start_date": start_date,
		"current_date": current_date,
		"total_days": total_days
	}
	return data

func deserialize(data: Dictionary) -> void:
	if data.has("campaign_name"): campaign_name = data.campaign_name
	if data.has("campaign_type"): campaign_type = data.campaign_type
	if data.has("campaign_difficulty"): campaign_difficulty = data.campaign_difficulty
	if data.has("current_phase"): current_phase = data.current_phase
	if data.has("completed_phases"): completed_phases = data.completed_phases
	if data.has("resources"): resources = data.resources
	if data.has("start_date"): start_date = data.start_date
	if data.has("current_date"): current_date = data.current_date
	if data.has("total_days"): total_days = data.total_days