extends Resource
  
signal mission_completed

# Handle complete method if not available
func complete():
	set("_completed", true)
	emit_signal("mission_completed")
	return true

# Handle is_completed method if not available
func is_completed():
	if "_completed" in self:
		return get("_completed")
	return false
