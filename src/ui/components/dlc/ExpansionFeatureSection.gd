extends VBoxContainer

## Grouped DLC feature toggles — reusable in campaign creation,
## settings, and read-only summary views.
## Three modes: "campaign_creation", "settings", "read_only".

signal feature_toggled(flag: int, enabled: bool)
signal upsell_requested(dlc_id: String)
signal flags_changed(enabled_flags: Dictionary)

const DLCContentCatalogRef = preload(
	"res://src/ui/screens/store/DLCContentCatalog.gd")
const DLCFeatureToggleRowScript = preload(
	"res://src/ui/components/dlc/DLCFeatureToggleRow.gd")

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_RED := UIColors.COLOR_RED
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

# No-Minis Combat incompatibilities (Compendium p.66)
const NO_MINIS_INCOMPATIBLE: Array[String] = [
	"ESCALATING_BATTLES",
	"AI_VARIATIONS",
	"DEPLOYMENT_VARIABLES",
]

var _mode: String = "campaign_creation"
var _dlc_mgr: Node = null
var _toggle_rows: Dictionary = {}  # flag_name -> ToggleRow
var _pack_containers: Dictionary = {}  # dlc_id -> VBoxContainer
var _acknowledged_packs: Dictionary = {}  # dlc_id -> bool
var _pending_toggle: Dictionary = {}  # temp storage during disclaimer

func setup(mode: String = "campaign_creation") -> void:
	_mode = mode
	_dlc_mgr = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	add_theme_constant_override("separation", SPACING_LG)
	_build_ui()

func refresh() -> void:
	## Re-read toggle state from DLCManager
	if not _dlc_mgr:
		return
	for flag_name: String in _toggle_rows:
		var row: Variant = _toggle_rows[flag_name]
		var flag_val: int = _dlc_mgr.ContentFlag.get(
			flag_name, -1)
		if flag_val >= 0 and row.has_method("set_enabled"):
			row.set_enabled(
				_dlc_mgr.is_feature_enabled(flag_val))

func _build_ui() -> void:
	var pack_ids: Array[String] = [
		"trailblazers_toolkit",
		"freelancers_handbook",
		"fixers_guidebook",
	]
	for dlc_id: String in pack_ids:
		var is_owned: bool = false
		if _dlc_mgr and _dlc_mgr.has_method("has_dlc"):
			is_owned = _dlc_mgr.has_dlc(dlc_id)
		# In settings mode, skip unowned packs
		if _mode == "settings" and not is_owned:
			continue
		_build_pack_section(dlc_id, is_owned)

func _build_pack_section(
	dlc_id: String, is_owned: bool,
) -> void:
	var catalog: Dictionary = (
		DLCContentCatalogRef.get_pack_catalog(dlc_id))
	if catalog.is_empty():
		return

	# Pack card
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	card.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = catalog.get("name", dlc_id)
	name_lbl.add_theme_font_size_override(
		"font_size", FONT_SIZE_LG)
	name_lbl.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	# Owned/locked badge
	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	if is_owned:
		badge.text = "Owned"
		badge.add_theme_color_override(
			"font_color", COLOR_EMERALD)
	else:
		badge.text = "Not Owned"
		badge.add_theme_color_override(
			"font_color", COLOR_TEXT_MUTED)
	header.add_child(badge)

	# Bulk actions (owned + not read_only)
	if is_owned and _mode != "read_only":
		var bulk := HBoxContainer.new()
		bulk.add_theme_constant_override(
			"separation", SPACING_SM)
		vbox.add_child(bulk)

		var enable_btn := Button.new()
		enable_btn.text = "Enable All"
		enable_btn.custom_minimum_size = Vector2(80, 32)
		enable_btn.pressed.connect(
			_on_enable_all.bind(dlc_id))
		bulk.add_child(enable_btn)

		var disable_btn := Button.new()
		disable_btn.text = "Disable All"
		disable_btn.custom_minimum_size = Vector2(80, 32)
		disable_btn.pressed.connect(
			_on_disable_all.bind(dlc_id))
		bulk.add_child(disable_btn)

	# Feature rows
	var features_vbox := VBoxContainer.new()
	features_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(features_vbox)
	_pack_containers[dlc_id] = features_vbox

	var features: Array[Dictionary] = (
		DLCContentCatalogRef.get_features_for_display(dlc_id))
	var pack_name: String = catalog.get("name", dlc_id)

	for feat: Dictionary in features:
		var flag_name: String = feat.get("flag", "")
		var flag_val: int = -1
		if _dlc_mgr:
			flag_val = _dlc_mgr.ContentFlag.get(flag_name, -1)
		var is_enabled: bool = false
		if flag_val >= 0 and _dlc_mgr:
			is_enabled = _dlc_mgr.is_feature_enabled(flag_val)

		var row: HBoxContainer = DLCFeatureToggleRowScript.new()
		if _mode == "read_only":
			# Read-only: show as disabled checkbox
			row.setup(
				flag_val,
				feat.get("label", ""),
				"",
				is_owned,
				is_enabled,
				pack_name,
				dlc_id,
			)
			if row._checkbox:
				row._checkbox.disabled = true
		else:
			row.setup(
				flag_val,
				feat.get("label", ""),
				feat.get("preview", ""),
				is_owned,
				is_enabled,
				pack_name,
				dlc_id,
			)
		row.feature_toggled.connect(_on_feature_toggled)
		row.upsell_requested.connect(
			func(id: String): upsell_requested.emit(id))
		features_vbox.add_child(row)
		_toggle_rows[flag_name] = row

func _on_feature_toggled(flag: int, enabled: bool) -> void:
	if not _dlc_mgr:
		return

	# In campaign_creation mode, show disclaimer on first enable per pack
	if enabled and _mode == "campaign_creation":
		var dlc_id := ""
		if _dlc_mgr.has_method("get_dlc_for_feature"):
			dlc_id = _dlc_mgr.get_dlc_for_feature(flag)
		if not dlc_id.is_empty() \
				and not _acknowledged_packs.get(dlc_id, false):
			# Show disclaimer before enabling
			_pending_toggle = {"flag": flag, "dlc_id": dlc_id}
			_show_dlc_disclaimer(dlc_id, flag)
			return

	_apply_feature_toggle(flag, enabled)

func _show_dlc_disclaimer(
	dlc_id: String, flag: int,
) -> void:
	var DisclaimerScript = load(
		"res://src/ui/dialogs/DLCContentDisclaimer.gd")
	if not DisclaimerScript:
		# Fallback: just enable without disclaimer
		_apply_feature_toggle(flag, true)
		return
	var pack_name: String = DLCContentCatalogRef.get_pack_name(
		dlc_id)
	var dialog: AcceptDialog = DisclaimerScript.new()
	add_child(dialog)
	dialog.accepted.connect(func():
		_acknowledged_packs[dlc_id] = true
		_apply_feature_toggle(flag, true)
	)
	dialog.rejected.connect(func():
		# Revert the checkbox
		var flag_name := ""
		for key: String in _dlc_mgr.ContentFlag:
			if _dlc_mgr.ContentFlag[key] == flag:
				flag_name = key
				break
		var row: Variant = _toggle_rows.get(flag_name)
		if row and row.has_method("set_enabled"):
			row.set_enabled(false)
		_pending_toggle.clear()
	)
	dialog.show_for_pack(pack_name)

func _apply_feature_toggle(flag: int, enabled: bool) -> void:
	_dlc_mgr.set_feature_enabled(flag, enabled)
	feature_toggled.emit(flag, enabled)

	# Enforce No-Minis Combat incompatibilities
	_enforce_no_minis_compat(flag, enabled)

	# Emit full flag state
	if _dlc_mgr.has_method("serialize_campaign_flags"):
		flags_changed.emit(
			_dlc_mgr.serialize_campaign_flags())
	_pending_toggle.clear()

func _enforce_no_minis_compat(
	flag: int, enabled: bool,
) -> void:
	if not _dlc_mgr or not enabled:
		return
	var no_minis_val: int = _dlc_mgr.ContentFlag.get(
		"NO_MINIS_COMBAT", -1)
	if flag == no_minis_val:
		# Disable incompatible flags
		for incompat: String in NO_MINIS_INCOMPATIBLE:
			var val: int = _dlc_mgr.ContentFlag.get(incompat, -1)
			if val >= 0:
				_dlc_mgr.set_feature_enabled(val, false)
	else:
		# Check if this flag is incompatible with no-minis
		var flag_name := ""
		for key: String in _dlc_mgr.ContentFlag:
			if _dlc_mgr.ContentFlag[key] == flag:
				flag_name = key
				break
		if flag_name in NO_MINIS_INCOMPATIBLE:
			if no_minis_val >= 0:
				_dlc_mgr.set_feature_enabled(
					no_minis_val, false)
	# Refresh all rows to reflect changes
	refresh()

func _on_enable_all(dlc_id: String) -> void:
	if _dlc_mgr and _dlc_mgr.has_method("enable_all_for_dlc"):
		_dlc_mgr.enable_all_for_dlc(dlc_id)
	refresh()
	if _dlc_mgr and _dlc_mgr.has_method("serialize_campaign_flags"):
		flags_changed.emit(
			_dlc_mgr.serialize_campaign_flags())

func _on_disable_all(dlc_id: String) -> void:
	if _dlc_mgr and _dlc_mgr.has_method("disable_all_for_dlc"):
		_dlc_mgr.disable_all_for_dlc(dlc_id)
	refresh()
	if _dlc_mgr and _dlc_mgr.has_method("serialize_campaign_flags"):
		flags_changed.emit(
			_dlc_mgr.serialize_campaign_flags())
