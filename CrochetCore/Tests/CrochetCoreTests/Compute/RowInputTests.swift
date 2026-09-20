import Testing
@testable import CrochetCore

@Suite("段の指定位置への入力（ui-spec U16）")
struct RowInputTests {
    @Test("途中に目を挿入できる。最初の鎖以外の目なら立ち上がりが先頭に入り、位置が1つずれる")
    func insertStitch() {
        var row = Row(steps: [.stitch(.chain), .stitch(.chain)])
        let result = PatternInput.insertStitch(.doubleCrochet, at: 1, in: &row, method: .joinedRounds)

        #expect(result.insertedTurningChain)
        #expect(result.stepIndex == 2)
        #expect(row.steps.map(\.kind) == [.turningChain(chains: 3), .stitch(.chain), .stitch(.doubleCrochet), .stitch(.chain)])

        // 2回目は立ち上がりが入らない
        let second = PatternInput.insertStitch(.singleCrochet, at: 0, in: &row, method: .joinedRounds)
        #expect(!second.insertedTurningChain)
        #expect(second.stepIndex == 0)
        #expect(row.steps.first?.kind == .stitch(.singleCrochet))
    }

    @Test("先に選ぶ状態を付けて挿入できる。位置は範囲内に丸める")
    func insertWithModifier() {
        var row = Row(steps: [.turningChain(1), .stitch(.singleCrochet)])
        var modifier = StitchModifier()
        modifier.toggleIncrease()
        let result = PatternInput.insertStitch(.singleCrochet, modifier: modifier, at: 99, in: &row, method: .joinedRounds)
        #expect(result.stepIndex == 2)
        #expect(row.steps.last?.kind == .increase(.singleCrochet, count: 2))
    }

    @Test("入力位置の直前を消す。繰り返しは丸ごと、段を閉じる引き抜きは消さない、先頭では何もしない")
    func deleteBefore() {
        var row = Row(steps: [
            .turningChain(1),
            .repeating([.stitch(.singleCrochet)], times: 3),
            .stitch(.singleCrochet),
            .closeRound(),
        ])
        #expect(!PatternInput.deleteStep(before: 0, in: &row))
        #expect(!PatternInput.deleteStep(before: 4, in: &row))  // 引き抜きの直前ではない：index 4 の直前 = 引き抜き
        #expect(PatternInput.deleteStep(before: 2, in: &row))   // 繰り返しが丸ごと消える
        #expect(row.steps.map(\.kind) == [.turningChain(chains: 1), .stitch(.singleCrochet), .closeRound])
    }

    @Test("範囲を繰り返しにまとめる。立ち上がりは含めない")
    func wrapRange() {
        var row = Row(steps: [.turningChain(1), .stitch(.singleCrochet), .increase(.singleCrochet), .stitch(.singleCrochet), .closeRound()])
        #expect(PatternInput.wrapRepeat(0..<3, count: .times(4), in: &row))
        #expect(row.steps.count == 4)
        guard case .repeatGroup(let unit, .times(4)) = row.steps[1].kind else { Issue.record("繰り返しのはず"); return }
        #expect(unit.map(\.kind) == [.stitch(.singleCrochet), .increase(.singleCrochet, count: 2)])

        // 引き抜きを含む範囲はまとめられない
        #expect(!PatternInput.wrapRepeat(2..<4, count: .times(2), in: &row))
    }

    @Test("末尾への入力（入力中の段）は、指定位置への入力の特別な場合として同じ結果になる")
    func appendMatchesInsertAtEnd() {
        var viaPattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        for _ in 0..<3 { PatternInput.addStitch(.singleCrochet, to: &viaPattern) }
        PatternInput.addSkip(to: &viaPattern)

        var row = Row()
        for _ in 0..<3 { PatternInput.insertStitch(.singleCrochet, at: row.steps.count, in: &row, method: .joinedRounds) }
        PatternInput.insertSkip(at: row.steps.count, in: &row)

        #expect(viaPattern.rows[0].hasSameSteps(as: row))
    }
}
