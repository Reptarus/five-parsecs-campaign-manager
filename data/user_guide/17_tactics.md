# Chapter 17: Tactics

> **Quick Start** (for tabletop veterans)
> - Tactics is a separate points-based army campaign with its own save files. It is not part of a standard Five Parsecs campaign.
> - Main Menu > **Tactics**. With no Tactics save it opens the 4-step army wizard; with saves it offers Continue, Load or New.
> - Wizard: Configuration, Species, Army Roster, Review. The app checks your army against the army-building rules as you build.
> - The turn has 8 phases. You play the battle on your table and **record** the result in the app. Tactics does not open the app's battle screen.
> - Named veterans can be commissioned in from other modes and retired out to them.

## Overview

Tactics is the army-scale campaign from the Five Parsecs: Tactics book. You build a force from a species army list, fight battles on your table, spend Campaign Points on improvements and run an operational map where your faction and the enemy contest regions.

The app is the campaign keeper. It builds and validates your army, tracks your units between battles, rolls the post-battle tables and walks you through the operational turn. It does not run the tabletop battle. During the Battle phase you fight on your table and enter the result.

Where this chapter gives a page number, it points at the Tactics rulebook. Use the book for the rules themselves.

## Starting Tactics

Open the Main Menu and tap **Tactics**.

- With no Tactics save, the creation wizard opens.
- With one or more saves, a **Tactics** dialog opens first. It offers to continue the most recent campaign, load a listed one, or start **New Tactics Campaign**.

In an alpha build the Tactics button can answer with a "not in this build" note instead of opening the mode. See {{chapter:01}}.

## Creating an Army

The wizard is titled **FIVE PARSECS: TACTICS** and shows "Step N of 4" with the step name. **Back** and **Next** move between steps; **Next** stays disabled until the step is complete. **Cancel** returns to the Main Menu. The last step has **Launch Campaign**.

### Step 1: Configuration

- **Campaign Name** (required) and an optional **Army Name**.
- **Points Limit.** Choose one of the listed tiers.
- **Organization.** A Platoon, or a Company of two to four platoons. For a company you pick how many platoons.
- **Armored platoons** (optional rule, Tactics p.135). A tick box appears for each platoon.
- **Play Mode.** Solo (vs AI), GM-Directed Scenarios, or Head-to-Head Pick-up Game.

The step is complete once the campaign has a name and a points limit.

### Step 2: Species

Browse the species cards. Each shows its traits and rules. Press **Select** on the one you want. Changing species clears any roster you built.

### Step 3: Army Roster

This is the army builder. The header shows your points against the limit and the unit count, for example "0 / 500 pts · 0 units". The screen also lists the composition limits that apply to your organization, so you can see what you may take before you break one.

- **Available Units** lists the units from your species book plus the vehicles every army can take. Press **+ Add** to add one.
- **Your Roster** lists what you have added, each with its points. **X** removes a unit.
- For each unit you can set where it serves: a platoon or, for a company, the company itself.
- A unit's listed options appear as a dropdown (pick one) or tick boxes (pick several).
- A squad can be given a transport vehicle where the rules allow it.

Every price comes from the same calculation the validator uses. The step is complete when the roster is not empty and the army passes validation. Problems are listed so you can fix them. See the Army Builder, Tactics pp.133-140, and Vehicles from p.141.

### Step 4: Review

The review shows a summary of the configuration, species and roster, and a **Validation** line: PASSED, or a count of issues with each issue listed. **Launch Campaign** is enabled once the first three steps are complete. The app builds the campaign, saves it and opens the Tactics dashboard.

## The Dashboard

From the top:

- The campaign name and, below it, the army and species.
- **Stat tiles:** Turn, Op Turn, CP (Campaign Points), Units and Wins. A dash means none yet.
- **Continue Campaign.** The subtitle reads "Start turn N" or "Resume turn N: phase name". When the war has ended it is replaced by a banner saying you won, lost, or that it was inconclusive (Tactics p.99).
- **Save Campaign** and **Main Menu.**
- **Commission Veteran** and **Retire Veteran Out** (see "Moving Characters Between Modes").
- **Operational Map summary:** Cohesion for each side, Player Battle Points, the number of Zones, regions held by each side, each Zone's Army Strength, and any banked battle advantages.
- **Army Roster:** one card per unit.
- **Battle History:** one line per recorded battle with the turn and the CP earned.

## The 8-Phase Turn

Press **Continue Campaign** to open the turn screen. The header shows the turn number and the phase name, and a row of dots shows progress: an empty dot for a phase to come, a ringed dot for the current phase and a filled dot for a finished one. **Dashboard** returns to the dashboard.

For the first four phases and for Post-Battle and Advancement, a **Complete Phase** button at the foot of the panel moves you on. The Battle phase completes when you record the result. When the turn ends the screen says "Turn N is complete and saved." and offers **Start Turn N+1** or **Return to Dashboard**.

### 1. Commit Your Force

Pick the Operational Zone your force fights in this turn (Tactics p.96). It starts where Step 8 of the last turn committed it. If no Zone is open yet, the phase simply completes.

### 2. Reconnaissance

This phase shows you the Observation rule (Tactics p.39) so you have it in front of you. The test is rolled at the table during the battle, so the app asks for nothing here.

### 3. Battle Preparation

Pick the scenario you will play (Tactics pp.74-81). The scenario is kept if you leave the phase and come back. If you have banked battle advantages, tick any you are spending in this battle. They are used up when the phase completes (Tactics pp.107-108).

### 4. Deployment

The phase shows "Deploying N unit(s)." and a condition note for any unit that is Weakened, Devastated or Lost. A Lost unit never deploys, a Devastated one cannot deploy for a number of battles, and a Weakened one deploys one figure short (Tactics p.106). Place your forces on the table by the scenario's deployment rules. The units listed here are recorded as having fought this battle.

### 5. Battle

The screen reads **BATTLE IN PROGRESS**. Fight the battle on your table, then record it:

1. Enter the **Victory Points you scored**. If the scenario did not use Victory Points, tick **This scenario did not use Victory Points** instead.
2. Tick **Play another battle this turn** if you will fight more than one. The book sets no limit on battles per operational turn (Tactics p.95).
3. Press **Victory**, **Draw** or **Defeat**.

Pressing the outcome button completes the phase. The app awards Campaign Points from the result and Player Battle Points where the book gives them (Tactics pp.96, 106-107). A draw earns no Player Battle Points. If you ticked **Play another battle this turn**, the turn loops back to Battle Preparation instead of moving on.

### 6. Post-Battle

The panel shows the battle result and your available CP. Then:

- **Unit losses.** Tick each unit that was completely destroyed and press **Roll Unit Losses for ticked units**. A unit still on the table at the end is assumed to recover completely (Tactics pp.105-106).
- **Story event.** Press **Roll Story Event (D100)** to roll on the story table (Tactics pp.102-104). The result and its effect are shown.

### 7. Advancement

Spend Campaign Points on the purchases the card lists, each with its CP cost (Tactics pp.107-108). The costs shown come from the same table the app charges from. A purchase button is disabled when you cannot afford it or when no unit can receive it. Choosing a purchase that needs a target asks you to pick the unit or option, then **Confirm** or **Cancel**. Everything you commit is listed under "Committed this phase" and applied when you complete the phase.

### 8. Strategic Phase

This phase walks the operational turn in the order the book prints it (Tactics pp.96-99). A status block shows both sides' Cohesion, your Player Battle Points and the regions each side holds. Each step shows its dice as a card. Use the buttons in order:

- **Step 3, Operational Combat.** Mark whether your territory touches each Zone, optionally launch an assault or commit Player Battle Points, then press **Resolve Step 3 — Operational Combat in every Zone**.
- **Step 4, Operational Orders.** Press **Roll Step 4 — Operational Orders (1D6 each side)**, choose your order's Zone where the book lets you, then **Carry Out Orders**.
- **Step 5, Commando Raids.** Commit unspent Player Battle Points with the **Raid with N PBP** buttons, or continue.
- **Step 6, Redeploy Forces.** Move Army Strength between your armies where allowed.
- **Step 7, New Zones and Focus.** Press **Resolve Step 7 — Open new Zones and select the Focus**.
- **Step 8, Player Commitments.** Assign your army to a Zone for next turn.

**Complete Strategic Phase** is enabled only at the last step. The app then applies Cohesion changes (Step 9) and ends the turn. If either side's Cohesion reaches 0, the campaign ends and the turn screen shows the result with "(Tactics p.99, Step 9)".

Mirror each result on your own campaign map if you keep one. The app does not read your paper map.

## The Battle on Your Table

The Tactics turn has no hand-off to the app's battle screen. You fight the battle with your own miniatures and rules, and the app holds the campaign around it. If you want the app's battle companion for a standard Five Parsecs battle, see {{chapter:06}}. That screen is not used by Tactics.

## Saving and Loading

- **Save Campaign** on the dashboard writes the campaign to disk.
- The app saves when a turn ends and when the campaign ends.
- To load, use Main Menu > **Tactics**, or **Load Campaign**. Tactics saves are tagged **[TAC]** in that list. See {{chapter:14}}.
- If you leave mid-turn, **Continue Campaign** resumes at the phase the campaign recorded.

## Moving Characters Between Modes

Tactics treats an imported character as a **named veteran**: an officer or hero figure attached to your army. It is not a squad unit, so it does not count toward your points limit (Tactics pp.182-183).

- **Commission Veteran.** Lists veterans from your Five Parsecs, Bug Hunt and Planetfall saves. Press **Select** on one, review the **COMMISSION PREVIEW**, then press **Commission**. **Go Back** returns to the list. The veteran is removed from the save they came from once they arrive.
- **Retire Veteran Out.** Lists your named veterans with **→ 5PFH**, **→ Bug Hunt** and **→ Planetfall** buttons. The veteran leaves your army and a transfer file waits for that mode, which picks it up the next time you open that mode's dashboard. If the file cannot be written, the veteran stays with you and the app tells you.

See {{chapter:12}} for Bug Hunt and {{chapter:16}} for Planetfall.

## What's Next?

- For saves and file transfers: {{chapter:14}} — Saving and Loading
- For the other expansion modes: {{chapter:12}} — Bug Hunt, {{chapter:16}} — Planetfall
- For the standalone battle practice mode: {{chapter:18}} — Battle Simulator
