extends Control

## Planetfall Creation Step 5: Tutorial Missions
## 3 introductory missions (Beacons/Analysis/Perimeter) that teach core rules.
## Player can play each on the tabletop and report results, or skip.
## TODO: Full mission companion UI — currently play/skip buttons.

signal tutorials_updated(data: Dictionary)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")

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
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "Before the campaign begins, play 3 tutorial missions to earn starting bonuses. You can skip these and proceed directly to the campaign."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	# Mission cards
	var missions := [
		{"id": "beacons", "title": "Beacons (Scout Mission)",
		 "desc": "Scouts deploy 3 beacons in a storm. Reward: 2 Raw Materials.",
		 "success_key": "beacons_success"},
		{"id": "analysis", "title": "Analysis (Scientist Mission)",
		 "desc": "Scientists reveal 4+ of 6 contacts. Reward: 2-3 Research Points.",
		 "success_key": "analysis_success"},
		{"id": "perimeter", "title": "Perimeter (Trooper Mission)",
		 "desc": "Troopers kill 6 lifeforms. Reward: +3 Colony Morale.",
		 "success_key": "perimeter_success"},
	]

	for m in missions:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UIColorsRef.COLOR_ELEVATED.r, UIColorsRef.COLOR_ELEVATED.g, UIColorsRef.COLOR_ELEVATED.b, 0.8)
		style.border_color = UIColorsRef.COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		var title_lbl := Label.new()
		title_lbl.text = m.title
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
		vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = m.desc
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		vbox.add_child(btn_row)

		var success_btn := Button.new()
		success_btn.text = "Mission Success"
		success_btn.custom_minimum_size = Vector2(150, 40)
		var mid: String = m.id
		var skey: String = m.success_key
		success_btn.pressed.connect(func(): _on_mission_result(mid, skey, true))
		btn_row.add_child(success_btn)

		var fail_btn := Button.new()
		fail_btn.text = "Mission Failed"
		fail_btn.custom_minimum_size = Vector2(150, 40)
		fail_btn.pressed.connect(func(): _on_mission_result(mid, skey, false))
		btn_row.add_child(fail_btn)

		content.add_child(card)

	# Skip all button
	var skip_btn := Button.new()
	skip_btn.text = "Skip All Tutorials"
	skip_btn.custom_minimum_size = Vector2(200, 48)
	skip_btn.pressed.connect(_on_skip_all)
	content.add_child(skip_btn)


func _on_mission_result(mission_id: String, success_key: String, success: bool) -> void:
	_results.missions[mission_id] = true
	_results[success_key] = success
	tutorials_updated.emit(_results)


func _on_skip_all() -> void:
	if _coordinator:
		_coordinator.skip_tutorials()
	tutorials_updated.emit(_results)
