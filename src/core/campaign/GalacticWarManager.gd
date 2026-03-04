class_name GalacticWarManager
extends Node

## Galactic War Progress Tracking System
##
## Manages multiple war tracks that affect the campaign environment.
## War tracks progress based on dice rolls and player actions, creating
## dynamic galactic conflicts that influence missions, prices, and encounters.
##
## Based on Five Parsecs From Home Galactic War campaign rules.

## Signals

signal war_track_advanced(track_id: String, new_value: int, old_value: int)
signal war_threshold_reached(track_id: String, threshold: int, event_data: Dictionary)
signal war_effect_triggered(track_id: String, effect_id: String, description: String)
signal war_track_activated(track_id: String)
signal war_track_deactivated(track_id: String)
signal campaign_ending_triggered(track_id: String, ending_type: String)

## Configuration

const WAR_DATA_PATH := "res://data/galactic_war/war_progress_tracks.json"
const ADVANCEMENT_THRESHOLD := 5  # D6 roll of 5+ advances track
const DORMANT_ACTIVATION_CHANCE := 0.15  # 15% chance per turn

## State

var war_tracks: Dictionary = {}  # track_id -> war track data
var active_track_ids: Array[String] = []
var current_effects: Dictionary = {}  # effect_id -> effect data
var dice_system: Node = null

## Initialization

func _ready() -> void:
	dice_system = get_node_or_null("/root/DiceSystem")
	load_war_tracks()
	pass

func load_war_tracks() -> void:
	## Load war track definitions from JSON
	if not FileAccess.file_exists(WAR_DATA_PATH):
		push_error("GalacticWarManager: War data file not found: " + WAR_DATA_PATH)
		return
	
	var file = FileAccess.open(WAR_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("GalacticWarManager: Failed to open war data file")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("GalacticWarManager: Failed to parse JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if not data or not "war_tracks" in data:
		push_error("GalacticWarManager: Invalid war data structure")
		return
	
	# Initialize war tracks
	for track_id in data.war_tracks.keys():
		var track_data = data.war_tracks[track_id].duplicate(true)
		track_data["current_progress"] = track_data.get("starting_progress", 0)
		track_data["highest_threshold_reached"] = 0
		war_tracks[track_id] = track_data
		
		if track_data.get("active", false):
			active_track_ids.append(track_id)
	
	pass

## Campaign Turn Processing

func process_turn_war_progression() -> Array[Dictionary]:
	## Process war advancement for all active tracks.
	## Called once per campaign turn.
	## Returns array of events that occurred.
	var events: Array[Dictionary] = []
	
	# Advance active tracks
	for track_id in active_track_ids:
		var advancement_events = _roll_for_advancement(track_id)
		events.append_array(advancement_events)
	
	# Check for dormant track activation
	var activation_events = _check_dormant_activation()
	events.append_array(activation_events)
	
	return events

func _roll_for_advancement(track_id: String) -> Array[Dictionary]:
	## Roll D6 for track advancement (5+ succeeds)
	var events: Array[Dictionary] = []
	
	if not track_id in war_tracks:
		return events
	
	var track = war_tracks[track_id]
	var roll = _roll_d6()
	
	
	if roll >= ADVANCEMENT_THRESHOLD:
		var advancement_events = advance_war_track(track_id, 1)
		events.append_array(advancement_events)
		events.append({
			"type": "war_advancement_roll",
			"track_id": track_id,
			"track_name": track.name,
			"roll": roll,
			"advanced": true
		})
	else:
		events.append({
			"type": "war_advancement_roll",
			"track_id": track_id,
			"track_name": track.name,
			"roll": roll,
			"advanced": false
		})
	
	return events

func _check_dormant_activation() -> Array[Dictionary]:
	## Check if any dormant tracks should activate
	var events: Array[Dictionary] = []
	
	for track_id in war_tracks.keys():
		if track_id in active_track_ids:
			continue  # Already active
		
		var random_value = randf()
		if random_value < DORMANT_ACTIVATION_CHANCE:
			activate_war_track(track_id)
			events.append({
				"type": "war_track_activated",
				"track_id": track_id,
				"track_name": war_tracks[track_id].name,
				"description": "A new galactic conflict has erupted!"
			})
	
	return events

## War Track Manipulation

func advance_war_track(track_id: String, amount: int = 1) -> Array[Dictionary]:
	## Advance a war track by specified amount.
	## Returns array of threshold events triggered.
	var events: Array[Dictionary] = []
	
	if not track_id in war_tracks:
		push_warning("GalacticWarManager: Unknown track ID: " + track_id)
		return events
	
	var track = war_tracks[track_id]
	var old_progress = track.current_progress
	var new_progress = mini(old_progress + amount, track.max_progress)
	
	if new_progress == old_progress:
		return events  # No change
	
	track.current_progress = new_progress
	war_track_advanced.emit(track_id, new_progress, old_progress)
	
	
	# Check for threshold crossings
	if "thresholds" in track:
		for threshold_key in track.thresholds.keys():
			var threshold_value = int(threshold_key)
			if old_progress < threshold_value and new_progress >= threshold_value:
				var threshold_events = _trigger_threshold(track_id, threshold_value)
				events.append_array(threshold_events)
	
	# Check for campaign ending
	if new_progress >= track.max_progress:
		_check_campaign_ending(track_id)
	
	return events

func reduce_war_track(track_id: String, amount: int = 1) -> void:
	## Reduce a war track (player successfully opposed faction).
	## Does not trigger threshold events in reverse.
	if not track_id in war_tracks:
		return
	
	var track = war_tracks[track_id]
	var old_progress = track.current_progress
	var new_progress = maxi(old_progress - amount, track.min_progress)
	
	track.current_progress = new_progress
	war_track_advanced.emit(track_id, new_progress, old_progress)
	

func _trigger_threshold(track_id: String, threshold: int) -> Array[Dictionary]:
	## Trigger threshold event and apply effects
	var events: Array[Dictionary] = []
	
	var track = war_tracks[track_id]
	var threshold_key = str(threshold)
	
	if not threshold_key in track.thresholds:
		return events
	
	var threshold_data = track.thresholds[threshold_key]
	track.highest_threshold_reached = threshold
	
	war_threshold_reached.emit(track_id, threshold, threshold_data)
	
	
	# Apply effects
	if "effects" in threshold_data:
		for effect_id in threshold_data.effects.keys():
			var effect_value = threshold_data.effects[effect_id]
			_apply_war_effect(track_id, effect_id, effect_value, threshold_data)
	
	events.append({
		"type": "war_threshold",
		"track_id": track_id,
		"track_name": track.name,
		"threshold": threshold,
		"event_name": threshold_data.name,
		"description": threshold_data.get("description", ""),
		"narrative": threshold_data.get("narrative", ""),
		"effects": threshold_data.get("effects", {})
	})
	
	return events

func _apply_war_effect(track_id: String, effect_id: String, effect_value: Variant, context: Dictionary) -> void:
	## Apply a war effect to the campaign state
	var effect_key = "%s_%s" % [track_id, effect_id]
	
	current_effects[effect_key] = {
		"track_id": track_id,
		"effect_id": effect_id,
		"value": effect_value,
		"context": context
	}
	
	war_effect_triggered.emit(track_id, effect_id, context.get("description", ""))

func _check_campaign_ending(track_id: String) -> void:
	## Check if this track triggers a campaign ending
	var track = war_tracks[track_id]
	var max_threshold_key = str(track.max_progress)
	
	if max_threshold_key in track.thresholds:
		var threshold_data = track.thresholds[max_threshold_key]
		if "effects" in threshold_data and "campaign_ending" in threshold_data.effects:
			if threshold_data.effects.campaign_ending:
				var ending_type = track_id + "_victory"
				campaign_ending_triggered.emit(track_id, ending_type)

## Track Activation/Deactivation

func activate_war_track(track_id: String) -> void:
	## Activate a dormant war track
	if track_id in active_track_ids:
		return  # Already active
	
	if not track_id in war_tracks:
		push_warning("GalacticWarManager: Cannot activate unknown track: " + track_id)
		return
	
	active_track_ids.append(track_id)
	war_tracks[track_id].active = true
	war_track_activated.emit(track_id)
	

func deactivate_war_track(track_id: String) -> void:
	## Deactivate an active war track
	var index = active_track_ids.find(track_id)
	if index == -1:
		return  # Not active
	
	active_track_ids.remove_at(index)
	war_tracks[track_id].active = false
	war_track_deactivated.emit(track_id)
	

## Query Methods

func get_war_track(track_id: String) -> Dictionary:
	## Get war track data
	return war_tracks.get(track_id, {})

func get_all_war_tracks() -> Dictionary:
	## Get all war track data
	return war_tracks.duplicate(true)

func get_active_war_tracks() -> Array[Dictionary]:
	## Get all active war tracks
	var active_tracks: Array[Dictionary] = []
	for track_id in active_track_ids:
		active_tracks.append(war_tracks[track_id])
	return active_tracks

func get_current_progress(track_id: String) -> int:
	## Get current progress for a track
	if not track_id in war_tracks:
		return 0
	return war_tracks[track_id].current_progress

func get_active_effects() -> Dictionary:
	## Get all currently active war effects
	return current_effects.duplicate(true)

func has_effect(effect_id: String) -> bool:
	## Check if a specific effect is currently active
	for key in current_effects.keys():
		if key.ends_with("_" + effect_id):
			return true
	return false

func get_effect_modifier(effect_id: String, default_value: float = 0.0) -> float:
	## Get numeric modifier from an active effect
	for key in current_effects.keys():
		if key.ends_with("_" + effect_id):
			var effect = current_effects[key]
			if effect.value is float or effect.value is int:
				return float(effect.value)
	return default_value

## Player Influence

func player_mission_success(track_id: String, mission_type: String = "defense") -> void:
	## Called when player completes mission opposing a faction
	reduce_war_track(track_id, 1)

func player_mission_failure(track_id: String) -> void:
	## Called when player fails mission opposing a faction
	advance_war_track(track_id, 1)

func player_sabotage_success(track_id: String) -> void:
	## Called when player completes special sabotage mission
	reduce_war_track(track_id, 2)

## Save/Load Support

func get_save_data() -> Dictionary:
	## Get war state for saving
	return {
		"war_tracks": war_tracks.duplicate(true),
		"active_track_ids": active_track_ids.duplicate(),
		"current_effects": current_effects.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	## Restore war state from save
	if "war_tracks" in data:
		war_tracks = data.war_tracks.duplicate(true)
	
	if "active_track_ids" in data:
		active_track_ids = data.active_track_ids.duplicate()
	
	if "current_effects" in data:
		current_effects = data.current_effects.duplicate(true)
	
	pass

## Utilities

func _roll_d6() -> int:
	## Roll a D6
	if dice_system and dice_system.has_method("roll_dice"):
		return dice_system.roll_dice(1, 6)
	else:
		return randi_range(1, 6)

func reset_all_tracks() -> void:
	## Reset all war tracks to starting state (for testing/new campaign)
	for track_id in war_tracks.keys():
		var track = war_tracks[track_id]
		track.current_progress = track.starting_progress
		track.highest_threshold_reached = 0
	
	current_effects.clear()
