class_name Armor
extends Equipment

@export var armor_save: int
@export var armor_type: GlobalEnums.ArmorType

func _init(p_name: String = "", p_item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.ARMOR, p_level: int = 1, p_description: String = "", p_armor_save: int = 0, p_armor_type: GlobalEnums.ArmorType = GlobalEnums.ArmorType.LIGHT):
    super._init(p_name, p_item_type, p_level, p_description)
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

func get_effectiveness() -> int:
    return armor_save

func can_be_repaired() -> bool:
    return is_damaged and armor_save < get_max_armor_save()

func get_max_armor_save() -> int:
    match armor_type:
        GlobalEnums.ArmorType.LIGHT:
            return 2
        GlobalEnums.ArmorType.MEDIUM:
            return 3
        GlobalEnums.ArmorType.HEAVY:
            return 4
        GlobalEnums.ArmorType.SCREEN:
            return 1
    return 0