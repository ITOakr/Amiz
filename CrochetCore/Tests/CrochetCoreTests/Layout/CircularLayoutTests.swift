import CoreGraphics
import Foundation
import Testing
@testable import CrochetCore

@Suite("円形図のレイアウト（tech-spec 8-1）")
struct CircularLayoutTests {
    private let twoPi = 2 * Double.pi

    /// 角度を 0 ≦ θ < 2π に正規化する
    private func normalized(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: twoPi)
        if value < 0 { value += twoPi }
        return value
    }

    /// 角度の差を −π < d ≦ π に折り返す（円周上の近さを測る）
    private func wrapped(_ angle: Double) -> Double {
        var value = normalized(angle)
        if value > Double.pi { value -= twoPi }
        return value
    }

    /// 2つの角度が円周上でほぼ同じか
    private func sameAngle(_ a: Double, _ b: Double) -> Bool {
        abs(wrapped(a - b)) < 1e-9
    }

    /// 段の数える目（数える目の順）
    private func countedStitches(of layout: ChartLayout, row: Int) -> [LaidOutStitch] {
        layout.stitches.filter { $0.rowIndex == row && $0.countedIndex != nil }
    }

    @Test("TC-1：各段の数える目の頭は編む順に等間隔で1周し、段の半径は単調に増える")
    func tc1HeadsAndRings() {
        let layout = TestPatterns.tc1().circularLayout()
        let expectedCounts = [6, 12, 18, 24, 24]

        for (row, count) in expectedCounts.enumerated() {
            let stitches = countedStitches(of: layout, row: row)
            #expect(stitches.count == count, "\(row + 1)段目の目数")

            // 隣り合う頭の角度差はすべて 2π/n
            let step = twoPi / Double(count)
            for pair in zip(stitches, stitches.dropFirst()) {
                let difference = normalized(pair.1.polarAngle - pair.0.polarAngle)
                #expect(abs(difference - step) < 1e-9, "\(row + 1)段目の頭の間隔")
            }
            // 頭はすべて段の外側の半径にある
            #expect(stitches.allSatisfy { abs($0.polarRadius - layout.rings[row].outerRadius) < 1e-9 })
        }

        // 段の半径：細編みの段は高さ 1 ずつ積み上がる
        for (ring, expected) in zip(layout.rings, [0.8, 1.8, 2.8, 3.8, 4.8]) {
            #expect(abs(ring.innerRadius - expected) < 1e-9)
            #expect(abs(ring.outerRadius - expected - 1) < 1e-9)
        }
        #expect(abs(layout.bounds.width - (5.8 + 1.5) * 2) < 1e-9)
    }

    @Test("TC-1 2段目：増し目の2目は根元を共有し、頭が根元の左右に対称に広がる")
    func increaseSharesBase() {
        let layout = TestPatterns.tc1().circularLayout()
        let row2 = countedStitches(of: layout, row: 1)

        for pairIndex in 0..<6 {
            let first = row2[pairIndex * 2]
            let second = row2[pairIndex * 2 + 1]
            #expect(first.bases.count == 1)
            #expect(first.bases == second.bases, "増し目の2目は同じ根元")

            // 根元は前段の目の頭の角度にある
            let previous = layout.countedStitch(rowIndex: 0, countedIndex: pairIndex)!
            let base = first.bases[0]
            let baseAngle = atan2(-Double(base.y), Double(base.x))
            #expect(sameAngle(baseAngle, previous.polarAngle))

            // 頭は根元の角度の前後に半歩ずつ（V字が左右対称）
            let step = twoPi / 12
            #expect(sameAngle(first.polarAngle, previous.polarAngle - step / 2))
            #expect(sameAngle(second.polarAngle, previous.polarAngle + step / 2))
        }
    }

    @Test("増減なしの段では、頭と根元の角度が一致して放射状になる")
    func unchangedRowIsRadial() {
        let layout = TestPatterns.tc1().circularLayout()
        let row5 = countedStitches(of: layout, row: 4)
        for stitch in row5 {
            let base = stitch.bases[0]
            let baseAngle = atan2(-Double(base.y), Double(base.x))
            #expect(sameAngle(stitch.polarAngle, baseAngle))
            // 向きは根元→頭（外向き）：頭の位置ベクトルと同じ方向
            let outward = atan2(Double(stitch.head.y), Double(stitch.head.x))
            #expect(sameAngle(stitch.angle, outward))
        }
    }

    @Test("n目一度は根元が n 個で頭が1つ。鎖は根元がなく接線方向を向く")
    func decreaseAndChain() {
        let pattern = TestPatterns.afterRound(of: 6, row: Row(steps: [
            .turningChain(1),
            .decrease(.singleCrochet, count: 2),
            .stitch(.chain),
            .decrease(.singleCrochet, count: 3),
            .closeRound(),
        ]))
        let layout = pattern.circularLayout()
        let row2 = countedStitches(of: layout, row: 1)

        #expect(row2.map(\.bases.count) == [2, 0, 3])
        let chain = row2[1]
        #expect(chain.kind == .chain)
        // 接線方向：頭の位置ベクトルと直交する
        let radial = atan2(Double(chain.head.y), Double(chain.head.x))
        #expect(abs(abs(wrapped(chain.angle - radial)) - Double.pi / 2) < 1e-9)
    }

    @Test("長編みの段は高さ3で、立ち上がり鎖3目は数える目として頭を持つ")
    func doubleCrochetRow() {
        let layout = TestPatterns.tc3().circularLayout()
        #expect(layout.rings[1].outerRadius - layout.rings[1].innerRadius == 3)

        let row2 = countedStitches(of: layout, row: 1)
        #expect(row2.count == 12)
        #expect(row2[0].role == .turningChain(chains: 3))
        #expect(row2[0].height == 3)
        #expect(row2[0].bases.count == 1)
    }

    @Test("数えない立ち上がりは最初の目の半歩手前、段を閉じる引き抜きは最後の目の半歩後ろ")
    func uncountedPositions() {
        let layout = TestPatterns.tc1().circularLayout()
        let row1 = layout.stitches.filter { $0.rowIndex == 0 }
        let step = twoPi / 6

        let turningChain = row1.first!
        #expect(turningChain.countedIndex == nil)
        #expect(sameAngle(turningChain.polarAngle, row1[1].polarAngle - step / 2))

        let closing = row1.last!
        #expect(closing.role == .closingSlipStitch)
        #expect(closing.bases.isEmpty)
        #expect(sameAngle(closing.polarAngle, row1[6].polarAngle + step / 2))
    }

    @Test("検索：StitchRef から、（段, 数える目の位置）から、一番近い位置から")
    func lookups() {
        let pattern = TestPatterns.tc1()
        let layout = pattern.circularLayout()

        // 3段目の繰り返し2回目の増し目の2目め
        let increaseStep = { () -> Step in
            if case .repeatGroup(let unit, _) = pattern.rows[2].steps[1].kind { return unit[1] }
            fatalError()
        }()
        let ref = StitchRef(rowID: pattern.rows[2].id, stepID: increaseStep.id, repetition: 1, ordinal: 1)
        let found = layout.stitch(for: ref)
        #expect(found?.rowIndex == 2)
        #expect(found?.countedIndex == 5)  // (細編み, 増し目×2) × 2回目 → 3 + 2 = 5番目（0始まり）

        // ハイライト用：1段目の3番目の目
        let third = layout.countedStitch(rowIndex: 0, countedIndex: 2)
        #expect(third?.ref.ordinal == 0)
        #expect(sameAngle(third!.polarAngle, twoPi / 6 * 2))

        // 一番近い目：頭の少しそばの点から探す
        let nearest = layout.nearestStitch(to: CGPoint(x: third!.head.x + 0.1, y: third!.head.y - 0.1))
        #expect(nearest?.ref == third?.ref)
        #expect(layout.nearestStitch(to: CGPoint(x: 100, y: 100), maxDistance: 1) == nil)
    }

    @Test("空の段（入力中）でも輪が作られ、拾いすぎても壊れない")
    func edgeCases() {
        var pattern = TestPatterns.tc1()
        pattern.rows.append(Row())
        let layout = pattern.circularLayout()
        #expect(layout.rings.count == 6)
        #expect(layout.rings[5].outerRadius == layout.rings[5].innerRadius + 1)

        let over = TestPatterns.afterRound(of: 3, row: Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 5) + [.closeRound()]))
        let overLayout = over.circularLayout()
        #expect(countedStitches(of: overLayout, row: 1).count == 5)
    }
}
