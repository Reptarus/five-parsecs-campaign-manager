extends Control

## Tactics Review Panel — Step 4 of 5
## Read-only summary of all creation data. Validation check.

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const COLOR_SUCCESS := _UC.COLOR_SUCCESS
const COLOR_DANGER := _UC.COLOR_DANGER
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG

var _coordinator = null
var _content: VBoxContainer


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)


func set_coordinator(coord) -> void:
	_coordinator = coord


func refresh() -> void:
	if not _content:
		return
	for child in _content.get_children():
		child.queue_free()

	if not _coordinator:
		return

	# Title
	var title := Label.new()
	title.text = "CAMPAIGN REVIEW"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	# Config summary
	_add_card("Configuration", _build_config_summary())

	# Species
	_add_card("Species", _build_species_summary())

	# Roster
	_add_card("Army Roster", _build_roster_summary())

	# Validation
	_add_validation_section()


func _build_config_summary() -> String:
	if not _coordinator:
		return "No data"
	var cfg: Dictionary = _coordinator.config_data
	var lines: Array[String] = []
	lines.append("Campaign: %s" % cfg.get("campaign_name", "(none)"))
	if not cfg.get("army_name", "").is_empty():
		lines.append("Army: %s" % cfg.army_name)
	lines.append("Points: %d" % cfg.get("points_limit", 500))
	lines.append("Organization: %s" % cfg.get("org_type", "platoon").capitalize())
	lines.append("Play Mode: %s" % cfg.get("play_mode", "solo").capitalize())
	return "\n".join(lines)


func _build_species_summary() -> String:
	if not _coordinator:
		return "No data"
	var sid: String = _coordinator.species_id
	if sid.is_empty():
		return "No species selected"
	var book: TacticsSpeciesBook = _coordinator.get_species_book()
	if book and book.species:
		var line := book.species.species_name
		if not book.species.species_traits.is_empty():
			line += "\nTraits: %s" % book.species.get_traits_display()
		return line
	return sid.capitalize()


func _build_roster_summary() -> String:
	if not _coordinator:
		return "No data"
	var entries: Array = _coordinator.roster_entries
	if entries.is_empty():
		return "No units added"

	var lines: Array[String] = []
	var total_pts: int = 0
	var book: TacticsSpeciesBook = _coordinator.get_species_book()

	for entry in entries:
		var name: String = entry.get("display_name", "Unknown")
		var cost: int = 0
		if book:
			var profile: TacticsUnitProfile = book.get_unit_profile(entry.get("unit_id", ""))
			if profile:
				cost = profile.points_cost
		total_pts += cost
		lines.append("• %s (%dpts, %d models)" % [
			name, cost, entry.get("model_count", 1)])

	var limit: int = _coordinator.config_data.get("points_limit", 500)
	lines.append("")
	lines.append("Total: %d / %d pts" % [total_pts, limit])
	return "\n".join(lines)


func _add_validation_section() -> void:
	if not _coordinator or not _coordinator.has_method("get_validation_errors"):
		return

	var errors: Array[String] = _coordinator.get_validation_errors()

	var header := Label.new()
	header.add_theme_font_size_override("font_size", _scaled_font(18))
	if errors.is_empty():
		header.text = "Validation: PASSED"
		header.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		header.text = "Validation: %d issue(s)" % errors.size()
		header.add_theme_color_override("font_color", COLOR_DANGER)
	_content.add_child(header)

	for err in errors:
		var lbl := Label.new()
		lbl.text = "• " + err
		lbl.add_theme_font_size_override("font_size", _scaled_font(12))
		lbl.add_theme_color_override("font_color", COLOR_DANGER)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(lbl)


func _add_card(card_title: String, body_text: String) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = card_title
	title_lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	title_lbl.add_theme_color_override("font_color", COLOR_FOCUS)
	vbox.add_child(title_lbl)

	var body := Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", _scaled_font(14))
	body.add_theme_color_override("font_color", COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	_content.add_child(card)
