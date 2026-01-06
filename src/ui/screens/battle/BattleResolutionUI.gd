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
signal tactical_battle_requested(tactical_scene: Node) # Request parent to add tactical battle scene

# Dependencies - following modernized pattern
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState = preload("res://src/core/battle/FPCM_BattleState.gd")
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")
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

## Sprint 11.5: BattlePhase integration for campaign turn system
var battle_phase_handler: Node = null  # Reference to BattlePhase for campaign turn integration
var _awaiting_mode_selection: bool = false  # True when BattlePhase is waiting for mode choice

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

	# Sprint 11.5: Try to connect to BattlePhase for campaign turn integration
	call_deferred("_try_connect_battle_phase")

## Sprint 11.5: BattlePhase Integration Methods

func _try_connect_battle_phase() -> void:
	"""Try to find and connect to BattlePhase handler for campaign turn integration"""
	# Check if CampaignPhaseManager exists and has battle phase handler
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_method("get_current_phase_handler"):
		var handler = cpm.get_current_phase_handler()
		if handler and handler.get_class() == "BattlePhase":
			set_battle_phase_handler(handler)
			return

	# Alternative: Search for BattlePhase in tree
	var battle_phase = _find_node_by_script_class("BattlePhase")
	if battle_phase:
		set_battle_phase_handler(battle_phase)

func set_battle_phase_handler(handler: Node) -> void:
	"""Connect to BattlePhase handler for campaign turn battle mode selection"""
	if battle_phase_handler and battle_phase_handler.has_signal("battle_mode_selection_requested"):
		if battle_phase_handler.battle_mode_selection_requested.is_connected(_on_battle_mode_selection_requested):
			battle_phase_handler.battle_mode_selection_requested.disconnect(_on_battle_mode_selection_requested)

	battle_phase_handler = handler

	if battle_phase_handler and battle_phase_handler.has_signal("battle_mode_selection_requested"):
		battle_phase_handler.battle_mode_selection_requested.connect(_on_battle_mode_selection_requested)
		print("BattleResolutionUI: Connected to BattlePhase for battle mode selection")

func _on_battle_mode_selection_requested(crew_count: int, enemy_count: int) -> void:
	"""Handle battle mode selection request from BattlePhase (campaign turn system)"""
	_awaiting_mode_selection = true
	_log_battle_message("Choose your battle approach:", Color.YELLOW)
	_log_battle_message("  [Resolve Battle] - Auto-resolve using Five Parsecs rules", Color.CYAN)
	_log_battle_message("  [Play Tactically] - Turn-by-turn tactical combat", Color.CYAN)
	_log_battle_message("  Crew: %d vs Enemies: %d" % [crew_count, enemy_count], Color.WHITE)

	# Enable battle action buttons
	resolve_button.disabled = false
	tactical_button.disabled = false

func _notify_battle_phase_mode_selected(tactical: bool) -> void:
	"""Notify BattlePhase of user's battle mode selection"""
	if _awaiting_mode_selection and battle_phase_handler:
		if battle_phase_handler.has_method("set_battle_mode"):
			battle_phase_handler.set_battle_mode(tactical)
			_awaiting_mode_selection = false
			print("BattleResolutionUI: Notified BattlePhase of mode selection: %s" % ("Tactical" if tactical else "Auto-Resolve"))

func _find_node_by_script_class(script_class_name: String) -> Node:
	"""Find a node by its script class_name"""
	if not is_inside_tree():
		return null

	var root = get_tree().root
	return _recursive_find_by_script_class(root, script_class_name)

func _recursive_find_by_script_class(node: Node, target_class: String) -> Node:
	"""Recursively search for node with matching script class"""
	var script = node.get_script()
	if script:
		# Check global name if available
		if script.has_method("get_global_name"):
			if script.get_global_name() == target_class:
				return node
		# Check class name from resource path
		var path = script.resource_path
		if path.ends_with("/" + target_class + ".gd"):
			return node

	for child in node.get_children():
		var found = _recursive_find_by_script_class(child, target_class)
		if found:
			return found

	return null

func _setup_ui() -> void:
	"""Initialize UI state"""
	battle_log.clear()
	continue_button.disabled = true
	_log_battle_message("Preparing for battle...", Color.YELLOW)

func setup_battle(mission: Resource, crew: Array, enemies: Array = []) -> void:
	"""Setup battle with mission data, crew, and enemies"""
	current_mission = mission
	crew_members = crew.duplicate()

	# Generate enemies if not provided
	if enemies.is_empty() and alpha_manager:
		# Pass crew size for proper enemy scaling (Core Rules p.63)
		enemy_forces = alpha_manager.generate_enemies_for_mission(mission, crew.size())
	else:
		enemy_forces = enemies.duplicate()

	_update_battle_info()
	_update_crew_display()
	_update_enemy_display()
	_log_battle_message("Battle setup complete. Choose your approach.", Color.GREEN)

func _update_battle_info() -> void:
	"""Update mission and difficulty display"""
	if current_mission:
		var mission_type = Godot4Utils.safe_get_property(current_mission, "mission_type", "Unknown")
		var difficulty = Godot4Utils.safe_get_property(current_mission, "difficulty", 1)
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
	var character_name: Character = Godot4Utils.safe_get_property(crew_member, "character_name", "Unknown")
	name_label.text = str(character_name)
	card.add_child(name_label)
	var stats_label := Label.new()
	var combat_skill: Node = Godot4Utils.safe_get_property(crew_member, "combat_skill", 1)
	var toughness = Godot4Utils.safe_get_property(crew_member, "toughness", 3)
	stats_label.text = "Combat: %d, Toughness: %d" % [combat_skill, toughness]
	stats_label.add_theme_font_size_override("font_size", 10)
	card.add_child(stats_label)

	return card

func _create_enemy_card(enemy: Resource) -> Control:
	"""Create an enemy display card"""
	var card := VBoxContainer.new()
	var name_label := Label.new()
	var enemy_name: String = Godot4Utils.safe_get_property(enemy, "name", "Unknown Enemy")
	name_label.text = str(enemy_name)
	card.add_child(name_label)
	var stats_label := Label.new()
	var combat_skill: Node = Godot4Utils.safe_get_property(enemy, "combat_skill", 1)
	var toughness = Godot4Utils.safe_get_property(enemy, "toughness", 3)
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
			var character_name: String = Godot4Utils.safe_get_property(crew_member, "character_name", "Crew member")
			_log_battle_message("%s gained combat experience!" % character_name, Color.BLUE)
	
	# Mission completion bonuses
	if current_mission:
		var mission_bonus = Godot4Utils.safe_get_property(current_mission, "completion_bonus", 0)
		if mission_bonus > 0:
			battle_result.credits_earned += mission_bonus
			_log_battle_message("Mission completion bonus: %d credits" % mission_bonus, Color.GREEN)

func _on_resolve_battle_automatically() -> void:
	"""Resolve battle automatically using Five Parsecs rules"""
	if battle_in_progress:
		return

	# Sprint 11.5: Notify BattlePhase if awaiting mode selection (campaign turn flow)
	if _awaiting_mode_selection:
		_notify_battle_phase_mode_selected(false)  # Auto-resolve mode
		_log_battle_message("Selected: Auto-Resolve Mode", Color.CYAN)
		# BattlePhase will handle the actual battle - we just provide the UI choice
		return

	# Standalone battle flow (not part of campaign turn)
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

	# Sprint 11.5: Notify BattlePhase if awaiting mode selection (campaign turn flow)
	if _awaiting_mode_selection:
		_notify_battle_phase_mode_selected(true)  # Tactical mode
		_log_battle_message("Selected: Tactical Combat Mode", Color.CYAN)
		# BattlePhase will handle the tactical battle setup via TacticalBattleUI
		# We can still show local tactical UI as well
		visible = false
		return

	# Standalone battle flow (not part of campaign turn)
	# Load tactical battle scene
	var tactical_scene = preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
	var tactical_battle: Node = tactical_scene.instantiate()

	# Initialize tactical battle with current data
	tactical_battle.initialize_battle(crew_members, enemy_forces, current_mission)

	# Connect signals
	tactical_battle.tactical_battle_completed.connect(_on_tactical_battle_completed)
	tactical_battle.return_to_battle_resolution.connect(_on_return_from_tactical)

	# Signal up to parent to handle scene switching (call down, signal up pattern)
	tactical_battle_requested.emit(tactical_battle)
	visible = false

func _on_attempt_flee() -> void:
	"""Attempt to flee from battle"""
	_log_battle_message("Attempting to flee...", Color(1.0, 0.5, 0.0, 1.0))

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
	"""Calculate battle result using Five Parsecs combat tables"""
	var result := BattleResult.new()

	var crew_power = _calculate_crew_combat_power()
	var enemy_power: int = _calculate_enemy_combat_power()

	_log_battle_message("Crew combat power: %d" % crew_power, Color.WHITE)
	_log_battle_message("Enemy combat power: %d" % enemy_power, Color.WHITE)

	# Battle resolution using dice system (2D6 + advantage)
	var battle_roll: int = _roll_dice("Battle Resolution", "D6") + _roll_dice("Battle Resolution (2nd die)", "D6")
	var crew_advantage = crew_power - enemy_power
	var final_result = battle_roll + crew_advantage

	_log_battle_message("Battle roll: %d + %d advantage = %d" % [battle_roll, crew_advantage, final_result], Color.WHITE)

	# Determine victory/defeat
	if final_result >= 8:
		result.victory = true
		_log_battle_message("Victory! Battle won!", Color.GREEN)

		# Calculate rewards for victory
		var reward_credits = Godot4Utils.safe_get_property(current_mission, "reward_credits", 500)
		result.credits_earned = reward_credits

		# Generate loot opportunities (Five Parsecs p.96)
		_generate_loot_opportunities(result, battle_roll)

		# Calculate experience for victory (Five Parsecs p.97)
		_calculate_experience_gains(result, true)

		# Check for casualties even in victory
		_process_crew_casualties_and_injuries(result)
	else:
		result.victory = false
		_log_battle_message("Defeat! Battle lost.", Color.RED)

		# Calculate experience for defeat (reduced)
		_calculate_experience_gains(result, false)

		# Process casualties and injuries (more severe on defeat)
		_process_crew_casualties_and_injuries(result)

	return result

func _calculate_crew_combat_power() -> int:
	"""Calculate total crew combat effectiveness"""
	var total_power: int = 0
	for crew_member in crew_members:
		var combat_skill: int = crew_member.combat_skill if "combat_skill" in crew_member else 1
		var equipment_bonus: int = _calculate_equipment_bonus(crew_member)
		total_power += combat_skill + equipment_bonus

	return total_power

func _calculate_equipment_bonus(crew_member) -> int:
	"""Calculate combat bonus from equipment"""
	var bonus: int = 1  # Base equipment bonus
	var equipment = []

	# Get equipment from character
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	if "equipment" in crew_member:
		equipment = crew_member.equipment if crew_member.equipment else []
	elif crew_member is Dictionary:
		equipment = crew_member.get("equipment", [])
	elif crew_member.has_method("get"):
		equipment = crew_member.get("equipment")
		if equipment == null:
			equipment = []

	# Check for combat-enhancing equipment
	for item in equipment:
		var item_id = ""
		if item is String:
			item_id = item.to_lower()
		elif item is Dictionary:
			item_id = item.get("id", "").to_lower()

		# Equipment that provides combat bonuses
		match item_id:
			"combat_armor", "powered_armor": bonus += 1
			"military_rifle", "plasma_rifle": bonus += 1
			"targeting_system": bonus += 1
			"scavenger_kit", "lucky_charm": bonus += 1  # Luck/loot bonus also helps

	return bonus

func _calculate_enemy_combat_power() -> int:
	"""Calculate total enemy combat effectiveness"""
	var total_power: int = 0

	for enemy in enemy_forces:
		var combat_skill: int = Godot4Utils.safe_get_property(enemy, "combat_skill", 1)
		total_power += combat_skill

	return total_power

func _process_crew_casualties_and_injuries(result: BattleResult) -> void:
	"""Process crew casualties and injuries per Five Parsecs Core Rules p.94-95"""
	_log_battle_message("=== Processing Crew Casualties ===", Color.CYAN)

	for crew_member in crew_members:
		var character_name: String = Godot4Utils.safe_get_property(crew_member, "character_name", "Crew member")

		# Step 1: Determine if casualty or injury (D6, 1-2 = casualty)
		var fate_data = _determine_casualty_fate(crew_member, character_name)

		if fate_data.is_casualty:
			# Character is a casualty
			result.crew_casualties.append(crew_member)
			_log_battle_message("💀 %s: CASUALTY - %s (rolled %d)" % [character_name, fate_data.casualty_type, fate_data.roll], Color.RED)
		else:
			# Character survives but may be injured
			var injury_data = _roll_injury_type(crew_member, character_name)
			result.crew_injuries.append(crew_member)

			if injury_data.recovery_time > 0:
				_log_battle_message("🩹 %s: %s (%d turns recovery)" % [character_name, injury_data.injury_type, injury_data.recovery_time], Color(1.0, 0.6, 0.0))
			else:
				_log_battle_message("⚠️ %s: %s" % [character_name, injury_data.injury_type], Color.YELLOW)

func _determine_casualty_fate(crew_member: Resource, character_name: String) -> Dictionary:
	"""
	Determine if crew member is casualty or injured - SIMPLIFIED FOR AUTO-RESOLVE

	NOTE: In actual Five Parsecs tabletop play (Core Rules p.46-47):
	- Casualties occur when: 3+ Stun markers accumulated OR damage roll >= Toughness
	- Damage = 1D6 + weapon Damage rating vs target Toughness
	- Natural 6 on damage roll = automatic casualty

	This simplified version uses a single D6 roll for quick auto-resolution.
	For full tactical play, use TacticalBattleUI which implements proper Stun/damage mechanics.
	"""
	var casualty_roll := _roll_dice("Casualty Check - " + character_name, "D6")
	var casualty_threshold := 2 # Base: 1-2 = casualty (simplified for auto-resolve)

	# Apply character modifiers
	var toughness: int = Godot4Utils.safe_get_property(crew_member, "toughness", 0)
	if toughness >= 5:
		casualty_threshold -= 1 # Toughness makes casualties less likely
		_log_battle_message("  → Toughness bonus applied", Color.GRAY)

	var fate_data := {
		"roll": casualty_roll,
		"is_casualty": casualty_roll <= casualty_threshold,
		"casualty_type": ""
	}

	if fate_data.is_casualty:
		# Determine casualty type
		if casualty_roll == 1:
			fate_data.casualty_type = "Killed in Action"
		else:
			fate_data.casualty_type = "Critically Wounded"

	return fate_data

func _roll_injury_type(crew_member: Resource, character_name: String) -> Dictionary:
	"""Roll for injury type per Five Parsecs Core Rules Injury Table (D100)"""
	# Roll D100 using 2D10 method (tens + ones)
	var tens_roll = _roll_dice("Injury Tens - " + character_name, "D6") % 10
	var ones_roll = _roll_dice("Injury Ones - " + character_name, "D6") % 10
	var injury_roll = (tens_roll * 10) + ones_roll
	if injury_roll == 0:
		injury_roll = 100 # Handle 00 = 100

	var injury_data := {
		"injury_roll": injury_roll,
		"injury_type": "",
		"recovery_time": 0,
		"permanent_effects": [],
		"equipment_damaged": false
	}

	# Five Parsecs Core Rules Injury Table (exact page references)
	if injury_roll <= 5:
		# 1-5: Gruesome fate - Dead, all equipment damaged
		injury_data.injury_type = "Gruesome Fate"
		injury_data.recovery_time = -1 # Dead
		injury_data.equipment_damaged = true
		injury_data.permanent_effects = ["DEAD", "All carried equipment damaged"]
	elif injury_roll <= 15:
		# 6-15: Death or permanent injury
		injury_data.injury_type = "Death or Permanent Injury"
		injury_data.recovery_time = -1 # Removed from campaign
		injury_data.permanent_effects = ["DEAD or removed from campaign"]
	elif injury_roll == 16:
		# 16: Miraculous escape - Survives with +1 Luck, items lost
		injury_data.injury_type = "Miraculous Escape"
		injury_data.recovery_time = 0
		injury_data.permanent_effects = ["+1 Luck", "All items permanently lost"]
	elif injury_roll <= 30:
		# 17-30: Equipment loss
		injury_data.injury_type = "Equipment Loss"
		injury_data.recovery_time = 0
		injury_data.equipment_damaged = true
		injury_data.permanent_effects = ["Random carried item damaged"]
	elif injury_roll <= 45:
		# 31-45: Crippling wound - Requires surgery or permanent stat reduction
		var recovery_roll = _roll_dice("Crippling Wound Recovery - " + character_name, "D6")
		injury_data.injury_type = "Crippling Wound"
		injury_data.recovery_time = recovery_roll
		injury_data.permanent_effects = ["Requires 1D6 credits surgery", "OR permanent -1 to Speed/Toughness"]
	elif injury_roll <= 54:
		# 46-54: Serious injury - No long-term effect, 1D3+1 recovery
		var recovery_d3 = (_roll_dice("Serious Injury D3 - " + character_name, "D6") % 3) + 1
		injury_data.injury_type = "Serious Injury"
		injury_data.recovery_time = recovery_d3 + 1
		injury_data.permanent_effects = ["No long-term effect"]
	elif injury_roll <= 80:
		# 55-80: Minor injuries - 1 turn recovery
		injury_data.injury_type = "Minor Injuries"
		injury_data.recovery_time = 1
		injury_data.permanent_effects = ["No long-term effect"]
	elif injury_roll <= 95:
		# 81-95: Knocked out - No recovery needed
		injury_data.injury_type = "Knocked Out"
		injury_data.recovery_time = 0
		injury_data.permanent_effects = ["No long-term effect"]
	else:
		# 96-100: School of hard knocks - Earn 1 XP!
		injury_data.injury_type = "School of Hard Knocks"
		injury_data.recovery_time = 0
		injury_data.permanent_effects = ["Earn 1 XP"]

	return injury_data

func _calculate_experience_gains(result: BattleResult, victory: bool) -> void:
	"""Calculate experience gains per Five Parsecs Core Rules (p.94-95)"""
	_log_battle_message("=== Calculating Experience ===", Color.CYAN)

	# Track first casualty dealer
	var first_casualty_awarded = false

	for crew_member in crew_members:
		var character_name: String = Godot4Utils.safe_get_property(crew_member, "character_name", "Crew member")
		var crew_exp := 0

		# Check if crew member became a casualty
		var is_casualty := result.crew_casualties.any(func(c): return Godot4Utils.safe_get_property(c, "character_name", "") == character_name)

		# Core Rules XP Table (exact implementation)
		if is_casualty:
			# Became a casualty: +1 XP (Core Rules p.94)
			crew_exp = 1
			_log_battle_message("  %s: +1 XP (casualty)" % character_name, Color.ORANGE)
		elif victory:
			# Survived and Won: +3 XP (Core Rules p.94)
			crew_exp = 3
			_log_battle_message("  %s: +3 XP (survived and won)" % character_name, Color.GREEN)
		else:
			# Survived but didn't Win: +2 XP (Core Rules p.94)
			crew_exp = 2
			_log_battle_message("  %s: +2 XP (survived)" % character_name, Color.CYAN)

		# Bonus XP opportunities (Core Rules p.94-95)
		# First character to inflict a casualty: +1 XP
		if not first_casualty_awarded and victory:
			crew_exp += 1
			first_casualty_awarded = true
			_log_battle_message("  → +1 XP (first casualty)", Color.YELLOW)

		# TODO: Add support for:
		# - Killed Unique Individual: +1 XP
		# - Campaign on Easy mode: +1 XP
		# - Crew completed final stage of Quest: +1 XP

		# Store experience in result
		result.experience_gained[character_name] = crew_exp

func _generate_loot_opportunities(result: BattleResult, battle_roll: int) -> void:
	"""Generate loot opportunities per Five Parsecs rules (p.96)"""
	_log_battle_message("=== Generating Loot ===", Color.CYAN)

	# Calculate number of loot rolls
	var loot_rolls := 1 # Base victory loot

	# Bonus for high battle roll (12+ = overwhelming victory)
	if battle_roll >= 12:
		loot_rolls += 1
		_log_battle_message("  +1 loot roll (overwhelming victory)", Color.GRAY)

	# Bonus for no casualties
	if result.crew_casualties.size() == 0:
		loot_rolls += 1
		_log_battle_message("  +1 loot roll (no casualties)", Color.GRAY)

	# Mission type bonuses
	var mission_type: String = Godot4Utils.safe_get_property(current_mission, "type", "patrol")
	if mission_type in ["assault", "investigation"]:
		loot_rolls += 1
		_log_battle_message("  +1 loot roll (%s mission)" % mission_type, Color.GRAY)

	# Generate loot opportunities
	for i in loot_rolls:
		var loot_opportunity := _generate_single_loot_opportunity()
		result.loot_opportunities.append(loot_opportunity)
		_log_battle_message("  💎 %s" % loot_opportunity, Color.YELLOW)

func _generate_single_loot_opportunity() -> String:
	"""Generate single loot opportunity based on Five Parsecs loot table"""
	var loot_roll := randf()

	# Five Parsecs loot distribution (p.96)
	if loot_roll < 0.4: # 40% chance
		return "Credits: Roll 2D6 x 10 credits"
	elif loot_roll < 0.65: # 25% chance
		return "Equipment Cache: Roll on equipment table"
	elif loot_roll < 0.85: # 20% chance
		return "Consumables: Medical supplies or ammunition"
	elif loot_roll < 0.95: # 10% chance
		return "Information: Potential quest hook or intel"
	else: # 5% chance
		return "Special Item: Unusual discovery (GM determines)"

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

		# Navigate to PostBattleSequence UI
		await get_tree().create_timer(0.3).timeout  # Brief delay for signal processing
		if has_node("/root/SceneRouter"):
			get_node("/root/SceneRouter").navigate_to("post_battle_sequence")
		else:
			get_tree().change_scene_to_file("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

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
					_log_battle_message("Injured: %s" % _get_crew_name(crew_member), Color(1.0, 0.5, 0.0, 1.0))

func _get_crew_name(crew_member: Resource) -> String:
	"""Get crew member name safely"""
	if not crew_member:
		return "Unknown"
	
	var name_candidates: Array[String] = ["name", "character_name", "id"]
	for field: String in name_candidates:
		var name: Variant = Godot4Utils.safe_get_property(crew_member, field, "")
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
		var status_color: Color = Color.GREEN # Green
		
		if crew_member in battle_result.crew_casualties:
			status = "Casualty"
			status_color = Color.RED # Red
		elif crew_member in battle_result.crew_injuries:
			status = "Injured"
			status_color = Color(1.0, 0.5, 0.0, 1.0) # Orange
		
		crew_status_list.add_item("[color=" + status_color.to_html() + "]" + crew_name + " - " + status + "[/color]")
	
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
	_log_battle_message("=== COMPREHENSIVE BATTLE RESULTS ===", Color(1.0, 0.84, 0.0, 1.0))
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
		var name: Variant = Godot4Utils.safe_get_property(loot_item, field, "")
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

		# Navigate to PostBattleSequence UI
		await get_tree().create_timer(0.3).timeout  # Brief delay for signal processing
		if has_node("/root/SceneRouter"):
			get_node("/root/SceneRouter").navigate_to("post_battle_sequence")
		else:
			get_tree().change_scene_to_file("res://src/ui/screens/postbattle/PostBattleSequence.tscn")

## Signal handlers for battle results panel
func show_battle_results() -> void:
	"""Public method to show the battle results panel"""
	_display_comprehensive_battle_results()
