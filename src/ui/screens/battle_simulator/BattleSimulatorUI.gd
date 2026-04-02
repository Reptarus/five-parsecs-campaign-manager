extends Control

## Battle Simulator — Thin shell hosting the setup panel, TacticalBattleUI, and results panel.
## Follows BugHuntCreationUI pattern: all UI code-built, no multi-step wizard.

const SetupPanelScript := preload("res://src/ui/screens/battle_simulator/panels/BattleSimulatorSetupPanel.gd")
const ResultsPanelScript := preload("res://src/ui/screens/battle_simulator/panels/BattleSimulatorResultsPanel.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")

const COLOR_BASE := Color("#1A1A2E")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_ACCENT := Color("#2D5A7B")
const MAX_FORM_WIDTH := 800  # ISSUE-040: responsive centering

var _content_margin: MarginContainer
var _setup_panel: Control
var _results_panel: Control
var _battle_ui: Node = null
var _panel_container: Control
var _header: HBoxContainer
var _last_config: Dictionary = {}


func _ready() -> void:
	_build_layout()
	_create_panels()
	_connect_signals()
	_show_setup()


func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	# Main margin — responsive centering via _apply_content_max_width()
	_content_margin = MarginContainer.new()
	_content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_margin.add_theme_constant_override("margin_left", 20)
	_content_margin.add_theme_constant_override("margin_top", 20)
	_content_margin.add_theme_constant_override("margin_right", 20)
	_content_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(_content_margin)
	get_viewport().size_changed.connect(_apply_content_max_width)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_content_margin.add_child(vbox)
	call_deferred("_apply_content_max_width")

	# Header
	_header = HBoxContainer.new()
	vbox.add_child(_header)

	var back_button := Button.new()
	back_button.text = "< Back to Menu"
	back_button.custom_minimum_size = Vector2(160, 48)  # ISSUE-036: TOUCH_TARGET_MIN
	back_button.pressed.connect(_on_back_to_menu)
	_header.add_child(back_button)

	var title := Label.new()
	title.text = "BATTLE SIMULATOR"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title)

	# Panel container — fills remaining space
	_panel_container = Control.new()
	_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_panel_container)


func _create_panels() -> void:
	_setup_panel = SetupPanelScript.new() as Control
	_setup_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_container.add_child(_setup_panel)

	_results_panel = ResultsPanelScript.new() as Control
	_results_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_container.add_child(_results_panel)
	_results_panel.hide()


func _connect_signals() -> void:
	_setup_panel.launch_requested.connect(_on_launch_battle)
	_results_panel.play_again_pressed.connect(_on_play_again)
	_results_panel.main_menu_pressed.connect(_on_back_to_menu)


# --- State transitions ---

func _show_setup() -> void:
	_cleanup_battle_ui()
	_results_panel.hide()
	_setup_panel.show()
	_header.show()
	_restore_margins()


func _show_battle(context: Dictionary) -> void:
	_setup_panel.hide()
	_results_panel.hide()
	_header.hide()
	# Give battle UI full screen — no wrapper margins
	_set_margins(0)

	# Instantiate TacticalBattleUI from scene
	_battle_ui = TacticalBattleScene.instantiate()
	_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_container.add_child(_battle_ui)

	# CRITICAL: call initialize_battle() synchronously after add_child()
	# TacticalBattleUI uses call_deferred("_check_standalone_mode") in _ready()
	# which would trigger standalone fallback UI if _battle_initialized is still false
	_battle_ui.initialize_battle(
		context.get("crew", []),
		context.get("enemies", []),
		context.get("mission_data", null)
	)

	# Connect battle completion signal
	if _battle_ui.has_signal("tactical_battle_completed"):
		_battle_ui.tactical_battle_completed.connect(_on_battle_completed)
	if _battle_ui.has_signal("return_to_battle_resolution"):
		_battle_ui.return_to_battle_resolution.connect(_on_battle_abandoned)


func _show_results(result) -> void:
	_cleanup_battle_ui()
	_header.show()
	_restore_margins()
	_results_panel.show_results(result)
	_results_panel.show()


func _set_margins(px: int) -> void:
	_content_margin.add_theme_constant_override("margin_left", px)
	_content_margin.add_theme_constant_override("margin_top", px)
	_content_margin.add_theme_constant_override("margin_right", px)
	_content_margin.add_theme_constant_override("margin_bottom", px)


func _restore_margins() -> void:
	_set_margins(20)


func _cleanup_battle_ui() -> void:
	if is_instance_valid(_battle_ui):
		_battle_ui.queue_free()
		_battle_ui = null


# --- Signal handlers ---

func _on_launch_battle(config: Dictionary) -> void:
	_last_config = config.duplicate()
	var setup := BattleSimulatorSetup.new()
	var context: Dictionary = setup.generate_battle_context(config)
	_show_battle(context)


func _on_battle_completed(result) -> void:
	_show_results(result)


func _on_battle_abandoned() -> void:
	# Player hit "Return" during battle — go back to setup
	_show_setup()


func _on_play_again() -> void:
	_show_setup()


func _on_back_to_menu() -> void:
	_cleanup_battle_ui()
	# Clear residual temp data to prevent state leakage
	# into Campaign Creation or other modes
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("clear_all_temp_data"):
		gsm.clear_all_temp_data()
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("main_menu")
	else:
		push_error("BattleSimulatorUI: SceneRouter not found")


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
