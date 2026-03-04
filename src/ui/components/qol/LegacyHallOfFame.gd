extends ResponsiveContainer
class_name LegacyHallOfFame

## LegacyHallOfFame - Display archived campaigns and achievements
## Hall of Fame for completed campaigns

signal campaign_selected(campaign_id: String)
signal import_veteran_requested(character_id: String)

@onready var campaigns_container = $ScrollContainer/CampaignsContainer

func _ready() -> void:
	_load_hall_of_fame()
	LegacySystem.hall_of_fame_updated.connect(_on_hall_updated)

func _load_hall_of_fame() -> void:
	## Load all archived campaigns
	_clear_container()
	
	var archives = LegacySystem.get_hall_of_fame()
	
	for archive in archives:
		var card = _create_campaign_card(archive)
		campaigns_container.add_child(card)

func _create_campaign_card(archive: Dictionary) -> Control:
	## Create campaign archive card
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	
	# Campaign name/ID
	var name = Label.new()
	name.text = "Campaign: " + archive.campaign_id
	name.add_theme_font_size_override("font_size", 20)
	card.add_child(name)
	
	# Victory status
	var status = Label.new()
	if archive.victory:
		status.text = "🏆 VICTORY - %d Story Points" % archive.story_points
		status.modulate = Color.GOLD
	else:
		status.text = "Campaign Ended - Turn %d" % archive.turns_survived
	card.add_child(status)
	
	# Achievements
	if archive.has("achievements") and not archive.achievements.is_empty():
		var achievements = Label.new()
		achievements.text = "⭐ " + ", ".join(archive.achievements)
		card.add_child(achievements)
	
	# Crew count
	var crew_info = Label.new()
	crew_info.text = "Crew: %d members" % archive.get("crew", []).size()
	card.add_child(crew_info)
	
	# Action buttons
	var actions = HBoxContainer.new()
	
	var view_button = Button.new()
	view_button.text = "View Full History"
	view_button.pressed.connect(func(): campaign_selected.emit(archive.campaign_id))
	actions.add_child(view_button)
	
	var import_button = Button.new()
	import_button.text = "Import as NPCs"
	import_button.pressed.connect(func(): _import_campaign_crew(archive))
	actions.add_child(import_button)
	
	card.add_child(actions)
	
	return card

func _import_campaign_crew(archive: Dictionary) -> void:
	## Import crew from archived campaign
	# NOTE: Deferred — open character selection dialog for crew import
	pass

func _clear_container() -> void:
	## Clear campaigns container
	if not campaigns_container:
		return
	for child in campaigns_container.get_children():
		child.queue_free()

func _on_hall_updated() -> void:
	_load_hall_of_fame()
