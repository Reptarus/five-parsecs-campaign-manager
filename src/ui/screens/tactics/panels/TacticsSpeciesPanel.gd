extends Control

## Tactics Species Panel — Step 1 of 5
## Browse 14 species with trait preview, select primary (+ optional secondary).

signal species_updated(data: Dictionary)

const _UC = preload("res://src/ui/components/base/UIColors.gd")
var _SpeciesBookLoader: GDScript
var _Species: GDScript
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
	var rm = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


func _ready() -> void:
	_SpeciesBookLoader = load("res://src/data/tactics/TacticsSpeciesBookLoader.gd")
	_Species = load("res://src/data/tactics/TacticsSpecies.gd")
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "SELECT YOUR SPECIES"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var flavor = Label.new()
	flavor.text = "Choose the species for your army. Each has unique traits and unit profiles."
	flavor.add_theme_font_size_override("font_size", _scaled_font(14))
	flavor.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)

	# Load all species books
	_species_books = _SpeciesBookLoader.load_all_species_books()

	# Section: Major Powers
	_add_section_header(vbox, "Major Powers")
	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_card_container)

	var major_section = VBoxContainer.new()
	major_section.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(major_section)

	var minor_section_header_added = false
	var minor_section = VBoxContainer.new()
	minor_section.add_theme_constant_override("separation", SPACING_SM)

	var creature_section_header_added = false
	var creature_section = VBoxContainer.new()
	creature_section.add_theme_constant_override("separation", SPACING_SM)

	# Sort species by power level, then name
	var sorted_ids: Array = _species_books.keys()
	sorted_ids.sort_custom(func(a, b):
		var sa =_species_books[a]
		var sb =_species_books[b]
		if not sa or not sa.species or not sb or not sb.species:
			return false
		if sa.species.power_level != sb.species.power_level:
			return sa.species.power_level < sb.species.power_level
		return sa.species.species_name < sb.species.species_name
	)

	for sid in sorted_ids:
		var book =_species_books[sid]
		if not book or not book.species:
			continue

		var card = _create_species_card(book)
		_cards[sid] = card

		match book.species.power_level:
			_Species.PowerLevel.MAJOR:
				major_section.add_child(card)
			_Species.PowerLevel.MINOR:
				if not minor_section_header_added:
					_add_section_header(vbox, "Minor Powers")
					vbox.add_child(minor_section)
					minor_section_header_added = true
				minor_section.add_child(card)
			_Species.PowerLevel.CREATURE:
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


func _create_species_card(book) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size.y = TOUCH_TARGET_COMFORT

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)
	card.add_child(hbox)

	# Left: name + power level badge
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = book.species.species_name
	name_lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(name_lbl)

	# Power level and the Military profile. ⚠ This read "Major — 12 units, 21 weapons",
	# the same for every species: units are composed from the one Army Builder (pp.133-139)
	# and every species arms from the one p.181 table. The profile is what differs.
	var badge_lbl = Label.new()
	badge_lbl.text = power_label(book)
	var line: String = military_line(book)
	if not line.is_empty():
		badge_lbl.text += "\n" + line
	badge_lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	badge_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	badge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(badge_lbl)

	# Special Rules, with what each one does. The card used to list the names alone,
	# so choosing a species meant knowing its rules already.
	for t in book.species.species_traits:
		if not t is TacticsSpecialRule:
			continue
		var rule_name := Label.new()
		rule_name.text = t.get_display_name()
		rule_name.add_theme_font_size_override("font_size", _scaled_font(12))
		rule_name.add_theme_color_override("font_color", COLOR_FOCUS)
		rule_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(rule_name)
		if not t.description.is_empty():
			var rule_text := Label.new()
			rule_text.text = t.description
			rule_text.add_theme_font_size_override("font_size", _scaled_font(11))
			rule_text.add_theme_color_override("font_color", COLOR_TEXT_SEC)
			rule_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info_vbox.add_child(rule_text)

	# Right: select button
	var select_btn = Button.new()
	select_btn.text = "Select"
	# The shared token. A 40 px minimum was not under the floor: the theme drew it at
	# 42 design px (48.7 dp), so this is consistency, not a fix.
	select_btn.custom_minimum_size = Vector2(80, _UC.TOUCH_TARGET_MIN)
	# Centred, not stretched: the card now carries the Military profile and each rule's
	# text, and a FILL button grew into a slab as tall as the card.
	select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sid: String = book.species.species_id
	select_btn.pressed.connect(func(): _on_species_selected(sid))
	hbox.add_child(select_btn)

	return card


## "Major Power", "Minor Power" or "Creature", as the book groups the army lists.
func power_label(book) -> String:
	match book.species.power_level:
		_Species.PowerLevel.MAJOR:
			return "Major Power"
		_Species.PowerLevel.MINOR:
			return "Minor Power"
	return "Creature"


## The Military profile as the species file prints it (pp.153-167), the figures every
## squad is built from. "" for Creatures, which have no profiles.
static func military_line(book) -> String:
	var p: Variant = book.profiles.get("military") if book.profiles is Dictionary else null
	if not p is Dictionary:
		return ""
	return "Military: Speed %d\" · Reactions %d · Combat Skill %+d · Toughness %d · KP %d · Savvy %+d" % [
		int(p.get("speed", 0)), int(p.get("reactions", 0)), int(p.get("combat_skill", 0)),
		int(p.get("toughness", 0)), int(p.get("kp", 0)), int(p.get("savvy", 0))]


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
		var style = card.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if card_sid == _selected_species_id:
				style.border_color = COLOR_FOCUS
				style.set_border_width_all(2)
			else:
				style.border_color = COLOR_BORDER
				style.set_border_width_all(1)


func _add_section_header(parent: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _scaled_font(18))
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	parent.add_child(lbl)
