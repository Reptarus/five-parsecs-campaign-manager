class_name FPCM_BattleDashboardUI
extends Control

## Battle Dashboard UI - Game Master Assistant
##
## Manual combat facilitation dashboard for Five Parsecs battles.
## Provides dice rolling, combat calculations, and character tracking
## without automated video game mechanics - focuses on tabletop-style play.

# Signals for battle event coordination
signal dice_roll_requested(dice_type: String, context: String)
signal combat_calculation_requested(attacker: Dictionary, target: Dictionary)
signal character_action_confirmed(character_name: String, action_type: String)
signal round_advanced()
signal battle_completed(result: Dictionary)

# Dependencies
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const CharacterStatusCard = preload("res://src/ui/components/battle/CharacterStatusCard.tscn")

# UI node references - will be set up when scene is created
@onready var character_status_container: VBoxContainer = $MainLayout/ContentArea/LeftPanel/CharacterPanel/CharacterPanelContent/CharacterStatusContainer
@onready var dice_dashboard: FPCM_DiceDashboard = $MainLayout/ContentArea/RightPanel/DicePanel/DicePanelContent/DiceDashboard
@onready var combat_calculator: FPCM_CombatCalculator = $MainLayout/ContentArea/RightPanel/CalculatorPanel/CalculatorPanelContent/CombatCalculator
@onready var battle_log: RichTextLabel = $MainLayout/BottomPanel/BattleLogPanel/BattleLog
@onready var round_counter_label: Label = $MainLayout/TopBar/RoundInfo/RoundCounter
@onready var next_round_button: Button = $MainLayout/TopBar/RoundControls/NextRoundButton
@onready var end_battle_button: Button = $MainLayout/TopBar/RoundControls/EndBattleButton

# Battle state tracking
var battle_manager: FPCM_BattleManager = null
var dice_system: FPCM_DiceSystem = null
var current_round: int = 1
var active_characters: Array[Dictionary] = []
var enemy_units: Array[Dictionary] = []

# Character card tracking
var character_cards: Dictionary = {} # character_name -> CharacterStatusCard instance

# Combat tracking
var pending_action: Dictionary = {}
var last_roll_result: int = 0

func _ready() -> void:
	"""Initialize dashboard systems"""
	_initialize_systems()
	_connect_signals()
	_setup_ui_state()
	_log_message("Battle Dashboard Ready - Manual Combat Mode", Color.CYAN)

func _initialize_systems() -> void:
	"""Initialize battle systems and dependencies"""
	# Initialize dice system
	dice_system = FPCM_DiceSystem.new()
	dice_system.dice_rolled.connect(_on_dice_rolled)

	# Connect dice system to dice dashboard
	if dice_dashboard:
		dice_dashboard.set_dice_system(dice_system)

	# Battle manager will be provided externally
	if not battle_manager:
		battle_manager = FPCM_BattleManager.new()

func _connect_signals() -> void:
	"""Connect UI control signals"""
	if next_round_button:
		next_round_button.pressed.connect(_on_next_round_pressed)
	if end_battle_button:
		end_battle_button.pressed.connect(_on_end_battle_pressed)

	# Connect dice dashboard signals
	if dice_dashboard:
		dice_dashboard.dice_rolled.connect(_on_dice_dashboard_rolled)

	# Connect combat calculator signals
	if combat_calculator:
		combat_calculator.calculation_completed.connect(_on_calculation_completed)

func _setup_ui_state() -> void:
	"""Set up initial UI state"""
	_update_round_display()
	if battle_log:
		battle_log.clear()
		battle_log.bbcode_enabled = true

# =====================================================
# BATTLE MANAGEMENT
# =====================================================

func start_battle(crew_data: Array, enemy_data: Array) -> void:
	"""Initialize battle with crew and enemy data"""
	active_characters = crew_data.duplicate()
	enemy_units = enemy_data.duplicate()
	current_round = 1

	_log_message("=== Battle Started ===", Color.GREEN)
	_log_message("Crew: %d members | Enemies: %d units" % [crew_data.size(), enemy_data.size()], Color.WHITE)

	# Create character status cards for crew
	_create_character_cards()

	# Update display
	_update_round_display()

func _create_character_cards() -> void:
	"""Create character status cards for all crew members"""
	if not character_status_container:
		return

	# Clear existing cards
	for child in character_status_container.get_children():
		child.queue_free()

	# Create card for each character
	for character in active_characters:
		var card = _create_character_card(character)
		character_status_container.add_child(card)

func _create_character_card(character: Dictionary) -> Control:
	"""Create a character status card using CharacterStatusCard component"""
	var card: FPCM_CharacterStatusCard = CharacterStatusCard.instantiate()

	# Initialize card with character data
	card.set_character_data(character)

	# Connect card signals
	card.action_used.connect(_on_character_action_used)
	card.damage_taken.connect(_on_character_damage_taken)
	card.stun_marked.connect(_on_character_stun_marked)
	card.character_selected.connect(_on_character_selected)

	# Store reference for later updates
	var char_name: String = character.get("character_name", "Unknown")
	character_cards[char_name] = card

	return card

# =====================================================
# ROUND MANAGEMENT
# =====================================================

func _on_next_round_pressed() -> void:
	"""Advance to next combat round"""
	current_round += 1
	_update_round_display()
	_log_message("=== Round %d Started ===" % current_round, Color.CYAN)

	# Reset character actions and update cards
	for character in active_characters:
		character["actions_remaining"] = character.get("max_actions", 2)
		character["movement_remaining"] = character.get("max_movement", 6)

		# Reset character status card
		var char_name: String = character.get("character_name", "")
		if char_name in character_cards:
			character_cards[char_name].reset_round()

	round_advanced.emit()

func _update_round_display() -> void:
	"""Update round counter display"""
	if round_counter_label:
		round_counter_label.text = "Round: %d" % current_round

# =====================================================
# DICE ROLLING
# =====================================================

func roll_dice(dice_type: String, context: String = "") -> int:
	"""Roll dice and log result - manual confirmation required"""
	var result = 0

	if dice_system:
		# Convert string dice type to DicePattern enum
		var pattern: FPCM_DiceSystem.DicePattern
		match dice_type.to_upper():
			"D6":
				pattern = FPCM_DiceSystem.DicePattern.D6
			"D10":
				pattern = FPCM_DiceSystem.DicePattern.D10
			"D66":
				pattern = FPCM_DiceSystem.DicePattern.D66
			"D100":
				pattern = FPCM_DiceSystem.DicePattern.D100
			"2D6", "COMBAT":
				pattern = FPCM_DiceSystem.DicePattern.COMBAT
			_:
				pattern = FPCM_DiceSystem.DicePattern.D6 # Default fallback

		var dice_roll = dice_system.roll_dice(pattern, context)
		result = dice_roll.total
	else:
		# Fallback dice rolling
		match dice_type.to_upper():
			"D6":
				result = randi() % 6 + 1
			"D3":
				result = randi() % 3 + 1
			"2D6":
				result = (randi() % 6 + 1) + (randi() % 6 + 1)
			_:
				result = randi() % 6 + 1

	last_roll_result = result

	var context_text = " - %s" % context if context != "" else ""
	_log_message("🎲 Rolled %s: %d%s" % [dice_type, result, context_text], Color.YELLOW)

	dice_roll_requested.emit(dice_type, context)
	return result

func _on_dice_rolled(context: String, pattern: String, result: int) -> void:
	"""Handle dice roll from DiceSystem"""
	last_roll_result = result
	_log_message("🎲 %s rolled %s: %d" % [context, pattern, result], Color.YELLOW)

# =====================================================
# COMBAT CALCULATIONS
# =====================================================

func calculate_to_hit(attacker: Dictionary, target: Dictionary) -> Dictionary:
	"""Calculate to-hit chance (Five Parsecs rules - Core Rules p.46)"""
	var combat_skill = attacker.get("combat", 1)
	var cover = target.get("cover", 0)
	var range_modifier = 0 # Will be calculated from distance

	# Five Parsecs uses "roll high" system:
	# Roll 1D6 + Combat Skill, need to roll >= Target Number
	# Target Number = Base (3) + Cover + Range modifiers
	var base_target: int = 3
	var target_number: int = base_target + cover + range_modifier

	# What do we need to roll on D6 (before adding Combat Skill)?
	var effective_target: int = max(1, target_number - combat_skill)
	var hit_chance: float = 0.0
	if effective_target <= 6:
		hit_chance = ((7.0 - effective_target) / 6.0) * 100.0

	var calc_result = {
		"attacker": attacker.get("character_name", "Unknown"),
		"target": target.get("character_name", "Unknown"),
		"combat_skill": combat_skill,
		"cover": cover,
		"target_number": target_number,
		"effective_target": effective_target,
		"hit_chance": hit_chance,
		"explanation": "Need to roll ≥%d (Target %d = Base 3 + Cover %d)" % [target_number, target_number, cover]
	}

	_log_message("⚔️ To-Hit: %s → %s: %s (%.1f%% chance)" % [
		calc_result.attacker,
		calc_result.target,
		calc_result.explanation,
		hit_chance
	], Color.LIGHT_BLUE)

	combat_calculation_requested.emit(attacker, target)
	return calc_result

func calculate_damage(attacker: Dictionary, target: Dictionary, hit_roll: int) -> Dictionary:
	"""Calculate damage (Five Parsecs rules)"""
	var damage_roll = roll_dice("D6", "Damage")
	var toughness = target.get("toughness", 4)
	var actual_damage = max(1, damage_roll - (toughness / 2))

	var damage_result = {
		"damage_roll": damage_roll,
		"toughness": toughness,
		"actual_damage": actual_damage,
		"explanation": "Damage %d - (Toughness %d ÷ 2) = %d" % [damage_roll, toughness, actual_damage]
	}

	_log_message("💥 Damage: %s" % damage_result.explanation, Color.RED)

	return damage_result

# =====================================================
# CHARACTER ACTIONS
# =====================================================

func confirm_character_action(character_name: String, action_type: String, target: Dictionary = {}) -> void:
	"""Confirm and log character action - manual workflow"""
	_log_message("✓ Confirmed: %s performs %s" % [character_name, action_type], Color.GREEN)

	# Update character state
	for character in active_characters:
		if character.get("character_name", "") == character_name:
			var actions = character.get("actions_remaining", 2)
			character["actions_remaining"] = max(0, actions - 1)
			break

	character_action_confirmed.emit(character_name, action_type)

# =====================================================
# BATTLE COMPLETION
# =====================================================

func _on_end_battle_pressed() -> void:
	"""End battle and return results"""
	_log_message("=== Battle Ended ===", Color.CYAN)

	# Calculate simple result
	var result = {
		"rounds_fought": current_round,
		"crew_survived": _count_surviving_crew(),
		"enemies_defeated": _count_defeated_enemies()
	}

	battle_completed.emit(result)

func _count_surviving_crew() -> int:
	"""Count crew members still alive"""
	var count = 0
	for character in active_characters:
		if character.get("health", 0) > 0:
			count += 1
	return count

func _count_defeated_enemies() -> int:
	"""Count enemies defeated"""
	var count = 0
	for enemy in enemy_units:
		if enemy.get("health", 0) <= 0:
			count += 1
	return count

# =====================================================
# UI UTILITIES
# =====================================================

func _log_message(message: String, color: Color = Color.WHITE) -> void:
	"""Add message to battle log"""
	if not battle_log:
		return

	var timestamp = "[%s] " % Time.get_time_string_from_system()
	var colored_message = "[color=%s]%s%s[/color]" % [color.to_html(), timestamp, message]
	battle_log.append_text(colored_message + "\n")

func clear_log() -> void:
	"""Clear battle log"""
	if battle_log:
		battle_log.clear()

func get_current_round() -> int:
	"""Get current battle round"""
	return current_round

func get_active_characters() -> Array[Dictionary]:
	"""Get list of active characters"""
	return active_characters

func get_enemy_units() -> Array[Dictionary]:
	"""Get list of enemy units"""
	return enemy_units

# =====================================================
# CHARACTER CARD SIGNAL HANDLERS
# =====================================================

func _on_character_action_used(character_name: String, action_type: String) -> void:
	"""Handle action used from character card"""
	_log_message("✓ %s used action: %s" % [character_name, action_type], Color.CYAN)
	character_action_confirmed.emit(character_name, action_type)

func _on_character_damage_taken(character_name: String, amount: int) -> void:
	"""Handle damage taken from character card"""
	_log_message("💥 %s took %d damage" % [character_name, amount], Color.RED)

	# Update character data
	for character in active_characters:
		if character.get("character_name", "") == character_name:
			var current_health: int = character.get("health", 10)
			character["health"] = max(0, current_health - amount)
			break

func _on_character_stun_marked(character_name: String) -> void:
	"""Handle stun marker added from character card"""
	_log_message("⚡ %s marked with Stun" % character_name, Color.YELLOW)

	# Update character data
	for character in active_characters:
		if character.get("character_name", "") == character_name:
			var stun: int = character.get("stun_markers", 0)
			character["stun_markers"] = stun + 1

			# Check if out of action (3+ Stun markers)
			if character["stun_markers"] >= 3:
				_log_message("⚠️ %s is OUT OF ACTION (3+ Stun markers)" % character_name, Color.ORANGE)
			break

func _on_character_selected(character_name: String) -> void:
	"""Handle character card selection"""
	_log_message("Selected: %s" % character_name, Color.LIGHT_BLUE)

	# Highlight selected card, unhighlight others
	for card_name in character_cards:
		var card: FPCM_CharacterStatusCard = character_cards[card_name]
		if card_name == character_name:
			card.highlight()
		else:
			card.unhighlight()

# =====================================================
# DICE DASHBOARD SIGNAL HANDLERS
# =====================================================

func _on_dice_dashboard_rolled(dice_type: String, result: int, context: String) -> void:
	"""Handle dice roll from dice dashboard"""
	var context_text: String = ""
	if context != "":
		context_text = " - %s" % context

	_log_message("🎲 Rolled %s: %d%s" % [dice_type, result, context_text], Color.YELLOW)

	# Store for potential use
	last_roll_result = result

	# Emit signal for external listeners
	dice_roll_requested.emit(dice_type, context)

# =====================================================
# COMBAT CALCULATOR SIGNAL HANDLERS
# =====================================================

func _on_calculation_completed(calc_type: String, result: Dictionary) -> void:
	"""Handle completed calculation from combat calculator"""
	match calc_type:
		"to_hit":
			var hit_chance: float = result.get("hit_chance_percent", 0.0)
			var target: int = result.get("target_number", 3)
			_log_message("⚔️ To-Hit: %.1f%% chance (need ≥%d)" % [
				hit_chance,
				target
			], Color.LIGHT_BLUE)

		"damage":
			_log_message("💥 Damage calculation completed", Color.RED)

		"brawling":
			_log_message("🥊 Brawling calculation completed", Color.ORANGE)

		"reaction":
			_log_message("⚡ Reaction calculation completed", Color.CYAN)

	# Emit signal for external listeners
	combat_calculation_requested.emit({}, {})
