class_name PlanetfallEquipmentPanel
extends Control

## Equipment pool browser — accessible from Dashboard.
## Shows all weapons available to the colony, filtered by tier and class.
## Weapons are NOT individually owned — they come from the colony pool.
## Below them, the colony's Alien Artifacts (pp.135-136): Colony Items in effect, Single-Use
## items to activate, and Artifact equipment to give to one character for good.

const DisplayTextRef := preload("res://src/ui/components/common/DisplayText.gd")
const PlanetfallArmoryScript := preload(
	"res://src/core/systems/PlanetfallArmorySystem.gd")
const ResearchScript := preload("res://src/core/systems/PlanetfallResearchSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
const CoreScript := preload("res://src/game/campaign/PlanetfallCampaignCore.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_CYAN := UIColors.COLOR_CYAN
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const COLOR_DANGER := UIColors.COLOR_RED

var _campaign: Resource
var _armory: PlanetfallArmoryScript
var _current_filter: String = "all"  # "all", "standard", "tier_1", "tier_2"

var _content: VBoxContainer
var _filter_row: HFlowContainer
var _weapon_list: VBoxContainer
var _grunt_list: VBoxContainer
var _artifact_list: VBoxContainer
var _close_btn: Button


func _ready() -> void:
	_armory = PlanetfallArmoryScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	_current_filter = "all"
	_clear_container(_weapon_list)
	_build_weapon_list()
	_build_grunt_upgrades()
	_build_artifact_list()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(_content)

	# First and top right, as on every dashboard overlay: reachable the moment it opens.
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 48)
	_close_btn.pressed.connect(func(): hide())
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(_close_btn)

	var title := Label.new()
	title.text = "COLONY ARMORY"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var info := Label.new()
	info.text = "Weapons are assigned per mission from the colony pool — not individually owned."
	info.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
	info.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(info)

	# Filter buttons. A flow, so the four wrap two-and-two on a phone instead of running
	# the last one off the right edge.
	_filter_row = HFlowContainer.new()
	_filter_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_filter_row.add_theme_constant_override("h_separation", SPACING_SM)
	_filter_row.add_theme_constant_override("v_separation", SPACING_SM)
	_content.add_child(_filter_row)

	for filter in ["all", "standard", "tier_1", "tier_2"]:
		var btn := Button.new()
		btn.text = filter.replace("_", " ").capitalize()
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(_on_filter_pressed.bind(filter))
		_filter_row.add_child(btn)

	_weapon_list = VBoxContainer.new()
	_weapon_list.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(_weapon_list)

	_grunt_list = VBoxContainer.new()
	_grunt_list.name = "GruntUpgrades"
	_grunt_list.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(_grunt_list)

	_artifact_list = VBoxContainer.new()
	_artifact_list.name = "AlienArtifacts"
	_artifact_list.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(_artifact_list)



## ============================================================================
## WEAPON LIST
## ============================================================================

func _build_weapon_list() -> void:
	var available: Array = _armory.get_available_weapons(_campaign)
	var all_weapons: Array = _armory.get_all_weapons()
	var available_ids: Array = []
	for w in available:
		if w is Dictionary:
			available_ids.append(w.get("id", ""))

	var weapons_to_show: Array = all_weapons
	if _current_filter != "all":
		weapons_to_show = _armory.get_weapons_by_tier(_current_filter)

	for weapon in weapons_to_show:
		if weapon is not Dictionary:
			continue
		var wid: String = weapon.get("id", "")
		var wname: String = weapon.get("name", "?")
		var tier: String = weapon.get("tier", "standard")
		var is_available: bool = available_ids.has(wid)

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_ELEVATED
		style.border_color = COLOR_SUCCESS if is_available else COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(SPACING_SM)
		card.add_theme_stylebox_override("panel", style)
		_weapon_list.add_child(card)

		# Stacked, not a row. The traits label wrapped inside an HBox beside two other
		# columns, so it got no width of its own and printed one letter per line, which made
		# every card several hundred pixels tall on a tablet as well as a phone.
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", SPACING_SM)
		vbox.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = wname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
		name_lbl.add_theme_color_override(
			"font_color", COLOR_TEXT_PRIMARY if is_available else COLOR_TEXT_SECONDARY)
		name_row.add_child(name_lbl)

		var tier_lbl := Label.new()
		tier_lbl.text = DisplayTextRef.title_case(tier)
		tier_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
		tier_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
		name_row.add_child(tier_lbl)

		var stats_lbl := Label.new()
		stats_lbl.text = DisplayTextRef.weapon_profile(weapon)
		stats_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		stats_lbl.add_theme_color_override("font_color", COLOR_CYAN)
		vbox.add_child(stats_lbl)

		var traits: Array = weapon.get("traits", [])
		if not traits.is_empty():
			var trait_lines: Array = []
			for t in traits:
				trait_lines.append(_trait_line(str(t)))
			var traits_lbl := Label.new()
			traits_lbl.text = "\n".join(PackedStringArray(trait_lines))
			traits_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
			traits_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
			traits_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(traits_lbl)

		if not is_available:
			var lock := Label.new()
			var reason: String = _armory.get_lock_reason(_campaign, wid)
			lock.text = "LOCKED" if reason == "" else "LOCKED: %s" % reason
			lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lock.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
			lock.add_theme_color_override("font_color", COLOR_DANGER)
			vbox.add_child(lock)


## p.78 Weapon Traits: say what the trait DOES, from the Armory's own table, so a
## player meeting "Stabilized" or "Hail of Fire" does not need the book open.
func _trait_line(trait_id: String) -> String:
	var info: Dictionary = _armory.get_weapon_trait(trait_id) if _armory else {}
	var trait_name: String = str(info.get("name", ""))
	if trait_name == "":
		trait_name = DisplayTextRef.title_case(trait_id)
	var what: String = str(info.get("description", ""))
	return trait_name if what == "" else "%s: %s" % [trait_name, what]


## ============================================================================
## GRUNT UPGRADES (p.79)
## ============================================================================

## All six, each with whether the colony has it and, if not, what it still needs. The
## upgrade list existed in the data and the Armory never showed it.
func _build_grunt_upgrades() -> void:
	_clear_container(_grunt_list)
	_grunt_list.add_child(_line("GRUNT UPGRADES (p.79)", FONT_SIZE_MD, COLOR_TEXT_PRIMARY))
	for u in _armory.grunt_upgrade_status(_campaign, ResearchScript.new()):
		var on: bool = bool(u.get("available", false))
		_grunt_list.add_child(_line("%s%s" % [str(u.get("name", "")),
				": available to every fireteam" if on else ""], FONT_SIZE_SM,
				COLOR_SUCCESS if on else COLOR_TEXT_PRIMARY))
		_grunt_list.add_child(_line(str(u.get("description", "")), FONT_SIZE_XS,
				COLOR_TEXT_SECONDARY))
		if not on:
			_grunt_list.add_child(_line("LOCKED: %s" % str(u.get("needs", "")),
					FONT_SIZE_XS, COLOR_DANGER))


## ============================================================================
## ALIEN ARTIFACTS (pp.135-136)
## ============================================================================

func _build_artifact_list(result_lines: Array = []) -> void:
	_clear_container(_artifact_list)
	_artifact_list.add_child(_line("ALIEN ARTIFACTS (pp.135-136)", FONT_SIZE_MD,
			COLOR_TEXT_PRIMARY))
	for line in result_lines:
		_artifact_list.add_child(_line(str(line), FONT_SIZE_SM, COLOR_SUCCESS))
	var found: Array = _campaign.artifacts_found if _campaign and "artifacts_found" in _campaign \
			else []
	if found.is_empty():
		_artifact_list.add_child(_line("None found yet. A Delve that finds its Artifact rolls "
				+ "on the Artifacts table (pp.133, 135).", FONT_SIZE_SM, COLOR_TEXT_SECONDARY))
	for a in found:
		if a is Dictionary:
			_artifact_list.add_child(_artifact_card(a))
	TouchScrollOpenerRef.open_subtree(self)


func _artifact_card(a: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var kind: String = str(a.get("type", ""))
	card.add_child(_line("%s (%s)" % [str(a.get("name", "?")),
			kind.replace("_", "-").capitalize()], FONT_SIZE_SM, COLOR_CYAN))
	card.add_child(_line(str(a.get("description", "")), FONT_SIZE_XS, COLOR_TEXT_SECONDARY))
	var aid: String = str(a.get("id", ""))
	match kind:
		"colony_item":
			card.add_child(_line("Part of the colony: in effect.", FONT_SIZE_XS, COLOR_SUCCESS))
		"single_use":
			if bool(a.get("used", false)):
				card.add_child(_line("Used.", FONT_SIZE_XS, COLOR_TEXT_SECONDARY))
			else:
				var target: String = CoreScript.artifact_target(a)
				var picker: OptionButton = null
				if target != "":
					var who: Array = _campaign.fallen_now() if target == "fallen" \
							else _campaign.roster
					if who.is_empty():
						card.add_child(_line("No character who died this campaign turn."
								if target == "fallen" else "No character on the roster.",
								FONT_SIZE_XS, COLOR_WARNING))
						return card
					picker = _character_picker(who)
					card.add_child(picker)
				var use := Button.new()
				use.text = "Activate"
				use.custom_minimum_size = Vector2(160, 48)
				use.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				use.pressed.connect(func() -> void:
					_build_artifact_list(_campaign.use_artifact(aid, _picked(picker))))
				card.add_child(use)
		"equipment":
			var carrier: String = str(a.get("carrier", ""))
			if bool(a.get("lost", false)):
				card.add_child(_line("Lost with its carrier.", FONT_SIZE_XS, COLOR_DANGER))
			elif carrier != "":
				var c: Variant = _campaign.get_roster_character_by_id(carrier)
				card.add_child(_line("Carried by %s." % (str(c.get("name", carrier))
						if c is Dictionary else carrier), FONT_SIZE_XS, COLOR_SUCCESS))
			elif not _campaign.roster.is_empty():
				var picker := _character_picker(_campaign.roster)
				card.add_child(picker)
				var give := Button.new()
				give.text = "Give (cannot be traded later)"
				give.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				give.custom_minimum_size = Vector2(160, 48)
				give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				give.pressed.connect(func() -> void:
					_build_artifact_list(_campaign.give_artifact(aid, _picked(picker))))
				card.add_child(give)
	return card


func _character_picker(characters: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 48
	picker.clip_text = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in characters:
		if c is Dictionary:
			picker.add_item(str(c.get("name", "?")))
			picker.set_item_metadata(picker.item_count - 1, str(c.get("id", "")))
	return picker


func _picked(picker: OptionButton) -> String:
	if picker == null or picker.item_count == 0 or picker.selected < 0:
		return ""
	return str(picker.get_item_metadata(picker.selected))


func _line(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _on_filter_pressed(filter: String) -> void:
	_current_filter = filter
	_clear_container(_weapon_list)
	_build_weapon_list()


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
