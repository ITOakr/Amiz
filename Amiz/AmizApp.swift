//
//  AmizApp.swift
//  Amiz
//
//  Created by 伊藤彪 on 2026/09/19.
//

import SwiftUI
import SwiftData

@main
struct AmizApp: App {
    /// 作品の保存先。UI テスト中は専用のファイルに保存し、`--reset-store` で毎回空にする
    private let container = AmizApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            // 確認用の切り替え（xcrun simctl launch の SIMCTL_CHILD_AMIZ_SCREEN や Xcode のスキームの環境変数で指定する）。
            // 確認用の作品は保存しない
            switch ProcessInfo.processInfo.environment["AMIZ_SCREEN"] {
            case "symbols":
                NavigationStack { StitchSymbolCatalogView() }
            case "sample":
                NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.bearHead), title: "くまの頭") }
            case "motif":
                NavigationStack { EditorView(model: EditorModel(pattern: SamplePatterns.flowerMotif), title: "花のモチーフ") }
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
        // 作品の保存先（SwiftData）。React でいう Provider に近く、下の View から modelContext で使える
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let arguments = ProcessInfo.processInfo.arguments
        do {
            // ユニットテストのホストとして起動したときは、ファイルに書かない（テスト側が自分の保存先を作る）
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                return try ModelContainer(for: Work.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            }
            if arguments.contains("--ui-testing") {
                let url = URL.temporaryDirectory.appending(path: "amiz-uitest.store")
                if arguments.contains("--reset-store") {
                    for suffix in ["", "-shm", "-wal"] {
                        try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
                    }
                    // 設定（UserDefaults）も既定に戻す。前のテストで変えた設定が残らないように
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                }
                return try ModelContainer(for: Work.self, configurations: ModelConfiguration(url: url))
            }
            return try ModelContainer(for: Work.self)
        } catch {
            fatalError("作品の保存先を開けませんでした: \(error)")
        }
    }
}
