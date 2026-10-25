#if DEBUG
import AppKit

/// Opt-in development driver. Operates only AppKit/accessibility UI, never the model or stores.
/// Commands and screenshots stay inside a disposable directory selected at launch.
enum UXHarness {
    static var timer: Timer?
    static var root: URL?
    static var elements: [NSObject] = []

    static func get(_ object: NSObject, _ name: String) -> Any? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }

    static func boolean(_ object: NSObject, _ name: String) -> Bool {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector), let imp = object.method(for: selector) else { return false }
        typealias Function = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(imp, to: Function.self)(object, selector)
    }

    static func startIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SOPHIA_UX_HARNESS"], let library = env["SOPHIA_LIBRARY"],
              library.hasPrefix(path + "/"), env["SOPHIA_SNAPSHOT"] == nil else { return }
        root = URL(fileURLWithPath: path)
        if NSApp.responds(to: NSSelectorFromString("accessibilitySetValue:forAttribute:")) {
            NSApp.perform(NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: true, with: "AXEnhancedUserInterface")
        }
        try? FileManager.default.createDirectory(at: root!.appendingPathComponent("commands"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root!.appendingPathComponent("results"), withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in poll() }
    }

    static func tree() -> [[String: Any]] {
        elements = []
        var rows: [[String: Any]] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: Any, _ depth: Int) {
            guard depth < 40, let a = object as? NSObject,
                  seen.insert(ObjectIdentifier(a)).inserted else { return }
            let id = elements.count
            elements.append(a)
            let f = (a as? any NSAccessibilityProtocol)?.accessibilityFrame() ?? .zero
            var row: [String: Any] = ["id": id, "depth": depth,
                "class": String(describing: type(of: a)),
                "role": get(a, "accessibilityRole") as? String ?? "", "enabled": boolean(a, "isAccessibilityEnabled"),
                "frame": [f.origin.x, f.origin.y, f.width, f.height]]
            if let label = get(a, "accessibilityLabel") as? String { row["label"] = label }
            if let title = get(a, "accessibilityTitle") as? String { row["title"] = title }
            if let help = get(a, "accessibilityHelp") as? String { row["help"] = help }
            if let value = get(a, "accessibilityValue") { row["value"] = String(describing: value) }
            rows.append(row)
            for child in (get(a, "accessibilityChildren") as? [Any] ?? []) { visit(child, depth + 1) }
            if let view = object as? NSView { for child in view.subviews { visit(child, depth + 1) } }
            if let window = object as? NSWindow, let view = window.contentView { visit(view, depth + 1) }
        }
        for window in NSApp.windows where window.isVisible { visit(window, 0) }
        return rows
    }

    static func poll() {
        guard let root, let files = try? FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("commands"), includingPropertiesForKeys: nil),
              let file = files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first,
              let data = try? Data(contentsOf: file), let cmd = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try? FileManager.default.removeItem(at: file)
        var result: [String: Any] = [:]
        let action = cmd["action"] as? String ?? "inspect"
        if elements.isEmpty { _ = tree() }
        let target = (cmd["id"] as? Int).flatMap { elements.indices.contains($0) ? elements[$0] : nil }
        switch action {
        case "inspect": break
        case "menu":
            func menuItems(_ menu: NSMenu, _ path: String) -> [[String: Any]] {
                menu.items.flatMap { item -> [[String: Any]] in
                    let name = path + item.title
                    if let sub = item.submenu { return menuItems(sub, name + " > ") }
                    return [["title": name, "key": item.keyEquivalent, "enabled": item.isEnabled]]
                }
            }
            result["menu"] = NSApp.mainMenu.map { menuItems($0, "") } ?? []
        case "press":
            result["performed"] = target.map { boolean($0, "accessibilityPerformPress") } ?? false
        case "set":
            if let target, let text = cmd["text"] as? String {
                let view = (target as? NSCell)?.controlView ?? target as? NSView
                if let field = view as? NSTextField, let window = field.window {
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(field)
                    if let editor = field.currentEditor() as? NSTextView {
                        editor.selectAll(nil)
                        editor.insertText(text, replacementRange: editor.selectedRange())
                        result["performed"] = true
                    }
                } else if let target = target as? NSTextView {
                    target.window?.makeFirstResponder(target)
                    target.selectAll(nil)
                    target.insertText(text, replacementRange: target.selectedRange())
                    result["performed"] = true
                } else { result["error"] = "UI target is not an editable native text control" }
            } else { result["error"] = "Missing UI element or text" }
        case "key":
            guard let base = NSApp.windows.first(where: { $0.isVisible }) else { break }
            let window = base.attachedSheet ?? base
            var flags: NSEvent.ModifierFlags = []
            for m in cmd["modifiers"] as? [String] ?? [] {
                switch m { case "command": flags.insert(.command); case "shift": flags.insert(.shift); case "option": flags.insert(.option); default: break }
            }
            let chars = cmd["text"] as? String ?? "\r"
            let code = UInt16(cmd["code"] as? Int ?? 36)
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) {
                if flags.contains(.command), NSApp.mainMenu?.performKeyEquivalent(with: event) == true { result["performed"] = true }
                else { window.sendEvent(event); result["performed"] = true }
            }
        case "type":
            if let base = NSApp.windows.first(where: { $0.isVisible }), let text = cmd["text"] as? String {
                let window = base.attachedSheet ?? base
                if let input = window.firstResponder as? NSTextInputClient {
                    input.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                    result["performed"] = true
                } else { result["error"] = "Focus a text editor first" }
            }
        case "click", "hover":
            if let base = NSApp.windows.first(where: { $0.isVisible }), let x = cmd["x"] as? Double, let y = cmd["y"] as? Double {
                let window = base.attachedSheet ?? base
                let point = NSPoint(x: x, y: window.frame.height - y)
                window.makeKeyAndOrderFront(nil)
                let kinds: [NSEvent.EventType] = action == "hover" ? [.mouseMoved] : [.leftMouseDown, .leftMouseUp]
                for kind in kinds {
                    if let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                     windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) { NSApp.postEvent(event, atStart: false) }
                }
                result["performed"] = true
            }
        case "scroll":
            if let scroll = target as? NSScrollView, let dy = cmd["dy"] as? Double {
                let clip = scroll.contentView
                var bounds = clip.bounds
                bounds.origin.y += (scroll.documentView?.isFlipped == false ? -dy : dy)
                clip.scroll(to: clip.constrainBoundsRect(bounds).origin)
                scroll.reflectScrolledClipView(clip)
                result["performed"] = true
            } else { result["error"] = "Choose a native AXScrollArea and provide dy in points" }
        case "resize":
            if let w = NSApp.windows.first(where: { $0.isVisible }), let width = cmd["width"] as? Double, let height = cmd["height"] as? Double {
                w.setContentSize(NSSize(width: width, height: height)); result["performed"] = true
            }
        default: result["error"] = "Unknown UI action"
        }
        // Allow SwiftUI and WebKit to render after the actual UI action.
        timer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result["tree"] = tree()
            result["at"] = ISO8601DateFormatter().string(from: Date())
            if let base = NSApp.windows.first(where: { $0.isVisible }),
               let w = Optional(base.attachedSheet ?? base),
               let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                let shot = root.appendingPathComponent("results").appendingPathComponent(file.deletingPathExtension().lastPathComponent + ".png")
                try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: shot)
                result["screenshot"] = shot.path
            }
            let output = root.appendingPathComponent("results").appendingPathComponent(file.lastPathComponent)
            if let bytes = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) { try? bytes.write(to: output, options: .atomic) }
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in poll() }
        }
    }
}
#endif
