class_name EquipmentManagerUI
extends Control
const TouchScrollOpenerRef = preload(
	"res://src/ui/components/common/TouchScrollOpener.gd")

signal equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary)

## AdaptivePanelGroup preloaded by path (responsive 3-pane → tab strip in
## portrait; master-detail). Path preload avoids the stale class_name cache.
const AdaptivePanelGroupClass = preload("res://src/ui/components/base/AdaptivePanelGroup.gd")

@onready var equipment_grid: GridContainer = %EquipmentGrid
@onready var crew_list: VBoxContainer = %CrewList
@onready var details_container: VBoxContainer = %DetailsContainer

# The three content panels reparented into this group (set in _setup_adaptive_panels).
var _panel_group: Control = null

var selected_equipment: Dictionary = {}
var selected_crew_member: Dictionary = {}
var equipment_database: Array[Dictionary] = []
var crew_roster: Array[Dictionary] = []

var is_initialized: bool = false
var initialization_attempts: int = 0
const MAX_INITIALIZATION_ATTEMPTS: int = 3

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	# §2: open the touch chain once this function has built the tree.
	# call_deferred runs AFTER _ready() returns, so placement here is
	# equivalent to placing it last and cannot land before the children exist.
	call_deferred("_open_touch_chain")
	
	# Node structure initialized
	
	# Portrait de-clip: trim root margins in portrait (restored landscape).
	var pc_mc := get_node_or_null("MarginContainer")
	if pc_mc is MarginContainer:
		var pc = load("res://src/ui/components/base/PortraitChrome.gd").new()
		add_child(pc)
		pc.setup(pc_mc as MarginContainer)

	# Keep content clear of the floating SettingsOverlay gear/bug buttons, which
	# are drawn on their own CanvasLayer ABOVE this screen. Pushes content DOWN --
	# a right-side margin would raise the container's minimum WIDTH and propagate
	# an overflow up the tree (proven and reverted on HelpScreen).
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)

	_adopt_screen_header()

	# Wait for scene to be fully ready if nodes are null
	if equipment_grid == null or crew_list == null or details_container == null:
		call_deferred("_deferred_initialization")
		return
	
	_initialize_systems()

## Bring the scene-built header onto the shared idiom: "< Back" first, then the
## title at FONT_SIZE_XL. The scene used to pin the title at 32px, which outranks
## the responsive theme, so on a phone "Equipment Manager" wrapped to two lines and
## pushed the Back button off the top of the screen.
func _adopt_screen_header() -> void:
	ScreenChrome.adopt_header(
		get_node_or_null("MarginContainer/VBoxContainer/Header/BackButton") as Button,
		get_node_or_null("MarginContainer/VBoxContainer/Header/Title") as Label
	)

func _deferred_initialization():
	## Initialize after scene is fully ready
	initialization_attempts += 1
	pass # Attempting deferred initialization
	
	# Try multiple node finding strategies
	_find_nodes_with_fallbacks()
	
	if equipment_grid != null and crew_list != null and details_container != null:
		_initialize_systems()
	elif initialization_attempts < MAX_INITIALIZATION_ATTEMPTS:
		call_deferred("_deferred_initialization")
	else:
		push_error("EquipmentManager: Critical nodes still not found after %d attempts - cannot initialize" % MAX_INITIALIZATION_ATTEMPTS)

func _find_nodes_with_fallbacks():
	## Try multiple strategies to find required nodes
	
	# Strategy 1: @onready should have worked
	if equipment_grid != null and crew_list != null and details_container != null:
		return
	
	# Strategy 2: Find by unique name
	if equipment_grid == null:
		equipment_grid = find_child("EquipmentGrid", true, false)
		if equipment_grid == null:
			# Strategy 3: unique name (reparent-proof — the panels move into the
			# AdaptivePanelGroup, so an absolute path would be stale).
			equipment_grid = get_node_or_null("%EquipmentGrid")
		pass # equipment_grid lookup complete

	if crew_list == null:
		crew_list = find_child("CrewList", true, false)
		if crew_list == null:
			crew_list = get_node_or_null("%CrewList")
		pass # crew_list lookup complete

	if details_container == null:
		details_container = find_child("DetailsContainer", true, false)
		if details_container == null:
			details_container = get_node_or_null("%DetailsContainer")
		pass # details_container lookup complete

func _initialize_systems():
	## Initialize all systems once nodes are confirmed available
	is_initialized = true
	_setup_adaptive_panels()
	_load_equipment_database()
	_load_crew_roster()
	_refresh_equipment_display()
	_refresh_crew_display()


## Reparent the 3 content panels (Equipment / Crew / Details) into an
## AdaptivePanelGroup: side-by-side in landscape, a tab strip in portrait
## (master-detail — selecting an item focuses the Details tab). Header + Controls
## are siblings of MainContent, so they stay put. The %-unique node refs above
## survive the reparent (they point at descendants that move with their panel).
func _setup_adaptive_panels() -> void:
	if _panel_group:
		return  # _initialize_systems may run once, but guard re-entry anyway.
	var eq_list: Control = get_node_or_null("%EquipmentList")
	var crew_panel: Control = get_node_or_null("%CrewAssignment")
	var details_panel: Control = get_node_or_null("%EquipmentDetails")
	if not (eq_list and crew_panel and details_panel):
		return
	var main_content: Node = eq_list.get_parent()       # the MainContent HBox
	var vbox: Node = main_content.get_parent() if main_content else null
	if not vbox:
		return
	var idx: int = main_content.get_index()
	var group := AdaptivePanelGroupClass.new()
	group.name = "AdaptiveContent"
	group.portrait_mode = AdaptivePanelGroupClass.PortraitMode.TABS
	group.max_columns = 3
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(group)
	vbox.move_child(group, idx)
	group.add_pane(eq_list, "Equipment")
	group.add_pane(crew_panel, "Crew")
	group.add_pane(details_panel, "Details")
	main_content.queue_free()  # now empty; Header + Controls untouched
	_panel_group = group

func _load_equipment_database() -> void:
	## Load equipment from data systems (hardcoded fallback — no DataManager equipment API)
	equipment_database = [
		{"name": "Military Rifle", "type": "weapon", "range": 24, "shots": 1, "damage": 1, "traits": ["Military"]},
		{"name": "Scrap Pistol", "type": "weapon", "range": 12, "shots": 1, "damage": 1, "traits": ["Pistol"]},
		{"name": "Combat Armor", "type": "armor", "save": 5, "traits": ["Heavy"]},
		{"name": "Analyzer", "type": "gadget", "traits": ["Tech"]},
		{"name": "Medkit", "type": "gear", "traits": ["Medical"]},
	]

func _load_crew_roster() -> void:
	## Load current crew from campaign data (hardcoded fallback — no CampaignManager autoload)
	crew_roster = [
		{"name": "Captain Reynolds", "class": "Soldier", "equipment": []},
		{"name": "Dr. Chen", "class": "Scientist", "equipment": []},
		{"name": "Sgt. Martinez", "class": "Military", "equipment": []},
		{"name": "Tech Walker", "class": "Engineer", "equipment": []},
	]

func set_crew_data(crew_data: Array) -> void:
	## Set crew data from external source (EquipmentPanel coordinator)
	pass # Receiving crew data
	
	crew_roster.clear()
	for member in crew_data:
		# Validate each crew member data
		var validated_member = DataValidator.validate_crew_member(member)
		crew_roster.append(validated_member)
		pass # Crew member added
	
	# Refresh display with new crew data
	_refresh_crew_display()
	pass # Crew roster updated

func _refresh_equipment_display() -> void:
	## Refresh the equipment grid display
	
	# Check if we're initialized and nodes are available
	if not is_initialized or equipment_grid == null:
		if equipment_grid == null:
			_find_nodes_with_fallbacks()
		
		if equipment_grid == null:
			return
	
	pass # Clearing equipment items
	
	# Clear existing items safely
	for child in equipment_grid.get_children():
		child.queue_free()

	# Add equipment items
	pass # Adding equipment items to display
	for equipment in equipment_database:
		var validated_equipment = DataValidator.validate_equipment(equipment)
		var item_button: Button = Button.new()
		item_button.text = DataValidator.safe_get_name(validated_equipment)
		item_button.custom_minimum_size = Vector2(0, 60)
		item_button.pressed.connect(_on_equipment_selected.bind(validated_equipment))
		equipment_grid.add_child(item_button)

func _refresh_crew_display() -> void:
	## Refresh the crew assignment display
	
	# Check if we're initialized and nodes are available
	if not is_initialized or crew_list == null:
		if crew_list == null:
			_find_nodes_with_fallbacks()
		
		if crew_list == null:
			return
	
	pass # Clearing crew items
	
	# Clear existing items safely
	for child in crew_list.get_children():
		child.queue_free()

	# Add crew members
	pass # Adding crew members to display
	for crew_member in crew_roster:
		var crew_panel: Control = _create_crew_panel(crew_member)
		crew_list.add_child(crew_panel)
		var member_name = DataValidator.safe_get_name(crew_member)

func _create_crew_panel(crew_member: Dictionary) -> Control:
	## Create a panel for crew _member equipment assignment
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Validate and normalize crew member data
	var validated_member = DataValidator.validate_crew_member(crew_member)
	
	# Crew member name
	var name_label: Label = Label.new()
	var member_name = DataValidator.safe_get_name(validated_member)
	var member_class = DataValidator.safe_get_class(validated_member)
	name_label.text = "%s (%s)" % [member_name, member_class]
	vbox.add_child(name_label)

	# Equipment list
	var equipment_list = VBoxContainer.new()
	for equipment_item in validated_member.get("equipment", []):
		var validated_equipment = DataValidator.validate_equipment(equipment_item)
		var equipment_label: Label = Label.new()
		equipment_label.text = "- " + DataValidator.safe_get_name(validated_equipment)
		equipment_list.add_child(equipment_label)
	vbox.add_child(equipment_list)

	# Assign button
	var assign_button: Button = Button.new()
	assign_button.text = "Assign Equipment"
	assign_button.pressed.connect(_on_crew_selected.bind(crew_member))
	vbox.add_child(assign_button)

	return panel

func _update_equipment_details(equipment: Dictionary) -> void:
	## Update the equipment details panel
	
	# Safety check for details_container
	if details_container == null:
		push_error("EquipmentManager: details_container is null, cannot update details")
		return
	
	# Clear existing details safely
	for child in details_container.get_children():
		child.queue_free()

	if equipment.is_empty():
		return

	# Validate equipment data
	var validated_equipment = DataValidator.validate_equipment(equipment)
	pass # Displaying equipment details

	# Equipment name
	var name_label: Label = Label.new()
	name_label.text = DataValidator.safe_get_name(validated_equipment)
	name_label.add_theme_font_size_override("font_size", _scaled_font(18))
	details_container.add_child(name_label)

	# Equipment type
	var type_label: Label = Label.new()
	type_label.text = "Type: " + validated_equipment.get("type", "unknown").capitalize()
	details_container.add_child(type_label)

	# Equipment stats
	match validated_equipment.get("type", ""):
		"weapon":
			var range_label: Label = Label.new()
			range_label.text = "Range: " + str(validated_equipment.get("range", 0)) + "\""
			details_container.add_child(range_label)

			var shots_label: Label = Label.new()
			shots_label.text = "Shots: " + str(validated_equipment.get("shots", 0))
			details_container.add_child(shots_label)

			var damage_label: Label = Label.new()
			damage_label.text = "Damage: +" + str(validated_equipment.get("damage", 0))
			details_container.add_child(damage_label)

		"armor":
			var save_label: Label = Label.new()
			save_label.text = "Saving Throw: " + str(validated_equipment.get("save", 0)) + "+"
			details_container.add_child(save_label)

	# Traits
	if validated_equipment.has("traits"):
		var traits_label: Label = Label.new()
		var traits = validated_equipment.get("traits", [])
		if traits is Array and traits.size() > 0:
			traits_label.text = "Traits: " + ", ".join(traits)
			details_container.add_child(traits_label)

func _on_equipment_selected(equipment: Dictionary) -> void:
	## Handle equipment selection
	selected_equipment = equipment
	_update_equipment_details(equipment)
	# Portrait master-detail: bring the Details pane (index 2) forward. No-op in
	# landscape grid mode where all three panes are already side-by-side.
	if _panel_group and _panel_group.has_method("focus_pane"):
		_panel_group.focus_pane(2)

func _on_crew_selected(crew_member: Dictionary) -> void:
	## Handle crew _member selection for equipment assignment
	selected_crew_member = crew_member

	if not selected_equipment.is_empty():
		_assign_equipment_to_crew()

func _assign_equipment_to_crew() -> void:
	## Assign selected equipment to selected crew member
	if selected_equipment.is_empty() or selected_crew_member.is_empty():
		return

	# Add equipment to crew member
	if not selected_crew_member.has("equipment"):
		selected_crew_member["equipment"] = []

	selected_crew_member["equipment"].append(selected_equipment.duplicate())

	# Emit signal
	equipment_assigned.emit(selected_equipment, selected_crew_member)

	# Refresh displays
	_refresh_crew_display()

	# Clear selections
	selected_equipment = {}
	selected_crew_member = {}
	_update_equipment_details({})

	pass # Equipment assigned

func _on_back_pressed() -> void:
	## Handle back button press
	SceneRouter.navigate_back()

func _on_generate_equipment_pressed() -> void:
	## Generate new equipment using tables
	# Implement equipment generation tables
	var dice_mgr = get_node_or_null("/root/DiceManager")
	var new_equipment = _generate_random_equipment(dice_mgr)
	equipment_database.append(new_equipment)
	_refresh_equipment_display()
	pass # New equipment generated

func _generate_random_equipment(dice_mgr) -> Dictionary:
	## Generate random equipment based on tables
	var roll = 0
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		roll = dice_mgr.roll_dice(1, 6)
	else:
		roll = randi_range(1, 6)
	
	match roll:
		1, 2:
			return {"name": "Basic Weapon", "type": "weapon", "range": 12, "shots": 1, "damage": 1, "traits": []}
		3, 4:
			return {"name": "Light Armor", "type": "armor", "save": 6, "traits": []}
		5:
			return {"name": "Tech Gadget", "type": "gadget", "traits": ["Tech"]}
		6:
			return {"name": "Survival Gear", "type": "gear", "traits": ["Utility"]}
		_:
			return {"name": "Mystery Item", "type": "gear", "traits": []}

# ============================================================================
# THE FABRICATED EQUIPMENT ECONOMY WAS DELETED HERE (2026-08-06, audit row 203).
#
# 515 lines implementing a shop and a paid repair service that exist in NEITHER
# rulebook: _calculate_buy_price() with a base of 500 credits, _calculate_sell_
# price() at 60% of buy, _calculate_repair_cost() returning 2500, and Quick
# (+50%) / Quality (+100%) repair tiers, plus the market generator and the
# buy/sell/repair/repair-all handlers behind them.
#
# WHAT THE BOOK ACTUALLY SAYS, and it is short:
#   p.125 "Purchase Items" — "You may pay 3 credits to receive a roll on the
#     Military Weapon Table, Gear Table or Gadget Table"; "You may purchase any
#     number of Hand Guns, Blades, Colony Rifles, or Shotguns for 1 credit
#     each"; "You may sell up to 3 items, earning 1 credit for each."
#   p.78 "Repair Your Kit" — a FREE crew task. 1D6 + Savvy, +1 if an Engineer,
#     "You may spend credits on spare parts. Every 1 credit spent before the
#     roll grants a +1 bonus." There is no repair shop and no repair fee.
#
# This screen is opened from the campaign-creation wizard's "Manual Select"
# button, where a crew is holding single-digit credits — so it was quoting
# 500-2500 credit prices to a player with 4. Deleted rather than rescaled: per
# CLAUDE.md, a mechanic the book does not have is fabricated, and fabricated
# means REMOVE, not rebalance. The correct prices already live in
# PurchaseItemsComponent (3cr per roll / 1cr basics / 1cr sell) and Repair Your
# Kit already lives in CrewTaskComponent; a second, wronger copy next to them is
# the harm.
#
# The assignment half above is untouched: this screen's real job is picking
# equipment for a crew member, which is what "Manual Select" is for.
# ============================================================================


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
