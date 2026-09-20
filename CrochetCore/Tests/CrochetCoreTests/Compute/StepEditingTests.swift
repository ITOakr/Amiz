import Testing
@testable import CrochetCore

@Suite("選択した目の編集（ui-spec U15、domain-spec 15）")
struct StepEditingTests {
    /// TC-1 の3段目の繰り返しの中の細編み（1目め）を指す
    private func refToRow3FirstStitch(in pattern: Pattern) -> StitchRef {
        guard case .repeatGroup(let unit, _) = pattern.rows[2].steps[1].kind else { fatalError() }
        return StitchRef(rowID: pattern.rows[2].id, stepID: unit[0].id, repetition: 2, ordinal: 0)
    }

    @Test("場所の検索：段の直下の操作と、繰り返しの単位の中の操作")
    func locate() {
        let pattern = TestPatterns.tc1()
        let turningChain = StitchRef(rowID: pattern.rows[0].id, stepID: pattern.rows[0].steps[0].id)
        #expect(PatternInput.locate(turningChain, in: pattern) == PatternInput.StepLocation(rowIndex: 0, stepIndex: 0, unitIndex: nil))

        let inside = refToRow3FirstStitch(in: pattern)
        #expect(PatternInput.locate(inside, in: pattern) == PatternInput.StepLocation(rowIndex: 2, stepIndex: 1, unitIndex: 0))

        let unknown = StitchRef(rowID: pattern.rows[0].id, stepID: pattern.rows[1].steps[0].id)
        #expect(PatternInput.locate(unknown, in: pattern) == nil)
    }

    @Test("種類の変更：繰り返しの中の目を変えるとすべての回に反映され、目数は変わらない（TC-5）")
    func changeKindInsideRepeat() {
        var pattern = TestPatterns.tc1()
        let ref = refToRow3FirstStitch(in: pattern)
        #expect(PatternInput.changeStitchKind(at: ref, to: .halfDoubleCrochet, in: &pattern))

        let expansion = pattern.expanded()
        #expect(expansion.rows.map(\.totalCount) == [6, 12, 18, 24, 24])
        #expect(expansion.warnings().isEmpty)
        let kinds = Set(expansion.rows[2].stitches.filter { $0.role == .regular }.map(\.kind))
        #expect(kinds == [.halfDoubleCrochet, .singleCrochet])  // 単位の1目めが中長編み、増し目は細編みのまま
        #expect(expansion.rows[2].stitches.filter { $0.kind == .halfDoubleCrochet }.count == 6)
    }

    @Test("種類の変更：増し目・減らし目は目数を保ち、立ち上がりや繰り返し全体には使えない")
    func changeKindRules() {
        var pattern = TestPatterns.afterRound(of: 6, row: Row(steps: [
            .turningChain(1), .increase(.singleCrochet, count: 3), .decrease(.singleCrochet), .closeRound(),
        ]))
        let rowID = pattern.rows[1].id
        let increase = StitchRef(rowID: rowID, stepID: pattern.rows[1].steps[1].id)
        let decrease = StitchRef(rowID: rowID, stepID: pattern.rows[1].steps[2].id)
        let turningChain = StitchRef(rowID: rowID, stepID: pattern.rows[1].steps[0].id)

        #expect(PatternInput.changeStitchKind(at: increase, to: .doubleCrochet, in: &pattern))
        #expect(PatternInput.changeStitchKind(at: decrease, to: .doubleCrochet, in: &pattern))
        #expect(!PatternInput.changeStitchKind(at: turningChain, to: .doubleCrochet, in: &pattern))
        #expect(pattern.rows[1].steps[1].kind == .increase(.doubleCrochet, count: 3))
        #expect(pattern.rows[1].steps[2].kind == .decrease(.doubleCrochet, count: 2))

        let repeatRef = StitchRef(rowID: TestPatterns.tc1().rows[2].id, stepID: TestPatterns.tc1().rows[2].steps[1].id)
        var tc1 = TestPatterns.tc1()
        #expect(!PatternInput.changeStitchKind(at: repeatRef, to: .doubleCrochet, in: &tc1))
    }

    @Test("削除：段の直下の目、繰り返しの中の目（全回に反映）、単位が空になれば繰り返しごと")
    func delete() {
        var pattern = TestPatterns.tc1()

        // 1段目の細編み1つを消す → 5目
        let first = StitchRef(rowID: pattern.rows[0].id, stepID: pattern.rows[0].steps[1].id)
        #expect(PatternInput.deleteStep(at: first, in: &pattern))
        #expect(pattern.expanded().rows[0].totalCount == 5)

        // 3段目の繰り返し（細編み、増し目）×6 の細編みを消す → （増し目）×6 = 12目
        let inside = refToRow3FirstStitch(in: pattern)
        #expect(PatternInput.deleteStep(at: inside, in: &pattern))
        #expect(pattern.expanded().rows[2].totalCount == 12)

        // 残った増し目も消す → 単位が空なので繰り返しごと消え、立ち上がりと引き抜きだけ残る
        guard case .repeatGroup(let unit, _) = pattern.rows[2].steps[1].kind else { Issue.record("繰り返しのはず"); return }
        let increase = StitchRef(rowID: pattern.rows[2].id, stepID: unit[0].id)
        #expect(PatternInput.deleteStep(at: increase, in: &pattern))
        #expect(pattern.rows[2].steps.map(\.kind) == [.turningChain(chains: 1), .closeRound])
    }

    @Test("繰り返しの解除：×6 は6回分に展開され、目数は変わらない")
    func unwrapTimes() {
        var pattern = TestPatterns.tc1()
        let before = pattern.expanded().rows[2]
        let ref = refToRow3FirstStitch(in: pattern)

        #expect(PatternInput.unwrapRepeat(containing: ref, in: &pattern))
        #expect(pattern.rows[2].steps.count == 1 + 12 + 1)  // 立ち上がり + (細編み, 増し目)×6 + 引き抜き
        #expect(pattern.expanded().rows[2].totalCount == before.totalCount)
        // 1回目は元の ID、2回目以降は新しい ID
        #expect(pattern.rows[2].steps[1].id == ref.stepID)
        #expect(Set(pattern.rows[2].steps.map(\.id)).count == pattern.rows[2].steps.count)
    }

    @Test("繰り返しの解除：「段の終わりまで」は今の前段の目数で決まる回数で展開し、以後は追従しない")
    func unwrapUntilEnd() {
        var pattern = TestPatterns.tc1()
        let repeatStep = pattern.rows[1].steps[1]
        let ref = StitchRef(rowID: pattern.rows[1].id, stepID: repeatStep.id)

        #expect(PatternInput.unwrapRepeat(containing: ref, in: &pattern))
        #expect(pattern.rows[1].steps.count == 1 + 6 + 1)
        #expect(pattern.expanded().rows[1].totalCount == 12)

        // 1段目を7目にしても2段目は12目のまま（追従しない）
        pattern.rows[0] = Row(id: pattern.rows[0].id, steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.closeRound()])
        #expect(pattern.expanded().rows[1].totalCount == 12)
        #expect(pattern.expanded().warnings().map(\.rowNumber) == [2])
    }

    @Test("指定した段の立ち上がりの目数を変える")
    func setTurningChainInRow() {
        var pattern = TestPatterns.tc1()
        #expect(PatternInput.setTurningChain(chains: 3, rowID: pattern.rows[2].id, in: &pattern))
        #expect(pattern.rows[2].steps[0].kind == .turningChain(chains: 3))
        // 鎖3目は1目と数えて前段を1目拾うので、3段目は19目・前段を13目拾う（警告）
        let row = pattern.expanded().rows[2]
        #expect(row.totalCount == 19)
        #expect(row.pickedCount == 13)
    }
}
