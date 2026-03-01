class_name PsionicLegalityBadge
extends PanelContainer
## Psionic Legality Badge - Displays current world's psionic legality status
##
## Code-only UI component (no .tscn). Color-coded badge:
##   Green = WHO_CARES, Orange = HIGHLY_UNUSUAL, Red = OUTLAWED
##
## Usage: var badge = PsionicLegalityBadge.new(); badge.set_legality(legality_int)

const PsionicSystemRef = preload("res://src/core/systems/PsionicSystem.gd")

const COLOR_OUTLAWED := Color("#DC2626")
const COLOR_UNUSUAL := Color("#D97706")
const COLOR_SAFE := Color("#10B981")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_BG_BASE := Color("#252542")
const COLOR_BORDER_BASE := Color("#3A3A5C")

var _icon_label: Label
var _status_label: Label
var _detail_label: Label
var _current_legality: int = PsionicSystemRef.PsionicLegality.WHO_CARES

func _ready() -> void:
	_setup_style()
	_build_ui()
	_update_display()

func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_BASE
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER_BASE
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(200, 40)

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(_icon_label)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(_status_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 11)
	_detail_label.add_theme_color_override("font_color", Color("#808080"))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_label)

func set_legality(legality: int) -> void:
	_current_legality = legality
	if is_inside_tree():
		_update_display()

func _update_display() -> void:
	var color: Color
	var icon: String
	match _current_legality:
		PsionicSystemRef.PsionicLegality.OUTLAWED:
			color = COLOR_OUTLAWED
			icon = "X"
		PsionicSystemRef.PsionicLegality.HIGHLY_UNUSUAL:
			color = COLOR_UNUSUAL
			icon = "!"
		_:
			color = COLOR_SAFE
			icon = "~"

	_icon_label.text = icon
	_icon_label.add_theme_color_override("font_color", color)
	_status_label.text = "Psionics: %s" % PsionicSystemRef.get_legality_name(_current_legality)
	_detail_label.text = PsionicSystemRef.get_legality_description(_current_legality)

	# Update border color to match status
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var new_style := style.duplicate() as StyleBoxFlat
		new_style.border_color = color.lerp(COLOR_BORDER_BASE, 0.5)
		add_theme_stylebox_override("panel", new_style)

func get_legality() -> int:
	return _current_legality
