extends Control

## Tactics Config Panel — Step 0 of 5
## Campaign name, points limit, org type, play mode, army name.

signal config_updated(data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_INPUT := _UC.COLOR_INPUT
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _coordinator = null
var _name_edit: LineEdit
var _army_name_edit: LineEdit
var _points_option: OptionButton
var _org_option: OptionButton
var _play_mode_option: OptionButton
var _validation_label: Label

var _config_data: Dictionary = {
	"campaign_name": "",
	"army_name": "",
	"points_limit": 500,
	"org_type": "platoon",
	"platoon_count": 1,
	"play_mode": "solo",
}

const POINTS_TIERS := [
	{"value": 500, "label": "500 pts — Small / Learning Game"},
	{"value": 750, "label": "750 pts — Standard Game"},
	{"value": 1000, "label": "1000 pts — Large Game"},
]

const ORG_TYPES := [
	{"value": "platoon", "label": "Platoon (1 platoon)"},
	{"value": "company", "label": "Company (2-4 platoons)"},
]

const PLAY_MODES := [
	{"value": "solo", "label": "Solo (vs AI)"},
	{"value": "gm", "label": "GM-Directed Scenarios"},
	{"value": "versus", "label": "Head-to-Head Pick-up Game"},
]


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "TACTICS — CAMPAIGN SETUP"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var flavor := Label.new()
	flavor.text = "Configure your Tactics campaign. Choose your force size, organization, and play mode."
	flavor.add_theme_font_size_override("font_size", _scaled_font(14))
	flavor.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)

	# Campaign name
	_add_section_label(vbox, "Campaign Name")
	_name_edit = _create_styled_line_edit("Enter campaign name...")
	_name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(_name_edit)

	# Army name (optional flavor)
	_add_section_label(vbox, "Army Name (optional)")
	_army_name_edit = _create_styled_line_edit("e.g., 3rd Colonial Expeditionary Force")
	_army_name_edit.text_changed.connect(_on_army_name_changed)
	vbox.add_child(_army_name_edit)

	# Points limit
	_add_section_label(vbox, "Points Limit")
	_points_option = OptionButton.new()
	_points_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	for tier in POINTS_TIERS:
		_points_option.add_item(tier.label)
	_points_option.selected = 0
	_points_option.item_selected.connect(_on_points_changed)
	vbox.add_child(_points_option)

	# Organization type
	_add_section_label(vbox, "Organization")
	_org_option = OptionButton.new()
	_org_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	for org in ORG_TYPES:
		_org_option.add_item(org.label)
	_org_option.selected = 0
	_org_option.item_selected.connect(_on_org_changed)
	vbox.add_child(_org_option)

	# Play mode
	_add_section_label(vbox, "Play Mode")
	_play_mode_option = OptionButton.new()
	_play_mode_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	for mode in PLAY_MODES:
		_play_mode_option.add_item(mode.label)
	_play_mode_option.selected = 0
	_play_mode_option.item_selected.connect(_on_mode_changed)
	vbox.add_child(_play_mode_option)

	# Validation
	_validation_label = Label.new()
	_validation_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_validation_label.add_theme_color_override("font_color", _UC.COLOR_DANGER)
	vbox.add_child(_validation_label)


func _on_name_changed(new_text: String) -> void:
	_config_data.campaign_name = new_text.strip_edges()
	_emit_update()


func _on_army_name_changed(new_text: String) -> void:
	_config_data.army_name = new_text.strip_edges()
	_emit_update()


func _on_points_changed(idx: int) -> void:
	if idx >= 0 and idx < POINTS_TIERS.size():
		_config_data.points_limit = POINTS_TIERS[idx].value
		# Auto-set platoon count based on points
		if _config_data.org_type == "company":
			_config_data.platoon_count = 2 if _config_data.points_limit <= 750 else 3
	_emit_update()


func _on_org_changed(idx: int) -> void:
	if idx >= 0 and idx < ORG_TYPES.size():
		_config_data.org_type = ORG_TYPES[idx].value
		_config_data.platoon_count = 1 if _config_data.org_type == "platoon" else 2
	_emit_update()


func _on_mode_changed(idx: int) -> void:
	if idx >= 0 and idx < PLAY_MODES.size():
		_config_data.play_mode = PLAY_MODES[idx].value
	_emit_update()


func _emit_update() -> void:
	# Validation feedback
	if _config_data.campaign_name.is_empty():
		_validation_label.text = "Campaign name is required"
	else:
		_validation_label.text = ""
	config_updated.emit(_config_data.duplicate())


func _add_section_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(lbl)


func _create_styled_line_edit(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_INPUT
	bg.border_color = COLOR_BORDER
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = SPACING_MD
	bg.content_margin_right = SPACING_MD
	edit.add_theme_stylebox_override("normal", bg)
	edit.add_theme_color_override("font_color", COLOR_TEXT)
	edit.add_theme_color_override("font_placeholder_color", COLOR_TEXT_SEC)
	return edit
