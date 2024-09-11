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

func use_power(power: String, character: Character) -> bool:
	var projection_roll = randi() % 6 + 1 + randi() % 6 + 1
	if character.has_ability("Enhanced " + power):
		projection_roll += randi() % 6 + 1
	return projection_roll >= 7  # Assuming 7+ is a success

func strain(character: Character) -> bool:
	var strain_roll = randi() % 6 + 1
	if strain_roll in [4, 5]:
		character.apply_status_effect(StatusEffect.new("Stunned", 1))
		return true
	elif strain_roll == 6:
		character.apply_status_effect(StatusEffect.new("Stunned", 1))
		return false
	return true

func determine_enemy_psionic_action(character: Character) -> Dictionary:
	var best_power = ""
	var best_score = -1
	var best_target = null

	for power in character.powers:
		for target in get_valid_targets(character, power):
			var score = evaluate_psionic_action(character, power, target)
			if score > best_score:
				best_score = score
				best_power = power
				best_target = target

	return {"power": best_power, "target": best_target}

func get_valid_targets(character: Character, power: String) -> Array:
	# Implement logic to get valid targets based on the power
	# This will depend on your game's rules and structure
	pass

func evaluate_psionic_action(character: Character, power: String, target: Character) -> float:
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

func check_psionic_legality(world: World) -> String:
	var roll = randi() % 100 + 1
	if roll <= 25:
		return "Outlawed"
	elif roll <= 55:
		return "Highly unusual"
	else:
		return "Who cares?"

func acquire_new_power(character: Character) -> void:
	var new_power = roll_power()
	while new_power in character.powers:
		new_power = adjust_power(new_power)
	character.powers.append(new_power)

func enhance_power(character: Character, power: String) -> void:
	if power in character.powers and not character.has_ability("Enhanced " + power):
		character.add_ability("Enhanced " + power)

func serialize() -> Dictionary:
	return {"powers": powers}

static func deserialize(data: Dictionary) -> PsionicManager:
	var manager = PsionicManager.new()
	manager.powers = data["powers"]
	return manager
