import Foundation

/// 段の手順を1目ずつの列に展開する（domain-spec 15・17・21）。
///
/// 前段の目を先頭から順に「拾って」いくカーソルを進めながら、操作を1つずつ目に変換する。
public enum Expander {
    /// 編み図全体を展開する。各段の「前段の目数」は、直前の段の展開結果（合計目数）から決める
    public static func expand(_ pattern: Pattern) -> PatternExpansion {
        var rows: [RowExpansion] = []
        var previousCount = initialPreviousCount(for: pattern.foundation)
        // 前段の数える目が鎖かどうか（編んだ順）。束に編み入れるアーチの検出に使う。作り目の鎖は目として扱い、アーチにはしない
        var previousIsChain: [Bool]? = previousCount.map { [Bool](repeating: false, count: $0) }

        let reversed = pattern.method.picksPreviousRowReversed
        for row in pattern.rows {
            let expansion = expand(row: row, previousCount: previousCount, picksReversed: reversed, previousIsChain: previousIsChain)
            rows.append(expansion)
            previousCount = expansion.totalCount
            previousIsChain = expansion.stitches.filter(\.isCounted).map(\.isChainSpaceLink)
        }

        return PatternExpansion(rows: rows)
    }

    /// 1段を展開する
    /// - Parameters:
    ///   - row: 段
    ///   - previousCount: 前段の目数。わの作り目に編み入れる1段目は nil
    ///   - picksReversed: 前段を逆順に拾うか（往復編み）
    ///   - previousIsChain: 前段の数える目が鎖かどうか（編んだ順。束に編み入れるアーチの検出に使う）。省略すると鎖はないものとする
    public static func expand(
        row: Row, previousCount: Int?, picksReversed: Bool = false, previousIsChain: [Bool]? = nil
    ) -> RowExpansion {
        var state = State(
            rowID: row.id, previousCount: previousCount, picksReversed: picksReversed,
            previousIsChain: previousIsChain ?? previousCount.map { [Bool](repeating: false, count: $0) }
        )
        expand(steps: row.steps, repetition: 0, state: &state)

        return RowExpansion(
            rowID: row.id,
            stitches: state.stitches,
            pickedCount: state.cursor,
            previousCount: previousCount,
            leavesRemaining: state.leavesRemaining,
            repeatCounts: state.repeatCounts,
            issues: state.issues,
            picksReversed: picksReversed
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
        /// 前段を逆順に拾うか（往復編み）。前段の目数が決まらない段では順方向と同じ
        let picksReversed: Bool
        /// 前段の数える目が鎖かどうか（編んだ順）。前段の目数が決まらない段では nil
        let previousIsChain: [Bool]?
        /// 前段から拾った数（拾う順のカーソル）
        var cursor = 0
        var stitches: [ExpandedStitch] = []
        var leavesRemaining = false
        var repeatCounts: [UUID: Int] = [:]
        var issues: [RowExpansion.Issue] = []

        init(rowID: UUID, previousCount: Int?, picksReversed: Bool = false, previousIsChain: [Bool]? = nil) {
            self.rowID = rowID
            self.previousCount = previousCount
            self.picksReversed = picksReversed
            self.previousIsChain = previousIsChain
        }

        /// 拾う順での位置を、前段の編んだ順の番号にする
        private func creationIndex(atPickPosition position: Int) -> Int {
            if picksReversed, let previousCount { previousCount - 1 - position } else { position }
        }

        /// 束に編み入れる：次の鎖のアーチ（連続する鎖のまとまり）まで進み、その鎖をまとめて拾う（domain-spec 21）。
        /// 間の鎖でない目は飛ばした扱いになる。アーチが残っていなければ nil（カーソルは動かさない）
        mutating func pickChainSpace() -> Range<Int>? {
            guard let previousCount, let isChain = previousIsChain else { return nil }
            var position = cursor
            while position < previousCount, !isChain[creationIndex(atPickPosition: position)] {
                position += 1
            }
            guard position < previousCount else { return nil }
            let start = position
            while position < previousCount, isChain[creationIndex(atPickPosition: position)] {
                position += 1
            }
            cursor = position
            let first = creationIndex(atPickPosition: start)
            let last = creationIndex(atPickPosition: position - 1)
            return min(first, last)..<(max(first, last) + 1)
        }

        /// 編み入れ先に応じて前段を拾う。束なら次のアーチ、そうでなければ1目（前段を拾わない目は 0）
        mutating func pick(for kind: StitchKind, into placement: Placement, step: Step) -> Range<Int> {
            guard kind.takesPreviousStitch else { return pick(0) }
            guard placement == .chainSpace else { return pick(1) }
            if let arch = pickChainSpace() { return arch }
            issues.append(.noChainSpaceAhead(stepID: step.id))
            return pick(0)
        }

        /// 前段の目を count 目拾い、カーソルを進める。返すのは前段の編んだ順での番号。
        /// 逆順に拾う段では前段の最後の目から下がっていく（拾いすぎると負の番号になる）
        mutating func pick(_ count: Int) -> Range<Int> {
            let range: Range<Int>
            if picksReversed, let previousCount {
                let end = previousCount - cursor
                range = (end - count)..<end
            } else {
                range = cursor..<(cursor + count)
            }
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
                isCounted: counted,
                yarnID: step.yarnID
            ))

        case .stitch(let kind, let into):
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: kind,
                into: into,
                picks: state.pick(for: kind, into: into, step: step),
                isCounted: true,
                yarnID: step.yarnID
            ))

        case .increase(let kind, let count, let into):
            // 同じ編み入れ先に count 目編む（domain-spec 2）
            let picks = state.pick(for: kind, into: into, step: step)
            for ordinal in 0..<count {
                state.stitches.append(ExpandedStitch(
                    ref: state.ref(step, repetition: repetition, ordinal: ordinal),
                    kind: kind,
                    into: into,
                    picks: picks,
                    isCounted: true,
                    yarnID: step.yarnID
                ))
            }

        case .decrease(let kind, let count):
            // 前段の count 目をまとめて1目にする（domain-spec 2）
            state.stitches.append(ExpandedStitch(
                ref: state.ref(step, repetition: repetition),
                kind: kind,
                picks: state.pick(count),
                isCounted: true,
                yarnID: step.yarnID
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
                isCounted: false,
                yarnID: step.yarnID
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
            // 単位がまだ収まる間だけ繰り返す（余った前段の目は拾わずに残す）。
            // 拾う数が一定の単位なら「残り ÷ 1回の拾う数」と同じ。束を含む単位は拾う数が一定でないので、試しに展開して確かめる
            guard picksPerIteration(of: unit) > 0 else {
                state.issues.append(.untilEndUnitPicksNothing(stepID: step.id))
                return 0
            }
            guard let previousCount = state.previousCount else {
                state.issues.append(.untilEndWithoutPreviousCount(stepID: step.id))
                return 0
            }
            var times = 0
            var trial = state
            while times < previousCount {
                var probe = trial
                let cursorBefore = probe.cursor
                expand(steps: unit, repetition: times, state: &probe)
                // 前段を拾いすぎず、前に進み、問題（アーチがない等）が増えなければ、この1回は収まる
                guard probe.cursor <= previousCount, probe.cursor > cursorBefore, probe.issues.count == trial.issues.count else { break }
                trial = probe
                times += 1
            }
            return times
        }
    }

    /// 単位を1回編むと前段を何目拾うか（domain-spec 21 の表）。束に編み入れる目はアーチの大きさで変わるので 1 と見なす
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
