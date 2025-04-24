@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterManager = preload("res://src/core/character/management/CharacterManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal battle_results_recorded(results: Dictionary)
signal casualties_processed(casualties: Array)
signal rewards_calculated(rewards: Dictionary)
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
		"mission_type": GameEnums.MissionType.NONE,
		"objective": GameEnums.MissionObjective.NONE,
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
	_current_battle.mission_type = mission_data.get("type", GameEnums.MissionType.NONE)
	_current_battle.objective = mission_data.get("objective", GameEnums.MissionObjective.NONE)
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

## Complete the battle with a specific outcome
func complete_battle(outcome: String) -> Dictionary:
	_current_battle.outcome = outcome
	_current_battle.completed = true
	
	# Process outcome-based data
	match outcome:
		OUTCOME_VICTORY:
			_process_victory()
		OUTCOME_DEFEAT:
			_process_defeat()
		OUTCOME_DRAW:
			_process_draw()
		OUTCOME_RETREAT:
			_process_retreat()
	
	# Calculate rewards
	_calculate_rewards()
	
	# Add to battle history
	_battle_history.append(_current_battle.duplicate())
	
	# Emit signal
	battle_results_recorded.emit(_current_battle)
	
	log_battle_event({
		"type": "battle_completed",
		"outcome": outcome,
		"total_enemy_casualties": _current_battle.enemy_casualties.size(),
		"total_player_casualties": _current_battle.player_casualties.size()
	})
	
	return _current_battle

## Process casualties after battle
func process_casualties() -> Array:
	var casualties = []
	
	for casualty in _current_battle.player_casualties:
		var character_id = casualty.get("character_id", "")
		if character_id.is_empty():
			continue
			
		var character = character_manager.get_character(character_id)
		if not character:
			continue
		
		# Determine the detailed injury result based on the Five Parsecs rulebook's tables
		var injury_result = _determine_injury_by_rulebook()
		
		# Apply the result to the character
		match injury_result.get("result", ""):
			"dead":
				# Character died
				character_manager.set_character_status(character, "dead")
				casualties.append({
					"character": character,
					"status": "dead",
					"description": injury_result.get("description", "Killed in battle")
				})
			"critical":
				# Critical injury
				character_manager.set_character_status(character, "critical")
				casualties.append({
					"character": character,
					"status": "critical",
					"description": injury_result.get("description", "Critically injured")
				})
			"injured":
				# Regular injury
				character_manager.set_character_status(character, "injured")
				casualties.append({
					"character": character,
					"status": "injured",
					"description": injury_result.get("description", "Injured in battle"),
					"recovery_time": injury_result.get("recovery_time", 1)
				})
			"recovered":
				# Character recovered without serious injury
				casualties.append({
					"character": character,
					"status": "recovered",
					"description": injury_result.get("description", "Recovered from injuries")
				})
			"miraculous":
				# Miraculous escape (special case in rulebook)
				casualties.append({
					"character": character,
					"status": "miraculous_escape",
					"description": "Miraculous escape from certain death",
					"luck_bonus": injury_result.get("luck_bonus", 1)
				})
	
	casualties_processed.emit(casualties)
	return casualties

## Determine injury details according to the Five Parsecs rulebook tables
func _determine_injury_by_rulebook() -> Dictionary:
	# Roll D100 as per the rulebook
	var roll = randi() % 100 + 1
	
	if roll <= 5:
		# Gruesome Fate / "Dead and gone" result
		return {
			"result": "dead",
			"description": "Gruesome fate - character is dead",
			"recover_chance": 0
		}
	elif roll <= 15:
		# Death or permanent injury (option for cybernetics or special treatment)
		return {
			"result": "dead",
			"description": "Fatal injuries",
			"recover_chance": 10 # Small chance to recover with advanced medical care
		}
	elif roll == 16:
		# Miraculous escape (rulebook special case)
		return {
			"result": "miraculous",
			"description": "Miraculous escape from certain death",
			"luck_bonus": 1
		}
	elif roll <= 30:
		# Critical injury (long recovery time, permanent effect)
		return {
			"result": "critical",
			"description": "Critical injury with lasting effects",
			"recovery_time": 3, # Battles/campaign turns
			"permanent_effect": true
		}
	elif roll <= 60:
		# Serious injury (medium recovery time)
		return {
			"result": "injured",
			"description": "Serious injury requiring recovery",
			"recovery_time": 2 # Battles/campaign turns
		}
	elif roll <= 90:
		# Light injury (short recovery time)
		return {
			"result": "injured",
			"description": "Light injury requiring brief recovery",
			"recovery_time": 1 # Battles/campaign turns
		}
	else:
		# Just a scratch / quick recovery
		return {
			"result": "recovered",
			"description": "Minor scratch, quickly recovered"
		}

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
		if _current_battle.mission_type == GameEnums.MissionType.BLACK_ZONE:
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

## Private implementation methods

func _process_victory() -> void:
	# Additional processing for victory conditions
	pass

func _process_defeat() -> void:
	# Additional processing for defeat conditions
	pass

func _process_draw() -> void:
	# Additional processing for draw conditions
	pass

func _process_retreat() -> void:
	# Additional processing for retreat conditions
	pass

func _calculate_rewards() -> void:
	var reward_data = {}
	
	# Base rewards based on outcome
	match _current_battle.outcome:
		OUTCOME_VICTORY:
			reward_data["credits"] = 100 + randi() % 100
			reward_data["reputation"] = 5
		OUTCOME_DRAW:
			reward_data["credits"] = 50 + randi() % 50
			reward_data["reputation"] = 2
		OUTCOME_DEFEAT:
			reward_data["credits"] = 25
			reward_data["reputation"] = 0
		OUTCOME_RETREAT:
			reward_data["credits"] = 0
			reward_data["reputation"] = -2
			
	# Additional rewards based on mission type
	match _current_battle.mission_type:
		GameEnums.MissionType.BLACK_ZONE:
			reward_data["credits"] += 100
			reward_data["tech_parts"] = 1 + randi() % 3
		GameEnums.MissionType.RESCUE:
			reward_data["credits"] += 50
			reward_data["reputation"] += 3
			
	# Calculate loot drops
	reward_data["loot"] = _generate_battle_loot()
		
	_current_battle.rewards = reward_data
	rewards_calculated.emit(reward_data)
	
## Generate loot items based on battle outcome
func _generate_battle_loot() -> Array:
	var loot_items = []
	
	# Only generate loot for victories or draws
	if _current_battle.outcome == OUTCOME_DEFEAT or _current_battle.outcome == OUTCOME_RETREAT:
		return loot_items
		
	# Chance of finding loot depends on outcome
	var loot_chance = 0.7 if _current_battle.outcome == OUTCOME_VICTORY else 0.3
	
	# Number of loot items depends on enemy casualties
	var enemy_count = _current_battle.enemy_casualties.size()
	var max_items = min(enemy_count / 2, 5) # Cap at 5 items
	
	# Generate random loot
	for i in range(max_items):
		if randf() <= loot_chance:
			# Simplified loot generation - would be more complex in real implementation
			var loot_item = {
				"id": "loot_" + str(randi()),
				"type": ["weapon", "armor", "item"].pick_random(),
				"quality": randi() % 3, # 0=common, 1=uncommon, 2=rare
				"value": 50 + randi() % 200
			}
			loot_items.append(loot_item)
			
	return loot_items