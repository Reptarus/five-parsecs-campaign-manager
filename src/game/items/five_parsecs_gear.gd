@tool
extends BaseGear

## Additional Five Parsecs specific gear functionality
var uses_remaining: int = 1
var is_consumable: bool = false
var is_tradeable: bool = true

func _init() -> void:
	super._init()

func use() -> void:
	if is_consumable:
		uses_remaining = maxi(0, uses_remaining - 1)
		
func is_usable() -> bool:
	return not is_consumable or uses_remaining > 0
	
func get_display_name() -> String:
	var display = super.get_display_name()
	if is_consumable:
		display += " (%d uses)" % uses_remaining
	return display

func get_description() -> String:
	var desc = super.get_description()
	if is_consumable:
		desc += "\nUses Remaining: %d" % uses_remaining
	if not is_tradeable:
		desc += "\nNot Tradeable"
	return desc 