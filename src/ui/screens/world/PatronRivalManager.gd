class_name PatronRivalManagerUI
extends Control
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

signal patron_selected(patron: Dictionary)
signal rival_selected(rival: Dictionary)

const AdaptivePanelGroupClass = preload("res://src/ui/components/base/AdaptivePanelGroup.gd")

# Index of the Details pane within the adaptive group (Patrons=0, Rivals=1, Details=2).
const DETAILS_PANE_INDEX := 2

@onready var patrons_list: VBoxContainer = %PatronsList
@onready var rivals_list: VBoxContainer = %RivalsList
@onready var details_container: VBoxContainer = %DetailsContainer

var _panel_group: Control = null

# DataManager accessed via autoload singleton

var patrons: Array[Dictionary] = []
var rivals: Array[Dictionary] = []
var selected_patron: Dictionary = {}
var selected_rival: Dictionary = {}

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

# JSON data storage

func _ready() -> void:
	# §2: open the touch chain once this function has built the tree.
	# call_deferred runs AFTER _ready() returns, so placement here is
	# equivalent to placing it last and cannot land before the children exist.
	call_deferred("_open_touch_chain")
	_load_patrons_and_rivals()
	_refresh_displays()
	_setup_adaptive_panels()
	# Push content below the floating gear/bug buttons. Belt-and-braces: this screen is
	# also opened as a child from the World Phase, where it never becomes current_scene
	# and so is never reached by the autoload's scene_changed net.
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)
	# Portrait de-clip: trim root margins in portrait (restored landscape).
	var pc_mc := get_node_or_null("MarginContainer")
	if pc_mc is MarginContainer:
		var pc = load("res://src/ui/components/base/PortraitChrome.gd").new()
		add_child(pc)
		pc.setup(pc_mc as MarginContainer)

	# One header idiom app-wide: "< Back" first, then the title at FONT_SIZE_XL. The
	# scene used to pin the title at 32px, which outranks the responsive theme.
	ScreenChrome.adopt_header(
		get_node_or_null("MarginContainer/VBoxContainer/Header/BackButton") as Button,
		get_node_or_null("MarginContainer/VBoxContainer/Header/Title") as Label
	)

	# Short-screen scroll: this column wants 343 design px and a phone in landscape
	# only has ~291. Without this the grow-both root re-centres to a NEGATIVE y and
	# the header slides up under the floating gear/bug buttons. The other four
	# manager screens already wire this; this one was missed. Pinned=1 keeps the
	# header row fixed while the content below it scrolls; no-ops above 620 px.
	var _sss_column := get_node_or_null("MarginContainer/VBoxContainer")
	if _sss_column is BoxContainer:
		var _sss = load("res://src/ui/components/base/ShortScreenScroll.gd").new()
		add_child(_sss)
		_sss.setup(_sss_column as BoxContainer, 1)

func _setup_adaptive_panels() -> void:
	## Reparent the three side-by-side panes (Patrons / Rivals / Details) into an
	## AdaptivePanelGroup so they collapse to a master-detail tab strip in portrait
	## while staying side-by-side in landscape. Header + Controls rows stay outside.
	if _panel_group:
		return

	var patrons_pane: Control = get_node_or_null("%Patrons")
	var rivals_pane: Control = get_node_or_null("%Rivals")
	var details_pane: Control = get_node_or_null("%Details")
	if not patrons_pane or not rivals_pane or not details_pane:
		return

	var main_content: Node = patrons_pane.get_parent()
	var vbox: Node = main_content.get_parent()
	var idx: int = main_content.get_index()

	var group := AdaptivePanelGroupClass.new()
	group.name = "AdaptiveContent"
	group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	group.max_columns = 3
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(group)
	vbox.move_child(group, idx)

	group.add_pane(patrons_pane, "Patrons")
	group.add_pane(rivals_pane, "Rivals")
	group.add_pane(details_pane, "Details")

	main_content.queue_free()
	_panel_group = group

func _load_patrons_and_rivals() -> void:
	## Load patrons and rivals from GameStateManager (single source of truth)
	# Primary: Load from GameStateManager
	if GameStateManager:
		var loaded_patrons: Array = GameStateManager.get_patrons()
		var loaded_rivals: Array = GameStateManager.get_rivals()

		# Convert to typed arrays
		patrons.clear()
		for p in loaded_patrons:
			if p is Dictionary:
				patrons.append(p)

		rivals.clear()
		for r in loaded_rivals:
			if r is Dictionary:
				rivals.append(r)

		pass # Patrons and rivals loaded
	else:
		push_warning("PatronRivalManager: GameStateManager not available")

	# NO auto-generation on an empty list.
	#
	# This used to invent 2 patrons and 2 rivals from the JSON templates whenever
	# either list was empty, and then SAVE them into the campaign. Merely opening
	# the screen wrote four contacts that the player never earned into their save
	# file. Patrons are found at World step 3 (Determine job offers, p.76) and
	# rivals arrive from battles and encounters -- a read-only record of who you
	# have met must never mint entries. "You have no patrons yet" is a true and
	# legitimate state, especially on turn 1, and the empty list renders as such.

func _refresh_displays() -> void:
	## Refresh all display lists
	_refresh_patrons_list()
	_refresh_rivals_list()

func _refresh_patrons_list() -> void:
	## Refresh the patrons list display
	# Clear existing items
	for child in patrons_list.get_children():
		child.queue_free()

	# Add patron items
	for patron in patrons:
		var patron_panel: Control = _create_patron_panel(patron)
		patrons_list.add_child(patron_panel)

func _refresh_rivals_list() -> void:
	## Refresh the rivals list display
	# Clear existing items
	for child in rivals_list.get_children():
		child.queue_free()

	# Add rival items
	for rival in rivals:
		var rival_panel: Control = _create_rival_panel(rival)
		rivals_list.add_child(rival_panel)

func _create_patron_panel(patron: Dictionary) -> Control:
	## Create a panel for a patron
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Name and type — .get() with defaults: a patron dict from a save / FactionSystem
	# may be MISSING these keys, and `patron.name` property access on a missing key
	# hard-errors (aborts the panel; halts under --debug). str() alone only fixes the
	# int-enum type case, not the missing-key case. Mirrors the safe _update_details
	# sibling below (:453-470).
	var name_label: Label = Label.new()
	# T11-29: blank, never "Unknown". GameStateManager.add_patron() guarantees
	# name/type/status/relationship (:979-984), so a blank here means a legacy
	# or hand-authored record - which is worth showing as a gap, not papering
	# over with a word that looks like a value.
	var pname: String = str(patron.get("name", "")).strip_edges()
	var ptype: String = str(patron.get("type", "")).strip_edges()
	name_label.text = pname if ptype.is_empty() else "%s (%s)" % [pname, ptype]
	name_label.add_theme_font_size_override("font_size", _scaled_font(16))
	vbox.add_child(name_label)

	# Status and relationship
	var status_label: Label = Label.new()
	status_label.text = "Status: %s | Relationship: %s" % [
		str(patron.get("status", "")), str(patron.get("relationship", 0))]
	vbox.add_child(status_label)

	# Jobs offered
	var jobs_label: Label = Label.new()
	jobs_label.text = "Jobs Available: " + str(patron.get("jobs_offered", 0))
	vbox.add_child(jobs_label)

	# Select button
	var select_button: Button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_patron_selected.bind(patron))
	vbox.add_child(select_button)

	return panel

## Separator for a multi-line special-rules list (see _update_details).
const NL_JOIN := "\n"

## T11-29 — the origin values the real producers write, in the player's words.
## RivalPatronResolver._append_rival writes battle_grudge / psi_hunt;
## PostBattleContext.add_rival writes campaign_event (or whatever the caller
## passes). An unlisted value falls back to a de-underscored capitalize().
const _ORIGIN_LABELS := {
	"battle_grudge": "Battle grudge",
	"psi_hunt": "Psi-hunters",
	"campaign_event": "Campaign event",
	"character_event": "Character event",
	"story": "Story Track",
	"event": "Event",
}


## T11-29 — render the keys a REAL Rival actually has.
##
## This panel used to read `threat_level`, `relationship` and `status` and print
## "Unknown" for each. Those three keys were written by exactly one producer: this
## screen's own _create_rival_from_template(), which built them from three JSON
## template files that DO NOT EXIST in the repo, so every value came from an
## invented `_create_*_templates_fallback()`. The screen was displaying the shape
## of its own fabricated data and calling every genuine Rival Unknown.
##
## The real producers are RivalPatronResolver._append_rival() and
## PostBattleContext.add_rival(), which now emit ONE shape:
##   id, name, type, planet_id, threat_level, created_turn, origin
## plus the optional tags is_elite / is_psi_hunter / persistent /
## enemy_count_bonus.
##
## Missing values render as NOTHING, never "Unknown": a contact record with an
## empty line is honest, and a screen full of Unknowns is what made a working
## feature look broken on the tablet.
func _create_rival_panel(rival: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Heading: the enemy TYPE. Core Rules p.119 — "the type of opponents you
	# just fought become your Rivals" — so the type IS the identity; the name is
	# flavour on top of it. Falls back to the name for a legacy record with no
	# type (a STARTING Rival records a faction category, not an enemy type).
	var heading: Label = Label.new()
	var rtype: String = str(rival.get("type", "")).strip_edges()
	var rname: String = str(rival.get("name", "")).strip_edges()
	heading.text = rtype if not rtype.is_empty() else rname
	heading.add_theme_font_size_override("font_size", _scaled_font(16))
	vbox.add_child(heading)

	# The name, when it says something the type does not.
	if not rname.is_empty() and rname != rtype:
		var sub: Label = Label.new()
		sub.text = rname
		sub.add_theme_font_size_override("font_size", _scaled_font(12))
		vbox.add_child(sub)

	var provenance: String = _rival_provenance(rival)
	if not provenance.is_empty():
		var prov: Label = Label.new()
		prov.text = provenance
		prov.add_theme_font_size_override("font_size", _scaled_font(12))
		vbox.add_child(prov)

	var tags: String = _rival_tags(rival)
	if not tags.is_empty():
		var tag_label: Label = Label.new()
		tag_label.text = tags
		tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag_label.add_theme_font_size_override("font_size", _scaled_font(12))
		vbox.add_child(tag_label)

	var select_button: Button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_rival_selected.bind(rival))
	vbox.add_child(select_button)

	return panel


## Where this Rival came from and when — the two facts every real producer records.
func _rival_provenance(rival: Dictionary) -> String:
	var parts: Array = []
	var origin_label: String = _ORIGIN_LABELS.get(
		str(rival.get("origin", "")), "")
	if origin_label.is_empty():
		origin_label = str(rival.get("origin", "")).replace("_", " ").capitalize()
	if not origin_label.is_empty():
		parts.append(origin_label)
	var planet: String = _planet_name(str(rival.get("planet_id", "")))
	if not planet.is_empty():
		parts.append("on " + planet)
	var turn: int = int(rival.get("created_turn", 0))
	if turn > 0:
		parts.append("since turn %d" % turn)
	return " · ".join(PackedStringArray(parts))


## The riders that change how a battle against this Rival plays out. Each one is a
## rule the player has to remember at the table, so it belongs on the card rather
## than only in the code that applies it.
func _rival_tags(rival: Dictionary) -> String:
	var tags: Array = []
	if bool(rival.get("is_elite", false)):
		tags.append("Elite")
	if bool(rival.get("is_psi_hunter", false)):
		tags.append("Psi-hunters")
	if bool(rival.get("persistent", false)):
		tags.append("Follows you")
	var bonus: int = int(rival.get("enemy_count_bonus", 0))
	if bonus != 0:
		tags.append("%+d enemies" % bonus)
	return ", ".join(PackedStringArray(tags))


## Planet id -> the name the player knows it by. Blank when the id is unknown to
## PlanetDataManager, which is a legitimate state for a legacy save.
func _planet_name(planet_id: String) -> String:
	if planet_id.is_empty():
		return ""
	var pdm: Node = get_node_or_null("/root/PlanetDataManager")
	if pdm == null:
		return ""
	if not pdm.has_method("get_planet_stats"):
		return ""
	var stats: Dictionary = pdm.get_planet_stats(planet_id)
	return str(stats.get("name", ""))

func _update_details(entity: Dictionary, is_patron: bool) -> void:
	## Update the details panel
	# Clear existing details
	for child in details_container.get_children():
		child.queue_free()

	if entity.is_empty():
		return

	# Entity name. str()-wrap every field: loaded save data can carry int/enum
	# values here and String + int hard-errors at runtime (twin of the :424 fix).
	var name_label: Label = Label.new()
	name_label.text = str(entity.get("name", ""))
	name_label.add_theme_font_size_override("font_size", _scaled_font(20))
	details_container.add_child(name_label)

	# Type
	var type_label: Label = Label.new()
	type_label.text = "Type: " + str(entity.get("type", ""))
	details_container.add_child(type_label)

	# T11-29: `status` and `relationship` are PATRON keys —
	# GameStateManager.add_patron() guarantees both (:983-984). No Rival
	# producer writes either, so printing them for a Rival could only ever
	# say "Unknown".
	if is_patron:
		var status_label: Label = Label.new()
		status_label.text = "Status: " + str(entity.get("status", ""))
		details_container.add_child(status_label)

		var relationship_label: Label = Label.new()
		relationship_label.text = "Relationship: " + str(
			entity.get("relationship", 0))
		details_container.add_child(relationship_label)

	if is_patron:
		var jobs_label: Label = Label.new()
		jobs_label.text = "Jobs Available: " + str(entity.get("jobs_offered", 0))
		details_container.add_child(jobs_label)

		# T11-29: the "Get Job Offer" button is GONE. It called
		# _generate_job_offer(), which built an offer from
		# data/jobs/job_templates.json - a file that does not exist - so every
		# field came from _create_job_templates_fallback()'s invented values
		# (job_multiplier 1.5 and friends, in neither rulebook). The real job
		# path is the World Phase JOB_OFFERS step (Core Rules p.76), which rolls
		# the book's own tables. A viewer must not mint jobs.
	else:
		# T11-29 — the Rival's provenance and its battle riders, both of which
		# real producers record. `threat_level` used to be printed here; it is
		# written as a constant 1 and read by nothing, so it said nothing.
		var provenance: String = _rival_provenance(entity)
		if not provenance.is_empty():
			var prov: Label = Label.new()
			prov.text = provenance
			details_container.add_child(prov)
		var tags: String = _rival_tags(entity)
		if not tags.is_empty():
			var tag_label: Label = Label.new()
			tag_label.text = "Rules: " + tags
			tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details_container.add_child(tag_label)

	# Special rules
	if entity.has("special_rules"):
		var rules_label: Label = Label.new()
		rules_label.text = "Special Rules:"
		rules_label.add_theme_font_size_override("font_size", _scaled_font(14))
		details_container.add_child(rules_label)

		var rules_text = Label.new()
		# ⚠ NOT `entity.special_rules`. Every OTHER producer in the codebase
		# makes this an ARRAY — Character.gd:1462 (`special_rules.duplicate()`),
		# EnemyData.gd:131 and SpeciesDataService.gd:91 (`[]` defaults),
		# PatronJobGenerator.gd:92, BattleResolver.gd:295 (`var x: Array`).
		# Only this screen's own template generator (:352/:368) stores a single
		# String, and the screen no longer reads those templates: it loads live
		# contacts from GameStateManager (:264-282). Assigning an Array to the
		# String `Label.text` is a type error that ABORTS _update_details(), so
		# the details pane would stop building mid-way with no crash to notice.
		# Dormant today only because no live producer writes the key at all.
		var raw_rules: Variant = entity.get("special_rules", "")
		rules_text.text = (NL_JOIN.join(PackedStringArray(
			(raw_rules as Array).map(func(r: Variant) -> String: return str(r))))
			if raw_rules is Array else str(raw_rules))
		rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_container.add_child(rules_text)

func _on_patron_selected(patron: Dictionary) -> void:
	## Handle patron selection
	selected_patron = patron
	selected_rival = {}
	_update_details(patron, true)
	if _panel_group:
		_panel_group.focus_pane(DETAILS_PANE_INDEX)
	patron_selected.emit(patron)

func _on_rival_selected(rival: Dictionary) -> void:
	## Handle rival selection
	selected_rival = rival
	selected_patron = {}
	_update_details(rival, false)
	if _panel_group:
		_panel_group.focus_pane(DETAILS_PANE_INDEX)
	rival_selected.emit(rival)

func _on_back_pressed() -> void:
	## Reachable from the Campaign Dashboard, so fall back THERE rather than the
	## main menu when there is no history to pop.
	ScreenChrome.navigate_back(self, "campaign_dashboard")


## §2: let a touch-drag over content reach the ScrollContainer that owns it.
##
## Every decorative surface — `PanelContainer`, `HSeparator`, `CheckBox`,
## `OptionButton`, `SpinBox`, `Button` — defaults to `MOUSE_FILTER_STOP`, and
## `Viewport::_gui_call_input` stops Mouse/ScreenDrag/ScreenTouch at the first STOP
## control. Only WHEEL is excepted (`mouse_force_pass_scroll_events`, default true),
## which is exactly why the scrollbar and the desktop mouse wheel work here and a
## finger does not.
##
## This screen `extends Control`, so it inherits neither
## `BaseCampaignPanel._fix_touch_scroll_filters()` nor `CampaignScreenBase`'s — it had
## no sweep at all. `open_subtree()` is idempotent and STOP -> PASS only, so calling it
## again after a rebuild is free; PASS still offers the event to the control FIRST, so
## a tap keeps working (measured in `tests/unit/test_touch_pass_is_safe_for_buttons.gd`).
func _open_touch_chain() -> void:
	TouchScrollOpenerRef.open_subtree(self)
