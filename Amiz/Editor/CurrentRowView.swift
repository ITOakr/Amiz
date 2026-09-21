import SwiftUI
import CrochetCore

/// 現在の段（ui-spec 5-5 の C）。進み具合の数字を主役にし、直前に編んだ3項目を添える。
/// 過去の段を編集中（U16）は、その段の手順をすべて並べ、項目の間をタップして入力位置を動かす。
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
                if model.hasUsedUpPreviousRow, model.editingSession == nil {
                    // 前段を拾い切った。さらに編める（拾いすぎ）が、警告は段を終えたときに出す（domain-spec 23）
                    Text("前段を使い切りました")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("status.usedUp")
                }
                if let session = model.editingSession {
                    editingSteps(session)
                } else {
                    recentSteps
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(model.editingSession == nil ? AppTheme.card : AppTheme.accent.opacity(0.08))
        // 縦は必要な高さだけ使い、余りは目数表に渡す
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 「拾った目／前段の目数」を大きく。わの作り目の1段目は分母がないので「この段 ○目」だけ
    private var progress: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let row = model.activeRow, let previous = row.previousCount {
                Text("\(row.pickedCount)/\(previous)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("前段から拾った目")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(model.activeRow?.totalCount ?? 0)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("この段の目数")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 88, alignment: .leading)
    }

    /// 「4段目・この段 5目」（編集中は「3段目を編集中・この段 18目」）
    private var rowSummary: String {
        guard let index = model.activeRowIndex, let row = model.activeRow else {
            return "1段目を編み始めてください"
        }
        if model.editingSession != nil {
            return "\(index + 1)段目を編集中・この段 \(row.totalCount)目"
        }
        return "\(index + 1)段目・この段 \(row.totalCount)目"
    }

    /// 直前に編んだ3項目（ui-spec 5-5）。タップで選択（U15）
    private var recentSteps: some View {
        HStack(spacing: 6) {
            let steps = model.recentSteps(count: 3)
            if steps.isEmpty {
                Text("まだ目がありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(steps) { step in
                    let ref = model.currentRowIndex.map { StitchRef(rowID: model.pattern.rows[$0].id, stepID: step.id) }
                    StepChip(label: StitchTableFormatter.label(for: step), yarn: chipYarn(for: step), isSelected: ref != nil && model.selection == ref) {
                        model.select(ref)
                    }
                }
                cursorBar
            }
            if model.isRepeating {
                Text("繰り返し入力中")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
        }
    }

    /// 編集中：段の手順をすべて並べ、項目の間（すき間）をタップして入力位置を動かす（U16）
    private func editingSteps(_ session: EditorModel.RowEditingSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(session.row.steps.enumerated()), id: \.element.id) { index, step in
                    cursorGap(at: index, isCursor: session.cursor == index)
                    StepChip(label: StitchTableFormatter.label(for: step), yarn: chipYarn(for: step), isSelected: false) {
                        model.moveCursor(to: index + 1)
                    }
                    .accessibilityIdentifier("editing.step.\(index)")
                }
                cursorGap(at: session.row.steps.count, isCursor: session.cursor == session.row.steps.count)
                if model.isRepeating {
                    Text("繰り返し入力中")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.leading, 6)
                }
            }
        }
    }

    /// 項目の間のすき間。タップで入力位置に。入力位置なら縦線を出す
    private func cursorGap(at index: Int, isCursor: Bool) -> some View {
        Button {
            model.moveCursor(to: index)
        } label: {
            ZStack {
                Color.clear.frame(width: 14, height: 28)
                if isCursor {
                    cursorBar
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editing.gap.\(index)")
    }

    /// 入力位置の縦線
    private var cursorBar: some View {
        Rectangle()
            .fill(AppTheme.accent)
            .frame(width: 2, height: 20)
    }
}

/// 手順の1項目（チップ）
private struct StepChip: View {
    let label: String
    /// 糸の色見本（糸が2本以上の作品で、糸を持つ操作だけ）
    var yarn: Yarn?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let yarn {
                    YarnSwatch(color: yarn.color, size: 10)
                }
                Text(label)
            }
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? AppTheme.selection.opacity(0.25) : AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.chipRadius).stroke(isSelected ? AppTheme.selection : AppTheme.hairline, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(yarn.map { "\(label)・\($0.name)" } ?? label)
    }
}

extension CurrentRowView {
    /// 項目に添える糸。糸が1本だけの作品では添えない（見た目を増やさないため）
    fileprivate func chipYarn(for step: Step) -> Yarn? {
        guard model.yarns.count > 1 else { return nil }
        switch step.kind {
        case .skip, .leaveRemaining, .repeatGroup: return nil
        default: return model.pattern.yarn(for: step.yarnID)
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
