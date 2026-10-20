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
