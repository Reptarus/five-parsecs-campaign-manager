class_name PsionicManager
extends Resource

# Character script is now an autoload, so we don't need to preload it
# const CharacterScript = preload("res://Characters/Character.gd")

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
	GlobalEnums.PsionicPower.PSIONIC_SCARE: "Psionic Scare"
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
	return PSIONIC_POWERS[randi() % 10 + 1]

func adjust_power(power: String) -> String:
	var index = PSIONIC_POWERS.values().find(power)
	var new_index = (index + [-1, 1].pick_random() + 10) % 10
	return PSIONIC_POWERS.values()[new_index]

func use_power(power: String, character) -> bool:
	var projection_roll = randi() % 6 + 1 + randi() % 6 + 1
	if character.has_ability("Enhanced " + power):
		projection_roll += randi() % 6 + 1
	return projection_roll >= 7  # Assuming 7+ is a success

func strain(character) -> bool:
	var strain_roll = randi() % 6 + 1
	if strain_roll in [4, 5]:
		character.apply_status_effect(StatusEffect.new(StatusEffect.EffectType.STUNNED, 1))
		return true
	elif strain_roll == 6:
		character.apply_status_effect(StatusEffect.new(StatusEffect.EffectType.STUNNED, 1))
		return false
	return true

func determine_enemy_psionic_action(character, all_characters: Array) -> Dictionary:
	var best_power: String = ""
	var best_score: float = -1.0
	var best_target = null
	for power in character.psionic_powers:
		for target in get_valid_targets(character, power, all_characters):
			var score = evaluate_psionic_action(character, power, target)
			if score > best_score:
				best_score = score
				best_power = power
				best_target = target

	return {"power": best_power, "target": best_target}

func get_valid_targets(character, power: String, all_characters: Array) -> Array:
	var valid_targets = []
	
	for target in all_characters:
		if _is_valid_target(character, target, power):
			valid_targets.append(target)
	
	# Filter targets based on range (assuming a range of 12" for all powers)
	return _filter_targets_by_range(character, valid_targets)

func _is_valid_target(character, target, power: String) -> bool:
	match power:
		"Barrier", "Shroud", "Predict", "Rejuvenate":
			return target == character or _is_ally(character, target)
		"Grab", "Lift", "Enrage", "Shock", "Psionic Scare":
			return _is_enemy(character, target)
		"Guide":
			return _is_ally(character, target) and target != character
		_:
			return false

func _is_ally(character, target) -> bool:
	return character.faction == target.faction

func _is_enemy(character, target) -> bool:
	return character.faction != target.faction

func _filter_targets_by_range(character, targets: Array) -> Array:
	var max_range = 12 * 25.4  # 12 inches converted to mm
	return targets.filter(func(target): return character.global_position.distance_to(target.global_position) <= max_range)

func evaluate_psionic_action(character, power: String, target) -> float:
	var score = 0.0
	
	match power:
		"Barrier":
			score = 10.0 if target.health < target.max_health * 0.5 else 5.0
		"Grab":
			score = 15.0 if target.is_in_cover() else 8.0
		"Lift":
			score = 12.0 if not target.is_in_cover() else 6.0
		"Shroud":
			score = 18.0 if character.health < character.max_health * 0.3 else 10.0
		"Enrage":
			score = 20.0 if target.is_enemy(character) else -5.0
		"Predict":
			score = 15.0 if target == character else 8.0
		"Shock":
			score = 25.0 if target.is_enemy(character) else -10.0
		"Rejuvenate":
			score = 30.0 if target.health < target.max_health * 0.5 else 5.0
		"Guide":
			score = 22.0 if target.is_ally(character) else -5.0
		"Psionic Scare":
			score = 28.0 if target.is_enemy(character) else -15.0

	# Adjust score based on character's current situation
	if character.health < character.max_health * 0.3:
		score *= 1.5
	if character.is_in_cover():
		score *= 1.2

	return score

func check_psionic_legality(_world: World) -> String:
	var roll = randi() % 100 + 1
	if roll <= 25:
		return "Outlawed"
	elif roll <= 55:
		return "Highly unusual"
	else:
		return "Accepted"

func acquire_new_power(character) -> void:
	var new_power = roll_power()
	while new_power in character.powers:
		new_power = adjust_power(new_power)
	character.powers.append(new_power)
	print("Character acquired new power: ", new_power)

func enhance_power(character, power: String) -> void:
	if power in character.powers and not character.has_ability("Enhanced " + power):
		character.add_ability("Enhanced " + power)

func serialize() -> Dictionary:
	return {"powers": powers}

static func deserialize(data: Dictionary) -> PsionicManager:
	var manager = PsionicManager.new()
	manager.powers = data["powers"]
	return manager
