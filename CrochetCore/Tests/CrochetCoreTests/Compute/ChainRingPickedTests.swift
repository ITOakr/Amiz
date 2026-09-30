import CoreGraphics
import Foundation
import Testing
@testable import CrochetCore

/// 鎖を輪にして、鎖を1目ずつ拾う筒状の編み始め（domain-spec 33。AMIZ-79）
@Suite("鎖を輪にして1目ずつ拾う")
struct ChainRingPickedTests {
    private let twoPi = 2 * Double.pi

    /// 鎖12目を輪にして、1段目「立ち上がり鎖1目、細編み12目、引き抜き」
    private func tube(stitchCount: Int = 12, rowStitches: Int = 12, method: WorkingMethod = .joinedRounds) -> Pattern {
        Pattern(method: method, foundation: .chain(stitchCount: stitchCount), rows: [
            Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, rowStitches) + [.closeRound()]),
        ])
    }

    @Test("1段目は作り目の鎖を1目ずつ拾い、目数が数えられる")
    func firstRowPicksEachChain() {
        let expansion = tube().expanded()

        #expect(expansion.rows.count == 1)
        // 立ち上がりの鎖1目は数えない（標準）ので、細編み12目で12目
        #expect(expansion.rows[0].totalCount == 12)
        #expect(expansion.rows[0].pickedCount == 12, "作り目の12目をすべて拾う")
        #expect(expansion.rows[0].previousCount == 12, "前段の目数は鎖の目数")
    }

    @Test("前段の目数として整合性チェックが働く（わの作り目と違って対象になる）")
    func firstRowIsChecked() {
        // 鎖12目に対して細編み10目しか編まない
        let warnings = tube(stitchCount: 12, rowStitches: 10).expanded().warnings()

        #expect(warnings.map(\.rowNumber) == [1])
        #expect(warnings.first?.message == "前段12目のうち10目しか拾っていません")

        // ちょうど拾えば警告なし
        #expect(tube().expanded().warnings().isEmpty)
    }

    @Test("螺旋編みでも同じように拾える")
    func spiral() {
        let pattern = Pattern(method: .spiral, foundation: .chain(stitchCount: 12), rows: [
            Row(steps: TestPatterns.stitches(.singleCrochet, 12)),
        ])
        #expect(pattern.expanded().rows[0].totalCount == 12)
        #expect(pattern.expanded().warnings().isEmpty)
    }

    @Test("実際に編む鎖の目数は n 目ちょうど（立ち上がりを足さない）")
    func foundationChainCount() {
        // 輪にする場合：立ち上がりは輪にしたあとに編むので作り目に含まれない
        #expect(StitchTableFormatter.foundationChainCount(for: tube()) == 12)
        #expect(StitchTableFormatter.foundationText(for: tube()) == "作り目：鎖12目を輪にする")

        // 長編みの段でも変わらない
        let doubleCrochet = Pattern(method: .joinedRounds, foundation: .chain(stitchCount: 12), rows: [
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 11) + [.closeRound()]),
        ])
        #expect(StitchTableFormatter.foundationChainCount(for: doubleCrochet) == 12)

        // 往復編みは今までどおり、立ち上がりを含めて数える（domain-spec 33）
        let flat = Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: [
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 19)),
        ])
        #expect(StitchTableFormatter.foundationChainCount(for: flat) == 22)
        #expect(StitchTableFormatter.foundationText(for: flat) == "作り目：鎖22目")
    }

    // MARK: - 円形図

    @Test("作り目の鎖が一番内側の輪に並び、1段目の根元がその鎖の上にある")
    func chartPutsRootsOnTheChains() {
        let layout = tube().circularLayout()
        let hole = layout.rings[0].innerRadius

        // 作り目の鎖12目が輪の上に並ぶ
        #expect(layout.foundationChain.count == 12)
        #expect(abs(hole - 12 / twoPi) < 1e-9, "穴の半径は鎖12目ぶんの円")

        let row1 = layout.stitches.filter { $0.rowIndex == 0 && $0.countedIndex != nil }
        #expect(row1.count == 12)

        // 根元は輪の上（作り目の鎖の角度）にあり、1点に集まらない
        for stitch in row1 {
            #expect(stitch.bases.count == 1)
            #expect(abs(hypot(stitch.bases[0].x, stitch.bases[0].y) - hole) < 1e-9)
        }
        let rootAngles = row1.map { atan2(-Double($0.bases[0].y), Double($0.bases[0].x)) }
        let chainAngles = layout.foundationChain.map { atan2(-Double($0.head.y), Double($0.head.x)) }
        for angle in rootAngles {
            #expect(chainAngles.contains { abs(wrapped($0 - angle)) < 1e-9 }, "根元が作り目の鎖の真上にある")
        }
    }

    @Test("同じ鎖に2目編み入れると、根元を共有して頭が広がる")
    func increaseSharesTheSameChain() {
        // 鎖6目を輪にして、すべての鎖に細編み2目ずつ（12目）
        let pattern = Pattern(method: .joinedRounds, foundation: .chain(stitchCount: 6), rows: [
            Row(steps: [.turningChain(1), .untilEnd([.increase(.singleCrochet)]), .closeRound()]),
        ])
        #expect(pattern.expanded().rows[0].totalCount == 12)

        let layout = pattern.circularLayout()
        let row1 = layout.stitches.filter { $0.rowIndex == 0 && $0.countedIndex != nil }
        #expect(row1.count == 12)

        // 2目ずつが同じ根元を共有する（増し目の V字。domain-spec 11）
        let roots = Set(row1.map { "\($0.bases[0].x),\($0.bases[0].y)" })
        #expect(roots.count == 6, "根元は鎖6目ぶん")
        #expect(row1.allSatisfy { $0.sharedBaseCount == 2 })
    }

    /// 角度の差を −π < d ≦ π に折り返す
    private func wrapped(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: twoPi)
        if value < 0 { value += twoPi }
        if value > Double.pi { value -= twoPi }
        return value
    }
}
