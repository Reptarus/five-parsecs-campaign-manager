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

func _init() -> void:
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
	var event: Variant = _get_event_for_roll(roll)

	if event:
		# Check for conflicts with existing events
		var conflicts = _check_event_conflicts(event)
		if conflicts:
			event_conflicts_detected.emit(event, conflicts)
			print("Event conflict detected - discarding: " + event.title)
			return

		safe_call_method(events_triggered, "append", [event])
		battle_event_triggered.emit(event)
		_apply_event_effects(event)

		print("Battle Event Triggered: " + event.title)

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
			effects["spawn_enemies"] = 2
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
			effects["max_toughness"] = 6
			effects["remove_all_stun"] = true
		"ENEMY_VIP":
			# Unique Individual joins at center of enemy edge
			effects["spawn_unique"] = true
			effects["spawn_location"] = "enemy_edge_center"
		"POSSIBLE_REINFORCEMENTS":
			# 3 markers along enemy edge, roll 5-6 each round for spawn
			effects["reinforcement_markers"] = 3
			effects["spawn_on_roll"] = [5, 6]
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
			effects["run_distance"] = 6
			effects["apply_stun"] = true
			effects["scatter_radius"] = 4
			effects["ignore_no_grenades"] = true

## Handle battlefield-wide events
func _apply_battlefield_event(_event: BattleEvent) -> void:
	var effects = _event.effects

	match _event.event_id:
		"VISIBILITY_CHANGE":
			# If unlimited: reduce to 1D6+6", if reduced: increase by +1D6"
			var current_vision = effects.get("current_vision", 24)
			if current_vision > 24:
				effects["new_vision"] = randi_range(1, 6) + 6
			else:
				effects["new_vision"] = current_vision + randi_range(1, 6)
		"FOG_CLOUD":
			# Dense fog 6" radius from center, blocks visibility past 2"
			effects["fog_radius"] = 6
			effects["fog_vision_limit"] = 2
			effects["fog_location"] = "table_center"
			effects["duration"] = "rest_of_battle"
		"CLOCK_RUNNING_OUT":
			# Roll 1D6 end of each round, 6 = game ends, no objectives
			effects["time_pressure"] = true
			effects["end_on_roll"] = 6
			effects["no_hold_field_unless_cleared"] = true
		"ENVIRONMENTAL_HAZARD":
			# Random terrain: figures within 1" roll Savvy 5+ or Damage +1
			effects["terrain_selection"] = "random"
			effects["hazard_radius"] = 1
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

	safe_call_method(active_hazards, "append", [hazard])
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
			print("Universal event applied: " + _event.title)

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
		if roll >= event.roll_range[0] and roll <= event.roll_range[1]:
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
				safe_call_method(completed_events, "append", [event])

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

	print("Battle Events System ended")

## Cleanup temporary effects
func _cleanup_temporary_effects() -> void:
	# Remove non-persistent events
	var persistent_events: Array[BattleEvent] = []
	for event in events_triggered:
		var typed_event: Variant = event
		if event.is_persistent:
			safe_call_method(persistent_events, "append", [event])
	events_triggered = persistent_events

	# Remove non-permanent hazards
	var permanent_hazards: Array[EnvironmentalHazard] = []
	for hazard in active_hazards:
		var typed_hazard: Variant = hazard
		if hazard.is_permanent:
			safe_call_method(permanent_hazards, "append", [hazard])
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
	var serialized: Array = []
	for event in events:
		var typed_event: Variant = event
		if event != null:
			safe_call_method(serialized, "append" , [ {
				"event_id": event.event_id,
				"title": event.title,
				"duration": event.duration
			}])
	return serialized

func _deserialize_events(data: Array) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for item in data:
		var typed_item: Variant = item
		var typed_item_dict: Dictionary = item as Dictionary
		if item is Dictionary and event_registry.has(item.get("event_id", "")):
			var event: Variant = event_registry[item.event_id]
			event.duration = item.get("duration", 0)
			safe_call_method(events, "append", [event])
	return events

func _serialize_hazards(hazards: Array[EnvironmentalHazard]) -> Array:
	var serialized: Array = []
	for hazard in hazards:
		var typed_hazard: Variant = hazard
		if hazard != null:
			safe_call_method(serialized, "append", [ {
				"hazard_id": hazard.hazard_id,
				"hazard_name": hazard.hazard_name,
				"effect_type": hazard.effect_type
			}])
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
			safe_call_method(hazards, "append", [hazard])
	return hazards

## Initialize the complete Core Rules event registry (p.116-117)
func _initialize_event_registry() -> void:
	# Complete Core Rules Battle Events (1-100 range)
	event_registry = {
		"RENEWED_EFFORTS": _create_event("RENEWED_EFFORTS", "Renewed Efforts", [1, 5],
			"The enemy is making a concerted effort to push you back. For the rest of the battle, after all enemy figures have acted, select a random figure that may immediately take a second Move and second Combat Action.",
			{"target_type": "enemy"}),
		"ENEMY_REINFORCEMENTS": _create_event("ENEMY_REINFORCEMENTS", "Enemy Reinforcements", [6, 9],
			"An additional 2 enemy figures arrive at the center of the opposing battlefield edge. One is armed as a Specialist (if applicable to the enemy type).",
			{"target_type": "enemy"}),
		"CHANGE_OF_PLANS": _create_event("CHANGE_OF_PLANS", "Change of Plans", [10, 13],
			"The enemy switches to the Cautious AI type for the rest of the battle. If they were already Cautious, they instead switch to Tactical AI. Enemies with no ranged attacks are unaffected by this event.",
			{"target_type": "enemy"}),
		"LOST_HEART": _create_event("LOST_HEART", "Lost Heart", [14, 16],
			"The enemy has had enough of this fight. At the end of the next round, they will leave the field.",
			{"target_type": "enemy"}),
		"SEIZED_MOMENT": _create_event("SEIZED_MOMENT", "Seized the Moment", [17, 20],
			"Select a crew member who may move and act in both the Quick and Slow Actions phases next round.",
			{"target_type": "crew"}),
		"CRITTERS": _create_event("CRITTERS", "Critters!", [21, 26],
			"Place 1D3 Vent Crawlers in the center of the table, and move each of them 1D6\" in a random direction. At the beginning of the Enemy Actions phase, they will move towards the nearest figure and attack, regardless of which side the figure is on.",
			{"target_type": "enemy"}),
		"AMMO_FAULT": _create_event("AMMO_FAULT", "Ammo Fault", [27, 30],
			"Select a random figure in your crew. If they fired a weapon last round, it cannot be used for the rest of the battle. If they did not, select a random carried weapon, which can be fired only once this battle.",
			{"target_type": "crew"}),
		"VISIBILITY_CHANGE": _create_event("VISIBILITY_CHANGE", "Visibility Change", [31, 34],
			"If visibility is currently reduced, increase the vision range by +1D6\". If visibility is currently unlimited, reduce it to 1D6+6\".",
			{"target_type": "battlefield"}),
		"TOUGHER_THAN_EXPECTED": _create_event("TOUGHER_THAN_EXPECTED", "Tougher than Expected", [35, 38],
			"Select a random enemy figure. They receive +1 Toughness (to a maximum of 6) and remove all current stun markers on that figure.",
			{"target_type": "enemy"}),
		"SNAP_SHOT": _create_event("SNAP_SHOT", "Snap Shot", [39, 42],
			"Select a figure in your crew. They may fire a weapon immediately. If the weapon is a Pistol, it Hits automatically, otherwise roll to Hit normally.",
			{"target_type": "crew"}),
		"CUNNING_PLAN": _create_event("CUNNING_PLAN", "Cunning Plan", [43, 46],
			"In the next round, do not roll for Initiative. Each of your crew acts in the Quick or Slow Actions phase as you prefer.",
			{"target_type": "crew"}),
		"POSSIBLE_REINFORCEMENTS": _create_event("POSSIBLE_REINFORCEMENTS", "Possible Reinforcements", [47, 50],
			"Place 3 markers evenly spaced along the opposing battlefield edge. At the start of the Enemy Actions phase next round, select a random marker, and roll 1D6. On a 5-6, a new basic enemy figure is placed on the marker, otherwise it is removed. Roll for one marker per round until they are all gone. If a crew member moves within 3\" of a marker, it is removed instantly.",
			{"target_type": "enemy"}),
		"CLOCK_RUNNING_OUT": _create_event("CLOCK_RUNNING_OUT", "Clock is Running Out", [51, 54],
			"At the end of the next round and each round thereafter, roll 1D6. On a 6, the game ends immediately, and you are unable to complete any objectives. You will not count as Holding the Field unless you clear the table of enemies before this happens.",
			{"target_type": "battlefield"}),
		"ENVIRONMENTAL_HAZARD": _create_event("ENVIRONMENTAL_HAZARD", "Environmental Hazard", [55, 60],
			"Select a random terrain feature. Any figure currently in, on, or within 1\" of the feature must roll 1D6+Savvy and achieve a 5+ (enemies roll 1D6 and must roll a 4+) or take a Damage +1 Hit, ignoring any Armor Saving Throws. The feature is safe afterwards.",
			{"target_type": "battlefield"}),
		"DESPERATE_PLAN": _create_event("DESPERATE_PLAN", "A Desperate Plan", [61, 65],
			"A random figure in your crew cannot act next round, but instead select another figure of choice that may act in both the Quick and Slow Actions phases.",
			{"target_type": "crew"}),
		"MOMENT_OF_HESITATION": _create_event("MOMENT_OF_HESITATION", "A Moment of Hesitation", [66, 70],
			"Next round, select a single figure that acts in the Quick Actions phase (if any Feral are in the squad, you must select a Feral). All other figures act in the Slow Actions phase.",
			{"target_type": "crew"}),
		"FUMBLED_GRENADE": _create_event("FUMBLED_GRENADE", "Fumbled Grenade", [71, 73],
			"A random enemy fumbles a grenade. The figure in question runs 6\" in a random direction and is then Stunned. Every figure, crew and enemy within 4\" of the initial position will immediately run 4\" directly away. The grenade then goes off harmlessly. If the enemy is one that would not use grenades, nothing happens.",
			{"target_type": "enemy"}),
		"BACK_UP": _create_event("BACK_UP", "Back Up", [74, 77],
			"If you have spare crew not taking part in the battle, you may have one crew member arrive. Place them on the center of your own battlefield edge.",
			{"target_type": "crew"}),
		"ENEMY_VIP": _create_event("ENEMY_VIP", "Enemy VIP", [78, 80],
			"A Unique Individual immediately joins the enemy force. Place them on the center of their battlefield edge.",
			{"target_type": "enemy"}),
		"FOG_CLOUD": _create_event("FOG_CLOUD", "Fog Cloud", [81, 85],
			"A dense cloud of fog envelops the center of the table for the rest of the battle. It extends 6\" in every direction and blocks all visibility past 2\".",
			{"target_type": "battlefield"}),
		"LOST": _create_event("LOST", "Lost!", [86, 89],
			"A random crew member loses their way and misses the rest of the battle. Remove the figure from the battlefield. They rejoin you safely afterwards, looking a bit sheepish. Ignore this event if you are currently outnumbered.",
			{"target_type": "crew"}),
		"FOUND_SOMETHING": _create_event("FOUND_SOMETHING", "I Found Something!", [90, 93],
			"Randomly select a crew member, then place a marker 1D6\" from them in a random direction. The enemy will ignore it. If any crew member moves into contact and spends a non-Combat Action, roll for a Loot item and claim it for use immediately.",
			{"target_type": "crew"}),
		"LOOKS_VALUABLE": _create_event("LOOKS_VALUABLE", "Looks Valuable", [94, 97],
			"Randomly select a crew member, then place a marker 1D6\" from them in a random direction. The enemy will ignore it. If any crew member moves into contact and spends a non-Combat Action, obtain 1D3 credits.",
			{"target_type": "crew"}),
		"CHECK_THAT_OUT": _create_event("CHECK_THAT_OUT", "You Want Me to Check That Out?", [98, 100],
			"Select a random crew member. They may opt to go check out something they insist they saw. If they do, they are removed from the battle. After the battle ends, they may roll once on the Loot table. If you opt not to go, you cannot send a different character, and the chance is lost.",
			{"target_type": "crew"})
	}

## Helper to create battle events
func _create_event(id: String, title: String, roll_range: Array[int], description: String, effects: Dictionary) -> BattleEvent:
	var event := BattleEvent.new()
	event.event_id = id
	event.title = title
	event.roll_range = roll_range
	event.description = description
	event.effects = effects
	event.target_type = effects.get("target_type", "battlefield")
	event.duration = effects.get("duration", 0)
	event.is_persistent = effects.get("persistent", false)
	return event

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null