class_name PsionicManager
extends Resource

const PSIONIC_POWERS = {
	GlobalEnums.PsionicPower.BARRIER: "Barrier",
	GlobalEnums.PsionicPower.GRAB: "Grab",
	GlobalEnums.PsionicPower.LIFT: "Lift",
	GlobalEnums.PsionicPower.SHROUD: "Shroud",
	GlobalEnums.PsionicPower.ENRAGE: "Enrage",
	GlobalEnums.PsionicPower.PREDICT: "Predict",
	GlobalEnums.PsionicPower.SHOCK: "Shock",
	GlobalEnums.PsionicPower.REJUVENATE: "Rejuvenate",
	GlobalEnums.PsionicPower.GUIDE: "Guide",
	GlobalEnums.PsionicPower.PSIONIC_SCARE: "Psionic Scare",
	GlobalEnums.PsionicPower.CRUSH: "Crush",
	GlobalEnums.PsionicPower.DIRECT: "Direct",
	GlobalEnums.PsionicPower.DOMINATE: "Dominate"
}

var powers: Array[String] = []

func _init():
	randomize()

func generate_starting_powers():
	for _i in range(2):
		var power = roll_power()
		if power not in powers:
			powers.append(power)
		else:
			powers.append(adjust_power(power))

func roll_power() -> String:
	return PSIONIC_POWERS.values()[randi() % PSIONIC_POWERS.size()]

func adjust_power(power: String) -> String:
	var index = PSIONIC_POWERS.values().find(power)
	var new_index = (index + [-1, 1].pick_random() + PSIONIC_POWERS.size()) % PSIONIC_POWERS.size()
	return PSIONIC_POWERS.values()[new_index]

func use_power(power: String, character: Character) -> bool:
	var projection_roll = GameManager.roll_dice(2, 6)
	if character.traits.has("Enhanced " + power):
		projection_roll += GameManager.roll_dice(1, 6)
	return projection_roll >= 7  # Assuming 7+ is a success

func strain(character: Character) -> bool:
	var strain_roll = GameManager.roll_dice(1, 6)
	if strain_roll >= 4:
		character.apply_status_effect(GlobalEnums.StatusEffectType.STUN, 1)
		return strain_roll != 6
	
	return true

func determine_enemy_psionic_action(character: Character, all_characters: Array[Character]) -> Dictionary:
	var best_power: String = ""
	var best_score: float = -1.0
	var best_target: Character = null
	for power in character.psionic_powers:
		for target in get_valid_targets(character, power, all_characters):
			var score = evaluate_psionic_action(character, power, target)
			if score > best_score:
				best_score = score
				best_power = power
				best_target = target

	return {"power": best_power, "target": best_target}

func get_valid_targets(character: Character, power: String, all_characters: Array[Character]) -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for target in all_characters:
		if _is_valid_target(character, target, power):
			valid_targets.append(target)
	
	# Filter targets based on range (assuming a range of 12" for all powers)
	return _filter_targets_by_range(character, valid_targets)

func _is_valid_target(character: Character, target: Character, power: String) -> bool:
	match power:
		"Barrier", "Shroud", "Predict", "Rejuvenate":
			return target == character or _is_ally(character, target)
		"Grab", "Lift", "Enrage", "Shock", "Psionic Scare", "Crush", "Dominate":
			return _is_enemy(character, target)
		"Guide", "Direct":
			return _is_ally(character, target) and target != character
		_:
			return false

func _is_ally(character: Character, target: Character) -> bool:
	return character.faction == target.faction

func _is_enemy(character: Character, target: Character) -> bool:
	return character.faction != target.faction

func _filter_targets_by_range(character: Character, targets: Array[Character]) -> Array[Character]:
	var max_range = 12 * 25.4  # 12 inches converted to mm
	return targets.filter(func(target): return character.global_position.distance_to(target.global_position) <= max_range)

func evaluate_psionic_action(character: Character, power: String, target: Character) -> float:
	var score = 0.0
	
	match power:
		"Barrier":
			score = 10.0 if target.toughness < 3 else 5.0
		"Grab":
			score = 15.0 if target.is_in_cover() else 8.0
		"Lift":
			score = 12.0 if not target.is_in_cover() else 6.0
		"Shroud":
			score = 18.0 if character.toughness < 2 else 10.0
		"Enrage":
			score = 20.0 if _is_enemy(character, target) else -5.0
		"Predict":
			score = 15.0 if target == character else 8.0
		"Shock":
			score = 25.0 if _is_enemy(character, target) else -10.0
		"Rejuvenate":
			score = 30.0 if target.toughness < 2 else 5.0
		"Guide":
			score = 22.0 if _is_ally(character, target) else -5.0
		"Psionic Scare":
			score = 28.0 if _is_enemy(character, target) else -15.0
		"Crush":
			score = 35.0 if _is_enemy(character, target) else -20.0
		"Direct":
			score = 25.0 if _is_ally(character, target) else -10.0
		"Dominate":
			score = 40.0 if _is_enemy(character, target) else -25.0

	# Adjust score based on character's current situation
	if character.toughness < 2:
		score *= 1.5
	if character.is_in_cover():
		score *= 1.2

	return score

func check_psionic_legality(world: Location) -> GlobalEnums.PsionicLegality:
	var roll = GameManager.roll_dice(1, 100)
	if roll <= 25:
		return GlobalEnums.PsionicLegality.ILLEGAL
	elif roll <= 55:
		return GlobalEnums.PsionicLegality.RESTRICTED
	else:
		return GlobalEnums.PsionicLegality.LEGAL

func acquire_new_power(character: Character) -> void:
	var new_power = roll_power()
	while new_power in character.psionic_powers:
		new_power = adjust_power(new_power)
	character.psionic_powers.append(new_power)
	print("Character acquired new power: ", new_power)

func enhance_power(character: Character, power: String) -> void:
	if power in character.psionic_powers and not character.traits.has("Enhanced " + power):
		character.traits.append("Enhanced " + power)

func serialize() -> Dictionary:
	return {"powers": powers}

static func deserialize(data: Dictionary) -> PsionicManager:
	var manager = PsionicManager.new()
	manager.powers = data["powers"]
	return manager
