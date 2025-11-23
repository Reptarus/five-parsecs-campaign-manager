# Five Parsecs from Home - Rules Implementation Guide

## 📘 Introduction

This guide explains how the Five Parsecs from Home tabletop rules have been translated into the digital Campaign Manager. Whether you're a veteran tabletop player or completely new to Five Parsecs, this document clarifies how rules work in the digital version.

### Philosophy of Digital Adaptation

The digital implementation prioritizes:
1. **Automation** - Complex calculations handled by the game
2. **Accuracy** - Faithful to core tabletop rules
3. **Accessibility** - Easier for new players to learn
4. **Speed** - Faster play compared to manual tabletop
5. **Transparency** - All calculations shown in combat log

### What's Different from Tabletop?

**Automated**:
- Dice rolling and calculations
- Table lookups and cross-referencing
- Stat tracking and record-keeping
- Enemy AI behavior

**Simplified**:
- No physical measuring (distances calculated automatically)
- No manual terrain setup (procedurally generated)
- Visual feedback instead of rulebook checking

**Enhanced**:
- Save/load functionality
- Undo capabilities (limited)
- Analytics and statistics tracking
- Tutorial and learning modes

---

## 🎲 Core Resolution Mechanics

### The D6 System

Five Parsecs uses six-sided dice (D6) for all random resolution:

**Notation**:
- `1D6` = Roll one six-sided die (result: 1-6)
- `2D6` = Roll two dice and add them (result: 2-12)
- `D6+2` = Roll one die and add 2 (result: 3-8)
- `D3` = Roll D6: 1-2=1, 3-4=2, 5-6=3

**Digital Implementation**:
```
The game uses a cryptographically secure random number generator
Results appear in the combat log with exact rolls shown
Example: "Sara shoots: Roll 4 + Combat Skill +1 = 5 total"
```

### Target Number System

Most actions use a target number (TN) system:
- Roll D6 + Modifiers
- Compare to Target Number
- Equal or greater = Success
- Less than = Failure

**Example - Shooting**:
```
Base TN: 5
+ Range modifier: +2 (long range)
+ Cover modifier: -1 (target in light cover)
+ Weapon modifier: 0 (standard rifle)
= Final TN: 6

Roll: 4 + Combat Skill +1 = 5 total
Result: 5 < 6 = MISS
```

### Critical Success and Failure

**Natural 6** (on unmodified die roll):
- Always succeeds (even if modifiers would cause failure)
- May trigger bonus effects (weapon-specific)
- Shown as ⚡ in combat log

**Natural 1** (on unmodified die roll):
- Always fails (even if modifiers would cause success)
- May trigger negative effects (weapon jamming, etc.)
- Shown as ☠ in combat log

**Digital Note**: The game distinguishes between "total result" and "natural roll"

---

## 👥 Character Statistics

### The Five Core Stats

Every character has five stats that define their capabilities:

#### 1. Reactions (0-5)

**Tabletop**: Determines initiative order
**Digital Implementation**:
- Initiative = 1D6 + Reactions
- Characters activate in descending initiative order
- Ties resolved by higher Reactions stat, then randomly
- Shown as numbered activation sequence in battle UI

**Typical Values**:
- 0 = Slow and lumbering
- 1 = Average (most humans)
- 2 = Alert and quick
- 3+ = Lightning reflexes (elite troops)

**Advancement**: Rarely increases (expensive upgrade)

#### 2. Speed (3"-8")

**Tabletop**: Movement in inches on tabletop
**Digital Implementation**:
- Converted to grid squares or pixel distance
- Visual movement range shown when character selected
- Difficult terrain automatically reduces movement
- Dashing allows up to 2× Speed movement (no shooting)

**Typical Values**:
- 3"-4" = Slow (heavily armored, injured)
- 5" = Average (most species)
- 6"-7" = Fast (light troops, scouts)
- 8"+ = Very fast (specialized runners)

**Movement Types**:
- **Normal Move**: Up to Speed distance
- **Dash**: Up to 2× Speed, cannot shoot this turn
- **Careful Move**: Half Speed, gain +1 cover bonus

#### 3. Combat Skill (+0 to +3)

**Tabletop**: Modifier added to shooting and brawling rolls
**Digital Implementation**:
- Directly added to all attack rolls
- Shown in character stat panel
- Highlighted when rolling (green for positive, red for negative)
- Most impactful stat for combat effectiveness

**Typical Values**:
- +0 = Untrained civilian
- +1 = Average soldier/mercenary
- +2 = Veteran warrior
- +3 = Elite combatant

**Affects**:
- Shooting accuracy
- Brawling effectiveness
- Some special weapon uses

#### 4. Toughness (3-6)

**Tabletop**: Roll equal or under to resist damage
**Digital Implementation**:
- Automatic saving throw when hit
- Roll 1D6, success if ≤ Toughness
- Success = No damage taken
- Failure = Take 1 damage (HP reduced by 1)
- Critical hit (6 on damage die) = Ignore Toughness, automatic damage

**Typical Values**:
- 3 = Fragile (unarmored civilians, small species)
- 4 = Average human
- 5 = Tough (armored, larger species)
- 6 = Extremely resilient (heavy armor, K'Erin)

**Modified By**:
- Armor: +1 or +2 to Toughness
- Injuries: Can reduce Toughness temporarily
- Cover: Doesn't affect Toughness but prevents hits

#### 5. Savvy (+0 to +3)

**Tabletop**: Intelligence, tech use, psionic power
**Digital Implementation**:
- Used for skill checks (hacking, repairs)
- Determines psionic power strength
- Affects some special abilities
- Less frequently rolled than Combat Skill

**Typical Values**:
- +0 = Simple-minded
- +1 = Average intelligence
- +2 = Smart, educated
- +3 = Genius-level intellect

**Affects**:
- Tech interaction success
- Psionic power effectiveness
- Some mission objectives (hacking, sabotage)
- Story event outcomes

### Derived Stats

**Hit Points (HP)**:
Not a stat in tabletop, but tracked digitally:
- Start at 1 HP per character
- If reduced to 0 HP = Character down (roll injury)
- Can have temporary HP from stims/abilities
- Visual HP indicator above character sprite

**XP (Experience Points)**:
- Earned during battles
- Accumulates toward level-ups
- Spend to increase stats or gain abilities
- Tracked automatically per character

---

## ⚔️ Combat System Implementation

### Combat Overview

Combat is tactical, turn-based miniatures gameplay.

**Tabletop Flow**:
1. Set up battlefield with terrain
2. Deploy forces
3. Roll initiative each round
4. Activate characters in order
5. Move, shoot, or brawl
6. Repeat until victory/defeat

**Digital Changes**:
- Battlefield auto-generated or selected from templates
- Enemy AI handles opponent actions
- Calculations automated
- Faster resolution

### Battle Setup Phase

#### 1. Mission Briefing

**Displays**:
- Objective (what you need to accomplish)
- Enemy type and approximate numbers
- Deployment condition
- Special rules or hazards

**Digital Enhancement**: Objective tracker shown during battle

#### 2. Battlefield Generation

**Tabletop**: Players manually set up terrain
**Digital Implementation**:
- Procedural generation based on world type
- Terrain density settings (sparse, normal, dense)
- Cover automatically placed
- Objective markers positioned

**Terrain Types**:
- Light Cover: Crates, barrels, low walls
- Heavy Cover: Walls, buildings, vehicles
- Obstacles: Movement-blocking terrain
- Hazardous: Toxic zones, fire, etc.

#### 3. Deployment

**Tabletop**: Deploy within 12" of edge
**Digital**: Deployment zone highlighted
- Click and place characters
- Zone size varies by scenario
- Some scenarios allow infiltration deployment

**Deployment Conditions** (random):
- **Standard**: Normal deployment zones
- **Encounter**: Closer starting positions (shorter battlefield)
- **Flank Attack**: You deploy on two sides
- **Delayed**: You arrive in waves
- **Defensive**: You set up first, enemy deploys closer

#### 4. Enemy Deployment

**Automatic AI deployment**:
- Enemies placed in their zone
- Smart positioning (use cover, spread out)
- Special units positioned strategically
- Number revealed (may differ from briefing estimate)

### Battle Round Structure

Each round has 4 phases:

#### Phase 1: Quick Actions

**Before initiative**, characters can take Quick Actions:

**Bail Out** (if in vehicle):
- Exit vehicle before it explodes
- 1D6 roll to avoid damage

**Dash** (before regular activation):
- Move up to 2× Speed immediately
- Cannot shoot this round
- Useful for repositioning

**Digital Note**: Click "Quick Action" button on character portrait

#### Phase 2: Roll Initiative

**Tabletop**:
- Each side rolls 1D6
- Higher roll activates all their characters first

**Digital Implementation**:
- Each character rolls 1D6 + Reactions individually
- Activation order displayed numerically
- Characters activate one at a time, highest to lowest
- More granular tactical control than tabletop

**Activation Indicator**:
- Green highlight = Currently activating
- Yellow border = Can activate soon
- Gray = Already activated this round
- Red = Cannot activate (stunned, etc.)

#### Phase 3: Character Activation

When a character activates, they can:

**1. Move** (up to Speed distance)
**2. Combat Action** (shoot OR brawl)
**3. Object Interaction** (open door, pick up item)

Or:

**Dash** (move up to 2× Speed, no shooting)

**Movement Rules**:

**Normal Movement**:
- Move up to Speed in inches/squares
- Can split movement (move-shoot-move)
- Moving through difficult terrain halves speed
- Cannot move through enemy figures

**Climbing**:
- Each 1" vertical = 2" horizontal movement cost
- Some characters have climbing bonuses
- Failed climb check = no movement this turn

**Jumping**:
- Horizontal jump: Up to Speed distance with run-up
- Vertical jump: 1" max
- Failure = fall damage

**Digital Implementation**:
- Click destination, pathfinding automatic
- Movement cost shown before confirming
- Invalid moves grayed out
- Undo movement allowed (before shooting)

**Combat Actions**:

**Shooting** (if carrying ranged weapon):

**Step 1**: Select Target
- Must have line of sight
- Target must be in weapon range
- Game validates automatically

**Step 2**: Determine Target Number
```
Base TN: 5
+ Range modifier
+ Cover modifier  
+ Movement modifier
+ Special modifiers
= Final Target Number
```

**Step 3**: Roll to Hit
```
Roll 1D6 + Combat Skill
Compare to Target Number
≥ TN = Hit
< TN = Miss
```

**Step 4**: Roll Damage (if hit)
- Target rolls 1D6 vs Toughness
- Success = No damage
- Failure = 1 damage (or weapon-specific)

**Brawling** (if adjacent to enemy):

**Opposed Roll**:
- Attacker: 1D6 + Combat Skill
- Defender: 1D6 + Combat Skill
- Higher total wins
- Ties favor defender

**Winner Effects**:
- Deal 1 damage to loser (Toughness save allowed)
- Loser may be pushed back 1"
- Loser stunned (some weapons)

**Digital Implementation**:
- Both rolls shown simultaneously
- Results compared automatically
- Effects applied immediately

#### Phase 4: Enemy Actions

**Tabletop**: Player controls enemies using AI tables
**Digital**: Fully automated AI

**AI Behavior Types**:

**Aggressive**:
- Move toward nearest threat
- Shoot when in range
- Charge into brawl

**Defensive**:
- Seek cover
- Shoot from protected positions
- Fall back when outnumbered

**Tactical**:
- Flank player positions
- Focus fire on weak targets
- Use special abilities

**Beast**:
- Charge toward nearest target
- Brawl-focused
- Ignore morale

**Digital AI Enhancements**:
- Smarter pathfinding than tabletop tables
- Adapts to battlefield conditions
- Uses special abilities appropriately
- Visible intent indicators (optional setting)

### Round End

After all characters activate:
- Check morale (some scenarios)
- Update objective progress
- Resolve ongoing effects (fire, poison, etc.)
- Start new round or end battle

### Morale and Withdrawing

**Morale Checks** (some scenarios):
- Triggered by: Heavy casualties, leader death
- Roll 1D6, compare to campaign morale stat
- Failure: Crew must withdraw or face penalties

**Voluntary Withdrawal**:
- Click "Withdraw" button
- All crew flee battlefield
- Mission failed, no pay
- Crew survives (unless caught fleeing)

**Enemy Morale**:
- Automatic when 50%+ enemies defeated
- Enemies flee or surrender
- Battle ends early

---

## 📐 Range and Line of Sight

### Range Bands

Weapons have effective ranges measured in inches:

**Tabletop Measurement**:
- Use ruler or measuring tape
- Measure base-to-base

**Digital Implementation**:
- Automatic distance calculation
- Range bands color-coded:
  - 🟢 Green: Short range (no penalty)
  - 🟡 Yellow: Long range (+1 TN modifier)
  - 🔴 Red: Extreme/Out of range (cannot shoot)

**Weapon Range Examples**:
- **Pistol**: 12" (short 0-6", long 7-12")
- **Rifle**: 24" (short 0-12", long 13-24")
- **Shotgun**: 12" (short only, ineffective beyond)
- **Sniper Rifle**: 36" (short 0-18", long 19-36")

**Range Modifiers**:
- Short range: +0 to TN
- Long range: +1 to TN
- Beyond max range: Cannot shoot

### Line of Sight (LOS)

**Tabletop**: "If you can see any part of the target from your model's perspective, you have LOS"

**Digital Implementation**:
- Raycast from shooter to target
- Blocked by: Solid terrain, other figures
- Partial cover possible (see below)
- Visual LOS indicator when targeting

**LOS Rules**:

**Blocked**:
- Solid terrain between shooter and target
- Friendly or enemy figure blocking path
- Cannot shoot

**Clear**:
- No obstructions
- Full accuracy

**Partial** (through gaps):
- Small gaps in terrain
- Can shoot but counts as cover for target

### Cover System

**Cover Types**:

**Light Cover**:
- Low walls, crates, barrels
- -1 to enemy hit rolls
- Automatically applied when behind terrain <1" tall

**Heavy Cover**:
- Walls, vehicles, bunkers
- -2 to enemy hit rolls  
- Terrain 1"+ tall

**Solid Cover**:
- Completely blocks LOS
- Cannot be shot at
- Must peek out to shoot (lose cover)

**Digital Cover Detection**:
- Automatic based on figure position
- Cover icon shown above character
- Tooltip explains exact bonus
- 🛡️ symbol on character = in cover

**Cover Arc**:
- Cover only applies from the direction it's positioned
- Flanking negates cover
- Digital: Cover shown with directional indicator

**Breaking Cover**:
- Moving out from cover to shoot
- Counts as "in open" for enemy reaction fire
- Can immediately return to cover after shot (if movement allows)

---

## 🏥 Damage and Injuries

### Taking Damage

**When Hit**:

**Step 1**: Toughness Save
- Roll 1D6
- Success if roll ≤ Toughness value
- Success = No damage ("Shrugged off the hit!")
- Failure = Take damage

**Step 2**: Reduce HP
- Lose 1 HP (or weapon damage amount)
- When reduced to 0 HP = Down
- Some weapons deal multiple damage

**Digital Display**:
- HP bar above character
- Green = full HP
- Yellow = damaged
- Red = critical
- Flashing = down

### Being Down

**When character reaches 0 HP**:
- Figure removed from play immediately
- Cannot act for rest of battle
- Roll on injury table post-battle
- May be stabilized by medics (optional rule)

### Injury Table (Post-Battle)

After battle, roll for each downed character:

**Roll 1D6 + Modifiers**:

**1 or less - Dead**:
- Character killed
- Remove from campaign permanently
- Can buy off with Story Point
- Rare on Easy difficulty

**2-3 - Serious Wound**:
- Out for 3+ campaign turns
- May have stat penalty during recovery
- Medical treatment can reduce recovery time

**4-5 - Light Injury**:
- Out for 1-2 turns
- Minor stat penalty
- Heals quickly

**6+ - Lucky Escape**:
- No lasting injury
- Available next turn
- Maybe just winded!

**Modifiers**:
- Medical care: +1 or +2
- Battlefield medics: +1 if medic survives
- Medical supplies used: +1 per stimpack applied

**Digital Implementation**:
- Automatic rolls shown after battle
- Medical options presented if available
- Recovery timers tracked automatically
- Injured status shown in roster

### Death and Replacement

**Character Death**:
- Permanent (unless Story Point spent)
- Equipment lost with character
- Crew morale may be affected
- Can recruit replacement (costs credits)

**Story Point Resurrection**:
- Spend 1 Story Point
- Character lives with serious injury
- Out for 5+ turns recovering
- Possible permanent stat reduction

---

## 🎯 Weapons and Equipment

### Weapon Statistics

Each weapon has these properties:

**Range**: Maximum effective distance
- Example: "12"" or "24""

**Shots**: How many times can fire per battle
- Most weapons: Unlimited (infinite ammo abstraction)
- Heavy weapons: Limited (tracked per battle)

**Damage**: Amount of damage dealt
- Usually 1 (standard weapons)
- 2-3 (heavy weapons, explosives)

**Traits**: Special rules
- Examples: Piercing, Area Effect, Stun, etc.

### Weapon Types

**Pistols**:
- Range: 10-12"
- Can shoot after dashing
- Cheap and common
- Backup weapon for most crew

**Rifles**:
- Range: 18-24"
- Standard infantry weapon
- Balanced performance
- Most common primary weapon

**Shotguns**:
- Range: 12" (short only)
- Powerful at close range
- May damage multiple targets at point-blank
- Useless at long range

**Sniper Rifles**:
- Range: 30-36"
- Extreme range
- Bonus vs stationary targets
- Expensive, rare

**Machine Guns**:
- Range: 24-30"
- Can target multiple enemies
- Heavy, reduces speed
- Limited shots per battle

**Melee Weapons**:
- Range: Adjacent only
- Bonus to brawling
- Cheap
- Backup for close combat specialists

**Grenades/Explosives**:
- Range: 8-12" thrown
- Area effect damage
- Limited uses
- Dangerous if close

### Weapon Traits

**Piercing** (X):
- Ignore X points of armor
- Example: Piercing (1) ignores +1 armor bonus
- Effective vs armored targets

**Area Effect** (X"):
- Affects all figures within X" of impact
- Useful vs clusters
- Friendly fire possible

**Stun**:
- On hit, target loses next activation
- Doesn't deal damage
- Tactical crowd control

**Snap Shot**:
- Can shoot before moving
- Tactical advantage
- Usually pistols only

**Single Use**:
- Can only fire once per battle
- Grenades, rockets
- High impact

**Critical** (X+):
- On natural die roll of X+, extra effect
- Example: Critical (6) adds bonus damage on natural 6
- High-risk/reward weapons

**Digital Implementation**:
- Traits shown in weapon tooltip
- Effects applied automatically
- Visual indicators for trait triggers

### Armor

**Armor Types**:

**Screen/Shield**: +1 Toughness
**Flak Vest**: +1 Toughness
**Combat Armor**: +2 Toughness
**Battle Dress**: +2 Toughness + Special

**Armor Limits**:
- Can only wear one armor
- Some armor reduces Speed
- May be incompatible with certain species
- Expensive but worthwhile

**Digital Armor Tracking**:
- Armor bonus shown in character stats (Toughness displays as "4+1" if armored)
- Equip/unequip in loadout screen
- Damage to armor tracked separately (optional rule)

### Gear and Consumables

**Medkits**:
- Use on downed ally (adjacent)
- +1 to post-battle injury roll
- Single use
- Critical survival tool

**Booster Pills**:
- +1 to all rolls for one battle round
- Risky (side effects possible)
- Temporary advantage

**Combat Serum**:
- +2 Combat Skill for battle
- Crash afterward (-1 next battle)
- Emergency performance boost

**Motion Tracker**:
- Reveals hidden enemies
- +1 Reactions for battle
- Expensive tech item

**Stim Pack**:
- Restore 1 HP during battle
- One use per battle
- Life-saving

**Digital Gear Usage**:
- Click item in inventory during battle
- Effect applied immediately
- Used items grayed out
- Cooldowns tracked automatically

---

## 🌌 Campaign Turn Sequence (Detailed)

### Turn Structure

Every campaign turn follows this exact sequence:

### Step 1: TRAVEL

**Sub-steps**:
1. Check if invaded (flee if necessary)
2. Decide: Stay or Travel
3. If traveling:
   - Roll for travel event (1D6)
   - Pay fuel cost (1-3 credits)
   - Arrive at new world
4. If new world:
   - Roll for world traits
   - Check for rivals present
   - Dismiss incompatible patrons

**Travel Events** (1D6):
- 1: Hostile encounter (space combat)
- 2-3: Uneventful
- 4: Opportunity (find something)
- 5: Meet traveler (potential hire)
- 6: Good fortune (credits or info)

**Digital Implementation**:
- Travel map shows known systems
- Click destination, event resolves
- Automatic cost deduction
- New world info displayed

### Step 2: WORLD PHASE

**Sub-steps**:
1. **Pay Upkeep** (automatic)
   - Ship maintenance
   - Crew wages
   - Debt payments

2. **Crew Recovery**
   - Injured crew heal (reduce recovery timer by 1)
   - Check if anyone fully recovers

3. **Assign Crew Tasks**
   - Each crew member picks one task:
     - Find Patron
     - Trade
     - Explore
     - Train
     - Recruit
     - Repair Kit
     - Decoy
     - Track (Rival)
     - Rest (injured only)

4. **Resolve Tasks**
   - Roll for each task
   - Apply results
   - Update campaign state

5. **Determine Job Offers**
   - Patron jobs generated
   - Opportunity missions available
   - Rival encounters possible
   - Quest missions (if story points available)

6. **Assign Equipment**
   - Equip crew for battle
   - Transfer items between crew
   - Sell/buy equipment

7. **Choose Mission**
   - Select from available jobs
   - Accept and proceed to battle

**Digital Implementation**:
- Step-by-step wizard interface
- Clear current task display
- Undo allowed (until battle starts)
- Auto-save after each sub-step

### Step 3: TABLETOP BATTLE

(See Combat System section above)

### Step 4: POST-BATTLE SEQUENCE

**Sub-steps**:
1. **Resolve Rival Status**
   - Defeated rivals may become patrons
   - Fled rivals become stronger
   - New rivals may be gained

2. **Resolve Patron Status**
   - Mission success/failure recorded
   - Patron relationship updated
   - Patron may offer bonus or leave

3. **Determine Quest Progress**
   - Check quest objectives
   - Update quest stage
   - Unlock new quest steps

4. **Get Paid**
   - Mission reward delivered
   - Bonuses for performance
   - Penalties for failures

5. **Battlefield Finds**
   - Each crew member searches
   - Roll for loot
   - Find credits, gear, weapons

6. **Gather Loot**
   - Collect enemy equipment
   - Add to inventory
   - Sell immediately or keep

7. **Check for Invasion**
   - Roll for planet invasion (rare)
   - If invaded, must flee or fight

8. **Determine Injuries**
   - Roll for each downed character
   - Apply medical treatment
   - Set recovery timers

9. **Experience and Upgrades**
   - Award XP to participants
   - Level up eligible characters
   - Choose stat increases/abilities

10. **Invest in Training**
    - Optional advanced training
    - Costs credits
    - Bonus XP or unlock abilities

11. **Purchase Items**
    - Visit market
    - Buy/sell equipment
    - Limited stock (random)

12. **Campaign Event**
    - Roll for random event
    - May be good or bad
    - Affects campaign state

13. **Character Event**
    - Personal events for crew
    - Backstory developments
    - Relationship changes

**Digital Implementation**:
- Automated sequence with UI prompts
- Each step clearly labeled
- Options presented when choices available
- Summary screen at end

---

## 📈 Character Advancement

### Earning Experience (XP)

Characters earn XP during battles:

**XP Awards**:
- **Participated in battle**: +1 XP
- **Landed a hit on enemy**: +1 XP
- **Defeated an enemy**: +1 XP
- **Completed objective**: +1 XP
- **Survived tough battle**: +1 XP (optional)

**Typical Battle**: 2-4 XP earned
**Difficult Battle**: 4-6 XP earned

**Digital XP Tracking**:
- Automatic awards post-battle
- XP bar shows progress to next level
- Visual celebration on level up

### Leveling Up

**XP Thresholds**:
- Level 2: 5 XP
- Level 3: 10 XP (15 total)
- Level 4: 15 XP (30 total)
- Level 5: 20 XP (50 total)
- Level 6+: 25 XP each

**On Level Up, Choose ONE**:

**Option A: Increase Stat**
- +1 to any stat (within limits):
  - Reactions: Max 5
  - Speed: Max 8"
  - Combat Skill: Max +3
  - Toughness: Max 6
  - Savvy: Max +3

**Option B: Gain Ability**
- Choose from available ability list
- Some abilities have prerequisites
- Can have multiple abilities

**Common Abilities**:
- **Veteran**: Re-roll one die per battle
- **Marksman**: +1 to shooting at long range
- **Brawler**: +1 to brawling rolls
- **Medic**: Better healing efficiency
- **Tech**: Bonus to tech interactions
- **Stealth**: Better at stealth missions
- **Leader**: Grants bonus to nearby allies

**Digital Level Up**:
- Pause after battle when level reached
- Present choices clearly
- Show stat limits
- Preview ability effects
- Confirm selection

### Training (Optional)

**Advanced Training** (crew task or post-battle):
- Costs: 1-3 credits
- Gain: +1 or +2 XP
- Restrictions: Once per turn per character
- Good for pushing toward level up

**Specialist Training**:
- Unlock specific abilities
- Higher cost (5-10 credits)
- Requirements: Certain stat minimums
- Examples: Sniper school, Tech academy

---

## 🎲 Random Tables and Generators

### Campaign Event Table

**Roll 1D6 each turn (post-battle)**:

**1 - Crisis**:
- Negative event
- Equipment theft, injury relapse, debt collector
- Must handle immediately

**2-3 - Nothing Notable**:
- Quiet turn
- No special event

**4 - Opportunity**:
- Chance for bonus
- Extra mission, discount shopping, find item

**5 - Connection**:
- Meet useful NPC
- Potential patron, info broker, ally

**6 - Windfall**:
- Good fortune
- Find credits, free equipment, bonus

**Digital Implementation**:
- Automatic roll shown
- Event details displayed
- Choices presented if applicable

### Character Event Table

**Each turn, one random crew member**:

**1 - Personal Crisis**:
- Family issue, old enemy surfaces
- May require mission or credits to resolve

**2-3 - Nothing**:
- Calm period

**4 - Training Opportunity**:
- Bonus XP or discount on training

**5 - Connection**:
- Meet old friend, gain contact

**6 - Lucky Break**:
- Find item, earn bonus credits

### Loot Tables

**Battlefield Finds** (post-battle):
- Each participating crew member rolls 1D6

**1-2**: Nothing
**3**: 1 credit
**4**: 1D3 credits
**5**: Item (roll on gear table)
**6**: Choice of credits or weapon

**Gear Table** (when finding items):
- 1D6 roll determines item type:
  - 1-2: Consumable (medkit, stim)
  - 3-4: Gear (equipment, tools)
  - 5: Weapon (roll weapon type)
  - 6: Armor or valuable

**Digital Loot**:
- Automatic rolls after battle
- Items added to inventory
- Option to auto-sell junk
- Rare item notifications

---

## 🎴 Enemy Types and AI

### Enemy Categories

**Roving Threats**:
- Common opponents
- Punks, Raiders, Gangers
- Low-moderate skill
- Standard equipment

**Hired Muscle**:
- Mercenaries, Soldiers
- Moderate-high skill
- Better equipment
- More tactical

**Interested Parties**:
- Corporate security, Agents
- High skill
- Advanced equipment
- Special abilities

**Unique Foes**:
- Story-specific enemies
- Variable stats
- Unique equipment
- Boss-level challenges

### Enemy Stats

Enemies use same stats as player characters:

**Typical Raider**:
- Reactions: 1
- Speed: 5"
- Combat Skill: +0
- Toughness: 4
- Equipment: Scrap pistol or blade

**Veteran Mercenary**:
- Reactions: 2
- Speed: 5"
- Combat Skill: +2
- Toughness: 5
- Equipment: Military rifle, armor

### Enemy AI Behavior Tables

**Tabletop**: Players roll on AI tables to determine enemy actions
**Digital**: AI automatically selects optimal action

**AI Decision Priority** (digital):
1. If in cover and enemy in range → Shoot
2. If not in cover → Move to nearest cover
3. If no cover available → Move toward enemy
4. If adjacent to enemy → Brawl
5. If heavily wounded → Flee

**AI Special Behaviors**:

**Aggressive**: Prioritize moving toward enemies
**Defensive**: Prioritize staying in cover
**Tactical**: Flank and focus fire
**Beast/Feral**: Charge directly, always brawl

---

## 🏆 Victory Conditions and Campaign Goals

### Standard Victory Conditions

(See Player's Guide for details, rules same in digital)

**Credits**: Accumulate 500 credits
**Renown**: Reach fame level 10
**Quest**: Complete major quest line
**Story Points**: Earn 20 story points
**Survival**: Survive 50 turns
**Open-Ended**: Play indefinitely

### Campaign Progression Tracking

**Digital Dashboard Shows**:
- Progress toward victory condition (percentage bar)
- Current turn number
- Credits on hand
- Renown level
- Active quests
- Story points earned

**Milestones** (achievements):
- 10 battles won
- First character level 5
- Defeat first rival
- Complete first quest
- Survive 25 turns
- 100+ credits earned

---

## 🛡️ Optional Rules

The digital version supports many optional rules from the tabletop:

### Story Track

**Enabled in campaign setup**:
- Narrative events occur
- Quest missions available
- Story points earned and spent
- Deeper campaign narrative

**Disabled**:
- Pure tactical/economic focus
- No quests
- Simpler campaign

### Progressive Difficulty

**Enabled**:
- Enemies get stronger over time
- Missions scale with crew power
- Maintains challenge

**Disabled**:
- Static difficulty
- Easier late game

### Ironman Mode

**Enabled**:
- Only one save file (auto-save)
- No save scumming
- Permanent consequences
- Ultimate challenge

**Disabled**:
- Multiple saves allowed
- Can reload bad outcomes
- Recommended for learning

### Detailed Injuries

**Enabled**:
- More injury types
- Longer-term consequences
- Permanent injuries possible

**Disabled**:
- Simplified injury system
- Faster recovery
- Less punishing

### Elite Enemies

**Enabled**:
- Tougher enemy tables
- Better equipped foes
- Higher challenge, better rewards

**Disabled**:
- Standard enemy strength
- Normal game balance

---

## 🔄 Differences from Tabletop

### Major Changes

**Initiative System**:
- **Tabletop**: Each side rolls 1D6, winner activates all their figures
- **Digital**: Individual initiative per character (1D6 + Reactions)
- **Why**: More granular tactics, less swingy

**Enemy AI**:
- **Tabletop**: Player consults AI tables and controls enemies
- **Digital**: Full AI automation with enhanced decision-making
- **Why**: Faster play, true "solo" experience

**Terrain Generation**:
- **Tabletop**: Manual terrain setup
- **Digital**: Procedural generation or templates
- **Why**: Faster setup, variety

**Range Measurement**:
- **Tabletop**: Physical ruler
- **Digital**: Automatic calculation
- **Why**: Precision, speed

### Minor Changes

**Automatic Tracking**:
- Credits, XP, recovery timers
- Reduces bookkeeping

**Visual Feedback**:
- HP bars, status icons, range indicators
- Easier to understand battlefield state

**Dice Display**:
- All rolls shown in log
- Complete transparency

**Undo/Redo** (limited):
- Can undo movement before shooting
- Cannot undo after combat roll

### What's Exactly the Same

**Core Mechanics**:
- D6 system unchanged
- Target numbers identical
- Damage resolution same
- Character stats match

**Campaign Structure**:
- Turn sequence identical
- World phase steps same
- Post-battle sequence matches

**Equipment Stats**:
- All weapons have same stats as tabletop
- Armor bonuses unchanged
- Gear effects identical

---

## 📊 Statistical Differences

### Probability Reference

Useful for understanding your odds:

**Target Number Probabilities** (1D6):
- TN 2+: 83% success
- TN 3+: 67% success
- TN 4+: 50% success
- TN 5+: 33% success
- TN 6+: 17% success

**With +1 Modifier** (1D6 +1):
- TN 3+: 83% success
- TN 4+: 67% success
- TN 5+: 50% success
- TN 6+: 33% success

**Toughness Save Probabilities**:
- Toughness 3: 50% save
- Toughness 4: 67% save
- Toughness 5: 83% save
- Toughness 6: 100% save (always succeeds on 1D6)

### Expected Outcomes

**Average Battle Results** (5 crew vs 5 enemies):
- Player casualties: 1-2 down
- Enemy casualties: 3-4 defeated
- Battle length: 4-6 rounds
- XP earned per survivor: 2-3

**Campaign Economics** (per turn, average):
- Income: 8-15 credits
- Expenses: 7-10 credits
- Net gain: 1-5 credits per turn
- Time to 100 credits: 20-40 turns

---

*Last Updated: January 2025*  
*Compatible with Core Rulebook v3.0 and Compendium*  
*Digital Version: 1.0.0-alpha+*