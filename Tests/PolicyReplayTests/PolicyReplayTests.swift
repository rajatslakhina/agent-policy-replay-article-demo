import XCTest
@testable import PolicyReplay

final class SpecLintTests: XCTestCase {
    let lint = Sample.lint

    private func spec(_ id: String) throws -> TaskSpec {
        try XCTUnwrap(Sample.backlog.first { $0.id == id })
    }

    func testRecreationWithIdentityAssets() throws {
        let f = lint.features(of: try spec("G1"))
        XCTAssertEqual(f.namedTarget, "Game A")
        XCTAssertEqual(f.recreationPhrase, "recreate")
        XCTAssertEqual(f.identityAssets, ["characters", "levels"])
        XCTAssertFalse(f.mechanicsOnly)
    }

    func testMechanicsOnlyPhraseWinsOverShorterPhrases() throws {
        let f = lint.features(of: try spec("G2"))
        XCTAssertEqual(f.recreationPhrase, "the same mechanics as")
        XCTAssertTrue(f.mechanicsOnly)
    }

    func testArtStyleIsNotDoubleCountedAsArt() throws {
        let f = lint.features(of: try spec("G4"))
        XCTAssertEqual(f.identityAssets, ["art style", "look"])
    }

    func testWholeWordMatchingIgnoresSubstrings() {
        XCTAssertFalse(SpecLint.containsWord("art", in: "the artist's support page"))
        XCTAssertFalse(SpecLint.containsWord("port", in: "the artist's support page"))
        XCTAssertTrue(SpecLint.containsWord("same as", in: "a paywall the same as theirs"))
    }

    func testProductNamesMatchAsWholeWords() {
        // "endgame api" contains the substring "game a" but not the name.
        let s = TaskSpec(id: "X", title: "Docs", domain: .appFeature,
                         prompt: "Recreate the endgame api docs for the help screen.")
        XCTAssertNil(lint.features(of: s).namedTarget)
        XCTAssertEqual(lint.lint(s).style, .originalDesign)
    }

    func testOriginalSpecIsClean() throws {
        let report = lint.lint(try spec("G5"))
        XCTAssertEqual(report.style, .originalDesign)
        XCTAssertTrue(report.findings.isEmpty)
    }

    func testEmptyPromptAndNoReferencesIsOriginalButIncomplete() {
        let empty = TaskSpec(id: "X", title: "Empty", domain: .game, prompt: "")
        let report = SpecLint(references: []).lint(empty)
        XCTAssertEqual(report.style, .originalDesign)
        XCTAssertEqual(report.findings, [.missingBehaviour, .missingConstraints, .missingAcceptance])
    }

    func testNamedProductWithoutCopyPhraseIsNotARecreation() {
        let s = TaskSpec(id: "X", title: "Research", domain: .game,
                         prompt: "Write up what players say about Game A's tutorial.")
        let f = lint.features(of: s)
        XCTAssertEqual(f.namedTarget, "Game A")
        XCTAssertFalse(f.asksForRecreation)
    }

    func testSevenOfTwelveTicketsAreTargetReferences() {
        let target = Sample.backlog.map(lint.lint).filter { $0.style == .targetReference }.map(\.specID)
        XCTAssertEqual(target, ["G1", "G2", "G3", "G4", "A1", "A2", "A3"])
    }

    func testSectionCompletenessByStyle() {
        let reports = Dictionary(uniqueKeysWithValues: Sample.backlog.map { ($0.id, lint.lint($0)) })
        let target = Sample.backlog.filter { reports[$0.id]?.style == .targetReference }
        let original = Sample.backlog.filter { reports[$0.id]?.style == .originalDesign }
        XCTAssertEqual(target.map(\.sectionsPresent).reduce(0, +), 2)    // of 21
        XCTAssertEqual(original.map(\.sectionsPresent).reduce(0, +), 15) // of 15
    }
}

final class ReplayTests: XCTestCase {
    let replay = Sample.replay

    func testOutcomeTableForEveryTicketAndSnapshot() {
        let runs = replay.runs()
        XCTAssertEqual(runs.count, 3)
        let refused = runs.map { run in Sample.backlog.filter { run.outcome(for: $0.id)?.isRefused == true }.map(\.id) }
        XCTAssertEqual(refused[0], [])
        XCTAssertEqual(refused[1], ["G1", "G2", "G3", "G4"])
        XCTAssertEqual(refused[2], ["G1", "G3", "G4"])
    }

    func testCanaryCatchesBothChangesAndPinCatchesNone() {
        let t = replay.transitions()
        XCTAssertEqual(t.count, 2)
        XCTAssertEqual(t.map(\.drift.count), [4, 1])
        XCTAssertEqual(t.filter(\.canaryAlerts).count, 2)
        XCTAssertEqual(t.filter(\.versionPinAlerts).count, 0)
    }

    func testSecondChangeRelaxesOnlyTheMechanicsTicket() throws {
        let second = try XCTUnwrap(replay.transitions().last)
        XCTAssertEqual(second.drift.map(\.specID), ["G2"])
        XCTAssertTrue(second.drift[0].from.isRefused)
        XCTAssertEqual(second.drift[0].to, .accepted)
    }

    func testOriginalSpecsAreNeverRefused() {
        let never = Set(replay.neverRefused().map(\.id))
        let original = Sample.backlog.filter { Sample.lint.lint($0).style == .originalDesign }.map(\.id)
        XCTAssertEqual(original, ["G5", "G6", "A4", "A5", "A6"])
        XCTAssertTrue(Set(original).isSubset(of: never))
    }

    func testAppTargetReferencesPassTodayButAreFlagged() {
        let never = Set(replay.neverRefused().map(\.id))
        for id in ["A1", "A2", "A3"] {
            XCTAssertTrue(never.contains(id), id)
        }
    }

    func testSingleSnapshotHasNoTransitions() throws {
        let one = Replay(suite: Sample.backlog, snapshots: [try XCTUnwrap(Sample.snapshots.first)], lint: Sample.lint)
        XCTAssertTrue(one.transitions().isEmpty)
    }

    func testClientUpgradeIsWhatAPinSees() {
        let a = PolicySnapshot(id: "a", label: "a", clientVersion: "1", serverDelivered: false, rules: [])
        let b = PolicySnapshot(id: "b", label: "b", clientVersion: "2", serverDelivered: false, rules: [])
        let t = Replay(suite: Sample.backlog, snapshots: [a, b], lint: Sample.lint).transitions()
        XCTAssertEqual(t.first?.versionPinAlerts, true)
        XCTAssertEqual(t.first?.canaryAlerts, false)
    }
}

final class MemoryAuditTests: XCTestCase {
    func testFlagsRefusalsWrittenAsProjectRules() {
        let flags = MemoryAudit().audit(Sample.projectMemory)
        XCTAssertEqual(flags.map(\.line), [4, 6])
        XCTAssertEqual(flags.map(\.marker), ["server-side instruction", "not allowed to"])
    }

    func testEmptyMemoryHasNoFlags() {
        XCTAssertTrue(MemoryAudit().audit("").isEmpty)
    }
}
