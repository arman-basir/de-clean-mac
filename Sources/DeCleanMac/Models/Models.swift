import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, cleanup, protection, speed, apps, files, duplicates, history, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .cleanup: return "Clear Cache"
        case .protection: return "Protection"
        case .speed: return "Speed & Memory"
        case .apps: return "Uninstall Apps"
        case .files: return "Large & Old Files"
        case .duplicates: return "Duplicate Finder"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .cleanup: return "trash"
        case .protection: return "shield"
        case .speed: return "gauge.with.dots.needle.67percent"
        case .apps: return "app.badge.checkmark"
        case .files: return "doc.text.magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

/// A category of reclaimable disk space (system cache, browser cache, trash, etc).
struct CleanupCategory: Identifiable {
    let id: String
    let name: String
    let desc: String
    let paths: [URL]
    var sizeBytes: Int64 = 0
    var selected: Bool = true
    var isScanning: Bool = false
}

struct DiskSlice: Identifiable {
    let id = UUID()
    let label: String
    let bytes: Int64
    let color: String
}

struct InstalledApp: Identifiable {
    let id: String            // bundle path, unique
    let name: String
    let path: URL
    var sizeBytes: Int64
    let lastUsed: Date?
}

struct LargeFile: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
    let sizeBytes: Int64
    let modified: Date?
}

struct StartupItem: Identifiable {
    let id: String  // plist path
    let label: String
    let path: URL
    var enabled: Bool
}

/// A login item registered in System Events (System Settings > General > Login Items).
struct LoginItemEntry: Identifiable {
    let id: String   // name, used as unique key for deletion
    let name: String
    let path: String
}

/// A persisted record of a cleanup/uninstall/delete action, shown in the History tab.
struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let action: String    // "Cleaned", "Uninstalled", "Deleted File", "Deleted Duplicate", "Removed Login Item"
    let detail: String
    let bytesFreed: Int64
}

/// A group of files that are byte-for-byte identical (matched by size + SHA-256).
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    var files: [LargeFile]
    var sizeEach: Int64 { files.first?.sizeBytes ?? 0 }
    var wastedBytes: Int64 { sizeEach * Int64(max(0, files.count - 1)) }
}

struct MemoryStats {
    var totalBytes: Int64 = 0
    var usedBytes: Int64 = 0
    var freeBytes: Int64 = 0
    var wiredBytes: Int64 = 0
    var compressedBytes: Int64 = 0
}

func formatBytes(_ bytes: Int64) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useMB, .useGB, .useKB]
    f.countStyle = .file
    return f.string(fromByteCount: max(0, bytes))
}
