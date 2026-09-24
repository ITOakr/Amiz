import SwiftUI
import CrochetCore

/// 目数表（ui-spec 5-4 の B）。1行につき1段。同じ内容の段はまとめ、入力中の段は「入力中」と出す。
/// 段をタップするとその段の編集に入る（U16）。まとめた行はタップで展開してから段を選ぶ。
struct StitchTableView: View {
    let model: EditorModel

    /// 展開して1段ずつ表示しているまとめ行（先頭の段番号で覚える）
    @State private var expandedRuns: Set<Int> = []
    /// 複製の回数を聞いている段（0始まり）
    @State private var duplicateTarget: Int?
    @State private var duplicateCountText = "1"

    var body: some View {
        ScrollViewReader { proxy in
            List {
                foundationRow
                ForEach(model.finishedTableRows, id: \.rowNumbers) { row in
                    if row.isMerged, expandedRuns.contains(row.rowNumbers.lowerBound) {
                        ForEach(row.rowNumbers.map { $0 - 1 }, id: \.self) { index in
                            if let single = model.singleTableRow(at: index) {
                                finishedRow(single)
                            }
                        }
                    } else {
                        finishedRow(row)
                    }
                }
                if let index = model.currentRowIndex {
                    currentRow(number: index + 1)
                        .id(Self.currentRowID)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .accessibilityIdentifier("stitchTable")
            .alert("この段を複製", isPresented: isDuplicatePresented) {
                TextField("回数", text: $duplicateCountText)
                    .keyboardType(.numberPad)
                Button("複製する") {
                    if let target = duplicateTarget {
                        model.requestDuplicateRow(at: target, times: max(1, Int(duplicateCountText) ?? 1))
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let target = duplicateTarget {
                    Text("\(target + 1)段目と同じ手順の段を、その直後に指定した回数ぶん挿入します。")
                }
            }
            // 段が増えたら入力中の段が見えるように末尾へスクロールする
            .onChange(of: model.pattern.rows.count, initial: true) { _, _ in
                withAnimation {
                    proxy.scrollTo(Self.currentRowID, anchor: .bottom)
                }
            }
        }
    }

    private static let currentRowID = "currentRow"

    private var isDuplicatePresented: Binding<Bool> {
        Binding(get: { duplicateTarget != nil }, set: { if !$0 { duplicateTarget = nil } })
    }

    /// 作り目の行（domain-spec 33）
    private var foundationRow: some View {
        HStack {
            Text("作り目")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(model.foundationText)
            Spacer()
        }
    }

    /// 段が終わった行。警告があれば色を変えて警告文を添える（domain-spec 23）。タップで編集（U16）
    private func finishedRow(_ row: StitchTableRow) -> some View {
        let warning = row.rowIDs.count == 1 ? model.warningsByRowIndex[row.rowNumbers.lowerBound - 1] : nil
        let isEditing = model.editingSession?.rowIndex == row.rowNumbers.lowerBound - 1 && !row.isMerged
        return Button {
            if row.isMerged {
                expandedRuns.insert(row.rowNumbers.lowerBound)
            } else if model.isColorEditing {
                // 色編集モード：段全体を塗る（ui-spec U21）
                model.paintRow(at: row.rowNumbers.lowerBound - 1)
            } else {
                model.beginEditingRow(at: row.rowNumbers.lowerBound - 1)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.rowNumberText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(row.instruction)
                    Spacer(minLength: 8)
                    if isEditing {
                        Text("編集中")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                    Text(row.countText + (row.isUnchangedRun ? "（増減なし）" : ""))
                        .font(.callout)
                        .monospacedDigit()
                }
                if let warning {
                    Text(warning.message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                        .padding(.leading, 56)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(hasWarning: warning != nil, isEditing: isEditing))
        .accessibilityIdentifier("table.row.\(row.rowNumbers.lowerBound)")
        // 段の長押しメニュー（U22）。まとめた行は展開してから。色編集モード中は目の追加・削除をしない
        .contextMenu {
            if !row.isMerged, !model.isColorEditing {
                Button("この段を複製", systemImage: "plus.square.on.square") {
                    duplicateTarget = row.rowNumbers.lowerBound - 1
                }
                Button("この段を削除", systemImage: "trash", role: .destructive) {
                    model.requestDeleteRow(at: row.rowNumbers.lowerBound - 1)
                }
            }
        }
    }

    private func rowBackground(hasWarning: Bool, isEditing: Bool) -> Color {
        if isEditing { return AppTheme.accent.opacity(0.12) }
        if hasWarning { return AppTheme.warning.opacity(0.1) }
        return AppTheme.canvas
    }

    /// 入力中の段の行（ui-spec 8章のサンプル：「4 | 入力中 | —」）
    private func currentRow(number: Int) -> some View {
        HStack {
            Text("\(number)段目")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text("入力中")
                .foregroundStyle(.tint)
            Spacer()
            Text("—")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let model = EditorModel(pattern: SamplePatterns.bearHead)
    return StitchTableView(model: model)
}
