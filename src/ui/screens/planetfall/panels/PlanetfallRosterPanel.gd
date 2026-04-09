extends Control

## Planetfall Creation Step 2: Character Roster
## Player picks 8 characters from 3 classes (Scientist/Scout/Trooper),
## optionally selects sub-species, and can import characters from other campaigns.
## TODO: Full implementation in next sprint — currently a functional stub.

signal roster_updated(characters: Array)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")

var _coordinator = null
var _roster: Array = []


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
	header.text = "CHARACTER ROSTER"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "Choose 8 characters: Scientists, Scouts, and Troopers (min 1 of each).\nYou also get 12 Grunts and 1 Colony Bot automatically."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	# Quick-generate button for testing
	var gen_btn := Button.new()
	gen_btn.text = "Auto-Generate Default Roster (2S / 2Sc / 4T)"
	gen_btn.custom_minimum_size = Vector2(300, 56)
	gen_btn.pressed.connect(_on_auto_generate)
	content.add_child(gen_btn)

	# Import button placeholder
	var import_btn := Button.new()
	import_btn.text = "Import Characters from 5PFH / Bug Hunt"
	import_btn.custom_minimum_size = Vector2(300, 48)
	import_btn.disabled = true
	import_btn.tooltip_text = "Character import coming in a future sprint"
	content.add_child(import_btn)


func _on_auto_generate() -> void:
	_roster.clear()
	# Load class data
	var classes_data := _load_json("res://data/planetfall/character_classes.json")
	var composition := ["scientist", "scientist", "scout", "scout",
			"trooper", "trooper", "trooper", "trooper"]
	for i in range(composition.size()):
		var cls: String = composition[i]
		var profile: Dictionary = classes_data.get("classes", {}).get(cls, {}).get("profiles", {})
		var char_dict := {
			"id": "pf_char_%d" % i,
			"name": "Colonist %d" % (i + 1),
			"class": cls,
			"subspecies": "",
			"reactions": profile.get("reactions", 1),
			"speed": profile.get("speed", 4),
			"combat_skill": profile.get("combat_skill", 0),
			"toughness": profile.get("toughness", 3),
			"savvy": profile.get("savvy", 0),
			"xp": 0,
			"kp": 0,
			"loyalty": "committed",
			"motivation": "",
			"prior_experience": "",
			"notable_event": "",
			"abilities": classes_data.get("classes", {}).get(cls, {}).get("abilities", []),
			"is_imported": false,
			"source_campaign": ""
		}
		_roster.append(char_dict)
	roster_updated.emit(_roster)


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
