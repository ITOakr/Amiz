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
    /// 先に選ぶボタンの状態（状態 S2）
    private(set) var modifier = StitchModifier.none
    /// 「繰り返し開始」を押した位置（入力中の段の操作数）。押していなければ nil
    private(set) var repeatStartIndex: Int?
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var autoTurningChain = true

    private var undoStack: [Pattern] = []
    private var redoStack: [Pattern] = []

    init(pattern: Pattern) {
        self.pattern = pattern
        self.expansion = pattern.expanded()
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

    /// 直前に編んだ操作の表記（「現在の段」に並べる。ui-spec 5-5）
    func recentStepLabels(count: Int) -> [String] {
        currentRowSteps.suffix(count).map(StitchTableFormatter.label)
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

    /// 目ボタン。先に選ぶ状態を適用して1操作追加し、状態を解除する
    func pressStitch(_ kind: StitchKind) {
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
        expansion = after.expanded()
    }

    /// 元に戻す／やり直しで編み図を差し替える。先に選ぶ状態と繰り返し開始の位置はずれるので解除する
    private func replacePattern(with newPattern: Pattern) {
        pattern = newPattern
        expansion = newPattern.expanded()
        modifier = .none
        repeatStartIndex = nil
    }
}
