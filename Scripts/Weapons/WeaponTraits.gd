extends Node

class_name WeaponTraits

var game_state: GameState

func initialize(gs: GameState) -> void:
    game_state = gs

# Function definitions
func area_effect(weapon: Weapon, target: Node,_character_inventory: CharacterInventory) -> void:
    var nearby_figures = get_figures_within_range(target, 2)
    for figure in nearby_figures:
        if figure.has_method("take_damage"):
            figure.take_damage(weapon.damage)

func clumsy_effect(_weapon: Weapon, user: Character, opponent: Character) -> int:
    return -1 if opponent.stats.speed > user.stats.speed else 0

func critical_effect(_weapon: Weapon, roll: int) -> int:
    return 2 if roll == 6 else 1

func elegant_effect(_weapon: Weapon, user: Character) -> void:
    if user.has_method("is_in_brawl") and user.is_in_brawl():
        user.can_reroll_brawl = true

func focused_effect(weapon: Weapon) -> void:
    weapon.single_target_only = true

func heavy_effect(_weapon: Weapon, user: Character) -> int:
    return -1 if user.moved_this_turn else 0

func impact_effect(_weapon: Weapon, target: Character) -> void:
    if target.is_stunned:
        target.stun_count += 1

func melee_effect(_weapon: Weapon) -> int:
    return 2  # +2 to Brawling rolls

func piercing_effect(_weapon: Weapon, target: Character) -> void:
    target.armor_save = 0

func pistol_effect(_weapon: Weapon) -> int:
    return 1  # +1 to Brawling rolls

func single_use_effect(weapon: Weapon, character_inventory: CharacterInventory) -> void:
    weapon.uses_left -= 1
    if weapon.uses_left <= 0:
        remove_weapon(weapon, character_inventory)

func snap_shot_effect(_weapon: Weapon, distance: float) -> int:
    return 1 if distance <= 6 else 0

func stun_effect(_weapon: Weapon, target: Character) -> void:
    target.stunned = true
    target.stun_count = 1

func terrifying_effect(_weapon: Weapon, target: Character) -> void:
    target.must_retreat = true
    target.retreat_distance = roll_dice(1, 6)

func burst_effect(weapon: Weapon) -> void:
    weapon.shots += 1

func reliable_effect(weapon: Weapon) -> void:
    weapon.jam_threshold = max(1, weapon.jam_threshold - 1)

func unwieldy_effect(weapon: Weapon, user: Character) -> int:
    return -1 if user.stats.strength < weapon.strength_requirement else 0

func inaccurate_effect(_weapon: Weapon) -> int:
    return -1  # -1 to hit rolls

func slow_effect(_weapon: Weapon, user: Character) -> void:
    user.actions_this_turn = max(0, user.actions_this_turn - 1)

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
func get_figures_within_range(target: Node, range_value: float) -> Array:
    var nearby_figures = []
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

# Additional helper functions based on the rules
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
            target.set_state("out_of_action")

func check_ammo_depletion(weapon: Weapon) -> void:
    if weapon.ammo > 0:
        var depletion_roll = roll_dice(1, 6)
        if depletion_roll == 1:
            weapon.ammo = max(0, weapon.ammo - 1)
            if weapon.ammo == 0:
                print("Weapon out of ammo: ", weapon.name)

# Balancing tips and potential improvements remain unchanged
