extends Control

## Tactics Species Panel — Step 1 of 5
## Browse 14 species with trait preview, select primary (+ optional secondary).

signal species_updated(data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_ACCENT_HOVER := _UC.COLOR_ACCENT_HOVER
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_FOCUS := _UC.COLOR_FOCUS
const SPACING_SM := _UC.SPACING_SM
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _coordinator = null
var _species_books: Dictionary = {}  # species_id -> TacticsSpeciesBook
var _selected_species_id: String = ""
var _card_container: VBoxContainer
var _cards: Dictionary = {}  # species_id -> PanelContainer


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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "SELECT YOUR SPECIES"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var flavor := Label.new()
	flavor.text = "Choose the species for your army. Each has unique traits and unit profiles."
	flavor.add_theme_font_size_override("font_size", _scaled_font(14))
	flavor.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)

	# Load all species books
	_species_books = TacticsSpeciesBookLoader.load_all_species_books()

	# Section: Major Powers
	_add_section_header(vbox, "Major Powers")
	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_card_container)

	var major_section := VBoxContainer.new()
	major_section.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(major_section)

	var minor_section_header_added := false
	var minor_section := VBoxContainer.new()
	minor_section.add_theme_constant_override("separation", SPACING_SM)

	var creature_section_header_added := false
	var creature_section := VBoxContainer.new()
	creature_section.add_theme_constant_override("separation", SPACING_SM)

	# Sort species by power level, then name
	var sorted_ids: Array = _species_books.keys()
	sorted_ids.sort_custom(func(a, b):
		var sa: TacticsSpeciesBook = _species_books[a]
		var sb: TacticsSpeciesBook = _species_books[b]
		if not sa or not sa.species or not sb or not sb.species:
			return false
		if sa.species.power_level != sb.species.power_level:
			return sa.species.power_level < sb.species.power_level
		return sa.species.species_name < sb.species.species_name
	)

	for sid in sorted_ids:
		var book: TacticsSpeciesBook = _species_books[sid]
		if not book or not book.species:
			continue

		var card := _create_species_card(book)
		_cards[sid] = card

		match book.species.power_level:
			TacticsSpecies.PowerLevel.MAJOR:
				major_section.add_child(card)
			TacticsSpecies.PowerLevel.MINOR:
				if not minor_section_header_added:
					_add_section_header(vbox, "Minor Powers")
					vbox.add_child(minor_section)
					minor_section_header_added = true
				minor_section.add_child(card)
			TacticsSpecies.PowerLevel.CREATURE:
				if not creature_section_header_added:
					_add_section_header(vbox, "Creatures")
					vbox.add_child(creature_section)
					creature_section_header_added = true
				creature_section.add_child(card)

	# Add minor/creature sections if not already added (empty case)
	if not minor_section_header_added:
		_add_section_header(vbox, "Minor Powers")
		vbox.add_child(minor_section)
	if not creature_section_header_added:
		_add_section_header(vbox, "Creatures")
		vbox.add_child(creature_section)


func _create_species_card(book: TacticsSpeciesBook) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = TOUCH_TARGET_COMFORT

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	card.add_child(hbox)

	# Left: name + power level badge
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = book.species.species_name
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(name_lbl)

	# Power level badge
	var power_str: String = TacticsSpecies.PowerLevel.keys()[book.species.power_level].capitalize()
	var badge_lbl := Label.new()
	badge_lbl.text = "%s — %d units, %d weapons" % [
		power_str, book.unit_profiles.size(), book.weapons.size()]
	badge_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	badge_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	info_vbox.add_child(badge_lbl)

	# Traits
	if book.species.species_traits.size() > 0:
		var traits_lbl := Label.new()
		traits_lbl.text = book.species.get_traits_display()
		traits_lbl.add_theme_font_size_override("font_size", _scaled_font(11))
		traits_lbl.add_theme_color_override("font_color", COLOR_FOCUS)
		traits_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(traits_lbl)

	# Right: select button
	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size = Vector2(80, 40)
	var sid: String = book.species.species_id
	select_btn.pressed.connect(func(): _on_species_selected(sid))
	hbox.add_child(select_btn)

	return card


func _on_species_selected(sid: String) -> void:
	_selected_species_id = sid
	_update_card_highlights()
	species_updated.emit({
		"species_id": sid,
		"secondary_species_id": "",
	})


func _update_card_highlights() -> void:
	for card_sid in _cards:
		var card: PanelContainer = _cards[card_sid]
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if card_sid == _selected_species_id:
				style.border_color = COLOR_FOCUS
				style.set_border_width_all(2)
			else:
				style.border_color = COLOR_BORDER
				style.set_border_width_all(1)


func _add_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	parent.add_child(lbl)
