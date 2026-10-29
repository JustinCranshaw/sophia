#if DEBUG
import AppKit

/// Opt-in development driver. Operates only AppKit/accessibility UI, never the model or stores.
/// Commands and screenshots stay inside a disposable directory selected at launch.
enum UXHarness {
    static var timer: Timer?
    static var menuObserver: NSObjectProtocol?
    static var root: URL?
    static var elements: [NSObject] = []
    static var elementWindows: [NSWindow] = []

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
        menuObserver = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { notification in
            guard let menu = notification.object as? NSMenu else { return }
            let capture = Timer(timeInterval: 0.2, repeats: false) { _ in captureTrackedMenu(menu) }
            RunLoop.main.add(capture, forMode: .eventTracking)
        }

        if NSApp.responds(to: NSSelectorFromString("accessibilitySetValue:forAttribute:")) {
            NSApp.perform(NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: true, with: "AXEnhancedUserInterface")
        }
        try? FileManager.default.createDirectory(at: root!.appendingPathComponent("commands"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root!.appendingPathComponent("results"), withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in poll() }
    }

    /// Menu tracking has its own run-loop mode and separate windows. Capture only this
    /// process's visible windows; never screenshot the desktop or another application's UI.
    static func captureTrackedMenu(_ menu: NSMenu) {
        guard let root else { return }
        let stem = "menu-" + UUID().uuidString
        var record: [String: Any] = ["title": menu.title, "items": menu.items.map { ["title": $0.title, "enabled": $0.isEnabled, "separator": $0.isSeparatorItem] as [String: Any] }]
        // AppKit exposes its tracked popup as an owned window. Capturing that exact ID
        // avoids a desktop capture and includes the real native menu rendering.
        if let popup = NSApp.windows.first(where: { $0.isVisible && String(describing: type(of: $0)) == "NSPopupMenuWindow" }),
           let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(popup.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
           let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            let shot = root.appendingPathComponent("results/" + stem + ".png")
            try? data.write(to: shot); record["screenshot"] = shot.path
        }
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: root.appendingPathComponent("results/" + stem + ".json"))
        }
    }

    static func tree() -> [[String: Any]] {
        elements = []; elementWindows = []
        var rows: [[String: Any]] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: Any, _ depth: Int, _ window: NSWindow) {
            guard depth < 40, let a = object as? NSObject,
                  seen.insert(ObjectIdentifier(a)).inserted else { return }
            let owner = (a as? NSWindow) ?? (a as? NSView)?.window ?? window
            let id = elements.count
            elements.append(a); elementWindows.append(owner)
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
            for child in (get(a, "accessibilityChildren") as? [Any] ?? []) { visit(child, depth + 1, owner) }
            if let view = object as? NSView { for child in view.subviews { visit(child, depth + 1, owner) } }
            if let window = object as? NSWindow, let view = window.contentView { visit(view, depth + 1, owner) }
        }
        for window in NSApp.windows where window.isVisible { visit(window, 0, window) }
        return rows
    }

    static var activeWindow: NSWindow? {
        // A popover can be in front while the main window remains key. Never capture another app.
        let popover = NSApp.windows.first(where: { $0.isVisible && $0.accessibilityRole() == .popover })
        let base = popover ?? NSApp.keyWindow ?? NSApp.orderedWindows.first(where: { $0.isVisible })
        return base?.attachedSheet ?? base
    }

    static func poll() {
        guard let root, let files = try? FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("commands"), includingPropertiesForKeys: nil),
              let file = files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first,
              file.isFileURL else { return }
        let data = try? Data(contentsOf: file)
        try? FileManager.default.removeItem(at: file)
        guard let data, let cmd = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var result: [String: Any] = [:]
        let action = cmd["action"] as? String ?? "inspect"
        if elements.isEmpty { _ = tree() }
        let target = (cmd["id"] as? Int).flatMap { elements.indices.contains($0) ? elements[$0] : nil }
        let targetWindow = (cmd["id"] as? Int).flatMap { elementWindows.indices.contains($0) ? elementWindows[$0] : nil }
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
        case "show-menu":
            result["performed"] = target.map { boolean($0, "accessibilityPerformShowMenu") } ?? false
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
            guard let window = activeWindow else { break }
            var flags: NSEvent.ModifierFlags = []
            for m in cmd["modifiers"] as? [String] ?? [] {
                switch m { case "command": flags.insert(.command); case "shift": flags.insert(.shift); case "option": flags.insert(.option); default: break }
            }
            let chars = cmd["text"] as? String ?? "\r"
            let code = UInt16(cmd["code"] as? Int ?? 36)
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) {
                if flags.contains(.command), NSApp.mainMenu?.performKeyEquivalent(with: event) == true { result["performed"] = true }
                else { NSApp.postEvent(event, atStart: false); result["performed"] = true }
            }
        case "type":
            if let window = activeWindow, let text = cmd["text"] as? String {
                if let input = window.firstResponder as? NSTextInputClient {
                    input.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                    result["performed"] = true
                } else { result["error"] = "Focus a text editor first" }
            }
        case "click", "hover":
            if let window = activeWindow {
                let point: NSPoint
                if cmd["id"] != nil {
                    guard let target, let accessible = target as? any NSAccessibilityProtocol else {
                        result["error"] = "The UI element is missing; inspect again."; break
                    }
                    guard targetWindow === window else {
                        result["error"] = "The UI element is outside the active window."; break
                    }
                    let frame = accessible.accessibilityFrame()
                    let role = get(target, "accessibilityRole") as? String
                    let label = get(target, "accessibilityLabel") as? String
                    let type = String(describing: Swift.type(of: target))
                    _ = tree()
                    // Native segments recreate their AX wrapper on each read. Require one exact
                    // visible match in the same window, never reinterpret an old numeric index.
                    let matches = elements.enumerated().filter { index, value in
                        elementWindows[index] === window && String(describing: Swift.type(of: value)) == type
                            && (get(value, "accessibilityRole") as? String) == role
                            && (get(value, "accessibilityLabel") as? String) == label
                            && (value as? any NSAccessibilityProtocol)?.accessibilityFrame() == frame
                    }
                    guard matches.count == 1 else {
                        result["error"] = "The UI element is stale or ambiguous; inspect again."; break
                    }
                    let center = NSPoint(x: frame.midX, y: frame.midY)
                    guard !frame.isEmpty, window.frame.contains(center) else {
                        result["error"] = "The UI element is outside the active window."; break
                    }
                    point = window.convertPoint(fromScreen: center)
                } else if let x = cmd["x"] as? Double, let y = cmd["y"] as? Double {
                    point = NSPoint(x: x, y: window.frame.height - y)
                } else { result["error"] = "Supply a current element ID or click coordinates."; break }
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
            if let w = activeWindow, let width = cmd["width"] as? Double, let height = cmd["height"] as? Double {
                w.setContentSize(NSSize(width: width, height: height)); result["performed"] = true
            }
        default: result["error"] = "Unknown UI action"
        }
        // Allow SwiftUI and WebKit to render after the actual UI action.
        timer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            result["tree"] = tree()
            result["at"] = ISO8601DateFormatter().string(from: Date())
            if let w = activeWindow,
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
