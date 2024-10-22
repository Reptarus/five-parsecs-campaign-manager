extends PanelContainer

@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var class_label = $MarginContainer/VBoxContainer/ClassLabel
@onready var stats_container = $MarginContainer/VBoxContainer/StatsContainer
@onready var health_bar = $MarginContainer/VBoxContainer/HealthBar

func update_display(crew_member: CrewMember) -> void:
	if not crew_member:
		push_error("Attempted to update display with null crew member")
		return
	
	name_label.text = crew_member.name
	class_label.text = str(crew_member.get("class_type"))
	
	# Update stats
	var stats_text = "Combat: %d  Tech: %d\nSocial: %d  Survival: %d" % [
		crew_member.combat,
		crew_member.technical,
		crew_member.social,
		crew_member.survival
	]
	stats_container.text = stats_text
	
	# Update health bar
	health_bar.max_value = crew_member.max_health
	health_bar.value = crew_member.health
