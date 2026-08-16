import Components
import SwiftUI

struct DocumentBulkEditTitlePreviewRow: View {

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            Text(preview.oldTitle)
                .strikethrough()
                .foregroundStyle(Color.m3Outline)
            Text(preview.newTitle)
                .fontWeight(.medium)
                .foregroundStyle(Color.m3OnSurface)
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .foregroundStyle(Color.m3SurfaceContainer)
        )
    }

    let preview: DocumentBulkEditTitleReducer.Preview
}
