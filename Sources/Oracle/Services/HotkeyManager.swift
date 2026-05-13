import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleOracle = Self("toggleOracle", default: .init(.space, modifiers: [.command, .shift]))
}

@MainActor
final class HotkeyManager {
    private var action: (() -> Void)?
    
    func register(action: @escaping () -> Void) {
        self.action = action
        KeyboardShortcuts.onKeyUp(for: .toggleOracle) { [weak self] in
            self?.action?()
        }
    }
    
    func unregister() {
        action = nil
    }
}
