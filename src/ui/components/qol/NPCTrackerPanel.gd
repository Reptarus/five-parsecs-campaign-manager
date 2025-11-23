extends ResponsiveContainer
class_name NPCTrackerPanel

## NPCTrackerPanel - NPC relationship and history UI
## Displays patrons, rivals, and locations

signal npc_selected(npc_id: String, npc_type: String)

@onready var tab_container = $TabContainer
@onready var patrons_tab = $TabContainer/Patrons
@onready var rivals_tab = $TabContainer/Rivals
@onready var locations_tab = $TabContainer/Locations

func _ready() -> void:
	_load_data()
	NPCTracker.patron_interaction.connect(_on_patron_interaction)
	NPCTracker.rival_encounter.connect(_on_rival_encounter)
	NPCTracker.location_visited.connect(_on_location_visited)

func _load_data() -> void:
	"""Load all NPC data"""
	_load_patrons()
	_load_rivals()
	_load_locations()

func _load_patrons() -> void:
	"""Load patron list"""
	if not patrons_tab:
		return
	
	for patron in NPCTracker.get_all_patrons():
		var card = _create_patron_card(patron)
		patrons_tab.add_child(card)

func _load_rivals() -> void:
	"""Load rival list"""
	if not rivals_tab:
		return
	
	for rival in NPCTracker.get_all_rivals():
		var card = _create_rival_card(rival)
		rivals_tab.add_child(card)

func _load_locations() -> void:
	"""Load location list"""
	if not locations_tab:
		return
	
	for location in NPCTracker.get_all_locations():
		var card = _create_location_card(location)
		locations_tab.add_child(card)

func _create_patron_card(patron: Dictionary) -> Control:
	"""Create patron info card"""
	var card = VBoxContainer.new()
	
	var name = Label.new()
	name.text = patron.name
	card.add_child(name)
	
	var relationship = Label.new()
	relationship.text = "Relationship: %d/5" % patron.relationship
	card.add_child(relationship)
	
	var jobs = Label.new()
	jobs.text = "Jobs: %d completed, %d failed" % [patron.jobs_completed, patron.jobs_failed]
	card.add_child(jobs)
	
	return card

func _create_rival_card(rival: Dictionary) -> Control:
	"""Create rival info card"""
	var card = VBoxContainer.new()
	
	var name = Label.new()
	name.text = rival.name
	card.add_child(name)
	
	var encounters = Label.new()
	encounters.text = "Encounters: %d (W:%d L:%d)" % [rival.encounters, rival.victories, rival.defeats]
	card.add_child(encounters)
	
	return card

func _create_location_card(location: Dictionary) -> Control:
	"""Create location info card"""
	var card = VBoxContainer.new()
	
	var name = Label.new()
	name.text = location.name
	card.add_child(name)
	
	var visits = Label.new()
	visits.text = "Visits: %d" % location.visits
	card.add_child(visits)
	
	return card

func _on_patron_interaction(patron_id: String, event_type: String) -> void:
	_load_patrons()

func _on_rival_encounter(rival_id: String, battle_result: String) -> void:
	_load_rivals()

func _on_location_visited(location_id: String, visit_count: int) -> void:
	_load_locations()
