import SwiftUI
import AppKit

/// Only the main workspace installs this. Settings keeps its original close behavior.
struct WorkspaceWindowCloseGuard: NSViewRepresentable {
    var shouldClose: () -> Bool
    var attached: (NSWindow) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(shouldClose: shouldClose, attached: attached) }
    func makeNSView(context: Context) -> Anchor {
        let view = Anchor()
        view.attach = { [weak coordinator = context.coordinator] in coordinator?.install($0) }
        return view
    }
    func updateNSView(_ view: Anchor, context: Context) {
        context.coordinator.shouldClose = shouldClose
        context.coordinator.install(view.window)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: Coordinator) { coordinator.uninstall() }

    final class Anchor: NSView {
        var attach: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); attach?(window) }
    }
    final class Coordinator: NSObject, NSWindowDelegate {
        var shouldClose: () -> Bool
        let attached: (NSWindow) -> Void
        weak var window: NSWindow?
        weak var previous: (any NSWindowDelegate)?
        init(shouldClose: @escaping () -> Bool, attached: @escaping (NSWindow) -> Void) {
            self.shouldClose = shouldClose; self.attached = attached
        }
        func install(_ target: NSWindow?) {
            guard let target, target.delegate !== self else { return }
            uninstall()
            window = target; previous = target.delegate; target.delegate = self
            attached(target)
        }
        func uninstall() {
            if let window, window.delegate === self { window.delegate = previous }
            window = nil; previous = nil
        }
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard shouldClose() else { return false }
            return previous?.windowShouldClose?(sender) ?? true
        }
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previous?.responds(to: selector) == true
        }
        override func forwardingTarget(for selector: Selector!) -> Any? {
            if previous?.responds(to: selector) == true { return previous }
            return super.forwardingTarget(for: selector)
        }
    }
}
