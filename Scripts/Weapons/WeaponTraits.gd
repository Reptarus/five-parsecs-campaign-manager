extends Node

class_name WeaponTraits

## Manages weapon traits and their effects in the game.
## This class defines the behavior of various weapon traits, providing
## methods to apply their effects during combat.

# Function definitions
func area_effect(weapon: Weapon, target):
	# Affects all figures within 2" of the target
	var nearby_figures = get_figures_within_range(target, 2)
	for figure in nearby_figures:
		apply_damage(figure, weapon.damage)

func clumsy_effect(_weapon: Weapon, user, opponent):
	if opponent.speed > user.speed:
		return -1
	return 0

func critical_effect(_weapon: Weapon, roll):
	if roll == 6:
		return 2
	return 1

func elegant_effect(_weapon: Weapon, user):
	# Allow reroll in Brawling
	if user.is_in_brawl():
		user.can_reroll_brawl = true

func focused_effect(weapon: Weapon):
	# Ensure all shots are against a single target
	weapon.single_target_only = true

func heavy_effect(_weapon: Weapon, user):
	if user.moved_this_turn:
		return -1
	return 0

func impact_effect(_weapon: Weapon, target):
	if target.is_stunned:
		target.stun_count += 1

func melee_effect(_weapon: Weapon):
	return 2  # +2 to Brawling rolls

func piercing_effect(_weapon: Weapon, target):
	target.armor_save = 0

func pistol_effect(_weapon: Weapon):
	return 1  # +1 to Brawling rolls

func single_use_effect(weapon: Weapon):
	weapon.uses_left -= 1
	if weapon.uses_left <= 0:
		remove_weapon(weapon)

func snap_shot_effect(_weapon: Weapon, distance):
	if distance <= 6:
		return 1
	return 0

func stun_effect(_weapon: Weapon, target):
	target.stunned = true
	target.stun_count = 1

func terrifying_effect(_weapon: Weapon, target):
	target.must_retreat = true
	target.retreat_distance = roll_dice(1, 6)

# New traits based on the provided context
func burst_effect(weapon: Weapon):
	weapon.shots += 1

func reliable_effect(weapon: Weapon):
	weapon.jam_threshold -= 1

func unwieldy_effect(weapon: Weapon, user):
	if user.strength < weapon.strength_requirement:
		return -1
	return 0

func inaccurate_effect(_weapon: Weapon):
	return -1  # -1 to hit rolls

func slow_effect(_weapon: Weapon, user):
	user.actions_this_turn -= 1

# Dictionary of weapon traits and their corresponding effect functions
var traits = {
	"Area": area_effect,
	"Clumsy": clumsy_effect,
	"Critical": critical_effect,
	"Elegant": elegant_effect,
	"Focused": focused_effect,
	"Heavy": heavy_effect,
	"Impact": impact_effect,
	"Melee": melee_effect,
	"Piercing": piercing_effect,
	"Pistol": pistol_effect,
	"Single use": single_use_effect,
	"Snap shot": snap_shot_effect,
	"Stun": stun_effect,
	"Terrifying": terrifying_effect,
	"Burst": burst_effect,
	"Reliable": reliable_effect,
	"Unwieldy": unwieldy_effect,
	"Inaccurate": inaccurate_effect,
	"Slow": slow_effect
}

# Applies the effect of a specific trait to a weapon in a given context
func apply_trait(trait_name: String, weapon: Weapon, context: Dictionary) -> int:
	if trait_name in traits:
		var effect_function = traits.get(trait_name)
		var arg_count = effect_function.get_method_info().args.size()
		match arg_count:
			2:
				return effect_function.call(weapon, context)
			1:
				return effect_function.call(weapon)
			_:
				push_warning("Unexpected argument count for trait: " + trait_name)
	return 0

# Helper functions
func get_figures_within_range(target, range_value: int) -> Array:
	var nearby_figures = []
	var all_figures = get_tree().get_nodes_in_group("figures")
	for figure in all_figures:
		if figure != target and figure.position.distance_to(target.position) <= range_value:
			nearby_figures.append(figure)
	return nearby_figures

func apply_damage(figure, damage: int) -> void:
	figure.toughness -= damage
	if figure.toughness <= 0:
		figure.set_state("out_of_action")
		if figure.is_in_group("enemies"):
			GameState.current_battle.enemy_casualties += 1
	else:
		# Check for panic
		var panic_roll = roll_dice(2, 6)
		if panic_roll <= figure.panic_value:
			figure.set_state("panicked")

func remove_weapon(weapon: Weapon) -> void:
	if weapon in GameState.player_inventory.weapons:
		GameState.player_inventory.weapons.erase(weapon)
	if weapon.is_equipped:
		weapon.owner.unequip_weapon(weapon)

func roll_dice(number: int, sides: int) -> int:
	var total = 0
	for i in range(number):
		total += randi() % sides + 1
	return total

# Additional helper functions based on the rules
func check_reaction(figure) -> void:
	var reaction_roll = roll_dice(2, 6)
	if reaction_roll <= figure.reaction_value:
		figure.can_react = true
	else:
		figure.can_react = false

func resolve_critical_hit(_weapon: Weapon, target) -> void:
	var crit_roll = roll_dice(1, 6)
	match crit_roll:
		1, 2:
			apply_damage(target, 1)
		3, 4:
			apply_damage(target, 2)
		5:
			apply_damage(target, 3)
		6:
			target.set_state("out_of_action")

func check_ammo_depletion(weapon: Weapon) -> void:
	if weapon.ammo > 0:
		var depletion_roll = roll_dice(1, 6)
		if depletion_roll == 1:
			weapon.ammo -= 1
			if weapon.ammo == 0:
				print("Weapon out of ammo: ", weapon.name)

# Balancing tips:
# 1. Ensure each trait provides a unique and meaningful effect.
# 2. Balance positive traits (like "Critical") with limitations or drawbacks.
# 3. Consider how traits interact with each other and with weapon stats.
# 4. Implement a system to limit the number of traits a weapon can have.
# 5. Create traits that encourage different playstyles or tactical choices.
# 6. Regularly review and adjust trait effects based on gameplay testing.
# 7. Consider creating "anti-traits" that specifically counter certain traits.

# Potential improvements:
# 1. Implement a trait stacking system for multiple instances of the same trait.
# 2. Create more complex traits that interact with character skills or abilities.
# 3. Add traits that affect non-combat situations (e.g., intimidation, bartering).
# 4. Implement a trait upgrade system where traits can become more powerful.
# 5. Create dynamic traits that change based on in-game conditions or events.
