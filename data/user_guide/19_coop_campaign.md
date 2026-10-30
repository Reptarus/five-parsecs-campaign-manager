# Chapter 19: Co-op Campaign

> **Quick Start** (for tabletop veterans)
> - The Bug Hunt Co-op Campaign (Compendium pp.209-211) is a Bug Hunt campaign shared by several players. Main Menu > **Co-op Campaign** > **Bug Hunt Co-op Campaign**.
> - Each player brings their own squad. The app keeps the shared sector map, each sector's Priority and Factor, the common Support pool, and the Enemy Moves rolled at the end of every operational turn.
> - Each operational turn, every player attacks one sector. A mission with 2 or more Objectives clears the sector and adds Support points to the common pool.
> - The campaign is won when every sector is cleared.
> - Player vs Player (pp.35-38) and Expanded Co-op Battles (pp.39-41) are reference text only.

## Overview

The Co-op Campaign is an extra way to play Bug Hunt (see {{chapter:12}}). Several players retake a world one sector at a time on one shared map. Each player runs their own squad at the table. The Compendium's rules for it are on pp.209-211, under "Co-op campaigns" in the Appendices.

This is a companion app, so the players supply the squads, the miniatures and the dice for the fighting. The device tracks what the campaign shares:

- the sector map: each sector's Priority, its special Factor, any resource stash and whether it is cleared,
- the common pool of Support points,
- who has attacked this operational turn,
- the Enemy Moves rolled at the end of each operational turn.

Which menu buttons are live depends on the build you have. See {{chapter:01}}. In an alpha build the **Co-op Campaign** button is dimmed and answers with a note that the mode is coming in a later release.

## Starting a Co-op Campaign

Open the Main Menu and tap **Co-op Campaign**. A dialog titled **Co-op** offers two choices:

- **Bug Hunt Co-op Campaign.** Several players retake a world sector by sector on one shared map (Compendium pp.209-211). This opens the Bug Hunt creation wizard with co-op already switched on.
- **Expanded Co-op rules (Compendium pp.39-41).** Two players share one battle. This is reference text only. See "The Other Co-op Rules" below.

**Cancel** closes the dialog.

## Creating the Campaign

The Bug Hunt wizard is titled **BUG HUNT — NEW CAMPAIGN** and has four steps: Campaign Config, Squad Setup, Equipment and Review & Launch. The co-op setup is on step 1. The other steps work as in {{chapter:12}}.

### Step 1: the Co-op Campaign card

The card is titled **Co-op Campaign**. It holds a switch, "Play as a co-op campaign: several players fight over one shared sector map (Compendium pp.209-211)". It is already on if you came in through the menu choice above. Turning it on shows:

- **Players.** One name box per player, with **Add Player** and a **Remove** button on each row. It starts with two rows. Every row needs a name, and two players cannot share a name. If a row is blank or duplicated, a red message says so and Next stays held on this step. At least one player is needed.
- **Sectors per player.** A dropdown: **3 (shorter campaign)**, **4**, or **5 (longer campaign)**. The book's guideline (p.210) is "try 3 sectors per player for a shorter campaign, up to 5 for a longer campaign". A line below the dropdown totals it, for example "3 players x 3 sectors = 9 sectors on the map".
- **Enemies and Difficulty notes.** The card quotes the two choices Preparatory Steps (p.209) asks the players to make together. Enemies: decide whether to play against a single enemy type or roll each time as you normally would. Difficulty: all players should use the same difficulty setting. The app does not pick an enemy type for you. It carries one difficulty for the whole campaign, the **Mission Difficulty** set on the same step.

Turning co-op on switches **Use Campaign Escalation (fixed Priority sequence)** off and disables it. The note beside it reads "Not used in a co-op campaign: each mission's Priority comes from the sector map (Compendium p.211)."

### Step 4: Review & Launch

When co-op is on, the review shows a card titled **Co-op Campaign (Compendium pp.209-211)** with **Players** and **Sector Map** rows, for example "9 sectors (3 per player)". It tells you "Launching rolls the map: each sector's Priority, its Factor and any resource stash (Compendium p.210)." Nothing is rolled until you press **Launch Campaign**.

### What Launch rolls

Launching builds the map and rolls its dice through the app's dice manager. For each sector the app does the three steps of The Map (p.210):

1. **Priority.** Roll 2D6 and keep the lower die. That is the sector's Priority Rating (1 to 6).
2. **Factor.** Roll D100 on the Sector Factor table below. The book says you must place one of each Factor before you can duplicate any, so while a Factor has not yet been placed, a roll that lands on an already-placed Factor is rolled again.
3. **Resource stash.** If the D100 that was kept ends in a 5 or a 0 (25, 40, 85 and so on), the sector also holds a resource stash of 1D6 Support points.

The map is a near-square grid of sectors named Sector 1, Sector 2 and so on. The book leaves the map's shape to the players (p.210: a grid map "will have a nice military look"), so the layout is the app's own choice. Each sector card lists the sectors it borders, and the Infiltration point and Sheltered Factors use that adjacency.

## The Sector Factors (p.210)

Each sector rolls one Factor on D100 (Compendium p.210):

| D100 | Factor | Effect |
|------|--------|--------|
| 1-15 | Ambush zone | No visibility is possible beyond 8". |
| 16-30 | Infiltration point | At the end of each operational turn, select a random adjacent sector and increase its Priority level by +1 (to a maximum of 6). |
| 31-50 | Sheltered | The sector cannot be attacked until at least one adjacent sector has been cleared. |
| 51-65 | Swarming | When revealing any Contact marker, the number of enemies is increased by +1. |
| 66-80 | Obstructed | Evac ships cannot provide covering fire. |
| 81-90 | Inaccessible | Only a single support roll can be made. |
| 91-100 | Hot zone | The evac ship cannot loiter. It will evac any troops in range upon arrival, and then leave immediately. The ship must be called again, if needed. |

The app shows each Factor's effect in these words on the sector cards, the mission briefing and the battle card, so you can apply it at the table.

## The Operational Turn

An operational turn (p.210) is: each player carries out a mission, followed by a roll for Enemy Moves. The normal Operational Progress table is not used. The turn number is shown as **Operational Turn N**.

### The Co-op Campaign Map

On the Bug Hunt Dashboard, a card titled **Co-op Campaign Map** appears only for a campaign created as co-op. Its line reads like "Operational turn 1 - 0 of 9 sectors cleared - 0 Support points in the common pool". Tap it to open the map page, titled **Co-op Campaign Map**. **Close** at the top returns to the dashboard.

The page shows:

- A status card, **Operational Turn N**: sectors cleared out of the total, the common Support pool, any Sabotage penalty, the players, who has already fought this turn, the difficulty, and the Enemies note.
- One card per sector, named after the sector. Each shows "Enemy-held, Priority N" or "Cleared", the sector's Factors and conditions in their data words, any "Resource stash", and "Adjacent" sectors. Tap a card to highlight it.
- A card, **End of the Operational Turn**, with the end-of-turn button once every player has fought.
- A card, **Record a Mission Played Elsewhere**, described below.

### Choosing a sector (Mission stage)

Co-op missions are set up on the Bug Hunt Mission panel, in the Mission stage of the Bug Hunt turn. A card titled **Co-op Campaign: Operational Turn N** shows the **Common Pool**, and the Sabotage penalty when there is one.

1. Pick the player in the **Player** dropdown. It lists the players who have not yet attacked this turn. Each player attacks one sector of their choice (p.211).
2. Tap a sector card. Cards you cannot attack are dimmed and say why. A cleared sector cannot be attacked. A Sheltered sector cannot be attacked until an adjacent sector has been cleared. A player who has already attacked this turn cannot attack again.
3. **Generate Mission** stays disabled until a sector is chosen. The mission uses the Priority from the sector map (p.211: "Set up the mission as normal, using the Priority level from the sector map"). The briefing gets a **Co-op Sector** row and the sector's Factors and conditions.
4. Optionally draw from the common pool: under Support, **Draw 1 from the common pool** adds a point to this mission's Support and **Put 1 back** returns it. The points are taken from the pool once, when you press **Launch Mission**. The book (p.211) says players must agree between themselves how the points are shared.
5. Press **Launch Mission**.

Two Factors change how Support works. Inaccessible limits the mission to a single Support roll, and the Support request list says so when the limit is reached. Enemy sabotage (below) reduces Support by 1 for every battle in the turn.

The battle card on the battle screen lists the sector, the Factors and conditions in force, any Sabotage penalty and the common-pool draw, in the same words, so you can apply them at the table.

### Fighting the mission

You fight the battle at your table, using the battle screen the same way a Bug Hunt mission does. See {{chapter:12}} and {{chapter:06}}.

### Post-Battle

In the Bug Hunt Post-Battle stage a card titled **Co-op Campaign: <sector name>** says who attacked which sector. It reminds you of the success rule: 2 or more Objectives, counted the way the debrief counts them (normal 1, Vital 2, Critical 3), Compendium p.211. Press **Complete Post-Battle**. The result is recorded once on the map and shown in a **Sector Map** receipt:

- **A victory** (2 or more Objectives): the sector is cleared and 1 Support point is added to the common pool, plus the sector's resource stash if it had one (p.211). The sector's Factors stay with it, in case the enemy takes it back.
- **A failure**: the sector stays under enemy control.

A co-op campaign does not use the Operational Progress table (p.210), so Post-Battle skips that roll.

### Ending the operational turn

When every player has attacked, or has no sector left they are allowed to attack, the button **End Operational Turn: roll Enemy Moves (Compendium p.211)** appears on the Mission panel, the Post-Battle panel and the map page (as **End Operational Turn: roll Enemy Moves**). Until then the page tells you who is still to fight. In order, pressing it:

1. clears last turn's Sabotage penalty,
2. lets each Infiltration point raise the Priority of one adjacent sector by 1, to a maximum of 6 (p.210),
3. rolls once on the Enemy Moves table for **each player** and applies the result to the map (p.211),
4. starts the next operational turn.

A receipt lists every die and what it did. If a result needs a sector (for example "one enemy sector"), the app picks one with a die roll, as p.211 allows. A result with no eligible sector has no effect, and the receipt says so.

## The Enemy Moves Table (p.211)

At the end of each operational turn, each player rolls D100 and the results are applied to the map (Compendium p.211):

| D100 | Result | Effect |
|------|--------|--------|
| 1-10 | Enemy assault | A cleared sector falls to the enemy. Priority level 3. |
| 11-21 | Enemy digs in | One enemy sector becomes an Ambush zone. |
| 22-30 | Enemy establishes control | One enemy sector becomes Obstructed. |
| 31-39 | Enemy gathers forces | One enemy sector becomes an Infiltration point. |
| 40-47 | Enemy sabotage! | During the next operational turn, all battles are fought with -1 Support point. |
| 48-56 | Enemy patrols | One enemy sector is heavily patrolled: when rolling for Contact marker actions, add +1 to the Aggression die. |
| 57-65 | Enemy swarms | One enemy sector is swarmed. Place 1 additional Contact marker at the beginning of the battle. |
| 66-73 | Enemy elites | One enemy sector is held by elite forces. If Combat Skill is +0, raise it to +1. If Toughness is 3, raise it to 4. Raise Speed by +1". |
| 74-85 | Wastage | Reduce Support reserves by -1D3 points. |
| 86-100 | Suspicious activity | One enemy sector increases Priority by +1. |

Priority never goes outside 1 to 6 (p.187). The common pool cannot go below 0. The book does not say whether a sector rolled for the same Factor twice gains it twice. The app treats a Factor as something a sector has or does not, so a repeat adds nothing, while two Sabotage results are two results.

## Recording a Mission Played Elsewhere

p.211 notes that in an online campaign one player will manage and update the map as results are sent in. The map page supports that. The **Record a Mission Played Elsewhere** card is for a player whose squad fought on another device or at another table. Fill in:

- **Player**: who fought.
- **Sector attacked**: the sector they attacked.
- **Objectives completed (weighted, as their debrief scored it)**: their Objective total.
- **Support points they drew from the common pool (N available)**: points they took from the pool for that mission.

Press **Record Mission on the Map**. It applies the same victory or failure result as a Post-Battle on this device. A player whose mission is in progress on this device is left out, because their result is recorded at their own debrief.

## Winning

The campaign is won when every sector is cleared (p.210). The status card changes to **Campaign Won** and the Enemy Moves roll is no longer offered.

The book (p.210) also says operational turns continue until all Lairs have been destroyed. The Compendium never describes a Lair anywhere else, so the app does not track one, and the win check is "every sector cleared".

## The Other Co-op Rules

**Expanded Co-op Battles** (Compendium pp.39-41) are rules for two players sharing one battle. **Player vs Player** (pp.35-38) is a head-to-head battle variant. The app does not run either as a game mode. Both are shown as reference text on the battle screen's Cheat Sheet, and the Expanded Co-op rules are also reachable from the Co-op dialog through **Expanded Co-op rules (Compendium pp.39-41)**. That page has a **Close** button. If the Compendium content is not enabled on your device, it says "The Expanded Co-op Battles rules (Compendium pp.39-41) are Compendium content and are not enabled on this device." Use the book to play them.

## Saving

The co-op map is saved with the Bug Hunt campaign. The app saves after it records a mission result and after it ends an operational turn. Load it as you would any Bug Hunt campaign. See {{chapter:14}}.

## Tips

- **Agree the pool rules first.** The book leaves how Support points are shared to the players.
- **Check Sheltered sectors.** They cannot be attacked until a neighbour is cleared, so clear the edges first.
- **Watch Infiltration points.** They raise a neighbour's Priority every turn, so clear them early.
- **Match difficulty.** Everyone should use the same difficulty setting (p.209).

## What's Next?

- For the Bug Hunt rules this builds on: {{chapter:12}} - Bug Hunt Mode
- For the battle screen: {{chapter:06}} - The Battle Companion
- For saving campaigns: {{chapter:14}} - Saving and Loading
