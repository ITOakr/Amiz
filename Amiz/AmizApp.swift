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
            EditorView()
        }
    }
}
