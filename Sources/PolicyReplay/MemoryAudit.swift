import Foundation

/// Flags lines in an agent's project memory (CLAUDE.md, notes, saved context)
/// that record a vendor refusal as if it were a project rule.
///
/// A refusal that lands in memory outlives the session that produced it: the
/// next session reads it back as an instruction, even after the vendor's rule
/// changes. Those lines belong in a quarantine list a human reviews, not in
/// the file every session loads.
public struct MemoryAudit: Sendable {
    static let refusalMarkers = [
        "server-side instruction", "refuse", "refused", "refusing",
        "not allowed to", "policy prohibits", "cannot help with",
    ]

    public init() {}

    public struct Flag: Hashable, Sendable {
        public let line: Int
        public let text: String
        public let marker: String
    }

    /// Returns flagged lines, 1-based, in file order.
    public func audit(_ memory: String) -> [Flag] {
        var flags: [Flag] = []
        for (index, raw) in memory.components(separatedBy: "\n").enumerated() {
            let text = raw.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let lower = text.lowercased()
            if let marker = Self.refusalMarkers.first(where: { SpecLint.containsWord($0, in: lower) }) {
                flags.append(Flag(line: index + 1, text: text, marker: marker))
            }
        }
        return flags
    }
}
