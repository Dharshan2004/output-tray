import Foundation
import Combine

struct TrayArtifact: Identifiable, Equatable {
    let url: URL
    let title: String
    let project: String?
    let task: String?
    let createdAt: Date
    let kind: String
    let modifiedAt: Date
    let byteCount: Int64
    var id: String { url.standardizedFileURL.path }
    var folderName: String { url.deletingLastPathComponent().lastPathComponent }
}

/// Reads only immediate files in explicitly selected folders. A changed file must
/// have the same size and modification date on two scans before it is presented.
struct ArtifactScanner {
    private struct Fingerprint: Equatable {
        let size: Int64
        let modified: Date
    }
    private struct Manifest: Decodable {
        let artifacts: [Entry]
    }
    private struct Entry: Decodable {
        let path: String
        let title: String?
        let project: String?
        let task: String?
        let createdAt: String?
    }
    private var observations: [String: Fingerprint] = [:]
    private var accepted: [String: TrayArtifact] = [:]
    let maximumFilesPerFolder: Int

    init(maximumFilesPerFolder: Int = 500) {
        self.maximumFilesPerFolder = maximumFilesPerFolder
    }

    mutating func scan(folders: [URL]) -> (artifacts: [TrayArtifact], errors: [String]) {
        var nextObservations: [String: Fingerprint] = [:]
        var nextAccepted: [String: TrayArtifact] = [:]
        var errors: [String] = []
        let manager = FileManager.default
        for folder in folders {
            let base = folder.standardizedFileURL
            let entries: [URL]
            do {
                entries = try manager.contentsOfDirectory(at: base,
                    includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                        .fileSizeKey, .contentModificationDateKey, .creationDateKey],
                    options: [.skipsHiddenFiles])
            } catch {
                errors.append("Cannot read \(base.lastPathComponent): \(error.localizedDescription)")
                continue
            }
            var metadata: [String: Entry] = [:]
            let manifestURL = base.appendingPathComponent(".output-tray.json")
            if manager.fileExists(atPath: manifestURL.path) {
                do {
                    let values = try manifestURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
                    guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 1_000_000 else {
                        throw CocoaError(.fileReadInvalidFileName)
                    }
                    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
                    for entry in manifest.artifacts {
                        // Metadata may describe only an immediate child, never an
                        // absolute path, a nested folder, or a parent escape.
                        guard !entry.path.isEmpty, !entry.path.hasPrefix("/"),
                            !entry.path.contains("/"), entry.path != ".", entry.path != "..",
                            !entry.path.hasPrefix(".") else { continue }
                        let target = base.appendingPathComponent(entry.path).standardizedFileURL
                        guard target.deletingLastPathComponent().path == base.path else { continue }
                        metadata[target.path] = entry
                    }
                } catch {
                    errors.append("Metadata in \(base.lastPathComponent) could not be read.")
                }
            }
            let candidates = entries.filter { !Self.isTemporary($0.lastPathComponent) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if candidates.count > maximumFilesPerFolder {
                errors.append("\(base.lastPathComponent) has more than \(maximumFilesPerFolder) files; only the first \(maximumFilesPerFolder) are watched.")
            }
            for file in candidates.prefix(maximumFilesPerFolder) {
                let url = file.standardizedFileURL
                guard nextObservations[url.path] == nil,
                    let values = try? url.resourceValues(forKeys: [.isRegularFileKey,
                        .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]),
                    values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                let modified = values.contentModificationDate ?? .distantPast
                let fingerprint = Fingerprint(size: Int64(values.fileSize ?? 0), modified: modified)
                nextObservations[url.path] = fingerprint
                guard observations[url.path] == fingerprint else {
                    // Keep the previous visible entry while an application writes
                    // a replacement, but remove it as soon as its file disappears.
                    if let previous = accepted[url.path] { nextAccepted[url.path] = previous }
                    continue
                }
                let entry = metadata[url.path]
                let creation = entry?.createdAt.flatMap { ISO8601DateFormatter().date(from: $0) }
                    ?? values.creationDate ?? modified
                nextAccepted[url.path] = TrayArtifact(url: url,
                    title: Self.nonempty(entry?.title) ?? url.lastPathComponent,
                    project: Self.nonempty(entry?.project), task: Self.nonempty(entry?.task),
                    createdAt: creation, kind: url.pathExtension.isEmpty ? "FILE" : url.pathExtension.uppercased(),
                    modifiedAt: modified, byteCount: fingerprint.size)
            }
        }
        observations = nextObservations
        accepted = nextAccepted
        let artifacts = nextAccepted.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
        return (artifacts, errors)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isTemporary(_ name: String) -> Bool {
        let lower = name.lowercased()
        return name.hasPrefix(".") || name.hasPrefix("~$") || name.hasSuffix("~")
            || [".tmp", ".temp", ".part", ".partial", ".download", ".crdownload", ".swp"].contains { lower.hasSuffix($0) }
    }
}

@MainActor
final class ArtifactStore: ObservableObject {
    @Published private(set) var artifacts: [TrayArtifact] = []
    @Published private(set) var watchedFolders: [URL] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var codexRoot: URL?
    @Published private(set) var codexErrorMessage: String?
    private var scanner = ArtifactScanner()
    private let defaultFolder: URL
    private let defaults: UserDefaults
    private let persistenceKey: String
    private var refreshSubscription: AnyCancellable?
    private var manualFolders: [URL] = []
    private var discoveredFolders: [URL] = []
    private var discoveryErrors: [String] = []
    private var connectionSelectionError: String?
    private var lastDiscovery = Date.distantPast
    private let codexPersistenceKey = "OutputTray.codexRoot"
    private let persistsCodexConnection: Bool

    init(defaultFolder: URL, defaults: UserDefaults = .standard, startMonitoring: Bool = true, ignoreSavedCodexRoot: Bool = false) {
        self.defaultFolder = defaultFolder.standardizedFileURL
        self.defaults = defaults
        persistsCodexConnection = !ignoreSavedCodexRoot
        persistenceKey = "OutputTray.watchedFolders.\(defaultFolder.standardizedFileURL.path)"
        let extra = (defaults.stringArray(forKey: persistenceKey) ?? []).map { URL(fileURLWithPath: $0).standardizedFileURL }
        let extraPaths = Set(extra.map(\.path).filter { $0 != self.defaultFolder.path })
        manualFolders = extraPaths.sorted().map { URL(fileURLWithPath: $0, isDirectory: true) }
        if !ignoreSavedCodexRoot {
            var rootPath = defaults.string(forKey: codexPersistenceKey)
            if rootPath == nil, let legacyPath = defaults.string(forKey: persistenceKey + ".codexRoot") {
                rootPath = legacyPath
                defaults.set(legacyPath, forKey: codexPersistenceKey)
                defaults.removeObject(forKey: persistenceKey + ".codexRoot")
            }
            if let rootPath { codexRoot = URL(fileURLWithPath: rootPath, isDirectory: true) }
        }
        rebuildFolders()
        refresh()
        if startMonitoring {
            refreshSubscription = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect().sink { [weak self] _ in
                    Task { @MainActor [weak self] in self?.refresh() }
                }
        }
    }

    func addFolder(_ url: URL) {
        let folder = url.standardizedFileURL
        guard folder.path != defaultFolder.path,
            !manualFolders.contains(where: { $0.path == folder.path }) else { return }
        manualFolders.append(folder)
        rebuildFolders()
        persist()
        refresh()
    }

    func removeFolder(_ url: URL) {
        guard url.standardizedFileURL.path != defaultFolder.path else { return }
        manualFolders.removeAll { $0.path == url.standardizedFileURL.path }
        rebuildFolders()
        persist()
        refresh()
    }

    func refresh() {
        if let root = codexRoot, Date().timeIntervalSince(lastDiscovery) >= 3 {
            let discovery = CodexDiscovery().discover(root: root)
            discoveredFolders = discovery.folders
            discoveryErrors = discovery.errors
            lastDiscovery = Date()
            rebuildFolders()
        }
        let connectionErrors = connectionSelectionError.map { [$0] } ?? discoveryErrors
        codexErrorMessage = connectionErrors.isEmpty ? nil : connectionErrors.joined(separator: "\n")
        let result = scanner.scan(folders: watchedFolders)
        if artifacts != result.artifacts { artifacts = result.artifacts }
        let errors = connectionErrors + result.errors
        let message = errors.isEmpty ? nil : errors.joined(separator: "\n")
        if errorMessage != message { errorMessage = message }
    }

    private func persist() {
        defaults.set(manualFolders.map(\.path), forKey: persistenceKey)
    }

    func connectCodexRoot(_ url: URL) {
        let root = url.standardizedFileURL
        if let error = CodexDiscovery.validationError(for: root) {
            connectionSelectionError = error
            codexErrorMessage = error
            errorMessage = error
            return
        }
        connectionSelectionError = nil
        codexRoot = root
        if persistsCodexConnection { defaults.set(root.path, forKey: codexPersistenceKey) }
        lastDiscovery = .distantPast
        refresh()
    }

    func disconnectCodex() {
        codexRoot = nil
        connectionSelectionError = nil
        codexErrorMessage = nil
        if persistsCodexConnection { defaults.removeObject(forKey: codexPersistenceKey) }
        discoveredFolders = []
        discoveryErrors = []
        rebuildFolders()
        refresh()
    }

    func isAutomaticallyDiscovered(_ url: URL) -> Bool {
        discoveredFolders.contains { $0.path == url.standardizedFileURL.path }
            && !manualFolders.contains { $0.path == url.standardizedFileURL.path }
            && url.standardizedFileURL.path != defaultFolder.path
    }

    private func rebuildFolders() {
        var paths = Set([defaultFolder.path])
        var folders = [defaultFolder]
        for folder in manualFolders + discoveredFolders {
            if paths.insert(folder.path).inserted { folders.append(folder) }
        }
        if watchedFolders.map(\.path) != folders.map(\.path) { watchedFolders = folders }
    }
}
