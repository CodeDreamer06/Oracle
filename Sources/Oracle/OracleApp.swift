import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct OracleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Oracle", systemImage: "waveform.circle.fill") {
            Button("Activate Oracle") {
                appDelegate.togglePanel()
            }
            .keyboardShortcut(.return, modifiers: [])
            
            Divider()
            
            Button("Settings...") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(.init(","), modifiers: .command)
            
            Divider()
            
            Button("Quit Oracle") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut(.init("q"), modifiers: .command)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    var windowController: AssistantWindowController?
    var settingsWindowController: NSWindowController?
    var hotkeyManager: HotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        appState = state
        hotkeyManager = HotkeyManager()
        
        setupHotkey()
        setupWindow()
    }
    
    func setupHotkey() {
        hotkeyManager?.register { [weak self] in
            self?.togglePanel()
        }
    }
    
    func setupWindow() {
        guard let state = appState else { return }
        windowController = AssistantWindowController(appState: state)
    }
    
    func togglePanel() {
        guard let state = appState else { return }
        state.togglePanel()
        if state.isPanelVisible {
            windowController?.showPanel()
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                await state.startListening()
            }
        } else {
            windowController?.hidePanel()
        }
    }
    
    func showSettings() {
        guard let state = appState else { return }
        
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Oracle Settings"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView().environment(state))
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// MARK: - Assistant Window Controller

@MainActor
class AssistantWindowController: NSWindowController, NSTouchBarDelegate {
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        
        let hostingView = NSHostingView(rootView: AssistantPanel().environment(appState))
        panel.contentView = hostingView
        
        super.init(window: panel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showPanel() {
        guard let window = window else { return }
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenRect.midX - windowSize.width / 2
            let y = screenRect.midY - windowSize.height / 2 + 80
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    func hidePanel() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                window.orderOut(nil)
            }
        }
    }
    
    // MARK: - Touch Bar
    
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.oracleButton]
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == .oracleButton else { return nil }
        
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton()
        button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Oracle")
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(touchBarTapped)
        item.view = button
        return item
    }
    
    @objc func touchBarTapped() {
        appState.togglePanel()
        if appState.isPanelVisible {
            showPanel()
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                await appState.startListening()
            }
        } else {
            hidePanel()
        }
    }
}

extension NSTouchBarItem.Identifier {
    static let oracleButton = NSTouchBarItem.Identifier("com.abhinav.oracle.touchbar")
}
