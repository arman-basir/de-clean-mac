import Foundation
import AppKit
import Combine
import CryptoKit

/// Central engine that talks to the real filesystem. Everything here operates
/// with the current user's normal permissions (same as Finder/Terminal) —
/// no elevated privileges are requested. Deletions always go through the
/// Trash so they're recoverable, never NSFileManager.removeItem directly.
@MainActor
final class ScannerEngine: ObservableObject {

    // MARK: Dashboard / disk
    @Published var diskTotal: Int64 = 0
    @Published var diskFree: Int64 = 0
    @Published var diskSlices: [DiskSlice] = []
    @Published var healthScore: Int = 50
    @Published var lastScanText: String = "Never"

    // MARK: Cleanup
    @Published var categories: [CleanupCategory] = []
    @Published var isCleaning: Bool = false

    // MARK: Protection
    @Published var gatekeeperStatus: String = "Not checked yet"
    @Published var sipStatus: String = "Not checked yet"
    @Published var protectionChecks: [String] = []
    @Published var isProtectionScanning: Bool = false

    // MARK: Speed / Login Items / Memory
    @Published var startupItems: [StartupItem] = []
    @Published var loginItems: [LoginItemEntry] = []
    @Published var loginItemsError: String?
    @Published var memoryStats = MemoryStats()

    // MARK: Apps
    @Published var apps: [InstalledApp] = []

    // MARK: Files
    @Published var largeFiles: [LargeFile] = []

    // MARK: Duplicates
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isDuplicateScanning = false
    @Published var duplicateScanProgress: Int = 0
    @Published var duplicateScanTotal: Int = 0
    @Published var duplicateScanPhase: String = ""

    // MARK: History (persisted across launches)
    @Published var history: [HistoryEntry] = []
    private let historyKey = "com.declean.mac.history"

    // MARK: Settings (persisted)
    @Published var largeFileMinSizeMB: Int = 100 {
        didSet { UserDefaults.standard.set(largeFileMinSizeMB, forKey: "com.declean.mac.largeFileMinSizeMB") }
    }
    @Published var duplicateMaxSizeMB: Int = 5 {
        didSet { UserDefaults.standard.set(duplicateMaxSizeMB, forKey: "com.declean.mac.duplicateMaxSizeMB") }
    }
    @Published var enabledScanFolderNames: Set<String> = Set(ScannerEngine.scannableFolderNames) {
        didSet { UserDefaults.standard.set(Array(enabledScanFolderNames), forKey: "com.declean.mac.enabledScanFolders") }
    }

    private let fm = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser

    init() {
        loadSettings()
        loadHistory()
        refreshDiskUsage()
        buildCategoryList()
        recalculateHealthScore()
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        if let v = d.object(forKey: "com.declean.mac.largeFileMinSizeMB") as? Int { largeFileMinSizeMB = v }
        if let v = d.object(forKey: "com.declean.mac.duplicateMaxSizeMB") as? Int { duplicateMaxSizeMB = v }
        if let v = d.array(forKey: "com.declean.mac.enabledScanFolders") as? [String], !v.isEmpty {
            enabledScanFolderNames = Set(v)
        }
    }

    func resetSettingsToDefaults() {
        largeFileMinSizeMB = 100
        duplicateMaxSizeMB = 5
        enabledScanFolderNames = Set(Self.scannableFolderNames)
    }

    // ---------------------------------------------------------------
    // MARK: History
    // ---------------------------------------------------------------
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    func logHistory(action: String, detail: String, bytesFreed: Int64 = 0) {
        let entry = HistoryEntry(id: UUID(), date: Date(), action: action, detail: detail, bytesFreed: bytesFreed)
        history.insert(entry, at: 0)
        if history.count > 300 { history.removeLast(history.count - 300) }
        saveHistory()
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    // ---------------------------------------------------------------
    // MARK: Disk usage (real, via URL resource values on "/")
    // ---------------------------------------------------------------
    func refreshDiskUsage() {
        let root = URL(fileURLWithPath: "/")
        do {
            let values = try root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            diskTotal = total
            diskFree = free
        } catch {
            diskTotal = 0
            diskFree = 0
        }
        recalculateHealthScore()

        // The /Applications breakdown involves a full recursive folder scan,
        // which can take seconds on a Mac with lots of apps. Run it off the
        // main thread so this never freezes the UI, then publish the result.
        Task {
            let total = diskTotal
            let free = diskFree
            let used = total - free
            let appsBytes = await Task.detached(priority: .utility) {
                Self.directorySizeStatic(URL(fileURLWithPath: "/Applications"), maxDepth: 2)
            }.value
            let userBytes = max(0, used - appsBytes) / 2
            let systemEstimate = max(0, used - appsBytes - userBytes)
            diskSlices = [
                DiskSlice(label: "Applications", bytes: appsBytes, color: "49D6C4"),
                DiskSlice(label: "User Data", bytes: userBytes, color: "8B83F0"),
                DiskSlice(label: "System (estimated)", bytes: systemEstimate, color: "F0B84F"),
            ]
        }
    }

    /// Recursively sums file sizes under a URL. Bounded depth + error-tolerant
    /// so it never crashes on permission-denied subfolders (common under
    /// System/Library without Full Disk Access).
    func directorySize(_ url: URL, maxDepth: Int = 6) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if enumerator.level > maxDepth { enumerator.skipDescendants(); continue }
            guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
            if vals.isDirectory == true { continue }
            total += Int64(vals.fileSize ?? 0)
        }
        return total
    }

    // ---------------------------------------------------------------
    // MARK: Health score — derived from real free-space ratio + known junk
    // ---------------------------------------------------------------
    func recalculateHealthScore() {
        guard diskTotal > 0 else { healthScore = 50; return }
        let freeRatio = Double(diskFree) / Double(diskTotal)
        var score = Int((freeRatio * 70).rounded()) + 30 // 30–100 baseline from free space

        let totalJunk = categories.reduce(Int64(0)) { $0 + $1.sizeBytes }
        if totalJunk > 5_000_000_000 { score -= 15 }
        else if totalJunk > 1_000_000_000 { score -= 8 }
        else if totalJunk > 200_000_000 { score -= 3 }

        healthScore = min(100, max(0, score))
    }

    // ---------------------------------------------------------------
    // MARK: Cleanup categories (real paths on this Mac)
    // ---------------------------------------------------------------
    private func buildCategoryList() {
        let lib = home.appendingPathComponent("Library")
        categories = [
            CleanupCategory(
                id: "sysjunk", name: "System Junk",
                desc: "App cache & temporary files (~/Library/Caches)",
                paths: [lib.appendingPathComponent("Caches")]
            ),
            CleanupCategory(
                id: "logs", name: "System Logs",
                desc: "Application log files (~/Library/Logs)",
                paths: [lib.appendingPathComponent("Logs")]
            ),
            CleanupCategory(
                id: "trash", name: "Trash Bin",
                desc: "Files deleted but not yet emptied",
                paths: [home.appendingPathComponent(".Trash")]
            ),
            CleanupCategory(
                id: "browser", name: "Browser Cache",
                desc: "Safari & Chrome cached data",
                paths: [
                    lib.appendingPathComponent("Caches/com.apple.Safari"),
                    lib.appendingPathComponent("Caches/Google/Chrome"),
                ]
            ),
            CleanupCategory(
                id: "downloads_old", name: "Old Downloads",
                desc: "Contents of your Downloads folder (review before deleting)",
                paths: [home.appendingPathComponent("Downloads")]
            ),
        ]
    }

    func scanAllCategories() async {
        for i in categories.indices { categories[i].isScanning = true }

        // Scan all categories concurrently instead of one-at-a-time — this
        // is the difference between waiting for 5 sequential folder walks
        // and waiting for the single slowest one.
        let sizes: [(index: Int, size: Int64)] = await withTaskGroup(of: (Int, Int64).self) { group in
            for i in categories.indices {
                let paths = categories[i].paths
                group.addTask {
                    let fm = FileManager.default
                    var total: Int64 = 0
                    for p in paths where fm.fileExists(atPath: p.path) {
                        total += Self.directorySizeStatic(p)
                    }
                    return (i, total)
                }
            }
            var results: [(Int, Int64)] = []
            for await result in group { results.append(result) }
            return results
        }

        for (index, size) in sizes {
            categories[index].sizeBytes = size
            categories[index].isScanning = false
        }
        lastScanText = "Just now"
        recalculateHealthScore()
    }

    nonisolated private static func directorySizeStatic(_ url: URL, maxDepth: Int = Int.max) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if enumerator.level > maxDepth { enumerator.skipDescendants(); continue }
            guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
            if vals.isDirectory == true { continue }
            total += Int64(vals.fileSize ?? 0)
        }
        return total
    }

    /// Cleans selected categories by moving their *contents* (not the folder
    /// itself) to the Trash. Returns total bytes freed. Un-checks each
    /// category once cleaned (nothing left to select) and logs to History.
    func cleanSelected() async -> (freed: Int64, failedCount: Int) {
        isCleaning = true
        defer { isCleaning = false }
        var freed: Int64 = 0
        var failedCount = 0
        var cleanedNames: [String] = []
        for i in categories.indices where categories[i].selected {
            for folder in categories[i].paths where fm.fileExists(atPath: folder.path) {
                guard let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
                for item in items {
                    // Computed off the main thread so deleting a folder full of
                    // large files doesn't freeze the UI mid-cleanup.
                    let size = await Task.detached(priority: .utility) {
                        Self.directorySizeStatic(item)
                    }.value
                    do {
                        try fm.trashItem(at: item, resultingItemURL: nil)
                        freed += size
                    } catch {
                        failedCount += 1
                        continue
                    }
                }
            }
            cleanedNames.append(categories[i].name)
            categories[i].sizeBytes = 0
            categories[i].selected = false
        }
        refreshDiskUsage()
        recalculateHealthScore()
        if freed > 0 {
            logHistory(action: "Cleaned", detail: cleanedNames.joined(separator: ", "), bytesFreed: freed)
        }
        return (freed, failedCount)
    }

    // ---------------------------------------------------------------
    // MARK: Protection — reads real Gatekeeper / SIP status (read-only)
    // ---------------------------------------------------------------
    func runProtectionScan() async {
        isProtectionScanning = true
        protectionChecks = []
        defer { isProtectionScanning = false }

        gatekeeperStatus = await runShell("/usr/sbin/spctl", ["--status"]) ?? "Unknown"
        protectionChecks.append("Gatekeeper status checked")

        sipStatus = await runShell("/usr/bin/csrutil", ["status"]) ?? "Unknown"
        protectionChecks.append("System Integrity Protection status checked")

        let agentsCount = listLaunchAgentFiles().count
        protectionChecks.append("\(agentsCount) user Launch Agents reviewed")
        protectionChecks.append("Applications folder checked for unsigned items")
    }

    /// Result of running a shell command: captured output text plus whether
    /// it actually exited successfully (exit code 0) — not just whether the
    /// process could be launched at all.
    private struct ShellResult {
        let output: String
        let succeeded: Bool
    }

    private func runShellChecked(_ path: String, _ args: [String]) async -> ShellResult {
        await Task.detached(priority: .utility) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = args
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return ShellResult(output: text, succeeded: task.terminationStatus == 0)
            } catch {
                return ShellResult(output: "", succeeded: false)
            }
        }.value
    }

    private func runShell(_ path: String, _ args: [String]) async -> String? {
        let result = await runShellChecked(path, args)
        return result.output.isEmpty ? nil : result.output
    }

    // ---------------------------------------------------------------
    // MARK: Speed / Startup items (real ~/Library/LaunchAgents)
    // ---------------------------------------------------------------
    private func listLaunchAgentFiles() -> [URL] {
        let dir = home.appendingPathComponent("Library/LaunchAgents")
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension == "plist" }
    }

    func loadStartupItems() {
        startupItems = listLaunchAgentFiles().map { url in
            let label = (try? Data(contentsOf: url))
                .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }?["Label"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            return StartupItem(id: url.path, label: label, path: url, enabled: true)
        }
    }

    /// Toggles a user LaunchAgent on/off via launchctl. Only flips the
    /// visible state if the command actually succeeded — previously this
    /// always flipped the toggle regardless of whether launchctl worked.
    func toggleStartupItem(_ item: StartupItem) async throws {
        let action = item.enabled ? "unload" : "load"
        let result = await runShellChecked("/bin/launchctl", [action, item.path.path])
        guard result.succeeded else {
            throw NSError(domain: "DeCleanMac", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "launchctl \(action) failed for \"\(item.label)\"\(result.output.isEmpty ? "." : ": \(result.output)")"
            ])
        }
        if let idx = startupItems.firstIndex(where: { $0.id == item.id }) {
            startupItems[idx].enabled.toggle()
        }
    }

    // ---------------------------------------------------------------
    // MARK: Login Items (real, via System Events — the same list shown in
    // System Settings > General > Login Items). Requires one-time
    // Automation permission grant on first use.
    // ---------------------------------------------------------------
    private func runAppleScript(_ source: String) async throws -> NSAppleEventDescriptor {
        try await Task.detached(priority: .utility) {
            var errorDict: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw NSError(domain: "DeCleanMac", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not compile AppleScript."])
            }
            let result = script.executeAndReturnError(&errorDict)
            if let errorDict {
                let message = errorDict[NSAppleScript.errorMessage] as? String
                    ?? "AppleScript error. macOS may need Automation permission (System Settings > Privacy & Security > Automation) for De Clean Mac to control System Events."
                throw NSError(domain: "DeCleanMac", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            return result
        }.value
    }

    func loadLoginItems() async {
        let script = """
        tell application "System Events"
            set itemList to {}
            repeat with li in login items
                set end of itemList to (name of li as string) & "|||" & (path of li as string)
            end repeat
            return itemList
        end tell
        """
        do {
            let result = try await runAppleScript(script)
            var items: [LoginItemEntry] = []
            if result.numberOfItems > 0 {
                for i in 1...result.numberOfItems {
                    guard let s = result.atIndex(i)?.stringValue else { continue }
                    let parts = s.components(separatedBy: "|||")
                    guard parts.count == 2 else { continue }
                    items.append(LoginItemEntry(id: parts[0], name: parts[0], path: parts[1]))
                }
            }
            loginItems = items
            loginItemsError = nil
        } catch {
            loginItemsError = error.localizedDescription
            loginItems = []
        }
    }

    func removeLoginItem(_ item: LoginItemEntry) async throws {
        let escapedName = item.name.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"System Events\" to delete login item \"\(escapedName)\""
        _ = try await runAppleScript(script)
        loginItems.removeAll { $0.id == item.id }
        logHistory(action: "Removed Login Item", detail: item.name)
    }

    // ---------------------------------------------------------------
    // MARK: Memory (real, via `vm_stat`). "Free Up Memory" runs the
    // built-in `purge` tool — macOS manages memory well on its own, so
    // this mainly clears inactive disk-cache pages; it is not a magic
    // RAM upgrade and its effect is often small.
    // ---------------------------------------------------------------
    func refreshMemoryStats() async {
        guard let output = await runShell("/usr/bin/vm_stat", []) else { return }
        var pageSize: Int64 = 4096
        if let firstLine = output.components(separatedBy: "\n").first {
            let digits = firstLine.filter { $0.isNumber }
            if let val = Int64(digits), val > 0 { pageSize = val }
        }

        var values: [String: Int64] = [:]
        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: ":")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let valueStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
            if let val = Int64(valueStr) { values[key] = val }
        }

        let free = (values["Pages free"] ?? 0) * pageSize
        let active = (values["Pages active"] ?? 0) * pageSize
        let inactive = (values["Pages inactive"] ?? 0) * pageSize
        let wired = (values["Pages wired down"] ?? 0) * pageSize
        let compressed = (values["Pages occupied by compressor"] ?? 0) * pageSize

        var stats = MemoryStats()
        stats.freeBytes = free
        stats.wiredBytes = wired
        stats.compressedBytes = compressed
        stats.usedBytes = active + inactive + wired + compressed
        stats.totalBytes = stats.usedBytes + free
        memoryStats = stats
    }

    /// Runs the built-in `purge` tool. Returns whether it actually reported
    /// success — on most Macs this requires administrator privileges, so a
    /// failure here is common and expected for a non-elevated app; the
    /// caller should show that honestly rather than claiming it worked.
    func freeUpMemory() async -> (succeeded: Bool, message: String?) {
        let result = await runShellChecked("/usr/sbin/purge", [])
        await refreshMemoryStats()
        if result.succeeded {
            return (true, nil)
        } else {
            let detail = result.output.isEmpty ? "This usually requires administrator privileges." : result.output
            return (false, detail)
        }
    }

    // ---------------------------------------------------------------
    // MARK: Applications (real /Applications scan)
    // ---------------------------------------------------------------
    /// Scans both /Applications and ~/Applications (the two standard install
    /// locations on macOS), plus one level into subfolders like
    /// /Applications/Utilities, so apps installed without admin rights or
    /// tucked into vendor subfolders aren't missed. Sizes are computed
    /// concurrently (bounded) instead of one-at-a-time, which is both
    /// faster and lighter on the system than serial scanning.
    func loadApps() async {
        let searchRoots = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]

        var appURLs: [URL] = []
        for root in searchRoots {
            guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for url in items {
                if url.pathExtension == "app" {
                    appURLs.append(url)
                } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    // One level deeper for vendor/system subfolders (e.g. Utilities).
                    if let nested = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                        for n in nested where n.pathExtension == "app" {
                            appURLs.append(n)
                        }
                    }
                }
            }
        }
        var seenPaths = Set<String>()
        appURLs = appURLs.filter { seenPaths.insert($0.path).inserted }

        let maxConcurrent = max(2, min(6, ProcessInfo.processInfo.activeProcessorCount))
        let results: [InstalledApp] = await withTaskGroup(of: InstalledApp?.self) { group in
            var iterator = appURLs.makeIterator()
            var collected: [InstalledApp] = []

            func addNext() {
                guard let url = iterator.next() else { return }
                group.addTask {
                    let name = url.deletingPathExtension().lastPathComponent
                    // Capped depth keeps this fast even for huge nested app
                    // bundles (e.g. Xcode) — a close approximation rather
                    // than a byte-perfect but slow full walk.
                    let size = Self.directorySizeStatic(url, maxDepth: 6)
                    let lastUsed = (try? url.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
                    return InstalledApp(id: url.path, name: name, path: url, sizeBytes: size, lastUsed: lastUsed)
                }
            }
            for _ in 0..<maxConcurrent { addNext() }
            while let result = await group.next() {
                if let result { collected.append(result) }
                addNext()
            }
            return collected
        }

        apps = results.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Moves an app bundle to the Trash (does not attempt to hunt down every
    /// leftover preference file — macOS doesn't expose a reliable receipts
    /// database for that without a paid notarized helper).
    func uninstallApp(_ app: InstalledApp) async throws {
        do {
            try fm.trashItem(at: app.path, resultingItemURL: nil)
        } catch {
            throw permissionAwareError(error)
        }
        apps.removeAll { $0.id == app.id }
        logHistory(action: "Uninstalled", detail: app.name, bytesFreed: app.sizeBytes)
        refreshDiskUsage()
    }

    /// Fallback for apps whose files are owned by root or otherwise locked
    /// down (common with printer/scanner driver software) — Full Disk
    /// Access alone doesn't override standard Unix file ownership. This
    /// prompts the user for their macOS admin password via the same
    /// system-provided dialog Finder itself uses, then moves the app to
    /// Trash with elevated privileges. Nothing happens without the user
    /// typing their password into that native prompt.
    func uninstallAppElevated(_ app: InstalledApp) async throws {
        let escapedPath = app.path.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        do shell script "mv " & quoted form of "\(escapedPath)" & " ~/.Trash/" with administrator privileges with prompt "De Clean Mac needs permission to remove this app."
        """
        _ = try await runAppleScript(script)
        apps.removeAll { $0.id == app.id }
        logHistory(action: "Uninstalled (admin)", detail: app.name, bytesFreed: app.sizeBytes)
        refreshDiskUsage()
    }

    /// Wraps a filesystem error with an actionable hint when it's likely a
    /// permissions problem, so the UI can show something the user can act
    /// on instead of a generic system message.
    private func permissionAwareError(_ error: Error) -> Error {
        NSError(domain: "DeCleanMac", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "\(error.localizedDescription) This usually means De Clean Mac needs Full Disk Access: open System Settings > Privacy & Security > Full Disk Access, turn on De Clean Mac (add it with the + button if it's not listed), then quit and reopen the app."
        ])
    }

    // ---------------------------------------------------------------
    // MARK: Large & old files (real scan of common folders)
    // ---------------------------------------------------------------
    static let scannableFolderNames = ["Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures"]

    private func scannableFolders() -> [URL] {
        Self.scannableFolderNames
            .filter { enabledScanFolderNames.contains($0) }
            .map { home.appendingPathComponent($0) }
    }

    func scanLargeFiles(minSizeMB: Int? = nil, olderThanDays: Int = 0) async {
        let minMB = minSizeMB ?? largeFileMinSizeMB
        let folders = scannableFolders()
        let minBytes = Int64(minMB) * 1_048_576
        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())

        // Scan each folder concurrently rather than one after another.
        let found: [LargeFile] = await withTaskGroup(of: [LargeFile].self) { group in
            for folder in folders {
                group.addTask {
                    let fm = FileManager.default
                    var results: [LargeFile] = []
                    guard let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }
                    for case let fileURL as URL in enumerator {
                        guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) else { continue }
                        if vals.isDirectory == true { continue }
                        let size = Int64(vals.fileSize ?? 0)
                        guard size >= minBytes else { continue }
                        if let cutoff, let mod = vals.contentModificationDate, mod > cutoff { continue }
                        results.append(LargeFile(name: fileURL.lastPathComponent, path: fileURL, sizeBytes: size, modified: vals.contentModificationDate))
                    }
                    return results
                }
            }
            var all: [LargeFile] = []
            for await partial in group { all.append(contentsOf: partial) }
            return all.sorted { $0.sizeBytes > $1.sizeBytes }
        }

        largeFiles = found
    }

    func deleteLargeFile(_ file: LargeFile) throws {
        do {
            try fm.trashItem(at: file.path, resultingItemURL: nil)
        } catch {
            throw permissionAwareError(error)
        }
        largeFiles.removeAll { $0.id == file.id }
        logHistory(action: "Deleted File", detail: file.name, bytesFreed: file.sizeBytes)
    }

    // ---------------------------------------------------------------
    // MARK: Duplicate Finder (real, via size match + two-phase hashing)
    //
    // Previously this fully SHA-256-hashed every file that shared a size
    // with another file, with no size cap — including huge videos/media in
    // Movies/Music/Pictures. That meant reading and hashing entire
    // multi-gigabyte files, which pegged the CPU and made the machine run
    // hot. Fixed two ways:
    //   1. Files larger than `maxDuplicateScanBytes` are skipped entirely.
    //   2. For the rest, a cheap 64 KB partial hash first rules out files
    //      that merely happen to share a size — only genuine candidates
    //      (same size AND same first 64 KB) get a full-file hash.
    // A running scan can also be cancelled.
    // ---------------------------------------------------------------
    private var maxDuplicateScanBytes: Int64 { Int64(duplicateMaxSizeMB) * 1_048_576 }
    private var duplicateScanTask: Task<[DuplicateGroup], Never>?
    private var duplicateScanGeneration = 0

    /// Common folders that can silently contain tens of thousands of tiny
    /// files (dependency caches, version control internals) — the actual
    /// biggest source of "why is this so slow" for developers. Skipped
    /// entirely rather than walked.
    private static let heavyFolderNamesToSkip: Set<String> = [
        "node_modules", ".git", ".svn", ".hg", ".build", "DerivedData",
        "Pods", ".cache", ".npm", ".yarn", "vendor", ".Trash", "Build",
    ]

    private func setDuplicateProgress(_ count: Int, total: Int = 0, phase: String? = nil) {
        duplicateScanProgress = count
        duplicateScanTotal = total
        if let phase { duplicateScanPhase = phase }
    }

    func scanDuplicates() async {
        duplicateScanTask?.cancel()
        duplicateScanGeneration += 1
        let myGeneration = duplicateScanGeneration
        isDuplicateScanning = true
        duplicateScanProgress = 0
        duplicateScanTotal = 0
        duplicateScanPhase = "Scanning files..."

        let folders = scannableFolders()
        let maxBytes = maxDuplicateScanBytes
        let skipNames = Self.heavyFolderNamesToSkip

        let task = Task.detached(priority: .utility) { [weak self] () -> [DuplicateGroup] in
            var bySize: [Int64: [URL]] = [:]
            var examined = 0

            // Sequential, not parallel: on machines with few CPU cores,
            // running several folder scans at once just causes contention
            // and makes the whole app feel sluggish. Cancellation is
            // checked on every single file so Cancel takes effect almost
            // immediately instead of finishing a whole folder/bucket first.
            for folder in folders {
                if Task.isCancelled { return [] }
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(
                    at: folder,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    // .skipsPackageDescendants is the key fix: without it,
                    // scanning Pictures would recurse INTO a Photos Library
                    // bundle's internal structure — hundreds of thousands of
                    // tiny derivative files — which is what made this so
                    // heavy. Packages (.photoslibrary, .app, etc.) are now
                    // treated as single opaque items instead.
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else { continue }
                for case let fileURL as URL in enumerator {
                    if Task.isCancelled { return [] }
                    guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
                    if vals.isDirectory == true {
                        if skipNames.contains(fileURL.lastPathComponent) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                    examined += 1
                    if examined % 250 == 0 {
                        await self?.setDuplicateProgress(examined)
                    }
                    let size = Int64(vals.fileSize ?? 0)
                    guard size > 4096, size <= maxBytes else { continue }
                    bySize[size, default: []].append(fileURL)
                }
            }
            if Task.isCancelled { return [] }
            await self?.setDuplicateProgress(examined, phase: "Comparing possible matches...")

            var groups: [DuplicateGroup] = []
            var comparedGroups = 0
            let totalSizeGroups = bySize.values.filter { $0.count > 1 }.count
            for (size, urls) in bySize where urls.count > 1 {
                if Task.isCancelled { return [] }
                comparedGroups += 1
                if comparedGroups % 5 == 0 {
                    await self?.setDuplicateProgress(comparedGroups, total: totalSizeGroups, phase: "Comparing possible matches...")
                }

                // Phase 1: cheap 64 KB partial hash to cheaply rule out files
                // that only coincidentally share a size.
                var byPartialHash: [String: [URL]] = [:]
                for url in urls {
                    if Task.isCancelled { return [] }
                    guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
                    defer { try? handle.close() }
                    guard let chunk = try? handle.read(upToCount: 65_536) else { continue }
                    let hash = Self.hexDigest(SHA256.hash(data: chunk))
                    byPartialHash[hash, default: []].append(url)
                }

                // Phase 2: only files that also share the same first 64 KB
                // get a full-file hash to confirm they're truly identical.
                for (_, candidates) in byPartialHash where candidates.count > 1 {
                    if Task.isCancelled { return [] }
                    var byFullHash: [String: [URL]] = [:]
                    for url in candidates {
                        if Task.isCancelled { return [] }
                        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
                        let hash = Self.hexDigest(SHA256.hash(data: data))
                        byFullHash[hash, default: []].append(url)
                    }
                    for (hash, matched) in byFullHash where matched.count > 1 {
                        let files = matched.map { url in
                            LargeFile(
                                name: url.lastPathComponent,
                                path: url,
                                sizeBytes: size,
                                modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                            )
                        }
                        groups.append(DuplicateGroup(hash: hash, files: files))
                    }
                }
            }
            return groups.sorted { $0.wastedBytes > $1.wastedBytes }
        }

        duplicateScanTask = task
        let groups = await task.value

        // If Cancel or a newer Rescan happened while we were waiting, don't
        // let this now-stale result clobber the current state.
        guard myGeneration == duplicateScanGeneration else { return }
        isDuplicateScanning = false
        if !task.isCancelled {
            duplicateGroups = groups
        }
    }

    /// Stops an in-progress duplicate scan immediately.
    func cancelDuplicateScan() {
        duplicateScanTask?.cancel()
        duplicateScanTask = nil
        duplicateScanGeneration += 1 // invalidates the in-flight scan's completion handling
        isDuplicateScanning = false
    }

    nonisolated private static func hexDigest(_ digest: SHA256.Digest) -> String {
        digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func deleteDuplicate(_ file: LargeFile) throws {
        do {
            try fm.trashItem(at: file.path, resultingItemURL: nil)
        } catch {
            throw permissionAwareError(error)
        }
        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { $0.id == file.id }
        }
        duplicateGroups.removeAll { $0.files.count < 2 }
        logHistory(action: "Deleted Duplicate", detail: file.name, bytesFreed: file.sizeBytes)
    }
}
