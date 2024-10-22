# WeaponSystem.gd
class_name WeaponSystem
extends Node

# Constants
const BASE_WEAPONS = {
	"Auto rifle": {"range": 24, "shots": 2, "damage": 0, "traits": []},
	"Beam pistol": {"range": 10, "shots": 1, "damage": 1, "traits": ["Pistol", "Critical"]},
	"Blade": {"range": 0, "shots": 1, "damage": 0, "traits": ["Melee"]},
	"Blast pistol": {"range": 8, "shots": 1, "damage": 1, "traits": ["Pistol"]},
	"Blast rifle": {"range": 16, "shots": 1, "damage": 1, "traits": []},
	"Boarding saber": {"range": 0, "shots": 1, "damage": 1, "traits": ["Melee", "Elegant"]},
	"Brutal melee weapon": {"range": 0, "shots": 1, "damage": 1, "traits": ["Melee", "Clumsy"]},
	"Cling fire pistol": {"range": 12, "shots": 2, "damage": 1, "traits": ["Focused", "Terrifying"]},
	"Colony rifle": {"range": 18, "shots": 1, "damage": 0, "traits": []},
	"Dazzle grenade": {"range": 6, "shots": 1, "damage": 0, "traits": ["Area", "Stun", "Single use"]},
	"Duelling pistol": {"range": 8, "shots": 1, "damage": 0, "traits": ["Pistol", "Critical"]},
	"Flak gun": {"range": 8, "shots": 2, "damage": 1, "traits": ["Focused", "Critical"]},
	"Frakk grenade": {"range": 6, "shots": 2, "damage": 0, "traits": ["Heavy", "Area", "Single use"]},
	"Fury rifle": {"range": 24, "shots": 1, "damage": 2, "traits": ["Heavy", "Piercing"]},
	"Glare sword": {"range": 0, "shots": 1, "damage": 0, "traits": ["Melee", "Elegant", "Piercing"]},
	"Hand cannon": {"range": 8, "shots": 1, "damage": 2, "traits": ["Pistol"]},
	"Hand flamer": {"range": 12, "shots": 2, "damage": 1, "traits": ["Focused", "Area"]},
	"Hand laser": {"range": 12, "shots": 1, "damage": 0, "traits": ["Snap shot", "Pistol"]},
	"Hand gun": {"range": 12, "shots": 1, "damage": 0, "traits": ["Pistol"]},
	"Hold out pistol": {"range": 4, "shots": 1, "damage": 0, "traits": ["Pistol", "Melee"]},
	"Hunting rifle": {"range": 30, "shots": 1, "damage": 1, "traits": ["Heavy"]},
	"Hyper blaster": {"range": 24, "shots": 3, "damage": 1, "traits": []},
	"Infantry laser": {"range": 30, "shots": 1, "damage": 0, "traits": ["Snap shot"]},
	"Machine pistol": {"range": 8, "shots": 2, "damage": 0, "traits": ["Pistol", "Focused"]},
	"Marksman's rifle": {"range": 36, "shots": 1, "damage": 0, "traits": ["Heavy"]},
	"Military rifle": {"range": 24, "shots": 1, "damage": 0, "traits": []},
	"Needle rifle": {"range": 18, "shots": 2, "damage": 0, "traits": ["Critical"]},
	"Plasma rifle": {"range": 20, "shots": 2, "damage": 1, "traits": ["Focused", "Piercing"]},
	"Power claw": {"range": 0, "shots": 1, "damage": 3, "traits": ["Melee", "Clumsy"]},
	"Rattle gun": {"range": 24, "shots": 3, "damage": 0, "traits": ["Heavy"]},
	"Ripper sword": {"range": 0, "shots": 1, "damage": 1, "traits": ["Melee"]},
	"Scrap pistol": {"range": 9, "shots": 1, "damage": 0, "traits": ["Pistol"]},
	"Shatter axe": {"range": 0, "shots": 1, "damage": 2, "traits": ["Melee"]},
	"Shell gun": {"range": 30, "shots": 2, "damage": 0, "traits": ["Heavy", "Area"]},
	"Shotgun": {"range": 12, "shots": 2, "damage": 1, "traits": ["Focused"]},
	"Suppression maul": {"range": 0, "shots": 1, "damage": 1, "traits": ["Melee", "Impact"]}
}

# Variables
var weapon_traits: Dictionary = {}
var weapon_mods: Dictionary = {}
var game_state: GameStateManager

# Initialization
func _init() -> void:
	initialize_weapon_traits()
	initialize_weapon_mods()

func initialize(gs: GameStateManager) -> void:
	game_state = gs

func initialize_weapon_traits() -> void:
	weapon_traits = {
		"Area": area_trait,
		"Clumsy": clumsy_trait,
		"Critical": critical_trait,
		"Elegant": elegant_trait,
		"Focused": focused_trait,
		"Heavy": heavy_trait,
		"Impact": impact_trait,
		"Melee": melee_trait,
		"Piercing": piercing_trait,
		"Pistol": pistol_trait,
		"Single use": single_use_trait,
		"Snap shot": snap_shot_trait,
		"Stun": stun_trait,
		"Terrifying": terrifying_trait
	}

func initialize_weapon_mods() -> void:
	weapon_mods = {
		"Assault blade": {
			"effect": assault_blade_effect,
			"restrictions": assault_blade_restrictions
		},
		"Beam light": {
			"effect": beam_light_effect,
			"restrictions": always_true
		},
		"Bipod": {
			"effect": bipod_effect,
			"restrictions": not_pistol_restrictions
		},
		"Hot shot pack": {
			"effect": hot_shot_pack_effect,
			"restrictions": always_true
		},
		"Stabilizer": {
			"effect": stabilizer_effect,
			"restrictions": always_true
		},
		"Shock attachment": {
			"effect": shock_attachment_effect,
			"restrictions": always_true
		},
		"Upgrade kit": {
			"effect": upgrade_kit_effect,
			"restrictions": always_true
		}
	}

# Weapon Trait Functions
func area_trait(weapon: Weapon, target: Character, _character_inventory: CharacterInventory) -> void:
	var nearby_figures = get_figures_within_range(target.get_parent(), 2)
	for figure in nearby_figures:
		if figure.has_method("take_damage"):
			figure.take_damage(weapon.damage)

func clumsy_trait(_weapon: Weapon, user: Character, opponent: Character) -> int:
	return -1 if opponent.stats.speed > user.stats.speed else 0

func critical_trait(_weapon: Weapon, roll: int) -> int:
	return 2 if roll == 6 else 1

func elegant_trait(_weapon: Weapon, user: Character) -> void:
	if user.has_method("is_in_brawl") and user.is_in_brawl():
		user.can_reroll_brawl = true

func focused_trait(weapon: Weapon) -> void:
	weapon.single_target_only = true

func heavy_trait(_weapon: Weapon, user: Character) -> int:
	return -1 if user.moved_this_turn else 0

func impact_trait(_weapon: Weapon, target: Character) -> void:
	if target.is_stunned:
		target.stun_count += 1

func melee_trait(_weapon: Weapon) -> int:
	return 2  # +2 to Brawling rolls

func piercing_trait(_weapon: Weapon, target: Character) -> void:
	target.armor_save = 0

func pistol_trait(_weapon: Weapon) -> int:
	return 1  # +1 to Brawling rolls

func single_use_trait(weapon: Weapon, character_inventory: CharacterInventory) -> void:
	weapon.uses_left -= 1
	if weapon.uses_left <= 0:
		remove_weapon(weapon, character_inventory)

func snap_shot_trait(_weapon: Weapon, distance: float) -> int:
	return 1 if distance <= 6 else 0

func stun_trait(_weapon: Weapon, target: Character) -> void:
	target.stunned = true
	target.stun_count = 1

func terrifying_trait(_weapon: Weapon, target: Character) -> void:
	target.must_retreat = true
	target.retreat_distance = roll_dice(1, 6)

# Weapon Mod Functions
func assault_blade_effect(weapon: Weapon) -> void:
	weapon.add_trait("Melee")
	weapon.set_damage(weapon.get_damage() + 1)

func assault_blade_restrictions(weapon: Weapon) -> bool:
	return not weapon.has_trait("Pistol")

func beam_light_effect(weapon: Weapon) -> void:
	weapon.set_visibility_bonus(3)

func bipod_effect(weapon: Weapon) -> void:
	weapon.set_bipod_bonus(1)

func hot_shot_pack_effect(weapon: Weapon) -> void:
	if weapon.get_name() in ["Blast Pistol", "Blast Rifle", "Hand Laser", "Infantry Laser"]:
		weapon.set_damage(weapon.get_damage() + 1)
	weapon.set_hot_shot(true)

func stabilizer_effect(weapon: Weapon) -> void:
	weapon.remove_trait("Heavy")

func shock_attachment_effect(weapon: Weapon) -> void:
	weapon.add_trait("Impact")

func upgrade_kit_effect(weapon: Weapon) -> void:
	weapon.set_range(weapon.get_range() + 2)

func always_true(_weapon: Weapon) -> bool:
	return true

func not_pistol_restrictions(weapon: Weapon) -> bool:
	return not weapon.has_trait("Pistol")

# Weapon System Functions
func apply_mod(weapon: Weapon, mod_name: String) -> void:
	var mod = weapon_mods[mod_name]
	if mod.restrictions.call(weapon):
		mod.effect.call(weapon)

func calculate_hit_bonus(weapon: Weapon, distance: float, is_aiming: bool, is_in_cover: bool) -> int:
	var bonus = 0
	if weapon.bipod_bonus > 0 and distance > 8 and (is_aiming or is_in_cover):
		bonus += weapon.bipod_bonus
	return bonus

func check_overheat(weapon: Weapon, roll: int) -> bool:
	return weapon.hot_shot and roll == 6

func apply_trait(trait_name: String, weapon: Weapon, context: Dictionary) -> int:
	if trait_name in weapon_traits:
		var effect_function = weapon_traits[trait_name]
		var method_info = effect_function.get_method_info()
		var arg_count = method_info.args.size() if method_info else 0
		match arg_count:
			2:
				return effect_function.call(weapon, context.get("target"))
			1:
				return effect_function.call(weapon)
			_:
				push_warning("Unexpected argument count for trait: " + trait_name)
	return 0

# Helper functions
func get_figures_within_range(target: Node, range_value: float) -> Array[Character]:
	var nearby_figures: Array[Character] = []
	var all_figures = get_tree().get_nodes_in_group("figures")
	for figure in all_figures:
		if figure != target and figure.global_position.distance_to(target.global_position) <= range_value:
			nearby_figures.append(figure)
	return nearby_figures

func remove_weapon(weapon: Weapon, character_inventory: CharacterInventory) -> void:
	if character_inventory and character_inventory.has_method("get_all_items") and weapon in character_inventory.get_all_items():
		character_inventory.remove_item(weapon)
	if weapon.is_equipped and weapon.owner and weapon.owner.has_method("unequip_weapon"):
		weapon.owner.unequip_weapon(weapon)

func roll_dice(number: int, sides: int) -> int:
	var total = 0
	for _i in range(number):
		total += randi() % sides + 1
	return total

func check_reaction(figure: Character) -> void:
	var reaction_roll = roll_dice(2, 6)
	figure.can_react = reaction_roll <= figure.stats.reactions

func resolve_critical_hit(_weapon: Weapon, target: Character) -> void:
	var crit_roll = roll_dice(1, 6)
	match crit_roll:
		1, 2:
			target.take_damage(1)
		3, 4:
			target.take_damage(2)
		5:
			target.take_damage(3)
		6:
			target.set_state(GlobalEnums.CharacterState.OUT_OF_ACTION)

func check_ammo_depletion(weapon: Weapon) -> void:
	if weapon.ammo > 0:
		var depletion_roll = roll_dice(1, 6)
		if depletion_roll == 1:
			weapon.ammo = max(0, weapon.ammo - 1)
			if weapon.ammo == 0:
				print("Weapon out of ammo: ", weapon.name)

func get_weapon_range(weapon: Weapon) -> int:
	return BASE_WEAPONS[weapon.name]["range"] if weapon.name in BASE_WEAPONS else 0

func get_weapon_shots(weapon: Weapon) -> int:
	return BASE_WEAPONS[weapon.name]["shots"] if weapon.name in BASE_WEAPONS else 1

func get_weapon_damage(weapon: Weapon) -> int:
	return BASE_WEAPONS[weapon.name]["damage"] if weapon.name in BASE_WEAPONS else 0

func get_weapon_traits(weapon: Weapon) -> Array:
	return BASE_WEAPONS[weapon.name]["traits"] if weapon.name in BASE_WEAPONS else []

func is_weapon_melee(weapon: Weapon) -> bool:
	return weapon.has_trait("Melee")

func is_weapon_ranged(weapon: Weapon) -> bool:
	return not is_weapon_melee(weapon)

func can_weapon_attack(weapon: Weapon, attacker: Character, target: Character) -> bool:
	var distance = attacker.global_position.distance_to(target.global_position)
	return distance <= get_weapon_range(weapon)

func serialize() -> Dictionary:
	var serialized_data = {
		"weapon_traits": {},
		"weapon_mods": {},
		"base_weapons": BASE_WEAPONS
	}
	
	for trait_name in weapon_traits:
		serialized_data["weapon_traits"][trait_name] = weapon_traits[trait_name].get_method()
	
	for mod_name in weapon_mods:
		serialized_data["weapon_mods"][mod_name] = {
			"effect": weapon_mods[mod_name]["effect"].get_method(),
			"restrictions": weapon_mods[mod_name]["restrictions"].get_method()
		}
	
	return serialized_data

func deserialize(data: Dictionary) -> void:
	BASE_WEAPONS.clear()
	BASE_WEAPONS.merge(data["base_weapons"])
	
	weapon_traits.clear()
	for trait_name in data["weapon_traits"]:
		weapon_traits[trait_name] = Callable(self, data["weapon_traits"][trait_name])
	
	weapon_mods.clear()
	for mod_name in data["weapon_mods"]:
		weapon_mods[mod_name] = {
			"effect": Callable(self, data["weapon_mods"][mod_name]["effect"]),
			"restrictions": Callable(self, data["weapon_mods"][mod_name]["restrictions"])
		}