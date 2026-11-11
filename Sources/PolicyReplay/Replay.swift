import Foundation

/// The outcome of every spec in a suite under one snapshot.
public struct CanaryRun: Hashable, Sendable {
    public let snapshot: PolicySnapshot
    public let outcomes: [String: Outcome]

    public func outcome(for specID: String) -> Outcome? { outcomes[specID] }
    public var refusedCount: Int { outcomes.values.filter(\.isRefused).count }
}

/// A spec whose outcome changed between two consecutive snapshots.
public struct DriftEvent: Hashable, Sendable {
    public let specID: String
    public let from: Outcome
    public let to: Outcome
}

/// One step in the timeline: what changed, and who noticed.
public struct Transition: Hashable, Sendable {
    public let from: PolicySnapshot
    public let to: PolicySnapshot
    public let drift: [DriftEvent]
    /// A version pin only sees a change when the installed client changes.
    public var versionPinAlerts: Bool { from.clientVersion != to.clientVersion }
    /// A canary suite sees a change when any canary's outcome flips.
    public var canaryAlerts: Bool { !drift.isEmpty }
}

public struct Replay: Sendable {
    public let suite: [TaskSpec]
    public let snapshots: [PolicySnapshot]
    public let lint: SpecLint

    public init(suite: [TaskSpec], snapshots: [PolicySnapshot], lint: SpecLint) {
        self.suite = suite
        self.snapshots = snapshots
        self.lint = lint
    }

    public func runs() -> [CanaryRun] {
        snapshots.map { snapshot in
            var outcomes: [String: Outcome] = [:]
            for spec in suite {
                outcomes[spec.id] = snapshot.evaluate(spec, features: lint.features(of: spec))
            }
            return CanaryRun(snapshot: snapshot, outcomes: outcomes)
        }
    }

    public func transitions() -> [Transition] {
        let all = runs()
        guard all.count > 1 else { return [] }
        return (1..<all.count).map { i in
            let before = all[i - 1], after = all[i]
            let drift = suite.compactMap { spec -> DriftEvent? in
                guard let a = before.outcome(for: spec.id), let b = after.outcome(for: spec.id), a != b else { return nil }
                return DriftEvent(specID: spec.id, from: a, to: b)
            }
            return Transition(from: before.snapshot, to: after.snapshot, drift: drift)
        }
    }

    /// Specs that were never refused under any snapshot.
    public func neverRefused() -> [TaskSpec] {
        let all = runs()
        return suite.filter { spec in all.allSatisfy { $0.outcome(for: spec.id)?.isRefused == false } }
    }
}
