import Foundation

/// Searches only a root the user connected, stopping at output folders.
struct CodexDiscovery {
    struct Result {
        let folders: [URL]
        let errors: [String]
    }
    let maximumDepth: Int
    let maximumVisitedDirectories: Int
    let maximumOutputFolders: Int

    init(maximumDepth: Int = 3, maximumVisitedDirectories: Int = 500, maximumOutputFolders: Int = 100) {
        self.maximumDepth = maximumDepth
        self.maximumVisitedDirectories = maximumVisitedDirectories
        self.maximumOutputFolders = maximumOutputFolders
    }

    static func validationError(for root: URL) -> String? {
        let path = root.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard !["/", home, home + "/Desktop", home + "/Documents"].contains(path) else {
            return "Choose your Codex folder, rather than a whole home, Desktop, or Documents folder."
        }
        guard let values = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
            values.isDirectory == true, values.isSymbolicLink != true else {
            return "The connected Codex folder is unavailable or is a symbolic link."
        }
        return nil
    }

    func discover(root: URL) -> Result {
        let root = root.standardizedFileURL
        if let error = Self.validationError(for: root) { return Result(folders: [], errors: [error]) }
        let manager = FileManager.default
        var pending: [(URL, Int)] = [(root, 0)]
        var visited = 0
        var found: [URL] = []
        var errors: [String] = []
        let ignored = Set(["node_modules", ".git", ".build", "build", "dist", "vendor"])
        let limitMessage = "Output discovery reached the \(maximumVisitedDirectories)-directory limit."
        while let (folder, depth) = pending.popLast(), visited < maximumVisitedDirectories {
            visited += 1
            guard let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                values.isDirectory == true, values.isSymbolicLink != true else { continue }
            let name = folder.lastPathComponent.lowercased()
            if name == "outputs" || name == "output" {
                found.append(folder)
                if found.count >= maximumOutputFolders {
                    errors.append("Output discovery reached the \(maximumOutputFolders)-folder limit.")
                    break
                }
                continue
            }
            guard depth < maximumDepth else { continue }
            do {
                let children = try manager.contentsOfDirectory(at: folder,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
                let candidates: [(URL, Date)] = children.compactMap { child in
                    let name = child.lastPathComponent.lowercased()
                    guard !ignored.contains(name), !name.hasSuffix(".app"),
                        let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]),
                        values.isDirectory == true, values.isSymbolicLink != true else { return nil }
                    return (child.standardizedFileURL, values.contentModificationDate ?? .distantPast)
                }.sorted {
                    if $0.1 != $1.1 { return $0.1 > $1.1 }
                    return $0.0.lastPathComponent > $1.0.lastPathComponent
                }
                // Descend through the newest branch immediately. If sibling
                // directories fill the budget, evict older pending siblings so
                // their output children do not starve behind a breadth-first queue.
                let remaining = max(0, maximumVisitedDirectories - visited)
                let selected = Array(candidates.prefix(remaining))
                let pendingAllowance = remaining - selected.count
                if candidates.count > selected.count || pending.count > pendingAllowance {
                    if !errors.contains(limitMessage) { errors.append(limitMessage) }
                }
                if pending.count > pendingAllowance {
                    pending.removeFirst(pending.count - pendingAllowance)
                }
                pending.append(contentsOf: selected.reversed().map { ($0.0, depth + 1) })
            } catch {
                if errors.count < 5 { errors.append("Cannot discover outputs in \(folder.lastPathComponent): \(error.localizedDescription)") }
            }
        }
        return Result(folders: found.sorted { $0.path < $1.path }, errors: errors)
    }
}
