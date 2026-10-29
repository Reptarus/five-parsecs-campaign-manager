class_name RulesHelpText
extends RefCounted

## Help text for the two World Phase steps that carry their own "?" button:
## Upkeep (UpkeepPhaseComponent) and Crew Tasks (CrewTaskComponent). Every other
## screen's help reads data/help_context_map.json and the user guide.
##
## This file used to hold 35 topics and get_short_hint(). Only these two were ever
## shown; the other 33 and get_short_hint() had no caller. Nine topics carried a
## literal "pass" line inside the player-facing text, including Crew Tasks, which a
## player could open. They were removed in Sprint 6 (F6-11) rather than wired,
## because the user guide already covers those steps.

# Core Rules p.76, Upkeep and Ship Repairs.
const UPKEEP_PHASE := """[b]Upkeep[/b]
Each campaign turn you must pay Upkeep for your crew.
• [color=#F59E0B]1 credit[/color] if you have 4-6 crew
• [color=#F59E0B]+1 credit[/color] per crew member past 6
• Crew in Sick Bay don't count toward Upkeep
• You may sell equipment to pay: each item sold covers 1 credit
• For each credit you are short, one crew member refuses to do any jobs this turn
[i](Core Rules p.76)[/i]"""

# Core Rules pp.76-78, Assign and Resolve Crew Tasks.
const CREW_TASKS_OVERVIEW := """[b]Crew Tasks[/b]
Each crew member that isn't in Sick Bay can take on one task. You may assign up to two characters to any one task, or leave a character on the ship.
• [color=#4FC3F7]Find a Patron[/color] - Go look for someone to hire the crew
• [color=#4FC3F7]Train[/color] - Earn 1 XP
• [color=#4FC3F7]Trade[/color] - Roll on the Trade Table (p.79)
• [color=#4FC3F7]Recruit[/color] - Expand your crew
• [color=#4FC3F7]Explore[/color] - Roll on the Exploration Table (p.80)
• [color=#4FC3F7]Track[/color] - Look for a Rival
• [color=#4FC3F7]Repair Your Kit[/color] - Repair broken items
• [color=#4FC3F7]Decoy[/color] - +1 to the roll to see if Rivals track you down
[i](Core Rules pp.76-78)[/i]"""


static func get_tooltip(key: String) -> String:
	match key:
		"upkeep_phase": return UPKEEP_PHASE
		"crew_tasks": return CREW_TASKS_OVERVIEW
		_:
			push_warning("RulesHelpText: Unknown tooltip key '%s'" % key)
			return "[i]No help text available[/i]"
