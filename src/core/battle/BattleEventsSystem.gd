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
# GlobalEnums available as autoload singleton

# Signals - following proven patterns from Story Track System
signal battle_event_triggered(event: BattleEvent)
signal environmental_hazard_activated(hazard: EnvironmentalHazard)
signal event_resolved(event_id: String, outcome: Dictionary)
signal round_event_check(round_number: int)
signal event_conflicts_detected(event1: BattleEvent, event2: BattleEvent)
signal terrain_effect_triggered(effect: Dictionary)
## effect = {type: "fog"|"hazard"|"reinforcement_marker", center: Vector2,
##           radius: float, label: String, duration_rounds: int}

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

# Battle event constants (Core Rules p.116)
const EVENT_TRIGGER_ROUND_1 := 2  # First event check at end of round 2
const EVENT_TRIGGER_ROUND_2 := 4  # Second event check at end of round 4
const EVENT_ROLL_MIN := 1
const EVENT_ROLL_MAX := 100  # d100 table
const MAX_ENEMY_TOUGHNESS := 6  # Toughness cap for event buffs
const REINFORCEMENT_SPAWN_COUNT := 2  # Standard reinforcement count
const REINFORCEMENT_MARKERS_COUNT := 3  # Possible reinforcement markers
const REINFORCEMENT_SPAWN_THRESHOLD := [5, 6]  # Rolls that spawn reinforcements
const FUMBLED_GRENADE_RUN_DISTANCE := 6  # inches
const FUMBLED_GRENADE_SCATTER_RADIUS := 4  # inches
const FOG_RADIUS := 6  # inches from center
const FOG_VISION_LIMIT := 2  # max visibility in fog (inches)
const UNLIMITED_VISION_THRESHOLD := 24  # Above this = unlimited visibility
const VISION_REDUCTION_BASE := 6  # 1d6 + this for reduced visibility
const HAZARD_RADIUS := 1  # inches
const CLOCK_END_ROLL := 6  # Roll this on d6 to end battle

# Core System Properties
@export var is_system_active: bool = false
@export var current_round: int = 0
@export var events_triggered: Array[BattleEvent] = []
@export var active_hazards: Array[EnvironmentalHazard] = []
@export var pending_events: Array[BattleEvent] = []
@export var battle_in_progress: bool = false

# Event Registry - 100 Core Rules Events
var event_registry: Dictionary = {}

func _init() -> void:
	if not _load_events_from_json():
		push_error("BattleEventsSystem: Failed to load event_tables.json — battle events will be empty")

## Load battle events from event_tables.json (Core Rules pp.116-117)
func _load_events_from_json() -> bool:
	var path := "res://data/event_tables.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("BattleEventsSystem: Failed to parse event_tables.json")
		return false
	file.close()

	var data: Variant = json.get_data()
	if not data is Dictionary:
		return false

	var battle_section: Dictionary = data.get("battle_events", {})
	var entries: Array = battle_section.get("entries", [])
	if entries.is_empty():
		return false

	event_registry.clear()
	for entry in entries:
		if not entry is Dictionary or not entry.has("roll_range"):
			continue
		var name_str: String = entry.get("name", "Unknown")
		var event_id: String = name_str.to_upper().replace(" ", "_").replace("!", "").replace("'", "").replace("?", "").replace(".", "")
		var effect_str: String = entry.get("effect", "")
		var roll_range: Array = entry.get("roll_range", [1, 1])

		# Infer target_type from event content
		var target_type := "battlefield"
		var effect_lower := effect_str.to_lower()
		if "crew" in effect_lower or "your" in effect_lower:
			target_type = "crew"
		elif "enemy" in effect_lower:
			target_type = "enemy"

		event_registry[event_id] = _create_event(
			event_id, name_str, roll_range, effect_str,
			{"target_type": target_type}
		)

	return event_registry.size() > 0

## Initialize system for a new battle
func initialize_battle() -> void:
	is_system_active = true
	current_round = 0
	events_triggered.clear()
	active_hazards.clear()
	pending_events.clear()
	battle_in_progress = true


## Advance to next round and check for events
func advance_round() -> void:
	if not is_system_active or not battle_in_progress:
		return

	current_round += 1
	round_event_check.emit(current_round)

	# Core Rules: Events trigger end of rounds 2 and 4
	if current_round == EVENT_TRIGGER_ROUND_1 or current_round == EVENT_TRIGGER_ROUND_2:
		trigger_battle_event()

	_process_active_events()

## Trigger a random battle event (Core Rules Table)
func trigger_battle_event() -> void:
	if not is_system_active:
		return

	var roll = randi_range(EVENT_ROLL_MIN, EVENT_ROLL_MAX)
	var event: Variant = _get_event_for_roll(roll)

	if event:
		# Check for conflicts with existing events
		var conflicts = _check_event_conflicts(event)
		if conflicts:
			event_conflicts_detected.emit(event, conflicts)
			return

		events_triggered.append(event)
		battle_event_triggered.emit(event)
		_apply_event_effects(event)


## Apply event effects based on type
func _apply_event_effects(_event: BattleEvent) -> void:
	match _event.target_type:
		"crew":
			_apply_crew_event(_event)
		"enemy":
			_apply_enemy_event(_event)
		"battlefield":
			_apply_battlefield_event(_event)
		"environmental":
			_apply_environmental_event(_event)
		"all":
			_apply_universal_event(_event)

## Handle crew-targeting events
func _apply_crew_event(_event: BattleEvent) -> void:
	var effects = _event.effects

	match _event.event_id:
		"SEIZED_MOMENT":
			# Crew member acts in both phases next round
			effects["selected_crew"] = "random"
			effects["bonus_actions"] = 2
			effects["phases"] = ["quick", "slow"]
		"SNAP_SHOT":
			# Immediate weapon fire - pistol auto-hits
			effects["immediate_attack"] = true
			effects["pistol_auto_hit"] = true
			effects["selected_crew"] = "player_choice"
		"CUNNING_PLAN":
			# Choose action phases next round - no initiative roll
			effects["initiative_control"] = true
			effects["skip_initiative_roll"] = true
		"BACK_UP":
			# Spare crew member arrives at center of your edge
			effects["spawn_crew"] = 1
			effects["spawn_location"] = "player_edge_center"
			effects["requires_spare_crew"] = true
		"FOUND_SOMETHING":
			# Loot marker 1D6" from random crew in random direction
			effects["spawn_loot_marker"] = true
			effects["marker_distance"] = "1d6"
			effects["requires_action"] = true
		"LOOKS_VALUABLE":
			# Credit marker 1D6" from random crew
			effects["spawn_credit_marker"] = true
			effects["credit_amount"] = randi_range(1, 3)
			effects["marker_distance"] = "1d6"
			effects["requires_action"] = true
		"AMMO_FAULT":
			# Random crew weapon malfunctions
			effects["selected_crew"] = "random"
			effects["weapon_disabled"] = true
			effects["fired_last_round_check"] = true
		"DESPERATE_PLAN":
			# One crew can't act, another gets both phases
			effects["disabled_crew"] = "random"
			effects["bonus_crew"] = "player_choice"
			effects["bonus_actions"] = 2
		"MOMENT_OF_HESITATION":
			# Only one figure in Quick Actions, rest in Slow
			effects["quick_actions_limit"] = 1
			effects["feral_priority"] = true
		"LOST":
			# Random crew removed from battle (returns safely after)
			effects["selected_crew"] = "random"
			effects["remove_from_battle"] = true
			effects["returns_after_battle"] = true
			effects["ignore_if_outnumbered"] = true
		"CHECK_THAT_OUT":
			# Optional: crew leaves for post-battle loot roll
			effects["selected_crew"] = "random"
			effects["optional_removal"] = true
			effects["post_battle_loot_roll"] = true

## Handle enemy-targeting events
func _apply_enemy_event(_event: BattleEvent) -> void:
	var effects = _event.effects

	match _event.event_id:
		"RENEWED_EFFORTS":
			# After all enemies act, one random gets second Move + Combat Action
			effects["selected_enemy"] = "random"
			effects["bonus_move"] = true
			effects["bonus_combat"] = true
			effects["duration"] = "rest_of_battle"
		"ENEMY_REINFORCEMENTS":
			# 2 enemies at center of opposing edge, one is Specialist
			effects["spawn_enemies"] = REINFORCEMENT_SPAWN_COUNT
			effects["specialist_count"] = 1
			effects["spawn_location"] = "enemy_edge_center"
		"CHANGE_OF_PLANS":
			# Switch to Cautious AI (or Tactical if already Cautious)
			effects["ai_change"] = "cautious"
			effects["if_cautious"] = "tactical"
			effects["ignore_no_ranged"] = true
		"LOST_HEART":
			# Enemies leave field at end of next round
			effects["enemy_retreat"] = true
			effects["retreat_delay"] = 1
		"TOUGHER_THAN_EXPECTED":
			# Random enemy +1 Toughness (max 6), remove all stun
			effects["selected_enemy"] = "random"
			effects["toughness_bonus"] = 1
			effects["max_toughness"] = MAX_ENEMY_TOUGHNESS
			effects["remove_all_stun"] = true
		"ENEMY_VIP":
			# Unique Individual joins at center of enemy edge
			effects["spawn_unique"] = true
			effects["spawn_location"] = "enemy_edge_center"
		"POSSIBLE_REINFORCEMENTS":
			# 3 markers along enemy edge, roll 5-6 each round for spawn
			effects["reinforcement_markers"] = REINFORCEMENT_MARKERS_COUNT
			effects["spawn_on_roll"] = REINFORCEMENT_SPAWN_THRESHOLD
			effects["remove_within_3"] = true
		"CRITTERS":
			# 1D3 Vent Crawlers in center, move 1D6" random direction
			effects["spawn_crawlers"] = randi_range(1, 3)
			effects["spawn_location"] = "table_center"
			effects["scatter_distance"] = "1d6"
			effects["attacks_nearest"] = true
		"FUMBLED_GRENADE":
			# Random enemy runs 6" random, stunned, others flee 4"
			effects["selected_enemy"] = "random"
			effects["run_distance"] = FUMBLED_GRENADE_RUN_DISTANCE
			effects["apply_stun"] = true
			effects["scatter_radius"] = FUMBLED_GRENADE_SCATTER_RADIUS
			effects["ignore_no_grenades"] = true

## Handle battlefield-wide events
func _apply_battlefield_event(_event: BattleEvent) -> void:
	var effects = _event.effects

	match _event.event_id:
		"VISIBILITY_CHANGE":
			# If unlimited: reduce to 1D6+6", if reduced: increase by +1D6"
			var current_vision = effects.get("current_vision", UNLIMITED_VISION_THRESHOLD)
			if current_vision > UNLIMITED_VISION_THRESHOLD:
				effects["new_vision"] = randi_range(1, 6) + VISION_REDUCTION_BASE
			else:
				effects["new_vision"] = current_vision + randi_range(1, 6)
		"FOG_CLOUD":
			# Dense fog 6" radius from center, blocks visibility past 2"
			effects["fog_radius"] = FOG_RADIUS
			effects["fog_vision_limit"] = FOG_VISION_LIMIT
			effects["fog_location"] = "table_center"
			effects["duration"] = "rest_of_battle"
		"CLOCK_RUNNING_OUT":
			# Roll 1D6 end of each round, 6 = game ends, no objectives
			effects["time_pressure"] = true
			effects["end_on_roll"] = CLOCK_END_ROLL
			effects["no_hold_field_unless_cleared"] = true
		"ENVIRONMENTAL_HAZARD":
			# Random terrain: figures within 1" roll Savvy 5+ or Damage +1
			effects["terrain_selection"] = "random"
			effects["hazard_radius"] = HAZARD_RADIUS
			effects["crew_save"] = "savvy_5plus"
			effects["enemy_save"] = "4plus"
			effects["damage"] = 1
			effects["ignore_armor"] = true
			effects["one_time_only"] = true

## Handle environmental hazard events
func _apply_environmental_event(_event: BattleEvent) -> void:
	var hazard := EnvironmentalHazard.new()
	hazard.hazard_id = _event.event_id
	hazard.hazard_name = _event.title
	hazard.effect_type = _event.effects.get("effect_type", "damage")
	hazard.damage_bonus = _event.effects.get("damage_bonus", 1)
	hazard.save_difficulty = _event.effects.get("save_difficulty", 5)
	hazard.affects_radius = _event.effects.get("radius", 1)
	hazard.is_permanent = _event.effects.get("permanent", false)

	active_hazards.append(hazard)
	environmental_hazard_activated.emit(hazard)

## Handle universal events that affect everything
func _apply_universal_event(_event: BattleEvent) -> void:
	var effects = _event.effects

	match _event.event_id:
		"BATTLEFIELD_EFFECT":
			# Global battlefield changes
			effects["global_modifier"] = true
		_:
			# Default universal handling
			pass

## Check if event conflicts with active events
func _check_event_conflicts(new_event: BattleEvent) -> BattleEvent:
	for active_event in events_triggered:
		var typed_active_event: Variant = active_event
		if new_event.event_id in active_event.conflicts_with:
			return active_event
		if active_event.event_id in new_event.conflicts_with:
			return active_event
	return null

## Get _event for dice roll (Core Rules Table)
func _get_event_for_roll(roll: int) -> BattleEvent:
	for event_id in event_registry:
		var typed_event_id: Variant = event_id
		var event: Variant = event_registry[event_id]
		var range_arr: Array = event.roll_range
		if range_arr.size() >= 2 and roll >= int(range_arr[0]) and roll <= int(range_arr[1]):
			return event
	return null

## Process ongoing event effects
func _process_active_events() -> void:
	var completed_events: Array = []

	for event in events_triggered:
		var typed_event: Variant = event
		if event.duration > 0:
			event.duration -= 1
			if event.duration <= 0:
				completed_events.append(event)

	# Remove completed events
	for event in completed_events:
		var typed_event: Variant = event
		events_triggered.erase(event)
		event_resolved.emit(event.event_id, {"completed": true})

## Environmental hazard damage check
func check_environmental_damage(character_position: Vector2, character_savvy: int) -> Dictionary:
	var damage_results: Dictionary = {}

	for hazard in active_hazards:
		var typed_hazard: Variant = hazard
		var distance = character_position.distance_to(Vector2.ZERO) # Hazard at origin for testing
		if distance <= hazard.affects_radius:
			var save_roll = randi_range(1, 6) + character_savvy
			var damage_taken: int = 0

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


## Cleanup temporary effects
func _cleanup_temporary_effects() -> void:
	# Remove non-persistent events
	var persistent_events: Array[BattleEvent] = []
	for event in events_triggered:
		var typed_event: Variant = event
		if event.is_persistent:
			persistent_events.append(event)
	events_triggered = persistent_events

	# Remove non-permanent hazards
	var permanent_hazards: Array[EnvironmentalHazard] = []
	for hazard in active_hazards:
		var typed_hazard: Variant = hazard
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

func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event in events:
		var typed_event: Variant = event
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
		var typed_item: Variant = item
		var typed_item_dict: Dictionary = item as Dictionary
		if item is Dictionary and event_registry.has(item.get("event_id", "")):
			var event: Variant = event_registry[item.event_id]
			event.duration = item.get("duration", 0)
			events.append(event)
	return events

func _serialize_hazards(hazards: Array) -> Array:
	var serialized: Array = []
	for hazard in hazards:
		var typed_hazard: Variant = hazard
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
		var typed_item: Variant = item
		var typed_item_dict: Dictionary = item as Dictionary
		if item is Dictionary:
			var hazard := EnvironmentalHazard.new()
			hazard.hazard_id = item.get("hazard_id", "")
			hazard.hazard_name = item.get("hazard_name", "")
			hazard.effect_type = item.get("effect_type", "")
			hazards.append(hazard)
	return hazards

## Hardcoded event registry removed — all events now loaded from res://data/event_tables.json
## See Core Rules pp.116-117 for the 24 battle events (roll_range [1, 100])

## Helper to create battle events
func _create_event(id: String, title: String, roll_range: Array, description: String, effects: Dictionary) -> BattleEvent:
	var event := BattleEvent.new()
	event.event_id = id
	event.title = title
	# Convert Array to Array[int] explicitly (JSON parses numbers as float)
	var typed_range: Array[int] = []
	for value in roll_range:
		typed_range.append(int(value))
	event.roll_range = typed_range
	event.description = description
	event.effects = effects
	event.target_type = effects.get("target_type", "battlefield")
	event.duration = effects.get("duration", 0)
	event.is_persistent = effects.get("persistent", false)
	return event
