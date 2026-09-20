import SwiftUI
import CrochetCore

/// 編集画面（ui-spec 5章）。`NavigationStack` の中に置く前提（ツールバーは navigation bar に出す）。
///
/// - iPhone と iPad 縦向き（5-2）：上から ツールバー（E）→ 図／目数表のタブ（A／B）→ 現在の段（C）→ 編み目キーボード（D）
/// - iPad 横向き：左に図（上）と目数表（下）を同時に表示し、右に幅 392pt の固定レール（C と D）。
///   向きは画面の縦横比で判定する（サイズクラスだけでは iPad の縦横を区別できないため）
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
    /// 立ち上がりを1目と数えるか（ui-spec 6-3）
    @AppStorage(AppSettings.turningChainCountingKey) private var turningChainCounting = TurningChainCounting.standard
    /// 図／目数表の切り替え
    @State private var tab: Tab = .chart
    /// 書き出しシート（ui-spec 6-2）
    @State private var showsExportSheet = false
    /// 書き出し前の確認の文（ui-spec 7-3）。nil なら確認を出していない
    @State private var exportConfirmationMessage: String?

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
        GeometryReader { geometry in
            if Self.usesWideLayout(for: geometry.size) {
                wideLayout
            } else {
                compactLayout
            }
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
        // 書き出し前の確認（7-3）。「書き出す」で書き出しシートへ進む
        .alert("書き出し前の確認", isPresented: isExportConfirmationPresented) {
            Button("書き出す") { showsExportSheet = true }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(exportConfirmationMessage ?? "")
        }
        .sheet(isPresented: $showsExportSheet) {
            ExportSheet(title: title, pattern: model.pattern)
        }
        .onChange(of: autoTurningChain, initial: true) { _, isOn in
            model.autoTurningChain = isOn
        }
        .onChange(of: turningChainCounting, initial: true) { _, counting in
            model.turningChainCounting = counting
        }
        // 立ち上がりを数えるかの確認（7-4。設定が「毎回選択」のとき）
        .alert("立ち上がり", isPresented: isTurningChainQuestionPresented) {
            Button("数える") { model.answerTurningChainQuestion(counted: true) }
            Button("数えない") { model.answerTurningChainQuestion(counted: false) }
            Button("キャンセル", role: .cancel) { model.cancelTurningChainQuestion() }
        } message: {
            Text(model.pendingTurningChainQuestion?.message ?? "")
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

    private var isTurningChainQuestionPresented: Binding<Bool> {
        Binding(get: { model.pendingTurningChainQuestion != nil }, set: { if !$0 { model.cancelTurningChainQuestion() } })
    }

    private var isExportConfirmationPresented: Binding<Bool> {
        Binding(get: { exportConfirmationMessage != nil }, set: { if !$0 { exportConfirmationMessage = nil } })
    }

    /// 書き出しへ進む。目数が合わない段があれば先に確認を出す（ui-spec 7-3）
    private func requestExport() {
        let document = ExportDocument(title: title, pattern: model.pattern, options: ExportOptions())
        if let message = document.confirmationMessage {
            exportConfirmationMessage = message
        } else {
            showsExportSheet = true
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

    /// iPad 横向きなら true（横長で、レールと図の両方が置ける幅があるとき）
    static func usesWideLayout(for size: CGSize) -> Bool {
        size.width > size.height && size.width >= 900
    }

    /// iPhone・iPad 縦向きの配置（ui-spec 5-2）
    private var compactLayout: some View {
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
            contextBar
            StitchKeyboardView(model: model)
        }
    }

    /// iPad 横向きの配置（ui-spec 5-2）：左に図と目数表、右に固定レール
    private var wideLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                chart
                Divider()
                // 目数表は高さを決めて下に置く（図は残りの高さを使う）
                StitchTableView(model: model)
                    .frame(height: 260)
            }
            Divider()
            VStack(spacing: 0) {
                CurrentRowView(model: model)
                Divider()
                contextBar
                StitchKeyboardView(model: model, isLarge: true)
                Spacer(minLength: 0)
            }
            .frame(width: 392)
            .background(Color(.secondarySystemBackground))
        }
    }

    /// 編集中／選択中の操作バー（状態 S4／S6）
    @ViewBuilder
    private var contextBar: some View {
        if model.editingSession != nil {
            EditingBar(model: model)
            Divider()
        } else if model.selection != nil {
            SelectionBar(model: model)
            Divider()
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
                // 色の編集はフェーズ9で有効にする
                Button("色を編集", systemImage: "paintpalette") {}
                    .disabled(true)
                Button("書き出し", systemImage: "square.and.arrow.up") { requestExport() }
                    .accessibilityIdentifier("menu.export")
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
            showsSeamMarks: model.pattern.method == .spiral,
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
