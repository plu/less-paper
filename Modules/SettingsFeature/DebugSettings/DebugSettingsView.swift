#if DEBUG
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

// Deliberately unlocalized: this screen never ships. Every string here is English, on purpose, and
// none of it belongs in the string catalogue.
@ViewAction(for: DebugSettingsReducer.self)
public struct DebugSettingsView: View {

    public var body: some View {
        List {
            if let snapshot = store.snapshot {
                storageSection(snapshot)
                gateSection(snapshot)
                stateSection(snapshot)
            }
            actionsSection
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Debug")
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    public init(store: StoreOf<DebugSettingsReducer>) {
        self.store = store
    }

    // The first thing to check when the invitation will not appear. A missing app group entitlement
    // makes `UserDefaults(suiteName:)` return nil, the accessor falls back to `.standard`, and
    // everything keeps working except that nothing written to the group suite is ever read.
    @ViewBuilder
    private func storageSection(_ snapshot: TipInvitationDebug.Snapshot) -> some View {
        Section {
            row(
                "Storage",
                snapshot.isAppGroupStore ? "App group" : "Fell back to standard",
                isGood: snapshot.isAppGroupStore
            )
        } header: {
            Text("Where the gate is stored")
        } footer: {
            if !snapshot.isAppGroupStore {
                Text("The app group entitlement is not in effect, so the app and the share extension keep separate values.")
            }
        }
    }

    @ViewBuilder
    private func gateSection(_ snapshot: TipInvitationDebug.Snapshot) -> some View {
        Section {
            row(
                "Tenure",
                "\(snapshot.tenureDays.map(String.init) ?? "—") / \(snapshot.tenureDaysRequired) days",
                isGood: snapshot.hasEnoughTenure
            )
            row(
                "Active days",
                "\(snapshot.activeDays) / \(snapshot.activeDaysRequired)",
                isGood: snapshot.hasEnoughActiveDays
            )
            row(
                "Not answered yet",
                snapshot.isSettled ? "Answered" : "Not answered",
                isGood: !snapshot.isSettled
            )
            row(
                "Clear of review prompt",
                snapshot.daysSinceReviewPrompt
                    .map { "\($0) / \(snapshot.daysClearOfReviewPromptRequired) days" } ?? "Never asked",
                isGood: snapshot.isClearOfReviewPrompt
            )
            row(
                "Eligible now",
                snapshot.isEligible ? "Yes" : "No",
                isGood: snapshot.isEligible
            )
        } header: {
            Text("Tip invitation gate")
        } footer: {
            Text("\"Eligible now\" comes from the real gate, not from the four rows above it. If they disagree, the rows are wrong.")
        }
    }

    @ViewBuilder
    private func stateSection(_ snapshot: TipInvitationDebug.Snapshot) -> some View {
        Section {
            row("First active", snapshot.firstActiveAt.map(Self.formatter.string(from:)) ?? "—")
            row("Last counted day", snapshot.lastActiveDay.map(String.init) ?? "—")
            row("Review prompt", snapshot.reviewRequestedAt.map(Self.formatter.string(from:)) ?? "—")
        } header: {
            Text("Raw values")
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button("Make eligible") {
                send(.makeEligibleButtonTapped)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            Button("Clear the answered flag") {
                send(.clearAnsweredButtonTapped)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            Button("Reset to a fresh install", role: .destructive) {
                send(.resetButtonTapped)
            }
            .listRowBackground(Color.m3SurfaceContainer)
        } footer: {
            Text("Go back to the inbox afterwards - the list re-checks the gate when it appears, so no relaunch is needed.")
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String, isGood: Bool? = nil) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.m3OnSurface)
            Spacer()
            Text(value)
                .foregroundStyle(isGood == false ? Color.m3Error : Color.m3OnSurfaceVariant)
            if let isGood {
                Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGood ? Color.m3Primary : Color.m3Error)
            }
        }
        .listRowBackground(Color.m3SurfaceContainer)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    @Bindable
    public var store: StoreOf<DebugSettingsReducer>
}
#endif
