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

    @Test("TC-1：各段の数える目の頭は編む順に進んでちょうど1周し、段の半径は単調に増える")
    func tc1HeadsAndRings() {
        let layout = TestPatterns.tc1().circularLayout()
        let expectedCounts = [6, 12, 18, 24, 24]

        for (row, count) in expectedCounts.enumerated() {
            let stitches = countedStitches(of: layout, row: row)
            #expect(stitches.count == count, "\(row + 1)段目の目数")

            // 隣り合う頭の角度差はすべて正で、1周ぶんの合計が 2π（重ならず、隙間も余りもない）
            var total = 0.0
            for pair in zip(stitches, stitches.dropFirst()) {
                let difference = normalized(pair.1.polarAngle - pair.0.polarAngle)
                #expect(difference > 1e-9 && difference < Double.pi, "\(row + 1)段目の頭の順序")
                total += difference
            }
            total += normalized(stitches.first!.polarAngle - stitches.last!.polarAngle)
            #expect(abs(total - twoPi) < 1e-9, "\(row + 1)段目は1周する")
            // 頭はすべて段の外側の半径にある
            #expect(stitches.allSatisfy { abs($0.polarRadius - layout.rings[row].outerRadius) < 1e-9 })
        }

        // 終わった段はすべて等間隔（実物の編み図と同じ）
        for (row, count) in expectedCounts.enumerated() {
            let stitches = countedStitches(of: layout, row: row)
            let step = twoPi / Double(count)
            for pair in zip(stitches, stitches.dropFirst()) {
                #expect(abs(normalized(pair.1.polarAngle - pair.0.polarAngle) - step) < 1e-9, "\(row + 1)段目は等間隔")
            }
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
            let quarter = twoPi / 12 / 2
            #expect(sameAngle(first.polarAngle, previous.polarAngle - quarter))
            #expect(sameAngle(second.polarAngle, previous.polarAngle + quarter))
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
        // 鎖1目の立ち上がりは根元寄りに短く（段の高さ 1 より低い）
        #expect(abs(turningChain.polarRadius - (layout.rings[0].innerRadius + 0.5)) < 1e-9)

        let closing = row1.last!
        #expect(closing.role == .closingSlipStitch)
        #expect(closing.bases.isEmpty)
        #expect(sameAngle(closing.polarAngle, row1[6].polarAngle + step / 2))
        // 段を閉じる引き抜きは頭の近く（立ち上がりと同じ角度でも高さで分かれる）
        #expect(abs(closing.polarRadius - (layout.rings[0].outerRadius - 0.12)) < 1e-9)
        #expect(sameAngle(layout.rings[0].seamAngle, turningChain.polarAngle))
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

    @Test("入力中の段：編んだ目は拾った前段の目の真上に置かれ、円周に散らばらない。増し目は前段1目分の幅の中で広がる")
    func rowInProgressFollowsBases() {
        // 5段目（前段24目）を「細編み4目、増し目」だけ入力した状態
        var pattern = TestPatterns.tc1()
        pattern.rows[4] = Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 4) + [.increase(.singleCrochet)])
        let layout = pattern.circularLayout()
        let row5 = countedStitches(of: layout, row: 4)
        #expect(row5.count == 6)

        for index in 0..<4 {
            let previous = layout.countedStitch(rowIndex: 3, countedIndex: index)!
            #expect(sameAngle(row5[index].polarAngle, previous.polarAngle))
        }
        let base = layout.countedStitch(rowIndex: 3, countedIndex: 4)!.polarAngle
        let quarter = twoPi / 24 / 4
        #expect(sameAngle(row5[4].polarAngle, base - quarter))
        #expect(sameAngle(row5[5].polarAngle, base + quarter))
        #expect(row5[4].sharedBaseCount == 2)
        #expect(row5[3].sharedBaseCount == 1)

        // 段を終える（閉じる）と等間隔になる
        pattern.rows[4].steps.append(.closeRound())
        let closed = countedStitches(of: pattern.circularLayout(), row: 4)
        let step = twoPi / 6
        for pair in zip(closed, closed.dropFirst()) {
            #expect(abs(normalized(pair.1.polarAngle - pair.0.polarAngle) - step) < 1e-9)
        }
    }

    @Test("鎖は前後の目の間に均等に並ぶ（長編み1目、鎖2目の繰り返し）")
    func chainsBetweenStitches() {
        let layout = TestPatterns.tc4().circularLayout()
        let row2 = countedStitches(of: layout, row: 1)
        // 立ち上がり、鎖、鎖、（長編み、鎖、鎖）×11 = 36
        #expect(row2.count == 36)
        let step = twoPi / 12
        // 立ち上がり（前段の1目め）の頭は 0、次の長編みは前段の2目め（2π/12）。間の鎖2目は3等分の位置
        #expect(sameAngle(row2[0].polarAngle, 0))
        #expect(sameAngle(row2[1].polarAngle, step / 3))
        #expect(sameAngle(row2[2].polarAngle, step * 2 / 3))
        #expect(sameAngle(row2[3].polarAngle, step))
        // 最後の鎖2目は、最後の長編みと（1周して）最初の立ち上がりの間
        #expect(sameAngle(row2[34].polarAngle, step * 11 + step / 3))
        #expect(sameAngle(row2[35].polarAngle, step * 11 + step * 2 / 3))
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

/// 束に編み入れた目の図（domain-spec 11、TC-10）
@Suite("束に編み入れた目のレイアウト")
struct ChainSpaceLayoutTests {
    @Test("円形図：束の目の根元はアーチ（鎖2目）の中央に1つ。同じアーチの3目は根元を共有して広がる")
    func circular() {
        let layout = TestPatterns.tc10().circularLayout()
        let row3 = layout.stitches.filter { $0.rowIndex == 2 && $0.role == .regular }
        #expect(row3.count == 36)
        let first = row3[0]
        #expect(first.into == .chainSpace)
        #expect(first.bases.count == 1)
        #expect(first.sharedBaseCount == 3)
        #expect(row3[1].bases == first.bases && row3[2].bases == first.bases)

        // 根元の角度は、拾った2目の鎖（前段の 1・2 目め）の中間
        let chain1 = layout.countedStitch(rowIndex: 1, countedIndex: 1)!
        let chain2 = layout.countedStitch(rowIndex: 1, countedIndex: 2)!
        let mid = CGPoint(x: (chain1.head.x + chain2.head.x) / 2, y: (chain1.head.y + chain2.head.y) / 2)
        let baseAngle = atan2(-(first.bases[0].y - layout.center.y), first.bases[0].x - layout.center.x)
        let midAngle = atan2(-(mid.y - layout.center.y), mid.x - layout.center.x)
        #expect(abs(baseAngle - midAngle) < 0.01)
        // 3目の頭は根元の周りに広がる（角度が単調に進む）
        let angles = row3.prefix(3).map { $0.polarAngle }
        #expect(angles[0] < angles[1] && angles[1] < angles[2])
    }

    @Test("平面図：束の目の根元はアーチの中央（2目の鎖の x の平均）に1つ")
    func flat() {
        var pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 10))
        pattern.rows.append(Row(steps: [
            .turningChain(3), .stitch(.chain), .stitch(.chain),
            .skip(), .skip(), .stitch(.doubleCrochet), .stitch(.chain), .stitch(.chain),
            .skip(), .skip(), .stitch(.doubleCrochet),
        ]))
        pattern.rows.append(Row(steps: [.turningChain(1), .repeating([.increase(.singleCrochet, count: 3, into: .chainSpace)], times: 2)]))
        let layout = pattern.flatLayout()
        let row2 = layout.stitches.filter { $0.rowIndex == 1 && $0.role == .regular }
        #expect(row2.count == 6)
        // 最初のアーチは前段の 4・5 目め（逆順なので最後のアーチ）。根元はその x の平均
        let chain4 = layout.countedStitch(rowIndex: 0, countedIndex: 4)!
        let chain5 = layout.countedStitch(rowIndex: 0, countedIndex: 5)!
        #expect(row2[0].bases.count == 1)
        #expect(abs(row2[0].bases[0].x - (chain4.head.x + chain5.head.x) / 2) < 0.001)
        #expect(row2[0].sharedBaseCount == 3)
    }
}

/// 入力中の段の末尾の鎖（AMIZ-58）
@Suite("入力中の段の末尾の鎖")
struct TrailingChainLayoutTests {
    @Test("段の終わりに続く鎖は、前段の1目分ずつ進めて置く（1目分に詰めて重ねない）")
    func trailingChainsSpread() {
        var pattern = TestPatterns.tc1()
        pattern.rows = Array(pattern.rows.prefix(1))  // 6目
        // 入力中：細編み1目、鎖4目（次の目はまだ）
        pattern.rows.append(Row(steps: [.turningChain(1), .stitch(.singleCrochet)] + TestPatterns.stitches(.chain, 4)))
        let layout = pattern.circularLayout()
        let chains = layout.stitches.filter { $0.rowIndex == 1 && $0.kind == .chain && $0.role == .regular }
        #expect(chains.count == 4)
        let step = 2 * Double.pi / 6  // 前段の1目分
        for (a, b) in zip(chains, chains.dropFirst()) {
            var diff = b.polarAngle - a.polarAngle
            while diff < 0 { diff += 2 * .pi }
            #expect(abs(diff - step) < 0.01)
        }
        // 閉じた段（段を終えた後）は最初の目まで均等（前段 6 目に対して 1 + 4 = 5 目なので 72° 間隔）
        pattern.rows[1].steps.append(.closeRound())
        let closed = pattern.circularLayout()
        let closedHeads = closed.stitches.filter { $0.rowIndex == 1 && $0.countedIndex != nil }
        for (a, b) in zip(closedHeads, closedHeads.dropFirst()) {
            var diff = b.polarAngle - a.polarAngle
            while diff < 0 { diff += 2 * .pi }
            #expect(abs(diff - 2 * Double.pi / 5) < 0.01)
        }
    }
}

/// 鎖を輪にした作り目（domain-spec 33、tech-spec 8-1。AMIZ-77）
@Suite("鎖を輪にした作り目のレイアウト")
struct ChainRingLayoutTests {
    private let twoPi = 2 * Double.pi

    /// 角度の差を −π < d ≦ π に折り返す
    private func wrapped(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: twoPi)
        if value < 0 { value += twoPi }
        if value > Double.pi { value -= twoPi }
        return value
    }

    private func sameAngle(_ a: Double, _ b: Double) -> Bool {
        abs(wrapped(a - b)) < 1e-9
    }

    /// 段の数える目（数える目の順）
    private func countedStitches(of layout: ChartLayout, row: Int) -> [LaidOutStitch] {
        layout.stitches.filter { $0.rowIndex == row && $0.countedIndex != nil }
    }

    /// 鎖6目を輪にして、その中に1段目「立ち上がり鎖3目、長編み15目、引き抜き」＝16目
    private func chainRingMotif(chainCount: Int = 6) -> Pattern {
        Pattern(method: .joinedRounds, foundation: .chainRing(chainCount: chainCount), rows: [
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 15) + [.closeRound()]),
        ])
    }

    @Test("輪にした鎖が一番内側の輪に等間隔で並ぶ")
    func chainRingFoundation() {
        let layout = chainRingMotif().circularLayout()
        let hole = layout.rings[0].innerRadius

        #expect(layout.foundationChain.count == 6)
        // すべて穴の輪の上にある
        for link in layout.foundationChain {
            #expect(abs(hypot(link.head.x, link.head.y) - hole) < 1e-9)
            #expect(abs(hypot(link.root.x, link.root.y) - hole) < 1e-9)
        }
        // 頭の角度が 1周 ÷ 6 ずつ増え、根元は1目手前にある
        let headAngles = layout.foundationChain.map { atan2(-Double($0.head.y), Double($0.head.x)) }
        for index in 0..<6 {
            #expect(sameAngle(headAngles[index], Double(index) * twoPi / 6))
        }
        for link in layout.foundationChain {
            let head = atan2(-Double(link.head.y), Double(link.head.x))
            let root = atan2(-Double(link.root.y), Double(link.root.x))
            #expect(abs(wrapped(head - root) - twoPi / 6) < 1e-9)
        }
    }

    @Test("穴の半径は鎖の目数で決まり、わの作り目より小さくならない")
    func chainRingHoleRadius() {
        let options = CircularLayout.Options()
        let magicRing = CircularLayout.holeRadius(for: .magicRing, options: options)

        // 鎖6目：円周が 6 になる大きさ（≒0.955）。わの作り目（0.8）より大きい
        let six = CircularLayout.holeRadius(for: .chainRing(chainCount: 6), options: options)
        #expect(abs(six - 6 / twoPi) < 1e-9)
        #expect(six > magicRing)

        // 鎖が多いほど穴が大きい
        #expect(CircularLayout.holeRadius(for: .chainRing(chainCount: 12), options: options) > six)

        // 鎖が少なくても、わの作り目より小さくはしない
        #expect(CircularLayout.holeRadius(for: .chainRing(chainCount: 3), options: options) == magicRing)

        // 鎖の作り目（往復編み）と わの作り目は今までどおり
        #expect(CircularLayout.holeRadius(for: .chain(stitchCount: 20), options: options) == magicRing)
    }

    @Test("1段目は穴の外側に並び、根元は輪の上にある")
    func chainRingFirstRow() {
        let layout = chainRingMotif().circularLayout()
        let hole = layout.rings[0].innerRadius
        let row1 = countedStitches(of: layout, row: 0)

        #expect(row1.count == 16)
        for stitch in row1 {
            // 頭は穴より外
            #expect(hypot(stitch.head.x, stitch.head.y) > hole)
            // 根元は輪のすぐ外（束に編み入れるので、輪から少し離して目ごとに並べる。domain-spec 11）
            #expect(stitch.bases.count == 1)
            let gap = CircularLayout.Options().chainRingBaseGap
            #expect(abs(hypot(stitch.bases[0].x, stitch.bases[0].y) - (hole + gap)) < 1e-9)
        }
        // 根元が1点に集まっていない
        #expect(Set(row1.map { "\($0.bases[0].x),\($0.bases[0].y)" }).count == 16)
    }

    @Test("わの作り目では作り目の鎖を描かない")
    func magicRingHasNoFoundationChain() {
        #expect(TestPatterns.tc1().circularLayout().foundationChain.isEmpty)
    }}
