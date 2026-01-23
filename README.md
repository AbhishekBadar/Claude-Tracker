# Claude Tracker

Minimal macOS menu bar app that shows Claude usage for multiple profiles.

## Build and Run (Xcode)

1. Clone the repo
   ```bash
   git clone <YOUR_REPO_URL>
   cd <REPO_NAME>
   ```

2. Open the project
   ```bash
   open "Claude Tracker.xcodeproj"
   ```

3. Build and run
   - In Xcode, press `Cmd + R`

4. Optional: Install the app
   - In Xcode, go to **Product → Show Build Folder**
   - Find `Claude Tracker.app` in `Products`
   - Drag it into `/Applications`

## Usage

- Click the menu bar icon to open the popup.
- Use **Manage** tab to add profiles (name + session key).
- Use **Usage** tab to view per-profile stats.
- Use **Delete All** to clear saved profiles.

## How to Get Your Session Key

1. Open Claude in your browser and log in.
2. Open Developer Tools (Right click → Inspect).
3. Go to the **Application** tab.
4. In the left sidebar, open **Cookies**.
5. Select the Claude site (e.g., `https://claude.ai`).
6. Find the cookie named `sessionKey`.
7. Copy its value (it starts with `sk-`).
8. Paste it into the app’s **Manage** tab.

## Storage

Profiles are stored locally in `UserDefaults` (on your Mac only).
