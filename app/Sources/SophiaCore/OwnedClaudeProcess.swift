import Foundation
import Darwin

/// Keeps cleanup alive after a session releases its engine. Only birth-identified
/// descendants of the exact launched process are eligible for a signal.
public final class OwnedClaudeProcess {
    struct Identity: Equatable {
        let pid: pid_t
        let started: UInt64
        let microseconds: UInt64
        let uid: uid_t
        static func read(_ pid: pid_t) -> Identity? {
            var info = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) == MemoryLayout.size(ofValue: info),
                  info.pbi_status != SZOMB else { return nil }
            return Identity(pid: pid, started: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec, uid: info.pbi_uid)
        }
        var alive: Bool { Self.read(pid) == self }
        func signal(_ value: Int32) { if alive { Darwin.kill(pid, value) } }
    }
    private static let queue = DispatchQueue(label: "Sophia.owned-Claude-processes")
    private static var live: [UUID: OwnedClaudeProcess] = [:]
    private static var waiters: [() -> Void] = []
    private static var terminating = false
    private let id = UUID()
    private let root: Identity?
    private var known: [pid_t: Identity] = [:]
    private var timer: DispatchSourceTimer?
    private var terminateAt: Date?
    private var killAt: Date?

    private init(_ process: Process) {
        root = Identity.read(process.processIdentifier)
        if let root { known[root.pid] = root }
        refresh()
        guard !known.isEmpty else { return }
        Self.live[id] = self
        let timer = DispatchSource.makeTimerSource(queue: Self.queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    /// Serialize the launch with the Quit gate: a queued readiness check cannot
    /// launch an unregistered child after the registry has already drained.
    public static func launch(_ process: Process) throws -> OwnedClaudeProcess {
        try queue.sync {
            guard !terminating else { throw CocoaError(.userCancelled) }
            try process.run()
            return OwnedClaudeProcess(process)
        }
    }

    private func refresh() {
        var pending = Array(known.values), visited: Set<pid_t> = []
        while let parent = pending.popLast() {
            guard visited.insert(parent.pid).inserted, parent.alive else { continue }
            // libproc returns a PID count; the buffer argument is a byte count.
            let capacity = max(16, Int(proc_listchildpids(parent.pid, nil, 0)) + 16)
            var children = [pid_t](repeating: 0, count: capacity)
            let count = children.withUnsafeMutableBytes { proc_listchildpids(parent.pid, $0.baseAddress, Int32($0.count)) }
            guard count > 0, parent.alive else { continue }
            for pid in children.prefix(min(Int(count), children.count)) where pid > 1 {
                guard let child = Identity.read(pid), child.uid == parent.uid else { continue }
                // Revalidate the edge as well as both process birth identities.
                var info = proc_bsdinfo()
                guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) == MemoryLayout.size(ofValue: info),
                      info.pbi_ppid == UInt32(parent.pid), Identity.read(pid) == child else { continue }
                known[pid] = child; pending.append(child)
            }
        }
    }

    public func stop(grace: TimeInterval = 3) {
        Self.queue.sync { self.beginStop(grace: grace); self.tick() }
    }
    private func beginStop(grace: TimeInterval) {
        refresh()
        let deadline = Date().addingTimeInterval(max(0, grace))
        terminateAt = min(terminateAt ?? deadline, deadline)
    }
    private func tick() {
        refresh()
        // A normally exiting root must not leave its already observed children behind.
        if root?.alive != true, terminateAt == nil { beginStop(grace: 0) }
        let now = Date()
        if let at = terminateAt, now >= at, killAt == nil {
            for identity in known.values { identity.signal(SIGTERM) }
            killAt = now.addingTimeInterval(0.2)
        }
        if let at = killAt, now >= at {
            for identity in known.values { identity.signal(SIGKILL) }
        }
        known = known.filter { $0.value.alive }
        if known.isEmpty {
            timer?.cancel(); timer = nil
            Self.live[id] = nil
            if Self.live.isEmpty {
                let callbacks = Self.waiters; Self.waiters = []
                for callback in callbacks { DispatchQueue.main.async(execute: callback) }
            }
        }
    }

    /// AppKit retains the main loop while graceful exit and escalation finish.
    public static func finishForApplicationTermination(_ completion: @escaping () -> Void) {
        queue.async {
            terminating = true
            for process in live.values { process.beginStop(grace: 3) }
            guard !live.isEmpty else { DispatchQueue.main.async(execute: completion); return }
            waiters.append(completion)
            // Bound the AppKit handoff even if the OS cannot reap a signalled process.
            queue.asyncAfter(deadline: .now() + 5) {
                for process in live.values {
                    process.refresh()
                    for identity in process.known.values { identity.signal(SIGKILL) }
                }
                let callbacks = waiters; waiters = []
                for callback in callbacks { DispatchQueue.main.async(execute: callback) }
            }
        }
    }
}
