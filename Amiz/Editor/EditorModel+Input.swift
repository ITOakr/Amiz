import Foundation
import Observation
import CrochetCore

/// `EditorModel` の編み目キーボードの入力（ui-spec 5-6）：目ボタン・先に選ぶ・段の操作。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    /// 目ボタン。選択中なら選択した目の種類を変える（U15）。そうでなければ先に選ぶ状態を適用して1操作追加し、状態を解除する。
    /// 立ち上がりが自動で入る目で、設定が「毎回選択」なら、数えるかを聞いてから入れる（7-4）。色編集モード中は何もしない
    func pressStitch(_ kind: StitchKind) {
        guard !isColorEditing else { return }
        if selection != nil {
            modifier = .none
            request(.changeKind(kind))
            return
        }
        var turningChainCounted: Bool?
        if let chains = turningChainToInsert(for: kind) {
            guard let counted = turningChainCounting.resolve(chains: chains) else {
                pendingTurningChainQuestion = TurningChainQuestion(chains: chains, action: .stitch(kind, modifier))
                return
            }
            turningChainCounted = counted
        }
        insertStitch(kind, modifier: modifier, turningChainCounted: turningChainCounted)
    }

    /// 目を入れる（先に選ぶ状態は解除する）。`turningChainCounted` は自動で入る立ち上がりを数えるか
    private func insertStitch(_ kind: StitchKind, modifier: StitchModifier, turningChainCounted: Bool?) {
        self.modifier = .none
        if editingSession != nil {
            editRow { session, method in
                let result = PatternInput.insertStitch(
                    kind, modifier: modifier, at: session.cursor, in: &session.row,
                    method: method, autoTurningChain: autoTurningChain, turningChainCounted: turningChainCounted
                )
                session.cursor = result.stepIndex + 1
                if result.insertedTurningChain, let start = session.repeatStartIndex {
                    session.repeatStartIndex = start + 1
                }
            }
            return
        }
        mutate { pattern in
            let inserted = PatternInput.addStitch(
                kind, modifier: modifier, autoTurningChain: autoTurningChain, turningChainCounted: turningChainCounted, to: &pattern
            )
            // 立ち上がりが先頭に入ると、繰り返し開始の位置が1つ後ろにずれる
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }

    /// この目を押すと立ち上がりが自動で入るなら、その鎖の目数
    private func turningChainToInsert(for kind: StitchKind) -> Int? {
        if let session = editingSession {
            return PatternInput.turningChainToInsert(for: kind, in: session.row, method: pattern.method, autoTurningChain: autoTurningChain)
        }
        return PatternInput.turningChainToInsert(for: kind, autoTurningChain: autoTurningChain, in: pattern)
    }

    /// 7-4 の答え：数える（true）／数えない（false）。聞いたときの操作を続ける
    func answerTurningChainQuestion(counted: Bool) {
        guard let question = pendingTurningChainQuestion else { return }
        pendingTurningChainQuestion = nil
        switch question.action {
        case .stitch(let kind, let modifier):
            insertStitch(kind, modifier: modifier, turningChainCounted: counted)
        case .turningChain:
            setTurningChain(chains: question.chains, counted: counted)
        }
    }

    /// 7-4 をキャンセル。目は入れない（先に選ぶ状態はそのまま）
    func cancelTurningChainQuestion() {
        pendingTurningChainQuestion = nil
    }

    func toggleIncrease() { modifier.toggleIncrease() }
    func toggleDecrease() { modifier.toggleDecrease() }
    func toggleCluster() { modifier.toggleCluster() }
    func toggleChainSpace() { modifier.toggleChainSpace() }
    func toggleUntilEnd() { modifier.toggleUntilEnd() }

    /// 「ピコット」：直前の目にピコットを付ける（domain-spec 3・21）。付けられないときは何もしない
    func pressPicot(chains: Int = 3) {
        guard !isColorEditing else { return }
        modifier = .none
        if editingSession != nil {
            editRow { session, _ in
                if PatternInput.insertPicot(chains: chains, at: session.cursor, in: &session.row, yarnID: pattern.currentYarnID) {
                    session.cursor += 1
                }
            }
            return
        }
        mutate { pattern in
            PatternInput.addPicot(chains: chains, to: &pattern)
        }
    }

    /// いまピコットを付けられるか（直前に目があるか）
    var canAddPicot: Bool {
        if let session = editingSession {
            return PatternInput.canInsertPicot(at: session.cursor, in: session.row)
        }
        return PatternInput.canAddPicot(in: pattern)
    }

    /// 「飛ばす」（選択状態にならず、押すたびに1目飛ばす）
    func pressSkip() {
        if editingSession != nil {
            editRow { session, _ in
                PatternInput.insertSkip(at: session.cursor, in: &session.row)
                session.cursor += 1
            }
            return
        }
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

    /// 「1目削除」。編集中は入力位置の直前を消す
    func pressDeleteLast() {
        modifier = .none
        if editingSession != nil {
            editRow { session, _ in
                if PatternInput.deleteStep(before: session.cursor, in: &session.row) {
                    session.cursor -= 1
                    if let start = session.repeatStartIndex, start > session.cursor {
                        session.repeatStartIndex = nil
                    }
                }
            }
            return
        }
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
        guard editingSession == nil else { return }
        modifier = .none
        repeatStartIndex = nil
        mutate { pattern in
            if leavingRemaining {
                PatternInput.addLeaveRemaining(to: &pattern)
            }
            PatternInput.finishRow(of: &pattern)
        }
    }

    /// 「繰り返し開始」：今の段の操作数を覚える（段がまだなければ 0）。編集中は入力位置を覚える
    func pressBeginRepeat() {
        if editingSession != nil {
            editingSession?.repeatStartIndex = editingSession?.cursor
            return
        }
        repeatStartIndex = pattern.rows.last?.steps.count ?? 0
    }

    /// 「繰り返し終了」。回数を指定してまとめる
    /// - Returns: まとめられたか（単位が空などのときは false で、開始位置は残る）
    @discardableResult
    func pressEndRepeat(count: RepeatCount) -> Bool {
        if let session = editingSession, let start = session.repeatStartIndex {
            var wrapped = false
            editRow { session, _ in
                let before = session.row.steps.count
                wrapped = PatternInput.wrapRepeat(start..<session.cursor, count: count, in: &session.row)
                if wrapped {
                    session.cursor -= before - session.row.steps.count
                    session.repeatStartIndex = nil
                }
            }
            return wrapped
        }
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
        editingSession?.repeatStartIndex = nil
    }

    /// 「立ち上がり」ボタン（U23）。設定が「毎回選択」なら数えるかを聞いてから入れる（7-4）
    func pressTurningChain(chains: Int) {
        guard let counted = turningChainCounting.resolve(chains: chains) else {
            pendingTurningChainQuestion = TurningChainQuestion(chains: chains, action: .turningChain)
            return
        }
        setTurningChain(chains: chains, counted: counted)
    }

    private func setTurningChain(chains: Int, counted: Bool) {
        mutate { pattern in
            let inserted = PatternInput.setTurningChain(chains: chains, counted: counted, in: &pattern)
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }
}
