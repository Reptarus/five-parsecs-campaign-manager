# WeaponSystem.gd

extends Node

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
  "Hand laser": {"range": 12, "shots": 1, "damage": 0, "traits": ["Snap Shot", "Pistol"]},
  "Hand gun": {"range": 12, "shots": 1, "damage": 0, "traits": ["Pistol"]},
  "Hold out pistol": {"range": 4, "shots": 1, "damage": 0, "traits": ["Pistol", "Melee"]},
  "Hunting rifle": {"range": 30, "shots": 1, "damage": 1, "traits": ["Heavy"]},
  "Hyper blaster": {"range": 24, "shots": 3, "damage": 1, "traits": []},
  "Infantry laser": {"range": 30, "shots": 1, "damage": 0, "traits": ["Snap Shot"]},
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

const WEAPON_TRAITS = {
  "Area": func(weapon, target, _character_inventory): 
    var nearby_figures = get_figures_within_range(target, 2)
    for figure in nearby_figures:
      if figure.has_method("take_damage"):
        figure.take_damage(weapon.damage),
  "Clumsy": func(_weapon, user, opponent): 
    return -1 if opponent.stats.speed > user.stats.speed else 0,
  "Critical": func(_weapon, roll): 
    return 2 if roll == 6 else 1,
  "Elegant": func(_weapon, user):
    if user.has_method("is_in_brawl") and user.is_in_brawl():
      user.can_reroll_brawl = true,
  "Focused": func(weapon):
    weapon.single_target_only = true,
  "Heavy": func(_weapon, user):
    return -1 if user.moved_this_turn else 0,
  "Impact": func(_weapon, target):
    if target.is_stunned:
      target.stun_count += 1,
  "Melee": func(_weapon):
    return 2,  # +2 to Brawling rolls
  "Piercing": func(_weapon, target):
    target.armor_save = 0,
  "Pistol": func(_weapon):
    return 1,  # +1 to Brawling rolls
  "Single use": func(weapon, character_inventory):
    weapon.uses_left -= 1
    if weapon.uses_left <= 0:
      remove_weapon(weapon, character_inventory),
  "Snap shot": func(_weapon, distance):
    return 1 if distance <= 6 else 0,
  "Stun": func(_weapon, target):
    target.stunned = true
    target.stun_count = 1,
  "Terrifying": func(_weapon, target):
    target.must_retreat = true
    target.retreat_distance = roll_dice(1, 6),
  "Burst": func(weapon):
    weapon.shots += 1,
  "Reliable": func(weapon):
    weapon.jam_threshold = max(1, weapon.jam_threshold - 1),
  "Unwieldy": func(weapon, user):
    return -1 if user.stats.strength < weapon.strength_requirement else 0,
  "Inaccurate": func(_weapon):
    return -1,  # -1 to hit rolls
  "Slow": func(_weapon, user):
    user.actions_this_turn = max(0, user.actions_this_turn - 1)
}

const WEAPON_MODS = {
  "Assault blade": {
    "effect": func(weapon):
      weapon.traits.append("Melee")
      weapon.damage += 1
      # Add logic for winning combat on a Draw
    "restrictions": func(weapon): return "Pistol" not in weapon.traits
  },
  "Beam light": {
    "effect": func(weapon):
      weapon.visibility_bonus = 3
    "restrictions": func(_weapon): return true
  },
  "Bipod": {
    "effect": func(weapon):
      weapon.bipod_bonus = 1
    "restrictions": func(weapon): return "Pistol" not in weapon.traits
  },
  "Hot shot pack": {
    "effect": func(weapon):
      if weapon.name in ["Blast Pistol", "Blast Rifle", "Hand Laser", "Infantry Laser"]:
        weapon.damage += 1
      weapon.hot_shot = true
    "restrictions": func(_weapon): return true
  },
  "Stabilizer": {
    "effect": func(weapon):
      weapon.traits.erase("Heavy")
    "restrictions": func(_weapon): return true
  },
  "Shock attachment": {
    "effect": func(weapon):
      weapon.traits.append("Impact")
    "restrictions": func(_weapon): return true
  },
  "Upgrade kit": {
    "effect": func(weapon):
      weapon.range += 2
    "restrictions": func(_weapon): return true
  }
}

var game_state: GameState

func initialize(gs: GameState) -> void:
  game_state = gs

func apply_mod(weapon, mod_name):
  var mod = WEAPON_MODS[mod_name]
  if mod.restrictions.call(weapon):
    mod.effect.call(weapon)

func calculate_hit_bonus(weapon, distance, is_aiming, is_in_cover):
  var bonus = 0
  if weapon.bipod_bonus > 0 and distance > 8 and (is_aiming or is_in_cover):
    bonus += weapon.bipod_bonus
  return bonus

func check_overheat(weapon, roll):
  return weapon.hot_shot and roll == 6

func apply_trait(trait_name: String, weapon, context: Dictionary) -> int:
  if trait_name in WEAPON_TRAITS:
    var effect_function = WEAPON_TRAITS[trait_name]
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