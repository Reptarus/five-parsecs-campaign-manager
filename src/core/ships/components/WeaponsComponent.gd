# Scripts/ShipAndCrew/WeaponsComponent.gd
extends ShipComponent
class_name WeaponsComponent

@export var damage: int = 10
@export var range: float = 100.0
@export var accuracy: float = 0.8
@export var fire_rate: float = 1.0
@export var ammo_capacity: int = 100
@export var weapon_slots: int = 2

var current_ammo: int = ammo_capacity
var equipped_weapons: Array = []
var cooldown_timers: Dictionary = {}

func _init() -> void:
    super()
    name = "Weapons System"
    description = "Standard weapons system"
    cost = 400
    power_draw = 3

func _apply_upgrade_effects() -> void:
    super()
    damage += 5
    range += 20.0
    accuracy += 0.05
    fire_rate += 0.1
    ammo_capacity += 25
    if level % 2 == 0: # Every other level
        weapon_slots += 1
    current_ammo = ammo_capacity

func get_damage() -> int:
    return ceili(damage * get_efficiency())

func get_range() -> float:
    return range * get_efficiency()

func get_accuracy() -> float:
    return accuracy * get_efficiency()

func get_fire_rate() -> float:
    return fire_rate * get_efficiency()

func get_available_slots() -> int:
    return weapon_slots - equipped_weapons.size()

func can_equip_weapon(weapon: Dictionary) -> bool:
    return is_active and get_available_slots() > 0

func equip_weapon(weapon: Dictionary) -> bool:
    if not can_equip_weapon(weapon):
        return false
        
    equipped_weapons.append(weapon)
    cooldown_timers[weapon.id] = 0.0
    return true

func unequip_weapon(weapon: Dictionary) -> void:
    equipped_weapons.erase(weapon)
    cooldown_timers.erase(weapon.id)

func update_weapons(delta: float) -> void:
    if not is_active:
        return
        
    for weapon_id in cooldown_timers:
        if cooldown_timers[weapon_id] > 0:
            cooldown_timers[weapon_id] = maxf(0, cooldown_timers[weapon_id] - delta)

func can_fire_weapon(weapon: Dictionary) -> bool:
    return is_active and current_ammo > 0 and cooldown_timers.get(weapon.id, 0.0) <= 0

func fire_weapon(weapon: Dictionary, target: Vector3) -> Dictionary:
    if not can_fire_weapon(weapon):
        return {
            "success": false,
            "reason": "Weapon cannot fire"
        }
    
    current_ammo -= 1
    cooldown_timers[weapon.id] = 1.0 / get_fire_rate()
    
    var hit_chance = get_accuracy()
    var distance = target.length()
    
    # Reduce accuracy based on distance
    if distance > get_range():
        hit_chance *= 0.5
    
    var result = {
        "success": true,
        "hit": randf() < hit_chance,
        "damage": get_damage() if randf() < hit_chance else 0,
        "critical": randf() < 0.1 if randf() < hit_chance else false
    }
    
    if result.critical:
        result.damage *= 2
    
    return result

func reload_ammo(amount: int) -> void:
    current_ammo = mini(current_ammo + amount, ammo_capacity)

func get_ammo_remaining() -> int:
    return current_ammo

func serialize() -> Dictionary:
    var data = super()
    data["damage"] = damage
    data["range"] = range
    data["accuracy"] = accuracy
    data["fire_rate"] = fire_rate
    data["ammo_capacity"] = ammo_capacity
    data["weapon_slots"] = weapon_slots
    data["current_ammo"] = current_ammo
    data["equipped_weapons"] = equipped_weapons.duplicate()
    data["cooldown_timers"] = cooldown_timers.duplicate()
    return data

static func deserialize(data: Dictionary) -> WeaponsComponent:
    var component = WeaponsComponent.new()
    var base_data = super.deserialize(data)
    component.name = base_data.name
    component.description = base_data.description
    component.cost = base_data.cost
    component.level = base_data.level
    component.max_level = base_data.max_level
    component.is_active = base_data.is_active
    component.upgrade_cost = base_data.upgrade_cost
    component.maintenance_cost = base_data.maintenance_cost
    component.durability = base_data.durability
    component.max_durability = base_data.max_durability
    component.efficiency = base_data.efficiency
    component.power_draw = base_data.power_draw
    component.status_effects = base_data.status_effects
    
    component.damage = data.get("damage", 10)
    component.range = data.get("range", 100.0)
    component.accuracy = data.get("accuracy", 0.8)
    component.fire_rate = data.get("fire_rate", 1.0)
    component.ammo_capacity = data.get("ammo_capacity", 100)
    component.weapon_slots = data.get("weapon_slots", 2)
    component.current_ammo = data.get("current_ammo", component.ammo_capacity)
    component.equipped_weapons = data.get("equipped_weapons", [])
    component.cooldown_timers = data.get("cooldown_timers", {})
    return component
