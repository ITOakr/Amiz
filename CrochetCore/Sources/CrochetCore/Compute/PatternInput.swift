import Foundation

/// キーボードの操作を編み図の変更に変換する純粋な関数（ui-spec 5-6、domain-spec 5・6・7・15・17）。
///
/// 入力中の段は `Pattern.rows` の最後の段。「段を終える」で次の空の段を追加する。
/// 元に戻すや先に選ぶ状態の保持は画面側（EditorModel）が行い、ここでは `Pattern` の変更だけを扱う。
public enum PatternInput {
    /// 目ボタンを押す。先に選ぶ状態を適用した操作を入力中の段の末尾に追加する。
    /// その段でまだ鎖以外の目がなく、鎖以外の目を押したときは、段の先頭に立ち上がりを自動で入れる（ui-spec 5-6 U5）。
    /// `turningChainCounted` は自動で入れる立ち上がりを1目と数えるか（nil なら標準。domain-spec 6）
    /// - Returns: 立ち上がりを自動で入れたか（繰り返し開始の位置をずらすために使う）
    @discardableResult
    public static func addStitch(
        _ kind: StitchKind,
        modifier: StitchModifier = .none,
        autoTurningChain: Bool = true,
        turningChainCounted: Bool? = nil,
        to pattern: inout Pattern
    ) -> Bool {
        let index = ensureCurrentRow(in: &pattern)
        var row = pattern.rows[index]
        let result = insertStitch(
            kind, modifier: modifier, at: row.steps.count, in: &row,
            method: pattern.method, autoTurningChain: autoTurningChain, turningChainCounted: turningChainCounted,
            yarnID: pattern.currentYarnID
        )
        pattern.rows[index] = row
        return result.insertedTurningChain
    }

    /// 「ピコット」ボタン：入力中の段の末尾にピコットを付ける。直前に目がなければ何もしない（domain-spec 21）
    /// - Returns: 付けたか
    @discardableResult
    public static func addPicot(chains: Int = 3, to pattern: inout Pattern) -> Bool {
        let index = ensureCurrentRow(in: &pattern)
        var row = pattern.rows[index]
        guard insertPicot(chains: chains, at: row.steps.count, in: &row, yarnID: pattern.currentYarnID) else { return false }
        pattern.rows[index] = row
        return true
    }

    /// いまピコットを付けられるか（入力中の段の末尾に目があるか）
    public static func canAddPicot(in pattern: Pattern) -> Bool {
        guard let index = pattern.currentRowIndex else { return false }
        return canInsertPicot(at: pattern.rows[index].steps.count, in: pattern.rows[index])
    }

    /// 糸を持ち替える（ui-spec U17）。これから編む目はこの糸になる。リストにない糸なら何もしない
    /// - Returns: 持ち替えたか
    @discardableResult
    public static func changeYarn(to yarnID: UUID?, in pattern: inout Pattern) -> Bool {
        if let yarnID, !pattern.yarns.contains(where: { $0.id == yarnID }) { return false }
        pattern.currentYarnID = yarnID
        return true
    }

    /// 目ボタンを押したときに、入力中の段の先頭に立ち上がりが自動で入るなら、その鎖の目数を返す（入らなければ nil）。
    /// 「毎回選択」の設定で、入れる前に数えるかを聞くために使う（ui-spec 5-6）
    public static func turningChainToInsert(for kind: StitchKind, autoTurningChain: Bool = true, in pattern: Pattern) -> Int? {
        let row = pattern.currentRowIndex.map { pattern.rows[$0] } ?? Row()
        return turningChainToInsert(for: kind, in: row, method: pattern.method, autoTurningChain: autoTurningChain)
    }

    /// 「飛ばす」。前段の目が残っていなければ何もしない（ui-spec 5-5）
    /// - Returns: 飛ばしたか
    @discardableResult
    public static func addSkip(to pattern: inout Pattern) -> Bool {
        let index = ensureCurrentRow(in: &pattern)
        if let unpicked = pattern.expanded().rows[index].unpickedCount, unpicked == 0 {
            return false
        }
        pattern.rows[index].steps.append(.skip())
        return true
    }

    /// 「残りは編まない」（domain-spec 23）
    public static func addLeaveRemaining(to pattern: inout Pattern) {
        let index = ensureCurrentRow(in: &pattern)
        insertLeaveRemaining(at: pattern.rows[index].steps.count, in: &pattern.rows[index])
    }

    /// 「1目削除」：直前の1操作を消す。繰り返しなら丸ごと消す（ui-spec 5-6）。
    /// 入力中の段が空なら、直前の「段を終える」を取り消す（空の段を消し、前の段の段を閉じる引き抜きを外す）。
    /// - Returns: 何かを消したか
    @discardableResult
    public static func deleteLastStep(from pattern: inout Pattern) -> Bool {
        guard let index = pattern.currentRowIndex else { return false }

        if !pattern.rows[index].steps.isEmpty {
            pattern.rows[index].steps.removeLast()
            return true
        }

        // 空の段：前の段があれば「段を終える」を取り消す
        guard index > 0 else { return false }
        pattern.rows.removeLast()
        if case .closeRound = pattern.rows[index - 1].steps.last?.kind {
            pattern.rows[index - 1].steps.removeLast()
        }
        return true
    }

    /// 「段を終える」：輪編みなら段を閉じる引き抜きを入れ（domain-spec 7）、次の空の段を追加する
    public static func finishRow(of pattern: inout Pattern) {
        let index = ensureCurrentRow(in: &pattern)
        if pattern.method.closesRound, !endsWithCloseRound(pattern.rows[index]) {
            pattern.rows[index].steps.append(Step.closeRound().withYarn(pattern.currentYarnID))
        }
        pattern.rows.append(Row())
    }

    /// 「繰り返し終了」：入力中の段の `startIndex` 番目以降の操作を1つの繰り返しにまとめる（domain-spec 15）。
    /// 先頭の立ち上がりは繰り返しに含めない。単位が空、繰り返しを含む（入れ子）、
    /// 「段の終わりまで」なのに単位が前段を拾わない場合は何もしない。
    /// - Returns: まとめたか
    @discardableResult
    public static func wrapRepeat(from startIndex: Int, count: RepeatCount, in pattern: inout Pattern) -> Bool {
        guard let index = pattern.currentRowIndex else { return false }
        return wrapRepeat(max(0, startIndex)..<pattern.rows[index].steps.count, count: count, in: &pattern.rows[index])
    }

    /// 「立ち上がり」ボタン：段の先頭に立ち上がりを入れる。すでにあれば鎖の目数を変える（ui-spec 5-6 U23）。
    /// `counted` は1目と数えるか（nil なら標準）。螺旋編みでは何もしない
    /// - Returns: 新しく先頭に入れたか（目数の変更や何もしなかったときは false）
    @discardableResult
    public static func setTurningChain(chains: Int, counted: Bool? = nil, in pattern: inout Pattern) -> Bool {
        guard pattern.method.usesTurningChain, (1...4).contains(chains) else { return false }
        let index = ensureCurrentRow(in: &pattern)
        let step = Step.turningChain(chains, counted: counted)

        if case .turningChain = pattern.rows[index].steps.first?.kind {
            let first = pattern.rows[index].steps[0]
            pattern.rows[index].steps[0] = Step(id: first.id, kind: step.kind, yarnID: first.yarnID)
            return false
        }
        pattern.rows[index].steps.insert(step.withYarn(pattern.currentYarnID), at: 0)
        return true
    }

    /// 最後の段が閉じている（段を閉じる引き抜きで終わっている）なら、続きを入力するための空の段を足す。
    /// 「上の段をほどく」や段の削除で、終わった段が最後になったときに使う
    /// - Returns: 足したか
    @discardableResult
    public static func ensureOpenRow(in pattern: inout Pattern) -> Bool {
        guard let last = pattern.rows.last, case .closeRound = last.steps.last?.kind else { return false }
        pattern.rows.append(Row())
        return true
    }

    /// 「段の終わりまで」を選べる単位か（前段を1目以上拾う。domain-spec 17）
    public static func canRepeatUntilEnd(unit: [Step]) -> Bool {
        Expander.picksPerIteration(of: unit) > 0
    }

    // MARK: - 補助

    /// 入力中の段の位置。段がなければ作る
    @discardableResult
    public static func ensureCurrentRow(in pattern: inout Pattern) -> Int {
        if pattern.rows.isEmpty {
            pattern.rows.append(Row())
        }
        return pattern.rows.count - 1
    }

    private static func endsWithCloseRound(_ row: Row) -> Bool {
        if case .closeRound = row.steps.last?.kind { true } else { false }
    }

}

extension Pattern {
    /// 入力中の段の位置（最後の段）。段がなければ nil
    public var currentRowIndex: Int? {
        rows.isEmpty ? nil : rows.count - 1
    }
}
