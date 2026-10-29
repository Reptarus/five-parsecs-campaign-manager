# Chapter 14: Saving and Loading

> **Quick Start** (for tabletop veterans)
> - The app saves for you as you play, and every campaign screen with a **Save** button saves on demand
> - A save keeps one previous version beside it, so a failed write cannot destroy your last good save
> - **Export** copies a campaign to a `.save` file you choose; **Import from File...** brings one back
> - Standard, Bug Hunt, Tactics and Planetfall campaigns each have their own save files, and the app detects the type on load

## Overview

The app saves your campaign as a JSON file in its own storage. You can rely on the app's saves for routine play, save by hand before a risky decision, and export a campaign to a file for backup or to move it to another device.

## Automatic Saves

The app saves without being asked at several points:

- **Standard campaign:** after each phase of the campaign turn is completed, at points during the World Phase, and when you finish the End Phase.
- **Battles:** the battle screen keeps a checkpoint so an interrupted battle can be resumed, and saves when you leave the battle.
- **Planetfall:** when a turn ends and before a battle starts.
- **Tactics:** when a turn ends and when the campaign ends.

An automatic save is quiet. There is no pop-up.

## Saving by Hand

- **Standard campaign:** press **Save** in the button row of the Campaign Dashboard. A message confirms it, or tells you why it failed.
- **Planetfall:** use the **Save Campaign** card on the dashboard or the **Save** button on the turn screen.
- **Tactics:** use the **Save Campaign** card on the dashboard.
- **Bug Hunt:** use the **Save Campaign** card on the dashboard.

Save before risky battles, before spending a lot of credits or dismissing crew, and at the end of a play session.

## Safe Writes and the Previous Version

A save is written to a temporary file and then swapped in, so a crash or a closed app part-way through a save leaves the old save intact. Where a save already existed, the app also keeps the previous version beside it as a `.bak` file. If a save will not open, the app tries that previous version.

## Loading Campaigns

### From the Main Menu

1. Tap **Continue Campaign** to resume the campaign already loaded, or **Load Campaign** to choose one.
2. Each entry shows the campaign name and when it was last played. Bug Hunt, Tactics and Planetfall saves carry **[BH]**, **[TAC]** and **[PF]** tags, and a **[DLC]** tag marks a save that needs expansion content you do not own.
3. Tap an entry to load it. The cross button beside an entry deletes that save.

You can also load Bug Hunt, Tactics and Planetfall campaigns from their own Main Menu buttons. See {{chapter:12}}, {{chapter:16}} and {{chapter:17}}.

### From the Dashboard

The **Load** button on the Campaign Dashboard lists your saves the same way and has **Import from File...**.

### Campaign Type Detection

The app reads the save file to find out whether it is a standard, Bug Hunt, Tactics or Planetfall campaign and opens the right screen. You do not choose.

## Export and Import

### Exporting

On the Campaign Dashboard, press **Export** and choose where to write the `.save` file. The file holds your crew, equipment, progress and history. Use it as a backup kept outside the app, or to move the campaign to another device.

### Importing

1. Open **Load Campaign** on the Main Menu, or **Load** on the Campaign Dashboard.
2. Press **Import from File...**.
3. Choose a `.save` or `.json` file. The app checks it and loads the campaign.

### On Android

The app's saves are in its private storage, which other apps and file managers cannot browse. **Export** is how you get a copy out, and **Import from File...** is how you bring one in.

## Campaign Journal

The Campaign Journal is an automatic log kept with a standard campaign. It records turn events, battle summaries, crew changes and story events. Open it from the Campaign Dashboard.

## Troubleshooting

### A save will not load

- The file may be damaged. The app tries the previous version automatically.
- If the save needs expansion content you do not own, the load shows a dialog naming the pack, with a way to open the Store.

### Import fails

- Check that the file is a `.save` or `.json` file exported from this app.
- A file that is empty or cut short cannot be loaded.

## What's Next?

- For campaign creation: {{chapter:02}} — Creating a Campaign
- For victory and campaign completion: {{chapter:11}} — Victory Conditions
