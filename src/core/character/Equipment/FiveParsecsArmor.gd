@tool
extends Resource
class_name FiveParsecsArmor

## Additional Five Parsecs specific armor functionality
var durability: int = 100
var repair_cost: int = 0
var is_damaged: bool = false

# Basic armor properties
var name: String = ""
var description: String = ""
var cost: int = 0
var armor_class: int = 0

func _init() -> void:
	pass

func damage(amount: int) -> void:
	durability = maxi(0, durability - amount)
	is_damaged = durability < 50
	
func repair() -> void:
	durability = 100
	is_damaged = false
	
func calculate_repair_cost() -> int:
	return (100 - durability) * cost / 100

func get_display_name() -> String:
	var display = name
	if is_damaged:
		display += " (Damaged)"
	return display

func get_description() -> String:
	var desc = description
	desc += "\nDurability: %d/100" % durability
	if is_damaged:
		desc += "\nNeeds Repair (Cost: %d credits)" % calculate_repair_cost()
	return desc