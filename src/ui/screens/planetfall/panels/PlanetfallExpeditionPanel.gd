extends Control

## Planetfall Creation Step 1: Expedition Type
## Player rolls D100 to determine their colonization agenda.
## Displays the result with description and starting bonus.

signal expedition_updated(data: Dictionary)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")

var _coordinator = null
var _rolled: bool = false
var _expedition_data: Dictionary = {}
var _name_input: LineEdit
var _colony_input: LineEdit
var _roll_button: Button
var _result_label: RichTextLabel
var _content: VBoxContainer


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)

	# Campaign name
	var name_label := Label.new()
	name_label.text = "Campaign Name"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	_content.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter campaign name..."
	_name_input.custom_minimum_size = Vector2(0, 48)
	_name_input.text_changed.connect(_on_name_changed)
	_content.add_child(_name_input)

	# Colony name
	var colony_label := Label.new()
	colony_label.text = "Colony Name"
	colony_label.add_theme_font_size_override("font_size", 16)
	colony_label.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	_content.add_child(colony_label)

	_colony_input = LineEdit.new()
	_colony_input.placeholder_text = "Name your colony (or leave blank for campaign name)..."
	_colony_input.custom_minimum_size = Vector2(0, 48)
	_colony_input.text_changed.connect(_on_colony_changed)
	_content.add_child(_colony_input)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = UIColorsRef.COLOR_BORDER
	_content.add_child(sep)

	# Expedition Type section
	var exp_header := Label.new()
	exp_header.text = "EXPEDITION TYPE"
	exp_header.add_theme_font_size_override("font_size", 18)
	exp_header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	_content.add_child(exp_header)

	var exp_desc := Label.new()
	exp_desc.text = "Roll D100 to determine your colonization agenda. This sets your starting bonuses."
	exp_desc.add_theme_font_size_override("font_size", 14)
	exp_desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	exp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(exp_desc)

	_roll_button = Button.new()
	_roll_button.text = "Roll D100 — Expedition Type"
	_roll_button.custom_minimum_size = Vector2(280, 56)
	_roll_button.pressed.connect(_on_roll_pressed)
	_content.add_child(_roll_button)

	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.custom_minimum_size = Vector2(0, 80)
	_result_label.add_theme_font_size_override("normal_font_size", 16)
	_result_label.visible = false
	_content.add_child(_result_label)


func _on_name_changed(new_text: String) -> void:
	_expedition_data["campaign_name"] = new_text
	_emit_update()


func _on_colony_changed(new_text: String) -> void:
	_expedition_data["colony_name"] = new_text
	_emit_update()


func _on_roll_pressed() -> void:
	var dice := get_node_or_null("/root/DiceManager")
	var roll: int
	if dice and dice.has_method("roll_d100"):
		roll = dice.roll_d100()
	else:
		roll = randi_range(1, 100)

	# Load expedition types from JSON
	var entry := _lookup_expedition(roll)
	if entry.is_empty():
		return

	_rolled = true
	_expedition_data["expedition_type"] = entry.get("type", "")
	_expedition_data["expedition_roll"] = roll

	# Display result
	var type_name: String = entry.get("type", "Unknown")
	var desc: String = entry.get("description", "")
	var effect: String = entry.get("effect", "")

	_result_label.text = ""
	_result_label.append_text("[b]Rolled: %d[/b]\n" % roll)
	_result_label.append_text("[color=#4FC3F7][b]%s[/b][/color]\n" % type_name)
	_result_label.append_text("%s\n\n" % desc)
	_result_label.append_text("[color=#10B981]%s[/color]" % effect)
	_result_label.visible = true

	_roll_button.text = "Re-roll D100 (Story Point)"
	_roll_button.pivot_offset = _roll_button.size / 2
	TweenFX.pop_in(_result_label, 0.3)

	_emit_update()


func _lookup_expedition(roll: int) -> Dictionary:
	var json_path := "res://data/planetfall/expedition_types.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("PlanetfallExpeditionPanel: Cannot open expedition_types.json")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	var data: Dictionary = json.data
	for entry in data.get("entries", []):
		if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
			return entry
	return {}


func _emit_update() -> void:
	expedition_updated.emit(_expedition_data)
