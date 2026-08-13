# De Clean Mac

A native SwiftUI macOS cleaning & optimization utility — inspired by CleanMyMac, with functionality that genuinely reads and cleans your system (not a simulation).

## Real, working features

- **Dashboard** — real disk usage, health score computed from actual free-space ratio + known junk size, with **Clear Cache** and **Uninstall Apps** featured as the primary actions
- **Clear Cache** — scans real size of `~/Library/Caches`, `~/Library/Logs`, `~/.Trash`, Safari/Chrome cache, and Downloads; cleans by moving items to the **Trash**. Includes Select All/Deselect All and a confirmation dialog before cleaning.
- **Uninstall Apps** — lists real applications in `/Applications` with real size and last-opened date, with a search box to filter. Uninstalling moves the app to Trash after a confirmation dialog, and surfaces a clear error message if it fails (e.g. missing admin permission) instead of failing silently.
- **Protection** — checks real Gatekeeper (`spctl --status`) and System Integrity Protection (`csrutil status`) status — a built-in macOS diagnostic, not a full antivirus.
- **Speed & Memory** — three real sub-sections:
  - **Memory** — live stats from `vm_stat` (used/free/wired/compressed) with a "Free Up Memory" button that runs the built-in `purge` tool (disclosed in-app as having limited effect, since macOS already manages memory well).
  - **Login Items** — the same list shown in System Settings > General > Login Items, read and removable via AppleScript/System Events (macOS will prompt for one-time Automation permission).
  - **Launch Agents** — toggles user agents in `~/Library/LaunchAgents` via `launchctl`.
- **Large & Old Files** — scans `Downloads`, `Documents`, `Desktop`, `Movies`, `Music`, `Pictures` for files over 100 MB, with a confirmation dialog before deleting.
- **Duplicate Finder** — finds byte-for-byte identical files (matched by size, then SHA-256 hash) across the same folders, and lets you delete extra copies while keeping one.
- **History** — a persisted log (survives app restarts) of every clean/uninstall/delete action taken, with total space freed.

## Navigation

- **Left sidebar** — click any item to jump straight to that feature
- **Back to Dashboard** button at the top of every feature screen, so you're never stuck

## App Icon

A custom logo is drawn directly in SwiftUI code (`Views/LogoMark.swift`) for the in-app sidebar branding — no image files are loaded at runtime, which avoids a class of SwiftPM resource-bundle crashes seen when packaging outside of Xcode. The macOS dock/Finder icon comes from `Assets.xcassets/AppIcon.appiconset` (all required sizes included) via `Info.plist`'s `CFBundleIconFile`, which the GitHub Actions build workflow wires up automatically when assembling the `.app`.

## Running it on your Mac

Requires **Xcode 15+** and **macOS 13+**.

### Option A — Open in Xcode
1. Open Xcode → **File > Open...**
2. Select the `Package.swift` file in this folder
3. Xcode creates a run scheme automatically. Press **⌘R** to build & run.

### Option B — Command line
```bash
swift run
```

## Permissions you may need

Some folders (especially outside your Home folder, or certain Library subfolders) require **Full Disk Access**:
System Settings → Privacy & Security → Full Disk Access → add this app (or Xcode/Terminal if running via `swift run`).

Without this permission the app still runs fine — inaccessible folders are safely skipped (no crash), they'll just read as 0 bytes or an empty category.

The **Login Items** section (Speed & Memory tab) controls System Events via AppleScript, so macOS will show a one-time **Automation** permission prompt the first time you open that tab or try to remove an item. If you accidentally deny it, re-enable it under System Settings → Privacy & Security → Automation → De Clean Mac → System Events.

## Publishing to GitHub

```bash
cd DeCleanMac
git init
git add .
git commit -m "Initial commit: De Clean Mac"
git branch -M main
git remote add origin https://github.com/USERNAME/de-clean-mac.git
git push -u origin main
```

Replace `USERNAME` and the repo name with your own GitHub account. Create an empty repository on github.com first before running the commands above.

## Known limitations

- **Uninstall** moves the `.app` bundle to Trash but doesn't hunt down every leftover file (preferences, cache under a different bundle ID) — macOS doesn't expose a reliable receipts database without a separate notarized helper.
- **Protection** is a built-in macOS security status check (Gatekeeper/SIP), not a malware scanner with a virus-signature database.
- All deletions use `FileManager.trashItem`, so everything can be recovered from the Trash before it's emptied.

## License

MIT — see `LICENSE`.
