//
//  ContentView.swift
//  Amiz
//
//  Created by 伊藤彪 on 2026/09/19.
//

import SwiftUI
import CrochetCore

// テンプレートの仮画面。CrochetCore パッケージがアプリから使えることの確認を兼ねている。
// フェーズ2で編集画面に置き換える。
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text("\(CrochetCoreInfo.name) を読み込みました")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
