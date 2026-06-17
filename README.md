# Claude Tracker

Minimal macOS menu bar app that shows Claude usage for multiple profiles.

<img width="312" height="363" alt="Screenshot 2026-01-23 at 8 23 08 PM" src="https://github.com/user-attachments/assets/7448748a-b4ba-4957-abff-bc70687bd98b" />
<img width="316" height="364" alt="Screenshot 2026-01-23 at 8 23 18 PM" src="https://github.com/user-attachments/assets/f9a1c0f9-a3d8-4e1d-ad4b-2cd9a35a4475" />


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

## Download & Install (no Xcode needed)

1. Grab `Claude-Tracker.dmg` (or `Claude-Tracker.zip`) from the build.
2. Open the `.dmg` and drag **Claude Tracker** into **Applications**.
3. The first time you open it, macOS will warn that it's from an
   unidentified developer (the app is signed but not notarized by Apple).
   **Right-click the app → Open → Open** to launch it anyway. You only do
   this once.

   If it still refuses, clear the download quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Claude Tracker.app"
   ```

A menu bar icon appears (top-right). There is no Dock icon — quit from the
**Manage** tab.

## Build a shareable copy yourself

This produces a universal (Apple Silicon + Intel) app, a `.dmg`, and a `.zip`
in `./dist`, using only the Xcode **Command Line Tools** — full Xcode is not
required:

```bash
./build.sh
```

> **Sharing more widely:** the build is *ad-hoc signed*, so recipients must do
> the right-click → Open step above. To ship without that warning you need an
> Apple Developer account ($99/yr) to sign with a Developer ID certificate and
> notarize the app.

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
