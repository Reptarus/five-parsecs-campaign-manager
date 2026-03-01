# Paid DLC Gating Mechanism Design

## 1. Core Concept: Entitlement Verification

The fundamental principle of DLC gating is to verify a player's "entitlement" to specific content. This means checking if they have legitimately purchased or unlocked the DLC. This verification process differs significantly across platforms.

## 2. Platform-Specific Entitlement Mechanisms

### 2.1. Android (Google Play Store)

*   **Mechanism**: Google Play Billing Library.
*   **How it Works**:
    1.  **Initialization**: The game integrates the Google Play Billing Library.
    2.  **Query Purchases**: At game launch or when attempting to access DLC content, the game queries Google Play's servers for the user's purchases.
    3.  **Verify Entitlement**: The game checks if the specific DLC SKU (Stock Keeping Unit) is present in the returned list of owned purchases.
    4.  **Consumption (for one-time purchases)**: For consumable DLC (e.g., in-game currency), the purchase needs to be "consumed" to allow re-purchase. For permanent content like a DLC expansion, it's typically a non-consumable purchase.
*   **Key Considerations**:
    *   Requires a Google Play Developer account and setting up in-app products (DLC SKUs).
    *   Internet connection is usually required for initial verification, but the library often caches purchase information for offline access.
    *   Handle various purchase states (pending, purchased, refunded).

### 2.2. iOS (Apple App Store)

*   **Mechanism**: StoreKit Framework.
*   **How it Works**:
    1.  **Initialization**: The game integrates StoreKit.
    2.  **Restore Purchases**: Players can "restore" purchases, which queries Apple's servers for their transaction history.
    3.  **Verify Entitlement**: The game iterates through the restored transactions to find the specific DLC product identifier.
*   **Key Considerations**:
    *   Requires an Apple Developer account and setting up in-app purchases (DLC Product IDs).
    *   "Restore Purchases" functionality is mandatory for non-consumable purchases to allow users to regain content on new devices or reinstalls.
    *   Similar to Android, initial verification often requires internet, with subsequent caching.

### 2.3. Steam (Desktop)

*   **Mechanism**: Steamworks API (`ISteamApps` interface).
*   **How it Works**:
    1.  **Initialization**: The game integrates the Steamworks SDK.
    2.  **`ISteamApps::IsDlcInstalled(AppId_t dlcAppID)`**: This function is the primary method. You provide the `AppID` of your DLC (which is a separate AppID from your base game on Steam).
    3.  **Verify Entitlement**: The function returns `true` if the DLC is owned and installed, `false` otherwise.
*   **Key Considerations**:
    *   Requires your game and DLC to be set up on Steam as separate AppIDs.
    *   Steam client must be running and the user logged in.
    *   The DLC content itself is usually downloaded and managed by the Steam client.

### 2.4. General Desktop / Other Platforms (e.g., Direct Download, Itch.io)

*   **Mechanism**: Custom license key validation, or simpler flag.
*   **How it Works**:
    1.  **License Key**: If selling directly, you might issue unique license keys. The game would prompt for a key, send it to your backend server for validation, and unlock content if valid.
    2.  **Simple Flag/File**: For less stringent gating, a simple flag in a configuration file or a specific file present in the game directory could indicate ownership.
*   **Key Considerations**:
    *   Requires a custom backend for license key management and validation (more complex).
    *   Less secure against piracy if not using robust backend validation.
    *   Offline play might be easier to support if the check is local.

### 3. In-Game Integration (GDScript Conceptual)

A central `DLCManager` or `GameState` singleton would handle all DLC checks.

```gdscript
# src/core/systems/DLCManager.gd (Autoload Singleton)
extends Node
class_name DLCManager

signal dlc_status_updated(dlc_id: String, is_owned: bool)

const COMPENDIUM_DLC_ID = "com.yourgame.compendium_expansion" # Android/iOS SKU/Product ID
const STEAM_COMPENDIUM_DLC_APPID = 123456789 # Example Steam DLC AppID

var _dlc_ownership_cache: Dictionary = {} # Cache to store ownership status

func _ready():
    # Initialize platform-specific billing/storefront APIs here
    # For example, connect to Google Play Billing, StoreKit, Steamworks
    _query_all_dlc_ownership()

func _query_all_dlc_ownership():
    # --- Platform-specific implementation ---
    # Android:
    # Call Google Play Billing Library to query purchases.
    # On purchase result, update _dlc_ownership_cache and emit signal.

    # iOS:
    # Call StoreKit to restore purchases.
    # On restore result, update _dlc_ownership_cache and emit signal.

    # Steam:
    # if Steam.is_steam_running(): # Assuming a Godot Steamworks plugin
    #     var is_compendium_owned = Steam.is_dlc_installed(STEAM_COMPENDIUM_DLC_APPID)
    #     _update_dlc_status("compendium", is_compendium_owned)

    # General Desktop (e.g., check local file/flag):
    # var compendium_owned_local = FileAccess.file_exists("user://dlc_compendium_unlocked.flag")
    # _update_dlc_status("compendium", compendium_owned_local)

    # For now, simulate for development
    _update_dlc_status("compendium", true) # Assume owned for testing
    print("DLCManager: Initial DLC ownership queried.")

func _update_dlc_status(dlc_id: String, is_owned: bool):
    if _dlc_ownership_cache.get(dlc_id, false) != is_owned:
        _dlc_ownership_cache[dlc_id] = is_owned
        dlc_status_updated.emit(dlc_id, is_owned)
        print(str("DLC '", dlc_id, "' ownership updated to: ", is_owned))

## Public API for checking DLC ownership
func is_dlc_owned(dlc_id: String) -> bool:
    # Return cached status. If not in cache, trigger a query (if not already in progress)
    # and return false until status is confirmed.
    return _dlc_ownership_cache.get(dlc_id, false)

## Function to trigger purchase flow (called from UI)
func purchase_dlc(dlc_id: String):
    # --- Platform-specific implementation ---
    # Android: Start Google Play Billing purchase flow
    # iOS: Start StoreKit purchase flow
    # Steam: Open Steam store page for DLC
    print(str("Attempting to purchase DLC: ", dlc_id))

# Example of how other parts of the game would check
# In CharacterCreationUI.gd
# if DLCManager.is_dlc_owned("compendium"):
#     # Show Krag/Skulker options
# else:
#     # Show "Requires Compendium DLC" message
```

### 4. Gating Logic: What Happens When DLC is Owned vs. Not Owned

#### 4.1. Content Access

*   **Owned**: Full access to all DLC content (species, psionics, missions, enemies, etc.).
*   **Not Owned**:
    *   **UI Elements**: Hide, disable, or grey out UI elements related to the DLC. Display a "Requires DLC" message or a button to purchase.
    *   **Gameplay Mechanics**: Prevent access to DLC-specific mechanics (e.g., cannot select Psionic character, cannot generate Elite Enemy encounters).
    *   **Data Loading**: Only load DLC-specific data files if the DLC is owned. This saves memory and prevents errors from missing data.
    *   **Narrative/Events**: Do not trigger DLC-specific story events or encounters.

#### 4.2. Fallback Behavior

When DLC is not owned but the game logic might otherwise try to use DLC content (e.g., a random mission generator rolls a DLC-specific mission type):

*   **Substitute**: Replace the DLC content with a suitable base-game alternative (e.g., a standard mission instead of a Stealth Mission).
*   **Inform User**: Optionally, display a subtle message (e.g., "A unique mission opportunity was detected, but requires the Compendium DLC.") to encourage purchase.
*   **Prevent Error**: Crucially, ensure the game does not crash or encounter errors due to missing DLC content.

### 5. Persistence

*   **Platform Handles Persistence**: For Google Play, Apple App Store, and Steam, purchase information is managed by the respective platform's servers. The game queries this information as needed.
*   **Local Caching**: The `DLCManager` should cache the ownership status locally (e.g., in `_dlc_ownership_cache`) to avoid constant network requests and allow for offline play after initial verification. This cache should be refreshed periodically or upon significant events (e.g., game launch, "restore purchases" action).
*   **Save Games**: DLC ownership status should generally *not* be saved directly within the player's save game files, as this can be easily manipulated. Instead, the game should always verify ownership via the `DLCManager` at load time.

### 6. User Experience

*   **Clear Communication**: Clearly inform players which content is part of a DLC and how to acquire it.
*   **Non-Intrusive Gating**: Avoid aggressive pop-ups or constant reminders. Gating should be natural within the UI and gameplay flow.
*   **"Try Before You Buy" (Optional)**: Consider offering a small, limited demo of DLC content (e.g., one introductory mission, a preview of a species) to entice players.
*   **Store Integration**: Provide direct links or buttons within the game to the relevant storefront page for purchasing the DLC.
