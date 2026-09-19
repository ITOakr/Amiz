import Testing
@testable import CrochetCore

@Suite("整合性チェック（domain-spec 23）")
struct ConsistencyCheckerTests {
    @Test("TC-1 は警告なし")
    func tc1HasNoWarnings() {
        #expect(TestPatterns.tc1().expanded().warnings().isEmpty)
    }

    @Test("TC-2 1段目を7目にして「上の段を残す」：3段目だけに警告")
    func tc2() {
        let pattern = TestPatterns.tc2AfterKeepingRowsAbove()
        let expansion = pattern.expanded()

        // 目数：2段目は「全目に」なので自動追従、3段目以降は固定回数のまま
        #expect(expansion.rows.map(\.totalCount) == [7, 14, 18, 24, 24])

        let warnings = expansion.warnings()
        #expect(warnings.count == 1)
        #expect(warnings.first?.rowNumber == 3)
        #expect(warnings.first?.rowID == pattern.rows[2].id)
        #expect(warnings.first?.kind == .shortage(previousCount: 14, pickedCount: 12))
        #expect(warnings.first?.message == "前段14目のうち12目しか拾っていません")
    }

    @Test("TC-6 そのまま終えると不足の警告、「残りは編まない」を付けると警告なし")
    func tc6() {
        let warnings = TestPatterns.tc6().expanded().warnings()
        #expect(warnings.map(\.message) == ["前段13目のうち12目しか拾っていません"])

        #expect(TestPatterns.tc6(leaveRemaining: true).expanded().warnings().isEmpty)
    }

    @Test("拾いすぎた段にも警告を出す")
    func excess() {
        // 前段6目に細編み7目
        let pattern = TestPatterns.afterRound(of: 6, row: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.closeRound()]
        ))
        let warnings = pattern.expanded().warnings()

        #expect(warnings.count == 1)
        #expect(warnings.first?.rowNumber == 2)
        #expect(warnings.first?.kind == .excess(previousCount: 6, pickedCount: 7))
        #expect(warnings.first?.message == "前段6目に対して7目拾っています")
    }

    @Test("「残りは編まない」があっても拾いすぎは警告する")
    func excessWithLeaveRemaining() {
        let pattern = TestPatterns.afterRound(of: 6, row: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.leaveRemaining(), .closeRound()]
        ))
        #expect(pattern.expanded().warnings().map(\.kind) == [.excess(previousCount: 6, pickedCount: 7)])
    }

    @Test("入力中の段は除外できる")
    func excludeRowInProgress() {
        // 前段6目に対して、まだ3目しか編んでいない段
        let pattern = TestPatterns.afterRound(of: 6, row: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 3)
        ))
        let expansion = pattern.expanded()

        #expect(expansion.warnings().count == 1)
        #expect(expansion.warnings(excludingRowAt: 1).isEmpty)
    }

    @Test("わの作り目の1段目は何目でも警告しない")
    func magicRingFirstRow() {
        for count in [1, 6, 12] {
            let pattern = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
                Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, count) + [.closeRound()]),
            ])
            #expect(pattern.expanded().warnings().isEmpty)
        }
    }

    @Test("鎖の作り目の1段目は「1段目に編む目数」と比べる")
    func chainFoundationFirstRow() {
        let pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: [
            Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 18)),
        ])
        #expect(pattern.expanded().warnings().map(\.message) == ["前段20目のうち18目しか拾っていません"])
    }
}
