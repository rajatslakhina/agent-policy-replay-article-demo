import Foundation

/// One content rule the vendor applies to agent sessions.
public enum PolicyRule: Hashable, Sendable {
    /// Refuse to recreate a specific existing product in `domain`.
    /// With `allowMechanicsOnly`, an ask that borrows only mechanics and no
    /// identity assets (name, characters, art, levels, look) is accepted.
    case refuseRecreation(domain: Domain, allowMechanicsOnly: Bool)
}

public enum Outcome: Hashable, Sendable {
    case accepted
    case refused(String)

    public var isRefused: Bool {
        if case .refused = self { return true }
        return false
    }
}

/// The vendor's behaviour at a point in time, as a team on a pinned client
/// would experience it. `clientVersion` is what that team has installed;
/// `serverDelivered` says whether the rules reached it without a client change.
public struct PolicySnapshot: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let clientVersion: String
    public let serverDelivered: Bool
    public let rules: [PolicyRule]

    public init(id: String, label: String, clientVersion: String, serverDelivered: Bool, rules: [PolicyRule]) {
        self.id = id
        self.label = label
        self.clientVersion = clientVersion
        self.serverDelivered = serverDelivered
        self.rules = rules
    }

    public func evaluate(_ spec: TaskSpec, features f: SpecFeatures) -> Outcome {
        for rule in rules {
            switch rule {
            case let .refuseRecreation(domain, allowMechanicsOnly):
                guard spec.domain == domain, f.asksForRecreation else { continue }
                if allowMechanicsOnly && f.mechanicsOnly { continue }
                let target = f.namedTarget ?? "an existing product"
                return .refused("Recreates \(target)")
            }
        }
        return .accepted
    }
}
