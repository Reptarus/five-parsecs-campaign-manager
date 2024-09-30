class_name Armor
extends Gear

@export var armor_save: int
@export var armor_type: GlobalEnums.ArmorType

func _init(p_name: String = "", p_description: String = "", p_armor_save: int = 0, p_armor_type: GlobalEnums.ArmorType = GlobalEnums.ArmorType.LIGHT, p_level: int = 1):
    super._init(p_name, p_description, GlobalEnums.ItemType.ARMOR, p_level)
    armor_save = p_armor_save
    armor_type = p_armor_type

func serialize() -> Dictionary:
    var data = super.serialize()
    data["armor_save"] = armor_save
    data["armor_type"] = armor_type
    return data

static func deserialize(data: Dictionary) -> Armor:
    var armor = Armor.new(
        data["name"],
        data["description"],
        data["armor_save"],
        data["armor_type"],
        data["level"]
    )
    armor.value = data["value"]
    armor.is_damaged = data["is_damaged"]
    return armor

func get_armor_type_string() -> String:
    return GlobalEnums.ArmorType.keys()[armor_type].capitalize()

func apply_damage() -> void:
    is_damaged = true
    armor_save = max(0, armor_save - 1)

func repair() -> void:
    is_damaged = false
    armor_save += 1