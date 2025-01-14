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
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	
	# Action buttons
	var action_buttons = $BattleLayout/MainContent/SidePanel/VBoxContainer/ActionPanel/VBoxContainer/ActionButtons
	action_buttons.get_node("MoveButton").pressed.connect(_on_action_button_pressed.bind(GameEnums.UnitAction.MOVE))
	action_buttons.get_node("AttackButton").pressed.connect(_on_action_button_pressed.bind(GameEnums.UnitAction.ATTACK))
	action_buttons.get_node("DashButton").pressed.connect(_on_action_button_pressed.bind(GameEnums.UnitAction.DASH))
	action_buttons.get_node("ItemsButton").pressed.connect(_on_action_button_pressed.bind(GameEnums.UnitAction.ITEMS))
	action_buttons.get_node("BrawlButton").pressed.connect(_on_action_button_pressed.bind(GameEnums.UnitAction.BRAWL))
	action_buttons.get_node("EndTurnButton").pressed.connect(_on_end_turn_pressed)

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
	info_text += "Type: " + GlobalEnums.MissionType.keys()[mission_type] + "\n"
	info_text += "Deployment: " + GlobalEnums.DeploymentType.keys()[deployment_type] + "\n"
	info_text += "Terrain: " + current_mission.terrain_type + "\n"
	info_text += "Enemy Count: " + str(current_mission.enemy_count) + "\n"
	info_text += "Difficulty: " + GlobalEnums.DifficultyLevel.keys()[current_mission.difficulty] + "\n"
	info_text += "\n[b]Objectives:[/b]\n"
	
	for objective in current_mission.objectives:
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
		message += source.name + " "
	message += effect_name
	if target:
		message += " on " + target.name
	add_to_battle_log(message)

func _on_reaction_opportunity(unit: Node, reaction_type: String, source: Node) -> void:
	add_to_battle_log(unit.name + " has reaction opportunity: " + reaction_type)
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
		GameEnums.UnitAction.MOVE, GameEnums.UnitAction.DASH:
			battlefield.show_movement_range(selected_unit)
		GameEnums.UnitAction.ATTACK:
			battlefield.show_attack_range(selected_unit)
		GameEnums.UnitAction.BRAWL:
			battlefield.show_brawl_range(selected_unit)

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
		var stats_text = "[b]" + selected_unit.name + "[/b]\n"
		stats_text += "HP: " + str(selected_unit.current_hp) + "/" + str(selected_unit.max_hp) + "\n"
		stats_text += "Action Points: " + str(selected_unit.action_points) + "\n"
		stats_text += "Combat: " + str(selected_unit.combat) + "\n"
		stats_text += "Savvy: " + str(selected_unit.savvy) + "\n"
		unit_stats.text = stats_text
	else:
		unit_stats.text = "Select a unit to view stats"

func _update_action_buttons() -> void:
	if not selected_unit or five_parcecs_system.current_phase != GameEnums.BattlePhase.ACTIVATION:
		return
		
	var buttons = $BattleLayout/MainContent/SidePanel/VBoxContainer/ActionPanel/VBoxContainer/ActionButtons
	
	for action in GameEnums.UnitAction.values():
		var button = buttons.get_node(GameEnums.UnitAction.keys()[action].capitalize() + "Button")
		if button:
			button.disabled = not five_parcecs_system.can_perform_action(selected_unit, action)

func add_to_battle_log(message: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	battle_log.text += "\n[" + timestamp + "] " + message
	# Auto-scroll to bottom
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)

func _show_battle_summary(result: Dictionary) -> void:
	# Implement battle summary UI
	pass

func _update_battle_info() -> void:
	var info_text = "Mission: " + current_mission.mission_name + "\n"
	info_text += "Type: " + GlobalEnums.MissionType.keys()[current_mission.mission_type] + "\n"
	info_text += "Difficulty: " + GlobalEnums.DifficultyLevel.keys()[current_mission.difficulty] + "\n"
	info_text += "Turn: " + str(five_parcecs_system.current_turn) + "\n"
	info_text += "Phase: " + GlobalEnums.BattlePhase.keys()[five_parcecs_system.current_phase] + "\n"
	
	battle_info_label.text = info_text