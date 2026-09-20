import Foundation

/// 段の手順を1目ずつの列に展開する（domain-spec 15・17・21）。
///
/// 前段の目を先頭から順に「拾って」いくカーソルを進めながら、操作を1つずつ目に変換する。
public enum Expander {
    /// 編み図全体を展開する。各段の「前段の目数」は、直前の段の展開結果（合計目数）から決める
    public static func expand(_ pattern: Pattern) -> PatternExpansion {
        var rows: [RowExpansion] = []
        var previousCount = initialPreviousCount(for: pattern.foundation)

        for row in pattern.rows {
            let expansion = expand(row: row, previousCount: previousCount)
            rows.append(expansion)
            previousCount = expansion.totalCount
        }

        return PatternExpansion(rows: rows)
    }

    /// 1段を展開する
    /// - Parameters:
    ///   - row: 段
    ///   - previousCount: 前段の目数。わの作り目に編み入れる1段目は nil
    public static func expand(row: Row, previousCount: Int?) -> RowExpansion {
        var state = State(rowID: row.id, previousCount: previousCount)
        expand(steps: row.steps, repetition: 0, state: &state)

        return RowExpansion(
            rowID: row.id,
            stitches: state.stitches,
            pickedCount: state.cursor,
            previousCount: previousCount,
            leavesRemaining: state.leavesRemaining,
            repeatCounts: state.repeatCounts,
            issues: state.issues
        )
    }

    /// 1段目の「前段の目数」（domain-spec 33）
    static func initialPreviousCount(for foundation: FoundationKind) -> Int? {
        switch foundation {
        case .magicRing: nil
        case .chain(let stitchCount): stitchCount
        }
    }

    // MARK: - 展開の状態

    private struct State {
        let rowID: UUID
        let previousCount: Int?
        /// 前段の次に拾う目の位置
        var cursor = 0
        var stitches: [ExpandedStitch] = []
        var leavesRemaining = false
        var repeatCounts: [UUID: Int] = [:]
        var issues: [RowExpansion.Issue] = []

        init(rowID: UUID, previousCount: Int?) {
            self.rowID = rowID
            self.previousCount = previousCount
        }

        /// 前段の目を count 目拾い、カーソルを進める
        mutating func pick(_ count: Int) -> Range<Int> {
            let range = cursor..<(cursor + count)
            cursor += count
            return range
        }

        func ref(_ step: Step, repetition: Int, ordinal: Int = 0) -> StitchRef {
            StitchRef(rowID: rowID, stepID: step.id, repetition: repetition, ordinal: ordinal)
        }
    }

    private static func expand(steps: [Step], repetition: Int, state: inout State) {
        for step in steps {
            expand(step: step, repetition: repetition, state: &state)
        }
    }

    private static func expand(step: Step, repetition: Int, state: inout State) {
        switch step.kind {
        case .turningChain(let chains, let counted):
            // 1目と数える立ち上がりは前段の1目を拾う。数えないなら拾わない（domain-spec 6・21）
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: .chain,
                role: .turningChain(chains: chains),
                picks: counted ? state.pick(1) : state.pick(0),
                isCounted: counted
            ))

        case .stitch(let kind, let into):
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: kind,
                into: into,
                picks: state.pick(kind.takesPreviousStitch ? 1 : 0),
                isCounted: true
            ))

        case .increase(let kind, let count, let into):
            // 同じ編み入れ先に count 目編む（domain-spec 2）
            let picks = state.pick(kind.takesPreviousStitch ? 1 : 0)
            for ordinal in 0..<count {
                state.stitches.append(ExpandedStitch(
                    ref: state.ref(step, repetition: repetition, ordinal: ordinal),
                    kind: kind,
                    into: into,
                    picks: picks,
                    isCounted: true
                ))
            }

        case .decrease(let kind, let count):
            // 前段の count 目をまとめて1目にする（domain-spec 2）
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: kind,
                picks: state.pick(count),
                isCounted: true
            ))

        case .skip:
            _ = state.pick(1)

        case .leaveRemaining:
            state.leavesRemaining = true

        case .closeRound:
            // 今の段の1目めに引き抜く。前段は拾わず、目数にも数えない（domain-spec 7）
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: .slipStitch,
                role: .closingSlipStitch,
                picks: state.pick(0),
                isCounted: false
            ))

        case .repeatGroup(let unit, let count):
            let times = iterations(of: unit, count: count, step: step, state: &state)
            state.repeatCounts[step.id] = times
            for repetition in 0..<times {
                expand(steps: unit, repetition: repetition, state: &state)
            }
        }
    }

    /// 繰り返しの実際の回数を決める（domain-spec 17）
    private static func iterations(of unit: [Step], count: RepeatCount, step: Step, state: inout State) -> Int {
        switch count {
        case .times(let times):
            return max(0, times)

        case .untilEnd:
            // 単位を最後まで編める回数だけ繰り返す。余った前段の目は拾わずに残す
            let unitPicks = picksPerIteration(of: unit)
            guard unitPicks > 0 else {
                state.issues.append(.untilEndUnitPicksNothing(stepID: step.id))
                return 0
            }
            guard let previousCount = state.previousCount else {
                state.issues.append(.untilEndWithoutPreviousCount(stepID: step.id))
                return 0
            }
            let remaining = max(0, previousCount - state.cursor)
            return remaining / unitPicks
        }
    }

    /// 単位を1回編むと前段を何目拾うか（domain-spec 21 の表）
    static func picksPerIteration(of steps: [Step]) -> Int {
        steps.reduce(0) { total, step in
            switch step.kind {
            case .turningChain(_, let counted):
                total + (counted ? 1 : 0)
            case .stitch(let kind, _), .increase(let kind, _, _):
                total + (kind.takesPreviousStitch ? 1 : 0)
            case .decrease(_, let count):
                total + count
            case .skip:
                total + 1
            case .leaveRemaining, .closeRound:
                total
            case .repeatGroup(let unit, let count):
                // 入れ子は使わない前提だが、回数固定なら計算できる。「段の終わりまで」の入れ子は 0 とみなす
                switch count {
                case .times(let times): total + times * picksPerIteration(of: unit)
                case .untilEnd: total
                }
            }
        }
    }
}

extension Pattern {
    /// 編み図全体を展開する（`Expander.expand(_:)` の省略形）
    public func expanded() -> PatternExpansion {
        Expander.expand(self)
    }
}
