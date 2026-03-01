# Event Effects Quick Reference

**Purpose**: Quick lookup for event effect testing and validation
**Last Updated**: 2025-11-29

## Campaign Events (25 total)

| Event Title | Roll Range | Effect | Game State Change |
|-------------|-----------|--------|-------------------|
| Friendly Doc | 1-3 | Reduce recovery time (2 crew) | `injury_recovery_turns -= 1` |
| Life Support Issues | 4-8 | Pay 1D6 credits (Engineer -1) | `credits -= 1D6` |
| New Ally | 9-12 | +1 Story Point | `story_points += 1` |
| Local Friends | 13-16 | +1 Story Point | `story_points += 1` |
| Mouthed Off | 17-20 | +1 Rival | `campaign.rivals.append()` |
| Gambling Opportunity | 21-24 | Bet 1-6 credits (interactive) | Variable |
| Trade Opportunity | 25-28 | Roll twice on Trade Table | Market bonus |
| Odd Job | 29-32 | Crew unavailable, 1D6+1 credits | `credits += 1D6+1` |
| Bar Brawl | 33-36 | Random crew injured (1 turn) | `injury_recovery_turns = 1` |
| Old Contact | 37-40 | +1 Rumor | `campaign.rumors.append()` |
| Valuable Find | 41-44 | 1D6 credits | `credits += 1D6` |
| Equipment Malfunction | 45-48 | Random item damaged | Equipment damage flag |
| Reputation Grows | 49-52 | +1 Patron search roll | Modifier flag |
| Suspicious Activity | 53-56 | Rival tracks crew (if has rivals) | Rival event trigger |
| Market Surplus | 57-60 | All purchases -1 credit (min 1) | Market modifier |
| Skill Training | 61-64 | Random crew +1 XP | `crew[random].experience += 1` |
| Information Broker | 65-68 | Buy rumors (2 credits each) | Interactive |
| Ship Parts | 69-72 | Repair 1 Hull Point free | `hull_points += 1` |
| Medical Supplies | 73-76 | 1 crew recovers immediately | `injury_recovery_turns = 0` |
| Cargo Opportunity | 77-80 | +3 credits, cannot travel | `credits += 3`, travel blocked |
| Unexpected Bill | 81-84 | Pay 1D6 or lose 1 Story Point | `credits -= 1D6` OR `story_points -= 1` |
| Lucky Break | 85-88 | +1 Story Point | `story_points += 1` |
| Crew Bonding | 89-92 | All crew +1 XP | `all_crew.experience += 1` |
| Dangerous Information | 93-96 | +2 Rumors, +1 Rival | `rumors += 2`, `rivals += 1` |
| Windfall | 97-100 | 2D6 credits | `credits += 2D6` |

## Character Events (20 total)

| Event Title | Roll Range | Effect | Game State Change |
|-------------|-----------|--------|-------------------|
| Focused Training | 1-5 | +1 Combat Skill XP | `character.experience += 1` |
| Technical Study | 6-10 | +1 Savvy XP | `character.experience += 1` |
| Physical Training | 11-15 | +1 Toughness XP | `character.experience += 1` |
| Old Friend | 16-20 | +1 Story Point | `story_points += 1` |
| Bad Dreams | 21-25 | -1 next combat roll | Combat modifier |
| Gambling | 26-30 | Roll D6 (1-2 lose, 3-4 even, 5-6 win) | Variable credits |
| Bar Fight | 31-35 | Roll D6 (1-3 injured, 4-6 respect) | `injury_recovery_turns` OR reputation |
| Found Item | 36-40 | Random gear added to stash | `ship_stash.append()` |
| Made Contact | 41-45 | +1 Patron search | Patron modifier |
| Personal Growth | 46-50 | +2 XP | `character.experience += 2` |
| Equipment Care | 51-55 | Repair damaged item | Equipment repair |
| Side Job | 56-60 | 1D6 credits | `credits += 1D6` |
| Wound Heals | 61-65 | Recovery time -1 turn | `injury_recovery_turns -= 1` |
| Made Enemy | 66-70 | +1 Rival (personalized) | `campaign.rivals.append()` |
| Valuable Intel | 71-75 | +1 Rumor | `campaign.rumors.append()` |
| Trait Development | 76-80 | Gain random positive trait | Character trait array |
| Equipment Lost | 81-85 | Random item lost | Equipment removal |
| Unexpected Windfall | 86-90 | 2D6 credits | `credits += 2D6` |
| Moment of Glory | 91-95 | +1 Story Point, +1 XP | `story_points += 1`, `experience += 1` |
| Life-Changing Event | 96-100 | Reroll Motivation | Character motivation change |

## Testing Quick Commands

### Test Campaign Events
```gdscript
# In CampaignEventComponent
1. Click "Roll" button
2. Verify event title displays
3. Click "Resolve" button
4. Check green "Result:" text appears
5. Verify game state changed (credits, story points, etc.)
```

### Test Character Events
```gdscript
# In CharacterEventComponent
1. Verify character name shown
2. Click "Roll" button
3. Verify event title displays with character name
4. Click "Resolve" button
5. Check green "Result:" text with character name
6. Verify character XP or game state changed
```

### Verify Effect Application
```gdscript
# Check console output
print("CampaignEventComponent: <effect description>")
print("PostBattlePhase: <effect applied>")

# Check UI
event_effect_label.text == "Result: <effect>"
event_effect_label.modulate == Color(0.5, 1.0, 0.5)  # Green
```

## Common Effect Patterns

### Credits Effects
```gdscript
# Gain credits
GameStateManager.add_credits(amount)

# Lose credits
GameStateManager.add_credits(-amount)

# Conditional (Unexpected Bill)
if credits >= cost:
    add_credits(-cost)
else:
    add_story_points(-1)
```

### XP Effects
```gdscript
# Single character
character["experience"] = character.get("experience", 0) + amount

# Random crew
crew[random_index]["experience"] += amount

# All crew
for member in crew:
    member["experience"] += amount
```

### Rumor Effects
```gdscript
campaign["rumors"].append({
    "id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi()],
    "type": randi_range(1, 5),
    "description": rumor_types[roll],
    "source": "event"
})
```

### Rival Effects
```gdscript
campaign["rivals"].append({
    "id": "rival_%d_%d" % [Time.get_ticks_msec(), randi()],
    "name": "Enemy Name",
    "type": ["Criminal", "Corporate", "Personal", "Gang"][randi() % 4],
    "hostility": randi_range(3, 5),
    "resources": randi_range(1, 3),
    "source": "event"
})
```

### Injury/Recovery Effects
```gdscript
# Injure crew
character["injury_recovery_turns"] = turns

# Reduce recovery time
character["injury_recovery_turns"] = max(0, character["injury_recovery_turns"] - amount)

# Immediate recovery
character["injury_recovery_turns"] = 0
```

## Expected Console Output

### Campaign Event Resolution
```
CampaignEventComponent: Rolled 45 - Equipment Malfunction
CampaignEventComponent: Event resolved - Equipment Malfunction (Random item damaged)
PostBattlePhase: Random item damaged
```

### Character Event Resolution
```
CharacterEventComponent: Selected Marcus Kane for character event
CharacterEventComponent: Marcus Kane rolled 48 - Personal Growth
CharacterEventComponent: Event resolved for Marcus Kane - Personal Growth (Marcus Kane gained +2 XP)
PostBattlePhase: Marcus Kane gained +2 XP
```

## Verification Checklist

### Per Event Type
- [ ] Event title displays correctly
- [ ] Effect description shows in UI
- [ ] Green "Result:" text appears after resolution
- [ ] Console shows effect application
- [ ] Game state changes (check credits/XP/etc in dashboard)
- [ ] Effect persists across UI refreshes

### Edge Cases
- [ ] Event with no eligible crew (should not crash)
- [ ] Full ship stash (equipment events should notify)
- [ ] Insufficient credits (Unexpected Bill uses Story Point)
- [ ] Character events on injured crew (recovery time updates)
- [ ] Multiple events in sequence (no data corruption)

## Debug Tips

### Check PostBattlePhase Availability
```gdscript
var post_battle = get_node_or_null("/root/PostBattlePhase")
if post_battle:
    print("PostBattlePhase found")
else:
    print("Using fallback - check autoload")
```

### Verify Effect Methods Exist
```gdscript
if post_battle.has_method("apply_campaign_event_effect"):
    print("Campaign event handler available")
if post_battle.has_method("apply_character_event_effect"):
    print("Character event handler available")
```

### Check Event Data Structure
```gdscript
print("Current event: ", current_event)
# Should have: title, description, effect fields
print("Event title: ", current_event.get("title", "MISSING"))
```

---

**Usage**: Keep this reference open during manual testing to quickly verify expected behaviors.
