//
//  AmizApp.swift
//  Amiz
//
//  Created by 伊藤彪 on 2026/09/19.
//

import SwiftUI

@main
struct AmizApp: App {
    var body: some Scene {
        WindowGroup {
            // フェーズ2の仮の形：起動すると直接、わの作り目・輪編みの新しい作品の編集画面が開く。
            // 作品一覧・新規作成・保存はフェーズ4で作る
            // 確認用の切り替え（xcrun simctl launch の SIMCTL_CHILD_AMIZ_SCREEN や Xcode のスキームの環境変数で指定する）
            NavigationStack {
                switch ProcessInfo.processInfo.environment["AMIZ_SCREEN"] {
                case "symbols":
                    StitchSymbolCatalogView()
                case "sample":
                    EditorView(model: EditorModel(pattern: SamplePatterns.bearHead), title: "くまの頭")
                case "motif":
                    EditorView(model: EditorModel(pattern: SamplePatterns.flowerMotif), title: "花のモチーフ")
                case "big":
                    // 性能確認：40段・約4900目
                    EditorView(model: EditorModel(pattern: SamplePatterns.largeDisc(rows: 40)), title: "大きな円")
                default:
                    EditorView()
                }
            }
        }
    }
}
