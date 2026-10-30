# Crew Management Screen - Post-Campaign Crew Roster Management
# Allows viewing and managing crew members after campaign creation
class_name CrewManagementScreen
extends CampaignScreenBase

## Core Rules p.63: the campaign crew size (4/5/6) is how many deploy, and 6 is
## the default the config step offers. It is NOT a roster cap: p.85 says "You may
## select no more than 6 crew members to bring into a battle. The rest will wait
## behind on the ship." This file used to hold an unsourced roster cap of 8, which
## only ever bound for Character-resource cards, because dictionary cards (every
## saved crew) were never counted.
const DEFAULT_DEPLOY_SIZE := 6
const CharacterCardScene := preload("res://src/ui/components/character/CharacterCard.tscn")
## T11-28. No class_name on that file, so it must be preloaded.
const TapGestureRef = preload("res://src/ui/components/common/TapGesture.gd")
## Add Member opens the SAME creator the wizard and the Campaign Editor use, as an
## overlay on this screen. It used to navigate to SimpleCharacterCreator, a scene
## that hid itself in _ready(), that nothing listened to once it was a whole screen,
## and that rolled stats with an invented ceil(2D6/3) formula.
const CharacterCreatorScene := preload("res://src/ui/screens/character/CharacterCreator.tscn")
const CharacterCreatorScript := preload("res://src/core/character/Generation/CharacterCreator.gd")

# ============ NODE REFERENCES ============
@onready var crew_grid: GridContainer = %CrewGrid
@onready var crew_count_label: Label = %CrewCountLabel
@onready var add_button: Button = %AddButton
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

# ============ STATE ============
var current_campaign = null
## Every card on the grid, Character and Dictionary members alike. Dictionary cards
## were not tracked, so _clear_crew_grid() never freed them and every reload (Add
## Member included) stacked a second copy of the roster under the first.
var character_cards: Array[Control] = []
var current_columns: int = 1
var _character_creator: Control = null

func _setup_screen() -> void:
	# Setup responsive grid
	if crew_grid:
		crew_grid.add_theme_constant_override("h_separation", SPACING_MD)
		crew_grid.add_theme_constant_override("v_separation", SPACING_MD)
		# Pull the correct column count synchronously for the initial paint:
		# layout_class_changed has no boot emit, so don't wait for a resize.
		current_columns = -1  # force the first _update to apply the real count
		_update_grid_columns_for_mode()

	# Connect signals
	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Load crew data
	load_crew_data()

func load_crew_data() -> void:
	current_campaign = _get_campaign()
	if not current_campaign:
		push_error("CrewManagementScreen: No active campaign found")
		_update_crew_count()
		return

	_clear_crew_grid()

	# Get crew members — try multiple access patterns
	var members: Array = []
	if current_campaign.has_method("get_crew_members"):
		members = current_campaign.get_crew_members()
	elif "crew_data" in current_campaign:
		members = current_campaign.crew_data.get("members", [])

	for character in members:
		_create_character_card_entry(character)

	_update_crew_count()

# ============ RESPONSIVE LAYOUT (via CampaignScreenBase) ============

func _apply_mobile_layout() -> void:
	_update_grid_columns_for_mode()

func _apply_tablet_layout() -> void:
	_update_grid_columns_for_mode()

func _apply_desktop_layout() -> void:
	_update_grid_columns_for_mode()

func _update_grid_columns_for_mode() -> void:
	if not crew_grid:
		return
	var new_columns := get_optimal_column_count()
	if _responsive_manager and _responsive_manager.has_method("get_effective_crew_columns"):
		# Orientation-aware: drops columns in portrait. The legacy
		# get_crew_grid_columns() was width-only, so a portrait tablet kept its
		# wide column count.
		new_columns = _responsive_manager.get_effective_crew_columns()
	var spacing := get_responsive_spacing(SPACING_MD)
	crew_grid.add_theme_constant_override("h_separation", spacing)
	crew_grid.add_theme_constant_override("v_separation", spacing)
	if new_columns != current_columns:
		crew_grid.columns = new_columns
		current_columns = new_columns

# ============ CHARACTER CARD MANAGEMENT ============

func _clear_crew_grid() -> void:
	if not crew_grid:
		return
	for card in character_cards:
		if is_instance_valid(card):
			card.queue_free()
	character_cards.clear()

func _create_character_card_entry(character) -> void:
	if not crew_grid:
		return
	# If character is a Character Resource, use CharacterCard scene
	if character is Character:
		var card: CharacterCard = CharacterCardScene.instantiate()
		crew_grid.add_child(card)
		card.set_variant(CharacterCard.CardVariant.STANDARD)
		card.set_character(character)
		card.view_details_pressed.connect(_on_card_view_details.bind(character))
		card.edit_pressed.connect(_on_card_edit.bind(character))
		card.remove_pressed.connect(_on_card_remove.bind(character))
		card.card_tapped.connect(_on_card_tapped.bind(character))
		character_cards.append(card)
	elif character is Dictionary:
		# Dictionary-based crew member (from save file)
		var name_str: String = character.get(
			"character_name", character.get("name", "Unknown"))
		var is_captain: bool = character.get("is_captain", false)

		# M2: show species/origin (matching the Dashboard crew cards) — the save
		# dicts carry origin/species (e.g. "assault_bot"), NOT a `background` enum
		# int, so the old `background` read defaulted every crew to "COLONIST".
		var origin_val = character.get("origin",
			character.get("species", character.get("species_id", "")))
		var cls_val = character.get("character_class",
			character.get("class", -1))
		var bg_name: String = _format_origin_display(origin_val)
		var cls_name: String = _resolve_class_name(cls_val)

		# Captain entries lack flat stats — parse traits
		if bg_name == "Unknown" or cls_name == "Unknown":
			var parsed := _parse_traits(
				character.get("traits", []))
			if bg_name == "Unknown" and not parsed.bg.is_empty():
				bg_name = parsed.bg
			if cls_name == "Unknown" and not parsed.cls.is_empty():
				cls_name = parsed.cls

		# Build stat display — captain may lack flat stats
		var char_ref = character.get("character", null)
		var stats := {}
		if character.has("combat") or character.has("reactions"):
			stats = {
				"C": int(character.get("combat", 0)),
				"R": int(character.get("reactions",
					character.get("reaction", 0))),
				"T": int(character.get("toughness", 0)),
				"S": int(character.get("speed", 0)),
				"Sv": int(character.get("savvy", 0)),
				"L": int(character.get("luck", 0)),
			}
		elif char_ref is Resource and char_ref.has_method("get"):
			stats = {
				"C": int(char_ref.get("combat") if char_ref.get("combat") else 0),
				"R": int(char_ref.get("reactions") if char_ref.get("reactions") else 0),
				"T": int(char_ref.get("toughness") if char_ref.get("toughness") else 0),
				"S": int(char_ref.get("speed") if char_ref.get("speed") else 0),
				"Sv": int(char_ref.get("savvy") if char_ref.get("savvy") else 0),
				"L": int(char_ref.get("luck") if char_ref.get("luck") else 0),
			}

		var display_name := name_str
		if is_captain:
			display_name = "[Captain] " + name_str
		var subtitle := "%s / %s" % [bg_name, cls_name]
		# T11-51: pass the BARE name as the identity. `display_name` carries the
		# "[Captain] " prefix, and the factory derives the avatar initial and
		# colour from the identity — otherwise the captain's avatar reads `[`.
		var card := _create_character_card(
			display_name, subtitle, stats, "", name_str)
		crew_grid.add_child(card)
		character_cards.append(card)

		# Make dict-based cards tappable → navigate to character details.
		# T11-28: fires on RELEASE, so dragging the crew list to scroll it no
		# longer navigates away mid-gesture.
		TapGestureRef.connect_tap(
			card, _on_dict_card_tapped.bind(character)
		)

func _update_crew_count() -> void:
	if not crew_count_label:
		return
	# Every card is tracked now, dictionary members included. Counting the grid's
	# children instead also counts the cards a reload has queued for freeing.
	var crew_size := character_cards.size()
	# A roster larger than the deploy size is legal (p.85), so it is not a warning.
	crew_count_label.text = "Crew: %d · deploy up to %d" % [crew_size, _get_max_crew_size()]

## M6: the campaign's fixed crew-size setting (Core Rules p.63 — 4/5/6) via the
## GameState chain, NOT the hardcoded roster ceiling. Falls back to the const.
func _get_max_crew_size() -> int:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_campaign_crew_size"):
		var n: int = gs.get_campaign_crew_size()
		if n > 0:
			return n
	return DEFAULT_DEPLOY_SIZE

## T11-31 - the species/origin name, from the file that owns it.
##
## TWO defects lived in the four lines this replaces, and the device walk saw
## both:
##   1. A String with no underscore was returned VERBATIM, so the stored enum key
##      "KERIN" printed as "KERIN" while the Campaign Dashboard, one tap away,
##      printed "K'Erin" for the same crew member.
##   2. A legacy NUMERIC origin was resolved through
##      `_resolve_background_name()`, i.e. against GlobalEnums.BACKGROUND - the
##      wrong enum entirely, so origin 4 (KERIN) rendered as Background[4].
##      Numeric origins are 52% of crew records across the 21 real save files.
func _format_origin_display(val) -> String:
	return SpeciesDataService.display_name(val, "", "Unknown")

# ============ CHARACTER CARD SIGNAL HANDLERS ============

func _on_card_view_details(character: Character) -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_temp_data"):
		gsm.set_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER, character)
		# Pass crew list for swipe navigation
		_store_crew_list_for_swipe(gsm, character)
		gsm.navigate_to_screen("character_details")

func _on_card_edit(character: Character) -> void:
	_on_card_view_details(character)

func _on_card_remove(character: Character) -> void:
	var char_name = character.get_display_name()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove Crew Member"
	dialog.dialog_text = "Remove %s from crew?\nThis cannot be undone." % char_name
	dialog.ok_button_text = "Remove"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	dialog.confirmed.connect(func():
		_actually_remove_character(character)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _on_card_tapped(character: Character) -> void:
	_on_card_view_details(character)

func _actually_remove_character(character: Character) -> void:
	if not current_campaign:
		return
	var members: Array = current_campaign.get_crew_members() if current_campaign.has_method("get_crew_members") else []
	var index: int = members.find(character)
	if index >= 0:
		members.remove_at(index)
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("mark_campaign_modified"):
			gsm.mark_campaign_modified()
		load_crew_data()

# ============ BUTTON HANDLERS ============

func _on_add_member_pressed() -> void:
	_ensure_character_creator()
	$MarginContainer.hide()
	_character_creator.start_creation(CharacterCreatorScript.CreatorMode.CHARACTER)


func _ensure_character_creator() -> void:
	if _character_creator:
		return
	_character_creator = CharacterCreatorScene.instantiate()
	_character_creator.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_character_creator.hide()
	add_child(_character_creator)
	_character_creator.character_created.connect(_on_character_created)
	_character_creator.creation_cancelled.connect(_hide_character_creator)


func _on_character_created(character) -> void:
	_hide_character_creator()
	if current_campaign == null or character == null or not character.has_method("to_dictionary"):
		return
	# The crew-addition chokepoint: it appends a Dictionary, forces is_captain off
	# and rebuilds the id index.
	current_campaign.add_crew_member(character.to_dictionary())
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("mark_campaign_modified"):
		gsm.mark_campaign_modified()
	load_crew_data()


func _hide_character_creator() -> void:
	if _character_creator:
		_character_creator.hide()
	$MarginContainer.show()

func _on_save_pressed() -> void:
	if _game_state and _game_state.has_method("save_campaign"):
		var result: Dictionary = _game_state.save_campaign()
		if result.get("success", false):
			pass

func _on_back_pressed() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("has_temp_data"):
		if gsm.has_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER):
			gsm.clear_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER)
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("campaign_dashboard")
	else:
		get_tree().change_scene_to_file(
			"res://src/ui/screens/campaign/CampaignDashboard.tscn"
		)

## T11-28: renamed from _on_dict_card_clicked and no longer takes the InputEvent —
## TapGesture owns the tap-vs-drag discrimination now, so this only runs on a real tap.
func _on_dict_card_tapped(char_dict: Dictionary) -> void:
	# Convert dict to Character Resource for the details screen
	var character := Character.new()
	character.from_dictionary(char_dict)
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_temp_data"):
		gsm.set_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER, character)
		# Store the source dict so CharacterDetailsScreen can write changes back
		gsm.set_temp_data("source_crew_dict", char_dict)
		# Pass crew list for swipe navigation
		_store_crew_list_for_swipe(gsm, character)
		gsm.navigate_to_screen("character_details")

func _store_crew_list_for_swipe(gsm: Node, selected_character: Character) -> void:
	if not current_campaign:
		return
	var members: Array = []
	if current_campaign.has_method("get_crew_members"):
		members = current_campaign.get_crew_members()
	elif "crew_data" in current_campaign:
		members = current_campaign.crew_data.get("members", [])
	if members.is_empty():
		return
	# Convert all members to dicts for uniform handling
	var crew_dicts: Array[Dictionary] = []
	var selected_idx: int = 0
	for i in members.size():
		var m = members[i]
		var d: Dictionary
		if m is Dictionary:
			d = m
		elif m.has_method("to_dictionary"):
			d = m.to_dictionary()
		else:
			continue
		crew_dicts.append(d)
		# Match by character_id or character_name
		var sel_id: String = selected_character.character_id \
			if "character_id" in selected_character else ""
		var m_id: String = str(d.get("character_id", d.get("id", "")))
		if not sel_id.is_empty() and m_id == sel_id:
			selected_idx = crew_dicts.size() - 1
	gsm.set_temp_data("crew_list_for_swipe", crew_dicts)
	gsm.set_temp_data("crew_index_for_swipe", selected_idx)

# ============ DATA RESOLUTION HELPERS ============

func _parse_traits(traits: Array) -> Dictionary:
	var result := {"bg": "", "cls": ""}
	for trait_str in traits:
		if trait_str is String:
			if trait_str.begins_with("Background: "):
				result.bg = trait_str.substr(12)
			elif trait_str.begins_with("Class: "):
				result.cls = trait_str.substr(7)
	return result

## T11-31 - the class name in the book's spelling.
##
## A String was returned VERBATIM, so the stored key "BOUNTY_HUNTER" printed as
## "BOUNTY_HUNTER" on the crew card. GlobalEnums.get_class_display_name() already
## handles both the int and String forms and produces the p.27 spelling
## ("Bounty Hunter"), so this is a delegation rather than a second copy.
func _resolve_class_name(val) -> String:
	# Returns "Unknown" rather than "" on purpose: the caller at :133-139 keys
	# on that exact string to fall back to parsing the character's traits, so a
	# blank here would silently disable the captain-card fallback.
	return GlobalEnums.get_class_display_name(val)
