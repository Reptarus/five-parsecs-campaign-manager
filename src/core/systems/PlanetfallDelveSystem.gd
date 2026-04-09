class_name PlanetfallDelveSystem
extends RefCounted

## Manages Delve mission mechanics: hazard markers, trap resolution,
## environmental hazards, and device activation for ancient site exploration.
## Source: Planetfall pp.130-135

var _hazard_reveal: Array = []
var _traps: Array = []
var _environmental_hazards: Array = []
var _device_activation: Dictionary = {}
var _activations_required: int = 3
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	var data: Dictionary = _load_json("res://data/planetfall/delve_system.json")
	var reveal_data: Dictionary = data.get("hazard_reveal", {})
	_hazard_reveal = reveal_data.get("entries", [])

	var trap_data: Dictionary = data.get("traps", {})
	_traps = trap_data.get("entries", [])

	var hazard_data: Dictionary = data.get("environmental_hazards", {})
	_environmental_hazards = hazard_data.get("entries", [])

	_device_activation = data.get("device_activation", {})
	_activations_required = _device_activation.get("activations_required", 3)

	_loaded = not _traps.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallDelveSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallDelveSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## HAZARD REVEAL (D6)
## ============================================================================

func resolve_hazard_reveal(roll_d6: int) -> Dictionary:
	## When a Delve Hazard is revealed (crew within 3" and LoS), roll D6.
	## 1-2 = Sleeper, 3-4 = Trap, 5-6 = Environmental Hazard.
	for entry in _hazard_reveal:
		if entry is Dictionary:
			if roll_d6 >= entry.get("min", 0) and roll_d6 <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func get_hazard_type(roll_d6: int) -> String:
	## Returns the hazard type string: "enemy", "trap", or "environmental_hazard".
	var result: Dictionary = resolve_hazard_reveal(roll_d6)
	return result.get("id", "")


## ============================================================================
## TRAPS (D100)
## ============================================================================

func resolve_trap(roll: int) -> Dictionary:
	## D100 lookup on Delve Trap table. Returns full trap entry.
	return _lookup_d100(_traps, roll)


func get_all_traps() -> Array:
	return _traps.duplicate(true)


## ============================================================================
## ENVIRONMENTAL HAZARDS (D100)
## ============================================================================

func resolve_environmental_hazard(roll: int) -> Dictionary:
	## D100 lookup on Environmental Hazard table. Returns full hazard entry.
	return _lookup_d100(_environmental_hazards, roll)


func get_all_environmental_hazards() -> Array:
	return _environmental_hazards.duplicate(true)


## ============================================================================
## DEVICE ACTIVATION (D6)
## ============================================================================

func resolve_device_activation(roll_d6: int) -> Dictionary:
	## Roll D6 to determine how a Delve Device activates.
	## 1=Unusable, 2-3=Time-based (2 rounds), 4-5=Automatic, 6=Skill-based (Savvy 4+).
	var entries: Array = _device_activation.get("entries", [])
	for entry in entries:
		if entry is Dictionary:
			if roll_d6 >= entry.get("min", 0) and roll_d6 <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func get_activations_required() -> int:
	## Number of successful device activations needed to unlock Artifact location.
	return _activations_required


func is_artifact_unlocked(activations_completed: int) -> bool:
	## Returns true if enough activations completed to reveal Artifact.
	return activations_completed >= _activations_required


## ============================================================================
## DELVE STATE HELPERS
## ============================================================================

func create_delve_state() -> Dictionary:
	## Create a fresh delve mission state tracker.
	return {
		"hazard_markers": 4,
		"devices_activated": 0,
		"devices_attempted": [],
		"artifact_unlocked": false,
		"artifact_collected": false,
		"sleepers_on_table": 0,
		"active_traps": [],
		"active_hazards": [],
		"round_number": 1
	}


func tick_round(state: Dictionary) -> Dictionary:
	## Process start-of-round effects for delve state.
	## Returns list of events that occurred.
	var events: Array = []
	state["round_number"] = state.get("round_number", 1) + 1

	# Replenish hazard markers up to 4
	var current_hazards: int = state.get("hazard_markers", 0)
	if current_hazards < 4:
		state["hazard_markers"] = current_hazards + 1
		events.append({"type": "hazard_placed", "description": "New Delve Hazard placed at table center."})

	return {"events": events, "round": state["round_number"]}


## ============================================================================
## DICE HELPERS
## ============================================================================

func roll_d100() -> int:
	return randi_range(1, 100)


func roll_d6() -> int:
	return randi_range(1, 6)


## ============================================================================
## PRIVATE
## ============================================================================

func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
