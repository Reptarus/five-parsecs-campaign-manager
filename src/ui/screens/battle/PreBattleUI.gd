## PreBattleUI manages the pre-battle setup interface
# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control


## Dependencies
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
## Grid geometry SSOT (table sizes p.108) — preloaded per this file's
## stale-class_name-cache convention.
const BattlefieldGridClass = preload("res://src/core/battle/BattlefieldGrid.gd")
# KeywordLinker preload — bypasses the global class_name cache which can be
# stale until editor reopens (CLAUDE.md "Preload Pattern for UI Class
# References").
const KeywordLinker = preload("res://src/ui/components/tooltips/KeywordLinker.gd")
## DLCUpsellBanner preloaded by path (same stale-class_name-cache reason as above).
const DLCUpsellBanner = preload("res://src/ui/components/dlc/DLCUpsellBanner.gd")
## AdaptivePanelGroup preloaded by path — the 3 content panels collapse to a tab
## strip in portrait via this (master-detail). Same stale-class_name avoidance.
const AdaptivePanelGroupClass = preload("res://src/ui/components/base/AdaptivePanelGroup.gd")
## PortraitChrome preloaded by path (stale-class_name avoidance) — trims the root
## MarginContainer L/R margins in portrait to reclaim width on the 360dp floor.
const PortraitChromeClass = preload("res://src/ui/components/base/PortraitChrome.gd")

## Signals
signal crew_selected(crew: Array)
signal deployment_confirmed
signal preview_updated
signal back_pressed

## Tracking tier selection (moved here from TacticalBattleUI overlay)
## 0 = LOG_ONLY, 1 = ASSISTED, 2 = FULL_ORACLE
var selected_tier: int = 0

## Combat representation mode (Wave 3 per-battle picker) — orthogonal to the
## tracking tier. Sprint Roadmap "representation axis": HOW the battle is fought.
##   "play_on_table" = interactive full-minis companion (default)
##   "no_minis"      = interactive No-Minis abstract panel (Freelancer's Handbook DLC)
##   "auto_resolve"  = "play it out for me" — resolver + NarrativeScreen, no tabletop
var selected_representation_mode: String = "play_on_table"

## Tier radios, tracked so picking auto-resolve can grey them out (tracking level
## is moot when the app resolves the whole battle for you).
var _tier_radios: Array[CheckBox] = []

## AI letter codes → human-readable names (Core Rules p.99, EnemyAI.json).
## Used to decode the AI cell in the enemy stat table so testers don't need
## the rulebook open to know what "T" means.
const AI_TYPE_NAMES: Dictionary = {
	"A": "Aggressive",
	"C": "Cautious",
	"T": "Tactical",
	"D": "Defensive",
	"R": "Rampage",
	"B": "Beast",
	"G": "Guardian",
}

## Node references
# %-relative so they survive the LeftPanel/CenterPanel/RightPanel reparent into
# AdaptivePanelGroup (panel-internal structure is intact; only the parent moves).
@onready var mission_info_panel = %LeftPanel/MissionInfo/VBoxContainer/Content
@onready var enemy_info_panel = %LeftPanel/EnemyInfo/VBoxContainer/Content
@onready var battlefield_preview = %PreviewContent
@onready var crew_selection_panel = %RightPanel/CrewSelection/VBoxContainer/ScrollContainer/Content
@onready var confirm_button = %ConfirmButton
@onready var back_button = %BackButton

## State
var current_mission: StoryQuestData
var selected_crew: Array = []
var _max_deploy: int = 6  # Campaign crew size deployment limit (Core Rules p.63/85)
var _deploy_label: Label  # "Deploying X / Y max" display
var _keyword_tooltip: KeywordTooltip = null  # Lazy-instantiated for inline rules popovers
var _portrait_chrome: Node = null  # PortraitChrome margin-trim helper
var _panel_group: Control = null  # AdaptivePanelGroup holding the 4 panes
var _summary_label: Label = null  # Live "Mode · Tracking" choice summary

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

## Device-keyed touch-target height: 56 on the mobile bucket, 48 otherwise
## (ResponsiveManager.get_touch_target_size). Fallback 48 in editor/headless.
func _touch_target() -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_touch_target_size"):
		return rm.get_touch_target_size()
	return 48

func _ready() -> void:
	_apply_base_background()
	_connect_signals()
	confirm_button.disabled = true
	_setup_adaptive_panels()
	_setup_portrait_chrome()


## Reparent the 3 content panels (Mission / Battlefield / Crew) into an
## AdaptivePanelGroup so they sit side-by-side in landscape and collapse to a tab
## strip in portrait (master-detail). The FooterPanel (Confirm/Back) is a sibling
## of MainContent, so it stays put — always visible below the group. @onready vars
## above already cached their (now %-relative, reparent-proof) node references.
func _setup_adaptive_panels() -> void:
	var left: Control = get_node_or_null("%LeftPanel")
	var center: Control = get_node_or_null("%CenterPanel")
	var right: Control = get_node_or_null("%RightPanel")
	if not (left and center and right):
		return
	# Promote EnemyInfo (currently stacked under MissionInfo inside LeftPanel) to
	# its OWN "Forces" pane: the Mission pane becomes "what's happening + my two
	# choices", Forces becomes "who I'm fighting" — clearer read order on desktop,
	# and in portrait the enemy table gets its own tab instead of burying the
	# decisions. add_pane reparents it out of LeftPanel automatically; the
	# enemy_info_panel @onready ref already cached the inner Content node, so it
	# stays valid after the move.
	var enemy: Control = get_node_or_null("%LeftPanel/EnemyInfo")
	var main_content: Node = left.get_parent()          # the MainContent HBox
	var vbox: Node = main_content.get_parent() if main_content else null
	if not vbox:
		return
	var idx: int = main_content.get_index()
	var group := AdaptivePanelGroupClass.new()
	group.name = "AdaptiveContent"
	group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	# 4 panes but max 3 columns: on desktop the wide 8-col Forces table wraps to
	# its own full-width row 2 rather than cramming into a quarter-width column.
	group.max_columns = 3
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(group)
	vbox.move_child(group, idx)
	# add_pane reparents each panel out of MainContent into the group's grid.
	# Order = tab/focus index: Mission / Forces / Battlefield / Crew.
	group.add_pane(left, "Mission")
	if enemy:
		group.add_pane(enemy, "Forces")
	group.add_pane(center, "Battlefield")
	group.add_pane(right, "Crew")
	_panel_group = group
	main_content.queue_free()  # now empty; footer untouched

## Trim the root MarginContainer's L/R margins in portrait (reclaims ~32px on the
## 360dp floor) and restore them in landscape. PortraitChrome self-wires to
## ResponsiveManager.layout_class_changed; zero desktop/landscape impact.
func _setup_portrait_chrome() -> void:
	var mc := get_node_or_null("MarginContainer")
	if mc == null:
		return
	_portrait_chrome = PortraitChromeClass.new()
	add_child(_portrait_chrome)
	_portrait_chrome.setup(mc)

## Apply the Deep Space COLOR_BASE background behind this panel
func _apply_base_background() -> void:
	var bg := ColorRect.new()
	bg.name = "__phase_bg"
	bg.color = Color("#1A1A2E")  # COLOR_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)

## Lazy-instantiate the shared keyword tooltip used by inline rules popovers.
## Called only when a clickable keyword surface is built, so PreBattleUI without
## special_rules / weapon traits avoids the AcceptDialog allocation entirely.
func _ensure_keyword_tooltip() -> KeywordTooltip:
	if _keyword_tooltip == null:
		_keyword_tooltip = KeywordTooltip.new()
		add_child(_keyword_tooltip)
	return _keyword_tooltip

## Connect UI signals
func _connect_signals() -> void:
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_pressed.emit()

## Accept deployment condition data and display in mission panel
func set_deployment_condition(condition: Dictionary) -> void:
	if not condition or condition.is_empty():
		return
	if not mission_info_panel:
		return

	var separator := HSeparator.new()
	mission_info_panel.add_child(separator)

	var header := Label.new()
	header.text = "Deployment Condition"
	header.add_theme_font_size_override("font_size", _scaled_font(16))
	mission_info_panel.add_child(header)

	var title := Label.new()
	title.text = condition.get("title", "Unknown")
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	title.add_theme_color_override(
		"font_color", Color("#D97706"))
	mission_info_panel.add_child(title)

	# Show canonical rule text from Core Rules p.88
	var desc := Label.new()
	desc.text = condition.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", _scaled_font(14))
	mission_info_panel.add_child(desc)

## Setup the UI with mission data
func setup_preview(data: Dictionary) -> void:
	if not data:
		push_error("PreBattleUI: Invalid preview data")
		return

	_setup_mission_info(data)
	_setup_enemy_info(data)
	_setup_battlefield_preview(data)
	preview_updated.emit()

## Setup mission information
func _setup_mission_info(data: Dictionary) -> void:
	if not mission_info_panel:
		return

	var mission_title := Label.new()
	mission_title.text = data.get("title", "Unknown Mission")

	var mission_desc := Label.new()
	mission_desc.text = data.get("description", "No description available")

	var battle_type := Label.new()
	battle_type.text = "Battle Type: " + GlobalEnums.BattleType.keys()[data.get("battle_type", 0)]

	mission_info_panel.add_child(mission_title)
	mission_info_panel.add_child(mission_desc)
	mission_info_panel.add_child(battle_type)

	# Initiative context summary (pre-computed by CampaignTurnController)
	var init_ctx: Dictionary = data.get("initiative_context", {})
	if not init_ctx.is_empty():
		var sep := HSeparator.new()
		mission_info_panel.add_child(sep)
		var init_header := Label.new()
		init_header.text = "Seize the Initiative"
		init_header.add_theme_font_size_override("font_size", _scaled_font(16))
		mission_info_panel.add_child(init_header)
		var init_info := Label.new()
		var prob: float = init_ctx.get("success_probability", 0.0)
		init_info.text = "Need %d+ on 2D6 (Savvy +%d) — %.0f%% chance" % [
			init_ctx.get("required_roll", 10),
			init_ctx.get("highest_savvy", 0),
			prob * 100.0]
		init_info.add_theme_font_size_override("font_size", _scaled_font(14))
		init_info.add_theme_color_override("font_color", Color("#4FC3F7"))
		init_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_info_panel.add_child(init_info)

	# ── Battle Setup ── the two coupled decisions (how to fight / how much to
	# track), grouped into distinct cards under one header so they read as choices
	# and don't get buried under the mission text. Combat Mode comes first because
	# it decides whether the app tracks at all (auto-resolve needs no tracking).
	var setup_sep := HSeparator.new()
	mission_info_panel.add_child(setup_sep)
	var setup_header := Label.new()
	setup_header.text = "Battle Setup"
	setup_header.add_theme_font_size_override("font_size", _scaled_font(18))
	mission_info_panel.add_child(setup_header)
	# Live glanceable summary of the current two choices (updated on each pick).
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_summary_label.add_theme_color_override("font_color", Color("#4FC3F7"))
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_info_panel.add_child(_summary_label)
	_build_representation_selector()
	_build_tier_selector()
	_update_choice_summary()

## Setup enemy information — Core Rules table format (pp.91-94)
func _setup_enemy_info(data: Dictionary) -> void:
	if not enemy_info_panel:
		return

	var enemy_force: Dictionary = data.get("enemy_force", {})
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# ── Table header: "Enemy Forces" ──
	var title := Label.new()
	title.text = "Enemy Forces"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	container.add_child(title)

	# ── Stat table (GridContainer, 8 columns) ──
	var table_panel := PanelContainer.new()
	var table_style := StyleBoxFlat.new()
	table_style.bg_color = Color("#252542")  # COLOR_ELEVATED
	table_style.border_color = Color("#3A3A5C")  # COLOR_BORDER
	table_style.set_border_width_all(1)
	table_style.set_corner_radius_all(4)
	table_style.set_content_margin_all(4)
	table_panel.add_theme_stylebox_override("panel", table_style)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header row
	var headers := ["ENEMY", "NUMBERS", "PANIC", "SPEED",
		"CMB", "TGH", "AI", "WEAPONS"]
	for h in headers:
		var lbl := Label.new()
		lbl.text = h
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(10))
		lbl.add_theme_color_override("font_color", Color("#808080"))
		grid.add_child(lbl)

	# Data row
	var type_name: String = enemy_force.get("type", "")
	if type_name.is_empty():
		type_name = data.get("enemy_type",
			data.get("enemy_faction", "Unknown"))

	var spd: int = enemy_force.get("speed", 0)
	var cmb: int = enemy_force.get("combat_skill", 0)
	var tgh: int = enemy_force.get("toughness", 0)
	var numbers_str: String = str(enemy_force.get("numbers", ""))
	var panic_str: String = str(enemy_force.get("panic", ""))
	var ai_raw: String = str(enemy_force.get("ai", ""))
	# Decode AI letter to letter+name (e.g. "T → Tactical") for readability.
	# Falls back to raw letter if unrecognized.
	var ai_str: String = ai_raw
	if AI_TYPE_NAMES.has(ai_raw):
		ai_str = "%s (%s)" % [ai_raw, AI_TYPE_NAMES[ai_raw]]
	var weapons_val = enemy_force.get("weapons", "")
	var weapons_str: String = ""
	if weapons_val is Array:
		weapons_str = ", ".join(
			weapons_val.map(func(w): return str(w)))
	else:
		weapons_str = str(weapons_val)

	var cmb_str := "+%d" % cmb if cmb >= 0 else str(cmb)
	var values := [type_name, numbers_str, panic_str,
		'%d"' % spd, cmb_str, str(tgh), ai_str, weapons_str]

	for i in range(values.size()):
		var raw_value: String = str(values[i])
		# Col 7 = weapons. Wrap recognized trait/weapon keywords as clickable
		# popovers (Pistol, Heavy, etc. are all in KeywordDB).
		if i == 7 and not raw_value.is_empty():
			var weapons_rtl := RichTextLabel.new()
			weapons_rtl.bbcode_enabled = true
			weapons_rtl.fit_content = true
			weapons_rtl.scroll_active = false
			weapons_rtl.text = KeywordLinker.wrap_known_keywords(raw_value)
			weapons_rtl.add_theme_font_size_override(
				"normal_font_size", _scaled_font(13))
			weapons_rtl.add_theme_color_override(
				"default_color", Color("#4FC3F7"))
			KeywordLinker.attach(weapons_rtl, _ensure_keyword_tooltip())
			grid.add_child(weapons_rtl)
			continue

		var lbl := Label.new()
		lbl.text = raw_value
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		if i == 0:
			# Enemy name in red
			lbl.add_theme_color_override(
				"font_color", Color("#DC2626"))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			lbl.add_theme_color_override(
				"font_color", Color("#4FC3F7"))
		grid.add_child(lbl)

	# Horizontal-scroll wrapper (Godot 4.6 ScrollContainer): the 8-col table
	# exceeds a ~321px portrait pane. h=AUTO / v=DISABLED means the grid keeps
	# its full min width on the scroll axis and SWIPES in portrait; in landscape
	# the grid min < pane width so — because the grid still has SIZE_EXPAND_FILL —
	# the ScrollContainer stretches it to fill and shows NO scrollbar
	# (pixel-identical to before). Pattern mirrors CompendiumCategoryView.
	var table_scroll := ScrollContainer.new()
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	table_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(grid)
	table_panel.add_child(table_scroll)
	container.add_child(table_panel)

	# ── Count ──
	var total: int = enemy_force.get("count",
		data.get("enemy_count", 0))
	if total > 0:
		var count_lbl := Label.new()
		count_lbl.text = "Count: %d" % total
		count_lbl.add_theme_font_size_override("font_size", _scaled_font(13))
		container.add_child(count_lbl)

	# ── Category rules (Core Rules pp.95-96) ──
	# Surfaces the parent enemy-category's rules block (Criminal Elements,
	# Hired Muscle, Interested Parties, Roving Threats). Players need this to
	# understand category-wide modifiers like "Hired Muscle: -1 to Seize the
	# Initiative" before they decide on tier.
	var category_name: String = str(enemy_force.get("category_name", ""))
	var category_rules: String = str(enemy_force.get("category_rules", ""))
	var seize_init_mod: int = int(enemy_force.get("seize_initiative_modifier", 0))
	if not category_name.is_empty() or not category_rules.is_empty():
		var cat_header := Label.new()
		var header_text: String = "Category: %s" % category_name if not category_name.is_empty() else "Category"
		if seize_init_mod != 0:
			header_text += "  (Seize Init %+d)" % seize_init_mod
		cat_header.text = header_text
		cat_header.add_theme_font_size_override("font_size", _scaled_font(12))
		cat_header.add_theme_color_override("font_color", Color("#10B981"))  # COLOR_SUCCESS
		container.add_child(cat_header)

		if not category_rules.is_empty():
			var cat_rules_rtl := RichTextLabel.new()
			cat_rules_rtl.bbcode_enabled = true
			cat_rules_rtl.fit_content = true
			cat_rules_rtl.scroll_active = false
			cat_rules_rtl.text = KeywordLinker.wrap_known_keywords(category_rules)
			cat_rules_rtl.add_theme_font_size_override(
				"normal_font_size", _scaled_font(11))
			cat_rules_rtl.add_theme_color_override(
				"default_color", Color("#808080"))  # COLOR_TEXT_SECONDARY
			cat_rules_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			KeywordLinker.attach(cat_rules_rtl, _ensure_keyword_tooltip())
			container.add_child(cat_rules_rtl)

	# ── Special rules ──
	# RichTextLabels with KeywordLinker so terms like "Heavy", "Area", "Stun" pop
	# the rules tooltip on click (Core Rules trait names live in KeywordDB).
	var rules: Array = enemy_force.get("special_rules", [])
	for rule in rules:
		var rule_rtl := RichTextLabel.new()
		rule_rtl.bbcode_enabled = true
		rule_rtl.fit_content = true
		rule_rtl.scroll_active = false
		rule_rtl.text = KeywordLinker.wrap_known_keywords(str(rule))
		rule_rtl.add_theme_font_size_override(
			"normal_font_size", _scaled_font(12))
		rule_rtl.add_theme_color_override(
			"default_color", Color("#D97706"))
		rule_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		KeywordLinker.attach(rule_rtl, _ensure_keyword_tooltip())
		container.add_child(rule_rtl)

	enemy_info_panel.add_child(container)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
	if not battlefield_preview:
		return

	# Gather terrain data from preview data or GameState. The stored
	# active_battlefield contract is FLAT (sectors at top level), so
	# bf_data.get("terrain", bf_data) resolves to the contract itself.
	var terrain_data: Dictionary = data.get("terrain", {})
	if terrain_data.is_empty():
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("get_battlefield_data"):
			var bf_data: Dictionary = game_state.get_battlefield_data()
			terrain_data = bf_data.get("terrain", bf_data)

	if terrain_data.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Terrain suggestions not available.\nSet up terrain on your physical table as desired."
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		placeholder.add_theme_color_override("font_color", Color("#9ca3af"))
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		battlefield_preview.add_child(placeholder)
		return

	# Prefer the display name; fall back to the theme key
	var theme_name: String = terrain_data.get("theme_name",
		terrain_data.get("theme", ""))

	# Try to extract sector data for the visual map view
	var sector_array: Array = _extract_sector_array(terrain_data)
	if not sector_array.is_empty():
		# Stack: table-size override row above the map (PreviewContent is a
		# bare anchoring Control, so stacking needs a VBox)
		var preview_vbox := VBoxContainer.new()
		preview_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview_vbox.add_theme_constant_override("separation", 4)
		battlefield_preview.add_child(preview_vbox)

		var table_ft: float = float(terrain_data.get("table_size_ft", 3.0))
		preview_vbox.add_child(_build_table_size_override(table_ft))

		# Use BattlefieldMapView for visual overhead grid
		var map_view := BattlefieldMapView.new()
		map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Size the grid to the persisted table size (Core Rules p.108)
		if map_view.has_method("configure_grid"):
			map_view.configure_grid(BattlefieldGridClass.dims_for_table(table_ft))
		var world_traits: Array = terrain_data.get("world_traits", [])
		map_view.populate_from_sectors(sector_array, theme_name, world_traits)
		# Show the persisted objective markers on the preview too
		var stored_obj: Variant = terrain_data.get("objective_positions", [])
		if stored_obj is Array and not stored_obj.is_empty() \
				and map_view.has_method("set_objective_positions"):
			var rehydrated: Array = []
			for obj in stored_obj:
				if obj is Dictionary:
					var o: Dictionary = obj.duplicate()
					o["grid_pos"] = BattlefieldGridClass.json_to_grid_pos(
						o.get("grid_pos"))
					rehydrated.append(o)
			map_view.set_objective_positions(rehydrated)
		preview_vbox.add_child(map_view)

		# Store terrain data for passthrough to post-battle
		_store_terrain_for_passthrough(sector_array, theme_name)
		return

	# Fallback: render terrain suggestions as text
	_setup_text_terrain_fallback(terrain_data, theme_name)

## Extract sector data into the Array format BattlefieldMapView expects.
## Handles the generator/contract Array format, dict-keyed sectors, and
## pre-formatted sector arrays.
func _extract_sector_array(terrain_data: Dictionary) -> Array:
	# Format A: sectors as Array of {label, features} — the shape both the
	# generator and the persisted active_battlefield contract emit.
	# (Pre-2026-07-02 this format was NOT handled, so the visual preview
	# could never render generator output.)
	var sectors: Variant = terrain_data.get("sectors",
		terrain_data.get("sector_list", []))
	if sectors is Array and not sectors.is_empty():
		return sectors

	# Format B: sectors as Dictionary {label: features_or_description}
	if sectors is Dictionary and not sectors.is_empty():
		var result: Array = []
		for sector_key: String in sectors:
			var sector_info = sectors[sector_key]
			var features: Array = []
			if sector_info is Array:
				features = sector_info
			elif sector_info is String:
				# Single description string — split on comma or use as-is
				if ", " in sector_info:
					features = sector_info.split(", ")
				else:
					features = [sector_info]
			elif sector_info is Dictionary:
				features = sector_info.get("features", [])
			result.append({"label": sector_key, "features": features})
		return result

	return []

## Per-battle table-size override row (Core Rules p.108). Changing it does
## NOT re-roll terrain dice (the 5-step process is size-independent,
## Compendium p.94) — it re-derives grid geometry + marker positions from
## the SAME seeds and persists the choice.
func _build_table_size_override(current_ft: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Table:"
	lbl.add_theme_font_size_override("font_size", _scaled_font(12))
	lbl.add_theme_color_override("font_color", Color("#E0E0E0"))
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.add_item("2x2 ft", 20)
	opt.add_item("2.5x2.5 ft", 25)
	opt.add_item("3x3 ft", 30)
	var cur_id: int = int(roundf(current_ft * 10.0))
	for i in range(opt.item_count):
		if opt.get_item_id(i) == cur_id:
			opt.select(i)
			break
	opt.custom_minimum_size = Vector2(140, _touch_target())
	opt.accessibility_name = "Battle table size override"
	opt.item_selected.connect(func(idx: int) -> void:
		_on_table_size_override(opt.get_item_id(idx) / 10.0))
	row.add_child(opt)
	var hint := Label.new()
	hint.text = "(p.108 — dice unchanged)"
	hint.add_theme_font_size_override("font_size", _scaled_font(11))
	hint.add_theme_color_override("font_color", Color("#808080"))
	row.add_child(hint)
	return row

## Re-derive grid geometry + marker positions for the new size and persist.
func _on_table_size_override(new_ft: float) -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("get_battlefield_data"):
		return
	var contract: Dictionary = gs.get_battlefield_data()
	if contract.get("sectors", []) is Array \
			and contract.get("sectors", []).is_empty():
		return
	contract["table_size_ft"] = new_ft
	var dims: Dictionary = BattlefieldGridClass.dims_for_table(new_ft)

	# Objective + enemy markers derive from grid dims — recompute
	# deterministically from the SAME seeds (terrain dice untouched).
	var GenClass = load("res://src/core/battle/BattlefieldGenerator.gd")
	var gen = GenClass.new()
	var base_seed: int = int(contract.get("seed", 0))
	var obj_rng := RandomNumberGenerator.new()
	obj_rng.seed = hash("%d|objectives" % base_seed)
	var runtime_obj: Array = gen.compute_objective_positions(
		str(contract.get("mission_objective", "")),
		contract.get("sectors", []), obj_rng, dims)
	runtime_obj = GenClass.append_notable_sight_marker(
		runtime_obj, contract.get("notable_sight", {}), dims)
	var obj_json: Array = []
	for obj in runtime_obj:
		var oj: Dictionary = obj.duplicate()
		oj["grid_pos"] = BattlefieldGridClass.grid_pos_to_json(
			oj.get("grid_pos", Vector2.ZERO))
		obj_json.append(oj)
	contract["objective_positions"] = obj_json
	var marker_rng := RandomNumberGenerator.new()
	marker_rng.seed = hash("%d|enemy_markers" % base_seed)
	contract["enemy_markers"] = GenClass.compute_enemy_deploy_markers(
		str(contract.get("enemy_ai", "")),
		int(contract.get("enemy_count", 0)), marker_rng, dims)
	gs.set_battlefield_data(contract)

	# Rebuild the preview with the new geometry (re-reads from GameState)
	for child in battlefield_preview.get_children():
		child.queue_free()
	_setup_battlefield_preview({})

## Store terrain data in GameStateManager temp-data for post-battle passthrough.
## Consumed by PostBattleSummarySheet._setup_battlefield_recap on the next screen.
## (Pre-Sprint-2 this targeted GameState.temp_data, which does not exist — dead code.
## Retargeted to GameStateManager during Sprint 2 F1.)
func _store_terrain_for_passthrough(sectors: Array, theme_name: String) -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("set_temp_data"):
		return
	gsm.set_temp_data("battlefield_terrain", {
		"sectors": sectors,
		"theme_name": theme_name
	})

## Text fallback for terrain data without structured sectors
func _setup_text_terrain_fallback(terrain_data: Dictionary, theme_name: String) -> void:
	var terrain_log := RichTextLabel.new()
	terrain_log.bbcode_enabled = true
	terrain_log.fit_content = true
	terrain_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	terrain_log.add_theme_color_override("default_color", Color("#f3f4f6"))
	terrain_log.add_theme_font_size_override("normal_font_size", _scaled_font(14))

	var bbcode: String = "[b]Terrain Setup Guide[/b]\n\n"
	if theme_name != "":
		bbcode += "[color=#f59e0b]Theme:[/color] %s\n\n" % theme_name

	if terrain_data.has("suggestions"):
		var suggestions: Array = terrain_data.get("suggestions", [])
		for suggestion in suggestions:
			bbcode += "- %s\n" % str(suggestion)
	elif terrain_data.has("description"):
		bbcode += str(terrain_data["description"])

	terrain_log.text = bbcode
	battlefield_preview.add_child(terrain_log)

## Setup crew selection — accepts both Character objects and Dictionaries
## max_deploy: deployment cap from campaign crew size setting (Core Rules p.63/85)
func setup_crew_selection(
	available_crew: Array, max_deploy: int = 6
) -> void:
	if not crew_selection_panel:
		return
	_max_deploy = max_deploy

	var crew_list := VBoxContainer.new()

	# Deployment counter label
	_deploy_label = Label.new()
	_deploy_label.add_theme_font_size_override("font_size", 14)
	_deploy_label.add_theme_color_override(
		"font_color", Color("#4FC3F7"))
	crew_list.add_child(_deploy_label)

	for item in available_crew:
		var char_button := Button.new()
		if item is Character:
			char_button.text = item.name
		elif item is Dictionary:
			char_button.text = item.get(
				"name", item.get("character_name", "Unknown"))
		else:
			char_button.text = str(item)
		char_button.toggle_mode = true
		# Touch target + long-name wrap: wrap within the (expanding) button so a
		# long crew name never widens the column / clips in the narrow Crew tab.
		char_button.custom_minimum_size.y = _touch_target()
		char_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Style the pressed/selected state
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color("#2D5A7B")
		pressed_style.border_color = Color("#4FC3F7")
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(8)
		char_button.add_theme_stylebox_override("pressed", pressed_style)
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color("#1E1E36")
		normal_style.border_color = Color("#3A3A5C")
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(8)
		char_button.pressed.connect(
			_on_character_selected.bind(item, char_button))
		crew_list.add_child(char_button)
		# Pre-select up to max_deploy crew members
		if selected_crew.size() < _max_deploy:
			char_button.button_pressed = true
			selected_crew.append(item)

	crew_selection_panel.add_child(crew_list)
	_update_deploy_label()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

## Handle character selection with deployment limit enforcement
func _on_character_selected(character, button: Button = null) -> void:
	if selected_crew.has(character):
		selected_crew.erase(character)
	else:
		# Enforce deployment cap (Core Rules p.63/85)
		if selected_crew.size() >= _max_deploy:
			# Revert toggle — at deployment limit
			if button:
				button.button_pressed = false
			return
		selected_crew.append(character)

	_update_deploy_label()
	crew_selected.emit(selected_crew)
	_update_confirm_button()

func _update_deploy_label() -> void:
	if not _deploy_label:
		return
	_deploy_label.text = "Deploying %d / %d max" % [
		selected_crew.size(), _max_deploy]
	# Red at empty (can't confirm), amber at the cap (no room left), cyan between.
	var col := Color("#4FC3F7")
	if selected_crew.is_empty():
		col = Color("#DC2626")
	elif selected_crew.size() >= _max_deploy:
		col = Color("#D97706")
	_deploy_label.add_theme_color_override("font_color", col)

## Handle confirm button press
func _on_confirm_pressed() -> void:
	deployment_confirmed.emit()

## Update confirm button state
func _update_confirm_button() -> void:
	if not confirm_button:
		return

	# Require crew selection (terrain always renders — map or text fallback)
	confirm_button.disabled = selected_crew.is_empty()
	# Tell the player WHY Confirm is disabled (the common case is no crew picked).
	confirm_button.tooltip_text = "Select at least one crew member to deploy" \
		if selected_crew.is_empty() else ""

## Build a styled "decision card" (PanelContainer + inner VBox) appended to the
## Mission pane, returning the inner VBox for the caller to fill. Bounds each
## battle-setup choice so it reads as a distinct, self-contained decision.
func _make_decision_card(title_text: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1E1E36")      # COLOR_INPUT
	style.border_color = Color("#3A3A5C")  # COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", _scaled_font(16))
	vb.add_child(title)
	mission_info_panel.add_child(card)
	return vb

## Build the tracking tier radio buttons (LOG_ONLY / ASSISTED / FULL_ORACLE)
func _build_tier_selector() -> void:
	if not mission_info_panel:
		return

	var card := _make_decision_card("Tracking Level")

	var desc := Label.new()
	desc.text = "How much should the app track for you?"
	desc.add_theme_font_size_override("font_size", _scaled_font(12))
	desc.add_theme_color_override("font_color", Color("#808080"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)

	var tier_names: Array[String] = [
		"Log Only — manual play, dice journal",
		"Assisted — auto-roll + guidance overlays",
		"Full Oracle — AI runs enemy turns",
	]
	var button_group := ButtonGroup.new()
	_tier_radios.clear()
	for i in range(tier_names.size()):
		var radio := CheckBox.new()
		radio.text = tier_names[i]
		radio.button_group = button_group
		radio.add_theme_font_size_override("font_size", _scaled_font(14))
		radio.custom_minimum_size.y = _touch_target()  # Touch-friendly
		radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long labels wrap at 360dp
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			radio.button_pressed = true  # Default to LOG_ONLY
		radio.pressed.connect(_on_tier_radio_pressed.bind(i))
		_tier_radios.append(radio)
		card.add_child(radio)

func _on_tier_radio_pressed(tier: int) -> void:
	selected_tier = tier
	_update_choice_summary()

## Live "Mode · Tracking" summary so the current two choices are glanceable
## without scrolling the cards. Auto-resolve reads differently (no tracking).
func _update_choice_summary() -> void:
	if not _summary_label:
		return
	var mode_names := {
		"play_on_table": "Play on table",
		"no_minis": "No-minis",
		"auto_resolve": "Auto-resolve",
	}
	var tier_names := ["Log Only", "Assisted", "Full Oracle"]
	var mode_txt: String = mode_names.get(
		selected_representation_mode, selected_representation_mode)
	if selected_representation_mode == "auto_resolve":
		_summary_label.text = "Mode: %s — the app resolves the whole battle" % mode_txt
	else:
		var tier_txt: String = tier_names[selected_tier] \
			if selected_tier >= 0 and selected_tier < tier_names.size() else "?"
		_summary_label.text = "Mode: %s · Tracking: %s" % [mode_txt, tier_txt]

## Build the per-battle combat representation picker (Wave 3, Sprint Roadmap
## "representation axis"). Three options; No-Minis is gated on Freelancer's
## Handbook DLC OWNERSHIP (not the global toggle — this picker IS the per-battle
## toggle). Auto-resolve is a base feature (the "digital version" value prop) and
## is never gated. Writes selected_representation_mode, read by
## CampaignTurnController._on_deployment_confirmed().
func _build_representation_selector() -> void:
	if not mission_info_panel:
		return

	var card := _make_decision_card("Combat Mode")

	var desc := Label.new()
	desc.text = "How do you want to fight this battle?"
	desc.add_theme_font_size_override("font_size", _scaled_font(12))
	desc.add_theme_color_override("font_color", Color("#808080"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)

	# DLC OWNERSHIP gate (is_feature_available ignores the global toggle — the
	# picker itself is the per-battle toggle). Null-safe for editor/headless.
	var dlc := get_node_or_null("/root/DLCManager")
	var no_minis_owned: bool = false
	if dlc and dlc.has_method("is_feature_available"):
		no_minis_owned = dlc.is_feature_available(dlc.ContentFlag.NO_MINIS_COMBAT)

	# Each row: [mode_id, label, enabled, locked_flag_name_for_upsell]
	var options: Array = [
		["play_on_table",
			"Play on my table — track my physical game", true, ""],
		["no_minis",
			"No-minis abstract — resolve by zones, no miniatures",
			no_minis_owned, "NO_MINIS_COMBAT"],
		["auto_resolve",
			"Play it out for me — auto-resolve as a story", true, ""],
	]

	var group := ButtonGroup.new()
	for opt in options:
		var mode_id: String = opt[0]
		var enabled: bool = opt[2]
		var locked_flag: String = opt[3]

		var radio := CheckBox.new()
		radio.text = opt[1]
		radio.button_group = group
		radio.add_theme_font_size_override("font_size", _scaled_font(14))
		radio.custom_minimum_size.y = _touch_target()  # Touch-friendly
		radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radio.disabled = not enabled
		if mode_id == selected_representation_mode and enabled:
			radio.button_pressed = true
		radio.pressed.connect(_on_representation_radio_pressed.bind(mode_id))
		card.add_child(radio)

		# Locked option → subtle, non-aggressive contextual upsell beneath it.
		if not enabled and not locked_flag.is_empty():
			var banner := DLCUpsellBanner.create_for_flag(locked_flag)
			card.add_child(banner)

func _on_representation_radio_pressed(mode: String) -> void:
	selected_representation_mode = mode
	# Tracking level is meaningless when the app resolves the whole battle.
	var is_auto: bool = (mode == "auto_resolve")
	for r in _tier_radios:
		if is_instance_valid(r):
			r.disabled = is_auto
	_update_choice_summary()

## Get selected crew
func get_selected_crew() -> Array:
	return selected_crew

## Cleanup
func cleanup() -> void:
	selected_crew.clear()
	current_mission = null

	# Clear UI panels
	for child in mission_info_panel.get_children():
		child.queue_free()
	for child in enemy_info_panel.get_children():
		child.queue_free()
	for child in battlefield_preview.get_children():
		child.queue_free()
	for child in crew_selection_panel.get_children():
		child.queue_free()
