import SwiftUI
import CrochetCore

/// 目数表（ui-spec 5-4 の B）。1行につき1段。同じ内容の段はまとめ、入力中の段は「入力中」と出す。
struct StitchTableView: View {
    let model: EditorModel

    var body: some View {
        ScrollViewReader { proxy in
            List {
                foundationRow
                ForEach(model.finishedTableRows, id: \.rowNumbers) { row in
                    finishedRow(row)
                }
                if let index = model.currentRowIndex {
                    currentRow(number: index + 1)
                        .id(Self.currentRowID)
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("stitchTable")
            // 段が増えたら入力中の段が見えるように末尾へスクロールする
            .onChange(of: model.pattern.rows.count, initial: true) { _, _ in
                withAnimation {
                    proxy.scrollTo(Self.currentRowID, anchor: .bottom)
                }
            }
        }
    }

    private static let currentRowID = "currentRow"

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

    /// 段が終わった行。警告があれば色を変えて警告文を添える（domain-spec 23）
    private func finishedRow(_ row: StitchTableRow) -> some View {
        let warning = row.rowIDs.count == 1 ? model.warningsByRowIndex[row.rowNumbers.lowerBound - 1] : nil
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.rowNumberText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
                Text(row.instruction)
                Spacer(minLength: 8)
                Text(row.countText + (row.isUnchangedRun ? "（増減なし）" : ""))
                    .font(.callout)
                    .monospacedDigit()
            }
            if let warning {
                Text(warning.message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 56)
            }
        }
        .listRowBackground(warning == nil ? Color.clear : Color.red.opacity(0.08))
        .accessibilityIdentifier("table.row.\(row.rowNumbers.lowerBound)")
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
    let model = EditorModel()
    for _ in 0..<6 { model.pressStitch(.singleCrochet) }
    model.pressFinishRow()
    model.toggleUntilEnd()
    model.toggleIncrease()
    model.pressStitch(.singleCrochet)
    model.pressFinishRow()
    return StitchTableView(model: model)
}
