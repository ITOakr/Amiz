import Foundation
import Testing
@testable import CrochetCore

/// 往復編み（domain-spec 5・21・33、TC-7・TC-9）
@Suite("往復編み（TC-9）")
struct FlatTests {
    @Test("TC-9 ブランケットの縁：目数と前段の目数、警告なし")
    func tc9Counts() {
        let expansion = TestPatterns.tc9().expanded()
        #expect(expansion.rows.map(\.totalCount) == [20, 20, 22, 22, 20, 20])
        #expect(expansion.rows.map(\.previousCount) == [20, 20, 20, 22, 22, 20])
        #expect(expansion.rows.allSatisfy { $0.pickedCount == $0.previousCount })
        #expect(expansion.warnings().isEmpty)
        #expect(expansion.rows.allSatisfy { $0.picksReversed })
        // 引き抜きはない。立ち上がりは1・3・5段目が数えない鎖1目、2・6段目が鎖3目、4段目が鎖2目
        #expect(expansion.rows.allSatisfy { row in !row.stitches.contains { $0.role == .closingSlipStitch } })
        #expect(expansion.rows.map { $0.stitches[0].isCounted } == [false, true, false, true, false, true])
    }

    @Test("作り目の行：1段目が細編みなら鎖21目（TC-7）")
    func foundationRow() {
        let pattern = TestPatterns.tc9()
        #expect(StitchTableFormatter.foundationText(for: pattern) == "作り目：鎖21目")
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: pattern.expanded())
        #expect(rows.map(\.instruction) == [
            "作り目に細編み20目",
            "立ち上がり鎖3目、長編み19目",
            "細編み2目編み入れる、細編み18目、細編み2目編み入れる",
            "立ち上がり鎖2目、中長編み21目",
            "細編み2目一度、細編み18目、細編み2目一度",
            "立ち上がり鎖3目、長編み19目",
        ])
        #expect(rows.map(\.countText) == ["20目", "20目", "22目", "22目", "20目", "20目"])
    }

    @Test("前段を逆順に拾う：2段目の立ち上がりは1段目の最後の目に、長編みは19目め→1目めの順に入る")
    func picksReversed() {
        let expansion = TestPatterns.tc9().expanded()
        let row2 = expansion.rows[1].stitches
        #expect(row2[0].role == .turningChain(chains: 3))
        #expect(row2[0].picks == 19..<20)
        #expect(row2[1].picks == 18..<19)
        #expect(row2[19].picks == 0..<1)

        // 3段目：最初の増し目は2段目の最後の長編み（19）に、最後の増し目は2段目の立ち上がり（0）に
        let row3 = expansion.rows[2].stitches
        #expect(row3[0].picks.isEmpty)  // 数えない立ち上がり
        #expect(row3[1].picks == 19..<20 && row3[2].picks == 19..<20)
        #expect(row3[21].picks == 0..<1 && row3[22].picks == 0..<1)

        // 5段目：最初の減らし目は4段目の 21・20 目め、最後の減らし目は 1・0 目め
        let row5 = expansion.rows[4].stitches
        #expect(row5[1].picks == 20..<22)
        #expect(row5[20].picks == 0..<2)
    }

    @Test("次に拾う目：往復編みでは前段の最後から下がっていき、拾い切ると nil")
    func nextPickIndex() {
        var pattern = TestPatterns.tc9(rows: 1)
        pattern.rows.append(Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 5)))
        let row = pattern.expanded().rows[1]
        #expect(row.pickedCount == 6)
        #expect(row.nextPickIndex == 13)  // 20 - 1 - 6

        // 輪編みは順方向
        let round = TestPatterns.tc2AfterKeepingRowsAbove().expanded().rows[1]
        #expect(round.nextPickIndex == nil || round.nextPickIndex == round.pickedCount)
        var bear = TestPatterns.tc1()
        bear.rows[1] = Row(steps: [.turningChain(1), .stitch(.singleCrochet)])
        #expect(bear.expanded().rows[1].nextPickIndex == 1)

        // 拾い切った段は nil、拾いすぎても nil。1段目（わの作り目）は nil
        #expect(TestPatterns.tc9().expanded().rows[1].nextPickIndex == nil)
        #expect(TestPatterns.tc1().expanded().rows[0].nextPickIndex == nil)
    }

    @Test("拾いすぎると番号が負になる（図では前段の始まりの先に置く）")
    func overpickGoesNegative() {
        var pattern = TestPatterns.tc9(rows: 1)
        pattern.rows.append(Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 21)))
        let row = pattern.expanded().rows[1]
        #expect(row.stitches.last?.picks == (-1)..<0)
        #expect(pattern.expanded().warnings().map(\.message) == ["前段20目に対して21目拾っています"])
    }

    @Test("入力：往復編みの「段を終える」は引き抜きを入れず、立ち上がりは目の種類に応じて自動で入る")
    func input() {
        var pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20))
        for _ in 0..<20 { PatternInput.addStitch(.singleCrochet, to: &pattern) }
        PatternInput.finishRow(of: &pattern)
        #expect(pattern.rows[0].steps.count == 21)
        #expect(pattern.rows[0].steps.first?.kind == .turningChain(chains: 1))
        #expect(pattern.rows[0].steps.last?.kind == .stitch(.singleCrochet))
        PatternInput.addStitch(.doubleCrochet, to: &pattern)
        #expect(pattern.rows[1].steps.map(\.kind) == [.turningChain(chains: 3), .stitch(.doubleCrochet)])
        #expect(pattern.expanded().rows[1].nextPickIndex == 17)  // 立ち上がり（数える）と長編みで2目拾った
    }
}
