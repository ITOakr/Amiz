import Foundation
import Testing
@testable import CrochetCore

/// 立ち上がりを1目と数えるかを立ち上がりごとに持つ（domain-spec 6）
@Suite("立ち上がりを数えるかどうか")
struct TurningChainCountingTests {
    /// 前段12目の作品に、指定した立ち上がりの段を足す
    private func pattern(withRow steps: [Step]) -> Pattern {
        var pattern = TestPatterns.tc1()
        pattern.rows = Array(pattern.rows.prefix(2))  // 1段目 6目、2段目 12目
        pattern.rows.append(Row(steps: steps))
        return pattern
    }

    @Test("省略すると標準：鎖1目は数えない、鎖2目以上は数える")
    func standard() {
        #expect(Step.turningChain(1).kind == .turningChain(chains: 1, counted: false))
        #expect(Step.turningChain(2).kind == .turningChain(chains: 2, counted: true))
        #expect(Step.turningChain(3).kind == .turningChain(chains: 3, counted: true))
        #expect(StepKind.turningChain(chains: 4) == .turningChain(chains: 4, counted: true))
    }

    @Test("鎖3目で数えない：前段を拾わず目数にも入らない。長編み12目で12目")
    func uncountedThreeChains() {
        let steps: [Step] = [.turningChain(3, counted: false)] + (0..<12).map { _ in .stitch(.doubleCrochet) } + [.closeRound()]
        let expansion = pattern(withRow: steps).expanded()
        let row = expansion.rows[2]
        #expect(row.stitches[0].isCounted == false)
        #expect(row.stitches[0].picks.isEmpty)
        #expect(row.totalCount == 12)
        #expect(row.pickedCount == 12)
        #expect(expansion.warnings().isEmpty)
    }

    @Test("鎖1目で数える：前段の1目を拾い、1目と数える。細編み11目で12目")
    func countedOneChain() {
        let steps: [Step] = [.turningChain(1, counted: true)] + (0..<11).map { _ in .stitch(.singleCrochet) } + [.closeRound()]
        let expansion = pattern(withRow: steps).expanded()
        let row = expansion.rows[2]
        #expect(row.stitches[0].isCounted == true)
        #expect(row.stitches[0].picks == 0..<1)
        #expect(row.totalCount == 12)
        #expect(expansion.warnings().isEmpty)
    }

    @Test("「残りの目すべてに」の回数も数え方に従う：鎖3目で数えないなら12回、数えるなら11回")
    func untilEndFollowsCounting() {
        let uncounted = pattern(withRow: [.turningChain(3, counted: false), .untilEnd([.stitch(.doubleCrochet)])]).expanded()
        #expect(uncounted.rows[2].totalCount == 12)
        let counted = pattern(withRow: [.turningChain(3, counted: true), .untilEnd([.stitch(.doubleCrochet)])]).expanded()
        #expect(counted.rows[2].totalCount == 12)
        #expect(counted.rows[2].stitches.filter { $0.role == .regular }.count == 11)
    }

    @Test("目数表：標準と違う数え方だけ注記する")
    func tableText() {
        #expect(StitchTableFormatter.items(for: [.turningChain(3)]) == ["立ち上がり鎖3目"])
        #expect(StitchTableFormatter.items(for: [.turningChain(3, counted: false)]) == ["立ち上がり鎖3目（数えない）"])
        #expect(StitchTableFormatter.items(for: [.turningChain(1)]) == [])
        #expect(StitchTableFormatter.items(for: [.turningChain(1, counted: true)]) == ["立ち上がり鎖1目（1目と数える）"])
        #expect(StitchTableFormatter.label(for: .turningChain(2, counted: false)) == "立ち上がり鎖2（数えない）")
    }

    @Test("鎖の作り目の鎖の目数：1段目の立ち上がりを数えるときだけ1目引く（domain-spec 33）")
    func foundationChainCount() {
        var pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20))
        pattern.rows = [Row(steps: [.turningChain(3, counted: false)])]
        #expect(StitchTableFormatter.foundationChainCount(for: pattern) == 23)
        pattern.rows = [Row(steps: [.turningChain(3, counted: true)])]
        #expect(StitchTableFormatter.foundationChainCount(for: pattern) == 22)
    }

    @Test("入力：数えるかを指定して立ち上がりを自動で入れる。指定しなければ標準")
    func inputWithCounted() {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.finishRow(of: &pattern)
        #expect(PatternInput.turningChainToInsert(for: .doubleCrochet, in: pattern) == 3)
        #expect(PatternInput.turningChainToInsert(for: .chain, in: pattern) == nil)

        PatternInput.addStitch(.doubleCrochet, turningChainCounted: false, to: &pattern)
        #expect(pattern.rows[1].steps[0].kind == .turningChain(chains: 3, counted: false))
        // 2目めからは立ち上がりが入らない
        #expect(PatternInput.turningChainToInsert(for: .doubleCrochet, in: pattern) == nil)
        #expect(pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: false))
    }

    @Test("立ち上がりボタンと選択：数えるかを指定して入れ替え、後から切り替えられる")
    func setTurningChain() {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        PatternInput.setTurningChain(chains: 1, counted: true, in: &pattern)
        #expect(pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: true))
        PatternInput.setTurningChain(chains: 3, in: &pattern)
        #expect(pattern.rows[0].steps[0].kind == .turningChain(chains: 3, counted: true))

        let rowID = pattern.rows[0].id
        #expect(PatternInput.setTurningChainCounted(false, rowID: rowID, in: &pattern))
        #expect(pattern.rows[0].steps[0].kind == .turningChain(chains: 3, counted: false))
        PatternInput.setTurningChain(chains: 2, counted: false, rowID: rowID, in: &pattern)
        #expect(pattern.rows[0].steps[0].kind == .turningChain(chains: 2, counted: false))

        // 立ち上がりのない段では何もしない
        var empty = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [Row()])
        #expect(PatternInput.setTurningChainCounted(true, rowID: empty.rows[0].id, in: &empty) == false)
    }

    @Test("図：数えない鎖3目の立ち上がりは継ぎ目に、鎖の目数ぶんの高さで描く")
    func layoutOfUncountedTallTurningChain() {
        let steps: [Step] = [.turningChain(3, counted: false)] + (0..<12).map { _ in .stitch(.doubleCrochet) } + [.closeRound()]
        let source = pattern(withRow: steps)
        let layout = source.circularLayout()
        let ring = layout.rings[2]
        let turningChain = layout.stitches.first { $0.rowIndex == 2 && $0.role == .turningChain(chains: 3) }!
        let radius = hypot(turningChain.head.x - layout.center.x, turningChain.head.y - layout.center.y)
        #expect(radius > ring.innerRadius + 2)
        #expect(radius < ring.outerRadius - 0.12)
        #expect(turningChain.countedIndex == nil)
    }
}
