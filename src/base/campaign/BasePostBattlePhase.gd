@tool
extends Resource

signal post_battle_phase_started
signal post_battle_phase_completed
signal rewards_calculated(rewards: Dictionary)
signal rewards_distributed
signal casualties_processed
signal experience_awarded

var battle_result: Dictionary = {}
var rewards: Dictionary = {}
var casualties: Array = []
var experience_gains: Dictionary = {}

func _init() -> void:
	pass

func start_post_battle_phase(result: Dictionary) -> void:
	battle_result = result
	post_battle_phase_started.emit()
	
	calculate_rewards()
	process_casualties()
	award_experience()

func complete_post_battle_phase() -> void:
	post_battle_phase_completed.emit()

func calculate_rewards() -> void:
	# Base implementation - override in derived classes
	rewards = {
		"credits": 0,
		"items": [],
		"resources": {}
	}
	
	rewards_calculated.emit(rewards)

func distribute_rewards() -> void:
	# Base implementation - override in derived classes
	rewards_distributed.emit()

func process_casualties() -> void:
	# Base implementation - override in derived classes
	casualties = []
	casualties_processed.emit()

func award_experience() -> void:
	# Base implementation - override in derived classes
	experience_gains = {}
	experience_awarded.emit()

func get_victory_status() -> bool:
	if battle_result.has("victory"):
		return battle_result.victory
	return false

func get_battle_summary() -> Dictionary:
	return {
		"victory": get_victory_status(),
		"rewards": rewards,
		"casualties": casualties,
		"experience": experience_gains
	}

func reset() -> void:
	battle_result = {}
	rewards = {}
	casualties = []
	experience_gains = {}

func serialize() -> Dictionary:
	return {
		"battle_result": battle_result,
		"rewards": rewards,
		"casualties": casualties,
		"experience_gains": experience_gains
	}

func deserialize(data: Dictionary) -> void:
	if data.has("battle_result"):
		battle_result = data.battle_result
	
	if data.has("rewards"):
		rewards = data.rewards
	
	if data.has("casualties"):
		casualties = data.casualties
	
	if data.has("experience_gains"):
		experience_gains = data.experience_gains