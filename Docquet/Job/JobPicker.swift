import SwiftUI

/// Role: Job. Full project choice on the fused blotter. Compact uses a named menu; wide uses a two-column chip grid. Creating a Job stays on this screen.
struct JobPicker: View {
    @ObservedObject var session: DaybookSession
    var compact: Bool

    var body: some View {
        if compact {
            projectMenu
        } else {
            chipGrid
        }
    }

    private var projectMenu: some View {
        Menu {
            ForEach(session.daybook.jobs) { job in
                Button {
                    session.selectJob(job.id)
                } label: {
                    Text(job.name)
                    Text(BlotterFigures.rate(job.rate.perMile))
                }
            }
            Divider()
            Button(session.showJobDraft ? "Close new project" : "New project") {
                session.showJobDraft.toggle()
            }
        } label: {
            HStack(spacing: BlotterFace.space(1)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.selectedJob?.name ?? "Choose a project")
                        .blotterText(.headline)
                        .lineLimit(1)
                    if let job = session.selectedJob {
                        Text(BlotterFigures.rate(job.rate.perMile))
                            .blotterText(.caption)
                            .foregroundStyle(BlotterInk.Palette.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, BlotterFace.space(1))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .contentShape(Rectangle())
            .blotterChip(selected: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(menuLabel)
        .accessibilityHint("Choose a project or start a new one")
        .accessibilityAddTraits(.isButton)
    }

    private var chipGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: BlotterFace.space(1)),
                GridItem(.flexible(), spacing: BlotterFace.space(1)),
            ],
            spacing: BlotterFace.space(1)
        ) {
            ForEach(session.daybook.jobs) { job in
                Button {
                    session.selectJob(job.id)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(job.name)
                            .blotterText(.callout)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(BlotterFigures.rate(job.rate.perMile))
                            .blotterText(.caption)
                            .foregroundStyle(BlotterInk.Palette.muted)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, BlotterFace.space(1))
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
                    .contentShape(Rectangle())
                    .blotterChip(selected: session.jobID == job.id)
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("\(job.name), \(BlotterFigures.rate(job.rate.perMile))")
                .accessibilityAddTraits(session.jobID == job.id ? .isSelected : [])
            }
            Button {
                session.showJobDraft.toggle()
            } label: {
                Text(session.showJobDraft ? "Close" : "New project")
                    .blotterText(.callout)
                    .lineLimit(1)
                    .padding(.horizontal, BlotterFace.space(1))
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
                    .blotterChip(selected: session.showJobDraft)
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel(session.showJobDraft ? "Close new project" : "New project")
        }
    }

    private var menuLabel: String {
        if let job = session.selectedJob {
            return "\(job.name), \(BlotterFigures.rate(job.rate.perMile))"
        }
        return "Choose a project"
    }
}
