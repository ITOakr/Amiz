import SwiftUI
import CrochetCore

/// 現在の段（ui-spec 5-5 の C）。進み具合の数字を主役にし、直前に編んだ3項目を添える。
struct CurrentRowView: View {
    let model: EditorModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            progress
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(rowSummary)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("status.row")
                recentSteps
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        // 縦は必要な高さだけ使い、余りは目数表に渡す
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 「拾った目／前段の目数」を大きく。わの作り目の1段目は分母がないので「この段 ○目」だけ
    private var progress: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let row = model.currentRow, let previous = row.previousCount {
                Text("\(row.pickedCount)/\(previous)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("前段から拾った目")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(model.currentRow?.totalCount ?? 0)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("この段の目数")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 88, alignment: .leading)
    }

    /// 「4段目・この段 5目」
    private var rowSummary: String {
        guard let index = model.currentRowIndex, let row = model.currentRow else {
            return "1段目を編み始めてください"
        }
        return "\(index + 1)段目・この段 \(row.totalCount)目"
    }

    /// 直前に編んだ3項目（ui-spec 5-5）
    private var recentSteps: some View {
        HStack(spacing: 6) {
            let labels = model.recentStepLabels(count: 3)
            if labels.isEmpty {
                Text("まだ目がありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                }
                // 入力位置
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 20)
            }
            if model.isRepeating {
                Text("繰り返し入力中")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
        }
    }
}

#Preview {
    let model = EditorModel()
    for _ in 0..<6 { model.pressStitch(.singleCrochet) }
    model.pressFinishRow()
    model.toggleIncrease()
    model.pressStitch(.singleCrochet)
    model.pressStitch(.singleCrochet)
    return CurrentRowView(model: model)
}
