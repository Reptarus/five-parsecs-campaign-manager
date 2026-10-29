extends Control

## Bug Hunt Campaign Creation UI — Thin shell wiring 4 panels to coordinator.
## Mirrors the CampaignCreationUI pattern: layout + navigation + signal wiring.

const CoordinatorScript := preload("res://src/ui/screens/bug_hunt/BugHuntCreationCoordinator.gd")
const ConfigPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntConfigPanel.gd")
const SquadPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")
const EquipmentPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntEquipmentPanel.gd")
const ReviewPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntReviewPanel.gd")

## This screen stays a plain Control (it is a wizard shell, not a campaign screen),
## so it has no CampaignScreenBase._fix_touch_scroll_filters() to inherit and opens
## the subtree itself.
const TouchScrollOpenerRef := preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")
const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := UIColorsRef.COLOR_BASE
const COLOR_TEXT := UIColorsRef.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := UIColorsRef.COLOR_TEXT_SECONDARY
const COLOR_ACCENT := UIColorsRef.COLOR_ACCENT
const MAX_FORM_WIDTH := 800

var coordinator: CoordinatorScript
var panels: Array[Control] = []
var current_panel: Control

var _step_label: Label
var _next_button: Button
var _back_button: Button
var _finish_button: Button
var _panel_container: Control
var _content_margin: MarginContainer


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
	_update_buttons(false, false, false)  # ISSUE-047: disable Next until config validates
	get_viewport().size_changed.connect(_apply_content_max_width)
	_apply_content_max_width()
	_apply_router_context()
	_open_touch_chain()


## The main menu's "Bug Hunt Co-op Campaign" choice arrives as SceneRouter context
## {"coop": true} (MainMenu._open_bug_hunt_coop_creation). Read once and CLEARED: the
## router keeps a context until someone erases it, so a later plain "New Bug Hunt" would
## otherwise open with co-op already switched on.
func _apply_router_context() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router == null or not router.has_method("get_scene_context"):
		return
	var ctx: Dictionary = router.get_scene_context("bug_hunt_creation")
	if bool(ctx.get("coop", false)) and panels.size() > 0 \
			and panels[0].has_method("preselect_coop"):
		panels[0].preselect_coop()
	if router.has_method("clear_scene_context"):
		router.clear_scene_context("bug_hunt_creation")


func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	# Main margin (stored for dynamic max-width adjustment)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	_content_margin = margin

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header — stacked: top row (cancel + title), bottom row (step indicator)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	# A row whose title WRAPS beside Cancel. This was an HFlowContainer holding an
	# unwrapped Label, which moved the title under Cancel but still let it demand its whole
	# text width: on a 310 px phone it ended at x=332 (test_bug_hunt_screen_fit.gd).
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header.add_child(header_row)

	var cancel_button := Button.new()
	cancel_button.text = "< Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 48)  # ISSUE-044: TOUCH_TARGET_MIN
	cancel_button.pressed.connect(_on_cancel_pressed)
	header_row.add_child(cancel_button)

	var title := Label.new()
	title.text = "BUG HUNT — NEW CAMPAIGN"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_row.add_child(title)

	_step_label = Label.new()
	_step_label.text = "Step 1 of 4: Campaign Config"
	_step_label.add_theme_font_size_override("font_size", _scaled_font(16))
	_step_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_step_label)

	# Panel container — fills remaining space
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)

	# Navigation buttons. A flow row (TacticsCreationUI's shape): Back, Next and Launch
	# Campaign side by side need more than a phone's width.
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override("h_separation", 16)
	nav.add_theme_constant_override("v_separation", 8)
	nav.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(nav)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(0, 48)
	nav.add_child(_back_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(0, 48)
	nav.add_child(_next_button)

	_finish_button = Button.new()
	_finish_button.text = "Launch Campaign"
	_finish_button.custom_minimum_size = Vector2(0, 48)
	nav.add_child(_finish_button)


func _create_coordinator() -> void:
	coordinator = CoordinatorScript.new()
	add_child(coordinator)


func _create_panels() -> void:
	var config_panel := ConfigPanelScript.new() as Control
	var squad_panel := SquadPanelScript.new() as Control
	var equipment_panel := EquipmentPanelScript.new() as Control
	var review_panel := ReviewPanelScript.new() as Control

	panels = [config_panel, squad_panel, equipment_panel, review_panel]

	for panel in panels:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_child(panel)
		panel.hide()
		if panel.has_method("set_coordinator"):
			panel.set_coordinator(coordinator)


func _connect_signals() -> void:
	# Coordinator signals
	coordinator.navigation_updated.connect(_update_buttons)
	coordinator.step_changed.connect(_on_step_changed)

	# Panel signals → coordinator
	var config_panel: Control = panels[0]
	var squad_panel: Control = panels[1]
	var equipment_panel: Control = panels[2]
	var review_panel: Control = panels[3]

	if config_panel.has_signal("config_updated"):
		config_panel.config_updated.connect(func(data: Dictionary):
			coordinator.update_config(data)
		)

	if squad_panel.has_signal("squad_updated"):
		squad_panel.squad_updated.connect(func(data: Dictionary):
			coordinator.update_squad(data)
		)

	if equipment_panel.has_signal("equipment_updated"):
		equipment_panel.equipment_updated.connect(func(data: Dictionary):
			coordinator.update_equipment(data)
		)

	# Navigation buttons
	_next_button.pressed.connect(_on_next_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_finish_button.pressed.connect(_on_finish_pressed)
	# TweenFX press feedback
	for btn: Button in [_next_button, _back_button, _finish_button]:
		btn.pressed.connect(func():
			btn.pivot_offset = btn.size / 2
			TweenFX.press(btn, 0.2)
		)


func _on_step_changed(step: int, _total: int) -> void:
	_show_panel(step)
	# The ONE label update per step. _show_panel() used to make a second one after its
	# fade-out await, which re-triggered the punch mid-flight and, before TweenManager
	# restored rest values on stop(), grew the label ~15% on every step.
	_update_step_label()

	# Refresh review panel when it becomes visible
	if step == 3 and panels[3].has_method("refresh"):
		panels[3].refresh()

	## After the refresh, because refresh() replaces the panel's children.
	##
	## _show_panel() above AWAITS its fade-out, so it is suspended when control
	## reaches here -- which is fine: all four panels are built once in
	## _create_panels(), so the subtree exists whether or not the fade has finished,
	## and mouse_filter is not something the fade touches.
	_open_touch_chain()


## §2: let a touch drag over content reach the ScrollContainer that owns it.
## Every surface under a finger is MOUSE_FILTER_STOP by construction, and
## Viewport::_gui_call_input stops touch drags there -- which is why the scrollbar
## and the desktop wheel worked on these screens and a finger did not.
func _open_touch_chain() -> void:
	TouchScrollOpenerRef.open_subtree(self)


func _show_panel(step: int) -> void:
	if current_panel:
		await TweenFX.fade_out(current_panel, 0.15).finished
		current_panel.hide()
	if step >= 0 and step < panels.size():
		current_panel = panels[step]
		current_panel.modulate.a = 0.0
		current_panel.show()
		TweenFX.fade_in(current_panel, 0.2)


func _update_step_label() -> void:
	var step_names := ["Campaign Config", "Squad Setup", "Equipment", "Review & Launch"]
	var idx: int = coordinator.current_step if coordinator else 0
	_step_label.text = "Step %d of 4: %s" % [idx + 1, step_names[idx]]
	# Left-aligned text in a full-width Label: a centred pivot slid the text sideways
	# while it scaled, so it is anchored on the left edge.
	_step_label.pivot_offset = Vector2(0.0, _step_label.size.y / 2.0)
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
	else:
		push_error("BugHuntCreationUI: SceneRouter not found")

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
