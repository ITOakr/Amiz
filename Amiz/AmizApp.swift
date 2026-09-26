//
//  AmizApp.swift
//  Amiz
//
//  Created by 伊藤彪 on 2026/09/19.
//

import SwiftUI
import SwiftData
import CrochetCore

@main
struct AmizApp: App {
    /// 作品の保存先（`WorkStore` が開く。開けなければ退避して作り直す。AMIZ-69）
    private let store = WorkStore.open()

    var body: some Scene {
        WindowGroup {
            root
                // 保存先を開けなかったときの説明（開けていれば何も出ない）
                .environment(\.storeWarning, store.warning)
                // 数字・英字を丸みのある書体に（ui-spec 1章。日本語はヒラギノのまま）
                .fontDesign(.rounded)
        }
        // 作品の保存先（SwiftData）。React でいう Provider に近く、下の View から modelContext で使える
        .modelContainer(store.container)
    }

    /// 起動する画面
    @ViewBuilder
    private var root: some View {
        // 確認用の切り替え（xcrun simctl launch の SIMCTL_CHILD_AMIZ_SCREEN や Xcode のスキームの環境変数で指定する）。
        // 確認用の作品は保存しない
        switch ProcessInfo.processInfo.environment["AMIZ_SCREEN"] {
        case "symbols":
            NavigationStack { StitchSymbolCatalogView() }
        case "sample":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.bearHead), title: "くまの頭") }
        case "colored":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.bearHeadColored), title: "くまの頭（色付き）") }
        case "motif":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.flowerMotif), title: "花のモチーフ") }
        case "chainring":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.chainRingMotif), title: "鎖の輪のモチーフ") }
        case "blanket":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.blanketEdge), title: "ブランケットの縁") }
        case "rabbit":
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.rabbitBody), title: "うさぎの胴体") }
        case "big":
            // 性能確認：40段・約4900目
            NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.largeDisc(rows: 40)), title: "大きな円") }
        case "export":
            // 書き出し用のページの確認
            ExportPreviewView(document: ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions()))
        default:
            HomeView()
        }
    }

}
