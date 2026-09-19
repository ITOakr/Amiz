import SwiftUI
import CrochetCore

/// 仮の編集画面（plan.md フェーズ2）。
///
/// 本番の配置（ui-spec 5-2）はフェーズ4で作り直す。ここではキーボードと、
/// 入力の結果を確認するための表示だけを縦に並べる。
struct EditorView: View {
    /// 編集の状態。`@State` で View が持ち主になる（React の useState でオブジェクトを持つのに近い）
    @State private var model = EditorModel()
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3。仮の切り替えをこの画面に置く）
    @AppStorage(AppSettings.autoTurningChainKey) private var autoTurningChain = true

    var body: some View {
        VStack(spacing: 0) {
            settingsBar
            Divider()
            statusArea
            Spacer(minLength: 0)
            StitchKeyboardView(model: model)
        }
        .onChange(of: autoTurningChain, initial: true) { _, isOn in
            model.autoTurningChain = isOn
        }
    }

    /// 仮の設定：立ち上がりの自動入力
    private var settingsBar: some View {
        HStack {
            Toggle("立ち上がりの鎖を自動で入れる", isOn: $autoTurningChain)
                .font(.footnote)
            Button("元に戻す", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.canUndo)
            Button("やり直し", systemImage: "arrow.uturn.forward") { model.redo() }
                .disabled(!model.canRedo)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 入力の結果を確認するための仮の表示（現在の段と目数表はフェーズ2-3 で作る）
    private var statusArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let index = model.currentRowIndex, let row = model.currentRow {
                Text("\(index + 1)段目　この段 \(row.totalCount)目")
                    .font(.headline)
                    .accessibilityIdentifier("status.row")
                if let previous = row.previousCount {
                    Text("前段 \(previous)目のうち \(row.pickedCount)目拾った")
                } else {
                    Text("わの作り目に編み入れ中")
                }
                Text(model.pattern.rows[index].steps.suffix(3).map(StitchTableFormatter.label).joined(separator: "｜"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if model.isRepeating {
                    Text("繰り返しを入力中（『\((model.pendingRepeatUnit ?? []).map(StitchTableFormatter.label).joined(separator: "・"))』）")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            } else {
                Text("わの作り目　1段目を編み始めてください")
                    .font(.headline)
            }
            if !model.warnings.isEmpty {
                Text("警告：" + model.warnings.map { "\($0.rowNumber)段目 \($0.message)" }.joined(separator: "／"))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

#Preview {
    EditorView()
}
