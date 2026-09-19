import SwiftUI
import CrochetCore

/// 仮の編集画面（plan.md フェーズ2・3）。
///
/// 本番の配置（ui-spec 5-2）はフェーズ4で作り直す。ここでは上から
/// 仮の設定 → 図（A）／目数表（B）のタブ → 現在の段（C）→ 編み目キーボード（D）を縦に並べる。
struct EditorView: View {
    /// 編集の状態。`@State` で View が持ち主になる（React の useState でオブジェクトを持つのに近い）
    @State private var model: EditorModel
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3。仮の切り替えをこの画面に置く）
    @AppStorage(AppSettings.autoTurningChainKey) private var autoTurningChain = true
    /// 図に段番号を表示（ui-spec 6-3）
    @AppStorage(AppSettings.showsRowNumbersKey) private var showsRowNumbers = true
    /// 図／目数表の切り替え
    @State private var tab: Tab = .chart

    private enum Tab: String, CaseIterable {
        case chart = "図"
        case table = "目数表"
    }

    init(model: EditorModel = EditorModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsBar
            Picker("表示", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            Divider()
            switch tab {
            case .chart:
                ChartView(
                    layout: model.layout,
                    currentRowIndex: model.currentRowIndex,
                    highlighted: model.nextStitchToPick,
                    showsRowNumbers: showsRowNumbers
                )
            case .table:
                StitchTableView(model: model)
            }
            Divider()
            CurrentRowView(model: model)
            Divider()
            StitchKeyboardView(model: model)
        }
        .onChange(of: autoTurningChain, initial: true) { _, isOn in
            model.autoTurningChain = isOn
        }
    }

    /// 仮の設定：立ち上がりの自動入力、段番号、元に戻す／やり直し
    private var settingsBar: some View {
        HStack(spacing: 12) {
            Toggle("立ち上がりを自動で", isOn: $autoTurningChain)
                .font(.footnote)
            Toggle("段番号", isOn: $showsRowNumbers)
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
        .padding(.vertical, 6)
    }
}

#Preview("くまの頭") {
    EditorView(model: EditorModel(pattern: SamplePatterns.bearHead))
}
