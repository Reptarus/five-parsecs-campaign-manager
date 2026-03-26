extends Control

## Post-battle results overlay for the Battle Simulator.
## Shows victory/defeat, stats, and navigation options.

signal play_again_pressed()
signal main_menu_pressed()

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
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

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(SPACING_LG)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(500, 300)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	vbox.add_child(_title_label)

	# Stats
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.custom_minimum_size = Vector2(0, 80)
	_stats_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	_stats_label.add_theme_color_override("default_color", COLOR_TEXT)
	vbox.add_child(_stats_label)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", SPACING_MD)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_play_again_btn = Button.new()
	_play_again_btn.text = "Play Again"
	_play_again_btn.custom_minimum_size = Vector2(180, TOUCH_TARGET)
	_play_again_btn.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_play_again_btn.pressed.connect(func(): play_again_pressed.emit())
	btn_row.add_child(_play_again_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.custom_minimum_size = Vector2(180, TOUCH_TARGET)
	_menu_btn.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_menu_btn.pressed.connect(func(): main_menu_pressed.emit())
	btn_row.add_child(_menu_btn)

	# TweenFX press feedback
	var tweenfx = Engine.get_main_loop().root.get_node_or_null("/root/TweenFX") if Engine.get_main_loop() else null
	if tweenfx and tweenfx.has_method("press"):
		for btn: Button in [_play_again_btn, _menu_btn]:
			btn.pivot_offset = btn.size / 2
			btn.pressed.connect(func(): tweenfx.press(btn))


## Show results from a completed battle.
## result: BattleResult from TacticalBattleUI (has .victory, .rounds_fought, .crew_casualties, .crew_injuries)
func show_results(result) -> void:
	var victory: bool = result.victory if result else false
	var rounds: int = result.rounds_fought if result else 0
	var casualties: Array = result.crew_casualties if result else []
	var injuries: Array = result.crew_injuries if result else []

	# Title
	if victory:
		_title_label.text = "VICTORY"
		_title_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", COLOR_DANGER)

	# Stats
	var text := ""
	text += "[center]"
	text += "Rounds Fought: [color=#4FC3F7]%d[/color]\n" % rounds
	text += "Casualties: [color=#DC2626]%d[/color]\n" % casualties.size()
	text += "Injuries: [color=#D97706]%d[/color]\n" % injuries.size()
	text += "[/center]"
	_stats_label.text = text

	# TweenFX pop-in for the title
	var tweenfx = Engine.get_main_loop().root.get_node_or_null("/root/TweenFX") if Engine.get_main_loop() else null
	if tweenfx and tweenfx.has_method("pop_in"):
		_title_label.pivot_offset = _title_label.size / 2
		tweenfx.pop_in(_title_label)

	show()
