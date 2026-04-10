class_name TacticsUpgradeGroup
extends Resource

## TacticsUpgradeGroup - A labeled set of TacticsUpgradeOptions with selection rules.
## Simplified from AoF: drops AoF-specific scopes (HERO_SELF, ALL_MODELS).
## Source: Five Parsecs: Tactics species army lists

enum SelectionMode {
	PICK_ONE,       ## Radio button — select 0 or 1 option
	PICK_ANY,       ## Checkboxes — select any combination
	PICK_UP_TO_N,   ## Checkboxes capped at max_selections
}

# Group Identity
@export var group_label: String = ""
@export var group_id: String = ""
@export var selection_mode: SelectionMode = SelectionMode.PICK_ONE
@export var max_selections: int = 1

# Options
var options: Array = []  # Array of TacticsUpgradeOption


## Check if an option is available by name
func is_option_available(option_name: String) -> bool:
	for opt in options:
		if opt is TacticsUpgradeOption and opt.upgrade_name == option_name:
			return true
	return false


## Get display text for the group header
func get_header_text() -> String:
	if not group_label.is_empty():
		return group_label
	match selection_mode:
		SelectionMode.PICK_ONE:
			return "Choose one"
		SelectionMode.PICK_ANY:
			return "Choose any"
		SelectionMode.PICK_UP_TO_N:
			return "Choose up to %d" % max_selections
	return "Upgrades"


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary, weapon_lookup: Dictionary = {}) -> TacticsUpgradeGroup:
	var _Self = load("res://src/data/tactics/TacticsUpgradeGroup.gd")
	var group = _Self.new()
	group.group_label = data.get("label", data.get("group_label", ""))
	group.group_id = data.get("id", data.get("group_id", ""))
	group.max_selections = data.get("max_selections", 1)

	# Selection mode
	var mode_str: String = data.get("mode", data.get("selection_mode", "pick_one"))
	group.selection_mode = _mode_from_string(mode_str)

	# Options
	var raw_options: Array = data.get("options", [])
	for raw in raw_options:
		if raw is Dictionary:
			group.options.append(TacticsUpgradeOption.from_dict(raw, weapon_lookup))

	# Auto-generate ID
	if group.group_id.is_empty() and not group.group_label.is_empty():
		group.group_id = group.group_label.to_lower().replace(" ", "_")

	return group


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"label": group_label,
		"mode": SelectionMode.keys()[selection_mode].to_lower(),
	}
	if not group_id.is_empty():
		data["id"] = group_id
	if max_selections != 1:
		data["max_selections"] = max_selections

	var opt_list: Array = []
	for opt in options:
		if opt is TacticsUpgradeOption:
			opt_list.append(opt.to_dict())
	data["options"] = opt_list

	return data


static func _mode_from_string(mode_str: String) -> SelectionMode:
	match mode_str.to_lower():
		"pick_one": return SelectionMode.PICK_ONE
		"pick_any": return SelectionMode.PICK_ANY
		"pick_up_to_n": return SelectionMode.PICK_UP_TO_N
		_: return SelectionMode.PICK_ONE
