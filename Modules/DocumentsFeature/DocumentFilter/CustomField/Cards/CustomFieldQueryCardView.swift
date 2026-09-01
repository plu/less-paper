import ApiInterface
import Components
import DesignTokens
import IdentifiedCollections
import SwiftUI

// Recurses through itself for nested groups. It takes the sub-query as a value and the reducer's
// state read-only rather than a store, so the recursion is a plain value type and SwiftUI can size
// it; a `@ViewAction` store would have to be re-scoped at every level for no gain.
struct CustomFieldQueryCardView: View {

    let depth: Int

    let fields: IdentifiedArrayOf<CustomField>

    let onViewAction: (CustomFieldQueryCardsReducer.Action.View) -> Void

    let path: CustomFieldQuery.Path

    let query: CustomFieldQuery

    let state: CustomFieldQueryCardsReducer.State

    var body: some View {
        switch query {
        case let .atom(atom):
            atomRow(atom)
        case let .group(logicalOperator, children):
            card(logicalOperator: logicalOperator, children: children, isNegated: false)
        case let .negation(child):
            switch child {
            case let .group(logicalOperator, children):
                card(logicalOperator: logicalOperator, children: children, isNegated: true)
            default:
                atomRow(nil)
            }
        }
    }

    private var rail: Color {
        switch depth % 4 {
        case 0:
            .m3Primary
        case 1:
            .m3Secondary
        case 2:
            .m3Tertiary
        default:
            .m3Outline
        }
    }

    @ViewBuilder
    private func atomRow(_ atom: CustomFieldQuery.Atom?) -> some View {
        HStack(spacing: .x3) {
            Rectangle()
                .foregroundStyle(rail)
                .frame(width: .x1)

            Button {
                onViewAction(.rowTapped(path))
            } label: {
                Text(query.summary(fields: fields))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.m3OnSurface)

            Button {
                onViewAction(.negationToggled(path))
            } label: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(atom == nil ? Color.m3Primary : Color.m3Outline)
            }
            .accessibilityLabel(.customFieldQueryNot)

            Button {
                onViewAction(.deleteTapped(path))
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.m3Error)
            }
            .accessibilityLabel(.delete)
        }
        .padding(.vertical, .x2)
    }

    @ViewBuilder
    private func card(
        logicalOperator: CustomFieldQueryLogicalOperator,
        children: [CustomFieldQuery],
        isNegated: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: .x3) {
            cardHeader(logicalOperator: logicalOperator, isNegated: isNegated)

            ForEach(Array(children.enumerated()), id: \.offset) { offset, child in
                CustomFieldQueryCardView(
                    depth: depth + 1,
                    fields: fields,
                    onViewAction: onViewAction,
                    path: childPath(isNegated: isNegated) + [offset],
                    query: child,
                    state: state
                )
            }

            cardFooter(isNegated: isNegated)
        }
        .padding(.x3)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .foregroundStyle(depth.isMultiple(of: 2) ? Color.m3SurfaceBright : Color.m3SurfaceContainerLow)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .foregroundStyle(rail)
                .frame(width: .x1)
        }
    }

    // A negated group's children hang off the group, which is the negation's only child.
    private func childPath(isNegated: Bool) -> CustomFieldQuery.Path {
        isNegated ? path + [0] : path
    }

    @ViewBuilder
    private func cardHeader(logicalOperator: CustomFieldQueryLogicalOperator, isNegated: Bool) -> some View {
        HStack(spacing: .x3) {
            Picker("", selection: Binding(
                get: { logicalOperator },
                set: { onViewAction(.logicalOperatorTapped(childPath(isNegated: isNegated), $0)) }
            )) {
                Text(.all).tag(CustomFieldQueryLogicalOperator.and)
                Text(.any).tag(CustomFieldQueryLogicalOperator.or)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            Button {
                onViewAction(.negationToggled(path))
            } label: {
                Image(systemName: isNegated ? "exclamationmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(isNegated ? Color.m3Primary : Color.m3Outline)
            }
            .accessibilityLabel(.customFieldQueryNot)

            Spacer()

            if !path.isEmpty {
                Button {
                    onViewAction(.deleteTapped(path))
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.m3Error)
                }
                .accessibilityLabel(.delete)
            }
        }
    }

    @ViewBuilder
    private func cardFooter(isNegated: Bool) -> some View {
        let target = childPath(isNegated: isNegated)

        HStack(spacing: .x4) {
            Button {
                onViewAction(.addConditionTapped(target))
            } label: {
                HStack(spacing: .x2) {
                    Image(systemName: "plus.circle")
                    Text(.customFieldQueryAddCondition)
                }
            }
            .disabled(!state.canAddCondition(at: target))

            Spacer()

            Button {
                onViewAction(.addGroupTapped(target))
            } label: {
                HStack(spacing: .x2) {
                    Image(systemName: "folder.badge.plus")
                    Text(.customFieldQueryAddGroup)
                }
            }
            .disabled(!state.canAddGroup(at: target))
        }
        .font(.footnote)
    }
}
