import SwiftUI

/// 設定（ui-spec 6-3）。値は UserDefaults に保存する（tech-spec 5-5）。
struct SettingsView: View {
    @AppStorage(AppSettings.autoTurningChainKey) private var autoTurningChain = true
    @AppStorage(AppSettings.showsRowNumbersKey) private var showsRowNumbers = true

    var body: some View {
        Form {
            Section {
                Toggle("立ち上がりの鎖の自動入力", isOn: $autoTurningChain)
                    .accessibilityIdentifier("settings.autoTurningChain")
            } footer: {
                Text("段の最初に鎖以外の目を編んだとき、段の先頭に立ち上がりの鎖を自動で入れます。")
            }
            Section {
                Toggle("図に段番号を表示", isOn: $showsRowNumbers)
                    .accessibilityIdentifier("settings.showsRowNumbers")
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
