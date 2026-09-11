import SwiftUI

/// Role: Job. Name plus mileage rate fused onto the blotter. Optional start miles set the chain head.
struct JobDraft: View {
    @ObservedObject var session: DaybookSession
    var focused: FocusState<InlineBlotter.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            Text("New project")
                .blotterText(.headline)
            TextField("Project name", text: $session.jobNameText)
                .blotterText(.body)
                .padding(.horizontal, BlotterFace.space(1))
                .frame(minHeight: BlotterFace.tap)
                .blotterCard()
                .focused(focused, equals: .jobName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Project name")
            TextField("Mileage rate", text: $session.jobRateText)
                .blotterText(.figure)
                .keyboardType(.decimalPad)
                .padding(.horizontal, BlotterFace.space(1))
                .frame(minHeight: BlotterFace.tap)
                .blotterCard()
                .focused(focused, equals: .jobRate)
                .accessibilityLabel("Mileage rate")
            TextField("Starting miles (optional)", text: $session.jobStartText)
                .blotterText(.figure)
                .keyboardType(.decimalPad)
                .padding(.horizontal, BlotterFace.space(1))
                .frame(minHeight: BlotterFace.tap)
                .blotterCard()
                .focused(focused, equals: .jobStart)
                .accessibilityLabel("Starting miles")
            Button {
                focused.wrappedValue = nil
                Task { await session.addJob() }
            } label: {
                Text("Add project")
                    .blotterText(.headline)
                    .foregroundStyle(BlotterInk.Palette.surface)
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .tint(BlotterInk.Palette.accent)
            .disabled(!session.canAddJob)
            .opacity(session.canAddJob ? 1 : 0.45)
            .accessibilityHint("Names the project and sets its mileage rate")
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .blotterCard()
    }
}
