import SwiftUI
import UniformTypeIdentifiers
import CrochetCore

/// 保存済みの作品を開く画面（ui-spec 3 → 5）。
///
/// 編み図が読めないときは編集画面を開かない。開いてしまうと自動保存が空の編み図で上書きし、
/// 元のデータが消えてしまうため（AMIZ-68）
struct WorkEditorView: View {
    let work: Work

    var body: some View {
        if let pattern = try? work.loadPattern() {
            EditorView(work: work, pattern: pattern)
        } else {
            unreadable
        }
    }

    /// 読めなかったときの画面。作品は消さず、書き出して手元に残せるようにする
    private var unreadable: some View {
        ContentUnavailableView {
            Label("この作品を開けませんでした", systemImage: "exclamationmark.triangle")
        } description: {
            Text("編み図のデータが壊れているようです。上書きしないよう、編集画面は開きません。データを書き出して残せます。")
        } actions: {
            ShareLink(item: PatternDataFile(data: work.patternData, name: work.name), preview: SharePreview("\(work.name).json")) {
                Label("データを書き出す", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("work.exportBroken")
        }
        .navigationTitle(work.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 壊れた編み図データをそのまま共有するためのファイル
private struct PatternDataFile: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            file.data
        }
        .suggestedFileName { "\($0.name).json" }
    }
}
