import Testing
@testable import CrochetCore

@Suite("段の複製と手順の比較")
struct RowTests {
    @Test("複製は手順が同じで、段と操作（繰り返しの中も）の ID が新しい")
    func duplicated() {
        let original = TestPatterns.tc1().rows[2]
        let copy = original.duplicated()

        #expect(copy.hasSameSteps(as: original))
        #expect(copy.id != original.id)
        #expect(copy.steps.map(\.id) != original.steps.map(\.id))

        // 繰り返しの単位の中の操作も新しい ID になる
        guard case .repeatGroup(let unit, _) = original.steps[1].kind,
              case .repeatGroup(let copiedUnit, _) = copy.steps[1].kind else {
            Issue.record("3段目の2番目の操作は繰り返しのはず")
            return
        }
        #expect(Set(unit.map(\.id)).isDisjoint(with: copiedUnit.map(\.id)))
    }

    @Test("ID を無視した手順の比較")
    func hasSameSteps() {
        let row = Row(steps: [.turningChain(1), .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6), .closeRound()])
        let same = Row(steps: [.turningChain(1), .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6), .closeRound()])
        let differentTimes = Row(steps: [.turningChain(1), .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 5), .closeRound()])
        let differentUnit = Row(steps: [.turningChain(1), .repeating([.stitch(.halfDoubleCrochet), .increase(.singleCrochet)], times: 6), .closeRound()])
        let shorter = Row(steps: [.turningChain(1), .closeRound()])

        #expect(row.hasSameSteps(as: same))
        #expect(!row.hasSameSteps(as: differentTimes))
        #expect(!row.hasSameSteps(as: differentUnit))
        #expect(!row.hasSameSteps(as: shorter))
        #expect(row != same)  // ID が違うので通常の比較では等しくない
    }
}
