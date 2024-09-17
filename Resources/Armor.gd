class_name Armor
extends Gear

@export var armor_save: int

func _init(p_name: String = "", p_description: String = "", p_armor_save: int = 0, p_level: int = 1):
    super._init(p_name, p_description, "Armor", p_level)
    armor_save = p_armor_save

func serialize() -> Dictionary:
    var data = super.serialize()
    data["armor_save"] = armor_save
    return data

static func deserialize(data: Dictionary) -> Armor:
    var armor = Armor.new(
        data["name"],
        data["description"],
        data["armor_save"],
        data["level"]
    )
    armor.value = data["value"]
    armor.is_damaged = data["is_damaged"]
    return armor