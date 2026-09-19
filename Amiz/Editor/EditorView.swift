import SwiftUI
import CrochetCore

/// 編集画面（ui-spec 5章）。iPhone の配置（5-2）：上から ツールバー（E）→ 図／目数表のタブ（A／B）→ 現在の段（C）→ 編み目キーボード（D）。
///
/// iPad の配置はフェーズ4-2 で追加する。`NavigationStack` の中に置く前提（ツールバーは navigation bar に出す）。
struct EditorView: View {
    /// 編集の状態。`@State` で View が持ち主になる（React の useState でオブジェクトを持つのに近い）
    @State private var model: EditorModel
    /// 作品名（ツールバーに表示）
    let title: String
    /// 編み図が変わったときに呼ぶ（自動保存。tech-spec 6）。確認用の作品では nil
    private let onPatternChange: ((Pattern) -> Void)?
    /// 自動保存をまとめるための待ち（連続入力のたびに書き込まないように）
    @State private var saveTask: Task<Void, Never>?
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3）
    @AppStorage(AppSettings.autoTurningChainKey) private var autoTurningChain = true
    /// 図に段番号を表示（ui-spec 6-3）
    @AppStorage(AppSettings.showsRowNumbersKey) private var showsRowNumbers = true
    /// 図／目数表の切り替え
    @State private var tab: Tab = .chart

    private enum Tab: String, CaseIterable {
        case chart = "図"
        case table = "目数表"
    }

    init(model: EditorModel = EditorModel(), title: String = "新しい作品", onPatternChange: ((Pattern) -> Void)? = nil) {
        _model = State(initialValue: model)
        self.title = title
        self.onPatternChange = onPatternChange
    }

    /// 保存済みの作品を開く。編み図が変わるたびに作品へ自動保存する
    init(work: Work) {
        let pattern = work.loadPattern() ?? Pattern(method: work.method, foundation: .magicRing)
        self.init(model: EditorModel(pattern: pattern), title: work.name) { pattern in
            work.save(pattern: pattern)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            switch tab {
            case .chart:
                chart
            case .table:
                StitchTableView(model: model)
            }
            Divider()
            CurrentRowView(model: model)
            Divider()
            if model.editingSession != nil {
                EditingBar(model: model)
                Divider()
            } else if model.selection != nil {
                SelectionBar(model: model)
                Divider()
            }
            StitchKeyboardView(model: model)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("修正の確認", isPresented: isConfirmationPresented) {
            Button("上の段を残す") { model.resolveConfirmation(keepingRowsAbove: true) }
            Button("上の段をほどく", role: .destructive) { model.resolveConfirmation(keepingRowsAbove: false) }
            Button("キャンセル", role: .cancel) { model.cancelConfirmation() }
        } message: {
            Text(model.pendingConfirmation?.message ?? "")
        }
        .onChange(of: autoTurningChain, initial: true) { _, isOn in
            model.autoTurningChain = isOn
        }
        .onChange(of: model.pattern) { _, pattern in
            scheduleSave(pattern)
        }
        .onDisappear {
            // 画面を閉じるときは待たずに保存する
            saveTask?.cancel()
            onPatternChange?(model.pattern)
        }
    }

    /// 少し待ってから保存する。待っている間に次の変更が来たら待ち直す
    private func scheduleSave(_ pattern: Pattern) {
        guard let onPatternChange else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            onPatternChange(pattern)
        }
    }

    /// 修正の確認ダイアログ（ui-spec 7-1）の表示状態
    private var isConfirmationPresented: Binding<Bool> {
        Binding(
            get: { model.pendingConfirmation != nil },
            set: { if !$0 { model.cancelConfirmation() } }
        )
    }

    // MARK: - ツールバー（E）

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(model.pattern.method.japaneseName)・\(model.pattern.foundation.japaneseName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("元に戻す", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.canUndo)
                .accessibilityIdentifier("op.undo")
            Button("やり直し", systemImage: "arrow.uturn.forward") { model.redo() }
                .disabled(!model.canRedo)
                .accessibilityIdentifier("op.redo")
            Menu("その他", systemImage: "ellipsis.circle") {
                // 色の編集はフェーズ9、書き出しはフェーズ5で有効にする
                Button("色を編集", systemImage: "paintpalette") {}
                    .disabled(true)
                Button("書き出し", systemImage: "square.and.arrow.up") {}
                    .disabled(true)
            }
            .accessibilityIdentifier("toolbar.more")
        }
    }

    // MARK: - 図／目数表（A／B）

    private var tabPicker: some View {
        Picker("表示", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var chart: some View {
        ChartView(
            layout: model.layout,
            currentRowIndex: model.currentRowIndex,
            highlighted: model.nextStitchToPick,
            selected: model.selectedStitch,
            showsRowNumbers: showsRowNumbers,
            onTapStitch: { model.select($0.ref) }
        )
        .overlay(alignment: .topLeading) {
            // 凡例（モックに合わせる）
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("次に拾う目")
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .padding(8)
        }
    }
}

#Preview("くまの頭") {
    NavigationStack {
        EditorView(model: EditorModel(pattern: SamplePatterns.bearHead), title: "くまの頭")
    }
}
