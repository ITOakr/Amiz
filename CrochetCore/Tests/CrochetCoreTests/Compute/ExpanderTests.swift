import Testing
@testable import CrochetCore

@Suite("手順の展開と目数（domain-spec 8・17・21）")
struct ExpanderTests {
    @Test("TC-1 わの作り目からの輪編み：各段の目数と拾った目数")
    func tc1() {
        let expansion = TestPatterns.tc1().expanded()

        #expect(expansion.rows.map(\.totalCount) == [6, 12, 18, 24, 24])
        #expect(expansion.rows.map(\.previousCount) == [nil, 6, 12, 18, 24])
        // 1段目はわの作り目に6目編み入れる（前段はない）。2段目以降は前段を全部拾う
        #expect(expansion.rows.map(\.pickedCount) == [6, 6, 12, 18, 24])
        // 鎖を含まない段なので、鎖抜きの目数は合計と同じ
        #expect(expansion.rows.map(\.nonChainCount) == [6, 12, 18, 24, 24])
        #expect(expansion.rows.allSatisfy { !$0.containsChains })
        #expect(expansion.rows.allSatisfy { $0.issues.isEmpty })
    }

    @Test("TC-1 1段目：立ち上がり鎖1と引き抜きは数えず、前段も拾わない")
    func tc1FirstRow() {
        let row = TestPatterns.tc1().expanded().rows[0]

        // 展開後は 立ち上がり + 細編み6 + 引き抜き = 8 要素だが、数えるのは細編みの6目だけ
        #expect(row.stitches.count == 8)
        #expect(row.totalCount == 6)
        #expect(row.stitches.first?.role == .turningChain(chains: 1))
        #expect(row.stitches.first?.isCounted == false)
        #expect(row.stitches.first?.picks.isEmpty == true)
        #expect(row.stitches.last?.role == .closingSlipStitch)
        #expect(row.stitches.last?.isCounted == false)
    }

    @Test("TC-1 2段目：「全目に増し目」は前段の目数（6）に合わせて6回になる")
    func tc1UntilEndIncrease() {
        let pattern = TestPatterns.tc1()
        let row = pattern.expanded().rows[1]
        let repeatStep = pattern.rows[1].steps[1]

        #expect(row.repeatCounts[repeatStep.id] == 6)
        #expect(row.totalCount == 12)

        // 増し目の2目は同じ前段の目を拾う（domain-spec 2）
        let increaseStitches = row.stitches.filter { $0.role == .regular }
        #expect(increaseStitches.count == 12)
        #expect(increaseStitches[0].picks == 0..<1)
        #expect(increaseStitches[1].picks == 0..<1)
        #expect(increaseStitches[2].picks == 1..<2)
        // 3回目の繰り返しの2目め（repetition: 2, ordinal: 1）が指せる（tech-spec 5-3）
        #expect(increaseStitches[5].ref.repetition == 2)
        #expect(increaseStitches[5].ref.ordinal == 1)
    }

    @Test("TC-3 長編みの段：立ち上がり鎖3目を1目と数え、前段の1目を拾う")
    func tc3() {
        let row = TestPatterns.tc3().expanded().rows[1]

        #expect(row.totalCount == 12)
        #expect(row.nonChainCount == 12)
        #expect(row.pickedCount == 12)
        #expect(row.previousCount == 12)
        #expect(row.stitches.first?.role == .turningChain(chains: 3))
        #expect(row.stitches.first?.isCounted == true)
        #expect(row.stitches.first?.picks == 0..<1)
    }

    @Test("TC-4 鎖を含む段：合計36目／鎖抜き12目、前段は12目拾う")
    func tc4() {
        let row = TestPatterns.tc4().expanded().rows[1]

        #expect(row.totalCount == 36)
        #expect(row.nonChainCount == 12)
        #expect(row.containsChains)
        #expect(row.pickedCount == 12)
        #expect(row.unpickedCount == 0)
    }

    @Test("TC-6 割り切れない場合：（細編み1目、増し目）を前段13目に段の終わりまで → 6回、1目残る")
    func tc6() {
        let pattern = TestPatterns.tc6()
        let row = pattern.expanded().rows[1]
        let repeatStep = pattern.rows[1].steps[1]

        #expect(row.repeatCounts[repeatStep.id] == 6)
        #expect(row.totalCount == 18)
        #expect(row.pickedCount == 12)
        #expect(row.unpickedCount == 1)
        #expect(!row.leavesRemaining)
        #expect(row.issues.isEmpty)
    }

    @Test("TC-6 「残りは編まない」を付けると、そのことが展開結果に残る")
    func tc6LeaveRemaining() {
        let row = TestPatterns.tc6(leaveRemaining: true).expanded().rows[1]

        #expect(row.totalCount == 18)
        #expect(row.unpickedCount == 1)
        #expect(row.leavesRemaining)
    }

    @Test("n目一度は前段の n 目をまとめて拾い、飛ばすはカーソルだけ進める")
    func decreaseAndSkip() {
        // 前段6目に「細編み2目一度、1目飛ばす、細編み3目一度」
        let pattern = TestPatterns.afterRound(of: 6, row: Row(steps: [
            .turningChain(1),
            .decrease(.singleCrochet, count: 2),
            .skip(),
            .decrease(.singleCrochet, count: 3),
            .closeRound(),
        ]))
        let row = pattern.expanded().rows[1]

        #expect(row.totalCount == 2)
        #expect(row.pickedCount == 6)
        let regular = row.stitches.filter { $0.role == .regular }
        #expect(regular[0].picks == 0..<2)
        #expect(regular[1].picks == 3..<6)
    }

    @Test("鎖の作り目：1段目の前段の目数は「1段目に編む目数」になる")
    func chainFoundation() {
        let pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: [
            Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 20)),
        ])
        let row = pattern.expanded().rows[0]

        #expect(row.previousCount == 20)
        #expect(row.pickedCount == 20)
        #expect(row.totalCount == 20)
    }

    @Test("「段の終わりまで」の単位が前段を拾わない場合は0回にして問題を記録する")
    func untilEndWithChainsOnly() {
        let pattern = TestPatterns.afterRound(of: 6, row: Row(steps: [
            .turningChain(1),
            .untilEnd([.stitch(.chain)]),
            .closeRound(),
        ]))
        let row = pattern.expanded().rows[1]
        let repeatStep = pattern.rows[1].steps[1]

        #expect(row.repeatCounts[repeatStep.id] == 0)
        #expect(row.issues == [.untilEndUnitPicksNothing(stepID: repeatStep.id)])
    }

    @Test("わの作り目の1段目で「段の終わりまで」は回数が決まらないので問題を記録する")
    func untilEndInMagicRingFirstRow() {
        let pattern = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(steps: [.turningChain(1), .untilEnd([.stitch(.singleCrochet)]), .closeRound()]),
        ])
        let row = pattern.expanded().rows[0]
        let repeatStep = pattern.rows[0].steps[1]

        #expect(row.totalCount == 0)
        #expect(row.issues == [.untilEndWithoutPreviousCount(stepID: repeatStep.id)])
    }
}
