import SwiftUI
import CrochetCore

/// 仮の編集画面（plan.md フェーズ2）。
///
/// 本番の配置（ui-spec 5-2）はフェーズ4で作り直す。ここでは上から
/// 仮の設定 → 目数表（B）→ 現在の段（C）→ 編み目キーボード（D）を縦に並べる。図（A）はフェーズ3。
struct EditorView: View {
    /// 編集の状態。`@State` で View が持ち主になる（React の useState でオブジェクトを持つのに近い）
    @State private var model = EditorModel()
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3。仮の切り替えをこの画面に置く）
    @AppStorage(AppSettings.autoTurningChainKey) private var autoTurningChain = true

    var body: some View {
        VStack(spacing: 0) {
            settingsBar
            Divider()
            StitchTableView(model: model)
            Divider()
            CurrentRowView(model: model)
            Divider()
            StitchKeyboardView(model: model)
        }
        .onChange(of: autoTurningChain, initial: true) { _, isOn in
            model.autoTurningChain = isOn
        }
    }

    /// 仮の設定：立ち上がりの自動入力、元に戻す／やり直し
    private var settingsBar: some View {
        HStack {
            Toggle("立ち上がりの鎖を自動で入れる", isOn: $autoTurningChain)
                .font(.footnote)
            Button("元に戻す", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.canUndo)
                .accessibilityIdentifier("op.undo")
            Button("やり直し", systemImage: "arrow.uturn.forward") { model.redo() }
                .disabled(!model.canRedo)
                .accessibilityIdentifier("op.redo")
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    EditorView()
}
