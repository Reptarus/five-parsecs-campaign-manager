extends VBoxContainer
## Difficulty Toggles Panel — displays Compendium DLC difficulty options
## DLC-gated: shows lock message when Freelancer's Handbook not enabled

const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")

# Design system colors
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_WARNING := Color("#D97706")

var toggle_states: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Section title
	var title := Label.new()
	title.text = "Difficulty Toggles"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	add_child(title)

	# DLC gate check
	var dlc = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	var dlc_enabled: bool = false
	if dlc and dlc.has_method("is_feature_enabled"):
		var flags = dlc.ContentFlag if "ContentFlag" in dlc else null
		if flags and "DIFFICULTY_TOGGLES" in flags:
			dlc_enabled = dlc.is_feature_enabled(
				flags.DIFFICULTY_TOGGLES)

	if not dlc_enabled:
		var lock_label := Label.new()
		lock_label.text = "Requires Freelancer's Handbook DLC"
		lock_label.add_theme_color_override("font_color", COLOR_WARNING)
		lock_label.add_theme_font_size_override("font_size", 14)
		add_child(lock_label)
		return

	# Load saved toggle states
	_load_toggle_states()

	# Build toggles grouped by category
	var categories: Array[String] = []
	categories.assign(CompendiumTogglesRef.get_categories())
	for category in categories:
		var cat_name: String = CompendiumTogglesRef.get_category_name(
			category)
		var toggles: Array[Dictionary] = \
			CompendiumTogglesRef.get_toggles_by_category(category)
		if toggles.is_empty():
			continue

		# Category header
		var cat_label := Label.new()
		cat_label.text = cat_name
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color", COLOR_ACCENT)
		add_child(cat_label)

		# Category card
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = COLOR_ELEVATED
		card_style.border_color = COLOR_BORDER
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", card_style)
		add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		for toggle in toggles:
			var toggle_id: String = toggle.get("id", "")
			var hbox := HBoxContainer.new()
			card_vbox.add_child(hbox)

			var check := CheckBox.new()
			check.text = toggle.get("name", "Unknown")
			check.button_pressed = toggle_states.get(toggle_id, false)
			check.add_theme_color_override("font_color",
				COLOR_TEXT_PRIMARY)
			check.toggled.connect(
				_on_toggle_changed.bind(toggle_id))
			hbox.add_child(check)

			# Description tooltip
			var desc: String = toggle.get("description", "")
			if not desc.is_empty():
				check.tooltip_text = desc

	# Save button
	var save_btn := Button.new()
	save_btn.text = "Save Difficulty Settings"
	save_btn.pressed.connect(_save_toggle_states)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_ACCENT
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	save_btn.add_theme_stylebox_override("normal", btn_style)
	save_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	add_child(save_btn)

func _on_toggle_changed(enabled: bool, toggle_id: String) -> void:
	toggle_states[toggle_id] = enabled

func _load_toggle_states() -> void:
	var config := ConfigFile.new()
	var err: int = config.load("user://difficulty_toggles.cfg")
	if err != OK:
		return
	for key in config.get_section_keys("toggles"):
		toggle_states[key] = config.get_value("toggles", key, false)

func _save_toggle_states() -> void:
	var config := ConfigFile.new()
	for key in toggle_states:
		config.set_value("toggles", key, toggle_states[key])
	config.save("user://difficulty_toggles.cfg")
