import SwiftUI
import AppKit

/// Development aid: renders the main window offscreen to PNGs, one per place (contents, goals, notes, About you, first page), then quits.
/// SOPHIA_SNAPSHOT=<out dir> SOPHIA_LIBRARY=<fixture library> build/Sophia.app/Contents/MacOS/Sophia
/// Optional: SOPHIA_SNAPSHOT_SIZE=1440x900, SOPHIA_SNAPSHOT_APPEARANCE=light|dark, SOPHIA_SNAPSHOT_SECTION,
/// SOPHIA_SNAPSHOT_EDIT (a section title, "(opening)", or "(page)" to show open in the editor). No conversation process is started.
enum Snapshot {
    static var outDir: URL? { ProcessInfo.processInfo.environment["SOPHIA_SNAPSHOT"].map { URL(fileURLWithPath: $0) } }

    static func run(model: AppModel) {
        guard let out = outDir else { return }
        let env = ProcessInfo.processInfo.environment
        switch env["SOPHIA_SNAPSHOT_APPEARANCE"] {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }
        let size = (env["SOPHIA_SNAPSHOT_SIZE"] ?? "1440x900").split(separator: "x").compactMap { Double($0) }
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let window = NSApp.windows.first(where: { $0.contentView != nil }) else { exit(1) }
            if size.count == 2 { window.setContentSize(NSSize(width: size[0], height: size[1])) }
            guard let s = model.open else {
                // The actual empty-Library root, under the same controlled appearance and size.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    save(window, to: out.appendingPathComponent("empty.png"))
                    exit(0)
                }
                return
            }
            // The conversation scrolled to its end before the resize reflowed it.
            NotificationCenter.default.post(name: .scrollConversationToEnd, object: nil)
            var places: [(String, NotebookSession.Place)] = [("contents", .contents), ("goals", .goals), ("notes", .notes), ("about", .about)]
            if let p = s.store.contentPages.first { places.append(("page", .page(p.file))) }
            func shoot(_ i: Int) {
                guard i < places.count else { exit(0) }
                // SOPHIA_SNAPSHOT_SECTION: open the page scrolled to that section, as a followed link does.
                s.place = places[i].1
                if case .page = places[i].1 { s.pendingSection = ProcessInfo.processInfo.environment["SOPHIA_SNAPSHOT_SECTION"] }
                // SOPHIA_SNAPSHOT_EDIT: open that section ("(opening)", "(page)", or a section title) in the editor.
                if case .page(let file) = places[i].1, let want = ProcessInfo.processInfo.environment["SOPHIA_SNAPSHOT_EDIT"],
                   let r = s.store.editRanges(of: file).first(where: { $0.key == want || $0.section == want }) {
                    s.beginEdit(file: file, key: r.key)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    save(window, to: out.appendingPathComponent(places[i].0 + ".png"))
                    shoot(i + 1)
                }
            }
            shoot(0)
        }
    }

    private static func save(_ window: NSWindow, to url: URL) {
        if let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
            let rep = NSBitmapImageRep(cgImage: cg)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}
