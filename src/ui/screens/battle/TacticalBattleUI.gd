class_name FPCM_TacticalBattleUI
extends Control

## Tactical Battle UI - Five Parsecs Positioning and Movement
##
## Provides tactical turn-based combat with:
	## - Grid-based positioning system
## - Line of sight calculation
## - Cover and elevation mechanics
## - Five Parsecs combat rules
## - Dice integration for all rolls

signal tactical_battle_completed(battle_result: BattleResult)
signal return_to_battle_resolution()

const BattlefieldDisplayManager = preload("res://src/core/battle/BattlefieldDisplayManager.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# UI Nodes
@onready var battlefield_display: Control = $MainContainer/BattlefieldArea/BattlefieldDisplay
@onready var action_panel: Control = $MainContainer/ActionPanel
@onready var turn_indicator: Label = $MainContainer/ActionPanel/TurnIndicator
@onready var selected_unit_info: Control = $MainContainer/ActionPanel/UnitInfo
@onready var action_buttons: VBoxContainer = $MainContainer/ActionPanel/ActionButtons
@onready var battle_log: RichTextLabel = $MainContainer/ActionPanel/BattleLog
@onready var end_turn_button: Button = $MainContainer/ActionPanel/EndTurnButton
@onready var return_button: Button = $MainContainer/TopBar/ReturnButton
@onready var auto_resolve_button: Button = $MainContainer/TopBar/AutoResolveButton

# Core Systems
var battlefield_manager: BattlefieldManager
var battlefield_display_manager: BattlefieldDisplayManager
var dice_manager: Node = null
var alpha_manager: Node = null

# Battle State
var crew_units: Array[TacticalUnit] = []
var enemy_units: Array[TacticalUnit] = []
var all_units: Array[TacticalUnit] = []
var current_turn: int = 0
var current_unit_index: int = 0
var selected_unit: TacticalUnit = null
var battle_phase: String = "deployment" # deployment, combat, resolution
var turn_phase: String = "movement" # movement, action, resolution

# Grid and positioning
var grid_size: Vector2i = Vector2i(20, 20)
var _cell_size: int = 32
var deployment_zones: Dictionary = {}

# Battle Result
class BattleResult:
	var victory: bool = false
	var crew_casualties: Array[Resource] = []
	var crew_injuries: Array[Resource] = []
	var _loot_found: Array[Resource] = []
	var _credits_earned: int = 0
	var _experience_gained: Array[Dictionary] = []
	var rounds_fought: int = 0

func _ready() -> void:
	_initialize_managers()
	_setup_battlefield()
	_connect_signals()
	_setup_ui()

func _initialize_managers() -> void:
	"""Initialize manager references"""
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null

	# Create battlefield systems
	battlefield_manager = BattlefieldManager.new()
	add_child(battlefield_manager)

	# Create display manager - needs to be a proper Node type
	battlefield_display_manager = BattlefieldDisplayManager.new()
	# Note: Add to scene if BattlefieldDisplayManager extends Node
	# For now, keep it as a separate object for data management

func _setup_battlefield() -> void:
	"""Setup the tactical battlefield"""
	battlefield_manager.battlefield_width = grid_size.x
	battlefield_manager.battlefield_height = grid_size.y
	battlefield_manager._setup_battlefield()

	# Generate terrain and cover
	_generate_battlefield_terrain()
	_setup_deployment_zones()

func _generate_battlefield_terrain() -> void:
	"""Generate terrain using Five Parsecs rules"""
	# Use dice to determine terrain features
	var terrain_roll = _roll_dice("Terrain Generation", "D6")
	var num_features = terrain_roll + 2 # 3-8 terrain features

	_log_message("Generating battlefield with %d terrain features..." % num_features, Color.CYAN)

	for i: int in range(num_features):
		var x = randi_range(2, grid_size.x - 3)
		var y = randi_range(2, grid_size.y - 3)
		var feature_type = _roll_dice("Terrain Type", "D6")

		match feature_type:
			1, 2: # Cover (walls, rocks)
				_place_cover_feature(x, y)
			3, 4: # Elevation (hills, platforms)
				_place_elevation_feature(x, y)
			5: # Difficult terrain (debris, mud)
				_place_difficult_terrain(x, y)
			6: # Special feature (determined by mission)
				_place_special_feature(x, y)

func _place_cover_feature(x: int, y: int) -> void:
	"""Place a cover feature on the battlefield"""
	# Create L-shaped or straight cover
	var cover_pattern = _roll_dice("Cover Pattern", "D6")
	var positions: Array = []

	match cover_pattern:
		1, 2, 3: # Straight line (horizontal)
			for i: int in range(3):
				if x + i < grid_size.x:
					positions.append(Vector2i(x + i, y))
		4, 5: # Straight line (vertical)
			for i: int in range(3):
				if y + i < grid_size.y:
					positions.append(Vector2i(x, y + i))
		6: # L-shape
			positions.append(Vector2i(x, y))
			positions.append(Vector2i(x + 1, y))
			positions.append(Vector2i(x, y + 1))

	for pos in positions:
		if _is_valid_position(pos):
			battlefield_manager.cover_map[pos.x][pos.y] = 2 # Full cover

func _place_elevation_feature(x: int, y: int) -> void:
	"""Place an elevation feature"""
	var size = _roll_dice("Elevation Size", "D6")
	var elevation_value: int = 1 if size <= 3 else 2

	# Create small elevated area
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var pos = Vector2i(x + dx, y + dy)
			if _is_valid_position(pos):
				battlefield_manager.elevation_map[pos.x][pos.y] = elevation_value

func _place_difficult_terrain(x: int, y: int) -> void:
	"""Place difficult terrain"""
	# Mark area as difficult terrain (movement cost x2)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var pos = Vector2i(x + dx, y + dy)
			if _is_valid_position(pos):
				battlefield_manager.terrain_map[pos.x][pos.y] = TerrainTypes.Type.DIFFICULT

func _place_special_feature(x: int, y: int) -> void:
	"""Place mission-specific special feature"""
	# Could be objectives, spawn points, etc.
	var pos = Vector2i(x, y)
	if _is_valid_position(pos):
		battlefield_manager.terrain_map[pos.x][pos.y] = TerrainTypes.Type.HAZARD # Use HAZARD for special features
		_log_message("Special feature placed at (%d, %d)" % [x, y], Color.YELLOW)

func _setup_deployment_zones() -> void:
	"""Setup deployment zones for crew and enemies"""
	# Crew deploys on left side
	deployment_zones["crew"] = []
	for x: int in range(0, 4):
		for y: int in range(grid_size.y):
			deployment_zones["crew"].append(Vector2i(x, y))

	# Enemies deploy on right side
	deployment_zones["enemies"] = []
	for x: int in range(grid_size.x - 4, grid_size.x):
		for y: int in range(grid_size.y):
			deployment_zones["enemies"].append(Vector2i(x, y))

func _connect_signals() -> void:
	"""Connect UI and system signals"""
	end_turn_button.pressed.connect(_on_end_turn)
	return_button.pressed.connect(_on_return_to_battle_resolution)
	auto_resolve_button.pressed.connect(_on_auto_resolve_battle)

	# Battlefield signals
	if battlefield_manager:
		battlefield_manager.terrain_updated.connect(_on_terrain_updated)
		battlefield_manager.cover_updated.connect(_on_cover_updated)

func _setup_ui() -> void:
	"""Setup the tactical UI"""
	turn_indicator.text = "Deployment Phase"
	battle_log.clear()
	_log_message("Tactical battle mode activated", Color.GREEN)
	_log_message("Deploy your crew in the western deployment zone", Color.CYAN)

## Initialize tactical battle with crew and enemies

func initialize_battle(crew_members: Array[Resource], enemies: Array[Resource], mission_data: Resource = null) -> void:
	"""Initialize the tactical battle"""
	_log_message("Initializing tactical battle...", Color.CYAN)

	# Create tactical units from crew
	for crew_member in crew_members:
		var unit := TacticalUnit.new()
		unit.initialize_from_crew_member(crew_member)
		unit.team = "crew"
		crew_units.append(unit)
		all_units.append(unit)

	# Create tactical units from enemies
	for enemy in enemies:
		var unit := TacticalUnit.new()
		unit.initialize_from_enemy(enemy)
		unit.team = "enemy"
		enemy_units.append(unit)
		all_units.append(unit)

	_log_message("Battle initialized: %d crew vs %d enemies" % [crew_units.size(), enemy_units.size()], Color.WHITE)

	# Start deployment phase
	_start_deployment_phase()

func _start_deployment_phase() -> void:
	"""Start the deployment phase"""
	battle_phase = "deployment"
	turn_indicator.text = "Deployment Phase - Place your crew"
	_log_message("Place your crew members in the deployment zone", Color.CYAN)

	# Enable deployment UI
	_update_action_buttons_for_deployment()

func _start_combat_phase() -> void:
	"""Start the main combat phase"""
	battle_phase = "combat"
	current_turn = 1
	current_unit_index = 0

	# Roll for initiative order
	_determine_initiative_order()

	turn_indicator.text = "Combat Round %d" % current_turn
	_log_message("Combat begins! Round %d" % current_turn, Color.RED)

	_start_unit_turn()

func _determine_initiative_order() -> void:
	"""Determine turn order using Five Parsecs initiative rules"""
	_log_message("Rolling for initiative...", Color.YELLOW)

	# Each unit rolls for initiative
	for unit in all_units:
		unit.initiative_roll = _roll_dice("Initiative: " + unit.name, "D6") + unit.get_initiative_bonus()
		_log_message("%s initiative: %d" % [unit.name, unit.initiative_roll], Color.WHITE)

	# Sort by initiative (highest first)
	all_units.sort_custom(func(a, b): return a.initiative_roll > b.initiative_roll)

func _start_unit_turn() -> void:
	"""Start a unit's turn"""
	if current_unit_index >= all_units.size():
		_end_combat_round()
		return

	selected_unit = all_units[current_unit_index]
	selected_unit.actions_remaining = selected_unit.max_actions
	selected_unit.movement_remaining = selected_unit.movement_points

	turn_phase = "movement"
	turn_indicator.text = "Round %d - %s's Turn" % [current_turn, selected_unit.name]
	_log_message("%s's turn begins" % selected_unit.name, Color.CYAN)

	_update_action_buttons_for_combat()
	_update_unit_info_display()

func _update_action_buttons_for_deployment() -> void:
	"""Update action buttons for deployment phase"""
	_clear_action_buttons()

	# Add deployment-specific buttons
	var place_unit_button := Button.new()
	place_unit_button.text = "Place Unit"
	place_unit_button.pressed.connect(_on_place_unit_clicked)
	action_buttons.add_child(place_unit_button)

	var auto_deploy_button := Button.new()
	auto_deploy_button.text = "Auto Deploy"
	auto_deploy_button.pressed.connect(_on_auto_deploy_clicked)
	action_buttons.add_child(auto_deploy_button)

func _update_action_buttons_for_combat() -> void:
	"""Update action buttons for combat phase"""
	_clear_action_buttons()

	if not selected_unit or selected_unit.team != "crew":
		return # Only show actions for crew units

	# Movement
	if selected_unit.movement_remaining > 0:
		var move_button := Button.new()
		move_button.text = "Move (%d left)" % selected_unit.movement_remaining
		move_button.pressed.connect(_on_move_clicked)
		action_buttons.add_child(move_button)

	# Shooting
	if selected_unit.actions_remaining > 0:
		var shoot_button := Button.new()
		shoot_button.text = "Shoot"
		shoot_button.pressed.connect(_on_shoot_clicked)
		action_buttons.add_child(shoot_button)

	# Dash (extra movement)
	if selected_unit.actions_remaining > 0:
		var dash_button := Button.new()
		dash_button.text = "Dash"
		dash_button.pressed.connect(_on_dash_clicked)
		action_buttons.add_child(dash_button)

	# Skip turn
	var skip_button := Button.new()
	skip_button.text = "End Turn"
	skip_button.pressed.connect(_on_skip_turn_clicked)
	action_buttons.add_child(skip_button)

func _clear_action_buttons() -> void:
	"""Clear all action buttons"""
	for child in action_buttons.get_children():
		child.queue_free()

func _update_unit_info_display() -> void:
	"""Update the selected unit info display"""
	if not selected_unit:
		return

	# Update unit info panel
	# This would show stats, health, equipment, etc.
	_log_message("Selected: %s (Team: %s)" % [selected_unit.name, selected_unit.team], Color.YELLOW)

# Action handlers
func _on_move_clicked() -> void:
	"""Handle move action"""
	_log_message("%s is moving..." % selected_unit.name, Color.CYAN)
	# TODO: Implement movement selection UI

func _on_shoot_clicked() -> void:
	"""Handle shoot action"""
	_log_message("%s is shooting..." % selected_unit.name, Color.RED)
	# TODO: Implement target selection and shooting

func _on_dash_clicked() -> void:
	"""Handle dash action (extra movement)"""
	selected_unit.movement_remaining += selected_unit.movement_points
	selected_unit.actions_remaining -= 1
	_log_message("%s dashes forward!" % selected_unit.name, Color.YELLOW)
	_update_action_buttons_for_combat()

func _on_skip_turn_clicked() -> void:
	"""Skip the current unit's turn"""
	_log_message("%s ends their turn" % selected_unit.name, Color.GRAY)
	_end_unit_turn()

func _on_place_unit_clicked() -> void:
	"""Handle unit placement in deployment"""
	_log_message("Click on the deployment zone to place units", Color.CYAN)

func _on_auto_deploy_clicked() -> void:
	"""Auto-deploy all crew units"""
	_log_message("Auto-deploying crew members...", Color.CYAN)

	var crew_positions = deployment_zones["crew"].duplicate()
	crew_positions.shuffle()

	for i: int in range(min(crew_units.size(), crew_positions.size())):
		crew_units[i].position = crew_positions[i]
		_log_message("%s deployed at (%d, %d)" % [crew_units[i].name, crew_positions[i].x, crew_positions[i].y], Color.WHITE)

	# Auto-deploy enemies too
	_auto_deploy_enemies()

	# Start combat
	_start_combat_phase()

func _auto_deploy_enemies() -> void:
	"""Auto-deploy enemy units"""
	var enemy_positions: Array[Character] = deployment_zones["enemies"].duplicate()
	enemy_positions.shuffle()

	for i: int in range(min(enemy_units.size(), enemy_positions.size())):
		enemy_units[i].position = enemy_positions[i]
		_log_message("%s deployed at (%d, %d)" % [enemy_units[i].name, enemy_positions[i].x, enemy_positions[i].y], Color.WHITE)

func _end_unit_turn() -> void:
	"""End the current unit's turn"""
	current_unit_index += 1
	_start_unit_turn()

func _end_combat_round() -> void:
	"""End the current combat round"""
	current_turn += 1
	current_unit_index = 0

	_log_message("Round %d complete" % (current_turn - 1), Color.YELLOW)

	# Check victory conditions
	if _check_victory_conditions():
		_resolve_battle()
	else:
		_start_unit_turn()

func _check_victory_conditions() -> bool:
	"""Check if battle should end"""
	var crew_alive = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive = enemy_units.filter(func(u): return u.health > 0).size()

	return crew_alive == 0 or enemies_alive == 0 or current_turn > 20 # Max 20 rounds

func _resolve_battle() -> void:
	"""Resolve the tactical battle"""
	battle_phase = "resolution"

	var crew_alive = crew_units.filter(func(u): return u.health > 0).size()
	var enemies_alive = enemy_units.filter(func(u): return u.health > 0).size()

	var result := BattleResult.new()
	result.rounds_fought = current_turn - 1

	if crew_alive > 0 and enemies_alive == 0:
		result.victory = true
		_log_message("Victory! All enemies defeated!", Color.GREEN)
	elif crew_alive == 0:
		result.victory = false
		_log_message("Defeat! All crew members down!", Color.RED)
	else:
		# Stalemate or time limit
		result.victory = crew_alive > enemies_alive
		_log_message("Battle concluded after %d rounds" % result.rounds_fought, Color.YELLOW)

	# Calculate casualties and injuries
	for unit in crew_units:
		if unit.health <= 0:
			if unit.is_dead:
				result.crew_casualties.append(unit.original_character)
			else:
				result.crew_injuries.append(unit.original_character)

	tactical_battle_completed.emit(result)

func _on_end_turn() -> void:
	"""Handle end turn button"""
	if battle_phase == "combat":
		_end_unit_turn()

func _on_return_to_battle_resolution() -> void:
	"""Return to battle resolution UI"""
	return_to_battle_resolution.emit() # warning: return value discarded (intentional)

func _on_auto_resolve_battle() -> void:
	"""Auto-resolve the remaining battle"""
	_log_message("Auto-resolving battle...", Color.ORANGE)
	# TODO: Use existing battle resolution system
	var result := BattleResult.new()
	result.victory = true # Simplified for now
	tactical_battle_completed.emit(result) # warning: return value discarded (intentional)

func _on_terrain_updated(position: Vector2, terrain_type: int) -> void:
	"""Handle terrain updates"""
	# Update visual display
	pass

func _on_cover_updated(position: Vector2, cover_value: int) -> void:
	"""Handle cover updates"""
	# Update visual display
	pass

## Utility functions

func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is valid on battlefield"""
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func _roll_dice(context: String, pattern: String) -> int:
	"""Roll dice using the dice system"""
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		match pattern:
			"D6": return randi_range(1, 6)
			"D10": return randi_range(1, 10)
			_: return randi_range(1, 6)

func _log_message(message: String, color: Color = Color.WHITE) -> void:
	"""Log a message to the battle log"""
	var timestamp: String = "[%02d:%02d] " % [current_turn, current_unit_index]
	battle_log.append_text("[color=%s]%s%s[/color]\n" % [color.to_html(), timestamp, message])
	battle_log.scroll_to_line(battle_log.get_line_count())

## Tactical Unit Class

class TacticalUnit:
	var node_name: String = ""
	var team: String = "" # "crew" or "enemy"
	var node_position: Vector2i = Vector2i(-1, -1)
	var health: int = 3
	var max_health: int = 3
	var is_dead: bool = false
	var movement_points: int = 6
	var movement_remaining: int = 6
	var max_actions: int = 2
	var actions_remaining: int = 2
	var initiative_roll: int = 0
	var original_character: Resource = null

	# Combat stats
	var combat_skill: int = 0
	var toughness: int = 0
	var savvy: int = 0
	var reactions: int = 0

	# Equipment
	var _weapon_range: int = 12
	var _weapon_shots: int = 1
	var _weapon_damage: int = 1
	var _armor_save: int = 0

	func initialize_from_crew_member(crew_member: Resource) -> void:
		"""Initialize unit from crew member data"""
		original_character = crew_member
		var name: String = crew_member.character_name if crew_member.has_method("character_name") else "Crew Member"

		# Extract stats if available
		combat_skill = crew_member.combat_skill if crew_member.has_method("combat_skill") else 0
		toughness = crew_member.toughness if crew_member.has_method("toughness") else 0
		savvy = crew_member.savvy if crew_member.has_method("savvy") else 0
		reactions = crew_member.reactions if crew_member.has_method("reactions") else 0

		# Set health based on toughness
		max_health = max(1, toughness)
		health = max_health

	func initialize_from_enemy(enemy: Resource) -> void:
		"""Initialize unit from enemy data"""
		original_character = enemy
		var name: String = enemy.name if enemy.has_method("name") else "Enemy"

		# Extract enemy stats
		var combat_skill: int = enemy.combat_skill if enemy.has_method("combat_skill") else 0
		var toughness: int = enemy.toughness if enemy.has_method("toughness") else 0
		var reactions: int = enemy.reactions if enemy.has_method("reactions") else 0

		max_health = max(1, toughness)
		health = max_health

	func get_initiative_bonus() -> int:
		"""Get initiative bonus based on reactions"""
		return reactions

	func take_damage(amount: int) -> void:
		"""Apply damage to the unit"""
		health = max(0, health - amount)
		if health <= 0:
			is_dead = true

	func can_act() -> bool:
		"""Check if unit can take actions"""
		return health > 0 and actions_remaining > 0

	func can_move() -> bool:
		"""Check if unit can move"""
		return health > 0 and movement_remaining > 0
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null    