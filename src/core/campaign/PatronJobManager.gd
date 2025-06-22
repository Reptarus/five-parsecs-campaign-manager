@tool
extends RefCounted
class_name PatronJobManager

## Simple patron job manager for Five Parsecs
##
## Handles patron relationships, job offers, and contract management

signal job_offered(patron: Dictionary, job: Dictionary)
signal job_completed(patron: Dictionary, job: Dictionary, success: bool)
signal patron_relationship_changed(patron: Dictionary, new_level: int)

enum PatronRelationship {
	HOSTILE = -2,
	UNFRIENDLY = -1,
	NEUTRAL = 0,
	FRIENDLY = 1,
	ALLIED = 2
}

enum JobType {
	DELIVERY,
	ESCORT,
	INVESTIGATION,
	PATROL,
	SALVAGE,
	BOUNTY
}

var active_patrons: Array[Dictionary] = []
var available_jobs: Array[Dictionary] = []
var completed_jobs: Array[Dictionary] = []

func _init() -> void:
	_initialize_default_patrons()

func _initialize_default_patrons() -> void:
	# Initialize some default patrons
	active_patrons = [
		{
			"name": "Captain Morrison",
			"faction": "Unity Fleet",
			"relationship": PatronRelationship.NEUTRAL,
			"reputation": 50,
			"specialty": JobType.ESCORT
		},
		{
			"name": "Dr. Chen",
			"faction": "Research Consortium",
			"relationship": PatronRelationship.FRIENDLY,
			"reputation": 30,
			"specialty": JobType.INVESTIGATION
		}
	]

## Generate job offers from patrons
func generate_job_offers() -> Array[Dictionary]:
	available_jobs.clear()
	
	for patron in active_patrons:
		if _should_patron_offer_job(patron):
			var job = _create_job_for_patron(patron)
			available_jobs.append(job) # warning: return value discarded (intentional)
			job_offered.emit(patron, job) # warning: return value discarded (intentional)
	
	return available_jobs

## Check if patron should offer a job
func _should_patron_offer_job(patron: Dictionary) -> bool:
	var relationship_bonus = patron.get("relationship", 0) * 0.1
	var base_chance: float = 0.3 + relationship_bonus
	return randf() < base_chance

## Create a job for a specific patron
func _create_job_for_patron(patron: Dictionary) -> Dictionary:
	var job_type = patron.get("specialty", JobType.DELIVERY)
	
	return {
		"id": randi(),
		"patron_name": patron.get("name", "Unknown"),
		"type": job_type,
		"title": _get_job_title(job_type),
		"description": _get_job_description(job_type),
		"payment": randi_range(100, 500),
		"difficulty": randi_range(1, 5),
		"deadline": 10, # turns
		"requirements": _get_job_requirements(job_type)
	}

## Get job title based on type
func _get_job_title(job_type: JobType) -> String:
	match job_type:
		JobType.DELIVERY: return "Urgent Delivery"
		JobType.ESCORT: return "Protection Detail"
		JobType.INVESTIGATION: return "Missing Person"
		JobType.PATROL: return "Sector Patrol"
		JobType.SALVAGE: return "Salvage Operation"
		JobType.BOUNTY: return "Bounty Collection"
		_: return "Contract Work"

## Get job description based on _type
func _get_job_description(job_type: JobType) -> String:
	match job_type:
		JobType.DELIVERY: return "Transport cargo to destination safely."
		JobType.ESCORT: return "Provide protection for client during travel."
		JobType.INVESTIGATION: return "Investigate suspicious activities in the sector."
		JobType.PATROL: return "Patrol designated area and report findings."
		JobType.SALVAGE: return "Recover valuable materials from wreckage."
		JobType.BOUNTY: return "Locate and apprehend wanted individual."
		_: return "Complete assigned objectives."

## Get job requirements based on _type
func _get_job_requirements(job_type: JobType) -> Array[String]:
	match job_type:
		JobType.DELIVERY: return ["Ship with cargo capacity"]
		JobType.ESCORT: return ["Combat-ready crew"]
		JobType.INVESTIGATION: return ["High Savvy crew member"]
		JobType.PATROL: return ["Long-range sensors"]
		JobType.SALVAGE: return ["Salvage equipment"]
		JobType.BOUNTY: return ["Combat expertise"]
		_: return []

## Accept a job
func accept_job(job_id: int) -> bool:
	for job in available_jobs:
		if job.get("_id") == job_id:
			available_jobs.erase(job)
			return true
	return false

## Complete a job
func complete_job(job: Dictionary, success: bool) -> void:
	completed_jobs.append(job) # warning: return value discarded (intentional)
	
	# Find patron and update relationship
	for patron in active_patrons:
		if patron.get("name") == job.get("patron_name"):
			var relationship_change: int = 1 if success else -1
			_update_patron_relationship(patron, relationship_change)
			job_completed.emit(patron, job, success) # warning: return value discarded (intentional)
			break

## Update patron relationship
func _update_patron_relationship(patron: Dictionary, change: int) -> void:
	var current_relationship = patron.get("relationship", PatronRelationship.NEUTRAL)
	var new_relationship = clamp(current_relationship + change,
								PatronRelationship.HOSTILE,
								PatronRelationship.ALLIED)
	patron["relationship"] = new_relationship
	patron_relationship_changed.emit(patron, new_relationship) # warning: return value discarded (intentional)

## Get patron by name
func get_patron(name: String) -> Dictionary:
	for patron in active_patrons:
		if patron.get("name") == name:
			return patron
	return {}

## Add new patron
func add_patron(patron: Dictionary) -> void:
	active_patrons.append(patron) # warning: return value discarded (intentional)

## Get available jobs
func get_available_jobs() -> Array[Dictionary]:
	return available_jobs.duplicate()

## Get patron relationship level name
func get_relationship_name(level: PatronRelationship) -> String:
	match level:
		PatronRelationship.HOSTILE: return "Hostile"
		PatronRelationship.UNFRIENDLY: return "Unfriendly"
		PatronRelationship.NEUTRAL: return "Neutral"
		PatronRelationship.FRIENDLY: return "Friendly"
		PatronRelationship.ALLIED: return "Allied"
		_: return "Unknown"