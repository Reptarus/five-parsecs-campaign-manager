@tool
extends Node
const CharacterManager = preload("res://src/core/character/Management/CharacterManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal battle_log_updated(log_entry: Dictionary)

var character_manager
var game_state: FiveParsecsGameState

# Battle result data
var _current_battle: Dictionary = {}
var _battle_history: Array[Dictionary] = []
var _current_battle_log: Array[Dictionary] = []

# Constants for battle outcomes
const OUTCOME_VICTORY = "victory"
const OUTCOME_DEFEAT = "defeat"
const OUTCOME_DRAW = "draw"
const OUTCOME_RETREAT = "retreat"

func _init() -> void:
	pass

func _ready() -> void:
	reset_current_battle()

func setup(state: FiveParsecsGameState, char_manager) -> void:
	game_state = state
	character_manager = char_manager

func reset_current_battle() -> void:
	_current_battle = {
		"id": "",
		"mission_id": "",
		"mission_type": GlobalEnums.MissionType.NONE,
		"objective": GlobalEnums.MissionObjective.NONE,
		"planet": "",
		"turn": 0,
		"outcome": "",
		"player_casualties": [],
		"enemy_casualties": [],
		"rewards": {},
		"special_events": [],
		"completed": false,
		"timestamp": 0
	}
	_current_battle_log.clear()

## Initialize a new battle record
func start_battle(mission_data: Dictionary) -> void:
	reset_current_battle()
	
	_current_battle.id = "battle_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	_current_battle.mission_id = mission_data.get("id", "")
	_current_battle.mission_type = mission_data.get("type", GlobalEnums.MissionType.NONE)
	_current_battle.objective = mission_data.get("objective", GlobalEnums.MissionObjective.NONE)
	_current_battle.planet = mission_data.get("planet", "")
	_current_battle.turn = game_state.turn_number
	_current_battle.timestamp = Time.get_unix_time_from_system()
	
	log_battle_event({
		"type": "battle_started",
		"mission": mission_data.get("name", "Unknown Mission"),
		"location": _current_battle.planet
	})

## Record a character casualty during battle
func record_casualty(character, damage: int, is_critical: bool, is_enemy: bool = false) -> void:
	if is_enemy:
		var enemy_data = {
			"id": character.get("id", ""),
			"type": character.get("type", ""),
			"damage": damage,
			"is_critical": is_critical,
			"is_killed": damage >= character.get("toughness", 1) * 2
		}
		_current_battle.enemy_casualties.append(enemy_data)
		
		log_battle_event({
			"type": "enemy_casualty",
			"enemy_type": enemy_data.type,
			"is_killed": enemy_data.is_killed,
			"damage": damage
		})
	else:
		# Player character casualty
		var injury_data = character_manager.apply_battle_damage(character, damage, is_critical)
		var casualty_data = {
			"character_id": character.get("id", ""),
			"name": character.get("name", "Unknown"),
			"damage": damage,
			"is_critical": is_critical,
			"survived": injury_data.get("survived", true),
			"injury_type": injury_data.get("injury_type", "minor")
		}
		_current_battle.player_casualties.append(casualty_data)
		
		log_battle_event({
			"type": "player_casualty",
			"character_name": casualty_data.name,
			"survived": casualty_data.survived,
			"injury_type": casualty_data.injury_type,
			"damage": damage
		})

## Record a special event that occurred during battle
func record_special_event(event_type: String, event_data: Dictionary) -> void:
	var event = event_data.duplicate()
	event["type"] = event_type
	event["turn"] = _current_battle.get("current_turn", 0)
	
	_current_battle.special_events.append(event)
	
	log_battle_event({
		"type": "special_event",
		"event_type": event_type,
		"description": event_data.get("description", "")
	})

# NOTE (2026-06-02 dead-code cleanup): complete_battle(), process_casualties(),
# _determine_injury_by_rulebook() and the battle_results_recorded / casualties_processed /
# rewards_calculated signals were REMOVED. The whole chain was dead: its only entry point,
# GameSystemManager.process_battle_results(), had zero callers (GameSystemManager is itself
# uninstantiated). Live post-battle resolution runs through PostBattlePhase and its processors
# (LootProcessor / InjuryProcessor / ExperienceTrainingProcessor). The state-recording API
# (start_battle / record_casualty / log_battle_event / get_*) is retained.

## Calculate experience for characters based on battle outcome according to the Five Parsecs rulebook
func calculate_experience() -> Dictionary:
	var experience_data = {}
	
	# Get all active characters
	var characters = character_manager.get_active_characters()
	for character in characters:
		var char_id = character.get("id", "")
		if char_id.is_empty():
			continue
		
		# 1. Base XP for participating in battle (rulebook: each character gets XP for participating)
		var base_xp = 1
		
		# 2. XP for holding the field - Five Parsecs rulebook awards 1 XP if the crew holds the field
		var held_field_xp = 1 if _current_battle.outcome == OUTCOME_VICTORY else 0
		
		# 3. XP for Black Zone Missions - Five Parsecs rulebook awards 1 XP for Black Zone missions
		var black_zone_xp = 0
		if _current_battle.mission_type == GlobalEnums.MissionType.BLACK_ZONE:
			black_zone_xp = 1
		
		# 4. XP for leading combat (assuming the "Main Character" led the combat)
		var leader_xp = 0
		if character.get("is_main_character", false):
			leader_xp = 1
		
		# 5. Check if character was injured (gets 1 XP for surviving injury according to the rulebook)
		var survival_xp = 0
		for casualty in _current_battle.player_casualties:
			if casualty.get("character_id", "") == char_id and casualty.get("survived", true):
				survival_xp = 1
				break
		
		# 6. XP for enemy casualties (handled by mission objectives, not direct XP in the rulebook)
		
		# Calculate total XP for this character
		var total_xp = base_xp + held_field_xp + black_zone_xp + leader_xp + survival_xp
		
		# Store experience for this character
		experience_data[char_id] = {
			"character": character,
			"base_xp": base_xp,
			"held_field_xp": held_field_xp,
			"black_zone_xp": black_zone_xp,
			"leader_xp": leader_xp,
			"survival_xp": survival_xp,
			"total": total_xp
		}
	
	return experience_data

## Apply calculated experience to characters
func apply_experience(experience_data: Dictionary) -> void:
	for char_id in experience_data:
		var data = experience_data[char_id]
		var character = data["character"]
		var xp_amount = data["total"]
		
		character_manager.process_advancement(character, xp_amount)

## Log an event to the battle log
func log_battle_event(event: Dictionary) -> void:
	var log_entry = event.duplicate()
	log_entry["timestamp"] = Time.get_unix_time_from_system()
	
	_current_battle_log.append(log_entry)
	battle_log_updated.emit(log_entry)

## Get the battle log
func get_battle_log() -> Array:
	return _current_battle_log.duplicate()

## Get battle history
func get_battle_history() -> Array:
	return _battle_history.duplicate()

## Get specific battle from history
func get_battle(battle_id: String) -> Dictionary:
	for battle in _battle_history:
		if battle.get("id", "") == battle_id:
			return battle
	return {}

## Get current active battle data
func get_current_battle() -> Dictionary:
	return _current_battle.duplicate()

# NOTE (2026-06-02 dead-code cleanup): _process_victory/_process_defeat/_process_draw/
# _process_retreat() stubs and _calculate_rewards() + its res://data/battle_rewards.json
# loader (_ensure_br_loaded / _br_data) were REMOVED with complete_battle() (their only
# caller). battle_rewards.json had no other consumer and was deleted.
