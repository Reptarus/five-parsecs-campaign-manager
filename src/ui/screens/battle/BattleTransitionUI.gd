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
	"""Initialize battle transition UI"""
	_setup_ui_components()
	_connect_signals()

func _setup_ui_components() -> void:
	"""Configure UI components for battle transition"""
	if battle_progress:
		battle_progress.value = 0
		battle_progress.max_value = 100
	
	_update_status("Waiting for mission data...")

func _connect_signals() -> void:
	"""Connect internal signals"""
	# Future: Connect to battle system signals when available
	pass

## Public Interface

func show_mission_briefing(mission_data: Dictionary) -> void:
	"""Display mission briefing and prepare for battle"""
	current_mission_data = mission_data
	
	_update_title(mission_data.get("title", "Unknown Mission"))
	_update_status("Preparing mission briefing...")
	_show_mission_details(mission_data)
	
	# Start battle preparation sequence
	_start_battle_preparation()

func show_battle_transition(battle_data: Dictionary) -> void:
	"""Show battle transition with loading progress"""
	battle_context = battle_data
	
	_update_status("Launching Battle Companion...")
	_show_loading_sequence()

## Private Methods

func _update_title(title: String) -> void:
	"""Update battle title display"""
	if battle_title:
		battle_title.text = title

func _update_status(status: String) -> void:
	"""Update status message"""
	if battle_status:
		battle_status.text = status
	print("BattleTransitionUI: %s" % status)

func _update_progress(value: float) -> void:
	"""Update progress bar (0-100)"""
	if battle_progress:
		battle_progress.value = value

func _show_mission_details(mission_data: Dictionary) -> void:
	"""Display mission briefing details"""
	var mission_type = mission_data.get("type", "Unknown")
	var difficulty = mission_data.get("difficulty", "Standard")
	var location = mission_data.get("location", "Unknown Location")
	
	_update_status("Mission: %s | Difficulty: %s | Location: %s" % [mission_type, difficulty, location])

func _start_battle_preparation() -> void:
	"""Begin battle preparation sequence"""
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
	"""Show battle loading progress"""
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
	"""Create comprehensive battle context for battle system"""
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
	"""Get data for crew members deployed to battle"""
	# Future: Integrate with actual crew management system
	return [
		{"name": "Captain", "class": "Leader", "stats": {"reactions": 1, "speed": 4}},
		{"name": "Marine", "class": "Soldier", "stats": {"reactions": 1, "speed": 4}},
		{"name": "Medic", "class": "Medic", "stats": {"reactions": 1, "speed": 4}}
	]

func _get_crew_equipment_data() -> Dictionary:
	"""Get equipment data for deployed crew"""
	# Future: Integrate with actual equipment management system
	return {
		"weapons": ["Colony Rifle", "Handgun", "Blade"],
		"armor": ["Combat Armor", "Flak Vest"],
		"equipment": ["Med-Kit", "Scanner"]
	}

## Event Handlers

func _on_cancel_button_pressed() -> void:
	"""Handle battle setup cancellation"""
	battle_setup_cancelled.emit()
	_update_status("Battle cancelled")

func _on_launch_battle_pressed() -> void:
	"""Handle manual battle launch trigger"""
	if current_mission_data.is_empty():
		_update_status("Error: No mission data available")
		return
	
	battle_ready_to_launch.emit(_create_battle_context())

## Debug and Testing

func _test_mission_briefing() -> void:
	"""Test method for mission briefing display"""
	var test_mission = {
		"title": "Rival Encounter",
		"type": "Opportunity Mission",
		"difficulty": "Challenging",
		"location": "Industrial Complex",
		"battlefield_type": "urban",
		"objectives": ["Defeat all enemies", "Secure the area"],
		"enemy_data": {"type": "Rivals", "count": 4}
	}
	
	show_mission_briefing(test_mission)