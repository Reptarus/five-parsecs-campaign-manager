@tool
class_name BaseCrewSystem
extends Node

signal crew_changed(crew_data: Dictionary)

var current_crew: Dictionary = {
	"captain": null,
	"crew_members": [],
	"connections": [],
	"ship": null,
	"resources": 0
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_initialize_crew()

func _initialize_crew() -> void:
	if current_crew == null:
		push_error("Failed to initialize crew system - current_crew is null")
		return
	
	current_crew = {
		"captain": null,
		"crew_members": [],
		"connections": [],
		"ship": null,
		"resources": 0,
	}
	
	crew_changed.emit(current_crew)

func add_crew_member(member) -> bool:
	if member == null:
		push_error("Cannot add null crew member")
		return false
		
	if member in current_crew.crew_members:
		push_error("Member already in crew")
		return false
		
	current_crew.crew_members.append(member)
	crew_changed.emit(current_crew)
	return true
	
func remove_crew_member(member) -> bool:
	if member == null:
		push_error("Cannot remove null crew member")
		return false
		
	if not member in current_crew.crew_members:
		push_error("Member not in crew")
		return false
		
	current_crew.crew_members.erase(member)
	crew_changed.emit(current_crew)
	return true
	
func set_captain(captain) -> void:
	current_crew.captain = captain
	crew_changed.emit(current_crew)
	
func add_connection(connection: Dictionary) -> bool:
	if connection.is_empty():
		push_error("Cannot add empty connection")
		return false
		
	current_crew.connections.append(connection)
	crew_changed.emit(current_crew)
	return true
	
func remove_connection(connection_id: String) -> bool:
	for i in range(current_crew.connections.size()):
		if current_crew.connections[i].id == connection_id:
			current_crew.connections.remove_at(i)
			crew_changed.emit(current_crew)
			return true
			
	push_error("Connection not found: " + connection_id)
	return false
	
func set_ship(ship) -> void:
	current_crew.ship = ship
	crew_changed.emit(current_crew)
	
func add_resources(amount: int) -> void:
	current_crew.resources += amount
	crew_changed.emit(current_crew)
	
func remove_resources(amount: int) -> bool:
	if amount > current_crew.resources:
		push_error("Not enough resources")
		return false
		
	current_crew.resources -= amount
	crew_changed.emit(current_crew)
	return true
	
func get_crew_size() -> int:
	return current_crew.crew_members.size() + (1 if current_crew.captain != null else 0)
	
func save_crew() -> Dictionary:
	# Base implementation - to be extended by derived classes
	return current_crew
	
func load_crew(data: Dictionary) -> bool:
	# Base implementation - to be extended by derived classes
	if data.has("captain"):
		current_crew.captain = data.captain
	
	if data.has("crew_members"):
		current_crew.crew_members = data.crew_members
		
	if data.has("connections"):
		current_crew.connections = data.connections
		
	if data.has("ship"):
		current_crew.ship = data.ship
		
	if data.has("resources"):
		current_crew.resources = data.resources
		
	crew_changed.emit(current_crew)
	return true