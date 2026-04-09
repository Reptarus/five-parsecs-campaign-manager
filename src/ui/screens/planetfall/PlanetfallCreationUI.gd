extends Control

## Planetfall Campaign Creation UI — 6-step wizard shell.
## Follows the BugHuntCreationUI pattern: code-built layout + coordinator + panels.
##
## Steps:
##   0: Expedition Type
##   1: Character Roster
##   2: Backgrounds
##   3: Map Generation
##   4: Tutorial Missions
##   5: Final Review

const CoordinatorScript := preload("res://src/ui/screens/planetfall/PlanetfallCreationCoordinator.gd")
const ExpeditionPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallExpeditionPanel.gd")
const RosterPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallRosterPanel.gd")
const BackgroundsPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallBackgroundsPanel.gd")
const MapPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallMapPanel.gd")
const TutorialPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallTutorialPanel.gd")
const ReviewPanelScript := preload("res://src/ui/screens/planetfall/panels/PlanetfallReviewPanel.gd")

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := UIColorsRef.COLOR_BASE
const COLOR_TEXT := UIColorsRef.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := UIColorsRef.COLOR_TEXT_SECONDARY
const COLOR_ACCENT := UIColorsRef.COLOR_ACCENT
const MAX_FORM_WIDTH := 800

var coordinator: PlanetfallCreationCoordinator
var panels: Array[Control] = []
var current_panel: Control

var _step_label: Label
var _next_button: Button
var _back_button: Button
var _finish_button: Button
var _panel_container: Control
var _content_margin: MarginContainer

const STEP_NAMES := [
	"Expedition Type",
	"Character Roster",
	"Backgrounds",
	"Map Generation",
	"Tutorial Missions",
	"Review & Launch"
]


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_layout()
	_create_coordinator()
	_create_panels()
	_connect_signals()
	_show_panel(0)
	_update_buttons(false, false, false)
	get_viewport().size_changed.connect(_apply_content_max_width)
	_apply_content_max_width()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	_content_margin = margin

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	var header_row := HBoxContainer.new()
	header.add_child(header_row)

	var cancel_button := Button.new()
	cancel_button.text = "< Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 48)
	cancel_button.pressed.connect(_on_cancel_pressed)
	header_row.add_child(cancel_button)

	var title := Label.new()
	title.text = "PLANETFALL — NEW COLONY"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_step_label = Label.new()
	_step_label.text = "Step 1 of 6: Expedition Type"
	_step_label.add_theme_font_size_override("font_size", _scaled_font(16))
	_step_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	header.add_child(_step_label)

	# Panel container
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Navigation buttons
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(140, 48)
	nav.add_child(_back_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(140, 48)
	nav.add_child(_next_button)

	_finish_button = Button.new()
	_finish_button.text = "Establish Colony"
	_finish_button.custom_minimum_size = Vector2(200, 48)
	nav.add_child(_finish_button)


func _create_coordinator() -> void:
	coordinator = CoordinatorScript.new()
	add_child(coordinator)


func _create_panels() -> void:
	var expedition_panel := ExpeditionPanelScript.new() as Control
	var roster_panel := RosterPanelScript.new() as Control
	var backgrounds_panel := BackgroundsPanelScript.new() as Control
	var map_panel := MapPanelScript.new() as Control
	var tutorial_panel := TutorialPanelScript.new() as Control
	var review_panel := ReviewPanelScript.new() as Control

	panels = [expedition_panel, roster_panel, backgrounds_panel,
			map_panel, tutorial_panel, review_panel]

	for panel in panels:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_child(panel)
		panel.hide()
		if panel.has_method("set_coordinator"):
			panel.set_coordinator(coordinator)


func _connect_signals() -> void:
	coordinator.navigation_updated.connect(_update_buttons)
	coordinator.step_changed.connect(_on_step_changed)

	# Panel signals → coordinator
	if panels[0].has_signal("expedition_updated"):
		panels[0].expedition_updated.connect(func(data: Dictionary):
			coordinator.update_expedition(data)
		)
	if panels[1].has_signal("roster_updated"):
		panels[1].roster_updated.connect(func(characters: Array):
			coordinator.update_roster(characters)
		)
	if panels[2].has_signal("backgrounds_updated"):
		panels[2].backgrounds_updated.connect(func(data: Dictionary):
			coordinator.update_backgrounds(data)
		)
	if panels[3].has_signal("map_updated"):
		panels[3].map_updated.connect(func(data: Dictionary):
			coordinator.update_map_config(data)
		)
	if panels[4].has_signal("tutorials_updated"):
		panels[4].tutorials_updated.connect(func(data: Dictionary):
			coordinator.update_tutorial_results(data)
		)

	# Navigation buttons
	_next_button.pressed.connect(_on_next_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_finish_button.pressed.connect(_on_finish_pressed)

	for btn: Button in [_next_button, _back_button, _finish_button]:
		btn.pressed.connect(func():
			btn.pivot_offset = btn.size / 2
			TweenFX.press(btn, 0.2)
		)


func _on_step_changed(step: int, _total: int) -> void:
	_show_panel(step)
	_update_step_label()
	# Refresh review panel when visible
	if step == 5 and panels[5].has_method("refresh"):
		panels[5].refresh()


func _show_panel(step: int) -> void:
	if current_panel:
		await TweenFX.fade_out(current_panel, 0.15).finished
		current_panel.hide()
	if step >= 0 and step < panels.size():
		current_panel = panels[step]
		current_panel.modulate.a = 0.0
		current_panel.show()
		TweenFX.fade_in(current_panel, 0.2)
	_update_step_label()


func _update_step_label() -> void:
	var idx: int = coordinator.current_step if coordinator else 0
	_step_label.text = "Step %d of 6: %s" % [idx + 1, STEP_NAMES[idx]]
	_step_label.pivot_offset = _step_label.size / 2
	TweenFX.punch_in(_step_label, 0.15, 0.15)


func _update_buttons(can_back: bool, can_forward: bool, can_finish: bool) -> void:
	_back_button.visible = can_back
	_next_button.visible = can_forward and not can_finish
	_finish_button.visible = can_finish
	_next_button.disabled = not can_forward
	_finish_button.disabled = not can_finish


func _on_next_pressed() -> void:
	coordinator.next_step()


func _on_back_pressed() -> void:
	coordinator.previous_step()


func _on_finish_pressed() -> void:
	coordinator.finalize()


func _on_cancel_pressed() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("main_menu")


func _apply_content_max_width() -> void:
	if not _content_margin:
		return
	var vp := get_viewport()
	if not vp:
		return
	var vp_width := vp.get_visible_rect().size.x
	if vp_width > MAX_FORM_WIDTH + 64:
		var side := int((vp_width - MAX_FORM_WIDTH) / 2.0)
		_content_margin.add_theme_constant_override("margin_left", side)
		_content_margin.add_theme_constant_override("margin_right", side)
	else:
		_content_margin.add_theme_constant_override("margin_left", 20)
		_content_margin.add_theme_constant_override("margin_right", 20)
