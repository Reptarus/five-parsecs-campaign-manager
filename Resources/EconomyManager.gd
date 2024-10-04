class_name EconomyManager
extends Node

signal global_event_triggered(event: GlobalEnums.GlobalEvent)
signal economy_updated

var location_price_modifiers: Dictionary = {}
var global_economic_modifier: float = 1.0
var trade_restricted_items: Array[String] = []
var scarce_resources: Array[String] = []
var new_tech_items: Array[String] = []

const BASE_ITEM_MARKUP: float = 1.2
const BASE_ITEM_MARKDOWN: float = 0.8
const GLOBAL_EVENT_CHANCE: float = 0.1
const ECONOMY_NORMALIZATION_RATE: float = 0.1

func _init() -> void:
    initialize_location_price_modifiers()

func initialize_location_price_modifiers() -> void:
    for location in get_tree().get_nodes_in_group("locations"):
        location_price_modifiers[location.name] = randf_range(0.8, 1.2)

func calculate_item_price(item: Equipment, is_buying: bool) -> int:
    var base_price: int = item.value
    var location_modifier = location_price_modifiers.get(GameStateManager.game_state.current_location.name, 1.0)
    
    if is_buying:
        base_price = int(base_price * BASE_ITEM_MARKUP * location_modifier * global_economic_modifier)
    else:
        base_price = int(base_price * BASE_ITEM_MARKDOWN * location_modifier * global_economic_modifier)
    
    if item.name in scarce_resources:
        base_price = int(base_price * 1.5)
    elif item.name in new_tech_items:
        base_price = int(base_price * 0.8)
    
    return base_price

func generate_random_equipment() -> Equipment:
    var item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.values()[randi() % GlobalEnums.ItemType.size()]
    
    match item_type:
        GlobalEnums.ItemType.WEAPON:
            return generate_random_weapon()
        GlobalEnums.ItemType.ARMOR:
            return generate_random_armor()
        GlobalEnums.ItemType.GEAR:
            return generate_random_gear()
        GlobalEnums.ItemType.CONSUMABLE:
            return generate_random_consumable()
        _:
            push_error("Unexpected item type")
            return Equipment.new("Generic Item", GlobalEnums.ItemType.GEAR, 0)

func generate_random_weapon() -> Equipment:
    var weapon_types = GlobalEnums.WeaponType.values()
    var weapon_type = weapon_types[randi() % weapon_types.size()]
    var weapon_name = "Generic " + GlobalEnums.WeaponType.keys()[weapon_type]
    var damage = randi() % 5 + 1
    var weapon_range = randi() % 10 + 1
    return Equipment.new(weapon_name, GlobalEnums.ItemType.WEAPON, damage)

func generate_random_armor() -> Equipment:
    var armor_types = GlobalEnums.ArmorType.values()
    var armor_type = armor_types[randi() % armor_types.size()]
    var armor_name = "Generic " + GlobalEnums.ArmorType.keys()[armor_type]
    var defense = randi() % 5 + 1
    return Equipment.new(armor_name, GlobalEnums.ItemType.ARMOR, defense)

func generate_random_gear() -> Equipment:
    var gear_types = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
    var gear_name = gear_types[randi() % gear_types.size()]
    return Equipment.new(gear_name, GlobalEnums.ItemType.GEAR, 1)

func generate_random_consumable() -> Equipment:
    var consumable_types = ["Stim Pack", "Grenade", "Repair Nanites", "Energy Cell"]
    var consumable_name = consumable_types[randi() % consumable_types.size()]
    return Equipment.new(consumable_name, GlobalEnums.ItemType.CONSUMABLE, 1)

func trigger_global_event() -> void:
    var event = GlobalEnums.GlobalEvent.values()[randi() % GlobalEnums.GlobalEvent.size()]
    match event:
        GlobalEnums.GlobalEvent.MARKET_CRASH:
            global_economic_modifier = 0.8
            print("A market crash has occurred! Prices are generally lower.")
        GlobalEnums.GlobalEvent.ECONOMIC_BOOM:
            global_economic_modifier = 1.2
            print("An economic boom is happening! Prices are generally higher.")
        GlobalEnums.GlobalEvent.TRADE_EMBARGO:
            trade_restricted_items = ["Weapon", "Armor", "Ship Component"]
            print("A trade embargo has been imposed. Weapons, armor, and ship components are unavailable.")
        GlobalEnums.GlobalEvent.RESOURCE_SHORTAGE:
            scarce_resources = ["Fuel", "Medical Supplies", "Food"]
            print("A resource shortage is affecting the market. Fuel, medical supplies, and food are more expensive.")
        GlobalEnums.GlobalEvent.TECHNOLOGICAL_BREAKTHROUGH:
            new_tech_items = ["Advanced AI", "Quantum Computer", "Nanotech Fabricator"]
            print("A technological breakthrough has occurred. Advanced AI, Quantum Computers, and Nanotech Fabricators are now available.")
    
    global_event_triggered.emit(event)

func update_global_economy() -> void:
    if randf() < GLOBAL_EVENT_CHANCE:
        trigger_global_event()
    else:
        global_economic_modifier = lerp(global_economic_modifier, 1.0, ECONOMY_NORMALIZATION_RATE)
        trade_restricted_items.clear()
        scarce_resources.clear()
        new_tech_items.clear()
    
    for location_name in location_price_modifiers.keys():
        location_price_modifiers[location_name] = lerp(location_price_modifiers[location_name], 1.0, ECONOMY_NORMALIZATION_RATE)
    
    economy_updated.emit()
