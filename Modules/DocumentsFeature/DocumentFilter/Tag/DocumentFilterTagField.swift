import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI
import TagsFeature

struct DocumentFilterTagField: View {

    enum Value {
        case exclude(Tag)
        case include(Tag)
    }

    let rule: DocumentFilterTagRule

    let selection: [Value]

    init(
        rule: DocumentFilterTagRule,
        selection: DocumentFilterTagSelection
    ) {
        self.rule = rule
        switch rule {
        case .all:
            self.selection = (selection.all.include.map { .include($0) } + selection.all.exclude.map { .exclude($0) }).sorted()
        case .any:
            self.selection = selection.any.map { .include($0) }.sorted()
        case .assigned, .notAssigned:
            self.selection = []
        }
    }

    var body: some View {
        Field(.tag) {
            HStack(spacing: .x3) {
                Image(systemName: "tag.circle")
                    .font(.title2)
                    .foregroundStyle(Color.m3Primary)
                switch rule {
                case .all, .any:
                    if selection.isEmpty {
                        Text(.any).capsule()
                        Spacer()
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: .x3) {
                                ForEach(selection) { value in
                                    Text(value.tag.description)
                                        .capsule(
                                            backgroundColor: Color(hex: value.tag.color),
                                            foregroundColor: Color(hex: value.tag.textColor)
                                        )
                                        .strikethrough(value.striketrhough)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                case .assigned:
                    Text(.assigned)
                        .capsule()
                    Spacer()
                case .notAssigned:
                    Text(.notAssigned)
                        .capsule()
                    Spacer()
                }
            }
        }
    }
}

extension DocumentFilterTagField.Value: Comparable, Identifiable {
    var id: Tag.Id {
        tag.id
    }

    var striketrhough: Bool {
        switch self {
        case .exclude:
            true
        case .include:
            false
        }
    }

    var tag: Tag {
        switch self {
        case let .exclude(tag),
             let .include(tag):
            tag
        }
    }

    static func < (lhs: DocumentFilterTagField.Value, rhs: DocumentFilterTagField.Value) -> Bool {
        lhs.tag.description < rhs.tag.description
    }
}

extension DocumentFilterTagField {
    static func testValue(
        rule: DocumentFilterTagRule = .all,
        selection: DocumentFilterTagSelection = .testValue()
    ) -> Self {
        .init(
            rule: rule,
            selection: selection
        )
    }
}
