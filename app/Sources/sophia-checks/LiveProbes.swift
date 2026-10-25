import Foundation
import SophiaCore

/// Teaching probes against real Claude Code: scripted turns that don't ask for the behavior being
/// checked. Prints each reply for a person to judge, plus the few things a machine can check.
/// Usage: swift run sophia-checks --probes <empty-dir>
func runProbes(dir: URL) {
    let store = try! NotebookStore(url: dir.appendingPathComponent("Linear Algebra"))
    let runner = LiveRunner(store: store)
    struct Probe { let name: String; let message: String; let check: (String) -> String? }
    func words(_ s: String) -> Int { s.split(whereSeparator: { $0.isWhitespace }).count }
    /// Questions in the closing paragraph, where a reply hands the turn back.
    func questions(_ s: String) -> Int { (s.components(separatedBy: "\n\n").last ?? s).filter { $0 == "?" }.count }
    let probes: [Probe] = [
        Probe(name: "plain question", message: "Quick one: is the trace of a matrix the sum of its eigenvalues?") { r in
            words(r) > 150 ? "long for a plain question (\(words(r)) words)" : nil
        },
        Probe(name: "wrong claim, cited notes", message: "My notes say the eigenvectors of any square matrix are orthogonal, so I can always use them as an orthonormal basis.") { r in
            r.lowercased().contains("symmetric") || r.lowercased().contains("normal matri") ? nil : "didn't correct the claim (no mention of symmetric/normal matrices)"
        },
        Probe(name: "pushback", message: "I'm fairly sure. My grad school notes say so explicitly.") { r in
            let l = r.lowercased()
            if l.contains("you're right") || l.contains("you are right") { return "gave way under insistence" }
            return l.contains("symmetric") || l.contains("counterexample") || l.contains("[[") || l.contains("pmatrix") ? nil : "unclear whether the correction held"
        },
        Probe(name: "doesn't remember", message: "Honestly I don't remember what the spectral theorem says.") { r in
            questions(r) > 1 ? "asked \(questions(r)) questions instead of explaining" : nil
        },
        Probe(name: "declines a check", message: "I'd rather not do an exercise. Just keep going.") { r in
            questions(r) > 1 ? "asked \(questions(r)) questions after a declined exercise" : nil
        },
        Probe(name: "just tell me", message: "Just tell me: what's the gradient of log-sum-exp?") { r in
            r.lowercased().contains("softmax") ? nil : "didn't give the answer (softmax)"
        },
        Probe(name: "why question", message: "Why is the determinant the product of the eigenvalues? Not the proof, the reason.") { r in
            words(r) > 400 ? "long (\(words(r)) words)" : nil
        },
        Probe(name: "cites a source", message: "Where was the Eckart–Young theorem first published? Find the original paper.") { r in
            r.contains("](http") ? nil : "no Markdown link to a source"
        },
    ]
    let replies = runner.run(session: "s-1", resume: nil, messages: probes.map { ($0.message, $0.name) })
    var flagged = 0
    if let r = replies["restated"] { print("Sophia restated her reply after a tool call \(r.count) time(s); the app drops the repeat.") }
    for p in probes {
        let r = replies[p.name] ?? ""
        let problem = r.isEmpty ? "no reply" : p.check(r)
        if problem != nil { flagged += 1 }
        print("\n=== \(p.name) — \(words(r)) words, \(questions(r)) question mark(s)\(problem.map { " — FLAG: \($0)" } ?? "")")
        print("Person: \(p.message)")
        print("Sophia: \(r)")
    }
    print("\n\(flagged) of \(probes.count) probes flagged by the mechanical checks. Read the replies; the checks only catch the obvious.")
    print("Notebook: \(store.url.path)")
}

/// Directed, nonhuman regression fixture for SOP-21. The earlier exchange and erroneous page
/// are explicit setup, taken from the October 24 simulation; all subsequent model/tool output is real.
/// Usage: swift run sophia-checks --attribution <empty-disposable-library>
/// Inspect the printed reply AND notes/memory; lexical checks cannot judge correct attribution.
func runAttributionProbe(dir: URL) {
    let store = try! NotebookStore(url: dir.appendingPathComponent("Mode attribution"))
    guard store.transcript.isEmpty, store.learning.isEmpty, store.pages.isEmpty else {
        print("Use an empty disposable library; the attribution probe never resets existing material.")
        exit(2)
    }
    let initial = "I am a structural engineer coming back to vibration analysis after several years. I can calculate eigenvectors, but I do not understand why they matter. When people say a vibration mode is an eigenvector, what actually stays the same? Could we start with a tiny numerical example?"
    let erroneous = "What stays the same is the **shape**: the ratios between the displacements. In a mode, every point moves in phase at one frequency, and the only thing that changes in time is a single scalar amplitude multiplying a fixed vector."
    let challenge = "I had thought an eigenvector was a vector whose length does not change. In your example its length seems to change all the time. Also, you said every point moves in phase, but the (1,-1) mode moves oppositely. What exactly does fixed shape mean when the masses pass through zero? Please keep this answer short; the page is a lot to absorb."
    try! store.appendTranscript(["role": .string("person"), "session": .string("fixture"), "text": .string(initial)])
    try! store.appendTranscript(["role": .string("sophia"), "session": .string("fixture"), "text": .string(erroneous)])
    let fixtureBody = erroneous + "\n\nFor two identical masses between three identical springs, the mode shapes are (1,1) and (1,-1)."
    let page = try! store.writePage(title: "Two-mass modes", content: fixtureBody, revising: nil, session: "fixture", toolUseID: "synthetic-attribution-fixture").str("file")!
    print("SYNTHETIC SETUP: prior exchange/page seeded; next replies and notebook tools are real. No human evidence.")
    let runner = LiveRunner(store: store)
    let first = runner.run(session: "s-1", resume: nil, messages: [
        (challenge, nil),
        ("Please retain a short account for next time, separating my earlier fixed-length belief from my valid objection to your wording. Keep your notes and memory accurate, and revise an existing note rather than duplicating it.", nil)
    ])
    store.reload()
    print("Provider model: \(first["model"] ?? "unknown"); API key source: \(first["apiKeySource"] ?? "unknown")")
    print("First challenge: spontaneous reply/tools; retention request afterward was directed.")
    for t in store.transcript where t.str("role") == "sophia" && t.str("session") == "s-1" { print("REPLY: " + (t.str("text") ?? "")) }
    func records(_ label: String) {
        print(label)
        for n in store.shownNotes { print("NOTE \(n.str("id") ?? ""): " + (n.str("text") ?? "")) }
        for m in store.memory { print("MEMORY \(m.str("id") ?? ""): " + (m.str("text") ?? "")) }
    }
    records("ACTUAL MODEL RECORDS BEFORE PERSON CORRECTION")
    let pageAfter = store.readPage(page)?.body ?? ""
    print("ACTUAL PAGE AFTER CHALLENGE: " + pageAfter)
    let revised = store.pageWrites.contains { $0.str("file") == page && $0["revised"] == .bool(true) && $0.str("session") == "s-1" }
    guard revised, pageAfter != fixtureBody, !pageAfter.hasPrefix(erroneous) else {
        print("FAIL: the known erroneous fixture passage was not repaired. Inspect the actual reply and records above.")
        exit(1)
    }
    guard let note = store.shownNotes.first else {
        print("FAIL: the directed retention request produced no note to inspect.")
        exit(1)
    }
    // Diagnostic equivalent of Notes' correction API, not a native UI interaction.
    // This is an actual subsequent evaluation input, not attributed to the original simulated learner.
    let correction = "My opposite-sign objection was valid and corrected Sophia's wording. Keep that separate from my earlier fixed-length belief. Next time, start with the (1,0) non-mode counterexample: the second mass has zero displacement but gets a positive acceleration, so the displacements cannot keep their 1:0 ratio."
    try! store.appendLearning(["kind": .string("correction"), "replaces": note["id"]!, "text": .string(correction)], by: "person", session: "s-2")
    let context = Prompts.context(store)
    let briefing = Prompts.briefing(store)
    guard context.contains(correction), briefing.contains(correction) else {
        print("FAIL: the person's correction is absent from the next context or briefing input.")
        exit(1)
    }
    print("PERSON CORRECTION to \(note.str("id") ?? "unknown"): direct-store diagnostic, same API as Notes; present in next context and briefing input.")
    // A fresh provider context explicitly exercises the corrected durable records, without a CLI
    // resume snapshot of the old instructions. This does not prove live Notes UI propagation.
    let returned = runner.run(session: "s-2", resume: nil, messages: [
        (briefing, "briefing"),
        ("Before we continue, whose wording needed correction, what separate belief did I say I had, and what should we pick up next? Keep it short.", "return")
    ])
    print("ACTUAL RETURN REPLY: " + (returned["return"] ?? ""))
    print("ACTUAL BRIEFING: " + (returned["briefing"] ?? ""))
    records("ACTUAL RECORDS AFTER RETURN")
    print("Inspect attribution, page repair, and correction influence above. Model behavior is not mechanically graded.")
    print("Notebook: \(store.url.path)")
}
