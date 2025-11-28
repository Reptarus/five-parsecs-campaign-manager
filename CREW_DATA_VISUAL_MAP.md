# CrewPanel Data Structures - Visual Flow Map

## CURRENT BROKEN STATE

```
    _on_character_generated()
            |
            v
    local_crew_data.members <---- CHARACTER DATA DICT
            |
            +---> crew_members <---- CHARACTER OBJECT
            |
            v (used by validation, display)
    Current state: BOTH SYNCED (1 path)


    add_crew_member(member)
            |
            v
    crew_members <---- ADD HERE (line 123)
            |
            X (NOT updated)
            v
    local_crew_data.members <---- MISSING UPDATE!
    
    Current state: OUT OF SYNC


    clear_crew()
            |
            v
    crew_members.clear() <---- CLEARED (line 640)
            |
            X (NOT updated)
            v
    local_crew_data.members <---- STILL HAS OLD DATA!
    
    Current state: OUT OF SYNC


    set_captain(character)
            |
            v
    current_captain <---- UPDATED (line 653)
            |
            X (NOT updated)
            v
    local_crew_data.captain <---- MISSING UPDATE!
    
    Current state: OUT OF SYNC


    remove_crew_member(member)
            |
            v
    crew_members.erase() <---- REMOVED (line 678)
            |
            X (NOT updated)
            v
    local_crew_data.members <---- STILL HAS OLD MEMBER!
    
    Current state: OUT OF SYNC
```

---

## DESIRED UNIFIED STATE

```
                        Single Source of Truth
                    (local_crew_data: Dictionary)
                            /    |    \
                           /     |     \
                          /      |      \
                         v       v       v
                    .members   .captain  .patrons
                     (Array)   (Object)  (Array)
                         |
                         v
                  All writes funnel here!
    
    add_crew_member()  ---------->  local_crew_data.members.append()
    remove_crew_member()  -------->  local_crew_data.members.erase()
    clear_crew()  ----------------->  local_crew_data.members.clear()
    set_captain()  ----------------->  local_crew_data.captain = value
    
    For reads, create accessors:
    
    crew_members[i]  ---------->  local_crew_data.members[i]["character_object"]
    crew_members.size()  ------->  local_crew_data.members.size()
```

---

## DATA STRUCTURE HIERARCHY

### Level 1: External Interface (What external code sees)
```
GameStateManager
    ^
    |
    | reads/writes
    |
CampaignFinalizationService
    ^
    |
    | reads
    |
CampaignCreationCoordinator
    ^
    |
    | reads/writes
    |
CrewPanel.get_panel_data()  ------>  local_crew_data
```

### Level 2: Internal Sources of Truth (What should sync)
```
local_crew_data (SHOULD BE ONLY SOURCE)
    |
    | drives updates to
    |
    v
crew_members (SHOULD BE DERIVED, NOT PRIMARY)
panel_data (SHOULD BE DELETED - UNUSED)
```

### Level 3: Derived Data (Generated from crew)
```
local_crew_data.members
    |
    +---> Display in _update_crew_display()
    |
    +---> Validation in validate_panel()
    |
    +---> Equipment generation in _generate_crew_starting_equipment()
    |
    +---> Patron/Rival generation in _generate_character_relationships()
```

---

## FUNCTION WRITE PATTERNS

### Pattern 1: BROKEN (Current - adds to wrong structure)
```gdscript
func add_crew_member(member):
    crew_members.append(member)              # ❌ Updates display cache
                                             # ❌ Doesn't update source
    # local_crew_data.members NOT updated!
```

### Pattern 2: CORRECT (Used in _on_character_generated)
```gdscript
func _on_character_generated(character):
    var character_data = _character_to_dict(character)
    
    # Update source of truth first
    local_crew_data.members.append(character_data)      # ✅ Primary update
    
    # Update display cache
    if character_object:
        crew_members.append(character_object)           # ✅ Secondary update
        
        if not current_captain:
            local_crew_data.captain = character_object  # ✅ Captain synced
            current_captain = character_object          # ✅ Cache synced
```

### Pattern 3: PROPOSED (Unified approach)
```gdscript
func _update_crew_structure(change_type: String, member, new_value = null):
    """Single point for all crew structure updates"""
    match change_type:
        "add":
            local_crew_data.members.append(member)
        "remove":
            local_crew_data.members.erase(member)
        "clear":
            local_crew_data.members.clear()
        "set_captain":
            local_crew_data.captain = new_value
    
    # Consistency check
    _validate_crew_setup()
```

---

## MISMATCH DETECTION CODE (Current Workaround)

```
validate_panel() (line 1074)
    |
    v
if crew_members.size() != local_crew_data.members.size():
    |
    +-> push_warning()          # Alert user to problem
    |
    +-> Recovery code
    |   |
    |   v
    |   Attempt to repopulate crew_members from local_crew_data
    |   (Only works one direction!)
    |
    v
This catches the symptom but not the disease!
```

---

## DEPENDENCIES CHART

```
What depends on what:

GameStateManager
    <-- local_crew_data (saved state)

CampaignFinalizationService
    <-- local_crew_data.members
    <-- local_crew_data.patrons
    <-- local_crew_data.rivals
    <-- current_captain

CampaignDashboard
    <-- local_crew_data.members (display)
    <-- crew_members (for validation checks)

_update_crew_display()
    <-- crew_members (iteration)
    <-- local_crew_data (metadata for display)

validate_panel()
    <-- crew_members.size()
    <-- local_crew_data.members.size()
    <-- current_captain
    <-- local_crew_data.captain

_generate_crew_starting_equipment()
    <-- crew_members (iterate all members)
    <-- Character.generate_starting_equipment_enhanced()
    --> local_crew_data.starting_equipment (write)
```

---

## SYNCHRONIZATION FAILURE SCENARIO

### Scenario: User clicks "Add Member" button

```
Step 1: User clicks "Add Member"
        |
        v
Step 2: _on_add_member_pressed()
        |
        v
Step 3: generate_random_character()
        |
        v
Step 4: add_crew_member(character)
        |
        v
Step 5: crew_members.append(character)          [STATE: crew_members=1]
        local_crew_data.members NOT updated      [STATE: local_crew_data=0]
        |
        v
Step 6: _validate_crew_setup() -> validate_panel()
        |
        v
Step 7: if crew_members.size() (1) != local_crew_data.members.size() (0)
        |
        YES! Mismatch detected!
        |
        v
Step 8: push_warning("Data structure mismatch")
        |
        v
Step 9: Attempt recovery (only works if crew_members empty!)
        |
        Fails because crew_members.size() > 0
        |
        v
Step 10: Uses crew_members.size() for validation
         (But local_crew_data has old data)
         |
         Result: Corrupted state!
```

---

## SOLUTION IN 3 STEPS

### Step 1: Update all write functions to sync to local_crew_data
```
add_crew_member()       → append to local_crew_data.members
remove_crew_member()    → erase from local_crew_data.members
clear_crew()            → clear local_crew_data.members
set_captain()           → set local_crew_data.captain
```

### Step 2: Update all read functions to read from local_crew_data
```
crew_members.size()     → local_crew_data.members.size()
crew_members[i]         → local_crew_data.members[i]["character_object"]
current_captain         → local_crew_data.captain
```

### Step 3: Remove panel_data (unused)
```
Delete variable definition (line 105)
Delete all assignments to panel_data
Replace references with local_crew_data
```

---

## CODE LOCATIONS QUICK REFERENCE

| Issue | Location | Fix |
|-------|----------|-----|
| add_crew_member writes wrong structure | Line 123 | Also append to local_crew_data.members |
| clear_crew doesn't sync | Line 640 | Also clear local_crew_data.members |
| set_captain doesn't sync | Line 653 | Also set local_crew_data.captain |
| remove_crew_member doesn't sync | Line 678 | Also remove from local_crew_data.members |
| _adjust_crew_size compounds errors | Line 686+ | Calls broken functions above |
| Validation detects but doesn't fix | Line 1074+ | Won't be needed after fixes |
| Correct pattern (reference) | Line 1284-1289 | Follow this pattern everywhere |
| panel_data unused | Line 105-110 | Delete |

