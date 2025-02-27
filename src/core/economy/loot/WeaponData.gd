extends EquipmentData

# Core weapon stats
@export var damage: int = 1
@export var range: int = 1
@export var weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.BASIC
@export var combat_range: GameEnums.CombatRange = GameEnums.CombatRange.SHORT

# Ammunition and capacity
@export var ammo_capacity: int = -1 # -1 means unlimited
@export var current_ammo: int = -1

# Combat modifiers
var combat_modifiers: Array[GameEnums.CombatModifier] = []
var combat_advantages: Array[GameEnums.CombatAdvantage] = []

# Special rules and characteristics
var special_rules: Array[String] = []
var weapon_class: GameEnums.EnemyWeaponClass = GameEnums.EnemyWeaponClass.BASIC

func _init(weapon_name: String = "",
          weapon_description: String = "",
          weapon_damage: int = 1,
          weapon_range: int = 1,
          p_weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.BASIC,
          p_combat_range: GameEnums.CombatRange = GameEnums.CombatRange.SHORT) -> void:
    super(weapon_name, weapon_description, GameEnums.ItemType.WEAPON)
    damage = weapon_damage
    range = weapon_range
    weapon_type = p_weapon_type
    combat_range = p_combat_range
    _setup_weapon_class()

func _setup_weapon_class() -> void:
    match weapon_type:
        GameEnums.WeaponType.BASIC:
            weapon_class = GameEnums.EnemyWeaponClass.BASIC
        GameEnums.WeaponType.ADVANCED:
            weapon_class = GameEnums.EnemyWeaponClass.ADVANCED
        GameEnums.WeaponType.ELITE:
            weapon_class = GameEnums.EnemyWeaponClass.ELITE
        _:
            weapon_class = GameEnums.EnemyWeaponClass.BASIC

func get_damage() -> int:
    var total_damage = damage
    
    # Apply combat advantages
    for advantage in combat_advantages:
        match advantage:
            GameEnums.CombatAdvantage.MINOR:
                total_damage += 1
            GameEnums.CombatAdvantage.MAJOR:
                total_damage += 2
            GameEnums.CombatAdvantage.OVERWHELMING:
                total_damage += 3
    
    return total_damage

func get_range() -> int:
    return range

func get_combat_range() -> GameEnums.CombatRange:
    return combat_range

func get_weapon_type() -> GameEnums.WeaponType:
    return weapon_type

func get_weapon_class() -> GameEnums.EnemyWeaponClass:
    return weapon_class

func set_weapon_type(type: GameEnums.WeaponType) -> void:
    weapon_type = type
    _setup_weapon_class()

func set_combat_range(new_range: GameEnums.CombatRange) -> void:
    combat_range = new_range

func has_unlimited_ammo() -> bool:
    return ammo_capacity == -1

func get_ammo_capacity() -> int:
    return ammo_capacity

func get_current_ammo() -> int:
    return current_ammo

func set_ammo_capacity(capacity: int) -> void:
    ammo_capacity = capacity
    if current_ammo == -1 or current_ammo > capacity:
        current_ammo = capacity

func reload() -> void:
    if not has_unlimited_ammo():
        current_ammo = ammo_capacity

func use_ammo(amount: int = 1) -> bool:
    if has_unlimited_ammo() or current_ammo >= amount:
        if not has_unlimited_ammo():
            current_ammo -= amount
        return true
    return false

func add_combat_modifier(modifier: GameEnums.CombatModifier) -> void:
    if not modifier in combat_modifiers:
        combat_modifiers.append(modifier)

func remove_combat_modifier(modifier: GameEnums.CombatModifier) -> void:
    combat_modifiers.erase(modifier)

func has_combat_modifier(modifier: GameEnums.CombatModifier) -> bool:
    return modifier in combat_modifiers

func add_combat_advantage(advantage: GameEnums.CombatAdvantage) -> void:
    if not advantage in combat_advantages:
        combat_advantages.append(advantage)

func remove_combat_advantage(advantage: GameEnums.CombatAdvantage) -> void:
    combat_advantages.erase(advantage)

func has_combat_advantage(advantage: GameEnums.CombatAdvantage) -> bool:
    return advantage in combat_advantages

func add_special_rule(rule: String) -> void:
    if not rule in special_rules:
        special_rules.append(rule)

func remove_special_rule(rule: String) -> void:
    special_rules.erase(rule)

func has_special_rule(rule: String) -> bool:
    return rule in special_rules

func get_special_rules() -> Array[String]:
    return special_rules

func serialize() -> Dictionary:
    var data = super.serialize()
    data.merge({
        "damage": damage,
        "range": range,
        "weapon_type": weapon_type,
        "combat_range": combat_range,
        "ammo_capacity": ammo_capacity,
        "current_ammo": current_ammo,
        "combat_modifiers": combat_modifiers.duplicate(),
        "combat_advantages": combat_advantages.duplicate(),
        "special_rules": special_rules.duplicate(),
        "weapon_class": weapon_class
    })
    return data

func deserialize(data: Dictionary) -> WeaponData:
    super.deserialize(data)
    if not data.has_all(["damage", "range", "weapon_type"]):
        push_error("Invalid weapon data for deserialization")
        return self
        
    damage = data.get("damage", 1)
    range = data.get("range", 1)
    weapon_type = data.get("weapon_type", GameEnums.WeaponType.BASIC)
    combat_range = data.get("combat_range", GameEnums.CombatRange.SHORT)
    ammo_capacity = data.get("ammo_capacity", -1)
    current_ammo = data.get("current_ammo", -1)
    combat_modifiers = data.get("combat_modifiers", [])
    combat_advantages = data.get("combat_advantages", [])
    special_rules = data.get("special_rules", [])
    weapon_class = data.get("weapon_class", GameEnums.EnemyWeaponClass.BASIC)
    return self