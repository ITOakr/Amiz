import Foundation

/// 段の「指定した位置」への入力（ui-spec U16 過去の段の編集で使う）。
///
/// `PatternInput` の入力中の段への操作は、すべて「最後の段の末尾」への入力なので、
/// ここにある段＋位置を指定する関数の特別な場合として扱える。
extension PatternInput {
    /// 段の `index` の位置に目を入れる。先に選ぶ状態を適用し、その段にまだ鎖以外の目がなければ立ち上がりを先頭に自動で入れる
    /// - Returns: 入れた操作の数（立ち上がりが自動で入れば 2、そうでなければ 1）。入れた後の入力位置は `index + 戻り値`。
    ///   ただし立ち上がりは先頭に入るので、`index` より前に1つ増える
    @discardableResult
    public static func insertStitch(
        _ kind: StitchKind,
        modifier: StitchModifier = .none,
        at index: Int,
        in row: inout Row,
        method: WorkingMethod,
        autoTurningChain: Bool = true
    ) -> (insertedTurningChain: Bool, stepIndex: Int) {
        var step = modifier.step(for: kind)
        if case .repeatGroup(let unit, .untilEnd) = step.kind, !canRepeatUntilEnd(unit: unit) {
            step = unit[0]
        }

        var insertedTurningChain = false
        var position = min(max(index, 0), row.steps.count)
        if autoTurningChain, method.usesTurningChain, kind != .chain,
           !hasNonChainStitch(row), let chains = kind.defaultTurningChains {
            row.steps.insert(.turningChain(chains), at: 0)
            insertedTurningChain = true
            position += 1
        }
        row.steps.insert(step, at: position)
        return (insertedTurningChain, position)
    }

    /// 段の `index` の位置に「飛ばす」を入れる
    public static func insertSkip(at index: Int, in row: inout Row) {
        row.steps.insert(.skip(), at: min(max(index, 0), row.steps.count))
    }

    /// 段の `index` の位置に「残りは編まない」を入れる
    public static func insertLeaveRemaining(at index: Int, in row: inout Row) {
        row.steps.insert(.leaveRemaining(), at: min(max(index, 0), row.steps.count))
    }

    /// 入力位置の直前の操作を消す（繰り返しなら丸ごと）。段を閉じる引き抜きは消さない
    /// - Returns: 消したか
    @discardableResult
    public static func deleteStep(before index: Int, in row: inout Row) -> Bool {
        let position = index - 1
        guard row.steps.indices.contains(position) else { return false }
        if case .closeRound = row.steps[position].kind { return false }
        row.steps.remove(at: position)
        return true
    }

    /// `range` の操作を1つの繰り返しにまとめる（先頭の立ち上がりは含めない）。条件は `wrapRepeat(from:count:in:)` と同じ
    /// - Returns: まとめたか
    @discardableResult
    public static func wrapRepeat(_ range: Range<Int>, count: RepeatCount, in row: inout Row) -> Bool {
        var start = max(0, range.lowerBound)
        let end = min(range.upperBound, row.steps.count)
        if start == 0, case .turningChain = row.steps.first?.kind {
            start = 1
        }
        guard start < end else { return false }

        let unit = Array(row.steps[start..<end])
        guard unit.allSatisfy(canBeInRepeatUnit) else { return false }
        if case .untilEnd = count, !canRepeatUntilEnd(unit: unit) {
            return false
        }
        row.steps.replaceSubrange(start..<end, with: [Step(kind: .repeatGroup(unit: unit, count: count))])
        return true
    }

    /// 段に鎖以外の目（または立ち上がり）がすでにあるか
    static func hasNonChainStitch(_ row: Row) -> Bool {
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

    /// 繰り返しの単位に入れられる操作か（立ち上がり・段を閉じる引き抜き・残りは編まない・入れ子は不可）
    static func canBeInRepeatUnit(_ step: Step) -> Bool {
        switch step.kind {
        case .stitch, .increase, .decrease, .skip: true
        case .turningChain, .closeRound, .leaveRemaining, .repeatGroup: false
        }
    }
}
