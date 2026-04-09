class_name PlanetfallPlaceholderPanel
extends Control

## Generic placeholder panel for unimplemented Planetfall turn steps.
## Displays the phase name and a "Complete Phase" button.
## Implements the standard panel interface contract so the TurnController
## can treat it identically to real panels.

signal phase_completed(result_data: Dictionary)

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node  # PlanetfallPhaseManager
var _phase_name: String = "Unknown Phase"
var _phase_index: int = -1
var _title_label: Label
var _desc_label: Label
var _complete_btn: Button


func _ready() -> void:
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func configure(phase_name: String, phase_index: int) -> void:
	## Set the display name and index for this placeholder.
	_phase_name = phase_name
	_phase_index = phase_index
	if _title_label:
		_title_label.text = _phase_name.to_upper()


func refresh() -> void:
	## Called when this panel becomes visible. Update display with current data.
	if _title_label:
		_title_label.text = _phase_name.to_upper()
	if _complete_btn:
		_complete_btn.disabled = false


func complete() -> void:
	## Called by TurnController to trigger completion externally.
	_on_complete_pressed()


## ============================================================================
## PRIVATE — UI BUILD
## ============================================================================

func _build_ui() -> void:
	# Full-rect anchoring
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", SPACING_LG)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = _phase_name.to_upper()
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Description
	_desc_label = Label.new()
	_desc_label.text = "This phase will be implemented in a future sprint.\nClick below to proceed to the next step."
	_desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	# Phase index badge
	if _phase_index >= 0:
		var badge := Label.new()
		badge.text = "Step %d of 18" % (_phase_index + 1)
		badge.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		badge.add_theme_color_override("font_color", COLOR_ACCENT)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)

	# Complete button
	_complete_btn = Button.new()
	_complete_btn.text = "Complete Phase"
	_complete_btn.custom_minimum_size.y = 48
	_complete_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_complete_btn.custom_minimum_size.x = 200
	_complete_btn.pressed.connect(_on_complete_pressed)
	vbox.add_child(_complete_btn)


func _on_complete_pressed() -> void:
	if _complete_btn:
		_complete_btn.disabled = true
	phase_completed.emit({})
