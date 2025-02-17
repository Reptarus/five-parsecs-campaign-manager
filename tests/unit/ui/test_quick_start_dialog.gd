extends "res://addons/gut/test.gd"

const QuickStartDialog = preload("res://src/ui/components/dialogs/QuickStartDialog.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var dialog: QuickStartDialog
var template_selected_signal_emitted := false
var import_requested_signal_emitted := false

func before_each() -> void:
	dialog = QuickStartDialog.new()
	add_child(dialog)
	template_selected_signal_emitted = false
	import_requested_signal_emitted = false
	dialog.template_selected.connect(_on_template_selected)
	dialog.import_requested.connect(_on_import_requested)

func after_each() -> void:
	dialog.queue_free()

func _on_template_selected(_template: String) -> void:
	template_selected_signal_emitted = true

func _on_import_requested(_data: Dictionary) -> void:
	import_requested_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(dialog)
	assert_not_null(dialog.templates)
	assert_true(dialog.templates.has("Solo Campaign"))
	assert_true(dialog.templates.has("Standard Campaign"))
	assert_true(dialog.templates.has("Challenge Campaign"))

func test_template_data() -> void:
	var solo_campaign = dialog.templates["Solo Campaign"]
	assert_eq(solo_campaign.crew_size, GameEnums.CrewSize.FOUR)
	assert_eq(solo_campaign.difficulty, GameEnums.DifficultyLevel.NORMAL)
	assert_true(solo_campaign.mobile_friendly)

func test_mobile_ui_setup() -> void:
	if OS.has_feature("mobile"):
		dialog._setup_mobile_ui()
		var viewport_size = dialog.get_viewport().get_visible_rect().size
		assert_eq(dialog.custom_minimum_size.y, viewport_size.y * 0.8)
		assert_eq(dialog.position.y, viewport_size.y * 0.2)

func test_template_selection() -> void:
	var template_list = dialog.get_node("VBoxContainer/TemplateList")
	assert_not_null(template_list)
	dialog._on_template_selected(0) # Select first template
	assert_true(template_selected_signal_emitted)  