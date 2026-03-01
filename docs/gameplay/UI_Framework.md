UI Framework & QOL Feature Suggestions
Recommended UI Framework
Mobile-First Hybrid Approach with Phase-Based Contexts

Your existing architecture is already solid - build on it:

Keep your responsive container system - It's working well

Adopt Infinity Army's philosophy: Different UI density for different contexts

Builder Mode (desktop-friendly): Dense info for crew building, equipment management, campaign setup
Play Mode (mobile-optimized): Streamlined for at-table reference during physical play
Manager Mode (balanced): Post-game resolution, progression, shopping
Information Hierarchy Pattern:

Primary: Dashboard always shows turn, credits, crew health, active mission
Secondary: Expandable sections for equipment, ship status, relationships
Tertiary: Progressive disclosure for detailed stats, full rule text
Card-Based Layouts for crew (you're doing this) - continue using for:

Character roster (2-3 columns mobile, 4-6 desktop)
Equipment items
Missions/contracts
Rivals/Patrons
Hyperlinked Keywords - This is THE killer feature to implement

Every keyword/trait/ability should be tappable
Shows definition in overlay without leaving context
Cross-reference related rules automatically
Feedback on Your Proposed QOL Features
✅ Dedicated Crew Builder - EXCELLENT
Why: Essential for this type of game

Separate from campaign loop = perfect for sharing builds, theorycrafting
Implement as standalone mode accessible from main menu
Export/import as JSON and PDF
Include validation against game rules
Add: Template system (starter crews, archetype presets)
Add: Random crew generator with constraints
✅ In-Game Tracking Separate from Main Loop - GREAT IDEA
Why: Supports "companion app" philosophy

Editable character sheets that update during physical play
Quick wound tracking, ammo counting, status effects
Key: Make this the "Play Mode" - minimal chrome, maximum clarity
Touch-friendly +/- buttons for health, ammo
Undo last change functionality
Add: Simple round counter, turn order tracker
✅ Keyword Implementation - CRITICAL PRIORITY
Why: You identified this as possibly redundant with glossary - it's NOT

This is Infinity Army's secret sauce
Every keyword should:
Have tap-to-reveal definition
Show related keywords
Link to full rules if needed
Appears contextually (on character sheets, equipment, etc.)
Implementation: Leverage your existing tooltip system
Add: Search glossary, bookmark frequently used terms
✅ Basic MD/TXT Editor for Notes - GOOD, with caveats
Why: Campaign journal is huge for narrative games

You have logbook UI already - complete it!
Markdown is overkill - rich text is sufficient
Simpler approach:
Date-stamped entries (auto-generated or manual)
Attach to specific turns/missions
Tag with characters, locations, rivals
Export to PDF or TXT for sharing
Cross-device: Save to user directory, allow manual sync via export/import
Add: Auto-generated entries from major events ("Crew member killed", "Rival defeated")
✅ Major Events/History Trackers - ESSENTIAL
Why: This is what makes campaigns memorable Your combat log is good - extend the pattern:

Campaign Timeline:

Visual timeline of major events
Turn-by-turn log
Filter by type (battles, story events, character events, purchases)
Add: "Campaign Highlights" - player can flag memorable moments
Add: Photo attachment for battle reports (screenshot physical table setup)
Character History:

Individual character journals
Injuries sustained (with dates)
Battles participated in
Relationships formed
XP milestones
Add: "Character Story" auto-generated from events
Rival/Patron Tracker:

Encounter history with each
Relationship progression
Unresolved conflicts
Add: "Nemesis System" - track recurring antagonists across campaigns
⚠️ Glossary/Reference Section - NOT Redundant
Why: Different from keywords

Keywords = contextual, inline definitions
Glossary = comprehensive reference for browsing/learning
You have RulesReference already - that's your glossary
Improve: Add better search, categorization, bookmarks
Add: "Frequently Asked Questions" section
Add: Quick reference sheets (printable)
✅ Import/Export Custom Crews - Already Good
Why: You have PDF and JSON export

Complete the import UI (file picker)
Add: Community sharing features (export with QR code?)
Add: Crew templates/archetypes for quick starts
Add: Validate imports to prevent broken data
✅ Bug Hunt Integration - Good Forward Thinking
Why: Mode-switching support

Design crew builder to support multiple rulesets
Tag crews by compatible game modes
Add: Mode selector in crew builder
Add: Rule variations per mode
✅ Crew/Ship Inventory + NPC/POI Management - CRITICAL
Why: Persistence creates immersion You have ShipInventory already - extend it:

Inventory:

Current weight-based system is good
Add: Item stash on ship vs carried by character
Add: Equipment sets/loadouts for quick swapping
Add: Shopping list/wishlist for equipment goals
NPC Persistence:

Patron System:
Tied to locations (planet/station)
Relationship values
Available jobs history
Favors owed
Rival System:
Tracks your existing encounters
Escalation mechanics
"Unfinished Business" tracker
Location associations
POI (Point of Interest) / Location Tracking:

Galaxy Map:
Track visited systems
Reputation per system
Available facilities (market, hospital, etc.)
Danger level history
Rumors/hooks per location
Location Memory:
Remember NPCs met at each location
Return to same patrons at same places
Faction control changes over time
✅ Character Sheets to Character Cards - CONTEXT-DEPENDENT
Why: Both have uses

Full Sheets: For crew builder, progression, detailed management
Cards: For at-table play reference, quick overview
Implement both views, switchable
Cards in 2-3 column grid (mobile: 1-2 columns)
Add: "Compact Mode" toggle for play vs management
Additional QOL Features You Missed
1. Quick Battle Setup Wizard
Generate enemies from tables automatically
Set deployment conditions
Calculate mission parameters
One-click "Start Battle" that sets everything up
2. Turn Phase Checklist
Each phase shows checklist of required/optional actions
Can't advance until required items checked
Prevents forgetting upkeep, patron checks, etc.
3. "What Do I Do Next?" Helper
Context-sensitive suggestions based on game state
New players: guided workflow
Veterans: can disable
4. Equipment Comparison Tool
Side-by-side weapon/armor stats
Highlight better/worse stats
Calculate cost/benefit for purchases
"Recommended for [character type]" suggestions
5. Mission Success Probability Calculator
Based on crew stats vs mission difficulty
"Risk Assessment" before accepting jobs
Historical success rate tracking
6. Crew Retirement/Legacy System
Archive completed campaigns
View retired crew stats/stories
Import veterans as NPCs in new campaigns
Hall of Fame
7. Undo/Redo for Sensitive Actions
Accidental crew deletion, wrong purchases
Limited undo stack (last 5-10 actions)
Clear visual indicator of undo availability
8. Dice History and Statistics
Track roll results over campaign
Luck analysis (are you actually unlucky?)
Hot/cold streak detection
Can prove to friends the dice hate you
9. Campaign Difficulty Adjustment
Mid-campaign rebalancing
"Mercy Mode" if losing badly
"Hard Mode" if winning too easily
Track difficulty changes in history
10. Voice Notes
Quick voice-to-text for battle reports
Easier than typing on mobile during games
Auto-transcribe to campaign journal
11. Auto-Save Every Phase
Never lose progress
Rewind to any previous phase if mistake made
"Checkpoint" system
12. Share Battle Reports
Generate formatted battle report with stats
Export as image for social media
Include crew portrait, enemy faced, outcome
"Brag about victory" feature
13. Tutorial Tooltips (You have framework)
Context-sensitive help on first use
"?" icons next to complex features
Can replay tutorials
Progressive onboarding
14. Colorblind Modes
Multiple palette options
Shape+color for status indicators
High contrast mode (you have this)
15. Bulk Actions
Sell multiple items at once
Apply healing to whole crew
Mass equipment changes
Implementation Priority
Phase 1 - Core UX (Do First):

Complete keyword tap-to-reveal system
Finish logbook/journal implementation
NPC/Patron/Location persistence
Import UI completion
Character card view
Phase 2 - Quality of Life (Do Second):

Equipment comparison tool
Campaign timeline visualization
Turn phase checklists
Undo system for sensitive actions
Battle setup wizard
Phase 3 - Polish (Do Third):

Voice notes
Share/export battle reports
Dice statistics
Legacy/retirement system
Difficulty adjustment
Design Philosophy Summary
Your app should:

Eliminate tedium (table rolling, calculations) ✅ You're doing this
Enhance storytelling (history, journals, NPCs) - IMPROVE THIS
Quick reference at table (keywords, play mode) - ADD THIS
Respect physical play (don't automate tactics) ✅ You do this
Enable sharing (export, reports) ✅ Good foundation
Support offline ✅ Already works
Mobile-first, desktop-enhanced ✅ Your responsive system does this
You're 70% there. Focus on keywords, NPC persistence, and completing the journal system.