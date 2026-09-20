import SwiftUI

/// 書き出し用のページを画面で確認するためのプレビュー（確認用。環境変数 AMIZ_SCREEN=export）
struct ExportPreviewView: View {
    let document: ExportDocument

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                let pages = document.pages
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    ExportPageView(document: document, page: page, pageNumber: index + 1, pageCount: pages.count)
                        .scaleEffect(0.6, anchor: .top)
                        .frame(width: ExportDocument.pageSize.width * 0.6, height: ExportDocument.pageSize.height * 0.6)
                        .border(Color.gray.opacity(0.4))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
