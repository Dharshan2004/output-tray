import SwiftUI
import AppKit
import QuickLookUI
import Combine

@main
@MainActor
enum OutputTrayApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = TrayAppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class TrayAppDelegate: NSObject, NSApplicationDelegate {
    private var store: ArtifactStore!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var inspector: NSWindow?
    private var countSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let identifier = Bundle.main.bundleIdentifier {
            for previous in NSRunningApplication.runningApplications(withBundleIdentifier: identifier) where previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previous.terminate()
            }
        }
        let folder: URL
        if let index = args.firstIndex(of: "--folder"), args.count > index + 1 {
            folder = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        } else {
            folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OutputTray/Outputs", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let index = args.firstIndex(of: "--drag-log"), args.count > index + 1 {
            FileDragView.diagnosticURL = URL(fileURLWithPath: args[index + 1])
        }
        store = ArtifactStore(defaultFolder: folder, ignoreSavedCodexRoot: args.contains("--demo"))
        if let index = args.firstIndex(of: "--codex-root"), args.count > index + 1 {
            store.connectCodexRoot(URL(fileURLWithPath: args[index + 1], isDirectory: true))
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: "Output Tray")
            button.imagePosition = .imageLeading
            button.toolTip = "Output Tray · files within reach"
            button.target = self
            button.action = #selector(toggleTray)
            button.setAccessibilityLabel("Output Tray")
        }
        countSubscription = store.$artifacts.sink { [weak self] artifacts in
            self?.statusItem.button?.title = artifacts.isEmpty ? "" : " \(artifacts.count)"
        }
        let controller = NSViewController()
        let host = NSHostingView(rootView: TrayView(store: store, onHeightChange: { [weak self] height in
            self?.popover.contentSize = NSSize(width: 390, height: height)
        }))
        host.sizingOptions = []
        controller.view = host
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 390, height: 400)
        popover.behavior = .transient
        popover.animates = false
        let menu = NSMenu()
        let applicationMenu = NSMenu()
        let show = NSMenuItem(title: "Show Output Tray", action: #selector(showTray), keyEquivalent: "o")
        show.keyEquivalentModifierMask = [.control, .option]
        show.target = self
        applicationMenu.addItem(show)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(NSMenuItem(title: "Quit Output Tray", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let root = NSMenuItem()
        root.submenu = applicationMenu
        menu.addItem(root)
        NSApp.mainMenu = menu
        if args.contains("--window") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Output Tray"
            let windowHost = NSHostingView(rootView: TrayView(store: store, onHeightChange: { [weak window] height in
                window?.setContentSize(NSSize(width: 390, height: height))
            }))
            windowHost.sizingOptions = []
            window.contentView = windowHost
            window.isReleasedWhenClosed = false
            window.center()
            inspector = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        if args.contains("--show-tray") { DispatchQueue.main.async { self.showTray() } }
    }

    @objc private func toggleTray() {
        if popover.isShown { popover.performClose(nil) } else { showTray() }
    }
    @objc private func showTray() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

struct TrayView: View {
    @ObservedObject var store: ArtifactStore
    @State private var foldersExpanded = false
    var onHeightChange: (CGFloat) -> Void = { _ in }
    private var preferredHeight: CGFloat {
        155 + (store.artifacts.isEmpty ? 235 : min(CGFloat(store.artifacts.count) * 105, 420)) + (foldersExpanded ? CGFloat(min(store.watchedFolders.count, 5)) * 23 + 92 : 0) + (store.errorMessage == nil ? 0 : 48)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "tray.full.fill").font(.system(size: 23)).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Output Tray").font(.system(size: 19, weight: .semibold))
                    Text("Your files. Within reach.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.artifacts.count)").font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(8).background(.primary.opacity(0.06), in: Circle())
            }.padding(20)
            Divider()
            HStack(spacing: 6) {
                Circle().fill(store.errorMessage == nil ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(store.errorMessage == nil ? "Watching \(store.watchedFolders.count) folder\(store.watchedFolders.count == 1 ? "" : "s")" : "Folder needs attention")
                Spacer()
                if store.codexRoot == nil {
                    Button("Connect Codex", action: connectCodex).buttonStyle(.plain).foregroundStyle(.orange)
                } else {
                    Text("Codex folders").foregroundStyle(.secondary)
                }
                Button { foldersExpanded.toggle() } label: { Image(systemName: "folder.badge.gearshape") }.buttonStyle(.plain).help("Manage watched folders")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 12)
            if foldersExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let root = store.codexRoot {
                        HStack {
                            Text("Connected: \(root.lastPathComponent)")
                            Spacer()
                            Button("Disconnect") { store.disconnectCodex() }.buttonStyle(.plain)
                        }
                    }
                    ForEach(Array(store.watchedFolders.prefix(5)), id: \.path) { folder in
                        HStack {
                            Text(folder.path).lineLimit(1).truncationMode(.middle).help(folder.path)
                            Spacer()
                            Button { NSWorkspace.shared.open(folder) } label: { Image(systemName: "arrow.up.forward") }.buttonStyle(.plain)
                            if store.watchedFolders.count > 1 && !store.isAutomaticallyDiscovered(folder) && folder.path != store.watchedFolders.first?.path {
                                Button { store.removeFolder(folder) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Button("Add folder…", action: addFolder)
                        Spacer()
                        Button(store.codexRoot == nil ? "Connect Codex…" : "Change Codex folder…", action: connectCodex)
                    }
                }.font(.system(size: 11)).padding(12).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 16).padding(.bottom, 10)
            }
            if let error = store.errorMessage {
                Text(error).font(.system(size: 11)).lineLimit(3).help(error).foregroundStyle(.orange).padding(.horizontal, 20).padding(.bottom, 8)
            }
            if store.artifacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus").font(.system(size: 38, weight: .light)).foregroundStyle(.secondary)
                    Text("Ready for your next output").font(.system(size: 15, weight: .medium))
                    Text("Save a file to the watched folder.\nIt will appear here automatically.").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Open output folder") { if let folder = store.watchedFolders.first { NSWorkspace.shared.open(folder) } }
                }.frame(maxWidth: .infinity).padding(.vertical, 38)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(store.artifacts.prefix(30))) { artifact in ArtifactRow(artifact: artifact) }
                    }.padding(.horizontal, 12).padding(.bottom, 12)
                }.frame(height: min(CGFloat(store.artifacts.count) * 105, 420))
            }
            Divider()
            HStack {
                Text("Drag the grip to take a file anywhere").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Refresh") { store.refresh() }
                    Button("Open output folder") { if let folder = store.watchedFolders.first { NSWorkspace.shared.open(folder) } }
                    Divider()
                    Button("Quit Output Tray") { NSApplication.shared.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
            }.padding(.horizontal, 16).padding(.vertical, 12)
        }.frame(width: 390, height: preferredHeight, alignment: .top).background(Color(nsColor: .windowBackgroundColor))
            .onAppear { onHeightChange(preferredHeight) }
            .onChange(of: preferredHeight) { _, height in onHeightChange(height) }

    }
    private func connectCodex() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Codex", isDirectory: true)
        panel.message = "Choose your local Codex folder. Output Tray will find its output folders automatically."
        panel.prompt = "Connect Codex"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let root = panel.url { store.connectCodexRoot(root) }
    }
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch folder"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let folder = panel.url { store.addFolder(folder) }
    }
}

extension TrayArtifact {
    var provenanceLabel: String {
        let folder = url.deletingLastPathComponent()
        if ["outputs", "output"].contains(folder.lastPathComponent.lowercased()) {
            return folder.deletingLastPathComponent().lastPathComponent + " / " + folder.lastPathComponent
        }
        return folder.lastPathComponent
    }
}

struct ArtifactRow: View {
    let artifact: TrayArtifact
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: artifact.url.path)).resizable().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 5) {
                Text(artifact.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).help(artifact.url.lastPathComponent)
                Text([artifact.project, artifact.task].compactMap { $0 }.joined(separator: " · ").isEmpty ? artifact.provenanceLabel : [artifact.project, artifact.task].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 10) {
                    Button("Preview") { PreviewController.shared.show(artifact.url) }
                    Button("Open") { NSWorkspace.shared.open(artifact.url) }
                    Button { NSWorkspace.shared.activateFileViewerSelecting([artifact.url]) } label: { Image(systemName: "folder") }.help("Show in Finder")
                    Text(artifact.kind).fontWeight(.medium)
                    Text(ByteCountFormatter.string(fromByteCount: artifact.byteCount, countStyle: .file)).foregroundStyle(.tertiary)
                }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            FileDragHandle(url: artifact.url).frame(width: 22, height: 48).help("Drag this file to Finder or another app")
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
final class PreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = PreviewController()
    private var url: NSURL?
    func show(_ file: URL) {
        url = file as NSURL
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { url }
}

struct FileDragHandle: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> FileDragView { FileDragView(url: url) }
    func updateNSView(_ view: FileDragView, context: Context) { view.url = url }
}
@MainActor
final class FileDragView: NSView, NSDraggingSource {
    static var diagnosticURL: URL?
    var url: URL
    init(url: URL) {
        self.url = url
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Drag file \(url.lastPathComponent)")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.tertiaryLabelColor.setFill()
        for x in [8.0, 13.0] { for y in [18.0, 24.0, 30.0] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill() } }
    }
    override func mouseDown(with event: NSEvent) { }
    override func mouseDragged(with event: NSEvent) {
        recordDrag("started", operation: nil, point: nil)
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(NSRect(x: 0, y: 0, width: 40, height: 40), contents: NSWorkspace.shared.icon(forFile: url.path))
        beginDraggingSession(with: [dragging], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        recordDrag("ended", operation: operation.rawValue, point: screenPoint)
    }
    private func recordDrag(_ phase: String, operation: UInt?, point: NSPoint?) {
        guard let destination = Self.diagnosticURL else { return }
        let line = "\(phase) file=\(url.lastPathComponent) operation=\(operation.map(String.init) ?? "-") x=\(point?.x ?? 0) y=\(point?.y ?? 0)\n"
        if !FileManager.default.fileExists(atPath: destination.path) { FileManager.default.createFile(atPath: destination.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: destination) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        }
    }
}
