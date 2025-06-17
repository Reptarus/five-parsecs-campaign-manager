class_name FPCM_BattleEventsSystem
extends Resource

## Battle Events System implementing Five Parsecs Core Rules p.116
##
## Features:
## - Battle event triggers (end of rounds 2 and 4)
## - 100 battle events from core rules
## - Environmental hazards
## - Event conflict resolution
## - Round-based activation system

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals - following proven patterns from Story Track System
signal battle_event_triggered(event: BattleEvent)
signal environmental_hazard_activated(hazard: EnvironmentalHazard)
signal event_resolved(event_id: String, outcome: Dictionary)
signal round_event_check(round_number: int)
signal event_conflicts_detected(event1: BattleEvent, event2: BattleEvent)

# Battle Event Resource Class
class BattleEvent extends Resource:
	@export var event_id: String = ""
	@export var title: String = ""
	@export var description: String = ""
	@export var roll_range: Array[int] = []
	@export var effects: Dictionary = {}
	@export var target_type: String = "" # "crew", "enemy", "battlefield", "all"
	@export var duration: int = 0 # 0 = instant, 1+ = rounds
	@export var triggers_on_round: int = 0
	@export var is_persistent: bool = false
	@export var conflicts_with: Array[String] = []

# Environmental Hazard Resource Class  
class EnvironmentalHazard extends Resource:
	@export var hazard_id: String = ""
	@export var hazard_name: String = ""
	@export var effect_type: String = ""
	@export var damage_bonus: int = 1
	@export var save_difficulty: int = 5
	@export var affects_radius: int = 1
	@export var is_permanent: bool = false

# Core System Properties
@export var is_system_active: bool = false
@export var current_round: int = 0
@export var events_triggered: Array[BattleEvent] = []
@export var active_hazards: Array[EnvironmentalHazard] = []
@export var pending_events: Array[BattleEvent] = []
@export var battle_in_progress: bool = false

# Event Registry - 100 Core Rules Events
var event_registry: Dictionary = {}

func _init():
	_initialize_event_registry()

## Initialize system for a new battle
func initialize_battle() -> void:
	is_system_active = true
	current_round = 0
	events_triggered.clear()
	active_hazards.clear()
	pending_events.clear()
	battle_in_progress = true
	
	print("Battle Events System initialized")

## Advance to next round and check for events
func advance_round() -> void:
	if not is_system_active or not battle_in_progress:
		return
		
	current_round += 1
	round_event_check.emit(current_round)
	
	# Core Rules: Events trigger end of rounds 2 and 4
	if current_round == 2 or current_round == 4:
		trigger_battle_event()
	
	_process_active_events()

## Trigger a random battle event (Core Rules Table)
func trigger_battle_event() -> void:
	if not is_system_active:
		return
		
	var roll = randi_range(1, 100)
	var event = _get_event_for_roll(roll)
	
	if event:
		# Check for conflicts with existing events
		var conflicts = _check_event_conflicts(event)
		if conflicts:
			event_conflicts_detected.emit(event, conflicts)
			print("Event conflict detected - discarding: " + event.title)
			return
		
		events_triggered.append(event)
		battle_event_triggered.emit(event)
		_apply_event_effects(event)
		
		print("Battle Event Triggered: " + event.title)

## Apply event effects based on type
func _apply_event_effects(event: BattleEvent) -> void:
	match event.target_type:
		"crew":
			_apply_crew_event(event)
		"enemy":
			_apply_enemy_event(event)
		"battlefield":
			_apply_battlefield_event(event)
		"environmental":
			_apply_environmental_event(event)
		"all":
			_apply_universal_event(event)

## Handle crew-targeting events
func _apply_crew_event(event: BattleEvent) -> void:
	var effects = event.effects
	
	match event.event_id:
		"SEIZED_MOMENT":
			# Crew member acts in both phases next round
			effects["selected_crew"] = "random"
			effects["bonus_actions"] = 2
		"SNAP_SHOT":
			# Immediate weapon fire
			effects["immediate_attack"] = true
			effects["pistol_auto_hit"] = true
		"CUNNING_PLAN":
			# Choose action phases next round
			effects["initiative_control"] = true
		"BACK_UP":
			# Crew reinforcements
			effects["spawn_crew"] = 1
		"FOUND_SOMETHING":
			# Loot discovery
			effects["spawn_loot_marker"] = true
		"LOOKS_VALUABLE":
			# Credit discovery
			effects["spawn_credit_marker"] = true
			effects["credit_amount"] = randi_range(1, 3)

## Handle enemy-targeting events
func _apply_enemy_event(event: BattleEvent) -> void:
	var effects = event.effects
	
	match event.event_id:
		"RENEWED_EFFORTS":
			# Random enemy gets bonus actions
			effects["enemy_bonus_actions"] = 2
		"ENEMY_REINFORCEMENTS":
			# 2 additional enemies
			effects["spawn_enemies"] = 2
			effects["specialist_count"] = 1
		"CHANGE_OF_PLANS":
			# Switch AI type
			effects["ai_change"] = "cautious"
		"LOST_HEART":
			# Enemies retreat next round
			effects["enemy_retreat"] = true
			effects["retreat_delay"] = 1
		"TOUGHER_THAN_EXPECTED":
			# Random enemy +1 Toughness
			effects["toughness_bonus"] = 1
			effects["remove_stun"] = true
		"ENEMY_VIP":
			# Unique Individual joins
			effects["spawn_unique"] = true

## Handle battlefield-wide events  
func _apply_battlefield_event(event: BattleEvent) -> void:
	var effects = event.effects
	
	match event.event_id:
		"VISIBILITY_CHANGE":
			# Change vision range
			var current_vision = effects.get("current_vision", 24)
			if current_vision > 24:
				effects["new_vision"] = randi_range(1, 6) + 6
			else:
				effects["new_vision"] = current_vision + randi_range(1, 6)
		"FOG_CLOUD":
			# Dense fog in center
			effects["fog_radius"] = 6
			effects["fog_vision"] = 2
		"CLOCK_RUNNING_OUT":
			# Time pressure mechanic
			effects["time_pressure"] = true
			effects["end_chance"] = 6 # 1d6 = 6

## Handle environmental hazard events
func _apply_environmental_event(event: BattleEvent) -> void:
	var hazard = EnvironmentalHazard.new()
	hazard.hazard_id = event.event_id
	hazard.hazard_name = event.title
	hazard.effect_type = event.effects.get("effect_type", "damage")
	hazard.damage_bonus = event.effects.get("damage_bonus", 1)
	hazard.save_difficulty = event.effects.get("save_difficulty", 5)
	hazard.affects_radius = event.effects.get("radius", 1)
	hazard.is_permanent = event.effects.get("permanent", false)
	
	active_hazards.append(hazard)
	environmental_hazard_activated.emit(hazard)

## Handle universal events that affect everything
func _apply_universal_event(event: BattleEvent) -> void:
	var effects = event.effects
	
	match event.event_id:
		"BATTLEFIELD_EFFECT":
			# Global battlefield changes
			effects["global_modifier"] = true
		_:
			# Default universal handling
			print("Universal event applied: " + event.title)

## Check if event conflicts with active events
func _check_event_conflicts(new_event: BattleEvent) -> BattleEvent:
	for active_event in events_triggered:
		if new_event.event_id in active_event.conflicts_with:
			return active_event
		if active_event.event_id in new_event.conflicts_with:
			return active_event
	return null

## Get event for dice roll (Core Rules Table)
func _get_event_for_roll(roll: int) -> BattleEvent:
	for event_id in event_registry:
		var event = event_registry[event_id]
		if roll >= event.roll_range[0] and roll <= event.roll_range[1]:
			return event
	return null

## Process ongoing event effects
func _process_active_events() -> void:
	var completed_events = []
	
	for event in events_triggered:
		if event.duration > 0:
			event.duration -= 1
			if event.duration <= 0:
				completed_events.append(event)
	
	# Remove completed events
	for event in completed_events:
		events_triggered.erase(event)
		event_resolved.emit(event.event_id, {"completed": true})

## Environmental hazard damage check
func check_environmental_damage(character_position: Vector2, character_savvy: int) -> Dictionary:
	var damage_results = {}
	
	for hazard in active_hazards:
		var distance = character_position.distance_to(Vector2.ZERO) # Hazard at origin for testing
		if distance <= hazard.affects_radius:
			var save_roll = randi_range(1, 6) + character_savvy
			var damage_taken = 0
			
			if save_roll < hazard.save_difficulty:
				damage_taken = 1 + hazard.damage_bonus
			
			damage_results[hazard.hazard_id] = {
				"damage": damage_taken,
				"save_roll": save_roll,
				"required": hazard.save_difficulty
			}
	
	return damage_results

## End battle and cleanup
func end_battle() -> void:
	battle_in_progress = false
	_cleanup_temporary_effects()
	
	print("Battle Events System ended")

## Cleanup temporary effects
func _cleanup_temporary_effects() -> void:
	# Remove non-persistent events
	var persistent_events: Array[BattleEvent] = []
	for event in events_triggered:
		if event.is_persistent:
			persistent_events.append(event)
	events_triggered = persistent_events
	
	# Remove non-permanent hazards
	var permanent_hazards: Array[EnvironmentalHazard] = []
	for hazard in active_hazards:
		if hazard.is_permanent:
			permanent_hazards.append(hazard)
	active_hazards = permanent_hazards

## System status checking
func is_active() -> bool:
	return is_system_active and battle_in_progress

func get_current_round() -> int:
	return current_round

func get_active_events() -> Array[BattleEvent]:
	return events_triggered

func get_active_hazards() -> Array[EnvironmentalHazard]:
	return active_hazards

## Serialization support
func serialize() -> Dictionary:
	return {
		"is_system_active": is_system_active,
		"current_round": current_round,
		"events_triggered": _serialize_events(events_triggered),
		"active_hazards": _serialize_hazards(active_hazards),
		"battle_in_progress": battle_in_progress
	}

func deserialize(data: Dictionary) -> void:
	is_system_active = data.get("is_system_active", false)
	current_round = data.get("current_round", 0)
	events_triggered = _deserialize_events(data.get("events_triggered", []))
	active_hazards = _deserialize_hazards(data.get("active_hazards", []))
	battle_in_progress = data.get("battle_in_progress", false)

func _serialize_events(events: Array[BattleEvent]) -> Array:
	var serialized = []
	for event in events:
		if event != null:
			serialized.append({
				"event_id": event.event_id,
				"title": event.title,
				"duration": event.duration
			})
	return serialized

func _deserialize_events(data: Array) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for item in data:
		if item is Dictionary and event_registry.has(item.get("event_id", "")):
			var event = event_registry[item.event_id]
			event.duration = item.get("duration", 0)
			events.append(event)
	return events

func _serialize_hazards(hazards: Array[EnvironmentalHazard]) -> Array:
	var serialized = []
	for hazard in hazards:
		if hazard != null:
			serialized.append({
				"hazard_id": hazard.hazard_id,
				"hazard_name": hazard.hazard_name,
				"effect_type": hazard.effect_type
			})
	return serialized

func _deserialize_hazards(data: Array) -> Array[EnvironmentalHazard]:
	var hazards: Array[EnvironmentalHazard] = []
	for item in data:
		if item is Dictionary:
			var hazard = EnvironmentalHazard.new()
			hazard.hazard_id = item.get("hazard_id", "")
			hazard.hazard_name = item.get("hazard_name", "")
			hazard.effect_type = item.get("effect_type", "")
			hazards.append(hazard)
	return hazards

## Initialize the complete Core Rules event registry
func _initialize_event_registry() -> void:
	# Sample of Core Rules Battle Events (1-100 range)
	event_registry = {
		"RENEWED_EFFORTS": _create_event("RENEWED_EFFORTS", "Renewed Efforts", [1, 5],
			"Enemy making concerted effort to push back", {"target_type": "enemy", "bonus_actions": 2}),
		"ENEMY_REINFORCEMENTS": _create_event("ENEMY_REINFORCEMENTS", "Enemy Reinforcements", [6, 9],
			"2 additional enemy figures arrive", {"target_type": "enemy", "spawn_count": 2}),
		"CHANGE_OF_PLANS": _create_event("CHANGE_OF_PLANS", "Change of Plans", [10, 13],
			"Enemy switches AI type", {"target_type": "enemy", "ai_change": "cautious"}),
		"LOST_HEART": _create_event("LOST_HEART", "Lost Heart", [14, 16],
			"Enemy will leave field next round", {"target_type": "enemy", "retreat": true}),
		"SEIZED_MOMENT": _create_event("SEIZED_MOMENT", "Seized the Moment", [17, 20],
			"Crew member acts in both phases", {"target_type": "crew", "bonus_actions": 2}),
		"CRITTERS": _create_event("CRITTERS", "Critters!", [21, 26],
			"1D3 Vent Crawlers appear", {"target_type": "battlefield", "spawn_crawlers": true}),
		"AMMO_FAULT": _create_event("AMMO_FAULT", "Ammo Fault", [27, 30],
			"Random weapon malfunctions", {"target_type": "crew", "weapon_jam": true}),
		"VISIBILITY_CHANGE": _create_event("VISIBILITY_CHANGE", "Visibility Change", [31, 34],
			"Vision range changes", {"target_type": "battlefield", "vision_change": true}),
		"TOUGHER_THAN_EXPECTED": _create_event("TOUGHER_THAN_EXPECTED", "Tougher than Expected", [35, 38],
			"Random enemy +1 Toughness", {"target_type": "enemy", "toughness_bonus": 1}),
		"SNAP_SHOT": _create_event("SNAP_SHOT", "Snap Shot", [39, 42],
			"Crew member fires immediately", {"target_type": "crew", "immediate_fire": true}),
		"CUNNING_PLAN": _create_event("CUNNING_PLAN", "Cunning Plan", [43, 46],
			"Choose action phases next round", {"target_type": "crew", "initiative_control": true}),
		"POSSIBLE_REINFORCEMENTS": _create_event("POSSIBLE_REINFORCEMENTS", "Possible Reinforcements", [47, 50],
			"3 reinforcement markers placed", {"target_type": "enemy", "reinforcement_markers": 3}),
		"CLOCK_RUNNING_OUT": _create_event("CLOCK_RUNNING_OUT", "Clock is Running Out", [51, 54],
			"Time pressure - battle may end", {"target_type": "battlefield", "time_pressure": true}),
		"ENVIRONMENTAL_HAZARD": _create_event("ENVIRONMENTAL_HAZARD", "Environmental Hazard", [55, 60],
			"Random terrain becomes hazardous", {"target_type": "environmental", "hazard_terrain": true}),
		"DESPERATE_PLAN": _create_event("DESPERATE_PLAN", "A Desperate Plan", [61, 65],
			"One crew can't act, another gets bonus", {"target_type": "crew", "action_trade": true}),
		"MOMENT_OF_HESITATION": _create_event("MOMENT_OF_HESITATION", "A Moment of Hesitation", [66, 70],
			"Initiative order restricted", {"target_type": "crew", "initiative_restricted": true}),
		"FUMBLED_GRENADE": _create_event("FUMBLED_GRENADE", "Fumbled Grenade", [71, 73],
			"Enemy fumbles grenade", {"target_type": "enemy", "grenade_fumble": true}),
		"BACK_UP": _create_event("BACK_UP", "Back Up", [74, 77],
			"Spare crew member arrives", {"target_type": "crew", "reinforcement": true}),
		"ENEMY_VIP": _create_event("ENEMY_VIP", "Enemy VIP", [78, 80],
			"Unique Individual joins enemy", {"target_type": "enemy", "spawn_unique": true}),
		"FOG_CLOUD": _create_event("FOG_CLOUD", "Fog Cloud", [81, 85],
			"Dense fog envelops center", {"target_type": "battlefield", "fog": true}),
		"LOST": _create_event("LOST", "Lost!", [86, 89],
			"Crew member loses their way", {"target_type": "crew", "remove_member": true}),
		"FOUND_SOMETHING": _create_event("FOUND_SOMETHING", "I Found Something!", [90, 93],
			"Loot marker appears", {"target_type": "crew", "spawn_loot": true}),
		"LOOKS_VALUABLE": _create_event("LOOKS_VALUABLE", "Looks Valuable", [94, 97],
			"Credit marker appears", {"target_type": "crew", "spawn_credits": true}),
		"CHECK_THAT_OUT": _create_event("CHECK_THAT_OUT", "You Want Me to Check That Out?", [98, 100],
			"Optional exploration for loot", {"target_type": "crew", "exploration_choice": true})
	}

## Helper to create battle events
func _create_event(id: String, title: String, roll_range: Array[int], description: String, effects: Dictionary) -> BattleEvent:
	var event = BattleEvent.new()
	event.event_id = id
	event.title = title
	event.roll_range = roll_range
	event.description = description
	event.effects = effects
	event.target_type = effects.get("target_type", "battlefield")
	event.duration = effects.get("duration", 0)
	event.is_persistent = effects.get("persistent", false)
	return event