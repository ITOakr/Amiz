import Foundation

/// 選択した目（操作）に対する編集（ui-spec 5-8 U15）。入力中の段に限らず、どの段の操作にも使える純粋関数。
///
/// 目は `StitchRef`（段ID・操作ID）で指す。繰り返しの中の操作を変えると、すべての回に反映される（domain-spec 15）。
/// 目数が変わる編集を過去の段に行ったときの確認（domain-spec 25）は、呼び出し側が `PatternEditor` で行う。
extension PatternInput {
    /// 操作の場所（段の位置、段の中の位置、繰り返しの単位の中なら単位の中の位置）
    public struct StepLocation: Hashable, Sendable {
        public var rowIndex: Int
        public var stepIndex: Int
        public var unitIndex: Int?

        /// 繰り返しの中の操作か
        public var isInsideRepeat: Bool { unitIndex != nil }
    }

    /// 操作の場所を探す
    public static func locate(_ ref: StitchRef, in pattern: Pattern) -> StepLocation? {
        guard let rowIndex = pattern.rows.firstIndex(where: { $0.id == ref.rowID }) else { return nil }
        for (stepIndex, step) in pattern.rows[rowIndex].steps.enumerated() {
            if step.id == ref.stepID {
                return StepLocation(rowIndex: rowIndex, stepIndex: stepIndex, unitIndex: nil)
            }
            if case .repeatGroup(let unit, _) = step.kind,
               let unitIndex = unit.firstIndex(where: { $0.id == ref.stepID }) {
                return StepLocation(rowIndex: rowIndex, stepIndex: stepIndex, unitIndex: unitIndex)
            }
        }
        return nil
    }

    /// 場所にある操作
    public static func step(at location: StepLocation, in pattern: Pattern) -> Step? {
        guard pattern.rows.indices.contains(location.rowIndex) else { return nil }
        let steps = pattern.rows[location.rowIndex].steps
        guard steps.indices.contains(location.stepIndex) else { return nil }
        let step = steps[location.stepIndex]
        guard let unitIndex = location.unitIndex else { return step }
        guard case .repeatGroup(let unit, _) = step.kind, unit.indices.contains(unitIndex) else { return nil }
        return unit[unitIndex]
    }

    /// 目の種類を変える（種類の変更）。目数（n目編み入れる／n目一度の n）と編み入れ先はそのまま。
    /// 立ち上がり・飛ばす・残りは編まない・段を閉じる引き抜き・繰り返し全体には使えない
    /// - Returns: 変えたか
    @discardableResult
    public static func changeStitchKind(at ref: StitchRef, to kind: StitchKind, in pattern: inout Pattern) -> Bool {
        guard let location = locate(ref, in: pattern), let step = step(at: location, in: pattern) else { return false }
        let newKind: StepKind
        switch step.kind {
        case .stitch(_, let into):
            newKind = .stitch(kind, into: into)
        case .increase(_, let count, let into):
            newKind = .increase(kind, count: count, into: into)
        case .decrease(_, let count):
            newKind = .decrease(kind, count: count)
        case .turningChain, .skip, .leaveRemaining, .closeRound, .repeatGroup:
            return false
        }
        replaceStep(at: location, with: Step(id: step.id, kind: newKind), in: &pattern)
        return true
    }

    /// 操作を削除する。繰り返しの中なら単位から消える（すべての回に反映）。単位が空になれば繰り返しごと消す
    /// - Returns: 消したか
    @discardableResult
    public static func deleteStep(at ref: StitchRef, in pattern: inout Pattern) -> Bool {
        guard let location = locate(ref, in: pattern) else { return false }
        var row = pattern.rows[location.rowIndex]

        if let unitIndex = location.unitIndex {
            guard case .repeatGroup(var unit, let count) = row.steps[location.stepIndex].kind else { return false }
            unit.remove(at: unitIndex)
            if unit.isEmpty {
                row.steps.remove(at: location.stepIndex)
            } else {
                row.steps[location.stepIndex] = Step(id: row.steps[location.stepIndex].id, kind: .repeatGroup(unit: unit, count: count))
            }
        } else {
            row.steps.remove(at: location.stepIndex)
        }
        pattern.rows[location.rowIndex] = row
        return true
    }

    /// 繰り返しを解除して1目ずつに展開する（domain-spec 15）。
    /// `ref` が繰り返しの中の操作でも、繰り返し全体でもよい。
    /// 「段の終わりまで」は今の前段の目数で決まる実際の回数で展開する（以後は前段に追従しなくなる）。
    /// 1回目は元の操作の ID を保ち、2回目以降は新しい ID にする
    /// - Returns: 解除したか
    @discardableResult
    public static func unwrapRepeat(containing ref: StitchRef, in pattern: inout Pattern) -> Bool {
        guard let location = locate(ref, in: pattern) else { return false }
        let repeatStep = pattern.rows[location.rowIndex].steps[location.stepIndex]
        guard case .repeatGroup(let unit, let count) = repeatStep.kind else { return false }

        let times: Int
        switch count {
        case .times(let value):
            times = max(0, value)
        case .untilEnd:
            times = pattern.expanded().rows[location.rowIndex].repeatCounts[repeatStep.id] ?? 0
        }

        var expanded: [Step] = []
        for repetition in 0..<times {
            expanded += repetition == 0 ? unit : unit.map { $0.duplicated() }
        }
        pattern.rows[location.rowIndex].steps.replaceSubrange(location.stepIndex...location.stepIndex, with: expanded)
        return true
    }

    /// 指定した段の立ち上がりの鎖の目数を変える（なければ先頭に入れる）。螺旋編みでは何もしない
    /// - Returns: 変えたか（新しく入れた場合も true）
    @discardableResult
    public static func setTurningChain(chains: Int, rowID: UUID, in pattern: inout Pattern) -> Bool {
        guard pattern.method.usesTurningChain, (1...4).contains(chains),
              let rowIndex = pattern.rows.firstIndex(where: { $0.id == rowID }) else { return false }
        if case .turningChain = pattern.rows[rowIndex].steps.first?.kind {
            let id = pattern.rows[rowIndex].steps[0].id
            pattern.rows[rowIndex].steps[0] = Step(id: id, kind: .turningChain(chains: chains))
        } else {
            pattern.rows[rowIndex].steps.insert(.turningChain(chains), at: 0)
        }
        return true
    }

    // MARK: - 補助

    /// 場所にある操作を差し替える
    private static func replaceStep(at location: StepLocation, with newStep: Step, in pattern: inout Pattern) {
        var row = pattern.rows[location.rowIndex]
        if let unitIndex = location.unitIndex {
            guard case .repeatGroup(var unit, let count) = row.steps[location.stepIndex].kind else { return }
            unit[unitIndex] = newStep
            row.steps[location.stepIndex] = Step(id: row.steps[location.stepIndex].id, kind: .repeatGroup(unit: unit, count: count))
        } else {
            row.steps[location.stepIndex] = newStep
        }
        pattern.rows[location.rowIndex] = row
    }
}
