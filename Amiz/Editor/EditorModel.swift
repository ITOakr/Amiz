import Observation
import CrochetCore

/// 編集画面の状態（React の store に当たる）。
///
/// 画面はこのオブジェクトを見て描き、ボタンは `press…` を呼ぶ。編み物のルールは CrochetCore の
/// `PatternInput` に任せ、ここでは状態の保持と元に戻す／やり直しだけを扱う（tech-spec 9）。
@Observable
final class EditorModel {
    /// 編み図。変更は必ず `mutate` を通す（元に戻す用のコピーを積むため）
    private(set) var pattern: Pattern
    /// 展開結果。`pattern` が変わるたびに計算し直す（保存はしない。tech-spec 5-1）
    private(set) var expansion: PatternExpansion
    /// 図のレイアウト。`pattern` が変わるたびに計算し直す
    private(set) var layout: ChartLayout
    /// 先に選ぶボタンの状態（状態 S2）
    private(set) var modifier = StitchModifier.none
    /// 「繰り返し開始」を押した位置（入力中の段の操作数）。押していなければ nil
    private(set) var repeatStartIndex: Int?
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var autoTurningChain = true
    /// 選択中の目（状態 S6。ui-spec U15）
    private(set) var selection: StitchRef?
    /// 確認待ちの修正（ui-spec 7-1）。画面がこれを見てダイアログを出す
    private(set) var pendingConfirmation: PendingConfirmation?

    /// 目数が変わる修正の確認待ち。「上の段を残す」なら `edited` をそのまま使い、「ほどく」なら上の段を消す
    struct PendingConfirmation {
        let impact: EditImpact
        let rowIndex: Int
        let editedRow: Row

        /// 7-1 のメッセージ（「2段目の目数が12目から14目に変わりました。3〜5段目に影響があります。」）
        var message: String {
            var text = "\(impact.editedRowNumber)段目"
            if let before = impact.countBefore, let after = impact.countAfter {
                text += "の目数が\(before)目から\(after)目に変わりました。"
            } else {
                text += "を変更します。"
            }
            if let affected = impact.affectedRowsDescription {
                text += "\(affected)に影響があります。"
            }
            return text
        }
    }

    /// 選択した目に対する編集（ui-spec U15）
    enum SelectionEdit {
        case changeKind(StitchKind)
        case delete
        case unwrapRepeat
        case setTurningChain(Int)
    }

    private var undoStack: [Pattern] = []
    private var redoStack: [Pattern] = []

    init(pattern: Pattern) {
        self.pattern = pattern
        let expansion = pattern.expanded()
        self.expansion = expansion
        self.layout = pattern.circularLayout(expansion: expansion)
    }

    /// 新しい作品（わの作り目・輪編み）で始める
    convenience init() {
        self.init(pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
    }

    // MARK: - 画面が読む値

    /// 入力中の段の位置（0始まり）。まだ段がなければ nil
    var currentRowIndex: Int? {
        pattern.currentRowIndex
    }

    /// 入力中の段の展開結果
    var currentRow: RowExpansion? {
        currentRowIndex.map { expansion.rows[$0] }
    }

    /// 目数の警告。入力中の段は対象外（domain-spec 23）
    var warnings: [RowWarning] {
        expansion.warnings(excludingRowAt: currentRowIndex)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isRepeating: Bool { repeatStartIndex != nil }

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
        guard let current = currentRowIndex else { return [] }
        var finished = pattern
        finished.rows.removeLast()
        let finishedExpansion = PatternExpansion(rows: Array(expansion.rows[..<current]))
        return StitchTableFormatter.tableRows(for: finished, expansion: finishedExpansion, warnings: warnings)
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
              let unpicked = row.unpickedCount, unpicked > 0 else { return nil }
        return layout.countedStitch(rowIndex: index - 1, countedIndex: row.pickedCount)
    }

    /// 「繰り返し終了」で「段の終わりまで」を選べるか
    var canEndRepeatUntilEnd: Bool {
        guard let unit = pendingRepeatUnit else { return false }
        return PatternInput.canRepeatUntilEnd(unit: unit)
    }

    /// 「繰り返し開始」から今までの操作（繰り返し終了の確認に表示する）
    var pendingRepeatUnit: [Step]? {
        guard let start = repeatStartIndex, let index = currentRowIndex else { return nil }
        let steps = pattern.rows[index].steps
        guard start <= steps.count else { return nil }
        return Array(steps[start...])
    }

    // MARK: - 目ボタン・先に選ぶボタン

    /// 目ボタン。選択中なら選択した目の種類を変える（U15）。そうでなければ先に選ぶ状態を適用して1操作追加し、状態を解除する
    func pressStitch(_ kind: StitchKind) {
        if selection != nil {
            modifier = .none
            request(.changeKind(kind))
            return
        }
        let modifier = self.modifier
        self.modifier = .none
        mutate { pattern in
            let inserted = PatternInput.addStitch(kind, modifier: modifier, autoTurningChain: autoTurningChain, to: &pattern)
            // 立ち上がりが先頭に入ると、繰り返し開始の位置が1つ後ろにずれる
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }

    func toggleIncrease() { modifier.toggleIncrease() }
    func toggleDecrease() { modifier.toggleDecrease() }
    func toggleChainSpace() { modifier.toggleChainSpace() }
    func toggleUntilEnd() { modifier.toggleUntilEnd() }

    /// 「飛ばす」（選択状態にならず、押すたびに1目飛ばす）
    func pressSkip() {
        mutate { pattern in
            PatternInput.addSkip(to: &pattern)
        }
    }

    /// 「残りは編まない」（段を終えるときの確認 7-2 から呼ぶ）
    func pressLeaveRemaining() {
        mutate { pattern in
            PatternInput.addLeaveRemaining(to: &pattern)
        }
    }

    // MARK: - 段の操作

    /// 「1目削除」
    func pressDeleteLast() {
        modifier = .none
        mutate { pattern in
            PatternInput.deleteLastStep(from: &pattern)
        }
        // 繰り返し開始の位置が段の外に出たら解除
        if let start = repeatStartIndex, let index = currentRowIndex, start > pattern.rows[index].steps.count {
            repeatStartIndex = nil
        }
    }

    /// 「段を終える」を押したときに、前段に拾っていない目が残っていれば その数（確認 7-2 を出す）。なければ nil
    var remainingBeforeFinish: Int? {
        guard let unpicked = currentRow?.unpickedCount, unpicked > 0 else { return nil }
        return unpicked
    }

    /// 前段の目を使い切ったか（ui-spec 5-5「前段を使い切りました」）
    var hasUsedUpPreviousRow: Bool {
        guard let row = currentRow, row.previousCount != nil else { return false }
        return row.unpickedCount == 0
    }

    /// 「段を終える」。残っている前段の目の確認（7-2）は画面側が先に行う。
    /// - Parameter leavingRemaining: 確認で「残りは編まない」を選んだとき true（1回の操作として元に戻せる）
    func pressFinishRow(leavingRemaining: Bool = false) {
        modifier = .none
        repeatStartIndex = nil
        mutate { pattern in
            if leavingRemaining {
                PatternInput.addLeaveRemaining(to: &pattern)
            }
            PatternInput.finishRow(of: &pattern)
        }
    }

    /// 「繰り返し開始」：今の段の操作数を覚える（段がまだなければ 0）
    func pressBeginRepeat() {
        repeatStartIndex = pattern.rows.last?.steps.count ?? 0
    }

    /// 「繰り返し終了」。回数を指定してまとめる
    /// - Returns: まとめられたか（単位が空などのときは false で、開始位置は残る）
    @discardableResult
    func pressEndRepeat(count: RepeatCount) -> Bool {
        guard let start = repeatStartIndex else { return false }
        var wrapped = false
        mutate { pattern in
            wrapped = PatternInput.wrapRepeat(from: start, count: count, in: &pattern)
        }
        if wrapped {
            repeatStartIndex = nil
        }
        return wrapped
    }

    /// 繰り返しの入力をやめる（まとめずに開始位置を忘れる）
    func cancelRepeat() {
        repeatStartIndex = nil
    }

    /// 「立ち上がり」ボタン
    func pressTurningChain(chains: Int) {
        mutate { pattern in
            let inserted = PatternInput.setTurningChain(chains: chains, in: &pattern)
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }

    // MARK: - 目の選択（ui-spec U15）

    /// 目を選ぶ。同じ目をもう一度選ぶと解除
    func select(_ ref: StitchRef?) {
        selection = selection == ref ? nil : ref
        modifier = .none
    }

    func clearSelection() {
        selection = nil
    }

    /// 選択中の目の図上の位置（強調表示に使う）
    var selectedStitch: LaidOutStitch? {
        selection.flatMap { layout.stitch(for: $0) }
    }

    /// 選択中の操作の場所
    var selectedLocation: PatternInput.StepLocation? {
        selection.flatMap { PatternInput.locate($0, in: pattern) }
    }

    /// 選択中の操作
    var selectedStep: Step? {
        selectedLocation.flatMap { PatternInput.step(at: $0, in: pattern) }
    }

    /// 選択中の目が繰り返しの中（または繰り返しそのもの）か
    var selectionIsInRepeat: Bool {
        guard let location = selectedLocation else { return false }
        if location.isInsideRepeat { return true }
        if case .repeatGroup = pattern.rows[location.rowIndex].steps[location.stepIndex].kind { return true }
        return false
    }

    /// 選択中の目が立ち上がりなら、その鎖の目数
    var selectedTurningChainCount: Int? {
        if case .turningChain(let chains) = selectedStep?.kind { chains } else { nil }
    }

    /// 選択中の目の表記と段番号（「細編み（3段目）」）
    var selectionDescription: String? {
        guard let location = selectedLocation, let step = selectedStep else { return nil }
        return "\(StitchTableFormatter.label(for: step))（\(location.rowIndex + 1)段目）"
    }

    /// 選択した目を編集する。過去の段で目数が変わり上に段があれば、確認待ち（7-1）にする
    func request(_ edit: SelectionEdit) {
        guard let ref = selection, let location = selectedLocation else { return }

        // まず編集後の段を作る
        var edited = pattern
        let applied: Bool
        switch edit {
        case .changeKind(let kind):
            applied = PatternInput.changeStitchKind(at: ref, to: kind, in: &edited)
        case .delete:
            applied = PatternInput.deleteStep(at: ref, in: &edited)
        case .unwrapRepeat:
            applied = PatternInput.unwrapRepeat(containing: ref, in: &edited)
        case .setTurningChain(let chains):
            applied = PatternInput.setTurningChain(chains: chains, rowID: ref.rowID, in: &edited)
        }
        guard applied else { return }

        let editedRow = edited.rows[location.rowIndex]
        let impact = PatternEditor.impact(of: .replace(rowIndex: location.rowIndex, with: editedRow), on: pattern)
        let keepsSelection: Bool = if case .changeKind = edit { true } else if case .setTurningChain = edit { true } else { false }

        if impact.needsConfirmation {
            pendingConfirmation = PendingConfirmation(impact: impact, rowIndex: location.rowIndex, editedRow: editedRow)
        } else {
            mutate { $0 = edited }
            if !keepsSelection { selection = nil }
        }
    }

    /// 確認（7-1）の答え：上の段を残す（true）／ほどく（false）
    func resolveConfirmation(keepingRowsAbove: Bool) {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        let edit = RowEdit.replace(rowIndex: pending.rowIndex, with: pending.editedRow)
        mutate { pattern in
            pattern = keepingRowsAbove
                ? PatternEditor.applyKeepingRowsAbove(edit, to: pattern)
                : PatternEditor.applyUnravelingRowsAbove(edit, to: pattern)
        }
        selection = nil
    }

    /// 確認（7-1）をキャンセル
    func cancelConfirmation() {
        pendingConfirmation = nil
    }

    // MARK: - 元に戻す／やり直し（tech-spec 9）

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(pattern)
        replacePattern(with: previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(pattern)
        replacePattern(with: next)
    }

    /// 編み図を変更する。変更前のコピーを履歴に積み、やり直しの履歴は捨てる
    private func mutate(_ change: (inout Pattern) -> Void) {
        let before = pattern
        var after = pattern
        change(&after)
        guard after != before else { return }
        undoStack.append(before)
        redoStack.removeAll()
        pattern = after
        recompute()
    }

    /// 元に戻す／やり直しで編み図を差し替える。先に選ぶ状態と繰り返し開始の位置はずれるので解除する
    private func replacePattern(with newPattern: Pattern) {
        pattern = newPattern
        recompute()
        modifier = .none
        repeatStartIndex = nil
        selection = nil
    }

    /// 展開結果とレイアウトを計算し直す
    private func recompute() {
        expansion = pattern.expanded()
        layout = pattern.circularLayout(expansion: expansion)
    }
}
