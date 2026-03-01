@tool
extends Node
class_name ContactManager

## Contact Management System for Five Parsecs Campaign Manager
## Handles NPC contacts, relationships, and world-specific interactions

# Safe imports
# GlobalEnums available as autoload singleton

## Contact data structure
class Contact:
	var id: String
	var name: String
	var contact_type: String  # "PATRON", "TRADER", "INFORMANT", "OFFICIAL", "CRIMINAL"
	var planet_id: String
	var reputation: int = 0  # -3 to +3 relationship scale
	var discovery_turn: int = 0
	var last_interaction_turn: int = -1
	var services_available: Array[String] = []
	var special_traits: Array[String] = []
	var interaction_history: Array[Dictionary] = []
	
	func _init(contact_id: String = "", contact_name: String = "", type: String = ""):
		id = contact_id if contact_id != "" else "contact_" + str(Time.get_unix_time_from_system())
		name = contact_name
		contact_type = type
		
	func serialize() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"contact_type": contact_type,
			"planet_id": planet_id,
			"reputation": reputation,
			"discovery_turn": discovery_turn,
			"last_interaction_turn": last_interaction_turn,
			"services_available": services_available,
			"special_traits": special_traits,
			"interaction_history": interaction_history
		}
	
	func deserialize(data: Dictionary) -> void:
		id = data.get("id", "")
		name = data.get("name", "")
		contact_type = data.get("contact_type", "")
		planet_id = data.get("planet_id", "")
		reputation = data.get("reputation", 0)
		discovery_turn = data.get("discovery_turn", 0)
		last_interaction_turn = data.get("last_interaction_turn", -1)
		services_available = data.get("services_available", [])
		special_traits = data.get("special_traits", [])
		interaction_history = data.get("interaction_history", [])

## Contact Manager Signals
signal contact_discovered(contact: Contact)
signal contact_reputation_changed(contact_id: String, old_reputation: int, new_reputation: int)
signal contact_interaction_completed(contact_id: String, interaction_type: String, result: Dictionary)

## Data storage
var contacts_by_planet: Dictionary = {}  # planet_id -> Array[Contact]
var contacts_by_id: Dictionary = {}      # contact_id -> Contact
var current_planet_id: String = ""

func _ready() -> void:
	print("ContactManager: Initialized successfully")

## Add a new contact to the current planet
func add_contact(contact_name: String, contact_type: String, planet_id: String = "", discovery_turn: int = 0) -> Contact:
	var contact = Contact.new("", contact_name, contact_type)
	contact.planet_id = planet_id if planet_id != "" else current_planet_id
	contact.discovery_turn = discovery_turn
	
	# Add to storage
	if not contacts_by_planet.has(contact.planet_id):
		contacts_by_planet[contact.planet_id] = []
	contacts_by_planet[contact.planet_id].append(contact)
	contacts_by_id[contact.id] = contact
	
	# Generate starting services based on type
	_generate_contact_services(contact)
	
	print("ContactManager: Added contact %s (%s) to planet %s" % [contact.name, contact.contact_type, contact.planet_id])
	self.contact_discovered.emit(contact)
	
	return contact

## Generate services available from a contact based on their type
func _generate_contact_services(contact: Contact) -> void:
	match contact.contact_type:
		"PATRON":
			contact.services_available = ["hire_jobs", "equipment_access", "information"]
		"TRADER":
			contact.services_available = ["buy_equipment", "sell_equipment", "rare_items"]
		"INFORMANT":
			contact.services_available = ["rumors", "rival_locations", "mission_intel"]
		"OFFICIAL":
			contact.services_available = ["permits", "legal_assistance", "bounty_postings"]
		"CRIMINAL":
			contact.services_available = ["black_market", "smuggling_jobs", "illegal_mods"]
		_:
			contact.services_available = ["basic_services"]

## Find contacts on a specific planet
func get_contacts_on_planet(planet_id: String) -> Array[Contact]:
	var planet_contacts: Array[Contact] = []
	if contacts_by_planet.has(planet_id):
		for contact in contacts_by_planet[planet_id]:
			planet_contacts.append(contact)
	return planet_contacts

## Get all contacts of a specific type
func get_contacts_by_type(contact_type: String) -> Array[Contact]:
	var typed_contacts: Array[Contact] = []
	for contact in contacts_by_id.values():
		if contact.contact_type == contact_type:
			typed_contacts.append(contact)
	return typed_contacts

## Get available patrons (contacts with positive reputation)
func get_available_patrons() -> Array[Contact]:
	var patrons: Array[Contact] = []
	for contact in get_contacts_on_planet(current_planet_id):
		if contact.contact_type == "PATRON" and contact.reputation >= 0:
			patrons.append(contact)
	return patrons

## Interact with a contact
func interact_with_contact(contact_id: String, interaction_type: String, turn_number: int = 0) -> Dictionary:
	if not contacts_by_id.has(contact_id):
		return {"success": false, "error": "Contact not found"}
	
	var contact = contacts_by_id[contact_id]
	contact.last_interaction_turn = turn_number
	
	var result = _process_contact_interaction(contact, interaction_type)
	
	# Record interaction
	var interaction_record = {
		"turn": turn_number,
		"type": interaction_type,
		"result": result,
		"reputation_change": result.get("reputation_change", 0)
	}
	contact.interaction_history.append(interaction_record)
	
	# Apply reputation changes
	if result.has("reputation_change"):
		modify_contact_reputation(contact_id, result.reputation_change)
	
	self.contact_interaction_completed.emit(contact_id, interaction_type, result)
	
	return result

## Process specific contact interactions
func _process_contact_interaction(contact: Contact, interaction_type: String) -> Dictionary:
	var result = {"success": false, "message": "Unknown interaction"}
	
	match interaction_type:
		"hire_job":
			if contact.contact_type == "PATRON" and contact.reputation >= 0:
				result = _generate_patron_job(contact)
		"buy_equipment":
			if contact.contact_type == "TRADER":
				result = _generate_equipment_offer(contact)
		"get_rumor":
			if contact.contact_type == "INFORMANT" and contact.reputation >= -1:
				result = _generate_rumor(contact)
		"get_permit":
			if contact.contact_type == "OFFICIAL" and contact.reputation >= 0:
				result = _generate_permit(contact)
		"black_market":
			if contact.contact_type == "CRIMINAL" and contact.reputation >= -1:
				result = _generate_black_market_offer(contact)
		_:
			result = {"success": false, "message": "Invalid interaction type for this contact"}
	
	return result

## Generate a job from a patron
func _generate_patron_job(contact: Contact) -> Dictionary:
	var job_types = ["escort", "salvage", "delivery", "patrol", "investigation"]
	var job_type = job_types[randi() % job_types.size()]
	
	var base_payment = 6 + contact.reputation + randi_range(-2, 2)
	var danger_pay = randi_range(0, 3)
	
	return {
		"success": true,
		"job_type": job_type,
		"payment": max(3, base_payment),
		"danger_pay": danger_pay,
		"patron_id": contact.id,
		"message": "Job offer from %s: %s mission" % [contact.name, job_type],
		"reputation_change": 0
	}

## Generate equipment offer from trader
func _generate_equipment_offer(contact: Contact) -> Dictionary:
	var equipment_types = ["weapon", "armor", "gear", "consumable"]
	var equipment_type = equipment_types[randi() % equipment_types.size()]
	
	var cost = 3 + randi_range(0, 5) - contact.reputation
	
	return {
		"success": true,
		"equipment_type": equipment_type,
		"cost": max(1, cost),
		"message": "Equipment available from %s" % contact.name,
		"reputation_change": 0
	}

## Generate rumor from informant
func _generate_rumor(contact: Contact) -> Dictionary:
	var rumor_types = ["quest_clue", "rival_location", "treasure_location", "danger_warning"]
	var rumor_type = rumor_types[randi() % rumor_types.size()]
	
	return {
		"success": true,
		"rumor_type": rumor_type,
		"rumor_value": 1 + (contact.reputation if contact.reputation > 0 else 0),
		"message": "Rumor obtained from %s: %s" % [contact.name, rumor_type],
		"reputation_change": 0
	}

## Generate permit from official
func _generate_permit(contact: Contact) -> Dictionary:
	var permit_types = ["trade_license", "exploration_permit", "weapon_permit", "travel_pass"]
	var permit_type = permit_types[randi() % permit_types.size()]
	
	var cost = 2 + randi_range(0, 3) - contact.reputation
	
	return {
		"success": true,
		"permit_type": permit_type,
		"cost": max(1, cost),
		"message": "Permit available from %s: %s" % [contact.name, permit_type],
		"reputation_change": 0
	}

## Generate black market offer
func _generate_black_market_offer(contact: Contact) -> Dictionary:
	var offer_types = ["illegal_weapon", "stolen_goods", "smuggling_job", "forged_documents"]
	var offer_type = offer_types[randi() % offer_types.size()]
	
	return {
		"success": true,
		"offer_type": offer_type,
		"risk_level": randi_range(1, 3),
		"message": "Black market offer from %s: %s" % [contact.name, offer_type],
		"reputation_change": 0
	}

## Modify contact reputation
func modify_contact_reputation(contact_id: String, change: int) -> void:
	if not contacts_by_id.has(contact_id):
		return
	
	var contact = contacts_by_id[contact_id]
	var old_reputation = contact.reputation
	contact.reputation = clamp(contact.reputation + change, -3, 3)
	
	if contact.reputation != old_reputation:
		print("ContactManager: %s reputation changed from %d to %d" % [contact.name, old_reputation, contact.reputation])
		self.contact_reputation_changed.emit(contact_id, old_reputation, contact.reputation)

## Set current planet for contact operations
func set_current_planet(planet_id: String) -> void:
	current_planet_id = planet_id
	print("ContactManager: Current planet set to %s" % planet_id)

## Get contact by ID
func get_contact(contact_id: String) -> Contact:
	return contacts_by_id.get(contact_id, null)

## Check if contact is available for interaction
func is_contact_available(contact_id: String, interaction_type: String) -> bool:
	var contact = get_contact(contact_id)
	if not contact:
		return false
	
	# Check if contact has required service
	match interaction_type:
		"hire_job":
			return contact.contact_type == "PATRON" and "hire_jobs" in contact.services_available
		"buy_equipment":
			return contact.contact_type == "TRADER" and "buy_equipment" in contact.services_available
		"get_rumor":
			return contact.contact_type == "INFORMANT" and "rumors" in contact.services_available
		_:
			return true

## Generate random contact for planet
func generate_random_contact(planet_id: String, turn_number: int = 0) -> Contact:
	var contact_types = ["PATRON", "TRADER", "INFORMANT", "OFFICIAL", "CRIMINAL"]
	var contact_type = contact_types[randi() % contact_types.size()]
	
	var names_by_type = {
		"PATRON": ["Director Chen", "Captain Hayes", "Administrator Voss", "Executive Martinez"],
		"TRADER": ["Merchant Singh", "Dealer O'Brien", "Vendor Klaus", "Broker Tanaka"],
		"INFORMANT": ["Whisper", "The Source", "Network", "Intel"],
		"OFFICIAL": ["Inspector Reynolds", "Commissioner Wright", "Magistrate Torres"],
		"CRIMINAL": ["Shadow", "The Fence", "Black Jack", "Void Runner"]
	}
	
	var names = names_by_type.get(contact_type, ["Unknown Contact"])
	var contact_name = names[randi() % names.size()]
	
	return add_contact(contact_name, contact_type, planet_id, turn_number)

## Serialize all contact data
func serialize_all() -> Dictionary:
	var serialized_contacts = {}
	for contact_id in contacts_by_id:
		serialized_contacts[contact_id] = contacts_by_id[contact_id].serialize()
	
	return {
		"contacts": serialized_contacts,
		"contacts_by_planet": _serialize_contacts_by_planet(),
		"current_planet_id": current_planet_id
	}

func _serialize_contacts_by_planet() -> Dictionary:
	var serialized = {}
	for planet_id in contacts_by_planet:
		var contact_ids = []
		for contact in contacts_by_planet[planet_id]:
			contact_ids.append(contact.id)
		serialized[planet_id] = contact_ids
	return serialized

## Deserialize contact data
func deserialize_all(data: Dictionary) -> void:
	contacts_by_id.clear()
	contacts_by_planet.clear()
	
	var contacts_data = data.get("contacts", {})
	for contact_id in contacts_data:
		var contact = Contact.new()
		contact.deserialize(contacts_data[contact_id])
		contacts_by_id[contact_id] = contact
	
	# Rebuild contacts_by_planet
	var planet_data = data.get("contacts_by_planet", {})
	for planet_id in planet_data:
		contacts_by_planet[planet_id] = []
		for contact_id in planet_data[planet_id]:
			if contacts_by_id.has(contact_id):
				contacts_by_planet[planet_id].append(contacts_by_id[contact_id])
	
	current_planet_id = data.get("current_planet_id", "")

## Get debug info
func get_debug_info() -> Dictionary:
	return {
		"total_contacts": contacts_by_id.size(),
		"planets_with_contacts": contacts_by_planet.size(),
		"current_planet": current_planet_id,
		"contacts_on_current_planet": get_contacts_on_planet(current_planet_id).size()
	}

