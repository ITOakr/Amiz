import CoreGraphics
import Foundation
import Testing
@testable import CrochetCore

/// 平面図のレイアウト（tech-spec 8-2、domain-spec 9・21）
@Suite("平面図のレイアウト（往復編み）")
struct FlatLayoutTests {
    private func heads(_ layout: ChartLayout, row: Int) -> [LaidOutStitch] {
        layout.stitches.filter { $0.rowIndex == row && $0.countedIndex != nil }
    }

    @Test("作り目の鎖は x = 0…19 で横一列に並び、1段目の目はその真上に右から左へ並ぶ")
    func foundationAndFirstRow() {
        let layout = TestPatterns.tc9(rows: 1).flatLayout()
        #expect(layout.foundationChain.count == 20)
        #expect(layout.foundationChain.map(\.head.x) == (0..<20).map { CGFloat($0) })
        #expect(layout.foundationChain.allSatisfy { $0.head.y > 0 && $0.head.y < 1 })  // 1段目の根元（y = 0）の少し下
        // 鎖1目は左（根元）から右（頭）へ1目ぶん寝ている
        #expect(layout.foundationChain.allSatisfy { $0.head.x - $0.root.x == 1 && $0.head.y == $0.root.y })
        #expect(layout.rings.isEmpty && layout.bands.count == 1)

        let row1 = heads(layout, row: 0)
        #expect(row1.count == 20)
        // 入力中の段（最後の段）：前段の真上。最初の細編みは作り目の右端（x = 19）
        #expect(abs(row1[0].head.x - 19) < 0.001 && abs(row1[19].head.x - 0) < 0.001)
        #expect(row1.allSatisfy { abs($0.head.y - (-1)) < 0.001 })
        #expect(row1[0].bases == [CGPoint(x: 19, y: 0)])
        #expect(layout.bands[0].direction == -1)
        #expect(abs(layout.bands[0].seamX - 19.5) < 0.001)

        // 数えない立ち上がりは右端（始まりの端の少し外）に立つ
        let turningChain = layout.stitches.first { $0.rowIndex == 0 && $0.countedIndex == nil }!
        #expect(turningChain.role == .turningChain(chains: 1))
        #expect(abs(turningChain.head.x - 19.8) < 0.001)
        #expect(turningChain.head.y < 0 && turningChain.bases[0].y == 0)
    }

    @Test("段ごとに向きが反転し、段の高さが累計される（細編み1、長編み3、中長編み2）")
    func alternatingDirectionAndHeights() {
        let layout = TestPatterns.tc9().flatLayout()
        #expect(layout.bands.map(\.direction) == [-1, 1, -1, 1, -1, 1])
        #expect(layout.bands.map(\.baseY) == [0, -1, -4, -5, -7, -8])
        #expect(layout.bands.map(\.topY) == [-1, -4, -5, -7, -8, -11])

        // 2段目（左から右）：立ち上がり鎖3目は左端で、1段目の最後の目（x = 0）の上
        let row2 = heads(layout, row: 1)
        #expect(row2[0].role == .turningChain(chains: 3))
        #expect(abs(row2[0].head.x - 0) < 0.001)
        #expect(row2[0].bases == [CGPoint(x: 0, y: -1)])
        #expect(abs(row2[19].head.x - 19) < 0.001)
        #expect(layout.bands[1].seamX < row2[0].head.x)
        // 段番号側（始まりの端）は左
        #expect(abs(layout.bands[1].seamX - (-0.5)) < 0.001)
    }

    @Test("増し目は根元を共有して頭が広がり、減らし目は根元の中間に頭が来る。終わった段は等間隔")
    func increasesAndDecreases() {
        let layout = TestPatterns.tc9().flatLayout()

        // 3段目（右から左、22目）：最初の2目が増し目。根元は2段目の右端（x = 19）
        let row3 = heads(layout, row: 2)
        #expect(row3.count == 22)
        #expect(row3[0].bases == row3[1].bases)
        #expect(row3[0].sharedBaseCount == 2)
        #expect(abs(row3[0].bases[0].x - 19) < 0.001)
        for (a, b) in zip(row3, row3.dropFirst()) {
            #expect(abs((a.head.x - b.head.x) - 1) < 0.001)  // 等間隔・右から左
        }
        // 頭と根元のずれの平均は 0（両端で1目ずつ増えるので、並びは前段の半目ぶん外に広がる）
        let shifts = row3.compactMap { stitch -> Double? in
            guard !stitch.bases.isEmpty else { return nil }
            let meanBase = stitch.bases.map(\.x).reduce(0, +) / Double(stitch.bases.count)
            return Double(stitch.head.x) - Double(meanBase)
        }
        #expect(abs(shifts.reduce(0, +) / Double(shifts.count)) < 0.001)

        // 5段目（右から左、20目）：最初が減らし目。根元は4段目の右端2目（21・20）で、頭はその中間
        let row5 = heads(layout, row: 4)
        #expect(row5[0].bases.count == 2)
        let baseMid = (row5[0].bases[0].x + row5[0].bases[1].x) / 2
        #expect(abs(row5[0].head.x - baseMid) <= 0.5 + 0.001)  // 両端で1目ずつ減るので、端は半目ぶん内側に寄る
    }

    @Test("入力中の段：拾った前段の目の真上に置き、まだ拾っていない目の上は空く")
    func inProgressRowFollowsBases() {
        var pattern = TestPatterns.tc9(rows: 1)
        pattern.rows.append(Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 5)))
        let layout = pattern.flatLayout()
        let row1 = heads(layout, row: 0)
        let row2 = heads(layout, row: 1)
        // 1段目は終わった段なので等間隔（右から左）。2段目は左から右で、1段目の最後の目（x = 0）から
        #expect(abs(row1[19].head.x - 0) < 0.001)
        #expect(row2.count == 6)
        #expect(row2.map { Int(($0.head.x).rounded()) } == [0, 1, 2, 3, 4, 5])
        #expect(row2[5].bases == [CGPoint(x: 5, y: -1)])

        // 次に拾う目（前段の番号 14）は x = 5 の隣（x = 6）
        let next = layout.countedStitch(rowIndex: 0, countedIndex: pattern.expanded().rows[1].nextPickIndex!)!
        #expect(abs(next.head.x - 6) < 0.001)
    }

    @Test("鎖は前後の目の間に横たわり、外接矩形は作り目と段番号のぶんを含む")
    func chainsAndBounds() {
        var pattern = TestPatterns.tc9(rows: 1)
        pattern.rows.append(Row(steps: [.turningChain(1), .stitch(.singleCrochet), .stitch(.chain), .stitch(.chain), .stitch(.singleCrochet)]))
        let layout = pattern.flatLayout()
        let row2 = heads(layout, row: 1)
        let chains = row2.filter { $0.kind == .chain && $0.role == .regular }
        #expect(chains.count == 2)
        #expect(chains.allSatisfy { $0.bases.isEmpty && abs($0.angle) < 0.001 })  // 左から右へ横たわる
        #expect(row2[0].head.x < chains[0].head.x && chains[0].head.x < chains[1].head.x && chains[1].head.x < row2[3].head.x)

        #expect(layout.bounds.minX < -0.5 && layout.bounds.maxX > 19.5)
        #expect(layout.bounds.minY < -2 && layout.bounds.maxY > 0)
    }

    @Test("chartLayout は編み方で切り替わる：往復編みは平面図、輪編みは円形図")
    func chartLayoutDispatch() {
        #expect(TestPatterns.tc9().chartLayout().bands.count == 6)
        #expect(TestPatterns.tc9().chartLayout().rings.isEmpty)
        #expect(TestPatterns.tc1().chartLayout().rings.count == 5)
        #expect(TestPatterns.tc1().chartLayout().bands.isEmpty)
        #expect(TestPatterns.tc8().chartLayout().rings.count == 12)
    }
}
