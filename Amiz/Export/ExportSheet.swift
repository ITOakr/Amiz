import SwiftUI
import CrochetCore

/// 書き出しシート（ui-spec 6-2、U18）。形式と含める内容を選び、iOS 標準の共有シートに渡す。
///
/// 共有シートは SwiftUI の `ShareLink` で開く。`ShareLink` は押した瞬間にファイルが要るので、
/// 設定が変わるたびに先に書き出しておく（数百ミリ秒）。React でいえば、設定を依存配列にした useEffect でファイルを作り直す形。
struct ExportSheet: View {
    let title: String
    let pattern: Pattern

    @Environment(\.dismiss) private var dismiss
    @State private var options = ExportOptions()
    /// 現在の設定で書き出したファイル。書き出し中・失敗時は nil
    @State private var exportedURL: URL?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("形式") {
                    Picker("形式", selection: $options.format) {
                        ForEach(ExportOptions.Format.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("export.format")
                }
                Section {
                    Toggle("図", isOn: $options.includesChart)
                    Toggle("目数表", isOn: $options.includesTable)
                    Toggle("凡例", isOn: $options.includesLegend)
                    // 糸リストはフェーズ9（色）で有効にする
                    Toggle("糸リスト", isOn: $options.includesYarns)
                        .disabled(true)
                } header: {
                    Text("含める内容")
                } footer: {
                    Text("糸リストは色に対応してから選べるようになります。")
                }
                Section {
                    shareButton
                } footer: {
                    Text(statusText)
                }
            }
            .navigationTitle("書き出し")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("export.close")
                }
            }
            // 設定が変わるたびに書き出し直す
            .task(id: options) { render() }
        }
    }

    private var document: ExportDocument {
        ExportDocument(title: title, pattern: pattern, options: options)
    }

    /// 書き出しボタン。押すと共有シートが開く（ui-spec 6-2）
    @ViewBuilder
    private var shareButton: some View {
        if let url = exportedURL {
            ShareLink(item: url, preview: SharePreview(url.lastPathComponent, image: Image(systemName: "doc.richtext"))) {
                Label("書き出し", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("export.share")
        } else {
            HStack {
                Spacer()
                if failed || document.pages.isEmpty {
                    Label("書き出し", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
                Spacer()
            }
        }
    }

    private var statusText: String {
        let pages = document.pages.count
        if pages == 0 { return "含める内容を1つ以上選んでください。" }
        if failed { return "書き出しに失敗しました。" }
        return options.format == .pdf ? "A4 の PDF、\(pages)ページ" : "A4 \(pages)ページぶんを縦に並べた画像"
    }

    /// 現在の設定でファイルを作る
    private func render() {
        exportedURL = nil
        failed = false
        let document = document
        guard !document.pages.isEmpty else { return }
        do {
            exportedURL = try ExportRenderer.export(document)
        } catch {
            failed = true
        }
    }
}

#Preview {
    ExportSheet(title: "くまの頭", pattern: SamplePatterns.bearHead)
}
