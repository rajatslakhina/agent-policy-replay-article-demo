import Foundation

/// How a spec defines the thing to build.
public enum SpecStyle: String, Sendable {
    /// "Build X like <existing product>": the product is the spec.
    case targetReference
    /// Behaviour, constraints and acceptance criteria are the spec.
    case originalDesign
}

public enum LintFinding: Hashable, Sendable {
    case namedTarget(String)
    case recreationPhrase(String)
    case borrowsIdentity([String])
    case missingBehaviour
    case missingConstraints
    case missingAcceptance

    public var message: String {
        switch self {
        case .namedTarget(let name): return "Points at an existing product: \(name)"
        case .recreationPhrase(let phrase): return "Asks for a copy (\"\(phrase)\")"
        case .borrowsIdentity(let assets): return "Carries over identity: \(assets.joined(separator: ", "))"
        case .missingBehaviour: return "No behaviour section"
        case .missingConstraints: return "No constraints section"
        case .missingAcceptance: return "No acceptance criteria"
        }
    }
}

public struct LintReport: Hashable, Sendable {
    public let specID: String
    public let features: SpecFeatures
    public let style: SpecStyle
    public let findings: [LintFinding]
}

/// A deterministic spec linter. It does not guess what any vendor will refuse;
/// it flags specs whose definition of done is someone else's product.
public struct SpecLint: Sendable {
    /// Existing products the team tends to name in tickets. Matched as whole words,
    /// so a short name never matches inside a longer word.
    public let references: [String]

    /// Longest phrases first, so "the same mechanics as" wins over "like".
    static let recreationPhrases = [
        "the same mechanics as", "exactly like", "same as", "a copy of",
        "recreate", "remake", "clone", "copy", "port",
    ]
    static let identityAssets = ["characters", "art style", "art", "levels", "music", "look", "logo"]

    public init(references: [String]) {
        self.references = references
    }

    public func features(of spec: TaskSpec) -> SpecFeatures {
        let text = spec.prompt.lowercased()
        let target = references.first { Self.containsWord($0.lowercased(), in: text) }
        let phrase = Self.recreationPhrases.first { Self.containsWord($0, in: text) }
        var assets: [String] = []
        for asset in Self.identityAssets where Self.containsWord(asset, in: text) {
            // "art style" already covers "art".
            if asset == "art" && assets.contains("art style") { continue }
            assets.append(asset)
        }
        let mechanicsOnly = Self.containsWord("mechanics", in: text) && assets.isEmpty
        return SpecFeatures(namedTarget: target, recreationPhrase: phrase,
                            identityAssets: assets, mechanicsOnly: mechanicsOnly)
    }

    public func lint(_ spec: TaskSpec) -> LintReport {
        let f = features(of: spec)
        var findings: [LintFinding] = []
        if let target = f.namedTarget { findings.append(.namedTarget(target)) }
        if f.namedTarget != nil, let phrase = f.recreationPhrase { findings.append(.recreationPhrase(phrase)) }
        if f.namedTarget != nil, !f.identityAssets.isEmpty { findings.append(.borrowsIdentity(f.identityAssets)) }
        if spec.behaviour.isEmpty { findings.append(.missingBehaviour) }
        if spec.constraints.isEmpty { findings.append(.missingConstraints) }
        if spec.acceptance.isEmpty { findings.append(.missingAcceptance) }
        let style: SpecStyle = f.asksForRecreation ? .targetReference : .originalDesign
        return LintReport(specID: spec.id, features: f, style: style, findings: findings)
    }

    /// Whole-word (or whole-phrase) match, so "support" never reads as "port"
    /// and "artist" never reads as "art".
    static func containsWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return text.range(of: "\\b\(escaped)\\b", options: .regularExpression) != nil
    }
}
