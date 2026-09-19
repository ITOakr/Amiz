import Testing
@testable import CrochetCore

@Suite("目数表の文章（ui-spec 5-4・8章、domain-spec 8・18）")
struct StitchTableFormatterTests {
    /// 各段の手順文
    private func instructions(of pattern: Pattern) -> [String] {
        pattern.rows.indices.map { StitchTableFormatter.instruction(for: pattern.rows[$0], rowIndex: $0, in: pattern) }
    }

    @Test("TC-1「くまの頭」の手順文は ui-spec 8章のサンプルと一致する")
    func tc1() {
        #expect(instructions(of: TestPatterns.tc1()) == [
            "わの作り目に細編み6目",
            "細編み2目編み入れる×全目",
            "（細編み1目、細編み2目編み入れる）×6",
            "（細編み2目、細編み2目編み入れる）×6",
            "残りの目すべてに細編み",
        ])
    }

    @Test("TC-2 修正後（S3 のサンプル）：1段目が7目、2段目は×全目のまま")
    func tc2() {
        let pattern = TestPatterns.tc2AfterKeepingRowsAbove()
        let expansion = pattern.expanded()

        #expect(instructions(of: pattern)[0...1] == ["わの作り目に細編み7目", "細編み2目編み入れる×全目"])
        #expect(expansion.rows[0...2].map(StitchTableFormatter.countText) == ["7目", "14目", "18目"])
    }

    @Test("TC-3 長編みの段：立ち上がり鎖3目を書き、引き抜きは書かない")
    func tc3() {
        let pattern = TestPatterns.tc3()
        #expect(instructions(of: pattern)[1] == "立ち上がり鎖3目、長編み11目")
        #expect(StitchTableFormatter.countText(for: pattern.expanded().rows[1]) == "12目")
    }

    @Test("TC-4 鎖を含む段：合計と鎖抜きを併記する")
    func tc4() {
        let pattern = TestPatterns.tc4()
        #expect(instructions(of: pattern)[1] == "立ち上がり鎖3目、鎖2目、（長編み1目、鎖2目）×11")
        #expect(StitchTableFormatter.countText(for: pattern.expanded().rows[1]) == "合計36目／鎖抜き12目")
    }

    @Test("「花のモチーフ」2段目（段の終わりまで）は ui-spec 8章のサンプルと一致する")
    func flowerMotif() {
        let pattern = TestPatterns.afterRound(of: 12, row: Row(steps: [
            .turningChain(3),
            .stitch(.chain), .stitch(.chain),
            .untilEnd([.stitch(.doubleCrochet), .stitch(.chain), .stitch(.chain)]),
            .closeRound(),
        ]))
        #expect(instructions(of: pattern)[1] == "立ち上がり鎖3目、鎖2目、（長編み1目、鎖2目）を段の終わりまで")
        #expect(StitchTableFormatter.countText(for: pattern.expanded().rows[1]) == "合計36目／鎖抜き12目")
    }

    @Test("n目一度・飛ばす・残りは編まない・束に")
    func otherSteps() {
        let row = Row(steps: [
            .turningChain(1),
            .decrease(.singleCrochet, count: 2),
            .skip(),
            .skip(),
            .decrease(.doubleCrochet, count: 3),
            .increase(.singleCrochet, count: 3, into: .chainSpace),
            .stitch(.singleCrochet, into: .chainSpace),
            .leaveRemaining(),
            .closeRound(),
        ])
        let pattern = TestPatterns.afterRound(of: 10, row: row)
        #expect(instructions(of: pattern)[1] == "細編み2目一度、2目飛ばす、長編み3目一度、束に細編み3目編み入れる、束に細編み1目、残りは編まない")
    }

    @Test("単位が1つの繰り返しは括弧なし、鎖の作り目の1段目は「作り目に」")
    func singleUnitRepeatAndChainFoundation() {
        let pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: [
            Row(steps: [.turningChain(1), .repeating([.stitch(.singleCrochet)], times: 20)]),
            Row(steps: [.turningChain(3), .repeating([.decrease(.doubleCrochet)], times: 5), .untilEnd([.increase(.doubleCrochet)])]),
        ])
        #expect(instructions(of: pattern) == [
            "作り目に細編み1目×20",
            "立ち上がり鎖3目、長編み2目一度×5、長編み2目編み入れる×全目",
        ])
    }

    @Test("同じ内容で目数が変わらない段が続けば「5〜9段目」にまとめる")
    func mergedRows() {
        // TC-1 の5段目（残りの目すべてに細編み、24目）を4回複製して 5〜9段目にする
        let pattern = PatternEditor.applyKeepingRowsAbove(.duplicate(rowIndex: 4, times: 4), to: TestPatterns.tc1())
        let expansion = pattern.expanded()
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion, warnings: expansion.warnings())

        #expect(rows.map(\.rowNumberText) == ["1段目", "2段目", "3段目", "4段目", "5〜9段目"])
        #expect(rows.map(\.isMerged) == [false, false, false, false, true])
        #expect(rows.map(\.isUnchangedRun) == [false, false, false, false, true])
        #expect(rows[4].instruction == "残りの目すべてに細編み")
        #expect(rows[4].countText == "24目")
        #expect(rows[4].rowIDs == pattern.rows[4...8].map(\.id))
    }

    @Test("同じ手順でも目数が変わる段はまとめない（「全目に増し目」を2段続けた場合）")
    func sameStepsDifferentCounts() {
        var pattern = TestPatterns.tc1()
        pattern.rows = Array(pattern.rows[0...1]) + [pattern.rows[1].duplicated()]  // 6 → 12 → 24
        let expansion = pattern.expanded()
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion)

        #expect(rows.map(\.rowNumberText) == ["1段目", "2段目", "3段目"])
        #expect(rows.allSatisfy { !$0.isMerged })
    }

    @Test("警告のある段はまとめない")
    func warnedRowsAreNotMerged() {
        // 前段6目に細編み7目を2段続ける：手順も目数（7目）も同じだが、2段目に拾いすぎの警告がある
        let row = Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.closeRound()])
        var pattern = TestPatterns.afterRound(of: 6, row: row)
        pattern.rows.append(row.duplicated())
        let expansion = pattern.expanded()
        let warnings = expansion.warnings()
        #expect(warnings.map(\.rowNumber) == [2])

        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion, warnings: warnings)
        #expect(rows.map(\.rowNumberText) == ["1段目", "2段目", "3段目"])
    }

    @Test("操作1つの表記（現在の段の項目）")
    func stepLabels() {
        let labels = [
            Step.turningChain(1), .stitch(.singleCrochet), .increase(.singleCrochet), .decrease(.doubleCrochet, count: 3),
            .skip(), .leaveRemaining(), .closeRound(), .stitch(.chain),
            .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6),
            .untilEnd([.stitch(.singleCrochet)]),
        ].map(StitchTableFormatter.label)

        #expect(labels == [
            "立ち上がり鎖1", "細編み", "細編み2目編み入れる", "長編み3目一度",
            "1目飛ばす", "残りは編まない", "引き抜き", "鎖編み",
            "（細編み1目、細編み2目編み入れる）×6",
            "残りの目すべてに細編み",
        ])
    }

    @Test("作り目の行：わの作り目、鎖の作り目は鎖の目数を計算する（TC-7）")
    func foundationText() {
        #expect(StitchTableFormatter.foundationText(for: TestPatterns.tc1()) == "わの作り目")
        #expect(StitchTableFormatter.foundationChainCount(for: TestPatterns.tc1()) == nil)

        // 1段目を編み始める前 → 仮表示 21
        var pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20))
        #expect(StitchTableFormatter.foundationText(for: pattern) == "作り目：鎖21目")

        // 細編み（鎖1目）→ 21、長編み（鎖3目）→ 22
        pattern.rows = [Row(steps: [.turningChain(1), .stitch(.singleCrochet)])]
        #expect(StitchTableFormatter.foundationChainCount(for: pattern) == 21)
        pattern.rows = [Row(steps: [.turningChain(3), .stitch(.doubleCrochet)])]
        #expect(StitchTableFormatter.foundationChainCount(for: pattern) == 22)
    }

    @Test("目の種類の日本語名")
    func japaneseNames() {
        #expect(StitchKind.allCases.map(\.japaneseName) == ["鎖編み", "引き抜き編み", "細編み", "中長編み", "長編み", "長々編み"])
        #expect(StitchKind.chain.instructionName == "鎖")
        #expect(StitchKind.doubleCrochet.instructionName == "長編み")
    }
}
