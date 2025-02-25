extends Control

const BattleEventManager = preload("res://src/core/battle/events/BattleEventManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

var mission_type: GlobalEnums.MissionType
var deployment_type: GlobalEnums.DeploymentType

@onready var battlefield = $BattleLayout/MainContent/BattlefieldMain
@onready var five_parcecs_system = $FiveParcecsSystem
@onready var turn_label = $BattleLayout/TopBar/HBoxContainer/TurnLabel
@onready var phase_label = $BattleLayout/TopBar/HBoxContainer/PhaseLabel
@onready var active_unit_label = $BattleLayout/TopBar/HBoxContainer/ActiveUnitLabel
@onready var unit_stats = $BattleLayout/MainContent/SidePanel/VBoxContainer/UnitInfo/VBoxContainer/UnitStats
@onready var action_panel = $BattleLayout/MainContent/SidePanel/VBoxContainer/ActionPanel
@onready var battle_log = $BattleLayout/MainContent/SidePanel/VBoxContainer/BattleLog/VBoxContainer/LogContent
@onready var preview_panel = $BattleLayout/MainContent/SidePanel/VBoxContainer/PreviewPanel
@onready var regenerate_button = $BattleLayout/MainContent/SidePanel/VBoxContainer/PreviewPanel/RegenerateButton
@onready var battle_info_label := $BattleInfo/Label

var game_state: Node
var event_manager: BattleEventManager
var selected_unit: Node
var selected_action: int = GameEnums.UnitAction.NONE
var current_mission: Mission

func _ready() -> void:
	game_state = get_node("/root/GameState")
	event_manager = BattleEventManager.new()
	_connect_signals()

func initialize_battle(mission: Mission) -> void:
	current_mission = mission
	mission_type = mission.mission_type
	deployment_type = mission.deployment_type
	_initialize_battlefield_preview()
	add_to_battle_log("Initializing battle: " + mission.mission_name)

func _connect_signals() -> void:
	# System signals
	five_parcecs_system.phase_changed.connect(_on_phase_changed)
	five_parcecs_system.battle_started.connect(_on_battle_started)
	five_parcecs_system.battle_ended.connect(_on_battle_ended)
	five_parcecs_system.combat_effect_triggered.connect(_on_combat_effect)
	five_parcecs_system.reaction_opportunity.connect(_on_reaction_opportunity)
	
	# Battlefield signals
	battlefield.connect("tile_selected", _on_tile_selected)
	battlefield.connect("unit_selected", _on_unit_selected)
	
	# Preview signals
	if regenerate_button and "pressed" in regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	
	# Action buttons
	var action_buttons = $BattleLayout/MainContent/SidePanel/VBoxContainer/ActionPanel/VBoxContainer/ActionButtons
	if action_buttons:
		var buttons = {
			"MoveButton": GameEnums.UnitAction.MOVE,
			"AttackButton": GameEnums.UnitAction.ATTACK,
			"DashButton": GameEnums.UnitAction.DASH,
			"ItemsButton": GameEnums.UnitAction.USE_ITEM,
			"BrawlButton": GameEnums.UnitAction.BRAWL,
			"EndTurnButton": - 1
		}
		
		for button_name in buttons:
			var button = action_buttons.get_node_or_null(button_name)
			if button and "pressed" in button:
				if button_name == "EndTurnButton":
					button.pressed.connect(_on_end_turn_pressed)
				else:
					button.pressed.connect(_on_action_button_pressed.bind(buttons[button_name]))

func _on_battle_started() -> void:
	_update_ui()
	battlefield.initialize_battlefield()
	add_to_battle_log("Battle has begun!")

func _on_battle_ended(result: Dictionary) -> void:
	add_to_battle_log("Battle complete!")
	if result.has("victory"):
		add_to_battle_log("Result: " + ("Victory!" if result.victory else "Defeat..."))
	
	# Show post-battle summary
	_show_battle_summary(result)

func _initialize_battlefield_preview() -> void:
	if not current_mission:
		push_error("MainBattleController: No mission set for preview")
		return
	
	preview_panel.visible = true
	battlefield.initialize_preview(current_mission)
	_update_preview_info()

func _update_preview_info() -> void:
	var preview_info = $BattleLayout/MainContent/SidePanel/VBoxContainer/PreviewPanel/PreviewInfo
	var info_text = "[b]Mission Preview[/b]\n"
	info_text += "Type: " + GlobalEnums.MissionType.keys()[_get_mission_property(current_mission, "mission_type", GameEnums.MissionType.NONE)] + "\n"
	info_text += "Deployment: " + GlobalEnums.DeploymentType.keys()[_get_mission_property(current_mission, "deployment_type", GameEnums.DeploymentType.NONE)] + "\n"
	info_text += "Terrain: " + str(_get_mission_property(current_mission, "terrain_type", "Unknown")) + "\n"
	info_text += "Enemy Count: " + str(_get_mission_property(current_mission, "enemy_count", 0)) + "\n"
	info_text += "Difficulty: " + GlobalEnums.DifficultyLevel.keys()[_get_mission_property(current_mission, "difficulty", GameEnums.DifficultyLevel.NONE)] + "\n"
	info_text += "\n[b]Objectives:[/b]\n"
	
	var objectives = _get_mission_property(current_mission, "objectives", [])
	for objective in objectives:
		info_text += "- " + GlobalEnums.MissionObjective.keys()[objective.type] + "\n"
	
	preview_info.text = info_text

func _on_regenerate_pressed() -> void:
	if not current_mission:
		return
	
	battlefield.regenerate_preview(current_mission)
	add_to_battle_log("Regenerating battlefield layout...")

func start_battle() -> void:
	if not current_mission:
		push_error("MainBattleController: Cannot start battle without mission")
		return
	
	preview_panel.visible = false
	five_parcecs_system.start_battle(current_mission)
	_update_ui()
	add_to_battle_log("Battle started!")

func _on_phase_changed(new_phase: int) -> void:
	phase_label.text = "Phase: " + GameEnums.BattlePhase.keys()[new_phase]
	_update_ui()
	
	match new_phase:
		GameEnums.BattlePhase.SETUP:
			add_to_battle_log("Setting up battlefield...")
		GameEnums.BattlePhase.DEPLOYMENT:
			add_to_battle_log("Deployment phase - Position your units")
		GameEnums.BattlePhase.INITIATIVE:
			add_to_battle_log("Rolling for initiative...")
		GameEnums.BattlePhase.ACTIVATION:
			_handle_activation_phase()
		GameEnums.BattlePhase.REACTION:
			add_to_battle_log("Reaction phase")
		GameEnums.BattlePhase.CLEANUP:
			add_to_battle_log("Cleaning up turn effects")

func _handle_activation_phase() -> void:
	var active_unit = five_parcecs_system.current_battle_state.get("active_unit")
	if active_unit:
		add_to_battle_log(active_unit.name + "'s turn")
		_update_unit_info()
		_update_action_buttons()

func _on_combat_effect(effect_name: String, source: Node, target: Node) -> void:
	var message = ""
	if source:
		message += _get_character_name(source) + " "
	message += effect_name
	if target:
		message += " on " + _get_character_name(target)
	add_to_battle_log(message)

func _on_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void:
	add_to_battle_log(_get_character_name(unit) + " has reaction opportunity: " + reaction_type)
	# Show reaction UI
	_show_reaction_options(unit, reaction_type, source)

func _show_reaction_options(unit: Node, reaction_type: String, source: Node) -> void:
	# Implement reaction UI
	pass

func _on_tile_selected(grid_position: Vector2) -> void:
	if selected_action != -1 and selected_unit:
		var target_data = {"position": grid_position}
		_try_perform_action(target_data)

func _on_unit_selected(unit: Node) -> void:
	selected_unit = unit
	_update_unit_info()
	
	if selected_action != -1:
		var target_data = {"target": unit}
		_try_perform_action(target_data)

func _on_action_button_pressed(action: GameEnums.UnitAction) -> void:
	selected_action = action
	_update_ui()
	
	match action:
		GameEnums.UnitAction.MOVE:
			battlefield.show_movement_range(selected_unit)
		GameEnums.UnitAction.ATTACK:
			battlefield.show_attack_range(selected_unit)
		GameEnums.UnitAction.DASH:
			battlefield.show_movement_range(selected_unit)
		GameEnums.UnitAction.BRAWL:
			battlefield.show_brawl_range(selected_unit)
		GameEnums.UnitAction.USE_ITEM:
			# Show item selection UI
			pass

func _on_end_turn_pressed() -> void:
	if five_parcecs_system.current_phase == GameEnums.BattlePhase.ACTIVATION:
		five_parcecs_system.advance_phase()

func _try_perform_action(target_data: Dictionary) -> void:
	if five_parcecs_system.can_perform_action(selected_unit, selected_action):
		five_parcecs_system.perform_action(selected_unit, selected_action, target_data)
		selected_action = -1
		_update_ui()
	else:
		add_to_battle_log("Cannot perform that action")

func _update_ui() -> void:
	turn_label.text = "Turn: " + str(five_parcecs_system.current_turn)
	
	var active_unit = five_parcecs_system.active_unit
	active_unit_label.text = "Active Unit: " + (active_unit.name if active_unit else "None")
	
	# Update action panel visibility
	action_panel.visible = (five_parcecs_system.current_phase == GameEnums.BattlePhase.ACTIVATION and
						   active_unit == selected_unit)
	
	_update_unit_info()
	_update_action_buttons()

func _update_unit_info() -> void:
	if selected_unit:
		var stats_text = "[b]" + _get_character_name(selected_unit) + "[/b]\n"
		var health = _get_character_health(selected_unit)
		var stats = _get_character_stats(selected_unit)
		
		stats_text += "HP: " + str(health.current) + "/" + str(health.max) + "\n"
		stats_text += "Action Points: " + str(stats.action_points) + "\n"
		stats_text += "Combat: " + str(stats.combat) + "\n"
		stats_text += "Savvy: " + str(stats.savvy) + "\n"
		unit_stats.text = stats_text
	else:
		unit_stats.text = "Select a unit to view stats"

func _update_action_buttons() -> void:
	if not selected_unit or five_parcecs_system.current_phase != GameEnums.BattlePhase.ACTIVATION:
		return
		
	var buttons = $BattleLayout/MainContent/SidePanel/VBoxContainer/ActionPanel/VBoxContainer/ActionButtons
	
	for action in GameEnums.UnitAction.values():
		var button = buttons.get_node_or_null(GameEnums.UnitAction.keys()[action].capitalize() + "Button")
		if button:
			button.disabled = not five_parcecs_system.can_perform_action(selected_unit, action)

func add_to_battle_log(message: String) -> void:
	if not battle_log or not "text" in battle_log:
		push_error("Battle log missing or missing text property")
		return
		
	var timestamp = Time.get_time_string_from_system()
	battle_log.text += "\n[" + timestamp + "] " + message
	# Auto-scroll to bottom
	if "get_line_count" in battle_log:
		battle_log.scroll_to_line(battle_log.get_line_count() - 1)

func _show_battle_summary(result: Dictionary) -> void:
	# Implement battle summary UI
	pass

func _update_battle_info() -> void:
	if not current_mission:
		return
		
	var info_text = "Mission: " + _get_mission_property(current_mission, "mission_name", "Unknown") + "\n"
	info_text += "Type: " + GlobalEnums.MissionType.keys()[_get_mission_property(current_mission, "mission_type", GameEnums.MissionType.NONE)] + "\n"
	info_text += "Difficulty: " + GlobalEnums.DifficultyLevel.keys()[_get_mission_property(current_mission, "difficulty", GameEnums.DifficultyLevel.NONE)] + "\n"
	info_text += "Turn: " + str(five_parcecs_system.current_turn) + "\n"
	info_text += "Phase: " + GlobalEnums.BattlePhase.keys()[five_parcecs_system.current_phase] + "\n"
	
	if battle_info_label and "text" in battle_info_label:
		battle_info_label.text = info_text

## Safe Property Access Methods
func _get_character_name(character: Node) -> String:
	if not character or not "character_name" in character:
		push_error("Invalid character or missing character_name property")
		return "Unknown"
	return character.character_name

func _get_character_health(character: Node) -> Dictionary:
	var health_data := {"current": 0, "max": 0}
	if not character:
		push_error("Trying to access health of null character")
		return health_data
		
	health_data.current = character.current_hp if "current_hp" in character else 0
	health_data.max = character.max_hp if "max_hp" in character else 0
	return health_data

func _get_character_stats(character: Node) -> Dictionary:
	var stats := {
		"combat": 0,
		"savvy": 0,
		"action_points": 0
	}
	
	if not character:
		push_error("Trying to access stats of null character")
		return stats
		
	stats.combat = character.combat if "combat" in character else 0
	stats.savvy = character.savvy if "savvy" in character else 0
	stats.action_points = character.action_points if "action_points" in character else 0
	return stats

func _get_mission_property(mission: Mission, property: String, default_value = null) -> Variant:
	if not mission:
		push_error("Trying to access property '%s' on null mission" % property)
		return default_value
	if not property in mission:
		push_error("Mission missing required property: %s" % property)
		return default_value
	return mission.get(property)