extends Control

## Tactics Campaign Creation UI — Thin shell wiring 5 panels to coordinator.
## Mirrors the BugHuntCreationUI pattern: layout + navigation + signal wiring.

const CoordinatorScript := preload("res://src/ui/screens/tactics/TacticsCreationCoordinator.gd")
const ConfigPanelScript := preload("res://src/ui/screens/tactics/panels/TacticsConfigPanel.gd")
const SpeciesPanelScript := preload("res://src/ui/screens/tactics/panels/TacticsSpeciesPanel.gd")
const RosterPanelScript := preload("res://src/ui/screens/tactics/panels/TacticsRosterPanel.gd")
const ReviewPanelScript := preload("res://src/ui/screens/tactics/panels/TacticsReviewPanel.gd")

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const TouchScrollOpenerRef = preload("res://src/ui/components/common/TouchScrollOpener.gd")
const COLOR_BASE := UIColorsRef.COLOR_BASE
const COLOR_TEXT := UIColorsRef.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := UIColorsRef.COLOR_TEXT_SECONDARY
const COLOR_ACCENT := UIColorsRef.COLOR_ACCENT
const MAX_FORM_WIDTH := 800

const STEP_NAMES := [
	"Configuration",
	"Species",
	"Army Roster",
	"Review",
]

var coordinator: CoordinatorScript
var panels: Array[Control] = []
var current_panel: Control

var _step_label: Label
var _next_button: Button
var _back_button: Button
var _finish_button: Button
var _panel_container: Control
var _content_margin: MarginContainer
var _title_spacer: Control


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
	# ⚠ The label used to be filled only on a step CHANGE, so the first screen showed
	# its build-time literal, "Step 1 of 5", on a four-step wizard.
	_update_step_label()
	_update_buttons(false, false, false)
	get_viewport().size_changed.connect(_apply_content_max_width)
	_apply_content_max_width()
	# This screen extends Control, so it has no base-class sweep, and the Species and
	# Review steps had none of their own: 15 species cards and their Select buttons stayed
	# STOP and swallowed a drag meant for the list. Kept open, as PlanetfallCreationUI is,
	# because every step adds content as the player works.
	TouchScrollOpenerRef.keep_open(self)


func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	# Main margin
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

	# Top row: Cancel + Title
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	header.add_child(top_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	# The shared token. 40 was not under the floor: the theme drew it at 42 design px
	# (48.7 dp), so this is consistency with the turn screen, not a fix.
	cancel_btn.custom_minimum_size.y = UIColorsRef.TOUCH_TARGET_MIN
	cancel_btn.pressed.connect(_on_cancel)
	top_row.add_child(cancel_btn)

	var title := Label.new()
	title.text = "FIVE PARSECS: TACTICS"
	title.add_theme_font_size_override("font_size", _scaled_font(22))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ⚠ Wrapped, like PlanetfallCreationUI's title. Unwrapped it demanded its whole
	# text width, and with Cancel and the spacer beside it the header pushed EVERY step
	# past a phone's right edge: the species Select buttons, the roster's + Add and
	# Launch Campaign were all off-screen (capture_modes.gd, 393x851, 2026-10-28).
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(title)

	# Spacer to balance cancel button, so the title centres on the page. Wide screens
	# only: on a phone the 70 px it takes are worth more to the title
	# (_apply_content_max_width() shows or hides it).
	_title_spacer = Control.new()
	_title_spacer.custom_minimum_size.x = 70
	top_row.add_child(_title_spacer)

	# Step indicator
	_step_label = Label.new()
	_step_label.text = ""  # set by _update_step_label() from the coordinator
	_step_label.add_theme_font_size_override("font_size", _scaled_font(14))
	_step_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_step_label)

	# Panel container (fills remaining space)
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Navigation buttons. A flow row, so Back and Launch Campaign wrap onto two lines on
	# a phone instead of pushing Launch off its right edge (3 px past 310, in a row).
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override("h_separation", 12)
	nav.add_theme_constant_override("v_separation", 8)
	nav.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(120, 48)
	nav.add_child(_back_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(120, 48)
	nav.add_child(_next_button)

	_finish_button = Button.new()
	_finish_button.text = "Launch Campaign"
	_finish_button.custom_minimum_size = Vector2(0, 48)
	_finish_button.visible = false
	nav.add_child(_finish_button)


func _create_coordinator() -> void:
	coordinator = CoordinatorScript.new()
	add_child(coordinator)


func _create_panels() -> void:
	var config_panel := ConfigPanelScript.new()
	var species_panel := SpeciesPanelScript.new()
	var roster_panel := RosterPanelScript.new()
	var review_panel := ReviewPanelScript.new()

	panels = [config_panel, species_panel, roster_panel, review_panel]

	for panel in panels:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		_panel_container.add_child(panel)
		if panel.has_method("set_coordinator"):
			panel.set_coordinator(coordinator)


func _connect_signals() -> void:
	# Coordinator signals
	coordinator.navigation_updated.connect(_update_buttons)
	coordinator.step_changed.connect(_on_step_changed)

	# Panel signals → coordinator
	var config_panel: Control = panels[0]
	if config_panel.has_signal("config_updated"):
		config_panel.config_updated.connect(
			func(data): coordinator.update_config(data))

	var species_panel: Control = panels[1]
	if species_panel.has_signal("species_updated"):
		species_panel.species_updated.connect(
			func(data): coordinator.update_species(data))

	var roster_panel: Control = panels[2]
	if roster_panel.has_signal("roster_updated"):
		roster_panel.roster_updated.connect(
			func(entries): coordinator.update_roster(entries))

	# Nav buttons
	_back_button.pressed.connect(func(): coordinator.previous_step())
	_next_button.pressed.connect(func(): coordinator.next_step())
	_finish_button.pressed.connect(func(): coordinator.finalize())

	# TweenFX press feedback
	var tfx = get_node_or_null("/root/TweenFX")
	if tfx:
		for btn in [_back_button, _next_button, _finish_button]:
			btn.button_down.connect(func():
				btn.pivot_offset = btn.size / 2
				if tfx.has_method("press"):
					tfx.press(btn))


func _on_step_changed(step: int, _total: int) -> void:
	# One panel per step (the separate Vehicles step is gone; see the coordinator).
	var panel_idx: int = step

	_show_panel(panel_idx)
	_update_step_label()

	# Refresh roster panel when entering step 2
	if step == 2 and panel_idx < panels.size() and panels[panel_idx].has_method("refresh"):
		panels[panel_idx].refresh()

	# Refresh review panel when entering step 3
	if step == 3 and panel_idx < panels.size() and panels[panel_idx].has_method("refresh"):
		panels[panel_idx].refresh()


func _show_panel(index: int) -> void:
	if index < 0 or index >= panels.size():
		return

	var tfx = get_node_or_null("/root/TweenFX")

	# Hide current
	if current_panel and is_instance_valid(current_panel):
		if tfx and tfx.has_method("fade_out"):
			tfx.fade_out(current_panel, 0.15)
			await get_tree().create_timer(0.15).timeout
		current_panel.visible = false

	# Show new
	current_panel = panels[index]
	current_panel.visible = true
	if tfx and tfx.has_method("fade_in"):
		tfx.fade_in(current_panel, 0.2)


func _update_step_label() -> void:
	if not _step_label:
		return
	var step: int = coordinator.current_step
	var name: String = coordinator.get_step_name()
	_step_label.text = "Step %d of %d: %s" % [step + 1, coordinator.total_steps, name]

	var tfx = get_node_or_null("/root/TweenFX")
	if tfx and tfx.has_method("punch_in"):
		_step_label.pivot_offset = _step_label.size / 2
		tfx.punch_in(_step_label, 0.3)


func _update_buttons(can_back: bool, can_forward: bool, can_finish: bool) -> void:
	_back_button.visible = can_back
	_back_button.disabled = not can_back
	_next_button.visible = not can_finish
	_next_button.disabled = not can_forward
	_finish_button.visible = can_finish
	_finish_button.disabled = not can_finish


func _on_cancel() -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")


func _apply_content_max_width() -> void:
	if not _content_margin:
		return
	var vp := get_viewport()
	if not vp:
		return
	var vp_width: float = vp.get_visible_rect().size.x
	if vp_width > MAX_FORM_WIDTH + 64:
		var side: float = (vp_width - MAX_FORM_WIDTH) / 2.0
		_content_margin.add_theme_constant_override("margin_left", int(side))
		_content_margin.add_theme_constant_override("margin_right", int(side))
		if _title_spacer:
			_title_spacer.visible = true
	else:
		if _title_spacer:
			_title_spacer.visible = false
		_content_margin.add_theme_constant_override("margin_left", 16)
		_content_margin.add_theme_constant_override("margin_right", 16)
