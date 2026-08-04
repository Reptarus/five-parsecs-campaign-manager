extends Control

## Planetfall Creation Step 5: Tutorial Missions (Planetfall pp.44-45)
##
## 3 introductory missions (Beacons / Analysis / Perimeter) that teach core rules.
## The player runs each on the tabletop and reports the result here.
##
## Now DATA-DRIVEN from data/planetfall/tutorial_missions.json. That file was
## fully authored from the book — table size, forces, setup instructions,
## objectives, rewards — and had ZERO loaders repo-wide; this panel hardcoded a
## one-line summary of each mission instead, so none of the setup or objective
## text ever reached the player.
##
## It also fixes an unreachable reward: Analysis pays "2 Research Points (3 if
## all 6 Contacts revealed)", the coordinator reads `analysis_all_six`, and
## nothing could ever set it — the 3 RP bonus was impossible to earn.

const TUTORIAL_DATA_PATH := "res://data/planetfall/tutorial_missions.json"

signal tutorials_updated(data: Dictionary)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER

var _coordinator = null
var _results: Dictionary = {
	"missions": {"beacons": false, "analysis": false, "perimeter": false},
	"beacons_success": false,
	"analysis_success": false,
	"analysis_all_six": false,
	"perimeter_success": false
}


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var header := Label.new()
	header.text = "INITIAL MISSIONS (Optional)"
	header.add_theme_font_size_override("font_size", ScreenChrome.font_size(18))
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "Before the campaign begins, play 3 tutorial missions to earn starting bonuses. You can skip these and proceed directly to the campaign."
	desc.add_theme_font_size_override("font_size", ScreenChrome.font_size(14))
	desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	# Mission cards, built from the book data rather than hardcoded blurbs.
	var missions: Array = _load_missions()

	for m in missions:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UIColorsRef.COLOR_ELEVATED.r, UIColorsRef.COLOR_ELEVATED.g, UIColorsRef.COLOR_ELEVATED.b, 0.8)
		style.border_color = UIColorsRef.COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		var mid: String = str(m.get("id", ""))
		var skey: String = "%s_success" % mid

		var title_lbl := Label.new()
		var subtitle: String = str(m.get("subtitle", ""))
		title_lbl.text = ("%s — %s" % [str(m.get("name", "Mission")), subtitle]) \
			if not subtitle.is_empty() else str(m.get("name", "Mission"))
		title_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(16))
		title_lbl.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
		vbox.add_child(title_lbl)

		# What the mission teaches + the table it wants. Both are in the book and
		# were previously invisible.
		var meta_bits: Array[String] = []
		if not str(m.get("teaches", "")).is_empty():
			meta_bits.append("Teaches: %s" % str(m.get("teaches")))
		if not str(m.get("table_size", "")).is_empty():
			meta_bits.append("Table: %s" % str(m.get("table_size")))
		if not meta_bits.is_empty():
			vbox.add_child(_body_label(" · ".join(meta_bits), 12))

		if not str(m.get("setup", "")).is_empty():
			vbox.add_child(_body_label("Setup: %s" % str(m.get("setup")), 13))
		if not str(m.get("objective", "")).is_empty():
			vbox.add_child(_body_label(
				"Objective: %s" % str(m.get("objective")), 13))

		var reward: Dictionary = m.get("reward_success", {})
		if not str(reward.get("description", "")).is_empty():
			vbox.add_child(_body_label(
				"Reward: %s" % str(reward.get("description")), 13))

		# Planetfall p.45, Analysis: "2 Research Points (3 if all 6 Contacts
		# revealed)". The coordinator reads `analysis_all_six`; without this box
		# nothing could set it, so the 3 RP tier was unreachable.
		if reward.has("bonus_all_six"):
			var all_six := CheckBox.new()
			all_six.text = "All 6 Contacts revealed (bonus)"
			all_six.custom_minimum_size = Vector2(0, 40)
			all_six.toggled.connect(_on_all_six_toggled)
			vbox.add_child(all_six)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		vbox.add_child(btn_row)

		var success_btn := Button.new()
		success_btn.text = "Mission Success"
		success_btn.custom_minimum_size = Vector2(0, 40)
		success_btn.pressed.connect(func(): _on_mission_result(mid, skey, true))
		btn_row.add_child(success_btn)

		var fail_btn := Button.new()
		fail_btn.text = "Mission Failed"
		fail_btn.custom_minimum_size = Vector2(0, 40)
		fail_btn.pressed.connect(func(): _on_mission_result(mid, skey, false))
		btn_row.add_child(fail_btn)

		content.add_child(card)

	# Skip all button
	var skip_btn := Button.new()
	skip_btn.text = "Skip All Tutorials"
	skip_btn.custom_minimum_size = Vector2(0, 48)
	skip_btn.pressed.connect(_on_skip_all)
	content.add_child(skip_btn)


func _body_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _load_missions() -> Array:
	## Read the book data. Falls back to the three ids in play order so the step
	## still functions if the file is missing from an export.
	var file := FileAccess.open(TUTORIAL_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("PlanetfallTutorialPanel: %s not found" % TUTORIAL_DATA_PATH)
		return _fallback_missions()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallTutorialPanel: %s failed to parse: %s"
			% [TUTORIAL_DATA_PATH, json.get_error_message()])
		return _fallback_missions()
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return _fallback_missions()
	var missions: Variant = data.get("missions", [])
	if not (missions is Array) or missions.is_empty():
		return _fallback_missions()
	return missions


func _fallback_missions() -> Array:
	return [
		{"id": "beacons", "name": "Beacons", "subtitle": "Scout Mission"},
		{"id": "analysis", "name": "Analysis", "subtitle": "Scientist Mission"},
		{"id": "perimeter", "name": "Perimeter", "subtitle": "Trooper Mission"},
	]


func _on_all_six_toggled(pressed: bool) -> void:
	_results["analysis_all_six"] = pressed
	tutorials_updated.emit(_results)


func _on_mission_result(mission_id: String, success_key: String, success: bool) -> void:
	_results.missions[mission_id] = true
	_results[success_key] = success
	tutorials_updated.emit(_results)


func _on_skip_all() -> void:
	if _coordinator:
		_coordinator.skip_tutorials()
	tutorials_updated.emit(_results)
