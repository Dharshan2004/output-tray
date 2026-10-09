import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

@main
struct StoreChecks {
    @MainActor
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("result.md")
        var scanner = ArtifactScanner()
        try Data("first".utf8).write(to: file)
        try expect(scanner.scan(folders: [folder]).artifacts.isEmpty, "unstable new file exposed")
        try expect(scanner.scan(folders: [folder]).artifacts.first?.byteCount == 5, "stable file missing")
        try Data("replacement".utf8).write(to: file)
        try expect(scanner.scan(folders: [folder]).artifacts.first?.byteCount == 5, "partial write exposed")
        try expect(scanner.scan(folders: [folder]).artifacts.first?.byteCount == 11, "modified file not updated")
        try FileManager.default.removeItem(at: file)
        try expect(scanner.scan(folders: [folder]).artifacts.isEmpty, "deleted file retained")
        print("PASS creation, stable write, modification, deletion")

        let real = folder.appendingPathComponent("report.pdf")
        try Data("report".utf8).write(to: real)
        for name in [".hidden", "draft.tmp", "~$sheet.xlsx"] {
            try Data("x".utf8).write(to: folder.appendingPathComponent(name))
        }
        let nested = folder.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: nested.appendingPathComponent("child.md"))
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link.pdf"), withDestinationURL: real)
        let manifest = #"{"artifacts":[{"path":"report.pdf","title":"Demo report","project":"Output Tray","task":"Demo","createdAt":"2026-10-09T10:00:00Z"},{"path":"../report.pdf","title":"Escape"},{"path":"/report.pdf","title":"Absolute"}]}"#
        let metadata = folder.appendingPathComponent(".output-tray.json")
        try Data(manifest.utf8).write(to: metadata)
        _ = scanner.scan(folders: [folder])
        let result = scanner.scan(folders: [folder, folder])
        try expect(result.artifacts.count == 1, "hidden/temp/nested/symlink or duplicate entry exposed")
        try expect(result.artifacts[0].title == "Demo report", "manifest label missing")
        try expect(result.artifacts[0].project == "Output Tray" && result.artifacts[0].task == "Demo", "project/task missing")
        try expect(result.artifacts[0].kind == "PDF", "kind incorrect")
        try expect(result.artifacts[0].createdAt == ISO8601DateFormatter().date(from: "2026-10-09T10:00:00Z"), "registered date incorrect")
        print("PASS labels, explicit provenance, date, unsafe paths, duplicates, temporary/hidden/nested/symlink exclusion")

        try Data("invalid".utf8).write(to: metadata)
        let fallback = scanner.scan(folders: [folder])
        try expect(fallback.artifacts.first?.title == "report.pdf" && fallback.errors.count == 1, "malformed metadata did not fall back")
        print("PASS malformed manifest fallback")

        let suite = "OutputTraySelfTest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw TestFailure(description: "defaults unavailable") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let primary = folder.appendingPathComponent("zzz-primary")
        let extra = folder.appendingPathComponent("aaa-extra")
        try FileManager.default.createDirectory(at: primary, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: extra, withIntermediateDirectories: true)
        let store = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
        store.addFolder(extra)
        store.addFolder(URL(fileURLWithPath: extra.path, isDirectory: true))
        store.removeFolder(primary)
        try expect(store.watchedFolders.map(\.path) == [primary.path, extra.path], "default order, dedup or remove guard failed")
        let restored = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
        try expect(restored.watchedFolders.map(\.path) == [primary.path, extra.path], "persistence failed")
        restored.removeFolder(extra)
        try expect(ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false).watchedFolders.map(\.path) == [primary.path], "remove did not persist")
        print("PASS folder persistence, ordering, path dedup, default removal guard")
        let connectedRoot = folder.appendingPathComponent("Codex")
        let discoveredOutput = connectedRoot.appendingPathComponent("2026-10-09/task/outputs")
        try FileManager.default.createDirectory(at: discoveredOutput, withIntermediateDirectories: true)
        let deep = connectedRoot.appendingPathComponent("a/b/c/outputs")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        let ignoredOutput = connectedRoot.appendingPathComponent("node_modules/outputs")
        try FileManager.default.createDirectory(at: ignoredOutput, withIntermediateDirectories: true)
        let nestedOutput = discoveredOutput.appendingPathComponent("outputs")
        try FileManager.default.createDirectory(at: nestedOutput, withIntermediateDirectories: true)
        let outside = folder.appendingPathComponent("outside/outputs")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: connectedRoot.appendingPathComponent("outside-link"), withDestinationURL: outside.deletingLastPathComponent())
        var discovery = CodexDiscovery().discover(root: connectedRoot)
        try expect(discovery.folders.map(\.path) == [discoveredOutput.path], "discovery crossed depth, ignored folder, symlink or output boundary")
        try expect(CodexDiscovery().discover(root: discoveredOutput).folders.map(\.path) == [discoveredOutput.path], "direct output root missing")
        let newOutput = connectedRoot.appendingPathComponent("new/output")
        try FileManager.default.createDirectory(at: newOutput, withIntermediateDirectories: true)
        discovery = CodexDiscovery().discover(root: connectedRoot)
        try expect(discovery.folders.count == 2, "new output folder not discovered")
        try FileManager.default.removeItem(at: newOutput)
        try expect(CodexDiscovery().discover(root: connectedRoot).folders.count == 1, "deleted output folder retained")
        let rootLink = folder.appendingPathComponent("root-link")
        try FileManager.default.createSymbolicLink(at: rootLink, withDestinationURL: connectedRoot)
        try expect(CodexDiscovery().discover(root: rootLink).folders.isEmpty, "symbolic connected root accepted")
        try expect(CodexDiscovery.validationError(for: URL(fileURLWithPath: "/")) != nil, "whole filesystem root accepted")
        try expect(CodexDiscovery.validationError(for: FileManager.default.homeDirectoryForCurrentUser) != nil, "home root accepted")
        try expect(CodexDiscovery(maximumVisitedDirectories: 1).discover(root: connectedRoot).errors.count == 1, "directory cap not reported")
        try expect(CodexDiscovery(maximumOutputFolders: 1).discover(root: connectedRoot).folders.count == 1, "output cap failed")
        store.connectCodexRoot(connectedRoot)
        try expect(store.codexRoot?.path == connectedRoot.path && store.watchedFolders.contains { $0.path == discoveredOutput.path }, "store root connection failed")
        let reconnected = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
        try expect(reconnected.codexRoot?.path == connectedRoot.path, "connected root did not persist")
        let relocated = ArtifactStore(defaultFolder: extra, defaults: defaults, startMonitoring: false)
        try expect(relocated.codexRoot?.path == connectedRoot.path, "changing default output folder lost the connected root")
        let isolatedDemo = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false, ignoreSavedCodexRoot: true)
        try expect(isolatedDemo.codexRoot == nil && defaults.string(forKey: "OutputTray.codexRoot") == connectedRoot.path, "isolated demo loaded or erased the saved connected root")
        isolatedDemo.disconnectCodex()
        try expect(defaults.string(forKey: "OutputTray.codexRoot") == connectedRoot.path, "isolated demo disconnect erased normal preferences")
        reconnected.disconnectCodex()
        let legacyKey = "OutputTray.watchedFolders.\(primary.standardizedFileURL.path).codexRoot"
        defaults.set(connectedRoot.path, forKey: legacyKey)
        let migrated = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
        try expect(migrated.codexRoot?.path == connectedRoot.path && defaults.string(forKey: "OutputTray.codexRoot") == connectedRoot.path, "legacy connected root was not migrated")
        try expect(defaults.string(forKey: legacyKey) == nil, "migrated legacy key was not cleared")
        migrated.disconnectCodex()
        try expect(reconnected.codexRoot == nil && !reconnected.watchedFolders.contains { $0.path == discoveredOutput.path }, "disconnect retained discovery")
        try expect(ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false).codexRoot == nil, "disconnect not persisted")
        reconnected.connectCodexRoot(URL(fileURLWithPath: "/"))
        reconnected.refresh()
        try expect(reconnected.codexErrorMessage != nil && reconnected.errorMessage != nil, "refresh cleared connection selection error")
        reconnected.connectCodexRoot(connectedRoot)
        try expect(reconnected.codexErrorMessage == nil, "valid root selection did not clear error")
        reconnected.disconnectCodex()
        print("PASS connected-root discovery, new/deleted folders, depth and output boundaries, exclusions, symlink protection, caps, connection persistence and disconnect")
        let largeRoot = folder.appendingPathComponent("large-Codex")
        let dateFolder = largeRoot.appendingPathComponent("2026-10-09")
        var freshestOutput: URL?
        for number in 0..<20 {
            let task = dateFolder.appendingPathComponent(String(format: "task-%02d", number))
            let output = task.appendingPathComponent("outputs")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(number + 1))], ofItemAtPath: task.path)
            if number == 19 { freshestOutput = output }
        }
        let bounded = CodexDiscovery(maximumVisitedDirectories: 6).discover(root: largeRoot)
        try expect(bounded.folders.contains { $0.path == freshestOutput?.path }, "directory cap starved newest task output")
        try expect(bounded.folders.count < 20 && !bounded.errors.isEmpty, "bounded discovery falsely claimed full coverage")
        print("PASS newest-first depth traversal finds freshest output under a small directory budget and reports limited coverage")
        print("All store checks passed.")
    }
}
