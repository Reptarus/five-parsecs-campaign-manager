class_name TacticsRoster
extends Resource

## TacticsRoster - A player's complete Tactics army roster
## Replaces AoF ArmyList: 500/750/1000 pts, platoon/company org.
## Drops AoF hero-per-375, 35% cap, duplicate limit, combined units.
## Validation delegated to TacticsCompositionValidator.
## Source: Five Parsecs: Tactics army building rules pp.81-88

enum OrgType {
	PLATOON,        # Single platoon (~500 pts)
	COMPANY,        # 2-4 platoons (~750-1000 pts)
}

# Roster Identity
@export var roster_name: String = ""
@export var roster_id: String = ""
@export var points_limit: int = 500

# Organization
@export var org_type: OrgType = OrgType.PLATOON
@export var platoon_count: int = 1

# Species book this roster is built from
var species_book: TacticsSpeciesBook = null

# Units in the roster
var entries: Array = []  # Array of TacticsRosterEntry


## Get total points cost of all entries
func get_total_points() -> int:
	var total: int = 0
	for entry in entries:
		if entry is TacticsRosterEntry:
			total += entry.get_total_cost()
	return total


## Get remaining points budget
func get_remaining_points() -> int:
	return points_limit - get_total_points()


## Add an entry to the roster
func add_entry(entry: TacticsRosterEntry) -> void:
	if entry.entry_id.is_empty():
		entry.entry_id = _generate_entry_id()
	entries.append(entry)


## Remove an entry by index
func remove_entry(index: int) -> void:
	if index >= 0 and index < entries.size():
		entries.remove_at(index)


## Remove an entry by ID
func remove_entry_by_id(entry_id: String) -> bool:
	for i in range(entries.size()):
		var entry: TacticsRosterEntry = entries[i] as TacticsRosterEntry
		if entry and entry.entry_id == entry_id:
			entries.remove_at(i)
			return true
	return false


## Get entries for a specific platoon
func get_entries_for_platoon(platoon_idx: int) -> Array:
	var result: Array = []
	for entry in entries:
		if entry is TacticsRosterEntry and entry.platoon_index == platoon_idx:
			result.append(entry)
	return result


## Get entries by org slot
func get_entries_by_slot(slot: int) -> Array:
	var result: Array = []
	for entry in entries:
		if entry is TacticsRosterEntry and entry.get_org_slot() == slot:
			result.append(entry)
	return result


## Count entries by org slot within a platoon
func count_slot_in_platoon(slot: int, platoon_idx: int) -> int:
	var count: int = 0
	for entry in entries:
		if entry is TacticsRosterEntry and entry.platoon_index == platoon_idx:
			if entry.get_org_slot() == slot:
				count += 1
	return count


## Get species ID from book
func get_species_id() -> String:
	if species_book:
		return species_book.get_species_id()
	return ""


## Get summary for UI display
func get_summary() -> String:
	var parts: Array[String] = []
	if species_book:
		parts.append(species_book.get_species_name())
	if not roster_name.is_empty():
		parts.append('"%s"' % roster_name)
	parts.append("%d units" % entries.size())
	parts.append("%d / %dpts" % [get_total_points(), points_limit])
	parts.append(OrgType.keys()[org_type].capitalize())
	return ", ".join(parts)


## Serialize to dictionary (for save files)
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"roster_id": roster_id,
		"roster_name": roster_name,
		"points_limit": points_limit,
		"org_type": OrgType.keys()[org_type].to_lower(),
		"platoon_count": platoon_count,
	}
	if species_book:
		data["species_id"] = species_book.get_species_id()

	var entry_list: Array = []
	for entry in entries:
		if entry is TacticsRosterEntry:
			entry_list.append(entry.to_dict())
	data["entries"] = entry_list

	return data


func _generate_entry_id() -> String:
	return "entry_%d_%d" % [entries.size(), randi() % 10000]
