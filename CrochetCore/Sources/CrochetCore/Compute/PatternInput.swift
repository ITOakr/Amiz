import Foundation

/// キーボードの操作を編み図の変更に変換する純粋な関数（ui-spec 5-6、domain-spec 5・6・7・15・17）。
///
/// 入力中の段は `Pattern.rows` の最後の段。「段を終える」で次の空の段を追加する。
/// 元に戻すや先に選ぶ状態の保持は画面側（EditorModel）が行い、ここでは `Pattern` の変更だけを扱う。
public enum PatternInput {
    /// 目ボタンを押す。先に選ぶ状態を適用した操作を入力中の段の末尾に追加する。
    /// その段でまだ鎖以外の目がなく、鎖以外の目を押したときは、段の先頭に立ち上がりを自動で入れる（ui-spec 5-6 U5）。
    /// - Returns: 立ち上がりを自動で入れたか（繰り返し開始の位置をずらすために使う）
    @discardableResult
    public static func addStitch(
        _ kind: StitchKind,
        modifier: StitchModifier = .none,
        autoTurningChain: Bool = true,
        to pattern: inout Pattern
    ) -> Bool {
        let index = ensureCurrentRow(in: &pattern)
        var step = modifier.step(for: kind)

        // 「残りすべてに」は、単位が前段を1目も拾わない（鎖編みなど）なら付けられない（domain-spec 17）
        if case .repeatGroup(let unit, .untilEnd) = step.kind, !canRepeatUntilEnd(unit: unit) {
            step = unit[0]
        }

        var insertedTurningChain = false
        if autoTurningChain,
           pattern.method.usesTurningChain,
           kind != .chain,
           !hasNonChainStitch(pattern.rows[index]),
           let chains = kind.defaultTurningChains {
            pattern.rows[index].steps.insert(.turningChain(chains), at: 0)
            insertedTurningChain = true
        }

        pattern.rows[index].steps.append(step)
        return insertedTurningChain
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
        pattern.rows[index].steps.append(.leaveRemaining())
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
            pattern.rows[index].steps.append(.closeRound())
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
        var start = max(0, startIndex)
        let steps = pattern.rows[index].steps

        if start == 0, case .turningChain = steps.first?.kind {
            start = 1
        }
        guard start < steps.count else { return false }

        let unit = Array(steps[start...])
        guard unit.allSatisfy(canBeInRepeatUnit) else { return false }
        if case .untilEnd = count, !canRepeatUntilEnd(unit: unit) {
            return false
        }

        pattern.rows[index].steps.replaceSubrange(start..., with: [Step(kind: .repeatGroup(unit: unit, count: count))])
        return true
    }

    /// 「立ち上がり」ボタン：段の先頭に立ち上がりを入れる。すでにあれば鎖の目数を変える（ui-spec 5-6 U23）。
    /// 螺旋編みでは何もしない
    /// - Returns: 新しく先頭に入れたか（目数の変更や何もしなかったときは false）
    @discardableResult
    public static func setTurningChain(chains: Int, in pattern: inout Pattern) -> Bool {
        guard pattern.method.usesTurningChain, (1...4).contains(chains) else { return false }
        let index = ensureCurrentRow(in: &pattern)

        if case .turningChain = pattern.rows[index].steps.first?.kind {
            let id = pattern.rows[index].steps[0].id
            pattern.rows[index].steps[0] = Step(id: id, kind: .turningChain(chains: chains))
            return false
        }
        pattern.rows[index].steps.insert(.turningChain(chains), at: 0)
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

    /// 段に鎖以外の目（または立ち上がり）がすでにあるか
    private static func hasNonChainStitch(_ row: Row) -> Bool {
        row.steps.contains { step in
            switch step.kind {
            case .turningChain:
                true
            case .stitch(let kind, _), .increase(let kind, _, _), .decrease(let kind, _):
                kind != .chain
            case .repeatGroup(let unit, _):
                hasNonChainStitch(Row(steps: unit))
            case .skip, .leaveRemaining, .closeRound:
                false
            }
        }
    }

    private static func endsWithCloseRound(_ row: Row) -> Bool {
        if case .closeRound = row.steps.last?.kind { true } else { false }
    }

    /// 繰り返しの単位に入れられる操作か（立ち上がり・段を閉じる引き抜き・残りは編まない・入れ子は不可）
    private static func canBeInRepeatUnit(_ step: Step) -> Bool {
        switch step.kind {
        case .stitch, .increase, .decrease, .skip: true
        case .turningChain, .closeRound, .leaveRemaining, .repeatGroup: false
        }
    }
}

extension Pattern {
    /// 入力中の段の位置（最後の段）。段がなければ nil
    public var currentRowIndex: Int? {
        rows.isEmpty ? nil : rows.count - 1
    }
}
