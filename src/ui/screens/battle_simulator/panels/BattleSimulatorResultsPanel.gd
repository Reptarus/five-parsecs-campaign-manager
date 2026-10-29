extends Control

## Post-battle results overlay for the Battle Simulator.
## Shows victory/defeat, stats, and navigation options.

signal play_again_pressed()
signal main_menu_pressed()

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := UIColors.COLOR_TEXT_SECONDARY
const COLOR_SUCCESS := Color("#10B981")
const COLOR_DANGER := Color("#DC2626")
const COLOR_FOCUS := Color("#4FC3F7")

const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_TITLE := 36
const SPACING_MD := 16
const SPACING_LG := 24
const TOUCH_TARGET := 48

var _title_label: Label
var _stats_label: RichTextLabel
var _play_again_btn: Button
var _menu_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent background overlay
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(COLOR_BASE, 0.92)
	add_child(bg)

	# The card fills the screen's content column (BattleSimulatorUI centres that column at
	# up to 800 px) and centres vertically. It used to sit in a CenterContainer with a
	# fixed 500 px minimum width, which ran ~100 px off the right edge of a 393 px phone
	# and took the Main Menu button with it.
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(SPACING_LG)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 300)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_TITLE))
	vbox.add_child(_title_label)

	# Stats
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.custom_minimum_size = Vector2(0, 80)
	ScreenChrome.size_rich_text(_stats_label, FONT_SIZE_MD)
	_stats_label.add_theme_color_override("default_color", COLOR_TEXT)
	vbox.add_child(_stats_label)

	# Buttons
	var btn_row := HFlowContainer.new()
	btn_row.add_theme_constant_override("h_separation", SPACING_MD)
	btn_row.add_theme_constant_override("v_separation", SPACING_MD)
	btn_row.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_play_again_btn = Button.new()
	_play_again_btn.text = "Play Again"
	_play_again_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	_play_again_btn.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_play_again_btn.pressed.connect(func(): play_again_pressed.emit())
	btn_row.add_child(_play_again_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET)
	_menu_btn.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_menu_btn.pressed.connect(func(): main_menu_pressed.emit())
	btn_row.add_child(_menu_btn)

	# TweenFX press feedback
	var tweenfx = Engine.get_main_loop().root.get_node_or_null("/root/TweenFX") if Engine.get_main_loop() else null
	if tweenfx and tweenfx.has_method("press"):
		for btn: Button in [_play_again_btn, _menu_btn]:
			btn.pivot_offset = btn.size / 2
			btn.pressed.connect(func(): tweenfx.press(btn))


## Every shape TacticalBattleUI's four tactical_battle_completed emit sites produce
## (Record Result form, played end, in-battle auto-resolve, evacuation) reduced to what
## this screen prints. All four send `crew_casualties` / `crew_injuries` as COUNTS with
## the records in `*_data`; this panel typed them as Arrays, so assigning the count was
## a runtime error that aborted show_results() on EVERY path and left a blank card with
## only its two buttons (measured 2026-10-29 on all three shapes captured).
##
## Static and tolerant of either form, so a fifth producer cannot blank it again.
static func summarize(result) -> Dictionary:
	var r: Dictionary = result if result is Dictionary else {}
	return {
		"victory": bool(r.get("victory", r.get("won", false))),
		"held_field": bool(r.get("held_field", false)),
		"rounds": int(r.get("rounds_fought", r.get("rounds", 0))),
		"casualties": _count(r, "crew_casualties"),
		"injuries": _count(r, "crew_injuries"),
		"enemies_defeated": int(r.get("enemies_defeated_count", -1)),
		"auto_resolved": bool(r.get("auto_resolved", false)),
		# Core Rules p.90: the objective, not the fight, decides the mission, so a won
		# fight can still miss it. Every emit site carries both keys.
		"objective": str(r.get("objective_id", "")),
		"objective_met": bool(r.get("objective_met", false)),
	}


## A count from the `<key>_data` records when they are present, else from `<key>`
## as either a number or a list.
static func _count(r: Dictionary, key: String) -> int:
	var records: Variant = r.get(key + "_data", null)
	if records is Array:
		return (records as Array).size()
	var value: Variant = r.get(key, 0)
	if value is Array:
		return (value as Array).size()
	return int(value) if (value is int or value is float) else 0


## Show results from a completed battle.
func show_results(result) -> void:
	var s: Dictionary = summarize(result)

	# Title
	if s["victory"]:
		_title_label.text = "VICTORY"
		_title_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif s["held_field"]:
		_title_label.text = "HELD THE FIELD"
		_title_label.add_theme_color_override("font_color", COLOR_FOCUS)
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", COLOR_DANGER)

	# Stats
	var lines: Array[String] = []
	if not str(s["objective"]).is_empty():
		lines.append("Objective (%s): %s" % [str(s["objective"]).capitalize(),
			"[color=ui-success]achieved[/color]" if s["objective_met"]
				else "[color=ui-danger]not achieved[/color]"])
	lines.append_array([
		"Rounds Fought: [color=ui-info]%d[/color]" % s["rounds"],
		"Casualties: [color=ui-danger]%d[/color]" % s["casualties"],
		"Injuries: [color=ui-warning]%d[/color]" % s["injuries"],
	])
	if int(s["enemies_defeated"]) >= 0:
		lines.append("Enemies Defeated: [color=ui-success]%d[/color]" % s["enemies_defeated"])
	if s["auto_resolved"]:
		lines.append("[color=ui-secondary]Auto-resolved[/color]")
	lines.append("[color=ui-secondary]Nothing from a Simulator battle is saved.[/color]")
	_stats_label.text = UIColors.bbcode("[center]%s[/center]" % "\n".join(lines))

	# TweenFX pop-in for the title
	var tweenfx = Engine.get_main_loop().root.get_node_or_null("/root/TweenFX") if Engine.get_main_loop() else null
	if tweenfx and tweenfx.has_method("pop_in"):
		_title_label.pivot_offset = _title_label.size / 2
		tweenfx.pop_in(_title_label)

	show()
