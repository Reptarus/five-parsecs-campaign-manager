class_name FPCM_CombatCalculator
extends Control

## Combat Calculator - Five Parsecs Combat Math Assistant
##
## Helps calculate to-hit chances, damage resolution, and modifiers
## based on Five Parsecs from Home Core Rules for tabletop-style play.

# Signals
signal calculation_completed(calc_type: String, result: Dictionary)

# UI References
@onready var calculation_mode: OptionButton = %CalculationMode
@onready var attacker_combat: SpinBox = %AttackerCombat
@onready var target_cover: SpinBox = %TargetCover
@onready var range_modifier: SpinBox = %RangeModifier
@onready var calculate_button: Button = %CalculateButton
@onready var result_label: RichTextLabel = %ResultLabel

# Calculation modes
enum CalcMode {
	TO_HIT,
	DAMAGE,
	BRAWLING,
	REACTION
}

# Current calculation settings
var current_mode: CalcMode = CalcMode.TO_HIT

func _ready() -> void:
	## Initialize combat calculator
	_setup_calculation_modes()
	_connect_signals()
	_update_ui_for_mode()

func _setup_calculation_modes() -> void:
	## Set up calculation mode dropdown
	if calculation_mode:
		calculation_mode.clear()
		calculation_mode.add_item("To-Hit Calculation", CalcMode.TO_HIT)
		calculation_mode.add_item("Damage Resolution", CalcMode.DAMAGE)
		calculation_mode.add_item("Brawling", CalcMode.BRAWLING)
		calculation_mode.add_item("Reaction Roll", CalcMode.REACTION)
		calculation_mode.selected = CalcMode.TO_HIT

func _connect_signals() -> void:
	## Connect UI signals
	if calculation_mode:
		calculation_mode.item_selected.connect(_on_mode_changed)
	if calculate_button:
		calculate_button.pressed.connect(_on_calculate_pressed)

# =====================================================
# COMBAT CALCULATIONS
# =====================================================

func _on_calculate_pressed() -> void:
	## Perform calculation based on current mode
	match current_mode:
		CalcMode.TO_HIT:
			_calculate_to_hit()
		CalcMode.DAMAGE:
			_calculate_damage()
		CalcMode.BRAWLING:
			_calculate_brawling()
		CalcMode.REACTION:
			_calculate_reaction()

func _calculate_to_hit() -> void:
	## Calculate to-hit chance per Five Parsecs Core Rules
	var combat_skill: int = int(attacker_combat.value) if attacker_combat else 0
	var cover: int = int(target_cover.value) if target_cover else 0
	var range_mod: int = int(range_modifier.value) if range_modifier else 0

	# Five Parsecs To-Hit Formula (Core Rules p.46):
	# Roll 1D6 + Combat Skill, need to roll >= Target Number
	# Target Number: 3+ (open), 5+ (cover at range OR close with cover), 6+ (cover at weapon range)
	# Higher rolls are BETTER (roll high system)
	var base_target: int = 3  # Base target number (3+)
	var target_number: int = base_target + cover + range_mod  # Cover/range make it harder (higher target)

	# Calculate hit chance: What do we need to roll on D6 to reach target?
	# With Combat Skill bonus, effective target we need to roll = target_number - combat_skill
	var effective_target: int = max(1, target_number - combat_skill)  # Can't go below 1
	effective_target = min(7, effective_target)  # Can't go above 7 (impossible on D6)

	# Probability of rolling >= effective_target on D6
	# Rolling 3+ = 4/6 = 66.67%, Rolling 5+ = 2/6 = 33.33%, etc.
	var hit_chance: float = 0.0
	if effective_target <= 6:
		hit_chance = ((7.0 - effective_target) / 6.0) * 100.0
	else:
		hit_chance = 0.0  # Impossible (need 7+ on D6)

	var result := {
		"calc_type": "to_hit",
		"combat_skill": combat_skill,
		"cover": cover,
		"range_modifier": range_mod,
		"base_target": base_target,
		"target_number": target_number,
		"effective_target": effective_target,
		"hit_chance_percent": hit_chance,
		"explanation": _format_to_hit_explanation(combat_skill, cover, range_mod, target_number, effective_target, hit_chance)
	}

	_display_result(result)
	calculation_completed.emit("to_hit", result)

func _calculate_damage() -> void:
	## Calculate damage resolution per Five Parsecs Core Rules
	# Note: Actual damage uses dice rolls, this calculates probabilities
	var weapon_damage: int = 0 # Would come from weapon selection
	var target_toughness: int = 4 # Default toughness

	# Five Parsecs Damage System:
	# Roll 1D6 + weapon Damage rating
	# Compare to target Toughness:
	#   - Less than Toughness: Stun marker
	#   - Equal or greater: Casualty
	#   - Natural 6: Always casualty (before modifiers)

	var result := {
		"calc_type": "damage",
		"weapon_damage": weapon_damage,
		"target_toughness": target_toughness,
		"explanation": _format_damage_explanation(weapon_damage, target_toughness)
	}

	_display_result(result)
	calculation_completed.emit("damage", result)

func _calculate_brawling() -> void:
	## Calculate brawling (melee) combat per Five Parsecs Core Rules
	var attacker_combat_skill: int = int(attacker_combat.value) if attacker_combat else 0

	# Five Parsecs Brawling:
	# Both combatants roll 1D6 + Combat Skill
	# Higher roll wins, ties favor defender
	# Winner can inflict damage or push opponent

	var result := {
		"calc_type": "brawling",
		"attacker_combat": attacker_combat_skill,
		"explanation": _format_brawling_explanation(attacker_combat_skill)
	}

	_display_result(result)
	calculation_completed.emit("brawling", result)

func _calculate_reaction() -> void:
	## Calculate reaction roll per Five Parsecs Core Rules
	var reactions_stat: int = 1 # Default Reactions value

	# Five Parsecs Reactions:
	# Roll 1D6 + Reactions stat
	# Result determines who acts first in surprise situations

	var result := {
		"calc_type": "reaction",
		"reactions_stat": reactions_stat,
		"explanation": _format_reaction_explanation(reactions_stat)
	}

	_display_result(result)
	calculation_completed.emit("reaction", result)

# =====================================================
# RESULT FORMATTING
# =====================================================

func _format_to_hit_explanation(combat: int, cover: int, range_mod: int, target_number: int, effective_target: int, hit_chance: float) -> String:
	## Format to-hit calculation explanation
	var lines: Array[String] = []

	lines.append("[b]Five Parsecs To-Hit Calculation[/b]\n")
	lines.append("(Core Rules p.46: Roll High System)\n\n")

	lines.append("Target Number: %d+\n" % target_number)
	lines.append("  Base: 3+\n")
	if cover != 0:
		lines.append("  Cover Penalty: +%d\n" % cover)
	if range_mod != 0:
		lines.append("  Range Modifier: %+d\n" % range_mod)

	lines.append("\nYour Roll: 1D6 + Combat Skill\n")
	if combat != 0:
		lines.append("  Combat Skill: %+d\n" % combat)

	lines.append("\n[color=yellow]Need to roll %d+ on D6[/color]\n" % effective_target)
	lines.append("(After adding Combat Skill bonus)\n\n")

	lines.append("[color=cyan]Hit Chance: %.1f%%[/color]\n\n" % hit_chance)
	lines.append("Roll 1D6 + Combat Skill.\n")
	lines.append("Success if result ≥ %d" % target_number)

	return "".join(lines)

func _format_damage_explanation(weapon_dmg: int, toughness: int) -> String:
	## Format damage calculation explanation
	var lines: Array[String] = []

	lines.append("[b]Five Parsecs Damage Resolution[/b]\n")
	lines.append("Roll 1D6 + %d (weapon damage)\n" % weapon_dmg)
	lines.append("vs Toughness %d\n\n" % toughness)

	lines.append("[color=yellow]Results:[/color]\n")
	lines.append("• Natural 6: Always casualty\n")
	lines.append("• Roll ≥ Toughness: Casualty\n")
	lines.append("• Roll < Toughness: Stun marker\n")

	return "".join(lines)

func _format_brawling_explanation(attacker_combat: int) -> String:
	## Format brawling calculation explanation
	var lines: Array[String] = []

	lines.append("[b]Five Parsecs Brawling[/b]\n")
	lines.append("Both combatants roll 1D6 + Combat Skill\n")
	lines.append("Attacker Combat: %+d\n\n" % attacker_combat)

	lines.append("[color=yellow]Weapon Bonuses:[/color]\n")
	lines.append("• Melee weapon: +2\n")
	lines.append("• Pistol: +1\n\n")

	lines.append("[color=yellow]Results:[/color]\n")
	lines.append("• Higher roll wins (ties = both take a hit)\n")
	lines.append("• Loser takes a hit at Damage +1\n")
	lines.append("• Natural 6: inflict hit regardless of total\n")
	lines.append("• Natural 1: opponent inflicts hit regardless\n")

	return "".join(lines)

func _format_reaction_explanation(reactions: int) -> String:
	## Format reaction roll explanation
	var lines: Array[String] = []

	lines.append("[b]Five Parsecs Reaction Roll[/b]\n")
	lines.append("Roll 1D6 + %d (Reactions)\n\n" % reactions)

	lines.append("[color=yellow]Purpose:[/color]\n")
	lines.append("• Determines initiative\n")
	lines.append("• Resolves surprise encounters\n")
	lines.append("• Higher roll acts first\n")

	return "".join(lines)

func _display_result(result: Dictionary) -> void:
	## Display calculation result
	if result_label:
		result_label.clear()
		result_label.append_text(result.explanation)

# =====================================================
# UI MODE SWITCHING
# =====================================================

func _on_mode_changed(index: int) -> void:
	## Handle calculation mode change
	current_mode = index as CalcMode
	_update_ui_for_mode()

func _update_ui_for_mode() -> void:
	## Update UI based on selected calculation mode
	# Show/hide relevant input fields based on mode
	match current_mode:
		CalcMode.TO_HIT:
			_show_to_hit_inputs()
		CalcMode.DAMAGE:
			_show_damage_inputs()
		CalcMode.BRAWLING:
			_show_brawling_inputs()
		CalcMode.REACTION:
			_show_reaction_inputs()

func _show_to_hit_inputs() -> void:
	## Show inputs for to-hit calculation
	if attacker_combat:
		attacker_combat.visible = true
	if target_cover:
		target_cover.visible = true
	if range_modifier:
		range_modifier.visible = true

func _show_damage_inputs() -> void:
	## Show inputs for damage calculation
	if attacker_combat:
		attacker_combat.visible = false
	if target_cover:
		target_cover.visible = false
	if range_modifier:
		range_modifier.visible = false

func _show_brawling_inputs() -> void:
	## Show inputs for brawling calculation
	if attacker_combat:
		attacker_combat.visible = true
	if target_cover:
		target_cover.visible = false
	if range_modifier:
		range_modifier.visible = false

func _show_reaction_inputs() -> void:
	## Show inputs for reaction calculation
	if attacker_combat:
		attacker_combat.visible = false
	if target_cover:
		target_cover.visible = false
	if range_modifier:
		range_modifier.visible = false

# =====================================================
# PUBLIC INTERFACE
# =====================================================

func quick_to_hit(combat: int, cover: int, range_mod: int = 0) -> Dictionary:
	## Quick to-hit calculation from code
	if attacker_combat:
		attacker_combat.value = combat
	if target_cover:
		target_cover.value = cover
	if range_modifier:
		range_modifier.value = range_mod

	current_mode = CalcMode.TO_HIT
	_calculate_to_hit()

	# Return last calculation result
	return {
		"combat": combat,
		"cover": cover,
		"range": range_mod
	}
