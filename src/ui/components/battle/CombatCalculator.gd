class_name FPCM_CombatCalculator
extends MarginContainer

## Combat Calculator: the To Hit table and the Hit table of the battle's own book.
##
## To Hit lists the rows the book prints (Core Rules p.44 with its errata row, Bug Hunt
## p.177, Planetfall p.37) and says what the die must show once Combat Skill is added.
## Damage resolves a Hit through BattleCalculations.resolve_hit_for_mode(), the function
## the battle screen's hit sheet applies, once for each face of the die, so the odds it
## shows are the outcomes that sheet would apply. Saving Throws are rolled first and are
## left out here.
##
## Until 2026-10-30 this file also had Brawling and Reaction modes. Both printed rules
## the books do not have: a brawl "loser takes a hit at Damage +1" (Core Rules p.45 uses
## the highest Melee or Pistol Damage carried, +0 with neither) and a reaction "1D6 +
## Reactions, higher acts first" (p.112 compares one die per figure with its Reactions).
## Brawls have the Brawl Resolver and the Reference tab; reactions are rolled on the
## battle screen itself. Its To Hit mode added a cover spinner and a range spinner to a
## base of 3, which matches none of the printed rows.

signal calculation_completed(calc_type: String, result: Dictionary)

@onready var calculation_mode: OptionButton = %CalculationMode
@onready var attacker_combat: SpinBox = %AttackerCombat
@onready var shot_option: OptionButton = %ShotOption
@onready var weapon_damage: SpinBox = %WeaponDamage
@onready var target_toughness: SpinBox = %TargetToughness
@onready var calculate_button: Button = %CalculateButton
@onready var result_label: RichTextLabel = %ResultLabel

enum CalcMode {
	TO_HIT,
	DAMAGE,
}

const RESULT_TEXT := {
	"down": "Casualty",
	"wounded": "Wounded",
	"sprawling": "Knocked Sprawling",
	"kp_lost": "Loses a Kill Point",
	"stun": "Stunned",
}

## What the odds above cannot show, because they depend on the figure's state.
const DAMAGE_NOTES := {
	"core": "A Hit deflected by a Saving Throw still Stuns.",
	"bug_hunt": "A second Wound makes a casualty.",
	"planetfall": "A figure with Kill Points loses one instead of becoming a casualty.",
}

var current_mode: CalcMode = CalcMode.TO_HIT
var _rules_mode: String = "core"
var _hit_rows: Array = []


func _ready() -> void:
	_setup_calculation_modes()
	_connect_signals()
	_fill_shot_rows()
	_update_ui_for_mode()


## The battle's book: "core", "bug_hunt" or "planetfall".
func set_rules_mode(mode: String) -> void:
	_rules_mode = mode
	_fill_shot_rows()
	if result_label:
		result_label.clear()


func _setup_calculation_modes() -> void:
	if calculation_mode:
		calculation_mode.clear()
		calculation_mode.add_item("To Hit", CalcMode.TO_HIT)
		calculation_mode.add_item("Damage", CalcMode.DAMAGE)
		calculation_mode.selected = CalcMode.TO_HIT


func _fill_shot_rows() -> void:
	_hit_rows = BattleCalculations.hit_rows_for_mode(_rules_mode)
	if shot_option == null:
		return
	shot_option.clear()
	for i in _hit_rows.size():
		var row: Dictionary = _hit_rows[i]
		shot_option.add_item("%s: %d+" % [str(row.label), int(row.target)], i)
	shot_option.selected = 0


func _connect_signals() -> void:
	if calculation_mode:
		calculation_mode.item_selected.connect(_on_mode_changed)
	if calculate_button:
		calculate_button.pressed.connect(_on_calculate_pressed)


func _on_calculate_pressed() -> void:
	match current_mode:
		CalcMode.TO_HIT:
			_calculate_to_hit()
		CalcMode.DAMAGE:
			_calculate_damage()


func _calculate_to_hit() -> void:
	var skill: int = int(attacker_combat.value) if attacker_combat else 0
	var index: int = shot_option.selected if shot_option else 0
	var row: Dictionary = _hit_rows[clampi(index, 0, _hit_rows.size() - 1)]
	var target: int = int(row.target)
	# The modified score must equal or beat the row's number, so the die needs
	# target - skill. A die can only show 1-6.
	var need: int = target - skill
	var faces: int = clampi(7 - maxi(need, 1), 0, 6)
	var lines: PackedStringArray = [
		"[b]To Hit (%s)[/b]" % str(row.cite),
		"%s: %d+" % [str(row.label), target],
		"Roll 1D6 + Combat Skill (%+d)." % skill,
	]
	if faces == 0:
		lines.append("The die cannot reach it: no chance to hit.")
	elif need <= 1:
		lines.append("Any roll hits.")
	else:
		lines.append("The die must show [b]%d+[/b]: %d in 6." % [need, faces])
	var result := {
		"calc_type": "to_hit",
		"rules_mode": _rules_mode,
		"combat_skill": skill,
		"target_number": target,
		"die_needed": need,
		"hit_faces": faces,
		"explanation": "\n".join(lines),
	}
	_display_result(result)
	calculation_completed.emit("to_hit", result)


func _calculate_damage() -> void:
	var damage: int = int(weapon_damage.value) if weapon_damage else 0
	var toughness: int = int(target_toughness.value) if target_toughness else 4
	var counts: Dictionary = {}
	var order: Array = []
	for face in range(1, 7):
		var roll_face: int = face
		var out: Dictionary = BattleCalculations.resolve_hit_for_mode(_rules_mode, damage,
			toughness, 0, Callable(), func() -> int: return roll_face)
		var key: String = str(out.result)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] += 1
	var page: String = {"bug_hunt": "Bug Hunt p.178", "planetfall": "Planetfall pp.37-38"} \
		.get(_rules_mode, "Core Rules p.46")
	var lines: PackedStringArray = [
		"[b]Damage (%s)[/b]" % page,
		"1D6 + %d against Toughness %d:" % [damage, toughness],
	]
	for key: String in order:
		lines.append("  %s: %d in 6" % [str(RESULT_TEXT.get(key, key)), int(counts[key])])
	lines.append(str(DAMAGE_NOTES.get(_rules_mode, DAMAGE_NOTES.core)))
	var result := {
		"calc_type": "damage",
		"rules_mode": _rules_mode,
		"weapon_damage": damage,
		"target_toughness": toughness,
		"outcomes": counts,
		"explanation": "\n".join(lines),
	}
	_display_result(result)
	calculation_completed.emit("damage", result)


func _display_result(result: Dictionary) -> void:
	if result_label:
		result_label.clear()
		result_label.append_text(str(result.explanation))


func _on_mode_changed(index: int) -> void:
	var id: int = calculation_mode.get_item_id(index) if calculation_mode else index
	current_mode = id as CalcMode
	_update_ui_for_mode()


func _update_ui_for_mode() -> void:
	var to_hit: bool = current_mode == CalcMode.TO_HIT
	for node: Control in [attacker_combat, shot_option]:
		if node and node.get_parent():
			(node.get_parent() as Control).visible = to_hit
	for node: Control in [weapon_damage, target_toughness]:
		if node and node.get_parent():
			(node.get_parent() as Control).visible = not to_hit
