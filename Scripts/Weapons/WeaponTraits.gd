extends Node

class_name WeaponTraits

## Manages weapon traits and their effects in the game.
## This class defines the behavior of various weapon traits, providing
## methods to apply their effects during combat.

# Function definitions
func area_effect(weapon: Weapon, target):
	# Logic for Area effect
	pass

func clumsy_effect(weapon: Weapon, user, opponent):
	if opponent.speed > user.speed:
		return -1
	return 0

func critical_effect(weapon: Weapon, roll):
	if roll == 6:
		return 2
	return 1

func elegant_effect(weapon: Weapon, user):
	# Logic for rerolling in Brawling
	pass

func focused_effect(weapon: Weapon):
	# Logic to ensure all shots are against a single target
	pass

func heavy_effect(weapon: Weapon, user):
	if user.moved_this_round:
		return -1
	return 0

func impact_effect(weapon: Weapon, target):
	if target.is_stunned:
		target.stun_count += 1

func melee_effect(weapon: Weapon):
	return 2  # +2 to Brawling rolls

func piercing_effect(weapon: Weapon, target):
	target.armor_save = 0

func pistol_effect(weapon: Weapon):
	return 1  # +1 to Brawling rolls

func single_use_effect(weapon: Weapon):
	# Logic to remove weapon after use
	pass

func snap_shot_effect(weapon: Weapon, distance):
	if distance <= 6:
		return 1
	return 0

func stun_effect(weapon: Weapon, target):
	target.stunned = true

func terrifying_effect(weapon: Weapon, target):
	# Logic to make target retreat 1D6"
	pass

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
	"Terrifying": terrifying_effect
}

# Applies the effect of a specific trait to a weapon in a given context
func apply_trait(String, weapon: Weapon, context: Dictionary) -> void:
	if String in traits:
		return traits[String].call(weapon, context)




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
