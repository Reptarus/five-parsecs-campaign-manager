# Five Parsecs from Home - Player's Guide

## 📖 Welcome to Five Parsecs from Home!

Welcome, Captain! This guide will walk you through everything you need to know to start your journey through the Fringe, leading a crew of ragtag adventurers in search of fortune, glory, and survival.

Five Parsecs from Home is a digital implementation of the popular solo tabletop game. You'll manage a crew, take on dangerous missions, upgrade your ship, and navigate the perils of frontier space.

## 🎯 What is Five Parsecs from Home?

Five Parsecs from Home is a campaign-based game where you:

- **Lead a crew** of 4-6 unique characters
- **Accept missions** from patrons, pursue rivalries, and follow quest lines
- **Fight tactical battles** on diverse battlefields
- **Manage resources** including credits, equipment, and ship upgrades
- **Make story decisions** that shape your crew's destiny
- **Survive and thrive** in the lawless Fringe sectors

### Game Flow Overview

Each campaign turn follows this pattern:
1. **Travel** - Move between star systems
2. **World Phase** - Manage crew, repair ship, find work
3. **Battle** - Fight tactical missions
4. **Post-Battle** - Collect rewards, heal injuries, advance characters

---

## 💻 Installation & Setup

### System Requirements

**Minimum Requirements:**
- **OS**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+)
- **Processor**: Dual-core 2.0 GHz
- **Memory**: 2 GB RAM
- **Graphics**: OpenGL 3.3 compatible
- **Storage**: 500 MB available space

**Recommended Requirements:**
- **OS**: Windows 11, macOS 12+, or Linux (Ubuntu 22.04+)
- **Processor**: Quad-core 2.5 GHz or better
- **Memory**: 4 GB RAM
- **Graphics**: Dedicated GPU with OpenGL 4.5+
- **Storage**: 1 GB available space (for saves and mods)

### Installation Steps

#### Windows Installation
1. Download `FiveParsecsCampaignManager-Windows.zip`
2. Extract to your preferred location (e.g., `C:\Games\FiveParsecs\`)
3. Run `FiveParsecsCampaignManager.exe`
4. First launch may take 10-15 seconds to initialize

#### macOS Installation
1. Download `FiveParsecsCampaignManager-macOS.dmg`
2. Open the DMG file
3. Drag "Five Parsecs Campaign Manager" to Applications
4. Right-click → Open (first time only, to bypass Gatekeeper)

5. Grant permissions if prompted for save file access

#### Linux Installation
1. Download `FiveParsecsCampaignManager-Linux.tar.gz`
2. Extract: `tar -xzvf FiveParsecsCampaignManager-Linux.tar.gz`
3. Navigate to extracted directory: `cd FiveParsecsCampaignManager`
4. Make executable: `chmod +x FiveParsecsCampaignManager.x86_64`
5. Run: `./FiveParsecsCampaignManager.x86_64`

### First Launch Setup

When you first launch the game:

1. **Language Selection** - Choose your preferred language (default: English)
2. **Graphics Quality** - Select Low/Medium/High based on your system
3. **Accessibility Options** - Configure screen reader, high contrast, text size
4. **Tutorial Prompt** - Choose "Yes" to start the introductory campaign

**Save File Location:**
- Windows: `%APPDATA%\Godot\app_userdata\FiveParsecsCampaignManager\`
- macOS: `~/Library/Application Support/Godot/app_userdata/FiveParsecsCampaignManager/`
- Linux: `~/.local/share/godot/app_userdata/FiveParsecsCampaignManager/`

---

## 🎮 User Interface Navigation

### Main Menu

When you launch the game, you'll see the Main Menu with these options:

**🆕 New Campaign** - Start a fresh campaign with a new crew
**📁 Load Campaign** - Continue an existing campaign from a save file
**⚙️ Settings** - Configure game options, graphics, audio, and accessibility
**📚 Tutorial** - Launch the guided introductory campaign
**📖 Rule Reference** - Access the Five Parsecs rulebook and compendium
**❓ Help** - View this guide and FAQ
**🚪 Exit** - Close the application

### Keyboard Shortcuts (Global)

- **F1** - Open Help/Quick Reference
- **F5** - Quick Save (during campaign)
- **F9** - Quick Load (from main menu)
- **Escape** - Return to previous screen/Cancel current action
- **Space** - Confirm/Continue dialog
- **Tab** - Cycle through UI elements
- **Arrow Keys** - Navigate menus and lists

### Accessibility Features

The game includes comprehensive accessibility options:

- **Screen Reader Support** - Fully compatible with NVDA, JAWS, VoiceOver
- **High Contrast Mode** - Toggle with Ctrl+F7
- **Scalable Text** - Adjust text size from 50% to 200%
- **Colorblind Modes** - Protanopia, Deuteranopia, Tritanopia filters
- **Keyboard-Only Navigation** - Full game playable without mouse
- **Reduced Motion** - Disable animations and camera shake
- **Audio Cues** - Sound indicators for important events

Access these in **Settings → Accessibility** at any time.

---

## 🚀 Your First Campaign: Complete Walkthrough

This section walks you through creating and playing your very first campaign, step by step.

### Step 1: Creating Your Campaign

1. From the Main Menu, select **New Campaign**
2. You'll enter the **Campaign Creation Wizard** with multiple phases

#### Phase 1: Campaign Configuration

**Campaign Name**: Enter a unique name for your campaign (3-50 characters)
- Example: "Fringe Runners", "The Star Wanderers", "Crimson Crew"

**Difficulty Setting**: Choose your challenge level
- **Easy** - Forgiving, great for learning (recommended for first campaign)
- **Normal** - Balanced challenge
- **Hard** - Tough battles and limited resources
- **Challenging** - For experienced players
- **Insane** - Brutal difficulty, high risk/reward

**Victory Condition**: Choose how you want to win
- **Wealth** - Accumulate 500 credits
- **Fame** - Reach renown level 10
- **Quest Complete** - Finish a major quest line
- **Story Points** - Earn 20 story points
- **Turns Survived** - Survive 50 campaign turns
- **Open-Ended** - No specific victory, play indefinitely

**Story Track** (Optional): Enable dynamic narrative events
- Recommended: **Yes** for first campaign

**Starting Credits**: The game will generate your starting funds (typically 10-30 credits)

**Tip**: For your first campaign, use **Easy difficulty**, **Wealth** victory condition, and **enable Story Track**.

#### Phase 2: Crew Size Selection

Choose how many crew members you want to start with:

- **4 Crew** - Smaller, more manageable team, higher individual character focus
- **5 Crew** - Balanced option (recommended for first campaign)
- **6 Crew** - Larger crew, more tactical options, harder to manage

More crew means more firepower but higher upkeep costs and more complex management.

**Recommendation**: Start with **5 crew members** for your first campaign.

#### Phase 3: Character Creation

Now the fun part - creating your crew! You'll create each character one at a time.

For each character, you'll determine:

**1. Species/Origin**
Roll or choose from available species:
- **Human** - Versatile, balanced stats
- **Soulless** (robots) - Immune to injuries, can't gain XP naturally
- **Precursor** - High Savvy, psychic potential
- **Feral** (uplifted animals) - Varies by type
- **Bot** (if owned) - Customizable robot crew member
- **K'Erin** - Tough warriors
- **Swift** - Fast and agile
- **Skulker** - Rodent-like, excellent climbers
- **Krag** - Stocky and belligerent
- **Engineer** - Tech specialists

**2. Background**
Your character's past determines starting skills and equipment:
- Military, Criminal, Technician, Explorer, Colonist, etc.
- Each background provides different bonuses

**3. Motivation**
Why did they join the crew?
- Survival, Wealth, Fame, Revenge, Redemption, Adventure, etc.
- Affects reactions to story events

**4. Class**
Starting specialization:
- **Soldier** - Combat focused
- **Hacker** - Tech and electronics
- **Medic** - Healing abilities
- **Mechanic** - Ship and gear repair
- **Scout** - Reconnaissance specialist
- **Psyker** - Psionic powers (if unlocked)

**5. Stats**
Each character has five core stats (rated 0-5):
- **Reactions** - Initiative in combat, dodging attacks
- **Speed** - Movement distance per turn (in inches)
- **Combat Skill** - Shooting and brawling accuracy
- **Toughness** - Damage resistance
- **Savvy** - Intelligence, hacking, psionic power

**6. Starting Equipment**
Based on background and credits available:
- Weapons (pistol, rifle, blade, etc.)
- Armor (if affordable)
- Gear (stimulants, gadgets)

**Character Creation Methods:**

**Quick Creation** (Recommended for first campaign)
- Click "Generate Random Character"
- System rolls everything automatically
- Adjust name and appearance
- Repeat for all crew members
- Takes ~30 seconds per character

**Manual Creation**
- Roll each table individually
- Make choices where options exist
- Fully customize your crew
- Takes ~2-5 minutes per character

**Tip**: Use Quick Creation for your first campaign to get playing faster!


#### Phase 4: Ship Setup

Your crew needs a ship! The campaign wizard will help you acquire one.

**Ship Name**: Give your ship a memorable name
- Examples: "Void Runner", "Lucky Star", "Rusty Bucket", "Crimson Dawn"

**Ship Type**: Your starting ship is typically a basic freighter
- **Hull Points**: How much damage the ship can take (usually 20-30)
- **Cargo Capacity**: How much equipment you can carry
- **Upgrade Slots**: Spaces for future improvements

**Initial Ship Debt** (Optional rule):
- Most crews start with a ship loan (10-50 credits)
- Must be repaid with interest
- Adds challenge but provides better starting ship

**Tip**: Accept the ship debt for a better starting vessel. You can pay it off within 5-10 turns.

#### Phase 5: Starting Situation

The wizard generates your initial campaign state:

**Starting World**: Your first location in Fringe space
- World type (Colony, Industrial, Frontier, etc.)
- Population traits (Busy, Dangerous, Restricted, etc.)
- Available services and markets

**Patrons**: Initial job contacts (0-2 patrons)
**Rivals**: Enemies from your crew's pasts (0-2 rivals)
**Rumors**: Leads on opportunities or dangers

**Story Track Setup** (if enabled):
- Starting Story Points: Usually 1-2
- Initial story threads

**Initial Credits**: Final starting funds after all deductions (typically 5-20 credits)

Click **"Launch Campaign"** to begin your adventure!

---

## 🎲 Campaign Turn Walkthrough

Each campaign turn follows a structured sequence. Let's walk through your very first turn.

### Turn 1: Your First Steps

When you launch your campaign, you'll land on the **Campaign Dashboard** - your mission control center.

#### Campaign Dashboard Overview

The Campaign Dashboard has several key areas:

**Top Bar**:
- Campaign name and turn counter
- Current world and location
- Credits on hand
- Story Points available
- Quick Save/Load buttons

**Left Panel - Crew Roster**:
- All crew members listed with portraits
- Health status (green = healthy, yellow = injured, red = critical)
- XP bars showing advancement progress
- Click any crew member for detailed stats

**Center Panel - Current Status**:
- Ship status and hull integrity
- Active missions and deadlines
- Upcoming events and warnings
- Available actions for this turn

**Right Panel - World Information**:
- Current world details
- Available facilities (markets, medical, training)
- Known patrons and rivals on this world
- Travel options

**Bottom Panel - Action Bar**:
- Main actions you can take this turn
- Navigation between different screens
- End Turn button (when ready)

### Step 1: Travel Phase

On your first turn, you're already planetside, so no travel needed.

**Travel Phase Actions** (for future turns):
- **Stay on Current World**: Continue here
- **Travel to New World**: Move to adjacent star system
- **Use Star Map**: View known worlds and plan route

**Skip this phase on Turn 1.**

### Step 2: World Phase - The Heart of Campaign Management

This is where you manage your crew between battles. On Turn 1, you'll do several things:

#### A. Pay Upkeep (Automatic)

The game automatically deducts upkeep costs:
- **Ship Maintenance**: ~1-2 credits per turn
- **Crew Wages**: ~1 credit per crew member
- **Debt Payments**: If you have ship loan

**Turn 1 Total**: ~7-10 credits typically

If you can't afford upkeep, you'll receive a warning and may need to sell equipment or take immediate work.

#### B. Assign Crew Tasks

Each crew member can perform ONE task per turn (except injured crew). Click on a crew member and choose:

**Find a Patron** 
- Search for new job contacts
- Chance to gain a new patron
- Important for finding missions
- **Recommend: Assign 1 crew member**

**Trade** 
- Buy/sell equipment at market
- Prices vary by world type
- Good for upgrading gear
- **Recommend: Assign 1 crew member if needed**

**Explore** 
- Scout the area for opportunities
- May find items, credits, or encounters
- Random events possible
- **Recommend: Assign 1 crew member**

**Train** 
- Practice skills for bonus XP
- Costs 1 credit
- Helps with advancement
- **Skip on Turn 1** (save credits)

**Recruit** 
- Look for new crew members
- Costs 1-3 credits per recruit
- Only if you have crew slots
- **Skip on Turn 1** (crew is full)

**Repair Kit** 
- Craft repair equipment
- Requires parts
- **Skip on Turn 1**

**Decoy** 
- Create combat decoys
- Advanced tactic
- **Skip on Turn 1**

**Track** 
- Hunt down a rival
- Requires active rival
- **Skip if no rivals**

**Example Turn 1 Assignments**:
- Crew #1: Find a Patron
- Crew #2: Explore
- Crew #3: Trade (if need equipment)
- Crew #4 & #5: Reserve for battle

Click **"Resolve Tasks"** and watch the results!

#### C. Review Task Results

The game processes each task and shows results:

**Find a Patron Results**:
- Success: "Met a local shipping magnate. Patron added!"
- Failure: "No promising contacts found today."

**Explore Results**:
- Might find: Credits, equipment, rumors, or encounters
- Example: "Found 3 credits in an abandoned cache!"

**Trade Results**:
- Shows available items based on world market
- Purchase weapons, armor, gear
- Sell unwanted equipment

#### D. Determine Job Offers

After tasks, available missions appear:

**Patron Jobs** 
- Jobs from your patrons
- Better pay and rewards
- Build relationship with patron
- May have special conditions

**Opportunity Missions** 
- Random jobs anyone can take
- Variable pay
- Good for starting out
- No strings attached

**Rival Encounters** 
- Confrontations with enemies
- May be unavoidable
- Higher risk but can earn respect

**Quest Missions** 
- Story-driven objectives
- Part of larger narrative
- Best rewards
- Require story points to unlock

**Turn 1 Expectations**: 
- 1-2 Opportunity missions available
- Possibly 1 Patron job if you have a patron
- Low-risk missions (patrols, deliveries, salvage)

#### E. Assign Equipment

Before choosing a mission, equip your crew:

1. Click **"Crew Management"** → **"Equipment"**
2. Each crew member has slots:
   - **Primary Weapon** (rifle, pistol, etc.)
   - **Secondary Weapon** (backup pistol, blade)
   - **Armor** (if owned)
   - **Gear** (grenades, stims, gadgets)
   - **Consumables** (med-kits, booster pills)

**Turn 1 Equipment Tips**:
- Distribute weapons evenly (everyone should have at least 1 weapon)
- Give best weapons to characters with high Combat Skill
- Save armor for characters who will move forward
- Keep at least 1 medkit in reserve

Click **"Confirm Equipment"** when ready.

#### F. Choose Your Battle

Review available missions and select one:

**Mission Information Shows**:
- **Mission Type**: Patrol, Opportunity, Rival fight
- **Objective**: What you need to accomplish
- **Difficulty**: Enemy strength estimate
- **Payment**: Credits offered
- **Patron**: Who hired you (if applicable)
- **Deadline**: Turns remaining (if any)

**First Mission Recommendation**:
Choose an **Opportunity mission** with:
- **Low difficulty** (1-2 skulls)
- **Simple objective** (Move through, Patrol, Secure area)
- **Decent pay** (5+ credits)

Example good first mission:
> "**Patrol the Perimeter**"  
> Type: Opportunity  
> Objective: Move through the area  
> Difficulty: ⚔️ (Easy)  
> Payment: 6 credits  
> "Local merchants need security presence to deter thieves."

Click **"Accept Mission"** to proceed to battle!

---

## ⚔️ Your First Battle: Step-by-Step

When you accept a mission, the game transitions to the **Tactical Battle Screen**.

### Battle Setup Phase

#### 1. Battle Briefing

The screen shows:
- **Objective**: Your specific goal (e.g., "Move any crew member to the far side of the battlefield")
- **Enemy Forces**: What you're facing (e.g., "3-5 unknown hostiles")
- **Deployment Condition**: Where you start (e.g., "Standard deployment")
- **Notable Sight**: Special battlefield feature (e.g., "Ancient wreckage")
- **Terrain**: Battlefield environment (Desert, Urban, Rocky, Forest)

Read this carefully! Understanding your objective is critical.

#### 2. Battlefield Generation

The game generates a tactical map:
- **Size**: Typically 2-3 feet equivalent (tabletop)
- **Terrain Features**: Cover, obstacles, elevation
- **Deployment Zones**: Where you and enemies start

**Cover Types**:
- 🟩 **Light Cover**: -1 to enemy hit rolls
- 🟧 **Heavy Cover**: -2 to enemy hit rolls
- 🟥 **Solid Cover**: Complete protection from one direction

#### 3. Deploy Your Crew

Place your crew members in your deployment zone:

**Deployment Tips**:
- Spread out (don't cluster together)
- Put tough/armored characters in front
- Keep support characters (medics) in back
- Use cover immediately
- Position shooters with clear lines of sight

**Mouse Controls**:
- Click and drag crew portraits to battlefield
- Right-click to rotate facing direction
- Scroll wheel to zoom in/out

When positioned, click **"Confirm Deployment"**.

#### 4. Enemy Deployment

The game places enemy forces:
- Enemies deploy in their zone
- Initial count revealed
- Enemy types shown (Punks, Raiders, Mercs, etc.)

### Battle Round Sequence

Battles play out in rounds. Each round has four phases:

#### Phase 1: Quick Actions

Before initiative is rolled, some actions can happen:
- **Dash moves**: Characters can reposition
- **Overwatch**: Set up defensive positions
- **Use items**: Activate equipment

**Turn 1 Recommendation**: Skip quick actions unless you spot immediate danger.

#### Phase 2: Roll Initiative

Each character rolls for initiative:
- Roll 1D6 + Reactions stat
- Higher total = acts first
- Characters activate in order

**Your first character's turn!**

#### Phase 3: Character Activation

When it's your character's turn, you can:

**1. Move** (up to Speed distance)
- Click destination on battlefield
- Character moves there
- Can split move (move, shoot, move)
- Rough terrain slows movement

**2. Shoot** (if carrying ranged weapon)
- Click "Shoot" button
- Select target enemy
- Game calculates:
  - Range to target
  - Cover bonuses for target
  - Your Combat Skill
- Roll to hit (1D6 + Combat Skill vs target number)
- If hit, roll damage

**3. Brawl** (if adjacent to enemy)
- Click "Brawl" button
- Both characters roll 1D6 + Combat Skill
- Higher roll wins
- Winner deals damage
- Loser may be stunned or knocked back

**4. Use Item/Ability**
- Activate special equipment
- Use character abilities
- Spend story points for re-rolls

**5. Take Cover**
- Move behind obstacle
- Gain cover bonus
- Reduces chance to be hit

**First Turn Tactics**:
1. Move to better cover if exposed
2. Shoot at closest, most dangerous enemy
3. Focus fire (multiple crew shooting same target)
4. Don't rush forward alone

**Example First Turn**:
> Character: Sara "Gunner" Martinez (Combat Skill +1, Speed 5")
> 1. Move 5" forward to heavy cover (crate)
> 2. Shoot at Raider #1 (10" away)
>    - Roll: 4 + 1 (Combat) = 5
>    - Target number: 5 (base) + 2 (range) - 1 (raider in light cover) = 6
>    - Miss! Bullet sparks off nearby wall.
> 3. End turn in cover

#### Phase 4: Enemy Activation

Enemies act according to AI rules:
- The game controls enemy movement
- Enemies move toward objectives or your crew
- Enemies shoot when in range
- Enemies seek cover when hurt

Watch enemy actions carefully - learn their patterns!

### Continuing the Battle

Rounds continue until:
- **Victory**: Objective completed + enemies flee/defeated
- **Defeat**: All crew members down or fled
- **Withdrawal**: You choose to retreat

**Battle Tips**:
- **Use cover religiously** - being in the open is deadly
- **Focus fire** - eliminate enemies one at a time
- **Protect wounded** - get injured crew to safety
- **Watch ammunition** - some weapons have limited shots
- **Use consumables** - stims and medkits can save lives
- **Know when to retreat** - survival > mission success

### Victory Conditions by Mission Type

**Move Through**: 
- Get 1+ crew to opposite edge
- Can extract with crew there

**Patrol**:
- Survive 6 combat rounds
- Stay on battlefield

**Eliminate Enemy**:
- Defeat all hostiles
- Last enemy may flee

**Secure Area**:
- Hold specific positions
- Defend for several rounds

**Your First Battle Goal**:
Just survive and learn the basics. Don't worry about perfect tactics yet!

---

## 🏥 Post-Battle Sequence

After battle ends (win or lose), you enter the **Post-Battle Sequence**:

### 1. Immediate Results

**Rival Status Update**:
- If you fought a rival, relationship changes
- Defeating rivals may convert them to patrons

**Illegal Activity Check**:
- If you used banned weapons/psionics
- May attract law enforcement attention

**Patron Status**:
- Mission success/failure recorded
- Patron relationship affected

### 2. Get Paid

**Mission Reward**:
- Base payment delivered
- Bonuses for objectives met
- Penalties for collateral damage

**Example**: 
> "Mission Success: Patrol the Perimeter"  
> Base Payment: 6 credits  
> No enemies escaped: +2 credits  
> Total: **8 credits earned**

### 3. Battlefield Finds

After battle, characters can search the area:
- Roll 1D6 per crew member who participated
- May find: Credits, weapons, equipment, gadgets
- Better locations have better loot

**Example**: 
> Sara finds: 2 credits  
> Marcus finds: Damaged pistol (can sell for 1 credit)  
> Total finds: 3 credits value

### 4. Gather Loot

Collect items from defeated enemies:
- Each defeated enemy may drop equipment
- Weapons, armor, gear
- Keep or sell

**Loot Management**:
- Auto-equip better items
- Store in ship cargo
- Sell for credits

### 5. Injuries and Recovery

**Check each crew member who took damage**:

If reduced to 0 HP during battle:
- Roll on Injury Table
- Results range from:
  - **Light Injury**: -1 to stat for 1-2 turns
  - **Serious Wound**: Out for 3+ turns
  - **Permanent Injury**: Stat permanently reduced
  - **Death**: Character killed (rare on easy difficulty)

**Medical Care**:
- Medkits reduce injury severity
- Medical facilities speed recovery
- Some injuries require specific treatment

**Turn 1 Expectation**: 
Hopefully no serious injuries, but if someone gets hurt:
- Check how many turns recovery takes
- Note any stat penalties
- Injured crew can't fight until healed

### 6. Experience and Advancement

Crew members who fought gain XP:
- **Participated in battle**: +1 XP
- **Landed a hit**: +1 XP
- **Defeated enemy**: +1 XP
- **Objective completed**: +1 XP

**Total typical XP per battle**: 2-4 XP

**Advancement**:
- At 5 XP: Character levels up
- Choose stat increase OR new ability
- Becomes more powerful

**Example**:
> Sara earned 3 XP (battle, hit, objective)
> Sara's total: 3/5 XP to next level

### 7. Purchase Items

Visit the market to buy/sell:

**Weapons** (typical costs):
- Scrap pistol: 2 credits
- Military rifle: 6 credits
- Shotgun: 5 credits
- Blade: 2 credits

**Armor**:
- Flak vest: 4 credits
- Battle dress: 8 credits
- Combat armor: 12 credits

**Gear**:
- Medkit: 3 credits
- Grenades: 4 credits
- Booster pills: 2 credits

**Shopping Tips**:
- Prioritize weapons first
- Get medkits for safety
- Save for armor when affordable
- Don't spend everything - keep emergency funds

### 8. Campaign Events

Random events may occur:
- New opportunities arise
- World conditions change
- Story developments
- Character personal events

Read these carefully - they add flavor and may affect future turns!

### 9. Check for Invasion

Rarely, worlds get invaded by hostile forces:
- Must flee immediately or fight overwhelming odds
- Lose access to that world
- Can return later to liberate it

**Turn 1**: Extremely unlikely to happen.

### End of Turn

Click **"End Turn"** to proceed to Turn 2!

The cycle begins again: Travel → World Phase → Battle → Post-Battle

---

## 📊 Understanding Your Crew

### Character Stats Explained

**Reactions** (0-5, average: 1)
- Determines initiative order in combat
- Higher = acts first
- Affects dodging ranged attacks
- Important for aggressive characters

**Speed** (3"-8", average: 5")
- Movement distance per turn
- Measured in tabletop inches
- Affects tactical positioning
- Higher = more mobility

**Combat Skill** (+0 to +3, average: +1)
- Added to shooting rolls
- Added to brawling rolls
- Higher = better accuracy
- Most important combat stat

**Toughness** (3-5, average: 4)
- Damage resistance
- Roll equal/under to resist damage
- Higher = survives more hits
- Critical for front-line fighters

**Savvy** (+0 to +3, average: +1)
- Intelligence and cunning
- Affects hacking, tech use
- Determines psionic power (if applicable)
- Used for some skill checks

### Character Advancement Path

As characters gain XP, they level up and improve:

**Level 2** (5 XP):
- +1 to any stat OR new ability
- Examples: +1 Combat Skill, +1" Speed

**Level 3** (10 XP total):
- Another improvement
- May unlock special abilities

**Level 5+** (20+ XP):
- Elite status
- Multiple stat bonuses
- Special abilities unlocked
- Can mentor other crew

**Ability Examples**:
- **Snap Shot**: Shoot before moving
- **Veteran**: Re-roll one die per battle
- **Medic Training**: Better healing
- **Iron Will**: Resist mental effects
- **Tech Expert**: Hack devices faster

### Character Specialization Strategy

**Build Types**:

**Glass Cannon** (High Combat, Low Toughness):
- Focus: +Combat Skill upgrades
- Role: Rear guard sniper
- Tactics: Stay in cover, pick off enemies
- Risk: Dies if caught in close combat

**Tank** (High Toughness, Moderate Combat):
- Focus: +Toughness, +Speed
- Role: Front-line distraction
- Tactics: Draw fire, soak damage
- Strength: Hard to kill

**Speedy Scout** (High Speed, High Reactions):
- Focus: +Speed, +Reactions
- Role: Flanker, objective grabber
- Tactics: Fast movement, hit and run
- Advantage: Always acts first

**Balanced Fighter** (Even stats):
- Focus: Gradual improvements across all stats
- Role: Flexible squad member
- Tactics: Adapt to situation
- Reliability: Never weak anywhere

---

## 🚢 Managing Your Ship

Your ship is your mobile base and safe haven.

### Ship Systems

**Hull Points** (HP):
- Ship's health
- Starts at 20-30 HP typically
- Damaged by ship combat (rare) or events
- Repair at shipyard (costs credits)

**Cargo Capacity**:
- How much equipment you can store
- Typical start: 10-15 cargo slots
- Each weapon/item takes 1 slot
- Upgrade to carry more

**Upgrade Slots**:
- Spaces for ship improvements
- Usually 2-4 slots initially
- Add weapons, shields, sensors

### Ship Upgrades

**Weapons** (Ship Combat):
- Turrets: Defense against pirates
- Missiles: Offensive capability
- Cost: 15-25 credits

**Defense**:
- Shields: Absorb damage
- Armor: Reduce damage taken
- Cost: 10-20 credits

**Systems**:
- Enhanced sensors: Detect threats
- Faster engines: Better escape chance
- Medical bay: Faster crew healing
- Cost: 12-30 credits

**Luxury**:
- Crew quarters: Better morale
- Recreation: XP bonuses
- Cost: 10-15 credits

**Ship Upgrade Priority**:
1. Medical bay (if affordable)
2. Extra cargo space
3. Basic defense (shields)
4. Luxury items (late game)

---

## 💰 Economic Management

### Income Sources

**Mission Pay**:
- Primary income
- 5-15 credits per mission (early game)
- Increases with difficulty

**Battlefield Loot**:
- Found items
- Enemy equipment
- Average: 2-5 credits value per mission

**Trading**:
- Buy low, sell high
- Varies by world type
- Can be profitable but risky

**Patrons**:
- Better mission pay
- Bonuses for loyalty
- Long-term relationships

### Expenses

**Per Turn Costs**:
- Ship upkeep: ~2 credits
- Crew wages: ~1 credit per crew member
- Debt payment: Varies (if applicable)
- **Total**: ~7-10 credits per turn

**One-Time Costs**:
- Equipment purchases
- Ship repairs
- Medical treatment
- Training fees

### Budget Management Tips

**Rule of Thumb**:
- Keep 15+ credits in reserve
- Never go below 10 credits
- Save for emergencies (medical, ship damage)

**Early Game Focus**:
- Weapons for all crew
- One medkit minimum
- Basic armor for 2-3 crew
- Don't overspend

**Mid Game Goals**:
- Full crew armor
- Ship upgrades
- Specialty weapons
- Training investments

**Late Game Wealth**:
- Premium equipment
- Multiple ship upgrades
- Hire additional crew
- Pursue quests freely

---

## 🌍 World Types and Navigation

### Common World Types

**Colony Worlds**:
- Developing settlements
- Cheap labor, basic markets
- Good mission variety
- Low tech equipment

**Industrial Worlds**:
- Manufacturing centers
- Expensive goods but available
- Many patron opportunities
- High tech equipment

**Frontier Worlds**:
- Edge of civilized space
- Dangerous, lawless
- High risk missions
- Rare equipment sometimes available

**Agricultural Worlds**:
- Farming communities
- Very cheap living costs
- Limited mission types
- Basic equipment only

**Mining Worlds**:
- Resource extraction
- Hazardous environments
- Salvage opportunities
- Industrial equipment

**Pleasure Worlds**:
- Entertainment and luxury
- Expensive everything
- Social missions
- High-end gear available

### World Traits

Each world has 1-2 special traits:

**Busy Markets**: More equipment available
**Dangerous**: More hostile encounters
**Restricted**: Weapon bans enforced
**Wealthy**: Higher mission pay
**Medical Hub**: Better healing facilities
**Tech Center**: Advanced equipment
**Lawless**: No regulations

### Travel Strategy

**When to Travel**:
- No good missions available
- Fleeing invasion
- Following quest leads
- Market shopping (specific gear)
- Avoiding rivals temporarily

**Travel Costs**:
- Fuel: 1-3 credits
- Travel time: 1 turn
- Risk: Random encounter possible

**Travel Tips**:
- Plan 2-3 turns ahead
- Keep notes on good worlds
- Diversify patron relationships
- Build network of safe havens

---

## 🎯 Mission Types Guide

### Opportunity Missions

**Description**: Generic jobs available to anyone
**Pay**: Low to moderate (5-12 credits)
**Risk**: Variable
**Availability**: Always 1-2 available

**Common Objectives**:
- Move through: Cross the battlefield
- Patrol: Survive 6 rounds
- Secure area: Hold positions
- Eliminate target: Kill specific enemy

**Best For**: Starting out, building funds, low pressure

### Patron Missions

**Description**: Jobs from your patron contacts
**Pay**: Moderate to high (10-20 credits)
**Risk**: Moderate
**Availability**: Requires patron relationship

**Benefits**:
- Better rewards
- Relationship building
- May unlock special equipment
- Story connections

**Consequences**:
- Failure damages relationship
- May lose patron if repeated failures
- Sometimes mandatory

### Quest Missions

**Description**: Story-driven objectives
**Pay**: Variable, often non-monetary rewards
**Risk**: High
**Availability**: Requires story points to unlock

**Rewards**:
- Unique items
- Story progression
- Permanent bonuses
- Reputation gains

**Requirements**:
- Spend 1-2 story points
- May need specific crew/equipment
- Often multi-part

### Rival Encounters

**Description**: Confrontations with enemies
**Pay**: None (unless bounty available)
**Risk**: High
**Availability**: Random when rival active

**Outcomes**:
- Defeat rival: Gain respect, may become patron
- Lose: Rival grows stronger
- Flee: Rival relationship worsens

### Special Mission Types

**Stealth Missions**:
- Avoid detection
- Non-lethal options
- High skill requirement
- Excellent rewards if successful

**Salvage Jobs**:
- Explore derelict ships/bases
- Find valuable items
- Unknown dangers
- High loot potential

**Street Fights**:
- Urban combat
- Civilians present
- Police involvement risk
- Close quarters

---

## 🎲 The Story Track System

The Story Track adds narrative depth to your campaign.

### What is the Story Track?

A secondary progression system that:
- Generates story events
- Unlocks quest missions
- Provides narrative context
- Rewards role-playing choices

### Story Points

**Earning Story Points**:
- Complete quest missions: +2-3 SP
- Significant milestones: +1 SP
- Story events: Variable
- Character achievements: +1 SP

**Spending Story Points**:
- Unlock quest missions: -1 to -2 SP
- Re-roll critical failures: -1 SP
- Avoid negative events: -1 SP
- Activate special abilities: -1 SP

**Managing Story Points**:
- Keep 2-3 in reserve
- Don't hoard excessively
- Use for critical moments
- Invest in quests regularly

### Story Events

Random narrative events occur:
- Character backstory elements
- World developments
- New opportunities
- Relationship changes

**Example Story Event**:
> "A message arrives from Marcus's past. His former commander needs help on a nearby world. This could be dangerous... or profitable."
> 
> Choice:
> A) Investigate (spend 1 SP, unlock quest)
> B) Ignore (safe, no cost)

### Story Track Advancement

As you complete story missions:
- Unlock new narrative threads
- Build relationships with factions
- Reveal larger plots
- Create epic campaign moments

**Tip**: The Story Track is optional but highly recommended for immersive play!

---

## ❓ Frequently Asked Questions

### Getting Started

**Q: How long does a typical campaign last?**
A: 20-50 turns for shorter victory conditions, 100+ for open-ended play. Each turn takes 15-30 minutes.

**Q: Can I have multiple campaigns?**
A: Yes! Save slots are unlimited. Create different crews, try different playstyles.

**Q: What difficulty should I start with?**
A: Easy or Normal for first campaign. You can adjust later.

**Q: Do I need to know the tabletop rules?**
A: No! The game handles all rules automatically. This guide teaches you everything needed.

### Campaign Management

**Q: What happens if all my crew dies?**
A: Campaign ends. You can recruit new crew if credits allow, or start fresh.

**Q: Can I rename characters after creation?**
A: Yes, in Crew Management → Character Details → Edit Name.

**Q: How do I fire a crew member?**
A: Crew Management → Select character → Dismiss. They leave with no penalty.

**Q: Can I recruit mid-campaign?**
A: Yes, use the "Recruit" crew task. Costs 1-3 credits per new member.

### Combat Questions

**Q: How does cover work exactly?**
A: Light cover gives -1 to enemy hit rolls, Heavy cover gives -2. Must be between you and shooter.

**Q: Can I shoot through teammates?**
A: No, teammates block line of sight. Position carefully.

**Q: What happens when I run out of ammo?**
A: Most weapons have unlimited ammo. Special weapons (heavy guns) track ammunition.

**Q: Can I retreat from losing battles?**
A: Yes, click "Withdraw" button. Forfeit mission pay but save your crew.

**Q: Do enemies respawn during battle?**
A: Only on specific mission types ("Escalating Battles" optional rule). Usually no.

### Equipment & Economy

**Q: Can I sell starting equipment?**
A: Yes, but not recommended early. You need those weapons.

**Q: Where's the best place to buy equipment?**
A: Industrial and Tech Center worlds have best selection.

**Q: Do weapons degrade or break?**
A: No, equipment lasts forever unless lost in battle.

**Q: How much should I save for emergencies?**
A: Keep at least 15 credits in reserve for medical/repairs.

### Progression

**Q: How fast do characters level up?**
A: Typically 2-3 battles per level early on, slower at higher levels.

**Q: What's the level cap?**
A: No hard cap, but diminishing returns after level 10.

**Q: Can I respec a character?**
A: Not currently. Choose upgrades carefully.

**Q: Do characters retire?**
A: Optional rule. Can set retirement conditions if desired.

### Technical

**Q: Where are save files stored?**
A: See "First Launch Setup" section for OS-specific paths.

**Q: Can I backup my saves?**
A: Yes! Copy the entire save folder to backup location.

**Q: Does the game autosave?**
A: Yes, after each major phase. Manual F5 quicksave also available.

**Q: Can I mod the game?**
A: Yes! See the Modding Guide (coming soon) for details.

**Q: The game crashed, did I lose progress?**
A: Probably not. Check autosave from last turn.

### Troubleshooting

**Q: Game runs slowly/laggy**
A: Lower graphics settings in Options → Display → Quality: Low

**Q: Can't find save file**
A: Use Settings → Campaign → Locate Save Files button

**Q: Battle won't let me end turn**
A: All characters must complete actions. Click "Skip" for inactive characters.

**Q: Screen reader not working**
A: Enable in Options → Accessibility → Screen Reader: ON

**Q: Controls not responding**
A: Check Options → Controls → Reset to Defaults

---

## 🎓 Advanced Tips & Strategy

### Early Game (Turns 1-10)

**Priorities**:
1. Survive battles - don't take unnecessary risks
2. Build credit reserve (15+ credits)
3. Equip all crew with basic weapons
4. Find 2-3 reliable patrons
5. Learn combat mechanics

**Avoid**:
- High risk missions
- Expensive purchases
- Rival confrontations
- Travel without purpose

### Mid Game (Turns 11-30)

**Focus**:
1. Upgrade crew armor
2. Specialize characters
3. Improve ship
4. Pursue quests
5. Build faction relationships

**Strategic Goals**:
- Level crew to 3-5
- Acquire specialist weapons
- Install ship upgrades
- Complete 1-2 quest lines

### Late Game (Turns 31+)

**Objectives**:
1. Maximize crew power
2. Complete victory condition
3. Pursue epic quests
4. Dominate challenging missions
5. Build legacy

**End Game Activities**:
- Elite missions
- Faction warfare
- Epic quest conclusions
- Legendary equipment acquisition

### Combat Mastery

**Positioning Fundamentals**:
- Always use cover
- Create crossfires
- Control chokepoints
- Protect flanks

**Target Priority**:
1. Enemies with heavy weapons
2. Enemy leaders (if present)
3. Wounded enemies (finish them off)
4. Isolated targets

**Advanced Tactics**:
- Suppress enemies (keep them pinned in cover)
- Leapfrog advance (move in pairs)
- Hold reserves (don't commit everyone immediately)
- Create kill zones (force enemies through firing lanes)

### Resource Optimization

**Credit Management**:
- Spend 60% on essentials (weapons/armor)
- Save 30% for emergencies
- Invest 10% in growth (training/upgrades)

**Equipment Lifecycle**:
1. Early: Basic weapons, no armor
2. Mid: Upgraded weapons, some armor
3. Late: Specialist gear, full armor, mods

**Time Management**:
- Plan 3-5 turns ahead
- Track patron relationships
- Note world traits
- Schedule ship upgrades

---

## 🏆 Victory Conditions Explained

### Wealth Victory (500 Credits)

**Strategy**:
- Accept all profitable missions
- Trade aggressively
- Minimize expenses
- Sell excess equipment

**Timeline**: 25-40 turns
**Difficulty**: Medium
**Best For**: Economic focus players

### Fame Victory (Renown 10)

**Strategy**:
- Complete high-profile missions
- Defeat rivals publicly
- Build patron relationships
- Complete quests

**Timeline**: 30-50 turns
**Difficulty**: Medium-Hard
**Best For**: Combat-focused players

### Quest Complete Victory

**Strategy**:
- Prioritize story track
- Spend story points on quests
- Build required crew specializations
- Gather quest-specific gear

**Timeline**: 20-40 turns
**Difficulty**: Variable
**Best For**: Narrative-focused players

### Story Points Victory (20 SP)

**Strategy**:
- Complete many quests
- Trigger story events
- Make narrative choices
- Balance SP earning/spending

**Timeline**: 35-60 turns
**Difficulty**: Hard
**Best For**: Story lovers

### Survival Victory (50 Turns)

**Strategy**:
- Conservative play
- Risk management
- Steady income
- Avoid rivalries

**Timeline**: 50 turns (fixed)
**Difficulty**: Medium
**Best For**: Patient players

### Open-Ended Play

**Strategy**: Whatever you enjoy!
**Timeline**: Infinite
**Difficulty**: Your choice
**Best For**: Sandbox lovers

---

## 📚 Additional Resources

### In-Game Help

- Press **F1** anytime for context help
- Hover tooltips explain stats/mechanics
- Combat log shows detailed calculations
- Tutorial missions available from main menu

### Community Resources

- Official Forums: [Link]
- Discord Community: [Link]
- Strategy Wiki: [Link]
- YouTube Guides: [Link]

### Further Reading

- **Core Rulebook Reference** (in-game)
- **Compendium Content Guide** (docs/gameplay/)
- **Modding Guide** (docs/modding/)
- **Developer API** (docs/developer/)

---

## 🎉 You're Ready to Play!

Congratulations, Captain! You now have everything you need to start your Five Parsecs campaign.

**Your Next Steps**:
1. Launch the game
2. Create your first campaign
3. Build your crew
4. Accept your first mission
5. Survive and thrive!

Remember:
- Start on **Easy difficulty**
- Take your time learning
- Don't fear failure - it's part of the story
- Every campaign is unique
- Most importantly: **Have fun!**

May fortune favor you in the Fringe!

---

*Last Updated: January 2025*  
*Guide Version: 1.0.0*  
*Compatible with Game Version: 1.0.0-alpha+*