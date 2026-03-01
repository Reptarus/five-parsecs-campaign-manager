# Victory Conditions Guide

**Last Updated**: November 2025
**System Version**: 1.1.0

## Overview

Victory conditions define how your crew achieves their ultimate goal. The Five Parsecs Campaign Manager supports **multi-select victory conditions** with customizable targets - you can choose multiple paths to victory and win when **any** condition is achieved (OR logic).

---

## Victory Logic

### Multi-Select System
- Choose 1-5 victory conditions during campaign creation
- Customize target values for each condition
- Victory is achieved when ANY selected condition reaches its target
- Progress is tracked for all conditions simultaneously
- "Closest to completion" shown in victory panel

### Progress Tracking
The VictoryProgressPanel displays:
- All selected conditions with current progress
- Percentage completion for each
- Milestone markers (25%, 50%, 75%)
- Which condition is closest to completion

---

## Victory Condition Categories

### Duration (5 conditions)
Survive a set number of campaign turns.

| Condition | Default Target | Description | Estimated Playtime |
|-----------|----------------|-------------|-------------------|
| **20 Turns** | 20 | Short campaign - perfect for learning | 4-6 hours |
| **50 Turns** | 50 | Standard campaign length | 10-15 hours |
| **100 Turns** | 100 | Epic campaign for dedicated players | 20-30 hours |
| **Play Forever** | - | No victory - sandbox mode | Unlimited |
| **Custom Duration** | Variable | Set your own turn target | Variable |

**Strategy Tips**:
- Focus on crew survival over risky missions
- Build a sustainable economy
- Manage injuries carefully

### Combat (5 conditions)

| Condition | Default Target | Description | Estimated Playtime |
|-----------|----------------|-------------|-------------------|
| **Battles Won** | 30 | Win tactical engagements | 8-12 hours |
| **Enemies Defeated** | 100 | Total enemy kills | 8-12 hours |
| **Rival Defeated** | 3 | Destroy rival factions | 6-10 hours |
| **Quest Victory** | 3 | Complete quest chains | 8-12 hours |
| **Boss Battle** | 1 | Defeat a legendary enemy | 6-10 hours |

**Strategy Tips**:
- Take every fight opportunity
- Build combat-focused crew
- Invest in weapons and armor

### Story (3 conditions)

| Condition | Default Target | Description | Estimated Playtime |
|-----------|----------------|-------------|-------------------|
| **Story Points** | 20 | Accumulate narrative rewards | 10-15 hours |
| **Quests Completed** | 5 | Finish multi-stage quests | 10-15 hours |
| **Story Finale** | 1 | Complete the campaign story | 15-20 hours |

**Strategy Tips**:
- Prioritize patron jobs with story rewards
- Follow quest chains to completion
- Explore narrative events

### Wealth (2 conditions)

| Condition | Default Target | Description | Estimated Playtime |
|-----------|----------------|-------------|-------------------|
| **Credits** | 100 | Accumulate wealth | 8-12 hours |
| **Fame** | 10 | Build crew renown | 8-12 hours |

**Strategy Tips**:
- Take high-paying jobs
- Avoid unnecessary expenses
- Sell loot strategically

### Challenge (2 conditions)

| Condition | Default Target | Description | Estimated Playtime |
|-----------|----------------|-------------|-------------------|
| **Flawless Campaign** | 20 | Complete 20 turns with no crew deaths | 6-10 hours |
| **Ironman** | 50 | Survive with permadeath enabled | 15-20 hours |

**Strategy Tips**:
- Play conservatively
- Retreat from bad situations
- Invest heavily in crew protection

---

## Custom Victory Conditions

### Creating Custom Conditions
The CustomVictoryDialog allows you to:
1. Select any standard victory type
2. Adjust the target value (within min/max limits)
3. Preview estimated playtime impact
4. Add multiple custom conditions

### Target Value Limits
Each condition type has minimum and maximum values:
- Turns: 5-200
- Battles Won: 5-100
- Credits: 25-1000
- Story Points: 5-50
- Enemies Defeated: 25-500
- etc.

### Example Custom Combinations
**Speed Run**: 10 turns + 50 credits
**Combat Focus**: 20 battles won + 50 enemies defeated
**Story Rich**: 15 story points + 3 quests completed
**Challenge Mode**: 30 turns flawless + 100 credits

---

## Progress Tracking

### VictoryProgressPanel
Located on the Campaign Dashboard, shows:
```
Selected Conditions:
  [=======----] 70% - 20 Turns (14/20)
  [====-------] 45% - 100 Credits (45/100)

Closest to completion: 20 Turns
```

### Condition Progress Sources
| Condition Type | Progress Source |
|----------------|-----------------|
| Turns | current_turn |
| Credits | current credits |
| Fame | renown |
| Battles Won | battles_won |
| Enemies Defeated | enemies_defeated_total |
| Story Points | story_points |
| Quests | quests_completed |
| Rivals Defeated | rivals_eliminated |

---

## Data Storage

### Save File Format
```json
{
  "campaign": {
    "victory_conditions": {
      "TURNS_20": {"target": 20, "progress": 15},
      "WEALTH_100": {"target": 100, "progress": 45}
    }
  }
}
```

### GameStateManager Integration
Victory conditions are stored in:
- FiveParsecsCampaignCore.victory_conditions
- GameStateManager.victory_conditions

Access via:
```gdscript
var conditions = GameStateManager.get_victory_conditions()
GameStateManager.set_victory_conditions(new_conditions)
```

---

## UI Components

### Campaign Creation
- **ExpandedConfigPanel**: Multi-select checkbox list with descriptions
- **CustomVictoryDialog**: Modal for custom target configuration
- **RichTextLabel**: Full narrative descriptions for each condition

### Campaign Dashboard
- **VictoryProgressPanel**: Real-time progress tracking
- Milestone visualization (25%, 50%, 75%)
- "Closest to completion" algorithm

---

## Victory Descriptions

Each victory condition includes:
- **Full Description**: Narrative context for the goal
- **Strategy Tips**: How to achieve it efficiently
- **Difficulty Rating**: Easy/Medium/Hard/Very Hard
- **Estimated Playtime**: Hours to completion
- **Category**: Duration/Combat/Story/Wealth/Challenge

Access via `FPCM_VictoryDescriptions.get_victory_info(condition_type)`

---

## Technical Implementation

### Key Files
- `src/game/victory/VictoryDescriptions.gd` - Narrative database
- `src/ui/components/victory/CustomVictoryDialog.gd` - Custom condition UI
- `src/ui/screens/campaign/VictoryProgressPanel.gd` - Progress tracking
- `src/ui/screens/campaign/panels/ExpandedConfigPanel.gd` - Multi-select UI

### Data Flow
1. User selects conditions in ExpandedConfigPanel
2. CustomVictoryDialog allows target customization
3. CampaignCreationUI stores in config Dictionary
4. CampaignFinalizationService transfers to campaign resource
5. GameStateManager receives for runtime access
6. VictoryProgressPanel displays real-time progress

---

*Related Documentation*:
- [Core Rules](rules/core_rules.md)
- [Data Model](../technical/DATA_MODEL_AND_SAVE_SYSTEM.md)
- [System Architecture](../technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md)
