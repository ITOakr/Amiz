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
    /// 作品の保存先。UI テスト中は専用のファイルに保存し、`--reset-store` で毎回空にする
    private let container = AmizApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            root
                // 数字・英字を丸みのある書体に（ui-spec 1章。日本語はヒラギノのまま）
                .fontDesign(.rounded)
        }
        // 作品の保存先（SwiftData）。React でいう Provider に近く、下の View から modelContext で使える
        .modelContainer(container)
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
                let container = try ModelContainer(for: Work.self, configurations: ModelConfiguration(url: url))
                // UI テスト用：編み図が読めない作品を1つ置く（AMIZ-68 の確認）
                if arguments.contains("--seed-broken-work") {
                    let work = Work(name: "壊れた作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
                    work.patternData = Data("not json".utf8)
                    container.mainContext.insert(work)
                    try? container.mainContext.save()
                }
                return container
            }
            return try ModelContainer(for: Work.self)
        } catch {
            fatalError("作品の保存先を開けませんでした: \(error)")
        }
    }
}
