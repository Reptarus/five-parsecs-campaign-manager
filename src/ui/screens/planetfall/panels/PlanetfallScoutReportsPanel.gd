class_name PlanetfallScoutReportsPanel
extends Control

## Step 3: Scout Reports — Scout Explore action + Scout Discovery roll.
## Player selects a scout character and target sector, then resolves exploration.
## Source: Planetfall pp.59-60

signal phase_completed(result_data: Dictionary)

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _resolver: PlanetfallEventResolverScript
var _explore_done: bool = false
var _discovery_done: bool = false
var _result_data: Dictionary = {}

var _title_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _explore_btn: Button
var _discovery_btn: Button
var _continue_btn: Button
var _scout_select: OptionButton


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func refresh() -> void:
	_explore_done = false
	_discovery_done = false
	_result_data = {}
	_clear_container(_content_vbox)
	_clear_container(_result_container)

	if _title_label:
		_title_label.text = "STEP 3: SCOUT REPORTS"
	if _explore_btn:
		_explore_btn.visible = true
		_explore_btn.disabled = false
	if _discovery_btn:
		_discovery_btn.visible = true
		_discovery_btn.disabled = false
	if _continue_btn:
		_continue_btn.visible = false

	_build_scout_info()
	_populate_scout_select()


func complete() -> void:
	if not _explore_done:
		_on_explore_pressed()
	elif not _discovery_done:
		_on_discovery_pressed()
	else:
		_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "STEP 3: SCOUT REPORTS"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content_vbox)

	# Scout assignment
	var scout_row := HBoxContainer.new()
	scout_row.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(scout_row)

	var scout_lbl := Label.new()
	scout_lbl.text = "Assign Scout (optional):"
	scout_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	scout_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	scout_row.add_child(scout_lbl)

	_scout_select = OptionButton.new()
	_scout_select.custom_minimum_size.x = 200
	scout_row.add_child(_scout_select)

	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	# Action buttons
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(btn_box)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", SPACING_MD)
	btn_box.add_child(action_row)

	_explore_btn = Button.new()
	_explore_btn.text = "Scout Explore"
	_explore_btn.custom_minimum_size = Vector2(180, 48)
	_explore_btn.pressed.connect(_on_explore_pressed)
	action_row.add_child(_explore_btn)

	_discovery_btn = Button.new()
	_discovery_btn.text = "Scout Discovery (D100)"
	_discovery_btn.custom_minimum_size = Vector2(220, 48)
	_discovery_btn.pressed.connect(_on_discovery_pressed)
	action_row.add_child(_discovery_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue to Next Step"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	btn_box.add_child(_continue_btn)


## ============================================================================
## SCOUT INFO
## ============================================================================

func _build_scout_info() -> void:
	_add_info_text(
		"Each campaign turn, your scout teams explore the world.")
	_add_info_text(
		"[b]Scout Explore:[/b] Select an unexploited sector. Roll 2D6 twice (pick lowest each) for Resource and Hazard levels.")
	_add_info_text(
		"[b]Scout Discovery:[/b] Optional D100 roll on the Scout Discovery table.")
	_add_info_text(
		"[color=#808080]Assigning a scout character gives them bonus XP on certain results.[/color]")


func _populate_scout_select() -> void:
	_scout_select.clear()
	_scout_select.add_item("(No scout assigned)", 0)

	if not _campaign or not "roster" in _campaign:
		return

	var idx: int = 1
	for char_dict in _campaign.roster:
		if char_dict is not Dictionary:
			continue
		var char_class: String = char_dict.get("class", "")
		var char_name: String = char_dict.get("name", "Unknown")
		var cid: String = char_dict.get("id", "")
		# Check not in sick bay
		var in_sick_bay: bool = false
		if "sick_bay" in _campaign:
			in_sick_bay = _campaign.sick_bay.has(cid) and _campaign.sick_bay[cid] > 0
		if not in_sick_bay and char_class == "scout":
			_scout_select.add_item("%s (Scout)" % char_name, idx)
			_scout_select.set_item_metadata(idx, cid)
			idx += 1


## ============================================================================
## SCOUT EXPLORE
## ============================================================================

func _on_explore_pressed() -> void:
	_explore_btn.disabled = true
	_explore_done = true

	# Roll 2D6 twice, take lowest each time for Resource and Hazard
	var r1: int = _resolver.roll_d6()
	var r2: int = _resolver.roll_d6()
	var resource_level: int = mini(r1, r2)

	var h1: int = _resolver.roll_d6()
	var h2: int = _resolver.roll_d6()
	var hazard_level: int = mini(h1, h2)

	_add_result_bbcode("[b]Scout Explore Results:[/b]")
	_add_result_bbcode(
		"  Resource Level: 2D6 (%d, %d) → %d" % [r1, r2, resource_level])
	_add_result_bbcode(
		"  Hazard Level: 2D6 (%d, %d) → %d" % [h1, h2, hazard_level])

	# Check for Ancient Sign (double 4, 5, or 6)
	var ancient_sign: bool = false
	if r1 == r2 and r1 >= 4:
		ancient_sign = true
	elif h1 == h2 and h1 >= 4:
		ancient_sign = true

	if ancient_sign:
		_add_result_bbcode(
			"\n[color=#4FC3F7]Ancient Sign discovered in this sector![/color]")

	_add_result_bbcode(
		"\n[color=#10B981]Mark these values on your colony map for the explored sector.[/color]")

	_result_data["explore"] = {
		"resource_level": resource_level,
		"hazard_level": hazard_level,
		"ancient_sign": ancient_sign
	}

	_check_can_continue()


## ============================================================================
## SCOUT DISCOVERY
## ============================================================================

func _on_discovery_pressed() -> void:
	_discovery_btn.disabled = true
	_discovery_done = true

	var roll: int = _resolver.roll_d100()

	# Scout Discovery table (Planetfall p.59)
	var discovery: Dictionary = _resolve_scout_discovery(roll)
	var name: String = discovery.get("name", "Unknown")
	var desc: String = discovery.get("description", "")

	_add_result_bbcode("\n[b]Scout Discovery (D100: %d):[/b]" % roll)
	_add_result_bbcode("[b]%s[/b]" % name)
	_add_result_bbcode(desc)

	# Apply scout XP if assigned
	var scout_idx: int = _scout_select.get_selected_id()
	if scout_idx > 0:
		var scout_id: String = str(_scout_select.get_item_metadata(scout_idx))
		var xp_bonus: int = discovery.get("scout_xp", 0)
		if xp_bonus > 0:
			_apply_xp_to_character(scout_id, xp_bonus)
			var scout_name: String = _get_character_name(scout_id)
			_add_result_bbcode(
				"\n[color=#10B981]+%d XP for assigned scout %s[/color]" % [
					xp_bonus, scout_name])

	_result_data["discovery"] = discovery
	_check_can_continue()


func _resolve_scout_discovery(roll: int) -> Dictionary:
	## Inline Scout Discovery table (Planetfall p.59).
	## This table is small enough to inline rather than a separate JSON.
	if roll <= 10:
		return {"name": "Routine Trip", "description": "The scouts find nothing at all.", "scout_xp": 0}
	elif roll <= 20:
		return {"name": "Good Practice", "description": "The scouts find nothing, but it is a good opportunity to rehearse the basics. If a scout was assigned, they receive +2 XP.", "scout_xp": 2}
	elif roll <= 25:
		return {"name": "SOS Signal", "description": "The scouts report a distress signal. You may play a Rescue Mission this turn. If you do not, Colony Morale drops by -3.", "scout_xp": 0}
	elif roll <= 30:
		return {"name": "Scout Down!", "description": "The scout vehicle crashes. If you assigned a scout, they need rescue. You can opt to have them escape on foot (roll on injury table, +2 XP if survived) or play the Scout Down! mission.", "scout_xp": 2}
	elif roll <= 60:
		return {"name": "Exploration Report", "description": "Select any sector that has not yet been Explored and generate Resource and Hazard levels.", "scout_xp": 0}
	elif roll <= 70:
		return {"name": "Recon Patrol", "description": "If there are Tactical Enemies on the map, select one and add 1 Enemy Information. If no enemies present, no event.", "scout_xp": 0}
	elif roll <= 80:
		return {"name": "Ancient Sign", "description": "Randomly select a map sector, then mark that it has an Ancient Sign. Completing any mission in that sector awards the Ancient Sign.", "scout_xp": 0}
	else:
		return {"name": "Revised Survey", "description": "Randomly pick a map sector. If not Explored, generate values. If Explored but not Exploited, increase Resource +1. If already Exploited, generate new values — can Exploit again.", "scout_xp": 0}


## ============================================================================
## HELPERS
## ============================================================================

func _check_can_continue() -> void:
	if _explore_done:
		_continue_btn.visible = true
		_continue_btn.disabled = false


func _on_continue_pressed() -> void:
	_continue_btn.disabled = true
	phase_completed.emit(_result_data)


func _get_character_name(character_id: String) -> String:
	if not _campaign or not "roster" in _campaign:
		return character_id
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				return char_dict.get("name", character_id)
	return character_id


func _apply_xp_to_character(character_id: String, xp: int) -> void:
	if not _campaign or not "roster" in _campaign:
		return
	for char_dict in _campaign.roster:
		if char_dict is Dictionary:
			if char_dict.get("id", "") == character_id:
				char_dict["xp"] = char_dict.get("xp", 0) + xp
				break


func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
