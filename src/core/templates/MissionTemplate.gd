extends Resource

# GlobalEnums available as autoload singleton

@export_group("Mission Details")
@export var type: GlobalEnums.MissionType
@export var title_templates: Array[String] = []
@export var description_templates: Array[String] = []
@export var objective: GlobalEnums.MissionObjective
@export var objective_description: String = ""

@export_group("Requirements")
@export var reward_range: Vector2 = Vector2(100, 1000)
@export var difficulty_range: Vector2 = Vector2(1, 5)
@export var required_skills: Array[int] = []
@export var enemy_types: Array[int] = []

@export_group("Chances")
@export_range(0, 1) var deployment_condition_chance: float = 0.3
@export_range(0, 1) var notable_sight_chance: float = 0.2

func validate() -> bool:
	if (safe_call_method(title_templates, "is_empty") == true) or (safe_call_method(description_templates, "is_empty") == true):
		push_error("Mission template must have at least one title and description")
		return false

	if reward_range.x >= reward_range.y:
		push_error("Invalid reward range")
		return false

	if difficulty_range.x >= difficulty_range.y:
		push_error("Invalid difficulty range")
		return false

	return true
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null