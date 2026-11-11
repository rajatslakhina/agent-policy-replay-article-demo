import Foundation

/// What a ticket asks the coding agent to build.
public enum Domain: String, Sendable, CaseIterable {
    case game
    case appFeature
}

/// A ticket as a team hands it to a coding agent.
///
/// `prompt` is the one-line ask people actually type. The three sections are
/// the parts of a spec that make an ask independent of any existing product:
/// what it does, what it must respect, and how we know it is done.
public struct TaskSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let domain: Domain
    public let prompt: String
    public let behaviour: [String]
    public let constraints: [String]
    public let acceptance: [String]

    public init(id: String, title: String, domain: Domain, prompt: String,
                behaviour: [String] = [], constraints: [String] = [], acceptance: [String] = []) {
        self.id = id
        self.title = title
        self.domain = domain
        self.prompt = prompt
        self.behaviour = behaviour
        self.constraints = constraints
        self.acceptance = acceptance
    }

    /// Number of the three spec sections that are filled in (0...3).
    public var sectionsPresent: Int {
        [behaviour, constraints, acceptance].filter { !$0.isEmpty }.count
    }
}

/// Facts read off a spec's prompt. Everything downstream (the lint, the policy
/// model) works from these, so the same reading feeds both.
public struct SpecFeatures: Hashable, Sendable {
    /// The existing product the prompt points at, if any.
    public let namedTarget: String?
    /// The phrase that makes the ask a copy rather than a reference ("clone", "same as", ...).
    public let recreationPhrase: String?
    /// Identity assets the prompt asks to carry over (characters, art, levels, ...).
    public let identityAssets: [String]
    /// True when the prompt limits the borrowing to mechanics.
    public let mechanicsOnly: Bool

    /// The prompt asks to reproduce a specific named product.
    public var asksForRecreation: Bool { namedTarget != nil && recreationPhrase != nil }
}
