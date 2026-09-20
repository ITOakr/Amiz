import Foundation
import Testing
@testable import CrochetCore

/// 螺旋編み（domain-spec 5、TC-8）
@Suite("螺旋編み（TC-8）")
struct SpiralTests {
    @Test("TC-8 うさぎの胴体：立ち上がりなしで前段の目数がそのまま分母になり、警告は出ない")
    func tc8Counts() {
        let expansion = TestPatterns.tc8().expanded()
        #expect(expansion.rows.map(\.totalCount) == [6, 12, 18, 24, 30, 30, 30, 30, 30, 24, 18, 12])
        #expect(expansion.rows.map(\.previousCount) == [nil, 6, 12, 18, 24, 30, 30, 30, 30, 30, 24, 18])
        #expect(expansion.rows.dropFirst().allSatisfy { $0.pickedCount == $0.previousCount })
        #expect(expansion.warnings().isEmpty)
        // 立ち上がりも引き抜きもない
        #expect(expansion.rows.allSatisfy { row in row.stitches.allSatisfy { $0.role == .regular } })
    }

    @Test("「段を終える」で引き抜きは入らず、次の段は空で始まる")
    func finishRowAddsNothing() {
        var pattern = Pattern(method: .spiral, foundation: .magicRing)
        for _ in 0..<6 { PatternInput.addStitch(.singleCrochet, to: &pattern) }
        PatternInput.finishRow(of: &pattern)
        #expect(pattern.rows.count == 2)
        #expect(pattern.rows[0].steps.count == 6)
        #expect(pattern.rows[0].steps.allSatisfy { $0.kind == .stitch(.singleCrochet) })
        #expect(pattern.rows[1].steps.isEmpty)
    }

    @Test("立ち上がりは自動で入らず、「立ち上がり」の操作も何もしない")
    func noTurningChain() {
        var pattern = Pattern(method: .spiral, foundation: .magicRing)
        for _ in 0..<6 { PatternInput.addStitch(.singleCrochet, to: &pattern) }
        PatternInput.finishRow(of: &pattern)
        #expect(PatternInput.turningChainToInsert(for: .doubleCrochet, in: pattern) == nil)
        PatternInput.addStitch(.doubleCrochet, to: &pattern)
        #expect(pattern.rows[1].steps.map(\.kind) == [.stitch(.doubleCrochet)])

        #expect(PatternInput.setTurningChain(chains: 3, in: &pattern) == false)
        #expect(PatternInput.setTurningChain(chains: 3, rowID: pattern.rows[1].id, in: &pattern) == false)
        #expect(pattern.rows[1].steps.count == 1)
    }

    @Test("警告は輪編みと同じ：拾い残しと拾いすぎ")
    func warnings() {
        var pattern = TestPatterns.tc8(rows: 2)  // 6目、12目
        pattern.rows.append(Row(steps: TestPatterns.stitches(.singleCrochet, 10)))
        pattern.rows.append(Row(steps: TestPatterns.stitches(.singleCrochet, 11)))
        let warnings = pattern.expanded().warnings()
        #expect(warnings.map(\.rowNumber) == [3, 4])
        #expect(warnings[0].message == "前段12目のうち10目しか拾っていません")
        #expect(warnings[1].message == "前段10目に対して11目拾っています")
    }

    @Test("目数表：1段目は「わの作り目に細編み6目」、6〜9段目は1行にまとまる")
    func table() {
        let pattern = TestPatterns.tc8()
        let expansion = pattern.expanded()
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion)
        #expect(rows.map(\.rowNumberText) == ["1段目", "2段目", "3段目", "4段目", "5段目", "6〜9段目", "10段目", "11段目", "12段目"])
        #expect(rows[0].instruction == "わの作り目に細編み6目")
        #expect(rows[1].instruction == "細編み2目編み入れる×全目")
        #expect(rows[5].instruction == "残りの目すべてに細編み")
        #expect(rows[5].countText == "30目" && rows[5].isUnchangedRun)
        #expect(rows[6].instruction == "（細編み3目、細編み2目一度）×6")
        #expect(rows[8].countText == "12目")
    }

    @Test("図：段ごとに輪が重なり、各段の目が円周に等間隔で並ぶ")
    func layout() {
        let layout = TestPatterns.tc8().circularLayout()
        #expect(layout.rings.count == 12)
        #expect(layout.stitches.filter { $0.rowIndex == 4 && $0.countedIndex != nil }.count == 30)
        // 12段目の12目は 30° 間隔
        let heads = layout.stitches.filter { $0.rowIndex == 11 }.map {
            atan2(-($0.head.y - layout.center.y), $0.head.x - layout.center.x)
        }
        #expect(heads.count == 12)
        for (a, b) in zip(heads, heads.dropFirst()) {
            var diff = b - a
            while diff < 0 { diff += 2 * .pi }
            #expect(abs(diff - .pi / 6) < 0.001)
        }
    }
}
