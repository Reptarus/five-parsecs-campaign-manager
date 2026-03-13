extends Control

## Battle Transition UI - Mission Briefing and Battle Setup Interface
## Handles the transition from World Phase to Battle Phase with proper context

# UI Components
@onready var battle_title: Label = $BattleTransitionPanel/BattleTransitionContent/BattleTitle
@onready var battle_status: Label = $BattleTransitionPanel/BattleTransitionContent/BattleStatus  
@onready var battle_progress: ProgressBar = $BattleTransitionPanel/BattleTransitionContent/BattleProgress

# Mission Context
var current_mission_data: Dictionary = {}
var battle_context: Dictionary = {}

# Signals
signal battle_ready_to_launch(mission_context: Dictionary)
signal battle_setup_cancelled()

func _ready() -> void:
	## Initialize battle transition UI
	_setup_ui_components()
	_connect_signals()

func _setup_ui_components() -> void:
	## Configure UI components for battle transition
	if battle_progress:
		battle_progress.value = 0
		battle_progress.max_value = 100
	
	_update_status("Waiting for mission data...")

func _connect_signals() -> void:
	## Connect internal signals
	# Future: Connect to battle system signals when available
	pass

## Public Interface

func show_mission_briefing(mission_data: Dictionary) -> void:
	## Display mission briefing and prepare for battle
	current_mission_data = mission_data
	
	_update_title(mission_data.get("title", "Unknown Mission"))
	_update_status("Preparing mission briefing...")
	_show_mission_details(mission_data)
	
	# Start battle preparation sequence
	_start_battle_preparation()

func show_battle_transition(battle_data: Dictionary) -> void:
	## Show battle transition with loading progress
	battle_context = battle_data
	
	_update_status("Launching Battle Companion...")
	_show_loading_sequence()

## Private Methods

func _update_title(title: String) -> void:
	## Update battle title display
	if battle_title:
		battle_title.text = title

func _update_status(status: String) -> void:
	## Update status message
	if battle_status:
		battle_status.text = status

func _update_progress(value: float) -> void:
	## Update progress bar (0-100)
	if battle_progress:
		battle_progress.value = value

func _show_mission_details(mission_data: Dictionary) -> void:
	## Display mission briefing details
	var mission_type = mission_data.get("type", "Unknown")
	var difficulty = mission_data.get("difficulty", "Standard")
	var location = mission_data.get("location", "Unknown Location")
	
	_update_status("Mission: %s | Difficulty: %s | Location: %s" % [mission_type, difficulty, location])

func _start_battle_preparation() -> void:
	## Begin battle preparation sequence
	_update_progress(10)
	_update_status("Validating crew deployment...")
	
	# Simulate preparation steps
	await get_tree().create_timer(0.5).timeout
	_update_progress(30)
	_update_status("Loading battlefield parameters...")
	
	await get_tree().create_timer(0.5).timeout 
	_update_progress(60)
	_update_status("Initializing battle systems...")
	
	await get_tree().create_timer(0.5).timeout
	_update_progress(90)
	_update_status("Ready to launch battle...")
	
	await get_tree().create_timer(0.5).timeout
	_update_progress(100)
	_update_status("Battle Ready!")
	
	# Signal that battle is ready to launch
	battle_ready_to_launch.emit(_create_battle_context())

func _show_loading_sequence() -> void:
	## Show battle loading progress
	_update_progress(0)
	
	# Simulate battle companion loading
	for i in range(1, 11):
		await get_tree().create_timer(0.1).timeout
		_update_progress(i * 10)
		
		match i:
			3:
				_update_status("Connecting to Battle Companion...")
			6:
				_update_status("Loading battlefield data...")
			9:
				_update_status("Initializing combat systems...")
	
	_update_status("Battle Companion Ready!")

func _create_battle_context() -> Dictionary:
	## Create comprehensive battle context for battle system
	return {
		"mission_data": current_mission_data,
		"campaign_turn": GameState.get_campaign_turn() if GameState else 1,
		"crew_data": _get_deployed_crew_data(),
		"equipment_data": _get_crew_equipment_data(),
		"battlefield_type": current_mission_data.get("battlefield_type", "standard"),
		"enemy_data": current_mission_data.get("enemy_data", {}),
		"objectives": current_mission_data.get("objectives", []),
		"special_conditions": current_mission_data.get("special_conditions", [])
	}

func _get_deployed_crew_data() -> Array:
	## Get data for crew members deployed to battle from GameState
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("get_crew_members"):
		var members: Array = game_state.get_crew_members()
		if not members.is_empty():
			var crew_data: Array = []
			for member in members:
				var entry: Dictionary = {}
				entry["name"] = member.character_name if "character_name" in member else str(member)
				entry["class"] = member.character_class if "character_class" in member else "Crew"
				entry["stats"] = {
					"reaction": member.reaction if "reaction" in member else 1,
					"speed": member.speed if "speed" in member else 4,
					"combat": member.combat if "combat" in member else 0,
					"toughness": member.toughness if "toughness" in member else 3,
				}
				crew_data.append(entry)
			return crew_data
	# Fallback: try current_crew property
	if game_state and "current_crew" in game_state and game_state.current_crew:
		var crew = game_state.current_crew
		if crew.has_method("get_members"):
			var members: Array = crew.get_members()
			if not members.is_empty():
				var crew_data: Array = []
				for member in members:
					var entry: Dictionary = {}
					entry["name"] = member.character_name if "character_name" in member else str(member)
					entry["class"] = member.character_class if "character_class" in member else "Crew"
					crew_data.append(entry)
				return crew_data
	return []

func _get_crew_equipment_data() -> Dictionary:
	## Get equipment data for deployed crew from GameState
	var game_state = get_node_or_null("/root/GameState")
	var equipment: Dictionary = {"weapons": [], "armor": [], "equipment": []}
	if game_state and game_state.has_method("get_crew_members"):
		var members: Array = game_state.get_crew_members()
		for member in members:
			if member is Dictionary:
				# Extract equipment from Dictionary crew (loaded saves)
				var member_equipment: Array = member.get("equipment", [])
				for eq_item in member_equipment:
					var eq_name: String = eq_item.get("name", str(eq_item)) if eq_item is Dictionary else str(eq_item)
					var eq_type: String = eq_item.get("type", "gear") if eq_item is Dictionary else "gear"
					if eq_type == "weapon" or eq_type == "Weapon":
						if eq_name not in equipment["weapons"]:
							equipment["weapons"].append(eq_name)
					elif eq_type == "armor" or eq_type == "Armor":
						if eq_name not in equipment["armor"]:
							equipment["armor"].append(eq_name)
					else:
						if eq_name not in equipment["equipment"]:
							equipment["equipment"].append(eq_name)
			elif member.has_method("get_weapons"):
				for w in member.get_weapons():
					var wname: String = w.item_name if "item_name" in w else str(w)
					if wname not in equipment["weapons"]:
						equipment["weapons"].append(wname)
				if member.has_method("get_armor"):
					var a = member.get_armor()
					if a:
						var aname: String = a.item_name if "item_name" in a else str(a)
						if aname not in equipment["armor"]:
							equipment["armor"].append(aname)
	if equipment["weapons"].is_empty() and equipment["armor"].is_empty():
		return {}
	return equipment

## Event Handlers

func _on_cancel_button_pressed() -> void:
	## Handle battle setup cancellation
	battle_setup_cancelled.emit()
	_update_status("Battle cancelled")

func _on_launch_battle_pressed() -> void:
	## Handle manual battle launch trigger
	if current_mission_data.is_empty():
		_update_status("Error: No mission data available")
		return

	battle_ready_to_launch.emit(_create_battle_context())

## Sprint 26.4: Battle Mode Selection and Auto-Resolve

signal auto_resolve_completed(result: Dictionary)

func show_mode_selection(crew_count: int, enemy_count: int) -> void:
	## Show battle mode selection screen with crew/enemy info
	_update_title("Battle Mode Selection")
	_update_status("Crew: %d vs Enemies: %d - Select battle mode" % [crew_count, enemy_count])
	_update_progress(0)
	show()

func show_auto_resolve_progress() -> void:
	## Show auto-resolve battle simulation with progress feedback
	show()
	_update_title("Auto-Resolving Battle...")
	_update_progress(0)

	# Simulate battle resolution phases with progress
	var phases = [
		{"progress": 10, "status": "Initializing combat simulation...", "delay": 0.3},
		{"progress": 25, "status": "Calculating opening moves...", "delay": 0.4},
		{"progress": 40, "status": "Resolving firefight rounds...", "delay": 0.5},
		{"progress": 55, "status": "Processing casualties...", "delay": 0.4},
		{"progress": 70, "status": "Evaluating tactical outcomes...", "delay": 0.4},
		{"progress": 85, "status": "Determining battle result...", "delay": 0.3},
		{"progress": 100, "status": "Battle Complete!", "delay": 0.2}
	]

	for phase in phases:
		await get_tree().create_timer(phase.delay).timeout
		_update_progress(phase.progress)
		_update_status(phase.status)

	# Brief pause to show completion
	await get_tree().create_timer(0.5).timeout

	# Emit completion - BattlePhase will handle actual results
	auto_resolve_completed.emit({"auto_resolved": true, "timestamp": Time.get_unix_time_from_system()})
