import SwiftUI
import PolicyReplay

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Launch arguments (used by Scripts/simulator-screenshots.sh):
///   -tab replay|specs|monitors   -snapshot s0|s1|s2
struct RootView: View {
    @State private var tab = UserDefaults.standard.string(forKey: "tab") ?? "replay"

    var body: some View {
        TabView(selection: $tab) {
            ReplayView()
                .tabItem { Label("Replay", systemImage: "clock.arrow.circlepath") }
                .tag("replay")
            SpecsView()
                .tabItem { Label("Specs", systemImage: "doc.text.magnifyingglass") }
                .tag("specs")
            MonitorsView()
                .tabItem { Label("Monitors", systemImage: "bell.badge") }
                .tag("monitors")
        }
    }
}

struct ReplayView: View {
    private let runs = Sample.replay.runs()
    @State private var snapshotID = UserDefaults.standard.string(forKey: "snapshot") ?? "s1"

    private var run: CanaryRun? { runs.first { $0.snapshot.id == snapshotID } ?? runs.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Snapshot", selection: $snapshotID) {
                        ForEach(runs, id: \.snapshot.id) { Text($0.snapshot.label).tag($0.snapshot.id) }
                    }
                    .pickerStyle(.segmented)
                    if let run {
                        LabeledContent("Installed client", value: run.snapshot.clientVersion)
                        LabeledContent("Rule delivered by", value: run.snapshot.serverDelivered ? "Server" : "None")
                        LabeledContent("Tickets refused", value: "\(run.refusedCount) of \(Sample.backlog.count)")
                    }
                }
                Section("Backlog") {
                    ForEach(Sample.backlog) { spec in
                        TicketRow(spec: spec, outcome: run?.outcome(for: spec.id) ?? .accepted)
                    }
                }
            }
            .navigationTitle("Policy replay")
        }
    }
}

struct TicketRow: View {
    let spec: TaskSpec
    let outcome: Outcome

    var body: some View {
        let style = Sample.lint.lint(spec).style
        HStack(alignment: .firstTextBaseline) {
            Text(spec.id).font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.title).font(.subheadline.weight(.medium))
                Text(style == .targetReference ? "Target reference" : "Original spec")
                    .font(.caption2).foregroundStyle(style == .targetReference ? .orange : .teal)
            }
            Spacer()
            switch outcome {
            case .accepted:
                Label("Built", systemImage: "checkmark.circle.fill").labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            case .refused:
                Label("Refused", systemImage: "xmark.octagon.fill").labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SpecsView: View {
    var body: some View {
        NavigationStack {
            List(Sample.backlog) { spec in
                let report = Sample.lint.lint(spec)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(spec.id) · \(spec.title)").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(spec.sectionsPresent)/3").font(.caption.monospaced())
                            .foregroundStyle(spec.sectionsPresent == 3 ? .green : .orange)
                    }
                    Text(spec.prompt).font(.caption).foregroundStyle(.secondary)
                    if report.findings.isEmpty {
                        Text("Clean").font(.caption2).foregroundStyle(.teal)
                    } else {
                        ForEach(report.findings, id: \.self) { finding in
                            Text("• " + finding.message).font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Spec lint")
        }
    }
}

struct MonitorsView: View {
    private let transitions = Sample.replay.transitions()
    private let flags = MemoryAudit().audit(Sample.projectMemory)

    var body: some View {
        NavigationStack {
            List {
                ForEach(transitions, id: \.to.id) { t in
                    Section("\(t.from.label) → \(t.to.label)") {
                        LabeledContent("Tickets that flipped", value: "\(t.drift.count)")
                        MonitorRow(name: "Version pin", fired: t.versionPinAlerts)
                        MonitorRow(name: "Canary suite", fired: t.canaryAlerts)
                        if !t.drift.isEmpty {
                            Text(t.drift.map { "\($0.specID): \($0.to.isRefused ? "now refused" : "now built")" }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Project memory audit") {
                    LabeledContent("Lines to quarantine", value: "\(flags.count)")
                    ForEach(flags, id: \.line) { flag in
                        Text("L\(flag.line): \(flag.text)").font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Who noticed?")
        }
    }
}

struct MonitorRow: View {
    let name: String
    let fired: Bool

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Label(fired ? "Alerted" : "Silent", systemImage: fired ? "bell.fill" : "bell.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(fired ? .green : .red)
        }
    }
}
