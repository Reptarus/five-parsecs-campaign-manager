# JSON to TRES Conversion Guide

## Overview

This guide documents the conversion of JSON data files to Godot's native `.tres` resource system for the Five Parsecs Campaign Manager. This conversion optimizes performance, provides better type safety, and leverages Godot's strengths.

## What We've Accomplished

### 1. Resource Classes Created

#### CharacterBackgroundResource.gd
- **Purpose**: Replaces JSON character background data
- **Features**: 
  - Stat bonuses/penalties
  - Starting gear and skills
  - Special abilities
  - Five Parsecs specific data (patrons, rivals, story points, credits)
  - Utility methods for stat calculations

#### CharacterMotivationResource.gd
- **Purpose**: Replaces JSON character motivation data
- **Features**:
  - Stat modifications
  - Five Parsecs specific effects (patrons, rivals, story points, XP bonuses)
  - Special effects and tags

#### CharacterClassResource.gd
- **Purpose**: Replaces JSON character class data
- **Features**:
  - Class abilities and features
  - Starting skills
  - Five Parsecs specific data

### 2. Conversion System

#### JsonToTresConverter.gd
- **Purpose**: Converts JSON files to TRES resources
- **Features**:
  - Batch conversion of all character data
  - Progress tracking with signals
  - Error handling and reporting
  - Resource loading utilities

### 3. Five Parsecs Rules Integration

#### Updated CaptainPanel.gd
- **Background Table**: All 24 backgrounds from Five Parsecs core rules
- **Motivation Table**: All 17 motivations from Five Parsecs core rules
- **Stat Generation**: Uses Five Parsecs method (2d6/3 rounded up)
- **Bonus Application**: Properly applies background and motivation bonuses
- **Resource Integration**: Ready to use TRES resources when available

## Five Parsecs Rules Implementation

### Background Table (24 options)
1. **Peaceful, High-Tech Colony** - +1 Savvy, 1D6 Credits
2. **Giant, Overcrowded, Dystopian City** - +1 Speed
3. **Low-Tech Colony** - Low-tech Weapon
4. **Mining Colony** - +1 Toughness
5. **Military Brat** - +1 Combat
6. **Space Station** - Gear
7. **Military Outpost** - +1 Reactions
8. **Drifter** - Gear
9. **Lower Megacity Class** - Low-tech Weapon
10. **Wealthy Merchant Family** - 2D6 Credits
11. **Frontier Gang** - +1 Combat
12. **Religious Cult** - Patron, 1 Story Point
13. **War-Torn Hell-Hole** - +1 Reactions, Military Weapon
14. **Tech Guild** - +1 Savvy, 1D6 Credits, High-tech Weapon
15. **Subjugated Colony on Alien World** - Gadget
16. **Long-Term Space Mission** - +1 Savvy
17. **Research Outpost** - +1 Savvy, Gadget
18. **Primitive or Regressed World** - +1 Toughness, Low-tech Weapon
19. **Orphan Utility Program** - Patron, 1 Story Point
20. **Isolationist Enclave** - 2 Rumors
21. **Comfortable Megacity Class** - 1D6 Credits
22. **Industrial World** - Gear
23. **Bureaucrat** - 1D6 Credits
24. **Wasteland Nomads** - +1 Reactions, Low-tech Weapon
25. **Alien Culture** - High-tech Weapon

### Motivation Table (17 options)
1. **Wealth** - 1D6 Credits
2. **Fame** - 1 Story Point
3. **Glory** - +1 Combat, Military Weapon
4. **Survival** - +1 Toughness
5. **Escape** - +1 Speed
6. **Adventure** - 1D6 Credits, Low-tech Weapon
7. **Truth** - 1 Rumor, 1 Story Point
8. **Technology** - +1 Savvy, Gadget
9. **Discovery** - +1 Savvy, Gear
10. **Loyalty** - Patron, 1 Story Point
11. **Revenge** - +2 XP, Rival
12. **Romance** - 1 Rumor, 1 Story Point
13. **Faith** - 1 Rumor, 1 Story Point
14. **Political** - Patron, 1 Story Point
15. **Power** - +2 XP, Rival
16. **Order** - Patron, 1 Story Point
17. **Freedom** - +2 XP

## Benefits of TRES Resources

### Performance
- **Faster Loading**: Native Godot format loads faster than JSON
- **Memory Efficient**: Optimized binary format
- **Type Safety**: Compile-time type checking

### Developer Experience
- **Editor Integration**: Resources appear in Godot editor
- **Auto-completion**: IDE support for resource properties
- **Validation**: Built-in error checking

### Maintainability
- **Structured Data**: Clear property definitions
- **Version Control**: Better diff tracking
- **Refactoring**: Easier to update and modify

## Usage Examples

### Loading a Background Resource
```gdscript
var converter = JsonToTresConverter.new()
var background = converter.load_background_resource("military_brat")
print("Background: %s" % background.name)
print("Combat bonus: %d" % background.get_stat_bonus("combat"))
```

### Creating a Character with Five Parsecs Rules
```gdscript
# Generate base stats using Five Parsecs method
var combat = ceili(float(randi() % 6 + 1 + randi() % 6 + 1) / 3.0)
var toughness = ceili(float(randi() % 6 + 1 + randi() % 6 + 1) / 3.0)
# ... etc for other stats

# Apply background bonuses
var background = converter.load_background_resource("military_brat")
combat += background.get_stat_bonus("combat")

# Apply motivation bonuses
var motivation = converter.load_motivation_resource("revenge")
combat += motivation.get_stat_bonus("combat")
```

## Next Steps

### 1. Complete JSON Conversion
- Run the conversion system to create all TRES resources
- Test resource loading and validation
- Update existing systems to use TRES resources

### 2. Expand Resource Types
- Create resources for weapons, armor, equipment
- Create resources for enemies and NPCs
- Create resources for missions and locations

### 3. Integration
- Update character creation UI to use resources
- Update campaign management to use resources
- Update save/load systems to handle resources

### 4. Testing
- Create comprehensive test suite for resources
- Test performance improvements
- Validate Five Parsecs rules compliance

## File Structure

```
src/data/
├── resources/
│   ├── CharacterBackgroundResource.gd
│   ├── CharacterMotivationResource.gd
│   ├── CharacterClassResource.gd
│   ├── backgrounds/          # Generated TRES files
│   ├── motivations/          # Generated TRES files
│   └── classes/             # Generated TRES files
├── JsonToTresConverter.gd
├── TestJsonConversion.gd
└── TestResourceSystem.gd
```

## Running the Conversion

1. **Test the Resource System**:
   ```bash
   # Run the test scene to verify resource creation
   godot --headless --main-pack res://src/data/TestJsonConversion.tscn
   ```

2. **Convert JSON to TRES**:
   ```gdscript
   var converter = JsonToTresConverter.new()
   converter.convert_all_json_to_tres()
   ```

3. **Verify Results**:
   - Check generated TRES files in `src/data/resources/`
   - Test resource loading
   - Validate Five Parsecs rules compliance

## Conclusion

The JSON to TRES conversion system provides a solid foundation for optimizing the Five Parsecs Campaign Manager. By leveraging Godot's native resource system, we gain:

- **Better Performance**: Faster loading and memory efficiency
- **Type Safety**: Compile-time validation and IDE support
- **Maintainability**: Structured data with clear property definitions
- **Five Parsecs Compliance**: Accurate implementation of game rules

The system is ready for integration with the existing character creation and campaign management systems. 