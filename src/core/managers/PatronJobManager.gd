extends Resource

var game_state_manager: Node
var validation_manager: Node

# JSON-loaded patron job tables (Core Rules pp.83-84)
var _patron_data: Dictionary = {}
var _patron_data_loaded: bool = false

func _init(_game_state: Node) -> void:
	game_state_manager = _game_state
	validation_manager = Node.new()
	_ensure_patron_data_loaded()

func _ensure_patron_data_loaded() -> void:
	if _patron_data_loaded:
		return
	_patron_data_loaded = true
	var file := FileAccess.open("res://data/patron_generation.json", FileAccess.READ)
	if not file:
		push_warning("PatronJobManager: patron_generation.json not found, using fallback")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("PatronJobManager: Failed to parse patron_generation.json")
		file.close()
		return
	file.close()
	_patron_data = json.data

## Roll on a D10 subtable from patron_generation.json and return the entry
func _roll_on_patron_subtable(table_key: String) -> Dictionary:
	var subtable: Dictionary = _patron_data.get(table_key, {})
	var entries: Array = subtable.get("entries", [])
	if entries.is_empty():
		return {}
	var roll: int = randi_range(1, 10)
	for entry in entries:
		var roll_range: Array = entry.get("roll_range", [1, 1])
		if roll >= roll_range[0] and roll <= roll_range[1]:
			return entry
	return entries[-1]

func accept_job(mission: Node) -> bool:
	var validation_result = validation_manager.validate_mission_start(mission)
	if not validation_result.valid:
		return false
		
	game_state_manager.current_mission = mission
	game_state_manager.remove_available_mission(mission)
	return true
func complete_job(mission: Node) -> void:
	if not mission:
		push_error("Attempted to complete null mission")
		return
		
	mission.complete()
	_apply_job_rewards(mission)
	if mission.patron:
		mission.patron.change_relationship(10)
	game_state_manager.current_mission = null

func fail_job(mission: Node) -> void:
	if not mission:
		push_error("Attempted to fail null mission")
		return
		
	mission.fail()
	if mission.patron:
		mission.patron.change_relationship(-5)
	game_state_manager.current_mission = null
	_apply_failure_consequences(mission)

func update_job_timers() -> void:
	for mission in game_state_manager.available_missions:
		if mission.patron:
			mission.time_limit -= 1
			if mission.time_limit <= 0:
				game_state_manager.remove_available_mission(mission)
				mission.patron.change_relationship(-2)

func _apply_job_rewards(mission: Node) -> void:
	game_state_manager.add_credits(mission.rewards["credits"])
	game_state_manager.add_reputation(mission.rewards.get("reputation", 0))
	
	if mission.rewards.has("equipment"):
		for item in mission.rewards.equipment:
			game_state_manager.current_crew.add_equipment(item)
			
	if mission.rewards.has("influence"):
		game_state_manager.add_influence(mission.rewards.influence)

func _apply_failure_consequences(mission: Node) -> void:
	if mission.hazards.size() > 0:
		game_state_manager.current_crew.apply_casualties()
	
	if mission.conditions.has("Reputation Required"):
		game_state_manager.decrease_reputation(5)

func generate_benefits_hazards_conditions(patron: Node) -> Dictionary:
	return {
		"benefits": [generate_benefit()] if should_generate_benefit(patron) else [],
		"hazards": [generate_hazard()] if should_generate_hazard(patron) else [],
		"conditions": [generate_condition()] if should_generate_condition(patron) else []
	}

func should_generate_benefit(patron: Node) -> bool:
	var chance: float = 0.8 if patron.type in ["CORPORATE", "UNITY"] else 0.5
	return randf() < chance

func should_generate_hazard(patron: Node) -> bool:
	var chance: float = 0.5 if patron.type == "FRINGE" else 0.8
	return randf() < chance

func should_generate_condition(patron: Node) -> bool:
	var chance: float = 0.5 if patron.type == "CORPORATE" else 0.8
	return randf() < chance

func generate_benefit() -> String:
	var entry: Dictionary = _roll_on_patron_subtable("benefits_subtable")
	return entry.get("name", "Fringe Benefit")

func generate_hazard() -> String:
	var entry: Dictionary = _roll_on_patron_subtable("hazards_subtable")
	return entry.get("name", "Dangerous Job")

func generate_condition() -> String:
	var entry: Dictionary = _roll_on_patron_subtable("conditions_subtable")
	return entry.get("name", "Vengeful")

## Get the full effect text for a benefit/hazard/condition name
func get_bhc_effect(table_key: String, name: String) -> String:
	var subtable: Dictionary = _patron_data.get(table_key, {})
	for entry in subtable.get("entries", []):
		if entry.get("name", "") == name:
			return entry.get("effect", "")
	return ""

func add_mission(mission: Node) -> void:
	game_state_manager.add_available_mission(mission)

func remove_mission(mission: Node) -> void:
	game_state_manager.remove_available_mission(mission)

func add_patron(patron: Node) -> void:
	game_state_manager.patrons.append(patron)

func remove_patron(patron: Node) -> void:
	game_state_manager.patrons.erase(patron)
