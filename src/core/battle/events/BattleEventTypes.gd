extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Event definitions with their effects and requirements
const BATTLE_EVENTS = {
	"CRITICAL_HIT": {
		"category": GlobalEnums.EventCategory.COMBAT,
		"probability": 0.15,
		"effect": {
			"type": "damage_multiplier",
			"_value": 2.0
		},
		"requirements": ["attack_roll >= 6"]
	},
	"WEAPON_JAM": {
		"category": GlobalEnums.EventCategory.EQUIPMENT,
		"probability": 0.1,
		"effect": {
			"type": "disable_weapon",
			"duration": 1
		},
		"requirements": ["has_ranged_weapon", "attack_roll <= 1"]
	},
	"TAKE_COVER": {
		"category": GlobalEnums.EventCategory.TACTICAL,
		"probability": 0.2,
		"effect": {
			"type": "defense_bonus",
			"_value": 2,
			"duration": 1
		},
		"requirements": ["near_cover"]
	}
}

# Event trigger conditions
static func check_event_requirements(event_name: String, context: Dictionary) -> bool:
	if not BATTLE_EVENTS.has(event_name):
		return false

	var event: Variant = BATTLE_EVENTS[event_name]
	for requirement in event.requirements:
		if not _evaluate_requirement(requirement, context):
			return false

	return true

static func _evaluate_requirement(requirement: String, context: Dictionary) -> bool:
	var parts = requirement.split(" ")
	match parts[0]:
		"attack_roll":
			var roll = context.get("attack_roll", 0)
			return _compare_value(roll, parts[1], parts[2].to_int())
		"has_ranged_weapon":
			return context.get("has_ranged_weapon", false)
		"near_cover":
			return context.get("near_cover", false)
		_:
			push_warning("Unknown requirement: " + requirement)
			return false

static func _compare_value(_value: float, operator: String, target: float) -> bool:
	match operator:
		">=": return _value >= target
		"<=": return _value <= target
		">": return _value > target
		"<": return _value < target
		"==": return _value == target
		_: return false

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null