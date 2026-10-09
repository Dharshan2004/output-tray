import XCTest
@testable import OutputTray

final class ArtifactScannerTests: XCTestCase {
    private func withFolder(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder)
    }

    func testStableCreationUpdateAndDeletion() throws {
        try withFolder { folder in
            var scanner = ArtifactScanner()
            let file = folder.appendingPathComponent("result.md")
            try Data("first".utf8).write(to: file)
            XCTAssertTrue(scanner.scan(folders: [folder]).artifacts.isEmpty)
            XCTAssertEqual(scanner.scan(folders: [folder]).artifacts.first?.byteCount, 5)
            try Data("replacement".utf8).write(to: file)
            XCTAssertEqual(scanner.scan(folders: [folder]).artifacts.first?.byteCount, 5)
            XCTAssertEqual(scanner.scan(folders: [folder]).artifacts.first?.byteCount, 11)
            try FileManager.default.removeItem(at: file)
            XCTAssertTrue(scanner.scan(folders: [folder]).artifacts.isEmpty)
        }
    }

    func testManifestLabelsAndUnsafePaths() throws {
        try withFolder { folder in
            try Data("report".utf8).write(to: folder.appendingPathComponent("report.pdf"))
            let manifest = #"{"artifacts":[{"path":"report.pdf","title":"Demo report","project":"Output Tray","task":"Demo","createdAt":"2026-10-09T10:00:00Z"},{"path":"../report.pdf","title":"Escape"},{"path":"/report.pdf","title":"Absolute"}]}"#
            try Data(manifest.utf8).write(to: folder.appendingPathComponent(".output-tray.json"))
            var scanner = ArtifactScanner()
            _ = scanner.scan(folders: [folder])
            let result = scanner.scan(folders: [folder, folder])
            XCTAssertEqual(result.artifacts.count, 1)
            XCTAssertEqual(result.artifacts[0].title, "Demo report")
            XCTAssertEqual(result.artifacts[0].project, "Output Tray")
            XCTAssertEqual(result.artifacts[0].task, "Demo")
            XCTAssertEqual(result.artifacts[0].kind, "PDF")
        }
    }

    func testHiddenTemporaryNestedAndSymlinkFilesAreIgnored() throws {
        try withFolder { folder in
            for name in [".hidden", "draft.tmp", "~$sheet.xlsx", "real.png"] {
                try Data("x".utf8).write(to: folder.appendingPathComponent(name))
            }
            let child = folder.appendingPathComponent("nested")
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: child.appendingPathComponent("nested.md"))
            try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link.png"),
                withDestinationURL: folder.appendingPathComponent("real.png"))
            var scanner = ArtifactScanner()
            _ = scanner.scan(folders: [folder])
            XCTAssertEqual(scanner.scan(folders: [folder]).artifacts.map(\.title), ["real.png"])
        }
    }

    func testInvalidManifestDoesNotHideRealFiles() throws {
        try withFolder { folder in
            try Data("hello".utf8).write(to: folder.appendingPathComponent("notes.md"))
            try Data("invalid".utf8).write(to: folder.appendingPathComponent(".output-tray.json"))
            var scanner = ArtifactScanner()
            _ = scanner.scan(folders: [folder])
            let result = scanner.scan(folders: [folder])
            XCTAssertEqual(result.artifacts.first?.title, "notes.md")
            XCTAssertEqual(result.errors.count, 1)
        }
    }

    @MainActor
    func testFolderPersistenceKeepsDefaultFirstAndCannotRemoveDefault() throws {
        try withFolder { folder in
            let suite = "OutputTrayTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let extra = folder.appendingPathComponent("aaa-extra")
            let primary = folder.appendingPathComponent("zzz-default")
            try FileManager.default.createDirectory(at: primary, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: extra, withIntermediateDirectories: true)
            let store = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
            store.addFolder(extra)
            store.addFolder(extra)
            store.removeFolder(primary)
            XCTAssertEqual(store.watchedFolders.map(\.path), [primary.path, extra.path])
            let restored = ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false)
            XCTAssertEqual(restored.watchedFolders.map(\.path), [primary.path, extra.path])
            restored.removeFolder(extra)
            XCTAssertEqual(ArtifactStore(defaultFolder: primary, defaults: defaults, startMonitoring: false).watchedFolders.map(\.path), [primary.path])
        }
    }
}
