extends Control

## Bug Hunt Co-op Campaign Map (Compendium pp.209-211) -- opened from BugHuntDashboard.
##
## The shared sector map, as one card per sector: Priority, Factors and conditions (each
## in its data row's own words), any resource stash, cleared or enemy-held, and which
## sectors it borders. Above it, the operational turn: the common Support pool, this
## turn's Sabotage, who has fought, and -- once every player has -- the end of the turn,
## which rolls one Enemy Moves result per player (p.211) and shows the receipt.
##
## p.211: "Typically in an online campaign, one player will manage and update the map as
## they get results sent in." The "record a mission played elsewhere" form is that: a
## player whose squad is on another device reports their Objectives here, and the map
## takes the result through the same core writer the post-battle panel uses.
##
## Presentation only: every rule is BugHuntCoopCampaign's and every write is one of
## BugHuntCampaignCore's co-op wrappers, followed by its persist().
##
## UX floor. This panel extends Control, which has no base _ready() to inherit, so the
## pieces a screen base would add are done here by hand: ScreenChrome.overlay_page() gives
## the page background, the scroll, the side gutter, the Settings-band reservation and a
## TouchScrollOpener keeper; rebuild() opens its own subtree again after every populate.
## There is no footer to pin (Close sits at the top), so no ShortScreenScroll. Columns come
## from ResponsiveManager (BugHuntCoopView.card_columns()), never the viewport rect.

signal closed

const CoopRef := preload("res://src/core/campaign/BugHuntCoopCampaign.gd")
const CoopView := preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")
const CalloutCardRef := preload("res://src/ui/components/common/CalloutCard.gd")
const TapGestureRef := preload("res://src/ui/components/common/TapGesture.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")
const ReceiptCardRef := preload("res://src/ui/components/common/ReceiptCard.gd")

var _campaign: Resource = null
var _column: VBoxContainer = null
var _selected_sector: String = ""
var _last_receipt: Dictionary = {}
var _last_receipt_title: String = ""

# The "mission played elsewhere" form.
var _record_player: OptionButton = null
var _record_sector: OptionButton = null
var _record_objectives: SpinBox = null
var _record_pool: SpinBox = null


func set_campaign(campaign: Resource) -> void:
	_campaign = campaign
	if is_inside_tree() and _column != null:
		rebuild()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = ScreenChrome.overlay_page(self)
	var rm: Node = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		rm.layout_class_changed.connect(_on_layout_class_changed)
	rebuild()


func _on_layout_class_changed(_columns: int) -> void:
	if is_inside_tree():
		rebuild()


## Free and rebuild the whole page from the campaign. Every action here ends in one.
func rebuild() -> void:
	if _column == null:
		return
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_record_player = null
	_record_sector = null
	_record_objectives = null
	_record_pool = null

	_build_header()
	var coop: Dictionary = CoopView.coop_of(_campaign)
	if coop.is_empty():
		_note(_column, "This Bug Hunt campaign is not a co-op campaign. Co-op is chosen when "
			+ "the campaign is created (Compendium pp.209-211).", UIColors.COLOR_TEXT_SECONDARY)
		TouchScrollOpenerRef.open_subtree(self)
		return

	_build_status(coop)
	if not _last_receipt.is_empty():
		_build_receipt_card()
	if not CoopRef.is_campaign_won(coop):
		_build_turn_card(coop)
		_build_record_card(coop)
	_build_sector_grid(coop)
	# §2. Belt-and-braces: overlay_page()'s keeper ALSO opens every Control added under
	# this host (node_added, deferred), and removing this line left the touch sweep green
	# (detection arm G3, 2026-10-29). It opens the page in the same frame instead of the
	# next, and keeps the panel correct if it is ever built without overlay_page().
	TouchScrollOpenerRef.open_subtree(self)


# ── Page sections ─────────────────────────────────────────────────────────────────

func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIColors.SPACING_SM)
	_column.add_child(row)
	var title := Label.new()
	title.text = "Co-op Campaign Map"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_XL))
	title.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	row.add_child(title)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(96, UIColors.TOUCH_TARGET_MIN)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(_on_close)
	row.add_child(close_btn)


func _build_status(coop: Dictionary) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UIColors.SPACING_XS)
	var won: bool = CoopRef.is_campaign_won(coop)
	var total: int = CoopView.sectors(coop).size()
	if won:
		_note(body, "Every sector is cleared -- the co-op campaign is won (%s)." % CoopRef.CITE_MAP,
			UIColors.COLOR_EMERALD)
	_note(body, "Sectors cleared: %d of %d" % [CoopView.cleared_count(coop), total],
		UIColors.COLOR_TEXT_PRIMARY)
	var pool: int = int(coop.get("support_pool", 0))
	_note(body, "Common Support pool: %d point%s. Any player may draw on it for a mission (%s)."
		% [pool, "" if pool == 1 else "s", CoopRef.CITE_BATTLES], UIColors.COLOR_TEXT_PRIMARY)
	var penalty: int = int(coop.get("support_penalty", 0))
	if penalty > 0:
		_note(body, "%s: -%d Support point for every battle this operational turn (%s)."
			% [CoopView.sabotage_name(), penalty, CoopRef.CITE_BATTLES], UIColors.COLOR_AMBER)
	var players: Array = coop.get("players", []) if coop.get("players", []) is Array else []
	var waiting: Array = CoopView.players_to_fight(coop)
	var fought: Array = []
	for p in players:
		if not waiting.has(str(p)):
			fought.append(str(p))
	_note(body, "Players: %s" % ", ".join(players), UIColors.COLOR_TEXT_PRIMARY)
	if not won:
		_note(body, "Fought this turn: %s" % (", ".join(fought) if not fought.is_empty() else "nobody yet"),
			UIColors.COLOR_TEXT_SECONDARY)
	var difficulty: String = str(_campaign.difficulty) if _campaign and "difficulty" in _campaign \
		else ""
	if not difficulty.is_empty():
		_note(body, "Difficulty: %s. %s (%s)" % [difficulty.replace("_", " ").capitalize(),
			CoopView.PREP_DIFFICULTY, CoopView.CITE_PREP], UIColors.COLOR_TEXT_SECONDARY)
	_note(body, "Enemies (%s): %s" % [CoopView.CITE_PREP, CoopView.PREP_ENEMIES],
		UIColors.COLOR_TEXT_SECONDARY)
	var title: String = "Campaign Won" if won \
		else "Operational Turn %d" % int(coop.get("op_turn", 1))
	_add_callout(title, body, UIColors.COLOR_EMERALD if won else UIColors.COLOR_CYAN)


func _build_receipt_card() -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UIColors.SPACING_XS)
	ReceiptCardRef.fill(body, CoopView.receipt_step(_last_receipt, _last_receipt_title,
		CoopRef.CITE_BATTLES), Callable(), 13)
	var card := _add_callout(_last_receipt_title, body,
		UIColors.COLOR_AMBER if bool(_last_receipt.get("ok", false)) else UIColors.COLOR_RED)
	card.name = "CoopReceiptCard"


## p.210/211: the end phase of an operational turn. Offered only when every player has
## fought (or has no sector they may attack), and refused with the reason otherwise.
func _build_turn_card(coop: Dictionary) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UIColors.SPACING_SM)
	var check: Dictionary = CoopView.can_end_turn(coop)
	_note(body, "At the end of each operational turn, Infiltration points act and each player "
		+ "rolls once on the Enemy Moves table (%s)." % CoopRef.CITE_BATTLES,
		UIColors.COLOR_TEXT_SECONDARY)
	if bool(check.get("ok", false)):
		var btn := Button.new()
		btn.name = "EndOperationalTurn"
		btn.text = "End Operational Turn: roll Enemy Moves"
		btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_end_turn)
		body.add_child(btn)
	else:
		_note(body, str(check.get("reason", "")), UIColors.COLOR_TEXT_SECONDARY)
	_add_callout("End of the Operational Turn", body, UIColors.COLOR_AMBER)


## p.211: a mission another player fought on their own device, reported to whoever keeps
## the map. The player whose mission is in flight on THIS device is left out: their result
## comes from the debrief, and recording it twice would refuse the second.
func _build_record_card(coop: Dictionary) -> void:
	var in_flight: String = CoopView.in_flight_player(_campaign)
	var players: Array = []
	for p in CoopView.players_to_fight(coop):
		if str(p) != in_flight and not CoopView.attackable_sector_ids(coop, str(p)).is_empty():
			players.append(str(p))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UIColors.SPACING_SM)
	_note(body, "For a player whose squad fought on another device. %s"
		% CoopView.objectives_rule_text(), UIColors.COLOR_TEXT_SECONDARY)
	if not in_flight.is_empty():
		_note(body, "%s's mission is in progress on this device; it is recorded at its debrief."
			% in_flight, UIColors.COLOR_TEXT_SECONDARY)
	if players.is_empty():
		_note(body, "No other player has a mission to record this operational turn.",
			UIColors.COLOR_TEXT_SECONDARY)
		_add_callout("Record a Mission Played Elsewhere", body, UIColors.COLOR_CYAN)
		return

	_record_player = OptionButton.new()
	_record_player.name = "RecordPlayer"
	_record_player.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	for p in players:
		_record_player.add_item(str(p))
	_record_player.item_selected.connect(func(_i: int) -> void: _fill_record_sectors(coop))
	_labelled(body, "Player", _record_player)

	_record_sector = OptionButton.new()
	_record_sector.name = "RecordSector"
	_record_sector.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_labelled(body, "Sector attacked", _record_sector)
	_fill_record_sectors(coop)

	_record_objectives = SpinBox.new()
	_record_objectives.name = "RecordObjectives"
	_record_objectives.min_value = 0
	_record_objectives.max_value = 99
	_record_objectives.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_labelled(body, "Objectives completed (weighted, as their debrief scored it)",
		_record_objectives)

	var pool: int = int(coop.get("support_pool", 0))
	_record_pool = SpinBox.new()
	_record_pool.name = "RecordPool"
	_record_pool.min_value = 0
	_record_pool.max_value = pool
	_record_pool.editable = pool > 0
	_record_pool.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	_labelled(body, "Support points they drew from the common pool (%d available)" % pool,
		_record_pool)

	var btn := Button.new()
	btn.name = "RecordMission"
	btn.text = "Record Mission on the Map"
	btn.custom_minimum_size.y = UIColors.TOUCH_TARGET_MIN
	btn.pressed.connect(_on_record_pressed)
	body.add_child(btn)
	_add_callout("Record a Mission Played Elsewhere", body, UIColors.COLOR_CYAN)


func _fill_record_sectors(coop: Dictionary) -> void:
	if _record_sector == null or _record_player == null:
		return
	_record_sector.clear()
	var player: String = _record_player.get_item_text(maxi(_record_player.selected, 0)) \
		if _record_player.item_count > 0 else ""
	for sid in CoopView.attackable_sector_ids(coop, player):
		_record_sector.add_item(CoopView.sector_name(coop, str(sid)))
		_record_sector.set_item_metadata(_record_sector.item_count - 1, str(sid))
	# A sector tapped on the map below is preselected when this player may attack it.
	for i in _record_sector.item_count:
		if str(_record_sector.get_item_metadata(i)) == _selected_sector:
			_record_sector.select(i)


func _build_sector_grid(coop: Dictionary) -> void:
	var sectors: Array = CoopView.sectors(coop)
	var heading := Label.new()
	heading.text = "Sectors (%s)" % CoopRef.CITE_MAP
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_LG))
	heading.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	_column.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "SectorGrid"
	grid.columns = CoopView.card_columns(sectors.size())
	grid.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
	grid.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
	_column.add_child(grid)
	for s: Dictionary in sectors:
		var sid: String = str(s.get("id", ""))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", UIColors.SPACING_XS)
		for line in CoopView.sector_lines(coop, sid):
			_note(body, str(line), UIColors.COLOR_TEXT_PRIMARY)
		var color: Color = UIColors.COLOR_EMERALD if bool(s.get("cleared", false)) \
			else UIColors.COLOR_AMBER
		if sid == _selected_sector:
			color = UIColors.COLOR_CYAN
		var card := CalloutCardRef.new()
		card.setup(str(s.get("name", sid)), body, color)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("sector_id", sid)
		TapGestureRef.connect_tap(card, _select_sector.bind(sid))
		grid.add_child(card)


# ── Actions ──────────────────────────────────────────────────────────────────────

func _select_sector(sector_id: String) -> void:
	_selected_sector = "" if _selected_sector == sector_id else sector_id
	rebuild()


func _on_end_turn() -> void:
	_last_receipt = CoopView.end_turn(_campaign)
	_last_receipt_title = "Enemy Moves"
	rebuild()


func _on_record_pressed() -> void:
	if _record_player == null or _record_sector == null or _record_sector.item_count == 0:
		return
	var player: String = _record_player.get_item_text(maxi(_record_player.selected, 0))
	var sector_id: String = str(_record_sector.get_item_metadata(maxi(_record_sector.selected, 0)))
	record_elsewhere(player, sector_id, int(_record_objectives.value),
		int(_record_pool.value) if _record_pool else 0)


## Record another player's mission: their draw from the common pool first (they fought
## with those points), then the battle, then one save. Public so a test drives the same
## path the form does.
func record_elsewhere(player: String, sector_id: String, objectives: int, pool_drawn: int) -> Dictionary:
	if _campaign == null or not _campaign.has_method("record_coop_battle"):
		return {}
	var check: Dictionary = CoopRef.can_attack(CoopView.coop_of(_campaign), sector_id, player)
	var receipt: Dictionary
	if not bool(check.get("ok", false)):
		receipt = {"ok": false, "error": str(check.get("reason", "")), "lines": [], "rolls": []}
	else:
		if pool_drawn > 0 and _campaign.has_method("draw_coop_support"):
			_campaign.draw_coop_support(pool_drawn)
		receipt = _campaign.record_coop_battle(player, sector_id,
			{"objectives_completed": maxi(objectives, 0)})
		if _campaign.has_method("persist"):
			_campaign.persist()
	_last_receipt = receipt
	_last_receipt_title = "Sector Map"
	rebuild()
	return receipt


func _on_close() -> void:
	closed.emit()
	queue_free()


# ── Builders ─────────────────────────────────────────────────────────────────────

func _add_callout(title: String, body: Control, color: Color) -> Control:
	var card := CalloutCardRef.new()
	card.setup(title, body, color)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(card)
	return card


func _note(parent: Control, text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_SM))
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _labelled(parent: Control, text: String, control: Control) -> void:
	var lbl := _note(parent, text, UIColors.COLOR_TEXT_SECONDARY)
	lbl.name = "%sLabel" % control.name
	parent.add_child(control)
