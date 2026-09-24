import Foundation
import Observation
import CrochetCore

/// `EditorModel` の糸リストと持ち替え（ui-spec U17・6-1）と色編集モード（U21）。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    var yarns: [Yarn] { pattern.yarns }

    /// 今持っている糸
    var currentYarn: Yarn { pattern.currentYarn }

    /// 糸を持ち替える（U17）。これから編む目はこの糸になる
    func changeYarn(to yarnID: UUID) {
        mutate { PatternInput.changeYarn(to: yarnID, in: &$0) }
    }

    func addYarn(_ yarn: Yarn) {
        mutate { PatternInput.addYarn(yarn, to: &$0) }
    }

    func updateYarn(_ yarn: Yarn) {
        mutate { PatternInput.updateYarn(yarn, in: &$0) }
    }

    func moveYarns(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let first = source.first else { return }
        mutate { PatternInput.moveYarn(from: first, to: destination, in: &$0) }
    }

    /// 糸を削除する。その糸で編んだ目は既定の糸に戻る。最後の1本は消せない
    func deleteYarn(id: UUID) {
        mutate { PatternInput.deleteYarn(id: id, from: &$0) }
    }

    // MARK: - 色編集モード（ui-spec U21）

    /// 色編集モードに入る。過去の段の編集中は入れない。選択や先に選ぶ状態は解除し、塗る色は今持っている糸から始める
    func beginColorEditing() {
        guard editingSession == nil else { return }
        selection = nil
        modifier = .none
        repeatStartIndex = nil
        paintYarnID = currentYarn.id
        isColorEditing = true
    }

    /// 「完了」：通常の入力に戻る
    func endColorEditing() {
        endPaintStroke()
        isColorEditing = false
    }

    /// 目を塗る。繰り返しの中の目なら、その繰り返しを解除してからその目だけ塗る（domain-spec 27）
    func paintStitch(_ ref: StitchRef) {
        guard isColorEditing else { return }
        mutate { PatternInput.setYarn(paintYarnID, at: ref, in: &$0) }
    }

    /// 段全体を塗る（domain-spec 28）
    func paintRow(at index: Int) {
        guard isColorEditing else { return }
        mutate { PatternInput.setYarn(paintYarnID, forRowAt: index, in: &$0) }
    }

    /// なぞり始め：ここから `endPaintStroke` までの塗りを、元に戻すの1回にまとめる
    func beginPaintStroke() {
        guard isColorEditing, paintStrokeSnapshot == nil else { return }
        paintStrokeSnapshot = pattern
    }

    /// なぞり終わり
    func endPaintStroke() {
        guard let snapshot = paintStrokeSnapshot else { return }
        paintStrokeSnapshot = nil
        if snapshot != pattern {
            undoStack.append(snapshot)
            redoStack.removeAll()
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isRepeating: Bool { (editingSession?.repeatStartIndex ?? repeatStartIndex) != nil }

    /// 入力中の段の操作の列
    var currentRowSteps: [Step] {
        currentRowIndex.map { pattern.rows[$0].steps } ?? []
    }

    /// 直前に編んだ操作（「現在の段」に並べる。ui-spec 5-5）
    func recentSteps(count: Int) -> [Step] {
        Array(currentRowSteps.suffix(count))
    }

    /// 目数表の行（入力中の段を除く。同じ内容の段はまとめる。ui-spec 5-4）
    var finishedTableRows: [StitchTableRow] {
        guard let current = currentRowIndex, expansion.rows.count > current else { return [] }
        var finished = displayedPattern
        finished.rows.removeLast()
        let finishedExpansion = PatternExpansion(rows: Array(expansion.rows[..<current]))
        return StitchTableFormatter.tableRows(for: finished, expansion: finishedExpansion, warnings: warnings)
    }

    /// 1段分の目数表の行（まとめた行を展開して表示するときに使う）。範囲外なら nil（AMIZ-73）
    func singleTableRow(at index: Int) -> StitchTableRow? {
        let shown = displayedPattern
        guard shown.rows.indices.contains(index), expansion.rows.indices.contains(index) else { return nil }
        return StitchTableRow(
            rowNumbers: (index + 1)...(index + 1),
            rowIDs: [shown.rows[index].id],
            instruction: StitchTableFormatter.instruction(for: shown.rows[index], rowIndex: index, in: shown),
            countText: StitchTableFormatter.countText(for: expansion.rows[index]),
            isUnchangedRun: index > 0 && expansion.rows[index].totalCount == expansion.rows[index - 1].totalCount
        )
    }

    /// 段の位置ごとの警告（目数表で引く）
    var warningsByRowIndex: [Int: RowWarning] {
        Dictionary(uniqueKeysWithValues: warnings.map { ($0.rowIndex, $0) })
    }

    /// 作り目の行の文章（「わの作り目」「作り目：鎖21目」）
    var foundationText: String {
        StitchTableFormatter.foundationText(for: pattern)
    }

    /// 次に拾う前段の目（図のハイライト。ui-spec 5-3）。前段がない・使い切った・段がないときは nil
    var nextStitchToPick: LaidOutStitch? {
        guard let index = currentRowIndex, index > 0, let row = currentRow,
              let next = row.nextPickIndex else { return nil }
        return layout.countedStitch(rowIndex: index - 1, countedIndex: next)
    }

    /// 「繰り返し終了」で「段の終わりまで」を選べるか
    var canEndRepeatUntilEnd: Bool {
        guard let unit = pendingRepeatUnit else { return false }
        return PatternInput.canRepeatUntilEnd(unit: unit)
    }

    /// 「繰り返し開始」から今までの操作（繰り返し終了の確認に表示する）
    var pendingRepeatUnit: [Step]? {
        if let session = editingSession {
            guard let start = session.repeatStartIndex, start <= session.cursor else { return nil }
            return Array(session.row.steps[start..<session.cursor])
        }
        guard let start = repeatStartIndex, let index = currentRowIndex else { return nil }
        let steps = pattern.rows[index].steps
        guard start <= steps.count else { return nil }
        return Array(steps[start...])
    }
}
