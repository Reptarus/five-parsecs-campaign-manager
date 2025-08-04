class_name FPCM_BattleResolutionUI
extends Control

## Enhanced Battle Resolution UI for Five Parsecs Campaign Manager
## Handles combat according to Five Parsecs rules with modern architecture
## Provides both automated and tactical battle options
## Integrates with FPCM_BattleManager and DiceSystem for consistent experience

# Enhanced signals for battle manager integration
signal battle_completed(battle_result: FPCM_BattleManager.BattleResult)
signal battle_fled()
signal back_to_pre_battle()
signal phase_completed() # For battle manager integration
signal dice_roll_requested(pattern: String, context: String)
signal ui_error_occurred(error: String, context: Dictionary)

# Dependencies - following modernized pattern
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

# Type alias for easier usage
const BattleResult = FPCM_BattleManager.BattleResult

## Battle Resolution UI for Five Parsecs
##
## Handles battle setup, combat resolution, and result display

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

# Battle results panel elements
@onready var battle_results_panel: Panel = $BattleResultsPanel
@onready var victory_value_label: Label = $BattleResultsPanel/ResultsContainer/VictoryStatus/VictoryValue
@onready var casualties_label: Label = $BattleResultsPanel/ResultsContainer/ResultsContent/LeftResults/CrewSection/CrewResults/CasualtiesLabel
@onready var injuries_label: Label = $BattleResultsPanel/ResultsContainer/ResultsContent/LeftResults/CrewSection/CrewResults/InjuriesLabel
@onready var crew_status_list: ItemList = $BattleResultsPanel/ResultsContainer/ResultsContent/LeftResults/CrewSection/CrewResults/CrewStatusList
@onready var credits_label: Label = $BattleResultsPanel/ResultsContainer/ResultsContent/RightResults/RewardsSection/RewardsResults/CreditsLabel
@onready var story_points_label: Label = $BattleResultsPanel/ResultsContainer/ResultsContent/RightResults/RewardsSection/RewardsResults/StoryPointsLabel
@onready var experience_label: Label = $BattleResultsPanel/ResultsContainer/ResultsContent/RightResults/RewardsSection/RewardsResults/ExperienceLabel
@onready var loot_list: ItemList = $BattleResultsPanel/ResultsContainer/ResultsContent/RightResults/LootSection/LootList
@onready var duration_label: Label = $BattleResultsPanel/ResultsContainer/BattleStatsSection/BattleStats/DurationLabel
@onready var events_label: Label = $BattleResultsPanel/ResultsContainer/BattleStatsSection/BattleStats/EventsLabel
@onready var close_results_button: Button = $BattleResultsPanel/ResultsContainer/ResultsButtons/CloseResultsButton
@onready var continue_from_results_button: Button = $BattleResultsPanel/ResultsContainer/ResultsButtons/ContinueFromResultsButton

# Enhanced system references
var battle_manager: FPCM_BattleManager = null
var dice_system: FPCM_DiceSystem = null
var battle_state: FPCM_BattleState = null

# Battle data - modernized with strict typing
var current_mission: Resource = null
var crew_members: Array[Resource] = []
var enemy_forces: Array[Resource] = []
var battle_result: FPCM_BattleManager.BattleResult = null
var battle_in_progress: bool = false


func _ready() -> void:
	_initialize_systems()
	_connect_signals()
	_setup_ui()

func _initialize_systems() -> void:
	"""Initialize modern battle systems"""
	# Initialize dice system
	dice_system = FPCM_DiceSystem.new()
	dice_system.dice_rolled.connect(_on_dice_rolled)
	
	# Initialize battle manager if not provided externally
	if not battle_manager:
		battle_manager = FPCM_BattleManager.new()
		battle_manager.register_ui_component("BattleResolutionUI", self)

func _connect_signals() -> void:
	"""Connect all UI signals"""
	resolve_button.pressed.connect(_on_resolve_battle_automatically)
	tactical_button.pressed.connect(_on_play_tactical_battle)
	flee_button.pressed.connect(_on_attempt_flee)
	back_button.pressed.connect(_on_back_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect battle results panel signals
	close_results_button.pressed.connect(_on_close_results_pressed)
	continue_from_results_button.pressed.connect(_on_continue_from_results_pressed)

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

func _generate_battle_loot(decisive_victory: bool) -> Array[String]:
	"""Generate loot found after battle using Five Parsecs loot tables"""
	var loot_found: Array[String] = []
	
	# Five Parsecs loot generation (Core Rules p.74-75)
	var loot_roll = _roll_dice("Loot Generation", "D100")
	
	if decisive_victory:
		loot_roll += 20 # Bonus for decisive victory
	
	if loot_roll >= 80:
		loot_found.append("Military Rifle")
		_log_battle_message("Found military-grade weapon!", Color.CYAN)
	elif loot_roll >= 60:
		loot_found.append("Combat Armor")
		_log_battle_message("Found protective equipment!", Color.CYAN)
	elif loot_roll >= 40:
		loot_found.append("Credits (" + str(_roll_dice("Bonus Credits", "D6") * 50) + ")")
		_log_battle_message("Found additional credits!", Color.CYAN)
	elif loot_roll >= 20:
		loot_found.append("Medical Supplies")
		_log_battle_message("Found medical equipment!", Color.CYAN)
	
	return loot_found

func _process_post_battle_procedures() -> void:
	"""Process Five Parsecs post-battle procedures"""
	# Story Point generation
	if battle_result.victory:
		_log_battle_message("Earned %d Story Point(s) for victory!" % battle_result.story_points, Color.BLUE)
	
	# Experience gain for crew
	for crew_member in crew_members:
		if not battle_result.crew_casualties.has(crew_member):
			var character_name: String = safe_get_property(crew_member, "character_name", "Crew member")
			_log_battle_message("%s gained combat experience!" % character_name, Color.BLUE)
	
	# Mission completion bonuses
	if current_mission:
		var mission_bonus = safe_get_property(current_mission, "completion_bonus", 0)
		if mission_bonus > 0:
			battle_result.credits_earned += mission_bonus
			_log_battle_message("Mission completion bonus: %d credits" % mission_bonus, Color.GREEN)

func _on_resolve_battle_automatically() -> void:
	"""Resolve battle automatically using Five Parsecs rules"""
	if battle_in_progress:
		return

	battle_in_progress = true
	_disable_battle_actions()
	_log_battle_message("Resolving battle automatically...", Color.CYAN)

	battle_result = _calculate_automatic_battle_result()
	_display_comprehensive_battle_results() # Use comprehensive display instead of simple one

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
			result.crew_casualties.append(crew_member)
			_log_battle_message("%s was injured! (rolled %d)" % [character_name, casualty_roll], Color.ORANGE)

func _display_battle_results() -> void:
	"""Display the final battle results (legacy method - redirects to comprehensive display)"""
	_display_comprehensive_battle_results()

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

func get_battle_result() -> FPCM_BattleManager.BattleResult:
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

	# Convert tactical result to battle result
	battle_result = FPCM_BattleManager.BattleResult.new()
	battle_result.victory = tactical_result.victory
	battle_result.crew_casualties = tactical_result.crew_casualties
	battle_result.crew_injuries = tactical_result.crew_injuries
	battle_result.credits_earned = tactical_result.credits_earned
	battle_result.experience_gained = tactical_result.experience_gained

	# Show comprehensive results instead of simple display
	_display_comprehensive_battle_results()

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

# =====================================================
# ENHANCED BATTLE SYSTEM INTEGRATION
# =====================================================

func _on_dice_rolled(result: FPCM_DiceSystem.DiceRoll) -> void:
	"""Handle dice roll results from dice system"""
	var message: String = "Dice Roll - %s: %s" % [result.context, result.get_simple_text()]
	_log_battle_message(message, Color.CYAN)

func setup_with_battle_manager(p_battle_manager: FPCM_BattleManager) -> void:
	"""Setup UI with external battle manager"""
	if battle_manager and battle_manager != p_battle_manager:
		# Cleanup old manager
		battle_manager.unregister_ui_component("BattleResolutionUI")
	
	battle_manager = p_battle_manager
	battle_manager.register_ui_component("BattleResolutionUI", self)
	
	# Get current battle state
	battle_state = battle_manager.battle_state
	if battle_state:
		_update_ui_from_battle_state()

func _update_ui_from_battle_state() -> void:
	"""Update UI based on current battle state"""
	if not battle_state:
		return
	
	# Update mission info
	if battle_state.mission_data:
		current_mission = battle_state.mission_data
		mission_type_label.text = battle_state.mission_type
	
	# Update crew and enemy lists
	crew_members = battle_state.crew_members.duplicate()
	enemy_forces = battle_state.enemy_forces.duplicate()
	
	_update_crew_display()
	_update_enemy_display()

func _on_resolve_battle_automatically_with_dice() -> void:
	"""Enhanced automatic battle resolution with dice integration"""
	if battle_in_progress:
		return
	
	battle_in_progress = true
	resolve_button.disabled = true
	_log_battle_message("Resolving battle automatically...", Color.YELLOW)
	
	# Use dice system for combat resolution
	if dice_system:
		var combat_roll: FPCM_DiceSystem.DiceRoll = dice_system.roll_dice(
			FPCM_DiceSystem.DicePattern.COMBAT,
			"Automatic Battle Resolution"
		)
		
		# Determine outcome based on dice roll and difficulty
		var difficulty_modifier: int = battle_state.difficulty_level if battle_state else 1
		var success_threshold: int = 4 + difficulty_modifier
		var victory: bool = combat_roll.total >= success_threshold
		
		# Create battle result
		battle_result = FPCM_BattleManager.BattleResult.new(victory)
		_process_automatic_battle_result(victory, combat_roll)
	else:
		# Fallback to old random system
		_resolve_battle_legacy()

func _process_automatic_battle_result(victory: bool, combat_roll: FPCM_DiceSystem.DiceRoll) -> void:
	"""Process automatic battle result with dice integration"""
	if victory:
		_log_battle_message("Victory! Combat roll: %s" % combat_roll.get_display_text(), Color.GREEN)
		battle_result.credits_earned = 1000 + (combat_roll.total * 50)
		battle_result.story_points = 2
	else:
		_log_battle_message("Defeat. Combat roll: %s" % combat_roll.get_display_text(), Color.RED)
		battle_result.credits_earned = 200
		battle_result.story_points = 1
		
		# Potential casualties on defeat
		if combat_roll.total <= 2:
			_apply_battle_casualties()
	
	# Update battle state with results
	if battle_state:
		battle_state.complete_battle(
			"victory" if victory else "defeat",
			battle_result.credits_earned,
			battle_result.loot_found
		)
	
	# Finalize resolution
	_finalize_battle_resolution()

func _apply_battle_casualties() -> void:
	"""Apply casualties based on poor combat roll"""
	if crew_members.size() > 0:
		# Roll for each crew member
		for crew_member: Resource in crew_members:
			if dice_system:
				var injury_roll: FPCM_DiceSystem.DiceRoll = dice_system.roll_dice(
					FPCM_DiceSystem.DicePattern.D6,
					"Casualty Check: %s" % _get_crew_name(crew_member)
				)
				
				if injury_roll.total <= 2:
					battle_result.crew_casualties.append(crew_member)
					_log_battle_message("Casualty: %s" % _get_crew_name(crew_member), Color.RED)
				elif injury_roll.total <= 4:
					battle_result.crew_injuries.append(crew_member)
					_log_battle_message("Injured: %s" % _get_crew_name(crew_member), Color.ORANGE)

func _get_crew_name(crew_member: Resource) -> String:
	"""Get crew member name safely"""
	if not crew_member:
		return "Unknown"
	
	var name_candidates: Array[String] = ["name", "character_name", "id"]
	for field: String in name_candidates:
		var name: Variant = safe_get_property(crew_member, field, "")
		if name != "" and name is String:
			return name as String
	
	return "Unnamed Crew"

func _finalize_battle_resolution() -> void:
	"""Complete battle resolution and emit results"""
	battle_in_progress = false
	continue_button.visible = true
	
	# Log final results
	_log_battle_message("Battle complete: %s" % battle_result.get_summary_text(),
		Color.GREEN if battle_result.victory else Color.RED)
	
	# Emit completion signal
	battle_completed.emit(battle_result)
	
	# Advance battle manager phase
	if battle_manager:
		battle_manager.advance_phase()
	
	phase_completed.emit()

func _resolve_battle_legacy() -> void:
	"""Legacy battle resolution fallback"""
	var victory: bool = randf() > 0.3 # 70% chance of victory
	battle_result = FPCM_BattleManager.BattleResult.new(victory)
	
	if victory:
		battle_result.credits_earned = 1000
		battle_result.story_points = 2
	else:
		battle_result.credits_earned = 200
		battle_result.story_points = 1
	
	_finalize_battle_resolution()

## Emergency cleanup
func _exit_tree() -> void:
	"""Cleanup when UI is removed"""
	if battle_manager:
		battle_manager.unregister_ui_component("BattleResolutionUI")
	
	if dice_system and dice_system.dice_rolled.is_connected(_on_dice_rolled):
		dice_system.dice_rolled.disconnect(_on_dice_rolled)

func _display_comprehensive_battle_results() -> void:
	"""Display comprehensive battle results to the player using the detailed UI panels"""
	if not battle_result:
		return
	
	# Show the battle results panel
	battle_results_panel.visible = true
	
	# Update victory status
	if battle_result.victory:
		victory_value_label.text = "VICTORY"
		victory_value_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		victory_value_label.text = "DEFEAT"
		victory_value_label.add_theme_color_override("font_color", Color.RED)
	
	# Update crew status section
	casualties_label.text = "Casualties: " + str(battle_result.crew_casualties.size())
	injuries_label.text = "Injuries: " + str(battle_result.crew_injuries.size())
	
	# Populate crew status list
	crew_status_list.clear()
	for crew_member in crew_members:
		var crew_name: String = _get_crew_name(crew_member)
		var status: String = "Healthy"
		var status_color: String = "#00FF00" # Green
		
		if crew_member in battle_result.crew_casualties:
			status = "Casualty"
			status_color = "#FF0000" # Red
		elif crew_member in battle_result.crew_injuries:
			status = "Injured"
			status_color = "#FFA500" # Orange
		
		crew_status_list.add_item("[color=" + status_color + "]" + crew_name + " - " + status + "[/color]")
	
	# Update rewards section
	credits_label.text = "Credits Earned: " + str(battle_result.credits_earned)
	story_points_label.text = "Story Points: " + str(battle_result.story_points)
	
	# Update experience section
	var exp_count: int = battle_result.experience_gained.size()
	if exp_count > 0:
		experience_label.text = "Experience Gained (" + str(exp_count) + " crew members)"
		experience_label.add_theme_color_override("font_color", Color.CYAN)
	else:
		experience_label.text = "No Experience Gained"
		experience_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Populate loot list
	loot_list.clear()
	if battle_result.loot_found.size() > 0:
		for loot_item in battle_result.loot_found:
			var loot_name: String = _get_loot_name(loot_item)
			loot_list.add_item(loot_name)
	else:
		loot_list.add_item("No loot found")
	
	# Update battle statistics
	duration_label.text = "Duration: " + str(battle_result.battle_duration) + " rounds"
	events_label.text = "Events Triggered: " + str(battle_result.events_triggered.size())
	
	# Log comprehensive results to battle log as well
	_log_battle_message("=== COMPREHENSIVE BATTLE RESULTS ===", Color.GOLD)
	_log_battle_message("Victory: " + ("YES" if battle_result.victory else "NO"),
		Color.GREEN if battle_result.victory else Color.RED)
	_log_battle_message("Casualties: " + str(battle_result.crew_casualties.size()), Color.WHITE)
	_log_battle_message("Credits Earned: " + str(battle_result.credits_earned), Color.YELLOW)
	_log_battle_message("Battle Duration: " + str(battle_result.battle_duration) + " rounds", Color.WHITE)
	
	# Hide main battle interface
	get_node("MainContainer").visible = false

func _get_loot_name(loot_item: Resource) -> String:
	"""Get loot item name safely"""
	if not loot_item:
		return "Unknown Item"
	
	var name_candidates: Array[String] = ["name", "item_name", "title", "id"]
	for field: String in name_candidates:
		var name: Variant = safe_get_property(loot_item, field, "")
		if name != "" and name is String:
			return name as String
	
	return "Unnamed Item"

func _on_close_results_pressed() -> void:
	"""Close the battle results panel and return to main battle interface"""
	battle_results_panel.visible = false
	get_node("MainContainer").visible = true

func _on_continue_from_results_pressed() -> void:
	"""Continue to post-battle phase from the results panel"""
	if battle_result:
		battle_completed.emit(battle_result)

## Signal handlers for battle results panel
func show_battle_results() -> void:
	"""Public method to show the battle results panel"""
	_display_comprehensive_battle_results()
