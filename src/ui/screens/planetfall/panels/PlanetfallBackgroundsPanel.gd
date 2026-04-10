extends Control

## Planetfall Creation Step 3: Character Backgrounds
## Roll Motivation (D100) for all 8 characters.
## Roll Prior Experience + Notable Event for 4 experienced characters.
## TODO: Full per-character roll UI in next sprint — currently auto-rolls all.

signal backgrounds_updated(data: Dictionary)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")

var _coordinator = null
var _background_results: Dictionary = {}


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build_placeholder()


func _build_placeholder() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var header := Label.new()
	header.text = "CHARACTER BACKGROUNDS"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "All characters roll Motivation. The first 4 are experienced and also roll Prior Experience and Notable Event."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var roll_btn := Button.new()
	roll_btn.text = "Auto-Roll All Backgrounds"
	roll_btn.custom_minimum_size = Vector2(280, 56)
	roll_btn.pressed.connect(_on_auto_roll)
	content.add_child(roll_btn)


func _on_auto_roll() -> void:
	if not _coordinator:
		return
	var roster: Array = _coordinator.roster_data
	var bg_json := _load_json("res://data/planetfall/character_backgrounds.json")
	if bg_json.is_empty():
		return

	_background_results.clear()
	for i in range(roster.size()):
		var char_dict: Dictionary = roster[i]
		var cid: String = char_dict.get("id", "")
		var result: Dictionary = {}

		# All characters get motivation
		var mot_roll: int = randi_range(1, 100)
		result["motivation"] = _lookup_table(bg_json, "motivation_table", mot_roll, "motivation")

		# First 4 are experienced
		if i < 4:
			var exp_roll: int = randi_range(1, 100)
			var exp_entry := _lookup_table_full(bg_json, "prior_experience_table", exp_roll)
			result["prior_experience"] = exp_entry.get("experience", "")
			# Apply bonuses
			if exp_entry.get("bonus_type", "") == "stat":
				result["bonus_stat"] = exp_entry.get("bonus_stat", "")
				result["bonus_value"] = exp_entry.get("bonus_value", 0)
			elif exp_entry.get("bonus_type", "") == "xp":
				result["bonus_xp"] = exp_entry.get("bonus_value", 0)
			elif exp_entry.get("bonus_type", "") == "loyalty":
				result["bonus_loyalty"] = exp_entry.get("bonus_value", "loyal")
			elif exp_entry.get("bonus_type", "") == "kp":
				result["bonus_kp"] = exp_entry.get("bonus_value", 0)
			elif exp_entry.get("bonus_type", "") == "story_point":
				result["bonus_story_point"] = exp_entry.get("bonus_value", 0)

			var event_roll: int = randi_range(1, 100)
			result["notable_event"] = _lookup_table(bg_json, "notable_event_table", event_roll, "event")

		_background_results[cid] = result

	backgrounds_updated.emit(_background_results)


func _lookup_table(data: Dictionary, table_key: String, roll: int, field: String) -> String:
	var table: Dictionary = data.get(table_key, {})
	for entry in table.get("entries", []):
		if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
			return entry.get(field, "")
	return ""


func _lookup_table_full(data: Dictionary, table_key: String, roll: int) -> Dictionary:
	var table: Dictionary = data.get(table_key, {})
	for entry in table.get("entries", []):
		if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
			return entry
	return {}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data if json.data is Dictionary else {}
