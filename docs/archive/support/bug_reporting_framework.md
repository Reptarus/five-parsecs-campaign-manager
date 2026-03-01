# In-Game Bug Detection & Reporting Framework

## 1. Overview

This document outlines a comprehensive framework for detecting, reporting, and managing bugs directly within the Five Parsecs Campaign Manager. The primary goal is to create a frictionless experience for players to report issues and to provide the development team with structured, actionable data to identify and resolve bugs efficiently.

The system is composed of three main components:
1.  **In-Game Reporting UI**: A user-friendly interface for players to manually submit bug reports.
2.  **Automated Crash Detection**: A system that automatically captures and reports unhandled exceptions (crashes).
3.  **Backend Management System**: A service (which can be a simple Git-based system initially) to receive, categorize, and track the status of reports.

## 2. In-Game Reporting UI

This UI should be accessible from a main menu or a pause screen.

### 2.1. UI Components

-   **Report Button**: A clearly visible button (e.g., with a "bug" icon) that opens the reporting dialog.
-   **Report Dialog**:
    -   **Title Field**: A one-line summary of the issue.
    -   **Description Field**: A multi-line text area for detailed steps to reproduce the bug.
    -   **Category Dropdown**: A dropdown to classify the bug (e.g., "UI/UX", "Combat", "Campaign", "Crash", "Typo/Text", "Other").
    -   **Attach Screenshot Checkbox**: Automatically checked. The system will take a screenshot of the game state when the report dialog is opened.
    -   **Attach Save Game Checkbox**: Allows the player to include their most recent autosave with the report.
    -   **Submit Button**: Sends the report to the backend.
    -   **Status Label**: Provides feedback to the player (e.g., "Submitting...", "Report Sent!", "Error: Could not send report.").

### 2.2. Data Collection (On Report Submission)

When a player submits a report, the system will package the following data:

-   **Player Input**: Title, Description, Category.
-   **Metadata**:
    -   `game_version`: (e.g., "v1.0.1")
    -   `platform`: (e.g., "Windows", "Android")
    -   `timestamp_utc`: ISO 8601 format.
    -   `dlc_status`: A dictionary of owned DLCs (e.g., `{"compendium": true}`).
-   **Game State Snapshot**:
    -   `current_scene`: The active scene file path.
    -   `campaign_turn`: The current campaign turn number.
    -   `player_credits`: Current credits.
    -   `active_mission`: The current mission ID, if any.
-   **Attachments**:
    -   `screenshot.png`: The captured screenshot.
    -   `savegame.sav`: A copy of the latest autosave file (if permitted by the player).
    -   `console_log.txt`: A snippet of the most recent console output/log messages.

## 3. Automated Crash Detection

This system will catch unhandled exceptions that cause the game to crash.

### 3.1. Implementation

-   **Global Exception Handler**: Use Godot's `get_tree().unhandled_exception` signal.
-   **Crash Dialog**: When an unhandled exception is caught, instead of crashing immediately, the game should:
    1.  Pause the tree (`get_tree().paused = true`).
    2.  Show a simple dialog: "Oh no! It looks like the game has crashed. Would you like to send an anonymous crash report to help us fix the issue?"
    3.  If the player agrees, the system gathers the same data as a manual report but with the exception details included.
-   **Data to Capture**:
    -   All data from a manual report.
    -   **Exception Info**: The full stack trace and error message provided by the `unhandled_exception` signal.

## 4. Backend Management System

For an indie project, a full-scale backend like Sentry or Zendesk can be overkill initially. A Git-based issue tracking system is a pragmatic and effective starting point.

### 4.1. Git-Based Workflow (Using GitHub Issues)

1.  **Endpoint**: The game will not directly post to GitHub. Instead, it will send the report to a simple, secure cloud function (e.g., Netlify Function, Google Cloud Function) that you control. This prevents abuse of your GitHub token.
2.  **Cloud Function Logic**:
    -   Receives the `POST` request from the game client with the bug report data (as a JSON payload).
    -   Authenticates the request (e.g., with a secret key).
    -   Formats the data into a clean Markdown body.
    -   Uses the GitHub API to create a new issue in a **private** repository dedicated to bug tracking.
    -   **Issue Title**: `[Category] - Player Report: {Report Title}`
    -   **Issue Body**: The formatted Markdown with all metadata and the player's description.
    -   **Labels**: Automatically adds labels based on the category, game version, and platform.
3.  **Attachments**: The cloud function would need to handle the file uploads (screenshot, save game) and link to them in the GitHub issue, perhaps by uploading them to a private cloud storage bucket (e.g., Google Cloud Storage, AWS S3).

## 5. Implementation Plan

### Phase 1: In-Game UI & Data Capture

-   [ ] Create the bug report dialog scene (`res://src/ui/screens/support/BugReportDialog.tscn`).
-   [ ] Implement the logic in `BugReportDialog.gd` to capture the screenshot and game state data.
-   [ ] Add a global `BugReporter` autoload singleton to manage the process and hold the data.

### Phase 2: Backend Cloud Function

-   [ ] Choose a serverless platform (e.g., Netlify, Vercel, Google Cloud).
-   [ ] Write the cloud function that receives data, formats it, and creates a GitHub issue.
-   [ ] Set up a private GitHub repository for issue tracking.

### Phase 3: Integration & Crash Reporting

-   [ ] Connect the in-game `Submit` button to make an `HTTPRequest` to the cloud function endpoint.
-   [ ] Implement the global `unhandled_exception` handler.
-   [ ] Create the simple crash dialog scene.
-   [ ] Test both manual and automated reporting flows.

## 6. Player Privacy

-   **Anonymity**: All reports should be anonymous by default. Do not collect personal information unless the player explicitly provides it (e.g., an email for follow-up, which should be optional).
-   **Transparency**: The UI should clearly state what data is being collected and sent.
-   **Save Data**: Explicitly ask for permission before sending save game files.
