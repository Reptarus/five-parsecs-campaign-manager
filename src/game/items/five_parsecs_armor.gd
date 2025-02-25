@tool
extends BaseArmor
class_name FiveParsecsArmor

## Additional Five Parsecs specific armor functionality
var durability: int = 100
var repair_cost: int = 0
var is_damaged: bool = false

func _init() -> void:
	super._init()

func damage(amount: int) -> void:
	durability = maxi(0, durability - amount)
	is_damaged = durability < 50
	
func repair() -> void:
	durability = 100
	is_damaged = false
	
func calculate_repair_cost() -> int:
	return (100 - durability) * cost / 100

func get_display_name() -> String:
	var display = super.get_display_name()
	if is_damaged:
		display += " (Damaged)"
	return display

func get_description() -> String:
	var desc = super.get_description()
	desc += "\nDurability: %d/100" % durability
	if is_damaged:
		desc += "\nNeeds Repair (Cost: %d credits)" % calculate_repair_cost()
	return desc