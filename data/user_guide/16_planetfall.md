# Chapter 16: Planetfall

> **Quick Start** (for tabletop veterans)
> - Planetfall is a separate colony campaign with its own save files. It is not part of a standard Five Parsecs campaign.
> - Main Menu > **Planetfall**. With no Planetfall save it opens the 6-step creation wizard; with saves it offers Continue, Load or New.
> - Wizard: Expedition Type, Character Roster, Backgrounds, Map Generation, Tutorial Missions, Review & Launch.
> - The turn has 18 steps, shown as numbered dots along the top. The battle is Step 8 and is played on the battle screen.
> - You can bring characters in from Five Parsecs and Bug Hunt saves, and muster colonists out to those two modes.

## Overview

Planetfall is the colony-building campaign from the Planetfall book. You lead a roster of colonists on a new world: you explore a map, fight missions, research theories, construct buildings and try to keep the colony standing. The app keeps the colony sheet, rolls the tables and shows each step of the turn. You still play the battles on your table.

Planetfall has its own campaign file, its own dashboard and its own turn screen. Nothing in it touches your standard campaigns.

Where this chapter gives a page number, it points at the Planetfall rulebook. Use the book for the rules themselves. This chapter describes what the app shows and asks you to do.

## Starting Planetfall

Open the Main Menu and tap **Planetfall**.

- If you have no Planetfall save, the creation wizard opens.
- If you have one or more Planetfall saves, a **Planetfall** dialog opens first. It offers to continue the most recent colony, load a listed one, or start **New Planetfall Campaign**.

Which menu buttons are live depends on the build you have. In an alpha build the Planetfall button can answer with a "not in this build" note instead of opening the mode. The same applies to Bug Hunt and Tactics. See {{chapter:01}}.

## Creating a Colony

The wizard shows the title **PLANETFALL — NEW COLONY** and a line such as "Step 1 of 6: Expedition Type". **Back** and **Next** move between steps. **Next** stays disabled until the current step is complete. **< Cancel** returns to the Main Menu without creating anything.

### Step 1: Expedition Type

- Type a **Campaign Name**. Optionally type a **Colony Name**; if you leave it blank, the colony takes the campaign name. If you leave the campaign name blank it becomes "New Colony".
- Press **Roll D100: Expedition Type**. The app rolls once and shows the result, its description and its effect. The button then reads "Expedition rolled" and is disabled, so the result cannot be re-rolled.
- The expedition's starting bonus is applied when the colony is founded.

See Planetfall p.52 for the Expedition Type table.

### Step 2: Character Roster

The step is complete when the roster follows the rules the app lists on screen, which come from Planetfall pp.14-20. Any problem is listed in amber under the buttons, and **Next** enables when none remain.

- Each colonist has a name field, a class picker and, where the rules allow it, a Human sub-species picker. **Remove** clears a slot.
- **Reset to the recommended mix** fills the roster with the book's recommended class mix.
- **Import a character** opens a picker listing characters in your Five Parsecs, Bug Hunt and Planetfall saves. See "Moving Characters Between Modes" below.
- If a pre-made crew is available, a **Use ...** button loads its names and portraits. You still choose each class and sub-species.
- Grunts and the colony bot are not on this roster. The app adds them when the colony is founded.

### Step 3: Backgrounds

You choose which characters are the experienced ones (the screen shows "Experienced: N of M chosen"), then press **Roll backgrounds**. Everyone rolls a Motivation. Experienced characters also roll Prior Experience and a Notable Event. Planetfall pp.21-22 has the tables.

For experienced characters, two extra buttons let you roll an earlier career or another Notable Event for story only. Both are labelled "(story only)".

### Step 4: Map Generation

Choose a map size from the three buttons, then tap the sector your colony stands in on the grid, or press **Roll the home sector randomly**. The Investigation Sites are placed at random when the colony is founded. See Planetfall pp.52-53.

### Step 5: Tutorial Missions

This step is optional. Each tutorial mission has a card with **Mission Success** and **Mission Failed** buttons for you to record how your tabletop game went. A success earns a starting bonus, which the Review step lists. **Skip All Tutorials** passes the step with no bonuses.

### Step 6: Review & Launch

The review lists the campaign and colony names, the expedition, the roster with each character's profile and background, the map size and the tutorial results. When it is correct, press **Establish Colony**. The app builds the colony, saves it and opens the Planetfall dashboard.

Establishing the colony needs a rolled expedition, a valid roster and rolled backgrounds. If one is missing the button stays disabled.

## The Dashboard

The dashboard is your hub between turns. From the top:

- **Header** with the campaign name, and the colony name and turn below it.
- **Stat tiles** for the colony's tracked values and the roster count.
- **Continue Campaign** card. Its subtitle says where you will land: "Start campaign turn N", or "Resume turn N at Step X: name" if you left mid-turn. After a failed or completed campaign, or when the End Game is open, the card changes to match.
- **Colony Map** with the sector grid, followed by one line per Tactical Enemy (sectors held, Enemy Information, any located Strongpoint or Boss).
- **Colony Management** cards:
  - **Colony Status**: research and buildings progress, milestones and colony statistics.
  - **Armory**: the weapons the colony can field and what unlocks the rest, plus any Alien Artifacts.
  - **Enemy Tracker**: Tactical Enemies and Ancient Signs.
  - **Augmentations**: spend Augmentation Points.
  - **Milestones & Progression**: milestone count out of 7, calamity and mission data tracking.
  - **Active Calamities**: appears only while a calamity is active.
  - **Import Veterans**, **Muster Colonists Out**, **Save Campaign** and **Main Menu**.
- **Colony Roster** at the bottom, one card per colonist with class, loyalty, and tags such as Imported or Sick Bay turns remaining.

## The 18-Step Turn

Press **Continue Campaign** on the dashboard to open the turn screen. The header shows the turn number, a phase line such as "PRE-BATTLE · STEP 1 OF 18", a strip of colony resources, and **Save** and **Dashboard** buttons. A row of numbered dots runs along the screen, grouped as PRE-BATTLE, BATTLE and POST-BATTLE.

One button at the foot of the screen completes each step. It is disabled until the step is ready, and a line above it says what is missing. Where a step finishes with its own button (such as a roll), press that first. Between turns the footer button reads **Start Next Turn**.

The app saves when a turn ends and before it launches a battle. You can also press **Save** at any time.

### Pre-Battle (Steps 1-6)

1. **Recovery.** Press **Process Recovery**. Characters in Sick Bay heal by one turn. Where a reward lets you bank turns, the step shows a spinner for it.
2. **Repairs.** The step shows your base repair rate and, if you have Raw Materials, a spinner to spend some on extra repairs. Press **Apply Repairs**. With nothing to repair, it is ready as soon as it opens.
3. **Scout Reports.** Three parts, in the order the book gives them. First, tap a sector on the map and press the explore button to explore it. Second, optionally roll a Scout Discovery (D100) and, if you wish, name a scout to lead it; some results ask you to make a choice. Third, press the button to process Enemy Information. The footer enables once the parts you owe are done. See Planetfall pp.59-61.
4. **Enemy Activity.** If Tactical Enemies are present, press **Roll Enemy Activity**. One enemy is chosen at random and rolls on the activity table. A checkbox lets you spend a Story Point to wait for a better moment, where the rules allow it.
5. **Colony Events.** Press **Roll Colony Event (D100)**. Some events ask you to choose a character, a priority or whether to decline. The footer enables once the event is resolved. Reaching a milestone can owe you further events, and the button then offers them one at a time.
6. **Mission Determination.** Pick a mission from **Available Missions**. A mission that is not available is greyed out, with the reason beneath it. Most missions need you to tap a highlighted sector on the map. If hostile wildlife was accepted at Step 5, a warning reminds you to play a Patrol Mission this turn or lose Colony Morale. The footer reads "Confirm" followed by the mission name.

### Battle (Steps 7-8)

7. **Lock and Load.** Tick which characters deploy and choose each character's weapon from the list their class allows. Characters in Sick Bay cannot deploy. Grunts deploy in fireteams, shown as tick boxes. The screen shows how many characters and grunts you have deployed against the mission's limit and the mission's opposition. The footer needs at least one character or fireteam.
8. **Play Out Your Mission.** The app saves, opens the battle screen with your force and the mission set up, and shows the mission's briefing card. The step has no panel of its own.

### The Battle and the Return

On the battle screen you play the mission with the app's battle companion, as described in {{chapter:06}}, with Planetfall's own mission card and contact tools. Planetfall's rules replace the standard campaign's there:

- **Reaction dice.** Each character rolls one die, each fireteam you deployed rolls one die for the whole team, and each scientist on the table adds one more die. Excess dice are discarded (pp.29-30).
- **Hits.** A roll above the target's Toughness makes it a casualty, and a roll equal to it knocks the target Sprawling (p.37). A figure with Kill Points loses one instead, and is not Stunned (p.38).
- **Reference tab.** It holds Planetfall's combat rules and weapons. The standard campaign's Battle Events are not rolled.

When the fight is over, use **Record Result** to fill in the outcome. When the battle ends you are returned to the Planetfall turn screen and the turn carries on at Step 9. The turn screen is rebuilt on return, and the app has kept the mission details for the post-battle steps.

If you leave the app mid-turn, **Continue Campaign** puts you back on the step you were on.

### Post-Battle (Steps 9-18)

9. **Injuries.** The panel first asks for what only the table knows: how many grunts fell, who directly killed a Boss or Leader, who left early, the Mission Data you gained, how many Find rolls the mission earned, and mission-specific questions. Its button reads **Roll Injuries**, or **Record the Debrief** if nothing needs rolling.
10. **Experience Progression.** Press **Award XP**. Where a character earns a Breakthrough, the app asks you to assign it. Augmentation Points can be spent from here.
11. **Colony Morale Adjustments.** Press **Calculate Morale**. The step lists each adjustment before it applies it, including casualty costs, and some options that spend a Story Point.
12. **Track Enemy Info and Mission Data.** This step is folded into the post-battle panel. After Morale, the footer reads **Continue to Post-Mission Finds** (press **Roll Finds**), then **Continue to Enemy Information** (press **Process Intel**). The turn screen skips the separate Step 12 entry for you.
13. **Replacements.** Press **Roll for Replacements**. If your roster is full there is nothing to do. Otherwise you take the replacements on offer and can dismiss characters you no longer want.
14. **Research.** The step shows your Research Points and a list of Theories. Pick a theory to invest points in it or to research one of its Applications. Bio-analysis of a sampled Lifeform is offered when you have samples. A milestone can be delivered when you finish this step.
15. **Building.** The step shows your Build Points and Raw Materials. Pick a building, then invest points in it. You can convert Raw Materials to Build Points and reclaim a building. The step enforces the limits the book sets for each turn.
16. **Colony Integrity.** Press **Check Integrity**. The roll only happens when Integrity is low enough to need one. A failure is looked up on the table, and a choice such as emergency repairs is offered when it is owed.
17. **Character Event.** Press **Roll Character Event**. A random character is selected. If the result is a Change of Assignment, you answer it here: accept the transfer, or decline and gain Loyalty. A transfer can go to Five Parsecs, Bug Hunt or Tactics.
18. **Update Colony Tracking Sheet.** Press **Roll Calamities**. Only an active Calamity rolls here. The turn then completes and saves.

If Colony Morale or Integrity collapses far enough, the campaign ends in failure and the turn screen shows **CAMPAIGN OVER** (Planetfall p.90).

### Overlays on the Turn Screen

Colony Status, Armory, Enemy Tracker, Augmentations, Milestones and Calamities are dashboard overlays. Each has a **Close** button. Open them from the dashboard between turns.

## The End Game

When the 7th Milestone is reached, the turn that earned it finishes and the screen shows **END GAME**. The End Game panel walks you through the Summit, Colony Security and the final construction (Planetfall pp.160-164). If Colony Security or the final milestone needs more campaign turns, press **Play a Campaign Turn** to go back to the normal turn flow. **End With Your Own Story** lets you close the campaign by narrating your own ending.

## Saving and Loading

- The dashboard card **Save Campaign** and the turn screen's **Save** button write the campaign to disk. **Save** briefly reads "Saved!".
- The app also saves when each turn ends and before a battle starts.
- To load a colony, use Main Menu > **Planetfall**, or **Load Campaign** (Planetfall saves are tagged **[PF]** in that list). See {{chapter:14}}.

## Moving Characters Between Modes

- **Bringing characters in.** In the creation wizard, use **Import a character** on the roster step. On the dashboard, use **Import Veterans**. Both list characters from your Five Parsecs and Bug Hunt saves. Select a veteran, review the import preview, then take **Proceed to Class Training**. There you press **Attempt Class Training**, or skip it and import the character unclassed. The character then joins the roster, tagged **Imported**. The character is removed from the save they came from once they arrive.
- **Sending characters out.** On the dashboard, **Muster Colonists Out** lists colonists with **→ 5PFH** and **→ Bug Hunt** buttons. The colonist leaves your roster and a transfer file waits for the other mode, which picks it up the next time you open that mode's dashboard. If the file cannot be written, the colonist stays on your roster and the app tells you.
- A character can also be transferred by the Change of Assignment result at Step 17, to Five Parsecs, Bug Hunt or Tactics.

See {{chapter:12}} for the Bug Hunt side and {{chapter:17}} for Tactics.

## What's Next?

- For the battle screen itself: {{chapter:06}} — The Battle Companion
- For saves and file transfers: {{chapter:14}} — Saving and Loading
- For the other expansion modes: {{chapter:12}} — Bug Hunt, {{chapter:17}} — Tactics
