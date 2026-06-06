extends FiveParsecsCampaignPanel

## Full-screen Galaxy Log — hex-grid visualization of every world the player
## has visited in this 5PFH campaign. Read-only history view, NOT a navigation
## interface.
##
## Mirrors the CompendiumScreen pattern (extends FiveParsecsCampaignPanel,
## skip super._ready, manual base init, code-built UI in _build_ui()).
## Anchor logic derives the starting world from the planet with the lowest
## discovered_on_turn — this works post Phase 0 audit fix B2 (starting world
## seeded with discovered_on_turn=0 during campaign finalization).

const GalaxyHexLayoutClass := preload("res://src/core/world/GalaxyHexLayout.gd")
const HexStarMapScript := preload("res://src/ui/components/galaxy_log/HexStarMap.gd")
const WorldDetailPopupScript := preload(
	"res://src/ui/components/galaxy_log/WorldDetailPopup.gd"
)

const CONFIG_PATH := "user://galaxy_log.cfg"
const CONFIG_SECTION := "view"
const CONFIG_KEY_SHOW_BREADCRUMB := "show_breadcrumb"

var _hex_map: Control
var _title_label: Label
var _count_label: Label
var _breadcrumb_toggle: CheckButton


func _ready() -> void:
	# Skip super._ready() panel structure — we build our own UI.
	_ensure_base_background()
	_setup_responsive_layout()
	_build_ui()
	_load_user_preferences()
	_refresh_from_planet_data_manager()


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.offset_left = UIColors.SPACING_XL
	outer.offset_right = -UIColors.SPACING_XL
	outer.offset_top = UIColors.SPACING_LG
	outer.offset_bottom = -UIColors.SPACING_LG
	add_child(outer)

	# Header row.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	outer.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = "Galaxy Log"
	_title_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.text = "0 worlds"
	_count_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	# No fixed min width — the title (expand-fill) absorbs slack. Forcing 220px
	# here pushed the count under the gear on a 375px portrait header; let it
	# size to its content ("25 worlds · turn 100") instead.
	_count_label.custom_minimum_size.x = 0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_count_label)
	# Reserve space for the global SettingsOverlay gear (top-right, ~56px wide
	# on a CanvasLayer above this screen). Without this spacer the count label
	# extends under the gear and gets visually clipped on the right.
	var gear_reserve := Control.new()
	gear_reserve.custom_minimum_size = Vector2(64, 0)
	header.add_child(gear_reserve)

	# Hex map — fills remaining vertical space.
	_hex_map = HexStarMapScript.new()
	_hex_map.size_flags_horizontal = SIZE_EXPAND_FILL
	_hex_map.size_flags_vertical = SIZE_EXPAND_FILL
	_hex_map.hex_selected.connect(_on_hex_selected)
	outer.add_child(_hex_map)

	# Legend / footer row with recenter + breadcrumb toggle. HFlowContainer (not
	# HBox) so the chips and controls WRAP onto a second line on a narrow portrait
	# header instead of clipping off the right edge. FlowContainer uses separate
	# h/v separation constants and ignores main-axis expand (so no right-spacer).
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", UIColors.SPACING_LG)
	legend.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
	outer.add_child(legend)

	legend.add_child(_make_legend_chip("Current", Color(0.18, 0.38, 0.58, 0.96)))
	legend.add_child(_make_legend_chip("Starting", Color(0.28, 0.18, 0.45, 0.94)))
	legend.add_child(_make_legend_chip("Danger 4+", Color(0.85, 0.35, 0.35, 0.95)))

	# Touch-friendly parity for the double-click / HOME "reset view" gesture —
	# neither is reachable on a phone or tablet.
	var recenter_btn := Button.new()
	recenter_btn.text = "Recenter"
	recenter_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(recenter_btn)
	recenter_btn.pressed.connect(_on_recenter_pressed)
	legend.add_child(recenter_btn)

	_breadcrumb_toggle = CheckButton.new()
	_breadcrumb_toggle.text = "Show travel path"
	_breadcrumb_toggle.button_pressed = true
	_breadcrumb_toggle.toggled.connect(_on_breadcrumb_toggled)
	legend.add_child(_breadcrumb_toggle)


func _make_legend_chip(label_text: String, swatch_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_XS)

	var swatch := ColorRect.new()
	swatch.color = swatch_color
	swatch.custom_minimum_size = Vector2(14, 14)
	row.add_child(swatch)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	row.add_child(lbl)

	return row


# ----------------------------------------------------------------------------
# Data flow
# ----------------------------------------------------------------------------

func _refresh_from_planet_data_manager() -> void:
	var pdm := get_node_or_null("/root/PlanetDataManager")
	if not pdm or not "visited_planets" in pdm:
		_title_label.text = "Galaxy Log"
		_count_label.text = "0 worlds"
		return

	# Collect all visited PlanetData objects + find the starting world via
	# min(discovered_on_turn). Post Phase 0 audit fix B2, the starting world is
	# seeded with discovered_on_turn=0 during CampaignFinalizationService.
	var planets: Array = []
	var planet_ids: Array = []
	var starting_id: String = ""
	var min_turn: int = 0x7fffffff  # Large initial sentinel.
	for pid in pdm.visited_planets.keys():
		var planet = pdm.visited_planets[pid]
		if not planet:
			continue
		planets.append(planet)
		planet_ids.append(str(pid))
		var discovered: int = int(planet.discovered_on_turn) if "discovered_on_turn" in planet else 0
		if discovered < min_turn:
			min_turn = discovered
			starting_id = str(pid)

	var current_id: String = str(pdm.current_planet_id) if "current_planet_id" in pdm else ""

	# Derive deterministic coords from (campaign_id, planet_id).
	var campaign_id: String = _resolve_campaign_id()
	var coords: Dictionary = GalaxyHexLayoutClass.assign_coords(
		campaign_id, planet_ids, starting_id
	)

	_hex_map.set_layout(planets, coords, current_id, starting_id)
	# Travel history drives the breadcrumb line.
	if "travel_history" in pdm and pdm.travel_history is Array:
		_hex_map.set_travel_history(pdm.travel_history)

	# Header stats.
	var campaign_name: String = _resolve_campaign_name()
	if not campaign_name.is_empty():
		_title_label.text = "Galaxy Log — %s" % campaign_name
	var turn_count: int = _resolve_turn_count()
	_count_label.text = "%d worlds · turn %d" % [planets.size(), turn_count]


func _resolve_campaign_id() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs and "current_campaign" in gs and gs.current_campaign:
		if "campaign_id" in gs.current_campaign:
			return str(gs.current_campaign.campaign_id)
		if gs.current_campaign.has_method("get_campaign_id"):
			return str(gs.current_campaign.get_campaign_id())
	return ""


func _resolve_campaign_name() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs and "current_campaign" in gs and gs.current_campaign:
		if "campaign_name" in gs.current_campaign:
			return str(gs.current_campaign.campaign_name)
	return ""


func _resolve_turn_count() -> int:
	var gs := get_node_or_null("/root/GameState")
	if gs and "current_campaign" in gs and gs.current_campaign:
		var camp = gs.current_campaign
		if "progress_data" in camp and camp.progress_data is Dictionary:
			return int(camp.progress_data.get("turns_played", 0))
	return 0


# ----------------------------------------------------------------------------
# Interaction
# ----------------------------------------------------------------------------

func _on_hex_selected(planet_id: String) -> void:
	var pdm := get_node_or_null("/root/PlanetDataManager")
	if not pdm or not "visited_planets" in pdm:
		return
	var planet = pdm.visited_planets.get(planet_id)
	if not planet:
		return
	WorldDetailPopupScript.show_for(self, planet)


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("go_back"):
		router.go_back()
	elif router and router.has_method("navigate_to"):
		router.navigate_to("campaign_dashboard")


func _on_breadcrumb_toggled(pressed: bool) -> void:
	if _hex_map and _hex_map.has_method("set_breadcrumb_visible"):
		_hex_map.set_breadcrumb_visible(pressed)
	_save_user_preferences()


func _on_recenter_pressed() -> void:
	if _hex_map and _hex_map.has_method("recenter"):
		_hex_map.recenter()


# ----------------------------------------------------------------------------
# Per-user preference persistence (not in campaign save; this is UI state)
# ----------------------------------------------------------------------------

func _load_user_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # No prior file, defaults apply.
	var show: bool = cfg.get_value(
		CONFIG_SECTION, CONFIG_KEY_SHOW_BREADCRUMB, true
	)
	if _breadcrumb_toggle:
		_breadcrumb_toggle.button_pressed = show
	if _hex_map and _hex_map.has_method("set_breadcrumb_visible"):
		_hex_map.set_breadcrumb_visible(show)


func _save_user_preferences() -> void:
	if not _breadcrumb_toggle:
		return
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # Best-effort merge with any future settings.
	cfg.set_value(
		CONFIG_SECTION,
		CONFIG_KEY_SHOW_BREADCRUMB,
		_breadcrumb_toggle.button_pressed,
	)
	cfg.save(CONFIG_PATH)
