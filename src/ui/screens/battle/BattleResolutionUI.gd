class_name BattleResolutionUI
extends Control

## Battle Resolution UI that handles combat according to Five Parsecs rules
## Provides both automated and tactical battle options

signal battle_completed(battle_result: BattleResult)
signal battle_fled()
signal back_to_pre_battle()

# UI nodes
@onready var battle_title: Label = $MainContainer/BattleTitle
@onready var mission_type_label: Label = $MainContainer/BattleInfo/MissionType
@onready var difficulty_label: Label = $MainContainer/BattleInfo/Difficulty
@onready var crew_list: VBoxContainer = $MainContainer/BattleContent/LeftPanel/CrewPanel/CrewList
@onready var enemy_list: VBoxContainer = $MainContainer/BattleContent/RightPanel/EnemyPanel/EnemyList
@onready var battle_log: RichTextLabel = $MainContainer/BattleContent/LeftPanel/BattleLogPanel/BattleLog
@onready var resolve_button: Button = $MainContainer/BattleContent/RightPanel/BattleActionsPanel/ActionButtons/ResolveBattle
@onready var tactical_button: Button = $MainContainer/BattleContent/RightPanel/BattleActionsPanel/ActionButtons/PlayTactically
@onready var flee_button: Button = $MainContainer/BattleContent/RightPanel/BattleActionsPanel/ActionButtons/FleeButton
@onready var back_button: Button = $MainContainer/BattleControls/BackButton
@onready var battle_status: Label = $MainContainer/BattleControls/BattleStatus
@onready var continue_button: Button = $MainContainer/BattleControls/ContinueButton
@onready var alpha_manager: Node = get_node_or_null("/root/FPCM_AlphaGameManager")
@onready var dice_manager: Node = get_node_or_null("/root/DiceManager")

# Battle data
var current_mission: Resource = null
var crew_members: Array[Resource] = []
var enemy_forces: Array[Resource] = []
var battle_result: BattleResult = null
var battle_in_progress: bool = false

class BattleResult:
	var victory: bool = false
	var crew_casualties: Array[Resource] = []
	var crew_injuries: Array[Resource] = []
	var _loot_found: Array[Resource] = []
	var credits_earned: int = 0
	var experience_gained: Array[Dictionary] = []

func _ready() -> void:
	_connect_signals()
	_setup_ui()

func _connect_signals() -> void:
	"""Connect all UI signals"""
	resolve_button.pressed.connect(_on_resolve_battle_automatically)
	tactical_button.pressed.connect(_on_play_tactical_battle)
	flee_button.pressed.connect(_on_attempt_flee)
	back_button.pressed.connect(_on_back_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

func _setup_ui() -> void:
	"""Initialize UI state"""
	battle_log.clear()
	continue_button.disabled = true
	_log_battle_message("Preparing for battle...", Color.YELLOW)

func setup_battle(mission: Resource, crew: Array[Resource], enemies: Array[Resource] = []) -> void:
	"""Setup battle with mission data, crew, and enemies"""
	current_mission = mission
	crew_members = crew.duplicate()

	# Generate enemies if not provided
	if enemies.is_empty() and alpha_manager:
		enemy_forces = alpha_manager.generate_enemies_for_mission(mission)
	else:
		enemy_forces = enemies.duplicate()

	_update_battle_info()
	_update_crew_display()
	_update_enemy_display()
	_log_battle_message("Battle setup complete. Choose your approach.", Color.GREEN)

func _update_battle_info() -> void:
	"""Update mission and difficulty display"""
	if current_mission:
		var mission_type = safe_get_property(current_mission, "mission_type", "Unknown")
		var difficulty = safe_get_property(current_mission, "difficulty", 1)
		mission_type_label.text = "Mission: " + str(mission_type)
		difficulty_label.text = "Difficulty: " + str(difficulty)
		battle_title.text = str(mission_type) + " Battle"

func _update_crew_display() -> void:
	"""Update crew member display"""
	# Clear existing crew display
	for child in crew_list.get_children():
		child.queue_free()

	# Add crew member cards
	for crew_member in crew_members:
		var crew_card = _create_crew_card(crew_member)
		crew_list.add_child(crew_card)

func _update_enemy_display() -> void:
	"""Update enemy forces display"""
	# Clear existing enemy display
	for child in enemy_list.get_children():
		child.queue_free()

	# Add enemy cards
	for enemy in enemy_forces:
		var enemy_card: Control = _create_enemy_card(enemy)
		enemy_list.add_child(enemy_card)

func _create_crew_card(crew_member: Resource) -> Control:
	"""Create a crew _member display card"""
	# Create a simple card for now - TODO: Create proper CharacterBattleCard
	var card := VBoxContainer.new()
	var name_label := Label.new()
	var character_name: Character = safe_get_property(crew_member, "character_name", "Unknown")
	name_label.text = str(character_name)
	card.add_child(name_label)
	var stats_label := Label.new()
	var combat_skill: Node = safe_get_property(crew_member, "combat_skill", 1)
	var toughness = safe_get_property(crew_member, "toughness", 3)
	stats_label.text = "Combat: %d, Toughness: %d" % [combat_skill, toughness]
	stats_label.add_theme_font_size_override("font_size", 10)
	card.add_child(stats_label)

	return card

func _create_enemy_card(enemy: Resource) -> Control:
	"""Create an enemy display card"""
	var card := VBoxContainer.new()
	var name_label := Label.new()
	var enemy_name: String = safe_get_property(enemy, "name", "Unknown Enemy")
	name_label.text = str(enemy_name)
	card.add_child(name_label)
	var stats_label := Label.new()
	var combat_skill: Node = safe_get_property(enemy, "combat_skill", 1)
	var toughness = safe_get_property(enemy, "toughness", 3)
	stats_label.text = "Combat: %d, Toughness: %d" % [combat_skill, toughness]
	stats_label.add_theme_font_size_override("font_size", 10)
	card.add_child(stats_label)

	return card

func _on_resolve_battle_automatically() -> void:
	"""Resolve battle automatically using Five Parsecs rules"""
	if battle_in_progress:
		return

	battle_in_progress = true
	_disable_battle_actions()
	_log_battle_message("Resolving battle automatically...", Color.CYAN)

	battle_result = _calculate_automatic_battle_result()
	_display_battle_results()

	battle_in_progress = false
	continue_button.disabled = false

func _on_play_tactical_battle() -> void:
	"""Switch to tactical battle mode"""
	_log_battle_message("Switching to tactical battle mode...", Color.CYAN)

	# Load tactical battle scene
	var tactical_scene = preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
	var tactical_battle: Node = tactical_scene.instantiate()

	# Initialize tactical battle with current data
	tactical_battle.initialize_battle(crew_members, enemy_forces, current_mission)

	# Connect signals
	tactical_battle.tactical_battle_completed.connect(_on_tactical_battle_completed)
	tactical_battle.return_to_battle_resolution.connect(_on_return_from_tactical)

	# Replace this scene with tactical battle
	get_parent().add_child(tactical_battle)
	visible = false

func _on_attempt_flee() -> void:
	"""Attempt to flee from battle"""
	_log_battle_message("Attempting to flee...", Color.ORANGE)

	# Roll for flee attempt using dice system
	var flee_roll = _roll_dice("Flee Attempt", "D6")
	_log_battle_message("Flee roll: %d" % flee_roll, Color.WHITE)

	if flee_roll >= 4: # Simple 50% chance for now
		_log_battle_message("Successfully fled the battle!", Color.GREEN)
		battle_fled.emit()
	else:
		_log_battle_message("Failed to flee! Must fight the battle.", Color.RED)
		flee_button.disabled = true

func _calculate_automatic_battle_result() -> BattleResult:
	"""Calculate battle result using simplified Five Parsecs rules"""
	var result := BattleResult.new()

	# Simplified battle resolution
	# TODO: Implement proper Five Parsecs battle resolution rules

	var crew_power = _calculate_crew_combat_power()
	var enemy_power: int = _calculate_enemy_combat_power()

	_log_battle_message("Crew combat power: %d" % crew_power, Color.WHITE)
	_log_battle_message("Enemy combat power: %d" % enemy_power, Color.WHITE)

	# Battle resolution using dice system
	var battle_roll: int = _roll_dice("Battle Resolution", "D6") + _roll_dice("Battle Resolution (2nd die)", "D6")
	var crew_advantage = crew_power - enemy_power
	var final_result = battle_roll + crew_advantage

	_log_battle_message("Battle roll: %d + %d advantage = %d" % [battle_roll, crew_advantage, final_result], Color.WHITE)

	if final_result >= 8:
		result.victory = true
		var reward_credits = safe_get_property(current_mission, "reward_credits", 500)
		result.credits_earned = reward_credits
		_log_battle_message("Victory! Battle won!", Color.GREEN)
	else:
		result.victory = false
		_calculate_battle_casualties(result)
		_log_battle_message("Defeat! Battle lost.", Color.RED)

	return result

func _calculate_crew_combat_power() -> int:
	"""Calculate total crew combat effectiveness"""
	var total_power: int = 0
	for crew_member in crew_members:
		var combat_skill: int = crew_member.combat_skill if crew_member.has("combat_skill") else 1
		var equipment_bonus: int = 1 # TODO: Calculate from equipment
		total_power += combat_skill + equipment_bonus

	return total_power

func _calculate_enemy_combat_power() -> int:
	"""Calculate total enemy combat effectiveness"""
	var total_power: int = 0

	for enemy in enemy_forces:
		var combat_skill: int = safe_get_property(enemy, "combat_skill", 1)
		total_power += combat_skill

	return total_power

func _calculate_battle_casualties(result: BattleResult) -> void:
	"""Calculate casualties from a lost battle"""
	# Simple casualty calculation using dice system
	for crew_member in crew_members:
		var character_name: String = safe_get_property(crew_member, "character_name", "Crew member")
		var casualty_roll = _roll_dice("Injury Check - " + str(character_name), "D6")
		if casualty_roll <= 2:
			result.crew_injuries.append(crew_member)
			_log_battle_message("%s was injured! (rolled %d)" % [character_name, casualty_roll], Color.ORANGE)

func _display_battle_results() -> void:
	"""Display the final battle results"""
	if battle_result.victory:
		battle_status.text = "Victory! Credits earned: %d" % battle_result.credits_earned
		_log_battle_message("Battle completed successfully!", Color.GREEN)
	else:
		battle_status.text = "Defeat! %d crew members injured." % battle_result.crew_injuries.size()
		_log_battle_message("Battle ended in defeat.", Color.RED)

func _disable_battle_actions() -> void:
	"""Disable battle action buttons during resolution"""
	resolve_button.disabled = true
	tactical_button.disabled = true
	flee_button.disabled = true

func _log_battle_message(message: String, color: Color = Color.WHITE) -> void:
	"""Add a message to the battle log"""
	var timestamp: String = "[%s] " % Time.get_datetime_string_from_system().split(" ")[1]
	var colored_message: String = "[color=%s]%s%s[/color]" % [color.to_html(), timestamp, message]
	battle_log.append_text(colored_message + "\n")

func _on_back_pressed() -> void:
	"""Return to pre-battle phase"""
	back_to_pre_battle.emit()

func _on_continue_pressed() -> void:
	"""Continue to post-battle phase"""
	if battle_result:
		battle_completed.emit(battle_result) # warning: return value discarded (intentional)

func get_battle_result() -> BattleResult:
	"""Get the current battle result"""
	return battle_result

func is_battle_complete() -> bool:
	"""Check if battle is complete"""
	return battle_result != null

func _roll_dice(context: String, pattern: String) -> int:
	"""Roll dice using the dice system with proper context"""
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		# Fallback to basic random if dice system unavailable
		match pattern:
			"D6":
				return randi_range(1, 6)
			"D10":
				return randi_range(1, 10)
			"D66":
				return randi_range(1, 6) * 10 + randi_range(1, 6)
			"D100":
				return randi_range(1, 100)
			_:
				return randi_range(1, 6)

func _on_tactical_battle_completed(tactical_result: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	_log_battle_message("Tactical battle completed!", Color.GREEN)

	# Convert tactical _result to battle _result
	battle_result = BattleResult.new()
	battle_result.victory = tactical_result.victory
	battle_result.crew_casualties = tactical_result.crew_casualties
	battle_result.crew_injuries = tactical_result.crew_injuries
	battle_result.credits_earned = tactical_result.credits_earned
	battle_result.experience_gained = tactical_result.experience_gained

	# Show results
	_display_battle_results()

	# Return to normal UI
	visible = true
	battle_in_progress = false
	continue_button.disabled = false

func _on_return_from_tactical() -> void:
	"""Handle return from tactical battle without completion"""
	_log_battle_message("Returned from tactical mode", Color.YELLOW)
	visible = true

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
	return null